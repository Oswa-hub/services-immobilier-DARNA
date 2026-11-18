'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore, FakeMessaging, silentLogger } = require('./fake_firestore');
const { createNotifier } = require('../src/notifier');
const h = require('../src/handlers');

const NOW = 'SERVER_TIMESTAMP';

function setup(seed, { deadTokens = [] } = {}) {
  const db = new FakeFirestore(seed);
  const messaging = new FakeMessaging(deadTokens);
  const notifier = createNotifier({ db, messaging, now: () => NOW, logger: silentLogger });
  return { db, messaging, notifier, deps: { db, notifier, logger: silentLogger } };
}

const notificationsOf = (db, uid) => Object.values(db.dump('notifications')).filter((n) => n.userId === uid);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

test('notifyUser writes the in-app doc, pushes to every device, prunes dead tokens', async () => {
  const { db, messaging, notifier } = setup(
    {
      'users/u1': { email: 'u1@x.tn', status: 'active' },
      'users/u1/devices/t-ok': { token: 't-ok' },
      'users/u1/devices/t-dead': { token: 't-dead' },
    },
    { deadTokens: ['t-dead'] },
  );

  const res = await notifier.notifyUser('u1', { type: 'newMessage', title: 'Hi', body: 'Yo', conversationId: 'c1' });

  assert.ok(res.id);
  const doc = db.dump('notifications')[res.id];
  assert.deepEqual(doc, {
    userId: 'u1',
    type: 'newMessage',
    title: 'Hi',
    body: 'Yo',
    read: false,
    readAt: null,
    createdAt: NOW,
    conversationId: 'c1',
  });
  assert.equal(messaging.sent.length, 1);
  assert.deepEqual(messaging.sent[0].tokens.sort(), ['t-dead', 't-ok']);
  assert.equal(messaging.sent[0].data.conversationId, 'c1');
  assert.deepEqual(Object.keys(db.dump('users/u1/devices')), ['t-ok']);
  assert.deepEqual(db.dump('mail'), {}); // newMessage is never emailed
});

test('notifyUser respects preferences (category off -> nothing; push off -> in-app only)', async () => {
  const { db, messaging, notifier } = setup({
    'users/a': { notificationPreferences: { newMessages: false } },
    'users/b': { notificationPreferences: { pushNotifications: false } },
    'users/b/devices/t': { token: 't' },
  });
  assert.equal((await notifier.notifyUser('a', { type: 'newMessage', title: 't' })).id, null);
  assert.ok((await notifier.notifyUser('b', { type: 'newMessage', title: 't' })).id);
  assert.equal(notificationsOf(db, 'a').length, 0);
  assert.equal(notificationsOf(db, 'b').length, 1);
  assert.equal(messaging.sent.length, 0);
});

test('notifyUser queues an email when opted in', async () => {
  const { db, notifier } = setup({
    'users/u': { email: 'u@x.tn', notificationPreferences: { emailNotifications: true } },
  });
  await notifier.notifyUser('u', { type: 'listingApproved', title: 'Annonce approuvée', body: 'En ligne <b>' });
  const mails = Object.values(db.dump('mail'));
  assert.equal(mails.length, 1);
  assert.equal(mails[0].to, 'u@x.tn');
  assert.equal(mails[0].message.subject, 'ImmoFind — Annonce approuvée');
  assert.match(mails[0].message.html, /En ligne &lt;b&gt;/);
});

test('notifyUser skips unknown users, banned accounts and unknown types', async () => {
  const { db, notifier } = setup({ 'users/banned': { status: 'banned' } });
  assert.equal((await notifier.notifyUser('ghost', { type: 'newMessage', title: 't' })).id, null);
  assert.equal((await notifier.notifyUser('banned', { type: 'newMessage', title: 't' })).id, null);
  assert.equal((await notifier.notifyUser('banned', { type: 'weird', title: 't' })).id, null);
  assert.deepEqual(db.dump('notifications'), {});
});

test('dedupeKey makes a retried event a no-op', async () => {
  const { db, messaging, notifier } = setup({ 'users/u': {}, 'users/u/devices/t': { token: 't' } });
  const p = { type: 'newMessage', title: 't' };
  const first = await notifier.notifyUser('u', p, { dedupeKey: 'evt1' });
  const again = await notifier.notifyUser('u', p, { dedupeKey: 'evt1' });
  assert.ok(first.id);
  assert.equal(again.duplicate, true);
  assert.equal(notificationsOf(db, 'u').length, 1);
  assert.equal(messaging.sent.length, 1);
});

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

test('onPropertyCreated tells the owner the listing is under review', async () => {
  const { db, deps } = setup({ 'users/o': {} });
  await h.onPropertyCreated(deps, {
    propertyId: 'p1',
    after: { ownerId: 'o', status: 'pending_review', title: 'Studio' },
    eventId: 'e',
  });
  const [n] = notificationsOf(db, 'o');
  assert.equal(n.type, 'listingSubmitted');
  assert.equal(n.propertyId, 'p1');
});

test('onPropertyUpdated: approval notifies owner and sends governorate alerts (not to the owner)', async () => {
  const { db, deps } = setup({
    'users/o': { preferredCity: 'Tunis' },
    'users/u1': { preferredCity: 'Tunis', status: 'active' },
    'users/u2': { preferredCity: 'Sousse' },
  });
  const before = { status: 'pending_review', ownerId: 'o', publishedAt: null, governorate: 'Tunis', title: 'Villa', price: 900000 };
  const after = { ...before, status: 'published', publishedAt: 'now', city: 'La Marsa' };

  const counts = await h.onPropertyUpdated(deps, { propertyId: 'p1', before, after, eventId: 'e1' });

  assert.deepEqual(counts, { owner: 1, favorites: 0, alerts: 1 });
  assert.equal(notificationsOf(db, 'o')[0].type, 'listingApproved');
  const alert = notificationsOf(db, 'u1')[0];
  assert.equal(alert.type, 'newMatchingProperty');
  assert.match(alert.body, /La Marsa, Tunis · 900 000 TND/);
  assert.equal(notificationsOf(db, 'u2').length, 0);
});

test('onPropertyUpdated: restoring a listing does not re-send alerts', async () => {
  const { db, deps } = setup({ 'users/o': {}, 'users/u1': { preferredCity: 'Tunis' } });
  const before = { status: 'suspended', ownerId: 'o', publishedAt: 'earlier', governorate: 'Tunis' };
  const counts = await h.onPropertyUpdated(deps, {
    propertyId: 'p1',
    before,
    after: { ...before, status: 'published' },
    eventId: 'e',
  });
  assert.deepEqual(counts, { owner: 1, favorites: 0, alerts: 0 });
  assert.equal(notificationsOf(db, 'o')[0].type, 'listingRestored');
});

test('onPropertyUpdated: price change notifies users who saved it', async () => {
  const { db, deps } = setup({
    'users/o': {},
    'users/fan': {},
    'users/quiet': { notificationPreferences: { favoriteUpdates: false } },
    'favorites/fan_p1': { userId: 'fan', propertyId: 'p1' },
    'favorites/quiet_p1': { userId: 'quiet', propertyId: 'p1' },
    'favorites/fan_p2': { userId: 'fan', propertyId: 'p2' },
  });
  const before = { status: 'published', ownerId: 'o', price: 300000, title: 'Duplex', publishedAt: 'x' };
  const counts = await h.onPropertyUpdated(deps, {
    propertyId: 'p1',
    before,
    after: { ...before, price: 280000 },
    eventId: 'e',
  });
  assert.deepEqual(counts, { owner: 0, favorites: 1, alerts: 0 });
  const [n] = notificationsOf(db, 'fan');
  assert.equal(n.type, 'priceChanged');
  assert.deepEqual(n.data, { oldPrice: 300000, newPrice: 280000 });
  assert.equal(notificationsOf(db, 'quiet').length, 0);
  assert.equal(notificationsOf(db, 'o').length, 0);
});

test('onMessageCreated: first message is an inquiry for the owner, sender is not notified', async () => {
  const { db, deps } = setup({
    'users/buyer': { name: 'Sami Ben Ali' },
    'users/owner': {},
    'conversations/p1_buyer': { participants: ['buyer', 'owner'], userId: 'buyer', recipientId: 'owner', propertyId: 'p1' },
    'conversations/p1_buyer/messages/m1': { senderId: 'buyer', text: 'Bonjour' },
  });
  const n = await h.onMessageCreated(deps, {
    conversationId: 'p1_buyer',
    message: { senderId: 'buyer', text: 'Bonjour' },
    eventId: 'e',
  });
  assert.equal(n, 1);
  const [msg] = notificationsOf(db, 'owner');
  assert.equal(msg.type, 'newInquiry');
  assert.equal(msg.title, 'Nouveau message de Sami Ben Ali');
  assert.equal(msg.conversationId, 'p1_buyer');
  assert.equal(notificationsOf(db, 'buyer').length, 0);
});

test('onMessageCreated: a reply is a plain new message', async () => {
  const { db, deps } = setup({
    'users/buyer': {},
    'users/owner': { name: 'Agence Carthage' },
    'conversations/c': { participants: ['buyer', 'owner'], userId: 'buyer', recipientId: 'owner' },
    'conversations/c/messages/m1': { senderId: 'buyer', text: 'Bonjour' },
    'conversations/c/messages/m2': { senderId: 'owner', text: 'Oui' },
  });
  await h.onMessageCreated(deps, { conversationId: 'c', message: { senderId: 'owner', text: 'Oui' }, eventId: 'e' });
  assert.equal(notificationsOf(db, 'buyer')[0].type, 'newMessage');
});

test('onVerificationUpdated notifies the requester (or the listing owner)', async () => {
  const { db, deps } = setup({ 'users/a': {}, 'users/o': {}, 'properties/p': { ownerId: 'o' } });
  await h.onVerificationUpdated(deps, {
    verificationId: 'v1',
    before: { status: 'pending' },
    after: { status: 'approved', targetId: 'a', targetType: 'agent' },
    eventId: 'e1',
  });
  await h.onVerificationUpdated(deps, {
    verificationId: 'v2',
    before: { status: 'pending' },
    after: { status: 'rejected', targetId: 'p', targetType: 'property' },
    eventId: 'e2',
  });
  assert.equal(notificationsOf(db, 'a')[0].type, 'verificationApproved');
  const own = notificationsOf(db, 'o')[0];
  assert.equal(own.type, 'verificationRejected');
  assert.equal(own.propertyId, 'p');
});

test('onDeviceRegistered removes the token from other accounts only', async () => {
  const { db, deps } = setup({
    'users/old/devices/tok': { token: 'tok' },
    'users/new/devices/tok': { token: 'tok' },
    'users/other/devices/x': { token: 'x' },
  });
  const removed = await h.onDeviceRegistered(deps, { userId: 'new', token: 'tok' });
  assert.equal(removed, 1);
  assert.deepEqual(Object.keys(db.dump('users/old/devices')), []);
  assert.deepEqual(Object.keys(db.dump('users/new/devices')), ['tok']);
  assert.deepEqual(Object.keys(db.dump('users/other/devices')), ['x']);
});

test('sendAdminNotification: admin only, validated, fan-out + audit log', async () => {
  const { db, deps } = setup({
    'users/admin': { role: 'admin', status: 'active' },
    'users/u1': { role: 'user', status: 'active' },
    'users/a1': { role: 'agent', status: 'active' },
    'users/s1': { role: 'user', status: 'suspended' },
  });
  const now = () => NOW;

  await assert.rejects(
    h.sendAdminNotification(deps, { caller: null, input: {}, now }),
    (e) => e.code === 'unauthenticated',
  );
  await assert.rejects(
    h.sendAdminNotification(deps, { caller: { uid: 'u1' }, input: {}, now }),
    (e) => e.code === 'permission-denied',
  );
  await assert.rejects(
    h.sendAdminNotification(deps, { caller: { uid: 'admin' }, input: { target: 'all', title: 'x', body: 'y' }, now }),
    (e) => e.code === 'invalid-argument',
  );

  const all = await h.sendAdminNotification(deps, {
    caller: { uid: 'admin' },
    input: { target: 'all', title: 'Maintenance', body: 'Service indisponible ce soir.' },
    now,
  });
  assert.deepEqual(all, { recipients: 3, delivered: 3 }); // admin + u1 + a1, not the suspended user
  assert.equal(notificationsOf(db, 's1').length, 0);

  const agents = await h.sendAdminNotification(deps, {
    caller: { uid: 'admin' },
    input: { target: 'role:agent', title: 'Agents', body: 'Nouvelle fonctionnalité.' },
    now,
  });
  assert.deepEqual(agents, { recipients: 1, delivered: 1 });

  const logs = Object.values(db.dump('audit_logs'));
  assert.equal(logs.length, 2);
  assert.equal(logs[0].action, 'notification.send');
  assert.equal(logs[0].targetId, 'all');
  assert.equal(logs[1].targetId, 'role:agent');
});
