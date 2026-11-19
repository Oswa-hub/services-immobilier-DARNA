# Module 14 — Reports & Safety

Spec §36 and §41. Works on the Spark plan (no Cloud Functions).

## Users

| Where | What |
|---|---|
| Property details (flag in the app bar) | report the listing (not your own) |
| Public agent profile (flag) | report the professional |
| Chat → ⋮ menu | report the other person, block / unblock them |
| Chat → long-press a received message | report that message |
| Profile → Signalements et sécurité (`/reports`) | follow my reports and the moderator's answer; unblock people |

Reasons come from the admin list *Contenu → Motifs de signalement* (Module 16):
Fraude, Fausse annonce, Informations incorrectes, Arnaque, Contenu offensant,
Annonce en double, Prix erroné, Activité suspecte, Autre ("Autre" needs details).

One report per person and target: id `{reporterId}_{targetType}_{targetId}`; a second
attempt says "Vous avez déjà signalé cet élément". The reported person never sees who reported.
Suspended / banned accounts cannot report.

**Blocking**: `users/{me}/blocked/{otherId}`. The rules refuse a message from someone the
recipient blocked; the chat shows a banner with "Débloquer" for the blocker.

## Admin (`/admin/reports`)

Lifecycle `open → investigating → resolved | rejected` (rules enforce it).

- Queue "À traiter" = open + investigating, sorted: priority, then oldest first.
- Priority: Fraude / Arnaque / Fausse annonce = high; Activité suspecte = high on a person,
  medium on a listing; Contenu offensant / Informations incorrectes = medium; others low.
  A target reported by 2 people goes up one level, by 3+ becomes high ("signalé N fois").
- Actions: assign to me, start investigation, resolve with a measure (none, suspend / remove the
  listing, suspend / ban the account), reject. A decision note (≥ 5 characters) is required and
  sent to the reporter (in-app notification `reportUpdated`, unless `serverNotifications` is on).
- The measure is applied first through the Module 15 actions (audited); if it fails the report stays open.
- Dashboard: "Signalements ouverts" KPI and "Signalements récents".

## Deploy

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

New indexes: `reports (reporterId, createdAt desc)`, `reports (status, createdAt desc)`.

## Tests

`flutter test test/features/reports`
