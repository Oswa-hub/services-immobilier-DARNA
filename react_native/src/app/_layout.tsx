import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { Text, View } from 'react-native';

import { AuthProvider } from '../lib/auth';
import { firebaseConfigured } from '../lib/firebase';
import { colors } from '../lib/theme';

export default function RootLayout() {
  if (!firebaseConfigured) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 30 }}>
        <Text style={{ fontSize: 18, fontWeight: '700', marginBottom: 8 }}>Configuration manquante</Text>
        <Text style={{ textAlign: 'center', color: colors.muted }}>
          Lancez « npm run env » dans le dossier react_native, puis redémarrez « npx expo start ».
        </Text>
      </View>
    );
  }
  return (
    <AuthProvider>
      <StatusBar style="light" />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: colors.primary },
          headerTintColor: 'white',
          headerTitleStyle: { fontWeight: '700' },
          contentStyle: { backgroundColor: colors.background },
        }}
      >
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen name="property/[id]" options={{ title: 'Détail du bien' }} />
        <Stack.Screen name="chat/[id]" options={{ title: 'Conversation' }} />
        <Stack.Screen name="login" options={{ title: 'Connexion' }} />
        <Stack.Screen name="register" options={{ title: 'Créer un compte' }} />
        <Stack.Screen name="publish" options={{ title: 'Publier une annonce' }} />
        <Stack.Screen name="notifications" options={{ title: 'Notifications' }} />
        <Stack.Screen name="my-listings" options={{ title: 'Mes annonces' }} />
      </Stack>
    </AuthProvider>
  );
}
