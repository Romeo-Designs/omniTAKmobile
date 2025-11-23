# Project Guide

This document provides a developer-focused guide to the OmniTAK Mobile iOS application located at `apps/omnitak`. It is written for engineers who are new to this codebase and need to get productive quickly.

The content is organized around:

1. High-level overview
2. Main features and flows
3. Integrations and dependencies
4. Internal architecture
5. Extension points and customization
6. Operational notes

---

## 1. High-Level Overview

### 1.1 What the Application Does

OmniTAK Mobile is an iOS Swift/SwiftUI client for the **TAK (Tactical Assault Kit)** ecosystem. It acts as a mobile situational awareness and collaboration tool, focused on:

- Connecting to **TAK servers** over TCP/UDP/TLS.
- Sending and receiving **Cursor-on-Target (CoT) XML messages** (position reports, chat, markers, alerts, teams, etc.).
- Presenting a rich, interactive **map-based UI** with overlays, unit markers, measurements, tracks, offline maps, and tactical tools.
- Providing **chat**, **mission/data package**, **offline map**, **video stream**, and **Meshtastic radio** integrations.
- Integrating with external services like **ArcGIS** and **elevation APIs** for spatial analysis.

In other words, this app is a full-featured TAK client tailored for iOS, built on SwiftUI and a strongly modular architecture.

### 1.2 Primary Domains / Business Areas

The main business domains the app covers are:

- **TAK Connectivity & CoT Messaging**
  - Maintaining connections to TAK servers (TLS, TCP, UDP).
  - Encoding and decoding CoT XML.
  - Broadcasting own position, receiving others’ positions, markers, and events.

- **Geospatial Visualization & Tools**
  - 2D/3D map display with overlays and military symbology (MIL-STD-2525).
  - Measurement tools (distance, area, range/bearing).
  - Routes, waypoints, tracks, line-of-sight, elevation profiles.
  - Offline maps and tile caching.

- **Collaboration & Communication**
  - GeoChat messaging (text + attachments).
  - Digital pointer, emergency beacons, SPOTREP/SALUTE/MEDEVAC-style reports.
  - Team membership and contact management.

- **Data & Mission Packages**
  - Importing/exporting KML/KMZ and TAK data packages.
  - Mission package sync and management.

- **External Integrations**
  - ArcGIS Portal/Online (authentication, item search, feature access).
  - Elevation and terrain analysis APIs.
  - Meshtastic radios (mesh network integration).

---

## 2. Main Features and Flows

This section outlines the primary user journeys and the technical flows behind them, focusing on triggers, involved modules, and key data.

### 2.1 TAK Server Connection & CoT Transport

**User journey:** Configure a TAK server and connect, maintaining a live CoT session.

#### Trigger

- SwiftUI screens:
  - `TAKServersView.swift` – list/manage servers.
  - `ServerPickerView.swift` / `QuickConnectView.swift` – select or create connection.
  - `SettingsView.swift` / `NetworkPreferencesView.swift` – tweak network options.
- User taps “Connect”, “Disconnect”, or chooses a server.

#### Key Components

- Views: `TAKServersView`, `ServerPickerView`, `QuickConnectView`, `ContentView` / `ATAKToolsView` (top-level connection indicators).
- Manager: `ServerManager` – owns `TAKServer` definitions & active server.
- Services:
  - `TAKService` – high-level CoT networking service.
  - `DirectTCPSender` (inner class in `TAKService.swift`) – low-level TCP/UDP/TLS.
  - `CertificateManager` – client certificate discovery and selection.
  - `CertificateEnrollmentService` – enrollment when needed.
- Models:
  - `TAKServer` – connection config (name, host, port, protocol, TLS flags).
  - `TAKCertificate` – certificate metadata.

#### Data Flow

1. **Configuration**
   - `ServerPickerView` binds to `ServerManager.shared.servers` and `activeServer`.
   - When adding/updating servers, `ServerManager` persists via `UserDefaults` (using `Codable` `TAKServer`).

2. **Connect**
   - View invokes something like:

     ```swift
     takService.connect(
         host: server.host,
         port: server.port,
         protocolType: server.protocolType,
         useTLS: server.useTLS,
         certificateName: server.certificateName,
         certificatePassword: server.certificatePassword
     )
     ```

   - `TAKService` constructs and configures `DirectTCPSender`:
     - Sets `onMessageReceived` to point back to `TAKService`.
     - Sets `onConnectionStateChanged` to update `@Published isConnected` / `connectionStatus`.

3. **TLS & Certificates** (if enabled)
   - `DirectTCPSender.connect` loads a `.p12` identity with:
     - `CertificateManager.shared.certificates` / Keychain.
     - `Documents/Certificates/<name>.p12`.
     - Fallback to app bundle.
   - It creates an `NWConnection` using `NWProtocolTLS` options with:
     - Custom cipher suite list.
     - Optional legacy TLS 1.0 support (`allowLegacyTLS`).
     - A permissive verify block (accept all server certificates, appropriate for TAK’s self-signed certs).

4. **Connection Lifecycle**
   - `NWConnection.stateUpdateHandler` updates connection status.
   - On `.ready`:
     - `onConnectionStateChanged(true)` – `TAKService` sets `isConnected = true`.
     - `startReceiveLoop()` begins reading bytes.
   - On `.failed` or `.cancelled`:
     - `onConnectionStateChanged(false)` – `isConnected = false`, may trigger reconnect logic.

5. **Sending CoT**
   - Other services (chat, position, etc.) invoke `TAKService.send(cotMessage:)` with XML string.
   - `TAKService` updates counters (`messagesSent`, `bytesSent`) and calls `DirectTCPSender.send(data:)`.
   - `DirectTCPSender` sends via `NWConnection.send` and logs any errors.

6. **Receiving CoT**
   - `DirectTCPSender` accumulates bytes from `NWConnection.receive` into `receiveBuffer`.
   - It uses parsing helpers (documented in `docs/Features/Networking.md`) to extract complete CoT XML messages.
   - For each valid message:
     - `onMessageReceived(xmlString)` is called on the main queue.
     - `TAKService` increments `messagesReceived` / `bytesReceived` and forwards to `CoTMessageParser` / `CoTEventHandler`.

### 2.2 Map & Situational Awareness

**User journey:** View self and team units on a map, with overlays, context menus, and tools.

#### Trigger

- App launch: `OmniTAKMobileApp` creates window with `ATAKMapView` (root map/tooling view).
- User navigates within `ATAKToolsView`, interacting with map controls.

#### Key Components

- Entry: `OmniTAKMobile/Core/OmniTAKMobileApp.swift`, `ContentView.swift`, `ATAKToolsView.swift`.
- Map controllers: `MapViewController`, `EnhancedMapViewController`, `Map3DViewController`, `IntegratedMapView`, `EnhancedMapViewRepresentable`, `MapContextMenus`, `MapOverlayCoordinator`, `MapStateManager`.
- Map overlays: `BreadcrumbTrailOverlay`, `CompassOverlay`, `MGRSGridOverlay`, `MeasurementOverlay`, `OfflineTileOverlay`, `RangeBearingOverlay`, `TrackOverlayRenderer`, `UnitTrailOverlay`, `VideoMapOverlay`.
- Markers: `CustomMarkerAnnotation`, `EnhancedCoTMarker`, `MarkerAnnotationView`.
- Managers: `MeasurementManager`, `OfflineMapManager`, `WaypointManager`, `GeofenceManager`, `DrawingToolsManager`, etc.
- Services: `MeasurementService`, `BreadcrumbTrailService`, `RangeBearingService`, `TrackRecordingService`, `OfflineMapManager`/tile services, `ArcGISFeatureService`.
- Models: `EnhancedCoTMarker`, `Track`, `Waypoint`, `MeasurementModels`, `OfflineMapModels`, `ArcGISModels`, etc.

#### Data Flow

1. **UI ↔ UIKit Bridge**

   ```swift
   struct EnhancedMapViewRepresentable: UIViewControllerRepresentable {
       func makeUIViewController(context: Context) -> EnhancedMapViewController { ... }
       func updateUIViewController(_ vc: EnhancedMapViewController, context: Context) { ... }
   }
   ```

   - SwiftUI hosts `EnhancedMapViewRepresentable`, which embeds UIKit map controllers.
   - `MapStateManager` coordinates map state (zoom, layers, selected markers) and is shared with SwiftUI.

2. **Inbound CoT Position/Markers**
   - `TAKService` → `CoTMessageParser.parse(xml:)` → `CoTEventType.positionUpdate(CoTEvent)` / `CoTEventType.waypoint(CoTEvent)`.
   - `CoTEventHandler` maps `CoTEvent` to `EnhancedCoTMarker` or other models and dispatches to map-related services/managers.
   - `MapOverlayCoordinator` updates overlays and annotations on the map.

3. **Map Interactions to Domain**
   - Tapping/long-pressing the map triggers methods in `MapViewController`:
     - Dropping waypoints: `WaypointManager.addWaypoint(...)`.
     - Starting measurements: `MeasurementManager.startMeasurement(...)`.
     - Drawing tools: `DrawingToolsManager.setMode(...)`.
   - Managers call corresponding Services to create domain entities and, if necessary, emit CoT (marker, geofence, digital pointer, etc.).

4. **Offline Maps**
   - `OfflineMapView` ↔ `OfflineMapManager` for region selection, package list, and download.
   - `OfflineTileOverlay` and `OfflineTileCache` serve tiles to the map from disk.

### 2.3 Chat (GeoChat)

**User journey:** Send and receive chat messages, including attachments and location, with TAK peers.

#### Trigger

- SwiftUI Views:
  - `ChatView.swift` – top-level chat list.
  - `ConversationView.swift` – specific conversation messages.
  - `ContactListView.swift`, `ContactDetailView.swift` – selecting recipients.
  - `PhotoPickerView.swift` – attaching images.
- User sends a message or opens a conversation; the app receives incoming GeoChat messages via TAK.

#### Key Components

- Managers: `ChatManager` (primary UI-facing state), possibly also `TeamService` / `TeamManager` for recipients.
- Services: `ChatService`, `PhotoAttachmentService`, `TAKService`.
- CoT: `ChatCoTGenerator`, `ChatXMLParser`, `ChatXMLGenerator`.
- Storage: `ChatPersistence`, `ChatStorageManager`.
- Models: `ChatMessage`, `Conversation`, `ChatParticipant`, `ImageAttachment`, `QueuedMessage`.

#### Outbound Flow (Send Message)

1. **User Action**

   ```swift
   // In ConversationView
   Button("Send") {
       chatManager.sendMessage(text: draftText, to: selectedParticipant)
   }
   ```

2. **Manager Layer (`ChatManager`)**
   - Validates non-empty text, selects conversation, updates optimistic UI.
   - Delegates to `ChatService` for actual sending.

3. **Service Layer (`ChatService`)**
   - Builds a `ChatMessage` model with `status = .pending`.
   - Uses `ChatCoTGenerator` to create GeoChat CoT XML:

     ```swift
     let xml = ChatCoTGenerator.generateGeoChat(from: message, location: currentLocation)
     ```

   - Wraps the message and XML into a `QueuedMessage`.
   - Stores via `ChatStorageManager` and enqueues for sending.

4. **Transport (`TAKService`)**
   - When connected, `ChatService`/`ChatManager` call `TAKService.send(cotMessage: xml)`.
   - On success, `ChatMessage.status` transitions to `.sent` / `.delivered`.
   - On failure, `QueuedMessage.status` set to `.failed`, enabling retry.

#### Inbound Flow (Receive Message)

1. **CoT Parsing**
   - `TAKService` receives XML → `CoTMessageParser.parse(xml:)`.
   - For type `b-t-f` (GeoChat), parser calls `parseChatMessage(xml:)`.
   - `ChatXMLParser.parseGeoChatMessage(xml:)` uses `XMLParser` to produce `ChatMessage`.

2. **Dispatch**
   - `CoTEventHandler` invokes `ChatManager.processIncomingMessage(chatMessage)`.

3. **State & Persistence**
   - `ChatManager`:
     - Inserts `ChatMessage` into corresponding `Conversation.messages`.
     - Updates `unreadCount`, `lastMessage`.
     - Persists via `ChatPersistence` / `ChatStorageManager`.
   - SwiftUI views bound to `ChatManager` update automatically.

### 2.4 Position Broadcast, Tracks, and Breadcrumbs

**User journey:** App continuously broadcasts own position to TAK, records tracks, and displays breadcrumb trails.

#### Trigger

- User enables position broadcast and/or track recording in UI:
  - `PositionBroadcastView.swift`.
  - `TrackRecordingView.swift` / `TrackListView.swift`.

#### Key Components

- Services: `PositionBroadcastService`, `TrackRecordingService`, `BreadcrumbTrailService`, `TAKService`.
- Managers: `MeasurementManager` (for some path-based tools), map managers.
- Models: `Track`, `TrackPoint`, `PositionBroadcastSettings`, `TrackModels.swift`.
- System frameworks: `CoreLocation`.

#### Data Flow

1. **Position Broadcast**
   - `PositionBroadcastService` is configured with `TAKService` and a location manager wrapper.
   - On a timer or distance-based update:
     - Reads current position from `CoreLocation`.
     - Builds a CoT PLI `event` XML with `CoTCoTGenerator` (or inline XML builder).
     - Sends via `TAKService.send(cotMessage:)`.

2. **Track Recording**
   - `TrackRecordingService` listens to location updates.
   - Appends `TrackPoint`s to an in-memory `Track` and persists segments to disk.
   - `BreadcrumbTrailService` exposes track segments to the map overlay.

3. **Inbound Tracks from Others**
   - Inbound CoT `a-` events represent positions of other units.
   - `CoTMessageParser` maps them to `CoTEvent` → `EnhancedCoTMarker`.
   - `UnitTrailOverlay` uses historical positions to render trails.

### 2.5 Offline Maps & ArcGIS Integration

**User journey:** Search ArcGIS Portal, download offline areas, view offline tiles.

#### Trigger

- `ArcGISPortalView.swift` – log in, search for content.
- `OfflineMapsView.swift` – select regions/items for offline use.

#### Key Components

- Services: `ArcGISPortalService`, `ArcGISFeatureService`, `OfflineMapManager`, tile downloaders (`TileDownloader`), `OfflineTileCache`.
- Models: `ArcGISCredentials`, `ArcGISPortalItem`, `ArcGISItemType`, `OfflineMapPackage`.

#### Data Flow

1. **Authentication** (`ArcGISPortalService`) – example pseudo-code:

   ```swift
   func authenticate(username: String, password: String) async throws {
       let url = portalBaseURL.appendingPathComponent("/sharing/rest/generateToken")
       var request = URLRequest(url: url)
       request.httpMethod = "POST"
       request.httpBody = ... // username/password, referer, f=json

       let (data, _) = try await urlSession.data(for: request)
       let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
       self.credentials = ArcGISCredentials(token: tokenResponse.token, ...)
       saveCredentialsToUserDefaults()
   }
   ```

2. **Search Content**
   - `searchContent(query:type:)` issues `/sharing/rest/search` with the stored token.
   - Returns `[ArcGISPortalItem]`, which `ArcGISPortalView` displays.

3. **Offline Downloads**
   - `OfflineMapsView` lets the user pick a portal item or a region.
   - `TileDownloader` uses `URLSession` to fetch tiles, caches via `OfflineTileCache`.
   - `OfflineTileOverlay` reads cached tiles to display offline on the map.

### 2.6 KML/KMZ & Data Packages

**User journey:** Import/export mission data via KML/KMZ or TAK data packages.

#### Trigger

- `DataPackageImportView.swift`, `DataPackageView.swift`, `KMLImportView.swift`.

#### Key Components

- Managers: `DataPackageManager`.
- Utilities: `KMLMapIntegration`, `KMLOverlayManager`, `KMLParser`, `KMZHandler`.
- Models: `DataPackageModels`, KML model classes.

#### Data Flow (KML Example)

1. User selects a KML/KMZ file.
2. `KMLImportView` hands URL to `KMLParser` / `KMZHandler`.
3. Parsed features are converted into internal models (routes, waypoints, overlays).
4. `KMLMapIntegration` and `KMLOverlayManager` add them to the map as overlays.

---

## 3. Integrations and Dependencies

This section focuses on **external** integrations: what they’re used for, where configured, and notable behavior.

### 3.1 TAK Server (CoT over TCP/UDP/TLS)

- **Used for:**
  - Primary tactical data exchange: PLI, chat, markers, alerts, teams, video URLs, mission packages.
- **Key Files:**
  - `OmniTAKMobile/Services/TAKService.swift`.
  - `OmniTAKMobile/CoT/*` (parsing, generation, event handling).
  - `OmniTAKMobile/Managers/ServerManager.swift`.
- **Configuration:**
  - Via UI `TAKServersView`, `ServerPickerView`.
  - Stored in `UserDefaults` (`TAKServer` model) managed by `ServerManager`.

- **Failure Modes & Handling:**
  - Network errors in `NWConnection` yield `.failed` / `.waiting` states.
  - `DirectTCPSender` logs and calls `onConnectionStateChanged(false)`; `TAKService` may trigger reconnect.
  - Receive buffer protections:
    - Warn if buffer > 100 KB, clear if > 1 MB to avoid memory blowups.
  - TLS verification accepts any certificate (expected for TAK), but connection may still fail if handshake fails.
  - Messages can be queued at higher layers (e.g., `ChatStorageManager`) when disconnected.

### 3.2 ArcGIS Portal & Feature Services

- **Used for:**
  - User authentication against ArcGIS.
  - Searching and retrieving content (maps, feature layers).
  - Potentially feeding offline map downloads and feature overlays.

- **Key Files:**
  - `OmniTAKMobile/Services/ArcGISPortalService.swift`.
  - `OmniTAKMobile/Services/ArcGISFeatureService.swift`.
  - `OmniTAKMobile/Models/ArcGISModels.swift`.
  - Views in `OmniTAKMobile/Views/ArcGISPortalView.swift`.

- **Configuration:**
  - Portal base URL, timeouts, and credentials inside `ArcGISPortalService`.
  - Credentials saved to and loaded from `UserDefaults`.

- **Failure Modes & Handling:**
  - HTTP errors or token expiry will surface as thrown errors or `Result` failures; `ArcGISPortalService` clears credentials on `signOut()`.
  - Search and feature calls rely on tokens; failure typically requires re-authentication.

### 3.3 Elevation & Terrain APIs

- **Used for:**
  - Line-of-sight and elevation profile analysis from polylines and points.

- **Key Files:**
  - `OmniTAKMobile/ElevationAPIClient.swift`.
  - `OmniTAKMobile/Services/ElevationProfileService.swift`, `LineOfSightService.swift`, `TerrainVisualizationService.swift`.
  - `OmniTAKMobile/Models/ElevationProfileModels.swift`, `LineOfSightModels.swift`.

- **Configuration:**
  - Base URL and API key (if any) in `ElevationAPIClient`.
  - Typically called from services using `URLSession`.

- **Failure Modes & Handling:**
  - Network errors or invalid responses result in thrown errors; managers should present user-facing failures (e.g., toast or alert) and perhaps fallback to on-device approximations.

### 3.4 Meshtastic Radios

- **Used for:**
  - Integrating with Meshtastic mesh radios to send/receive position and text over radio instead of IP-only TAK.

- **Key Files:**
  - `OmniTAKMobile/Managers/MeshtasticManager.swift`.
  - `OmniTAKMobile/Meshtastic/MeshtasticProtoMessages.swift`, `MeshtasticProtobufParser.swift`.
  - Views: `MeshtasticConnectionView`, `MeshtasticDevicePickerView`, `MeshTopologyView`.

- **Configuration:**
  - Device discovery and serial/BLE connection inside `MeshtasticManager`.

- **Failure Modes & Handling:**
  - Serial/BLE disconnects; manager updates connection state flags.
  - Parsing failures of protobuf messages handled via logging and ignoring bad packets.

### 3.5 Certificates and PKI

- **Used for:**
  - Client authentication to TAK servers over TLS.
  - Secure communications with enterprise services if needed.

- **Key Files:**
  - `OmniTAKMobile/Managers/CertificateManager.swift`.
  - `OmniTAKMobile/Services/CertificateEnrollmentService.swift`.
  - `OmniTAKMobile/Views/CertificateEnrollmentView.swift`, `CertificateManagementView.swift`, `CertificateSelectionView.swift`.

- **Configuration:**
  - Certificates stored in Keychain or app Documents directory.
  - `CertificateManager` exposes available certificates and chosen certificate.

- **Failure Modes & Handling:**
  - Missing or invalid certificate causes TLS handshake failure.
  - Enrollment service may expose errors through UI notifications.

### 3.6 Native Core / Rust xcframework

- **Used for:**
  - Low-level networking or CoT handling not fully visible in Swift.

- **Key Files:**
  - `OmniTAKMobile.xcframework/**/omnitak_mobile.h`.
  - `OmniTAKMobile/Core/OmniTAKMobile-Bridging-Header.h`.

- **Configuration:**
  - Linked as an xcframework in Xcode; Swift code may call C functions exposed in `omnitak_mobile.h`.

- **Failure Modes & Handling:**
  - Any errors raised at this layer are surfaced through Swift wrappers (e.g., `TAKService`), so developers rarely interact with it directly.

---

## 4. Internal Architecture

### 4.1 Layering and Patterns

The app follows a **feature-oriented MVVM** pattern with a clean separation of concerns:

- **Models** (`OmniTAKMobile/Models`)
  - Plain data structures, `Codable`, `Identifiable`, `Equatable`.
  - No knowledge of UI or networking.

- **Services** (`OmniTAKMobile/Services`)
  - Domain and integration layer.
  - Implement business workflows and network calls.
  - Often singletons (`static let shared`).

- **Managers** (`OmniTAKMobile/Managers`)
  - `ObservableObject` ViewModels.
  - Hold `@Published` UI state and orchestrate calls to services and storage.

- **Views/UI** (`OmniTAKMobile/Views`, `OmniTAKMobile/UI/*`)
  - SwiftUI view hierarchies and UIKit map components.
  - Bind to managers via `@StateObject`/`@ObservedObject`/`@EnvironmentObject`.

- **CoT Subsystem** (`OmniTAKMobile/CoT`) – protocol boundary.
  - Parsers & generators isolate XML handling from the rest of code.

- **Map Subsystem** (`OmniTAKMobile/Map`) – spatial visualization.

- **Storage** (`OmniTAKMobile/Storage`) – persistence
  - File-based or `UserDefaults` storage for chats, routes, drawings, teams.

- **Utilities** (`OmniTAKMobile/Utilities`) – cross-cutting helpers.

Patterns worth noting:

- **MVVM** – Managers are ViewModels, services are domain layer.
- **Service Layer** – All external I/O is through Services.
- **Repository-like Storage** – Storage managers abstract persistence for features.
- **Event-driven CoT** – `CoTEventHandler` is a central dispatcher for incoming events.
- **Bridging Pattern** – UIKit map controllers and Rust xcframework are bridged into SwiftUI.

### 4.2 Example: Chat Stack

- Model: `ChatMessage`, `Conversation`, `ChatParticipant`, `QueuedMessage`.
- Storage: `ChatPersistence` (file/database), `ChatStorageManager` (queue + history APIs).
- Service: `ChatService`.
- Manager: `ChatManager`.
- Views: `ChatView`, `ConversationView`, `ContactListView`.
- Transport: `TAKService` + `CoT` subsystem.

Responsibility split:

- **Views** – Render conversations/messages, gather input.
- **ChatManager** – Orchestrates UI state, delegates to `ChatService`.
- **ChatService** – Knows how to turn messages into GeoChat CoT, queue/retry, and call `TAKService`.
- **Storage** – Durable chat history and send queue.

### 4.3 Example: Map Stack

- Models: `EnhancedCoTMarker`, `Route`, `Track`, `Waypoint`, measurement models.
- Services: `MeasurementService`, `RoutePlanningService`, `TrackRecordingService`, `BreadcrumbTrailService`, `ArcGISFeatureService`.
- Managers: `MeasurementManager`, `WaypointManager`, `OfflineMapManager`, `MapStateManager`.
- Views: `ATAKToolsView`, map-related SwiftUI panels.
- Controllers: `MapViewController`, `EnhancedMapViewController`, overlays and marker views.

Responsibility split:

- **Controllers** manage map view state and user interactions on the map.
- **Managers/Services** hold domain state and provide operations.
- **Overlays** render specific aspects (grid, compass, tracks, measurements).

---

## 5. Extension Points and Customization

This section describes how to extend the application in common ways.

### 5.1 Adding a New Feature / View + Logic

**Typical steps:**

1. **Define Models (if needed)**
   - Add a new file under `OmniTAKMobile/Models`, e.g. `NewFeatureModels.swift`.
   - Create `struct`s conforming to `Codable`, `Identifiable`, `Equatable` where appropriate.

2. **Create a Service (domain logic)**
   - Add `NewFeatureService.swift` under `OmniTAKMobile/Services`.
   - Design it to be UI-agnostic and reusable.
   - For networked features, use `URLSession` or `TAKService`.

3. **Add a Manager (ViewModel)**
   - Add `NewFeatureManager.swift` under `OmniTAKMobile/Managers`.
   - Make it `ObservableObject` and expose `@Published` state properties.
   - Inject the service (either via initializer or `.shared`).

4. **Add Views**
   - Add SwiftUI views in `OmniTAKMobile/Views`.
   - Use `@StateObject`/`@ObservedObject` to bind to your manager.

5. **Wire into Navigation/UI**
   - Update `ATAKToolsView` / `NavigationDrawer` / `PluginsListView` to surface your feature.

6. **(Optional) CoT Integration**
   - If your feature exchanges CoT messages:
     - Add or modify parsers in `CoTMessageParser.swift` to detect your CoT `type` and map to new models.
     - Add generators in `CoT/Generators` to create CoT XML from your models.
     - Route inbound events in `CoTEventHandler.swift` to your manager/service.

### 5.2 Adding a New External HTTP API Integration

1. **Design Models**
   - Add response/request models under `Models`, e.g. `ExternalAPIModels.swift`.

2. **Create a Service**

   ```swift
   final class ExternalAPIService: ObservableObject {
       static let shared = ExternalAPIService()
       private let session: URLSession

       init(session: URLSession = .shared) {
           self.session = session
       }

       func fetchSomething() async throws -> SomeModel {
           let request = URLRequest(url: URL(string: "https://api.example.com/something")!)
           let (data, _) = try await session.data(for: request)
           return try JSONDecoder().decode(SomeModel.self, from: data)
       }
   }
   ```

3. **Add Manager & Views** as needed.

4. **Handle Errors and Retries**
   - Decide whether to implement retries in the service or manager.
   - Expose errors via `@Published var error: Error?` for UI to show.

### 5.3 Adding a New TAK/CoT-based Workflow

1. **Define CoT Types & Mapping**
   - Identify CoT `type` values your feature will use (e.g., `b-x-f-newFeature`).
   - Extend `CoTMessageParser.parse(xml:)` to recognize these types.

2. **Add Parsing Logic**
   - Implement a parser function that extracts necessary attributes and elements from XML into a model.

3. **Add Generator**
   - In `CoT/Generators`, define a generator that builds the correct CoT XML from your model.

4. **Update `CoTEventHandler`**
   - Route parsed events to an appropriate service/manager.

5. **Use `TAKService` for Sending**
   - Your service/manager should call `TAKService.send(cotMessage:)` with your XML.

### 5.4 Adding a New Background-like Workflow

iOS background execution is constrained, but within app lifetime you can:

- Use **Combine timers** or `Timer` in services/managers for periodic tasks (e.g., polling external APIs, refreshing data).
- Use **location updates** as a trigger for position-based workflows.

Pattern:

```swift
final class PeriodicSyncService: ObservableObject {
    private var timer: AnyCancellable?

    func start() {
        timer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.performSync() }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}
```

Integrate by exposing a manager or directly from `ContentView`/`OmniTAKMobileApp`.

---

## 6. Operational Notes

### 6.1 Environments (Dev / Staging / Prod)

The app itself does not hard-code multiple environments; instead, environment differences are handled via:

- **TAK server definitions**:
  - Users can configure multiple `TAKServer` entries (dev, test, prod) directly in the app.
- **ArcGIS portal URLs and credentials**:
  - Configurable via `ArcGISPortalService` (could be pointed at dev vs prod portals).
- **Build configurations**:
  - Xcode schemes and plist files (e.g., `ExportOptions-Development.plist`) suggest that different build flavors can be used when distributing.

### 6.2 Running in Development

- **Prerequisites:**
  - Xcode and configured signing identities.
  - A reachable TAK server (or local dev instance) with known host/port/protocol.

- **Steps:**
  1. Open `OmniTAKMobile.xcodeproj` in Xcode.
  2. Select the `OmniTAKMobile` target and a simulator or device.
  3. Run the app; initial screen shows map and tooling.
  4. Navigate to TAK server configuration views to add your server.

- **Debugging Tools:**
  - `ContentView` and `ATAKToolsView` typically expose connection status, message counters.
  - Many services/managers publish debug info via `print` or logging.

### 6.3 Certificates & TLS

- To use TLS connections to TAK:
  - Place `.p12` client certificate files either in:
    - App bundle (for testing), or
    - `Documents/Certificates/` via iTunes File Sharing / Finder or MDM.
  - Use `CertificateManagementView` to select the certificate.
  - Configure the TAK server entry to reference the certificate name/password.

- Legacy TLS support is available but should only be used if the TAK server demands it; see `TLS_LEGACY_SUPPORT.md` for details.

### 6.4 Offline Maps and Storage

- Offline tiles and data packages are stored under app-specific directories in the sandbox (e.g., `Documents/OfflineMaps`, `Documents/DataPackages`).
- Storage managers and services handle directory creation and disk usage.

### 6.5 Error Handling & Logging

- Network services generally use:
  - `print` / custom logging for errors.
  - `@Published var lastError: Error?` or similar patterns for UI-surfaced errors.
- For production-grade deployments, consider integrating a structured logging framework or crash reporter, but this is not visible in the current code.

---

This guide should give you enough mental model to navigate the codebase effectively:

- Start from `OmniTAKMobileApp` → `ContentView`/`ATAKToolsView` to see how managers and services are wired.
- For any feature, locate its View in `OmniTAKMobile/Views`, then trace to corresponding Manager in `OmniTAKMobile/Managers`, and finally the Service in `OmniTAKMobile/Services`.
- Use the `CoT` and `Map` directories as your reference when dealing with TAK protocol or map-based features.