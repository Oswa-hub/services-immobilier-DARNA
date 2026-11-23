import * as Location from 'expo-location';
import { useRouter } from 'expo-router';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Alert, Pressable, StyleSheet, Text, View } from 'react-native';
import MapView, { Callout, Marker } from 'react-native-maps';

import { TUNISIA_REGION } from '../../lib/constants';
import { formatPrice } from '../../lib/format';
import { watchPublished } from '../../lib/properties';
import { colors } from '../../lib/theme';
import type { Property } from '../../lib/types';

export default function MapScreen() {
  const router = useRouter();
  const map = useRef<MapView>(null);
  const [items, setItems] = useState<Property[]>([]);
  const [locating, setLocating] = useState(false);

  useEffect(() => watchPublished(setItems, () => setItems([])), []);
  const located = useMemo(() => items.filter((p) => p.latitude != null && p.longitude != null), [items]);

  async function goToMe() {
    setLocating(true);
    try {
      const perm = await Location.requestForegroundPermissionsAsync();
      if (perm.status !== 'granted') {
        Alert.alert('Position', 'Autorisez la localisation pour voir les biens autour de vous.');
        return;
      }
      const pos = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced });
      map.current?.animateToRegion({
        latitude: pos.coords.latitude, longitude: pos.coords.longitude, latitudeDelta: 0.15, longitudeDelta: 0.15,
      }, 600);
    } catch {
      Alert.alert('Position', 'Position introuvable. Activez le GPS et réessayez.');
    } finally {
      setLocating(false);
    }
  }

  return (
    <View style={{ flex: 1 }}>
      <MapView ref={map} style={{ flex: 1 }} initialRegion={TUNISIA_REGION} showsUserLocation>
        {located.map((p) => (
          <Marker key={p.id} coordinate={{ latitude: p.latitude!, longitude: p.longitude! }} pinColor={colors.primary}>
            <Callout onPress={() => router.push(`/property/${p.id}`)}>
              <View style={{ maxWidth: 220, padding: 4 }}>
                <Text style={{ fontWeight: '800', color: colors.primary }}>{formatPrice(p.price, p.currency, p.transactionType === 'rent')}</Text>
                <Text numberOfLines={2} style={{ fontWeight: '600' }}>{p.title}</Text>
                <Text style={{ color: colors.muted, fontSize: 12, marginTop: 2 }}>Voir le détail ›</Text>
              </View>
            </Callout>
          </Marker>
        ))}
      </MapView>
      <View style={s.info}><Text style={{ fontWeight: '700', color: colors.text }}>{located.length} bien{located.length > 1 ? 's' : ''} sur la carte</Text></View>
      <Pressable style={s.me} onPress={goToMe} disabled={locating}>
        <Text style={{ color: 'white', fontWeight: '700' }}>{locating ? 'Localisation…' : '◎ Autour de moi'}</Text>
      </Pressable>
    </View>
  );
}

const s = StyleSheet.create({
  info: { position: 'absolute', top: 12, alignSelf: 'center', backgroundColor: 'white', borderRadius: 20, paddingHorizontal: 14, paddingVertical: 8, elevation: 3 },
  me: { position: 'absolute', bottom: 20, right: 16, backgroundColor: colors.primary, borderRadius: 24, paddingHorizontal: 18, paddingVertical: 12, elevation: 4 },
});
