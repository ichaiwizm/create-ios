# Create iOS — PLAN D'IMPLÉMENTATION natif

Plan d'exécution pour porter l'app web **Create** (`/root/apps/create/`) en natif iOS **SwiftUI**,
projet géré par **XcodeGen** (`project.yml`), **min iOS 17**, esthétique **Liquid Glass**
(vrai `.glassEffect()` sur iOS 26, fallback `.ultraThinMaterial` sur iOS 17), **light mode uniquement**.

Sources de vérité : `NATIVE_SPEC.md` (produit / backend / catalogue kie) et `DESIGN.md` (DA / tokens /
motion). Ce document décrit **comment on construit**, pas quoi (déjà spécifié).

**Stratégie backend retenue : A** — le client natif tape les routes `/api/*` existantes sur
`https://create.vpsdashboard.space` avec un **token Bearer PocketBase**. La clé kie, le rapatriement
média et l'auth admin restent côté serveur. Un seul patch serveur est requis (voir §11).

---

## 1. Arborescence de fichiers proposée

Racine existante : `/root/apps/create-ios/` (contient déjà `project.yml`, `Sources/Theme.swift`,
`fastlane/`, `.github/workflows/`). On étoffe `Sources/` en groupes logiques (XcodeGen crée les
groupes intermédiaires via `createIntermediateGroups: true`, donc l'arbo disque = arbo Xcode).

```
create-ios/
├── project.yml                      # XcodeGen (déjà là — à compléter §9)
├── Gemfile                          # fastlane (à copier depuis ios-template)
├── PLAN.md  NATIVE_SPEC.md  DESIGN.md
├── fastlane/                        # Appfile / Matchfile / Fastfile (scaffold §10)
├── .github/workflows/ios-release.yml
├── Resources/
│   ├── Fonts/                       # InstrumentSerif-Regular/Italic.ttf, Figtree-*.ttf (SIL OFL)
│   ├── Assets.xcassets/             # AppIcon, AccentColor, couleurs nommées aurora
│   └── noise@2x.png                 # grain fractal 128px (généré une fois, cache disque)
└── Sources/
    ├── App/
    │   ├── CreateApp.swift          # @main, WindowGroup, .preferredColorScheme(.light)
    │   ├── RootView.swift           # switch auth: Login vs MainTabView
    │   └── AppEnvironment.swift     # injection DI (Session, API, Stores) via @Environment
    ├── Design/                      # DESIGN.md → primitives
    │   ├── Theme.swift              # (existe) tokens couleur — à étendre (inkFaint, iris.text)
    │   ├── Color+Hex.swift          # init(hex:), Color nommées aurora
    │   ├── Typography.swift         # Font2.display/ui + échelle (Dynamic Type)
    │   ├── AuroraBackground.swift   # MeshGradient (iOS18+) / RadialGradient stack (iOS17) + grain
    │   ├── GlassSurface.swift       # ViewModifier .glassSurface(_:radius:) → glassEffect|material
    │   ├── SpecularBorder.swift     # liseré liquid-glass + inset highlight (fallback)
    │   ├── PressStyle.swift         # ButtonStyle scale 0.94
    │   ├── IrisButtonStyle.swift    # bouton d'action verre teinté iris (+ fallback)
    │   ├── Motion.swift             # springs nommés (rise/pop/lightbox), respect ReduceMotion
    │   ├── Shimmer.swift            # skeleton diagonal
    │   ├── ProgressLine.swift       # barre iris indéterminée
    │   └── Haptics.swift            # wrapper UIKit feedback (§8 DESIGN)
    ├── Models/
    │   ├── Generation.swift         # GenerationDTO + Status/Kind enums (§2)
    │   ├── ModelCatalog.swift       # ModelFamily / ParamSpec / ModelVariant / Tool + données (§5 SPEC)
    │   ├── CatalogLogic.swift       # buildOptions(), paramsFor(), resolveModelId(), settingsSummary()
    │   └── User.swift               # AuthRecord (id, email…)
    ├── Networking/
    │   ├── APIClient.swift          # actor: baseURL, bearer, request<T>, multipart, raw upload
    │   ├── Endpoints.swift          # enum des routes /api/* + décodage
    │   ├── PocketBaseAuth.swift     # login direct PB + auth-refresh
    │   ├── APIError.swift           # mapping 401/400/502 → messages FR
    │   └── DTOs.swift               # GenerateRequest, UploadResponse, CreditsResponse, Transcript…
    ├── State/
    │   ├── Session.swift            # @Observable: token (Keychain), user, isAuthenticated
    │   ├── KeychainStore.swift      # save/load/delete token
    │   ├── Preferences.swift        # @AppStorage: dernier modèle, variante, params, mode
    │   ├── GenerationsStore.swift   # @Observable: feed + galerie, poll 4s, cache
    │   ├── ComposerState.swift      # @Observable: prompt, refs[], family, params, uploading
    │   └── CreditsStore.swift       # @Observable: solde animé, refresh 45s + foreground
    ├── Features/
    │   ├── Login/LoginView.swift
    │   ├── Main/MainTabView.swift          # tab bar verre flottante (Créer/Galerie)
    │   ├── Header/AppHeader.swift          # logo + cloche + chip crédits
    │   ├── Create/
    │   │   ├── CreateView.swift            # feed inversé + composer
    │   │   ├── Feed/FeedList.swift
    │   │   ├── Feed/FeedCard.swift         # pending/done/failed/cancelled/empty
    │   │   ├── Feed/EmptyState.swift       # hero + 3 suggestions
    │   │   ├── Composer/ComposerView.swift
    │   │   ├── Composer/RefThumbRow.swift
    │   │   ├── Composer/ActionRow.swift    # photo/micro/modèle/réglages/générer
    │   │   └── Composer/MicButton.swift    # enregistrement + halo pulsant
    │   ├── Sheets/
    │   │   ├── ModelSheet.swift            # segment Image/Vidéo + familles
    │   │   └── SettingsSheet.swift         # généré depuis ParamSpec (chips)
    │   ├── Gallery/
    │   │   ├── GalleryView.swift           # LazyVGrid 2 col + pull-to-refresh + bandeau
    │   │   └── GalleryCard.swift
    │   ├── Lightbox/
    │   │   ├── LightboxView.swift          # fullScreenCover, swipe-down, matchedGeometry
    │   │   └── LightboxActions.swift       # partager/upscale/détourer/sauver/supprimer
    │   └── Notifications/NotifBell.swift   # états perm + toggle APNs
    ├── Services/
    │   ├── AudioRecorder.swift             # AVAudioRecorder → Data (m4a) pour /api/transcribe
    │   ├── MediaSaver.swift                # PHPhotoLibrary (image + vidéo)
    │   ├── ShareSheet.swift                # UIActivityViewController wrapper
    │   ├── ImageUploader.swift             # PhotosPicker → Data → /api/upload
    │   ├── PushManager.swift               # APNs register, deviceToken → backend (§11 push)
    │   └── VideoThumbPlayer.swift          # AVPlayer muet en boucle pour miniatures vidéo
    └── Support/
        ├── TimeAgo.swift                   # "il y a 2 min" (RelativeDateTimeFormatter, fr)
        ├── RemoteImage.swift              # AsyncImage + cache (thumb URLs PB)
        └── Toast.swift                     # overlay capsule glassStrong auto-dismiss
```

---

## 2. Modèles de données (structs)

### 2.1 Génération (miroir de `GenerationDTO`, SPEC §3)
```swift
enum GenKind: String, Codable { case image, video }
enum GenStatus: String, Codable { case pending, done, failed, cancelled }

struct Generation: Identifiable, Codable, Equatable {
    let id: String
    let kind: GenKind
    let model: String                 // slug kie: "nano-banana-pro", "veo3_fast"…
    let prompt: String
    let status: GenStatus
    let mediaUrls: [String]           // URLs fichiers PB (déjà rapatriés)
    let error: String?
    let creditsConsumed: Int?
    let created: Date                 // ISO8601 → Date
    // dérivés (non décodés): thumbFeedURL(_:), thumbGridURL, downloadURL, isVideo
}
// GET /api/generations → { "items": [Generation] }
```

### 2.2 Catalogue kie (miroir exact de `models.ts`, SPEC §5) — data-driven
```swift
enum ModelKind: String { case image, video }

struct ParamSpec: Identifiable {
    let field: String                 // clé envoyée à /api/generate options
    let label: String                 // "Format", "Résolution", "Durée", "Son"…
    let values: [String]
    let def: String
    var numeric = false               // → Int dans options
    var boolean = false               // → Bool dans options
    var boolLabels: [String]? = nil   // ["Avec son","Sans son"]
    var textOnly = false              // masqué en mode édition
    var id: String { field }
}

struct ModelVariant: Identifiable {   // Veo Fast/Quality
    let key, label, id: String        // id = slug kie
    let credits: Int
}

struct ModelFamily: Identifiable {
    let key: String                   // "nano-banana-pro"
    let kind: ModelKind
    let name, tagline: String
    let credits: String               // "~18-24"
    let textId, editId: String
    let imageField: String            // "image_input", "input_urls"…
    let imageIsList: Bool
    let maxImages: Int
    let params: [ParamSpec]
    var extraInput: [String: JSONValue] = [:]   // output_format, multi_shots…
    var variants: [ModelVariant]? = nil
    var id: String { key }
}

struct Tool { let key, id: String; let credits: Int; let rawInput: [String: JSONValue] }
```
`ModelCatalog.image` (3 familles) et `.video` (3 familles) + `.tools` (upscale, removeBg) recopient
**verbatim** les valeurs de SPEC §5 (nano-banana-pro / gpt-image-2 / seedream-5-pro ; veo3.1 /
kling-3.0 / seedance-2). `JSONValue` = petit enum codable (string/int/bool/array) pour `extraInput`.

### 2.3 Logique catalogue (`CatalogLogic.swift`, miroir de `buildInput`/`paramsFor`)
- `paramsFor(family, editing) -> [ParamSpec]` : filtre `textOnly` si édition.
- `resolveModelId(family, variant, refs) -> String` : variante Veo si présente ; sinon `editId` si
  `refs.nonEmpty && family éditable` ; sinon `textId`.
- `buildOptions(family, selections, editing) -> [String: JSONValue]` : pour chaque param visible,
  valeur choisie si dans `values` sinon `def`, convertie numeric/bool. **NB** : côté stratégie A, le
  serveur reconstruit déjà l'`input` kie depuis `options` — le client envoie juste
  `{ model, prompt, imageUrls, options }`. Le mapping `imageField`/`extraInput` reste serveur.
- `settingsSummary(family, selections) -> String` : ex. `"16:9 · 8s"` pour le label du bouton Réglages.

### 2.4 Auth / requêtes réseau
```swift
struct AuthRecord: Codable { let id, email: String }         // record PB
struct GenerateRequest: Encodable {                           // POST /api/generate (génération)
    let model, prompt: String
    let imageUrls: [String]?
    let options: [String: JSONValue]
}
struct ToolRequest: Encodable { let tool: String; let toolImageUrl: String }   // upscale/removeBg
struct GenerateResponse: Decodable { let id, taskId: String }
struct UploadResponse: Decodable { let url: String }
struct CreditsResponse: Decodable { let credits: Int }
struct TranscriptResponse: Decodable { let transcript: String }
```

---

## 3. Couche réseau

**`APIClient` (actor)** : base `https://create.vpsdashboard.space`, injecte
`Authorization: Bearer <token>` (lu depuis `Session`) sur toutes les routes user.
Méthodes génériques : `get<T:Decodable>`, `post<T>(_ body: Encodable)`, `delete`,
`postMultipart(file:Data, filename:, mime:)` (pour `/api/upload`), `postRaw(bytes:Data, mime:)`
(pour `/api/transcribe`, body binaire brut, Content-Type = mime audio). Décodage JSON avec
`.iso8601` pour `created`.

**Endpoints réutilisés (backend existant, SPEC §3)** :

| Méthode | Route | Usage natif |
|---|---|---|
| POST | `/api/generate` | `send()` (génération) + outils upscale/removeBg (lightbox) |
| GET | `/api/generations` | feed (`.prefix(12).reversed()`) + galerie (tout) |
| GET | `/api/generations/{id}` | poll 4s des `pending` (déclenche refresh serveur) |
| DELETE | `/api/generations/{id}` | suppression (lightbox) |
| POST | `/api/generations/{id}/cancel` | annulation carte pending |
| POST | `/api/upload` | multipart `file` (max 10 Mo) → URL kie temp |
| GET | `/api/credits` | chip crédits (45s + foreground) |
| POST | `/api/transcribe` | dictée : octets audio → `{ transcript }` |
| POST/DELETE | `/api/push/*` | remplacé par enregistrement token APNs (§11) |

**Auth (SPEC §4)** — token Bearer, pas cookie :
- Login : `POST https://pb-create.vpsdashboard.space/api/collections/users/auth-with-password`
  body `{ identity, password }` → `{ token, record }`. Token stocké **Keychain**.
- Refresh : `POST …/api/collections/users/auth-refresh` (Bearer) avant expiration JWT (~14 j) ;
  déclenché à l'ouverture d'app si token > 7 j, et sur tout `401` (un retry, sinon déconnexion).
- Erreurs : toute route user renvoie `401 {error:"Non authentifié"}` → `APIError.unauthorized`
  → tentative refresh, sinon `Session.logout()` → écran Login.

---

## 4. Gestion d'état

Approche : **Observation framework** (`@Observable`, iOS 17+) + injection par `@Environment`.
Pas de dépendance externe de state management.

- **`Session`** (`@Observable`) : `token`, `user`, `isAuthenticated`. Persiste le token en Keychain.
  Racine `RootView` observe `isAuthenticated` pour basculer Login ↔ MainTab.
- **`GenerationsStore`** (`@Observable`, source unique) : `items: [Generation]`. Expose `feed`
  (12 derniers inversés) et `all` (galerie). Actions : `load()`, `refresh()`, `poll()` (timer 4s
  qui `GET /api/generations/{id}` pour chaque `pending`, met à jour l'item, détecte transition
  pending→done/failed → haptique `success`/`error` **une seule fois** + éventuel `pop`), `cancel(id)`,
  `delete(id)`, `submit(...)`. Le store est partagé entre Créer et Galerie (même vérité).
- **`ComposerState`** (`@Observable`) : `prompt`, `refs: [String]` (URLs uploadées), `family`,
  `variant`, `selections: [field:String]`, `mode: ModelKind`, `editing` (dérivé refs+famille),
  `uploading`. `send()` : `resolveModelId` + `buildOptions` → `GenerationsStore.submit`.
- **`CreditsStore`** (`@Observable`) : `credits: Int`, animation d'incrément (interpolation 0.6s).
  `refresh()` toutes 45s (`Timer`) + sur `scenePhase == .active`.
- **`Preferences`** (`@AppStorage`) : dernier `familyKey`, `variantKey`, `selections` (JSON),
  `mode` — restaurés au lancement dans `ComposerState`.

Cycle de vie du polling : timers démarrés `onAppear` des écrans, invalidés `onDisappear` /
`scenePhase != .active`. En arrière-plan, on s'appuie sur le **push APNs** (§11) ; poll = fallback
premier-plan uniquement (comme le web).

---

## 5. Écrans & vues (DESIGN §4)

| # | Écran | Vues / composants | Points clés |
|---|---|---|---|
| 1 | **Login** | `LoginView` | carte `glassStrong`, champs capsule, bouton iris, erreur inline, PB direct → Keychain, haptique `success` |
| 2 | **Main** | `MainTabView` + `AppHeader` | tab bar verre flottante (`GlassEffectContainer` iOS26), 2 items, pastille iris active ; header logo + cloche + chip crédits |
| 3 | **Créer** | `CreateView` → `FeedList`/`FeedCard`/`EmptyState` + `ComposerView` (`RefThumbRow`, `ActionRow`, `MicButton`) | feed inversé collé au composer ; 12 derniers ; états pending/done/failed/cancelled ; empty = hero + 3 suggestions ; poll 4s |
| 4 | **Sheet Modèle** | `ModelSheet` | `presentationDetents([.medium,.large])`, segment Image/Vidéo, familles avec contour iris actif, re-clamp refs |
| 5 | **Sheet Réglages** | `SettingsSheet` | **générée depuis `ParamSpec`** : rangée par param, chips horizontales, boolLabels, suffixe `s` durée, mini-glyphe ratio (Path), variants Veo |
| 6 | **Galerie** | `GalleryView` → `GalleryCard` | `LazyVGrid` 2 col, `.refreshable`, bandeau "N en cours" + progress-line, poll 4s, tap done → Lightbox |
| 7 | **Lightbox** | `LightboxView` + `LightboxActions` | `fullScreenCover`, swipe-down (>110pt) dismiss, `matchedGeometryEffect` depuis vignette, image zoomable / `VideoPlayer`, actions partager/upscale/détourer/sauver/supprimer(double-tap) |
| 8 | **Notifs** | `NotifBell` | états unsupported/denied/available/subscribed, toggle APNs, sheet permission |

Composants transverses : `AuroraBackground` (racine, `.ignoresSafeArea`), `Toast` (overlay),
`RemoteImage` (thumbs PB avec `?thumb=…`), `Shimmer`, `ProgressLine`, `PressStyle`.

Rendu du verre : modificateur unique **`.glassSurface(_ level:, radius:)`** qui branche
`if #available(iOS 26)` → `.glassEffect(.regular…, in: .rect(cornerRadius:))` sinon
`.background(.ultraThinMaterial/.regularMaterial)` + `SpecularBorder` + inset highlight + ombre.
Respect `accessibilityReduceTransparency` → `Color.white.opacity(0.96)`. Cartes de listes
(feed/galerie) = `cardSolid` **sans** verre réfractif (perf scroll, DESIGN §1.4).

---

## 6. Services natifs (remplacements web → natif, SPEC §10)

- **Upload image** : `PhotosPicker` → `Data` → `ImageUploader` → `POST /api/upload` multipart.
  Désactivé si `refs.count >= family.maxImages`.
- **Dictée** : `AudioRecorder` (AVAudioRecorder, format m4a/AAC) → à l'arrêt, `Data` → `postRaw`
  vers `/api/transcribe` (Content-Type mime). Auto-stop 60s ; ignore si `< ~1.2 ko`. Halo rouge
  pulsant pendant l'enregistrement (`MicButton`, motion §6.4 DESIGN).
- **Partage** : `ShareSheet` (UIActivityViewController) sur le fichier média téléchargé.
- **Sauver** : `MediaSaver` (PHPhotoLibrary) — image et vidéo, depuis URL `?download=1`.
- **Miniature vidéo** : `VideoThumbPlayer` (AVPlayer muet, boucle) dans feed/galerie.
- **Push** : `PushManager` — `UNUserNotificationCenter` + APNs `registerForRemoteNotifications`,
  deviceToken → backend, deep-link `tag = generationId` → Galerie (§11).

---

## 7. Dépendances

**Aucune dépendance tierce Swift requise** (choix délibéré : tout est faisable avec SwiftUI +
AVFoundation + Photos + UserNotifications + Security/Keychain). Cela simplifie la CI (pas de
résolution SPM sur les runners).

Outils de build (hôte / CI) :
- **XcodeGen** (génère `Create.xcodeproj` depuis `project.yml`) — `brew install xcodegen`.
- **fastlane** (Gemfile) — build, signature `match`, upload TestFlight/App Store.
- **Xcode 16+** sur le runner (SDK iOS 18+, permet de compiler les branches `#available(iOS 26)`).

Ressources embarquées : polices **Instrument Serif** + **Figtree** (SIL OFL, libres) dans
`Resources/Fonts/` + déclaration `UIAppFonts` (Info plist via `INFOPLIST_KEY_*` ou `Info.plist`
custom). Fallback système New York / SF Pro si absentes.

---

## 8. Build, signature & CI

Le pipeline **existe déjà** dans `/root/.appstore` (template iOS autonome) :
- `ios-template/` : `Gemfile`, `fastlane/{Appfile,Matchfile,Fastfile}`, `.github/workflows/ios-release.yml`.
- `scaffold-ios-ci.sh <app_dir> <bundle_id> <scheme>` : copie + substitue `__BUNDLE_ID__` / `__SCHEME__`.
- `setup-ios-secrets.sh <owner/repo>` : injecte les secrets Apple/match dans le repo GitHub.

**Signature** : `fastlane match` (storage git `git@github.com:ichaiwizm/ios-signing.git`, type
`appstore`). Auth App Store Connect via **clé API .p8** (`AuthKey_25S93LUR8B.p8`,
`ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_P8_BASE64`). `CODE_SIGN_STYLE: Manual` + `DEVELOPMENT_TEAM`
déjà dans `project.yml`. Clé SSH deploy pour le repo de certs = secret `MATCH_DEPLOY_KEY`.

**Bundle / scheme** : `com.wizycode.create` / scheme `Create` (cohérent avec `project.yml` actuel).

**⚠ Adaptation CI requise (XcodeGen)** : le workflow et le Fastfile référencent
`Create.xcodeproj`, **non commité** (généré par XcodeGen). Il faut ajouter une étape
`xcodegen generate` **avant** fastlane. Deux options :
1. Étape workflow : après checkout, `brew install xcodegen && xcodegen generate` (recommandé,
   garde le repo propre — ajouter `*.xcodeproj/` au `.gitignore`).
2. Ou committer le `.xcodeproj` généré (plus simple mais bruit de diff).
→ **Option 1**. Ajouter au `ios-release.yml` (avant "Lancer fastlane") :
```yaml
- name: Générer le projet Xcode
  run: brew install xcodegen && xcodegen generate
```

**Étapes de mise en place** (une fois) :
```bash
# 1. Compléter fastlane/ + workflow depuis le template
/root/.appstore/scaffold-ios-ci.sh /root/apps/create-ios com.wizycode.create Create
# 2. Ajouter l'étape xcodegen au workflow (cf. ci-dessus)
# 3. Créer le repo GitHub, push
# 4. Injecter les secrets
/root/.appstore/setup-ios-secrets.sh <owner>/create-ios
# 5. Déclencher TestFlight
gh workflow run ios-release.yml --repo <owner>/create-ios -f lane=beta
```

**Build local (dev)** : `cd /root/apps/create-ios && xcodegen generate && open Create.xcodeproj`
(nécessite un Mac — le VPS Linux ne compile pas iOS ; itération sur machine macOS ou runner CI).

**Info.plist / capabilities** : micro déjà déclaré (`NSMicrophoneUsageDescription`). À ajouter :
`NSPhotoLibraryAddUsageDescription` (sauver dans Photos), `NSPhotoLibraryUsageDescription` (picker
si accès complet), **Push Notifications** capability + `UIBackgroundModes: remote-notification`,
`aps-environment` entitlement. Orientation portrait uniquement (déjà fixé).

---

## 9. Compléments `project.yml`

À ajouter au `project.yml` existant :
- `sources`: garder `Sources` + ajouter `Resources` (fonts, assets, noise).
- `INFOPLIST_KEY_UIAppFonts` (ou Info.plist custom listant les .ttf).
- `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription`, `…NSPhotoLibraryUsageDescription`.
- `entitlements` : `aps-environment: production` + capability Push.
- `INFOPLIST_KEY_UIBackgroundModes` : `remote-notification`.
- `MinimumOSVersion`/`deploymentTarget` : déjà `17.0`. Compiler avec Xcode 16 pour `#available(iOS 26)`.

---

## 10. Patch serveur requis (stratégie A) — SPEC §4

Un seul changement côté backend web `/root/apps/create/` pour débloquer le natif :
- **`src/lib/pocketbase/server.ts` (`getUser()`)** : si header `Authorization: Bearer <token>`
  présent, faire `pb.authStore.save(token)` + `authRefresh()` au lieu de lire le cookie `pb_auth`.
  Le même endpoint sert alors web (cookie) **et** natif (bearer). Sans ça, toutes les routes user
  renvoient 401 au client natif.
- **Push** : ajouter une table PB `apns_tokens` (`user`, `deviceToken`, `platform:"ios"`) + une route
  `POST /api/push/apns` (enregistre le token) ; dans `refreshGeneration` (`complete.ts`), en plus du
  web-push VAPID, envoyer un push **APNs** (titre "✨ Ta création est prête" / "❌ Génération échouée",
  corps = prompt tronqué 90 car, `tag = generationId`, deep-link galerie). Nécessite la clé APNs
  (déjà `.p8` App Store Connect ou clé APNs dédiée). **Non bloquant** pour un premier TestFlight :
  le poll premier-plan suffit à voir les résultats ; le push arrive au jalon M6.

---

## 11. Ordre de construction recommandé (jalons)

- **M0 — Fondations projet** : compléter `project.yml` (Resources, plist keys), `scaffold-ios-ci.sh`,
  Design system (`Theme` étendu, `Color+Hex`, `Typography`, `AuroraBackground`, `GlassSurface`,
  `PressStyle`, `IrisButtonStyle`, `Motion`, `Haptics`). Livrable : app blanche qui affiche l'aurora +
  un bouton iris. Build CI vert (TestFlight vide).
- **M1 — Auth** : `PocketBaseAuth`, `KeychainStore`, `Session`, `LoginView`, `RootView`. **+ patch
  serveur `getUser()` Bearer**. Livrable : login réel → token persistant → écran vide authentifié.
- **M2 — Réseau + Catalogue** : `APIClient`, `Endpoints`, `DTOs`, `Generation`, `ModelCatalog`
  (verbatim SPEC §5), `CatalogLogic`. Livrable : `GET /api/generations` + `/api/credits` fonctionnent.
- **M3 — Écran Créer (lecture)** : `MainTabView`, `AppHeader`, chip crédits animée, `FeedList`/
  `FeedCard` (tous états), `EmptyState`, `GenerationsStore` + poll 4s. Livrable : feed live des
  générations existantes, transitions pending→done visibles.
- **M4 — Composer + génération** : `ComposerView`, `ActionRow`, `RefThumbRow`, `ImageUploader`,
  `ModelSheet`, `SettingsSheet` (générée depuis ParamSpec), `Preferences`, `send()`. Livrable :
  créer une image/vidéo de bout en bout (texte + refs + réglages + Générer).
- **M5 — Galerie + Lightbox** : `GalleryView`/`GalleryCard`, `LightboxView`, `matchedGeometryEffect`,
  `ShareSheet`, `MediaSaver`, outils upscale/détourer, delete double-tap. Livrable : consultation,
  partage, sauvegarde photothèque, suppression.
- **M6 — Dictée + Push** : `AudioRecorder` → `/api/transcribe` ; `PushManager` + table `apns_tokens`
  + envoi serveur APNs + deep-link. Livrable : dictée vocale et notifications de fin de génération.
- **M7 — Finitions** : accessibilité (Reduce Motion/Transparency, Dynamic Type, VoiceOver), RTL,
  toasts, haptiques complètes, polices embarquées, AppIcon, grain aurora, QA sur iOS 17 réel +
  iOS 26. Livrable : build App Store `lane: release`.

Chaque jalon = build TestFlight vérifiable (`lane: beta`) ; M0/M1/M2 sortables en 1 passe, l'UI
lourde (M3–M5) est le gros du travail.
