import { useRouter } from 'expo-router';
import { useState } from 'react';
import { Alert, Pressable, Text } from 'react-native';

import { useAuth } from '../lib/auth';
import { addFavorite, removeFavorite } from '../lib/favorites';
import { errorMessage } from '../lib/format';
import { colors } from '../lib/theme';
import type { Property } from '../lib/types';

export default function FavoriteButton({ property, size = 20 }: { property: Property; size?: number }) {
  const { user, favoriteIds } = useAuth();
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const on = favoriteIds.includes(property.id);

  async function toggle() {
    if (!user) {
      router.push('/login');
      return;
    }
    setBusy(true);
    try {
      if (on) await removeFavorite(user.uid, property.id);
      else await addFavorite(user.uid, property.id);
    } catch (e) {
      Alert.alert('Favoris', errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Pressable onPress={toggle} disabled={busy} hitSlop={8}
      style={{ backgroundColor: 'white', borderRadius: 20, width: size * 1.9, height: size * 1.9, alignItems: 'center', justifyContent: 'center', opacity: busy ? 0.6 : 1 }}>
      <Text style={{ fontSize: size, color: on ? colors.danger : colors.muted }}>{on ? '♥' : '♡'}</Text>
    </Pressable>
  );
}
