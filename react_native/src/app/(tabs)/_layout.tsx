import { Tabs } from 'expo-router';
import { useEffect, useState } from 'react';
import { Text, type ColorValue } from 'react-native';

import { useAuth } from '../../lib/auth';
import { isUnread, watchConversations } from '../../lib/messaging';
import { colors } from '../../lib/theme';

const icon = (glyph: string) => ({ color }: { color: ColorValue }) => <Text style={{ fontSize: 20, color }}>{glyph}</Text>;

export default function TabsLayout() {
  const { user } = useAuth();
  const [unread, setUnread] = useState(0);

  useEffect(() => {
    if (!user) {
      setUnread(0);
      return;
    }
    return watchConversations(user.uid, (items) => setUnread(items.filter((c) => isUnread(c, user.uid)).length), () => setUnread(0));
  }, [user]);

  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.muted,
        headerStyle: { backgroundColor: colors.primary },
        headerTintColor: 'white',
        headerTitleStyle: { fontWeight: '700' },
      }}
    >
      <Tabs.Screen name="index" options={{ title: 'Accueil', headerTitle: 'DARNA', tabBarIcon: icon('⌂') }} />
      <Tabs.Screen name="map" options={{ title: 'Carte', tabBarIcon: icon('◎') }} />
      <Tabs.Screen name="favorites" options={{ title: 'Favoris', tabBarIcon: icon('♡') }} />
      <Tabs.Screen name="messages" options={{ title: 'Messages', tabBarIcon: icon('✉'), tabBarBadge: unread || undefined }} />
      <Tabs.Screen name="profile" options={{ title: 'Profil', tabBarIcon: icon('☺') }} />
    </Tabs>
  );
}
