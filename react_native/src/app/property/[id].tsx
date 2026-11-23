import { useLocalSearchParams, useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { Alert, Dimensions, FlatList, Image, Linking, ScrollView, StyleSheet, Text, View } from 'react-native';
import MapView, { Marker } from 'react-native-maps';

import FavoriteButton from '../../components/FavoriteButton';
import { Button, Empty, Loading } from '../../components/ui';
import { useAuth } from '../../lib/auth';
import { AMENITIES, PROPERTY_TYPES, TRANSACTION_LABELS } from '../../lib/constants';
import { errorMessage, formatPrice } from '../../lib/format';
import { openOrCreate, recipientOf } from '../../lib/messaging';
import { getProperty, recordView } from '../../lib/properties';
import { colors } from '../../lib/theme';
import type { Property } from '../../lib/types';

const W = Dimensions.get('window').width;

export default function PropertyDetails() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { user, displayName } = useAuth();
  const [p, setP] = useState<Property | null | undefined>(undefined);
  const [page, setPage] = useState(0);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let alive = true;
    getProperty(String(id))
      .then((x) => {
        if (!alive) return;
        setP(x);
        if (x && user) recordView(x);
      })
      .catch(() => alive && setP(null));
    return () => { alive = false; };
  }, [id, user]);

  if (p === undefined) return <Loading />;
  if (p === null) return <Empty title="Bien introuvable" message="Cette annonce n’est plus disponible." />;

  const mine = !!user && recipientOf(p) === user.uid;

  async function contact() {
    if (!p) return;
    if (!user) {
      router.push('/login');
      return;
    }
    setBusy(true);
    try {
      const cid = await openOrCreate(p, { uid: user.uid, name: displayName });
      router.push(`/chat/${cid}`);
    } catch (e) {
      Alert.alert('Messagerie', errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  const facts = [
    p.surface ? ['Surface', `${p.surface} m²`] : null,
    p.bedrooms != null ? ['Chambres', String(p.bedrooms)] : null,
    p.bathrooms != null ? ['Salles de bain', String(p.bathrooms)] : null,
    ['Type', PROPERTY_TYPES[p.propertyType]],
  ].filter(Boolean) as [string, string][];

  return (
    <View style={{ flex: 1 }}>
      <ScrollView contentContainerStyle={{ paddingBottom: 110 }}>
        <View>
          <FlatList
            data={p.images.length ? p.images : ['']}
            horizontal
            pagingEnabled
            showsHorizontalScrollIndicator={false}
            keyExtractor={(u, i) => `${i}`}
            onMomentumScrollEnd={(e) => setPage(Math.round(e.nativeEvent.contentOffset.x / W))}
            renderItem={({ item }) => (item ? <Image source={{ uri: item }} style={{ width: W, height: 280 }} />
              : <View style={{ width: W, height: 280, backgroundColor: colors.line }} />)}
          />
          {p.images.length > 1 && (
            <View style={s.counter}><Text style={{ color: 'white', fontWeight: '700' }}>{page + 1} / {p.images.length}</Text></View>
          )}
          <View style={{ position: 'absolute', top: 12, right: 12 }}><FavoriteButton property={p} size={22} /></View>
        </View>

        <View style={{ padding: 16 }}>
          <Text style={s.badge}>{TRANSACTION_LABELS[p.transactionType]}</Text>
          <Text style={s.price}>{formatPrice(p.price, p.currency, p.transactionType === 'rent')}</Text>
          <Text style={s.title}>{p.title}</Text>
          <Text style={s.muted}>📍 {[p.area, p.city, p.governorate].filter(Boolean).join(', ')}</Text>

          <View style={s.facts}>
            {facts.map(([k, v]) => (
              <View key={k} style={s.fact}><Text style={s.factValue}>{v}</Text><Text style={s.factKey}>{k}</Text></View>
            ))}
          </View>

          <Text style={s.h2}>Description</Text>
          <Text style={s.body}>{p.description}</Text>

          {p.amenities.length > 0 && (
            <>
              <Text style={s.h2}>Équipements</Text>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
                {p.amenities.map((a) => <Text key={a} style={s.amenity}>✓ {AMENITIES[a]}</Text>)}
              </View>
            </>
          )}

          {p.latitude != null && p.longitude != null && (
            <>
              <Text style={s.h2}>Localisation</Text>
              <MapView
                style={{ height: 200, borderRadius: 14 }}
                initialRegion={{ latitude: p.latitude, longitude: p.longitude, latitudeDelta: 0.03, longitudeDelta: 0.03 }}
                scrollEnabled={false}
              >
                <Marker coordinate={{ latitude: p.latitude, longitude: p.longitude }} title={p.title} />
              </MapView>
              <Button
                title="Itinéraire"
                variant="outline"
                style={{ marginTop: 10 }}
                onPress={() => Linking.openURL(`https://www.google.com/maps/search/?api=1&query=${p.latitude},${p.longitude}`)}
              />
            </>
          )}

          <Text style={s.h2}>Annonceur</Text>
          <Text style={s.body}>{p.ownerName || 'Annonceur'}{p.agentId ? ' · Agent immobilier' : ' · Propriétaire'}</Text>
          <Text style={[s.muted, { marginTop: 8 }]}>{p.views} vue{p.views > 1 ? 's' : ''} · {p.favoritesCount} favori{p.favoritesCount > 1 ? 's' : ''}</Text>
        </View>
      </ScrollView>

      {!mine && (
        <View style={s.bottom}>
          <Button title="Contacter l’annonceur" onPress={contact} loading={busy} />
        </View>
      )}
    </View>
  );
}

const s = StyleSheet.create({
  counter: { position: 'absolute', bottom: 12, right: 12, backgroundColor: 'rgba(0,0,0,0.55)', borderRadius: 12, paddingHorizontal: 10, paddingVertical: 4 },
  badge: { alignSelf: 'flex-start', backgroundColor: colors.primarySoft, color: colors.primary, fontWeight: '700', paddingHorizontal: 10, paddingVertical: 4, borderRadius: 8, overflow: 'hidden' },
  price: { fontSize: 24, fontWeight: '800', color: colors.primary, marginTop: 8 },
  title: { fontSize: 19, fontWeight: '700', color: colors.text, marginTop: 4 },
  muted: { color: colors.muted, marginTop: 4 },
  facts: { flexDirection: 'row', flexWrap: 'wrap', gap: 10, marginTop: 16 },
  fact: { backgroundColor: 'white', borderWidth: 1, borderColor: colors.line, borderRadius: 12, paddingVertical: 10, paddingHorizontal: 14, minWidth: 95 },
  factValue: { fontSize: 16, fontWeight: '800', color: colors.text },
  factKey: { fontSize: 12, color: colors.muted, marginTop: 2 },
  h2: { fontSize: 17, fontWeight: '700', color: colors.text, marginTop: 22, marginBottom: 8 },
  body: { fontSize: 15, color: colors.text, lineHeight: 22 },
  amenity: { backgroundColor: 'white', borderWidth: 1, borderColor: colors.line, borderRadius: 10, paddingHorizontal: 10, paddingVertical: 6, color: colors.text },
  bottom: { position: 'absolute', left: 0, right: 0, bottom: 0, padding: 16, paddingBottom: 26, backgroundColor: 'white', borderTopWidth: 1, borderColor: colors.line },
});
