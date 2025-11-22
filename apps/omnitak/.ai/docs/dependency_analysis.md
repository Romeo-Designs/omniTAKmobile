# Dependency Analysis

## Internal Dependencies Map

### High-level layering

From the `docs/Architecture.md` and the directory layout, the codebase follows a layered MVVM-style structure:

- **Views (`OmniTAKMobile/Views`, `UI/*`)**
  - Pure SwiftUI views.
  - Depend on `Managers` (view models) via `@ObservedObject`, `@StateObject`, or `@EnvironmentObject`.
- **Managers (`OmniTAKMobile/Managers`)**
  - `ObservableObject` view models for each feature.
  - Depend on:
    - `Services` for business logic and I/O.
    - `Storage` for persistence.
    - `Models` for data structures.
- **Services (`OmniTAKMobile/Services`)**
  - Business logic, network calls, protocol handling, integration with external systems (TAK, ArcGIS, etc.).
  - Often singletons (`static let shared`).
  - Depend on:
    - Foundation / URLSession / Network frameworks.
    - CoreLocation (location-based features).
    - `Models` for request/response data.
    - Sometimes `Managers` via configuration methods (`configure(takService:..., locationManager:...)`).
- **Models (`OmniTAKMobile/Models`)**
  - Plain data structs/classes; mostly `Codable` and `Identifiable`.
  - Have no dependencies on managers or services; used broadly across all layers.
- **Utilities (`OmniTAKMobile/Utilities/*`)**
  - Cross-cutting helpers (coordinate converters, KML, networking, calculators).
  - Used by Managers, Services, and sometimes Views.
- **Map subsystem (`OmniTAKMobile/Map/*`)**
  - Controllers, overlays, markers, tile sources.
  - Depend on:
    - `Managers` for feature state (e.g., measurement, offline maps).
    - `Models` (routes, tracks, overlays).
    - `Services` for tile/elevation or similar features.
- **Storage (`OmniTAKMobile/Storage`)**
  - Persistence abstractions (chat history, team, routes).
  - Used primarily by `Managers` and `Services`.

### Example internal dependency chains

#### 1. TAK connectivity and CoT

- `ContentView` (Core/ContentView.swift)
  - Holds `@StateObject private var takService = TAKService()`.
  - Uses `takService.connectionStatus`, `isConnected`, `lastError`, counters.
  - Invokes:
    - `takService.connect(host:port:protocolType:useTLS:)`
    - `takService.disconnect()`
    - `takService.sendCoT(xml:)`.

- `TAKService` (Services/TAKService.swift)
  - Imports: `Foundation`, `Combine`, `CoreLocation`, `Network`, `Security`.
  - Internally:
    - Uses `DirectTCPSender` for actual socket/TLS/UDP connections.
    - Bridges CoT XML to/from the network.
    - Not in the snippet but described in `docs/API/Services.md` as a core service with connect/disconnect/send and stats.
  - Depends on:
    - `ServerManager` (indirectly) to get server configuration.
    - `Models` representing CoT / PLI / Tracks.
    - Possibly `CertificateManager` for client TLS certificates.

- `DirectTCPSender` (inner class of `TAKService.swift`)
  - Pure transport layer abstraction.
  - Depends only on `Network` and `Security` frameworks.
  - Exposes:
    - `onMessageReceived: (String)->Void`
    - `onConnectionStateChanged: (Bool)->Void`
  - `TAKService` subscribes to those and translates into app-level events.

Resulting chain:

`ContentView` → `TAKService` → `DirectTCPSender` → TAK server

Plus (from documentation):

`Services` (e.g., `ChatService`, `PositionBroadcastService`, `TrackRecordingService`, etc.) → `TAKService` for sending/receiving CoT.

#### 2. Server configuration

- `ServerPickerView` (Views/ServerPickerView.swift, referenced in root dir & Views)
  - Likely binds to `ServerManager.shared` to show and modify servers.

- `ServerManager` (Managers/ServerManager.swift)
  - Imports: `Foundation`, `Combine`.
  - Defines `struct TAKServer` and manages list of servers.
  - Persists via `UserDefaults` using `Codable`.
  - On init:
    - Loads servers and the active server.
    - If none exist, creates default `TAKServer(name:"Taky Server", host:"127.0.0.1", port:8087, ...)`.
  - Provides:
    - `addServer`, `updateServer`, `deleteServer`, `setActiveServer`, `getDefaultServer`.

Dependencies:

Views (Server selection, connection screens) → `ServerManager` → `TAKService` uses `ServerManager.activeServer` to establish connections.

#### 3. Chat subsystem

From `ChatService.swift` and docs:

- `ChatView` (Views/ChatView.swift)
  - Binds to `ChatManager` or `ChatService` (depending on wiring described in docs).
  - Shows conversations and messages.

- `ChatService` (Services/ChatService.swift)
  - Imports: `Foundation`, `Combine`, `CoreLocation`, `UIKit`.
  - Singleton: `static let shared = ChatService()`.
  - Holds:
    - Reactive state: `messages`, `conversations`, `participants`, `unreadCount`, `queuedMessages`, `isConnected`.
  - Depends directly on:
    - `ChatManager.shared` (manager/view-model).
    - `ChatStorageManager.shared` (persistence).
    - `LocationManager` (via `configure(takService:locationManager:)`).
    - `ChatCoTGenerator` and `ChatXMLParser` from `CoT/Generators` and `CoT/Parsers`.
    - `TAKService` (indirectly via `ChatManager.configure`).
  - Behavior:
    - Subscribes to `ChatManager`’s `@Published` properties.
    - Generates CoT packets for location messages.
    - Queues messages for sending via TAK (through `queueMessage`—implementation in `ChatStorageManager`/`ChatManager`).

- `ChatManager` (Managers/ChatManager.swift, referenced in docs/API/Managers.md)
  - `ObservableObject` with `@Published` conversations etc.
  - Uses:
    - `ChatService` (for send/receive, or they mutually coordinate).
    - `ChatPersistence` in `Storage`.

- `ChatStorageManager` + `ChatPersistence` (Storage/)
  - Manage local-DB or file-based chat history, queued messages, and statuses.

Dependencies:

Views (ChatView, ConversationView)  
→ `ChatManager` (state)  
↔ `ChatService` (business + integration)  
→ `ChatStorageManager`/`ChatPersistence` (storage)  
→ `ChatXMLParser` / `ChatCoTGenerator` (CoT XML)  
→ `TAKService` (CoT transport).

#### 4. Position broadcast and tracking

From `docs/API/Services.md`:

- `PositionBroadcastService`
  - Singleton `shared`.
  - Depends on:
    - `TAKService` for CoT publishing.
    - `LocationManager` (CoreLocation wrapper).
    - `PositionBroadcast` models (`Models/TrackModels.swift` or related).
  - Configured via `configure(takService:locationManager:)`.
  - Exposes `@Published` user callsign/UID/team fields that views can bind to.

- `TrackRecordingService`
  - Singleton `shared`.
  - Depends on `LocationManager` for GPS, and `Storage` for persisted tracks.
  - Uses `Track` models (in `Models/TrackModels.swift`).

Views (`TrackRecordingView`, `TrackListView`) → `TrackRecordingService` → Location/Storage.

#### 5. ArcGIS integration

- `ArcGISPortalView` (Views/ArcGISPortalView.swift)
  - Presents login/search UI.
  - Binds to `ArcGISPortalService.shared` or a local instance.

- `ArcGISPortalService` (Services/ArcGISPortalService.swift)
  - Singleton `shared`.
  - Imports: `Foundation`, `Combine`.
  - Stores:
    - `ArcGISCredentials` (Models/ArcGISModels.swift).
    - `ArcGISPortalItem`, `ArcGISItemType` (same models file).
  - Uses:
    - `URLSession` with custom configuration (timeouts).
    - Async/await (`session.data(for:request)`).
  - Responsibilities:
    - `authenticate(username:password:)` → calls `generateToken` endpoint.
    - `authenticateWithToken(...)`.
    - `signOut()` → clears credentials from `UserDefaults`.
    - `searchContent(...)` → calls `/sharing/rest/search` with token.

Dependencies:

`ArcGISPortalView` → `ArcGISPortalService` → ArcGIS REST endpoints.  

Other services such as `ArcGISFeatureService` and `OfflineMapManager` likely consume `ArcGISPortalService.credentials` to access secure feature layers or tile services.

#### 6. Plugin UI (non-dynamic)

- `PluginsListView` (Views/PluginsListView.swift)
  - Uses static `@State` list of `PluginInfo` structs; no dynamic discovery.
  - No integration with deeper plugin APIs; purely a configuration UI stub.

Dependencies:

`PluginsListView` → local `PluginInfo` model only.

### Cross-cutting managers and services

Some managers/services are central and referenced across multiple subsystems:

- `ServerManager.shared` – central location for TAK server endpoints.
- `CertificateManager.shared` – TLS client certificate management; used by:
  - `CertificateEnrollmentService.swift`
  - `TAKService` when establishing TLS with mutual auth.
- `OfflineMapManager` + `OfflineTileCache` – used by map controllers and overlays.
- `GeofenceManager` + `GeofenceService` – used by map overlays and views like `GeofenceManagementView`.
- `WaypointManager` + `WaypointModels` – for marker placement on the map.

## External Libraries Analysis

The project appears to avoid 3rd-party package managers in the checked-in code; it largely uses:

### System & Apple frameworks

- **SwiftUI** (across all `Views/` and many `UI/*` files)
- **Combine** (`Managers`, `Services`, `ArcGISPortalService`, `TAKService`)
- **Foundation** (ubiquitous)
- **CoreLocation** (TAKService, ChatService, measurement/track services)
- **Network** (`NWConnection`, `NWParameters` in `TAKService.swift`)
- **Security** (client TLS certificates in `DirectTCPSender`)
- **UIKit** (feedback generators in `ChatService`; may appear elsewhere)

These are standard system frameworks; versions depend on the Xcode/iOS SDK rather than project-level configuration.

### Bundled native component

- **OmniTAKMobile.xcframework**
  - Contains headers and Rust source (`Cargo.toml`, `callbacks.rs`, `connection.rs`, etc.).
  - Represents a compiled framework (probably a Rust-FFI core for TAK).
  - Current networking path uses `DirectTCPSender` to “bypass incomplete Rust FFI”; so the xcframework is present but not currently the main data path for CoT in `TAKService.swift`.

### REST / HTTP integrations

Implemented using `URLSession`, not third-party libs:

- ArcGIS REST API:
  - `ArcGISPortalService`:
    - `POST /sharing/rest/generateToken`
    - `GET /sharing/rest/search`
  - `ArcGISFeatureService`, `ArcGISTileSource`, `OfflineTileOverlay` likely use:
    - Feature service / map service endpoints with token query param or header.
- Elevation API:
  - `ElevationAPIClient.swift` and `ElevationProfileService.swift` appear to call a remote elevation service (possibly ArcGIS elevation or another REST API).

No evidence of Alamofire, Moya, or similar external networking libraries.

### Meshtastic integration

- `MeshtasticProtoMessages.swift`, `MeshtasticProtobufParser.swift`, `MESHTASTIC_PROTOBUF_README.md`.
  - Likely contain generated structs or manual parsing for Meshtastic’s protobuf protocol.
  - No explicit 3rd-party protobuf library is visible; parsing is likely hand-written or uses Swift Protobuf if vendored (not in listed files).

## Service Integrations

### TAK Server

- **Protocol:** Cursor on Target (CoT) over TCP/UDP/TLS.
- **Entry point:** `TAKService` using `DirectTCPSender`.
- **Security:**
  - TLS options configured via Security framework:
    - Custom TLS versions (min TLS 1.2; optional legacy TLS 1.0/1.1).
    - Custom cipher suites (to interop with older TAK servers).
    - Verification callback that accepts self-signed server certs.
    - Optional client certificate (`certificateName`, `certificatePassword`) loaded via Keychain.
  - `CertificateManager` and `CertificateEnrollmentService` handle Keychain/PKCS#12.

- **Clients of TAKService:**
  - `ChatService`, `PositionBroadcastService`, `DigitalPointerService`, `TeamService`, `TrackRecordingService`, `VideoStreamService`, etc.
  - CoT generator/parsers:
    - `CoTEventHandler`, `CoTMessageParser`, `ChatCoTGenerator`, `GeofenceCoTGenerator`, `MarkerCoTGenerator`, `TeamCoTGenerator`, `ChatXMLParser`.

### ArcGIS Portal & Map Services

- **Service:** `ArcGISPortalService`
  - Uses ArcGIS Online or on-prem Portal:
    - `https://www.arcgis.com/sharing/rest` by default.
  - Handles authentication and token management; persists credentials in `UserDefaults`.

- **Related services:**
  - `ArcGISFeatureService` – querying feature layers, performing identify/select.
  - `ArcGISTileSource` and `OfflineTileOverlay` – map tiles.
  - `OfflineMapManager` – offline package download from portal items.

Views like `ArcGISPortalView`, `OfflineMapsView`, and map controllers rely on these services.

### Elevation / Terrain

- `ElevationAPIClient.swift`
  - Lower-level client for retrieving elevation data from a server.
- `ElevationProfileService.swift`
  - Wraps API client; used by `ElevationProfileView` and `LineOfSightService`.

External endpoint specifics are in those files but we see standard `URLSession` usage.

### Meshtastic

- `MeshtasticManager` (Manager) + `MeshtasticProtobufParser` (Utility/Parser) + `MeshtasticProtoMessages` (Models).
  - Integrates with Meshtastic radios via either BLE/Serial/WiFi (implementation not shown but referenced in docs).
  - Acts as an additional, non-TAK network to bring in/out contacts and PLI.

### Other services

All in `OmniTAKMobile/Services`:

- `BloodhoundService` – Blue Force Tracking / contact tracking logic (UI representation present in `BloodhoundView`).
- `NavigationService`, `TurnByTurnNavigationService` – route navigation.
- `MissionPackageSyncService` – data package upload/download and synchronization with TAK.
- `VideoStreamService` – handles RTSP/other streaming protocols; uses underlying AVFoundation.

All of these integrate either with TAK (via CoT) or with third-party backends (e.g., video streaming servers), but they all share the same pattern: standalone service with Combine state, `static shared` singleton.

## Dependency Injection Patterns

### Patterns actually present

1. **Singleton services and managers**

   - Almost all services are exposed as:
     ```swift
     class ChatService: ObservableObject {
         static let shared = ChatService()
     }
     ```
   - Managers likewise often have:
     ```swift
     class ServerManager: ObservableObject {
         static let shared = ServerManager()
     }
     ```
   - Views typically either:
     - Own their own instance with `@StateObject`, or
     - Access `.shared` directly, or
     - Receive an instance via initializer parameters, which are then derived from `.shared` at composition time.

2. **Manual configuration methods**

   - Several services expose `configure(...)` methods that are called during app startup or when dependencies become available:

   ```swift
   func configure(takService: TAKService, locationManager: LocationManager)
   ```

   These are used in:
   - `ChatService` → calls through to `ChatManager.configure`.
   - `PositionBroadcastService`, `TrackRecordingService` (per docs) → `configure(takService:locationManager:)`.

   This is a form of setter/late injection, but not through a DI container.

3. **Environment and ObservedObjects**

   - Views use typical SwiftUI patterns:

     ```swift
     @StateObject private var takService = TAKService()
     @ObservedObject var chatManager: ChatManager
     @EnvironmentObject var serverManager: ServerManager
     ```

   - These interact with `ObservableObject` managers and services.

4. **Protocol-based interfaces (limited but present)**

   - `Architecture.md` describes protocols like:

     ```swift
     protocol CoTMessageGenerator {
         func generateCoTMessage() -> String
     }
     ```

   - Generators like `ChatCoTGenerator`, `GeofenceCoTGenerator` likely conform to these protocols and can be substituted in tests.
   - However, services mostly depend on concrete singletons rather than protocols.

### Things that are *not* present

- No use of a third-party DI framework (e.g., Needle, Resolver, Swinject).
- No centralized composition root that wires the whole object graph; initialization is mostly implicit via singletons and `@StateObject` instantiation.

### Implications

- **Testability**:
  - Direct use of `static let shared` and concrete types makes unit testing harder; dependencies like `TAKService` or `ArcGISPortalService` are difficult to mock.
  - Some injection exists via `configure(...)`, so for those services you *can* pass in mocked instances.

- **Lifecycle management**:
  - Singleton lifetime equals app lifetime; background tasks, timers (like `ChatService.retryTimer`) are pinned to app lifecycle and can become subtle sources of leaks or unwanted background activity.

## Module Coupling Assessment

### Cohesion

Overall, each directory has high cohesion:

- `Managers/` – feature-specific app state containers.
- `Services/` – business logic by domain (Chat, CoT, ArcGIS, Elevation, etc.).
- `Models/` – data-only.
- `Map/` – map rendering, overlays, controllers.
- `CoT/` – CoT-specific parsing/generation utilities.

Feature-specific clusters (e.g., Chat, Offline Maps, Measurement, Meshtastic) are well-bounded.

### Coupling patterns

1. **Vertical coupling (View → Manager → Service → Utility/Network)**
   - The main, desired path. Views rarely reach into Services directly; they usually talk via Managers.

2. **Singleton cross-links**

   - Many components reference each other through `.shared`, creating hidden coupling:
     - `ChatService` → `ChatManager.shared`, `ChatStorageManager.shared`.
     - Likely `TAKService.shared` is used inside other services rather than passed in.

3. **Service ↔ Manager bidirectional coupling**

   Example from `ChatService.swift`:

   - `ChatService` holds `private let chatManager = ChatManager.shared`.
   - Docs for `ChatManager` show it calls methods on `ChatService` (or expects to be configured by `ChatService`/TAK).
   - This creates a risk of circular conceptual dependency:
     - Manager updates state that Service also publishes and reads.
     - Service subscribes to Manager’s state (via Combine sinks).
   - Practically, the direction is Manager as UI-facing state, Service as backend; but because both are singletons they are tightly intertwined.

4. **TAKService as a central hub**

   - Many services depend on `TAKService` (for sending/receiving CoT).
   - `TAKService` requests configuration from `ServerManager` and `CertificateManager`.
   - Changes in `TAKService` (connection semantics, queueing, CoT parsing) can affect chat, PLI, tracks, team, video, etc.

5. **Rust xcframework bypass**

   - Networking is currently done via `DirectTCPSender` in Swift despite the xcframework existing.
   - When or if the Rust FFI is re-enabled, the dependency surface changes significantly:
     - `TAKService` would depend on the xcframework C-API (`omnitak_mobile.h`).
     - Current Swift networking code is decoupled from that only by the `TAKService` boundary.

### Degree of coupling by area

- **Chat subsystem**: Moderately high coupling between `ChatService`, `ChatManager`, and `ChatStorageManager`; good cohesion within the feature.
- **ArcGIS subsystem**: Fairly clean; `ArcGISPortalService` + `ArcGISFeatureService` + `ArcGISModels` with views binding to them. Decent separation.
- **Map subsystem**: Map controllers appear to be the integration point between many features (markers, overlays, trails, measurement, KML integration):
  - `EnhancedMapViewController`, `MapOverlayCoordinator`, `RadialMenuMapOverlay`, etc.
  - They are inherently high-coupling “shells” but their responsibility is to orchestrate overlays and tool managers; this is expected but worth monitoring.

## Dependency Graph

Below is a simplified textual graph of major components and their dependencies. Arrow direction: `A → B` means "A depends on B or calls into B".

### Core connectivity and configuration

- `ContentView`  
  → `TAKService`  
  → `ServerManager`  
  → `DirectTCPSender`  
  → `CertificateManager` (for client TLS)  
  → `CoTMessageParser` / `CoTEventHandler` (on received XML)

- `ServerPickerView` → `ServerManager`

### Chat subsystem

- `ChatView`, `ConversationView`, `ContactListView`  
  → `ChatManager`  
  → `ChatService`  
  → `ChatStorageManager` / `ChatPersistence`  
  → `TAKService` (via ChatManager config)  
  → `ChatCoTGenerator`, `ChatXMLParser`  
  → `LocationManager` (for location messages)

- `ChatManager` ↔ `ChatService` (subscribes to state, sends actions).

### PLI, tracks, tactical services

- `PositionBroadcastView` → `PositionBroadcastService`  
  → `TAKService`  
  → `LocationManager`

- `TrackRecordingView` / `TrackListView`  
  → `TrackRecordingService`  
  → `LocationManager`, `OfflineMapManager`, `Storage`.

- `GeofenceManagementView` → `GeofenceManager` → `GeofenceService` → `TAKService`.

- `VideoFeedListView` / `VideoPlayerView` → `VideoStreamService` → TAK or external streaming server.

### ArcGIS and offline maps

- `ArcGISPortalView` → `ArcGISPortalService`  
  → ArcGIS REST endpoints.

- `OfflineMapsView`  
  → `OfflineMapManager`  
  → `ArcGISPortalService` / `ArcGISFeatureService` / `TileDownloader` / `OfflineTileOverlay`.

- `EnhancedMapViewController` / `IntegratedMapView`  
  → `OfflineTileOverlay`, `ArcGISTileSource`, `BreadcrumbTrailOverlay`, `MGRSGridOverlay`, `RadialMenuMapOverlay`, etc.  
  → Various managers: `MeasurementManager`, `TrackRecordingService`, `GeofenceManager`, `WaypointManager`.

### Meshtastic

- `MeshtasticConnectionView` → `MeshtasticManager`  
  → `MeshtasticProtobufParser`, `MeshtasticProtoMessages`  
  → Possibly `TAKService` to bridge radio contacts into TAK network.

### Plugin UI

- `PluginsListView` → `PluginInfo` (local struct only).

## Potential Dependency Issues

1. **Singleton-heavy architecture**

   - Impact:
     - Harder to unit test isolated components (e.g., Chat or TAKService logic) because dependencies are globally shared and concrete.
     - Increases implicit coupling; changes in a singleton ripple across users unexpectedly.
   - Mitigation:
     - Introduce protocols for critical services (e.g., `TAKServiceProtocol`, `ChatServiceProtocol`, `ArcGISPortalServiceProtocol`).
     - Views and managers should depend on protocol types; actual instances provided via environment or initializers.

2. **Service ↔ Manager bidirectional coupling**

   - Chat is the clearest example:
     - `ChatService` owns `ChatManager.shared` and subscribes to it.
     - `ChatManager` also coordinates with `ChatService`.
   - This increases the risk of:
     - Tight cycles of responsibility.
     - Difficult reasoning about who “owns” the state.
   - Mitigation:
     - Choose a direction:
       - Managers own state, Services are pure side-effect helpers; or
       - Services own state, Managers just adapt state for UI.
     - Decouple with protocols and events rather than shared singletons.

3. **Centralization on `TAKService`**

   - Many features depend on `TAKService`. It is effectively a “god object” for network/CoT:
     - Complex, 1100+ lines.
     - Hard to reason about behavior across all CoT types.
   - Mitigation:
     - Factor out:
       - Protocol-specific modules (chat, PLI, video, geofence) into smaller helpers.
       - Transport concerns (socket/connect/reconnect/TLS) into a separate `TransportClient` protocol already partially represented by `DirectTCPSender`.

4. **TLS security posture embedded in `DirectTCPSender`**

   - `DirectTCPSender`:
     - Accepts all server certificates in the verification callback, to accommodate self-signed TAK servers.
     - Adds legacy ciphers and TLS 1.0/1.1 when `allowLegacyTLS` is enabled.
   - While this is necessary for legacy TAK, the security behavior is currently global and not easily constrained per server or environment.
   - Mitigation:
     - Encapsulate security policy in a separate configuration object or service; e.g.:
       ```swift
       struct TLSPolicy {
           let allowLegacy: Bool
           let acceptSelfSigned: Bool
       }
       ```
     - Associate policy with `TAKServer` model.

5. **Rust xcframework integration bypassed**

   - `DirectTCPSender` is explicitly described as “bypassing incomplete Rust FFI”.
   - There are two parallel paths:
     - Current live Swift network path.
     - Planned or legacy Rust xcframework path.
   - Risk:
     - When re-enabling the Rust path, behavior drift and duplication can cause bugs.
   - Mitigation:
     - Keep all higher-level CoT semantics in Swift (`TAKService`) and treat Rust as a pure transport or parsing backend.
     - Define a single abstract interface for the transport; both Rust-based and `DirectTCPSender`-based clients should conform.

6. **Plugin system is currently UI-only**

   - `PluginsListView` shows plugin toggles but they don’t hook into any extensible API.
   - Future real plugin support will need:
     - A plugin registry service.
     - A protocol that features implement to register UI/tools with the map and services.
   - Mitigation:
     - When implementing, ensure plugin API is independent of concrete services (use protocols and dependency boundaries).
     - Avoid letting plugins access `TAKService.shared` directly; pass them scoped interfaces.

7. **Testing and mocking external integrations**

   - External APIs (TAK, ArcGIS, Elevation) are called directly via `URLSession`/`NWConnection` in concrete services.
   - No obvious abstraction for:
     - Mocking ArcGIS responses.
     - Simulating TAK connectivity.
   - Mitigation:
     - Introduce small wrappers:
       - `HTTPClient` protocol for ArcGIS/Elevation.
       - `TransportClient` protocol for TAK connections.
     - Provide default implementations using `URLSession`/`NWConnection` and allow tests to inject mocks.

8. **Potential for circular runtime dependencies**

   - While the typegraph doesn’t show compile-time cycles, patterns like:
     - Service A holds `static let shared` of B, and B holds `static let shared` of A or uses A in its initializer.
   - This is not visible fully from the partial snippets, but should be checked carefully, especially around:
     - `ChatService`, `ChatManager`, `TAKService`, `CoTEventHandler`.
   - Mitigation:
     - Avoid doing heavy work in `init` of singletons.
     - Use explicit `configure(...)` steps after all singletons are constructed.

---

This analysis reflects the actual files and documentation present under `.` as of the snapshot. For deeper, per-type graphs (e.g., which service calls which specific method on `TAKService`), a follow-up pass over each `Services/*.swift` and `Managers/*.swift` file can be generated if needed.