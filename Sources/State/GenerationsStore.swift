//
//  GenerationsStore.swift
//  Create — State
//
//  CONTRACTS §4.3 : source UNIQUE des générations, partagée par le feed (Créer) et la
//  galerie. Polling 4 s des `pending`, haptique sur transition.
//  Dépend de Networking (`APIClient`, DTOs) et DesignSystem (`Haptics`).
//

import Foundation
import Observation

/// Détient la liste complète des générations de l'utilisateur et en dérive les vues
/// consommées par l'UI.
///
/// - `feed` : 12 plus récentes, ordre inversé (récent en bas) — bulles de chat sortantes.
/// - `all`  : tri `-created` — grille galerie.
/// - `pendingCount` : bandeau « N en cours ».
///
/// Le polling interroge `generation(id:)` pour chaque `pending` toutes les 4 s et déclenche
/// **une** haptique `success` par cycle si au moins une génération passe `done`, **une**
/// `error` si au moins une passe `failed`/`cancelled`.
@MainActor
@Observable
final class GenerationsStore {

    private(set) var items: [Generation] = []

    private let api: APIClient
    private var pollTask: Task<Void, Never>?

    init(api: APIClient) {
        self.api = api
    }

    // MARK: - Vues dérivées

    /// Générations triées du plus récent au plus ancien (source des dérivés).
    private var sortedDesc: [Generation] {
        items.sorted { $0.created > $1.created }
    }

    /// 12 dernières, inversées : la plus ancienne en haut, la plus récente collée au composer.
    var feed: [Generation] {
        Array(sortedDesc.prefix(12)).reversed()
    }

    /// Toutes les générations, tri `-created`, pour la galerie.
    var all: [Generation] { sortedDesc }

    /// Nombre de générations en cours (pour le bandeau de progression).
    var pendingCount: Int {
        items.reduce(into: 0) { if $1.status == .pending { $0 += 1 } }
    }

    // MARK: - Chargement

    /// Chargement initial de la liste.
    func load() async { await reload() }

    /// Rechargement (pull-to-refresh).
    func refresh() async { await reload() }

    private func reload() async {
        guard let fresh = try? await api.generations() else { return }
        items = fresh
    }

    // MARK: - Polling

    /// Démarre le timer 4 s (idempotent). À couper au passage en arrière-plan.
    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.pollPending()
            }
        }
    }

    /// Arrête le polling.
    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Rafraîchit chaque génération `pending` et gère les haptiques de transition.
    private func pollPending() async {
        let pendingIds = items.compactMap { $0.status == .pending ? $0.id : nil }
        guard !pendingIds.isEmpty else { return }

        var anyDone = false
        var anyFailed = false

        for id in pendingIds {
            guard let fresh = try? await api.generation(id: id),
                  let idx = items.firstIndex(where: { $0.id == id }) else { continue }

            let wasPending = items[idx].status == .pending
            items[idx] = fresh

            if wasPending, fresh.status != .pending {
                switch fresh.status {
                case .done:                 anyDone = true
                case .failed, .cancelled:   anyFailed = true
                case .pending:              break
                }
            }
        }

        // Au plus une haptique de chaque type par cycle de poll (CONTRACTS §2.8).
        if anyDone { Haptics.fire(.success) }
        if anyFailed { Haptics.fire(.error) }
    }

    // MARK: - Actions

    /// Lance une génération puis recharge le feed et (re)démarre le polling.
    func submit(_ req: GenerateRequest) async throws {
        _ = try await api.generate(req)
        await reload()
        startPolling()
    }

    /// Lance un outil 1-clic (upscale / removeBg) puis recharge et poll.
    func runTool(_ req: ToolRequest) async throws {
        _ = try await api.runTool(req)
        await reload()
        startPolling()
    }

    /// Annule une génération en cours ; met à jour l'item concerné.
    func cancel(id: String) async {
        try? await api.cancel(id: id)
        if let fresh = try? await api.generation(id: id),
           let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx] = fresh
        } else {
            await reload()
        }
    }

    /// Supprime une génération (retrait optimiste immédiat).
    func delete(id: String) async {
        try? await api.deleteGeneration(id: id)
        items.removeAll { $0.id == id }
    }
}
