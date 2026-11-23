import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { FlatList, Pressable, StyleSheet, Text, View } from 'react-native';

import { Empty, Loading } from '../components/ui';
import { useAuth } from '../lib/auth';
import { timeAgo } from '../lib/format';
import { deleteNotification, markNotificationRead, watchNotifications } from '../lib/notifications';
import { colors } from '../lib/theme';
import type { AppNotification } from '../lib/types';

export default function Notifications() {
  const router = useRouter();
  const { user } = useAuth();
  const [items, setItems] = useState<AppNotification[] | null>(null);

  useEffect(() => (user ? watchNotifications(user.uid, setItems) : undefined), [user]);

  if (!user) return <Empty title="Connectez-vous" message="Les notifications sont liées à votre compte." />;
  if (!items) return <Loading />;

  function open(n: AppNotification) {
    if (!n.read) markNotificationRead(n.id);
    if (n.conversationId) router.push(`/chat/${n.conversationId}`);
    else if (n.propertyId) router.push(`/property/${n.propertyId}`);
  }

  return (
    <FlatList
      data={items}
      keyExtractor={(n) => n.id}
      contentContainerStyle={{ flexGrow: 1 }}
      ListEmptyComponent={<Empty title="Aucune notification" message="Nouveaux messages, validation de vos annonces… tout arrive ici." />}
      renderItem={({ item: n }) => (
        <Pressable style={[s.row, !n.read && { backgroundColor: colors.primarySoft }]} onPress={() => open(n)}
          onLongPress={() => deleteNotification(n.id)}>
          <View style={{ flex: 1 }}>
            <Text style={[s.title, !n.read && { color: colors.primary }]}>{n.title}</Text>
            {n.body ? <Text style={s.body} numberOfLines={2}>{n.body}</Text> : null}
            <Text style={s.time}>{timeAgo(n.createdAt)}</Text>
          </View>
          {!n.read && <View style={s.dot} />}
        </Pressable>
      )}
      ListFooterComponent={items.length ? <Text style={s.hint}>Appui long pour supprimer une notification.</Text> : undefined}
    />
  );
}

const s = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', padding: 16, backgroundColor: 'white', borderBottomWidth: 1, borderColor: colors.line },
  title: { fontSize: 15, fontWeight: '700', color: colors.text },
  body: { fontSize: 14, color: colors.muted, marginTop: 3 },
  time: { fontSize: 12, color: colors.muted, marginTop: 5 },
  dot: { width: 10, height: 10, borderRadius: 5, backgroundColor: colors.primary, marginLeft: 10 },
  hint: { textAlign: 'center', color: colors.muted, fontSize: 12, padding: 16 },
});
