# Developer Guide: Getting Started

## Table of Contents

- [Development Environment Setup](#development-environment-setup)
- [Cloning the Repository](#cloning-the-repository)
- [Project Structure](#project-structure)
- [Building the Project](#building-the-project)
- [Running the App](#running-the-app)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Debugging](#debugging)
- [Common Issues](#common-issues)

---

## Development Environment Setup

### Prerequisites

#### Required Software

| Tool        | Version         | Purpose              |
| ----------- | --------------- | -------------------- |
| **macOS**   | 13.0+ (Ventura) | Development OS       |
| **Xcode**   | 15.0+           | IDE and build tools  |
| **Swift**   | 5.9+            | Programming language |
| **iOS SDK** | 17.0+           | Target platform SDK  |
| **Git**     | 2.30+           | Version control      |

#### Optional Tools

| Tool          | Purpose                           |
| ------------- | --------------------------------- |
| **Homebrew**  | Package manager for scripts       |
| **CocoaPods** | Dependency management (if needed) |
| **SwiftLint** | Code style enforcement            |
| **Jazzy**     | Documentation generation          |

### Installing Xcode

1. **Download Xcode** from the Mac App Store
2. **Open Xcode** and agree to license
3. **Install Command Line Tools:**
   ```bash
   xcode-select --install
   ```
4. **Verify installation:**
   ```bash
   xcode-select -p
   # Should output: /Applications/Xcode.app/Contents/Developer
   ```

### Installing Homebrew (Optional)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Setting Up Git

```bash
# Configure Git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Verify
git config --list
```

---

## Cloning the Repository

### Clone from GitHub

```bash
# Clone the repository
git clone https://github.com/tyroe1998/omniTAKmobile.git

# Navigate to project directory
cd omniTAKmobile/apps/omnitak

# Verify structure
ls -la
```

### Expected Directory Structure

```
omnitak/
├── OmniTAKMobile/          # Main source code
├── OmniTAKMobile.xcodeproj/ # Xcode project
├── screenshots/             # App Store screenshots
├── docs/                    # Documentation (this file)
├── README.md                # Project README
├── setup_xcode.sh           # Project setup script
├── update_build.sh          # Build number updater
└── update_version.sh        # Version updater
```

### Initialize Submodules (if any)

```bash
git submodule update --init --recursive
```

---

## Project Structure

### Source Code Organization

```
OmniTAKMobile/
├── Core/                    # App entry point and main coordinator
│   ├── OmniTAKMobileApp.swift
│   └── ContentView.swift
│
├── Managers/                # State management (@ObservableObject)
│   ├── ServerManager.swift
│   ├── ChatManager.swift
│   ├── CertificateManager.swift
│   └── ... (11 total)
│
├── Services/                # Business logic and integrations
│   ├── TAKService.swift
│   ├── ChatService.swift
│   ├── PositionBroadcastService.swift
│   └── ... (27 total)
│
├── Models/                  # Data structures (Codable, Identifiable)
│   ├── ChatModels.swift
│   ├── CoTFilterModel.swift
│   └── ... (23 files)
│
├── Views/                   # SwiftUI views (60+ files)
│   ├── ATAKMapView.swift
│   ├── ChatView.swift
│   ├── SettingsView.swift
│   └── ...
│
├── CoT/                     # CoT protocol implementation
│   ├── CoTMessageParser.swift
│   ├── CoTEventHandler.swift
│   ├── Generators/          # CoT XML generators
│   └── Parsers/             # Specialized parsers
│
├── Map/                     # Map system
│   ├── Controllers/         # MapKit controllers
│   ├── Markers/             # Custom annotations
│   ├── Overlays/            # Map overlays
│   └── TileSources/         # Tile providers
│
├── Meshtastic/              # Mesh networking
│   ├── MeshtasticProtoMessages.swift
│   └── MeshtasticProtobufParser.swift
│
├── Storage/                 # Persistence layer
│   ├── ChatPersistence.swift
│   ├── DrawingPersistence.swift
│   └── ...
│
├── UI/                      # Reusable UI components
│   ├── Components/
│   ├── MilStd2525/          # Military symbology
│   └── RadialMenu/
│
├── Utilities/               # Helper classes
│   ├── Calculators/
│   ├── Converters/
│   ├── Integration/
│   └── Parsers/
│
└── Resources/
    ├── Info.plist
    └── Assets.xcassets/
```

### Key Files

| File                     | Purpose                             |
| ------------------------ | ----------------------------------- |
| `OmniTAKMobileApp.swift` | App entry point (`@main`)           |
| `ATAKMapView.swift`      | Main coordinator view (2400+ lines) |
| `TAKService.swift`       | Core networking (1105 lines)        |
| `CoTMessageParser.swift` | CoT XML parsing (396 lines)         |
| `CoTEventHandler.swift`  | Event routing (333 lines)           |

---

## Building the Project

### Method 1: Xcode GUI

1. **Open project:**

   ```bash
   open OmniTAKMobile.xcodeproj
   ```

2. **Select target:**
   - Top toolbar: OmniTAKMobile > iPhone 15 Pro (or your device)

3. **Build:**
   - Press `⌘ + B` or Product > Build

4. **Expected output:**
   ```
   Build Succeeded
   ```

### Method 2: Command Line (xcodebuild)

```bash
# Build for simulator
xcodebuild -project OmniTAKMobile.xcodeproj \
  -scheme OmniTAKMobile \
  -sdk iphonesimulator \
  -configuration Debug \
  build

# Build for device
xcodebuild -project OmniTAKMobile.xcodeproj \
  -scheme OmniTAKMobile \
  -sdk iphoneos \
  -configuration Release \
  build
```

### Build Configurations

| Configuration | Purpose     | Optimizations                |
| ------------- | ----------- | ---------------------------- |
| **Debug**     | Development | None, debug symbols included |
| **Release**   | Production  | Full optimization, stripped  |

### Build Scripts

#### Update Build Number

```bash
./update_build.sh
# Increments CFBundleVersion in Info.plist
```

#### Update Version

```bash
./update_version.sh 1.2.0
# Sets CFBundleShortVersionString to 1.2.0
```

#### Setup Xcode Project

```bash
./setup_xcode.sh
# Regenerates project.pbxproj programmatically
```

---

## Running the App

### On Simulator

1. **Select simulator:**
   - Xcode toolbar: iPhone 15 Pro (or any iOS 15+ simulator)

2. **Run:**
   - Press `⌘ + R` or Product > Run

3. **Simulator launches** with app installed

**Tip:** Simulators don't have GPS. Use Debug > Location > Custom Location to simulate position.

### On Physical Device

#### Prerequisites

1. **Apple Developer Account** (free or paid)
2. **Device added** to Xcode (Window > Devices and Simulators)
3. **Trust computer** on device (tap "Trust" when prompted)

#### Steps

1. **Connect device** via USB or WiFi
2. **Select device** in Xcode toolbar
3. **Configure signing:**
   - Project settings > Signing & Capabilities
   - Team: Select your Apple ID
   - Automatically manage signing: ✅ enabled
4. **Run** (`⌘ + R`)

#### First Run on Device

You may need to trust the developer certificate:

1. **On device:** Settings > General > VPN & Device Management
2. **Tap your Apple ID**
3. **Tap "Trust"**
4. **Rerun** app from Xcode

### Launch Arguments

Add launch arguments for debugging:

```
Xcode > Product > Scheme > Edit Scheme > Run > Arguments

-com.apple.CoreData.SQLDebug 1        # SQL logging
-FIRAnalyticsDebugEnabled             # Analytics debug
-UIViewLayoutFeedbackLoopDebuggingThreshold 100  # Layout loop detection
```

---

## Development Workflow

### Daily Workflow

```bash
# 1. Pull latest changes
git pull origin main

# 2. Create feature branch
git checkout -b feature/my-new-feature

# 3. Make changes in Xcode
# Edit files, build, test

# 4. Commit changes
git add .
git commit -m "Add new feature: description"

# 5. Push branch
git push origin feature/my-new-feature

# 6. Create Pull Request on GitHub
```

### Branch Naming

| Branch Type | Pattern                 | Example                     |
| ----------- | ----------------------- | --------------------------- |
| **Feature** | `feature/description`   | `feature/chat-improvements` |
| **Bug Fix** | `fix/issue-number`      | `fix/issue-123`             |
| **Hotfix**  | `hotfix/critical-issue` | `hotfix/crash-on-launch`    |
| **Docs**    | `docs/topic`            | `docs/api-reference`        |

### Commit Messages

Follow conventional commits:

```
type(scope): description

feat(chat): add photo attachment support
fix(map): correct marker positioning
docs(readme): update installation instructions
refactor(cot): simplify XML parsing
test(services): add TAKService unit tests
```

### Code Review Checklist

Before submitting PR:

- ✅ Code builds without warnings
- ✅ All tests pass
- ✅ SwiftLint rules followed
- ✅ Documentation updated
- ✅ No debug print statements
- ✅ Assets optimized
- ✅ Performance tested

---

## Testing

### Unit Tests

```bash
# Run all tests
⌘ + U (Xcode)

# Or command line:
xcodebuild test \
  -project OmniTAKMobile.xcodeproj \
  -scheme OmniTAKMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Writing Tests

```swift
import XCTest
@testable import OmniTAKMobile

class CoTMessageParserTests: XCTestCase {
    func testParsePositionUpdate() {
        let xml = """
        <event uid="TEST-123" type="a-f-G-U-C" ...>
        ...
        </event>
        """

        let result = CoTMessageParser.parse(xml: xml)

        XCTAssertNotNil(result)
        if case .positionUpdate(let event) = result {
            XCTAssertEqual(event.uid, "TEST-123")
        } else {
            XCTFail("Expected position update")
        }
    }
}
```

### UI Tests

```swift
import XCTest

class OmniTAKUITests: XCTestCase {
    func testChatFlow() {
        let app = XCUIApplication()
        app.launch()

        // Tap chat button
        app.buttons["Chat"].tap()

        // Verify chat view appears
        XCTAssertTrue(app.staticTexts["Conversations"].exists)
    }
}
```

---

## Debugging

### Breakpoints

```swift
// Set breakpoint in Xcode: Click line number gutter

func handlePositionUpdate(_ event: CoTEvent) {
    // Execution pauses here when breakpoint hit
    print("Event: \(event)")  // Inspect variables in debugger
}
```

### Print Debugging

```swift
#if DEBUG
print("🔍 Debug: \(variable)")
print("📍 Location: \(coordinate)")
print("🚨 Error: \(error)")
#endif
```

### View Debugging

- **View Hierarchy:** Debug > View Debugging > Capture View Hierarchy
- **Inspect UI:** Click elements in 3D view to see constraints and properties

### Memory Debugging

```bash
# Enable malloc stack logging
Product > Scheme > Edit Scheme > Diagnostics
☑️ Malloc Stack Logging
```

### Instruments

Profile performance with Instruments:

```
Product > Profile (⌘ + I)

Available tools:
- Time Profiler: CPU usage
- Allocations: Memory usage
- Leaks: Memory leaks
- Network: Network activity
```

---

## Common Issues

### Issue: Code Signing Error

**Error:** `No signing certificate found`

**Solution:**

1. Xcode > Preferences > Accounts
2. Add Apple ID if not present
3. Download manual profiles if needed
4. Project settings > Signing: Select team

### Issue: Swift Compiler Error

**Error:** `Command CompileSwift failed with a nonzero exit code`

**Solution:**

1. Clean build folder: `⌘ + Shift + K`
2. Delete derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. Restart Xcode
4. Rebuild

### Issue: Simulator Not Launching

**Solution:**

```bash
# Reset simulator
xcrun simctl erase all

# Restart simulator service
sudo killall -9 com.apple.CoreSimulator.CoreSimulatorService
```

### Issue: Missing Dependencies

**Error:** `Module not found`

**Solution:**

- Verify all source files are in Xcode project
- Check File Inspector > Target Membership
- Clean and rebuild

### Issue: Device Not Recognized

**Solution:**

1. Unplug and replug device
2. Restart Xcode
3. Trust computer on device
4. Window > Devices and Simulators > Check device status

---

## Next Steps

- **[Codebase Navigation](CodebaseNavigation.md)** - Detailed file guide
- **[Development Workflow](DevelopmentWorkflow.md)** - Advanced workflows
- **[Coding Patterns](CodingPatterns.md)** - Best practices and conventions
- **[Contributing](Contributing.md)** - How to contribute

---

## Resources

### Documentation

- [Swift Language Guide](https://docs.swift.org/swift-book/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [MapKit Documentation](https://developer.apple.com/documentation/mapkit)
- [Combine Framework](https://developer.apple.com/documentation/combine)

### Tools

- [Xcode Release Notes](https://developer.apple.com/documentation/xcode-release-notes)
- [SF Symbols](https://developer.apple.com/sf-symbols/) - System icons
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

### Community

- [GitHub Repository](https://github.com/tyroe1998/omniTAKmobile)
- [Issue Tracker](https://github.com/tyroe1998/omniTAKmobile/issues)
- [Discussions](https://github.com/tyroe1998/omniTAKmobile/discussions)

---

_Last Updated: November 22, 2025_
