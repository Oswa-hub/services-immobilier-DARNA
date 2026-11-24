# DARNA (ImmoFind)

Application mobile de **petites annonces immobilières en Tunisie** : publier un bien, le chercher (liste, filtres, carte),
le mettre en favori, contacter l'annonceur, faire vérifier son profil, signaler un contenu, et tout modérer depuis
un espace d'administration.

> Nom commercial : **DARNA**. Nom interne du projet (code, étude) : **ImmoFind**. Application mobile en français.

---

## Sommaire
1. [Fonctionnalités](#fonctionnalités)
2. [Rôles](#rôles)
3. [Stack technique](#stack-technique)
4. [Architecture du code](#architecture-du-code)
5. [Installation et configuration](#installation-et-configuration)
6. [Lancer l'application](#lancer-lapplication)
7. [Firebase : règles, index, fonctions](#firebase--règles-index-fonctions)
8. [Modèle de données (Firestore)](#modèle-de-données-firestore)
9. [Cycle de vie d'une annonce](#cycle-de-vie-dune-annonce)
10. [Tests](#tests)
11. [Équipe et dépôt](#équipe-et-dépôt)

---

## Fonctionnalités

| Module | Contenu | Dossier |
|---|---|---|
| 01 Authentification | Inscription, connexion (email / Google), vérification d'email, mot de passe oublié, statut de compte | `features/auth` |
| 02 Profil | Profil, édition, sécurité, accès aux espaces | `features/profile` |
| 03 Accueil | Recommandations, biens proches, raccourcis achat / location, carte d'aperçu | `features/property_discovery` |
| 04 Recherche | Recherche texte, filtres (type, prix, surface, pièces, localisation, équipements), liste / carte | `features/search` |
| 05 Fiche d'un bien | Galerie, caractéristiques, annonceur, équipements, localisation, biens similaires | `features/properties` |
| 06 Carte | Carte OpenStreetMap, marqueurs, regroupement, recherche dans la zone | `features/map` |
| 07 Favoris | Cœur sur les cartes et la fiche, liste des favoris | `features/favorites` |
| 08 Publication | Assistant en 7 étapes, upload des photos, création en modération, modification d'une annonce | `features/publishing` |
| 09 Mes annonces | Suivi des statuts, soumettre, retirer, modifier | `features/listings` |
| 10 Espace agent | Profil professionnel, tableau de bord, annonces, demandes reçues, statistiques | `features/agents` |
| 11 Messagerie | Conversations par annonce, chat, non lus | `features/messaging` |
| 12 Notifications | Centre de notifications, préférences, notifications push (FCM) | `features/notifications` |
| 13 Vérification | Demandes de vérification (utilisateur, propriétaire, agent, bien), file d'attente et décision admin | `features/verification` |
| 14 Signalements | Signaler une annonce / un utilisateur / un message, suivi par l'utilisateur, traitement admin | `features/reports` |
| 15-17 Administration | Tableau de bord, utilisateurs, annonces, signalements, notifications, analytics, journal d'audit, listes de contenu, réglages de la plateforme, pages légales | `features/admin`, `features/content`, `features/settings` |

---

## Rôles

Le rôle est stocké dans `users/{uid}.role`. Les `firestore.rules` appliquent les droits **côté serveur** ; l'application
adapte l'interface (boutons, écrans) mais ne remplace jamais les règles.

| | Visiteur | user | owner | agent | admin |
|---|:--:|:--:|:--:|:--:|:--:|
| Parcourir (accueil, recherche, carte, fiche) | oui | oui | oui | oui | oui |
| Favoris, messages, profil | non | oui | oui | oui | oui |
| Publier et gérer des annonces | non | non (bouton « Devenir propriétaire ») | oui | oui | oui |
| Espace agent (profil pro, stats, demandes) | non | non | non | oui | non |
| Modérer (annonces, utilisateurs, signalements, vérifications) | non | non | non | non | oui |

- **user** : rôle par défaut à l'inscription.
- **owner** : un `user` actif avec email vérifié peut se promouvoir lui-même (règle dédiée, uniquement `user -> owner`).
- **agent** : profil professionnel (agent ou agence) ; l'attribution du rôle est prévue côté serveur (voir `firestore.rules`).
- **admin** : attribué manuellement dans Firestore ; un admin ne peut pas modifier son propre rôle.

Publier exige un compte **actif** et un **email vérifié**.

---

## Stack technique

| Domaine | Technologies |
|---|---|
| Application | Flutter, Dart |
| État | Riverpod |
| Navigation | go_router |
| Backend | Firebase Authentication, Cloud Firestore, Cloud Functions (Node.js), Firebase Cloud Messaging |
| Médias | Cloudinary (envoi non signé, deux presets : public et vérification privée) |
| Cartes | flutter_map + latlong2 (tuiles OpenStreetMap par défaut) |
| Autres | image_picker, geolocator, google_sign_in, cached_network_image, flutter_dotenv, http |

---

## Architecture du code

Organisation **par fonctionnalité**, chaque module est découpé en couches :

```
lib/
├── main.dart                 démarrage : charge .env, initialise Firebase
├── firebase_options.dart     identifiants Firebase publics (lus depuis .env)
├── app/                      app.dart, router.dart, routes.dart, router_guard.dart, app_shell.dart (barre de navigation)
├── core/                     thème, erreurs, widgets communs, formats, constantes (gouvernorats), services (Cloudinary), config (Env)
├── dev/                      outil de données de démonstration (property_seeder.dart)
└── features/<module>/
    ├── domain/               entités, règles métier pures, cas d'usage, interfaces
    ├── data/                 accès Firestore / Cloudinary, mappers, implémentations
    ├── presentation/         pages, widgets, providers Riverpod
    └── providers/            (selon les modules)
```

Flux d'une action (exemple : publier) :
`écran (widget)` -> `controller Riverpod` -> `use case` -> `repository` -> `Firestore / Cloudinary`,
puis les **`firestore.rules`** valident l'écriture côté serveur.

Fichiers à connaître :
- `app/router.dart` + `app/routes.dart` : toutes les URLs et l'écran associé.
- `app/router_guard.dart` : qui a le droit d'aller où (visiteur, admin, compte bloqué).
- `features/auth/domain/entities/auth_user.dart` : rôles (`user`, `owner`, `agent`, `admin`) et statuts.
- `features/property_discovery/domain/publish_permission.dart` : qui peut publier.
- `core/config/env.dart` : toutes les variables d'environnement.

---

## Installation et configuration

**Prérequis** : Flutter (SDK Dart récent), un projet Firebase, un compte Cloudinary, Node.js (pour `functions/`), Firebase CLI.

```bash
git clone https://github.com/Oswa-hub/services-immobilier-DARNA.git
cd services-immobilier-DARNA
flutter pub get
```

### 1. Fichier `.env` (jamais commité)
Copier le modèle puis renseigner les valeurs :

```bash
cp .env.example .env        # Windows : copy .env.example .env
```

| Variable | Rôle |
|---|---|
| `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_UPLOAD_PRESET` | Envoi des photos d'annonces (preset **non signé**) |
| `CLOUDINARY_VERIFICATION_PRESET` | Documents de vérification (preset privé / authentifié) |
| `VERIFICATION_DOCUMENT_ENDPOINT` | URL de la Cloud Function qui donne accès aux documents privés (admin) |
| `MAP_TILE_URL` | Fournisseur de tuiles (vide = OpenStreetMap public, suffisant pour une démo) |
| `MAP_USER_AGENT_PACKAGE` | Identifiant de l'application pour le serveur de tuiles (par défaut `com.darna.app`) |
| `FIREBASE_*` | Identifiants Firebase publics (projet, clés par plateforme, ids d'application) |

> N'écrire **jamais** de secret (clé API Cloudinary secrète, compte de service) dans `.env` ni dans le dépôt.

### 2. Firebase
- Créer le projet Firebase et activer **Authentication** (email / mot de passe, Google) et **Cloud Firestore**.
- **Android** : placer `google-services.json` dans `android/app/` (fichier du projet Firebase, source de vérité pour `com.darna.app`).
- Pour Google Sign-In sur Android, enregistrer l'empreinte **SHA-1** de la clé de signature dans la console Firebase.
- Publier les règles et les index (voir section suivante).

### 3. Cloudinary
Créer les presets **non signés** (photos publiques ; documents de vérification en livraison *Authenticated*), puis reporter leurs noms dans `.env`.

---

## Lancer l'application

```bash
flutter run                 # appareil / émulateur connecté
flutter run -d chrome       # navigateur
flutter analyze             # analyse statique
flutter test                # tests
```

Premier test conseillé : créer un compte, vérifier l'email, parcourir l'accueil, puis tester la publication
(bouton « Devenir propriétaire » puis assistant de publication).

---

## Firebase : règles, index, fonctions

Les fichiers à la racine du dépôt :

| Fichier | Rôle | Déploiement |
|---|---|---|
| `firestore.rules` | Droits de lecture / écriture (sécurité côté serveur) | `firebase deploy --only firestore:rules` |
| `firestore.indexes.json` | Index nécessaires aux requêtes | `firebase deploy --only firestore:indexes` |
| `functions/` | Cloud Functions Node.js (notifications, etc.) | `firebase deploy --only functions` |
| `firebase.json`, `.firebaserc` | Configuration de la CLI Firebase | - |

**Important** : modifier `firestore.rules` dans le dépôt ne change rien en production tant qu'elles ne sont pas **publiées**
(CLI ci-dessus, ou console Firebase > Firestore > Règles > Publier). Sans cela, les écritures échouent avec `permission-denied`.

Règle d'or : un champ ajouté dans un document côté Flutter doit aussi être autorisé dans les règles correspondantes
(par exemple `validNewListing` pour les annonces), sinon la création est refusée.

---

## Modèle de données (Firestore)

| Collection | Contenu |
|---|---|
| `users/{uid}` (+ `blocked`, `devices`) | profil, **rôle**, statut, utilisateurs bloqués, jetons push |
| `properties/{id}` | annonces (statut, prix, localisation, images, équipements, propriétaire / agent) |
| `favorites/{uid_propertyId}` | un favori par document |
| `agent_profiles/{uid}` | profil professionnel de l'agent ou de l'agence |
| `verifications/{type_target}` (+ `history`) | demandes de vérification et historique |
| `conversations/{propertyId_uid}` (+ `messages`) | messagerie |
| `notifications` | notifications dans l'application |
| `reports` | signalements |
| `audit_logs` | journal des actions d'administration (ajout seul) |
| `property_stats`, `property_events` | statistiques et événements de vue |
| `catalog`, `settings` | listes de contenu et réglages gérés par l'admin |

---

## Cycle de vie d'une annonce

```
draft ──soumettre──> pending_review ──admin approuve──> published ──expiration──> expired
   ▲                      │                                  │
   │                      └──admin rejette──> rejected       └──admin──> suspended
   └────── modifier et renvoyer ──────────────┘
Le propriétaire / l'agent peut aussi retirer l'annonce (removed).
```

- Une nouvelle annonce est **toujours** créée en `pending_review` (imposé par les règles).
- Seules les annonces `published` sont visibles par tous, ajoutables aux favoris et contactables.
- Modifier le contenu d'une annonce la renvoie en modération.

---

## Tests

```bash
flutter test                              # tous les tests
flutter test test/features/publishing     # un module précis
```

Les tests des Cloud Functions se trouvent dans `functions/test/`.

---

## Équipe et dépôt

- Dépôt : `https://github.com/Oswa-hub/services-immobilier-DARNA`
- Dépôt d'origine de l'équipe : `https://github.com/yahyabenther/services-immobilier`
- Contributeurs : **Oswa-hub**, **yahyabenther**, **ayaesghuir**

Flux de travail : une branche par fonctionnalité (`feature/...`, `fix/...`), Pull Request vers la branche principale, relecture, fusion.

<!-- TODO : ajouter des captures d'écran (accueil, recherche, publication, administration) dans docs/screenshots/ -->
