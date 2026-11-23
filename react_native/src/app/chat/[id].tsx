import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { Alert, FlatList, KeyboardAvoidingView, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

import { Empty, Loading } from '../../components/ui';
import { useAuth } from '../../lib/auth';
import { errorMessage } from '../../lib/format';
import { markRead, MAX_MESSAGE, sendMessage, watchConversation, watchMessages } from '../../lib/messaging';
import { colors } from '../../lib/theme';
import type { ChatMessage, Conversation } from '../../lib/types';

const time = (d?: Date | null) => (d ? d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }) : '');

export default function Chat() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { user, displayName } = useAuth();
  const [c, setC] = useState<Conversation | null | undefined>(undefined);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [text, setText] = useState('');
  const [sending, setSending] = useState(false);

  useEffect(() => watchConversation(String(id), setC), [id]);
  useEffect(() => watchMessages(String(id), setMessages), [id]);
  useEffect(() => {
    if (user && messages.length) markRead(String(id), user.uid);
  }, [messages.length, user, id]);

  if (!user) return <Empty title="Connectez-vous" />;
  if (c === undefined) return <Loading />;
  if (c === null) return <Empty title="Conversation introuvable" />;

  const other = c.userId === user.uid ? (c.recipientName || 'Annonceur') : (c.userName || 'Client');

  async function send() {
    if (!c || !user || !text.trim()) return;
    const value = text;
    setText('');
    setSending(true);
    try {
      await sendMessage(c, { uid: user.uid, name: displayName }, value);
    } catch (e) {
      setText(value);
      Alert.alert('Message', errorMessage(e));
    } finally {
      setSending(false);
    }
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={90}>
      <Stack.Screen options={{ title: other }} />
      <Pressable style={s.prop} onPress={() => router.push(`/property/${c.propertyId}`)}>
        <Text style={{ color: colors.primary, fontWeight: '700' }} numberOfLines={1}>🏠 {c.propertyTitle}</Text>
        <Text style={{ color: colors.muted, fontSize: 12 }}>Voir l’annonce ›</Text>
      </Pressable>
      <FlatList
        data={messages}
        inverted
        keyExtractor={(m) => m.id}
        contentContainerStyle={{ padding: 12 }}
        ListEmptyComponent={<Text style={{ textAlign: 'center', color: colors.muted, transform: [{ scaleY: -1 }] }}>Écrivez votre premier message.</Text>}
        renderItem={({ item: m }) => {
          const mine = m.senderId === user.uid;
          return (
            <View style={[s.bubble, mine ? s.mine : s.theirs]}>
              <Text style={{ color: mine ? 'white' : colors.text, fontSize: 15 }}>{m.text}</Text>
              <Text style={{ color: mine ? '#D7EDE6' : colors.muted, fontSize: 11, marginTop: 4, alignSelf: 'flex-end' }}>
                {m.pending ? 'Envoi…' : time(m.createdAt)}
              </Text>
            </View>
          );
        }}
      />
      <View style={s.bar}>
        <TextInput
          value={text}
          onChangeText={setText}
          placeholder="Votre message…"
          placeholderTextColor={colors.muted}
          multiline
          maxLength={MAX_MESSAGE}
          style={s.input}
        />
        <Pressable onPress={send} disabled={sending || !text.trim()} style={[s.send, (!text.trim() || sending) && { opacity: 0.5 }]}>
          <Text style={{ color: 'white', fontWeight: '800', fontSize: 18 }}>➤</Text>
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  prop: { backgroundColor: 'white', padding: 12, borderBottomWidth: 1, borderColor: colors.line },
  bubble: { maxWidth: '80%', borderRadius: 16, paddingHorizontal: 12, paddingVertical: 8, marginVertical: 4 },
  mine: { alignSelf: 'flex-end', backgroundColor: colors.primary, borderBottomRightRadius: 4 },
  theirs: { alignSelf: 'flex-start', backgroundColor: 'white', borderWidth: 1, borderColor: colors.line, borderBottomLeftRadius: 4 },
  bar: { flexDirection: 'row', alignItems: 'flex-end', gap: 8, padding: 10, paddingBottom: 18, backgroundColor: 'white', borderTopWidth: 1, borderColor: colors.line },
  input: { flex: 1, maxHeight: 120, backgroundColor: colors.background, borderRadius: 20, paddingHorizontal: 14, paddingVertical: 10, fontSize: 15, color: colors.text },
  send: { width: 46, height: 46, borderRadius: 23, backgroundColor: colors.primary, alignItems: 'center', justifyContent: 'center' },
});
