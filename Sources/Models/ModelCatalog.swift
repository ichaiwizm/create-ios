//
//  ModelCatalog.swift
//  Create
//
//  Miroir natif VERBATIM du catalogue kie (`src/lib/kie/models.ts`, SPEC §5).
//  Catalogue data-driven : chaque famille déclare ses vrais champs API et ses `ParamSpec`,
//  ce qui permet de générer les sheets de réglages dynamiquement.
//  Types, champs et valeurs figés par CONTRACTS §1.2. Aucune dépendance réseau.
//

import Foundation

/// Nature d'un modèle : image ou vidéo.
enum ModelKind: String, Sendable {
    case image
    case video
}

/// Description d'un réglage exposé par un modèle (un vrai champ API kie).
struct ParamSpec: Identifiable, Hashable, Sendable {
    /// Clé `options` envoyée à `/api/generate`.
    let field: String
    /// Libellé affiché ("Format", "Résolution", "Durée", "Son"…).
    let label: String
    let values: [String]
    let def: String
    /// Converti en `Int` dans les options.
    var numeric: Bool = false
    /// Converti en `Bool` dans les options.
    var boolean: Bool = false
    /// Libellés d'affichage pour les booléens, ex. ["Avec son", "Sans son"].
    var boolLabels: [String]? = nil
    /// Masqué en mode édition (le champ n'existe qu'en texte→média).
    var textOnly: Bool = false

    var id: String { field }
}

/// Déclinaison d'un modèle (ex. Veo Fast/Quality) — remplace textId/editId pour le slug.
struct ModelVariant: Identifiable, Hashable, Sendable {
    /// "fast" | "quality"
    let key: String
    /// "Rapide" | "Qualité"
    let label: String
    /// Slug kie : "veo3_fast" | "veo3"
    let id: String
    let credits: Int
}

/// Une famille de modèles (regroupe variante texte, variante édition et réglages).
struct ModelFamily: Identifiable, Hashable, Sendable {
    /// "nano-banana-pro", …
    let key: String
    let kind: ModelKind
    let name: String
    let tagline: String
    /// Libellé de coût, ex. "~18-24".
    let credits: String
    /// Slug texte→média.
    let textId: String
    /// Slug édition (i2i / i2v).
    let editId: String
    /// Champ API recevant les images ("image_input", "input_urls", "first_frame_url"…).
    let imageField: String
    /// Le champ image est une liste (sinon une seule URL).
    let imageIsList: Bool
    let maxImages: Int
    let params: [ParamSpec]
    /// Constantes toujours envoyées (champs requis par l'API).
    var extraInput: [String: JSONValue] = [:]
    /// Déclinaisons (Veo Fast/Quality) — remplacent textId/editId.
    var variants: [ModelVariant]? = nil

    var id: String { key }
}

/// Outil 1-clic appliqué à une image existante.
struct Tool: Identifiable, Sendable {
    /// "upscale" | "removeBg"
    let key: String
    /// Slug kie.
    let id: String
    let credits: Int
    /// Entrée brute type de l'outil (le champ image est renseigné à l'envoi).
    let rawInput: [String: JSONValue]

    var identityID: String { key }
}

// MARK: - Catalogue statique (VERBATIM SPEC §5)

enum ModelCatalog {

    // MARK: Image — 3 familles

    static let image: [ModelFamily] = [
        ModelFamily(
            key: "nano-banana-pro",
            kind: .image,
            name: "Nano Banana Pro",
            tagline: "Détails fins · texte net",
            credits: "~18-24",
            textId: "nano-banana-pro",
            editId: "nano-banana-pro",
            imageField: "image_input",
            imageIsList: true,
            maxImages: 8,
            params: [
                ParamSpec(field: "aspect_ratio", label: "Format",
                          values: ["1:1", "2:3", "3:2", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9", "21:9", "auto"],
                          def: "1:1"),
                ParamSpec(field: "resolution", label: "Résolution",
                          values: ["1K", "2K", "4K"], def: "1K"),
            ],
            extraInput: ["output_format": .string("png")]
        ),
        ModelFamily(
            key: "gpt-image-2",
            kind: .image,
            name: "GPT Image 2",
            tagline: "Dernier OpenAI · très créatif",
            credits: "~15-40",
            textId: "gpt-image-2-text-to-image",
            editId: "gpt-image-2-image-to-image",
            imageField: "input_urls",
            imageIsList: true,
            maxImages: 16,
            params: [
                ParamSpec(field: "aspect_ratio", label: "Format",
                          values: ["auto", "1:1", "3:2", "2:3", "4:3", "3:4", "5:4", "4:5", "16:9", "9:16", "21:9"],
                          def: "auto"),
                ParamSpec(field: "resolution", label: "Résolution",
                          values: ["1K", "2K", "4K"], def: "1K"),
            ]
        ),
        ModelFamily(
            key: "seedream-5-pro",
            kind: .image,
            name: "Seedream 5 Pro",
            tagline: "Le meilleur de ByteDance",
            credits: "~15-25",
            textId: "seedream/5-pro-text-to-image",
            editId: "seedream/5-pro-image-to-image",
            imageField: "image_urls",
            imageIsList: true,
            maxImages: 10,
            params: [
                ParamSpec(field: "aspect_ratio", label: "Format",
                          values: ["1:1", "4:3", "3:4", "16:9", "9:16", "2:3", "3:2"], def: "1:1"),
                ParamSpec(field: "quality", label: "Qualité",
                          values: ["basic", "high"], def: "basic"),
            ]
        ),
    ]

    // MARK: Vidéo — 3 familles

    static let video: [ModelFamily] = [
        ModelFamily(
            key: "veo3.1",
            kind: .video,
            name: "Veo 3.1",
            tagline: "Google · le meilleur · audio natif",
            credits: "~80-300",
            textId: "veo3_fast",
            editId: "veo3_fast",
            imageField: "imageUrls",
            imageIsList: true,
            maxImages: 3,
            params: [
                ParamSpec(field: "aspect_ratio", label: "Format",
                          values: ["16:9", "9:16"], def: "16:9"),
                ParamSpec(field: "resolution", label: "Résolution",
                          values: ["720p", "1080p"], def: "720p"),
                ParamSpec(field: "duration", label: "Durée",
                          values: ["4", "6", "8"], def: "8", numeric: true),
            ],
            variants: [
                ModelVariant(key: "fast", label: "Rapide", id: "veo3_fast", credits: 80),
                ModelVariant(key: "quality", label: "Qualité", id: "veo3", credits: 300),
            ]
        ),
        ModelFamily(
            key: "kling-3.0",
            kind: .video,
            name: "Kling 3.0",
            tagline: "Dernier Kling · 3-15 s · son",
            credits: "~150-400",
            textId: "kling-3.0/video",
            editId: "kling-3.0/video",
            imageField: "image_urls",
            imageIsList: true,
            maxImages: 2,
            params: [
                ParamSpec(field: "aspect_ratio", label: "Format",
                          values: ["16:9", "9:16", "1:1"], def: "16:9"),
                ParamSpec(field: "mode", label: "Mode",
                          values: ["std", "pro", "4K"], def: "pro"),
                ParamSpec(field: "duration", label: "Durée",
                          values: ["3", "5", "8", "10", "15"], def: "5"),
                ParamSpec(field: "sound", label: "Son",
                          values: ["true", "false"], def: "false",
                          boolean: true, boolLabels: ["Avec son", "Sans son"]),
            ],
            extraInput: [
                "multi_shots": .bool(false),
                "multi_prompt": .array([]),
            ]
        ),
        ModelFamily(
            key: "seedance-2",
            kind: .video,
            name: "Seedance 2.0",
            tagline: "ByteDance · très bon rapport qualité/prix",
            credits: "~100-300",
            textId: "bytedance/seedance-2",
            editId: "bytedance/seedance-2",
            imageField: "first_frame_url",
            imageIsList: false,
            maxImages: 1,
            params: [
                ParamSpec(field: "aspect_ratio", label: "Format",
                          values: ["16:9", "9:16", "1:1", "4:3", "3:4", "21:9", "adaptive"], def: "16:9"),
                ParamSpec(field: "resolution", label: "Résolution",
                          values: ["480p", "720p", "1080p"], def: "720p"),
                ParamSpec(field: "duration", label: "Durée",
                          values: ["4", "5", "8", "10", "12"], def: "5", numeric: true),
                ParamSpec(field: "generate_audio", label: "Son",
                          values: ["true", "false"], def: "true",
                          boolean: true, boolLabels: ["Avec son", "Sans son"]),
            ]
        ),
    ]

    // MARK: Outils 1-clic

    static let tools: [Tool] = [
        Tool(key: "upscale", id: "topaz/image-upscale", credits: 4,
             rawInput: ["image_url": .null, "upscale_factor": .string("2")]),
        Tool(key: "removeBg", id: "recraft/remove-background", credits: 4,
             rawInput: ["image": .null]),
    ]

    // MARK: Accès

    static func families(for kind: ModelKind) -> [ModelFamily] {
        switch kind {
        case .image: return image
        case .video: return video
        }
    }

    static func family(key: String) -> ModelFamily? {
        (image + video).first { $0.key == key }
    }

    static let defaultImageFamilyKey = "nano-banana-pro"
    static let defaultVideoFamilyKey = "veo3.1"
}
