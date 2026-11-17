'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const r = require('../src/notification_rules');

test('every type has a category, unknown types fall back to account', () => {
  for (const t of Object.values(r.TYPES)) assert.ok(r.isKnownType(t), t);
  assert.equal(r.categoryOf('nope'), 'account');
});

test('resolvePreferences fills defaults and ignores non-booleans', () => {
  assert.deepEqual(r.resolvePreferences(undefined), r.DEFAULT_PREFERENCES);
  const p = r.resolvePreferences({ newMessages: false, pushNotifications: 'yes', extra: true });
  assert.equal(p.newMessages, false);
  assert.equal(p.pushNotifications, true);
  assert.equal(p.extra, undefined);
});

test('channelsFor: optional category switched off -> nothing at all', () => {
  assert.deepEqual(r.channelsFor('newMessage', { newMessages: false }), { inApp: false, push: false, email: false });
  assert.deepEqual(r.channelsFor('priceChanged', { favoriteUpdates: false }), { inApp: false, push: false, email: false });
  assert.equal(r.channelsFor('newMatchingProperty', { propertyAlerts: false }).inApp, false);
  assert.equal(r.channelsFor('platformAnnouncement', { announcements: false }).inApp, false);
});

test('channelsFor: account notifications cannot be switched off', () => {
  const all = { newMessages: false, favoriteUpdates: false, propertyAlerts: false, announcements: false };
  assert.equal(r.channelsFor('listingApproved', all).inApp, true);
  assert.equal(r.channelsFor('verificationRejected', all).inApp, true);
});

test('channelsFor: push follows the master switch', () => {
  assert.equal(r.channelsFor('newMessage', {}).push, true);
  assert.equal(r.channelsFor('newMessage', { pushNotifications: false }).push, false);
  assert.equal(r.channelsFor('newMessage', { pushNotifications: false }).inApp, true);
});

test('channelsFor: email only for transactional types and when opted in', () => {
  assert.equal(r.channelsFor('listingApproved', {}).email, false); // default off
  assert.equal(r.channelsFor('listingApproved', { emailNotifications: true }).email, true);
  assert.equal(r.channelsFor('newMessage', { emailNotifications: true }).email, false);
  // Security notice: always emailed.
  assert.equal(r.channelsFor('accountWarning', {}).email, true);
});

test('formatPrice groups thousands', () => {
  assert.equal(r.formatPrice(1250000), '1 250 000 TND');
  assert.equal(r.formatPrice(950.4, 'EUR'), '950 EUR');
  assert.equal(r.formatPrice('abc'), '');
});

test('truncate collapses whitespace and adds an ellipsis', () => {
  assert.equal(r.truncate('  a   b ', 10), 'a b');
  assert.equal(r.truncate('abcdefghij', 5), 'abcd…');
  assert.equal(r.truncate(null, 5), '');
});

test('listingStatusNotification: approve / reject / suspend / restore', () => {
  const p = { title: 'Villa La Marsa' };
  const approved = r.listingStatusNotification({ status: 'pending_review' }, { ...p, status: 'published' }, 'p1');
  assert.equal(approved.type, 'listingApproved');
  assert.equal(approved.propertyId, 'p1');
  assert.match(approved.body, /Villa La Marsa/);

  const rejected = r.listingStatusNotification(
    { status: 'pending_review' },
    { ...p, status: 'rejected', rejectionReason: 'Photos floues' },
    'p1',
  );
  assert.equal(rejected.type, 'listingRejected');
  assert.match(rejected.body, /Photos floues/);

  assert.equal(r.listingStatusNotification({ status: 'published' }, { ...p, status: 'suspended' }, 'p1').type, 'listingSuspended');
  assert.equal(r.listingStatusNotification({ status: 'suspended' }, { ...p, status: 'published' }, 'p1').type, 'listingRestored');
});

test('listingStatusNotification: owner actions and no-ops are silent', () => {
  assert.equal(r.listingStatusNotification({ status: 'draft' }, { status: 'pending_review' }, 'p'), null);
  assert.equal(r.listingStatusNotification({ status: 'published' }, { status: 'removed' }, 'p'), null);
  assert.equal(r.listingStatusNotification({ status: 'published' }, { status: 'published' }, 'p'), null);
  assert.equal(r.listingStatusNotification(undefined, { status: 'published' }, 'p'), null);
});

test('priceChangeNotification only for a published listing whose price changed', () => {
  const before = { status: 'published', price: 500000, title: 'Appartement' };
  const down = r.priceChangeNotification(before, { ...before, price: 450000 }, 'p1');
  assert.equal(down.type, 'priceChanged');
  assert.equal(down.title, 'Baisse de prix');
  assert.match(down.body, /500 000 TND → 450 000 TND/);
  assert.deepEqual(down.data, { oldPrice: 500000, newPrice: 450000 });

  assert.equal(r.priceChangeNotification(before, { ...before, price: 550000 }, 'p1').title, 'Prix modifié');
  assert.equal(r.priceChangeNotification(before, { ...before }, 'p1'), null);
  assert.equal(r.priceChangeNotification({ ...before, status: 'draft' }, { ...before, price: 1 }, 'p1'), null);
});

test('favoriteUnavailableNotification when a saved listing leaves the market', () => {
  const n = r.favoriteUnavailableNotification({ status: 'published' }, { status: 'removed', title: 'T' }, 'p');
  assert.equal(n.type, 'favoriteUpdated');
  assert.equal(r.favoriteUnavailableNotification({ status: 'published' }, { status: 'published' }, 'p'), null);
  assert.equal(r.favoriteUnavailableNotification({ status: 'pending_review' }, { status: 'rejected' }, 'p'), null);
});

test('matchesAlert: same governorate, active, not the owner', () => {
  const prop = { governorate: 'Tunis', ownerId: 'o1', agentId: null };
  assert.equal(r.matchesAlert({ preferredCity: 'tunis' }, prop, 'u1'), true);
  assert.equal(r.matchesAlert({ preferredCity: 'Sousse' }, prop, 'u1'), false);
  assert.equal(r.matchesAlert({ preferredCity: 'Tunis' }, prop, 'o1'), false);
  assert.equal(r.matchesAlert({ preferredCity: 'Tunis', status: 'suspended' }, prop, 'u1'), false);
  assert.equal(r.matchesAlert({}, prop, 'u1'), false);
});

test('messageNotification targets everyone but the sender; first message is an inquiry for the recipient', () => {
  const conversation = { participants: ['buyer', 'owner'], userId: 'buyer', recipientId: 'owner', propertyId: 'p1' };
  const first = r.messageNotification({
    message: { senderId: 'buyer', text: 'Bonjour, est-il disponible ?' },
    conversation,
    conversationId: 'p1_buyer',
    senderName: 'Sami',
    isFirstMessage: true,
  });
  assert.equal(first.length, 1);
  assert.equal(first[0].userId, 'owner');
  assert.equal(first[0].payload.type, 'newInquiry');
  assert.equal(first[0].payload.title, 'Nouveau message de Sami');
  assert.equal(first[0].payload.conversationId, 'p1_buyer');

  const reply = r.messageNotification({
    message: { senderId: 'owner', text: 'Oui' },
    conversation,
    conversationId: 'p1_buyer',
    senderName: '',
  });
  assert.equal(reply[0].userId, 'buyer');
  assert.equal(reply[0].payload.type, 'newMessage');
  assert.equal(reply[0].payload.title, 'Nouveau message de Un utilisateur');
});

test('verificationNotification on decision only', () => {
  assert.equal(r.verificationNotification({ status: 'pending' }, { status: 'approved' }, 'v').type, 'verificationApproved');
  const rej = r.verificationNotification({ status: 'pending' }, { status: 'rejected', rejectionReason: 'CIN illisible' }, 'v');
  assert.equal(rej.type, 'verificationRejected');
  assert.match(rej.body, /CIN illisible/);
  assert.equal(r.verificationNotification({ status: 'pending' }, { status: 'pending' }, 'v'), null);
  assert.equal(r.verificationNotification({ status: 'approved' }, { status: 'expired' }, 'v'), null);
});

test('validateAdminRequest', () => {
  const ok = r.validateAdminRequest({ target: 'all', title: 'Maintenance', body: 'Ce soir à 22h.' });
  assert.equal(ok.ok, true);
  assert.equal(ok.value.type, 'platformAnnouncement');
  assert.deepEqual(ok.value.audience, { kind: 'all' });

  assert.deepEqual(r.validateAdminRequest({ target: 'role:agent', title: 'Agents', body: 'Nouveauté' }).value.audience, {
    kind: 'role',
    role: 'agent',
  });
  assert.equal(r.validateAdminRequest({ target: 'role:admin', title: 'abc', body: 'abc' }).ok, false);
  assert.equal(r.validateAdminRequest({ target: 'all', title: 'ab', body: 'abc' }).ok, false);
  assert.equal(r.validateAdminRequest({ target: 'all', title: 'abc', body: 'abc', type: 'listingApproved' }).ok, false);
  assert.equal(r.validateAdminRequest({ target: 'all', title: 'abc', body: 'abc', type: 'accountWarning' }).ok, false);
  assert.equal(r.validateAdminRequest({ target: 'user:u1', title: 'abc', body: 'abc', type: 'accountWarning' }).ok, true);
  assert.equal(r.validateAdminRequest({ target: 'user:../x', title: 'abc', body: 'abc' }).ok, false);
});

test('toFcmData only carries strings', () => {
  const d = r.toFcmData({ type: 'newMessage', conversationId: 'c1', propertyId: 42 }, 'n1');
  assert.deepEqual(d, { type: 'newMessage', notificationId: 'n1', propertyId: '42', conversationId: 'c1' });
  for (const v of Object.values(d)) assert.equal(typeof v, 'string');
});

test('chunk', () => {
  assert.deepEqual(r.chunk([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
  assert.deepEqual(r.chunk([], 3), []);
});
