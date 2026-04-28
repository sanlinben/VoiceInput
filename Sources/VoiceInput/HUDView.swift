import SwiftUI

/// Floating HUD window showing recording status and results.
struct HUDView: View {
    let state: ASRManager.State
    let audioLevel: Float
    let recordingState: HotKeyManager.RecordingState
    let transcription: String

    var body: some View {
        VStack(spacing: 12) {
            // Status icon
            Image(systemName: statusIcon)
                .font(.system(size: 28))
                .foregroundStyle(statusColor)
                .symbolEffect(.pulse, isActive: recordingState == .recording)

            // Status text
            Text(statusText)
                .font(.headline)
                .foregroundStyle(.secondary)

            // Audio level bar (recording only)
            if recordingState == .recording {
                audioLevelBar
            }

            // Transcription text
            if !transcription.isEmpty {
                Text(transcription)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: 300, alignment: .leading)
                    .padding(8)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .cornerRadius(8)
            }

            // Loading progress
            if case .loading(let progress, let status) = state {
                ProgressView(value: progress) {
                    Text(status).font(.caption)
                }
                .frame(width: 200)
            }

            // Error
            if case .error(let msg) = state {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: 300)
            }
        }
        .padding()
        .frame(width: 340)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statusIcon: String {
        switch recordingState {
        case .idle: return "mic.fill"
        case .recording: return "waveform"
        case .transcribing: return "arrow.triangle.2.circlepath"
        }
    }

    private var statusColor: Color {
        switch recordingState {
        case .idle: return .secondary
        case .recording: return .red
        case .transcribing: return .orange
        }
    }

    private var statusText: String {
        if case .loading = state { return "Loading model..." }
        if case .error = state { return "Error" }
        switch recordingState {
        case .idle: return "Idle — Cmd+Shift+D to record"
        case .recording: return "Recording..."
        case .transcribing: return "Transcribing..."
        }
    }

    private var audioLevelBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.green)
                    .frame(
                        width: max(4, geo.size.width * CGFloat(min(audioLevel * 3, 1.0))),
                        height: 4
                    )
            }
        }
        .frame(height: 4)
        .frame(maxWidth: 200)
    }
}
