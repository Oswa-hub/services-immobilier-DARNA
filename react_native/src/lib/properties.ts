import {
  collection, doc, getDoc, getDocs, increment, limit, onSnapshot, orderBy, query,
  serverTimestamp, setDoc, updateDoc, where, type DocumentData,
} from 'firebase/firestore';

import { AMENITIES, PROPERTY_TYPES, type Amenity, type PropertyType, type TransactionType } from './constants';
import { db } from './firebase';
import { toDate } from './format';
import type { Property } from './types';

const col = collection(db, 'properties');

/** Firestore document -> Property (same field names as the Flutter PropertyMapper). */
export function toProperty(id: string, d: DocumentData): Property | null {
  if (typeof d.title !== 'string' || typeof d.price !== 'number') return null;
  const num = (v: unknown) => (typeof v === 'number' ? v : null);
  return {
    id,
    ownerId: String(d.ownerId ?? ''),
    agentId: typeof d.agentId === 'string' && d.agentId ? d.agentId : null,
    ownerName: d.ownerName ?? null,
    ownerRole: d.ownerRole ?? null,
    title: d.title,
    description: String(d.description ?? ''),
    transactionType: d.transactionType === 'rent' ? 'rent' : 'buy',
    propertyType: (d.propertyType in PROPERTY_TYPES ? d.propertyType : 'apartment') as PropertyType,
    price: d.price,
    currency: d.currency ?? 'TND',
    surface: num(d.surface),
    bedrooms: num(d.bedrooms),
    bathrooms: num(d.bathrooms),
    governorate: String(d.governorate ?? ''),
    city: d.city ?? null,
    area: d.area ?? null,
    latitude: num(d.latitude),
    longitude: num(d.longitude),
    images: Array.isArray(d.images) ? d.images.filter((x: unknown) => typeof x === 'string') : [],
    amenities: Array.isArray(d.amenities) ? d.amenities.filter((a: string) => a in AMENITIES) : [],
    status: String(d.status ?? ''),
    views: num(d.views) ?? 0,
    favoritesCount: num(d.favoritesCount) ?? 0,
    publishedAt: toDate(d.publishedAt),
    createdAt: toDate(d.createdAt),
    expiresAt: toDate(d.expiresAt),
  };
}

export const isExpired = (p: Property) => !!p.expiresAt && p.expiresAt.getTime() < Date.now();
export const isVisible = (p: Property) => p.status === 'published' && !isExpired(p);

/** Latest published listings (index: status + publishedAt). Filters run on the device. */
export function watchPublished(onData: (items: Property[]) => void, onError: (e: unknown) => void) {
  const q = query(col, where('status', '==', 'published'), orderBy('publishedAt', 'desc'), limit(200));
  return onSnapshot(
    q,
    (snap) => onData(snap.docs.map((d) => toProperty(d.id, d.data())).filter((p): p is Property => !!p && isVisible(p))),
    onError,
  );
}

export async function getProperty(id: string): Promise<Property | null> {
  const snap = await getDoc(doc(db, 'properties', id));
  return snap.exists() ? toProperty(snap.id, snap.data()) : null;
}

/** +1 view (allowed by the rules on a published listing, once per session). */
const viewed = new Set<string>();
export async function recordView(p: Property) {
  if (viewed.has(p.id) || p.status !== 'published') return;
  viewed.add(p.id);
  try {
    await updateDoc(doc(db, 'properties', p.id), { views: increment(1) });
  } catch {
    // Visitors (not signed in) cannot count views: ignore.
  }
}

export function watchMyListings(uid: string, onData: (items: Property[]) => void) {
  return onSnapshot(query(col, where('ownerId', '==', uid)), (snap) => {
    const items = snap.docs.map((d) => toProperty(d.id, d.data())).filter((p): p is Property => !!p);
    items.sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0));
    onData(items);
  });
}

export interface SearchFilters {
  text: string;
  transactionType: TransactionType | null;
  propertyType: PropertyType | null;
  governorate: string | null;
  minPrice: number | null;
  maxPrice: number | null;
}

export const emptyFilters: SearchFilters = {
  text: '', transactionType: null, propertyType: null, governorate: null, minPrice: null, maxPrice: null,
};

export function applyFilters(items: Property[], f: SearchFilters): Property[] {
  const text = f.text.trim().toLowerCase();
  return items.filter((p) =>
    (!f.transactionType || p.transactionType === f.transactionType)
    && (!f.propertyType || p.propertyType === f.propertyType)
    && (!f.governorate || p.governorate === f.governorate)
    && (f.minPrice == null || p.price >= f.minPrice)
    && (f.maxPrice == null || p.price <= f.maxPrice)
    && (!text || `${p.title} ${p.city ?? ''} ${p.area ?? ''} ${p.governorate}`.toLowerCase().includes(text)));
}

export interface NewListing {
  title: string;
  description: string;
  transactionType: TransactionType;
  propertyType: PropertyType;
  price: number;
  surface: number;
  bedrooms: number | null;
  bathrooms: number | null;
  governorate: string;
  city: string;
  area: string;
  latitude: number | null;
  longitude: number | null;
  amenities: Amenity[];
}

/** New id first, so photos can be uploaded in properties/{id} before the document exists. */
export const newListingId = () => doc(col).id;

/**
 * Creates a listing in moderation. The shape is exactly the one `validNewListing`
 * accepts in firestore.rules (same as the Flutter PropertyWriteMapper).
 */
export async function createListing(
  id: string, data: NewListing, images: string[], owner: { uid: string; name: string; role: 'owner' | 'agent' },
) {
  const d: Record<string, unknown> = {
    ownerId: owner.uid,
    agentId: owner.role === 'agent' ? owner.uid : null,
    ownerName: owner.name.slice(0, 120),
    ownerRole: owner.role,
    title: data.title.trim(),
    description: data.description.trim(),
    transactionType: data.transactionType,
    propertyType: data.propertyType,
    price: data.price,
    currency: 'TND',
    surface: data.surface,
    isStudio: false,
    isNewBuild: false,
    governorate: data.governorate,
    city: data.city.trim(),
    images,
    amenities: data.amenities,
    status: 'pending_review',
    verificationStatus: 'not_submitted',
    views: 0,
    favoritesCount: 0,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    publishedAt: null,
  };
  if (data.bedrooms != null) d.bedrooms = Math.trunc(data.bedrooms);
  if (data.bathrooms != null) d.bathrooms = Math.trunc(data.bathrooms);
  if (data.area.trim()) d.area = data.area.trim().slice(0, 80);
  if (data.latitude != null && data.longitude != null) {
    d.latitude = data.latitude;
    d.longitude = data.longitude;
  }
  await setDoc(doc(db, 'properties', id), d);
}

/** Withdraw a listing (lifecycle move allowed to its owner). */
export async function withdrawListing(id: string) {
  await updateDoc(doc(db, 'properties', id), { status: 'removed', updatedAt: serverTimestamp() });
}

export async function getMany(ids: string[]): Promise<Property[]> {
  const res = await Promise.all(ids.map((id) => getDoc(doc(db, 'properties', id)).catch(() => null)));
  return res
    .map((s) => (s && s.exists() ? toProperty(s.id, s.data()) : null))
    .filter((p): p is Property => !!p);
}

export { getDocs };
