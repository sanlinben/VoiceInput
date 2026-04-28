import Foundation
import Qwen3ASR
import AudioCommon
import Observation

@Observable
@MainActor
final class ASRManager {
    enum State: Equatable {
        case idle
        case loading(progress: Double, status: String)
        case ready
        case transcribing
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var transcription = ""

    private var model: Qwen3ASRModel?

    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    /// Load model from a local path. Uses fromPretrained with offlineMode.
    /// The local path should contain safetensors, config.json, vocab.json, etc.
    func loadModel(from localPath: String) async {
        guard case .idle = state else { return }

        state = .loading(progress: 0, status: "Preparing...")
        transcription = ""

        do {
            let url = URL(fileURLWithPath: localPath)
            let modelId = url.lastPathComponent  // e.g. "Qwen3-ASR-1.7B-4bit"

            let model = try await Qwen3ASRModel.fromPretrained(
                modelId: modelId,
                cacheDir: url,
                offlineMode: true,
                progressHandler: { progress, status in
                    Task { @MainActor in
                        self.state = .loading(progress: progress, status: status)
                    }
                }
            )

            self.model = model
            state = .ready
        } catch {
            state = .error("Model failed to load: \(error.localizedDescription)")
        }
    }

    /// Transcribe audio samples. Must be 16kHz mono float32 PCM.
    func transcribe(audio: [Float], language: String? = nil) async {
        guard let model, case .ready = state else { return }

        state = .transcribing
        transcription = ""

        let text = model.transcribe(
            audio: audio,
            sampleRate: 16000,
            language: language
        )

        transcription = text
        state = .ready
    }
}
