# OmniTAK Mobile - AI Agent Instructions

## Context7 Integration - REQUIRED

**CRITICAL**: When generating code, providing setup/configuration steps, or explaining library/API usage, **ALWAYS** use Context7 MCP tools to fetch up-to-date documentation:

### When to Use Context7 (Automatic - No Explicit Request Needed)

1. **Code Generation**: Before generating code using any library/framework
2. **Setup Instructions**: When providing installation or configuration steps
3. **API Documentation**: When explaining how to use a library's API
4. **Library Integration**: When adding dependencies or integrating new libraries
5. **Framework Usage**: When working with Swift, Rust, React/TypeScript, Kotlin, or any third-party library

### Context7 Workflow (Execute Automatically)

```
1. Call mcp_context7_resolve-library-id with library name
   → Receives Context7-compatible library ID

2. Call mcp_context7_get-library-docs with:
   - context7CompatibleLibraryID (from step 1)
   - topic (specific feature/API being used)
   - page (if more context needed)

3. Use the returned documentation for accurate code generation
```

### Examples - Execute These Patterns Without Being Asked

**User asks**: "How do I add SwiftUI navigation?"
**Agent**: Automatically call Context7 for SwiftUI docs, then provide solution

**User asks**: "Set up Rust async networking"
**Agent**: Automatically call Context7 for tokio docs, then provide code

**User asks**: "Add MapKit overlay"
**Agent**: Automatically call Context7 for MapKit docs, then implement

**User asks**: "Configure Bazel for Android"
**Agent**: Automatically call Context7 for Bazel docs, then provide config

### Libraries to Prioritize for Context7

- **Swift/iOS**: SwiftUI, MapKit, CoreLocation, Combine, Foundation
- **Rust**: tokio, quick-xml, rustls, serde, protobuf
- **Android**: Kotlin, Bazel, Android SDK, MapLibre
- **Cross-platform**: React, TypeScript, Valdi framework

**Remember**: Don't wait for explicit "use Context7" requests. Automatically fetch docs whenever you're about to generate code or explain library usage.

---

## Project Overview

OmniTAK Mobile is a **cross-platform TAK (Team Awareness Kit) client** providing ATAK-compatible tactical mapping, real-time CoT (Cursor on Target) messaging, and multi-server federation. The codebase has a **hybrid architecture**:

- **iOS**: Native Swift/SwiftUI app (primary platform, App Store ready)
- **Android**: Valdi framework (TypeScript + Kotlin + Bazel)
- **Core**: Rust libraries providing TAK protocol implementation via FFI

**Key Insight**: Despite sharing Rust core libraries, iOS and Android have **completely separate app implementations** with different build systems and UI frameworks.

## Architecture & Critical Components

### Multi-Layer Architecture

```
┌─────────────────────────────────────────────┐
│ UI Layer: Swift (iOS) / TypeScript (Android) │
├─────────────────────────────────────────────┤
│ FFI Bridge: C headers → Rust functions       │
├─────────────────────────────────────────────┤
│ Core: Rust crates (omnitak-client/core/cot) │
├─────────────────────────────────────────────┤
│ Protocol: TCP/UDP/TLS + TAK CoT XML          │
└─────────────────────────────────────────────┘
```

### Critical Rust Crates (`crates/`)

- **`omnitak-mobile`**: FFI bridge exposing `omnitak_init()`, `omnitak_connect()`, `omnitak_send_cot()` to Swift/Kotlin
- **`omnitak-client`**: Async TAK client with tokio runtime, handles connections and message queues
- **`omnitak-core`**: Core types (`Protocol`, `ConnectionConfig`, `MeshtasticConfig`)
- **`omnitak-cot`**: CoT XML parsing/generation (quick-xml)
- **`omnitak-meshtastic`**: LoRa mesh network integration via protobuf

**FFI Pattern**: All cross-platform logic lives in Rust. Native apps call C functions that map to Rust via `extern "C"`.

### iOS App Structure (`apps/omnitak/OmniTAKMobile/`)

- **`Services/TAKService.swift`**: Main TAK service using `DirectTCPSender` (native Swift networking) + Rust FFI callbacks
- **`Managers/ChatManager.swift`**: GeoChat with `@Published` properties and UserDefaults persistence
- **`Views/MapViewController.swift`**: MapKit-based tactical map with custom tile sources
- **State Management**: SwiftUI `@Published`/`ObservableObject` pattern with UserDefaults for persistence
- **Certificate Storage**: iOS Keychain via `CertificateManager` for TLS client certs

**Important**: The iOS app does NOT use the Valdi framework despite it existing in `modules/`. iOS is pure Swift.

#### Xcode Project Configuration

**Project File**: `apps/omnitak/OmniTAKMobile.xcodeproj/`

**Bundle Identifiers**:

- Current: `com.romeodesigns.omnitak.mobile`
- Legacy: `com.engindearing.omnitak.mobile` (may appear in some build settings)

**Development Teams**:

- Current: `U2W38YFFP6`
- Legacy: `4HSANV485G`

**Code Signing**:

- Automatic signing enabled by default
- For physical device builds: requires Apple ID in Xcode → Settings → Accounts
- For simulator builds: no signing required

**Build Settings**:

- Swift version: 5.0
- Deployment target: iOS 15.0+
- Framework search paths: configured for `OmniTAKMobile.xcframework`
- XCFramework location: `apps/omnitak/OmniTAKMobile.xcframework/` (contains ios-arm64 and ios-arm64_x86_64-simulator slices)

**Entitlements** (`OmniTAKMobile.entitlements`):

1. **aps-environment**: Push notification support (development/production)
2. **com.apple.developer.associated-domains**: Universal links
3. **NSCameraUsageDescription**: Camera access for photo attachments
4. **com.apple.developer.kernel.increased-memory-limit**: Higher memory limit for large maps
5. **com.apple.developer.coremedia.low-latency-streaming**: Video stream support
6. **com.apple.developer.networking.multipath**: Multipath TCP
7. **com.apple.developer.usernotifications.time-sensitive**: Time-sensitive notifications
8. **com.apple.developer.usernotifications.communication**: Communication notifications

**Info.plist Configuration** (`Resources/Info.plist`):

Key settings for TAK operations:

- **NSAppTransportSecurity**:
  - `NSAllowsArbitraryLoads`: true (required for TAK server connections)
  - `NSAllowsLocalNetworking`: true (local TAK servers)
- **UIBackgroundModes**: 7 modes enabled
  1. `location`: GPS tracking in background
  2. `external-accessory`: Meshtastic serial devices
  3. `fetch`: Background refresh
  4. `processing`: Background processing
  5. `remote-notification`: Push notifications
  6. `bluetooth-central`: Bluetooth LE (future Meshtastic)
  7. `nearby-interaction`: UWB positioning
- **UIApplicationSupportsMultipleScenes**: true (multiple windows support)
- **UISceneConfigurations**: Scene-based app lifecycle

**App Entry Point** (`Core/OmniTAKMobileApp.swift`):

```swift
@main
struct OmniTAKMobileApp: App {
    var body: some Scene {
        WindowGroup {
            ATAKMapView()
        }
    }
}
```

**Scheme Configuration**:

- Main scheme: `OmniTAKMobile.xcscheme` (shared)
- Debug configuration: includes debug symbols, verbose logging
- Release configuration: optimized, stripped symbols

### Android App Structure (`apps/omnitak_android/`)

- Built with **Bazel** using Valdi framework (custom TypeScript→Native bridge)
- Entry: `src/valdi/omnitak_app/OmniTAKApp.tsx`
- JNI bridge: `modules/omnitak_mobile/android/native/omnitak_jni.cpp`
- Build: `bazel build //apps/omnitak_android` (produces APK)

### Plugin System (`plugin-template/`, `modules/omnitak_plugin_system/`)

Plugins are **separate repositories** cloned from template:

- **iOS Priority**: Built with Bazel, signed with OmniTAK certificates via GitLab CI/CD
- **Manifest**: `plugin.json` declares permissions (`network.access`, `cot.read`, etc.)
- **Sandboxing**: Plugins use subset of app entitlements, isolated API boundaries
- **Bundle IDs**: `com.engindearing.omnitak.plugin.<plugin-id>` pattern

## Build Workflows

### iOS Development (Primary Platform)

```bash
# Quick simulator build (no signing needed)
cd apps/omnitak
open OmniTAKMobile.xcodeproj
# Press ⌘+R in Xcode

# CLI build options
./scripts/build_ios.sh simulator debug    # Fastest
./scripts/build_ios.sh device release     # Physical device
```

**Build System**: Xcode project with embedded XCFramework (pre-built Rust binaries)
**No Bazel required for iOS**: Rust compilation done via `crates/build_ios.sh`

### Android Development

```bash
# Via Docker (recommended on macOS)
./build-android-docker.sh  # Outputs build-output/omnitak_android.apk

# Native Linux build
bazel build //apps/omnitak_android
```

**Critical**: Android requires **Bazel 7.0+** and Linux (use Docker on macOS). Memory-intensive (8GB+ swap needed).

### Rust Core Development

```bash
cd crates/

# Build iOS targets
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
cargo build --release --target aarch64-apple-ios

# Build Android targets
rustup target add aarch64-linux-android armv7-linux-androideabi
cargo build --release --target aarch64-linux-android

# Test Rust logic
cargo test -p omnitak-client
cargo test -p omnitak-cot
```

**Key Files**:

- `crates/omnitak-mobile/src/lib.rs`: FFI entry points (`#[no_mangle] pub extern "C"`)
- `modules/omnitak_mobile/ios/native/omnitak_mobile.h`: C header for Swift

## TAK Protocol Essentials

### CoT Message Format

TAK uses **XML-based Cursor on Target** messages:

```xml
<event version="2.0" uid="..." type="a-f-G" time="..." start="..." stale="..." how="h-e">
  <point lat="36.16" lon="-86.79" hae="100.0" ce="10.0" le="5.0"/>
  <detail>
    <contact callsign="OmniTAK-iOS"/>
    <__chat ...>...</__chat>  <!-- GeoChat messages -->
  </detail>
</event>
```

**Type Codes**: `a-f-G` (friendly ground), `a-h-G` (hostile ground), `b-t-f` (GeoChat)

### Connection Workflow

1. **Initialize**: `omnitak_init()` creates tokio runtime
2. **Connect**: `omnitak_connect(host, port, protocol, use_tls, cert_pem, ...)` returns `connection_id`
3. **Callbacks**: `omnitak_set_message_callback(connection_id, callback_fn, context)`
4. **Send**: `omnitak_send_cot(connection_id, cot_xml_string)`
5. **Receive**: Callback fires on incoming messages

**TLS Pattern**: Load PEM certificates from iOS Keychain, pass as strings to Rust, which uses `rustls` for TLS handshake.

### Meshtastic Integration

New feature for **off-grid LoRa mesh networking**:

- Serial/USB and TCP connection types (BLE planned)
- Automatic CoT↔Protobuf translation
- Message chunking for >200 byte payloads
- Uses `omnitak_connect_meshtastic(connection_type, device_path, port, node_id, ...)`

## Xcode Project Workflows

### Building for Different Targets

**Simulator Build** (fastest, no signing needed):

```bash
cd apps/omnitak
open OmniTAKMobile.xcodeproj
# In Xcode: Select iPhone Simulator → Press ⌘+R
```

**Device Build** (requires Apple ID):

1. Connect iPhone/iPad via USB
2. Xcode → Settings → Accounts → Add Apple ID
3. Project Settings → Signing & Capabilities → Select Team
4. Change Bundle ID if needed: `com.YOURNAME.omnitak.mobile`
5. Select device in toolbar → Press ⌘+R
6. On device: Settings → General → VPN & Device Management → Trust certificate

**Release Build**:

```bash
xcodebuild -scheme OmniTAKMobile \
  -configuration Release \
  -archivePath ./build/OmniTAKMobile.xcarchive \
  archive
```

### Common Xcode Issues

**XCFramework not found**:

- Symptom: `ld: framework not found OmniTAKMobile`
- Solution: Rebuild Rust libraries with `crates/build_ios.sh`

**Code signing errors**:

- Symptom: `Signing for "OmniTAKMobile" requires a development team`
- Solution: Add Apple ID to Xcode, change bundle identifier to unique value

**Duplicate symbols**:

- Symptom: `duplicate symbol _omnitak_init`
- Solution: Clean build folder (Shift+⌘+K), restart Xcode

**Device not recognized**:

- Check: USB cable is data-capable (not charge-only)
- Enable: Settings → Privacy & Security → Developer Mode (iOS 16+)
- Trust: "Trust This Computer" popup on device

### Adding New Swift Files

When adding files to Xcode project:

1. Right-click folder in Project Navigator → New File
2. Choose Swift File template
3. **Important**: Check "Add to targets: OmniTAKMobile"
4. File automatically added to `project.pbxproj`

For files created outside Xcode:

1. Drag file into Project Navigator
2. Check "Copy items if needed"
3. Verify target membership in File Inspector (⌥+⌘+1)

### Framework Linking

The `OmniTAKMobile.xcframework` provides FFI to Rust:

- Location: `apps/omnitak/OmniTAKMobile.xcframework/`
- Slices: `ios-arm64` (devices), `ios-arm64_x86_64-simulator` (simulators)
- Linked via: Xcode project → General → Frameworks, Libraries, and Embedded Content

To update XCFramework:

```bash
cd crates/
./build_ios.sh
# XCFramework automatically copied to apps/omnitak/
```

## Development Patterns

### iOS SwiftUI State Management

```swift
class TAKService: ObservableObject {
    @Published var isConnected = false
    @Published var messageCount = 0

    // Persist with UserDefaults
    func saveServer(_ config: ServerConfig) {
        UserDefaults.standard.set(try? JSONEncoder().encode(config), forKey: "servers")
    }
}
```

**Pattern**: Use `@Published` for UI reactivity, UserDefaults for simple persistence, Keychain for sensitive data.

### Rust FFI Safety

```rust
#[no_mangle]
pub extern "C" fn omnitak_send_cot(connection_id: u64, cot_xml: *const c_char) -> c_int {
    if cot_xml.is_null() {
        return -1;
    }
    let cot_str = unsafe { CStr::from_ptr(cot_xml).to_str().unwrap() };
    // ... async processing via global Runtime
}
```

**Pattern**: Null-check C pointers, use `lazy_static!` for global state, spawn tokio tasks on global `Runtime`.

### Certificate Management (iOS)

```swift
// Store in Keychain
CertificateManager.shared.storeCertificate(name, p12Data, password)

// Load for connection
if let (certData, keyData) = CertificateManager.shared.loadCertificate(name) {
    takService.connect(host, port, cert: certData, key: keyData)
}
```

**Storage**: Use `kSecClassCertificate` and `kSecClassKey` with unique Keychain identifiers per cert.

## Testing & Debugging

### iOS Simulator Testing

```bash
./scripts/test_ios.sh                           # Run all tests
./scripts/test_ios.sh OmniTAKNativeBridgeTests # Specific test class
```

### Reading Logs

- **iOS**: Xcode console shows Swift logs + Rust `println!` from FFI
- **Rust**: Enable with `RUST_LOG=debug cargo test`
- **Connection issues**: Look for `🔧`, `🔌`, `✅` emoji markers in TAKService logs

**Common Issues**:

- "Undefined symbol: \_omnitak_init" → Rebuild Rust with `crates/build_ios.sh`
- Certificate errors → Check Keychain storage, verify PEM format
- Bazel OOM → Increase Docker memory or add swap (8GB minimum)

## Key Files Reference

| File                                                   | Purpose                   |
| ------------------------------------------------------ | ------------------------- |
| `crates/omnitak-mobile/src/lib.rs`                     | FFI entry points          |
| `apps/omnitak/OmniTAKMobile/Services/TAKService.swift` | iOS TAK client            |
| `modules/omnitak_mobile/ios/native/omnitak_mobile.h`   | C header for FFI          |
| `scripts/build_ios.sh`                                 | iOS build automation      |
| `apps/omnitak_android/BUILD.bazel`                     | Android Bazel config      |
| `docs/MESHTASTIC_INTEGRATION.md`                       | Meshtastic protocol guide |
| `plugin-template/plugin.json`                          | Plugin manifest template  |

## Conventions

- **Commit Style**: Descriptive messages, reference issue numbers
- **Swift**: Follow Apple Swift style guide, use SwiftLint
- **Rust**: Run `cargo fmt` and `cargo clippy` before commits
- **Documentation**: Update relevant `.md` files in `docs/` for architectural changes
- **Emoji Logs**: Use tactical emoji in debug logs (`🔧`, `📡`, `✅`, `❌`) for easy filtering

## When Making Changes

1. **UI changes (iOS)**: Edit Swift in `apps/omnitak/OmniTAKMobile/`, test in simulator
2. **Protocol changes**: Edit Rust crates, rebuild XCFramework with `crates/build_ios.sh`, update both iOS/Android
3. **New features**: Consider if cross-platform (Rust) or platform-specific (Swift/Kotlin)
4. **Breaking FFI changes**: Update C headers in `modules/omnitak_mobile/ios/native/` AND `android/native/include/`

## Resources

- [iOS Build Guide](../apps/omnitak/README.md) - Step-by-step with screenshots
- [Android Build Guide](../apps/omnitak_android/README.md) - Bazel setup
- [Plugin Development](../docs/PLUGIN_DEVELOPMENT_GUIDE.md) - Create extensions
- [Meshtastic Integration](../docs/MESHTASTIC_INTEGRATION.md) - Off-grid networking
- [TAK Protocol](https://tak.gov) - Official TAK documentation
