# Code Structure Analysis

## Architectural Overview

The OmniTAK Mobile app under `OmniTAKMobile/` is organized as a modular SwiftUI iOS application implementing a **MVVM-style architecture**:

- **Views (`Views/`, `UI/`)** – SwiftUI views for screens and reusable components.
- **ViewModels / Managers (`Managers/`)** – `ObservableObject` classes holding feature state, exposing `@Published` properties for Combine-based reactive updates.
- **Services (`Services/`)** – Business logic, TAK networking, geospatial and tactical functions, background operations, and external integrations.
- **Models (`Models/`)** – Data structures (`struct`s, enums) representing domain concepts (CoT events, chats, routes, reports, etc.).
- **Storage (`Storage/`)** – Persistence utilities for chat, drawings, routes, teams, etc.
- **Map subsystem (`Map/`)** – Controllers, overlays, markers, and tile sources for the tactical map.
- **Utilities (`Utilities/`)** – Shared calculators, converters, network helpers, and integration utilities (KML, multi-server).
- **CoT subsystem (`CoT/`)** – CoT event handling, filtering, parsing, and generation for chat, markers, teams, and geofences.
- **Meshtastic (`Meshtastic/`)** – Protobuf parsing and models for Meshtastic integration.
- **Core app (`Core/`)** – App entry point, root composition, and bridging header for the Rust/xcframework integration.

Across the codebase:

- **MVVM** is the primary pattern: `Views` bind to `Managers` (view models) which orchestrate `Services`.
- **Reactive programming** via **Combine**: `@Published` on managers/services, `@ObservedObject` / `@EnvironmentObject` in views, and subscription chains between services.
- **Protocol-oriented design**: Protocols define capabilities (e.g., CoT generators) to keep components loosely coupled.
- **Subsystem layering**: Networking (TAKService, CoT parser/handler), Map (controllers + overlays), Storage (UserDefaults, Keychain, file system) are clearly separated and described in `docs/Architecture.md`.

## Core Components

### High-Level Modules / Directories

- `OmniTAKMobile/Core/`
  - `OmniTAKMobileApp.swift` – SwiftUI `@main` entry point, sets up root views and injects shared managers/services.
  - `ContentView.swift` – Top-level container for main navigation and embedding the map / tools.
  - `OmniTAKMobile-Bridging-Header.h` – Objective‑C bridging, likely for interacting with `OmniTAKMobile.xcframework` (Rust/C networking core).

- `OmniTAKMobile/Views/`
  - Screen-level SwiftUI views for most user-facing features:
    - Connectivity & configuration: `TAKServersView`, `ServerPickerView`, `CertificateEnrollmentView`, `NetworkPreferencesView`, `SettingsView`, `QuickConnectView`.
    - Map tools & overlays: `Map3DSettingsView`, `CompassOverlayView`, `MGRSGridToggleView`, `MeasurementToolView`, `DrawingToolsPanel`, `DrawingPropertiesView`, `RadialMenuView`, `RangeRingConfigView`, `RegionSelectionView`, `ScaleBarView`.
    - Tactical features: `BloodhoundView`, `DigitalPointerView`, `PositionBroadcastView`, `TrackRecordingView`, `TrackListView`, `NavigationDrawer`, `TurnByTurnNavigationView`, `LineOfSightView`, `ElevationProfileView`.
    - Reports & mission tools: `CASRequestView`, `MEDEVACRequestView`, `SPOTREPView`, `SALUTEReportView`, `MissionPackageSyncView`, `DataPackageView`, `KMLImportView`.
    - Collaboration: `ChatView`, `ConversationView`, `ContactListView`, `ContactDetailView`, `TeamManagementView`, `CoTUnitListView`, `SignalHistoryView`.
    - Misc & onboarding: `FirstTimeOnboarding`, `AboutView`, `PluginsListView`, `OfflineMapsView`, `WaypointListView`, `RoutePlanningView`, `VideoFeedListView`, `VideoPlayerView`, `PhotoPickerView`.

- `OmniTAKMobile/UI/`
  - `Components/` – Shared UI pieces:
    - Toolbars & quick actions: `ATAKBottomToolbar_Modified.swift`, `QuickActionToolbar.swift`, `DataPackageButton.swift`, `MeasurementButton.swift`, `TrackRecordingButton.swift`, `VideoStreamButton.swift`.
    - Status & connection: `ConnectionStatusWidget.swift`, `SharedUIComponents.swift`.
  - `RadialMenu/` – Radial context menu UX around map:
    - `RadialMenuView` (view), `RadialMenuButton`, `RadialMenuItemView`.
    - Behavior & coordination: `RadialMenuActionExecutor`, `RadialMenuGestureHandler`, `RadialMenuMapCoordinator`, `RadialMenuPresets`, `RadialMenuAnimations`.
  - `MilStd2525/` – Symbology:
    - `MilStd2525Symbols.swift`, `MilStd2525MarkerView`, `MilStd2525SymbolView` manage military standard 2525 symbol rendering and selection.

- `OmniTAKMobile/Managers/` (ViewModels)
  - Central state/control for each feature (see next sections for details).

- `OmniTAKMobile/Services/`
  - Domain-specific services for TAK networking, geospatial calculations, mission tools, etc. (detailed in Service Definitions).

- `OmniTAKMobile/Models/`
  - Typed data representations for:
    - CoT, Chat, Teams, Tracks, Routes, Waypoints.
    - CAS/MEDEVAC/SPOTREP etc. tactical reports.
    - Offline maps, missions, measurement, video streams, Meshtastic, etc.

- `OmniTAKMobile/Map/`
  - `Controllers/`
    - `EnhancedMapViewController`, `MapViewController`, `Map3DViewController`, `IntegratedMapView` – UIKit/MapKit (and possibly 3D) controllers.
    - `EnhancedMapViewRepresentable` – SwiftUI bridge (`UIViewControllerRepresentable`).
    - `MapOverlayCoordinator`, `MapStateManager`, `MapContextMenus`, `MapCursorMode` – map state, overlays, and interaction mode management.
  - `Markers/`
    - `CustomMarkerAnnotation`, `MarkerAnnotationView`, `EnhancedCoTMarker` – marker types, annotation views, and enriched CoT marker data.
  - `Overlays/`
    - `BreadcrumbTrailOverlay`, `UnitTrailOverlay`, `TrackOverlayRenderer`, `MeasurementOverlay`, `RangeBearingOverlay`, `MGRSGridOverlay`, `CompassOverlay`, `VideoMapOverlay`, `RadialMenuMapOverlay`, `OfflineTileOverlay`.
  - `TileSources/`
    - `ArcGISTileSource`, `OfflineTileCache`, `TileDownloader` – map tile sourcing and caching.

- `OmniTAKMobile/CoT/`
  - `CoTEventHandler.swift` – routes parsed CoT events to managers/services.
  - `CoTFilterCriteria.swift` – filter model for event types / affiliations.
  - `CoTMessageParser.swift` – low-level CoT XML parsing.
  - `Generators/` – CoT event generation for higher-level concepts:
    - `ChatCoTGenerator`, `GeofenceCoTGenerator`, `MarkerCoTGenerator`, `TeamCoTGenerator`.
  - `Parsers/`
    - `ChatXMLParser`, `ChatXMLGenerator` – GeoChat-specific CoT/Chat transformations.

- `OmniTAKMobile/Storage/`
  - `ChatPersistence`, `ChatStorageManager` – chat history and attachment persistence.
  - `DrawingPersistence` – saving/restoring drawing overlays.
  - `RouteStorageManager`, `TeamStorageManager` – route and team persistence.

- `OmniTAKMobile/Utilities/`
  - `Calculators/MeasurementCalculator` – geometric distance/area calculations.
  - `Converters/MGRSConverter`, `BNGConverter` – grid coordinate transformations.
  - `Integration/KMLMapIntegration`, `KMLOverlayManager` – KML/KMZ loading into the map.
  - `Parsers/KMLParser`, `KMZHandler` – raw KML/KMZ parsing.
  - `Network/MultiServerFederation`, `NetworkMonitor` – handling multiple TAK servers and network reachability/health.

- `OmniTAKMobile/Meshtastic/`
  - `MeshtasticProtoMessages`, `MeshtasticProtobufParser` – Meshtastic mesh radio protocol support.

- `OmniTAKMobile/Resources/Documentation/`
  - Feature-specific documentation and shared Swift interfaces for examples and integration references.

## Core Components

### Managers (ViewModel Layer)

Managers are the primary state holders for features, bridging Views and Services (see `docs/API/Managers.md`):

- **ServerManager**
  - Responsibility: Manage TAK server configurations and the active server.
  - Key state: `servers: [TAKServer]`, `selectedServer`, `activeServerIndex`.
  - Behaviors: Add/remove/update servers; select server; persist configuration to `UserDefaults`.

- **CertificateManager**
  - Responsibility: Manage client TLS certificates for TAK connections.
  - Key state: `certificates: [TAKCertificate]`, `selectedCertificate`.
  - Behaviors: Import/save/delete certificates, retrieve Keychain data, produce `SecIdentity` for TLS, validate expiry.

- **ChatManager**
  - Responsibility: Manage conversations, messages, and participants for chat UI.
  - Key state: `conversations`, `activeConversation`, `unreadCount`, `participants`.
  - Behaviors: Send/receive messages, handle photo messages, create conversations, mark read/delete, update participant location and presence from CoT.

- **CoTFilterManager**
  - Responsibility: Manage filter criteria for incoming CoT events.
  - Key state: `activeFilters: [CoTFilterCriteria]`, `filterEnabled`.
  - Behaviors: Add/remove/enable/disable filters, used by CoT event handling and map display.

- **DrawingToolsManager**
  - Responsibility: Manage active drawing tools, shapes, and styles on the map.
  - Coordinates with: `DrawingPersistence`, map overlays.

- **GeofenceManager**
  - Responsibility: Geofencing areas and events.
  - Likely interacts with: `GeofenceService`, `GeofenceModels`, CoT generators.

- **MeasurementManager**
  - Responsibility: Measurement tool state (distance/area, currently measured points).
  - Used by `MeasurementService` and map overlays.

- **MeshtasticManager**
  - Responsibility: Manage Meshtastic connections, devices, and topology.
  - Uses Meshtastic models and parsers.

- **OfflineMapManager**
  - Responsibility: Manage offline regions, tile downloads, and caching.
  - Interfaces: `OfflineMapModels`, `OfflineTileCache`, `TileDownloader`, `OfflineMapManager` views.

- **WaypointManager**
  - Responsibility: Manage user-defined waypoints, lists, and selection.
  - Integrates with `WaypointModels` and map overlays.

- **DataPackageManager**
  - Responsibility: Manage TAK data packages (import/export, listing, selection).
  - Backed by `DataPackageModels` and relevant storage.

Other feature-specific managers (in `Managers/`) mirror this pattern: one `ObservableObject` per feature with clear boundaries.

### Services (Business Logic Layer)

Key service groups (documented in `docs/API/Services.md` and in `OmniTAKMobile/Services/`):

- **Core Networking / TAK**
  - `TAKService` – central TAK networking coordinator (connect/disconnect, send CoT, track bytes and messages, expose connection status).
  - Integrates lower-level TCP/TLS, CoT parsing, and event routing.

- **Communication & Collaboration**
  - `ChatService` – message creation, queueing, retries, and interaction with TAKService and storage.
  - `PhotoAttachmentService` – image compression, file handling, and sending attachments.
  - `TeamService` – team lifecycle: create team, invite users, leave teams, broadcast team messages.

- **Location & Tracking**
  - `PositionBroadcastService` – PLI broadcasting with configurable intervals and user/team metadata.
  - `TrackRecordingService` – manages live track recording, pause/resume, saving, export to GPX/KML.
  - `EmergencyBeaconService` – high-frequency emergency beacon CoT messages with stateful activation.

- **Map & Geospatial**
  - `MeasurementService` – orchestrates measurement operations, overlays, and annotations; uses `MeasurementManager` and `MeasurementCalculator`.
  - `RangeBearingService` – creates range/bearing lines and calculates distances/bearings.
  - `LineOfSightService`, `TerrainVisualizationService`, `ElevationProfileService` – terrain analysis, elevation queries, profile generation (via `ElevationAPIClient`).
  - `ArcGISFeatureService`, `ArcGISPortalService` – ArcGIS feature querying and portal access.
  - `NavigationService`, `RoutePlanningService`, `TurnByTurnNavigationService` – route creation, pathfinding, and live navigation.
  - `OfflineMapService` responsibilities are partly handled by `OfflineMapManager` + tile services.

- **Tactical & Mission Services**
  - `BloodhoundService` – likely search-and-track or “bloodhound” guidance to targets.
  - `BreadcrumbTrailService` – manage breadcrumbs, separate from generic track recording.
  - `EchelonService` – handle echelon hierarchies and unit structures.
  - `GeofenceService` – evaluate locations against geofences, generate events and CoT.
  - `MissionPackageSyncService` – sync mission packages with TAK backend.
  - `SPOTREP` / CAS / MEDEVAC business logic mostly embedded in related services and managers.

- **Other Services**
  - `CertificateEnrollmentService` – certificate enrollment workflows.
  - `NavigationService` / `TurnByTurnNavigationService` – integration with routing/turn-by-turn APIs.
  - `PhotoAttachmentService`, `VideoStreamService` – media handling for imagery and live video.
  - `DigitalPointerService` – “laser pointer” style map coordination.

### Models (Data Layer)

Models are defined as Swift `struct`s, typically `Identifiable`, `Codable`, and `Equatable` (see `docs/API/Models.md`):

- **CoT Models**
  - `CoTEvent` – canonical CoT event with full time, location, error, and detail attributes.
  - `EnhancedCoTMarker` – map-oriented enrichment of CoT data with trail, status, and metrics.

- **Chat Models**
  - `ChatMessage`, `MessageStatus`, `Conversation`, `ChatParticipant`, `ImageAttachment`.

- **Map & Navigation**
  - `Waypoint`, `Route`, `PointMarker`, `Track`, `RangeBearingLine`, measurement-related entities.

- **Tactical Reports / Mission**
  - `CASRequest`, `MEDEVACRequest`, `SPOTREPReport`, SALUTE and other report types.
  - `MissionPackage` and related mission models in `MissionPackageModels.swift`.

- **Team & Identity**
  - `Team`, `TeamMember`, and related role/color definitions.
  - `TAKServer`, `TAKCertificate` models for connectivity and certificates.

- **Offline Maps, Elevation, Video, Meshtastic**
  - `OfflineRegion`, `ElevationProfile`, `VideoStream`, various Meshtastic message models, etc.

## Service Definitions

Below is a structural summary of the **most central and cross-cutting services** (based on `docs/API/Services.md` and project layout). This focuses on responsibilities and interaction boundaries rather than full API detail.

### TAKService (`Services/TAKService.swift`)

- **Role**: Authoritative TAK networking service.
- **Responsibilities**:
  - Maintain TCP/UDP/TLS connection to TAK servers.
  - Manage message send/receive counts and byte statistics.
  - Expose reactive connection state (`isConnected`, `connectionStatus`) for UI and managers.
  - Provide API to:
    - Connect/disconnect/reconnect to a configured TAK server.
    - Send CoT XML messages with priority.
- **Collaborators**:
  - `ServerManager` (which server to connect to).
  - `CertificateManager` / `CertificateEnrollmentService` (TLS credentials).
  - `CoTMessageParser` & `CoTEventHandler` (incoming CoT pipeline).
  - Feature services that send messages: `ChatService`, `PositionBroadcastService`, `DigitalPointerService`, `EmergencyBeaconService`, etc.

### CoTEvent Pipeline (`CoT/` + Services)

- **CoTMessageParser**
  - Input: Raw bytes / strings from TAKService.
  - Output: Structured CoT events.
  - Responsibility: Convert CoT XML into `CoTEvent` and related models, identify event types.

- **CoTEventHandler**
  - Input: Parsed CoT events.
  - Output: Delegated actions and notifications.
  - Responsibilities:
    - Route CoT events to correct managers: e.g., Chat, TrackRecording, EmergencyBeacon, Team, etc.
    - Apply filters from `CoTFilterManager`.
    - Publish updates via Combine and `NotificationCenter`.

- **CoT Generators (Chat/Geofence/Marker/Team)**
  - Responsibility: Encapsulate CoT XML creation logic for different features, shielding services from XML structure details.

### ChatService (`Services/ChatService.swift`)

- **Role**: Chat business logic and message lifecycle.
- **Responsibilities**:
  - Create CoT/GeoChat messages from user input and location.
  - Queue messages until connectivity is available (retry logic).
  - Maintain local message arrays and conversation collections (or feed them into `ChatManager`).
  - Drive `ChatManager` updates (e.g., `unreadCount`).
- **Collaborators**:
  - `TAKService` (sending messages).
  - `LocationManager` / PLI services for location-attached messages.
  - `ChatPersistence` for saving history.
  - `PhotoAttachmentService` for media attachments.

### PositionBroadcastService (`Services/PositionBroadcastService.swift`)

- **Role**: PLI broadcaster.
- **Responsibilities**:
  - Manage user’s call sign, UID, unit type, role and team color.
  - Periodically send position CoT events at a configured interval.
  - Expose reactive state for UI toggles and config screens.
- **Collaborators**:
  - `TAKService` to send CoT.
  - `LocationManager` (CoreLocation).
  - `CoT` generators for PLI format.

### TrackRecordingService (`Services/TrackRecordingService.swift`)

- **Role**: Tracking service for movement.
- **Responsibilities**:
  - Record GPS tracks over time, including speed, distance, elevation.
  - Provide access to current and saved tracks.
  - Export tracks to GPX/KML for external use.
- **Collaborators**:
  - `LocationManager` / CoreLocation.
  - `TrackModels`, `BreadcrumbTrailOverlay` and `TrackOverlayRenderer`.
  - `RouteStorageManager` (persistence).

### MeasurementService & RangeBearingService (`Services/MeasurementService.swift`, `RangeBearingService.swift`)

- **MeasurementService**
  - Responsibilities:
    - Start/stop measurement sessions (distance, area).
    - Manage overlays and annotations representing measurement lines/polygons.
    - Integrate with `MeasurementManager` and map overlays.
- **RangeBearingService**
  - Responsibilities:
    - Provide pure calculations and domain objects for range/bearing lines.
    - Maintain active range/bearing overlays and measurements.

### Map-Related Services

- **ElevationProfileService/ElevationAPIClient**
  - Responsibilities:
    - Request and aggregate elevation samples along a path.
    - Provide single-point elevation.
- **LineOfSightService/TerrainVisualizationService**
  - Responsibilities:
    - Compute line-of-sight and terrain features from elevation data and map geometry.
- **ArcGISFeatureService/ArcGISPortalService**
  - Responsibilities:
    - Communicate with ArcGIS services for features and portal content.
- **OfflineMap & Tile Services**
  - `OfflineTileCache`, `TileDownloader`, `OfflineMapManager`
  - Responsibilities:
    - Download and manage offline map tiles and regions.

### Tactical/Mission Services

- **GeofenceService**
  - Evaluate positions against defined geofences and raise CoT/notifications.
- **MissionPackageSyncService**
  - Synchronize mission packages (data packages) with backend TAK infrastructure.
- **BloodhoundService, EchelonService, TeamService**
  - Provide specialized tactical functionality:
    - Target/route guidance,
    - Unit hierarchy management,
    - Team lifecycle and messaging.

## Interface Contracts

Key abstractions and “interfaces” (often Swift protocols) that define architectural boundaries:

- **Protocol-based generators and handlers**
  - Example from `Architecture.md`:
    - `protocol CoTMessageGenerator { func generateCoTMessage() -> String }`
  - Likely implemented by:
    - `ChatCoTGenerator`, `GeofenceCoTGenerator`, `MarkerCoTGenerator`, `TeamCoTGenerator`.

- **View–ViewModel contract**
  - Views rely on:
    - `ObservableObject` conformance with `@Published` properties.
    - Standard operations (e.g., `sendMessage`, `startBroadcasting`, `startRecording`).
  - This creates an implicit contract: each view expects a manager with defined fields and action methods, e.g., `ChatView` expects `ChatManager` with `conversations`, `sendMessage`.

- **Networking & CoT handling**
  - `CoTMessageDelegate`:
    - DirectTCP-like networking components call back with received CoT messages.
  - `CoTEventHandler`’s public methods form a contract for pushing new events into the system and subscribing to notifications.

- **Storage contracts**
  - Persistence classes (e.g., `ChatPersistence`, `DrawingPersistence`) define serialization & deserialization interfaces used by managers and services.
  - Models are `Codable`, forming a contract for persistence and sync layers.

- **Map overlay & marker protocols**
  - UIKit/MapKit types (e.g., `MKOverlay`, `MKAnnotation`) form external contracts for map controllers, overlays, markers.
  - Custom overlays/annotations conform to these to plug into MapKit.

- **Grid & conversion utilities**
  - `MGRSConverter` & `BNGConverter` expose coordinate transformation methods as stateless APIs; they act as infrastructural “services” with functional contracts.

## Design Patterns Identified

- **MVVM (Model–View–ViewModel)** – Explicitly documented and consistently followed:
  - Views in `Views/` bind via `@ObservedObject`/`@EnvironmentObject` to managers.
  - Managers/Services transform user intents into domain operations and update `@Published` state.
  - Models remain pure data.

- **Reactive programming with Combine**
  - Managers/services use `@Published` and `AnyCancellable` to propagate state.
  - Example from docs: `takService.$isConnected` is observed by `ChatManager` or other controllers.

- **Singleton pattern**
  - Many services/managers expose `static let shared`:
    - `ChatService.shared`, `PositionBroadcastService.shared`, `TrackRecordingService.shared`, `CertificateManager.shared`, `ServerManager.shared`, etc.
  - Used to centralize side-effectful services and avoid passing dependencies everywhere.

- **Dependency Injection**
  - For more testable components, dependencies are configured via initializer or `configure(...)` methods:
    - `ChatService.configure(takService:locationManager:)`
    - `PositionBroadcastService.configure(takService:locationManager:)`
    - `CoTEventHandler.configure(takService:chatManager:)`
  - This supports both singleton use and test-oriented injection.

- **Protocol-Oriented Design**
  - Abstractions like `CoTMessageGenerator`, delegate protocols (`CoTMessageDelegate`), and service protocols (implied by documentation) allow multiple implementations for testing or different backends.

- **Observer/Publisher–Subscriber**
  - Combine publishers and `NotificationCenter` are used where many components need to react to the same events (e.g., new CoT message, connection state).

- **Coordinator pattern (for Map and Menus)**
  - `MapOverlayCoordinator`, `RadialMenuMapCoordinator`, `MapStateManager` take responsibility for managing complex UI behaviors and delegation instead of burying logic inside views/controllers.

- **Facade / Subsystem segmentation**
  - Subsystems like Network, Map, Storage are documented as aggregated into a simpler interface for the rest of the app:
    - `TAKService` for networking.
    - `EnhancedMapViewController` plus overlay coordinators for map.
    - `ChatManager`/`ChatService` for chat instead of exposing CoT or raw sockets.

## Component Relationships

Structural relationships (summarizing `docs/Architecture.md` and directories):

- **Entry & Composition**
  - `OmniTAKMobileApp`:
    - Creates root `ContentView`/map view.
    - Instantiates and injects core managers/services into environment or directly into views.
  - `ContentView`:
    - Embeds primary screens (map, navigation drawer, tools panels).
    - Provides tab or side navigation to feature views.

- **Map as Central Coordinator**
  - Main map view (`ATAKMapView`/`EnhancedMapViewController`/`IntegratedMapView`) integrates:
    - Network state (`TAKService`).
    - Feature managers (`ChatManager`, `OfflineMapManager`, `DrawingToolsManager`, `GeofenceManager`, `WaypointManager`, etc).
    - Overlays (measurement, trails, compass, video, radial menu).
  - Map controllers handle:
    - User gestures, context menus (RadialMenu).
    - Propagation of selection and tool actions to managers.

- **Network subsystem**
  - `TAKService` ↔ Direct TCP/TLS (via xcframework / bridging).
  - Inbound messages:
    - `TAKService` → `CoTMessageParser` → `CoTEventHandler`.
    - `CoTEventHandler` → Managers and Services, e.g.:
      - `ChatManager.receiveMessage`
      - `TrackRecordingService` or breadcrumb services
      - `EmergencyBeaconService`, `TeamService`, etc.
  - Outbound messages:
    - Managers/Views → Service (e.g., `ChatService.sendTextMessage`) → CoT Generator → `TAKService.send(cotMessage:)`.

- **Managers & Services**
  - Views only talk to Managers/Services:
    - Example: `ChatView` interacts with `ChatManager`; `ChatManager` orchestrates `ChatService` and `ChatPersistence`.
  - Managers coordinate with multiple services where necessary:
    - E.g., `ServerManager` works with `CertificateManager` and `TAKService`.

- **Storage subsystem**
  - Feature managers delegate persistence to specialized storage classes:
    - `ChatManager` → `ChatPersistence`/`ChatStorageManager`.
    - `DrawingToolsManager` → `DrawingPersistence`.
    - `TeamManager` → `TeamStorageManager`.
    - `Route`/`Track` → `RouteStorageManager`.
  - Underlying mechanisms: `UserDefaults`, Keychain, and file system (per `Architecture.md` storage section).

- **Utilities / External Systems**
  - Map views and services:
    - Use `ArcGISTileSource` / `ArcGIS*Service` for external map data.
  - KML integration:
    - `KMLImportView` → `KMLMapIntegration` / `KMLOverlayManager` → Map overlays.
  - Meshtastic:
    - `MeshtasticManager` + `MeshtasticProtobufParser` integrate mesh radio messages into CoT/marker flows.

The documented dependency graph (in `Architecture.md`) shows `ATAKMapView` at the center, referencing `TAKService`, `ChatManager`, `ServerManager`, `CertificateManager`, `DrawingToolsManager`, `OfflineMapManager`, `GeofenceManager`, `EnhancedMapViewController`, and overlay coordinators.

## Key Methods & Functions

Focusing on methods that define core capabilities and boundaries (from docs and structure):

### Networking / TAK

- `TAKService.connect(host:port:protocolType:...)`
  - Establishes TAK server connection with specific protocol (TCP/UDP/TLS) and credentials.
- `TAKService.disconnect()`, `reconnect()`
  - Lifecycle control for networking.
- `TAKService.send(cotMessage:priority:)`
  - Primary interface to send CoT XML messages to the server.

### Chat & Collaboration

- `ChatService.configure(takService:locationManager:)`
  - Wires ChatService to networking and location.
- `ChatService.sendTextMessage(_:to:)`
  - High-level send path from user-entered text.
- `ChatService.sendLocationMessage(location:to:)`
  - Location-centric chat messages.
- `ChatService.processQueue()`
  - Drains queued messages when connectivity is restored.

- `ChatManager.sendMessage(_:to:)`
  - View-friendly method called by `ChatView` to initiate a message.
- `ChatManager.receiveMessage(_:)`
  - Called by `CoTEventHandler` for inbound messages.
- `ChatManager.sendPhotoMessage(_:image:to:)`
  - Combines Chat and Photo services for image messages.

- `TeamService.createTeam(name:color:)`
  - Defines team creation boundary.
- `TeamService.inviteToTeam(_:uid:)`, `leaveTeam(_:)`, `broadcastTeamMessage(_:)`
  - Team membership and communication operations.

### Position & Tracking

- `PositionBroadcastService.configure(takService:locationManager:)`
- `PositionBroadcastService.startBroadcasting()`, `.stopBroadcasting()`
- `PositionBroadcastService.broadcastPositionNow()`
- `PositionBroadcastService.setUpdateInterval(_:)`
  - Core API for controlling automatic PLI.

- `TrackRecordingService.startRecording(name:)`
- `TrackRecordingService.pauseRecording()`, `resumeRecording()`, `stopRecording()`
- `TrackRecordingService.exportTrack(_:format:)`
  - Recording lifecycle and export.

- `EmergencyBeaconService.activateBeacon(type:)`
- `EmergencyBeaconService.cancelBeacon()`
- `EmergencyBeaconService.sendBeaconUpdate()`
  - Emergency beacon API.

### Map & Measurement

- `MeasurementService.startMeasurement(type:)`
- `MeasurementService.addPoint(_:)`
- `MeasurementService.completeMeasurement()`
- `MeasurementService.addRangeRing(center:radius:)`
  - Core operations for distance/area tools and range rings.

- `RangeBearingService.createLine(from:to:)`
- `RangeBearingService.calculateBearing(from:to:)`
- `RangeBearingService.calculateDistance(from:to:)`
  - Geodesic computations accessible across the app.

- `ElevationProfileService.generateProfile(for:)`
- `ElevationProfileService.fetchElevation(at:)`
  - Interfaces for terrain awareness and planning.

### Configuration & Certificates

- `ServerManager.addServer(_:)`, `removeServer(at:)`, `updateServer(at:with:)`
- `ServerManager.selectServer(_:)`
  - Allow UI to manage and switch between TAK endpoints.

- `CertificateManager.importCertificate(from:password:)`
- `CertificateManager.saveCertificate(_:data:password:)`
- `CertificateManager.getCertificateData(for:)`
- `CertificateManager.getIdentity(for:password:)`
- `CertificateManager.deleteCertificate(_:)`
- `CertificateManager.validateCertificate(_:)`
  - Encapsulate everything around TLS certificates & Keychain.

### CoT / Event Handling

- `CoTEventHandler.configure(takService:chatManager:...)`
  - Links event handler to global services.
- `CoTEventHandler` public process methods (e.g., `handleIncomingEvent(_:)` – implied).
  - Single place where incoming CoT is interpreted and routed.

- `CoTFilterManager.addFilter(_:)`, `removeFilter(at:)`
  - Filtering contract used by event routing and UI.

### KML & Offline

- `KMLParser.parse(...)`, `KMZHandler` methods
  - Parse imported KML/KMZ.
- `KMLMapIntegration.addKMLToMap(...)`
  - Integrate parsed KML into current map overlays.

- `OfflineTileCache` and `TileDownloader` methods
  - Manage caching and downloading offline tiles.

## Available Documentation

### Documentation Files and Paths

- Root-level:
  - `/OmniTAKMobile/RESTRUCTURING_GUIDE.md`
  - `/CONNECTING_TO_TAK_SERVER.md`
  - `/CONTRIBUTING.md`
  - `/DEPLOYMENT.md`
  - `/SETTINGS_PERSISTENCE_IMPROVEMENTS.md`
  - `/TLS_LEGACY_SUPPORT.md`
  - `/UNIT_TYPE_SELECTOR_GUIDE.md`
  - `/README.md`

- Main documentation tree:
  - `/docs/Architecture.md`
  - `/docs/README.md`
  - `/docs/DOCUMENTATION_COMPLETE.md`
  - `/docs/DOCUMENTATION_SUMMARY.md`
  - `/docs/errors.md`
  - `/docs/guidebook.md`
  - `/docs/suggestions.md`
  - `/docs/todo.md`
  - `/docs/userguide.md`

- API References:
  - `/docs/API/Managers.md`
  - `/docs/API/Models.md`
  - `/docs/API/Services.md`

- Developer Guides:
  - `/docs/DeveloperGuide/GettingStarted.md`
  - `/docs/DeveloperGuide/CodebaseNavigation.md`
  - `/docs/DeveloperGuide/CodingPatterns.md`

- Feature Guides:
  - `/docs/Features/ChatSystem.md`
  - `/docs/Features/CoTMessaging.md`
  - `/docs/Features/MapSystem.md`
  - `/docs/Features/Networking.md`

- User Guides:
  - `/docs/UserGuide/Features.md`
  - `/docs/UserGuide/GettingStarted.md`
  - `/docs/UserGuide/Settings.md`
  - `/docs/UserGuide/Troubleshooting.md`

- In-app / Feature-local docs:
  - `/OmniTAKMobile/Resources/Documentation/CHAT_FEATURE_README.md`
  - `/OmniTAKMobile/Resources/Documentation/FILTER_INTEGRATION_GUIDE.md`
  - `/OmniTAKMobile/Resources/Documentation/KML_INTEGRATION_GUIDE.md`
  - `/OmniTAKMobile/Resources/Documentation/MESHTASTIC_PROTOBUF_README.md`
  - `/OmniTAKMobile/Resources/Documentation/OFFLINE_MAPS_INTEGRATION.md`
  - `/OmniTAKMobile/Resources/Documentation/RADIAL_MENU_INTEGRATION_GUIDE.md`
  - `/OmniTAKMobile/Resources/Documentation/SHARED_INTERFACES.swift`
  - `/OmniTAKMobile/Resources/Documentation/UI_LAYOUT_REFERENCE.md`
  - `/OmniTAKMobile/Resources/Documentation/USAGE_EXAMPLES.swift`
  - `/OmniTAKMobile/Resources/Documentation/WAYPOINT_INTEGRATION_GUIDE.md`

- GitHub prompt:
  - `/.github/prompts/davia-documentation.md` – likely meta documentation instructions.

### Documentation Quality Assessment

- **Architecture.md**
  - High quality, detailed:
    - Explains overarching principles (SRP, DI, reactive state).
    - Shows MVVM and subsystem diagrams.
    - Clearly states component roles (views, managers, services, models).
    - Describes network, map, and storage subsystems with ASCII diagrams.
  - Very useful as a top-level orientation and for architectural reasoning.

- **API docs (Managers.md, Services.md, Models.md)**
  - High quality, close to reference-level:
    - Per-class sections with declarations, properties, method signatures, parameter descriptions, and usage examples.
    - Explicit line counts and file paths, making it easy to locate code.
    - These docs form a stable contract document between feature teams and the core architecture.

- **Developer Guides**
  - Provide onboarding and navigation guidance:
    - How to traverse the codebase and where to find feature code.
    - Coding patterns (how to write new managers/services/views).
  - Adequate to ramp up new contributors on structure and styles.

- **Feature Guides**
  - Focused on specific subsystems (Chat, CoT messaging, Map, Networking).
  - Likely include flow diagrams and common usage patterns; good for feature-level understanding.

- **User Guides**
  - Oriented toward end-users / testers:
    - Explains features, settings, and troubleshooting.
    - Less relevant for code structure, but helpful to connect code modules to user-visible behaviors.

- **Embedded Feature Docs**
  - Each major feature (chat, filters, KML, Meshtastic, offline maps, radial menu, waypoints) has its own integration guide and sometimes example Swift.
  - This material is particularly useful for:
    - Adding new features in those domains.
    - Understanding expected extension points and existing interfaces (`SHARED_INTERFACES.swift`, `USAGE_EXAMPLES.swift`).

Overall, the documentation suite is **comprehensive and structurally aligned** with the code:

- Architecture and API references correspond closely to the actual directory layout and pattern usage.
- Documentation emphasizes the same separation of concerns described above (Views–Managers–Services–Models).
- For structural analysis and AI-based agents, the available docs offer enough information to navigate and reason about the system with minimal code inspection.
