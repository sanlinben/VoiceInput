import AppKit
import Carbon
import Observation

/// Manages a global hotkey for toggling recording.
/// Uses Carbon RegisterEventHotKey for reliable global shortcut registration.
/// Mode: tap Cmd+Shift+D to start recording, tap again to stop and transcribe.
@Observable
@MainActor
final class HotKeyManager: ObservableObject {
    enum RecordingState: Equatable {
        case idle
        case recording
        case transcribing
    }

    private(set) var recordingState: RecordingState = .idle

    var onStartRecording: (() -> Void)?
    var onStopRecording: (() -> Void)?
    var onCancelRecording: (() -> Void)?

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    private let keyCode: UInt32 = 0x02  // 'D'
    private let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

    func register() {
        let hotKeyID = EventHotKeyID(signature: 0x56494e50, id: 1)

        // Register the hotkey
        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                           GetEventDispatcherTarget(), 0, &hotKeyRef)

        // Install event handler
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), { (_: EventHandlerCallRef?, _: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handleHotKeyPress()
            return noErr
        } as EventHandlerProcPtr, 1, &eventType, selfPtr, &eventHandler)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    func handleHotKeyPress() {
        switch recordingState {
        case .idle:
            recordingState = .recording
            onStartRecording?()
        case .recording:
            recordingState = .transcribing
            onStopRecording?()
        case .transcribing:
            break
        }
    }

    func finishTranscribing() {
        recordingState = .idle
    }

    func cancelRecording() {
        guard recordingState == .recording else { return }
        recordingState = .idle
        onCancelRecording?()
    }

    deinit {
        unregister()
    }
}
