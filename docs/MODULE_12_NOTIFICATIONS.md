# Module 12 — Notifications

Spec: ImmoFind study §32–33, §58–59. In-app notification center, push (FCM) and
transactional email, all driven by server-side events.

```
Firestore event ──► Cloud Function (functions/src/handlers.js)
                        │
                        ▼
              Notification Service (functions/src/notifier.js)
                ├─ notifications/{id}          in-app center (always first)
                ├─ FCM push                    users/{uid}/devices/{token}
                └─ mail/{id}                   "Trigger Email" extension format
```

Clients never create notifications (rules deny it); they read, mark read and delete their own.

## Events → notifications

| Event | Type | Recipient | Category (preference) |
|---|---|---|---|
| Listing created (`pending_review`) | `listingSubmitted` | owner | account (always) |
| `pending_review → published` | `listingApproved` | owner + agent | account |
| `pending_review → rejected` | `listingRejected` (+ `rejectionReason`) | owner + agent | account |
| `published → suspended` / `suspended → published` | `listingSuspended` / `listingRestored` | owner + agent | account |
| Price change on a published listing | `priceChanged` | users who saved it | favorites (`favoriteUpdates`) |
| Saved listing removed / expired / suspended | `favoriteUpdated` | users who saved it | favorites |
| First publication | `newMatchingProperty` | users whose `preferredCity` = listing governorate | alerts (`propertyAlerts`) |
| New message | `newMessage` (first one to the owner: `newInquiry`) | other participant | messages (`newMessages`) |
| Verification `pending → approved/rejected` | `verificationApproved` / `verificationRejected` | requester (or listing owner) | account |
| Admin callable `sendAdminNotification` | `platformAnnouncement` / `accountWarning` | all / role / one user | announcements / account |

Channels per user (`users/{uid}.notificationPreferences`): a switched-off category
gets nothing; push needs `pushNotifications`; email needs `emailNotifications` and an
email-worthy type (approved/rejected/suspended, verification result). An account
warning is always emailed.

Triggers are idempotent (the event id is part of the notification id), so a retried
function never duplicates a notification or a push.

## Flutter

`lib/features/notifications/`

- `domain/` — `AppNotification`, `NotificationType` (mirrors the server), `NotificationPreferences`,
  repository contract, navigation (`routeForNotification`) and day grouping (pure, tested).
- `data/` — Firestore data source, repository (errors → `NotificationFailure`), FCM wrapper.
- `presentation/` — `/notifications` center (Toutes / Non lues, grouped by day, tap = read + open,
  swipe = delete, "Tout marquer comme lu"), `/notifications/settings`, `NotificationBell`
  (live unread badge in the Home header), push registration.
- `lib/app/notification_bootstrap.dart` — registers the device token for the signed-in user
  and opens the right page when a push is tapped.

Push works on Android / iOS / macOS. On web the switch is disabled (needs a service worker + VAPID key).

## Deploy

```bash
flutter pub get                     # adds firebase_messaging
cd functions && npm install && npm test && cd ..
firebase deploy --only firestore:rules,firestore:indexes,functions
```

- Cloud Functions need the Blaze plan.
- Firestore triggers must run in the database's region: set `FUNCTIONS_REGION=<region>` in
  `functions/.env` if it is not `us-central1`.
- Email: install the **Trigger Email from Firestore** extension on the `mail` collection
  (or replace `queueEmail` in `notifier.js` with another provider).
- iOS push: upload the APNs key in Firebase console → Project settings → Cloud Messaging,
  and enable the Push Notifications + Background Modes (remote notifications) capabilities in Xcode.

## Tests

- `cd functions && npm test` — rules, notifier (prefs, push, dead tokens, email, dedupe) and every trigger.
- `flutter test test/features/notifications` — domain, providers, push registrar, center widgets.
