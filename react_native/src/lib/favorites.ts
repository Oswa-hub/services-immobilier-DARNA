import { collection, doc, increment, onSnapshot, query, serverTimestamp, where, writeBatch } from 'firebase/firestore';

import { db } from './firebase';

/** Favorite id = {userId}_{propertyId} (same as Flutter and the rules). */
const favId = (uid: string, propertyId: string) => `${uid}_${propertyId}`;

export function watchFavoriteIds(uid: string, onData: (ids: string[]) => void) {
  return onSnapshot(query(collection(db, 'favorites'), where('userId', '==', uid)), (snap) =>
    onData(snap.docs.map((d) => String(d.data().propertyId))));
}

/** Favorite + public counter in ONE batch (rule counterBump). */
export async function addFavorite(uid: string, propertyId: string) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'favorites', favId(uid, propertyId)), { userId: uid, propertyId, createdAt: serverTimestamp() });
  batch.update(doc(db, 'properties', propertyId), { favoritesCount: increment(1) });
  await batch.commit();
}

export async function removeFavorite(uid: string, propertyId: string) {
  const batch = writeBatch(db);
  batch.delete(doc(db, 'favorites', favId(uid, propertyId)));
  batch.update(doc(db, 'properties', propertyId), { favoritesCount: increment(-1) });
  try {
    await batch.commit();
  } catch {
    // Listing no longer published: the counter cannot change, remove the favorite alone.
    const only = writeBatch(db);
    only.delete(doc(db, 'favorites', favId(uid, propertyId)));
    await only.commit();
  }
}
