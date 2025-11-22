# Data Flow Analysis

## Data Models Overview

### Model Layer Structure

All primary data models live under `OmniTAKMobile/Models/` and are documented in `docs/API/Models.md`. They are almost uniformly:

- `struct`-based
- `Codable` (for JSON/plist persistence and network payloads)
- `Identifiable` (for SwiftUI `List` and diffing)
- `Equatable` (for value comparisons and change detection)

Key model groups:

- **CoT / Map / Tracking**
  - `CoTEvent` (CoT event payload)
  - `EnhancedCoTMarker` (map marker + trail)
  - `Track`, `TrackPoint` (breadcrumb trails)
  - `Waypoint`, `Route`, `OfflineMapRegion`, etc.
- **Chat / Messaging**
  - `ChatMessage`
  - `Conversation`
  - `ChatParticipant`
  - `ImageAttachment`
  - `QueuedMessage`
- **Teams / Tactical**
  - `Team`, `TeamMember`
  - `SPOTREP`, `SALUTE`, `MEDEVACRequest`, etc.
- **Servers / Certificates / Settings**
  - `TAKServer`
  - `TAKCertificate`
  - Various config structs for networking, offline maps, broadcast settings, etc.
- **Domain-Specific Models**
  - `Geofence`, `GeofenceEvent`
  - `Measurement`, `ElevationProfile`, `LineOfSightRequest/Result`
  - `VideoStream`, `MissionPackage`, `DataPackage` models

#### Example: CoTEvent

File: `OmniTAKMobile/Models/CoTModels.swift` (referenced in `docs/API/Models.md`)

```swift
struct CoTEvent: Identifiable, Codable, Equatable {
    let id: String              // UUID or UID from message
    let uid: String             // CoT UID (e.g., "ANDROID-123")
    let type: String            // CoT type (e.g., "a-f-G-U-C")
    let time: Date
    let start: Date
    let stale: Date
    let how: String             // acquisition method

    // Location
    let coordinate: CLLocationCoordinate2D
    let hae: Double
    let ce: Double
    let le: Double

    // Detail
    let callsign: String
    let team: String?
    let role: String?
    let remarks: String?
}
```

This is the core normalized representation of a CoT message used across services, map rendering, and filtering.

#### Example: ChatMessage

File: `OmniTAKMobile/Models/ChatModels.swift`

```swift
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let senderUID: String
    let senderCallsign: String
    let recipientUID: String
    let recipientCallsign: String
    let messageText: String
    let timestamp: Date

    var coordinate: CLLocationCoordinate2D?
    var attachment: ImageAttachment?
    var status: MessageStatus = .pending
    var isRead: Bool = false
}
```

This is the canonical in‑memory and persisted representation of a chat item; it is transformed to/from CoT/GeoChat XML for transport.

### Model Roles

- **Canonical domain state** for each feature (chat, map, teams, routes, etc.).
- **Boundary types** between:
  - Views and Managers (UI <-> view models).
  - Managers and Services (view models <-> business logic).
  - Services and Storage layer (business logic <-> persistence).
  - Services and network serialization (domain <-> XML/JSON CoT).

No business logic is embedded in models; they are purely data structures, sometimes with simple computed properties like `EnhancedCoTMarker.isStale`.

---

## Data Transformation Map

This section focuses on *how* data moves and is transformed between layers, using the main subsystems as exemplars.

### Global Architectural Data Path

From `docs/Architecture.md` and `docs/API/*`:

1. **External I/O**
   - Network (TAK server, ELEVATION API, Meshtastic, ArcGIS services)
   - Files (KML/KMZ, data packages)
   - Sensors (GPS, device orientation, video)
2. **Service Layer** (`Services/`)
   - Parses/serializes external formats (CoT XML, GeoChat XML, protobuf, KML, REST JSON).
   - Transforms external payloads into domain models.
3. **Manager Layer** (`Managers/`)
   - Holds app‑level state using domain models.
   - Coordinates Services and Storage.
4. **Storage Layer** (`Storage/`)
   - Reads/writes domain models to persistent stores (UserDefaults, files, local caches).
5. **View Layer** (`Views/`, `Map/`, `UI/`)
   - Subscribes via Combine to manager state (`@Published` properties).
   - Transforms domain models to view models / visual elements.

The transformation pattern is largely unidirectional:

```text
External Data <-> Service-specific DTOs <-> Domain Models
Domain Models <-> Storage Formats (JSON/plist/files)
Domain Models -> Published State -> Views
User Input -> Views -> Managers -> Services/Storage
```

### CoT Events & Map Markers

Primary files:
- `CoTMessageParser.swift`
- `CoTEventHandler.swift`
- `CoTFilterCriteria.swift`
- `MapOverlayCoordinator.swift` / `EnhancedMapViewController.swift`
- Models: `CoTModels.swift`, `TrackModels.swift`, `PointMarkerModels.swift`

**Inbound (Network → Map):**

1. **Raw data from TAK server**
   - `TAKService` receives CoT XML strings over TLS/UDP/TCP.
   - Updates counters: `messagesReceived`, `bytesReceived`.

2. **Parsing**
   - `CoTMessageParser` transforms XML into domain types:
     - CoT XML → `CoTEvent` (primary)
     - GeoChat XML → chat/message DTOs, then to `ChatMessage`
   - Any low‑level DTOs are immediately converted to the main models.

3. **Filtering & Distribution**
   - `CoTEventHandler`:
     - Receives `CoTEvent`.
     - Applies `CoTFilterCriteria` (user filter settings).
     - Routes:
       - Position events → map marker models (`EnhancedCoTMarker`).
       - Chat events → chat flow (`ChatService` / `ChatManager`).
       - Tactical reports → SPOTREP/MEDEVAC models.
   - Map specific transformations:
     - `CoTEvent` → `EnhancedCoTMarker` (adds trail and marker state).
     - For breadcrumbs, `TrackRecordingService` may also transform location samples into `Track`/`TrackPoint`.

4. **Map Rendering**
   - `MapOverlayCoordinator`, `EnhancedMapViewController`, overlays in `Map/Overlays/` transform:
     - `EnhancedCoTMarker`, `Track` → `MKAnnotation`, `MKOverlay` or Esri overlay objects.
   - These derived view models are *not persisted*; they mirror domain models in memory.

**Outbound (Map/Position → Network):**

1. **Domain state**
   - `PositionBroadcastService` uses the current location (`CLLocation`) and user settings (`userUID`, `userCallsign`, `teamColor`, `userUnitType`) to create a broadcasting payload.

2. **Generation**
   - CoT generator utilities (e.g., `TeamCoTGenerator`, `MarkerCoTGenerator`, `GeofenceCoTGenerator`, `ChatCoTGenerator`) build XML:
     - Domain models → CoT/GeoChat XML string.

3. **Sending**
   - `TAKService.send(cotMessage:priority:)` sends XML over the network.

### Chat Flow

Primary files:
- `ChatService.swift`
- `ChatManager.swift`
- Storage: `ChatPersistence.swift`, `ChatStorageManager.swift`
- CoT/Chat XML: `ChatCoTGenerator.swift`, `ChatXMLParser.swift`, `ChatXMLGenerator.swift`
- Models: `ChatModels.swift`

**Outbound (User → Network):**

1. **User Input**
   - `ChatView`, `ConversationView` capture text/photos.
   - UI calls into `ChatManager` (view model):
     ```swift
     chatManager.sendMessage(text, to: recipientUID)
     ```

2. **Manager → Service**
   - `ChatManager` delegates to `ChatService`:
     ```swift
     let message = chatService.createMessage(text, recipient)
     chatService.send(message)
     persistence.save(message)
     ```
   - Transformation:
     - Raw UI strings → `ChatMessage` domain model (fills IDs, timestamps).
     - Domain model → queued state (`QueuedMessage`) if offline.

3. **Service → CoT XML**
   - `ChatService` uses `ChatCoTGenerator` / `ChatXMLGenerator`:
     - `ChatMessage` (+ optional `coordinate`, `ImageAttachment`) → GeoChat CoT XML string.

4. **Network Send**
   - `ChatService` calls `TAKService.send(cotMessage:priority:)`.
   - On success:
     - Update `ChatMessage.status` (e.g., `.sent` → `.delivered` based on ACK CoT).
     - Push updated models back to `ChatManager` via Combine.

5. **Persistence**
   - `ChatPersistence` / `ChatStorageManager`:
     - Append/update message in JSON/plist store.
     - Maintain message indices for each `Conversation`.

**Inbound (Network → UI):**

1. **TAKService receives GeoChat CoT XML.**
2. **Chat XML Parsing**
   - `ChatXMLParser`:
     - XML → intermediate DTOs / fields (sender UID, callsign, text, time, optional coordinate).
   - `ChatService` converts these into `ChatMessage` domain models.

3. **Conversation Aggregation**
   - `ChatService` or `ChatStorageManager` computes:
     - `Conversation` models: group by participants, compute `lastMessage`, `unreadCount`.

4. **State Propagation**
   - `ChatService` updates:
     - `@Published var messages`, `conversations`, `participants`, `unreadCount`.
   - `ChatManager` mirrors or derives secondary state (sorting/filtering, current conversation, UI flags).

5. **View Updates**
   - `ChatView` / `ConversationView` observe `ChatManager`:
     - Domain models → SwiftUI cells (`ConversationRow`, `MessageBubble`).

### Server & Certificate Configuration

Primary files:
- `ServerManager.swift`
- `CertificateManager.swift`
- `NetworkPreferencesView.swift`, `TAKServersView.swift`
- `CertificateEnrollmentService.swift`, `CertificateEnrollmentView.swift`

**Server config data flow:**

1. **User Inputs**
   - In `TAKServersView`, user creates/edits `TAKServer` (host, port, protocol, TLS).
   - View calls:
     ```swift
     ServerManager.shared.addServer(server)
     ```

2. **Manager State**
   - `ServerManager`:
     - Maintains `@Published var servers: [TAKServer]`.
     - On change: `didSet` triggers persist:
       ```swift
       private func saveServers() {
           if let encoded = try? JSONEncoder().encode(servers) {
               UserDefaults.standard.set(encoded, forKey: "tak_servers")
           }
       }
       ```

3. **App Startup**
   - `ServerManager` loads servers from `UserDefaults` using `JSONDecoder`.
   - This is a typical pattern repeated for other settings.

4. **Connection**
   - On selecting a server:
     - `ServerManager.selectServer(_:)` sets `selectedServer` and triggers:
       ```swift
       takService.connect(host:..., port:..., protocolType:..., useTLS:..., certificateName:..., certificatePassword:...)
       ```

**Certificates flow:**

1. **Certificate Import**
   - `CertificateManagementView` / `CertificateEnrollmentView` read `.p12` file.
   - Pass raw `Data` and password to:
     ```swift
     CertificateManager.shared.importCertificate(from: data, password: password)
     ```

2. **CertificateManager**
   - Validates & parses the `.p12` into `TAKCertificate` metadata.
   - Persists into Keychain (`saveCertificate`) and an in‑memory list (`@Published var certificates`).
   - Likely also encodes some metadata to `UserDefaults` for fast lookup.

3. **Usage**
   - `TAKService` is configured with certificate name/password when connecting.

### Offline Maps & Tile Caching

Primary files:
- `OfflineMapModels.swift`
- `OfflineTileOverlay.swift`
- `OfflineTileCache.swift`
- `TileDownloader.swift`
- `OfflineMapManager.swift`
- Docs: `OFFLINE_MAPS_INTEGRATION.md`

**Data flow:**

1. **User selects offline region in `OfflineMapsView`.**
2. **`OfflineMapManager`**
   - Creates `OfflineMapRegion` model (bounds, zoom, identifier).
   - Hands to `TileDownloader`.

3. **`TileDownloader`**
   - Computes tile URLs (ArcGIS or other sources).
   - Downloads images, storing file data through `OfflineTileCache`.

4. **`OfflineTileCache`**
   - Provides a mapping: (x, y, zoom, source) → local file path or memory cache.
   - Likely uses file system directories keyed by region/source.
   - Maintains domain models for downloaded regions (saved via `Codable` into disk).

5. **Map Rendering**
   - `OfflineTileOverlay` reads from `OfflineTileCache`:
     - Tile coordinate → `Data` or `UIImage`.
   - This is a pure transformation from domain/coordinate space to UI texture.

### Tracks & Breadcrumbs

Primary files:
- `TrackModels.swift`
- `TrackRecordingService.swift`
- `BreadcrumbTrailOverlay.swift`
- `BreadcrumbTrailService.swift`
- `TrackOverlayRenderer.swift`

**Data flow:**

1. **Location updates (`CLLocation` source).**
2. **`TrackRecordingService`**
   - On each location:
     - Transform `CLLocation` → `TrackPoint` model (time, lat/lon, altitude, speed).
     - Append to `currentTrack`.
   - Computes live metrics:
     - `liveDistance`, `liveSpeed`, `liveAverageSpeed`, `liveElevationGain`.

3. **Persisting tracks**
   - On stop/save:
     - `currentTrack` appended to `savedTracks`.
     - Persisted via `Codable` to disk (`TrackPersistence` pattern similar to `ChatPersistence`).

4. **Rendering**
   - Map controllers/overlays transform:
     - `Track` (array of `TrackPoint`s) → polyline overlays.

### KML/KMZ and Data Packages

Primary files:
- `KMLParser.swift`, `KMZHandler.swift`, `KMLMapIntegration.swift`, `KMLOverlayManager.swift`
- `DataPackageManager.swift`, `DataPackageModels.swift`
- Views: `KMLImportView.swift`, `DataPackageImportView.swift`

**Data flow:**

1. **File import**
   - User opens KML/KMZ (from Files / data package).
   - `KMZHandler` unzips, extracts KML.
   - `KMLParser`:
     - KML → model structs (waypoints, routes, overlays).

2. **Integration**
   - `KMLMapIntegration` and `KMLOverlayManager` map these models to:
     - `Waypoint` / `Route` domain models.
     - Map overlays (polygons, polylines) for drawing.

3. **Persistence**
   - These derived models can be:
     - Saved (via `RouteStorageManager`, `WaypointManager`).
     - Or kept only in memory for session display.

---

## Storage Interactions

### Primary Storage Mechanisms

1. **UserDefaults**
   - Simple configuration and small lists:
     - `TAKServer` list in `ServerManager`.
     - Broadcast settings, user preferences.
   - Persistence pattern:
     ```swift
     if let encoded = try? JSONEncoder().encode(model) {
         UserDefaults.standard.set(encoded, forKey: "key")
     }
     ```

2. **File System (Documents / Caches)**
   - Chat history (`ChatPersistence`).
   - Tracks and routes (`RouteStorageManager`).
   - Offline map tiles and metadata (`OfflineTileCache`).
   - Data packages, attachments (e.g., `ImageAttachment.localPath`).

3. **Keychain**
   - Certificates and TLS credentials via `CertificateManager`.

4. **In‑memory Caches**
   - Map tiles, overlays (managed by `OfflineTileCache`, `ArcGISTileSource`).
   - Ephemeral state inside managers (`@Published` arrays and dictionaries).

### Storage Layer Files

- `OmniTAKMobile/Storage/ChatPersistence.swift`
- `OmniTAKMobile/Storage/ChatStorageManager.swift`
- `OmniTAKMobile/Storage/RouteStorageManager.swift`
- `OmniTAKMobile/Storage/TeamStorageManager.swift`
- `OmniTAKMobile/Storage/DrawingPersistence.swift`
- Map tile caching via `OfflineTileCache.swift`

**ChatPersistence pattern:**

Although the full code isn’t shown in docs, its documented behavior is:

- `save(_ message: ChatMessage)`:
  - Append to conversation file (per‑conversation JSON) or a global messages store.
- `loadConversations()`:
  - Decode `[Conversation]` from JSON.
- Data structure:
  - Domain models (`ChatMessage`, `Conversation`) are directly persisted as JSON using `Codable`.

**RouteStorageManager:**

- Stores `Route` models (waypoints, names, settings) as:
  - `Codable` JSON in `Documents/routes/` or a similar folder.
- Provides CRUD:
  - create/update/delete/list routes.

---

## Validation Mechanisms

Validation appears in three main tiers:

1. **UI‑level Input Constraints**
   - Forms restrict options (pickers for server protocol, team roles).
   - Use SwiftUI validation (disable buttons on invalid state, etc.).

2. **Manager/Service-level Validation**
   - Methods guard against invalid inputs before processing or persisting.

   Examples (as documented):

   - `CertificateManager.importCertificate(from:password:)`:
     - Throws `CertificateError` on bad data/password.
   - `TAKService.connect(...)`:
     - Validates host, port, and TLS parameters; updates `connectionStatus` accordingly.
   - `PositionBroadcastService`:
     - Validates `updateInterval` and `staleTime` (sane ranges, e.g., not zero/negative).
   - `ChatService.sendTextMessage(_:to:)`:
     - Ensures non‑empty text and a valid recipient; if offline, enqueues instead of sending.

3. **Model-level Sanity / Derived Validity**
   - Models themselves don’t enforce invariants, but computed properties communicate status.

   Example:
   ```swift
   var isStale: Bool {
       Date().timeIntervalSince(lastUpdate) > 300
   }
   ```

4. **Parsing/Deserialization Validation**
   - `CoTMessageParser`, `ChatXMLParser`, `KMLParser`:
     - Handle malformed/partial data.
     - Use optional fields, default values, or drop invalid events.
   - Meshtastic Protobuf:
     - `MeshtasticProtobufParser` verifies message types and structure.

5. **Error Handling Patterns**

   - Many services are `ObservableObject` and surface errors as:
     - `@Published var lastError: Error?` or `@Published var errorMessage: String?`.
   - For critical operations (e.g., certificates, server connection):
     - Throwing APIs + user‑visible alerts in views.

---

## State Management Analysis

### Core Pattern: MVVM with Combine

From `docs/Architecture.md`:

- **Views** (`Views/`, `Map/Controllers/`) use:
  - `@ObservedObject` or `@EnvironmentObject` to subscribe to **Managers**.
- **Managers** (ViewModels, in `Managers/`):
  - Conform to `ObservableObject`.
  - Use `@Published` for bindable properties.
  - Delegate heavy work to Services and Storage.
- **Services**:
  - Some are `ObservableObject` when UI needs direct state, but often they are accessed via Managers.

### Managers as State Hubs

Documented managers include:

- `ServerManager`
- `CertificateManager`
- `ChatManager`
- `CoTFilterManager`
- `DrawingToolsManager`
- `GeofenceManager`
- `MeasurementManager`
- `MeshtasticManager`
- `OfflineMapManager`
- `WaypointManager`
- `DataPackageManager`
- `MapStateManager` (for current map mode, overlays toggles)

Common behavior:

1. **Initialization**
   - Some are singletons (`static let shared`).
   - Others are injected into SwiftUI environment.

2. **State Synchronization**
   - On initialization, managers load persisted data (UserDefaults / disk).
   - They subscribe to relevant Services via Combine or method callbacks.

3. **Auto‑Save**
   - Use `didSet` on `@Published` properties:
     - On change → call persistence (`saveX`, `persistY`).

4. **UI‑Specific Derived State**
   - For example, `ChatManager`:
     - Derived `unreadCount`, sorted `conversations`, currently open `Conversation`.

5. **Interaction with Services**
   - Managers abstract away services from views; e.g.:
     ```swift
     func sendMessage(_ text: String, to recipient: String) {
         let message = chatService.createMessage(text, recipient)
         chatService.send(message)
         persistence.save(message)
     }
     ```
   - This creates a clear data flow path: View → Manager → Service → TAKService/Storage.

### Map & Overlay State

- `MapStateManager` (in `Map/Controllers`) centralizes:
  - Active overlays (aka toggles for MGRS grid, compass, trail).
  - Selection state (selected marker, selected track).
  - Cursor mode / interaction mode.

- Overlays like `BreadcrumbTrailOverlay`, `UnitTrailOverlay`, `MeasurementOverlay` read from:
  - Managers (`TrackRecordingService`, `MeasurementManager`).
  - Domain models (e.g., `Track`, `Measurement`).

These overlays are derived state only; they are recomputed from the underlying models when the managers’ `@Published` properties change.

---

## Serialization Processes

### CoT & GeoChat XML

Files:
- `CoTMessageParser.swift`
- `ChatCoTGenerator.swift`
- `ChatXMLGenerator.swift`
- `ChatXMLParser.swift`

**Inbound:**

- `TAKService` receives XML strings.
- `CoTMessageParser`:
  - Parses the XML DOM.
  - Extracts attributes: `uid`, `type`, `time`, `start`, `stale`, `how`.
  - Extracts location: `<point lat=".." lon=".." hae="..." ce="..." le="..."/>`.
  - Extracts `<detail>` contents (callsign, team, etc.).
  - Builds `CoTEvent` domain model.
- `ChatXMLParser`:
  - Interprets GeoChat CoT messages:
    - XML → `ChatMessage` (including `coordinate` if present).

**Outbound:**

- Generators (`ChatCoTGenerator`, `MarkerCoTGenerator`, `GeofenceCoTGenerator`, `TeamCoTGenerator`):
  - Take domain models (`ChatMessage`, `Geofence`, team data) and produce:
    - CoT XML strings adhering to TAK spec.
- `ChatService`, `PositionBroadcastService`, `DigitalPointerService`, `RangeBearingService` call these generators before:
  - `TAKService.send(cotMessage:priority:)`.

### JSON / Plist

- Used for:
  - Persisting domain models (Chat, Routes, Teams, Tracks, Preferences).
  - REST API payloads (Elevation API, ArcGIS services).
- Mechanism:
  - All domain models conform to `Codable`.
  - Example from `ServerManager`:
    ```swift
    if let encoded = try? JSONEncoder().encode(servers) {
        UserDefaults.standard.set(encoded, forKey: "tak_servers")
    }
    ```
  - `JSONDecoder` used symmetrically on load.

- Some configuration may use plist encoders (e.g., ExportOptions plists for builds), but at runtime the bulk is JSON.

### Protobuf (Meshtastic)

Files:
- `MeshtasticProtoMessages.swift`
- `MeshtasticProtobufParser.swift`
- `MeshtasticManager.swift`

**Inbound:**

- Raw protobuf bytes from Meshtastic radios.
- `MeshtasticProtobufParser`:
  - Decodes to message structs defined in `MeshtasticProtoMessages.swift`.
  - Further transforms to OmniTAK domain:
    - e.g., location packets → `CoTEvent` / markers.
    - text packets → `ChatMessage`.

**Outbound:**

- `MeshtasticManager` can send messages by:
  - Domain models → Meshtastic protobuf message objects → serialized bytes.

### KML/KMZ

Files:
- `KMLParser.swift`
- `KMZHandler.swift`
- `KMLMapIntegration.swift`

Process:

- KMZ (.zip) is decompressed by `KMZHandler`.
- `KMLParser`:
  - XML → domain types: waypoints, routes, polygons.
- `KMLMapIntegration`:
  - Maps parsed structures to OmniTAK models (`Waypoint`, `Route`).

### ArcGIS & Other REST/JSON

Files:
- `ArcGISFeatureService.swift`
- `ArcGISPortalService.swift`
- `ElevationAPIClient.swift`
- `ElevationProfileService.swift`

Pattern:

- JSON requests/responses use Swift `Codable` DTOs (simple mirror models).
- These DTOs are transformed into domain models for map overlays/measurements (e.g., `ElevationProfile`).

---

## Data Lifecycle Diagrams

Below are textual lifecycle diagrams for key subsystems, based only on existing documented behavior.

### 1. CoT Event Lifecycle

```text
[TAK Server] --CoT XML--> [TAKService]
   |
   v
[CoTMessageParser]
   |  (parse XML)
   v
[CoTEvent domain model]
   |
   +--> [CoTEventHandler]
   |       |
   |       +--> [CoTFilterManager] (applies CoTFilterCriteria)
   |       |
   |       +--> Position events --> [EnhancedCoTMarker]
   |       |                           |
   |       |                           v
   |       |                       [MapStateManager]
   |       |                           |
   |       |                           v
   |       |                     [Map Views / Overlays]
   |       |
   |       +--> GeoChat messages --> [ChatService] -> [ChatManager]
   |       |
   |       +--> Tactical reports --> [MEDEVACModels, SPOTREPModels] etc.
   |
   v
(optional) [Storage]
    - Tracks (TrackRecordingService) to disk
    - Chat via ChatPersistence
```

Outbound:

```text
[User action / Timer] --> [PositionBroadcastService / ChatService / others]
    |
    v
 (Domain models: CoTEvent/ChatMessage/etc.)
    |
    v
[CoT Generators / XML Generators]
    |
    v
      CoT XML string
    |
    v
[TAKService.send(...)] -- network --> [TAK Server]
```

### 2. Chat Message Lifecycle

**Outbound:**

```text
[User types in ChatView]
    |
    v
[ChatView] --send--> [ChatManager]
    |
    v
[ChatService.createMessage()]
    |
    v
[ChatMessage domain model (status: pending)]
    |
    +--> [ChatPersistence.save(message)]  (JSON on disk)
    |
    v
[ChatService.send(message)]
    |
    v
[ChatCoTGenerator / ChatXMLGenerator]
    |
    v
[TAKService.send(cotMessage:...)]
    |
    v
[Network]
```

**Inbound:**

```text
[TAK Server] --GeoChat CoT XML--> [TAKService]
    |
    v
[ChatXMLParser]
    |
    v
[ChatMessage domain model (status: received)]
    |
    +--> [ChatPersistence.save(message)]
    |
    v
[ChatService.messages, conversations] (Published)
    |
    v
[ChatManager] (derived state: unreadCount, selected conversation)
    |
    v
[ChatView / ConversationView] (UI updates via SwiftUI bindings)
```

### 3. Server Configuration Lifecycle

```text
[App Launch]
    |
    v
[ServerManager.init]
    |
    v
[UserDefaults] --JSON--> [servers: [TAKServer]]

User edits:

[TAKServersView] --add/update--> [ServerManager]
    |
    v
  modify [servers]
    |
    v
[ServerManager.saveServers()]
    |
    v
[UserDefaults.set(JSON-encoded servers)]

Connecting:

[User selects server in TAKServersView]
    |
    v
[ServerManager.selectServer(server)]
    |
    v
[TAKService.connect(host, port, protocol, ...)]
```

### 4. Offline Map Region Lifecycle

```text
[User defines region in OfflineMapsView]
    |
    v
[OfflineMapManager] creates OfflineMapRegion
    |
    v
[TileDownloader.download(region)]
    |
    v
[ArcGIS / tile source servers] --tile images--> [TileDownloader]
    |
    v
[OfflineTileCache.store(tileX, tileY, zoom, imageData)]
    |
    v
[OfflineMapManager] updates list of available regions (persisted via Codable)
    |
    v
(Map Usage)
[MapViewController] requests tiles
    |
    v
[OfflineTileOverlay] -> [OfflineTileCache.fetch(...)] -> [UIImage for tile]
    |
    v
[Map Rendering]
```

### 5. Track Recording Lifecycle

```text
[GPS Location Updates]
    |
    v
[TrackRecordingService] (if isRecording)
    |
    v
CLLocation -> TrackPoint
    |
    v
Append to currentTrack.points
    |
    +--> Update live metrics (distance, speed, avg speed, elevationGain)
    |
    v
[TrackOverlayRenderer / BreadcrumbTrailOverlay] reads currentTrack and draws

Saving:

[User taps "Save Track"]
    |
    v
[currentTrack] appended to savedTracks
    |
    v
[RouteStorageManager / TrackPersistence] encodes Track via Codable -> disk
```

### 6. Certificate Lifecycle

```text
[User selects .p12 in CertificateEnrollmentView]
    |
    v
Read file as Data + password
    |
    v
[CertificateManager.importCertificate(from:data, password)]
    |
    v
Validate + parse certificate -> TAKCertificate model
    |
    +--> [Keychain] (saveCertificate)
    |
    v
[certificates: [TAKCertificate]] updated (Published)

Connection:

[User chooses certificate for server]
    |
    v
[CertificateManager.selectedCertificate]
    |
    v
[TAKService.connect(..., certificateName, certificatePassword)]
    |
    v
Handshake with TAK server using stored credentials
```

---

This analysis is constrained to the code and documentation present in the repository under `/apps/omnitak`, especially `docs/Architecture.md` and `docs/API/*.md`, and the directory structure. All transformations and flows described are grounded in those existing definitions and patterns.