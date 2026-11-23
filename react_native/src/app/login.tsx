import { Link, useRouter } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, Text } from 'react-native';
import { sendPasswordResetEmail } from '@firebase/auth';
import { Alert } from 'react-native';

import { Button, Field } from '../components/ui';
import { useAuth } from '../lib/auth';
import { auth as fbAuth } from '../lib/firebase';
import { errorMessage } from '../lib/format';
import { colors } from '../lib/theme';

export default function Login() {
  const router = useRouter();
  const { signIn } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit() {
    setError(null);
    if (!email.trim() || !password) {
      setError('Saisissez votre e-mail et votre mot de passe.');
      return;
    }
    setBusy(true);
    try {
      await signIn(email, password);
      router.back();
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  async function reset() {
    if (!email.trim()) {
      setError('Saisissez votre e-mail pour recevoir le lien.');
      return;
    }
    try {
      await sendPasswordResetEmail(fbAuth, email.trim());
      Alert.alert('Mot de passe', 'Un lien de réinitialisation a été envoyé.');
    } catch (e) {
      setError(errorMessage(e));
    }
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={{ padding: 20 }} keyboardShouldPersistTaps="handled">
        <Text style={{ fontSize: 26, fontWeight: '800', color: colors.primary, marginBottom: 4 }}>DARNA</Text>
        <Text style={{ color: colors.muted, marginBottom: 22 }}>Connectez-vous à votre compte (le même que sur l’app Flutter).</Text>
        <Field label="E-mail" value={email} onChangeText={setEmail} autoCapitalize="none" keyboardType="email-address" autoComplete="email" />
        <Field label="Mot de passe" value={password} onChangeText={setPassword} secureTextEntry error={error} />
        <Button title="Se connecter" onPress={submit} loading={busy} />
        <Text onPress={reset} style={{ color: colors.primary, textAlign: 'center', marginTop: 16, fontWeight: '600' }}>Mot de passe oublié ?</Text>
        <Link href="/register" replace style={{ color: colors.primary, textAlign: 'center', marginTop: 16, fontWeight: '700' }}>
          Pas de compte ? Créer un compte
        </Link>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
