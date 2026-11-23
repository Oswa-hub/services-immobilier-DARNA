import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { Alert, FlatList, Text, View } from 'react-native';

import PropertyCard from '../components/PropertyCard';
import { Button, Empty, Loading } from '../components/ui';
import { useAuth } from '../lib/auth';
import { errorMessage } from '../lib/format';
import { isExpired, watchMyListings, withdrawListing } from '../lib/properties';
import { colors } from '../lib/theme';
import type { Property } from '../lib/types';

const STATUS: Record<string, string> = {
  draft: 'Brouillon', pending_review: 'En attente', published: 'Publiée', rejected: 'Refusée',
  removed: 'Retirée', suspended: 'Suspendue', expired: 'Expirée',
};

export default function MyListings() {
  const router = useRouter();
  const { user } = useAuth();
  const [items, setItems] = useState<Property[] | null>(null);

  useEffect(() => (user ? watchMyListings(user.uid, setItems) : undefined), [user]);

  if (!user) return <Empty title="Connectez-vous" />;
  if (!items) return <Loading />;

  const withdraw = (p: Property) => Alert.alert('Retirer l’annonce', `Retirer « ${p.title} » ? Elle ne sera plus visible.`, [
    { text: 'Annuler', style: 'cancel' },
    { text: 'Retirer', style: 'destructive', onPress: () => withdrawListing(p.id).catch((e) => Alert.alert('Erreur', errorMessage(e))) },
  ]);

  return (
    <FlatList
      data={items}
      keyExtractor={(p) => p.id}
      contentContainerStyle={{ padding: 16, flexGrow: 1 }}
      ListHeaderComponent={<Button title="＋ Publier une annonce" onPress={() => router.push('/publish')} style={{ marginBottom: 14 }} />}
      ListEmptyComponent={<Empty title="Aucune annonce" message="Vos annonces apparaîtront ici avec leur statut." />}
      renderItem={({ item: p }) => {
        const label = p.status === 'published' && isExpired(p) ? 'Expirée' : STATUS[p.status] ?? p.status;
        return (
          <View>
            <PropertyCard property={p} badge={label} />
            {p.status === 'pending_review' && (
              <Text style={{ color: colors.muted, marginTop: -8, marginBottom: 10 }}>L’administrateur doit valider l’annonce avant publication.</Text>
            )}
            {['draft', 'pending_review', 'published', 'rejected', 'expired'].includes(p.status) && (
              <Button title="Retirer" variant="outline" onPress={() => withdraw(p)} style={{ height: 40, marginTop: -6, marginBottom: 18 }} />
            )}
          </View>
        );
      }}
    />
  );
}
