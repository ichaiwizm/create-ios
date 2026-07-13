# Create iOS — Direction Artistique native

**App** : Create — studio mobile de génération d'images & vidéos IA (kie.ai).
**Cible** : iOS 26 (Liquid Glass natif via `.glassEffect()` / `GlassEffectContainer`), **fallback iOS 17**
(`.ultraThinMaterial` + overlays manuels).
**Langage** : SwiftUI (une seule base, adaptation par `if #available`).
**Règle absolue héritée du web** : **LIGHT MODE uniquement**. Le dark mode ne se code que sur demande
explicite (voir §7). Aucune interface ne part en sombre par défaut.

Ce document est la source de vérité visuelle du portage natif. Il reprend et traduit en primitives
SwiftUI l'identité web (`/root/apps/create/src/app/globals.css`) décrite dans `NATIVE_SPEC.md §8`.

---

## 0. Principe directeur

Une **feuille de verre irisée posée sur une aurore pastel**. Trois couches, jamais plus :

1. **Aurora** — fond fixe, mesh de violet → bleu → cyan sur base blanc-bleuté. Zéro animation (perf).
2. **Verre** — toutes les surfaces flottantes (nav, header, composer, sheets, cartes, lightbox).
   Sur iOS 26 = vrai Liquid Glass réfractif ; sur iOS 17 = matériau dépoli + liseré spéculaire simulé.
3. **Iris** — l'accent signature (dégradé violet→bleu→cyan) réservé aux éléments **actifs / d'action**
   (bouton Générer, chip sélectionnée, barre de progression, ponctuation du logo, hero italique).

L'iris est rare et précieux : il ne colore jamais une grande surface, seulement ce qui appelle au tap
ou signale l'état « vivant » d'une génération.

---

## 1. Tokens couleur

### 1.1 Encre (texte)
| Token | Hex | Usage |
|---|---|---|
| `ink` | `#2A3142` | Texte principal, titres, icônes actives |
| `inkSoft` | `#5D6478` | Texte secondaire, timeAgo, placeholders, icônes inactives |
| `inkFaint` | `rgba(42,49,66,0.35)` | Texte désactivé (label bouton disabled) |
| `accent` | `#2F6DF6` | Bleu de ponctuation (point du logo « Create. »), liens rares |

```swift
extension Color {
  static let ink      = Color(hex: 0x2A3142)
  static let inkSoft  = Color(hex: 0x5D6478)
  static let inkFaint = Color(hex: 0x2A3142).opacity(0.35)
  static let accent   = Color(hex: 0x2F6DF6)
}
```

### 1.2 Gradient Iris — l'accent signature
Deux variantes, exactement comme le web :

| Nom | Stops (angle 135°) | Usage |
|---|---|---|
| **Iris (fill)** | `#8B5CF6` → `#3B82F6` @55% → `#22D3EE` | Boutons, chips, barres, halos |
| **Iris (text)** | `#7C3AED` → `#2563EB` @55% → `#06B6D4` | Texte en dégradé (hero italique, `.text-iris`) |

```swift
enum Iris {
  static let fill = LinearGradient(
    stops: [.init(color: Color(hex: 0x8B5CF6), location: 0),
            .init(color: Color(hex: 0x3B82F6), location: 0.55),
            .init(color: Color(hex: 0x22D3EE), location: 1)],
    startPoint: .topLeading, endPoint: .bottomTrailing)

  static let text = LinearGradient(
    stops: [.init(color: Color(hex: 0x7C3AED), location: 0),
            .init(color: Color(hex: 0x2563EB), location: 0.55),
            .init(color: Color(hex: 0x06B6D4), location: 1)],
    startPoint: .topLeading, endPoint: .bottomTrailing)
}
```
Ombre portée iris (sous les boutons d'action) : `Color(0x6366F1).opacity(0.45)`, rayon 26, y +8.

### 1.3 Aurora (fond) — MeshGradient
iOS 18+ : `MeshGradient` natif. iOS 17 : superposition de `RadialGradient` (mêmes stops).
Le web pose 4 radiaux pastel sur une base linéaire ; on reproduit chaque foyer :

| Foyer | Couleur | Position (x,y) | Rayon |
|---|---|---|---|
| Violet | `rgba(167,139,250,0.40)` | 12% / 8% | 60% |
| Bleu | `rgba(96,165,250,0.35)` | 88% / 92% | 55% |
| Cyan | `rgba(103,232,249,0.28)` | 55% / 40% | 45% |
| Bleu clair | `rgba(147,197,253,0.30)` | 85% / 10% | 40% |
| **Base** | linéaire 165° `#EEF0FD` → `#EAF2FC` @45% → `#EAFAF9` | — | — |

```swift
// iOS 18+ : grille 3×3, couleurs coins/centre reprenant les foyers ci-dessus.
MeshGradient(width: 3, height: 3,
  points: [[0,0],[0.5,0],[1,0],[0,0.5],[0.5,0.4],[1,0.5],[0,1],[0.5,1],[1,1]],
  colors: [.auroraViolet, .auroraSkyLight, .auroraSkyLight,
           .auroraBase,   .auroraCyan,     .auroraBlue,
           .auroraBase,   .auroraBase,     .auroraCyan])
.ignoresSafeArea()
```
- **Statique** : ne pas animer les points (fidélité au web « zéro coût GPU »). Une dérive **très** lente
  (±0.02 sur 2-3 points, période 20 s, `easeInOut`) est tolérée uniquement si `Reduce Motion` est off ;
  par défaut, figé.
- **Grain** : overlay `Image` de bruit fractal (tuile 128px) à `opacity 0.04`, `blendMode(.overlay)`,
  `.allowsHitTesting(false)`, au-dessus de l'aurora et sous le contenu. Générable une fois via
  `CIRandomGenerator` mis en cache.
- **Barre de statut / status bar** : teinte `#EEF0FD`, `.preferredColorScheme(.light)` forcé.

### 1.4 Verre — tokens de matériau
| Niveau | Web équiv. | Fond blanc | Blur | Usage |
|---|---|---|---|---|
| `glass` | `.glass` | `rgba(255,255,255,0.50)` | 12px sat 160% | Cartes flottantes, chips, petits panneaux |
| `glassStrong` | `.glass-strong` | `rgba(255,255,255,0.72)` | 16px sat 170% | Nav, header, sheets, composer, lightbox bars |
| `cardSolid` | `.card-solid` | `rgba(255,255,255,0.55)` **sans blur** | — | **Cartes répétées dans un scroll** (feed, galerie) |

- **Highlight interne (inset top)** : liseré blanc `rgba(255,255,255,0.95)` de 1px en haut de chaque
  surface verre → l'arête qui « accroche la lumière ».
- **Ombre douce** : `rgba(25,32,46,0.18)`, rayon 36, y +10 (glass) / rayon 40 (glassStrong) ;
  `cardSolid` = ombre plus discrète `rgba(25,32,46,0.10)` rayon 22 y +6.
- **Liseré liquid-glass** : bord dégradé 135° blanc `0.95 → 0.25 → 0.08 → 0.60` (1px), simulé en
  fallback par un `.overlay(RoundedRectangle().strokeBorder(gradient, lineWidth: 1))`.

> **Perf critique (repris du web)** : les cartes d'un flux scrollable utilisent `cardSolid` (pas de
> `backdrop-filter`/`glassEffect` réfractif) — sinon jank au scroll. Réserver le vrai verre réfractif
> aux **petites surfaces persistantes** (nav, chips, header, boutons du composer).

---

## 2. Implémentation du verre : iOS 26 vs iOS 17

### iOS 26 — Liquid Glass natif
```swift
// Petites surfaces : vrai Liquid Glass réfractif + teinte + interactivité.
someView
  .glassEffect(.regular.tint(.white.opacity(0.12)).interactive(),
               in: .rect(cornerRadius: 26))

// Bouton d'action (Générer) : verre teinté iris.
Button { … } label: { Image(systemName: "arrow.up") }
  .buttonStyle(.glass)              // iOS 26
  .tint(Color(hex: 0x3B82F6))

// Regrouper les surfaces verre voisines pour la fusion/morph fluide :
GlassEffectContainer(spacing: 12) { nav-items… }
```
- Utiliser `GlassEffectContainer` pour la **tab bar** et la rangée d'actions du composer → les bulles
  de verre se fondent et se séparent proprement (effet « gouttes » Liquid Glass).
- `.interactive()` sur les éléments tappables → la lumière suit le doigt.
- Ne pas empiler deux `.glassEffect` (double réfraction sale) : un seul niveau de verre par « strate ».

### iOS 17–25 — fallback
```swift
someView
  .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
  .overlay( // liseré spéculaire
    RoundedRectangle(cornerRadius: 26, style: .continuous)
      .strokeBorder(specularGradient, lineWidth: 1))
  .overlay(alignment: .top) { // inset highlight
    Color.white.opacity(0.95).frame(height: 1).blur(radius: 0.5) }
  .shadow(color: Color(hex: 0x19202E).opacity(0.18), radius: 18, y: 10)
```
- `glass` → `.ultraThinMaterial` ; `glassStrong` → `.regularMaterial` (plus opaque, texte lisible).
- `cardSolid` → **pas** de material : `Color.white.opacity(0.55)` + gradient blanc + ombre.
- Respecter `.accessibilityReduceTransparency` : si actif, remplacer tout verre par
  `Color.white.opacity(0.96)` (comme `prefers-reduced-transparency` du web).

Un seul modificateur maison encapsule les deux chemins :
```swift
.glassSurface(.strong, radius: 26)   // choisit glassEffect (26) ou material (17) selon dispo
```

### Formes / rayons (tous en `style: .continuous`)
| Élément | Rayon |
|---|---|
| Bulles feed (cartes chat) | 28pt (haut) — coin bas-droit resserré à 8pt (queue de bulle sortante) |
| Composer, sheets | 26–28pt (haut des sheets seulement) |
| Cartes galerie | 22pt |
| Tab bar flottante | 24pt |
| Chips, segments | **capsule** (full-round) |
| Boutons ronds (photo, micro, générer) | cercle 44pt (générer), 40pt (secondaires) |
| Vignettes ref | 14pt |

---

## 3. Typographie

Le web utilise **Instrument Serif** (display) + **Figtree** (UI). Deux options natives :

- **Recommandé** : embarquer les fonts (SIL OFL, licences libres) dans le bundle → fidélité exacte.
  `Instrument Serif` (Regular + Italic) ; `Figtree` (400/500/600/700).
- **Fallback système** (sans fonts custom) : display → **New York** (serif système, `.serif` design) ;
  UI → **SF Pro** (`.default`). New York en italique light évoque bien Instrument Serif.

```swift
enum Font2 {
  static func display(_ s: CGFloat, italic: Bool = false) -> Font {
    .custom(italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular", size: s)
    // fallback: .system(size: s, design: .serif)
  }
  static func ui(_ s: CGFloat, _ w: Font.Weight = .regular) -> Font {
    .custom("Figtree", size: s).weight(w) // fallback: .system(size: s, weight: w)
  }
}
```

### Échelle typographique
| Rôle | Font | Taille / poids | Tracking | Exemple |
|---|---|---|---|---|
| Hero display | Instrument Serif | 34pt / 400 | -0.5 | « Qu'est-ce qu'on *crée* ? » (*crée* en italique iris) |
| Logo header | Instrument Serif | 26pt / 400 | 0 | « Create**.** » (point = accent bleu) |
| Titre sheet | Instrument Serif | 22pt / 400 | 0 | « Modèle », « Réglages » |
| Section label | Figtree | 13pt / 600, uppercase | +0.6 | « FORMAT », « QUALITÉ » |
| Corps / prompt | Figtree | 16pt / 400 | 0 | texte des bulles, saisie composer |
| Bouton / chip | Figtree | 15pt / 600 | +0.2 | « Se connecter », valeurs chips |
| Meta | Figtree | 13pt / 500 | 0 | « il y a 2 min · 42 cr » |
| Badge / micro-label | Figtree | 11pt / 700, uppercase | +0.8 | « ÉDITION », « IMAGE → VIDÉO » |
| Chip crédits | Figtree | 14pt / 600 (chiffres `.monospacedDigit`) | 0 | « 12 345 cr » |

- **Line height** : corps ×1.35, hero ×1.1.
- **Dynamic Type** : ancrer sur des `TextStyle` (`.body`, `.title`) via `relativeTo:` pour scaler ;
  plafonner le hero à `.accessibility1` pour ne pas casser la mise en page.
- **Chiffres** : toujours `.monospacedDigit()` sur le compteur de crédits (évite le tremblement pendant
  l'animation d'incrément).

---

## 4. Composants clés — specs

### 4.1 Header (haut, sur Créer & Galerie)
- Barre `glassStrong`, hauteur 52pt, épinglée sous la safe-area top, coins bas 0 (pleine largeur) ou
  flottante 24pt selon préférence — **flottante** retenue (cohérence avec la tab bar).
- Gauche : logo « Create. » (Instrument Serif 26, point en `.accent`).
- Droite : **cloche notifications** (SF Symbol `bell` / `bell.badge` / `bell.slash`) + **chip crédits**
  (capsule `glass`, éclair `bolt.fill` en iris + nombre monospaced). Tap cloche → sheet permissions ;
  tap chip → refresh crédits (haptique `tap`).
- États cloche : `unsupported` (grisée), `denied` (`bell.slash`, tap → réglages système),
  `available` (`bell`, tap = demander l'autorisation), `subscribed` (`bell.badge`, iris léger).

### 4.2 Tab bar (Créer / Galerie)
- Flottante, `glassStrong` (ou `GlassEffectContainer` iOS 26), largeur ~200pt centrée, hauteur 58pt,
  rayon 24pt, marge bas = safe-area + 8pt.
- 2 items : Créer (`sparkles`) / Galerie (`photo.on.rectangle`). Item actif = pastille iris derrière
  l'icône (`Iris.fill`, capsule) + label. Inactif = `inkSoft`.
- Transition d'onglet : cross-fade 0.2s + haptique `select`.

### 4.3 Composer chat (cœur de l'écran Créer)
Panneau `glassStrong` épinglé en bas, rayon 26pt, marge latérale 12pt, au-dessus de la tab bar.
Ordre vertical (padding 14pt) :

1. **Rangée refs** (si images) : `ScrollView(.horizontal)` de vignettes 56×56 (rayon 14pt), chacune
   avec bouton ✕ (cercle 20pt, `glass`) en haut-droite. Badge contextuel à gauche : capsule iris
   `.text` fine « ÉDITION » (mode image) ou « IMAGE → VIDÉO » (mode vidéo). Entrée en `.pop`.
2. **Zone de texte** : `TextField(axis: .vertical)`, min 1 ligne, **max ~150pt** puis scroll interne.
   Placeholder contextuel : « Décris ton image… » / « Décris ta vidéo… » / « Décris la retouche à
   faire… » (mode édition). Police corps 16pt, `ink`. Pas de bordure ; repose sur le verre.
3. **Rangée d'actions** (`GlassEffectContainer` iOS 26) — 5 contrôles, hauteur 44pt :
   - **Photo** (`photo.badge.plus`) — cercle 40pt `glass`. Désactivé (opacity 0.4) si
     `refs.count >= family.maxImages`. Tap → `PhotosPicker` → upload (`POST /api/upload`).
   - **Micro** (`mic.fill`) — cercle 40pt `glass`. En enregistrement → halo rouge pulsant (§6.4).
   - **Modèle** — capsule `glass`, label `{nom} {variante?} · {credits}cr` + chevron. Tap → sheet Modèle.
   - **Réglages** — capsule `glass`, label résumé `16:9 · 8s` + chevron. Tap → sheet Réglages.
   - **Générer** — cercle 44pt **iris** (`buttonStyle(.glass).tint`), flèche `arrow.up`. Disabled si
     prompt vide / génération en cours / upload en cours → passe en verre blanc + flèche `inkFaint`.
     Tap → haptique `launch`, vide le prompt, retire refs, scroll feed en bas.

### 4.4 Cartes feed (bulles chat sortantes)
- Liste **inversée** (plus récent en bas, collé au composer) ; 12 dernières générations.
- Largeur ~72% de l'écran, **alignées à droite** (bulle sortante). Surface `cardSolid`, rayon 28pt,
  coin bas-droit 8pt (queue). Entrée en `.rise`.
- **pending** : `shimmer` sur la zone média + spinner + prompt tronqué (2 lignes) + `progress-line`
  iris indéterminée + bouton ✕ (annuler → `POST …/cancel`, haptique `error`).
- **done** : miniature (image `?thumb=600x0` ou lecteur vidéo muet en boucle) rayon 20pt, + prompt
  (2 lignes) + meta « timeAgo · {credits} cr ». Tap → Lightbox (`launch` léger).
- **failed** : fond teinté rouge très pâle `#FDECEC`, texte « Échec — {error} », icône
  `exclamationmark.triangle`. Tap → réinjecte le prompt dans le composer.
- **cancelled** : `cardSolid` grisé (opacity 0.6), « Annulée ». Tap → réinjecte le prompt.
- **État vide** : hero display centré « Qu'est-ce qu'on *crée* aujourd'hui ? » (*crée* en italique
  `Iris.text`) + 3 chips-suggestions (capsule `glass`, tap = pré-remplit) :
  « Un logo minimaliste pour un café de quartier », « Portrait studio d'un golden retriever, fond
  pastel », « Une cuisine scandinave baignée de lumière du matin ».

### 4.5 Cartes galerie
- `LazyVGrid` 2 colonnes, spacing 12pt, `cardSolid` carré rayon 22pt.
- Miniature `?thumb=600x600` (ou vidéo muette). Sous l'image : prompt (1 ligne) + « {modèle} ·
  timeAgo ». Mêmes états pending/failed/cancelled que le feed.
- **Bandeau « N génération(s) en cours »** en tête (capsule `glassStrong` + `progress-line`) si des
  pending existent. **Pull-to-refresh** natif (`.refreshable`). Tap carte `done` → Lightbox.

### 4.6 Lightbox (visionneuse plein écran)
- `fullScreenCover` : fond aurora **assombri/flouté** (`.ultraThinMaterial` sombre léger ou
  `Color.black.opacity(0.35)` + blur du fond). Média centré `object-contain` (image zoomable
  `MagnificationGesture`, vidéo `VideoPlayer` autoplay + contrôles). Entrée `lightbox` (scale-in 0.94→1).
- **Swipe-down pour fermer** : `DragGesture` ; le média suit le doigt + le fond se dé-opacifie ;
  drag > 110pt (ou vélocité) → dismiss ; sinon spring retour. Haptique `tap` au lâcher-fermeture.
- **Barre haut** (`glassStrong`) : bouton fermer (`xmark`) + « {modèle} · timeAgo · {credits} cr ».
- **Panneau actions bas** (`glassStrong`, rayon haut 26pt) :
  - Prompt (tap = copier → toast « Copié », haptique `select`).
  - Grille d'actions (capsules `glass`, icône + label) :
    - **Partager** (`square.and.arrow.up`) → `UIActivityViewController` sur le fichier média.
    - **Upscale** (`arrow.up.left.and.arrow.down.right`, images only) → `POST /api/generate {tool:"upscale"}`.
    - **Détourer** (`scissors`, images only) → `{tool:"removeBg"}`.
    - **Sauver** (`arrow.down.to.line`) → enregistrement `PHPhotoLibrary` (fichier `?download=1`).
  - **Supprimer** (`trash`, teinte rouge) : **double-tap de confirmation** (1er tap → « Confirmer ? »
    rouge 3s ; 2e tap → `DELETE`, haptique `error`).

### 4.7 Sheets (Modèle / Réglages)
- `.presentationDetents([.medium, .large])`, `.presentationBackground(.glassStrong-equivalent)`,
  `presentationCornerRadius(28)`, `presentationDragIndicator(.visible)` (barre `inkSoft` 0.3).
  Entrée `sheet-up`.
- **Sheet Modèle** : en haut, **segment Image / Vidéo** (capsule `glass`, thumb actif blanc + ombre,
  transition 0.22s ease). Liste des familles du mode : nom (Figtree 600) + tagline (`inkSoft`) +
  coût crédits (capsule). Famille active = **contour iris** (`strokeBorder(Iris.fill, 2)`).
  Sélection → haptique `select`, ferme, re-clamp refs au `maxImages`.
- **Sheet Réglages** (générée depuis le catalogue `ModelFamily`/`ParamSpec`) :
  - Si `variants` (Veo) : rangée « Qualité » → chips.
  - Une rangée par `param` visible (`paramsFor(family, editing)`) : label (section-label uppercase) +
    `ScrollView(.horizontal)` de chips (valeurs `values`). Chip active = `Iris.fill`, inactive = `glass`.
    Rendus spéciaux : booléens → `boolLabels`, « Durée » → suffixe `s`, « Format » → mini-glyphe du
    ratio (petit rectangle proportionné dessiné en `Path`).
  - Aucun param → texte centré `inkSoft` « Ce modèle n'a pas de réglages. »

### 4.8 Écran Login
- Fond aurora plein écran. Carte centrée `glassStrong`, rayon 28pt, padding 24pt, `.pop` à l'apparition.
- Titre « Create. » (display 30) + sous-titre « Connecte-toi pour créer. » (`inkSoft`).
- Champ identifiant (`textInputAutocapitalization(.never)`, `keyboardType(.emailAddress)`) + champ
  mot de passe (`SecureField`) — chacun capsule `glass` interne. Bouton « Se connecter » pleine largeur
  **iris**. Erreur inline rouge « Identifiant ou mot de passe incorrect ».
- Auth = PB direct → token Bearer au **Keychain** (voir `NATIVE_SPEC §4`). Succès → haptique `success`.

### 4.9 Chip crédits (compteur animé)
- Capsule `glass` : `bolt.fill` (rempli iris) + nombre `.monospacedDigit()` + « cr ».
- Animation d'incrément : interpolation de la valeur sur 0.6s `easeOut` (compteur qui « roule »).
  Refresh toutes les ~45s et au retour foreground (`scenePhase == .active`).

### 4.10 Toasts
- Capsule `glassStrong` flottante en haut sous le header, `toast-in` (slide+scale spring), auto-dismiss
  2.5s. Icône contextuelle (✓ iris / ✕ rouge). Ex. « Copié », « Enregistré dans Photos ».

---

## 5. Iconographie
- **SF Symbols** partout (poids `.medium`, rendu `.hierarchical` pour la profondeur ; `.palette` avec
  `Iris.fill` sur les icônes actives d'action). Alignement optique 44pt cible tactile minimum.
- Correspondances : sparkles=Créer, photo.on.rectangle=Galerie, bell(.badge/.slash)=notifs,
  bolt.fill=crédits, photo.badge.plus=ajouter image, mic.fill=dictée, arrow.up=générer,
  xmark=fermer, square.and.arrow.up=partager, scissors=détourer, trash=supprimer,
  arrow.down.to.line=sauver, chevron.down=ouvrir sheet.

---

## 6. Motion

Toutes les courbes reprennent le web. Préférer `spring` natifs quand cité.

| Nom (web) | Déclencheur | Spec native |
|---|---|---|
| `press` | tout bouton à l'appui | `scaleEffect(0.94)` via `.buttonStyle` custom, 0.06s ease-out |
| `rise` | entrée carte feed | offset y +16 → 0 + fade, `spring(response:0.28, dampingFraction:0.9)` |
| `pop` | badge, vignette, carte login | scale 0.92 → 1 overshoot, `spring(response:0.35, dampingFraction:0.62)` |
| `sheet-up` | ouverture bottom sheet | détent système (déjà spring) ; sinon offset 100%→0 `spring 0.26` |
| `fade-in` | overlays légers | opacity 0→1, 0.16s ease |
| `shimmer` | skeleton pending | bande diagonale blanche 0.6, translation -100%→100%, 1.7s boucle |
| `progress-line` | barre pending | segment iris 40% qui glisse, 1.3s boucle easeInOut |
| `lightbox` | ouverture visionneuse | scale 0.94→1 + fade, `spring 0.30` |
| `mic-pulse` | enregistrement | halo rouge qui respire, 1.4s boucle (voir §6.4) |
| aurora | fond | **statique** (dérive ≤0.02 tolérée si Reduce Motion off) |

- **Réduction de mouvement** : si `accessibilityReducedMotion`, remplacer rise/pop/lightbox par un
  simple fade 0.01s, figer shimmer/progress (état statique), couper toute dérive aurora.
- **Transitions d'écran** : `matchedGeometryEffect` entre la miniature (feed/galerie) et le média
  plein écran de la lightbox → l'image « grandit » depuis sa vignette (effet Liquid Glass morph).
- **Feed** : à la transition `pending → done`, la carte fait un léger `pop` sur la miniature qui
  remplace le shimmer, synchronisé avec l'haptique `success`.

### 6.4 Micro en enregistrement
Halo rouge `#E03131` : anneau qui se dilate (`scale 1→1.6`, opacity `0.45→0`) en 1.4s boucle, +
ombre portée rouge stable. Le bouton lui-même vire au dégradé rouge `#FF5D5D → #E03131`, icône blanche.
Auto-stop 60s. Audio < ~1.2 ko ignoré (tap accidentel).

---

## 7. Light / Dark & accessibilité

- **Light mode forcé** : `.preferredColorScheme(.light)` au niveau racine. Tous les tokens ci-dessus
  sont pensés light. **Ne pas** livrer de dark tant qu'Ichai ne le demande pas explicitement.
- Si un dark mode est un jour demandé : inverser l'encre (`ink` → `#EAECF3`), assombrir la base aurora
  (`#0E1220 → #131A2E`), monter l'opacité du verre à ~0.14 fond sombre, garder l'iris **inchangé**
  (il fonctionne sur les deux). Ne pas improviser : refaire une passe DA dédiée.
- **Contraste** : `ink` sur verre blanc ≈ AAA ; vérifier `inkSoft` (secondaire) ≥ 4.5:1 sur les
  surfaces les plus translucides ; texte blanc sur iris ≥ 4.5:1 (OK, l'iris est mi-foncé).
- **Reduce Transparency** → verre opaque `white.opacity(0.96)`. **Reduce Motion** → §6.
  **Increase Contrast** → renforcer les liserés (opacity 0.9) et l'ombre des cartes.
- **Dynamic Type** : layouts en `ScrollView` tolérants ; boutons à hauteur mini 44pt.
- **VoiceOver** : chip crédits = « 12 345 crédits restants » ; cartes feed annoncent statut + prompt ;
  bouton Générer désactivé annonce la raison (« prompt vide »).

### RTL
L'app est en français (LTR par défaut). Prévoir la neutralité RTL au cas où :
- Utiliser des `leading/trailing` (jamais `left/right` codés en dur) → miroir automatique en RTL.
- **Bulles feed** : sortantes = côté `trailing` → en RTL elles passent à gauche, ce qui reste correct
  (le côté « moi » suit la direction de lecture). Le coin resserré de la queue suit `trailing`.
- **Ne pas miroiter** : le média lui-même, le gradient iris (directionnel décoratif), les glyphes de
  ratio. Les chevrons/flèches directionnelles (`arrow.up` OK, `chevron` OK) : laisser SF Symbols gérer.
- Chiffres de crédits : garder LTR (`.monospacedDigit`).

---

## 8. Haptique

Mapping direct de `haptics.ts` sur les générateurs UIKit (via un petit wrapper `Haptics`).

| Événement (web) | Déclencheur | Générateur iOS |
|---|---|---|
| `tap` | appui bouton neutre, fermeture, copie | `UIImpactFeedbackGenerator(.light)` |
| `select` | changement de modèle, toggle chip, segment, onglet | `UISelectionFeedbackGenerator` |
| `launch` | lancement d'une génération, ouverture lightbox | `UIImpactFeedbackGenerator(.medium)` |
| `success` | génération prête (pending→done), login réussi | `UINotificationFeedbackGenerator(.success)` |
| `error` | échec, annulation, suppression confirmée | `UINotificationFeedbackGenerator(.error)` |

Règles : **pré-armer** (`.prepare()`) le générateur avant un événement anticipé (juste avant l'envoi,
avant la fin de swipe lightbox). Ne jamais spammer : au plus 1 haptique par action utilisateur ; le
polling qui découvre plusieurs `done` d'un coup ne déclenche qu'un seul `success`. Respecter le réglage
système (les générateurs no-op si l'utilisateur a coupé le retour haptique).

---

## 9. Récap tokens (copier-coller)

```
INK        #2A3142   INK_SOFT  #5D6478   ACCENT #2F6DF6
IRIS_FILL  #8B5CF6 → #3B82F6 (55%) → #22D3EE   (135°)
IRIS_TEXT  #7C3AED → #2563EB (55%) → #06B6D4   (135°)
AURORA_BASE 165°  #EEF0FD → #EAF2FC (45%) → #EAFAF9
STATUS_BAR #EEF0FD
GLASS       white .50 / blur12 sat160     GLASS_STRONG white .72 / blur16 sat170
CARD_SOLID  white .55 (no blur)           SHADOW #19202E .18 r36 y10
RADII  bulle28(queue8) · sheet28 · composer26 · galerie22 · tabbar24 · chip=capsule · générer=44●
TYPE   Instrument Serif (display) + Figtree (UI)  |  fallback New York + SF Pro
MOTION spring: rise .28/.9 · pop .35/.62 · lightbox .30  |  aurora STATIQUE
HAPTIC tap=light · select=selection · launch=medium · success=notif✓ · error=notif✕
RULE   LIGHT MODE ONLY
```
