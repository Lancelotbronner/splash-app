# Building from Source

Splash Monitor is built as a native Xcode project (`Splash.xcodeproj`), not via Swift Package Manager.

## Requirements

- Mac with Apple Silicon (M3 or newer)
- macOS 26.4 (Tahoe) or later
- Xcode 26 (current release)
- [Inco AI Splash](https://github.com/incoai/splash) engine installed and running, to exercise the app against a live server:

  ```bash
  brew install incoai/tap/splash
  ```

## Build & Run

1. Open the project:

   ```bash
   open Splash.xcodeproj
   ```

2. Select the **Splash** scheme.
3. `⌘R` to build and run the Debug configuration.

### Release build from the command line

```bash
xcodebuild -project Splash.xcodeproj -scheme Splash -configuration Release build
```

The bundle lands in Xcode's derived data under `Build/Products/Release/` (e.g. `~/Library/Developer/Xcode/DerivedData/Splash-*/Build/Products/Release/Splash Monitor.app`).

## Packaging a DMG

```bash
# 1. Copy the built bundle next to the script's working directory
cp "/path/to/Build/Products/Release/Splash Monitor.app" .

# 2. Create the compressed image
hdiutil create -volname "Splash Monitor" \
  -srcfolder "Splash Monitor.app" -ov -format UDZO SplashMonitor.dmg

# 3. Publish the checksum (verified by the 1-line installer)
shasum -a 256 SplashMonitor.dmg > SHA256SUMS
```

## Versioning

`Splash/Services/Version.swift` is the single source of truth for the version, bundle identifier, and build number. Change it there only.
