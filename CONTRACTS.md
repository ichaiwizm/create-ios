# Create iOS — CONTRACTS (vocabulaire partagé figé)

**Rôle de ce document** : c'est le **contrat d'interface** que TOUS les modules générés doivent
respecter **à la lettre**. Noms de types, de champs, de tokens, de méthodes, de propriétés :
rien ne s'invente, rien ne se renomme. Si un module a besoin d'un type/token absent d'ici, on
**complète d'abord ce fichier**, puis on code. En cas de divergence entre un module et ce document,
**ce document gagne**.

Cible : **SwiftUI · iOS 17 min** (compilé Xcode 16+ pour les branches `#available(iOS 26)`) ·
**Liquid Glass** natif iOS 26 avec **fallback** iOS 17 · **LIGHT MODE uniquement**.

Sources : `NATIVE_SPEC.md` (produit/backend/catalogue kie), `DESIGN.md` (DA/tokens/motion),
`PLAN.md` (arborescence/jalons). `Sources/Theme.swift` existant est **remplacé** par le
DesignSystem décrit en §2 (voir note de migration §2.0).

Conventions Swift :
- Les stores sont des `final class` annotées **`@Observable`** (Observation framework, iOS 17+),
  injectées via `.environment(_:)` et lues via `@Environment(Type.self)`.
- Tous les appels réseau sont **`async throws`**. Aucune dépendance tierce (SwiftUI + AVFoundation +
  Photos + UserNotifications + Security). Décodage JSON en `.iso8601` pour les dates.
- Namespacing : types de modèle/réseau au niveau global (pas de préfixe). Tokens couleur = extensions
  `Color`. Gradients = `enum Iris`. Rien dans un `enum Theme` (supprimé).

---

## 1. MODÈLES (structs Codable) — noms et champs figés

Fichier de rattachement indiqué entre parenthèses. **Ces noms et ces champs sont définitifs.**

### 1.1 Génération (`Models/Generation.swift`)

```swift
enum GenKind: String, Codable, Sendable { case image, video }
enum GenStatus: String, Codable, Sendable { case pending, done, failed, cancelled }

struct Generation: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let kind: GenKind
    let model: String            // slug kie: "nano-banana-pro", "veo3_fast"…
    let prompt: String
    let status: GenStatus
    let mediaUrls: [String]      // URLs fichiers PB déjà rapatriés
    let error: String?
    let creditsConsumed: Int?
    let created: Date            // décodé ISO8601
}
```

Dérivés **calculés** (extension, NON décodés — noms figés) :
```swift
extension Generation {
    var isVideo: Bool                      // kind == .video
    var firstMediaURL: URL?                // mediaUrls.first
    func thumbFeedURL() -> URL?            // firstMediaURL + "?thumb=600x0"
    var thumbGridURL: URL?                 // firstMediaURL + "?thumb=600x600"
    var downloadURL: URL?                  // firstMediaURL + "?download=1"
}
```
Réponse liste : `GET /api/generations` → `{ "items": [Generation] }` (voir `GenerationsListResponse` §3.5).

### 1.2 Catalogue kie — data-driven (`Models/ModelCatalog.swift`)

Miroir **verbatim** de `models.ts` (SPEC §5). Noms de types et de champs figés :

```swift
enum ModelKind: String, Sendable { case image, video }

struct ParamSpec: Identifiable, Hashable, Sendable {
    let field: String            // clé options envoyée à /api/generate
    let label: String            // "Format", "Résolution", "Durée", "Son"…
    let values: [String]
    let def: String
    var numeric: Bool = false     // → Int dans options
    var boolean: Bool = false     // → Bool dans options
    var boolLabels: [String]? = nil   // ex. ["Avec son","Sans son"]
    var textOnly: Bool = false    // masqué en mode édition
    var id: String { field }
}

struct ModelVariant: Identifiable, Hashable, Sendable {
    let key: String              // "fast" | "quality"
    let label: String            // "Rapide" | "Qualité"
    let id: String               // slug kie: "veo3_fast" | "veo3"
    let credits: Int
}

struct ModelFamily: Identifiable, Hashable, Sendable {
    let key: String              // "nano-banana-pro"
    let kind: ModelKind
    let name: String
    let tagline: String
    let credits: String          // libellé "~18-24"
    let textId: String           // slug texte→média
    let editId: String           // slug édition (i2i / i2v)
    let imageField: String       // "image_input", "input_urls", "first_frame_url"…
    let imageIsList: Bool
    let maxImages: Int
    let params: [ParamSpec]
    var extraInput: [String: JSONValue] = [:]
    var variants: [ModelVariant]? = nil
    var id: String { key }
}

struct Tool: Identifiable, Sendable {
    let key: String              // "upscale" | "removeBg"
    let id: String               // slug kie
    let credits: Int
    let rawInput: [String: JSONValue]
    var identityID: String { key }
}
```

Catalogue statique — **noms figés** :
```swift
enum ModelCatalog {
    static let image: [ModelFamily]   // 3 familles: nano-banana-pro, gpt-image-2, seedream-5-pro
    static let video: [ModelFamily]   // 3 familles: veo3.1, kling-3.0, seedance-2
    static let tools: [Tool]          // upscale, removeBg
    static func families(for kind: ModelKind) -> [ModelFamily]
    static func family(key: String) -> ModelFamily?
    static let defaultImageFamilyKey = "nano-banana-pro"
    static let defaultVideoFamilyKey = "veo3.1"
}
```
Valeurs recopiées verbatim de SPEC §5 (aspect_ratio/resolution/quality/mode/duration/sound/
generate_audio, defaults, maxImages, extraInput `output_format`/`multi_shots`/`multi_prompt`,
variants Veo Fast=`veo3_fast`/Quality=`veo3`).

### 1.3 Valeur JSON dynamique (`Models/JSONValue.swift`)

Un seul enum pour `options`, `extraInput`, `rawInput`. Nom et cas **figés** :
```swift
enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null
}
```
Encodable/Decodable transparent (encode la valeur brute, pas d'enveloppe). `options` d'une requête
= `[String: JSONValue]`.

### 1.4 Logique catalogue (`Models/CatalogLogic.swift`) — signatures figées

```swift
enum CatalogLogic {
    static func paramsFor(_ family: ModelFamily, editing: Bool) -> [ParamSpec]
    static func resolveModelId(family: ModelFamily,
                               variant: ModelVariant?,
                               hasRefs: Bool) -> String
    static func buildOptions(family: ModelFamily,
                             selections: [String: String],
                             editing: Bool) -> [String: JSONValue]
    static func settingsSummary(family: ModelFamily,
                                variant: ModelVariant?,
                                selections: [String: String]) -> String   // ex. "16:9 · 8s"
    static func modelButtonLabel(family: ModelFamily,
                                 variant: ModelVariant?) -> String        // ex. "Veo 3.1 Rapide · ~80cr"
}
```
`selections` = `[field: valeurChoisie]` (String brut, avant conversion numeric/bool par `buildOptions`).

### 1.5 Auth / user (`Models/User.swift`)

```swift
struct AuthRecord: Codable, Equatable, Sendable {
    let id: String
    let email: String
}
```

---

## 2. DESIGN SYSTEM — API figée (`Design/`)

### 2.0 Note de migration
`Sources/Theme.swift` (enum `Theme` avec `Theme.ink`, `Theme.iris`, `Theme.auroraBase`…) est
**abandonné**. On expose désormais : **tokens couleur en extension `Color`**, **gradients en `enum Iris`**,
**fond en `AuroraBackground`**, **verre via `.glassSurface(...)`**. Aucun module ne référence `Theme.*`.

### 2.1 Tokens couleur (`Design/Color+Hex.swift`)

Init hex figé + tokens nommés (noms figés) :
```swift
extension Color { init(hex: UInt32, alpha: Double = 1) }

extension Color {
    static let ink      = Color(hex: 0x2A3142)              // texte principal
    static let inkSoft  = Color(hex: 0x5D6478)              // secondaire / placeholders
    static let inkFaint = Color(hex: 0x2A3142, alpha: 0.35) // disabled
    static let accent   = Color(hex: 0x2F6DF6)              // point du logo, liens rares

    // Aurora (foyers pastel + base)
    static let auroraViolet   = Color(hex: 0xA78BFA, alpha: 0.40)
    static let auroraBlue     = Color(hex: 0x60A5FA, alpha: 0.35)
    static let auroraCyan     = Color(hex: 0x67E8F9, alpha: 0.28)
    static let auroraSkyLight = Color(hex: 0x93C5FD, alpha: 0.30)
    static let auroraBase     = Color(hex: 0xEEF0FD)        // base / status bar

    // États sémantiques
    static let dangerBg   = Color(hex: 0xFDECEC)            // fond carte failed
    static let danger     = Color(hex: 0xE03131)            // rouge (delete, mic, error)
    static let micGlowTop = Color(hex: 0xFF5D5D)            // dégradé mic actif
}
```

### 2.2 Gradients Iris (`Design/Color+Hex.swift` ou `Design/Iris.swift`)

Nom `Iris`, membres figés :
```swift
enum Iris {
    static let fill: LinearGradient   // #8B5CF6 → #3B82F6 @0.55 → #22D3EE, topLeading→bottomTrailing
    static let text: LinearGradient   // #7C3AED → #2563EB @0.55 → #06B6D4, topLeading→bottomTrailing
    static let shadow = Color(hex: 0x6366F1).opacity(0.45)   // ombre sous boutons d'action (r26 y+8)
}
```

### 2.3 Fond aurora (`Design/AuroraBackground.swift`)

```swift
struct AuroraBackground: View { }   // MeshGradient (iOS18+) sinon RadialGradient stack (iOS17)
                                    // + grain fractal opacity 0.04 blendMode .overlay, statique
```
Usage figé : posé à la racine avec `.ignoresSafeArea()`, sous tout le contenu. Ne s'anime pas.

### 2.4 Verre — modificateur unique (`Design/GlassSurface.swift`)

Niveaux figés + API unique. **Tous les modules passent par ça, jamais `.ultraThinMaterial` en direct.**
```swift
enum GlassLevel { case glass, strong, card }   // .glass / .glass-strong / .card-solid

extension View {
    /// Branche `.glassEffect(...)` (iOS 26) ou material+liserés (iOS 17), gère
    /// accessibilityReduceTransparency → Color.white.opacity(0.96).
    func glassSurface(_ level: GlassLevel, radius: CGFloat = 26) -> some View
}
```
Conventions d'emploi (figées, DESIGN §1.4) :
- `.strong` → nav, header, sheets, composer, barres lightbox, toasts.
- `.glass` → chips, petits panneaux, boutons ronds secondaires du composer, chip crédits.
- `.card` → **cartes répétées dans un scroll** (feed, galerie) — jamais de verre réfractif ici (perf).

Primitives internes (utilisées par `glassSurface`, pas appelées directement par les features) :
`SpecularBorder` (`Design/SpecularBorder.swift`), inset highlight top, ombre douce.

### 2.5 Typographie (`Design/Typography.swift`)

Nom `Font2`, API figée :
```swift
enum Font2 {
    static func display(_ size: CGFloat, italic: Bool = false) -> Font   // Instrument Serif → New York
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font  // Figtree → SF Pro
}
```
Échelle (helpers optionnels, mais tailles figées, DESIGN §3) : hero 34 / logo 26 / titre sheet 22 /
section-label 13·600 uppercase / corps 16 / bouton-chip 15·600 / meta 13·500 / badge 11·700 uppercase /
crédits 14·600 `.monospacedDigit()`.

### 2.6 Styles & modificateurs (noms figés)

```swift
struct PressStyle: ButtonStyle          // Design/PressStyle.swift — scale 0.94, .press
struct IrisButtonStyle: ButtonStyle     // Design/IrisButtonStyle.swift — verre teinté iris + fallback

extension View {
    func shimmer(active: Bool = true) -> some View   // Design/Shimmer.swift — skeleton diagonal
}
struct ProgressLine: View               // Design/ProgressLine.swift — barre iris indéterminée
```

### 2.7 Motion (`Design/Motion.swift`) — springs nommés figés

```swift
enum Motion {
    static let rise     = Animation.spring(response: 0.28, dampingFraction: 0.90)
    static let pop      = Animation.spring(response: 0.35, dampingFraction: 0.62)
    static let lightbox = Animation.spring(response: 0.30, dampingFraction: 0.80)
    static let sheetUp  = Animation.spring(response: 0.26, dampingFraction: 0.85)
    static let fade     = Animation.easeInOut(duration: 0.16)
    /// Renvoie l'animation, ou un fade quasi-instantané si Reduce Motion est actif.
    static func reduced(_ base: Animation, reduceMotion: Bool) -> Animation
}
```

### 2.8 Haptique (`Design/Haptics.swift`) — API figée

```swift
enum Haptic { case tap, select, launch, success, error }
enum Haptics {
    static func fire(_ h: Haptic)
    static func prepare(_ h: Haptic)   // pré-armement avant événement anticipé
}
```
Mapping figé (DESIGN §8) : tap=impact.light · select=selection · launch=impact.medium ·
success=notification.success · error=notification.error. Au plus **1 haptique par action** ;
un poll qui découvre plusieurs `done` ne déclenche qu'**un** `success`.

---

## 3. RÉSEAU — client & signatures figées (`Networking/`)

### 3.1 Constantes (`Networking/Endpoints.swift`)

```swift
enum API {
    static let appBase = URL(string: "https://create.vpsdashboard.space")!   // routes /api/*
    static let pbBase  = URL(string: "https://pb-create.vpsdashboard.space")! // auth PocketBase
}
```

Routes `/api/*` (relative à `appBase`) — figées, réutilisées du backend existant :

| Méthode | Route | Méthode client |
|---|---|---|
| POST | `/api/generate` | `generate(_:)` (génération) & `runTool(_:)` (outil) |
| GET | `/api/generations` | `generations()` |
| GET | `/api/generations/{id}` | `generation(id:)` |
| DELETE | `/api/generations/{id}` | `deleteGeneration(id:)` |
| POST | `/api/generations/{id}/cancel` | `cancel(id:)` |
| POST | `/api/upload` (multipart `file`) | `upload(fileData:filename:mime:)` |
| GET | `/api/credits` | `credits()` |
| POST | `/api/transcribe` (body binaire) | `transcribe(audio:mime:)` |
| POST | `/api/push/apns` (nouvelle, §M6) | `registerAPNs(deviceToken:)` |

### 3.2 Client applicatif (`Networking/APIClient.swift`)

`actor` figé. Injecte `Authorization: Bearer <token>` (lu depuis `Session`) sur toutes les routes user.
```swift
actor APIClient {
    init(session: Session)

    func generations() async throws -> [Generation]
    func generation(id: String) async throws -> Generation
    func generate(_ req: GenerateRequest) async throws -> GenerateResponse
    func runTool(_ req: ToolRequest) async throws -> GenerateResponse
    func cancel(id: String) async throws
    func deleteGeneration(id: String) async throws
    func upload(fileData: Data, filename: String, mime: String) async throws -> UploadResponse
    func credits() async throws -> CreditsResponse
    func transcribe(audio: Data, mime: String) async throws -> TranscriptResponse
    func registerAPNs(deviceToken: String) async throws
}
```
Comportement figé : sur `401`, tente **un** `authRefresh` puis rejoue la requête ; si toujours `401`
→ propage `APIError.unauthorized` (le caller appelle `Session.logout()`).

### 3.3 Auth PocketBase (`Networking/PocketBaseAuth.swift`)

Auth **directe** contre `pbBase`, token **Bearer** (pas cookie). Signatures figées :
```swift
struct AuthResult: Decodable, Sendable { let token: String; let record: AuthRecord }

struct PocketBaseAuth {
    init(base: URL = API.pbBase)
    // POST /api/collections/users/auth-with-password  body { identity, password }
    func authWithPassword(identity: String, password: String) async throws -> AuthResult
    // POST /api/collections/users/auth-refresh  (Bearer <token>)
    func authRefresh(token: String) async throws -> AuthResult
}
```

### 3.4 Erreurs (`Networking/APIError.swift`)

```swift
enum APIError: Error, Equatable {
    case unauthorized              // 401
    case badRequest(String)        // 400 (message serveur)
    case upstream(String)          // 502 kie
    case network(String)
    case decoding(String)
    var frenchMessage: String { get }   // message FR affichable
}
```

### 3.5 DTOs requête/réponse (`Networking/DTOs.swift`) — noms & champs figés

```swift
struct GenerateRequest: Encodable, Sendable {          // POST /api/generate (génération)
    let model: String
    let prompt: String
    let imageUrls: [String]?
    let options: [String: JSONValue]
}
struct ToolRequest: Encodable, Sendable {              // POST /api/generate (outil 1-clic)
    let tool: String            // "upscale" | "removeBg"
    let toolImageUrl: String
}
struct GenerateResponse: Decodable, Sendable { let id: String; let taskId: String }
struct GenerationsListResponse: Decodable, Sendable { let items: [Generation] }
struct UploadResponse: Decodable, Sendable { let url: String }
struct CreditsResponse: Decodable, Sendable { let credits: Int }
struct TranscriptResponse: Decodable, Sendable { let transcript: String }
```

---

## 4. STRUCTURE APP — entrée, navigation, stores (figées)

### 4.1 Entrée & racine (`App/`)

```swift
@main struct CreateApp: App    // App/CreateApp.swift — WindowGroup, .preferredColorScheme(.light),
                               // instancie les stores, les injecte via .environment(_:)
struct RootView: View          // App/RootView.swift — observe Session.isAuthenticated :
                               //   true → MainTabView ; false → LoginView. Fond = AuroraBackground.
```
Injection DI figée : stores passés par `.environment(session)`, `.environment(generations)`,
`.environment(composer)`, `.environment(credits)`, `.environment(preferences)`, `.environment(api)`.
Lecture dans les vues via `@Environment(Session.self) private var session` etc.
Pas de `AppEnvironment` conteneur : chaque store est injecté individuellement.

### 4.2 Navigation (`Features/Main/MainTabView.swift`)

```swift
enum AppTab: Hashable { case create, gallery }
struct MainTabView: View       // tab bar verre flottante custom (pas UITabBar) : Créer / Galerie,
                               // + AppHeader en overlay haut. @State selection: AppTab = .create
```
Sheets présentées par états locaux d'écran (enum), pas de router global :
```swift
enum ActiveSheet: Identifiable { case model, settings, notifPermission }   // Create/*
// Lightbox : présentée en fullScreenCover(item: $selectedGeneration)
```

### 4.3 Stores `@Observable` — noms de type & propriétés figés

**`Session`** (`State/Session.swift`) :
```swift
@Observable final class Session {
    private(set) var token: String?
    private(set) var user: AuthRecord?
    var isAuthenticated: Bool { token != nil }
    init()                                            // recharge le token depuis Keychain
    func login(identity: String, password: String) async throws
    func refreshIfNeeded() async
    func logout()
    func currentToken() -> String?                    // lu par APIClient
}
```

**`KeychainStore`** (`State/KeychainStore.swift`) :
```swift
enum KeychainStore {
    static func save(token: String)
    static func load() -> String?
    static func delete()
}
```

**`GenerationsStore`** (`State/GenerationsStore.swift`) — **source unique** partagée feed+galerie :
```swift
@Observable final class GenerationsStore {
    private(set) var items: [Generation] = []
    var feed: [Generation] { get }          // 12 derniers, ordre inversé (récent en bas)
    var all: [Generation] { get }           // tri -created, pour la galerie
    var pendingCount: Int { get }
    init(api: APIClient)
    func load() async
    func refresh() async
    func startPolling()                     // timer 4s sur les pending → generation(id:)
    func stopPolling()
    func submit(_ req: GenerateRequest) async throws
    func runTool(_ req: ToolRequest) async throws
    func cancel(id: String) async
    func delete(id: String) async
}
```
Transition `pending→done` = 1 haptique `success` (une seule fois) ; `pending→failed/cancelled` = `error`.

**`ComposerState`** (`State/ComposerState.swift`) :
```swift
@Observable final class ComposerState {
    var prompt: String = ""
    var refs: [String] = []                 // URLs uploadées (kie temp)
    var mode: ModelKind = .image
    var family: ModelFamily                 // défaut ModelCatalog.image[0]
    var variant: ModelVariant? = nil
    var selections: [String: String] = [:]  // [field: valeur]
    var uploading: Bool = false
    var editing: Bool { get }               // dérivé : !refs.isEmpty && famille éditable
    func send(using store: GenerationsStore) async throws
    func selectFamily(_ family: ModelFamily)     // re-clamp refs au maxImages
    func reuse(prompt: String)              // réinjection depuis carte failed/cancelled
}
```

**`CreditsStore`** (`State/CreditsStore.swift`) :
```swift
@Observable final class CreditsStore {
    private(set) var credits: Int = 0       // valeur cible
    var displayed: Int { get }              // valeur animée (interpolation 0.6s easeOut)
    init(api: APIClient)
    func refresh() async                    // GET /api/credits
    func startAutoRefresh()                 // 45s + scenePhase .active
    func stopAutoRefresh()
}
```

**`Preferences`** (`State/Preferences.swift`) — persistance `@AppStorage`, clés figées :
```swift
enum PrefKey {
    static let familyKey  = "pref.familyKey"
    static let variantKey = "pref.variantKey"
    static let selections = "pref.selections"   // JSON [field:String]
    static let mode       = "pref.mode"         // "image" | "video"
}
struct Preferences {
    static func restore(into composer: ComposerState)
    static func persist(from composer: ComposerState)
}
```

### 4.4 Services natifs (`Services/`) — noms de type figés

```swift
struct AudioRecorder                 // AVAudioRecorder m4a/AAC → Data ; auto-stop 60s ; ignore <1.2ko
enum   MediaSaver                    // PHPhotoLibrary : saveImage(url:) / saveVideo(url:)
struct ShareSheet: UIViewControllerRepresentable   // UIActivityViewController
struct ImageUploader                 // PhotosPicker Data → APIClient.upload → URL
final class PushManager: NSObject     // APNs register, deviceToken → registerAPNs, deep-link galerie
struct VideoThumbPlayer: View        // AVPlayer muet en boucle (miniatures vidéo)
```

### 4.5 Support (`Support/`) — figés

```swift
enum TimeAgo { static func string(from date: Date) -> String }   // "il y a 2 min", locale fr
struct RemoteImage: View             // AsyncImage + cache (init(url:contentMode:))
@Observable final class ToastCenter { func show(_ message: String, kind: ToastKind) }
enum ToastKind { case success, error }
struct Toast: View                   // capsule glassStrong auto-dismiss 2.5s
```

---

## 5. RÈGLES TRANSVERSES (non négociables)

1. **LIGHT MODE only** : `.preferredColorScheme(.light)` racine. Aucun code dark sans demande explicite.
2. **Verre** : uniquement via `.glassSurface(_:radius:)`. Cartes de scroll = `.card`. Respect
   `accessibilityReduceTransparency` (géré dans le modificateur).
3. **Iris rare** : réservé aux éléments actifs/d'action (Générer, chip active, progress-line, hero
   italique, point logo). Jamais une grande surface.
4. **Motion** via `enum Motion` + `Motion.reduced(_:reduceMotion:)`. Aurora **statique**.
5. **Haptique** via `Haptics.fire(_:)` uniquement, 1 par action utilisateur.
6. **Réseau** via `APIClient` (routes user) + `PocketBaseAuth` (login/refresh) ; jamais d'URL en dur
   ailleurs qu'`enum API` / `Endpoints`.
7. **Token** en Keychain via `KeychainStore` ; jamais en `UserDefaults`.
8. **Catalogue** = `ModelCatalog` verbatim SPEC §5 ; toute sheet Réglages se génère depuis `ParamSpec`
   (aucun réglage codé en dur par famille).
9. **Dates** décodées ISO8601 ; crédits affichés `.monospacedDigit()`.
10. **SF Symbols** figés (DESIGN §5) : sparkles/photo.on.rectangle/bell(.badge/.slash)/bolt.fill/
    photo.badge.plus/mic.fill/arrow.up/xmark/square.and.arrow.up/scissors/trash/arrow.down.to.line/
    chevron.down.

---

## 6. Dépendance serveur (rappel, hors app iOS)

Stratégie **A** : le natif tape `/api/*` existants avec Bearer PocketBase. **Un** patch serveur requis
avant M1 : `getUser()` (`/root/apps/create/src/lib/pocketbase/server.ts`) doit accepter
`Authorization: Bearer <token>` en plus du cookie. Push APNs (`/api/push/apns` + table `apns_tokens` +
envoi dans `refreshGeneration`) = jalon M6, non bloquant pour un premier TestFlight.
