import { Link, useRouter } from 'expo-router';
import { useState } from 'react';
import { Alert, KeyboardAvoidingView, Platform, ScrollView, Text } from 'react-native';

import { Button, Field } from '../components/ui';
import { useAuth } from '../lib/auth';
import { errorMessage } from '../lib/format';
import { colors } from '../lib/theme';

export default function Register() {
  const router = useRouter();
  const { register } = useAuth();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit() {
    setError(null);
    if (name.trim().length < 2) return setError('Le nom doit contenir au moins 2 caractères.');
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/.test(email.trim())) return setError('Adresse e-mail invalide.');
    if (password.length < 6) return setError('Mot de passe : 6 caractères minimum.');
    if (password !== confirm) return setError('Les mots de passe ne correspondent pas.');
    setBusy(true);
    try {
      await register(name, email, password, phone);
      Alert.alert('Compte créé', 'Un e-mail de vérification vous a été envoyé. Vérifiez-le pour pouvoir publier.');
      router.back();
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={{ padding: 20 }} keyboardShouldPersistTaps="handled">
        <Text style={{ color: colors.muted, marginBottom: 18 }}>Créez votre compte DARNA pour publier, enregistrer et discuter.</Text>
        <Field label="Nom complet" value={name} onChangeText={setName} />
        <Field label="E-mail" value={email} onChangeText={setEmail} autoCapitalize="none" keyboardType="email-address" />
        <Field label="Téléphone (facultatif)" value={phone} onChangeText={setPhone} keyboardType="phone-pad" placeholder="+216 …" />
        <Field label="Mot de passe" value={password} onChangeText={setPassword} secureTextEntry />
        <Field label="Confirmer le mot de passe" value={confirm} onChangeText={setConfirm} secureTextEntry error={error} />
        <Button title="Créer mon compte" onPress={submit} loading={busy} />
        <Link href="/login" replace style={{ color: colors.primary, textAlign: 'center', marginTop: 18, fontWeight: '700' }}>
          Déjà un compte ? Se connecter
        </Link>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
