# Module 11 — Messaging

Based on Oussama's Module 11 work (built on the 12 November code), ported onto
the current `test` branch with the DARNA design, in French, and merged with
Module 14 (report / block) in the chat screen.

## What the user gets

- **Messages tab** (`/messages`, bottom navigation): every conversation of the
  signed-in user, as a buyer/renter or as an owner/agent, newest first.
  Loading, empty, error and offline states. Guests see the sign-in panel.
- **Unread badge** on the Messages tab (number of conversations with a newer
  message from the other side).
- **Chat** (`/chat/:conversationId`, unchanged so agent pages and notifications
  keep working):
  - older messages load by pages of 30 while scrolling up;
  - day separators (Aujourd'hui, Hier, lun. 09 nov.);
  - my messages show Envoi en cours / Envoyé / Vu;
  - a message written offline stays queued and is delivered when the
    connection returns (the user is told);
  - opening the chat marks it as read;
  - Module 14: report the user, report a message (long-press), block / unblock.
- Profile > Messages opens the tab.

## Data

`conversations/{propertyId}_{userId}` (one thread per user per listing),
`conversations/{id}/messages/{id}`. New field: `recipientName` (owner's name,
only when no agent manages the listing). Threads are created in a transaction,
so two quick taps never create two threads.

## Firestore

- Rule change: `conversations` **list** also accepts `uid in participants`, so
  the Messages tab query `where('participants', arrayContains: uid)` is allowed.
- Index already deployed: `participants CONTAINS, lastMessageAt DESC`.

Deploy: `firebase deploy --only firestore:rules`

## Not done (Spark plan)

No notification is created for a new message: the Cloud Function is not
deployed and the rules do not let a user write a notification for someone
else. The unread badge in the app works without it.
