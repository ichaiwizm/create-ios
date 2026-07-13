//
//  AudioRecorder.swift
//  Create
//
//  Pont natif figé — CONTRACTS §4.4 :
//  `struct AudioRecorder // AVAudioRecorder m4a/AAC → Data ; auto-stop 60s ; ignore <1.2ko`
//
//  Enregistre la dictée vocale du composer dans un fichier m4a/AAC temporaire, puis
//  restitue les octets bruts à envoyer à `APIClient.transcribe(audio:mime:)`.
//  L'auto-stop à 60 s est délégué au matériel via `record(forDuration:)` (aucun timer à
//  entretenir). Un enregistrement de moins de ~1.2 ko (tap accidentel) est ignoré.
//

import Foundation
import AVFoundation

/// Enregistreur audio minimal pour la dictée vocale (NATIVE_SPEC §2.5).
///
/// Valeur (`struct`) tenue par la vue via `@State` : `start()` / `stop()` sont `mutating`
/// et conservent l'instance `AVAudioRecorder` et l'URL entre les deux appels.
struct AudioRecorder {

    // MARK: Constantes figées

    /// Durée maximale d'enregistrement avant coupure automatique (NATIVE_SPEC §2.5).
    static let maxDuration: TimeInterval = 60

    /// Taille plancher : en-dessous, on considère un tap accidentel et on ignore.
    static let minBytes: Int = 1200

    /// MIME transmis à `APIClient.transcribe(audio:mime:)`.
    static let mime = "audio/m4a"

    // MARK: État

    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    /// `true` tant que le matériel capte (avant `stop()` ou l'auto-stop 60 s).
    var isRecording: Bool { recorder?.isRecording ?? false }

    /// Durée écoulée de l'enregistrement en cours (pour un éventuel indicateur visuel).
    var currentTime: TimeInterval { recorder?.currentTime ?? 0 }

    // MARK: Permission micro

    /// Demande (ou relit) l'autorisation micro. À appeler avant `start()`.
    static func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: Cycle de vie

    /// Démarre l'enregistrement m4a/AAC. Coupe automatiquement à `maxDuration`.
    /// - Throws: erreur de configuration de session ou d'ouverture du fichier.
    mutating func start() throws {
        // Session : enregistrement, sortie sur le haut-parleur, mixage.
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .default,
                                options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: [])

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("create-dictation-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 96_000,
        ]

        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.prepareToRecord()
        // Auto-stop matériel à 60 s : pas de timer applicatif à gérer.
        rec.record(forDuration: Self.maxDuration)

        self.recorder = rec
        self.fileURL = url
    }

    /// Arrête l'enregistrement et restitue les octets m4a.
    /// - Returns: `Data` de l'audio, ou `nil` si trop court (< `minBytes`) ou illisible.
    mutating func stop() -> Data? {
        defer { cleanup() }
        guard let recorder, let fileURL else { return nil }

        recorder.stop()

        guard let data = try? Data(contentsOf: fileURL), data.count >= Self.minBytes else {
            return nil
        }
        return data
    }

    /// Annule l'enregistrement en cours sans restituer de données (ex. dismiss).
    mutating func cancel() {
        recorder?.stop()
        cleanup()
    }

    // MARK: Privé

    private mutating func cleanup() {
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        recorder = nil
        fileURL = nil
        // Libère la session pour rendre la sortie audio aux autres apps.
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
