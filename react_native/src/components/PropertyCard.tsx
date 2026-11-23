import { Image } from 'react-native';
import { useRouter } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { PROPERTY_TYPES, TRANSACTION_LABELS } from '../lib/constants';
import { formatPrice } from '../lib/format';
import { colors, radius } from '../lib/theme';
import type { Property } from '../lib/types';
import FavoriteButton from './FavoriteButton';

export default function PropertyCard({ property: p, badge }: { property: Property; badge?: string }) {
  const router = useRouter();
  return (
    <Pressable style={s.card} onPress={() => router.push(`/property/${p.id}`)}>
      <View>
        {p.images[0] ? <Image source={{ uri: p.images[0] }} style={s.img} /> : <View style={[s.img, { backgroundColor: colors.line }]} />}
        <View style={s.tag}><Text style={s.tagText}>{TRANSACTION_LABELS[p.transactionType]}</Text></View>
        {badge ? <View style={[s.tag, { left: undefined, right: 10, backgroundColor: colors.accent }]}><Text style={s.tagText}>{badge}</Text></View>
          : <View style={s.fav}><FavoriteButton property={p} /></View>}
      </View>
      <View style={{ padding: 12 }}>
        <Text style={s.price}>{formatPrice(p.price, p.currency, p.transactionType === 'rent')}</Text>
        <Text style={s.title} numberOfLines={1}>{p.title}</Text>
        <Text style={s.meta} numberOfLines={1}>
          {PROPERTY_TYPES[p.propertyType]} · {[p.city, p.governorate].filter(Boolean).join(', ')}
        </Text>
        <Text style={s.meta}>
          {[p.surface ? `${p.surface} m²` : null, p.bedrooms ? `${p.bedrooms} ch.` : null, p.bathrooms ? `${p.bathrooms} sdb` : null].filter(Boolean).join('  ·  ')}
        </Text>
      </View>
    </Pressable>
  );
}

const s = StyleSheet.create({
  card: { backgroundColor: colors.card, borderRadius: radius, marginBottom: 14, overflow: 'hidden', borderWidth: 1, borderColor: colors.line },
  img: { width: '100%', height: 190 },
  tag: { position: 'absolute', top: 10, left: 10, backgroundColor: colors.primary, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 4 },
  tagText: { color: 'white', fontWeight: '700', fontSize: 12 },
  fav: { position: 'absolute', top: 8, right: 8 },
  price: { fontSize: 18, fontWeight: '800', color: colors.primary },
  title: { fontSize: 15, fontWeight: '700', color: colors.text, marginTop: 2 },
  meta: { fontSize: 13, color: colors.muted, marginTop: 3 },
});
