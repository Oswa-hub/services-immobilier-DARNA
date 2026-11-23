import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { FlatList, Image, Pressable, StyleSheet, Text, View } from 'react-native';

import { Button, Empty, Loading } from '../../components/ui';
import { useAuth } from '../../lib/auth';
import { errorMessage, timeAgo } from '../../lib/format';
import { isUnread, watchConversations } from '../../lib/messaging';
import { colors } from '../../lib/theme';
import type { Conversation } from '../../lib/types';

export default function MessagesScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const [items, setItems] = useState<Conversation[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!user) return;
    return watchConversations(user.uid, setItems, (e) => setError(errorMessage(e)));
  }, [user]);

  if (!user) {
    return <Empty title="Messagerie" message="Connectez-vous pour discuter avec les annonceurs."
      action={<Button title="Se connecter" onPress={() => router.push('/login')} style={{ alignSelf: 'stretch' }} />} />;
  }
  if (error) return <Empty title="Chargement impossible" message={error} />;
  if (!items) return <Loading />;

  return (
    <FlatList
      data={items}
      keyExtractor={(c) => c.id}
      contentContainerStyle={{ flexGrow: 1 }}
      ListEmptyComponent={<Empty title="Aucune conversation" message="Contactez un annonceur depuis une annonce." />}
      renderItem={({ item: c }) => {
        const unread = isUnread(c, user.uid);
        const other = c.userId === user.uid ? (c.recipientName || 'Annonceur') : (c.userName || 'Client');
        return (
          <Pressable style={s.row} onPress={() => router.push(`/chat/${c.id}`)}>
            {c.propertyImage ? <Image source={{ uri: c.propertyImage }} style={s.img} /> : <View style={[s.img, { backgroundColor: colors.line }]} />}
            <View style={{ flex: 1 }}>
              <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                <Text style={[s.name, unread && { color: colors.primary }]} numberOfLines={1}>{other}</Text>
                <Text style={s.time}>{timeAgo(c.lastMessageAt)}</Text>
              </View>
              <Text style={s.prop} numberOfLines={1}>{c.propertyTitle}</Text>
              <Text style={[s.last, unread && { fontWeight: '700', color: colors.text }]} numberOfLines={1}>
                {c.lastSenderId === user.uid ? 'Vous : ' : ''}{c.lastMessage}
              </Text>
            </View>
            {unread && <View style={s.dot} />}
          </Pressable>
        );
      }}
    />
  );
}

const s = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14, backgroundColor: 'white', borderBottomWidth: 1, borderColor: colors.line },
  img: { width: 58, height: 58, borderRadius: 12 },
  name: { fontSize: 15, fontWeight: '700', color: colors.text, flex: 1 },
  time: { fontSize: 12, color: colors.muted },
  prop: { fontSize: 13, color: colors.primary, marginTop: 1 },
  last: { fontSize: 14, color: colors.muted, marginTop: 2 },
  dot: { width: 10, height: 10, borderRadius: 5, backgroundColor: colors.primary },
});
