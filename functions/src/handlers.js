'use strict';

const rules = require('./notification_rules');

/**
 * Event handlers (Module 12). Each one takes plain data + injected deps so it
 * is unit-tested without the emulator; `index.js` only wires them to triggers.
 *
 * deps = { db, notifier, logger }
 */

/** properties/{propertyId} created -> owner gets "listing submitted". */
async function onPropertyCreated(deps, { propertyId, after, eventId }) {
  if (!after || after.status !== 'pending_review' || !after.ownerId) return 0;
  const res = await deps.notifier.notifyUser(
    after.ownerId,
    {
      type: rules.TYPES.listingSubmitted,
      title: 'Annonce envoyée',
      body: `« ${rules.truncate(after.title, 60) || 'Votre annonce'} » est en cours de vérification.`,
      propertyId,
    },
    { dedupeKey: eventId },
  );
  return res.id ? 1 : 0;
}

/**
 * properties/{propertyId} updated:
 *  1. moderation outcome -> owner (and the agent managing it)
 *  2. price change / no longer available -> users who saved it
 *  3. first publication -> users whose preferred governorate matches
 */
async function onPropertyUpdated(deps, { propertyId, before, after, eventId }) {
  const { db, notifier } = deps;
  if (!before || !after) return { owner: 0, favorites: 0, alerts: 0 };
  const counts = { owner: 0, favorites: 0, alerts: 0 };

  // 1. Owner / agent.
  const status = rules.listingStatusNotification(before, after, propertyId);
  if (status) {
    const managers = [after.ownerId, after.agentId].filter(Boolean);
    counts.owner = await notifier.notifyMany(managers, status, { dedupeKey: `${eventId}_status` });
  }

  // 2. Favorites.
  const favPayload =
    rules.priceChangeNotification(before, after, propertyId) ||
    rules.favoriteUnavailableNotification(before, after, propertyId);
  if (favPayload) {
    const favs = await db.collection('favorites').where('propertyId', '==', propertyId).get();
    const userIds = favs.docs
      .map((d) => d.get('userId'))
      .filter((uid) => uid && uid !== after.ownerId && uid !== after.agentId);
    counts.favorites = await notifier.notifyMany(userIds, favPayload, { dedupeKey: `${eventId}_fav` });
  }

  // 3. New-listing alerts: only the FIRST publication (not a restore / re-approval).
  const firstPublication =
    before.status !== 'published' && after.status === 'published' && before.publishedAt == null;
  if (firstPublication && after.governorate) {
    const snap = await db
      .collection('users')
      .where('preferredCity', '==', after.governorate)
      .limit(500)
      .get();
    const userIds = snap.docs.filter((d) => rules.matchesAlert(d.data(), after, d.id)).map((d) => d.id);
    if (userIds.length > 0) {
      counts.alerts = await notifier.notifyMany(
        userIds,
        rules.newMatchingPropertyNotification(after, propertyId),
        { dedupeKey: `${eventId}_alert` },
      );
    }
  }
  return counts;
}

/** conversations/{cid}/messages/{mid} created -> the other participant(s). */
async function onMessageCreated(deps, { conversationId, message, eventId }) {
  const { db, notifier } = deps;
  if (!message || !message.senderId) return 0;

  const convoRef = db.collection('conversations').doc(conversationId);
  const [convoSnap, senderSnap, firstTwo] = await Promise.all([
    convoRef.get(),
    db.collection('users').doc(message.senderId).get(),
    convoRef.collection('messages').limit(2).get(),
  ]);
  if (!convoSnap.exists) return 0;

  const sender = senderSnap.exists ? senderSnap.data() || {} : {};
  const targets = rules.messageNotification({
    message,
    conversation: convoSnap.data(),
    conversationId,
    senderName: sender.name,
    isFirstMessage: firstTwo.size <= 1,
  });
  let delivered = 0;
  for (const t of targets) {
    const res = await notifier.notifyUser(t.userId, t.payload, { dedupeKey: eventId });
    if (res.id) delivered++;
  }
  return delivered;
}

/** verifications/{id} updated -> decision to the requester. */
async function onVerificationUpdated(deps, { verificationId, before, after, eventId }) {
  const payload = rules.verificationNotification(before, after, verificationId);
  if (!payload || !after.targetId) return 0;
  // Property verifications notify the listing's owner.
  let userId = after.targetId;
  if (after.targetType === 'property') {
    const prop = await deps.db.collection('properties').doc(after.targetId).get();
    if (!prop.exists) return 0;
    userId = prop.get('ownerId');
    payload.propertyId = after.targetId;
  }
  const res = await deps.notifier.notifyUser(userId, payload, { dedupeKey: eventId });
  return res.id ? 1 : 0;
}

/**
 * users/{uid}/devices/{deviceId} created. A device token belongs to ONE
 * account: when another user signs in on the same phone, the token is removed
 * from the previous account so it stops receiving their pushes.
 */
async function onDeviceRegistered(deps, { userId, token }) {
  if (!token) return 0;
  const snap = await deps.db.collectionGroup('devices').where('token', '==', token).get();
  const stale = snap.docs.filter((d) => {
    const owner = d.ref.parent.parent;
    return owner && owner.id !== userId;
  });
  await Promise.all(stale.map((d) => d.ref.delete()));
  return stale.length;
}

/**
 * Admin broadcast (callable). `caller` = { uid } from the auth context.
 * Throws { code, message } errors that index.js converts to HttpsError.
 */
async function sendAdminNotification(deps, { caller, input, now }) {
  const { db, notifier } = deps;
  if (!caller || !caller.uid) throw { code: 'unauthenticated', message: 'Connexion requise.' };

  const adminSnap = await db.collection('users').doc(caller.uid).get();
  if (!adminSnap.exists || adminSnap.get('role') !== 'admin' || adminSnap.get('status') === 'banned') {
    throw { code: 'permission-denied', message: 'Réservé aux administrateurs.' };
  }

  const check = rules.validateAdminRequest(input);
  if (!check.ok) throw { code: 'invalid-argument', message: check.error };
  const { type, title, body, audience } = check.value;

  let userIds;
  if (audience.kind === 'user') {
    userIds = [audience.userId];
  } else {
    let q = db.collection('users').where('status', '==', 'active');
    if (audience.kind === 'role') q = q.where('role', '==', audience.role);
    const snap = await q.get();
    userIds = snap.docs.map((d) => d.id);
  }

  const delivered = await notifier.notifyMany(userIds, { type, title, body });

  await db.collection('audit_logs').add({
    adminId: caller.uid,
    action: 'notification.send',
    targetType: 'notification',
    targetId: audience.kind === 'user' ? audience.userId : audience.kind === 'role' ? `role:${audience.role}` : 'all',
    details: { type, title, recipients: userIds.length, delivered },
    timestamp: now(),
  });
  return { recipients: userIds.length, delivered };
}

module.exports = {
  onPropertyCreated,
  onPropertyUpdated,
  onMessageCreated,
  onVerificationUpdated,
  onDeviceRegistered,
  sendAdminNotification,
};
