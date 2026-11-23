// Copies the Firebase (web app) and Cloudinary values from the Flutter `.env`
// (one folder up) into `react_native/.env` with the EXPO_PUBLIC_ prefix.
// Both apps then use the SAME Firebase project and the SAME Cloudinary account.
const fs = require('fs');
const path = require('path');

const source = path.join(__dirname, '..', '..', '.env');
if (!fs.existsSync(source)) {
  console.error('Fichier introuvable : ' + source + '\nCopiez le .env de l’app Flutter à la racine du projet.');
  process.exit(1);
}
const values = {};
for (const line of fs.readFileSync(source, 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
  if (m) values[m[1]] = m[2].replace(/^['"]|['"]$/g, '');
}
const map = {
  EXPO_PUBLIC_FIREBASE_API_KEY: 'FIREBASE_WEB_API_KEY',
  EXPO_PUBLIC_FIREBASE_APP_ID: 'FIREBASE_WEB_APP_ID',
  EXPO_PUBLIC_FIREBASE_PROJECT_ID: 'FIREBASE_PROJECT_ID',
  EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN: 'FIREBASE_AUTH_DOMAIN',
  EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET: 'FIREBASE_STORAGE_BUCKET',
  EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID: 'FIREBASE_MESSAGING_SENDER_ID',
  EXPO_PUBLIC_CLOUDINARY_CLOUD_NAME: 'CLOUDINARY_CLOUD_NAME',
  EXPO_PUBLIC_CLOUDINARY_UPLOAD_PRESET: 'CLOUDINARY_UPLOAD_PRESET',
};
const missing = [];
const out = Object.entries(map).map(([to, from]) => {
  const v = values[from] || '';
  if (!v || v.startsWith('YOUR_')) missing.push(from);
  return `${to}=${v}`;
});
fs.writeFileSync(path.join(__dirname, '..', '.env'), out.join('\n') + '\n');
console.log(missing.length ? 'ATTENTION, valeurs manquantes : ' + missing.join(', ') : 'OK : react_native/.env créé.');
