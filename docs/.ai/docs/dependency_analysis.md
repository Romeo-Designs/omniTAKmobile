# Dependency Analysis

## Internal Dependencies Map

### High-level structure

The repo is a mono-repo with several major subsystems:

- **OmniTAK iOS app (SwiftUI MVVM)**  
  `apps/omnitak/OmniTAKMobile`
- **Cross‑platform UI modules (Valdi)**  
  `modules/`, `src/valdi_modules`, `valdi`, `valdi_core`, `snap_drawing`
- **Rust TAK & integration crates**  
  `crates/omnitak-*`
- **Android & iOS Valdi shells**  
  `apps/omnitak_android`, `apps/omnitak_mobile_ios`
- **Plugin system**  
  `modules/omnitak_plugin_system`, `plugin-template`
- **Rust TAK server**  
  `crates/omnitak-server`

The primary focus for OmniTAK Mobile dependencies is the **Swift iOS app** and its integration with **Rust crates**, **Valdi runtime**, **MapLibre**, and **JS/TS mapping stack**.

### OmniTAKMobile iOS (Swift) – internal layering

From `apps/omnitak/OmniTAKMobile` and docs:

**Layers:**

- **Views (`Views/`)**
- **Managers (`Managers/`)**
- **Services (`Services/`)**
- **Models (`Models/`)**
- **Map subsystem (`Map/…`)**
- **CoT subsystem (`CoT/…`)**
- **Meshtastic subsystem (`Meshtastic/…`)**
- **Utilities (`Utilities/…`)**
- **Storage (`Storage/`)**
- **UI components (`UI/…`)**
- **Core app (`Core/`)**

#### Core app wiring

- `OmniTAKMobileApp.swift` (entry); creates top-level environment objects.
- `ContentView.swift` embeds:
  - Global managers (typically via `@EnvironmentObject` / `@StateObject`).
  - Root map & navigation views (`ATAKToolsView`, `NavigationDrawer`, etc.).

**Dependencies:**

- `Core` depends on:
  - `Managers` (as environment objects / singletons).
  - `Views` and `UI/Components` for layout.
  - `Services` indirectly via the managers.

#### Views → Managers

- Each SwiftUI **View** observes one or more managers:

  - `ChatView` → `ChatManager`
  - `RoutePlanningView` → `RouteStorageManager`, `RoutePlanningService` via manager
  - `OfflineMapsView` → `OfflineMapManager`
  - `TAKServersView`, `ServerPickerView` → `ServerManager`, `CertificateManager`
  - `MeshtasticDevicePickerView` → `MeshtasticManager`
  - `VideoFeedListView`, `VideoPlayerView` → `VideoStreamService` (via manager)
  - `TurnByTurnNavigationView` → `NavigationService` / `TurnByTurnNavigationService` (via manager)
  - Map‑adjacent views (`Map3DSettingsView`, `RadialMenuView`, `MGRSGridToggleView`) depend on `MapStateManager`, `DrawingToolsManager`, etc.

**Pattern:**

- Views do **not** own services directly; they call methods on managers (ViewModels), which in turn call services or storage components.

#### Managers → Services / Storage / Models

Typical pattern (from `Architecture.md` and API docs):

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

**Key manager dependencies:**

- `ChatManager`
  - → `ChatService`
  - → `ChatPersistence` (in `Storage/ChatPersistence.swift`)
  - → `TAKService` indirectly via ChatService.

- `ServerManager`
  - → `TAKService` (connection lifecycle, CoT stream)
  - → `CertificateManager` (cert import, selection)
  - → `CertificateEnrollmentService` (enrollment workflow)
  - → `MultiServerFederation` (in `Utilities/Network`)

- `DataPackageManager`
  - → `DataPackageModels`
  - → `MissionPackageSyncService` (send/receive)
  - → Storage for packaging and persistence.

- `DrawingToolsManager`
  - → `DrawingModels`
  - → `DrawingPersistence`
  - → Map overlays (`Drawing` overlays inside `Map/Overlays`).

- `GeofenceManager`
  - → `GeofenceService`
  - → `GeofenceModels`
  - → `GeofenceCoTGenerator` (CoT subsystem).

- `MeasurementManager`
  - → `MeasurementService`
  - → `MeasurementModels`
  - → `MeasurementOverlay` (map overlay).

- `MeshtasticManager`
  - → `MeshtasticService` (in TS) on Valdi side, and
  - → `MeshtasticProtobufParser`, `MeshtasticProtoMessages` for Swift parsing of radio data.

- `OfflineMapManager`
  - → `OfflineMapModels`
  - → `TileDownloader`
  - → `OfflineTileCache`
  - → `ArcGISTileSource` / `ArcGISPortalService`.

- `WaypointManager`
  - → `WaypointModels`
  - → `WaypointIntegration` via services (`PointDropperService`, `RoutePlanningService`).

- `CoTFilterManager`
  - → `CoTFilterModel`
  - → `CoTEventHandler`
  - → `CoTFilterCriteria`.

- `MeasurementManager`, `TrackRecordingManager` (if present)
  - → `TrackRecordingService`, `TrackModels`, `UnitTrailOverlay`.

- `MeshtasticManager`
  - → `MeshtasticModels`
  - → `MeshtasticProtobufParser`.

**General flow:**

- Managers **hold** state (`@Published`) and references to services and storage managers.
- Managers **depend on**:
  - `Models` (shared)
  - One or more **Services**
  - One or more **Storage** helpers
  - Occasionally **Utilities** (e.g., converters).

#### Services → Utilities / Network / External APIs / Rust FFI

Representative dependencies (based on filenames & docs):

- `TAKService.swift`
  - Central CoT networking service.
  - Depends on:
    - Rust FFI via `omnitak_mobile.h` (in `OmniTAKMobile.xcframework` / crates).
    - `CoTMessageParser`, `CoTEventHandler` (for incoming/outgoing CoT XML).
    - `ChatService`, `TeamService`, `TrackRecordingService`, etc. (for routing parsed events).
    - `NetworkMonitor` and `MultiServerFederation`.

- `CertificateEnrollmentService.swift`
  - Uses Rust crate `omnitak-cert` via FFI (`enrollment_ffi.rs`) through `omnitak_mobile.h`.
  - Depends on `CertificateManager` and `CertificateKeychainManager` (iOS native keychain).

- `ChatService.swift`
  - Uses `ChatXMLGenerator` / `ChatXMLParser` to build/parse CoT-compliant GeoChat messages.
  - Sends data via `TAKService`.

- `MissionPackageSyncService.swift`
  - Encodes/decodes mission packages (zip/KML/attachments).
  - Talks to `TAKService` and local storage.

- `PositionBroadcastService.swift`
  - Obtains GPS/position (CoreLocation; likely through utilities).
  - Packages CoT position messages and sends via `TAKService`.
  - Coordinates with `TrackRecordingService` for trails.

- `TrackRecordingService.swift`
  - Maintains track data (breadcrumbs, unit trails).
  - Feeds `BreadcrumbTrailOverlay`, `UnitTrailOverlay`, `TrackOverlayRenderer`.

- `NavigationService.swift`, `TurnByTurnNavigationService.swift`
  - Integrate routing engines (internal route models + geospatial utilities).
  - Use `RoutePlanningService` and map overlays.

- `LineOfSightService.swift`, `ElevationProfileService.swift`, `TerrainVisualizationService.swift`, `MeasurementService.swift`, `RangeBearingService.swift`
  - Depend heavily on:
    - `ElevationAPIClient.swift` (for profile data if remote),
    - `ElevationProfileModels`, `LineOfSightModels`, `MeasurementModels`,
    - `Utilities/Calculators/MeasurementCalculator.swift`,
    - `Utilities/Converters` (e.g., MGRS/BNG).

- `ArcGISFeatureService.swift`, `ArcGISPortalService.swift`
  - Depend on ArcGIS REST APIs and corresponding models (`ArcGISModels`).

- `VideoStreamService.swift`
  - Manages video stream metadata (from CoT / network).
  - Integrates with `VideoMapOverlay`, `VideoStreamModels`.

- `PhotoAttachmentService.swift`
  - Bridges iOS Photo picker and CoT attachments.

- `TeamService.swift`
  - Manages team structures, CoT team messages via `TeamCoTGenerator`.

- `BloodhoundService.swift`, `DigitalPointerService.swift`, `EmergencyBeaconService.swift`, `EchelonService.swift`
  - Each maps domain workflows to CoT messages and internal models.

#### Storage → Models

Storage layer in `Storage/`:

- `ChatPersistence.swift`, `ChatStorageManager.swift`
- `DrawingPersistence.swift`
- `RouteStorageManager.swift`
- `TeamStorageManager.swift`

Dependencies:

- `Models` — chat, routes, team definitions.
- Foundation persistence APIs (e.g., file system, UserDefaults, CoreData; not all visible here but implied by naming).
- Maybe `PersistentStore` from Valdi in the Valdi branch; the native app uses pure Swift.

#### Map subsystem internal dependencies

Location: `Map/Controllers`, `Map/Markers`, `Map/Overlays`, `Map/TileSources`.

Key relationships:

- Map controllers (`MapViewController`, `EnhancedMapViewController`, `IntegratedMapView`) depend on:
  - **Map overlays**: `BreadcrumbTrailOverlay`, `MeasurementOverlay`, `OfflineTileOverlay`, `UnitTrailOverlay`, `VideoMapOverlay`, `CompassOverlay`, `RangeBearingOverlay`, `MGRSGridOverlay`.
  - **Marker classes**: `CustomMarkerAnnotation`, `EnhancedCoTMarker`, `MarkerAnnotationView`.
  - **Map state**: `MapStateManager`.
  - UI features: `RadialMenuMapOverlay`, `MapContextMenus`.

- Tile sources:
  - `ArcGISTileSource.swift` → ArcGIS REST + `ArcGISFeatureService/PortalService`.
  - `OfflineTileCache.swift` + `TileDownloader.swift` → offline tile storage; depend on `OfflineMapModels` and network.

- Overlays depend on:
  - Domain models (`TrackModels`, `MeasurementModels`, `OfflineMapModels`, etc.)
  - Services (`TrackRecordingService`, `MeasurementService`, `OfflineMapManager`).

MapLibre integration on iOS side appears mainly in the Valdi-based UI (`modules/omnitak_mobile/ios/maplibre`), but the native Swift app uses Apple map frameworks and ArcGIS plus overlays.

#### CoT subsystem internal dependencies

Location: `CoT/`, `CoT/Generators`, `CoT/Parsers`.

Dependencies:

- `CoTEventHandler.swift`
  - Central CoT dispatcher; receives parsed CoT events from `CoTMessageParser`.
  - Depends on:
    - `TAKService` (incoming stream from network).
    - `ChatManager`, `TeamService`, `TrackRecordingService`, `GeofenceService`, etc.
    - `CoTFilterManager` + `CoTFilterCriteria`.

- Generators:
  - `ChatCoTGenerator` → `ChatModels`, `ChatService`.
  - `MarkerCoTGenerator` → `PointMarkerModels`, map marker integration.
  - `GeofenceCoTGenerator` → `GeofenceModels`.
  - `TeamCoTGenerator` → `TeamModels`.

- Parsers:
  - `ChatXMLParser`, `ChatXMLGenerator` parse/generate specific GeoChat XML; used by `ChatService`.

#### Meshtastic subsystem internal dependencies

Location: `Meshtastic/`.

- `MeshtasticProtoMessages.swift`
- `MeshtasticProtobufParser.swift`
- `MeshtasticModels.swift` (in `Models/`)

Dependencies:

- Rust `omnitak-meshtastic` crate defines protobuf & FFI for radio integration.
- `MeshtasticManager` uses these files to integrate with:
  - USB/BLE or external connections (on iOS via `MeshtasticBridge.swift` in `modules/omnitak_mobile/ios/native`).
  - UI views: `MeshTopologyView`, `MeshtasticConnectionView`, `MeshtasticDevicePickerView`.

#### Utilities & Converters

Location: `Utilities/…`

- Calculators:
  - `MeasurementCalculator.swift` → used by `MeasurementService` & overlays.

- Converters:
  - `MGRSConverter.swift`, `BNGConverter.swift` → used across:
    - Map overlays (grid, range rings),
    - Views showing coordinates (`CoordinateDisplayView`),
    - Services needing coordinate formats.

- Integration:
  - `KMLMapIntegration.swift`, `KMLOverlayManager.swift` → integrate KML/KMZ import into map overlays.
  - `KMLParser.swift`, `KMZHandler.swift` (Parsers).

- Network:
  - `MultiServerFederation.swift` (multi‑server TAK federation) → used by `ServerManager`, `TAKService`.
  - `NetworkMonitor.swift` → used by network‑dependent services to detect connectivity.

#### Plugin system linkage

- `modules/omnitak_plugin_system/ios`:
  - `OmniTAKPlugin.swift`, `PluginAPIs.swift`, `PluginLoader.swift`, `PluginManifest.swift`, `PluginPermissions.swift`.
- `apps/omnitak/OmniTAKMobile/Views/PluginsListView.swift`:
  - Depends on plugin loader APIs to list installed plugins and present UI.

Plugins likely:

- Depend on `PluginAPIs` interfaces (map access, CoT send/receive, UI hooks).
- Are loaded dynamically (e.g., as .plugin bundles signed & packaged per `plugin-template`).

## External Libraries Analysis

### Swift / iOS

Key external libraries (from `DEPENDENCIES.md`, xcframeworks, and code layout):

- **MapLibre GL Native (iOS)**  
  Version: `6.8.0` (via http_archive or xcframework)  
  Used in:
  - `modules/omnitak_mobile/ios/maplibre/SCMapLibreMapView.*`
  - `modules/omnitak_mobile/src/valdi/omnitak/services/MapLibreIntegration.ts` (JS wrapper).
  - For **Valdi‑based UI** (Map screen with MapLibre).  
  Not heavily used in the pure Swift app – map overlays there appear MapKit/ArcGIS-based.

- **ArcGIS**  
  Not an explicit pod, but:
  - `ArcGISFeatureService.swift`, `ArcGISPortalService.swift`, `ArcGISModels.swift` show REST integration.
  - The app acts as an HTTP client to ArcGIS Online / Enterprise endpoints.

- **Rust FFI (omnitak-mobile)**  
  - `apps/omnitak/OmniTAKMobile.xcframework` includes headers:
    - `callbacks.rs`, `connection.rs`, `error.rs`, `lib.rs` in `ios-arm64/Headers/src`.
  - Underlying crate: `crates/omnitak-mobile` (and `omnitak-cert`, `omnitak-core`, `omnitak-cot`, `omnitak-client`, `omnitak-meshtastic`).
  - This provides:
    - CoT/TLS client connections,
    - Certificate enrollment,
    - Meshtastic integration,
    - Core TAK representations.

- **Valdi runtime (iOS)**  
  - `valdi`, `valdi_core` Objective‑C and C++ libs; bridging via `OmniTAKMobile-Bridging-Header.h` when used.
  - Supplies JS runtimes (QuickJS, Hermes, V8) and UI runtime; used more by the `modules/omnitak_mobile` Valdi app than by the Swift app directly.

### Android (MapLibre, geospatial, etc.)

From `DEPENDENCIES.md` & `modules/omnitak_mobile/android/build.gradle` (described in docs):

- **MapLibre Android SDK**  
  `org.maplibre.gl:android-sdk:11.5.2`  
  `org.maplibre.gl:android-sdk-turf:11.5.2`  
  Used for map rendering and geospatial functions in the Android app / Valdi map view (`MapLibreMapView.kt`).

- **JTS Topology Suite**  
  `org.locationtech.jts:jts-core:1.19.0`  
  Used for geometry operations; likely in route/measurement services on Android side.

- **GeoPackage Android**  
  `mil.nga.geopackage:geopackage-android:6.7.4`  
  Used for offline geospatial data (GeoPackages) on Android.

- **OkHttp / Okio**  
  `com.squareup.okhttp3:okhttp:4.12.0`, `com.squareup.okio:okio:3.6.0`  
  HTTP client stack (ArcGIS, custom APIs, tile downloads) on Android.

- **Glide**  
  `com.github.bumptech.glide:glide:4.16.0`  
  Used for image loading (markers, icons) on Android.

- **Kotlin Coroutines**  
  `org.jetbrains.kotlinx:kotlinx-coroutines-* :1.7.3`  
  Async tasks for services & networking.

- **Google Play Services Location**  
  `com.google.android.gms:play-services-location:21.0.1`  
  GPS and location updates support.

### JavaScript / TypeScript

From root `package.json` and Valdi modules:

Root `package.json` dependencies:

```json
{
  "dependencies": {
    "@mapbox/vector-tile": "^2.0.3",
    "@turf/turf": "^7.1.0",
    "geojson": "^0.5.0",
    "maplibre-gl": "^4.7.1",
    "milsymbol": "^2.2.0",
    "pbf": "^4.0.1"
  }
}
```

Usage:

- **maplibre-gl (4.7.1)**  
  - Used in web demo / tooling and likely for map rendering in `modules/omnitak_mobile` when running in web or dev mode.

- **milsymbol (2.2.0)**  
  - Used to generate MIL‑STD‑2525 symbols:
    - On JS side: `modules/omnitak_mobile/src/valdi/omnitak/services/SymbolRenderer.ts`.
    - On Swift side, MIL‑STD‑2525 symbol handling is encapsulated in `UI/MilStd2525/MilStd2525Symbols.swift` (not using milsymbol directly).

- **@turf/turf**, `geojson`, `@mapbox/vector-tile`, `pbf`  
  - Used for vector tile manipulation, geospatial ops, and decoding MBTiles/protobuf‑encoded vector layers.
  - These support offline or custom vector overlays in MapLibre (Valdi map stack).

Dev dependencies:

- **@typescript-eslint/*, eslint**  
  - Linting and code quality for TS/JS modules.

### Third‑party C++ / native libs (common)

In `/third-party` and `/snap_drawing`, `/valdi_core`:

- `boost`, `fmt`, `rapidjson`, `protobuf_cpp`, `sqlite`, `zlib`, `zstd`, `harfbuzz`, `icu`, `libjpeg_turbo`, `libpng`, `skia`, `yoga`, `quickjs`, `v8`, `websocketpp`, `xxhash`, `mapbox_geometry`, `mapbox_variant`, `resvg`, etc.

These underpin:

- The **Valdi runtime** (JS engines, layout, networking).
- **snap_drawing** 2D/animation engine used by Valdi for UI rendering.
- **Valdi Protobuf** for on‑device message parsing.

OmniTAKMobile uses these indirectly through:

- `Valdi` iOS runtime libraries (if Valdi‑based components are embedded).
- But the Swift‐only OmniTAKMobile is mostly insulated from their APIs.

### Rust crates

In `/crates`:

- `omnitak-core` — core TAK data types and logic.
- `omnitak-cot` — CoT protocol support.
- `omnitak-client` — TAK client logic.
- `omnitak-cert` — certificate enrollment and management.
- `omnitak-meshtastic` — Meshtastic radio integration (protobuf definitions, FFI).
- `omnitak-mobile` — FFI surface (callbacks.rs, connection.rs, enrollment_ffi.rs, error.rs).
- `omnitak-server` — TAK-compatible server (Axum, Tokio, TLS).

From `api_analysis.md`:

- `omnitak-server` uses:
  - **Tokio** runtime for async IO.
  - **Axum** for HTTP endpoints.
  - TLS libraries (likely `rustls` or OpenSSL; see `tls.rs`).
  - `serde`, `serde_json` for JSON serialization.

These crates are linked into:

- iOS and Android mobile apps via the `OmniTAKMobile.xcframework` and JNI on Android (through `modules/omnitak_mobile/android/native`).

## Service Integrations

### TAK / Marti / CoT Server

- **Outbound from mobile**:
  - `TAKService` uses Rust `omnitak-client` via `omnitak-mobile.h` to establish:
    - TCP connections on **8087** (default) for CoT.
    - TLS connections on **8089** using certificate from `CertificateManager`.
  - Sends CoT XML messages composed by:
    - `ChatCoTGenerator`, `MarkerCoTGenerator`, `TeamCoTGenerator`, `GeofenceCoTGenerator`, etc.

- **Inbound to mobile**:
  - CoT XML from server is received in Rust, passed into Swift callback (FFI `callbacks.rs`).
  - `CoTMessageParser.swift` parses XML into domain objects.
  - `CoTEventHandler.swift` dispatches to:
    - `ChatManager` for chat events.
    - `TeamService` for team updates.
    - `TrackRecordingService` for position updates.
    - `GeofenceService`, `EmergencyBeaconService`, etc.

- **Marti REST endpoints** (from `omnitak-server`):
  - `/Marti/api/version` — used by clients to probe server compatibility (`ElevationAPIClient` or `TAKService` may call this).
  - `/Marti/api/clientEndPoints` — currently returns empty clients; placeholder for future.

### ArcGIS

- **ArcGISFeatureService.swift**
  - Talks to ArcGIS REST feature services; expects standard endpoints with query, feature updates.

- **ArcGISPortalService.swift**
  - Integrates with ArcGIS Portal (list web maps, layers).
  - Bound to `ArcGISPortalView.swift`.

Used by:

- `OfflineMapManager` (, `OfflineMapsView.swift`).
- Map overlays that use ArcGIS imagery or vector layers.

### Elevation / Terrain APIs

- **ElevationAPIClient.swift** (Swift level)
- **ElevationAPIClient.swift** in `apps/omnitak/OmniTAKMobile` (file name: `ElevationAPIClient.swift` and service `ElevationProfileService.swift`).

Integration points:

- `ElevationProfileService` uses `ElevationAPIClient` to obtain elevation profiles given routes or polylines.
- `TerrainVisualizationService` may use the same API for shading/LOS calculations.

The API is generic HTTP; implementation details (which vendor) are in that file.

### Meshtastic

- **Rust side**:
  - `crates/omnitak-meshtastic` uses a `meshtastic.proto` to handle radio messages.

- **iOS side**:
  - `MeshtasticBridge.swift` (in `modules/omnitak_mobile/ios/native`) bridges to Rust FFI and/or local radios.
  - `MeshtasticProtobufParser.swift`, `MeshtasticProtoMessages.swift` parse protobuf messages.

- **JS side (Valdi)**:
  - `MeshtasticService.ts` in `modules/omnitak_mobile/src/valdi/omnitak/services`.

Used by:

- `MeshtasticManager` & `Meshtastic` Swift views (`MeshtasticConnectionView`, `MeshTopologyView`).

### MapLibre & Map tiles

- **MapLibre on iOS** (via Valdi):
  - `SCMapLibreMapView` Objective‑C wrapper around MapLibre GL.
  - JS service `MapLibreIntegration.ts` acts as high‑level map API in Valdi UI.

- **Map tiles / offline maps**:
  - `OfflineTileCache.swift`: local tile management.
  - `TileDownloader.swift`: downloads map tiles, likely from:
    - MapLibre tile endpoints (XYZ/WMTS) or
    - ArcGIS services.
  - `OfflineMapModels.swift` describe tile regions, caching policy.

### Military symbology (MIL‑STD‑2525)

- **JS/TS**: `milsymbol` library is primary symbol renderer for map overlays in Valdi UI.
- **Swift**: `MilStd2525Symbols.swift` implements MIL‑STD‑2525 symbolization on iOS side (no direct milsymbol dependency).

Used by:

- `MilStd2525MarkerView`, `MilStd2525SymbolView`.
- Map overlays rendering 2525 markers.

### Plugin system

- **Plugin loader** on iOS:
  - `PluginLoader.swift` loads plugin bundles according to `PluginManifest.swift`.
  - Plugin capabilities defined in `PluginAPIs.swift` (map overlay registration, CoT hooks, new tools).
  - Security/permissions gating via `PluginPermissions.swift`.

- **Plugin template**:
  - `plugin-template` provides a ready skeleton with `PluginMain.swift`, `plugin.json`, and scripts for build/signing.

OmniTAKMobile integrates this via:

- `PluginsListView.swift` — lists installed plugins and allows enabling/disabling them.
- Plugins can depend on `PluginAPIs` which exposes services like `TAKService`, `MapStateManager`, etc.

## Dependency Injection Patterns

### Swift / OmniTAKMobile

Patterns described in `Architecture.md` and seen implicitly:

1. **Initializer/Configurator injection**

   - Services and managers are created centrally in app startup and passed into dependents.

   ```swift
   func configure(takService: TAKService, chatManager: ChatManager) {
       self.takService = takService
       self.chatManager = chatManager
   }
   ```

   - This pattern appears in service/handler classes (e.g., `CoTEventHandler`).

2. **SwiftUI environment-based injection**

   - `OmniTAKMobileApp` creates core managers as `@StateObject` and exposes them via `@EnvironmentObject` to Views:

   ```swift
   @main
   struct OmniTAKMobileApp: App {
       @StateObject private var chatManager = ChatManager(...)
       @StateObject private var serverManager = ServerManager(...)

       var body: some Scene {
           WindowGroup {
               ContentView()
                   .environmentObject(chatManager)
                   .environmentObject(serverManager)
           }
       }
   }
   ```

   - Views then:

   ```swift
   struct ChatView: View {
       @EnvironmentObject var chatManager: ChatManager
   }
   ```

3. **Singleton / shared instance (limited)**

   - Some services may expose `shared` static instances (e.g., `TAKService.shared`) as visible in docs:

   ```swift
   TAKService.shared.send(cotMessage: message.cotXML)
   ```

   - This reduces explicit DI but is convenient for cross‑feature usage; it couples code to the concrete type.

4. **Protocol-based abstraction**

   - Protocols define interfaces for testability and pluggability (e.g., `CoTMessageGenerator`).
   - Actual implementations (e.g., `ChatCoTGenerator`) are injected into handlers or services that depend only on the protocol.

5. **Rust FFI injection**

   - The Rust FFI types (e.g., `omnitak_mobile_connection_t`) are wrapped in Swift classes and injected into `TAKService` / `CertificateEnrollmentService`.

### Valdi / TS / Node side

1. **Provider / GlobalProviderSource**

   - In `src/valdi_modules/src/valdi/valdi_core/src/provider/*`, DI is built around **providers** and `ProviderKey`s.
   - UI components access dependencies via providers, decoupling them from concrete implementations.

2. **Module loader and factories**

   - `ModuleLoader.ts` and `ModuleFactory` (in `valdi_core`) manage loading of JS modules and creating instances.
   - Many Valdi modules export **ModuleFactory** objects that declare what services/components they provide.

3. **Worker services**

   - `worker` module defines `WorkerService` and `IWorkerService` to run background computations; DI is via service registration and message passing.

4. **Native modules**

   - Bridge modules (HTTP client, Persistence, FileSystem, Protobuf) are injected into JS runtime as modules, not imported directly from platform-specific code.

### Rust server (`omnitak-server`)

- Uses **constructor injection**:
  - `marti::create_router()` builds an Axum `Router` with `MartiState` attached via Axum’s `Extension<Arc<MartiState>>`.
- Other components (`CotRouter`, TLS config) are wired together in `server.rs` via `TakServer::new(config)`.

## Module Coupling Assessment

### OmniTAKMobile Swift

**Cohesion: high within features**

- Each folder is strongly feature‑oriented:
  - `Services/` — pure business logic and integration.
  - `Managers/` — viewmodel state, one per feature.
  - `Views/` — UI per feature.
  - `Map/`, `CoT/`, `Meshtastic/`, `Utilities/`, `Storage/` — cohesive subsystems.

**Coupling patterns:**

- **Views → Managers** (OK, one‑directional).
- **Managers → Services / Storage / Utilities / Models** (intended).
- **Services → CoT / Rust / Network / Models**.
- **CoTEventHandler** is a *hub*:
  - Depends on many services and managers.
  - All CoT‑driven features converge there → high fan‑in and fan‑out.

- **TAKService** is another *central hub*:
  - All CoT send/receive goes through it.
  - Interacts with certificate, multi‑server federation, and CoTEventHandler.

Potential tight couplings:

- `TAKService` knows about higher‑level services (`ChatService`, `TeamService`, etc.) via callbacks or event routing; this can blur layers.
- `CoTEventHandler` may have methods referencing many concrete services (`ChatManager`, `TeamService`, `RoutePlanningService`, etc.), which makes it hard to split features.
- Some managers may directly know about map controllers/overlays (via delegates), binding UI behavior tightly to service decisions.

### Valdi / modules/omnitak_mobile

**Modules:**

- UI entry: `modules/omnitak_mobile/src/index.ts`
- Feature screens: `screens/*`
- Services: `services/*` (`CotParser`, `MapLibreIntegration`, `MarkerManager`, `MeshtasticService`, `MultiServerFederation`, `SymbolRenderer`, `TakService`).

**Coupling:**

- `services/TakService.ts` binds Valdi UI to the same backend protocols as Swift `TAKService`.
- `MapLibreIntegration` depends on MapLibre JS API and also interacts with `MarkerManager` and `SymbolRenderer`.

Cohesion is good per module, but:

- `TakService.ts` and `CotParser.ts` are central for protocol handling similar to Swift `TAKService` and `CoTMessageParser`.
- `MultiServerFederation.ts` and `MultiServerFederation.swift` implement the same concept in different stacks; they must be kept in sync manually.

### Rust crates

- `omnitak-core` and `omnitak-cot` are well‑factored domain libraries.
- `omnitak-mobile` is a thin FFI wrapper; it couples Rust domain to platform FFI but is small.
- `omnitak-server` couples CoT routing, Marti HTTP, and TLS, but modules (`router`, `marti`, `tls`, `server`) are separated and interact mostly through interfaces.

## Dependency Graph

### High-Level (OmniTAKMobile Swift)

```text
SwiftUI Views
   |
   v
Managers (ObservableObject) ----> Storage (ChatPersistence, RouteStorageManager, TeamStorageManager)
   |                                    ^
   |                                    |
   v                                    |
Services ------------------------------> Models
   |
   +---> CoT subsystem (CoTMessageParser, CoTEventHandler, *CoTGenerators, *XML Parsers)
   |
   +---> Map subsystem (Map controllers, overlays, tile sources)
   |
   +---> Meshtastic subsystem
   |
   +---> Utilities (Converters, Calculators, NetworkMonitor, MultiServerFederation)
   |
   +---> External APIs (ArcGIS, Elevation API, media, file system)
   |
   +---> Rust FFI (omnitak-mobile, omnitak-cert, omnitak-meshtastic)
```

### Cross‑stack overview

```text
[Swift UIKit/SwiftUI]        [Valdi (TS/JS)]                   [Rust]
       |                           |                            |
       |                           |                            |
       |                 Valdi runtime & bridges                |
       |-----------------------> valdi / valdi_core <-----------|
       |                           |                            |
OmniTAKMobile Swift app      Valdi modules/omnitak_mobile       |
 (Views/Managers/Services)         (App.tsx, services)          |
       |                           |                            |
       |                           v                            |
       |                   TakService.ts / CotParser.ts         |
       |                           |                            |
       v                           v                            v
          ----> FFI bridge to omnitak-mobile / omnitak-core / omnitak-cot
                             (CoT, TLS, Meshtastic client)
```

### Rust TAK server

```text
Clients (OmniTAKMobile, others)
   |
   v
[omnitak-client crate]  -- TCP/TLS CoT -->
[omnitak-server::server] --> CotRouter --> fan-out to other clients

Marti HTTP:
omnitak-server::marti (Axum Router)
  - /Marti/api/version
  - /Marti/api/clientEndPoints
```

## Potential Dependency Issues

1. **Centralized CoTEventHandler coupling**

   - `CoTEventHandler.swift` is likely aware of many domain services and managers.
   - This can create a "god object" that:
     - Is difficult to test in isolation.
     - Needs modification whenever new CoT-based feature is added.
   - **Mitigation:**  
     - Introduce CoT **event bus** or `CoTEventListener` protocol.
     - Register feature-specific listeners (Chat, Team, Track, Geofence) instead of hardcoding dependencies.

2. **TAKService as global singleton**

   - Usage of `TAKService.shared` couples code directly to concrete service and global state.
   - Complex connection logic plus multi-server logic plus CoT send/receive all live in one service.
   - **Mitigation:**
     - Extract interfaces (`ITakConnection`, `ICotSender`) and inject them.
     - Keep `TAKService` as façade but have smaller internal services.

3. **Duplicate feature stacks (Swift vs. Valdi)**

   - Features like:
     - `MultiServerFederation.swift` vs `MultiServerFederation.ts`
     - `TakService.swift` vs `TakService.ts`
     - MapLibre integration in Swift (Map controllers) vs TS (`MapLibreIntegration.ts`).
   - Risk:
     - Diverging behavior / protocol handling.
   - **Mitigation:**
     - Where possible, move shared logic into Rust (`omnitak-core` / `omnitak-cot`) or a common TS/Swift spec.
     - Keep behavior documented and tested in one place.

4. **Tight coupling between services and map overlays**

   - Overlays like `BreadcrumbTrailOverlay`, `UnitTrailOverlay`, `VideoMapOverlay` may directly query services (`TrackRecordingService`, `VideoStreamService`).
   - Blurs boundaries between visualization and business logic.
   - **Mitigation:**
     - Have overlays observe view models or pass in data via model objects instead of reaching into services directly.

5. **Plugin API surface area**

   - `PluginAPIs.swift` likely exposes powerful capabilities (map access, CoT send/receive, file system).
   - If not carefully segmented and versioned, changes in core services may break plugins.
   - **Mitigation:**
     - Define stable, minimal plugin interfaces.
     - Wrap internal services in façade interfaces that can evolve internally.

6. **Rust FFI boundaries**

   - `omnitak-mobile` FFI defines a narrow bridge but:
     - If Rust crates change, headers need to be regenerated and xcframework rebuilt.
   - **Mitigation:**
     - Keep FFI surface small and versioned.
     - Use opaque handles for connections and avoid baking internal types into FFI.

7. **Potential circular dependency candidates**

   Although not explicitly visible without scanning imports, likely suspects:

   - Map subsystem ↔ Managers ↔ Services:
     - e.g., `MapStateManager` might know about `WaypointManager`, while `WaypointManager` uses map callbacks.
   - CoT → Services → TAKService → CoT:
     - Ensure that `CoTEventHandler` and `TAKService` don't reference each other directly in multiple directions without clear layering.

   **Mitigation:**
   - Enforce directional layering:
     - CoT parsing → events → listeners; network service stays below them.
     - Map rendering listens to managers but managers don't own controllers.

8. **Shared configuration scattered**

   - Server addresses, port numbers, TLS options, and API base URLs (ArcGIS, elevation) may be hardcoded in multiple components (Swift, TS, Rust).
   - **Mitigation:**
     - Centralize configuration into a `Config` / `Settings` layer used by both services and UI.
     - Ensure environment-based configuration where feasible.

---

This analysis is based on the actual files and documentation present in the repository (`Architecture.md`, `.ai/docs/*`, `DEPENDENCIES.md`, and the visible directory structure).