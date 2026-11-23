import {
  collection, doc, limit, onSnapshot, orderBy, query, runTransaction, serverTimestamp, updateDoc, where, writeBatch,
} from 'firebase/firestore';

import { db } from './firebase';
import { toDate } from './format';
import type { ChatMessage, Conversation, Property } from './types';

export const MAX_MESSAGE = 2000;

/** Conversation id = {propertyId}_{userId} (rules + Flutter ConversationRepository). */
export const conversationId = (propertyId: string, uid: string) => `${propertyId}_${uid}`;
export const recipientOf = (p: Property) => (p.agentId ? p.agentId : p.ownerId);

function toConversation(id: string, d: Record<string, any>): Conversation | null {
  if (!d.userId || !d.recipientId || !d.propertyId) return null;
  const read: Record<string, Date> = {};
  for (const [k, v] of Object.entries(d.lastReadAt ?? {})) {
    const date = toDate(v);
    if (date) read[k] = date;
  }
  return {
    id,
    participants: Array.isArray(d.participants) ? d.participants : [d.userId, d.recipientId],
    userId: d.userId,
    recipientId: d.recipientId,
    propertyId: d.propertyId,
    userName: d.userName ?? null,
    recipientName: d.recipientName ?? null,
    propertyTitle: d.propertyTitle ?? null,
    propertyImage: d.propertyImage ?? null,
    lastMessage: d.lastMessage ?? null,
    lastMessageAt: toDate(d.lastMessageAt),
    lastSenderId: d.lastSenderId ?? null,
    lastReadAt: read,
  };
}

/** Opens the thread with the listing's owner / agent, creating it the first time. */
export async function openOrCreate(p: Property, me: { uid: string; name: string }): Promise<string> {
  const recipient = recipientOf(p);
  if (recipient === me.uid) throw new Error('C’est votre propre annonce.');
  const ref = doc(db, 'conversations', conversationId(p.id, me.uid));
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists()) return;
    tx.set(ref, {
      participants: [me.uid, recipient],
      userId: me.uid,
      recipientId: recipient,
      propertyId: p.id,
      userName: me.name || null,
      recipientName: p.agentId ? null : p.ownerName ?? null,
      propertyTitle: p.title,
      propertyImage: p.images[0] ?? null,
      lastMessage: null,
      lastMessageAt: null,
      lastSenderId: null,
      lastReadAt: {},
      messageCount: 0,
      createdAt: serverTimestamp(),
    });
  });
  return ref.id;
}

export function watchConversations(uid: string, onData: (items: Conversation[]) => void, onError: (e: unknown) => void) {
  const q = query(collection(db, 'conversations'), where('participants', 'array-contains', uid),
    orderBy('lastMessageAt', 'desc'), limit(50));
  return onSnapshot(q, (snap) => onData(snap.docs
    .map((d) => toConversation(d.id, d.data()))
    .filter((c): c is Conversation => !!c && !!c.lastMessage)), onError);
}

export function watchConversation(id: string, onData: (c: Conversation | null) => void) {
  return onSnapshot(doc(db, 'conversations', id), (s) => onData(s.exists() ? toConversation(s.id, s.data()) : null));
}

export function watchMessages(id: string, onData: (items: ChatMessage[]) => void) {
  const q = query(collection(db, 'conversations', id, 'messages'), orderBy('createdAt', 'desc'), limit(50));
  return onSnapshot(q, { includeMetadataChanges: true }, (snap) => onData(snap.docs.map((d) => ({
    id: d.id,
    senderId: String(d.data().senderId),
    text: String(d.data().text ?? ''),
    createdAt: toDate(d.data().createdAt),
    pending: d.metadata.hasPendingWrites,
  }))));
}

export const preview = (t: string) => (t.length > 120 ? `${t.slice(0, 117)}...` : t);

/** Message + conversation preview + notification for the other side, in ONE batch (rule newMessageNotice). */
export async function sendMessage(c: Conversation, me: { uid: string; name: string }, raw: string) {
  const text = raw.trim();
  if (!text) throw new Error('Écrivez un message avant de l’envoyer.');
  if (text.length > MAX_MESSAGE) throw new Error(`Message trop long (${MAX_MESSAGE} caractères maximum).`);
  const convo = doc(db, 'conversations', c.id);
  const other = c.participants.find((p) => p !== me.uid);
  const batch = writeBatch(db);
  batch.set(doc(collection(convo, 'messages')), {
    senderId: me.uid, text, attachments: [], createdAt: serverTimestamp(),
  });
  batch.update(convo, {
    lastMessage: preview(text),
    lastMessageAt: serverTimestamp(),
    lastSenderId: me.uid,
    [`lastReadAt.${me.uid}`]: serverTimestamp(),
  });
  if (other) {
    const who = me.name.trim().slice(0, 60);
    batch.set(doc(collection(db, 'notifications')), {
      userId: other,
      type: 'newMessage',
      title: who ? `Nouveau message de ${who}` : 'Nouveau message',
      body: preview(text),
      read: false,
      conversationId: c.id,
      createdAt: serverTimestamp(),
    });
  }
  await batch.commit();
}

export async function markRead(id: string, uid: string) {
  try {
    await updateDoc(doc(db, 'conversations', id), { [`lastReadAt.${uid}`]: serverTimestamp() });
  } catch {
    // ignore
  }
}

export function isUnread(c: Conversation, uid: string) {
  if (!c.lastMessageAt || c.lastSenderId === uid) return false;
  const seen = c.lastReadAt[uid];
  return !seen || seen < c.lastMessageAt;
}

