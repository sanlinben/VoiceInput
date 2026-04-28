# PRD: 语音输入助手 (VoiceInput)

## 1. 产品概述

一个 macOS 菜单栏应用，将系统任意文本框的键盘输入替换为语音输入。用户按下快捷键开始录音，说话结束后自动转写，文本直接注入当前聚焦的文本框。

核心思路参考 [speech-swift/Examples/SpeechDemo](https://github.com/soniqo/speech-swift/tree/main/Examples/SpeechDemo) — 一个 SwiftUI macOS 应用，演示了 Qwen3ASR 模型的语音转写能力。

## 2. 目标用户

- 一人公司/小团队开发者，需要高效文字输入但不想长时间打字。
- 多语言用户（中/英/日/韩等，模型支持 30+ 语种）。

## 3. 功能需求

### 3.1 核心流程

```
用户按下全局快捷键 → (首次)模型加载 → 麦克风开始录音 → push-to-talk 或 VAD 自动检测
→ 说话结束 → 调用 Qwen3ASR 模型转写 → 文本自动注入当前聚焦文本框
```

### 3.2 两种输入模式

| 模式 | 触发方式 | 适用场景 |
|------|----------|----------|
| Push-to-Talk (P0) | 按住快捷键期间录音，松开即转写 | 快速输入，精准控制 |
| VAD 模式 (P1) | 快捷键切换开关，检测到语音自动开始/结束 | 免手持，连续输入 |

### 3.3 功能清单

| 编号 | 功能 | 优先级 | 说明 |
|------|------|--------|------|
| F1 | 全局快捷键录音 | P0 | 默认 `Cmd+Shift+D`，按下开始/松开结束（push-to-talk） |
| F2 | 麦克风录音 | P0 | 使用 AVAudioEngine，自动重采样到 16kHz 单声道 |
| F3 | Qwen3ASR 本地转写 | P0 | 调用 `Qwen3ASRModel.transcribe(audio:sampleRate:language:)` |
| F4 | 文本注入焦点文本框 | P0 | 通过 Accessibility API 或 CGEvent 模拟键盘输入 |
| F5 | 菜单栏图标 + 状态指示 | P0 | 菜单栏图标显示录音状态（闲置/录音中/转写中） |
| F6 | 模型加载与缓存 | P0 | 首次从 HuggingFace 下载，缓存到 `~/Library/Caches/qwen3-speech/` |
| F7 | 转写结果 HUD 浮窗 | P1 | 浮动半透明窗口，显示实时转写文字与录音状态 |
| F8 | 多语言自动检测 | P1 | 模型自动检测语言，也可手动指定（en/zh/ja/ko/fr/es/de/ru） |
| F9 | VAD 自动模式 | P1 | Silero VAD 检测语音起止，免按键操作 |
| F10 | 模型配置管理 | P2 | 支持指定本地模型路径、切换模型大小（0.6B / 1.7B） |
| F11 | 转写历史 | P2 | 最近转写记录面板，支持复制与回看 |

### 3.4 模型集成

- **模型路径**: `/Users/benchi/.omlx/models/mlx-community/Qwen3-ASR-1.7B-4bit`
- **加载方式**: `Qwen3ASRModel.fromPretrained(path:)`，支持传入自定义路径
- **API 签名**:
  ```swift
  // 异步加载（支持进度回调）
  let model = try await Qwen3ASRModel.fromPretrained { progress, status in
      // progress: 0.0~1.0, status: 状态描述
  }
  
  // 同步转写
  let text = model.transcribe(audio: samples, sampleRate: 16000, language: "zh")
  // language: nil = 自动检测, 或指定 "en"/"zh"/"ja" 等
  ```
- **音频配置**: 16kHz 单声道 float32 PCM
- **模型规格**:
  - 架构: Qwen3ASRForConditionalGeneration (encoder-decoder)
  - 参数: 1.7B（备选 0.6B）
  - 量化: 4-bit MLX
  - 缓存大小: ~400 MB (0.6B) / ~2 GB (1.7B)

### 3.5 技术架构

```
┌─────────────────────────────────────────────────┐
│                    UI 层                          │
│  ┌──────────────┐  ┌──────────┐  ┌────────────┐ │
│  │ 菜单栏图标 +   │  │ 浮动 HUD  │  │ 快捷键监听   │ │
│  │ 状态菜单      │  │ (SwiftUI) │  │ (HotKey)   │ │
│  └──────────────┘  └──────────┘  └────────────┘ │
├─────────────────────────────────────────────────┤
│                  业务层                            │
│  ┌──────────────┐  ┌──────────┐  ┌────────────┐ │
│  │ AudioRecorder │  │ 转写管道   │  │ TextInjector│ │
│  │ (AVAudioEngine│  │ (ASR +   │  │(Accessibility│ │
│  │ + resample)   │  │  VAD)    │  │ /CGEvent)   │ │
│  └──────────────┘  └──────────┘  └────────────┘ │
├─────────────────────────────────────────────────┤
│                  模型层 (speech-swift)              │
│  ┌──────────────┐  ┌──────────┐                   │
│  │ Qwen3ASR     │  │ Silero   │                   │
│  │ (MLX 4bit)   │  │ VAD      │                   │
│  └──────────────┘  └──────────┘                   │
└─────────────────────────────────────────────────┘
```

API 参考自 SpeechDemo 的 `DictateViewModel`:
- `AudioRecorder` — `startRecording()` / `stopRecording() -> [Float]`
- `Qwen3ASRModel` — `fromPretrained()` / `transcribe(audio:sampleRate:language:)`
- 文本注入 — `NSPasteboard` + `CGEvent` 模拟粘贴，或 Accessibility API

## 4. 非功能需求

| 编号 | 要求 | 说明 |
|------|------|------|
| N1 | 延迟 | 首次模型加载 < 5s (已缓存); 单次转写 < 3s (1.7B) / < 1.5s (0.6B) |
| N2 | 内存 | 模型驻留内存 < 4GB (4-bit 1.7B) |
| N3 | 离线 | 模型加载完成后完全离线运行，无需网络 |
| N4 | 兼容性 | macOS 15+ (Sequoia), Apple Silicon (M1+) |
| N5 | 隐私 | 所有音频处理和模型推理在本地完成，不上传任何数据 |
| N6 | 模型缓存 | 模型下载到 `~/Library/Caches/qwen3-speech/`，后续自动加载 |

## 5. 验收标准

### 5.1 必须通过 (P0)

- [ ] 按下全局快捷键（默认 `Cmd+Shift+D`），麦克风开始录音，菜单栏图标切换为录音状态
- [ ] 松开快捷键，录音停止，调用 Qwen3ASR 转写
- [ ] 转写文本自动注入当前聚焦的文本框（TextEdit、Safari、VS Code、终端等）
- [ ] 首次启动自动从 HuggingFace 下载模型，缓存到本地
- [ ] 模型已缓存时，启动加载 < 5s
- [ ] 菜单栏图标清晰指示当前状态（闲置/录音/转写）

### 5.2 应该通过 (P1)

- [ ] Push-to-Talk 模式下，HUD 浮窗显示实时音频电平指示器
- [ ] 支持中/英/日/韩等语言，模型自动检测
- [ ] VAD 模式：检测到语音自动开始录音，静默后自动结束转写
- [ ] 模型路径可通过配置文件或设置面板指定本地目录

### 5.3 可选 (P2)

- [ ] 模型大小切换 (0.6B / 1.7B)
- [ ] 转写历史面板
- [ ] 快捷键可自定义（通过设置面板）

## 6. 参考实现分析 (speech-swift/SpeechDemo)

### 6.1 项目结构与关键文件

```
Examples/SpeechDemo/
├── Package.swift                    # SPM 依赖: speech-swift(父包) → ParakeetASR, Qwen3ASR, SpeechVAD, AudioCommon
├── SpeechDemo/
│   ├── SpeechDemoApp.swift          # @main 入口, TabView(Dictate, Speak, Echo)
│   ├── DictateViewModel.swift       # 核心: 模型管理 + 录音 + 转写 + 剪贴板
│   ├── DictateView.swift            # UI: 引擎选择、录音按钮、结果展示
│   ├── AudioRecorder.swift          # AVAudioEngine 麦克风捕获, 16kHz 重采样
│   ├── SpeakView.swift / SpeakViewModel.swift    # TTS (参考)
│   └── EchoView.swift / EchoViewModel.swift      # 全双工语音管道 (参考)
└── Tests/
```

### 6.2 核心数据流 (DictateViewModel)

```
1. 用户选择引擎 (Parakeet / Qwen3-ASR)
2. 点击 "Load" → model.fromPretrained(progressHandler) → 缓存到 ~/Library/Caches/qwen3-speech/
3. 点击 "Record" → AudioRecorder.startRecording() → AVAudioEngine 采集 16kHz mono float32
4. 点击 "Stop" → AudioRecorder.stopRecording() → [Float] → model.transcribe(audio:, sampleRate:, language:)
5. 结果展示 → copyToClipboard() (NSPasteboard / UIPasteboard)
```

### 6.3 与本项目的差异

| 维度 | SpeechDemo | 本项目 |
|------|-----------|--------|
| 使用场景 | 应用内 Dictate 标签页 | 系统级后台菜单栏应用 |
| 触发方式 | 手动点击 Record/Stop 按钮 | 全局快捷键 (push-to-talk 或 VAD) |
| 文本输出 | 展示在界面 + 手动复制 | 自动注入焦点文本框 |
| 模型加载 | 用户手动点击 Load | 启动后台自动加载 |
| 界面 | SwiftUI 主窗口 (TabView) | 菜单栏图标 + 轻量 HUD 浮窗 |

### 6.4 可复用模式

1. **Qwen3ASRModel API**: `fromPretrained()` 异步加载 + `transcribe(audio:sampleRate:language:)` 同步转写
2. **AudioRecorder**: AVAudioEngine installTap + 重采样到 16kHz + RMS 电平计算
3. **模型缓存**: 自动缓存到 `~/Library/Caches/qwen3-speech/`，支持自定义路径
4. **多语言**: 传入 `language: nil` 自动检测，或指定具体语言代码
5. **错误处理**: try-catch + errorMessage 展示模式

## 7. 依赖

| 依赖 | 来源 | 用途 |
|------|------|------|
| speech-swift | GitHub (soniqo/speech-swift) | Qwen3ASRModel、SileroVAD、AudioCommon |
| MLX (via speech-swift) | Apple / mlx.ai | Apple Silicon 张量计算 |
| AVFoundation (系统) | Apple | 麦克风捕获 |
| SwiftUI / AppKit (系统) | Apple | 菜单栏图标、HUD 界面 |
| Accessibility API / CGEvent (系统) | Apple | 文本注入焦点文本框 |

## 8. 风险与约束

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| macOS 15+ 要求 | 用户需升级系统 | 暂无降级计划（speech-swift 要求 15.0） |
| Accessibility API 权限 | 无法注入部分应用 | fallback: 自动复制到剪贴板 + 通知用户 Cmd+V |
| 1.7B 模型在 M1 上推理较慢 | 用户体验下降 | 提供 0.6B 模型备选 |
| 模型文件较大 (~2-4GB) | 首次下载/磁盘占用 | 显示下载进度；提供模型选择 |
| 后台录音隐私合规 | 用户信任 | 本地处理，不上传；录音时菜单栏有明确指示 |

## 9. 项目结构

```
STT/
├── Package.swift                    # Swift Package (spm)
├── Sources/
│   ├── VoiceInputApp.swift          # @main 入口, 菜单栏图标 + 状态管理
│   ├── AudioRecorder.swift          # 参照 SpeechDemo 的 AVAudioEngine 实现
│   ├── HotKeyManager.swift          # 全局快捷键监听 (NSEvent 或 HotKey 库)
│   ├── TranscriptionManager.swift   # 模型管理 + 转写调度 (参照 DictateViewModel)
│   ├── TextInjector.swift           # Accessibility API / CGEvent 注入
│   └── HUDView.swift                # 浮动状态窗口 (SwiftUI)
├── Tests/
│   └── VoiceInputTests.swift
├── docs/
│   └── prd.md                       # 本文档
└── Resources/
    └── Assets.xcassets              # 菜单栏图标
```

## 10. 里程碑

| 阶段 | 内容 | 预估周期 |
|------|------|----------|
| M1 — 模型集成 | 封装 Qwen3ASRModel 加载和转写，终端测试通过 | 2 天 |
| M2 — 录音管道 | AudioRecorder + VAD + 转写管道打通 | 2 天 |
| M3 — 菜单栏 + HUD | 菜单栏图标 + 浮动窗口，状态指示 | 2 天 |
| M4 — 文本注入 | Accessibility API / CGEvent 注入任意文本框 | 2 天 |
| M5 — 快捷键 + 完整闭环 | 全局快捷键 push-to-talk + VAD 模式，端到端测试 | 2 天 |

**总计预估: ~10 个工作日 (一人开发)**
