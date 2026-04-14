# Setting up the Xcode Project

The Directors Cut repository is structured as a **Swift Package** (all the library
logic lives in `Sources/`) plus a separate **Xcode app target** that provides the
`@main` entry point and links everything together.

Follow these steps to create the Xcode project and get the app running on your
iPhone or Mac.

---

## Prerequisites

| Requirement | Version |
|-------------|---------|
| macOS       | 14 Sonoma or later |
| Xcode       | 15.0 or later |
| iPhone      | iOS 17+ (or use the Simulator) |

---

## Steps

### 1. Clone the repository

```bash
git clone <repo-url> DirectorsCut
cd DirectorsCut
```

### 2. Open the Swift Package in Xcode

```bash
open Package.swift
```

Xcode will resolve dependencies and index the package. Verify that the
`EditorTests` scheme builds and tests pass:

```
Product → Test (⌘U)
```

### 3. Create the Xcode Application project

1. **File → New → Project…**
2. Choose **iOS → App**
3. Fill in:
   - **Product Name**: `DirectorsCut`
   - **Bundle Identifier**: `com.yourname.directorscut`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Minimum Deployments**: iOS 17.0
4. Save the `.xcodeproj` **inside** the `DirectorsCut` folder (next to `Package.swift`)

### 4. Add the local Swift Package

1. In the Xcode project navigator, select the project root
2. **File → Add Package Dependencies…**
3. Click **Add Local…** and select the `DirectorsCut` folder (the one containing `Package.swift`)
4. Add all library products:
   - `DirectorsCutEditor`
   - `DirectorsCutRender`
   - `DirectorsCutEffects`
   - `DirectorsCutAI`
   - `DirectorsCutExport`
   - `DirectorsCutMedia`
   - `DirectorsCutUI`

### 5. Replace the generated entry point

Delete the auto-generated `ContentView.swift` and `<AppName>App.swift` from the
Xcode target, then create a new `DirectorsCutApp.swift` in the **Xcode target**
(not inside `Sources/`) with:

```swift
import SwiftUI
import UI

@main
struct DirectorsCutApp: App {
    var body: some Scene {
        WindowGroup {
            EditorLayout()
                .preferredColorScheme(.dark)
        }
    }
}
```

### 6. Add required Info.plist keys

In the Xcode target's `Info.plist` (or via the target's **Info** tab), add:

| Key | Value |
|-----|-------|
| `NSPhotoLibraryUsageDescription` | "Directors Cut needs access to import your videos." |
| `NSPhotoLibraryAddUsageDescription` | "Directors Cut saves exported videos to your library." |
| `NSMicrophoneUsageDescription` | "Directors Cut uses the microphone for audio captions." |
| `NSCameraUsageDescription` | "Directors Cut uses the camera to record new clips." |

### 7. Set capabilities

In **Signing & Capabilities**:
- Enable **iCloud** → check **CloudKit** and **iCloud Documents** (for future cloud sync)
- Enable **Background Modes** → **Audio, AirPlay, and Picture in Picture**

### 8. Run on device or Simulator

```
Product → Run (⌘R)
```

Select your iPhone or an iOS 17 Simulator. The app should launch and display the
timeline editor.

---

## Project structure overview

```
DirectorsCut/              ← git repo root
├── Package.swift          ← SPM package (all library logic)
├── Sources/               ← Swift modules (Editor, Render, Effects, …)
├── Tests/                 ← Unit tests
├── docs/                  ← Documentation
├── DirectorsCut.xcodeproj ← Xcode app project (you create this in step 3)
└── DirectorsCut/          ← Xcode target sources (entry point + assets)
    ├── DirectorsCutApp.swift
    ├── Assets.xcassets
    └── Info.plist
```

---

## Running the tests from the command line

```bash
# Run all unit tests (no simulator needed)
swift test

# Run only the editor logic tests
swift test --filter EditorTests

# Run export preset tests
swift test --filter ExportTests
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "No such module 'UI'" in app target | Make sure all library products are linked in the app target's Frameworks list |
| Metal shader compile errors | Ensure **Compile Sources** in the `Effects` library target includes the `.metal` files |
| "ambiguous use of '@main'" | There must be exactly one `@main` in the app target — remove any duplicate |
| Photo picker doesn't appear | Add `NSPhotoLibraryUsageDescription` to Info.plist |
