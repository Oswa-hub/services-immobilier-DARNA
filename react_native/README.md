# DARNA — version React Native

Deuxième version de l’application DARNA, écrite en **React Native (Expo + TypeScript)**.
Elle utilise **le même backend** que la version Flutter : même projet Firebase (comptes, annonces,
messages, règles de sécurité) et même compte Cloudinary (photos). Une annonce publiée depuis
React Native est validée par l’administrateur dans l’app Flutter, puis visible dans les deux apps.

## Fonctionnalités
- Inscription / connexion (e-mail), vérification de l’e-mail, mot de passe oublié
- Accueil + recherche avec filtres (vente / location, type, gouvernorat, prix, texte)
- Détail d’un bien : galerie photos, caractéristiques, équipements, carte, itinéraire
- Publication d’une annonce : photos (galerie ou appareil photo) envoyées sur Cloudinary,
  position GPS, envoi en modération
- Carte des biens + « Autour de moi » (géolocalisation)
- Messagerie en temps réel avec l’annonceur, messages non lus
- Favoris, profil, mes annonces (statut, retrait)
- Notifications dans l’application (nouveau message, validation d’annonce)

## Lancer l’application
Prérequis : Node.js 20+ et l’application **Expo Go** sur le téléphone (Play Store).

```bash
cd react_native
npm install
npm run env        # copie la config Firebase / Cloudinary depuis le .env de l’app Flutter
npx expo start     # scanner le QR code avec Expo Go (même Wi-Fi que le PC)
```

Si le téléphone n’est pas sur le même réseau : `npx expo start --tunnel`.

## Architecture (même découpage que Flutter)
```
src/
  app/          écrans (Expo Router : un fichier = une route)
    (tabs)/     Accueil, Carte, Favoris, Messages, Profil
    property/   détail d’un bien
    chat/       conversation
    publish, login, register, notifications, my-listings
  components/   PropertyCard, FavoriteButton, composants UI
  lib/          accès aux données (Firestore, Auth, Cloudinary), types, constantes
```
- **Présentation** : `src/app`, `src/components`
- **État** : React hooks + `AuthProvider` (contexte)
- **Données** : `src/lib/*.ts` (mêmes collections et mêmes champs que Flutter ; les règles
  Firestore valident les deux apps de la même façon)

Vérification : `npx tsc --noEmit`.
