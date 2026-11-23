import { collection, deleteDoc, doc, limit, onSnapshot, orderBy, query, serverTimestamp, updateDoc, where } from 'firebase/firestore';

import { db } from './firebase';
import { toDate } from './format';
import type { AppNotification } from './types';

/** In-app notifications (same collection as Flutter; index userId + createdAt). */
export function watchNotifications(uid: string, onData: (items: AppNotification[]) => void) {
  const q = query(collection(db, 'notifications'), where('userId', '==', uid), orderBy('createdAt', 'desc'), limit(50));
  return onSnapshot(q, (snap) => onData(snap.docs.map((d) => {
    const n = d.data();
    return {
      id: d.id,
      type: String(n.type ?? ''),
      title: String(n.title ?? ''),
      body: String(n.body ?? ''),
      read: n.read === true,
      conversationId: n.conversationId ?? null,
      propertyId: n.propertyId ?? null,
      createdAt: toDate(n.createdAt),
    };
  })), () => onData([]));
}

export const markNotificationRead = (id: string) =>
  updateDoc(doc(db, 'notifications', id), { read: true, readAt: serverTimestamp() }).catch(() => undefined);

export const deleteNotification = (id: string) => deleteDoc(doc(db, 'notifications', id)).catch(() => undefined);
