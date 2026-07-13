//
//  ShareSheet.swift
//  Create
//
//  Pont natif figé — CONTRACTS §4.4 :
//  `struct ShareSheet: UIViewControllerRepresentable // UIActivityViewController`
//
//  Enveloppe SwiftUI du partage natif (NATIVE_SPEC §2.4 « Partager »). Présentée en
//  `.sheet` depuis la Lightbox avec le fichier média (ou son URL) à partager.
//

import SwiftUI
import UIKit

/// Partage natif via `UIActivityViewController` (feuille de partage système).
struct ShareSheet: UIViewControllerRepresentable {

    /// Éléments à partager : `URL` de fichier local, `UIImage`, `String`, etc.
    let items: [Any]

    /// Activités à masquer (optionnel).
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    /// Callback de fin (succès/annulation), utile pour un toast ou une haptique.
    var onComplete: ((_ completed: Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete?(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Rien à mettre à jour : le contrôleur est piloté par sa présentation.
    }
}
