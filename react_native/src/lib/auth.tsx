import {
  createUserWithEmailAndPassword, onAuthStateChanged, reload, sendEmailVerification, signInWithEmailAndPassword,
  signOut as fbSignOut, updateProfile, type User,
} from '@firebase/auth';
import { doc, onSnapshot, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';
import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';

import { watchFavoriteIds } from './favorites';
import { auth, db } from './firebase';
import type { UserProfile } from './types';

interface AuthValue {
  user: User | null;
  profile: UserProfile | null;
  loading: boolean;
  favoriteIds: string[];
  displayName: string;
  signIn(email: string, password: string): Promise<void>;
  register(name: string, email: string, password: string, phone: string): Promise<void>;
  signOut(): Promise<void>;
  /** Reloads the account so a just-verified e-mail is seen by the rules. */
  refreshVerification(): Promise<boolean>;
  resendVerification(): Promise<void>;
  /** user -> owner (rule B2), needed to publish. */
  ensurePublisherRole(): Promise<'owner' | 'agent' | 'admin'>;
  updateMyProfile(data: { name: string; phone: string }): Promise<void>;
}

const AuthContext = createContext<AuthValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(auth.currentUser);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [favoriteIds, setFavoriteIds] = useState<string[]>([]);

  useEffect(() => onAuthStateChanged(auth, (u) => {
    setUser(u);
    setLoading(false);
  }), []);

  useEffect(() => {
    if (!user) {
      setProfile(null);
      setFavoriteIds([]);
      return;
    }
    const stopProfile = onSnapshot(doc(db, 'users', user.uid), (s) => {
      const d = s.data();
      setProfile(d ? {
        id: s.id,
        name: String(d.name ?? ''),
        email: String(d.email ?? user.email ?? ''),
        phone: d.phone ?? null,
        photoUrl: d.photoUrl ?? null,
        role: (['owner', 'agent', 'admin'].includes(d.role) ? d.role : 'user'),
        status: String(d.status ?? 'active'),
      } : null);
    }, () => setProfile(null));
    const stopFavs = watchFavoriteIds(user.uid, setFavoriteIds);
    return () => {
      stopProfile();
      stopFavs();
    };
  }, [user]);

  const value = useMemo<AuthValue>(() => ({
    user,
    profile,
    loading,
    favoriteIds,
    displayName: profile?.name || user?.displayName || user?.email?.split('@')[0] || '',
    async signIn(email, password) {
      await signInWithEmailAndPassword(auth, email.trim(), password);
    },
    async register(name, email, password, phone) {
      const cred = await createUserWithEmailAndPassword(auth, email.trim(), password);
      await updateProfile(cred.user, { displayName: name.trim() });
      // Exactly the fields the `users` create rule accepts.
      await setDoc(doc(db, 'users', cred.user.uid), {
        id: cred.user.uid,
        name: name.trim(),
        email: cred.user.email,
        phone: phone.trim() || null,
        role: 'user',
        status: 'active',
        verified: false,
        createdAt: serverTimestamp(),
      });
      await sendEmailVerification(cred.user).catch(() => undefined);
    },
    async signOut() {
      await fbSignOut(auth);
    },
    async refreshVerification() {
      if (!auth.currentUser) return false;
      await reload(auth.currentUser);
      await auth.currentUser.getIdToken(true);
      setUser(auth.currentUser);
      return auth.currentUser.emailVerified;
    },
    async resendVerification() {
      if (auth.currentUser) await sendEmailVerification(auth.currentUser);
    },
    async ensurePublisherRole() {
      const u = auth.currentUser;
      if (!u) throw new Error('Connectez-vous pour publier.');
      if (!u.emailVerified) {
        await reload(u);
        await u.getIdToken(true);
        if (!auth.currentUser?.emailVerified) {
          throw new Error('Vérifiez votre adresse e-mail (lien reçu par e-mail) avant de publier.');
        }
      }
      const role = profile?.role ?? 'user';
      if (role === 'owner' || role === 'agent' || role === 'admin') return role;
      await updateDoc(doc(db, 'users', u.uid), { role: 'owner' });
      return 'owner';
    },
    async updateMyProfile(data) {
      if (!auth.currentUser) return;
      await updateDoc(doc(db, 'users', auth.currentUser.uid), { name: data.name.trim(), phone: data.phone.trim() || null });
    },
  }), [user, profile, loading, favoriteIds]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const v = useContext(AuthContext);
  if (!v) throw new Error('useAuth outside AuthProvider');
  return v;
}
