# Data Flow Analysis

## Data Models Overview

OmniTAK Mobile’s iOS app (`apps/omnitak/OmniTAKMobile`) is built around a set of Swift `struct` models plus a smaller set of reference‑types for persistence helpers. Models are centralized under `OmniTAKMobile/Models` and are described in `apps/omnitak/docs/API/Models.md`.

Common characteristics:

- **Swift `struct`s** for nearly all domain data
- Conform to `Identifiable`, `Codable`, and typically `Equatable`
- Organized by domain: Chat, CoT, Map/Waypoint/Route, Team, Geofence, OfflineMaps, Mission Packages, etc.

Selected concrete examples (all drawn from `Models.md` and referenced code):

### CoT & Tactical Entities

**File family:** `OmniTAKMobile/Models/*Models.swift`, plus `CoT/` generators and parsers.

- `CoTEvent` – canonical parsed CoT message:

```swift
struct CoTEvent: Identifiable, Codable, Equatable {
    let id: String              // UUID or UID from message
    let uid: String             // CoT UID (e.g., "ANDROID-123")
    let type: String            // CoT type (e.g., "a-f-G-U-C")
    let time: Date
    let start: Date
    let stale: Date
    let how: String

    let coordinate: CLLocationCoordinate2D
    let hae: Double
    let ce: Double
    let le: Double

    let callsign: String
    let team: String?
    let role: String?
    let remarks: String?
}
```

- `EnhancedCoTMarker` – derived display‑oriented marker on the map:

```swift
struct EnhancedCoTMarker: Identifiable, Equatable {
    let uid: String
    var coordinate: CLLocationCoordinate2D
    var callsign: String
    var type: String
    var team: String?
    var lastUpdate: Date

    var trailCoordinates: [CLLocationCoordinate2D] = []
    var trailTimestamps: [Date] = []

    var battery: Int?
    var speed: Double?
    var course: Double?

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdate) > 300 // 5 minutes
    }
}
```

Many tactical report models (`CASRequest`, `MEDEVACRequest`, `SPOTREPReport`, `SALUTEReport`, etc.) use the same pattern: doctrinal fields, timestamps, status, reporter metadata, all `Identifiable + Codable`.

### Chat Models

**File:** `OmniTAKMobile/Models/ChatModels.swift` (documented in `docs/API/Models.md`)

Core entities:

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

enum MessageStatus: String, Codable {
    case pending, sending, sent, delivered, failed
}

struct Conversation: Identifiable, Codable, Equatable {
    let id: String
    var participants: [ChatParticipant]
    var messages: [ChatMessage]
    var unreadCount: Int
    var lastMessage: ChatMessage?
    var isGroupChat: Bool
    var name: String
}

struct ChatParticipant: Identifiable, Codable, Equatable {
    let id: String          // CoT UID
    var callsign: String
    var endpoint: String?
    var lastSeen: Date
    var isOnline: Bool
    var coordinate: CLLocationCoordinate2D?
}

struct ImageAttachment: Codable, Equatable {
    let id: String
    let filename: String
    let mimeType: String
    let fileSize: Int
    var localPath: String?
    var thumbnailPath: String?
    var base64Data: String?
    var remoteURL: String?
}
```

These are the app’s main DTOs for chat: they back SwiftUI views and are transformed into GeoChat/CoT XML or TAK protobufs by `ChatService` and CoT generators.

### Map & Spatial Models

Representative models (from `WaypointModels.swift`, `RouteModels.swift`, `PointMarkerModels.swift`, `TrackModels.swift`, `MeasurementModels.swift`):

```swift
struct Waypoint: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var coordinate: CLLocationCoordinate2D
    var elevation: Double?
    var icon: String
    var color: Color
    var notes: String?
    var createdAt: Date
    var modifiedAt: Date
    var cotType: String
}

struct Route: Identifiable, Codable {
    let id: UUID
    var name: String
    var waypoints: [Waypoint]
    var totalDistance: Double
    var estimatedTime: TimeInterval
    var createdAt: Date
}

struct PointMarker: Identifiable, Codable, Equatable {
    let id: UUID
    let uid: String
    var name: String
    var coordinate: CLLocationCoordinate2D
    var elevation: Double
    var cotType: String
    var icon: String
    var color: UIColor
    var notes: String?
    var createdBy: String
    var createdAt: Date
}
```

These flow through:

- Managers: e.g. `WaypointManager`, `OfflineMapManager`, `MeasurementManager`
- Services: `RoutePlanningService`, `MeasurementService`, `TrackRecordingService`
- Map controllers/overlays: `MapViewController`, `EnhancedMapViewController`, `BreadcrumbTrailOverlay`, `TrackOverlayRenderer`, `OfflineTileOverlay`

### Team, Server, Certificate & System Models

From `Models.md` and managers:

- `TAKServer`: host, port, protocol, TLS flags, credential references. Persisted by `ServerManager`.
- `TAKCertificate`: metadata about imported TLS certs, backing `CertificateManager`.
- Team models (`Team`, `TeamMember`, roles/colors/unit type) back `TeamService` and `TeamStorageManager`.
- Elevation and terrain models: `ElevationProfile`, `ElevationSample` used in `ElevationProfileService` and `ElevationAPIClient`.
- Offline map models: definitions for tile packages, regions, and providers used by `OfflineMapManager`, `OfflineTileCache`, `TileDownloader`.

### Storage‑oriented Models

Under `OmniTAKMobile/Storage/` you have persistence helpers (e.g. `ChatPersistence`, `ChatStorageManager`, `DrawingPersistence`, `RouteStorageManager`, `TeamStorageManager`) which wrap:

- Domain models (`ChatMessage`, `Waypoint`, `Track`, `TeamMember`, etc.)
- Platform stores (`UserDefaults`, file system, likely SQLite via Valdi PersistentStore for some features)

They either directly encode `Codable` models to disk or map them to a more compact on‑disk representation.

---

## Data Transformation Map

This section follows the concrete path data takes between:

- **External interfaces** (TAK server network, Meshtastic, KML/DataPackage import, GPS)
- **Domain models** (Swift structs)
- **Presentation/state** (`ObservableObject` managers, SwiftUI views)
- **Persistence** (UserDefaults, files, local caches)

### 1. CoT and Position / Track Data

**Sources:**

- Network: TAK server via `TAKService`
- GPS: system location callbacks via `PositionBroadcastService`, `TrackRecordingService`
- Meshtastic radio: `MeshtasticService` (bridging to Rust `omnitak-meshtastic`)

**Flow (Inbound CoT):**

1. **TAKService** receives raw messages from the TAK server (see `TAKService.swift` in `Services/`).
   - Keeps counters: `messagesReceived`, `bytesReceived`.
   - Exposes connection state via `@Published` properties for the UI.

2. Raw CoT XML is handed to **`CoTMessageParser`** (`CoT/CoTMessageParser.swift`).
   - Parses XML into `CoTEvent` Swift structs.
   - Validation occurs here: malformed or unsupported XML leads to dropped events or error callbacks (see `docs/Features/CoTMessaging.md`).

3. Parsed `CoTEvent` is distributed:
   - To **`MapStateManager` / `MapOverlayCoordinator`** (update or create `EnhancedCoTMarker` with updated trail and metadata).
   - To **`ChatService`** if event represents GeoChat/Chat traffic.
   - To **Team/Contact state** if event encodes team presence.

4. **Map layer**:
   - `MapOverlayCoordinator` and various overlays (`UnitTrailOverlay`, `TrackOverlayRenderer`, `BreadcrumbTrailOverlay`) translate `EnhancedCoTMarker` + `Track` + breadcrumb data into MapLibre/ArcGIS overlay primitives.

**Flow (Outbound PLI / CoT):**

1. **PositionBroadcastService** combines:
   - Current `CLLocation` (from iOS LocationManager dependency)
   - User metadata (`userCallsign`, `userUID`, `teamColor`, `teamRole`, `userUnitType`, `updateInterval`, `staleTime`)
   into a domain representation for self position.

2. It calls a CoT generator – e.g. `MarkerCoTGenerator` or a dedicated PLI generator in `CoT/Generators/`:
   - Input: domain values (UID, type, coordinate, times, callsign, team, role)
   - Output: CoT XML string representing a `CoTEvent` (with `<point>`, `<detail>`, `<remarks>`, etc.)

3. The generated XML is sent via `TAKService.send(cotMessage:priority:)`.
   - `TAKService` applies network framing/transport encoding dictated by TAK (often TLS+proto, but from Swift it’s an opaque send into Rust via the C FFI header `omnitak_mobile.h`).

4. `TrackRecordingService` publishes breadcrumb points as `Track` models, and may also:
   - Optionally synthesize CoT markers for each breadcrumb (depending on settings).
   - Persist them with `TrackRecordingService` → `TrackOverlayRenderer` and a storage manager.

**Transformation types here:**

- XML ↔ `CoTEvent` (parsing & generation)
- `CoTEvent` → `EnhancedCoTMarker` (derive display + trail)
- `CLLocation` + user settings → `CoTEvent` (for PLI) → XML

### 2. Chat / GeoChat Data

**Sources:**

- User input via `ChatView`, `ConversationView` SwiftUI screens.
- Incoming GeoChat CoT from TAK via `TAKService` + `CoTMessageParser`.

**Outbound flow:**

1. SwiftUI view binds to **`ChatService.shared`** (`@ObservedObject` or `@EnvironmentObject`):
   - Users compose message text bound to some local view state.

2. When sending, UI calls:

```swift
ChatService.shared.sendTextMessage("...", to: conversationId)
```

3. `ChatService.sendTextMessage`:
   - Creates a `ChatMessage` model (status `.pending`, timestamp, sender/recipient UIDs, optional `coordinate` if sending with location).
   - Appends it to its `@Published var messages` and updates the corresponding `Conversation`.
   - Enqueues a `QueuedMessage` into `queuedMessages` for transport.

4. `ChatService.processQueue()`:
   - For each `QueuedMessage`, builds a GeoChat CoT:
     - Uses `ChatXMLGenerator` in `CoT/Parsers` or similar (documentation indicates Chat is encoded as CoT `<detail><__chat>...</__chat></detail>`).
     - Populates XML from `ChatMessage` fields.

   - Sends the resulting XML via `TAKService.send`.

5. On successful send / ACK:
   - Updates `ChatMessage.status` to `.sent` or `.delivered`.
   - If send fails, sets `.failed` and may re‑queue based on retry logic.

6. **Persistence**:
   - `ChatPersistence` / `ChatStorageManager` observes `ChatService.messages` / `conversations` and writes them to local store (UserDefaults and/or file/SQLite).
   - On app launch, persisted data is restored into `ChatService` at configuration time.

**Inbound flow:**

1. Incoming CoT message arrives in `TAKService`, is parsed by `CoTMessageParser`.
2. If recognized as chat:
   - A `ChatCoTGenerator` / `ChatXMLParser` path runs in reverse: extracts message body, sender, recipients, attachments, coordinate into a new `ChatMessage`.
3. `ChatService` adds this `ChatMessage` into in‑memory arrays:
   - Creates or updates `Conversation`.
   - Increments `unreadCount`.
4. `ChatStorageManager` is notified and persists the new message and conversation state.

**Key transformations:**

- `ChatMessage` ↔ CoT/GeoChat XML (via Chat‑specific parser/generator).
- `ChatMessage` + `Conversation` <-> persistent JSON/DB representation via `Codable` and storage helpers.

### 3. Waypoints, Routes, Markers, Geofences

**Inbound from UI:**

1. Users interact through views (`WaypointListView`, `RoutePlanningView`, `DrawingToolsPanel`, `GeofenceManagementView`, etc.).
2. These views interact with managers:
   - `WaypointManager`, `MeasurementManager`, `GeofenceManager`, `DrawingToolsManager`, `OfflineMapManager`.

3. Managers manipulate domain models:
   - Create/update `Waypoint`, `Route`, `PointMarker`, `Geofence`, etc.
   - State is kept in `@Published` arrays (e.g. `[Waypoint]`, `[Route]`).

4. Persistent storage:
   - `RouteStorageManager`, `DrawingPersistence`, `TeamStorageManager`, etc.:
     - Observes arrays in managers or is explicitly called to save.
     - Encodes `Codable` models to JSON and writes to:
       - `UserDefaults` for small lists (e.g. server configs, user preferences).
       - Files in app sandbox for larger or structured data (waypoints/routes).
       - Possibly a Valdi `PersistentStore` (see `src/valdi_modules/valdi/persistence` integration) for some stores.

**Interactions with Map & TAK:**

- Some waypoints/markers can be exported as CoT (e.g. sending a dropped point as a marker to TAK):
  - Domain models (`PointMarker`, `Waypoint`) → `MarkerCoTGenerator` → CoT XML → `TAKService`.
- Conversely, remote markers from CoT can be materialized locally as `PointMarker` or `Waypoint` instances.
- Offline map sources (`OfflineMapModels`, `OfflineTileCache`, `TileDownloader`) convert between:
  - A domain `OfflineRegion`/`OfflineTilePackage` model.
  - Tile URLs / MBTiles / local directory structures for MapLibre overlays.

### 4. Team & Presence

**Flow:**

1. `TeamService` and `TeamManager` track:
   - `Team` models, `TeamMember` models, color/role/unit type.

2. Inbound: CoT `CoTEvent` for known teammates update:
   - Location, `team` field, and presence.
   - `TeamService` correlates events with known `TeamMember` entries.

3. Outbound: Changing your team role/color in UI:
   - Updates `PositionBroadcastService`’s `teamColor`, `teamRole`, `userUnitType`.
   - Affects produced PLI CoT events (and thus remote clients’ representation of you).

4. Persistence:
   - `TeamStorageManager` persists membership and preferences, using JSON via `Codable`.

### 5. Certificates & Servers

**Flow: Server config**

1. UI (`TAKServersView`, `ServerPickerView`, `QuickConnectView`) manipulates `ServerManager.shared`:

```swift
class ServerManager: ObservableObject {
    static let shared = ServerManager()

    @Published var servers: [TAKServer] = []
    @Published var selectedServer: TAKServer?
    @Published var activeServerIndex: Int = 0
}
```

2. `addServer`, `removeServer`, `updateServer`, `selectServer` modify `servers` and `selectedServer`.

3. Persistence (`Managers.md`):

```swift
private func saveServers() {
    if let encoded = try? JSONEncoder().encode(servers) {
        UserDefaults.standard.set(encoded, forKey: "tak_servers")
    }
}
```

4. On app start, `ServerManager` reads that key back and decodes `[TAKServer]`.

5. When `selectedServer` changes, `ServerManager` triggers reconnection via `TAKService.connect(...)` with host/port/protocol from `TAKServer`.

**Flow: Certificates**

1. `CertificateManager.shared` holds:

```swift
class CertificateManager: ObservableObject {
    static let shared = CertificateManager()

    @Published var certificates: [TAKCertificate] = []
    @Published var selectedCertificate: TAKCertificate?
}
```

2. Import path:

```swift
func importCertificate(from data: Data, password: String) throws -> TAKCertificate
```

- Parses `.p12` data, validates password, extracts cert identity.
- On success, returns a `TAKCertificate` with metadata, which is appended to `certificates`.

3. `saveCertificate(_ name:data:password:)` stores the cert in iOS Keychain.

4. When connecting, `ServerManager` / UI pass the chosen cert’s identity to `TAKService.connect` via parameters like `certificateName` and `certificatePassword`. The Rust `omnitak-cert` crate and `enrollment_ffi.rs` handle the deeper PKI/TAK specifics on the Rust side.

---

## Storage Interactions

Storage in this project is multi‑layered:

- **Swift‑side simple persistence**: `UserDefaults` + filesystem via `Codable`.
- **Valdi PersistentStore**: generic JS/TS accessible key‑value store, which can be used by modules (in TS side, e.g. Android app variant).
- **Rust‑side persistent components**: TAK client core may maintain its own stores (not visible directly from Swift; see `crates/omnitak-*`).
- **Tile caches & offline content**: disk‑based caches for maps and media.

### 1. UserDefaults & JSON

From `ServerManager` example:

- Encode `servers: [TAKServer]` using `JSONEncoder`.
- Save as Data under `tak_servers`.
- On initialization, decode from that key.

This pattern is repeated for:

- Server profiles
- App preferences (e.g. map settings, PLI interval, last selected tools)
- Possibly chat, team, and other smaller lists where random access performance is not critical.

Advantages: no schema migration layer, rely on `Codable`. Risk: large arrays stored fully at once; `didSet` triggers full rewrites.

### 2. File‑based persistence helpers

Under `OmniTAKMobile/Storage`:

- **`ChatPersistence` / `ChatStorageManager`**
  - Likely maintain serialized conversations and messages to dedicated JSON files under app documents or application support directory.
  - Offer batch save/restore per conversation instead of entire message arrays.

- **`DrawingPersistence`**
  - Serializes geometry/drawing layers so drawing overlays (`DrawingModels`, `DrawingToolsManager`) can restore shapes.

- **`RouteStorageManager`, `TeamStorageManager`**
  - Similar responsibilities for their domains.

Pattern:

- Domain manager holds `@Published` arrays.
- Storage manager exposes methods like:
  - `loadXxx()` to return `[Model]` on startup.
  - `saveXxx(_:)` to persist arrays.
- Managers call them in `init()` or when state changes.

### 3. Tile Cache & Offline Maps

**Files:** `OfflineTileCache.swift`, `TileDownloader.swift`, `OfflineMapModels.swift`, `OfflineMapManager`.

- `OfflineTileCache` defines a small storage abstraction:
  - Key: tile coordinate (z/x/y) or some region ID.
  - Value: tile image data (PNG/JPEG).
  - Underlying store: disk directory with hashed filenames, possibly an LRU eviction policy.

- `TileDownloader`:
  - Uses network to fetch tiles from remote servers or from an ArcGIS/MapLibre provider (via `ArcGISFeatureService`, `ArcGISTileSource`).
  - Writes to `OfflineTileCache` to avoid repeated network calls.

Data flow:

- `OfflineMapManager` determines what regions to download.
- `TileDownloader` requests thousands of tile URLs.
- Each tile response is `Data` → optionally validated → written to `OfflineTileCache`.
- Map overlays use the cache (or fallback to network) to render tiles.

### 4. Valdi PersistentStore & TS side

While the main iOS app Swift code doesn’t directly call the Valdi `PersistentStore`, some of the cross‑platform code (Valdi modules for Android/web) uses:

- `src/valdi_modules/src/valdi/persistence/PersistentStore.ts`

This store:

- Implements key/value persistence, backed by a native module:
  - `PersistentStoreNative` (web or native variant).
- Serializes typical JSONish data types.
- For OmniTAK Mobile’s Valdi/TS apps (Android or plugin UIs), it plays the same role as `UserDefaults`.

---

## Validation Mechanisms

Validation and integrity checking is present at several levels:

### 1. Model‑level implicit validation

Because models are mostly simple `struct`s with non‑optional required fields:

- Creation of invalid objects is prevented by initializer signatures.
- Example: `CoTEvent` requires `uid`, `type`, timestamps, and location.

### 2. Parser/Generator Validation

**CoT and XML:**

- `CoTMessageParser`:
  - Validates that required XML elements exist and are well‑formed.
  - Fails or logs errors for:
    - Missing `<point>` coordinates.
    - Invalid date/timestamp formats.
    - Unknown message types.

- `ChatXMLParser` / `ChatXMLGenerator`:
  - Ensure `<detail>` structures satisfy TAK/GeoChat schema.
  - If parse fails, the message is discarded or converted into a generic textual fallback.

**KML/KMZ:**

- `KMLParser.swift` and `KMZHandler.swift`:
  - Parse external KML/KMZ into internal models.
  - Validate coordinates, styles, placemark naming.
  - Feed into `KMLMapIntegration` and `KMLOverlayManager`.

**Meshtastic Protobuf:**

- `MeshtasticProtobufParser.swift`:
  - Uses generated protobuf code (`MeshtasticProtoMessages.swift`) to decode radio messages.
  - Validation is enforced by protobuf schema types.

### 3. Input & Business‑Rule Validation

**CertificateManager:**

- Methods like `importCertificate(from:password:)`:
  - Use Keychain/PKCS#12 APIs.
  - Throw `CertificateError` on invalid password, corrupt file, unsupported key usage.
  - Callers must `do/catch`, as shown in docs.

**ServerManager:**

- Ensures indices passed into `removeServer(at:)` and `updateServer(at:with:)` are valid.
- Might normalize host/protocol strings; persists only valid JSON.

**Services:**

- `ChatService`:
  - Prevents sending empty messages or invalid recipients.
  - Queues unsent messages when `TAKService.isConnected == false`.
  - Enforces deduplication/idempotency for re‑queued items.

- `PositionBroadcastService`:
  - Guards broadcasting when GPS unavailable or `isEnabled == false`.
  - Ensures update intervals and stale times remain within sensible bounds.

### 4. Error Propagation

Most validation failures are surfaced as:

- Swift `Error` thrown from managers (`CertificateError`, file IO errors).
- Logging and ignoring invalid network messages in parsers.
- Updating state flags (`connectionStatus`, `isConnected`, `queuedMessages`) so UI can reflect the issue.

---

## State Management Analysis

SwiftUI + ObservableObject/Published is the primary state pattern.

### 1. Managers as State Hubs

From `Managers.md`:

> Managers are `ObservableObject` classes that manage state for specific features. They expose `@Published` properties and coordinate between Services and Views.

Examples:

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

They:

- Hold domain collections (`[TAKServer]`, `[ChatMessage]`, `[Waypoint]`, etc.)
- Persist via `didSet` of `@Published` properties.
- Wrap service calls (e.g. when server changes, call `TAKService.connect`).

### 2. Services as Business/Network Layer

Services are also `ObservableObject`s, but oriented more toward operations:

Examples (from `Services.md`):

- `TAKService`: networking and connection status
- `ChatService`: messaging queue, participants, conversations
- `PositionBroadcastService`: periodic PLI
- `TrackRecordingService`: live track state and recordings
- `NavigationService`, `RoutePlanningService`, `VideoStreamService`, `TeamService`, `MissionPackageSyncService`, `OfflineMapManager` uses these heavily.

These often use `static let shared` singletons and `@Published` for:

- Operational flags (`isConnected`, `isRecording`, `isEnabled`)
- Live metrics (`messagesSent`, `liveSpeed`, `broadcastCount`)

### 3. SwiftUI Views Binding

Under `OmniTAKMobile/Views/`:

- `ContentView`, `ChatView`, `ConversationView`, `RoutePlanningView`, `TrackRecordingView`, `TAKServersView`, etc.
- Each view:

```swift
@ObservedObject var chatService = ChatService.shared
@ObservedObject var serverManager = ServerManager.shared
```

or:

```swift
@EnvironmentObject var mapStateManager: MapStateManager
```

- Views use `@State` for local UI fields (e.g. textfields) and commit to managers/services on user actions.

### 4. Map State & Overlays

`MapStateManager` (controllers under `Map/Controllers`) centralizes:

- Current map mode (2D/3D, follow‑me mode, overlays toggles).
- Collections of visible markers (`[EnhancedCoTMarker]`), shapes, measurement overlays.

`MapOverlayCoordinator` subscribes to those state changes and drives:

- `BreadcrumbTrailOverlay`, `UnitTrailOverlay`, `MeasurementOverlay`, `VideoMapOverlay`, etc.

### 5. Concurrency & Threading

- Valdi runtime and HermES/QuickJS handle JS/TS side concurrency.
- For Swift services, standard iOS pattern:
  - Use `DispatchQueue` for long‑running operations (downloads, imports).
  - Update `@Published` properties on main queue.

The code uses ObservedObjects extensively; any heavy asynchronous IO is offloaded to background queues.

---

## Serialization Processes

Serialization/deserialization spans several concrete mechanisms:

### 1. Swift Codable (JSON / Plist)

Most models in `OmniTAKMobile/Models` are `Codable`:

- Used for:
  - Persistence (UserDefaults, files).
  - Inter‑process storage (e.g. packaging mission data).
- Example from `ServerManager`:

```swift
private func saveServers() {
    if let encoded = try? JSONEncoder().encode(servers) {
        UserDefaults.standard.set(encoded, forKey: "tak_servers")
    }
}
```

Other persistence helpers reuse the same pattern for their arrays (chat logs, routes, drawings, mission package metadata).

### 2. XML Serialization

**CoT and Chat XML:**

- For CoT:
  - `CoTMessageParser.swift` parses incoming CoT XML into `CoTEvent`.
  - Generators in `CoT/Generators` such as `MarkerCoTGenerator`, `TeamCoTGenerator`, `ChatCoTGenerator`, `GeofenceCoTGenerator` build XML from domain models.

- For chat:
  - `ChatXMLGenerator.swift` constructs `<detail><__chat>...</__chat></detail>` segments and encodes attachments and metadata.
  - `ChatXMLParser.swift` in `CoT/Parsers` does the reverse.

These operate on `String` or `Data` APIs from Foundation’s `XMLParser`.

### 3. Protobuf Serialization

**Meshtastic:**

- `MeshtasticProtoMessages.swift`, `MeshtasticProtobufParser.swift` use a generated protobuf representation for messages defined in `crates/omnitak-meshtastic/proto/meshtastic.proto`.

**Valdi / internal tooling:**

- Under `src/valdi_modules/valdi/valdi_protobuf`, there’s a generic protobuf implementation used in other parts of the repo (compiler, benchmarks). The mobile app specifically uses the Meshtastic proto set for radio communication.

### 4. Rust FFI: TAK Core & Encryption

Swift integrates with Rust through:

- `OmniTAKMobile.xcframework/.../omnitak_mobile.h`
- Rust sources in `crates/omnitak-mobile/src`:
  - `connection.rs`, `callbacks.rs`, `enrollment_ffi.rs`, `error.rs`, `lib.rs`.

Data crossing this boundary:

- Swift strings, bytes (CoT XML messages, certificate material, configuration JSON) → C FFI → Rust `omnitak-client`, `omnitak-cert`, `omnitak-server` libraries.
- Rust handles:
  - TAK protocol framing (KLV/Protobuf).
  - TLS / X.509 PKI.
  - Multi‑server routing and federation (per `MultiServerFederation.swift` bridging logic).
- Errors and events are returned via callbacks defined in `callbacks.rs` and `callbacks.rs` Swift/Obj‑C side wrappers.

### 5. KML/KMZ & Mission Packages

- `KMLParser.swift`, `KMZHandler.swift`:
  - Parse KML/KMZ into internal waypoint/overlay models.
  - Extract Placemark coordinates and style to `Waypoint`, `PointMarker`, or `DrawingModels`.

- `DataPackageManager`, `MissionPackageModels`:
  - Handle TAK mission packages:
    - Archives (ZIP) with metadata XML.
    - Convert them into internal mission models and to/from disk.

---

## Data Lifecycle Diagrams

Below are high‑level, text‑based lifecycle diagrams for key data paths.

### A. Chat Message Lifecycle

```text
User types text in ChatView
    |
    v
[SwiftUI View] --onSend--> ChatService.sendTextMessage(text, to:)
    |
    | 1) Build ChatMessage (status = pending)
    | 2) Append to messages, update Conversation
    | 3) Append QueuedMessage (wrapping ChatMessage)
    v
ChatService.queuedMessages
    |
    v
ChatService.processQueue()
    |
    | 4) For each QueuedMessage:
    |      a) Use ChatXMLGenerator to build CoT/GeoChat XML from ChatMessage
    |      b) Call TAKService.send(cotMessage: xml)
    v
TAKService
    |
    | 5) Swift -> Rust FFI (omnitak_mobile.h)
    | 6) Rust TAK client serializes to TAK protocol, sends over TLS/UDP
    v
Network
    |
    v
Remote TAK Server & Peers
```

**Inbound message:**

```text
Network
    |
    v
Rust TAK client receives data
    |
    v
TAKService callback (Swift)
    |
    | 1) Raw CoT XML passed to CoTMessageParser
    v
CoTMessageParser
    |
    | 2) Detects Chat CoT, uses ChatXMLParser
    v
ChatXMLParser
    |
    | 3) Build ChatMessage + Conversation metadata
    v
ChatService
    |
    | 4) Append message to messages & conversation
    | 5) Update unreadCount
    | 6) Notify SwiftUI via @Published
    v
SwiftUI ChatView/ConversationView (display new message)
```

Persistence overlay:

```text
ChatService.messages / conversations
    |
    v
ChatStorageManager / ChatPersistence
    |
    | Encode via JSONEncoder (Codable)
    v
Disk (UserDefaults / files)
```

On app launch:

```text
Disk
    |
    v
ChatStorageManager.load()
    |
    v
ChatService.messages, ChatService.conversations
```

### B. PLI (Position) Lifecycle

```text
CoreLocation -> LocationManager
    |
    v
PositionBroadcastService (has userCallsign, userUID, teamColor, teamRole)
    |
    | 1) Timer / update cycle triggers broadcastPositionNow()
    | 2) Build logical CoTEvent fields (type, time, stale, coord)
    | 3) Use CoT generator (MarkerCoTGenerator or dedicated PLI generator)
    v
CoT XML String
    |
    v
TAKService.send(cotMessage:)
    |
    v
Rust TAK client -> Network -> TAK server & peers
```

Remote client lifecycle is reciprocal: inbound CoT with your UID becomes an `EnhancedCoTMarker` on their map.

### C. Waypoint / Route Lifecycle

```text
User adds waypoint in WaypointListView / Map context menu
    |
    v
WaypointManager.addWaypoint(...)
    |
    | 1) Construct Waypoint struct
    | 2) Append to @Published [Waypoint]
    v
WaypointManager.waypoints
    |
    | 3) RoutePlanningService or NavigationService may reference them
    v
RoutePlanningService.buildRoute(from waypoints)
    |
    | 4) Create Route model, compute totalDistance, estimatedTime
    v
Route models
    |
    v
RouteStorageManager.save(routes)
    |
    | 5) JSON encode via Codable, write to disk
    v
Disk (routes.json, for example)
```

Map rendering:

```text
WaypointManager.waypoints / RouteService.routes
    |
    v
MapStateManager (exposes overlay sources)
    |
    v
MapOverlayCoordinator
    |
    v
MapViewController / EnhancedMapViewController
    |
    v
MapLibre / ArcGIS overlays (pins, polylines)
```

### D. Server & Certificate Lifecycle

```text
User creates server entry in TAKServersView
    |
    v
ServerManager.addServer(TAKServer)
    |
    | 1) Append to servers
    | 2) saveServers() -> JSONEncoder -> UserDefaults["tak_servers"]
    v
User selects server in ServerPickerView
    |
    v
ServerManager.selectServer(server)
    |
    | 3) Update selectedServer
    | 4) Trigger TAKService.connect(host:port:protocolType: useTLS: certificateName: ...)
    v
TAKService.connect(...)
    |
    v
Rust omnitak-client + omnitak-cert: establish TLS/TAK session
```

Certificate import:

```text
User chooses .p12 in CertificateImportView -> DataPackageImportView
    |
    v
CertificateManager.importCertificate(from: data, password:)
    |
    | 1) Validate p12, build TAKCertificate
    | 2) Append to @Published certificates
    | 3) saveCertificate(name:data:password:) -> Keychain APIs
    v
Keychain (persistent)
```

On connect:

```text
ServerManager.selectedServer + CertificateManager.selectedCertificate
    |
    v
TAKService.connect(... certificateName/password ...)
    |
    v
Rust side loads cert from Keychain / file path -> TLS handshake
```

---

This analysis is grounded in the existing documentation under `.ai/docs/data_flow_analysis.md` and `apps/omnitak/docs/API/*.md` plus the visible file structure. For deeper field‑level transformations (e.g. exact XML tags, protobuf field names, or concrete storage filenames), the corresponding Swift source files under `OmniTAKMobile/CoT`, `OmniTAKMobile/Services`, `OmniTAKMobile/Storage`, and `OmniTAKMobile/Managers` provide the implementation details.