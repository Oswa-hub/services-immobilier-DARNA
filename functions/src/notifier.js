'use strict';

const { channelsFor, toFcmData, chunk, isKnownType } = require('./notification_rules');

/** FCM error codes meaning the token is dead and must be removed. */
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/**
 * Notification Service (spec §33): ONE entry point for every event.
 *
 *   Event -> notifyUser() -> in-app (Firestore) + FCM push + email (queued)
 *
 * Dependencies are injected so the service is unit-tested with fakes:
 *   db         firebase-admin Firestore
 *   messaging  firebase-admin Messaging (sendEachForMulticast)
 *   now        () => Date | FieldValue (server timestamp in production)
 *   logger     { info, warn, error }
 */
function createNotifier({ db, messaging, now, logger = console }) {
  /**
   * Sends one notification to one user, honouring their preferences.
   * Never throws for a delivery problem: a failed push or email must not
   * lose the in-app notification (it is written first).
   *
   * `dedupeKey` (e.g. the trigger's event id) makes a retried trigger a no-op:
   * the document id is derived from it and created only once.
   *
   * @returns {Promise<{id: string|null, channels: object, duplicate?: boolean}>}
   */
  async function notifyUser(userId, payload, { userData, dedupeKey } = {}) {
    if (!userId || !payload || !isKnownType(payload.type)) {
      logger.warn('notifyUser: ignored invalid call', { userId, type: payload && payload.type });
      return { id: null, channels: { inApp: false, push: false, email: false } };
    }

    let user = userData;
    if (!user) {
      const snap = await db.collection('users').doc(userId).get();
      if (!snap.exists) return { id: null, channels: { inApp: false, push: false, email: false } };
      user = snap.data() || {};
    }
    // Deleted / banned accounts receive nothing.
    if (user.status === 'deleted' || user.status === 'banned') {
      return { id: null, channels: { inApp: false, push: false, email: false } };
    }

    const channels = channelsFor(payload.type, user.notificationPreferences);
    if (!channels.inApp) return { id: null, channels };

    // 1. In-app (history, notification center). Shape mirrors the Flutter mapper.
    const col = db.collection('notifications');
    const ref = dedupeKey ? col.doc(safeId(`${dedupeKey}_${userId}`)) : col.doc();
    const doc = {
      userId,
      type: payload.type,
      title: payload.title,
      body: payload.body || '',
      read: false,
      readAt: null,
      createdAt: now(),
    };
    if (payload.propertyId) doc.propertyId = payload.propertyId;
    if (payload.conversationId) doc.conversationId = payload.conversationId;
    if (payload.data && typeof payload.data === 'object') doc.data = payload.data;
    if (dedupeKey) {
      try {
        await ref.create(doc);
      } catch (e) {
        if (e && (e.code === 6 || e.code === 'already-exists')) return { id: null, channels, duplicate: true };
        throw e;
      }
    } else {
      await ref.set(doc);
    }

    // 2. Push + 3. email, independently.
    if (channels.push) {
      await sendPush(userId, payload, ref.id).catch((e) => logger.error('push failed', { userId, error: e.message }));
    }
    if (channels.email && user.email) {
      await queueEmail(user.email, payload).catch((e) => logger.error('email failed', { userId, error: e.message }));
    }
    return { id: ref.id, channels };
  }

  async function sendPush(userId, payload, notificationId) {
    const devices = await db.collection('users').doc(userId).collection('devices').get();
    const tokens = devices.docs.map((d) => d.get('token')).filter((t) => typeof t === 'string' && t.length > 0);
    if (tokens.length === 0) return { sent: 0, removed: 0 };

    let sent = 0;
    const dead = [];
    for (const batch of chunk(tokens, 500)) {
      const res = await messaging.sendEachForMulticast({
        tokens: batch,
        notification: { title: payload.title, body: payload.body || '' },
        data: toFcmData(payload, notificationId),
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      });
      sent += res.successCount;
      res.responses.forEach((r, i) => {
        if (!r.success && r.error && DEAD_TOKEN_CODES.has(r.error.code)) dead.push(batch[i]);
      });
    }
    // Remove tokens FCM rejected so we stop sending to uninstalled apps.
    const deviceCol = db.collection('users').doc(userId).collection('devices');
    await Promise.all(
      devices.docs.filter((d) => dead.includes(d.get('token'))).map((d) => deviceCol.doc(d.id).delete()),
    );
    return { sent, removed: dead.length };
  }

  /**
   * Email is abstracted behind the `mail` collection (spec §58), the format of
   * the "Trigger Email from Firestore" Firebase extension. Swapping provider
   * means changing only this function.
   */
  async function queueEmail(to, payload) {
    const text = `${payload.body || ''}\n\n— L'équipe ImmoFind`;
    await db.collection('mail').add({
      to,
      message: {
        subject: `ImmoFind — ${payload.title}`,
        text,
        html: `<p>${escapeHtml(payload.body || '')}</p><p>— L'équipe ImmoFind</p>`,
      },
      notificationType: payload.type,
      createdAt: now(),
    });
  }

  /** Same payload to many users (fan-out), limited concurrency. */
  async function notifyMany(userIds, payload, { concurrency = 20, dedupeKey } = {}) {
    const unique = [...new Set(userIds.filter(Boolean))];
    let delivered = 0;
    for (const group of chunk(unique, concurrency)) {
      const results = await Promise.all(
        group.map((uid) =>
          notifyUser(uid, payload, { dedupeKey }).catch((e) => {
            logger.error('notifyMany: user failed', { uid, error: e.message });
            return { id: null };
          }),
        ),
      );
      delivered += results.filter((r) => r.id).length;
    }
    return delivered;
  }

  return { notifyUser, notifyMany, sendPush, queueEmail };
}

/** Firestore ids cannot contain '/' and are limited to 1500 bytes. */
function safeId(raw) {
  return String(raw).replace(/\//g, '_').slice(0, 1400);
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

module.exports = { createNotifier, DEAD_TOKEN_CODES, escapeHtml, safeId };
