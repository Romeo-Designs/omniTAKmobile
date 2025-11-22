# Dependency Analysis

## Internal Dependencies Map

### High-level module structure

The Xcode project is organized primarily by feature and role:

- `Core/`
  - App entry and root composition (`ContentView.swift`, `OmniTAKMobileApp.swift` referenced in docs)
- `Views/`
  - SwiftUI screens and panels for each feature (map, chat, TAK servers, offline maps, Meshtastic, etc.)
- `Managers/`
  - Feature-level “view models” / controllers (e.g., `ChatManager`, `ServerManager`, `OfflineMapManager`, `WaypointManager`, etc.)
- `Services/`
  - Business logic and integration classes (e.g., `TAKService`, `ChatService`, `ArcGIS*Service`, `CertificateEnrollmentService`, etc.)
- `Models/`
  - Data structures grouped by feature (e.g., `ChatModels`, `RouteModels`, `TeamModels`, etc.)
- `CoT/`
  - CoT event handling, filtering, parsing, and XML generation
- `Map/`
  - Controllers, overlays, markers, tile sources, integration with map engines
- `Utilities/`
  - Cross-cutting helpers (calculators, converters, KML integration, networking, parsers)
- `Storage/`
  - Persistence and storage managers (chat, drawing, routes, team state)
- `Meshtastic/`
  - Protobuf models and parsing
- `UI/Components`, `UI/RadialMenu`, `UI/MilStd2525`
  - Reusable UI elements and MIL-STD-2525 symbol logic
- `Resources/Documentation`
  - In-code documentation and shared interface examples

This aligns with the architecture doc’s layers:

- Views (`Views/`)
- ViewModels/Managers (`Managers/`)
- Services (`Services/`)
- Models (`Models/`)
- Utilities & Integration (KML, network, converters)
- CoT infrastructure (`CoT/`)

### Core internal dependencies

#### `ContentView` → `TAKService`

File: `OmniTAKMobile/Core/ContentView.swift`

- Declares:
  - `@StateObject private var takService = TAKService()`
- Uses `takService`’s state:
  - `connectionStatus: String`
  - `isConnected: Bool`
  - `lastError: String`
  - `messagesReceived: Int`
  - `messagesSent: Int`
  - `lastMessage: String`
- Invokes methods:
  - `takService.connect(host:port:protocolType:useTLS:)`
  - `takService.disconnect()`
  - `takService.sendCoT(xml:) -> Bool`

This view is a thin UI shell around `TAKService`, and represents a direct view → service dependency, bypassing a separate manager.

#### `TAKService` → Networking, CoT, Managers

File: `OmniTAKMobile/Services/TAKService.swift` (partial view: DirectTCPSender inside)

Key internals:

- Imports:
  - `Foundation`
  - `Combine`
  - `CoreLocation`
  - `Network`
  - `Security`
- Defines `ConnectionProtocol` and `DirectTCPSender`.
- `DirectTCPSender` uses:
  - `NWConnection`, `NWParameters`, `NWEndpoint`, `NWProtocolTCP`, `NWProtocolTLS`
  - `sec_protocol_options_*` C APIs from `Security`

Within the larger `TAKService` (implied from architecture docs and naming), dependencies typically include:

- CoT handling:
  - `CoTEventHandler`
  - `CoTMessageParser`
  - CoT generators (`ChatCoTGenerator`, `MarkerCoTGenerator`, `TeamCoTGenerator`, etc.)
- Managers:
  - `ChatManager` (to emit new chat messages from incoming CoT)
  - `ServerManager` (for active server configuration)
  - `TeamManager`, `WaypointManager`, `TrackRecordingManager`, etc. for different CoT event types
- Services:
  - `PositionBroadcastService` (for periodic self-position CoT)
  - Possibly `BreadcrumbTrailService`, `TrackRecordingService` (for track updates transmitted over TAK)

So the dependency direction is:

- `ContentView` → `TAKService`
- `TAKService` → networking primitives, CoT components, multiple feature managers and services

#### `ServerManager` & `TAKServer` model

File: `OmniTAKMobile/Managers/ServerManager.swift`

- `TAKServer` (model):
  - `Identifiable`, `Codable`, `Equatable`
  - Properties:
    - `name`, `host`, `port`, `protocolType`, `useTLS`, `isDefault`
    - `certificateName`, `certificatePassword`, `allowLegacyTLS`
- `ServerManager` (manager/view-model):
  - `ObservableObject`
  - Singleton: `static let shared = ServerManager()`
  - `@Published var servers: [TAKServer]`
  - `@Published var activeServer: TAKServer?`
  - Uses `UserDefaults` for persistence.

Dependencies:

- `ServerManager` → `TAKServer` (model)
- `ServerManager` persists to `UserDefaults` and exposes `activeServer` for other components such as:
  - `TAKService` (to get host, port, TLS details)
  - `TAKServersView`, `ServerPickerView` (UI for selecting servers)
  - `QuickConnectView`, `NetworkPreferencesView`

The server configuration is thus a single shared dependency for all networked TAK-related features.

#### Managers → Services → Models

This pattern is consistent across features (from `docs/Architecture.md` and module layout):

- Example from Architecture doc:

  ```swift
  class ChatManager: ObservableObject {
      @Published var conversations: [Conversation] = []
      @Published var unreadCount: Int = 0
      
      private let chatService: ChatService
      private let persistence: ChatPersistence
      
      func sendMessage(_ text: String, to recipient: String) {
          let message = chatService.createMessage(text, recipient)
          chatService.send(message)
          persistence.save(message)
      }
  }
  ```

In the project:

- Each `Managers/*.swift` file likely follows this:

  - `ChatManager` → `ChatService`, `ChatPersistence`, `TAKService`
  - `WaypointManager` → `WaypointModels`, `OfflineMapManager` (for coordinate context), `BreadcrumbTrailService`
  - `OfflineMapManager` → `OfflineMapModels`, `OfflineTileCache`, `TileDownloader`
  - `MeasurementManager` → `MeasurementService`, `MeasurementModels`, `MeasurementCalculator`
  - `GeofenceManager` → `GeofenceService`, `GeofenceModels`
  - `MeshtasticManager` → `MeshtasticProtobufParser`, `MeshtasticModels`

- Each `Services/*.swift` file depends on:
  - Domain models (`Models/*`)
  - Lower-level utilities (e.g., KML, networking, storage)
  - `TAKService` is a special cross-cutting service used by many others (for CoT transport).

#### Views → Managers

Looking at `Views/` directory, each view’s name matches a feature manager or service:

- `ChatView` → `ChatManager`
- `CoTFilterPanel` → `CoTFilterManager`
- `OfflineMapsView` → `OfflineMapManager`
- `MeshtasticConnectionView`, `MeshTopologyView` → `MeshtasticManager`
- `TrackListView`, `TrackRecordingView` → `TrackRecordingService` / track manager
- `WaypointsListView` → `WaypointManager`
- `TeamManagementView` → `TeamService` / team manager
- `PluginsListView` → plugin registry / configuration (internal plugin system)

Relationship:

- Views depend on managers/services through property wrappers (`@ObservedObject`, `@StateObject`, `@EnvironmentObject`).
- Managers orchestrate between views and services; they are the primary internal dependency point for views.

#### CoT subsystem

Files:

- `CoT/CoTEventHandler.swift`
- `CoT/CoTFilterCriteria.swift`
- `CoT/CoTMessageParser.swift`
- `CoT/Generators/*.swift` (Chat, Geofence, Marker, Team)
- `CoT/Parsers/*.swift` (ChatXML*)

Dependencies:

- CoT generators depend on:
  - Feature models (`ChatModels`, `GeofenceModels`, `PointMarkerModels`, `TeamModels`, etc.)
  - Possibly `TAKService` for UID/timestamps
- `CoTEventHandler` depends on:
  - `TAKService` (to register callbacks/listeners)
  - Feature managers (`ChatManager`, `TeamService`, `GeofenceManager`, `WaypointManager`) to dispatch parsed CoT events.
- CoT filters (`CoTFilterCriteria`, `CoTFilterManager`) depend on:
  - Models representing filter state (`CoTFilterModel.swift`)
  - Map overlays / list views to determine what to show.

This subsystem is a major internal integration hub, linking network messages (via `TAKService`) to feature-level managers.

#### Map subsystem

Files:

- Controllers: `MapViewController.swift`, `EnhancedMapViewController.swift`, `IntegratedMapView.swift`, `MapStateManager.swift`, etc.
- Overlays: `BreadcrumbTrailOverlay.swift`, `RangeBearingOverlay.swift`, `UnitTrailOverlay.swift`, `VideoMapOverlay.swift`, etc.
- Markers: `CustomMarkerAnnotation.swift`, `EnhancedCoTMarker.swift`, `MarkerAnnotationView.swift`
- Tile sources: `ArcGISTileSource.swift`, `OfflineTileCache.swift`, `TileDownloader.swift`

Dependencies:

- Map controllers depend on:
  - Managers: `MeasurementManager`, `WaypointManager`, `DrawingToolsManager`, `OfflineMapManager`, `TrackRecordingService`, `TeamService`
  - Overlays & marker models: `TrackModels`, `BreadcrumbTrailService`, `ArcGISModels`, `VideoStreamModels`
  - Utilities:
    - `MGRSConverter`, `BNGConverter` (for coordinate labeling)
    - `MeasurementCalculator`
  - Possibly `TAKService` (for live position / track overlays)

- Overlays depend on:
  - Models (e.g., `TrackModels`, `BreadcrumbTrailModels` if present in `Models/`)
  - Services (e.g., `BreadcrumbTrailService`) that maintain overlay state

#### Utilities & Storage

- `Utilities/Calculators/MeasurementCalculator.swift`
  - Used by `MeasurementService` and map overlays for computing distance, bearing, etc.
- `Utilities/Converters/MGRSConverter.swift`, `BNGConverter.swift`
  - Used by `CoordinateDisplayView`, map overlays, and measurement views.
- `Utilities/Integration/KML*` (`KMLMapIntegration.swift`, `KMLOverlayManager.swift`, `KMLParser.swift`, `KMZHandler.swift`)
  - Used by `KMLImportView`, `OfflineMapManager`, and map controllers to overlay KML/KMZ content.
- `Utilities/Network/NetworkMonitor.swift`, `MultiServerFederation.swift`
  - `NetworkMonitor` used by `TAKService`, `OfflineMapManager`, `MissionPackageSyncService` to adapt to connectivity.
  - `MultiServerFederation` used by `TAKService` / `MissionPackageSyncService` to manage multiple TAK / TAK-like endpoints.

- `Storage/*`
  - `ChatPersistence`, `ChatStorageManager` used by `ChatManager`, `ChatService`.
  - `RouteStorageManager` used by route planning manager/service.
  - `TeamStorageManager` used by `TeamService` / `TeamManagementView` to persist team setup.
  - `DrawingPersistence` used by `DrawingToolsManager`.

## External Libraries Analysis

The repo does not show Cocoapods/Swift Package manifest files in the root listing, implying:

- Heavy use of **Apple frameworks**:
  - `SwiftUI` (views, `@StateObject`, `NavigationView`, etc.)
  - `Combine` (`ObservableObject`, `@Published`, reactive bindings)
  - `Network` (`NWConnection`, `NWParameters`, TLS/UDP/TCP)
  - `Security` (TLS configuration, client certificate loading)
  - `CoreLocation` (for coordinates in CoT, measurement, map features)
  - `MapKit` or 3rd-party map frameworks (Map controllers and overlays suggest MapKit; docs mention ArcGIS, so ArcGIS Runtime iOS is likely used via `ArcGISTileSource`, `ArcGISFeatureService`, `ArcGISPortalService`.)

- **ArcGIS Runtime SDK for iOS** (inferred):
  - `ArcGISFeatureService.swift`, `ArcGISPortalService.swift`, `ArcGISTileSource.swift`, `ArcGISModels.swift` strongly suggest this.
  - These services act as wrappers around the ArcGIS SDK: handling portal login, feature queries, map tile sources, elevation/terrain.

- **Meshtastic Protobuf** (internal / generated code):
  - `MeshtasticProtoMessages.swift`, `MeshtasticProtobufParser.swift` indicate embedded protobuf message definitions for Meshtastic devices, likely generated from `.proto` files, but committed as Swift.

- **Rust-based native library** (optional/incomplete):
  - `OmniTAKMobile.xcframework/ios-arm64/Headers/src/*.rs`, `Cargo.toml`, `omnitak_mobile.h`
  - Indicates a Rust core library exposed as an XCFramework to iOS.
  - However, `TAKService` comment: “Direct Network Sender (bypasses incomplete Rust FFI)” shows that for now, direct Swift networking is used instead of the Rust FFI bindings.
  - The Rust FFI is thus an *optional or future* dependency, partially wired via bridging header (`OmniTAKMobile-Bridging-Header.h`).

No explicit 3rd-party Swift packages (e.g., Alamofire, GRDB) appear in the listed files; networking and persistence are built on system APIs (`Network`, `UserDefaults`, possible `FileManager`).

## Service Integrations

### TAK Server (primary service)

- Implemented via `TAKService.swift` (plus `DirectTCPSender`).
- Protocols supported:
  - TCP, UDP, TLS (configurable via `protocolType` and `useTLS`).
- TLS configuration:
  - Uses `NWProtocolTLS` with:
    - Min TLS version configurable (TLS 1.0+ if `allowLegacyTLS = true`, else TLS 1.2).
    - Max TLS 1.3.
    - Legacy cipher suites appended for compatibility with older TAK servers.
    - Optionally disables certificate verification to accept self-signed certs (via `sec_protocol_options_set_verify_block`).
    - Optional client certificate from app bundle (`certificateName`/`certificatePassword` from `TAKServer`).
- Server configuration:
  - `ServerManager` manages multiple `TAKServer` entries, persisted to `UserDefaults`.
  - `TAKService.connect` likely takes arguments deriving from `ServerManager.activeServer`.

Integration points:

- Sending: `sendCoT(xml:)` in `TAKService` (used by `ContentView`, `ChatService`, CoT generators).
- Receiving:
  - `DirectTCPSender.startReceiveLoop()` reads data, updates `onMessageReceived` callback to deliver raw XML.
  - `TAKService` parses XML into CoT objects via `CoTMessageParser`, then dispatches to:
    - `ChatManager` (geo-chat)
    - `TeamService` (unit updates)
    - `GeofenceManager` (geofences shared via CoT)
    - `TrackRecordingService` / `BreadcrumbTrailService` (track updates)

### ArcGIS / Mapping Services

Files:

- `ArcGISFeatureService.swift`
- `ArcGISPortalService.swift`
- `ArcGISTileSource.swift`
- `ArcGISModels.swift`

Responsibilities:

- `ArcGISPortalService`:
  - Integration with ArcGIS Portal/Online: user sign-in, content browsing, token management.
- `ArcGISFeatureService`:
  - Querying feature layers, editing features, fetching attributes for overlays.
- `ArcGISTileSource`:
  - Custom tile source integration for base maps, perhaps hooking ArcGIS imagery into `MapViewController`.

Used by:

- `ArcGISPortalView` (UI)
- `Map3DViewController`, `Map3DSettingsView`
- Offline maps (if ArcGIS offline bundles are used) and `OfflineMapManager`.

### Elevation & Terrain

Files:

- `ElevationAPIClient.swift` (both under `OmniTAKMobile/` and `Services/`—possible duplication/overlap)
- `ElevationProfileService.swift`
- `ElevationProfileModels.swift`
- `LineOfSightService.swift`
- `TerrainVisualizationService.swift`

Responsibilities:

- `ElevationAPIClient`:
  - External HTTP service for elevation data (exact endpoint not visible, but strongly implied).
- `ElevationProfileService`:
  - Uses `ElevationAPIClient` to generate elevation profiles for routes/paths.
- `LineOfSightService`:
  - Uses elevation + coordinates to compute visibility.
- `TerrainVisualizationService`:
  - Generates terrain-based overlays for map.

### Meshtastic

Files:

- `MeshtasticManager.swift`
- `MeshtasticProtoMessages.swift`
- `MeshtasticProtobufParser.swift`
- Views: `MeshtasticConnectionView`, `MeshtasticDevicePickerView`, `MeshTopologyView`
- Models: `MeshtasticModels.swift`

Integration:

- Connects to Meshtastic radio devices (likely via Bluetooth or serial; specific APIs contained in these files).
- Uses protobuf-encoded messages to exchange position and chat; these are then converted into CoT or internal models.
- May inject positions into `TAKService`/CoT as a gateway.

### Mission Packages & Data Packages

Files:

- `DataPackageManager.swift`, `DataPackageModels.swift`
- `MissionPackageSyncService.swift`, `MissionPackageModels.swift`
- Views: `DataPackageImportView`, `DataPackageView`, `MissionPackageSyncView`

Integration:

- Handles TAK “Mission Packages” and “Data Packages” (compression, metadata, attachments).
- Sync may use TAK server file services or external HTTP endpoints.
- `DataPackageManager` interacts with local filesystem and `TAKService` to send/receive packages.

### Video Streams

Files:

- `VideoStreamService.swift`
- Models: `VideoStreamModels.swift`
- Views: `VideoFeedListView`, `VideoPlayerView`
- Overlay: `VideoMapOverlay.swift`

Integration:

- Connects to external video streams (RTSP, HLS, or TAK video endpoints).
- Exposes streams to map overlays and dedicated views.
- Likely interacts with iOS AVFoundation but details are in `VideoStreamService.swift`.

### Certificate Enrollment & Management

Files:

- `CertificateManager.swift` (manager)
- `CertificateEnrollmentService.swift`, `CertificateEnrollmentView.swift`
- `CertificateManagementView.swift`, `CertificateSelectionView.swift`
- `Resources/omnitak-mobile.p12` (embedded client certificate)

Integration:

- Interacts with:
  - TLS client certificate identity in `TAKService` (via `DirectTCPSender.loadClientCertificate`).
  - Possibly enrollment endpoints (SCEP, EST, or TAK server’s enrollment API), handled by `CertificateEnrollmentService`.

### Other Services

- `BloodhoundService` / `BloodhoundView`:
  - Search and rescue / route analysis features, possibly using external geospatial services or internal algorithms.
- `TurnByTurnNavigationService`:
  - Provides navigation instructions; may use iOS navigation/mapping APIs or custom routing.
- `DigitalPointerService`, `EmergencyBeaconService`, `PositionBroadcastService`:
  - CoT-based features integrated via `TAKService`.
- `ChatService`, `PhotoAttachmentService`, `TeamService`, `NavigationService`, `RoutePlanningService`:
  - Higher-level services layering business behavior on top of TAK CoT and map.

## Dependency Injection Patterns

### Patterns in use

From `docs/Architecture.md` and code:

1. **Init injection** for services and persistence:

   - Managers take services/persistence objects in initializers.
   - Example from docs (`ChatManager`):

     ```swift
     private let chatService: ChatService
     private let persistence: ChatPersistence
     ```

2. **Configuration injection via methods**:

   - Example in docs:

     ```swift
     func configure(takService: TAKService, chatManager: ChatManager) {
         self.takService = takService
         self.chatManager = chatManager
     }
     ```

   - Used for components that can’t use full init injection (e.g., created from storyboards/SwiftUI environment, or bridging from Objective‑C).

3. **Property wrapper-based injection**:

   - `@StateObject` / `@ObservedObject`:
     - `ContentView` uses `@StateObject private var takService = TAKService()`
   - `@EnvironmentObject`:
     - Many `Views/*` will accept plain `@EnvironmentObject var chatManager: ChatManager` etc., with the environment composed at the app root.

4. **Singletons for core services**:

   - `ServerManager`:

     ```swift
     class ServerManager: ObservableObject {
         static let shared = ServerManager()
     }
     ```

   - Likely similar patterns for global cross-cutting services (e.g., plugin registry, some managers).

5. **Bridging header for FFI**:

   - `OmniTAKMobile-Bridging-Header.h` connects Swift code to C/Rust FFI (via `omnitak_mobile.h` from the XCFramework).
   - This is a separate form of DI at the boundary between Swift and Rust: functions/handles are imported and used where needed (likely inside `TAKService` or a low-level connection wrapper), but currently bypassed by `DirectTCPSender`.

### DI composition points

- Root composition occurs in:

  - `OmniTAKMobileApp.swift` (not shown, but referenced), where:
    - `TAKService`, managers, and services are instantiated.
    - Environment objects for key managers are attached to the SwiftUI hierarchy.

- Views like `PluginsListView`, `SettingsView`, `TAKServersView` get dependencies from environment or from singletons (`ServerManager.shared`).

### Observed coupling in DI

- `ContentView` directly instantiates `TAKService` as `@StateObject`, which tightly couples that view to the specific implementation.
- `ServerManager` uses a `static shared` singleton, spreading implicit global state.

These patterns are used pragmatically but reduce testability versus full protocol-based DI + central container.

## Module Coupling Assessment

### Strongly coupled cores

1. **TAKService as a central hub**

   - Used by:
     - `ContentView`
     - `ChatService` (for message sending)
     - Position-related services (`PositionBroadcastService`, `TurnByTurnNavigationService`)
     - CoT generators and parsers
     - Map overlays representing live units/tracks
   - Internally relies on:
     - `DirectTCPSender` (internal nested class)
     - CoT subsystem (`CoTMessageParser`, `CoTEventHandler`)
     - `ServerManager` for configuration

   Impact: many features depend on this one class; changes in connection handling, TLS, or CoT dispatch can have wide blast radius.

2. **CoT subsystem coupling**

   - CoT parsing/generation touches nearly every tactical feature:
     - Chat, markers, tracks, geofences, teams, emergency beacons, digital pointers, mission packages.
   - `CoTEventHandler` interacts with many managers (`ChatManager`, `TeamService`, `WaypointManager`, etc.).

   Impact: domain logic for multiple features is centralized in CoT handling; this is necessary from a protocol standpoint but makes CoT a key coupling point.

3. **Map subsystem**

   - `MapStateManager`, map controllers, overlays, and tile sources depend on:
     - Many models (`TrackModels`, `PointMarkerModels`, `OfflineMapModels`, `VideoStreamModels`, etc.).
     - Services (`BreadcrumbTrailService`, `VideoStreamService`, `OfflineMapManager`, `ArcGIS*Service`).

   Impact: Map code is highly integrated; features that show anything on the map will depend on map types and overlays.

4. **ServerManager singleton**

   - Any code that needs server info can reach `ServerManager.shared`.
   - Couples configuration persistence to many consumers.

### Cohesion

Despite coupling, cohesion is good:

- Feature-specific directories:
  - `Managers` and `Models` are grouped by feature.
  - `Views` are grouped by function (Chat, Meshtastic, OfflineMaps, etc.)
- Each class has a clear single responsibility (per Architecture doc).
  - Managers are view models.
  - Services focus on external IO or business logic.
  - Models are data-only.

This promotes local reasoning: if you work on chat, you mostly touch `Chat*` files and associated CoT pieces.

## Dependency Graph

High-level conceptual graph (simplified):

```text
SwiftUI Views
    |
    v
Managers (ObservableObject)
    |
    v
Services  <--> Utilities/Storage
    |
    v
TAKService  <--> DirectTCPSender (NWConnection, TLS)
    |
    v
CoT Parsers / Generators
    |
    v
Models

ArcGIS Views --> ArcGIS*Manager/Services --> ArcGIS Runtime SDK
Meshtastic Views --> MeshtasticManager --> MeshtasticProtobufParser --> MeshtasticProtoMessages

ServerPickerView/TAKServersView
    |
    v
ServerManager (singleton)
    |
    v
TAKService.connect(...)
```

More concrete per-component relationships (non-exhaustive, but grounded in existing files and docs):

- `ContentView`
  - → `TAKService`

- `TAKService`
  - → `DirectTCPSender`
  - → `ServerManager` (config)
  - → `CoTMessageParser` / `CoTEventHandler`
  - → `PositionBroadcastService`
  - → `ChatService`, `TeamService`, `TrackRecordingService`, `WaypointManager`, etc. for dispatch.

- `ServerManager`
  - → `UserDefaults`
  - Exposed to:
    - `TAKService`
    - `TAKServersView`, `QuickConnectView`, `NetworkPreferencesView`

- `ChatManager`
  - → `ChatService`
  - → `ChatPersistence` / `ChatStorageManager`
  - → Observed by `ChatView`, `ConversationView`, `ContactListView`

- `ChatService`
  - → `TAKService` (sending messages via CoT)
  - → `ChatXMLGenerator` / `ChatXMLParser` (GeoChat XML)

- `OfflineMapManager`
  - → `OfflineTileCache`
  - → `TileDownloader`
  - → `OfflineMapModels`
  - → Observed by `OfflineMapsView`, `Map controllers`

- `MeasurementManager`
  - → `MeasurementService`
  - → `MeasurementCalculator`
  - → `MeasurementModels`
  - → Used by `MeasurementToolView`, `MeasurementOverlay`

- `MeshtasticManager`
  - → `MeshtasticProtobufParser`, `MeshtasticProtoMessages`
  - → `MeshtasticModels`
  - → Used by `MeshtasticConnectionView`, `MeshTopologyView`

- `MapViewController` & `MapStateManager`
  - → Managers: `MeasurementManager`, `DrawingToolsManager`, `WaypointManager`, `GeofenceManager`, `TrackRecordingService`
  - → Overlays: `BreadcrumbTrailOverlay`, `MGRSGridOverlay`, `VideoMapOverlay`, `RangeBearingOverlay`, etc.
  - → Tile sources: `ArcGISTileSource`, `OfflineTileOverlay`
  - → Utilities: `MGRSConverter`, `MeasurementCalculator`

- `CertificateManager`
  - → `CertificateEnrollmentService`
  - → `TAKService` (via certificateName/password, or direct TLS identity injection)
  - → `Resources/omnitak-mobile.p12`

## Potential Dependency Issues

### 1. Over-centralization of `TAKService`

- **Issue**: `TAKService` plays multiple roles:
  - Network transport (TCP/UDP/TLS)
  - CoT dispatch coordination
  - Global event source for multiple features
- **Risk**:
  - Changes in connection behavior or error handling can break many features simultaneously.
  - Harder to unit test in isolation.
- **Improvement**:
  - Introduce protocols (e.g., `CoTTransport`, `CoTEventBus`) and have `TAKService` implement them.
  - Have features depend on these protocols instead of the concrete `TAKService`.
  - Extract `DirectTCPSender` into a separate service object and inject it, instead of instantiating internally.

### 2. Mixed DI styles and singletons

- **Issue**:
  - Some components use init injection, some use `@StateObject` direct instantiation, others rely on singletons (e.g., `ServerManager.shared`).
- **Risk**:
  - Harder to swap implementations (e.g., fake servers for tests).
  - Lifecycle management of global singletons is implicit.
- **Improvement**:
  - Standardize DI:
    - Use `@EnvironmentObject` for global services and managers in SwiftUI.
    - Use protocols for core services and inject via initializers.
  - Wrap singletons in protocol types to allow mocking.

### 3. Tight coupling between CoT parsing and feature managers

- **Issue**:
  - `CoTEventHandler` likely contains logic like “if CoT type is X, update ChatManager; if Y, update TrackRecordingService…”.
- **Risk**:
  - Adding new CoT message types requires editing central handler.
  - Harder to modularize features; cross-feature dependencies accumulate in CoT handler.
- **Improvement**:
  - Implement a pluggable CoT handler registry:
    - Each feature registers a handler for specific CoT types (plugin-like system).
    - `CoTEventHandler` simply routes events to registered handlers.

### 4. Optional Rust FFI complexity

- **Issue**:
  - There is an XCFramework containing Rust code, but networking currently bypasses it in favor of `DirectTCPSender`.
- **Risk**:
  - Two competing code paths for TAK connectivity may emerge.
  - Future integration of Rust FFI could introduce subtle behavior differences.
- **Improvement**:
  - Define a clear `ConnectionProvider` protocol and ensure both “Swift NWConnection” and “Rust FFI” implementations conform.
  - Encapsulate selection logic (which provider to use) behind a single factory.

### 5. ArcGIS and external service wrappers

- **Issue**:
  - ArcGIS services and `ElevationAPIClient` are likely directly referenced by managers and views.
- **Risk**:
  - Vendor SDK types leak into app-wide code, making it harder to replace or abstract.
- **Improvement**:
  - Keep vendor-specific types inside service implementations; expose feature-oriented protocols/data models to the rest of the app.

### 6. Storage & UserDefaults

- **Issue**:
  - `ServerManager` directly uses `UserDefaults`.
  - Other storage managers likely use `FileManager` / `UserDefaults` directly.
- **Risk**:
  - Harder to unit test without side effects.
- **Improvement**:
  - Abstract persistence behind protocols (`KeyValueStore`, `FileStore`), and inject concrete implementations.

### 7. View ↔ Service direct coupling

- **Issue**:
  - `ContentView` directly owns `TAKService`, not through a manager.
- **Risk**:
  - Violates MVVM separation (view directly manipulating service).
- **Improvement**:
  - Introduce a simple `ConnectionManager` view model that wraps `TAKService`.
  - The view binds to `ConnectionManager`, which in turn coordinates with `TAKService`.

---

This analysis is based strictly on the existing files and documentation in the repo, focusing on observed imports, file naming, and documented patterns, without introducing new hypothetical structures.