# PocketTTSClone — Offline Voice Cloning for iOS

A native iOS app using SwiftUI + sherpa-onnx + Pocket TTS for offline voice cloning.

## Project Structure

```
app/PocketTTSClone/     ← iOS SwiftUI app (the main project)
sherpa-onnx/            ← Cloned sherpa-onnx dependency (not in git)
pocket-tts/             ← Cloned Pocket TTS dependency (not in git)
build/                  ← Build artifacts (not in git)
models/                 ← Model files (not in git)
```

## Build

See [GitHub Actions workflow](app/PocketTTSClone/.github/workflows/build-ios.yml) for automated builds.

**Prerequisites:**
- macOS with Xcode 16+
- sherpa-onnx iOS xcframework (built via `build-ios.sh`)

**Manual build (on macOS):**
```bash
cd path/to/sherpa-onnx
./build-ios.sh

cd path/to/PocketTTSClone
xcodebuild -scheme PocketTTSClone -destination 'generic/platform=iOS' build
```

**Deploy via AltStore:**
1. Download the IPA from GitHub Actions artifacts
2. Use AltServer to install AltStore on iPhone
3. Open AltStore → My Apps → tap + → select IPA
