//
//  CreditsStore.swift
//  Create — State
//
//  CONTRACTS §4.3 / DESIGN §4.9 : crédits kie, compteur animé (« roule » sur 0.6 s easeOut),
//  refresh toutes les 45 s + au retour foreground.
//  Dépend de Networking (`APIClient`, `CreditsResponse`).
//

import Foundation
import Observation

/// Détient le solde de crédits et sa valeur d'affichage interpolée.
///
/// - `credits`   : valeur cible réelle (dernier `GET /api/credits`).
/// - `displayed` : valeur affichée, animée vers la cible sur 0.6 s (easeOut cubique) ;
///   c'est elle que rend la chip crédits, en `.monospacedDigit()`.
@MainActor
@Observable
final class CreditsStore {

    private(set) var credits: Int = 0

    /// Valeur de la stored property animée, observée par l'UI.
    private var animatedValue: Double = 0

    /// Valeur affichée (arrondie) du compteur qui « roule ».
    var displayed: Int { Int(animatedValue.rounded()) }

    private let api: APIClient
    private var animationTask: Task<Void, Never>?
    private var autoRefreshTask: Task<Void, Never>?

    private let animationDuration: TimeInterval = 0.6

    init(api: APIClient) {
        self.api = api
    }

    // MARK: - Refresh

    /// Récupère le solde et lance l'animation d'incrément.
    func refresh() async {
        guard let response = try? await api.credits() else { return }
        setCredits(response.credits)
    }

    private func setCredits(_ target: Int) {
        guard target != credits else { return }
        credits = target
        animate(to: Double(target))
    }

    /// Interpole `animatedValue` vers `target` sur `animationDuration` (easeOut cubique).
    private func animate(to target: Double) {
        animationTask?.cancel()

        let start = animatedValue
        let delta = target - start
        guard delta != 0 else {
            animatedValue = target
            return
        }

        animationTask = Task { [weak self] in
            guard let self else { return }
            let startTime = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                let t = elapsed / self.animationDuration
                if t >= 1 { break }
                let eased = 1 - pow(1 - t, 3)          // easeOutCubic
                self.animatedValue = start + delta * eased
                try? await Task.sleep(nanoseconds: 16_000_000) // ~60 fps
            }
            if !Task.isCancelled {
                self.animatedValue = target
            }
        }
    }

    // MARK: - Auto-refresh

    /// Démarre le cycle 45 s (idempotent). Refresh immédiat au démarrage.
    func startAutoRefresh() {
        guard autoRefreshTask == nil else { return }
        autoRefreshTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 45_000_000_000)
                guard !Task.isCancelled else { break }
                await self.refresh()
            }
        }
    }

    /// Arrête l'auto-refresh (passage en arrière-plan).
    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }
}
