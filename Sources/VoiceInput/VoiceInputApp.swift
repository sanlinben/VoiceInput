import SwiftUI
import AppKit

@main
struct VoiceInputApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            AppMenuView()
        } label: {
            MenuBarIconView(manager: appDelegate.hotKeyManager)
        }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let asrManager = ASRManager()
    let recorder = AudioRecorder()
    let hotKeyManager = HotKeyManager()

    private var hudWindow: NSWindow?
    private var hudHostingView: NSHostingView<HUDView>?

    private var modelPath: String {
        if let envPath = ProcessInfo.processInfo.environment["VOICEINPUT_MODEL_PATH"] {
            return envPath
        }
        // Default to standard MLX cache location
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".omlx/models/mlx-community/Qwen3-ASR-1.7B-4bit").path
    }

    var menuBarIcon: String {
        switch hotKeyManager.recordingState {
        case .idle: return "mic.fill"
        case .recording: return "waveform.badge.mic"
        case .transcribing: return "arrow.triangle.2.circlepath"
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupHotkey()
        createHUDWindow()
        autoLoadModel()
    }

    // MARK: - Model Loading

    func loadModel() {
        guard !asrManager.isReady else { return }
        Task {
            await asrManager.loadModel(from: modelPath)
            refreshHUD()
        }
    }

    private func autoLoadModel() {
        Task {
            await asrManager.loadModel(from: modelPath)
            refreshHUD()
        }
    }

    // MARK: - Hotkey Setup

    private func setupHotkey() {
        hotKeyManager.onStartRecording = { [weak self] in
            guard let self else { return }
            self.recorder.startRecording()
            self.showHUD()
            self.refreshHUD()
        }
        hotKeyManager.onStopRecording = { [weak self] in
            guard let self else { return }
            let audio = self.recorder.stopRecording()
            self.refreshHUD()
            Task {
                await self.asrManager.transcribe(audio: audio)
                let text = self.asrManager.transcription
                if !text.isEmpty {
                    TextInjector.typeText(text)
                }
                self.hotKeyManager.finishTranscribing()
                self.refreshHUD()
                // Keep HUD visible for 2 seconds to show result
                try? await Task.sleep(for: .seconds(2))
                self.hideHUD()
            }
        }
        hotKeyManager.onCancelRecording = { [weak self] in
            guard let self else { return }
            _ = self.recorder.stopRecording()
            self.hideHUD()
            self.refreshHUD()
        }
        hotKeyManager.register()
    }

    // MARK: - HUD Window

    private func createHUDWindow() {
        let hudView = makeHUDView()
        let hostingView = NSHostingView(rootView: hudView)
        self.hudHostingView = hostingView

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 200),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        self.hudWindow = window
    }

    private func makeHUDView() -> HUDView {
        HUDView(
            state: asrManager.state,
            audioLevel: recorder.audioLevel,
            recordingState: hotKeyManager.recordingState,
            transcription: asrManager.transcription
        )
    }

    func showHUD() {
        positionHUDWindow()
        hudWindow?.orderFrontRegardless()
    }

    func hideHUD() {
        hudWindow?.orderOut(nil)
    }

    func toggleHUD() {
        if hudWindow?.isVisible == true {
            hideHUD()
        } else {
            showHUD()
        }
    }

    private func positionHUDWindow() {
        guard let window = hudWindow, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        let x = screenFrame.maxX - windowFrame.width - 20
        let y = screenFrame.maxY - windowFrame.height - 20
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func refreshHUD() {
        hudHostingView?.rootView = makeHUDView()
    }
}

// MARK: - Menu Bar Icon

struct MenuBarIconView: View {
    @ObservedObject var manager: HotKeyManager

    var body: some View {
        Image(systemName: iconName)
    }

    private var iconName: String {
        switch manager.recordingState {
        case .idle: return "mic.fill"
        case .recording: return "waveform.badge.mic"
        case .transcribing: return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - Menu Content

struct AppMenuView: View {
    @State private var asrReady = false
    @State private var asrLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VoiceInput").font(.headline)

            Divider()

            // Model status
            HStack {
                Circle()
                    .fill(asrReady ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(asrReady ? "Model Ready" : "Model Not Loaded")
                    .font(.caption)
            }

            if !asrReady {
                Button("Load Model") {
                    loadModel()
                }
                .disabled(asrLoading)
            }

            Divider()

            Text("Cmd+Shift+D to record")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 200)
        .onAppear {
            updateState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            updateState()
        }
    }

    private func updateState() {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }
        asrReady = delegate.asrManager.isReady
        if case .loading = delegate.asrManager.state {
            asrLoading = true
        } else {
            asrLoading = false
        }
    }

    private func loadModel() {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }
        delegate.loadModel()
    }
}
