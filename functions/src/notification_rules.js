'use strict';

/**
 * Module 12 — Notifications: pure business rules (no Firebase imports).
 *
 * Everything here is deterministic and unit-tested (`npm test`). The Flutter
 * side mirrors the type names and preference keys in
 * `lib/features/notifications/domain/entities/` — change them together.
 */

/** Notification types stored in `notifications/{id}.type`. */
const TYPES = Object.freeze({
  // Listing moderation (spec: "Property approved / rejected").
  listingSubmitted: 'listingSubmitted',
  listingApproved: 'listingApproved',
  listingRejected: 'listingRejected',
  listingSuspended: 'listingSuspended',
  listingRestored: 'listingRestored',
  // Messaging.
  newMessage: 'newMessage',
  newInquiry: 'newInquiry',
  // Favorites.
  favoriteUpdated: 'favoriteUpdated',
  priceChanged: 'priceChanged',
  // Alerts.
  newMatchingProperty: 'newMatchingProperty',
  // Trust / account.
  verificationSubmitted: 'verificationSubmitted',
  verificationApproved: 'verificationApproved',
  verificationRejected: 'verificationRejected',
  accountWarning: 'accountWarning',
  // Admin broadcast.
  platformAnnouncement: 'platformAnnouncement',
  // Module 14: a report the user filed was closed.
  reportUpdated: 'reportUpdated',
});

/**
 * Category of each type. A category maps to ONE user preference switch;
 * `account` cannot be switched off (moderation and security must reach the user).
 */
const CATEGORY_BY_TYPE = Object.freeze({
  listingSubmitted: 'account',
  listingApproved: 'account',
  listingRejected: 'account',
  listingSuspended: 'account',
  listingRestored: 'account',
  verificationSubmitted: 'account',
  verificationApproved: 'account',
  verificationRejected: 'account',
  accountWarning: 'account',
  newMessage: 'messages',
  newInquiry: 'messages',
  favoriteUpdated: 'favorites',
  priceChanged: 'favorites',
  newMatchingProperty: 'alerts',
  platformAnnouncement: 'announcements',
  reportUpdated: 'account',
});

/** Preference key (users/{uid}.notificationPreferences) for each optional category. */
const PREFERENCE_BY_CATEGORY = Object.freeze({
  messages: 'newMessages',
  favorites: 'favoriteUpdates',
  alerts: 'propertyAlerts',
  announcements: 'announcements',
});

/** Types worth an email (spec §58: transactional email use cases). */
const EMAIL_TYPES = new Set([
  TYPES.listingApproved,
  TYPES.listingRejected,
  TYPES.listingSuspended,
  TYPES.verificationApproved,
  TYPES.verificationRejected,
  TYPES.accountWarning,
]);

/** Types an admin may broadcast from the admin panel. */
const ADMIN_SENDABLE_TYPES = new Set([TYPES.platformAnnouncement, TYPES.accountWarning]);

const DEFAULT_PREFERENCES = Object.freeze({
  newMessages: true,
  favoriteUpdates: true,
  propertyAlerts: true,
  announcements: true,
  pushNotifications: true,
  emailNotifications: false,
});

function isKnownType(type) {
  return Object.prototype.hasOwnProperty.call(CATEGORY_BY_TYPE, type);
}

function categoryOf(type) {
  return CATEGORY_BY_TYPE[type] || 'account';
}

/**
 * Normalises a raw `notificationPreferences` map. Missing keys take their
 * default; anything that is not a boolean is ignored (fail to the default).
 */
function resolvePreferences(raw) {
  const prefs = { ...DEFAULT_PREFERENCES };
  if (raw && typeof raw === 'object') {
    for (const key of Object.keys(DEFAULT_PREFERENCES)) {
      if (typeof raw[key] === 'boolean') prefs[key] = raw[key];
    }
  }
  return prefs;
}

/**
 * Which channels a notification of `type` goes to for a user with `rawPrefs`.
 * - inApp: always, unless the user switched the (optional) category off.
 * - push : inApp AND the push master switch.
 * - email: inApp AND the email master switch AND the type is email-worthy.
 *   An account warning is a security notice: it is always emailed.
 */
function channelsFor(type, rawPrefs) {
  const prefs = resolvePreferences(rawPrefs);
  const category = categoryOf(type);
  const prefKey = PREFERENCE_BY_CATEGORY[category];
  const inApp = prefKey ? prefs[prefKey] !== false : true;
  return {
    inApp,
    push: inApp && prefs.pushNotifications,
    email: inApp && EMAIL_TYPES.has(type) && (prefs.emailNotifications || type === TYPES.accountWarning),
  };
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

/** "1 250 000 TND" (French grouping with a plain space, no decimals). */
function formatPrice(price, currency = 'TND') {
  const n = Number(price);
  if (!Number.isFinite(n)) return '';
  const grouped = Math.round(n)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  return `${grouped} ${currency || 'TND'}`;
}

function truncate(text, max) {
  const s = String(text || '').replace(/\s+/g, ' ').trim();
  return s.length <= max ? s : `${s.slice(0, max - 1).trimEnd()}…`;
}

function listingLabel(property) {
  const title = truncate(property && property.title, 60);
  return title ? `« ${title} »` : 'Votre annonce';
}

// ---------------------------------------------------------------------------
// Builders: event -> notification payload(s). They return null when the event
// does not deserve a notification.
// Payload shape: { type, title, body, propertyId?, conversationId?, data? }
// ---------------------------------------------------------------------------

/**
 * Moderation outcome for the listing's owner (spec §25: "Owner notified").
 * Only transitions decided by someone else are notified.
 */
function listingStatusNotification(before, after, propertyId) {
  const from = before && before.status;
  const to = after && after.status;
  if (!from || !to || from === to) return null;
  const label = listingLabel(after);
  const reason = truncate(after.rejectionReason || after.moderationReason || '', 200);

  if (from === 'pending_review' && to === 'published') {
    return {
      type: TYPES.listingApproved,
      title: 'Annonce approuvée',
      body: `${label} est maintenant en ligne.`,
      propertyId,
    };
  }
  if (from === 'pending_review' && to === 'rejected') {
    return {
      type: TYPES.listingRejected,
      title: 'Annonce refusée',
      body: reason
        ? `${label} a été refusée : ${reason}`
        : `${label} a été refusée. Modifiez-la puis soumettez-la à nouveau.`,
      propertyId,
    };
  }
  if (from === 'published' && to === 'suspended') {
    return {
      type: TYPES.listingSuspended,
      title: 'Annonce suspendue',
      body: reason ? `${label} a été suspendue : ${reason}` : `${label} a été suspendue par la modération.`,
      propertyId,
    };
  }
  if (from === 'suspended' && to === 'published') {
    return {
      type: TYPES.listingRestored,
      title: 'Annonce rétablie',
      body: `${label} est de nouveau en ligne.`,
      propertyId,
    };
  }
  return null;
}

/** Price change on a published listing, for users who saved it. */
function priceChangeNotification(before, after, propertyId) {
  if (!before || !after) return null;
  if (after.status !== 'published' || before.status !== 'published') return null;
  const oldPrice = Number(before.price);
  const newPrice = Number(after.price);
  if (!Number.isFinite(oldPrice) || !Number.isFinite(newPrice) || oldPrice === newPrice) return null;

  const down = newPrice < oldPrice;
  const currency = after.currency || 'TND';
  return {
    type: TYPES.priceChanged,
    title: down ? 'Baisse de prix' : 'Prix modifié',
    body: `${listingLabel(after)} : ${formatPrice(oldPrice, currency)} → ${formatPrice(newPrice, currency)}`,
    propertyId,
    data: { oldPrice, newPrice },
  };
}

/** A saved listing left the marketplace (sold, removed, expired, suspended). */
function favoriteUnavailableNotification(before, after, propertyId) {
  if (!before || !after) return null;
  if (before.status !== 'published' || after.status === 'published') return null;
  if (!['removed', 'expired', 'suspended'].includes(after.status)) return null;
  return {
    type: TYPES.favoriteUpdated,
    title: 'Favori indisponible',
    body: `${listingLabel(after)} n'est plus disponible.`,
    propertyId,
  };
}

/**
 * New listing alert (spec: "New matching property"). A user matches when
 * their preferred governorate is the listing's governorate and the listing is
 * not theirs.
 */
function matchesAlert(user, property, userId) {
  if (!user || !property) return false;
  if (user.status && user.status !== 'active') return false;
  if (userId && (userId === property.ownerId || userId === property.agentId)) return false;
  const pref = String(user.preferredCity || '').trim().toLowerCase();
  const gov = String(property.governorate || '').trim().toLowerCase();
  return pref.length > 0 && pref === gov;
}

function newMatchingPropertyNotification(property, propertyId) {
  const place = [property.city, property.governorate].filter(Boolean).join(', ');
  const price = formatPrice(property.price, property.currency);
  return {
    type: TYPES.newMatchingProperty,
    title: `Nouvelle annonce à ${property.governorate || 'proximité'}`,
    body: [truncate(property.title, 60), place, price].filter(Boolean).join(' · '),
    propertyId,
  };
}

/** Message in a conversation, for every participant except the sender. */
function messageNotification({ message, conversation, conversationId, senderName, isFirstMessage = false }) {
  if (!message || !conversation) return [];
  const senderId = message.senderId;
  const participants = Array.isArray(conversation.participants) ? conversation.participants : [];
  const name = truncate(senderName, 40) || 'Un utilisateur';
  return participants
    .filter((uid) => uid && uid !== senderId)
    .map((uid) => ({
      userId: uid,
      payload: {
        // The first message of a thread, received by the owner/agent, is an inquiry.
        type: isFirstMessage && uid === conversation.recipientId ? TYPES.newInquiry : TYPES.newMessage,
        title: `Nouveau message de ${name}`,
        body: truncate(message.text, 120),
        conversationId,
        propertyId: conversation.propertyId || undefined,
      },
    }));
}

/** Decision on a verification request (pending -> approved / rejected). */
function verificationNotification(before, after, verificationId) {
  if (!before || !after || before.status === after.status) return null;
  if (before.status !== 'pending') return null;
  const reason = truncate(after.rejectionReason || '', 200);
  if (after.status === 'approved') {
    return {
      type: TYPES.verificationApproved,
      title: 'Vérification approuvée',
      body: 'Votre compte est vérifié. Le badge apparaît désormais sur votre profil.',
      data: { verificationId, targetType: after.targetType || 'user' },
    };
  }
  if (after.status === 'rejected') {
    return {
      type: TYPES.verificationRejected,
      title: 'Vérification refusée',
      body: reason
        ? `Votre demande a été refusée : ${reason}`
        : 'Votre demande a été refusée. Corrigez vos documents puis soumettez-la à nouveau.',
      data: { verificationId, targetType: after.targetType || 'user' },
    };
  }
  return null;
}

/**
 * Validates the input of the admin `sendAdminNotification` callable.
 * Returns { ok: true, value } or { ok: false, error }.
 * target: 'all' | 'role:<user|owner|agent>' | 'user:<uid>'
 */
function validateAdminRequest(input) {
  const d = input || {};
  const type = d.type || TYPES.platformAnnouncement;
  if (!ADMIN_SENDABLE_TYPES.has(type)) return { ok: false, error: 'Type de notification non autorisé.' };

  const title = typeof d.title === 'string' ? d.title.trim() : '';
  const body = typeof d.body === 'string' ? d.body.trim() : '';
  if (title.length < 3 || title.length > 80) return { ok: false, error: 'Le titre doit contenir 3 à 80 caractères.' };
  if (body.length < 3 || body.length > 500) return { ok: false, error: 'Le message doit contenir 3 à 500 caractères.' };

  const target = typeof d.target === 'string' ? d.target.trim() : '';
  let audience;
  if (target === 'all') {
    audience = { kind: 'all' };
  } else if (/^role:(user|owner|agent)$/.test(target)) {
    audience = { kind: 'role', role: target.slice(5) };
  } else if (/^user:[A-Za-z0-9_-]{1,128}$/.test(target)) {
    audience = { kind: 'user', userId: target.slice(5) };
  } else {
    return { ok: false, error: 'Destinataire invalide.' };
  }
  // A warning concerns one account; it is never broadcast.
  if (type === TYPES.accountWarning && audience.kind !== 'user') {
    return { ok: false, error: 'Un avertissement ne peut viser qu’un seul utilisateur.' };
  }
  return { ok: true, value: { type, title, body, audience } };
}

/** FCM `data` values must be strings. */
function toFcmData(payload, notificationId) {
  const data = { type: payload.type, notificationId: String(notificationId || '') };
  if (payload.propertyId) data.propertyId = String(payload.propertyId);
  if (payload.conversationId) data.conversationId = String(payload.conversationId);
  return data;
}

function chunk(list, size) {
  const out = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
}

module.exports = {
  TYPES,
  CATEGORY_BY_TYPE,
  PREFERENCE_BY_CATEGORY,
  EMAIL_TYPES,
  DEFAULT_PREFERENCES,
  isKnownType,
  categoryOf,
  resolvePreferences,
  channelsFor,
  formatPrice,
  truncate,
  listingStatusNotification,
  priceChangeNotification,
  favoriteUnavailableNotification,
  matchesAlert,
  newMatchingPropertyNotification,
  messageNotification,
  verificationNotification,
  validateAdminRequest,
  toFcmData,
  chunk,
};
