import SwiftUI
import AVFoundation

/// Bouton de dictée : tap pour enregistrer, tap pour arrêter (auto-stop 60 s).
/// Halo rouge pulsant pendant l'enregistrement ; audio < 1.2 ko ignoré ; transcription via /api/transcribe.
/// (NATIVE_SPEC §2.5, DESIGN §4.3/6.4)
struct MicButton: View {
    @Environment(ComposerState.self) private var composer
    @Environment(APIClient.self) private var api
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var recorder = ClipRecorder()
    @State private var isRecording = false
    @State private var transcribing = false
    @State private var pulse = false
    @State private var autoStop: Task<Void, Never>?

    var body: some View {
        Button(action: toggle) {
            ZStack {
                // Halo rouge qui se dilate en boucle (mic-pulse).
                if isRecording {
                    Circle()
                        .stroke(Color.danger, lineWidth: 2)
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulse ? 1.6 : 1.0)
                        .opacity(pulse ? 0.0 : 0.45)
                }

                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isRecording ? Color.white : Color.ink)
                    .frame(width: 40, height: 40)
                    .background(micBackground)
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(PressStyle())
        .disabled(transcribing)
        .opacity(transcribing ? 0.5 : 1)
        .accessibilityLabel(isRecording ? "Arrêter la dictée" : "Dicter")
        .onChange(of: isRecording) { _, recording in
            guard !reduceMotion else { return }
            if recording {
                pulse = false
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            } else {
                pulse = false
            }
        }
        .onDisappear {
            autoStop?.cancel()
            if isRecording { _ = recorder.stop() }
        }
    }

    @ViewBuilder
    private var micBackground: some View {
        if isRecording {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.micGlowTop, Color.danger],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.danger.opacity(0.5), radius: 10, y: 2)
        } else {
            Circle()
                .fill(.clear)
                .glassSurface(.glass, radius: 20)
        }
    }

    // MARK: - Contrôle

    private func toggle() {
        if isRecording {
            finish()
        } else {
            begin()
        }
    }

    private func begin() {
        Task {
            let granted = await ClipRecorder.requestPermission()
            guard granted else { return }
            do {
                try recorder.start()
                isRecording = true
                Haptics.fire(.tap)
                autoStop = Task {
                    try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                    if !Task.isCancelled && isRecording {
                        finish()
                    }
                }
            } catch {
                Haptics.fire(.error)
            }
        }
    }

    private func finish() {
        autoStop?.cancel()
        autoStop = nil
        isRecording = false
        guard let data = recorder.stop(), data.count >= 1200 else { return }
        transcribing = true
        Task {
            defer { transcribing = false }
            do {
                let result = try await api.transcribe(audio: data, mime: "audio/m4a")
                let text = result.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                let separator = composer.prompt.isEmpty ? "" : " "
                composer.prompt += separator + text
                Haptics.fire(.select)
            } catch {
                Haptics.fire(.error)
            }
        }
    }
}

/// Enregistreur audio interne au bouton (m4a/AAC). Isolé du service `AudioRecorder` global :
/// il n'est utilisé que pour la dictée du composer.
private final class ClipRecorder {
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers])
        try session.setActive(true, options: [])

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictation-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.record()
        self.recorder = recorder
        self.fileURL = url
    }

    /// Arrête l'enregistrement et renvoie les octets bruts (nil si vide/erreur).
    func stop() -> Data? {
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        guard let url = fileURL else { return nil }
        fileURL = nil
        let data = try? Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        return data
    }
}
