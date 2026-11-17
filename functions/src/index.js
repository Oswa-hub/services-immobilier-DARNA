'use strict';

/**
 * ImmoFind Cloud Functions — Module 12: Notifications.
 *
 *   Firestore event ──► handler ──► Notification Service (notifier.js)
 *                                     ├─ notifications/{id}   (in-app center)
 *                                     ├─ FCM push             (users/{uid}/devices)
 *                                     └─ mail/{id}            (Trigger Email extension)
 *
 * Clients never write `notifications`: Firestore rules deny it.
 *
 * Region: Firestore triggers must run in the database's region. Set it with
 * FUNCTIONS_REGION in functions/.env (default: us-central1).
 */

const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

const { createNotifier } = require('./notifier');
const handlers = require('./handlers');

initializeApp();

const REGION = process.env.FUNCTIONS_REGION || 'us-central1';
setGlobalOptions({ region: REGION, maxInstances: 10 });

const db = getFirestore();
const now = () => FieldValue.serverTimestamp();
const notifier = createNotifier({ db, messaging: getMessaging(), now, logger });
const deps = { db, notifier, logger };

exports.notifyOnPropertyCreated = onDocumentCreated('properties/{propertyId}', (event) =>
  handlers.onPropertyCreated(deps, {
    propertyId: event.params.propertyId,
    after: event.data && event.data.data(),
    eventId: event.id,
  }),
);

exports.notifyOnPropertyUpdated = onDocumentUpdated('properties/{propertyId}', (event) =>
  handlers.onPropertyUpdated(deps, {
    propertyId: event.params.propertyId,
    before: event.data.before.data(),
    after: event.data.after.data(),
    eventId: event.id,
  }),
);

exports.notifyOnMessageCreated = onDocumentCreated('conversations/{conversationId}/messages/{messageId}', (event) =>
  handlers.onMessageCreated(deps, {
    conversationId: event.params.conversationId,
    message: event.data && event.data.data(),
    eventId: event.id,
  }),
);

exports.notifyOnVerificationUpdated = onDocumentUpdated('verifications/{verificationId}', (event) =>
  handlers.onVerificationUpdated(deps, {
    verificationId: event.params.verificationId,
    before: event.data.before.data(),
    after: event.data.after.data(),
    eventId: event.id,
  }),
);

exports.dedupeDeviceToken = onDocumentCreated('users/{userId}/devices/{deviceId}', (event) =>
  handlers.onDeviceRegistered(deps, {
    userId: event.params.userId,
    token: event.data && event.data.get('token'),
  }),
);

/** Admin panel: platform announcement / account warning. */
exports.sendAdminNotification = onCall(async (request) => {
  try {
    return await handlers.sendAdminNotification(deps, {
      caller: request.auth ? { uid: request.auth.uid } : null,
      input: request.data,
      now,
    });
  } catch (e) {
    if (e && typeof e.code === 'string' && !(e instanceof Error)) throw new HttpsError(e.code, e.message);
    logger.error('sendAdminNotification failed', e);
    throw new HttpsError('internal', 'Envoi impossible. Réessayez plus tard.');
  }
});
