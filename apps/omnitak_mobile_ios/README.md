# OmniTAK Mobile - iOS Application

iOS test application for OmniTAK Mobile SDK, demonstrating TAK server connectivity and MapLibre GL Native integration.

## Overview

This is a native iOS application that showcases the capabilities of OmniTAK Mobile:

- **TAK Server Connectivity** - Connect to TAK servers via TCP/UDP/TLS/WebSocket
- **CoT Messaging** - Send and receive Cursor-on-Target messages
- **MapLibre Integration** - Display tactical maps with markers and overlays
- **Cross-Platform FFI** - Demonstrates Rust ↔ Swift interop via C FFI
- **Valdi Framework** - Integration point for TypeScript-driven UI (future)

## Quick Start

```bash
# Build and run on iOS simulator
./scripts/run_ios_simulator.sh

# Or build manually
./scripts/build_ios.sh simulator debug

# Run tests
./scripts/test_ios.sh
```

## Features

### Implemented

- Native iOS app with Swift UI
- OmniTAK native library integration via XCFramework
- MapLibre GL Native map rendering
- TAK server connection management
- CoT message send/receive
- Location services integration
- Unit and integration tests
- Simulator and device support

### Planned

- Valdi TypeScript UI integration
- Advanced map features (layers, annotations)
- Certificate management UI
- Settings and preferences
- Background location tracking
- Push notifications

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────┐
│         iOS Application Layer           │
│  (Swift - AppDelegate, ViewController)  │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┴──────────┐
        │                    │
┌───────▼────────┐  ┌────────▼────────┐
│ OmniTAK Bridge │  │  MapLibre View  │
│ (Swift Wrapper)│  │  (Obj-C Wrapper)│
└───────┬────────┘  └────────┬────────┘
        │                    │
┌───────▼────────┐  ┌────────▼────────┐
│  C FFI Layer   │  │ MapLibre Native │
│ (omnitak_*.h)  │  │   (C++ Core)    │
└───────┬────────┘  └─────────────────┘
        │
┌───────▼────────┐
│ Rust Core Lib  │
│ (omnitak-core) │
└────────────────┘
```

### Key Components

1. **AppDelegate.swift** - App lifecycle, initialization
2. **ViewController.swift** - Main UI, demonstrates all features
3. **OmniTAKNativeBridge.swift** - Swift wrapper around C FFI
4. **OmniTAKMobile.xcframework** - Compiled Rust library for iOS
5. **SCMapLibreMapView** - Valdi custom view for MapLibre

## Project Structure

```
apps/omnitak_mobile_ios/
├── BUILD.bazel              # Bazel build configuration
├── README.md                # This file
├── IOS_BUILD_GUIDE.md       # Detailed build instructions
│
├── src/ios/
│   ├── AppDelegate.swift    # App entry point
│   └── ViewController.swift # Main UI and demo code
│
├── app_assets/ios/
│   ├── Info.plist          # App configuration and permissions
│   └── LaunchScreen.storyboard
│
└── tests/ios/
    └── OmniTAKTests.swift  # Unit and integration tests
```

## Building

### Prerequisites

- macOS 12.0+ (Monterey or later)
- Xcode 14.0+
- Bazel 6.0+
- Rust toolchain with iOS targets

See [IOS_BUILD_GUIDE.md](IOS_BUILD_GUIDE.md) for detailed setup instructions.

### Build Commands

```bash
# Simulator (recommended for development)
./scripts/build_ios.sh simulator debug

# Device (requires code signing)
./scripts/build_ios.sh device debug

# Release builds
./scripts/build_ios.sh simulator release
./scripts/build_ios.sh device release

# Using Bazel directly
bazel build //apps/omnitak_mobile_ios:OmniTAKMobile-Simulator \
    --config=ios_sim_debug
```

## Running

### On Simulator

```bash
# Automatic (recommended)
./scripts/run_ios_simulator.sh

# Specific device
./scripts/run_ios_simulator.sh "iPhone 15 Pro"
./scripts/run_ios_simulator.sh "iPad Pro (12.9-inch)"

# Manual
xcrun simctl boot <device-udid>
xcrun simctl install <device-udid> bazel-bin/.../OmniTAKMobile-Simulator.app
xcrun simctl launch --console <device-udid> com.engindearing.omnitak.mobile
```

### On Device

```bash
# Build for device
./scripts/build_ios.sh device debug

# Install via Xcode or ios-deploy
ios-deploy --bundle bazel-bin/.../OmniTAKMobile.app
```

## Testing

### Run All Tests

```bash
./scripts/test_ios.sh
```

### Run Specific Tests

```bash
# Test native bridge
./scripts/test_ios.sh OmniTAKNativeBridgeTests

# Test MapLibre integration
./scripts/test_ios.sh MapLibreIntegrationTests

# Test connection handling
./scripts/test_ios.sh testConnectionFailureWithInvalidHost
```

### Test Coverage

```bash
bazel coverage //apps/omnitak_mobile_ios:OmniTAKMobileTests \
    --config=ios_sim_debug \
    --combined_report=lcov
```

## Configuration

### TAK Server Connection

Update the server configuration in `ViewController.swift`:

```swift
let config: [String: Any] = [
    "host": "your-tak-server.example.com",
    "port": 8089,
    "protocol": "tcp",  // tcp, udp, tls, websocket
    "useTls": false,
    "reconnect": true,
    "reconnectDelayMs": 5000
]
```

### Permissions

Required iOS permissions are configured in `Info.plist`:

- **Location** - For displaying user position on map
- **Network** - For TAK server connectivity
- **Files** - For certificate import
- **Background Modes** - For continuous location updates

### Map Style

Change the MapLibre style in `ViewController.swift`:

````swift
// Default: MapLibre demo tiles
let mapURL = URL(string: "https://demotiles.maplibre.org/style.json").
// Alternative: Mapbox streets (requires API key)
let mapURL = URL(string: "mapbox://styles/mapbox/streets-v11").
// Custom: Your own style
let mapURL = URL(string: "https://your-tiles.example.com/style.json").```

## Usage Example

### Connect to TAK Server

```swift
let bridge = OmniTAKNativeBridge()

let config: [String: Any] = [
    "host": "tak-server.example.com",
    "port": 8089,
    "protocol": "tcp",
    "useTls": false,
    "reconnect": true,
    "reconnectDelayMs": 5000
]

bridge.connect(config: config) { connectionId in
    if let id = connectionId {
        print("Connected. ID: \(id)")
    } else {
        print("Connection failed")
    }
}
````

### Send CoT Message

```swift
let cotXml = """
<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0" uid="test-\(UUID().uuidString)" type="a-f-G-E-S"
       time="\(ISO8601DateFormatter().string(from: Date()))"
       start="\(ISO8601DateFormatter().string(from: Date()))"
       stale="\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(300)))"
       how="m-g">
    <point lat="39.8283" lon="-98.5795" hae="0" ce="9999999" le="9999999"/>
    <detail>
        <contact callsign="IOS-CLIENT"/>
    </detail>
</event>
"""

bridge.sendCot(connectionId: connectionId, cotXml: cotXml) { success in
    print("CoT sent: \(success)")
}
```

### Receive CoT Messages

```swift
bridge.registerCotCallback(connectionId: connectionId) { cotXml in
    print("Received CoT: \(cotXml)")
    // Parse and display on map
}
```

### MapLibre Map

```swift
let styleURL = URL(string: "https://demotiles.maplibre.org/style.json").let mapView = MLNMapView(frame: view.bounds, styleURL: styleURL)

// Set camera
mapView.setCenter(
    CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
    zoomLevel: 10,
    animated: true
)

// Add marker
let annotation = MLNPointAnnotation()
annotation.coordinate = CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795)
annotation.title = "Test Marker"
mapView.addAnnotation(annotation)
```

## Troubleshooting

### Common Issues

See [IOS_BUILD_GUIDE.md#troubleshooting](IOS_BUILD_GUIDE.md#troubleshooting) for comprehensive troubleshooting.

**Quick fixes:**

```bash
# XCFramework not found
# Build the Rust library first, then copy XCFramework

# Simulator won't boot
xcrun simctl erase all
xcrun simctl boot <device-udid>

# Code signing errors
# Use ad-hoc signing for testing
build:ios --ios_signing_cert_name=-

# Clean build
bazel clean --expunge
./scripts/build_ios.sh simulator debug
```

## Development

### Adding New Features

1. Update Swift source in `src/ios/`
2. Update BUILD.bazel if adding new files
3. Add tests in `tests/ios/`
4. Update documentation

### Modifying Native Bridge

1. Update Rust FFI in omnitak-mobile crate
2. Rebuild XCFramework
3. Update `omnitak_mobile.h` if API changed
4. Update `OmniTAKNativeBridge.swift` wrapper
5. Add tests

### Updating MapLibre

1. Update MapLibre version in MODULE.bazel
2. Test compatibility with existing code
3. Update any deprecated APIs

## Related Documentation

- [iOS Build Guide](IOS_BUILD_GUIDE.md) - Comprehensive build instructions
- [OmniTAK Mobile README](../../docs/modules/omnitak_mobile/README.md) - Module overview
- [MapLibre Integration](../../docs/modules/omnitak_mobile/ios/maplibre/INTEGRATION.md) - MapLibre details
- [Native Bridge README](../../docs/modules/omnitak_mobile/ios/native/README.md) - FFI documentation

## Performance

### Benchmarks

Measured on iPhone 15 Pro Simulator:

- App launch: ~500ms
- Map render: ~200ms
- CoT send: ~10ms
- CoT receive callback: ~5ms
- Connection establish: ~100ms (local server)

### Optimization Tips

1. Use release builds for performance testing
2. Enable whole-module optimization for Swift
3. Profile with Xcode Instruments
4. Minimize CoT message size
5. Use connection pooling for multiple servers

## Security

### Best Practices

1. **TLS Encryption** - Always use TLS for production
2. **Certificate Validation** - Validate server certificates
3. **Secure Storage** - Use Keychain for sensitive data
4. **Network Security** - Configure App Transport Security
5. **Code Signing** - Sign apps for device deployment

### Certificate Management

```swift
// Import certificate
bridge.importCertificate(
    certPem: certPem,
    keyPem: keyPem,
    caPem: caPem
) { certId in
    print("Certificate ID: \(certId)")
}

// Use in connection
let config: [String: Any] = [
    // ...
    "certificateId": certId,
    "useTls": true
]
```

## Contributing

When contributing to the iOS app:

1. Follow Swift style guidelines
2. Add tests for new features
3. Update documentation
4. Test on both simulator and device
5. Ensure builds pass with Bazel

## License

See [docs/LICENSE.md](../../docs/LICENSE.md) in the project root.

## Support

For questions or issues:

1. Check [IOS_BUILD_GUIDE.md](IOS_BUILD_GUIDE.md)
2. Review existing documentation
3. Open an issue on the project repository

## Changelog

### v0.1.0 (2024-11-08)

- Initial iOS app implementation
- OmniTAK native library integration
- MapLibre GL Native integration
- TAK server connectivity demo
- Basic UI with connection and messaging
- Unit and integration tests
- Build and run scripts
- Comprehensive documentation
