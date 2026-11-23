import * as ImagePicker from 'expo-image-picker';
import * as Location from 'expo-location';
import { useRouter } from 'expo-router';
import { useState } from 'react';
import { Alert, Image, KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Button, Chip, Empty, Field } from '../components/ui';
import { useAuth } from '../lib/auth';
import { cloudinaryConfigured, uploadImage } from '../lib/cloudinary';
import {
  AMENITIES, GOVERNORATES, MAX_IMAGES, PROPERTY_TYPES, TRANSACTION_LABELS, TUNISIA_BOUNDS,
  type Amenity, type PropertyType, type TransactionType,
} from '../lib/constants';
import { errorMessage } from '../lib/format';
import { createListing, newListingId } from '../lib/properties';
import { colors } from '../lib/theme';

const toNumber = (t: string) => (t.trim() && !Number.isNaN(Number(t.replace(',', '.'))) ? Number(t.replace(',', '.')) : null);

export default function Publish() {
  const router = useRouter();
  const auth = useAuth();
  const [transactionType, setTransaction] = useState<TransactionType>('buy');
  const [propertyType, setType] = useState<PropertyType>('apartment');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [price, setPrice] = useState('');
  const [surface, setSurface] = useState('');
  const [bedrooms, setBedrooms] = useState('');
  const [bathrooms, setBathrooms] = useState('');
  const [governorate, setGovernorate] = useState<string>('Tunis');
  const [city, setCity] = useState('');
  const [area, setArea] = useState('');
  const [coords, setCoords] = useState<{ latitude: number; longitude: number } | null>(null);
  const [amenities, setAmenities] = useState<Amenity[]>([]);
  const [photos, setPhotos] = useState<string[]>([]);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [progress, setProgress] = useState<string | null>(null);

  if (!auth.user) {
    return <Empty title="Connectez-vous pour publier"
      action={<Button title="Se connecter" onPress={() => router.replace('/login')} style={{ alignSelf: 'stretch' }} />} />;
  }

  async function pickPhotos() {
    const left = MAX_IMAGES - photos.length;
    if (left <= 0) return;
    const res = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'], allowsMultipleSelection: true, selectionLimit: left, quality: 0.8,
    });
    if (!res.canceled) setPhotos((p) => [...p, ...res.assets.map((a) => a.uri)].slice(0, MAX_IMAGES));
  }

  async function takePhoto() {
    const perm = await ImagePicker.requestCameraPermissionsAsync();
    if (!perm.granted) return Alert.alert('Appareil photo', 'Autorisez l’appareil photo pour prendre une photo.');
    const res = await ImagePicker.launchCameraAsync({ mediaTypes: ['images'], quality: 0.8 });
    if (!res.canceled) setPhotos((p) => [...p, res.assets[0].uri].slice(0, MAX_IMAGES));
  }

  async function useMyPosition() {
    try {
      const perm = await Location.requestForegroundPermissionsAsync();
      if (perm.status !== 'granted') return Alert.alert('Position', 'Autorisez la localisation.');
      const pos = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.High });
      const { latitude, longitude } = pos.coords;
      const b = TUNISIA_BOUNDS;
      if (latitude < b.minLat || latitude > b.maxLat || longitude < b.minLng || longitude > b.maxLng) {
        return Alert.alert('Position', 'Votre position est hors de Tunisie : le bien doit être situé en Tunisie.');
      }
      setCoords({ latitude: Math.round(latitude * 1e6) / 1e6, longitude: Math.round(longitude * 1e6) / 1e6 });
    } catch {
      Alert.alert('Position', 'Position introuvable. Activez le GPS et réessayez.');
    }
  }

  /** Same limits as the Firestore rules (validListingContent). */
  function validate() {
    const e: Record<string, string> = {};
    const pr = toNumber(price);
    const su = toNumber(surface);
    const be = toNumber(bedrooms);
    const ba = toNumber(bathrooms);
    if (title.trim().length < 5 || title.length > 100) e.title = 'Titre : 5 à 100 caractères.';
    if (description.trim().length < 20 || description.length > 2000) e.description = 'Description : 20 à 2000 caractères.';
    if (pr == null || pr <= 0 || pr > 1e9) e.price = 'Prix invalide.';
    if (su == null || su <= 0 || su > 1e6) e.surface = 'Surface invalide.';
    if (be != null && (!Number.isInteger(be) || be < 0 || be > 20)) e.bedrooms = '0 à 20.';
    if (ba != null && (!Number.isInteger(ba) || ba < 0 || ba > 20)) e.bathrooms = '0 à 20.';
    if (!city.trim() || city.length > 80) e.city = 'Indiquez la ville.';
    if (area.length > 80) e.area = '80 caractères maximum.';
    if (photos.length < 1) e.photos = 'Ajoutez au moins une photo.';
    setErrors(e);
    return Object.keys(e).length === 0 ? { pr: pr!, su: su!, be, ba } : null;
  }

  async function submit() {
    const v = validate();
    if (!v) return Alert.alert('Annonce', 'Corrigez les champs en rouge.');
    if (!cloudinaryConfigured) return Alert.alert('Photos', 'Cloudinary n’est pas configuré (npm run env).');
    try {
      setProgress('Vérification du compte…');
      const role = await auth.ensurePublisherRole();
      const id = newListingId();
      const urls: string[] = [];
      for (let i = 0; i < photos.length; i++) {
        setProgress(`Envoi des photos ${i + 1} / ${photos.length}…`);
        urls.push(await uploadImage(photos[i], `properties/${id}`));
      }
      setProgress('Enregistrement de l’annonce…');
      await createListing(id, {
        title, description, transactionType, propertyType, price: v.pr, surface: v.su, bedrooms: v.be, bathrooms: v.ba,
        governorate, city, area, latitude: coords?.latitude ?? null, longitude: coords?.longitude ?? null, amenities,
      }, urls, { uid: auth.user!.uid, name: auth.displayName, role: role === 'agent' ? 'agent' : 'owner' });
      Alert.alert('Annonce envoyée', 'Votre annonce est en attente de validation par l’administrateur.');
      router.replace('/my-listings');
    } catch (e) {
      Alert.alert('Publication impossible', errorMessage(e));
    } finally {
      setProgress(null);
    }
  }

  const toggleAmenity = (a: Amenity) => setAmenities((x) => (x.includes(a) ? x.filter((y) => y !== a) : x.length < 10 ? [...x, a] : x));

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 40 }} keyboardShouldPersistTaps="handled">
        {!auth.user.emailVerified && (
          <Text style={s.warn}>Vérifiez d’abord votre e-mail (Profil &gt; « J’ai vérifié »), sinon la publication sera refusée.</Text>
        )}

        <Text style={s.h2}>Photos ({photos.length}/{MAX_IMAGES})</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          {photos.map((uri, i) => (
            <View key={uri + i} style={{ marginRight: 8 }}>
              <Image source={{ uri }} style={s.thumb} />
              {i === 0 && <Text style={s.cover}>Couverture</Text>}
              <Pressable style={s.remove} onPress={() => setPhotos((p) => p.filter((_, j) => j !== i))}><Text style={{ color: 'white', fontWeight: '800' }}>✕</Text></Pressable>
            </View>
          ))}
          {photos.length < MAX_IMAGES && (
            <>
              <Pressable style={[s.thumb, s.add]} onPress={pickPhotos}><Text style={s.addText}>＋{'\n'}Galerie</Text></Pressable>
              <Pressable style={[s.thumb, s.add]} onPress={takePhoto}><Text style={s.addText}>📷{'\n'}Photo</Text></Pressable>
            </>
          )}
        </ScrollView>
        {errors.photos ? <Text style={s.err}>{errors.photos}</Text> : null}

        <Text style={s.h2}>Type d’annonce</Text>
        <View style={s.wrap}>
          {(Object.keys(TRANSACTION_LABELS) as TransactionType[]).map((t) => (
            <Chip key={t} label={TRANSACTION_LABELS[t]} selected={transactionType === t} onPress={() => setTransaction(t)} />
          ))}
        </View>
        <Text style={s.h2}>Type de bien</Text>
        <View style={s.wrap}>
          {(Object.keys(PROPERTY_TYPES) as PropertyType[]).map((t) => (
            <Chip key={t} label={PROPERTY_TYPES[t]} selected={propertyType === t} onPress={() => setType(t)} />
          ))}
        </View>

        <Text style={s.h2}>Informations</Text>
        <Field label="Titre" value={title} onChangeText={setTitle} maxLength={100} placeholder="Ex. : Appartement S+2 lumineux à La Marsa" error={errors.title} />
        <Field label="Description" value={description} onChangeText={setDescription} maxLength={2000} multiline error={errors.description} />
        <View style={{ flexDirection: 'row', gap: 10 }}>
          <View style={{ flex: 1 }}><Field label={transactionType === 'rent' ? 'Loyer (TND / mois)' : 'Prix (TND)'} value={price} onChangeText={setPrice} keyboardType="numeric" error={errors.price} /></View>
          <View style={{ flex: 1 }}><Field label="Surface (m²)" value={surface} onChangeText={setSurface} keyboardType="numeric" error={errors.surface} /></View>
        </View>
        {propertyType !== 'land' && (
          <View style={{ flexDirection: 'row', gap: 10 }}>
            <View style={{ flex: 1 }}><Field label="Chambres" value={bedrooms} onChangeText={setBedrooms} keyboardType="number-pad" error={errors.bedrooms} /></View>
            <View style={{ flex: 1 }}><Field label="Salles de bain" value={bathrooms} onChangeText={setBathrooms} keyboardType="number-pad" error={errors.bathrooms} /></View>
          </View>
        )}

        <Text style={s.h2}>Localisation</Text>
        <Text style={s.label}>Gouvernorat</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 10 }}>
          {GOVERNORATES.map((g) => <Chip key={g} label={g} selected={governorate === g} onPress={() => setGovernorate(g)} />)}
        </ScrollView>
        <Field label="Ville" value={city} onChangeText={setCity} maxLength={80} error={errors.city} />
        <Field label="Quartier (facultatif)" value={area} onChangeText={setArea} maxLength={80} error={errors.area} />
        <Button title={coords ? `📍 Position enregistrée (${coords.latitude.toFixed(4)}, ${coords.longitude.toFixed(4)})` : '📍 Utiliser ma position (pour la carte)'}
          variant="outline" onPress={useMyPosition} />

        <Text style={s.h2}>Équipements</Text>
        <View style={s.wrap}>
          {(Object.keys(AMENITIES) as Amenity[]).map((a) => (
            <Chip key={a} label={AMENITIES[a]} selected={amenities.includes(a)} onPress={() => toggleAmenity(a)} />
          ))}
        </View>

        <Button title={progress ?? 'Envoyer pour validation'} onPress={submit} loading={!!progress} style={{ marginTop: 20 }} />
        {progress ? <Text style={{ textAlign: 'center', color: colors.muted, marginTop: 8 }}>{progress}</Text> : null}
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  h2: { fontSize: 16, fontWeight: '700', color: colors.text, marginTop: 18, marginBottom: 10 },
  label: { fontSize: 13, fontWeight: '600', color: colors.muted, marginBottom: 6 },
  wrap: { flexDirection: 'row', flexWrap: 'wrap' },
  thumb: { width: 96, height: 96, borderRadius: 12 },
  add: { borderWidth: 1.5, borderStyle: 'dashed', borderColor: colors.primary, alignItems: 'center', justifyContent: 'center', marginRight: 8, backgroundColor: 'white' },
  addText: { color: colors.primary, fontWeight: '700', textAlign: 'center' },
  cover: { position: 'absolute', bottom: 4, left: 4, backgroundColor: colors.primary, color: 'white', fontSize: 10, fontWeight: '700', paddingHorizontal: 6, borderRadius: 6, overflow: 'hidden' },
  remove: { position: 'absolute', top: 4, right: 4, backgroundColor: 'rgba(0,0,0,0.6)', width: 24, height: 24, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  err: { color: colors.danger, fontSize: 12, marginTop: 6 },
  warn: { backgroundColor: '#FFF6E5', borderColor: '#F3D39A', borderWidth: 1, borderRadius: 12, padding: 12, color: colors.text },
});
