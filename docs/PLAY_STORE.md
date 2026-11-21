# DARNA — publication sur le Play Store

Identifiant : `com.darna.app` (définitif une fois publié). Version : `version:` dans
`pubspec.yaml` (`1.0.0+1` = nom 1.0.0, code 1). Chaque envoi au Play Store doit
avoir un code plus grand (`1.0.1+2`, ...).

## 1. Créer la clé d'envoi (une seule fois, à garder précieusement)

```powershell
keytool -genkey -v -keystore $HOME\darna-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias darna
```

Puis créer `android/key.properties` (ignoré par git, ne jamais l'envoyer sur GitHub) :

```
storePassword=LE_MOT_DE_PASSE
keyPassword=LE_MOT_DE_PASSE
keyAlias=darna
storeFile=C:\\Users\\pc2\\darna-upload.jks
```

Sans ce fichier, la version release est signée avec la clé de debug : bien pour tester,
refusé par le Play Store. Sauvegardez le `.jks` et le mot de passe hors du PC : si vous
les perdez, vous ne pourrez plus mettre l'application à jour.

## 2. Construire le paquet

```powershell
flutter clean
flutter build appbundle --release
```

Fichier : `build\app\outputs\bundle\release\app-release.aab`.

## 3. Google Play Console (compte développeur : 25 $ une fois)

1. Créer l'application : nom **DARNA**, langue français, application gratuite.
2. **Fiche du Store** : icône 512×512 (`docs/play_store_icon_512.png`), image de
   présentation 1024×500, au moins 2 captures d'écran du téléphone, description courte
   et complète.
3. **Règles de confidentialité** : une URL publique (une page web avec le texte de
   `/legal/privacy`).
4. **Sécurité des données** : l'app collecte e-mail, nom, téléphone, photos,
   position approximative (facultative), messages ; données chiffrées en transit ;
   l'utilisateur peut supprimer son compte (Profil > Supprimer mon compte).
5. **Suppression de compte** : indiquer le chemin dans l'app et une URL web
   (même page que la confidentialité, avec une adresse de contact).
6. **Classification du contenu**, **public cible** (18 ans et +), **annonces** : non.
7. **Tests** : un nouveau compte personnel doit d'abord faire un **test fermé avec
   12 testeurs pendant 14 jours** avant la production.
8. Envoyer `app-release.aab` dans une version de test, puis en production.

## 4. Connexion Google après publication

Le Play Store re-signe l'application avec sa propre clé. Dans Play Console >
**Intégrité de l'application**, copier le **SHA-1 de la clé de signature** et
l'ajouter dans Firebase (app `com.darna.app`), avec le SHA-1 de la clé d'envoi.
Puis télécharger le nouveau `google-services.json` dans `android/app/`.

## 5. Avant la mise en ligne

- `.env` : `MAP_TILE_URL` d'un fournisseur de cartes (MapTiler, Stadia) : les tuiles
  publiques OpenStreetMap sont interdites pour une application publiée.
- Cloudinary : limiter les presets (formats jpg/png/webp/pdf, taille max).
- Firebase : passer les règles en production (déjà faites) et vérifier qu'un compte
  admin existe.
