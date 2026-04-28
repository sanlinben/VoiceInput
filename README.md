Implementation Plan: VoiceInput (macOS 语音输入助手)

## Context

将系统任意文本框的键盘输入替换为语音输入。本地已有 Qwen3-ASR 1.7B 4-bit 模型，利用 speech-swift 库调用 MLX 推理。

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    VoiceInputApp                         │
│  ┌─────────────┐  ┌──────────┐  ┌────────────┐          │
│  │ AppDelegate  │  │ HotKey   │  │ MenuBar    │          │
│  │ (@main)      │  │ Manager  │  │ Extra+Menu │          │
│  └──────┬──────┘  └──────────┘  └────────────┘          │
├─────────┼────────────────────────────────────────────────┤
│         ▼                                                │
│  ┌─────────────┐  ┌────────────┐  ┌────────────┐        │
│  │ AudioCapture │  │ ASRManager │  │ TextInjector│       │
│  │ (AVEngine)   │──│ (模型 +    │──│ (CGEvent    │       │
│  │ AudioRecorder│  │  转写调度)  │  │  + 剪贴板   │       │
│  └─────────────┘  └────────────┘  └────────────┘        │
│                           │                              │
│                           ▼                              │
│                    ┌──────────────┐                      │
│                    │ HUDWindow    │                      │
│                    │ (SwiftUI)    │                      │
│                    └──────────────┘                      │
└──────────────────────────────────────────────────────────┘
```

## Project Structure

```
STT/
├── Package.swift              # SPM: 依赖 soniqo/speech-swift
├── Sources/
│   └── VoiceInput/
│       ├── VoiceInputApp.swift          # @main, MenuBarExtra
│       ├── HotKeyManager.swift          # 全局快捷键 (CGEvent tap + Carbon)
│       ├── AudioRecorder.swift          # 麦克风: AVAudioEngine + 16kHz 重采样
│       ├── ASRManager.swift             # Qwen3ASRModel 加载 + 转写
│       ├── TextInjector.swift           # 文本注入焦点文本框
│       ├── HUDView.swift                # 浮动状态窗口 (SwiftUI)
│       └── Info.plist                   # 权限描述
├── Tests/
│   └── VoiceInputTests/
│       └── ...
└── docs/
    └── prd.md
```

## Core API Flow (from speech-swift)

```swift
// 1. 加载模型
let model = try await Qwen3ASRModel.fromPretrained(path: localModelPath) { progress, status in
    // progress: 0.0~1.0
    // status: "Downloading config...", "Loading weights..."
}

// 2. 转写音频 (16kHz mono float32 PCM)
let text = model.transcribe(audio: samples, sampleRate: 16000, language: "zh")
// language: "auto" → nil 或具体 "en"/"zh"/"ja" 等

// 3. 录音 (from SpeechDemo AudioRecorder)
let recorder = AudioRecorder()
recorder.startRecording()  // AVAudioEngine installTap → resample → 16kHz
let audio = recorder.stopRecording()  // → [Float]
```

## Implementation Phases

### Phase 1: Project Scaffold + Model Loading (M1)
**Files**: `Package.swift`, `ASRManager.swift`, `VoiceInputApp.swift`

- Create SPM package with macOS 15.0 target
- Add dependency: `soniqo/speech-swift`
- Implement `ASRManager` (Observable class):
  - `loadModel(path:)` — calls `Qwen3ASRModel.fromPretrained` with local path
  - `transcribe(audio:language:)` → String
  - State tracking: `isLoaded`, `isLoading`, `loadProgress`, `errorMessage`
- Test: model loads, transcribe a known WAV file → verify text output
- **验证**: `swift build` 通过, 模型加载 < 5s, 转写测试文件返回正确文本

### Phase 2: Audio Recording (M2)
**Files**: `AudioRecorder.swift`

- Port `AudioRecorder` from SpeechDemo:
  - `startRecording()` → AVAudioEngine + 16kHz 重采样 + audioLevel
  - `stopRecording()` → `[Float]`
- Test with a simple terminal test: record 3s silence and speech, dump sample count
- **验证**: 能录制音频、重采样正确、audioLevel 在有声/无声时明显不同

### Phase 3: Global HotKey + MenuBar (M3)
**Files**: `HotKeyManager.swift`, `VoiceInputApp.swift`

- `@main` with `MenuBarExtra` (SwiftUI API)
- Menu with status indicator, settings, quit
- Global hotkey using **CGEvent tap** (monitor key down/up for push-to-talk):
  - `Cmd+Shift+D` default
  - Key down → Recording starts
  - Key up → Recording stops + transcription
- Use `NSEvent.addGlobalMonitorForEvents(matching:)` for simple modifier detection
- **验证**: 注册快捷键, 按下时菜单栏图标变化, 松开后触发转写

### Phase 4: Text Injection (M4)
**Files**: `TextInjector.swift`

- Primary method: **CGEvent-based keyboard typing**
  - Use `CGEvent(keyboardEventSource:)` to type each character
  - Post events to the focused application via `CGEventPost(.cgsSession)`
- Fallback method: **NSPasteboard + Cmd+V simulation**
  - Copy text to `NSPasteboard.general`
  - Post `Cmd+V` via CGEventPost
- Handle edge cases: Chinese characters, punctuation, multiple apps
- Permission requirements: 
  - Accessibility access needed for CGEvent
  - Show onboarding dialog on first launch
- **验证**: 在 TextEdit, VS Code, Safari 地址栏中测试文本注入

### Phase 5: Integration + HUD (M5)
**Files**: `HUDView.swift`, update `ASRManager.swift`, update `HotKeyManager.swift`

- `HUDView`: SwiftUI floating window (`.alwaysOnTop` panel)
  - States: Idle, Recording (with audio level bar), Transcribing, Result
  - Shows partial text, final text, and error messages
- `HotKeyManager`:
  - Push-to-talk mode: press-hold → record, release → transcribe
  - Toggle mode (VAD): press to toggle on/off, auto-detect speech
- Error handling:
  - Model load failure → menu bar notification
  - Microphone permission → first-run dialog
  - Accessibility permission → System Preferences guide
- **验证**: 完整流程端到端工作 Cmd+Shift+D → 录音 → 说话 → 文本注入文本框

## Key Dependencies

| Package | Usage |
|---------|-------|
| `soniqo/speech-swift` | Qwen3ASR (MLX), 可选 SpeechVAD |
| `mlx-swift` (via speech-swift) | GPU 推理 |
| AVFoundation | 麦克风 |
| AppKit/SwiftUI | UI |
| CoreGraphics | CGEvent 文本注入 |

## Model Loading Strategy

1. 首次启动: 使用 `Qwen3ASRModel.fromPretrained(path: modelPath)` 加载本地模型
2. 加载后保持驻留内存, 不卸载
3. 提供启动预加载 (launch at login) 和按需加载两种模式

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| `fromPretrained` 可能无本地路径参数 | 如果 API 无 path 参数, 需 copy 模型到 cache 目录; Qwen3ASR+Protocols.swift 有 `SpeechRecognitionModel` 协议, 可自定义加载 |
| Accessibility 权限拒绝 | 首次引导打开 系统偏好设置; fallback 到剪贴板+通知 |
| 全局快捷键冲突 | 支持自定义快捷键; 默认 `Cmd+Shift+D` (开发者常用且少冲突) |
| 1.7B 模型推理延迟 | 支持 0.6B 模型; 后台异步推理; HUD 显示进度 |

## Verification Plan

1. **单元测试**: 
   - AudioRecorder: 录制 → 转写 → 对比已知文本
   - ASRManager: 模型加载, 错误状态
2. **集成测试**:
   - 快捷键 → 录音 → 转写 → 文本注入 (手动在 TextEdit 测试)
   - 不同应用文本框兼容性 (TextEdit, Safari, VS Code, 终端)
3. **性能测试**:
   - 模型加载时间 (< 5s 已缓存, < 30s 首次)
   - 转写延迟 (< 3s 1.7B, < 1.5s 0.6B)
   - 内存占用 (< 4GB)
