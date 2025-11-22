# Request Flow Analysis

## Entry Points Overview

### Application-Level Entry

- **`OmniTAKMobileApp` (`OmniTAKMobile/Core/OmniTAKMobileApp.swift`)**
  - `@main` SwiftUI `App` struct.
  - Creates a single `WindowGroup` whose root view is `ATAKMapView()` (defined in `Views/ATAKToolsView.swift` / map controllers).
  - There is no HTTP server; all “requests” are:
    - User interactions in SwiftUI views.
    - Network I/O to/from TAK servers via `TAKService` → `DirectTCPSender`.
    - Integration calls to external APIs (e.g., Elevation service, ArcGIS services).

From a request-flow perspective, the core entry paths are:

1. **Outbound TAK / feature requests**
   - User action in a SwiftUI `View` (e.g., ChatView, DrawingToolsPanel, RoutePlanningView).
   - Delegated to a **Manager** (`ChatManager`, `DrawingToolsManager`, etc.).
   - Manager calls a **Service** (`ChatService`, `RoutePlanningService`, `GeofenceService`, etc.).
   - Service often serializes to CoT XML or domain-specific payload.
   - For TAK messages, service forwards to `TAKService` which uses `DirectTCPSender` for TCP/UDP/TLS.

2. **Inbound TAK messages**
   - Network data arrives from the TAK server on `NWConnection` inside `DirectTCPSender`.
   - `DirectTCPSender` assembles XML fragments and triggers its `onMessageReceived` callback.
   - `TAKService` receives raw XML, passes to `CoTMessageParser` / `ChatXMLParser` / other parsers.
   - Parsed CoT events dispatched to **Managers** (`ChatManager`, `TeamService/Manager`, `WaypointManager`, etc.).
   - Managers update `@Published` state, and SwiftUI views reactively update.

3. **External API / map service requests**
   - User actions (e.g., elevation profile, line-of-sight, route planning, ArcGIS features).
   - View → Manager → specific **Service** (e.g., `ElevationAPIClient`, `ArcGISFeatureService`, `RoutePlanningService`).
   - Those services use `URLSession` or ArcGIS SDK APIs to call external endpoints.
   - Responses update Models and Managers, notifying views.

## Request Routing Map

### High-Level Logical Routing

There is no central router like in a web framework; but there is a clear **responsibility-based routing**:

- **SwiftUI Views (`OmniTAKMobile/Views/`)**:
  - Each major feature has a primary View:
    - `ChatView`, `ConversationView` → chat.
    - `RoutePlanningView` → route planning.
    - `GeofenceManagementView` → geofences.
    - `TAKServersView`, `ServerPickerView`, `QuickConnectView` → server connection.
    - `OfflineMapsView`, etc.
  - Views depend on one or more `ObservableObject` managers via `@ObservedObject` or `@EnvironmentObject`.

- **Managers (`OmniTAKMobile/Managers/`)**:
  - Act as ViewModels and primary request dispatchers:
    - `ServerManager` – orchestrates connecting/disconnecting to TAKs via `TAKService`.
    - `ChatManager` – sends and receives chat via `ChatService` and `TAKService`.
    - `WaypointManager`, `GeofenceManager`, `MeasurementManager`, etc. – each handles a domain.
  - They decide which **Service** should handle a given feature request.

- **Services (`OmniTAKMobile/Services/`)**:
  - Feature-specific business logic and I/O:
    - `TAKService` – single gateway for TAK server communication.
    - `ChatService` – formats GeoChat XML, routes send calls to `TAKService`.
    - `RoutePlanningService` – computes/plans routes, may call external APIs.
    - `TeamService`, `MeasurementService`, `NavigationService`, etc. – analogous roles.

- **CoT Parsing & Generation (`OmniTAKMobile/CoT/`)**:
  - `CoTMessageParser` – parses incoming CoT XML (routes by type: chat, tracks, markers, etc.).
  - Generators (`ChatCoTGenerator`, `GeofenceCoTGenerator`, `MarkerCoTGenerator`, `TeamCoTGenerator`) – create outgoing CoT payloads from Models.

- **Network Layer (`TAKService.swift` & `DirectTCPSender`)**:
  - `TAKService` is the logical router to/from TAK servers:
    - Outbound: feature Services call `TAKService.send(cotMessage:)` (or equivalent).
    - Inbound: XML is routed into appropriate handlers via `CoTEventHandler` and Managers.

### Example Request Routes

1. **Send Chat Message**
   - `ChatView` → `ChatManager.sendMessage(text, to:)`
   - `ChatManager` → `ChatService.createMessage(...)` → `ChatCoTGenerator.generate...()`
   - `ChatService.send(message)` → `TAKService.shared.send(cotMessage: message.cotXML)`
   - `TAKService` → `DirectTCPSender.send(data)` via active `NWConnection`.

2. **Incoming Position/Track Update**
   - TAK server → TCP/TLS socket → `DirectTCPSender` receive loop.
   - `DirectTCPSender` → `onMessageReceived(xmlString)`
   - `TAKService` callback → `CoTMessageParser.parse(xmlString)`
   - Parsed CoT event → `CoTEventHandler` → e.g., `TrackService`, `TeamService`, `WaypointManager`.
   - Managed state updated → Views like `IntegratedMapView` / `TrackListView` update.

3. **Elevation Profile Request**
   - `ElevationProfileView` → some `ElevationProfileManager` (or `MeasurementManager`).
   - Manager → `ElevationProfileService` / `ElevationAPIClient`.
   - `ElevationAPIClient` issues external REST request via `URLSession`.
   - Response decoded into `ElevationProfileModels` → Manager updates `@Published` property → View updates.

## Middleware Pipeline

There is no explicit middleware chain (like Express/Koa), but there are discrete processing stages you can treat as “middleware” in the request pipeline.

### Outbound TAK Message Pipeline

For a typical outbound CoT request:

1. **View Event Layer**
   - User taps button / toggles control in a SwiftUI View.
   - View calls method on its Manager (e.g., `chatManager.sendMessage`, `geofenceManager.createGeofence`, `measurementManager.startMeasurement`).

2. **Manager Layer**
   - Validates quick client-side conditions (non-empty text, required selections).
   - Calls appropriate Service method.

3. **Service Layer**
   - Constructs or enriches domain Models.
   - Uses **CoT Generators** where applicable:
     - `ChatCoTGenerator` for chat.
     - `MarkerCoTGenerator` for map markers.
     - `GeofenceCoTGenerator` for geofences.
   - May attach additional metadata (UIDs, timestamps, positions from `CLLocationManager`).
   - Converts to XML string.

4. **TAKService Layer**
   - Accepts XML `String` or `Data`.
   - May enqueue message if not connected (message queue; described in `docs/Features/Networking.md`).
   - On active connection, forwards to `DirectTCPSender` (either TCP/UDP/TLS).

5. **DirectTCPSender / Network.framework**
   - Encodes message to bytes (UTF‑8).
   - Uses `NWConnection` to send on the configured protocol.
   - Tracks stats (`bytesSent`, `messagesSent` maintained in `TAKService`).

### Inbound TAK Message Pipeline

1. **Network Receive**
   - `DirectTCPSender.startReceiveLoop()` reads data from `NWConnection.receive(...)`.
   - Handles fragmentation: appends chunks to `receiveBuffer` protected by `bufferLock`.
   - Extracts complete XML messages (implementation in later `TAKService.swift` lines).

2. **Delivery to TAKService**
   - On each completed XML message: `onMessageReceived(xmlString)` callback.
   - `TAKService` updates `messagesReceived`, `bytesReceived`.
   - Forwards XML to parsing pipeline.

3. **Parsing / Classification**
   - `CoTMessageParser.parse(xmlString)` identifies CoT type:
     - Chat (`GeoChat`).
     - Marker/Point.
     - Track/position updates.
     - Team identity (callsigns, echelons).
   - For chat, `ChatXMLParser` may be used to extract structured chat payload.

4. **Dispatch to Feature Handlers**
   - `CoTEventHandler` routes parsed events to correct feature Managers/Services:
     - Chat → `ChatManager` (adds to `conversations`, updates unread counts, persists via `ChatPersistence`).
     - Tracks → `TrackRecordingService` / `TrackModels`.
     - Geofences → `GeofenceService` / `GeofenceManager`.
     - Video streams → `VideoStreamService`.
   - Managers update their `@Published` properties.

5. **UI Update**
   - SwiftUI views observing these managers automatically re-render.

### External REST / ArcGIS Pipelines

E.g., `ElevationAPIClient`, `ArcGISFeatureService`, `ArcGISPortalService`:

1. View triggers manager method (e.g., “Fetch Elevation Profile”).
2. Manager calls Service.
3. Service prepares `URLRequest` (`GET/POST`) or ArcGIS SDK query.
4. Uses `URLSession`/ArcGIS async APIs.
5. Decodes JSON response into Models (`ElevationProfileModels`, `ArcGISModels`).
6. Manager updates state; Views react to changes.

## Controller/Handler Analysis

Although SwiftUI avoids traditional MVC controllers, this codebase has:

### View-Controllers (Map System)

- **UIKit Map Controllers (`OmniTAKMobile/Map/Controllers/`)**
  - `MapViewController`, `EnhancedMapViewController`, `Map3DViewController`, `IntegratedMapView`, etc.
  - Bridge ATAK-style map into SwiftUI via `UIViewControllerRepresentable` (`EnhancedMapViewRepresentable`).
  - Handle gestures, selection, overlay updates, context menus (see `MapContextMenus.swift`).
  - Analogy to “controllers” in a web app: they orchestrate map-related state and dispatch actions to Managers/Services.

### Feature Managers as Controllers

Managers control logic and act as handlers for “requests” coming from Views:

- **`ChatManager`**
  - Methods:
    - `sendMessage(...)`
    - `loadConversations()`
    - `markConversationAsRead(...)` etc.
  - Handles inbound messages:
    - Called from TAK message pipeline to append new `ChatMessage` to in-memory collections, persist via `ChatPersistence`.

- **`ServerManager`**
  - Owns server connection state, interacts with:
    - `TAKService` for networking.
    - `CertificateManager` for TLS certs.
  - Exposes methods:
    - `connect(to server: TAKServer)`, `disconnect()`, `reconnect()`.
  - Exposes `@Published` connection state used by `ConnectionStatusWidget`, `QuickConnectView`, `TAKServersView`.

- **Other Managers** (`GeofenceManager`, `WaypointManager`, `OfflineMapManager`, etc.)
  - Expose domain-specific operations called by Views and triggered by CoT events.

### Service Handlers

Some important handlers in Services:

- **`TAKService`**
  - Core request handlers:
    - `connect(...)` → configures and initiates `DirectTCPSender.connect(...)`.
    - `disconnect()` → closes network connection, clears state.
    - `send(cotMessage: String)` (or similar) → handles message queuing or immediate send.
  - Inbound handler:
    - `handleReceivedMessage(_ xml: String)` → uses `CoTMessageParser` and dispatches to `CoTEventHandler`.

- **`ChatService`**
  - Request handlers:
    - `createMessage(text, recipient)` → builds `ChatMessage` + CoT XML via `ChatCoTGenerator`.
    - `send(ChatMessage)` → passes message to `TAKService`.

- **Geospatial Feature Services**
  - `MeasurementService`, `LineOfSightService`, `RoutePlanningService`, etc.
  - Handle domain-specific calculations and external API usage.

### CoT Event Handling

- **`CoTEventHandler.swift`**
  - Receives parsed CoT model objects from `CoTMessageParser`.
  - Routes by CoT type or UID prefix:
    - Chat, markers, tracks, emergency beacons, etc.
  - Interacts with relevant Managers to mutate state.

## Authentication & Authorization Flow

### TLS Client Authentication

Authentication is primarily through **mutual TLS** to TAK servers:

- Implemented in **`DirectTCPSender.connect(...)`**:
  - When `useTLS` or `protocolType == "tls"`:
    - Builds `NWProtocolTLS.Options()`.
    - Configures allowed TLS versions:
      - Default: min `.TLSv12`, max `.TLSv13`.
      - Legacy mode (if `allowLegacyTLS == true`): min TLS 1.0 via raw value `769`.
    - Configures cipher suites, including legacy AES-GCM and AES-CBC suites.
    - Sets **verify block** that accepts all server certificates (self-signed CA support).

- **Client certificate loading**
  - If `certificateName` is supplied:
    - `loadClientCertificate(name: certificateName, password: certificatePassword ?? "atakatak")` is used.
    - On success: `sec_protocol_options_set_local_identity(secOptions, identity)` to send client identity.
  - Tied into **`CertificateManager`**:
    - Handles import, storage, and selection of PKCS#12 certificate bundles (`omnitak-mobile.p12`).
    - Views: `CertificateEnrollmentView`, `CertificateManagementView`, `CertificateSelectionView`.

- **Server-side authorization**
  - Enforced by the TAK server, not by the mobile client.
  - The client accepts all server certs (with explicit note in docs for security implications).

### Application-Level Authorization

- There is **no explicit role-based access control in the app code**:
  - No separate RBAC system appears in Models or Services.
  - Permissions are effectively dictated by:
    - Which CoT messages a user can send (driven by UI capabilities and server policy).
    - TAK server’s ACLs applied at server side.

- Feature gating:
  - Some actions may be enabled/disabled based on:
    - Connection state (e.g., cannot send chat while disconnected).
    - Certificate presence/validity (connection may fail).
  - These checks are enforced in Managers/Views, not in a centralized auth module.

## Error Handling Pathways

### Network Connection Errors

- **`DirectTCPSender.stateUpdateHandler`**:

  ```swift
  connection?.stateUpdateHandler = { [weak self] state in
      switch state {
      case .ready:
          self.onConnectionStateChanged?(true)
          self.startReceiveLoop()
          completion(true)
      case .failed(let error):
          print("❌ Direct\(self.currentProtocol): Connection failed: \(error)")
          self.onConnectionStateChanged?(false)
          completion(false)
      case .waiting(let error):
          print("⏳ Direct\(self.currentProtocol): Waiting to connect: \(error)")
      case .cancelled:
          print("🔌 Direct\(self.currentProtocol): Connection cancelled")
          self.onConnectionStateChanged?(false)
      default:
          break
      }
  }
  ```

- `TAKService` subscribes to `onConnectionStateChanged`:
  - Updates `@Published var isConnected`, `connectionStatus` (e.g., “Connected”, “Disconnected”, “Connecting…”).
  - UI widgets like `ConnectionStatusWidget` show state to the user.
  - On `failed` or `cancelled`, `TAKService` may schedule a reconnect or flush message queue as configured.

### Message-Level Errors

- Outbound:
  - If `DirectTCPSender.isConnected` is false, `TAKService` enqueues messages rather than sending.
  - On connection established, queued messages are drained.
  - Errors in `send` (e.g., `NWError`) would cause connection state changes, leading back to connection error handling.

- Inbound:
  - XML parsing issues in `CoTMessageParser` / `ChatXMLParser`:
    - Likely logged and discarded; invalid messages do not propagate.
    - No explicit retry (since inbound messages are push-based from server).

### Certificate / TLS Errors

- TLS handshake issues:
  - Surfaced as `.failed(error)` in `stateUpdateHandler`.
  - Logged with prefix `Direct\(self.currentProtocol): Connection failed`.
  - Because server certificates are auto-accepted, the common failure points are:
    - Wrong host/port.
    - Incorrect or missing client certificate.
  - `CertificateManager` views allow managing/repairing certs.

### Application-Layer Errors

- Many Services/Managers are documented in `docs/errors.md` (see file), including:
  - Chat send failure messages.
  - Offline map download failure handling (`TileDownloader`).
  - Meshtastic connection issues (`MeshtasticManager`).

Error “responses” are usually:

- Logs to console (`print`).
- Manager state fields such as `errorMessage: String?` or `connectionStatus`.
- SwiftUI views observe and display alerts/banners where appropriate.

There is no unified exception middleware; errors are handled locally at each layer.

## Request Lifecycle Diagram

Below is an abstract lifecycle for **outbound** and **inbound** TAK-related requests, mapping directly to the existing code.

### Outbound Request (e.g., Send Chat)

```text
User taps "Send" in ChatView
        │
        ▼
ChatView (SwiftUI)
  - holds @ObservedObject ChatManager
  - calls chatManager.sendMessage(text, to)
        │
        ▼
ChatManager (Managers/ChatManager.swift)
  - validates input
  - uses ChatService to build message
        │
        ▼
ChatService (Services/ChatService.swift)
  - uses ChatCoTGenerator to build GeoChat CoT XML
  - wraps into ChatMessage model
  - calls TAKService.shared.send(cotMessage: xml)
        │
        ▼
TAKService (Services/TAKService.swift)
  - if not connected → enqueue
  - if connected → passes to DirectTCPSender.send(...)
        │
        ▼
DirectTCPSender (inside TAKService.swift)
  - formats data, writes via NWConnection.send
  - Network.framework handles TCP/UDP/TLS delivery
        │
        ▼
TAK Server (external)
```

### Inbound Request (e.g., Incoming CoT Chat / Position)

```text
TAK Server sends CoT XML over network
        │
        ▼
NWConnection (Network.framework)
  - data arrives on TCP/UDP/TLS socket
        │
        ▼
DirectTCPSender.startReceiveLoop()
  - appends bytes to receiveBuffer
  - extracts complete XML messages
  - invokes onMessageReceived(xml)
        │
        ▼
TAKService.onMessageReceived
  - increments messagesReceived, bytesReceived
  - forwards xml to CoTMessageParser
        │
        ▼
CoTMessageParser (CoT/CoTMessageParser.swift)
  - parses XML → CoTEvent, ChatMessage, etc.
  - routes to CoTEventHandler
        │
        ▼
CoTEventHandler (CoT/CoTEventHandler.swift)
  - inspects CoT type:
    - Chat  → ChatManager
    - Track → TrackRecordingService / TeamService
    - Marker/Geofence → relevant Managers
        │
        ▼
Managers (ChatManager, TeamService, etc.)
  - mutate @Published properties
  - persist via Storage (ChatPersistence, RouteStorageManager, etc.)
        │
        ▼
SwiftUI Views (ChatView, IntegratedMapView, etc.)
  - observe manager state changes
  - automatically re-render with new data
```

### External API Request (e.g., Elevation Profile)

```text
User configures profile in ElevationProfileView
        │
        ▼
ElevationProfileView
  - triggers manager.startProfile(from:to:)
        │
        ▼
MeasurementManager / ElevationProfileManager
  - builds request parameters
  - calls ElevationProfileService/ElevationAPIClient.fetch(...)
        │
        ▼
ElevationAPIClient (Services/ElevationAPIClient.swift)
  - builds URLRequest, calls URLSession
  - decodes JSON into ElevationProfileModels
        │
        ▼
Manager
  - updates @Published profile data or error field
        │
        ▼
ElevationProfileView
  - re-renders with graph or error message
```

---

This describes the concrete, existing request paths in the OmniTAK Mobile app:

- **Entry points** are user actions and network callbacks.
- **Routing** is via Managers and Services, with `TAKService` as the TAK gateway.
- **Middleware-like stages** are implemented as sequential layers: View → Manager → Service → Network (outbound) and Network → Parser → EventHandler → Manager → View (inbound).
- **Auth** is handled at the TLS layer with client certs and TAK server rules.
- **Errors** are locally managed at connection and service layers, surfaced through reactive state and console logs.