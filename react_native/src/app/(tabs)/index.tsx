import { useRouter } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import { FlatList, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { Tabs } from 'expo-router';

import PropertyCard from '../../components/PropertyCard';
import { Chip, Empty, Loading } from '../../components/ui';
import { useAuth } from '../../lib/auth';
import { GOVERNORATES, PROPERTY_TYPES, TRANSACTION_LABELS, type PropertyType, type TransactionType } from '../../lib/constants';
import { errorMessage } from '../../lib/format';
import { watchNotifications } from '../../lib/notifications';
import { applyFilters, emptyFilters, watchPublished, type SearchFilters } from '../../lib/properties';
import { colors } from '../../lib/theme';
import type { Property } from '../../lib/types';

export default function HomeScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const [all, setAll] = useState<Property[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [f, setF] = useState<SearchFilters>(emptyFilters);
  const [showFilters, setShowFilters] = useState(false);
  const [minText, setMinText] = useState('');
  const [maxText, setMaxText] = useState('');
  const [unread, setUnread] = useState(0);

  useEffect(() => watchPublished((items) => { setAll(items); setError(null); }, (e) => setError(errorMessage(e))), []);
  useEffect(() => (user ? watchNotifications(user.uid, (n) => setUnread(n.filter((x) => !x.read).length)) : setUnread(0)), [user]);

  const results = useMemo(() => (all ? applyFilters(all, f) : []), [all, f]);
  const activeCount = [f.propertyType, f.governorate, f.minPrice, f.maxPrice].filter((x) => x != null).length;

  const setPrice = (min: string, max: string) => {
    const n = (t: string) => (t.trim() && !Number.isNaN(Number(t)) ? Number(t) : null);
    setF((x) => ({ ...x, minPrice: n(min), maxPrice: n(max) }));
  };

  return (
    <View style={{ flex: 1, backgroundColor: colors.background }}>
      <Tabs.Screen
        options={{
          headerRight: () => (
            <View style={{ flexDirection: 'row', gap: 14, marginRight: 14 }}>
              <Pressable onPress={() => router.push(user ? '/notifications' : '/login')} hitSlop={8}>
                <Text style={{ color: 'white', fontSize: 20 }}>🔔{unread ? <Text style={{ fontSize: 12 }}> {unread}</Text> : null}</Text>
              </Pressable>
              <Pressable onPress={() => router.push(user ? '/publish' : '/login')} hitSlop={8}>
                <Text style={{ color: 'white', fontSize: 15, fontWeight: '700' }}>＋ Publier</Text>
              </Pressable>
            </View>
          ),
        }}
      />
      <FlatList
        data={results}
        keyExtractor={(p) => p.id}
        contentContainerStyle={{ padding: 16, flexGrow: 1 }}
        renderItem={({ item }) => <PropertyCard property={item} />}
        ListHeaderComponent={
          <View>
            <TextInput
              placeholder="Rechercher : ville, quartier, titre…"
              placeholderTextColor={colors.muted}
              value={f.text}
              onChangeText={(text) => setF((x) => ({ ...x, text }))}
              style={s.search}
            />
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginTop: 10 }}>
              <Chip label="Tous" selected={!f.transactionType} onPress={() => setF((x) => ({ ...x, transactionType: null }))} />
              {(Object.keys(TRANSACTION_LABELS) as TransactionType[]).map((t) => (
                <Chip key={t} label={TRANSACTION_LABELS[t]} selected={f.transactionType === t}
                  onPress={() => setF((x) => ({ ...x, transactionType: x.transactionType === t ? null : t }))} />
              ))}
              <Chip label={`Filtres${activeCount ? ` (${activeCount})` : ''}`} selected={showFilters} onPress={() => setShowFilters((v) => !v)} />
            </View>

            {showFilters && (
              <View style={s.panel}>
                <Text style={s.label}>Type de bien</Text>
                <View style={s.wrap}>
                  {(Object.keys(PROPERTY_TYPES) as PropertyType[]).map((t) => (
                    <Chip key={t} label={PROPERTY_TYPES[t]} selected={f.propertyType === t}
                      onPress={() => setF((x) => ({ ...x, propertyType: x.propertyType === t ? null : t }))} />
                  ))}
                </View>
                <Text style={s.label}>Gouvernorat</Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 6 }}>
                  {GOVERNORATES.map((g) => (
                    <Chip key={g} label={g} selected={f.governorate === g}
                      onPress={() => setF((x) => ({ ...x, governorate: x.governorate === g ? null : g }))} />
                  ))}
                </ScrollView>
                <Text style={s.label}>Prix (TND)</Text>
                <View style={{ flexDirection: 'row', gap: 10 }}>
                  <TextInput placeholder="Min" keyboardType="numeric" value={minText} placeholderTextColor={colors.muted}
                    onChangeText={(t) => { setMinText(t); setPrice(t, maxText); }} style={[s.search, { flex: 1 }]} />
                  <TextInput placeholder="Max" keyboardType="numeric" value={maxText} placeholderTextColor={colors.muted}
                    onChangeText={(t) => { setMaxText(t); setPrice(minText, t); }} style={[s.search, { flex: 1 }]} />
                </View>
                <Pressable onPress={() => { setF(emptyFilters); setMinText(''); setMaxText(''); }} style={{ marginTop: 10 }}>
                  <Text style={{ color: colors.primary, fontWeight: '700' }}>Réinitialiser les filtres</Text>
                </Pressable>
              </View>
            )}
            {all && <Text style={s.count}>{results.length} bien{results.length > 1 ? 's' : ''} trouvé{results.length > 1 ? 's' : ''}</Text>}
          </View>
        }
        ListEmptyComponent={
          error ? <Empty title="Chargement impossible" message={error} />
            : !all ? <Loading />
              : <Empty title="Aucun bien trouvé" message="Modifiez vos filtres ou votre recherche." />
        }
      />
    </View>
  );
}

const s = StyleSheet.create({
  search: { backgroundColor: 'white', borderWidth: 1, borderColor: colors.line, borderRadius: 12, paddingHorizontal: 14, paddingVertical: 11, fontSize: 15, color: colors.text },
  panel: { backgroundColor: 'white', borderRadius: 14, borderWidth: 1, borderColor: colors.line, padding: 14, marginBottom: 10 },
  label: { fontSize: 13, fontWeight: '700', color: colors.muted, marginBottom: 8, marginTop: 4 },
  wrap: { flexDirection: 'row', flexWrap: 'wrap' },
  count: { color: colors.muted, marginBottom: 10, marginTop: 2, fontWeight: '600' },
});

