# OmniTAK Android Application

Cross-platform TAK (Team Awareness Kit) client for Android, built with the Valdi framework.

## Overview

OmniTAK Android is the Android version of the OmniTAK mobile application, providing ATAK-compatible tactical awareness capabilities on Android devices. It features:

- **Real-time TAK Connectivity**: Connect to multiple TAK servers (TCP, UDP, TLS, WebSocket)
- **Tactical Mapping**: MapLibre-based maps with offline support
- **CoT Messaging**: Full Cursor on Target (CoT) XML and Protobuf support
- **Military Symbology**: MIL-STD-2525 compliant military symbols via milsymbol.js
- **Multi-server Management**: Connect to and manage multiple TAK servers simultaneously
- **Secure Communications**: TLS with certificate-based authentication

## Architecture

```
OmniTAK Android App
├── TypeScript/TSX (Application Logic)
│   └── Shared with iOS via Valdi framework
├── Kotlin (Native Bridge)
│   ├── OmniTAKNativeBridge.kt - JNI bridge to Rust
│   └── MapLibreMapView.kt - Custom MapLibre view
├── C++ (JNI Layer)
│   └── omnitak_jni.cpp - JNI bindings
└── Rust (Core Library)
    └── libomnitak_mobile.a - TAK protocol implementation
```

## Project Structure

```
apps/omnitak_android/
├── BUILD.bazel              # Bazel build configuration
├── README.md                # This file
├── ICON_ASSETS_README.md    # Icon design guide
│
├── src/valdi/omnitak_app/   # TypeScript entry point
│   ├── App.tsx              # Main app component
│   └── index.ts             # Module exports
│
└── app_assets/android/      # Android resources
    ├── drawable-nodpi/
    │   └── splash.xml       # Splash screen
    ├── mipmap-*/
    │   └── app_icon.png     # App icons (all densities)
    └── values/
        ├── colors.xml       # Color palette
        ├── strings.xml      # String resources
        └── themes.xml       # App themes
```

## Prerequisites

### Required Software

1. **Bazel 7.2.1+**
   ```bash
   # Install Bazel
   brew install bazel  # macOS
   # Or download from https://bazel.build
   ```

2. **Android SDK & NDK**
   - Android Studio Arctic Fox or later
   - Android SDK API 34+
   - Android NDK r21+ (r25 recommended)
   - Build Tools 34.0.0+

3. **Rust Toolchain** (for building native libraries)
   ```bash
   # Install Rust
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

   # Add Android targets
   rustup target add aarch64-linux-android
   rustup target add armv7-linux-androideabi
   rustup target add x86_64-linux-android
   rustup target add i686-linux-android
   ```

4. **Node.js & npm** (for TypeScript dependencies)
   ```bash
   # Install Node.js 18+
   brew install node  # macOS
   ```

### Environment Setup

```bash
# Set Android SDK/NDK paths
export ANDROID_HOME=$HOME/Library/Android/sdk       # macOS
# export ANDROID_HOME=$HOME/Android/Sdk             # Linux

export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/25.1.8937393

# Add to PATH
export PATH=$ANDROID_HOME/platform-tools:$PATH
export PATH=$ANDROID_HOME/tools:$PATH
```

## Building

### Step 1: Build Rust Native Libraries

The Rust libraries must be built from the separate `omni-TAK` repository:

```bash
# Clone omni-TAK repository (if not already cloned)
git clone <omni-TAK-repo-url> ~/omni-TAK

# Set environment variable
export OMNI_TAK_DIR=~/omni-TAK

# Build Android libraries
cd omni-BASE/modules/omnitak_mobile
./build_android.sh
```

This script will:
- Build Rust libraries for all Android architectures
- Copy them to `docs/modules/omnitak_mobile/android/native/lib/`

**Output:**
```
android/native/lib/
├── arm64-v8a/libomnitak_mobile.a       # 64-bit ARM
├── armeabi-v7a/libomnitak_mobile.a     # 32-bit ARM
├── x86_64/libomnitak_mobile.a          # 64-bit Intel (emulator)
└── x86/libomnitak_mobile.a             # 32-bit Intel (legacy)
```

### Step 2: Build Android App with Bazel

```bash
cd omni-BASE

# Build the APK
bazel build //apps/omnitak_android

# Output will be in:
# bazel-bin/apps/omnitak_android/omnitak_android.apk
```

### Step 3: Install on Device/Emulator

```bash
# Install to connected device
adb install -r bazel-bin/apps/omnitak_android/omnitak_android.apk

# Or use Bazel mobile-install for faster incremental builds
bazel mobile-install //apps/omnitak_android
```

## Development Workflow

### Quick Rebuild

For incremental development:

```bash
# Rebuild and install
bazel mobile-install //apps/omnitak_android --start_app

# With logging
bazel mobile-install //apps/omnitak_android --start_app && \
  adb logcat -s OmniTAK:V
```

### Debugging

```bash
# View logs
adb logcat | grep -E "OmniTAK|RustFFI|MapLibre"

# Debug bridge connection
adb logcat -s OmniTAKNativeBridge:V

# Clear app data and restart
adb shell pm clear com.engindearing.omnitak
```

### Building for Release

```bash
# Build release APK
bazel build -c opt //apps/omnitak_android

# Sign APK (requires keystore)
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore release.keystore \
  bazel-bin/apps/omnitak_android/omnitak_android.apk \
  alias_name
```

## Testing

### Run on Emulator

```bash
# List available emulators
emulator -list-avds

# Start emulator
emulator -avd <avd_name>

# Install and run
bazel mobile-install //apps/omnitak_android --start_app
```

### Integration Tests

```bash
# Run Android instrumented tests
bazel test //apps/omnitak_android:tests --test_output=all
```

## Configuration

### App Metadata

Edit `BUILD.bazel` to change:

```python
valdi_application(
    name = "omnitak_android",
    title = "OmniTAK",               # App display name
    version = "0.1.0",                # Version number
    android_package_name = "com.engindearing.omnitak",  # Package
)
```

### Themes and Colors

Edit theme colors in `app_assets/android/values/colors.xml`:

```xml
<color name="omnitak_primary">#1B5E20</color>  <!-- Dark Green -->
<color name="omnitak_accent">#4CAF50</color>    <!-- Bright Green -->
```

### Icons

Replace placeholder icons with branded icons. See `ICON_ASSETS_README.md` for details.

Required sizes:
- mdpi: 48×48 px
- hdpi: 72×72 px
- xhdpi: 96×96 px
- xxhdpi: 144×144 px
- xxxhdpi: 192×192 px

## Architecture Details

### TypeScript Layer

The main application logic is written in TypeScript and shared with iOS:

- **Location**: `docs/modules/omnitak_mobile/src/`
- **Entry Point**: `src/valdi/omnitak/App.tsx`
- **Features**: Map rendering, CoT parsing, UI components, state management

### Native Bridge (Kotlin)

Kotlin bridge between TypeScript and Rust:

- **Location**: `docs/modules/omnitak_mobile/android/native/OmniTAKNativeBridge.kt`
- **Functions**:
  - `connect()` - Establish TAK server connection
  - `disconnect()` - Close connection
  - `sendCoT()` - Send Cursor on Target message
  - `setCallback()` - Register event callbacks

### JNI Layer (C++)

C++ JNI bindings for Kotlin ↔ Rust communication:

- **Location**: `docs/modules/omnitak_mobile/android/native/omnitak_jni.cpp`
- **Build**: CMakeLists.txt

### Rust Core (FFI)

Core TAK protocol implementation:

- **Language**: Rust (async with Tokio)
- **Features**: TCP/UDP/TLS connections, CoT XML parsing, certificate handling
- **Output**: Static library (.a) for each Android ABI

## Troubleshooting

### Build Errors

**Error: `libomnitak_mobile.a not found`**

Solution: Build Rust libraries first
```bash
cd modules/omnitak_mobile
./build_android.sh
```

**Error: `ANDROID_NDK_HOME not set`**

Solution:
```bash
export ANDROID_NDK_HOME=$HOME/Library/Android/sdk/ndk/25.1.8937393
```

**Error: `Bazel version mismatch`**

Solution:
```bash
# Check required version
cat .bazelversion  # Should be 7.2.1

# Install correct version
bazel version
```

### Runtime Errors

**App crashes on launch**

Check logs:
```bash
adb logcat -s AndroidRuntime:E OmniTAK:V
```

Common causes:
- Missing native library for device ABI
- JNI signature mismatch
- Rust panic (check logs for "RUST PANIC")

**Cannot connect to TAK server**

Check:
- Network permissions in AndroidManifest.xml
- Server IP/port/protocol configuration
- TLS certificate validity
- Firewall settings

**Map not loading**

Verify:
- MapLibre native library included
- Internet permission granted
- MapLibre style URL is valid

## Performance

### App Size

Typical APK size with all ABIs:
- Debug: ~25-30 MB
- Release: ~15-20 MB

To reduce size, build for specific ABIs only:
```bash
bazel build //apps/omnitak_android --fat_apk_cpu=arm64-v8a
```

### Memory Usage

Typical memory footprint:
- Base app: ~80 MB
- With map loaded: ~150-200 MB
- Per TAK connection: ~5-10 MB

## Release Checklist

Before releasing to production:

- [ ] Replace placeholder app icons with branded icons
- [ ] Update version in BUILD.bazel
- [ ] Test on physical devices (not just emulator)
- [ ] Test with real TAK server connections
- [ ] Verify all permissions are properly requested
- [ ] Test offline map functionality
- [ ] Review ProGuard rules for release builds
- [ ] Sign APK with release keystore
- [ ] Test on Android 8.0+ and 13+ for permission changes

## Related Documentation

- [../docs/modules/omnitak_mobile/README.md](../../docs/modules/omnitak_mobile/README.md) - Module overview
- [../docs/modules/omnitak_mobile/BUILD_GUIDE.md](../../docs/modules/omnitak_mobile/BUILD_GUIDE.md) - Detailed build instructions
- [../docs/modules/omnitak_mobile/INTEGRATION.md](../../docs/modules/omnitak_mobile/INTEGRATION.md) - Integration guide
- [../docs/modules/omnitak_mobile/android/README.md](../../docs/modules/omnitak_mobile/android/README.md) - Android MapLibre guide

## License

See main repository LICENSE file.

## Support

For issues and questions:
- Check the main README.md
- Review BUILD_STATUS.md for known issues
- File issues in the GitHub repository
