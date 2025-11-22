# Code Structure Analysis

## Architectural Overview

The repository is a large mono‑repo with several major strata:

- **Valdi platform** (TypeScript → native UI/runtime, compiler, debugger, stdlib) — generic, not OmniTAK‑specific.
- **OmniTAK Mobile application stack**:
  - Native **iOS Swift app** (primary tactical client) at `apps/omnitak/OmniTAKMobile`.
  - Valdi‑driven mobile modules and platform shells:
    - `modules/omnitak_mobile` (Valdi UI module for OmniTAK),
    - `apps/omnitak_android` (Android host app),
    - `apps/omnitak_mobile_ios` (iOS host app).
- **Rust crates** under `crates/` providing TAK core logic and FFI bridges.
- **Plugin system** for OmniTAK iOS under `modules/omnitak_plugin_system`.

The **OmniTAK iOS client** (`apps/omnitak/OmniTAKMobile`) is architected as:

- **MVVM with Combine**:
  - **Views** (SwiftUI) bind to `ObservableObject` managers with `@ObservedObject` / `@EnvironmentObject`.
  - **Managers** act as ViewModels / controllers for each functional domain.
  - **Services** encapsulate business logic, network IO, and external integrations.
  - **Models** are pure data structures (`Codable`, `Identifiable`).
- **Subsystem‑oriented package layout**:
  - `CoT/`, `Map/`, `Meshtastic/`, `Managers/`, `Services/`, `Storage/`, `Utilities/`, `UI/`, `Views/`, `Models/`.

High‑level layering for the OmniTAK iOS app:

- **Presentation layer**
  - App entry (`Core/`), SwiftUI screens (`Views/`).
  - Reusable UI components (`UI/Components`, `UI/RadialMenu`, `UI/MilStd2525`).
  - UIKit map controllers and overlays (`Map/Controllers`, `Map/Markers`, `Map/Overlays`).
- **ViewModel / state layer**
  - Feature managers (`Managers/`) and storage managers (`Storage/`).
- **Domain/service layer**
  - Feature services implementing business rules and TAK integrations (`Services/`).
  - CoT handling, Meshtastic parsing (`CoT/`, `Meshtastic/`).
- **Infrastructure / integration layer**
  - Persistence utilities (`Storage/`).
  - Network & federation utilities (`Utilities/Network`).
  - Coordinate converters, KML/KMZ parsers, calculators (`Utilities/*`).
  - Rust core integration via xcframework (`OmniTAKMobile.xcframework`, `crates/`).
  - Valdi‑based UI modules in `modules/omnitak_mobile`.

The **Valdi/Valdi‑core tree** (`src/valdi_modules`, `valdi`, `valdi_core`, `compiler/`) is a generic technology stack and not specific to OmniTAK. It provides:

- A TypeScript runtime and UI framework, compiler, debugging infra.
- Native embeddings for Android/iOS/macOS.
- Standard modules (http, filesystem, drawing, persistence, navigation, protobuf, RxJS, worker services).

## Core Components

### OmniTAKMobile iOS App Core

**Location**: `apps/omnitak/OmniTAKMobile/Core/`

- `OmniTAKMobileApp.swift`
  - SwiftUI `@main` entry point.
  - Creates and injects global `ObservableObject` instances (e.g., `TAKService`, `ServerManager`, `ChatManager`, `PositionBroadcastService`) into the environment.
- `ContentView.swift`
  - Root UI container: sets up navigation (map, drawer, tools views).
  - Composes feature screens like `EnhancedMapView`, `ChatView`, `TAKServersView`, etc.
- `OmniTAKMobile-Bridging-Header.h`
  - Objective‑C/C headers exposure to Swift.
  - Bridges to Valdi and Rust xcframework (`omnitak_mobile.h`) where required.

**Why it matters**: This defines the boundary with the OS (entry point) and acts as the top‑level composition root for dependency wiring.

---

### Domain Models

**Location**: `apps/omnitak/OmniTAKMobile/Models/`

Representative files:

- Tactical / reporting:
  - `CASRequestModels.swift`, `MEDEVACModels.swift`, `SPOTREPModels.swift`, `SALUTEReportView.swift` (view), `EchelonModels.swift`, `TeamModels.swift`, `MissionPackageModels.swift`.
- Map / geometry:
  - `RouteModels.swift`, `WaypointModels.swift`, `TrackModels.swift`, `OfflineMapModels.swift`, `ElevationProfileModels.swift`, `LineOfSightModels.swift`, `MeasurementModels.swift`, `PointMarkerModels.swift`.
- Communication:
  - `ChatModels.swift`, `VideoStreamModels.swift`.
- ArcGIS and external:
  - `ArcGISModels.swift`.
- Misc:
  - `GeofenceModels.swift`, `DrawingModels.swift`, `RadialMenuModels.swift`, `MeshtasticModels.swift`, `VideoStreamModels.swift`.

**Responsibilities**:

- Define **typed representations** for all domain objects (tracks, waypoints, routes, mission packages, teams, chat messages, CoT filters, video streams).
- Serve as the **contract** between services, managers, and views.
- Typically:
  - `Codable` for storage / network interchange.
  - `Identifiable` for SwiftUI lists.
  - No business logic; may hold computed read‑only properties.

**Role structurally**: Shared foundation (“Model” in MVVM), used uniformly across subsystems (map, chat, PLI, mission management).

---

### Views (SwiftUI Screens)

**Location**: `apps/omnitak/OmniTAKMobile/Views/`

Representative view files:

- Core / navigation:
  - `ATAKToolsView.swift`, `NavigationDrawer.swift`, `FirstTimeOnboarding.swift`, `SettingsView.swift`, `PluginsListView.swift`.
- Networking & configuration:
  - `TAKServersView.swift`, `ServerPickerView.swift`, `NetworkPreferencesView.swift`, `QuickConnectView.swift`.
  - Certificate flows: `CertificateEnrollmentView.swift`, `CertificateManagementView.swift`, `CertificateSelectionView.swift`.
- Map and overlays:
  - `Map3DSettingsView.swift`, `ScaleBarView.swift`, `CoordinateDisplayView.swift`, `MGRSGridToggleView.swift`, `CompassOverlayView.swift`, `RangeRingConfigView.swift`.
- Tactical & tools:
  - `BloodhoundView.swift`, `LineOfSightView.swift`, `ElevationProfileView.swift`, `MeasurementToolView.swift`, `RoutePlanningView.swift`, `TrackRecordingView.swift`, `GeofenceManagementView.swift`.
  - Reporting: `CASRequestView.swift`, `MEDEVACRequestView.swift`, `SPOTREPView.swift`, `SALUTEReportView.swift`.
- Chat & collaboration:
  - `ChatView.swift`, `ConversationView.swift`, `ContactListView.swift`, `ContactDetailView.swift`, `CoTUnitListView.swift`.
- Packages & data:
  - `DataPackageView.swift`, `DataPackageImportView.swift`, `MissionPackageSyncView.swift`, `KMLImportView.swift`, `OfflineMapsView.swift`.
- Meshtastic:
  - `MeshtasticConnectionView.swift`, `MeshtasticDevicePickerView.swift`, `MeshTopologyView.swift`, `SignalHistoryView.swift`.
- Media:
  - `PhotoPickerView.swift`, `VideoFeedListView.swift`, `VideoPlayerView.swift`, `VideoStreamView` (map overlay + player integration).

**Responsibilities**:

- Declare **UI structure** and bind to managers/services:
  - Use `@ObservedObject` / `@EnvironmentObject` for reactive updates.
- Translate user gestures/actions into method calls on managers/services.
- Avoid business logic; follow patterns enforced by `Architecture.md`.

**Structural role**: Presentation layer. Every major feature has at least one primary SwiftUI view plus supporting views.

---

### Managers (ViewModels / Feature Controllers)

**Location**: `apps/omnitak/OmniTAKMobile/Managers/`

Key managers:

- **Networking & connectivity**
  - `ServerManager.swift` — manages list of TAK servers, connection selection, and server metadata.
  - `CertificateManager.swift` — manages certificates in keychain, mapping to servers and user profiles.
  - `MeshtasticManager.swift` — manages Meshtastic device state and connection parameters.
- **Communication & filtering**
  - `ChatManager.swift` — message lists, conversations, unread counts; orchestrates `ChatService` + storage.
  - `CoTFilterManager.swift` — coordinates `CoTFilterModel` criteria and applies them to incoming CoT events.
- **Spatial / map‑centric**
  - `WaypointManager.swift` — manages waypoints, favorites, grouping.
  - `GeofenceManager.swift` — manages geofence definitions and their lifecycle.
  - `MeasurementManager.swift` — current measurement session, type, and UI‑friendly metrics.
  - `DrawingToolsManager.swift` — state for drawing overlays (shapes, lines) and editing.
  - `OfflineMapManager.swift` — offline maps list, downloads, updates, area selections.
- **Packages & data**
  - `DataPackageManager.swift` — handles data mission packages life cycle (import/export, selection).
- **Other**
  - `MeshtasticManager.swift` — device discovery and link to `MeshtasticProtobufParser`.

**Responsibilities**:

- **Stateful ViewModels**:
  - `ObservableObject`s with `@Published` properties (documented explicitly for some).
- **Coordinator role**:
  - Call service methods in response to view events.
  - Sync service outputs and storage (e.g., loaded mission packages → UI).
- **Abstraction boundary**:
  - Hide underlying services/FFI from views; present simpler state and commands.

**Structural importance**: They form the intermediate MVVM layer and are the main unit of testable application logic aside from services.

---

### Services (Business Logic & Integrations)

**Location**: `apps/omnitak/OmniTAKMobile/Services/`  
**Detailed documentation**: `apps/omnitak/docs/API/Services.md`

Service files and high‑level domains:

- **Core TAK networking**
  - `TAKService.swift` — main CoT networking engine.
  - `CertificateEnrollmentService.swift` — certificate request and enrollment.
- **Location & tracking**
  - `PositionBroadcastService.swift` — PLI / presence broadcasts.
  - `TrackRecordingService.swift` — track logging and metrics.
  - `BreadcrumbTrailService.swift` — breadcrumb trail management.
- **Map analytics & tools**
  - `MeasurementService.swift` — measurement sessions and overlays.
  - `RangeBearingService.swift` — range/bearing lines.
  - `LineOfSightService.swift` — line‑of‑sight/visibility.
  - `ElevationProfileService.swift` — elevation profiles (uses `ElevationAPIClient.swift`).
  - `TerrainVisualizationService.swift` — terrain visualizations.
  - `NavigationService.swift`, `TurnByTurnNavigationService.swift` — navigation features.
- **Tactical workflows**
  - `EmergencyBeaconService.swift` — emergency beacons/911 type CoTs.
  - `BloodhoundService.swift` — search/tracking features.
  - `EchelonService.swift` — organizational structure support.
  - `RoutePlanningService.swift` — advanced route operations.
  - `TeamService.swift` — teams membership and messaging.
- **Communication & media**
  - `ChatService.swift` — chat queue, CoT creation, send/retry.
  - `DigitalPointerService.swift` — digital laser pointer.
  - `PhotoAttachmentService.swift` — compress & send photos, file storage.
  - `VideoStreamService.swift` — video feed list and playback session management.
- **Data & external integration**
  - `MissionPackageSyncService.swift` — mission/data packages sync.
  - `ArcGISFeatureService.swift`, `ArcGISPortalService.swift` — ArcGIS endpoints, portal sessions.
  - `ElevationAPIClient.swift` — HTTP client for elevation.
- **Misc**
  - `NavigationService.swift` — generic navigation context support on map.
  - `PointDropperService.swift` — quick marker placing.
  - `BreadcrumbTrailService.swift` — breadcrumbs.

**Common service traits (per docs)**:

- Often `ObservableObject` singletons (`static let shared`), especially where shared cross‑feature state is needed (chat, tracking, PLI).
- Use `@Published` for key metrics and states consumed by managers and some views.
- Provide clear, action‑oriented methods (`connect`, `sendTextMessage`, `startBroadcasting`, `startRecording`, `generateProfile`, etc.).

Structurally, services form the **domain logic layer** and encapsulate:

- TAK/CoT protocol handling (in cooperation with CoT subsystem and Rust FFI).
- Business rules specific to each tactical or UI feature.
- Network IO, background work, and interactions with storage.

---

### Map Subsystem

**Location**: `apps/omnitak/OmniTAKMobile/Map/`

Subdirectories:

- `Controllers/`
- `Markers/`
- `Overlays/`
- `TileSources/`

**Controllers (Map orchestration)**:

- `EnhancedMapViewController.swift`
- `MapViewController.swift` & variants (`_Enhanced`, `_FilterIntegration`, `_Modified`)
- `Map3DViewController.swift` (+ backup versions)
- `MapOverlayCoordinator.swift`
- `MapStateManager.swift`
- `IntegratedMapView.swift`
- `MapContextMenus.swift`
- `MapCursorMode.swift`
- SwiftUI bridge: `EnhancedMapViewRepresentable.swift`, `MapViewIntegrationExample.swift`

**Responsibilities**:

- Bridge **SwiftUI presentation** (`EnhancedMapViewRepresentable`) and **UIKit map rendering**.
- Manage:
  - Visible overlays (MGRS grid, breadcrumb trails, measurement geometry, video overlays, range rings).
  - User interactions (panning, selecting units/markers, long‑press radial menu).
  - 2D/3D and MapKit vs MapLibre vs ArcGIS integration.
- Use `MapOverlayCoordinator` and `RadialMenuMapCoordinator` to assemble and update overlays and menus based on underlying state (`Managers/Services` + `CoTEventHandler`).

**Markers**:

- `CustomMarkerAnnotation.swift`
- `EnhancedCoTMarker.swift`
- `MarkerAnnotationView.swift`

Responsible for:

- **Visual representation** of CoT entities or user‑created markers on the map.
- Linking back to models (`PointMarkerModels`, team/unit types) and MilStd2525 symbol data.

**Overlays**:

- Range/measurement: `MeasurementOverlay.swift`, `RangeBearingOverlay.swift`.
- Movement: `BreadcrumbTrailOverlay.swift`, `UnitTrailOverlay.swift`, `TrackOverlayRenderer.swift`.
- Reference: `MGRSGridOverlay.swift`, `CompassOverlay.swift`, `ScaleBarView.swift` (view).
- Media: `VideoMapOverlay.swift`.
- Tactics/UI: `RadialMenuMapOverlay.swift`.
- Maps: `OfflineTileOverlay.swift`.

**Tile Sources / map providers**:

- `ArcGISTileSource.swift` — ArcGIS vector/rasters.
- `OfflineTileCache.swift`, `TileDownloader.swift` — offline storage and fetching.

**Structural role**: Encapsulates **map presentation & interactions** as a dedicated subsystem that consumes state from domain services and managers, and produces user gestures back to them.

---

### CoT (Cursor on Target) Subsystem

**Location**: `apps/omnitak/OmniTAKMobile/CoT/`

Core:

- `CoTEventHandler.swift`
- `CoTFilterCriteria.swift`
- `CoTMessageParser.swift`

Generators:

- `ChatCoTGenerator.swift`
- `MarkerCoTGenerator.swift`
- `GeofenceCoTGenerator.swift`
- `TeamCoTGenerator.swift`

Parsers:

- `ChatXMLGenerator.swift`
- `ChatXMLParser.swift`

**Responsibilities**:

- **Parsing**: `CoTMessageParser` consumes XML from `TAKService` (via `DirectTCPSender`/Rust FFI) and translates into strongly‑typed CoT events for the app.
- **Routing**: `CoTEventHandler` distributes parsed events to managers/services (e.g., chat, tracks, emergency beacons) using Combine publishers and, where needed, `NotificationCenter`.
- **Filtering**: `CoTFilterCriteria` and `CoTFilterManager` shape which events propagate to map, chat, etc.
- **Generation**: Generators build appropriate CoT XML payloads for outbound actions (chat, markers, geofences, team updates), coordinating with domain services.

**Structural importance**: This is the **protocol adapter boundary** between generic TAK servers and the internal domain/model world.

---

### Storage & Persistence Subsystem

**Location**: `apps/omnitak/OmniTAKMobile/Storage/`

Files:

- `ChatPersistence.swift`, `ChatStorageManager.swift`
- `DrawingPersistence.swift`
- `RouteStorageManager.swift`
- `TeamStorageManager.swift`

**Responsibilities**:

- Encapsulate **how** and **where** data is persisted:
  - User chat histories and attachments.
  - Drawings and overlays.
  - Saved routes and tracks.
  - Team membership and preferences.
- Provide repository‑style APIs for managers/services:
  - e.g., `loadConversations()`, `save(message:)`, `loadRoutes()`, `persist(teamConfig:)`.
- Abstract away specific mechanisms (UserDefaults, file system, potential DB) from domain logic.

**Architectural role**: Infrastructure layer behind the Services/Managers; boundaries here allow swapping/augmenting persistence without touching feature code.

---

### Utilities

**Location**: `apps/omnitak/OmniTAKMobile/Utilities/`

Subfolders and purposes:

- `Calculators/`
  - `MeasurementCalculator.swift` — numeric algorithms for distances, areas, etc.
- `Converters/`
  - `MGRSConverter.swift`, `BNGConverter.swift` — coordinate system conversions.
- `Integration/`
  - `KMLMapIntegration.swift`, `KMLOverlayManager.swift` — integrate KML overlays with the map subsystem.
- `Network/`
  - `MultiServerFederation.swift` — multi‑server federation logic.
  - `NetworkMonitor.swift` — reachability/network status monitoring.
- `Parsers/`
  - `KMLParser.swift`, `KMZHandler.swift` — parse and unpack KML/KMZ files.

**Role**:

- Provide reusable, stateless or narrowly stateful helpers used across services/managers.
- Concentrate specialized logic (geo math, file formats, network environment) outside feature code.

---

### UI Components / Shared UI

**Location**: `apps/omnitak/OmniTAKMobile/UI/`

- `Components/`
  - Toolbars and buttons:
    - `ATAKBottomToolbar_Modified.swift`
    - `QuickActionToolbar.swift`
    - `MeasurementButton.swift`
    - `TrackRecordingButton.swift`
    - `VideoStreamButton.swift`
    - `DataPackageButton.swift`
  - Status displays:
    - `ConnectionStatusWidget.swift`
  - Core UI shared definitions:
    - `SharedUIComponents.swift`
- `RadialMenu/`
  - `RadialMenuView.swift` (in `Views/`)
  - `RadialMenuActionExecutor.swift`
  - `RadialMenuAnimations.swift`
  - `RadialMenuButton.swift`
  - `RadialMenuGestureHandler.swift`
  - `RadialMenuItemView.swift`
  - `RadialMenuMapCoordinator.swift`
  - `RadialMenuPresets.swift`
- `MilStd2525/`
  - `MilStd2525Symbols.swift` — mapping of symbol codes → visual render info.

**Responsibilities**:

- Encapsulate commonly used UI patterns and widgets.
- Provide the radial menu framework that other features plug into for contextual map actions.
- Provide consistent, isolated implementations for specialized UIs (e.g., MilStd2525 symbol rendering).

**Structural role**: Reusable presentation components that depend on managers/services but are shared across many views.

---

### Meshtastic Integration

**Location**: `apps/omnitak/OmniTAKMobile/Meshtastic/`

- `MeshtasticProtoMessages.swift`
- `MeshtasticProtobufParser.swift`

**Responsibilities**:

- Decode Meshtastic protobuf messages from devices (likely via Rust `omnitak-meshtastic`/FFI).
- Convert those into OmniTAK models and events used by map, chat, and presence services.

**Architectural placement**: Feature‑specific integration module that interfaces with Rust FFI and feeds into domain services/managers.

---

### Rust Crates & FFI Bridge

**Location**: `crates/omnitak-*`, `apps/omnitak/OmniTAKMobile.xcframework`, `modules/omnitak_mobile/ios/native/`

Key crates:

- `omnitak-core`
- `omnitak-client`
- `omnitak-cot`
- `omnitak-meshtastic`
- `omnitak-cert`
- `omnitak-mobile`
- `omnitak-server`

**Responsibilities**:

- Implement **cross‑platform TAK logic**:
  - CoT processing.
  - Client/server networking.
  - Certificate enrollment and validation.
  - Meshtastic integration.
- `omnitak-mobile` exposes a C API via `omnitak_mobile.h` used by:
  - `OmniTAKMobile.xcframework` (iOS binary).
  - Android/iOS native bridge code in `modules/omnitak_mobile/android/native` and `ios/native`.

On iOS:

- Swift side bridging code (e.g., `OmniTAKNativeBridge.swift`, `MeshtasticBridge.swift`) uses the C interface:
  - To create connections, send/receive CoT, process certificates, etc.
  - Then propagate results to Swift services (`TAKService`, `CertificateEnrollmentService`, `MeshtasticManager`).

**Structural role**: Forms the **backend core** for TAK protocol logic, reused by iOS, Android, and plugin systems via common FFI.

---

### Plugin System (iOS)

**Location**: `modules/omnitak_plugin_system/ios/Sources/`

Files:

- `OmniTAKPlugin.swift`
- `PluginAPIs.swift`
- `PluginLoader.swift`
- `PluginManifest.swift`
- `PluginPermissions.swift`

**Responsibilities**:

- Define the **plugin contract**:
  - Manifest structure, permissions declarations, plugin lifecycle.
  - APIs available to plugins (likely subset of TAK services and UI hooks).
- Implement plugin loading and validation on iOS.

**Architectural placement**: Extension boundary; plugins integrate into OmniTAK using the defined APIs without full coupling to internal implementation.

---

### OmniTAK Valdi Module (Cross‑platform UI)

**Location**: `modules/omnitak_mobile`

- `src/valdi/omnitak/App.tsx`, `AppController.tsx`
- `components/`: high‑level dialogs (`AddServerDialog`, `CertificateEnrollmentDialog`, `NavigationDrawer`, `MapLibreView`, etc.).
- `screens/`: `EnhancedMapScreen`, `MapScreenWithMapLibre`, `ServerManagementScreen`, `FederatedServerScreen`, `SettingsScreen`, `CertificateManagementScreen`, `PluginManagementScreen`.
- `services/`:
  - `CotParser.ts`
  - `MapLibreIntegration.ts`
  - `MarkerManager.ts`
  - `MeshtasticService.ts`
  - `MultiServerFederation.ts`
  - `SymbolRenderer.ts`
  - `TakService.ts`
- Platform bridges:
  - `android/native/OmniTAKNativeBridge.kt`, `omnitak_jni.cpp`
  - `ios/native/OmniTAKNativeBridge.swift`

**Responsibilities**:

- Implement a **Valdi‑based UI flavor** of OmniTAK:
  - Reimplements similar services and UI composition as in Swift, but in TS/Valdi.
- Use Valdi’s runtime & bindings to call into the same Rust FFI as Swift.
- Provide shared codebase for Android and iOS shells.

**Architectural role**: Parallel front‑end technology for OmniTAK that shares the same domain core via FFI.

## Service Definitions

This section maps the **key services** by domain, based on `Services.md` and structure. (Only representative services — there are more in the directory.)

### Core TAK Networking

#### TAKService

- **File**: `apps/omnitak/OmniTAKMobile/Services/TAKService.swift`
- **Type**: `ObservableObject`
- **State** (per docs):
  - `@Published var isConnected`, `connectionStatus`
  - Traffic counters: `messagesSent`, `messagesReceived`, `bytesSent`, `bytesReceived`
- **Responsibilities**:
  - Manage TCP/UDP/TLS connections to TAK servers.
  - Integrate with certificates and auth (via `CertificateManager`, `CertificateEnrollmentService`, Rust FFI).
  - Send outbound CoT XML (used by Chat, PLI, beacon, etc.).
  - Receive raw CoT XML and feed into `CoTMessageParser` → `CoTEventHandler`.

#### CertificateEnrollmentService

- **File**: `CertificateEnrollmentService.swift`
- **Responsibilities**:
  - Enroll/renew certificates using `omnitak-cert` FFI and remote endpoints.
  - Coordinate with keychain storage (Keychain APIs and `CertificateManager`).
  - Provide operations behind `CertificateEnrollmentView` and `CertificateManagementView`.

---

### Location, Tracking, & PLI

#### PositionBroadcastService

- **File**: `PositionBroadcastService.swift`
- **Type**: Singleton `ObservableObject` (`static let shared`)
- **State** (per docs):
  - `isEnabled`, `updateInterval`, `staleTime`, `lastBroadcastTime`, `broadcastCount`
  - `userCallsign`, `userUID`, `teamColor`, `teamRole`, `userUnitType`
- **Responsibilities**:
  - Periodically send PLI CoT messages when enabled.
  - Represent user identity and tactical metadata used in PLI.
  - Provide immediate broadcast and frequency control.

#### TrackRecordingService

- **File**: `TrackRecordingService.swift`
- **Type**: Singleton `ObservableObject`
- **State**:
  - `isRecording`, `isPaused`
  - `currentTrack`, `savedTracks`
  - Live metrics: `liveDistance`, `liveSpeed`, `liveAverageSpeed`, `liveElevationGain`
- **Responsibilities**:
  - Start/stop/pause/resume GPS track recording.
  - Update live metrics as positions are received.
  - Export recorded tracks (e.g., GPX/KML).
  - Works with overlays (`BreadcrumbTrailOverlay`, `UnitTrailOverlay`, `TrackOverlayRenderer`).

#### EmergencyBeaconService

- **File**: `EmergencyBeaconService.swift`
- **Type**: Singleton `ObservableObject`
- **State**:
  - `isActive`, `beaconType`, `lastBeaconTime`
- **Responsibilities**:
  - Manage emergency beacon activation/deactivation.
  - Send high‑frequency emergency CoT updates while active.
  - Integrate with map overlays and emergency UI.

---

### Communication & Collaboration

#### ChatService

- **File**: `ChatService.swift`
- **Type**: Singleton `ObservableObject`
- **State**:
  - `messages`, `conversations`, `participants`
  - `unreadCount`
  - `queuedMessages`
- **Responsibilities**:
  - Compose CoT chat messages (GeoChat XML) and send through `TAKService`.
  - Retry and queue messages; manage offline/online transitions.
  - Maintain canonical list of conversations and unread counts.
  - Coordinate with `ChatPersistence` for saving/loading history.

#### PhotoAttachmentService

- **File**: `PhotoAttachmentService.swift`
- **Type**: Plain service (non‑observable).
- **Responsibilities**:
  - Compress images (`compressImage(maxSize:)`).
  - Save attachments to file system (`saveAttachment`) and return URLs.
  - Orchestrate sending attachments with chat messages.

#### DigitalPointerService

- **File**: `DigitalPointerService.swift`
- **Type**: `ObservableObject`
- **State**:
  - `isActive`, `currentPointer`, `receivedPointers`
- **Responsibilities**:
  - Manage a “laser pointer” on the map for collaborative focus.
  - Start/update/stop pointer positions and propagate to other clients via CoT.
  - Provide state for map overlays and UI.

#### TeamService

- **File**: `TeamService.swift`
- **Type**: `ObservableObject`
- **State**:
  - `teams`, `currentUserTeams`
- **Responsibilities**:
  - Create/delete teams.
  - Manage membership (invite, leave).
  - Broadcast team messages.
  - Link team definitions to PLI and chat layers.

---

### Map & Spatial Analysis

#### MeasurementService

- **File**: `MeasurementService.swift`
- **Type**: `ObservableObject`
- **State**:
  - `manager: MeasurementManager`
  - `overlays: [MKOverlay]`
  - `annotations: [MKPointAnnotation]`
- **Responsibilities**:
  - Open/close measurement sessions (distance, area).
  - Manage overlays and annotations used for visualization.
  - Use `MeasurementCalculator` for metric computation.
  - Provide an API to add points and finalize measurements.

#### RangeBearingService

- **File**: `RangeBearingService.swift`
- **Type**: `ObservableObject`
- **State**:
  - `activeLines: [RangeBearingLine]`
- **Responsibilities**:
  - Create range‑and‑bearing lines between coordinates.
  - Compute true bearing and distance between two points.
  - Synchronize with map overlays.

#### ElevationProfileService

- **File**: `ElevationProfileService.swift`
- **Type**: `ObservableObject`
- **State**:
  - `currentProfile: ElevationProfile?`
  - `isLoading: Bool`
- **Responsibilities**:
  - Generate elevation profiles for polylines.
  - Query elevation for a single point using `ElevationAPIClient`.
  - Feed `ElevationProfileView`.

#### LineOfSightService

- **File**: `LineOfSightService.swift`
- **Responsibilities**:
  - Compute line‑of‑sight between points using terrain/elevation models.
  - Provide results for `LineOfSightView` (e.g., obstructed segments).

---

### Tactical Services & Packages

#### MissionPackageSyncService

- **File**: `MissionPackageSyncService.swift`
- **Responsibilities**:
  - Synchronize mission packages with TAK servers.
  - Interact with `DataPackageManager` and `MissionPackageModels`.
  - Manage download/upload queues and progress.

#### BloodhoundService

- **File**: `BloodhoundService.swift`
- **Responsibilities**:
  - Support “Bloodhound” tracking/search workflows.
  - Likely tie search queries, map markers, and CoT updates.

#### EchelonService

- **File**: `EchelonService.swift`
- **Responsibilities**:
  - Manage hierarchical military structures (echelons).
  - Provide data to `EchelonHierarchyView` for display and selection.

---

### External Integration

#### ArcGISFeatureService & ArcGISPortalService

- **Files**: `ArcGISFeatureService.swift`, `ArcGISPortalService.swift`
- **Responsibilities**:
  - Integrate with ArcGIS for querying feature services, login/portal interactions.
  - Feed `ArcGISPortalView` and map tile/feature overlays.

#### ElevationAPIClient

- **File**: `ElevationAPIClient.swift` (there is a copy in `apps/omnitak/OmniTAKMobile/` and a service file).
- **Responsibilities**:
  - HTTP client for elevation data.
  - Used by `ElevationProfileService` and possibly LOS/Terrain.

## Interface Contracts

The codebase uses several **interface/abstraction mechanisms**:

### Swift Protocols (Protocol‑Oriented Design)

From `Architecture.md` and patterns in the app:

- Protocols define behaviors for generators, services, and helper abstractions, e.g.:

  ```swift
  protocol CoTMessageGenerator {
      func generateCoTMessage() -> String
  }
  ```

- Likely usage patterns:
  - Multiple CoT generators conform (Chat, Marker, Geofence, Team) and can be used polymorphically.
  - Service interfaces for things like certificate enrollment, measurement calculators, etc., to decouple implementations from managers.

### ObservableObject & Combine

- `ObservableObject` + `@Published` act as **interface contracts between stateful components and views**.
  - Views only depend on `ObservableObject` semantics, not concrete implementations.
  - Managers and services sometimes expose configuration methods:

    ```swift
    func configure(takService: TAKService, chatManager: ChatManager)
    ```

  which declares their required dependencies explicitly.

### FFI Interfaces (C header)

- `omnitak_mobile.h` in multiple locations:
  - `crates/omnitak-mobile/include/omnitak_mobile.h`
  - Copied into iOS and Android native module directories.
- Defines the C interface used from Swift and Kotlin/NDK.

These FFI functions provide a **stable boundary** around Rust logic; Swift/TS/Java code treats them as external APIs.

### Plugin Interfaces

- `PluginAPIs.swift`, `PluginManifest.swift`, `PluginPermissions.swift` define:
  - Data structures and APIs available to plugins.
  - Required manifest fields and supported permission types.

This constitutes a contract for third‑party extensions.

### Valdi Core Interfaces

In the broader monorepo, Valdi defines many interfaces (`IHTTPClient`, `IModuleLoader`, `INavigator`, `IWorkerService`, etc.) to separate:

- Runtime engine from platform‑specific bindings.
- TypeScript application code from native code.

These are generic, but relevant for the `modules/omnitak_mobile` Valdi module.

## Design Patterns Identified

### 1. MVVM (Model–View–ViewModel)

Explicitly documented in `Architecture.md` and used throughout OmniTAK iOS:

- **Model**: `Models/` data types.
- **View**: SwiftUI `Views/` and UI components.
- **ViewModel**: `Managers/` (often suffixed `Manager` but functioning as ViewModels).
- **Service**: Domain/business logic behind ViewModels.

**Why**: Clean separation of concerns, testability, and reactive updates via Combine.

### 2. Singleton Services

Many services are implemented as singletons:

- `ChatService.shared`, `PositionBroadcastService.shared`, `TrackRecordingService.shared`, `EmergencyBeaconService.shared`, etc.

**Why**: Shared, global state for things like chat, tracks, network connectivity is simpler to manage across multiple views and managers.

### 3. Reactive Programming with Combine

- `@Published` properties on services and managers form a **reactive state graph**.
- Views subscribe via property wrappers; services/managers subscribe to each other’s publishers as needed.

### 4. Protocol Abstraction

- Protocols used to represent abstract behaviors (e.g., CoT generators).
- Encourages mocking in tests and swap of implementations.

### 5. Delegation & NotificationCenter

- Delegate pattern for one‑to‑one callbacks (e.g., `CoTMessageDelegate` for a TCP sender).
- `NotificationCenter` for cross‑cutting events that shouldn’t introduce strong compile‑time dependencies.

### 6. Subsystem Modularity

Stubbed into coherent directories (`Map`, `CoT`, `Meshtastic`, `Storage`, `Utilities`):

- Each subsystem encapsulates a domain and its internal patterns.
- Dependencies from outside subsystems are routed via services/managers, not direct coupling.

### 7. FFI Boundary / Hexagonal Tendencies

- Rust crates form a “core domain” accessible via FFI.
- Swift/Valdi frontends are adapters around this core:
  - CoT parser/generator in Swift wrap and extend core logic.
  - Certificates, Meshtastic, and client communications cross the boundary.

This resembles **ports and adapters** (hexagonal style) at the Rust vs. mobile‑frontend boundary.

### 8. Plugin/Extension Pattern

- `omnitak_plugin_system` and plugin template support dynamic loading of additional functionality while exposing only constrained APIs.

## Component Relationships

From `Architecture.md` and observed structure:

### High‑Level OmniTAK Dependencies

- `OmniTAKMobileApp` → `ContentView` → feature `Views`
- `Views` (SwiftUI screens) depend on:
  - `Managers` (ViewModels) and sometimes `Services`.
- `Managers` depend on:
  - `Services` (business logic).
  - `Storage` (repositories).
  - Utility classes/functions.
- `Services` depend on:
  - Rust FFI (via `OmniTAKMobile.xcframework` and C headers).
  - `CoTMessageParser` / `CoTEventHandler` for TAK data.
  - `Utilities` for conversions/calculations.
  - System frameworks (CoreLocation, MapKit, URLSession, etc.).

### Example Dependency Graph (from docs)

```
OmniTAKMobileApp
  └── ContentView
      └── ATAKMapView / EnhancedMapView
          ├── TAKService
          │   ├── DirectTCPSender (Rust/FFI)
          │   ├── CoTMessageParser
          │   └── CoTEventHandler
          │       ├── ChatManager
          │       ├── TrackRecordingService
          │       └── EmergencyBeaconService
          ├── ChatManager
          │   ├── ChatService
          │   ├── ChatPersistence
          │   └── PhotoAttachmentService
          ├── ServerManager
          │   └── CertificateManager
          ├── DrawingToolsManager
          │   └── DrawingPersistence
          ├── OfflineMapManager
          ├── PositionBroadcastService
          ├── LocationManager (CoreLocation)
          └── EnhancedMapViewController
              ├── MapOverlayCoordinator
              └── RadialMenuMapCoordinator
```

### Cross‑Cutting Relationships

- **CoTEventHandler**:
  - Central router of CoT events from `TAKService` to:
    - Chat, track, emergency, team, geofence, etc.
- **NetworkMonitor** / `MultiServerFederation`:
  - Used by `ServerManager`, `TAKService`, possibly plugin APIs.
- **Storage managers**:
  - Called by both managers and services (e.g., track service writing to route storage, chat service writing to chat storage).

## Key Methods & Functions

This section highlights **structurally important methods** (from `Services.md` and architecture docs), not every method.

### TAKService (Network Core)

- `connect(host:port:protocolType:...)`
  - Establish connection to TAKServer with TLS or other transport.
- `disconnect()`
  - Close connection and update state.
- `send(cotMessage:priority:)`
  - Core call to send outbound CoT XML.
- `reconnect()`
  - Recovery logic for connection loss.

### ChatService (Messaging Core)

- `configure(takService:locationManager:)`
  - Inject dependencies.
- `sendTextMessage(_:to:)`
  - Main entry for user text messages.
- `sendLocationMessage(location:to:)`
  - Share location via CoT chat.
- `processQueue()`
  - Retry unsent messages.
- `markAsRead(_:)`
  - Update unread badge counts.

### PositionBroadcastService (PLI)

- `configure(takService:locationManager:)`
- `startBroadcasting()`
- `stopBroadcasting()`
- `broadcastPositionNow()`
- `setUpdateInterval(_:)`

These define **how PLI is scheduled and sent** and form an important part of tactical awareness.

### TrackRecordingService (Tracks)

- `startRecording(name:)`
- `pauseRecording()`
- `resumeRecording()`
- `stopRecording() -> Track?`
- `exportTrack(_:format:) -> URL?`

These methods define the track lifecycle and outputs (exports).

### EmergencyBeaconService

- `activateBeacon(type:)`
- `cancelBeacon()`
- `sendBeaconUpdate()`

These encapsulate emergency workflows.

### MeasurementService

- `startMeasurement(type:)`
- `addPoint(_:)`
- `completeMeasurement() -> Measurement?`
- `addRangeRing(center:radius:)`

These drive map overlay creation and analytics.

### RangeBearingService

- `createLine(from:to:) -> RangeBearingLine`
- `calculateBearing(from:to:) -> Double`
- `calculateDistance(from:to:) -> Double`

Provide reusable mapping utilities used in measurement and tactical tools.

### ElevationProfileService

- `generateProfile(for:)` (async)
- `fetchElevation(at:) -> Double?`

These functions encapsulate path → profile transformation.

### DigitalPointerService

- `startPointing(at:)`
- `updatePointer(to:)`
- `stopPointing()`

Define the digital pointer interaction lifecycle.

### TeamService

- `createTeam(name:color:) -> Team`
- `inviteToTeam(_:uid:)`
- `leaveTeam(_:)`
- `broadcastTeamMessage(_:)`

Core operations for team management and communications.

Across the system, similar high‑level “verb‑style” methods exist for other services (Bloodhound, Echelon, MissionPackageSync, ArcGIS services), but the ones above are particularly central to tactical capabilities.

## Available Documentation

### OmniTAK‑Specific Docs

**Location**: `apps/omnitak/docs/`

Key files:

- `Architecture.md`
  - Detailed architectural description for OmniTAKMobile iOS:
    - MVVM explanation.
    - Component diagrams.
    - Network/map/storage subsystem breakdown.
    - Threading and data flow notes.
  - **Quality**: High. Contains consistent diagrams and concrete examples. Directly informs this analysis.
- `docs/API/Managers.md`, `docs/API/Models.md`, `docs/API/Services.md`
  - API‑style docs for managers, models, and services.
  - `Services.md` provides signatures, key methods, descriptions, example usage.
  - **Quality**: High; good for newcomers to get a structural understanding.
- `docs/Features/`
  - `ChatSystem.md`, `CoTMessaging.md`, `MapSystem.md`, `Networking.md`
  - Explain features and how they map to components (services, managers, views).
  - **Quality**: Good; feature‑oriented, help connect UI vs. technical architecture.
- `docs/DeveloperGuide/`
  - `CodebaseNavigation.md`, `CodingPatterns.md`, `GettingStarted.md`
  - Explain repo structure, coding conventions, MVVM practices.
  - **Quality**: High; very relevant for new contributors.
- `docs/UserGuide/`
  - User‑facing help, complements developer docs but less about structure.

### Global Repository Docs

**Location**: `/docs/` (top‑level)

- `DEV_SETUP.md`, `INSTALL.md`, `LOCAL_DEVELOPMENT_SETUP.md`
- `MESHTASTIC_INTEGRATION.md`, `MESHTASTIC_UI_UX_GUIDE.md`
- `PLUGIN_ARCHITECTURE.md`, `PLUGIN_DEVELOPMENT_GUIDE.md`, `PLUGIN_CI_CD_SETUP.md`
- `TROUBLESHOOTING.md`

**Quality**:

- Good for understanding how to run/build and the plugin architecture.
- Less focused on internal code organization of the iOS app.

### AI‑Oriented Internal Analyses

**Location**: `.ai/docs/`

- `structure_analysis.md`
  - Prior structural analysis (similar to this) of the repo.
  - **Quality**: High-level but accurate; covers multiple subsystems.
- `api_analysis.md`, `data_flow_analysis.md`, `request_flow_analysis.md`
  - Deeper dives into APIs and flows; useful for automated tooling and agents.

### Other Relevant Docs

- `modules/omnitak_mobile/ARCHITECTURE_DIAGRAM.md`
  - Architecture of the Valdi‑based OmniTAK module (TS side).
  - **Quality**: Good for cross‑platform and Valdi devs.
- `apps/omnitak/OmniTAKMobile/Resources/Documentation/`
  - Feature‑focused guides:
    - `CHAT_FEATURE_README.md`, `FILTER_INTEGRATION_GUIDE.md`, `KML_INTEGRATION_GUIDE.md`,
      `MESHTASTIC_PROTOBUF_README.md`, `OFFLINE_MAPS_INTEGRATION.md`,
      `RADIAL_MENU_INTEGRATION_GUIDE.md`, `WAYPOINT_INTEGRATION_GUIDE.md`,
      `UI_LAYOUT_REFERENCE.md`, `USAGE_EXAMPLES.swift`, `SHARED_INTERFACES.swift`.
  - **Quality**: Very practical; map code-level elements to concrete feature implementations.

Overall, the **documentation coverage** for OmniTAKMobile is **strong**:

- Architectural description, subsystem breakdown, and API references are all present.
- Feature guides and example code help connect theory to actual implementation.
- AI‑oriented `.ai/docs` provide additional structured metadata useful for automation.
