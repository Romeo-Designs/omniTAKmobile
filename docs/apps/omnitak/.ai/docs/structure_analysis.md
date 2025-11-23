# Code Structure Analysis

## Architectural Overview

OmniTAK Mobile is an iOS Swift/SwiftUI application organized around a clean layered architecture:

- **Presentation (Views/UI)**
  - `OmniTAKMobile/Core` – App entry point and root content (`OmniTAKMobileApp`, `ContentView`).
  - `OmniTAKMobile/Views` – Feature-specific SwiftUI screens (Chat, Map, Tracks, Settings, etc.).
  - `OmniTAKMobile/UI` – Reusable UI components (toolbars, widgets, radial menus, military symbology).

- **ViewModel / State (Managers)**
  - `OmniTAKMobile/Managers` – `ObservableObject` “manager” classes that play the ViewModel role in MVVM: they own feature state, coordinate user actions, and talk to services/storage.

- **Domain / Business Logic (Services, CoT, Map, Utilities)**
  - `OmniTAKMobile/Services` – Core feature services: TAK networking, chat, PLI, tracks, navigation, measurement, video, etc.
  - `OmniTAKMobile/CoT` – Cursor-on-Target messaging: parsers, generators, event dispatcher.
  - `OmniTAKMobile/Map` – Map controllers, overlays, markers, tile sources; bridges UIKit/MapKit into SwiftUI.
  - `OmniTAKMobile/Utilities` – Common cross-cutting utilities (coordinate converters, measurement calculators, KML integration, network helpers).

- **Domain Model (Models)**
  - `OmniTAKMobile/Models` – Data structures for all domains (chat, CoT filters, tracks, routes, geofences, missions, Meshtastic, teams, video, etc.).

- **Infrastructure (Storage, Networking, Integration)**
  - `OmniTAKMobile/Storage` – Persistence components (UserDefaults / filesystem / Keychain abstractions) for chat, routes, drawings, teams.
  - `OmniTAKMobile/Meshtastic` – Parsing and model helpers for Meshtastic radio integration.
  - `OmniTAKMobile/Utilities/Network` – Network monitor and multi-server federation logic.
  - `OmniTAKMobile/Utilities/Integration` + `/Parsers` – KML/KMZ integration.

- **Bridging & Native Core**
  - `OmniTAKMobile/Core/OmniTAKMobile-Bridging-Header.h` – Exposes native/Objective‑C or C APIs to Swift.
  - `OmniTAKMobile.xcframework` – Prebuilt native library (Rust + C header `omnitak_mobile.h`) exposing low-level TAK/mobile core functionality used by `TAKService` and related networking code.

The documented **architectural pattern is MVVM** (Model–View–ViewModel) with:

- SwiftUI Views as the View layer.
- “Manager” classes (`Managers/`) as ViewModels (`ObservableObject` with `@Published` state).
- Services (`Services/`) as domain/business layer.
- Models (`Models/`) as pure data structures.

Reactive flows are implemented via **Combine** (`@Published`, `@ObservedObject`, `@EnvironmentObject`), with supplementary use of **delegate pattern** and **NotificationCenter** for some asynchronous flows.

Feature boundaries are primarily **feature-oriented** (chat, map, tracks, PLI, offline maps, etc.), cutting through the standard MVVM layers.

---

## Core Components

### 1. App Core / Entry

**Files:**

- `OmniTAKMobile/Core/OmniTAKMobileApp.swift`
  - SwiftUI `@main` app entry; wires root environment objects and bootstrap services/managers.
- `OmniTAKMobile/Core/ContentView.swift`
  - Root view hosting navigation shell, map integration, and primary tools UI.
- `OmniTAKMobile/Resources/Info.plist` & entitlements
  - Declares capabilities (networking, background modes, certificates, etc.).

**Responsibility:**

- Owns global dependency graph (injects `TAKService`, `ServerManager`, `ChatManager`, etc. into environment).
- Sets up initial routing (main map, onboarding, server selection).

---

### 2. Views (SwiftUI Presentation Layer)

**Directory:** `OmniTAKMobile/Views`

Each SwiftUI view represents a feature screen or panel, e.g.:

- Map & Tools:
  - `ATAKToolsView.swift`, `NavigationDrawer.swift`, `MarkerInfoPanel.swift`, `CompassOverlayView.swift`, `ScaleBarView.swift`.
- Networking & Servers:
  - `TAKServersView.swift`, `ServerPickerView.swift`, `QuickConnectView.swift`, `NetworkPreferencesView.swift`.
- Chat & Messaging:
  - `ChatView.swift`, `ConversationView.swift`, `ContactListView.swift`, `ContactDetailView.swift`, `PhotoPickerView.swift`.
- Tactical Features:
  - `BloodhoundView.swift`, `DigitalPointerView.swift`, `EmergencyBeaconView.swift`, `SPOTREPView.swift`, `SALUTEReportView.swift`, `MEDEVACRequestView.swift`.
- Spatial Tools:
  - `MeasurementToolView.swift`, `RoutePlanningView.swift`, `LineOfSightView.swift`, `ElevationProfileView.swift`, `GeofenceManagementView.swift`.
- Data & Offline:
  - `DataPackageView.swift`, `DataPackageImportView.swift`, `OfflineMapsView.swift`, `MissionPackageSyncView.swift`, `KMLImportView.swift`.
- Tracks & Waypoints:
  - `TrackListView.swift`, `TrackRecordingView.swift`, `WaypointListView.swift`, `RegionSelectionView.swift`.
- Meshtastic / Radios:
  - `MeshtasticConnectionView.swift`, `MeshtasticDevicePickerView.swift`, `MeshTopologyView.swift`.
- Video:
  - `VideoFeedListView.swift`, `VideoPlayerView.swift`.
- Settings & Onboarding:
  - `SettingsView.swift`, `FirstTimeOnboarding.swift`, `AboutView.swift`, `PluginsListView.swift`, `TeamManagementView.swift`, `CertificateEnrollmentView.swift`, `CertificateManagementView.swift`.

**Responsibility:**

- Pure UI composition and user interaction handling.
- Bind to one or more `ObservableObject` managers/services using `@ObservedObject` or `@EnvironmentObject`.
- No direct business logic; delegate work to managers/services.

---

### 3. ViewModels / Managers

**Directory:** `OmniTAKMobile/Managers`

Representative managers (not exhaustive):

- `ChatManager.swift` – Manages chat conversations, unread counts, and UI-facing chat state.
- `ServerManager.swift` – Manages list of TAK servers, connection preferences, and certificate association.
- `CertificateManager.swift` – Handles certificate lifecycle and UI state (install, select, validate).
- `CoTFilterManager.swift` – Manages CoT filter rules (by type, team, distance) for map and lists.
- `DrawingToolsManager.swift` – State for drawing mode, selected tool, and overlays.
- `GeofenceManager.swift` – Geofence definitions, activation, and monitoring state.
- `MeasurementManager.swift` – Core measurement state (active measurement, units).
- `OfflineMapManager.swift` – Manages offline tile packages, region downloads, and selection.
- `WaypointManager.swift` – Waypoint lists, selection, import/export.
- `MeshtasticManager.swift` – Manages Meshtastic connection state and routing into domain models.
- `DataPackageManager.swift` – Import, list, and sync status for mission/data packages.

**Responsibility:**

- Serve as **ViewModels**:
  - Own `@Published` UI state.
  - Interpret user actions coming from Views, call services/storage.
  - Encapsulate coordination logic between multiple services (e.g., Chat + TAK + Storage).
- Often depend on:
  - One or more `Services` for business logic.
  - `Storage` components for persistence.
  - CoT/Map subsystems for event routing and visualization.

---

### 4. Services (Business Logic Layer)

**Directory:** `OmniTAKMobile/Services`  
Documented in depth by `/docs/API/Services.md`.

Key services:

- **Core Networking:**
  - `TAKService.swift` – Central networking and CoT message pipe to TAK server.
    - Publishes connection status, message/byte counters.
    - Methods: `connect(host:port:protocolType:)`, `disconnect()`, `send(cotMessage:priority:)`, `reconnect()`.

- **Communication & Coordination:**
  - `ChatService.swift` – Chat business logic: message creation, send/queue/retry, conversation organization.
  - `PositionBroadcastService.swift` – PLI broadcasting; maintains UID, callsign, intervals, and sends self-position CoT.
  - `TrackRecordingService.swift` – GPS track recording, pause/resume/export to GPX/KML.
  - `EmergencyBeaconService.swift` – SOS beacon with rapid PLI updates.
  - `TeamService.swift` – Team membership and messaging; invites, team broadcasts.
  - `PhotoAttachmentService.swift` – Compression, packaging, and sending of image attachments.

- **Map / Spatial Services:**
  - `MeasurementService.swift` – Manages measurement operations and underlying overlays.
  - `RangeBearingService.swift` – Range & bearing computation and line management.
  - `LineOfSightService.swift` – Line-of-sight analysis (likely uses elevation data).
  - `ElevationProfileService.swift` – Computes elevation profiles for paths.
  - `RoutePlanningService.swift` – Builds and modifies routes.
  - `NavigationService.swift` & `TurnByTurnNavigationService.swift` – Navigation path following and guidance.
  - `BreadcrumbTrailService.swift` & `TrackRecordingService.swift` – Track rendering and metrics.

- **Tactical / Specialized:**
  - `BloodhoundService.swift` – Target “bloodhound” tracking / directional guidance.
  - `DigitalPointerService.swift` – Laser-pointer-like map coordination.
  - `EchelonService.swift` – Unit/echelon classifications and hierarchies.
  - `EmergencyBeaconService.swift` – As above.
  - `VideoStreamService.swift` – Video feed discovery and stream management.

- **Data & External Integration:**
  - `MissionPackageSyncService.swift` – Sync mission/data packages with server.
  - `ArcGISFeatureService.swift`, `ArcGISPortalService.swift` – ArcGIS feature and portal integration.
  - `ElevationAPIClient.swift` – External elevation API.
  - `CertificateEnrollmentService.swift` – Certificate enrollment workflows.
  - `OfflineMap` related services integrate with tile sources and storage.

**Responsibility:**

- Encapsulate domain rules and workflows independent of UI.
- Abstract external systems (TAK server, ArcGIS, Meshtastic, etc.).
- Expose `ObservableObject` state where UI must reflect ongoing operations (loading, errors, active entities).
- Primarily invoked from managers; occasionally directly from views for simple utilities.

---

### 5. CoT Subsystem

**Directory:** `OmniTAKMobile/CoT`

- `CoTMessageParser.swift` – Parses inbound raw XML into structured CoT events.
- `CoTEventHandler.swift` – Central event router: receives parsed events and distributes to managers/services (chat, tracks, emergency, team, etc.) via Combine publishers and `NotificationCenter`.
- `CoTFilterCriteria.swift` – Data model for CoT filter rules.

Generators:

- `ChatCoTGenerator.swift` – Converts chat messages to GeoChat CoT XML.
- `GeofenceCoTGenerator.swift` – CoT for geofence events.
- `MarkerCoTGenerator.swift` – Map markers to CoT.
- `TeamCoTGenerator.swift` – Team messages/status to CoT.

Parsers:

- `ChatXMLParser.swift`, `ChatXMLGenerator.swift` – Specialized chat XML parsing/generation.

**Responsibility:**

- Provide a clear boundary between wire format (XML) and internal domain models.
- Centralize CoT handling so that feature-level code uses structured models instead of raw XML.

---

### 6. Map Subsystem

**Directory:** `OmniTAKMobile/Map`

Controllers (`Controllers/`):

- `EnhancedMapViewController.swift`, `MapViewController.swift`, `Map3DViewController.swift`, `Experimental`/`Modified` variants.
- `IntegratedMapView.swift` & `EnhancedMapViewRepresentable.swift` – SwiftUI/UIViewController bridges.
- `MapOverlayCoordinator.swift` – Coordinates overlays: MGRS grid, drawing shapes, tracks, ranges, video overlays.
- `MapContextMenus.swift`, `MapCursorMode.swift`, `MapStateManager.swift` – Context menus, cursor modes (e.g., select vs pan vs measurement), and current map-state.

Markers (`Markers/`):

- `CustomMarkerAnnotation.swift`, `EnhancedCoTMarker.swift`, `MarkerAnnotationView.swift` – Custom MapKit annotations representing CoT entities.

Overlays (`Overlays/`):

- `BreadcrumbTrailOverlay.swift`, `UnitTrailOverlay.swift`, `TrackOverlayRenderer.swift` – Track/breadcrumb visualizations.
- `MGRSGridOverlay.swift` – Military grid overlay.
- `MeasurementOverlay.swift`, `RangeBearingOverlay.swift` – Measurement and range/bearing visualizations.
- `OfflineTileOverlay.swift`, `VideoMapOverlay.swift`, `RadialMenuMapOverlay.swift`, `CompassOverlay.swift`.

Tile Sources (`TileSources/`):

- `ArcGISTileSource.swift` – ArcGIS basemap integration.
- `OfflineTileCache.swift`, `TileDownloader.swift` – Offline tile management and download.

**Responsibility:**

- Wrap MapKit / 3D mapping into a modular subsystem.
- Concentrate map interaction policies (what overlays to show, how context menus behave).
- Decouple pure geometric rendering from domain models by using overlay/annotation classes.

---

### 7. Models (Domain Data)

**Directory:** `OmniTAKMobile/Models`

Key model groups:

- Tactical / Map:
  - `TrackModels.swift`, `RouteModels.swift`, `WaypointModels.swift`, `PointMarkerModels.swift`, `LineOfSightModels.swift`, `ElevationProfileModels.swift`, `OfflineMapModels.swift`, `GeofenceModels.swift`, `MeasurementModels.swift`, `TerrainVisualizationService` models.

- Communication:
  - `ChatModels.swift`, `TeamModels.swift`, `VideoStreamModels.swift`, `SPOTREPModels.swift`, `MEDEVACModels.swift`, `MissionPackageModels.swift`.

- Protocol & Filters:
  - `CoTFilterModel.swift`, `CASRequestModels.swift`, `EchelonModels.swift`, `RadialMenuModels.swift`.

- Integration:
  - `ArcGISModels.swift`, `MeshtasticModels.swift`, `MissionPackageModels.swift`.

**Responsibility:**

- Act as pure data containers (`Codable`, `Identifiable` as noted in docs).
- Represent domain entities consistently across services, managers, storage, and views.
- No business logic beyond trivial computed properties.

---

### 8. Storage / Persistence

**Directory:** `OmniTAKMobile/Storage`

- `ChatPersistence.swift`, `ChatStorageManager.swift` – Local chat history, indexing, migration of message data.
- `DrawingPersistence.swift` – Persist drawing shapes / overlays.
- `RouteStorageManager.swift` – Persist routes and navigation plans.
- `TeamStorageManager.swift` – Persist team membership/metadata.

**Responsibility:**

- Abstract actual storage mechanisms (UserDefaults, Keychain, file system).
- Provide save/load/search APIs to managers and services.
- Hide serialization specifics from higher layers.

---

### 9. Utilities & Integration

**Directory:** `OmniTAKMobile/Utilities`

- Calculators:
  - `MeasurementCalculator.swift` – Geodesic distance/area/bearing calculations; used by `MeasurementService`, `RangeBearingService`.

- Converters:
  - `MGRSConverter.swift`, `BNGConverter.swift` – Coordinate system conversions.

- Network:
  - `NetworkMonitor.swift` – Observes network reachability, updates managers/services.
  - `MultiServerFederation.swift` – Handles cross-server routing/federation behavior.

- KML Integration:
  - `KMLParser.swift`, `KMZHandler.swift` – Parse KML/KMZ files into internal models/overlays.
  - `KMLMapIntegration.swift`, `KMLOverlayManager.swift` – Integrate parsed KML into map overlays and UI.

**Responsibility:**

- Provide shared, framework-agnostic utilities supporting multiple subsystems.
- Keep domain services & managers focused by pushing generic logic here.

---

### 10. UI Components & Radial Menu

**Directory:** `OmniTAKMobile/UI`

Components (`Components/`):

- `ATAKBottomToolbar_Modified.swift`, `QuickActionToolbar.swift`, `ConnectionStatusWidget.swift`, `DataPackageButton.swift`, `MeasurementButton.swift`, `TrackRecordingButton.swift`, `VideoStreamButton.swift`, `SharedUIComponents.swift`.

Radial Menu (`RadialMenu/`):

- `RadialMenuButton.swift`, `RadialMenuItemView.swift`, `RadialMenuAnimations.swift`, `RadialMenuGestureHandler.swift`, `RadialMenuMapCoordinator.swift`, `RadialMenuPresets.swift`, `RadialMenuActionExecutor.swift`.

Mil Std 2525 (`MilStd2525/`):

- `MilStd2525Symbols.swift` – Military standard symbology catalog/lookup.

**Responsibility:**

- Encapsulate reusable UI building blocks and complex interaction patterns (radial menu on the map).
- Keep Views thin by extracting complex visuals and interaction logic into dedicated components.

---

## Service Definitions

This section consolidates key service responsibilities and domains (based on `/docs/API/Services.md` and `Services/` directory).

### Core Services

- **TAKService**
  - **Role:** Core network manager to TAK server; single connection pipeline for all CoT messages.
  - **Key state:** `isConnected`, `connectionStatus`, message/byte counters.
  - **Capabilities:** Connect/disconnect/reconnect, send CoT with priority, manage TLS and certificate usage.

- **ChatService**
  - **Role:** Chat messaging engine.
  - **Capabilities:**
    - Configure with `TAKService` and `LocationManager`.
    - Build GeoChat CoT XML; send text and location messages.
    - Manage queued messages, retry on reconnect, maintain list of conversations and participants.

### Location & Tracking

- **PositionBroadcastService**
  - **Role:** Periodic PLI broadcasting.
  - **Capabilities:** Start/stop broadcasting, adjust intervals, force manual broadcast, configure identity/team metadata.

- **TrackRecordingService**
  - **Role:** Record GPS breadcrumb trails and metrics.
  - **Capabilities:** Start/pause/resume/stop tracks, compute live stats, export tracks to GPX/KML.

- **EmergencyBeaconService**
  - **Role:** Emergency beaconing with high-frequency PLIs.
  - **Capabilities:** Activate/cancel beacon, send beacon updates with special CoT types.

### Communication & Tactical Services

- **PhotoAttachmentService**
  - Sends chat image attachments, handles compression and local storage of attachment files.

- **DigitalPointerService**
  - Real-time pointer over map for coordination; manages active pointer and received pointers.

- **TeamService**
  - Creation/join/leave teams and team-based messaging; maintain team lists and user memberships.

- **VideoStreamService**
  - Discover and manage video feeds, integration with map overlays and player views.

### Map & Spatial Services

- **MeasurementService**
  - High-level distance/area measurement; manages overlays and annotations. Uses `MeasurementManager` and `MeasurementCalculator`.

- **RangeBearingService**
  - Range/bearing line calculations; creates and tracks `RangeBearingLine` entities.

- **ElevationProfileService**
  - Generates elevation profiles and single-point elevation lookups from path coordinates via `ElevationAPIClient` or similar.

- **LineOfSightService**
  - Uses elevation data and geometry to derive visibility between points.

- **BreadcrumbTrailService**
  - Converts track recordings and PLI history into rendered breadcrumb overlays.

- **NavigationService** / **TurnByTurnNavigationService**
  - Guidance over planned routes; may drive map camera and overlay instructions.

### Data & Sync Services

- **MissionPackageSyncService**
  - Sync mission packages with TAK/mission servers (upload/download, status).

- **ArcGISFeatureService** / **ArcGISPortalService**
  - Integrate ArcGIS portal and feature services: authentication, search, feature querying, and layer management.

- **CertificateEnrollmentService**
  - Enrollment flow for X.509 certificates (CSR creation, enrollment endpoints, store result, update `CertificateManager`).

- **TerrainVisualizationService**
  - Possibly builds terrain overlays from elevation or other terrain data.

---

## Interface Contracts

While Swift protocols are sparsely shown in the snippets, the architecture uses **protocol-oriented design** for interfaces and testability.

### Documented Interfaces

- `protocol CoTMessageGenerator` (example from `Architecture.md`)
  - `func generateCoTMessage() -> String`
  - Implemented by generator classes such as `ChatCoTGenerator`, `MarkerCoTGenerator`, `GeofenceCoTGenerator`, `TeamCoTGenerator`.

- CoT parsing/delegate:
  - `protocol CoTMessageDelegate: AnyObject` (doc snippet)
    - `func didReceiveMessage(_ message: String)`
  - Implemented by `CoTEventHandler` or higher-level components to receive parsed CoT from `DirectTCPSender`/`TAKService`.

- Shared interfaces in:
  - `OmniTAKMobile/Resources/Documentation/SHARED_INTERFACES.swift`
    - Likely defines cross-feature protocols (e.g., common selection, map interaction, or plugin APIs).

### ObservableObject / Combine Contracts

Many services and managers are defined as:

```swift
class XyzService: ObservableObject {
    @Published var someState: ...
}
```

That creates a **contract** with Views:

- Views can rely on `@Published` properties emitting changes.
- `configure(...)` methods must be called before usage to ensure dependencies are wired.

### Bridging Interfaces

- `OmniTAKMobile-Bridging-Header.h` and `OmniTAKMobile.xcframework/Headers/omnitak_mobile.h` expose C/Rust APIs:
  - An implicit contract: Swift `TAKService` and networking components must call into these functions to handle low-level socket connections, encryption, fragment handling, etc.
  - Rust `src/connection.rs`, `callbacks.rs`, `error.rs`, `lib.rs` define the internal core; the header defines the C ABI contract used by Swift.

---

## Design Patterns Identified

### 1. MVVM (Core Application Pattern)

Explicitly documented in `docs/Architecture.md`:

- **Model:** Types in `Models/` and some CoT & Meshtastic models.
- **ViewModel:** Classes in `Managers/` (and some services acting as view models where UI state is tightly coupled).
- **View:** SwiftUI views in `Views/` and UI components in `UI/`.

Bindings via:

- `@ObservedObject var manager: SomeManager` in Views.
- `@Published var property` in Managers/Services.

### 2. Reactive Programming with Combine

- Extensive `@Published` usage in `TAKService`, `ChatService`, `PositionBroadcastService`, `TrackRecordingService`, etc.
- Combine subscriptions used for:
  - Observing `TAKService` connection changes in managers.
  - Reacting to CoT events via `CoTEventHandler`.
  - Coordinating map state and overlays.

### 3. Dependency Injection

- Dependencies passed via `configure(...)` or initializers, e.g.:

  ```swift
  func configure(takService: TAKService, chatManager: ChatManager)
  ```

- Encourages:
  - Testability (mock `TAKService`, `LocationManager`).
  - Clear dependency graph (docs list many configure methods in services).

### 4. Protocol-Oriented & Delegate Patterns

- Protocols (`CoTMessageGenerator`, `CoTMessageDelegate`) separate behavior from implementation.
- `DirectTCPSender` uses delegate for message callbacks.
- `NotificationCenter` is used where 1:N broadcast is needed beyond Combine.

### 5. Feature Modularity / “Vertical Slices”

- Each tactical feature has a set of:
  - Models (`*Models.swift`)
  - Views (`*View.swift`)
  - Managers (`*Manager.swift`)
  - Services (`*Service.swift`).

This forms vertical slices (e.g., Chat, Track Recording, Geofencing), making it easier to reason about or extend individual capabilities.

### 6. Bridged Native Core Pattern

- Networking and protocol details are moved into a native xcframework (Rust + C), with a **Facade Service** (`TAKService`) on the Swift side:
  - Swift code maintains high-level state and Combine bindings.
  - Native core handles performance-critical and protocol-specific operations.

---

## Component Relationships

### High-Level Dependency Graph (based on `Architecture.md`)

- `OmniTAKMobileApp` → `ContentView`/`ATAKMapView` (main coordinator view).
- `ATAKMapView` owns:
  - `TAKService`
  - `ChatManager`, `ServerManager`, `CertificateManager`
  - `DrawingToolsManager`, `OfflineMapManager`, `GeofenceManager`
  - Location subsystem (`CoreLocation`)
  - Map controllers (`EnhancedMapViewController`, `MapOverlayCoordinator`, `RadialMenuMapCoordinator`)

- `TAKService` →
  - `DirectTCPSender` (low-level TCP/UDP/TLS)
  - `CoTMessageParser`
  - `CoTEventHandler`

- `CoTEventHandler` →
  - `ChatManager`, `TrackRecordingService`, `EmergencyBeaconService`, `TeamService`, etc.

- `ChatManager` →
  - `ChatService` (message logic)
  - `ChatPersistence` / `ChatStorageManager`
  - `PhotoAttachmentService`

- `DrawingToolsManager` →
  - `DrawingPersistence`
  - `MapOverlayCoordinator`

- `OfflineMapManager` →
  - `OfflineTileCache`, `TileDownloader`
  - `OfflineMapModels`

- `MeasurementService` / `RangeBearingService` / `LineOfSightService` →
  - `MeasurementCalculator`, `ElevationProfileService`, `ElevationAPIClient`
  - Map overlays for visualization.

### Communication Paths

- **TAKService → CoTEventHandler → Managers/Services**
  - Inbound CoT data flows from network to parser to event handler and then to feature managers.

- **Managers → Services → CoT Generators → TAKService**
  - Outbound actions (chat send, PLI, beacon, team messages, markers) flow from Views to Managers to domain Services, which generate CoT XML and send via `TAKService`.

- **Managers ↔ Map Controllers / Overlays**
  - Managers decide what overlays/markers should be active; the Map subsystem renders them.

- **Storage** is used by Managers and Services; Views rarely reach storage directly.

---

## Key Methods & Functions

Summarizing the most structurally important methods (per docs):

### TAKService

- `connect(host:port:protocolType:...)`
  - Opens or reconfigures the TAK connection (possibly via native xcframework functions).
- `disconnect()`
  - Hard close of network session.
- `send(cotMessage:priority:)`
  - Core outbound pipeline for any CoT XML.
- `reconnect()`
  - Reestablish connection after network change or failure.

### ChatService

- `configure(takService:locationManager:)`
  - Wires networking and location into chat.
- `sendTextMessage(_:to:)`
  - Standard text chat sending via CoT.
- `sendLocationMessage(location:to:)`
  - Location-sharing messages.
- `processQueue()`
  - Resend queued messages after reconnect or failures.
- `markAsRead(_:)`
  - Updates unread counts & conversation state.

### PositionBroadcastService

- `configure(takService:locationManager:)`
- `startBroadcasting()`, `stopBroadcasting()`
- `broadcastPositionNow()`
  - All central to continuous PLI functionality.
- `setUpdateInterval(_:)`
  - Controls frequency and battery-use vs timeliness.

### TrackRecordingService

- `startRecording(name:)`, `pauseRecording()`, `resumeRecording()`, `stopRecording()`
  - Governs track lifecycle.
- `exportTrack(_:format:)`
  - Integrates with sharing/export UI and KML/GPX formats.

### EmergencyBeaconService

- `activateBeacon(type:)`, `cancelBeacon()`, `sendBeaconUpdate()`
  - Define emergency escalation & persistence of beacon.

### MeasurementService

- `startMeasurement(type:)`
- `addPoint(_:)`
- `completeMeasurement()`
  - Map-centric measurement workflows.
- `addRangeRing(center:radius:)`
  - Quick configuration of range overlays.

### RangeBearingService

- `createLine(from:to:)`
- `calculateBearing(from:to:)`, `calculateDistance(from:to:)`
  - Core geometry primitives reused in tactical tools.

### ElevationProfileService

- `generateProfile(for:)`
  - Asynchronous path profile generation.
- `fetchElevation(at:)`
  - Single-point queries used by LOS, measurement, and map inspection.

### CoTEventHandler (from Architecture doc)

- Routes events to specific subsystems (ChatManager, TrackRecordingService, EmergencyBeaconService, etc.)
- Publishes domain events via Combine and NotificationCenter.

These methods define the main capabilities and boundaries: networking, messaging, PLI, tracks, spatial analysis, and integration.

---

## Available Documentation

### Documents in `/docs`

- `docs/Architecture.md`
  - **Content:**
    - Detailed architecture overview (MVVM, subsystems, diagrams for Network, Map, Storage).
    - Component relationships, data flow, threading, memory considerations (beyond excerpt).
  - **Quality:**
    - High: opinionated, diagrams, describes actual classes and flows; directly reflects the current structure.

- `docs/README.md`, `DOCUMENTATION_SUMMARY.md`, `DOCUMENTATION_COMPLETE.md`
  - **Content:**
    - Meta overview of documentation status and structure; pointers to other docs.
  - **Quality:**
    - Good for navigation; not deeply technical.

- `docs/errors.md`
  - Likely enumerates error types, codes, or handling patterns (e.g., TAK connection, certificate, map errors).

- `docs/guidebook.md`, `docs/userguide.md`, `docs/todo.md`, `docs/suggestions.md`
  - **guidebook/userguide:** Conceptual and end-user-level features overview.
  - **todo/suggestions:** Planned improvements, architectural debt, and feature requests.

- `docs/DOCUMENTATION_*` series
  - Provide coverage status and may highlight gaps.

### API Documentation

- `docs/API/Managers.md`
  - **Content:**
    - Describes each manager (`ChatManager`, `ServerManager`, etc.), public properties, and methods.
  - **Quality:**
    - Good for understanding ViewModel responsibilities and how to use them from Views.

- `docs/API/Models.md`
  - **Content:**
    - Data model schemas: properties, relationships, and how they are used by services and managers.
  - **Quality:**
    - Solid reference for serialization and feature data shapes.

- `docs/API/Services.md`
  - **Content (sample examined):**
    - Detailed service descriptions, key methods, and usage examples for `TAKService`, `ChatService`, `PositionBroadcastService`, `TrackRecordingService`, `EmergencyBeaconService`, `MeasurementService`, `RangeBearingService`, `ElevationProfileService`, `TeamService`, `PhotoAttachmentService`, `DigitalPointerService`.
  - **Quality:**
    - High: method signatures, semantics, and code snippets are provided. Up-to-date with file paths and approximate line counts, suggesting active maintenance.

### Feature Guides

- `docs/Features/ChatSystem.md`, `CoTMessaging.md`, `MapSystem.md`, `Networking.md`
  - **Content:**
    - Explain how high-level features are composed from managers, services, models, and CoT.
  - **Quality:**
    - Very helpful for onboarding; explain the “why” behind architectural choices for each domain.

### Developer-Oriented Docs

- `docs/DeveloperGuide/GettingStarted.md`
  - Project setup, build targets, environment.
- `docs/DeveloperGuide/CodebaseNavigation.md`
  - Maps directories to responsibilities (matches analysis above).
- `docs/DeveloperGuide/CodingPatterns.md`
  - Codifies MVVM, naming, Combine usage, and DI patterns.

### Embedded Feature Documentation

Under `OmniTAKMobile/Resources/Documentation`:

- `CHAT_FEATURE_README.md`
- `FILTER_INTEGRATION_GUIDE.md`
- `KML_INTEGRATION_GUIDE.md`
- `MESHTASTIC_PROTOBUF_README.md`
- `OFFLINE_MAPS_INTEGRATION.md`
- `RADIAL_MENU_INTEGRATION_GUIDE.md`
- `WAYPOINT_INTEGRATION_GUIDE.md`
- `UI_LAYOUT_REFERENCE.md`
- `USAGE_EXAMPLES.swift`
- `SHARED_INTERFACES.swift`

**Quality & Usefulness:**

- Very practical, feature-specific guides that:
  - Specify which managers/services to use.
  - Show example code paths (`USAGE_EXAMPLES.swift`).
  - Document internal interfaces and extension points (`SHARED_INTERFACES.swift`).
- They bridge the gap between the high-level architecture docs and concrete code usage.

### GitHub / Repo-Level Docs

- Root `README.md`
  - Project introduction, feature overview, and quickstart.
- `CONNECTING_TO_TAK_SERVER.md`, `TLS_LEGACY_SUPPORT.md`
  - Document network and TLS configuration details.
- `RESTRUCTURING_GUIDE.md`
  - Historical/ongoing refactoring and directory changes; explains why some “Modified”/“backup” files exist.

**Overall Documentation Quality:**

- Broad and deep coverage from architecture to per-service APIs and feature guides.
- Documentation is strongly aligned with the directory and class structure, making it an accurate map of the codebase.
- For structural understanding, `docs/Architecture.md`, `docs/API/*.md`, and `Resources/Documentation/*` are the primary references and appear well-maintained.
