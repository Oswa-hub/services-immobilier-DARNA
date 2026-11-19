# Modules 15 – 17 — Admin, Content, Platform Settings

Works on the **Spark plan**: no Cloud Functions needed. Every admin write is
checked by `firestore.rules` (`isAdmin()` = `users/{uid}.role == 'admin'`) and
logged in `audit_logs` in the same batch / transaction.

## Module 15 — Admin panel (`lib/features/admin/`)

Admins land on `/admin/dashboard` after login. Layout: navigation rail (wide) or drawer (phone).

| Route | Page | What it does |
|---|---|---|
| `/admin/dashboard` | KPIs (Firestore `count()`), listings to approve, recent sign-ups, last actions | |
| `/admin/users` | search, filter by status / role | suspend · restore · ban · delete (soft, status `deleted`) · change role, with reason |
| `/admin/properties` | moderation queue by default, search, filter | approve · reject · suspend · restore · remove (transaction: refused if the status changed meanwhile) |
| `/admin/verification` | Module 13 queue (unchanged) | |
| `/admin/reports` | placeholder until Module 14 creates `reports` | |
| `/admin/notifications` | announcement to all / one role, warning to one user | client fan-out to `notifications` |
| `/admin/content` | Module 16 | |
| `/admin/analytics` | growth (6 months), by governorate / type / status, average price, views, favorites | computed on the latest 1000 docs |
| `/admin/settings` | Module 17 | |
| `/admin/audit-logs` | latest 100 entries, filterable | |

Safety: an admin can never change their own role or status (UI + rules).
On approval: `publishedAt` (first time only), `expiresAt = now + listingExpirationDays`.
Owner notifications (approved / refused / suspended / restored) are written by the admin app
while `serverNotifications` is off; turn it on only after deploying the Module 12 Functions (Blaze).

The old in-memory demo panel (`admin_service.dart`, …) was removed: it was not routed anywhere.

## Module 16 — Content (`lib/features/content/`)

`catalog/{key}` = `{ items: [{id, label, active, order}], updatedAt, updatedBy }`, public read, admin write.

| Key | Editable |
|---|---|
| `property_types`, `amenities` | rename, hide, reorder (ids are code enums stored on listings) |
| `cities`, `areas`, `tags`, `verification_categories`, `report_reasons` | add, rename, hide, reorder, delete |

Defaults apply until a list is saved. Used today: amenities in the publish form (order, labels,
hidden ones removed), property-type labels in the admin. `report_reasons` is ready for Module 14.

## Module 17 — Platform settings (`lib/features/settings/`)

`settings/platform`, public read, admin write, every field validated by the rules:
max photos (1–10), max photo size (1–5 MB), listing duration (7–365 days), listing review,
announcements on/off, `serverNotifications`, currencies (TND/EUR/USD), terms, privacy, contact.

Used by: the publish form (photo count and size), approval (expiry), admin announcements,
public pages `/legal/terms`, `/legal/privacy`, `/contact` (linked from Profile, open to guests).

## Deploy (Spark is enough)

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

New indexes: `users (status, createdAt desc)`, `properties (status, createdAt desc)`.

Make an admin: Firebase console → Firestore → `users/{uid}` → set `role` to `admin`.

## Tests

`flutter test test/features/admin` — policy, analytics, catalog editor, settings validation,
admin actions, catalog editor widget, legal pages.
