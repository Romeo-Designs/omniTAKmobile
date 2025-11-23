# Codebase Navigation Guide

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Finding Specific Functionality](#finding-specific-functionality)
- [Key Files Reference](#key-files-reference)
- [Navigation Patterns](#navigation-patterns)
- [Common Tasks](#common-tasks)

---

## Overview

OmniTAK Mobile contains over 100 Swift files organized by functional domain. This guide helps you quickly locate specific code and understand the organizational structure.

### Quick Stats

- **Total Files**: ~120 Swift files
- **Lines of Code**: ~45,000
- **Main View**: `ATAKMapView` (3210 lines)
- **Managers**: 11 classes
- **Services**: 27 classes
- **Models**: 23 files
- **Views**: 60+ files

---

## Project Structure

### Root Directory

```
apps/omnitak/
├── OmniTAKMobile/              # Main source code
├── OmniTAKMobile.xcodeproj/    # Xcode project
├── screenshots/                # App Store screenshots
├── docs/                       # Documentation
├── *.py                        # Build scripts
└── *.sh                        # Setup scripts
```

### Source Code Organization

```
OmniTAKMobile/
├── Core/                       # App entry point
│   ├── OmniTAKMobileApp.swift  # Main app struct
│   ├── ContentView.swift       # Root view
│   └── OmniTAKMobile-Bridging-Header.h
│
├── Map/                        # Map system (LARGEST)
│   ├── Controllers/
│   │   ├── MapViewController.swift      # 3210 lines! Main map
│   │   ├── MapStateManager.swift
│   │   └── MapCursorModeCoordinator.swift
│   ├── Markers/
│   │   ├── EnhancedCoTMarker.swift
│   │   └── MarkerView.swift
│   ├── Overlays/
│   │   ├── MapOverlayCoordinator.swift
│   │   ├── CircleOverlay.swift
│   │   └── PolygonOverlay.swift
│   └── TileSources/
│       ├── OSMTileOverlay.swift
│       └── ArcGISTileOverlay.swift
│
├── Managers/                   # State management (11 classes)
│   ├── ServerManager.swift     # TAK server config
│   ├── CertificateManager.swift # TLS certificates
│   ├── ChatManager.swift       # Chat state
│   ├── CoTFilterManager.swift  # Message filtering
│   ├── DrawingToolsManager.swift
│   ├── GeofenceManager.swift
│   ├── MeasurementManager.swift
│   ├── MeshtasticManager.swift
│   ├── OfflineMapManager.swift
│   ├── WaypointManager.swift
│   └── DataPackageManager.swift
│
├── Services/                   # Business logic (27 classes)
│   ├── TAKService.swift        # 1105 lines! Core networking
│   ├── ChatService.swift       # 310 lines
│   ├── PositionBroadcastService.swift  # 398 lines
│   ├── TrackRecordingService.swift     # 635 lines
│   ├── GeofenceService.swift   # 538 lines
│   ├── MeasurementService.swift # 422 lines
│   └── ... (21 more services)
│
├── CoT/                        # CoT protocol
│   ├── CoTMessageParser.swift  # XML parsing
│   ├── CoTEventHandler.swift   # Event routing
│   ├── CoTFilterCriteria.swift
│   ├── Generators/             # CoT creation
│   │   ├── ChatCoTGenerator.swift
│   │   ├── MarkerCoTGenerator.swift
│   │   ├── GeofenceCoTGenerator.swift
│   │   └── TeamCoTGenerator.swift
│   └── Parsers/                # CoT parsing
│       ├── GeoChatParser.swift
│       └── MarkerParser.swift
│
├── Models/                     # Data structures (23 files)
│   ├── ChatModels.swift        # 259 lines
│   ├── CoTModels.swift
│   ├── ServerModels.swift
│   ├── TeamModels.swift
│   ├── WaypointModels.swift
│   ├── GeofenceModels.swift
│   ├── DrawingModels.swift
│   └── ... (16 more model files)
│
├── Views/                      # UI components (60+ files)
│   ├── Chat/
│   │   ├── ChatView.swift
│   │   ├── ConversationView.swift
│   │   └── MessageBubble.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── ServerConfigView.swift
│   │   └── CertificateView.swift
│   ├── Map/
│   │   ├── MapControlsView.swift
│   │   ├── CompassView.swift
│   │   └── CoordinateDisplayView.swift
│   └── ... (many more views)
│
├── Storage/                    # Persistence
│   ├── ChatStorageManager.swift
│   ├── WaypointStorage.swift
│   └── SettingsStorage.swift
│
├── Utilities/                  # Helper functions
│   ├── LocationManager.swift
│   ├── CoordinateConverter.swift
│   ├── XMLHelper.swift
│   └── DateFormatter+Extensions.swift
│
├── Resources/                  # Assets
│   ├── Info.plist
│   └── ... (other resources)
│
└── Assets.xcassets/           # Images & colors
    ├── AppIcon.appiconset/
    └── ... (icons, colors)
```

---

## Finding Specific Functionality

### "I want to modify..."

#### Map Rendering

**Location**: `OmniTAKMobile/Map/Controllers/MapViewController.swift`

- Main map view: Line 1-3210
- MapKit integration: Throughout
- Annotation rendering: Search for `MapAnnotation`

#### Server Connection

**Location**: `OmniTAKMobile/Services/TAKService.swift`

- Connect method: Line ~200
- TLS configuration: Line ~300
- Message sending: Line ~500
- DirectTCPSender class: Line ~700

#### Chat Messages

**Locations**:

- State: `OmniTAKMobile/Managers/ChatManager.swift` (790 lines)
- Business logic: `OmniTAKMobile/Services/ChatService.swift` (310 lines)
- UI: `OmniTAKMobile/Views/Chat/ChatView.swift`
- Models: `OmniTAKMobile/Models/ChatModels.swift` (259 lines)
- CoT generation: `OmniTAKMobile/CoT/Generators/ChatCoTGenerator.swift`

#### Position Broadcasting

**Location**: `OmniTAKMobile/Services/PositionBroadcastService.swift` (398 lines)

- Enable/disable: Line ~20
- Update interval: Line ~35
- CoT generation: Line ~250

#### CoT Message Parsing

**Locations**:

- Main parser: `OmniTAKMobile/CoT/CoTMessageParser.swift`
- Event handler: `OmniTAKMobile/CoT/CoTEventHandler.swift`
- Specific parsers: `OmniTAKMobile/CoT/Parsers/`

#### Drawing Tools

**Locations**:

- Manager: `OmniTAKMobile/Managers/DrawingToolsManager.swift`
- UI: `OmniTAKMobile/Views/Drawing/`
- Models: `OmniTAKMobile/Models/DrawingModels.swift`

#### Certificates

**Location**: `OmniTAKMobile/Managers/CertificateManager.swift` (436 lines)

- Import: Line ~100
- Validation: Line ~200
- Keychain: Line ~300

---

## Key Files Reference

### Largest Files (Lines of Code)

| File                             | Lines | Purpose                  |
| -------------------------------- | ----- | ------------------------ |
| `MapViewController.swift`        | 3210  | Main map interface       |
| `TAKService.swift`               | 1105  | Network communication    |
| `ChatManager.swift`              | 790   | Chat state management    |
| `TrackRecordingService.swift`    | 635   | GPS track recording      |
| `GeofenceService.swift`          | 538   | Geofence monitoring      |
| `CertificateManager.swift`       | 436   | TLS certificate handling |
| `MeasurementService.swift`       | 422   | Measurement tools        |
| `PositionBroadcastService.swift` | 398   | PLI broadcasting         |
| `ChatService.swift`              | 310   | Chat business logic      |
| `ChatModels.swift`               | 259   | Chat data structures     |

### Critical Entry Points

| Function            | File                      | Purpose             |
| ------------------- | ------------------------- | ------------------- |
| `@main`             | `OmniTAKMobileApp.swift`  | App entry point     |
| `ATAKMapView`       | `MapViewController.swift` | Main view           |
| `connect()`         | `TAKService.swift`        | Server connection   |
| `sendMessage()`     | `ChatManager.swift`       | Send chat           |
| `processCoTEvent()` | `CoTEventHandler.swift`   | Handle incoming CoT |

---

## Navigation Patterns

### Follow the Data Flow

#### Incoming CoT Message Flow

1. **Network Layer**: `TAKService.swift`
   - `DirectTCPSender.processReceivedData()` → Line ~900
   - Extracts XML from buffer

2. **Parser**: `CoTMessageParser.swift`
   - `parseCoTMessage(_ xml:)` → Line ~50
   - Converts XML to `CoTEvent` struct

3. **Router**: `CoTEventHandler.swift`
   - `handleCoTEvent(_ event:)` → Line ~100
   - Routes by event type

4. **Handler**: Type-specific
   - Chat: `ChatManager.processIncomingMessage()`
   - Marker: Update markers array
   - Team: `TeamService.handleTeamEvent()`

5. **UI Update**: SwiftUI
   - `@Published` properties trigger view updates
   - UI automatically re-renders

#### Outgoing Message Flow

1. **User Action**: View
   - Button tap, gesture, etc.

2. **Manager/Service**: Business Logic
   - `ChatManager.sendMessage()`
   - `PositionBroadcastService.broadcast()`

3. **CoT Generator**: `CoT/Generators/`
   - `ChatCoTGenerator.generate()`
   - Creates XML string

4. **Network**: `TAKService.swift`
   - `send(cotMessage:)` → Line ~500
   - Transmits over TCP/TLS

### Search Patterns

#### Find Class Definition

```bash
# In terminal
grep -r "class MyClassName" OmniTAKMobile/
```

#### Find Method Usage

```bash
# Find all calls to a method
grep -r "myMethodName(" OmniTAKMobile/
```

#### Find Protocol Conformance

```bash
# Find classes conforming to protocol
grep -r ": MyProtocol" OmniTAKMobile/
```

#### Find SwiftUI Views

```bash
# All views conforming to View protocol
grep -r "struct.*: View" OmniTAKMobile/Views/
```

---

## Common Tasks

### Adding a New Feature

**1. Define Model** (if needed)

- Location: `OmniTAKMobile/Models/`
- File: `MyFeatureModels.swift`
- Pattern: `struct`, `Identifiable`, `Codable`

**2. Create Manager** (for state)

- Location: `OmniTAKMobile/Managers/`
- File: `MyFeatureManager.swift`
- Pattern: `ObservableObject`, `@Published`

**3. Create Service** (for logic)

- Location: `OmniTAKMobile/Services/`
- File: `MyFeatureService.swift`
- Pattern: Singleton or injected

**4. Create View**

- Location: `OmniTAKMobile/Views/MyFeature/`
- File: `MyFeatureView.swift`
- Pattern: SwiftUI `View`

**5. Integrate**

- Add to main view (usually `ATAKMapView`)
- Add navigation/toolbar button
- Test end-to-end

### Adding CoT Message Type

**1. Update Parser**

- File: `CoTMessageParser.swift`
- Add parsing logic for new type

**2. Create Generator**

- File: `CoT/Generators/MyTypeCoTGenerator.swift`
- Implement XML generation

**3. Update Handler**

- File: `CoTEventHandler.swift`
- Add routing for new type

**4. Add Model** (if complex)

- File: `Models/MyTypeModels.swift`

### Modifying UI

**SwiftUI Views**:

- Location: `OmniTAKMobile/Views/`
- Hot reload: Cmd+Option+P (preview)
- Inspect hierarchy: View > Show SwiftUI Inspector

**Map Overlays**:

- Location: `OmniTAKMobile/Map/Overlays/`
- Add to `MapOverlayCoordinator`

**Custom Components**:

- Create reusable views in `Views/Components/`

---

## Tips & Tricks

### Xcode Navigation

**Quick Open**:

- `Cmd + Shift + O` → Open file by name

**Find in Project**:

- `Cmd + Shift + F` → Project-wide search

**Jump to Definition**:

- `Cmd + Click` on symbol

**Show Related Items**:

- `Ctrl + 1` → Show related files/tests

### Code Organization

**File Size**: If file exceeds 500 lines, consider splitting into:

- Extensions
- Separate view components
- Helper classes

**Naming**: Follow existing patterns:

- Managers: `*Manager.swift`
- Services: `*Service.swift`
- Models: `*Models.swift`
- Views: `*View.swift`

### Testing

**Unit Tests**:

- Location: `OmniTAKMobileTests/`
- Run: `Cmd + U`

**UI Tests**:

- Location: `OmniTAKMobileUITests/`
- Run: `Cmd + U` (all) or test diamond

---

## Reference Quick Links

### Most Commonly Modified Files

For typical feature work, you'll mostly edit:

1. **Map**: `MapViewController.swift`
2. **Networking**: `TAKService.swift`
3. **Chat**: `ChatManager.swift`, `ChatService.swift`
4. **Models**: `*Models.swift` files
5. **Views**: View files in `Views/`

### Least Commonly Modified

These are stable infrastructure:

1. **App Entry**: `OmniTAKMobileApp.swift`
2. **Core Utilities**: `Utilities/` files
3. **Bridging Header**: `OmniTAKMobile-Bridging-Header.h`

---

## Related Documentation

- **[Getting Started](GettingStarted.md)** - Dev environment setup
- **[Coding Patterns](CodingPatterns.md)** - Common patterns used
- **[Architecture](../Architecture.md)** - System design

---

_Last Updated: November 22, 2025_
