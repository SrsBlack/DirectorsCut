# Directors Cut — Architecture Overview

## Core Principle

**Rust for safety / performance → AVFoundation for video → Metal for GPU → SwiftUI/UIKit for UI**

More concretely:

| Concern | Technology |
|---------|-----------|
| UI shell | SwiftUI (panels, sheets, toolbars) |
| Timeline gestures | UIKit (precise drag/trim/scrub) |
| Video composition | AVFoundation (AVMutableComposition) |
| GPU effects | Metal compute shaders |
| Export | AVAssetWriter (no watermark, full quality) |
| On-device AI | Vision + Core ML + WhisperKit (Phase 3) |
| Project serialisation | Codable → JSON (.dcut) |

---

## Module Dependency Graph

```
App (Xcode target)
 └── UI  ─────────────────────────────────────────────────────────┐
      ├── Editor   (timeline model, undo/redo, serialisation)      │
      ├── Render   (AVComposition builder, Metal compositor)        │
      │    ├── Editor                                               │
      │    └── Effects                                             │
      ├── Effects  (Metal shaders, colour grading, transitions)     │
      ├── Media    (PHPicker import, thumbnails, waveforms)         │
      │    └── Editor                                               │
      ├── Export   (AVAssetWriter, quality presets)                 │
      │    ├── Editor                                               │
      │    └── Render                                               │
      └── AI       (stubs → Vision/Core ML/WhisperKit in Phase 3) ─┘
           └── Editor
```

---

## Data Flow

```
User gesture
    │
    ▼
TimelineViewModel (SwiftUI @Published)
    │  EditCommand
    ▼
AppState.apply(_:)        ← single source of truth for Project
    │
    ├─► Project.timeline  (mutated in place, Codable)
    │
    ├─► EditHistory       (undo/redo stack)
    │
    └─► CompositionBuilder.build(from:)   (async, on demand)
              │
              ▼
         AVMutableComposition + AVVideoComposition + AVAudioMix
              │
              ▼
         PreviewPlayer (AVPlayer)  ──►  PreviewCanvas (AVPlayerLayer / Metal)
              │
              └──► ExportEngine (AVAssetWriter)  ──►  Camera Roll / Files
```

---

## Key Design Decisions

### 1. Immutable-value Timeline model
`Project`, `Timeline`, `Track`, `Clip` are all structs. Mutations go through
`AppState.apply(_:)` which records an `EditCommand` for undo/redo before
modifying the live struct.  This makes the data model trivially serialisable and
testable in isolation.

### 2. Command pattern for undo/redo
Every edit produces an `EditCommand` enum case that knows its own inverse
(`command.inverse`). `EditHistory` stores a stack of applied commands; undo pops
the stack and applies the inverse. No full-snapshot required.

### 3. SwiftUI + UIKit hybrid timeline
The timeline ruler, clip views, and playhead need 60 fps gesture tracking with
snapping.  Pure SwiftUI gesture APIs have latency under heavy update loads.  The
solution: a `UIViewRepresentable` wrapper around a `UIScrollView` drives the
timeline, while the rest of the UI (panels, toolbars) stays in SwiftUI.

### 4. Metal compositor in AVFoundation
`MetalCompositor` implements `AVVideoCompositing`.  AVFoundation calls
`startRequest(_:)` for every frame.  We grab source pixel buffers, upload them
to Metal textures, run the effect shader graph, and write the output buffer back.
This gives us GPU-accelerated colour grading, chroma key, and transitions at no
extra cost during export (the same compositor runs inside AVAssetWriter).

### 5. Watermark-free export via AVAssetWriter
`AVAssetExportSession` has hard-coded preset limitations.  `AVAssetWriter` is
used instead, giving full control over codec, bitrate, colour space, and HDR
metadata.  Nothing is composited in that the user didn't explicitly add — no
watermark, no logo, no restrictions.

### 6. On-device AI (Phase 3)
All AI features run locally:
- **Captions**: WhisperKit (Apple Neural Engine)
- **Background removal**: `VNGeneratePersonSegmentationRequest` (Vision)
- **Object tracking**: `VNTrackObjectRequest` (Vision)
- **Scene detection**: histogram + optional Core ML
No video data ever leaves the device.

---

## File Layout Reference

```
Sources/
 Editor/
   Models/          Clip, Track, Timeline, Effect, Transition, Keyframe, Project
   History/         EditCommand (invertible), EditHistory (undo/redo)
   Serialization/   ProjectFile (.dcut JSON save/load)
 Effects/
   Shaders/         ColorCorrection.metal  ChromaKey.metal  Blur.metal
                    Transitions.metal  LUTApply.metal
   ColorGrading.swift       (parameter presets, Effect extension)
   FilterPipeline.swift     (Metal compute dispatch helpers)
   TransitionRenderer.swift (transition frame rendering)
 Render/
   CompositionBuilder.swift (Timeline → AVMutableComposition)
   MetalCompositor.swift    (AVVideoCompositing + Metal)
   PreviewPlayer.swift      (AVPlayer wrapper, seek/play/scrub)
   FrameCache.swift         (LRU decoded-frame cache)
 Media/
   MediaImporter.swift      (PHPickerViewController delegate)
   MediaLibrary.swift       (asset catalogue for a project)
   ThumbnailGenerator.swift (AVAssetImageGenerator helpers)
   WaveformGenerator.swift  (PCM → normalised amplitude array)
 Export/
   ExportPreset.swift       (quality presets, codec settings)
   ExportEngine.swift       (AVAssetWriter pipeline, progress)
 AI/                        (stubs in Phase 1, real in Phase 3)
   CaptionGenerator.swift
   BackgroundRemover.swift
   ObjectTracker.swift
   SceneDetector.swift
   SilenceDetector.swift
   AudioDenoiser.swift
 UI/
   Timeline/       TimelineView, TrackView, ClipView, Ruler, Playhead, Gestures
   Preview/        PreviewCanvas (AVPlayerLayer), TransportControls
   Properties/     PropertiesPanel, EffectControls, KeyframeEditor, ColorGradingView
   MediaBrowser/   MediaBrowserView
   AITools/        AIToolPanel, CaptionEditorView
   Export/         ExportView
   Layout/         EditorLayout (iPhone), EditorLayoutMac (iPad/Mac)
   Common/         DesignSystem (colours, typography, spacing)
 App/              DirectorsCutScene, AppState (central coordinator)
```
