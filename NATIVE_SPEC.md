# Create — Spécification NATIVE (iOS / Android)

Réimplémentation native de l'app web **Create** (`/root/apps/create/`), un studio mobile-first
de génération d'images & vidéos IA via **kie.ai**, avec backend **PocketBase** + routes Next.js
`/api/*`. Ce document est la source de vérité pour porter l'app en natif (SwiftUI / Jetpack Compose).

Le backend web existant (`create.vpsdashboard.space`) **reste réutilisable tel quel** : le client
natif peut taper directement les routes `/api/*` (elles gèrent auth, kie, rapatriement média, push).
Deux stratégies possibles, détaillées §3 :
- **A. Réutiliser le backend Next.js** (recommandé au départ) — le natif appelle `/api/*`.
- **B. Full-natif** — le natif parle directement à kie.ai + PocketBase (le backend Next disparaît).

Références de code (chemins absolus, à consulter) :
- Catalogue modèles : `/root/apps/create/src/lib/kie/models.ts`
- Client kie serveur : `/root/apps/create/src/lib/kie/client.ts`
- Rapatriement média + push : `/root/apps/create/src/lib/complete.ts`
- Routes API : `/root/apps/create/src/app/api/*`
- UI principale : `/root/apps/create/src/components/Studio.tsx`, `Lightbox.tsx`, `Gallery.tsx`
- Identité visuelle : `/root/apps/create/src/app/globals.css`

---

## 1. Vue d'ensemble produit

App perso mono-utilisateur (login obligatoire, inscription publique fermée). Interface **light mode
uniquement**, esthétique "liquid glass" iOS (verre dépoli, fond aurora, accent irisé violet→bleu→cyan).

Deux surfaces principales :
1. **Créer** (écran d'accueil) — composer type chat : prompt (texte + dictée vocale), images de
   référence, choix du modèle, réglages, bouton Générer. Feed inversé des dernières créations
   collé au composer (le plus récent en bas).
2. **Galerie** — grille 2 colonnes de toutes les créations, pull-to-refresh, lightbox plein écran
   avec partage natif, outils 1-clic (upscale / détourage), téléchargement, suppression.

Fonctions transverses : compteur de crédits kie animé, cloche de notifications push, retour
haptique, préférences persistées (dernier modèle/réglages), polling des générations en cours.

Flux fondamental d'une génération (asynchrone) :
```
prompt (+ images ref) → POST /api/generate → kie createTask → record PB "pending"
   ↓ (kie travaille 5 s à plusieurs min)
polling client GET /api/generations/{id}  ─┐
callback kie POST /api/callbacks/kie       ─┴→ refreshGeneration() :
   interroge kie → succès : télécharge les URLs kie (temporaires) → stocke dans PB media[]
   → statut "done" → push notification → feed rafraîchi
```

---

## 2. Écrans & flux détaillés

### 2.0 Navigation
- Onglets bas (tab bar) : **Créer** (icône étincelle) / **Galerie** (icône image). Barre en verre
  dépoli flottante, coins arrondis 1.5rem, safe-area bottom.
- Header haut sur les deux écrans : titre "Create." (serif, point en accent bleu) à gauche ;
  à droite cloche notifications + chip crédits.

### 2.1 Écran Login
- Affiché si non authentifié (redirection systématique). Carte en verre arrondie 2rem.
- Titre serif "Create." + sous-titre "Connecte-toi pour créer."
- Formulaire : champ **identifiant/email** (texte, autocap off), champ **mot de passe**,
  bouton "Se connecter" (btn-iris). Erreur inline "Identifiant ou mot de passe incorrect".
- Auth = `pb.collection('users').authWithPassword(identity, password)` (voir §4 auth native).
- Après succès : stocker le token, aller à l'écran Créer.

### 2.2 Écran Créer (le cœur — cf. `Studio.tsx`)

**Feed (haut, scrollable)** : liste inversée (plus ancien en haut, plus récent en bas, collée
au composer). Charge les 12 dernières générations via `GET /api/generations`, `.slice(0,12).reverse()`.
Chaque carte (`FeedCard`) fait ~72% de largeur, alignée à droite (bulle type chat sortante) :
- `pending` : carte shimmer + spinner + prompt tronqué + barre de progression indéterminée +
  bouton ✕ (annuler). Cliquer ✕ → `POST /api/generations/{id}/cancel`.
- `done` : miniature (image `?thumb=600x0` ou `<video>` muet) + prompt + timeAgo + crédits.
  Tap → ouvre la Lightbox.
- `failed` : carte rouge "Échec — {error}" + prompt, tap → réutilise le prompt (le remet dans le champ).
- `cancelled` : carte grisée "Annulée", tap → réutilise le prompt.
- État vide : titre serif « Qu'est-ce qu'on *crée* aujourd'hui ? » + 3 suggestions cliquables :
  - « Un logo minimaliste pour un café de quartier »
  - « Portrait studio d'un golden retriever, fond pastel »
  - « Une cuisine scandinave baignée de lumière du matin »

**Polling** : toutes les **4 s**, pour chaque génération `pending` du feed, `GET /api/generations/{id}`.
À la transition pending→done/failed : haptique succès + recharge le feed. (En natif : timer +
idéalement push pour réveiller ; garder le poll en fallback quand l'app est au premier plan.)

**Composer (bas, fixe)** — panneau verre dense arrondi 1.6rem :
1. **Miniatures des images de référence** (si présentes) : vignettes 56×56 avec bouton ✕, +
   badge "ÉDITION" (mode image) ou "IMAGE → VIDÉO" (mode vidéo).
2. **Zone de texte** auto-grow (max 150px), placeholder contextuel
   ("Décris ton image…" / "Décris ta vidéo…" / "Décris la retouche à faire…" en mode édition).
   Entrée = envoyer (sans shift).
3. **Rangée d'actions** :
   - Bouton **photo** (ajouter images ref) : ouvre picker, upload chaque fichier via `POST /api/upload`.
     Désactivé si `refs.length >= family.maxImages`.
   - Bouton **micro** (dictée) : voir §2.5.
   - Bouton **modèle** : label = `{nom} {variante?} · {credits}cr ▾`, ouvre la sheet Modèle.
   - Bouton **réglages** : label = résumé (ex. "16:9 · 8s ▾"), ouvre la sheet Réglages.
   - Bouton **Générer** (btn-iris rond, flèche ↑) : désactivé si prompt vide / en cours / upload en cours.

**Envoi** (`send()`) : résout le `modelId` (variante Veo choisie, sinon `editId` si images
présentes et famille éditable, sinon `textId`), puis `POST /api/generate` avec
`{ model, prompt, imageUrls: [...urls uploadées], options: {champ→valeur} }`. Sur succès : vide le
prompt, retire les refs, recharge le feed, scroll en bas.

**Sheet Modèle** (bottom sheet verre) :
- Segment Image / Vidéo en haut (change le mode ; re-clamp les refs au maxImages du nouveau modèle).
- Liste des familles du mode : nom + tagline + coût crédits. La famille active a un contour irisé.
  Sélection → ferme la sheet, clamp les refs.

**Sheet Réglages** (bottom sheet verre) — **générée dynamiquement depuis le catalogue** :
- Si la famille a des `variants` (Veo Fast/Quality) : rangée "Qualité" avec chips.
- Une rangée par `param` visible (`paramsFor(family, editing)`) : chips des valeurs `values`.
  Rendu spécial : booléens → `boolLabels`, "Durée" → suffixe `s`, "Format" → mini-icône ratio.
- Si aucun param : "Ce modèle n'a pas de réglages."

### 2.3 Écran Galerie (cf. `Gallery.tsx`)
- Grille 2 colonnes de **toutes** les générations (`GET /api/generations`, tri -created).
- Bandeau "N génération(s) en cours" + barre de progression si des `pending`.
- Pull-to-refresh (recharge). Poll 4 s identique au feed.
- Carte carrée : miniature `?thumb=600x600` (ou vidéo), prompt + modèle + timeAgo.
  `pending` = shimmer + ✕ annuler ; `failed` = message rouge ; `cancelled` = grisé "Annulée".
- Tap sur une carte `done` → Lightbox.

### 2.4 Lightbox / Visionneuse plein écran (cf. `Lightbox.tsx`)
- Overlay flouté plein écran, swipe-down pour fermer (drag > 110px).
- Média centré (image `object-contain` ou `<video controls autoPlay>`).
- Barre haut : bouton fermer + "{modèle} · {timeAgo} · {crédits}cr".
- Panneau actions bas (verre) :
  - Prompt (tap = copier).
  - Grille d'actions : **Partager** (partage natif de fichier), et pour les images **Upscale** +
    **Détourer** (appellent `POST /api/generate {tool, toolImageUrl}`), **Sauver** (télécharger `?download=1`).
  - Bouton **Supprimer** (double-tap de confirmation) → `DELETE /api/generations/{id}`.
- Natif : remplacer Web Share par le share sheet natif (UIActivityViewController / Android Intent
  ACTION_SEND), et "Sauver" par enregistrement dans la photothèque (PHPhotoLibrary / MediaStore).

### 2.5 Dictée vocale (cf. `MicButton.tsx`)
- Tap pour démarrer l'enregistrement micro, tap pour arrêter (auto-stop à 60 s).
- Halo rouge pulsant pendant l'enregistrement.
- À l'arrêt : envoyer l'audio brut à `POST /api/transcribe` (Content-Type = mime de l'audio) →
  reçoit `{ transcript }`, l'ajoute au prompt.
- Natif : AVAudioRecorder / MediaRecorder → POST des octets. Ignorer si < ~1.2 ko (tap accidentel).

### 2.6 Notifications push (cf. `NotifBell.tsx`, `push-client.ts`, `push.ts`)
- Cloche : toggle abonnement. États : unsupported / denied / available / subscribed.
- Web : VAPID + service worker. **Natif : remplacer par APNs (iOS) / FCM (Android)** — voir §7.
- À la complétion d'une génération, le serveur envoie un push :
  - titre "✨ Ta création est prête" (ou "❌ Génération échouée"), corps = prompt tronqué (90 car),
    `url: /gallery`, `tag: {generationId}`. Tap → ouvre la galerie.

---

## 3. Architecture backend & stratégie de portage

### Stratégie A — Réutiliser le backend Next.js (recommandé)
Le client natif appelle les routes `/api/*` existantes sur `https://create.vpsdashboard.space`.
Avantages : la clé kie, le rapatriement média, le push VAPID et l'auth admin PB restent côté serveur.
**Changement requis** : les routes lisent l'auth dans un **cookie** `pb_auth` (voir §4). Pour un
client natif, il faut soit (a) envoyer ce cookie manuellement, soit (b) modifier `getUser()` pour
accepter aussi un header `Authorization: Bearer <pb_token>`. Recommandation : patcher
`/root/apps/create/src/lib/pocketbase/server.ts` pour lire le token depuis `Authorization` **ou** cookie.

### Stratégie B — Full-natif (le backend Next disparaît)
Le natif parle directement à :
- **PocketBase** (`https://pb-create.vpsdashboard.space`) pour l'auth users + lecture des records
  `generations` (mais l'écriture des records exige le superuser — voir §6 : les règles interdisent
  create/update aux users). Il faudrait **assouplir les règles PB** ou garder un mini-backend.
- **kie.ai** directement (clé API dans l'app = **risque de sécurité**, déconseillé). 
- Le **rapatriement des médias** (URLs kie temporaires ~3 jours) et le **push serveur** deviennent
  problématiques sans backend. → **La stratégie A est fortement recommandée.**

Le reste de ce document décrit le backend tel qu'il existe (réutilisable en stratégie A) et donne
les détails kie bruts (pour une éventuelle stratégie B ou un backend réécrit).

### Endpoints `/api/*` réutilisables

| Méthode | Route | Rôle | Auth |
|---|---|---|---|
| POST | `/api/generate` | Lance une génération OU un outil (upscale/removeBg) | user |
| GET | `/api/generations` | Liste des générations de l'utilisateur (100 max, -created) | user |
| GET | `/api/generations/{id}` | Poll : interroge kie si pending, rapatrie les médias si succès | user |
| DELETE | `/api/generations/{id}` | Supprime une génération | user |
| POST | `/api/generations/{id}/cancel` | Annule (DELETE kie best-effort + statut cancelled) | user |
| POST | `/api/upload` | Upload image ref (multipart `file`, max 10 Mo) → URL temporaire kie | user |
| GET | `/api/credits` | Crédits kie restants (nombre) | user |
| POST | `/api/transcribe` | Audio brut (body binaire) → `{ transcript }` via Deepgram | user |
| POST/DELETE | `/api/push/subscribe` | Abonnement / désabonnement push (web VAPID) | user |
| POST | `/api/callbacks/kie` | Callback kie (appelé par kie, pas par le client) | public |

Toutes les routes user renvoient `401 {error:"Non authentifié"}` sans auth valide.

#### Formats de requête/réponse

**POST /api/generate**
```jsonc
// Requête (génération normale)
{ "model": "nano-banana-pro", "prompt": "…",
  "imageUrls": ["https://…kie-temp…"],          // optionnel (édition / i2v)
  "options": { "aspect_ratio": "1:1", "resolution": "2K" } }
// Requête (outil 1-clic)
{ "tool": "upscale", "toolImageUrl": "https://…" }   // ou "removeBg"
// Réponse 200
{ "id": "<pb_record_id>", "taskId": "<kie_task_id>" }
// Erreurs : 400 (modèle inconnu / prompt requis / …), 401, 502 (kie)
```

**GET /api/generations** → `{ "items": GenerationDTO[] }`
**GET /api/generations/{id}** → `GenerationDTO` (après tentative de refresh)
```jsonc
// GenerationDTO
{ "id": "…", "kind": "image|video", "model": "nano-banana-pro",
  "prompt": "…", "status": "pending|done|failed|cancelled",
  "mediaUrls": ["https://pb-create…/api/files/{collectionId}/{id}/{file}"],
  "error": "…?", "creditsConsumed": 42, "created": "2026-07-13T…Z" }
```

**POST /api/upload** (multipart, champ `file`) → `{ "url": "https://…kie-temp…" }`
**GET /api/credits** → `{ "credits": 12345 }`
**POST /api/transcribe** (body = octets audio, Content-Type = mime) → `{ "transcript": "…" }`

---

## 4. Auth PocketBase — token vs cookie

### Comment ça marche dans l'app web
- **Client** (`AuthForm`) : `pb.collection('users').authWithPassword(email, password)` contre
  `NEXT_PUBLIC_POCKETBASE_URL`. La lib PocketBase JS stocke le token dans `authStore`.
- Le token est **exporté en cookie** `pb_auth` (`authStore.exportToCookie`, httpOnly:false,
  sameSite:Lax) — cf. `pocketbase/client.ts`.
- **Serveur** (`getUser()` dans `pocketbase/server.ts`) : lit le cookie `pb_auth`, appelle
  `authStore.loadFromCookie('pb_auth=…')`, puis `authRefresh()` pour valider. Le middleware Next
  fait pareil et redirige vers `/login` si invalide.
- **Admin** (`pocketbase/admin.ts`) : côté serveur uniquement, `_superusers.authWithPassword`
  (env `POCKETBASE_ADMIN_EMAIL`/`PASSWORD`) — sert à écrire les records `generations` (les users
  n'ont pas le droit d'écrire, cf. règles §6).

### Recommandation NATIVE : **token Bearer, pas cookie**
Les clients natifs ne gèrent pas naturellement les cookies HTTP. Deux étapes :
1. **Login natif** : POST direct à PocketBase
   `POST https://pb-create.vpsdashboard.space/api/collections/users/auth-with-password`
   body `{ "identity": "<email>", "password": "<pwd>" }` → réponse `{ token, record }`.
   Stocker le `token` dans le **Keychain (iOS) / EncryptedSharedPreferences (Android)**.
2. **Appels API** : envoyer `Authorization: Bearer <token>`.
   → **Patch minimal côté serveur** : dans `getUser()`, si un header `Authorization: Bearer` est
   présent, faire `pb.authStore.save(token)` + `authRefresh()` au lieu de lire le cookie. Ainsi le
   même endpoint sert web (cookie) et natif (bearer). Le token PB est un JWT (~14 j de validité par
   défaut) ; rafraîchir via `POST /api/collections/users/auth-refresh` avant expiration.

Note : `authRefresh()` requiert que la collection `users` autorise l'auth (règle `authRule`).

---

## 5. Catalogue exact des modèles kie (source : `models.ts`)

Le catalogue est **data-driven** : chaque famille déclare ses vrais champs API (specs OpenAPI kie)
et le serveur construit l'`input` sans mapping en dur. **Répliquer cette structure en natif** (une
struct `ModelFamily` + `ParamSpec`) pour générer les sheets de réglages dynamiquement.

### Types
```
ModelKind = 'image' | 'video'
ParamSpec { field, label, values[], def, numeric?, boolean?, boolLabels?[2], textOnly? }
ModelVariant { key, label, id, credits }
ModelFamily { key, kind, name, tagline, credits, textId, editId,
              imageField, imageIsList, maxImages, params[], extraInput?, variants? }
```
Règles de construction de l'`input` (cf. `buildInput`) :
- Base `{ prompt }`, plus `extraInput` de la famille.
- Pour chaque param visible : valeur choisie si valide sinon `def` ; convertie en number si
  `numeric`, en bool si `boolean`.
- Si édition (variante edit + images présentes) : `input[imageField] = imageIsList ? urls.slice(0,maxImages) : urls[0]`.
- Sélection du slug : variante Veo si présente, sinon `editId` (édition), sinon `textId`.
- `paramsFor(family, editing)` masque les params `textOnly` en mode édition.

### IMAGE — 3 familles

**1. Nano Banana Pro** (`key: nano-banana-pro`) — "Détails fins · texte net" — ~18-24 cr — Gemini 3 Pro
- `textId` = `editId` = `nano-banana-pro` ; `imageField: image_input` (liste, **max 8**)
- `extraInput: { output_format: "png" }`
- params :
  - `aspect_ratio` (Format) : `1:1, 2:3, 3:2, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9, 21:9, auto` — def `1:1`
  - `resolution` (Résolution) : `1K, 2K, 4K` — def `1K`

**2. GPT Image 2** (`key: gpt-image-2`) — "Dernier OpenAI · très créatif" — ~15-40 cr
- `textId: gpt-image-2-text-to-image`, `editId: gpt-image-2-image-to-image`
- `imageField: input_urls` (liste, **max 16**)
- params :
  - `aspect_ratio` : `auto, 1:1, 3:2, 2:3, 4:3, 3:4, 5:4, 4:5, 16:9, 9:16, 21:9` — def `auto`
  - `resolution` : `1K, 2K, 4K` — def `1K`

**3. Seedream 5 Pro** (`key: seedream-5-pro`) — "Le meilleur de ByteDance" — ~15-25 cr
- `textId: seedream/5-pro-text-to-image`, `editId: seedream/5-pro-image-to-image`
- `imageField: image_urls` (liste, **max 10**)
- params :
  - `aspect_ratio` : `1:1, 4:3, 3:4, 16:9, 9:16, 2:3, 3:2` — def `1:1`
  - `quality` (Qualité) : `basic, high` — def `basic`

### VIDÉO — 3 familles

**1. Veo 3.1** (`key: veo3.1`) — "Google · le meilleur · audio natif" — ~80-300 cr
- Famille à **variants** (remplace textId/editId pour le slug) : Fast=`veo3_fast` (~80 cr),
  Quality=`veo3` (~300 cr). `textId/editId: veo3_fast`. `imageField: imageUrls` (liste, **max 3**).
- **⚠ API DÉDIÉE** : les modèles `veo3*` passent par `/api/v1/veo/generate` (pas `/jobs/createTask`).
  `isVeoModel(id) = id.startsWith('veo3')`.
- params :
  - `aspect_ratio` : `16:9, 9:16` — def `16:9`
  - `resolution` : `720p, 1080p` — def `720p`
  - `duration` (Durée) : `4, 6, 8` (numeric) — def `8`

**2. Kling 3.0** (`key: kling-3.0`) — "Dernier Kling · 3-15 s · son" — ~150-400 cr
- `textId` = `editId` = `kling-3.0/video` ; `imageField: image_urls` (liste, **max 2**)
- `extraInput: { multi_shots: false, multi_prompt: [] }` (**champs requis par l'API**)
- params :
  - `aspect_ratio` : `16:9, 9:16, 1:1` — def `16:9`
  - `mode` (Mode) : `std, pro, 4K` — def `pro`
  - `duration` : `3, 5, 8, 10, 15` — def `5`
  - `sound` (Son, boolean, boolLabels `["Avec son","Sans son"]`) : `true/false` — def `false`
- Testé ✅ : 42 cr en std 3 s.

**3. Seedance 2.0** (`key: seedance-2`) — "ByteDance · très bon rapport qualité/prix" — ~100-300 cr
- `textId` = `editId` = `bytedance/seedance-2` ; **i2v** : `imageField: first_frame_url` (**single**, non-liste, max 1)
- params :
  - `aspect_ratio` : `16:9, 9:16, 1:1, 4:3, 3:4, 21:9, adaptive` — def `16:9`
  - `resolution` : `480p, 720p, 1080p` — def `720p`
  - `duration` : `4, 5, 8, 10, 12` (numeric) — def `5`
  - `generate_audio` (Son, boolean, boolLabels `["Avec son","Sans son"]`) : `true/false` — def `true`

### Outils 1-clic (`TOOLS`)
- **upscale** : id `topaz/image-upscale` — ~4 cr — rawInput `{ image_url, upscale_factor: "2" }`
- **removeBg** (Détourer) : id `recraft/remove-background` — ~4 cr — rawInput `{ image: <url> }`

Coûts réels observés : nano-banana 4 cr, kling-3.0 std 3 s 42 cr, veo3_fast 4 s/720p ~60 cr.

---

## 6. Modèle de données PocketBase

Instance : `https://pb-create.vpsdashboard.space` (interne Docker `http://pocketbase-create:8090`).
Admin superuser : `admin@vpsdashboard.space` / `admin123456`. Compte app : `contact@phone.gs` / `admin123456`.

### Collection `users` (auth, standard PB)
- Inscription publique fermée (`createRule = null`) — comptes créés via l'admin PB.

### Collection `generations`
| Champ | Type | Notes |
|---|---|---|
| `user` | relation → users | propriétaire |
| `kind` | select | `image` \| `video` |
| `model` | text | slug kie (ex. `nano-banana-pro`, `veo3_fast`) |
| `prompt` | text | |
| `taskId` | text | id de tâche kie |
| `status` | select | `pending` \| `done` \| `failed` \| `cancelled` |
| `inputImages` | json | URLs des images de référence (temporaires kie) |
| `params` | json | options choisies + `{ tool }` |
| `media` | file (×6, 200 Mo) | fichiers rapatriés (jusqu'à 4 sauvegardés) |
| `error` | text | message d'échec |
| `creditsConsumed` | number | crédits kie consommés |
| `created` / `updated` | autodate | tri `-created` par défaut |

**Règles** : `list`/`view` = owner (`user = @request.auth.id`) ; `create`/`update`/`delete` = admin
seulement (le serveur écrit via `_superusers`). → En natif stratégie A, l'écriture passe par
`/api/generate` (qui utilise l'admin) ; le natif ne peut lire directement que ses propres records.

URL publique d'un fichier média :
`{NEXT_PUBLIC_POCKETBASE_URL}/api/files/{collectionId}/{recordId}/{filename}`
Suffixes utiles : `?thumb=600x600` (carré galerie), `?thumb=600x0` (largeur feed), `?download=1`.

### Collection `push_subs` (web push — à remplacer en natif par une table de tokens APNs/FCM)
| Champ | Type |
|---|---|
| `user` | relation → users |
| `endpoint` | text (unique logique) |
| `subscription` | json (PushSubscription) |

---

## 7. Détails kie.ai bruts (pour backend réutilisé ou réécrit)

Base API : `https://api.kie.ai`. Auth : header `Authorization: Bearer <KIE_API_KEY>`.
Upload : `https://kieai.redpandaai.co`. Enveloppe réponse : `{ code, msg, data }` (succès = `code 200`).

### Deux familles d'endpoints
**API unifiée "market"** (image + Kling + Seedance + outils) :
- Création : `POST /api/v1/jobs/createTask`
  body `{ model, input: {…}, callBackUrl }` → `data.taskId`
- Statut : `GET /api/v1/jobs/recordInfo?taskId=…`
  → `data.state` (`success|fail|<pending>`), `data.resultJson` (string JSON `{ resultUrls: [] }`),
  `data.creditsConsumed`, `data.failMsg`.

**API dédiée Veo** (modèles `veo3*`) :
- Création : `POST /api/v1/veo/generate`
  body `{ model, prompt, aspect_ratio (16:9|9:16), resolution (720p|1080p|4k), duration? (4|6|8),
  imageUrls? (max 3), callBackUrl }` → `data.taskId`. `generationType` auto-détecté selon présence
  d'`imageUrls`.
- Statut : `GET /api/v1/veo/record-info?taskId=…`
  → `data.successFlag` : `0/en cours` → pending, `1` → success (`response.resultUrls`),
  `2|3` → fail (`errorMessage`).

**Crédits** : `GET /api/v1/chat/credit` → `data` = nombre.
**Upload base64** : `POST /api/file-base64-upload` (host redpandaai)
  body `{ base64Data: "data:<mime>;base64,…", fileName, uploadPath: "create-app" }`
  → `data.fileUrl` (ou `downloadUrl`). **URLs temporaires ~3 jours.**
**Annulation** : `DELETE /api/v1/tasks/{taskId}` (best-effort ; tous les modèles ne le supportent pas).

### Callback kie
`callBackUrl` passé à la création → kie POST `{ taskId }` (ou `{ data: { taskId } }`) sur
`{APP_URL}/api/callbacks/kie` à la complétion. Le serveur **ne fait pas confiance au payload** :
il re-vérifie le statut via `getTaskStatus` (refreshGeneration).

### Rapatriement des médias (`refreshGeneration`, `complete.ts`) — CRITIQUE
Les URLs de résultat kie sont temporaires → dès succès, télécharger et stocker dans PB :
1. `getTaskStatus(taskId, model)` → si `pending`, ne rien faire.
2. Si `success` : pour chaque URL (max 4), `fetch(url)` → blob → FormData `media` avec extension
   (`mp4` pour vidéo, sinon type du blob, `jpeg`→`jpg`). Puis `generations.update(id, form)` avec
   `status: done` (+ `creditsConsumed`). Si 0 fichier sauvé → `status: failed`.
3. Si `fail` : `status: failed` + `error`.
4. Push notification à l'utilisateur (transition pending→done/failed).
Appelé par le **poll client** (`GET /api/generations/{id}`) ET le **callback kie**. Ne jamais
écraser un statut non-`pending` (protège les annulations).

### Polling — recommandation native
- App au premier plan : timer 4 s sur les générations `pending` (comme le web).
- App en arrière-plan : s'appuyer sur le **push** (APNs/FCM) déclenché par le backend à la
  complétion. Backend : après `refreshGeneration`, au lieu de web-push VAPID, envoyer un push
  natif (payload : titre, corps = prompt, deep-link vers galerie/génération, `tag = generationId`).

---

## 8. Identité visuelle (source : `globals.css`)

**Typographie** :
- Display (titres, hero) : **Instrument Serif** (400, normal + italic). Ex. "Create." avec point coloré,
  hero "Qu'est-ce qu'on *crée*…" (italique en dégradé iris).
- Body / UI : **Figtree** (sans-serif). `--font-display` / `--font-body`.

**Couleurs** :
- `--color-ink: #2a3142` (texte principal), `--color-ink-soft: #5d6478` (secondaire),
  `--color-accent: #2f6df6` (bleu accent, ponctuation).
- **Accent irisé** (dégradé signature, partout : boutons actifs, chips, barres de progression) :
  `linear-gradient(135deg, #8b5cf6, #3b82f6 55%, #22d3ee)` (violet → bleu → cyan).
  Variante texte (`.text-iris`) : `#7c3aed → #2563eb 55% → #06b6d4` en background-clip.

**Fond Aurora** (fixe, z-index -3, zéro animation pour perf) : superposition de radial-gradients
doux + base linéaire :
```
radial-gradient(60vmax at 12% 8%, rgba(167,139,250,0.4), transparent 65%),   // violet
radial-gradient(55vmax at 88% 92%, rgba(96,165,250,0.35), transparent 65%),  // bleu
radial-gradient(45vmax at 55% 40%, rgba(103,232,249,0.28), transparent 65%), // cyan
radial-gradient(40vmax at 85% 10%, rgba(147,197,253,0.3), transparent 65%),  // bleu clair
linear-gradient(165deg, #eef0fd 0%, #eaf2fc 45%, #eafaf9 100%)               // base
```
+ couche de grain SVG (opacity 0.04, mix-blend overlay).
Couleur de thème / status bar : `#eef0fd`. Background manifest : `#eef2fb`.

**Verre (glassmorphism)** — trois niveaux :
- `.glass` : `backdrop-filter: blur(12px) saturate(160%)`, fond `rgba(255,255,255,0.5)`,
  inset highlight blanc en haut, ombre portée `0 10px 36px rgba(25,32,46,0.18)`, liseré dégradé
  blanc façon "liquid glass" (bord qui accroche la lumière, via mask xor).
- `.glass-strong` : `blur(16px) saturate(170%)`, fond `rgba(255,255,255,0.72)` — barres, sheets, modales.
- `.card-solid` : aspect verre **sans backdrop-filter** (fluide au scroll) — cartes de listes/feed.
- `.glass-noise` : grain SVG sur les grands panneaux.
- Natif : reproduire avec `UIVisualEffectView`/`.ultraThinMaterial` (iOS) et blur + overlay
  translucide (Compose/`RenderEffect` Android). Toujours ombre douce + inset highlight blanc.

**Micro-interactions & animations** :
- `.press` : scale 0.94 à l'appui (feedback tactile visuel) sur tous les boutons.
- `.rise` (entrée cartes feed, translateY+fade), `.pop` (spring scale, badges/miniatures),
  `.sheet-up` (bottom sheet slide), `.fade-in`, `.shimmer` (skeleton loading),
  `.progress-line` (barre indéterminée dégradé iris), `.lightbox` (scale-in).
- `.mic-live` : halo rouge pulsant pendant l'enregistrement.
- **Haptique** (`haptics.ts`, à mapper sur UIImpactFeedbackGenerator / HapticFeedback) :
  `tap`=léger (boutons), `select`=changement modèle/toggle, `launch`=lancement génération,
  `success`=génération prête, `error`=échec/annulation.

**Formes** : coins très arrondis (bulles feed 3rem, composer/sheets 1.6-1.8rem, chips full-round,
boutons ronds 40-44px). Safe-areas respectées (env(safe-area-inset-*)).

**Règle absolue** : **LIGHT MODE uniquement**. Ne jamais implémenter de dark mode sauf demande explicite.

---

## 9. Variables d'environnement (backend, `docker-compose.yml` / `.env`)

| Var | Rôle |
|---|---|
| `NEXT_PUBLIC_POCKETBASE_URL` | URL PB externe (`https://pb-create.vpsdashboard.space`) — client + fichiers |
| `POCKETBASE_URL` | URL PB interne (`http://pocketbase-create:8090`) — admin serveur |
| `POCKETBASE_ADMIN_EMAIL` / `POCKETBASE_ADMIN_PASSWORD` | superuser PB (écriture records) |
| `KIE_API_URL` | `https://api.kie.ai` |
| `KIE_API_KEY` | clé kie (secret serveur, jamais exposée au client) |
| `KIE_UPLOAD_URL` | `https://kieai.redpandaai.co` (défaut) |
| `DEEPGRAM_API_KEY` | transcription vocale (Deepgram nova-3, `language=multi`) |
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` | web push (à remplacer par APNs/FCM en natif) |
| `NEXT_PUBLIC_VAPID_PUBLIC_KEY` | clé publique VAPID côté client |
| `APP_URL` | `https://create.vpsdashboard.space` — sert à construire le `callBackUrl` kie |

Deepgram : `POST https://api.deepgram.com/v1/listen?model=nova-3&language=multi&smart_format=true&punctuate=true`,
header `Authorization: Token <key>`, body = octets audio.

---

## 10. Checklist de portage natif

1. **Auth** : login PB direct → token Bearer stocké en Keychain/EncryptedSharedPreferences ;
   patch serveur `getUser()` pour accepter `Authorization: Bearer`.
2. **Catalogue modèles** : porter `ModelFamily`/`ParamSpec` en struct native ; générer les sheets
   de réglages dynamiquement (variants + params + boolLabels + icônes ratio).
3. **Écran Créer** : composer chat (texte auto-grow, dictée, images ref, sheets modèle/réglages),
   feed inversé, polling 4 s.
4. **Galerie** : grille 2 col, pull-to-refresh, poll, bandeau "en cours".
5. **Lightbox** : swipe-to-close, partage natif, outils upscale/removeBg, save photothèque, delete.
6. **Upload** : picker → `POST /api/upload` (multipart, max 10 Mo) → URL kie temporaire.
7. **Dictée** : enregistreur audio natif → `POST /api/transcribe`.
8. **Push** : remplacer VAPID par APNs (iOS) / FCM (Android) ; nouvelle table de tokens + envoi
   serveur dans `refreshGeneration` ; deep-link vers la galerie/génération.
9. **Crédits** : `GET /api/credits` toutes les ~45 s + au retour au premier plan, compteur animé.
10. **Identité visuelle** : light mode, aurora, verre (matériaux natifs), accent iris
    `#8b5cf6→#3b82f6→#22d3ee`, Instrument Serif + Figtree, haptique, coins très arrondis.
