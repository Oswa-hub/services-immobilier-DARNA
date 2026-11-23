import { manipulateAsync, SaveFormat } from 'expo-image-manipulator';

const cloud = process.env.EXPO_PUBLIC_CLOUDINARY_CLOUD_NAME;
const preset = process.env.EXPO_PUBLIC_CLOUDINARY_UPLOAD_PRESET;

export const cloudinaryConfigured = Boolean(cloud && preset);

/** Resizes (max 1600 px, JPEG 75 %) then uploads with the unsigned preset. Returns the https URL. */
export async function uploadImage(uri: string, folder: string): Promise<string> {
  if (!cloudinaryConfigured) throw new Error('Cloudinary n’est pas configuré (fichier .env).');
  const small = await manipulateAsync(uri, [{ resize: { width: 1600 } }], { compress: 0.75, format: SaveFormat.JPEG });
  const form = new FormData();
  form.append('file', { uri: small.uri, name: 'photo.jpg', type: 'image/jpeg' } as unknown as Blob);
  form.append('upload_preset', preset as string);
  form.append('folder', folder);
  const res = await fetch(`https://api.cloudinary.com/v1_1/${cloud}/image/upload`, { method: 'POST', body: form });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || typeof body.secure_url !== 'string') {
    throw new Error(body?.error?.message ? `Envoi de la photo refusé : ${body.error.message}` : 'Envoi de la photo impossible.');
  }
  return body.secure_url;
}
