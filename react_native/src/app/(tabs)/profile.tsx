import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { Alert, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Button, Empty, Field } from '../../components/ui';
import { useAuth } from '../../lib/auth';
import { errorMessage } from '../../lib/format';
import { colors } from '../../lib/theme';

const ROLE_LABELS = { user: 'Utilisateur', owner: 'Propriétaire', agent: 'Agent immobilier', admin: 'Administrateur' } as const;

export default function ProfileScreen() {
  const router = useRouter();
  const auth = useAuth();
  const { user, profile } = auth;
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [saving, setSaving] = useState(false);
  const [checking, setChecking] = useState(false);

  useEffect(() => {
    setName(profile?.name ?? '');
    setPhone(profile?.phone ?? '');
  }, [profile?.name, profile?.phone]);

  if (!user) {
    return (
      <Empty
        title="Bienvenue sur DARNA"
        message="Connectez-vous pour publier, enregistrer vos favoris et contacter les annonceurs."
        action={
          <View style={{ alignSelf: 'stretch', gap: 10, marginTop: 8 }}>
            <Button title="Se connecter" onPress={() => router.push('/login')} />
            <Button title="Créer un compte" variant="outline" onPress={() => router.push('/register')} />
          </View>
        }
      />
    );
  }

  async function save() {
    if (name.trim().length < 2) {
      Alert.alert('Profil', 'Le nom doit contenir au moins 2 caractères.');
      return;
    }
    setSaving(true);
    try {
      await auth.updateMyProfile({ name, phone });
      Alert.alert('Profil', 'Profil enregistré.');
    } catch (e) {
      Alert.alert('Profil', errorMessage(e));
    } finally {
      setSaving(false);
    }
  }

  async function checkEmail() {
    setChecking(true);
    try {
      const ok = await auth.refreshVerification();
      Alert.alert('E-mail', ok ? 'Adresse e-mail vérifiée. Vous pouvez publier.' : 'Pas encore vérifiée. Ouvrez le lien reçu par e-mail.');
    } finally {
      setChecking(false);
    }
  }

  const initials = (auth.displayName || '?').slice(0, 1).toUpperCase();

  return (
    <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 40 }}>
      <View style={s.header}>
        <View style={s.avatar}><Text style={{ color: 'white', fontSize: 26, fontWeight: '800' }}>{initials}</Text></View>
        <View style={{ flex: 1 }}>
          <Text style={s.name}>{auth.displayName}</Text>
          <Text style={s.muted}>{user.email}</Text>
          <Text style={s.role}>{ROLE_LABELS[profile?.role ?? 'user']}</Text>
        </View>
      </View>

      {!user.emailVerified && (
        <View style={s.warn}>
          <Text style={{ fontWeight: '700', color: colors.text }}>Vérifiez votre adresse e-mail</Text>
          <Text style={[s.muted, { marginVertical: 6 }]}>Un lien vous a été envoyé. La vérification est nécessaire pour publier.</Text>
          <View style={{ flexDirection: 'row', gap: 10 }}>
            <Button title="J’ai vérifié" onPress={checkEmail} loading={checking} style={{ flex: 1, height: 42 }} />
            <Button title="Renvoyer" variant="outline" style={{ flex: 1, height: 42 }}
              onPress={() => auth.resendVerification().then(() => Alert.alert('E-mail', 'Lien renvoyé.')).catch((e) => Alert.alert('E-mail', errorMessage(e)))} />
          </View>
        </View>
      )}

      <View style={s.menu}>
        {[
          ['＋  Publier une annonce', '/publish'],
          ['▤  Mes annonces', '/my-listings'],
          ['🔔  Notifications', '/notifications'],
        ].map(([label, href]) => (
          <Pressable key={href} style={s.item} onPress={() => router.push(href as '/publish')}>
            <Text style={s.itemText}>{label}</Text><Text style={s.muted}>›</Text>
          </Pressable>
        ))}
      </View>

      <Text style={s.h2}>Mes informations</Text>
      <Field label="Nom" value={name} onChangeText={setName} />
      <Field label="Téléphone" value={phone} onChangeText={setPhone} keyboardType="phone-pad" placeholder="+216 …" />
      <Button title="Enregistrer" onPress={save} loading={saving} />

      <Button title="Se déconnecter" variant="outline" style={{ marginTop: 24 }}
        onPress={() => Alert.alert('Déconnexion', 'Voulez-vous vous déconnecter ?', [
          { text: 'Annuler', style: 'cancel' },
          { text: 'Se déconnecter', style: 'destructive', onPress: () => auth.signOut() },
        ])} />
      <Text style={[s.muted, { textAlign: 'center', marginTop: 18, fontSize: 12 }]}>DARNA · version React Native</Text>
    </ScrollView>
  );
}

const s = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', gap: 14, backgroundColor: 'white', padding: 16, borderRadius: 14, borderWidth: 1, borderColor: colors.line },
  avatar: { width: 62, height: 62, borderRadius: 31, backgroundColor: colors.primary, alignItems: 'center', justifyContent: 'center' },
  name: { fontSize: 18, fontWeight: '800', color: colors.text },
  muted: { color: colors.muted },
  role: { alignSelf: 'flex-start', marginTop: 6, backgroundColor: colors.primarySoft, color: colors.primary, fontWeight: '700', fontSize: 12, paddingHorizontal: 8, paddingVertical: 3, borderRadius: 6, overflow: 'hidden' },
  warn: { backgroundColor: '#FFF6E5', borderColor: '#F3D39A', borderWidth: 1, borderRadius: 14, padding: 14, marginTop: 14 },
  menu: { backgroundColor: 'white', borderRadius: 14, borderWidth: 1, borderColor: colors.line, marginTop: 14 },
  item: { flexDirection: 'row', justifyContent: 'space-between', padding: 16, borderBottomWidth: 1, borderColor: colors.line },
  itemText: { fontSize: 15, fontWeight: '600', color: colors.text },
  h2: { fontSize: 17, fontWeight: '700', color: colors.text, marginTop: 22, marginBottom: 10 },
});
