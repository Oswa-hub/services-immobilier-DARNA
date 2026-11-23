import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { FlatList, View } from 'react-native';

import PropertyCard from '../../components/PropertyCard';
import { Button, Empty, Loading } from '../../components/ui';
import { useAuth } from '../../lib/auth';
import { getMany } from '../../lib/properties';
import { colors } from '../../lib/theme';
import type { Property } from '../../lib/types';

export default function FavoritesScreen() {
  const router = useRouter();
  const { user, favoriteIds } = useAuth();
  const [items, setItems] = useState<Property[] | null>(null);

  useEffect(() => {
    let alive = true;
    getMany(favoriteIds).then((x) => alive && setItems(x.filter((p) => p.status === 'published')));
    return () => { alive = false; };
  }, [favoriteIds.join(',')]);

  if (!user) {
    return <Empty title="Vos favoris" message="Connectez-vous pour enregistrer des biens."
      action={<Button title="Se connecter" onPress={() => router.push('/login')} style={{ alignSelf: 'stretch' }} />} />;
  }
  if (!items) return <Loading />;
  return (
    <View style={{ flex: 1, backgroundColor: colors.background }}>
      <FlatList
        data={items}
        keyExtractor={(p) => p.id}
        renderItem={({ item }) => <PropertyCard property={item} />}
        contentContainerStyle={{ padding: 16, flexGrow: 1 }}
        ListEmptyComponent={<Empty title="Aucun favori" message="Touchez ♡ sur une annonce pour l’enregistrer ici." />}
      />
    </View>
  );
}
