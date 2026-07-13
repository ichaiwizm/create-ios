//
//  LoginView.swift
//  Create — écran de connexion (NATIVE_SPEC §2.1 / §4.8, DESIGN §4.8)
//
//  Carte `glassStrong` posée sur l'aurora, titre « Create. » display,
//  champ identifiant (autocap never, clavier email) + SecureField en capsules
//  glass, bouton « Se connecter » iris pleine largeur, erreur inline rouge.
//  Auth via `Session.login` (PocketBase → token Bearer au Keychain), haptique
//  `success` au succès / `error` à l'échec.
//
//  Dépendances (contrats figés) : Session (State/Session.swift), DesignSystem
//  (AuroraBackground, .glassSurface(_:radius:), Font2, Color tokens, Iris,
//  IrisButtonStyle, Motion, Haptics).
//

import SwiftUI
import UIKit

struct LoginView: View {
    @Environment(Session.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Champs de saisie.
    @State private var identity: String = ""
    @State private var password: String = ""

    // État de la requête d'authentification.
    @State private var isSubmitting = false
    @State private var showError = false

    // Animation d'apparition de la carte (`.pop`).
    @State private var appeared = false

    // Focus clavier (identifiant → mot de passe → envoi).
    private enum Field: Hashable { case identity, password }
    @FocusState private var focused: Field?

    /// Envoi possible seulement si les deux champs sont non vides et qu'aucune
    /// requête n'est déjà en cours.
    private var canSubmit: Bool {
        !identity.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !isSubmitting
    }

    var body: some View {
        ZStack {
            // Fond aurora plein écran, sous la carte.
            AuroraBackground()
                .ignoresSafeArea()

            ScrollView {
                card
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 24)
                    // Centrage vertical dans la fenêtre.
                    .frame(maxWidth: .infinity, minHeight: screenMinHeight)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            Haptics.prepare(.success)
            withAnimation(Motion.reduced(Motion.pop, reduceMotion: reduceMotion)) {
                appeared = true
            }
        }
    }

    // MARK: - Carte verre

    private var card: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            fields
            errorLabel
            submitButton
        }
        .padding(24)
        .glassSurface(.strong, radius: 28)
        // Entrée `.pop` : scale 0.92 → 1 avec léger overshoot.
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - En-tête (titre + sous-titre)

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            // « Create. » — point en accent bleu.
            titleText
                .font(Font2.display(30))

            Text("Connecte-toi pour créer.")
                .font(Font2.ui(15))
                .foregroundStyle(Color.inkSoft)
        }
        .accessibilityElement(children: .combine)
    }

    /// Titre « Create. » extrait en `Text` typé. Les fragments sont hissés et
    /// annotés `: Text` pour forcer la surcharge `Text.foregroundStyle` (retour
    /// `Text`) et éviter que l'opérateur `+` fasse exploser l'inférence de types.
    private var titleText: Text {
        let name: Text = Text("Create").foregroundStyle(Color.ink)
        let dot: Text = Text(".").foregroundStyle(Color.accent)
        return name + dot
    }

    // MARK: - Champs

    private var fields: some View {
        VStack(spacing: 12) {
            // Identifiant / email.
            TextField("Identifiant ou email", text: $identity)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .autocorrectionDisabled(true)
                .submitLabel(.next)
                .focused($focused, equals: .identity)
                .onSubmit { focused = .password }
                .modifier(FieldChrome())

            // Mot de passe.
            SecureField("Mot de passe", text: $password)
                .textContentType(.password)
                .submitLabel(.go)
                .focused($focused, equals: .password)
                .onSubmit(attemptLogin)
                .modifier(FieldChrome())
        }
        .tint(Color.accent)
        .disabled(isSubmitting)
        .onChange(of: identity) { _, _ in clearError() }
        .onChange(of: password) { _, _ in clearError() }
    }

    // MARK: - Erreur inline

    @ViewBuilder
    private var errorLabel: some View {
        if showError {
            Text("Identifiant ou mot de passe incorrect")
                .font(Font2.ui(13, .medium))
                .foregroundStyle(Color.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
                .accessibilityAddTraits(.isStaticText)
        }
    }

    // MARK: - Bouton « Se connecter »

    private var submitButton: some View {
        Button(action: attemptLogin) {
            ZStack {
                // Réserve la hauteur pendant le chargement.
                Text("Se connecter")
                    .opacity(isSubmitting ? 0 : 1)

                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                }
            }
            .font(Font2.ui(15, .semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(IrisButtonStyle())
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.55)
        .animation(Motion.reduced(Motion.fade, reduceMotion: reduceMotion), value: isSubmitting)
    }

    // MARK: - Actions

    private func attemptLogin() {
        guard canSubmit else { return }
        focused = nil
        clearError()
        isSubmitting = true

        Task {
            do {
                try await session.login(
                    identity: identity.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                // Succès : RootView bascule sur MainTabView en observant
                // `session.isAuthenticated`.
                Haptics.fire(.success)
                isSubmitting = false
            } catch {
                isSubmitting = false
                Haptics.fire(.error)
                withAnimation(Motion.reduced(Motion.fade, reduceMotion: reduceMotion)) {
                    showError = true
                }
                // Repositionne le focus pour corriger la saisie.
                focused = .password
            }
        }
    }

    private func clearError() {
        guard showError else { return }
        withAnimation(Motion.reduced(Motion.fade, reduceMotion: reduceMotion)) {
            showError = false
        }
    }

    /// Hauteur minimale pour centrer la carte verticalement dans la fenêtre.
    private var screenMinHeight: CGFloat {
        #if canImport(UIKit)
        UIScreen.main.bounds.height - 120
        #else
        640
        #endif
    }
}

// MARK: - Habillage commun des champs (capsule verre)

/// Applique le chrome partagé aux deux champs : typo corps, encre, padding
/// interne et capsule `.glass`. Factorisé pour garantir l'identité visuelle
/// stricte entre TextField et SecureField.
private struct FieldChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font2.ui(16))
            .foregroundStyle(Color.ink)
            .frame(height: 24)
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .glassSurface(.glass, radius: 27)
    }
}

#Preview {
    LoginView()
        .environment(Session())
        .preferredColorScheme(.light)
}
