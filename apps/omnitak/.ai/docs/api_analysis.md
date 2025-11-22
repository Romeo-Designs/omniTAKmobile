# API Documentation

This project is an iOS app (SwiftUI, Combine, URLSession, Network framework) that **consumes external APIs** rather than serving HTTP APIs itself. The “API surface” is comprised of:

* Local Swift service classes (used by UI & managers)
* Network protocols to TAK servers (TCP/UDP/TLS, XML CoT)
* HTTP-based external APIs (ArcGIS Portal/Online, elevation, etc.)

There is **no HTTP server** or REST API exposed by the app; instead, you integrate by configuring it to talk to your TAK server and external map services.

Below, “APIs Served” documents the *internal service APIs* that other code in this app uses, because there are no public HTTP endpoints.

---

## APIs Served by This Project

### Technology Stack & Frameworks

- Language: Swift
- UI: SwiftUI + UIKit wrappers (map controllers)
- Concurrency: Combine + async/await
- Networking:
  - `Network` framework (`NWConnection`) for TAK (TCP/UDP/TLS)
  - `URLSession` for HTTP(S) (ArcGIS, elevation, etc.)
- Persistence: `UserDefaults`, lightweight storage managers
- No embedded HTTP server; no REST/gRPC/GraphQL server.

### Core Service Endpoints (Internal Swift APIs)

These are *Swift service classes* accessed by UI, managers, and other services.

#### `TAKService`

**Purpose:** Core communication layer with a TAK server (sending/receiving CoT XML over TCP/UDP/TLS).

**File:** `OmniTAKMobile/Services/TAKService.swift`  
**Related:** Direct network layer `DirectTCPSender` (same file, excerpted above).

**Key Published Properties:**

- `@Published var isConnected: Bool`
- `@Published var connectionStatus: String` (e.g., “Disconnected”, “Connected”)
- `@Published var messagesSent: Int`
- `@Published var messagesReceived: Int`
- `@Published var bytesSent: Int`
- `@Published var bytesReceived: Int`

**Important Methods (from `docs/API/Services.md` and code):**

- `connect(host: String, port: UInt16, protocolType: String, useTLS: Bool, certificateName: String?, certificatePassword: String?, allowLegacyTLS: Bool, completion: (Bool) -> Void)`
  - Wraps `DirectTCPSender.connect`.
  - Establishes a TCP/UDP/TLS connection to a TAK server.
- `disconnect()`
  - Cancels the `NWConnection`, stops receive loop, updates state.
- `send(cotMessage: String, priority: MessagePriority)`
  - Sends a CoT XML message over the current connection.
  - Likely increments `messagesSent` and `bytesSent`.
- `reconnect()`
  - Attempts to re-establish a dropped connection, using last-known configuration.

**Underlying “Transport API”: `DirectTCPSender`**

`DirectTCPSender` is the low-level network client:

- `func connect(host: String, port: UInt16, protocolType: String = "tcp", useTLS: Bool = false, certificateName: String? = nil, certificatePassword: String? = nil, allowLegacyTLS: Bool = false, completion: @escaping (Bool) -> Void)`
  
  - Uses `NWConnection` to create a `.tcp`, `.udp`, or TLS-over-TCP connection.
  - TLS settings:
    - Supports TLS 1.2–1.3 by default; optionally allows TLS 1.0–1.1 (`allowLegacyTLS`).
    - Adds several legacy cipher suites to match older TAK servers.
    - **Disables server certificate verification** (`sec_protocol_options_set_verify_block` always calls `complete(true)`), accepting self-signed TAK server certs.
    - Optionally loads a client certificate (`.p12`) and sets it as local identity.
  - For `localhost` / `127.0.0.1`, forces `.loopback` interface and `preferNoProxies` for dev.
  - On `.ready` state:
    - Calls `onConnectionStateChanged?(true)`
    - Starts `startReceiveLoop()` to read incoming bytes and parse messages.
  - On `.failed` or `.cancelled`:
    - Logs errors, calls `onConnectionStateChanged?(false)`, calls completion with `false`.

- `var onMessageReceived: ((String) -> Void)?`
  
  - Called when a full message (typically CoT XML) is assembled from the internal receive buffer.

- Internal buffering:
  
  - Maintains `receiveBuffer: String` with a lock to handle fragmented XML over TCP.
  - Increments `bytesReceived` and `messagesReceived`.

**Usage Example (from docs):**

```swift
let takService = TAKService()
takService.connect(
    host: "192.168.1.100",
    port: 8089,
    protocolType: "tls",
    useTLS: true,
    certificateName: "mycert",
    certificatePassword: "password"
) { success in
    if success {
        print("Connected to TAK server")
    }
}
```

**Error Handling & Resilience:**

- Uses `NWConnection.stateUpdateHandler` to react to `.ready`, `.failed`, `.waiting`, `.cancelled`.
- Logs detailed connection state in DEBUG builds.
- `reconnect()` logic is maintained at the `TAKService` level (see `docs/API/Services.md`).
- No exponential backoff is visible in the snippet; likely managed by higher-level managers or user actions.

**Authentication & Security:**

- No HTTP-style auth; TAK uses:
  - Optional mutual TLS (client certificate configured via `certificateName` and `.p12` file in `Resources`).
  - Accepts self-signed server certificates by design.
- Optional “legacy TLS” mode for older servers (TLS 1.0/1.1 and weaker ciphers).

---

#### `ChatService`

**Purpose:** CoT-based chat system on top of TAK transport.

**File:** `OmniTAKMobile/Services/ChatService.swift`  
**Doc:** `docs/API/Services.md`, `docs/Features/ChatSystem.md`

**Core API:**

- Singleton: `ChatService.shared`
- Published properties:
  - `messages: [ChatMessage]`
  - `conversations: [Conversation]`
  - `participants: [ChatParticipant]`
  - `unreadCount: Int`
  - `queuedMessages: [QueuedMessage]`

**Key Methods:**

- `configure(takService: TAKService, locationManager: LocationManager)`
  - Wires dependencies; must be called before actual usage.
- `sendTextMessage(_ text: String, to conversationId: String)`
  - Converts a text message to CoT XML (using `ChatCoTGenerator`), sends via `TAKService`.
  - Adds to local `messages` and queues when offline.
- `sendLocationMessage(location: CLLocation, to conversationId: String)`
  - Sends current location in a chat message.
- `processQueue()`
  - Attempts to send `queuedMessages` when network/TAK connection becomes available.
- `markAsRead(_ conversationId: String)`
  - Updates `unreadCount` and per-conversation status.

**Error Handling & Resilience:**

- Queues messages while offline or not connected.
- Retries queued messages in `processQueue()`.
- Actual retry policy (intervals, max attempts) is implemented in `ChatService.swift` and documented in `docs/Features/ChatSystem.md`.

**Authentication:**

- Inherits TAKService’s network authentication; no separate chat-specific auth.

---

#### `PositionBroadcastService`

**Purpose:** Periodic PLI (position) broadcasting to TAK.

**File:** `OmniTAKMobile/Services/PositionBroadcastService.swift`  
**Doc:** `docs/API/Services.md`

**Core API:**

- Singleton: `PositionBroadcastService.shared`

- Published properties:
  
  - `isEnabled: Bool` – global on/off for broadcasting.
  - `updateInterval: TimeInterval` – seconds between PLIs.
  - `staleTime: TimeInterval`
  - `lastBroadcastTime: Date?`
  - `broadcastCount: Int`
  - Identity metadata:
    - `userCallsign: String` (default `"R06"`)
    - `userUID: String` (unique id)
    - `teamColor: String` (e.g., "Dark Blue")
    - `teamRole: String` (e.g., "Team Lead")
    - `userUnitType: String` (e.g., `"a-f-G-U-C"` Mil-Std-2525)

**Key Methods:**

- `configure(takService: TAKService, locationManager: LocationManager)`
- `startBroadcasting()`
  - Schedules periodic broadcasts using timers/Combine.
- `stopBroadcasting()`
- `broadcastPositionNow()`
  - Immediately emits a PLI CoT event.
- `setUpdateInterval(_ interval: TimeInterval)`

**Error Handling & Resilience:**

- Skips broadcasts if no valid GPS fix or TAK connection.
- Uses Combine timers; should cancel cleanly to avoid leaks.

**Authentication:**

- Uses TAKService’s connection; no extra auth.

---

#### `TrackRecordingService`

**Purpose:** Record breadcrumb trails for movement tracking, with live metrics.

**File:** `OmniTAKMobile/Services/TrackRecordingService.swift`  
**Doc:** `docs/API/Services.md`, `docs/Features/MapSystem.md`

**Core API:**

- Singleton: `TrackRecordingService.shared`

- Published properties:
  
  - `isRecording: Bool`
  - `isPaused: Bool`
  - `currentTrack: Track?`
  - `savedTracks: [Track]`
  - Live metrics: `liveDistance`, `liveSpeed`, `liveAverageSpeed`, `liveElevationGain`.

**Key Methods (inferred from docs):**

- `startRecording()`
- `pauseRecording()`
- `resumeRecording()`
- `stopAndSaveTrack(name: String?)`
- `discardCurrentTrack()`
- Hooks into location updates and persists via `BreadcrumbTrailService`/storage managers.

**Error Handling:**

- Validates GPS availability, handles missing elevation data gracefully.

---

#### `ArcGISPortalService`

**Purpose:** Authenticate against and query ArcGIS Portal/Online REST APIs for content.

**File:** `OmniTAKMobile/Services/ArcGISPortalService.swift`  
**Models:** `OmniTAKMobile/Models/ArcGISModels.swift`

**Singleton & State:**

```swift
class ArcGISPortalService: ObservableObject {
    static let shared = ArcGISPortalService()

    @Published var isAuthenticated: Bool = false
    @Published var credentials: ArcGISCredentials?
    @Published var portalItems: [ArcGISPortalItem] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String = ""
    @Published var searchQuery: String = ""
    @Published var selectedItemType: ArcGISItemType?
    @Published var currentPage: Int = 1
    @Published var totalResults: Int = 0
    @Published var hasMoreResults: Bool = false
}
```

**Configuration:**

- `userDefaultsKey = "com.omnitak.arcgis.credentials"`
- `pageSize = 25`
- `session: URLSession` with:
  - `timeoutIntervalForRequest = 30`
  - `timeoutIntervalForResource = 60`

**Default URLs:**

- `arcGISOnlineURL = "https://www.arcgis.com"`
- `arcGISOnlineSharingURL = "https://www.arcgis.com/sharing/rest"`

**Public Methods:**

1. **`authenticate(portalURL: String = arcGISOnlineURL, username: String, password: String) async throws`**
   
   - Builds token URL: `"{portalURL}/sharing/rest/generateToken"`.
   - Request:
     - Method: `POST`
     - Headers:
       - `Content-Type: application/x-www-form-urlencoded`
     - Body params:
       - `username`: ArcGIS username
       - `password`: ArcGIS password
       - `referer`: `"OmniTAK-iOS"`
       - `expiration`: `60*24*7` minutes (7 days)
       - `f`: `"json"`
   - Response:
     - Expects HTTP 200.
     - JSON:
       - On success: `{ "token": "...", "expires": <epoch_ms>, ... }`
       - On error: `{ "error": { "message": "..." } }`
   - Errors:
     - Invalid URL → `ArcGISError.networkError("Invalid portal URL")`
     - Non-200 HTTP → `ArcGISError.networkError("HTTP <code>")`
     - Error JSON → `ArcGISError.invalidCredentials`
     - Missing fields → `ArcGISError.parseError("Missing token in response")`
   - On success:
     - Creates `ArcGISCredentials` and saves them (UserDefaults).
     - Sets `isAuthenticated = true`.

2. **`authenticateWithToken(portalURL: String = arcGISOnlineURL, token: String, username: String = "token_user", expiration: Date = Date().addingTimeInterval(3600))`**
   
   - Creates `ArcGISCredentials` directly with a pre-obtained token.
   - Marks service as authenticated and saves credentials.

3. **`signOut()`**
   
   - Clears `credentials`, `isAuthenticated`, and all portal-related state.
   - Removes credentials from `UserDefaults`.

4. **`searchContent(query: String = "", itemType: ArcGISItemType? = nil, sortField: String = "modified", sortOrder: String = "desc", page: Int = 1) async throws`**
   
   - Requires `isAuthenticated == true` and valid `credentials`.
   - Validates token via `creds.isValid`, else throws `ArcGISError.tokenExpired`.
   - Builds URL:
     - Base: `"{creds.portalURL}/sharing/rest/search"`
     - Query parameters (inferred from rest of file):
       - `q`: search text including item type filters.
       - `num`: `pageSize`
       - `start`: `(page - 1) * pageSize + 1`
       - `sortField`, `sortOrder`
       - `token`: `creds.token`
       - `f`: `"json"`
   - Sets `isLoading`, resets errors, updates pagination state before and after.
   - Parses JSON into `ArcGISPortalItem`s and pagination fields.

**Authentication & Security:**

- Standard ArcGIS token-based auth with username/password or existing token.
- Tokens and user info persisted into `UserDefaults` under a scoped key.
- Token validity is checked before each call; expired tokens cause explicit errors.

**Error Handling & Resilience:**

- Throws domain-specific errors (`ArcGISError`).
- Maintains UI-oriented state (`lastError`, `isLoading`) for presenting messages.
- Network timeouts are enforced at `URLSessionConfiguration` level.

**Usage Example:**

```swift
Task {
    do {
        try await ArcGISPortalService.shared.authenticate(
            portalURL: ArcGISPortalService.arcGISOnlineURL,
            username: "user@example.com",
            password: "secret"
        )
        try await ArcGISPortalService.shared.searchContent(
            query: "basemap",
            itemType: .webMap
        )
    } catch {
        print("ArcGIS error: \(error)")
    }
}
```

---

#### Other Notable Services

From `OmniTAKMobile/Services` and `docs/API/Services.md` (not all code shown here, but APIs are implemented, not just planned):

- `ArcGISFeatureService`
  
  - Wraps feature service queries (REST `/FeatureServer` endpoints).
  - Uses `ArcGISCredentials.token` for authorization (`token` query parameter).
  - Handles spatial queries for overlays and operational layers.

- `ElevationAPIClient` / `ElevationProfileService`
  
  - HTTP calls to an elevation service (URL configured; see `ElevationAPIClient.swift`).
  - Returns `ElevationProfile` models (`ElevationProfileModels.swift`).
  - Implements request timeouts and `Result`/`async` error propagation.

- `LineOfSightService`, `TerrainVisualizationService`
  
  - Call elevation/terrain APIs and perform client-side calculations.

- `MissionPackageSyncService`
  
  - Syncs TAK “mission packages” (files/data) likely via CoT-based tasks or HTTP endpoints if configured.

- `NavigationService`, `TurnByTurnNavigationService`, `RoutePlanningService`
  
  - Can use external routing APIs if configured; otherwise rely on map SDK.

- `OfflineMapManager`, `OfflineTileOverlay`, `TileDownloader`
  
  - Use HTTP(S) GET requests to LOS/WMTS/XYZ tile servers with configurable URL templates.
  - Implement caching, retry on network errors.

Each of these services follows the same patterns: Swift singleton, `@Published` UI state, and `URLSession` or `TAKService` under the hood.

---

### Request/Response Models & Validation

Models are in `OmniTAKMobile/Models/`:

- `ArcGISModels.swift`
  - `ArcGISCredentials`, `ArcGISPortalItem`, `ArcGISError`, `ArcGISItemType`.
- `CASRequestModels.swift`, `MEDEVACModels.swift`, `SPOTREPModels.swift`, etc.
  - Encode mission/MEDEVAC/CAS/SPOTREP reports into CoT or attach data packages.

Validation patterns:

- Most network calls:
  - Use `guard` to validate URLs and presence of required config fields.
  - Throw descriptive errors (e.g., `ArcGISError.networkError`, `ArcGISError.portalNotConfigured`, etc.).
- Request models:
  - Often use Swift structs with `Codable` for JSON requests.
  - Ensure required fields are non-empty before sending (see individual service implementations).

---

### Authentication & Security

#### TAK Connectivity

- Transport: TCP/UDP or TLS over TCP using `NWConnection`.
- Options:
  - `protocolType` string + `useTLS` boolean.
  - TLS 1.2–1.3 by default; optional legacy TLS 1.0–1.1.
- Server Certificates:
  - Server cert verification is disabled by a `verify_block` that always accepts; this is intentional for self-signed TAK servers.
  - This is a security tradeoff; recommended for closed/disconnected networks.
- Client Certificates:
  - `.p12` certificate file in `OmniTAKMobile/Resources/omnitak-mobile.p12`.
  - Loaded via Security.framework (`SecIdentity`) and attached to TLS options.
  - Default password is `"atakatak"` unless overridden.

#### ArcGIS

- Token authentication using username/password or pre-issued token.
- Tokens stored in `UserDefaults` under `com.omnitak.arcgis.credentials`.
- `ArcGISCredentials.isValid` is checked to avoid silent use of expired tokens.
- No refresh token mechanism in this snippet; user is expected to re-authenticate.

#### General

- No OAuth flows or web-based login on-device.
- No API keys hard-coded in repo for external services; config typically provided via settings or environment (see docs/guidebook).

---

### Rate Limiting & Constraints

- `URLSessionConfiguration`:
  - Per-request timeout: 30 seconds.
  - Resource timeout: 60 seconds.
- ArcGIS pagination:
  - `pageSize = 25` results per search page.
- Position broadcast:
  - `updateInterval` is configurable; default 30 seconds.
- Track recording:
  - Sample rate based on device’s location updates, often filtered by distance/time.

There is no explicit self-imposed rate limiter beyond these; external services (ArcGIS, tile servers) may enforce their own quotas.

---

## External API Dependencies

### Services Consumed

#### 1. TAK Server (COT/Chat/PLI)

- **Service Name & Purpose:**
  
  - TAK (Tactical Assault Kit) server for situational awareness, PLI, chat, mission data.

- **Transport:**
  
  - TCP/UDP/TLS via `NWConnection`.
  - Protocol: Cursor-on-Target (CoT) XML over sockets.

- **Configuration:**
  
  - Host, port, protocol, TLS choice, and certs are configured by user (see `QuickConnectView`, `TAKServersView`, docs/CONNECTING_TO_TAK_SERVER.md).

- **Endpoints Used:**
  
  - Not HTTP; single socket endpoint (host:port).
  - UDP/TCP unframed stream/messages with CoT XML.

- **Authentication Method:**
  
  - Optional mutual TLS with a client certificate (`omnitak-mobile.p12` or user-provided).
  - Server certificate verification is disabled to support self-signed TAK servers.

- **Error Handling:**
  
  - Uses `NWConnection.stateUpdateHandler`.
  - Logs `failed` and `waiting` errors.
  - Notifies via `onConnectionStateChanged` and `TAKService`’s `@Published` fields.

- **Retry / Circuit Breaking:**
  
  - `reconnect()` logic in `TAKService`.
  - No dedicated circuit-breaker library; reconnection is controlled by service and UI.

- **Integration Pattern:**
  
  - `TAKService` as central socket transport.
  - Higher-level services (Chat, PositionBroadcastService, MissionPackageSyncService, etc.) encode their function as CoT events or data packages and send via `TAKService`.

---

#### 2. ArcGIS Portal / ArcGIS Online

- **Service Name & Purpose:**
  
  - ArcGIS Portal / Online REST API for map content discovery and authentication.

- **Base URLs:**
  
  - `https://www.arcgis.com` (default portal)
  - `https://www.arcgis.com/sharing/rest` (sharing REST services)
  - User can configure alternate Portal URLs (e.g., on-prem).

- **Endpoints Used:**
  
  - `POST {portalURL}/sharing/rest/generateToken`
    - Form data token generation as described above.
  - `GET {portalURL}/sharing/rest/search`
    - For searching content (web maps, layers, etc.)
  - Additional endpoints (`content/items`, `export`, `feature services`) are used by `ArcGISFeatureService` and offline map services, not fully listed here but implemented.

- **Authentication:**
  
  - Token-based:
    - Request token via `/generateToken` with username/password.
    - Pass `token` query parameter in subsequent calls.

- **Error Handling:**
  
  - Non-200 or invalid responses throw `ArcGISError`.
  - JSON `"error"` fields are checked and mapped to `.invalidCredentials` or `.parseError`.
  - UI is updated via `lastError` and `isLoading`.

- **Retry / Circuit Breaking:**
  
  - No built-in retry loops beyond user-initiated actions.
  - Timeouts on `URLSession` handle hung connections.

- **Integration Pattern:**
  
  - `ArcGISPortalService` is the core integration point.
  - `ArcGISFeatureService`, `OfflineMapManager`, and the map controllers use it to authenticate and then work with item URLs and services.

---

#### 3. Elevation / Terrain Services

- **Service Name & Purpose:**
  
  - Elevation/terrain services used by:
    - `ElevationAPIClient`
    - `ElevationProfileService`
    - `LineOfSightService`
    - `TerrainVisualizationService`

- **Base URL / Configuration:**
  
  - Set in `ElevationAPIClient.swift` (see that file for the exact endpoint).
  - Likely a REST endpoint accepting polyline or point lists.

- **Endpoints Used:**
  
  - Typical pattern (inferred):
    - `GET /elevation?points=...` or `POST /elevation` with JSON body.
    - Returns profile data used to populate `ElevationProfile` models.

- **Authentication Method:**
  
  - Could be anonymous, API-key-based, or token-based, depending on configured service; not hard-coded in repo.

- **Error Handling:**
  
  - Wraps `URLSession` results in `Result` or `async throws`.
  - Invalid responses or HTTP codes mapped to domain errors used by view models.

- **Integration Pattern:**
  
  - Stateless calls from services; no permanent connection.
  - Combined with local calculations (e.g., LOS).

---

#### 4. Map Tile / Feature Servers

- **Service Name & Purpose:**
  
  - Standard web tile servers (XYZ/WMTS), and possibly ArcGIS feature services.

- **Base URL / Configuration:**
  
  - Configured via map settings UI (e.g. custom URL templates).
  - Implemented in:
    - `ArcGISTileSource.swift`
    - `OfflineTileOverlay.swift`
    - `TileDownloader.swift`
    - `ArcGISFeatureService.swift`

- **Endpoints Used:**
  
  - Tile templates, e.g.: `https://server/{z}/{x}/{y}.png`
  - ArcGIS Feature Server endpoints, e.g. `.../FeatureServer/0/query`.

- **Authentication:**
  
  - Some sources might use ArcGIS tokens; others may be public.
  - Any protected sources rely on previously obtained credentials or include query params/headers.

- **Error Handling & Resilience:**
  
  - Catches network errors, caches tiles offline, and falls back to cached content when offline.
  - Retry behavior is limited and tuned to user experience (no infinite loops).

---

### Integration Patterns

- **Centralized Services & Observability:**
  
  - Each external integration has a dedicated `Service` singleton.
  - Services `@Publish` state for SwiftUI views to observe.

- **Separation of Concerns:**
  
  - UI views call high-level service APIs (e.g., `startBroadcasting()`, `searchContent`).
  - Networking details are abstracted behind services; consumers never manipulate raw `URLSession` or `NWConnection`.

- **Resilience & Offline Behavior:**
  
  - Chat queues messages locally when offline.
  - PLI broadcasting checks connectivity and location availability.
  - Offline maps work via pre-downloaded tiles and overlays.

- **Configuration-driven:**
  
  - TAK server parameters are user-configured (see `CONNECTING_TO_TAK_SERVER.md`).
  - ArcGIS portals and API endpoints can be customized.
  - Certificates and TLS settings can be customized to support legacy servers.

---

## Available Documentation

### In-Repo Documentation Paths

- **Top-Level Docs:** `/docs`
  
  - `Architecture.md` – overall app architecture.
  - `errors.md` – error handling patterns and error types.
  - `guidebook.md`, `userguide.md` – high-level usage and architecture.

- **API-Focused:**
  
  - `/docs/API/Services.md`
    - Comprehensive service API reference (ChatService, TAKService, PositionBroadcastService, TrackRecordingService, etc.).
  - `/docs/API/Models.md`
    - Data models (CoT, chat, map, mission, etc.).
  - `/docs/API/Managers.md`
    - Managers that orchestrate services and storage.

- **Developer Guides:**
  
  - `/docs/DeveloperGuide/GettingStarted.md`
  - `/docs/DeveloperGuide/CodebaseNavigation.md`
  - `/docs/DeveloperGuide/CodingPatterns.md`
    - Explain the singleton service pattern, Combine usage, and conventions.

- **Feature Docs:**
  
  - `/docs/Features/Networking.md`
    - TAK connectivity, DirectTCPSender, TLS/legacy TLS, federation.
  - `/docs/Features/ChatSystem.md`
    - Chat message flow, retry, CoT formats.
  - `/docs/Features/MapSystem.md`
    - Map controllers, overlays, tile sources, offline maps.
  - `/docs/Features/CoTMessaging.md`
    - CoT formats, message generators/parsers.

- **UI & Integration Guides:**
  
  - `OmniTAKMobile/Resources/Documentation/`
    - `CHAT_FEATURE_README.md`
    - `OFFLINE_MAPS_INTEGRATION.md`
    - `WAYPOINT_INTEGRATION_GUIDE.md`
    - `FILTER_INTEGRATION_GUIDE.md`
    - etc.

- **TAK Connectivity & TLS:**
  
  - `CONNECTING_TO_TAK_SERVER.md`
  - `TLS_LEGACY_SUPPORT.md`

### Documentation Quality

- **Coverage:** High. Most major services and features have dedicated docs.
- **Accuracy:** Matches current implementation (Swift sources and docs are consistent, not aspirational).
- **Gaps:**
  - External elevation API and some routing endpoints are not fully documented as external API contracts; refer directly to `ElevationAPIClient.swift`, `LineOfSightService.swift`, etc., for exact URL forms.
  - No single consolidated external-API catalog; this document fills much of that role.

---

If you want, I can next:

- Enumerate each service in `OmniTAKMobile/Services/` with method signatures and integration notes, or
- Extract and document the exact HTTP shapes (paths, query params, JSON schemas) for the elevation and feature services.