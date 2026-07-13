import SwiftUI
import UIKit

/// Image distante avec **cache mémoire + disque** (figé — CONTRACTS §4.5).
///
/// Remplace `AsyncImage` (qui ne persiste rien) : les miniatures PocketBase
/// (`?thumb=600x600` / `?thumb=600x0`) sont chargées une fois puis relues depuis le
/// disque, ce qui évite le re-téléchargement au scroll et entre deux lancements.
///
/// Rendu : `resizable` + `aspectRatio(contentMode)`. Pendant le chargement, un placeholder
/// verre discret (avec shimmer) est affiché ; en cas d'échec, un glyphe `photo` neutre.
///
/// Usage : `RemoteImage(url: gen.thumbGridURL, contentMode: .fill)`.
struct RemoteImage: View {
    private let url: URL?
    private let contentMode: ContentMode

    @State private var image: UIImage?
    @State private var didFail = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - url: URL de l'image (nil → placeholder d'échec neutre).
    ///   - contentMode: `.fill` (défaut, vignettes) ou `.fit` (aperçu).
    init(url: URL?, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
    }

    var body: some View {
        content
            .task(id: url) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .transition(.opacity)
        } else if didFail || url == nil {
            failurePlaceholder
        } else {
            loadingPlaceholder
        }
    }

    // MARK: - Placeholders

    /// Teinte verre du placeholder (constante typée — évite de retyper `Color.white.opacity`
    /// à chaque rendu et sort le littéral du `ViewBuilder`).
    private static let placeholderTint: Color = Color.white.opacity(0.28)
    private static let glyphOpacity: Double = 0.6
    private static let glyphSize: CGFloat = 20
    private static let revealDuration: Double = 0.18

    private var loadingPlaceholder: some View {
        Self.placeholderTint
            .shimmer(active: !reduceMotion)
            .accessibilityHidden(true)
    }

    private var failurePlaceholder: some View {
        ZStack {
            Self.placeholderTint
            Image(systemName: "photo")
                .font(.system(size: Self.glyphSize, weight: .regular))
                .foregroundStyle(Color.inkSoft.opacity(Self.glyphOpacity))
        }
        .accessibilityHidden(true)
    }

    // MARK: - Chargement

    @MainActor
    private func load() async {
        // Reset lors d'un changement d'URL (réutilisation de vue dans une LazyVGrid).
        image = nil
        didFail = false

        guard let url else {
            didFail = true
            return
        }

        let loaded = await ImageDiskCache.shared.image(for: url)

        // La vue a pu être recyclée sur une autre URL entre-temps → `.task(id:)` relance
        // load(), donc on peut publier sans revérifier (l'ancienne tâche est annulée).
        guard !Task.isCancelled else { return }

        if let loaded {
            // Type explicite `Animation?` : la branche `nil` + member-lookup `.easeInOut`
            // ne force plus le type-checker à remonter la signature de `withAnimation`.
            let reveal: Animation? = reduceMotion ? nil : .easeInOut(duration: Self.revealDuration)
            withAnimation(reveal) {
                image = loaded
            }
        } else {
            didFail = true
        }
    }
}

// MARK: - Cache image (mémoire + disque)

/// Cache d'images à deux niveaux, isolé par acteur.
///
/// 1. **Mémoire** : `NSCache` (auto-purgé sous pression mémoire).
/// 2. **Disque** : fichiers dans `Caches/RemoteImageCache/`, nommés par hachage stable de l'URL.
///
/// Aucune dépendance tierce : le hachage de nom de fichier est un FNV-1a 64 bits maison
/// (pas de CryptoKit). `URLSession.shared` sert au réseau ; les données brutes sont écrites
/// telles quelles sur le disque puis décodées.
actor ImageDiskCache {
    static let shared = ImageDiskCache()

    private let memory = NSCache<NSURL, UIImage>()
    private let directory: URL
    private let session: URLSession

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("RemoteImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = nil // on gère notre propre cache disque
        session = URLSession(configuration: config)

        memory.countLimit = 200
    }

    /// Retourne l'image pour `url` : mémoire → disque → réseau (et repeuple les niveaux amont).
    func image(for url: URL) async -> UIImage? {
        let key = url as NSURL

        if let cached = memory.object(forKey: key) {
            return cached
        }

        let fileURL = directory.appendingPathComponent(Self.fileName(for: url))

        if let data = try? Data(contentsOf: fileURL), let img = UIImage(data: data) {
            memory.setObject(img, forKey: key)
            return img
        }

        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }
            guard let img = UIImage(data: data) else { return nil }
            try? data.write(to: fileURL, options: .atomic)
            memory.setObject(img, forKey: key)
            return img
        } catch {
            return nil
        }
    }

    /// Nom de fichier stable et sûr, dérivé de l'URL (FNV-1a 64 bits → hex).
    private static func fileName(for url: URL) -> String {
        let offsetBasis: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01B3
        let bytes: [UInt8] = Array(url.absoluteString.utf8)
        var hash: UInt64 = offsetBasis
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(format: "%016llx", hash)
    }
}
