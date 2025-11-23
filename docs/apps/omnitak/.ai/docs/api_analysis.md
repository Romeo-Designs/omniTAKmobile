# API Documentation

This project is an iOS SwiftUI mobile client, not a traditional HTTP server. It **does not expose REST/GraphQL endpoints**; instead it:

- Opens persistent **TCP/UDP/TLS connections** to TAK servers (Cursor-on-Target message exchange).
- Consumes several **external HTTP APIs**, notably ArcGIS Portal/Online and elevation services.
- Exposes a rich **internal service API** (Swift classes) used by views and managers.

Below, “APIs Served” focuses on the logical/protocol-level interfaces this app presents to TAK and other peers, plus the Swift services developers will integrate with inside the app. “External Dependencies” focuses on concrete HTTP services used.

---

## APIs Served by This Project

### Technology Stack & Framework

- **Platform:** iOS
- **UI:** SwiftUI + UIKit map controllers
- **Language:** Swift
- **Networking:**
  - `Network` framework (`NWConnection`) for TCP/UDP/TLS connections to TAK servers.
  - `URLSession` for REST-like HTTP calls (ArcGIS, Elevation, etc.).
- **State/DI:** `ObservableObject` services with `@Published` properties; mostly singletons (`.shared`).

Entry point:

```swift
// OmniTAKMobile/Core/OmniTAKMobileApp.swift
@main
struct OmniTAKMobileApp: App {
    var body: some Scene {
        WindowGroup {
            ATAKMapView()
        }
    }
}
```

There is **no HTTP server** or web framework; all “endpoints” below are protocol-level (TAK CoT) and internal Swift APIs.

---

### Endpoints

#### 1. TAK Connectivity & CoT Messaging

**Component:** `TAKService` + `DirectTCPSender`  
**Files:**

- `OmniTAKMobile/Services/TAKService.swift`
- `OmniTAKMobile/Services/TAKService.swift` (top portion: `DirectTCPSender` as shown)

**Purpose:** Maintain a network connection to a TAK server and send/receive CoT XML messages over TCP, UDP, or TLS.

##### Protocol-Level Endpoint

The app behaves like a TAK client:

- **Remote Endpoint (TAK server):**
  - **Protocol:** TCP / UDP / TLS over TCP
  - **Host:** Configurable (e.g., `192.168.1.10` or hostname)
  - **Port:** Configurable (e.g., `8087` for UDP / `8088` TCP / `8089` TLS; depends on server configuration)
  - **Application Protocol:** Cursor-on-Target (CoT) XML messages, newline-delimited.

The client:

- Connects to a configured TAK server.
- Sends CoT messages representing position (PLI), chat, digital pointer, teams, etc.
- Receives CoT messages from the server, parses via `CoTMessageParser`, and dispatches to managers/services.

##### Internal Swift API

`TAKService` (documented in `docs/API/Services.md`) exposes:

- `connect(host:port:protocolType:useTLS:certificateName:certificatePassword:completion:)`
- `disconnect()`
- `reconnect()`
- `send(cotMessage:priority:)`
- Various statistics via `@Published` properties (messagesSent, messagesReceived, bytesSent, bytesReceived, isConnected, connectionStatus).

`DirectTCPSender` handles the actual socket connection:

```swift
func connect(
    host: String,
    port: UInt16,
    protocolType: String = "tcp",
    useTLS: Bool = false,
    certificateName: String? = nil,
    certificatePassword: String? = nil,
    allowLegacyTLS: Bool = false,
    completion: @escaping (Bool) -> Void
)
```

**Description**

Connects to the TAK server using the specified protocol:

- `protocolType`: `"tcp"`, `"udp"`, or `"tls"` (case-insensitive).
- `useTLS`: when true, configures a TLS session with optional client certificate and legacy cipher suites for TAK compatibility.

Once connected, `DirectTCPSender`:

- Starts a continuous receive loop using `NWConnection.receive`.
- Accumulates raw bytes in `receiveBuffer`.
- Extracts and validates complete CoT XML messages using `CoTMessageParser.extractCompleteMessages / isValidCoTMessage`.
- Invokes `onMessageReceived(message: String)` callback on the main queue for each valid CoT.

**Request**

- **Transport:** NWConnection to TAK endpoint.
- **Application Data (Outbound):**
  - Messages are raw XML strings terminated with `\n`.
  - Example (simplified PLI CoT):

    ```xml
    <event
      version="2.0"
      type="a-f-G-U-C"
      uid="ANDROID-12345"
      time="2025-11-22T10:00:00Z"
      start="2025-11-22T10:00:00Z"
      stale="2025-11-22T10:05:00Z"
      how="m-g">
      <point lat="35.1234" lon="-97.1234" hae="250.0" ce="50.0" le="50.0"/>
      <detail>
        <contact callsign="R06"/>
        <!-- Additional detail elements -->
      </detail>
    </event>
    ```

- **Headers:** None at application level; TLS handshake used for TLS mode.

**Response**

- **Inbound Data:**
  - Raw CoT XML messages from the server, potentially fragmented at TCP level.
  - Messages are reassembled, validated, and passed to `onMessageReceived`.

**Authentication**

- **Transport Layer:**
  - TLS with potential client certificate authentication:
    - Client loads `.p12` identity via `loadClientCertificate(name:password:)`:
      - Searches:
        1. `CertificateManager.shared.certificates` / Keychain.
        2. Documents directory: `Documents/Certificates/<name>.p12`.
        3. App bundle: `<name>.p12`.
    - TLS verification is overridden to accept TAK’s self-signed certificates:

      ```swift
      sec_protocol_options_set_verify_block(secOptions, { metadata, trust, complete in
          complete(true)   // Accept all server certificates
      }, .main)
      ```

    - TLS versions:
      - Default: min TLS 1.2, max TLS 1.3.
      - With `allowLegacyTLS = true`: min forced to TLS 1.0.
    - Cipher suites: explicit list including modern and legacy RSA/AES GCM/CBC suites.

- **Application Layer:**
  - TAK-level authentication (UID, callsign, etc.) is embedded in CoT messages and TAK server config, not in HTTP-like headers.

**Error Handling**

- Connection state updates:

  ```swift
  connection?.stateUpdateHandler = { state in
      switch state {
      case .ready: onConnectionStateChanged?(true); startReceiveLoop()
      case .failed(let error): onConnectionStateChanged?(false); completion(false)
      case .waiting(let error): /* log */
      case .cancelled: onConnectionStateChanged?(false)
      default: break
      }
  }
  ```

- Receive errors:
  - On receive error, logs error and stops that receive invocation; outer service may initiate reconnection.
- Buffer safety:
  - Warn if `receiveBuffer.count > 100_000`.
  - If `> 1_000_000`, log and clear buffer (malformed data protection).
- Send errors:
  - Logs via completion block of `connection.send`.

**Examples**

Connect with TLS and client certificate:

```swift
let takService = TAKService()
takService.connect(
    host: "tak.example.mil",
    port: 8089,
    protocolType: "tls",
    useTLS: true,
    certificateName: "omnitak-client",
    certificatePassword: "atakatak"
) { success in
    if success {
        let cot = CoTGenerator.generatePLI(/* ... */)
        takService.send(cotMessage: cot, priority: .normal)
    }
}
```

Connect over UDP:

```swift
takService.connect(
    host: "192.168.1.50",
    port: 8087,
    protocolType: "udp",
    useTLS: false
) { success in /* ... */ }
```

---

#### 2. Internal Service APIs (Swift)

These are used by OmniTAK’s views/managers. They aren’t network endpoints but are crucial “APIs” for app integration.

Below are key services that drive how CoT and external calls are used.

##### 2.1 ChatService

**File:** `OmniTAKMobile/Services/ChatService.swift`  
**Description:** Handles chat conversations, including message queuing and retry via TAKService/CoT.

**Core API (from `docs/API/Services.md`):**

- `configure(takService:locationManager:)`
- `sendTextMessage(_:to:)`
- `sendLocationMessage(location:to:)`
- `processQueue()`
- `markAsRead(_:)`

**Usage Example:**

```swift
ChatService.shared.configure(takService: takService, locationManager: locationManager)

ChatService.shared.sendTextMessage("Ready to proceed", to: conversationId)
```

Messages are turned into CoT chat events and routed through `TAKService`.

##### 2.2 PositionBroadcastService

**File:** `PositionBroadcastService.swift`  
**Purpose:** Automatic PLI broadcasts at configurable intervals.

Key aspects:

- Uses LocationManager for GPS fixes.
- Uses TAKService to send PLI CoT messages.
- Exposes `isEnabled`, `updateInterval`, user identity fields (`userCallsign`, `userUID`, `teamColor`, `userUnitType`).

**Example:**

```swift
let pliService = PositionBroadcastService.shared
pliService.configure(takService: takService, locationManager: locationManager)
pliService.userCallsign = "Alpha-1"
pliService.updateInterval = 30.0
pliService.isEnabled = true
```

##### 2.3 TrackRecordingService, EmergencyBeaconService, DigitalPointerService, TeamService, MeasurementService, RangeBearingService, ElevationProfileService, LineOfSightService

Each of these:

- Is documented in `docs/API/Services.md`.
- Uses TAKService and/or external services to send CoT, compute measurements, and update map overlays.
- They **do not expose network endpoints**; they shape how CoT is generated and how external APIs are called.

See `docs/API/Services.md`, `docs/API/Managers.md`, and `docs/API/Models.md` for method signatures and model types.

---

### Authentication & Security

#### TAK Connectivity

- **TLS Support:**
  - Uses `NWProtocolTLS.Options` with configurable minimum TLS version.
  - Legacy TLS (1.0/1.1) is allowed only if explicitly requested (`allowLegacyTLS = true`).
  - Explicit cipher suites added to support older TAK servers:
    - `TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384`
    - `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256`
    - `TLS_RSA_WITH_AES_256_GCM_SHA384`
    - `TLS_RSA_WITH_AES_128_GCM_SHA256`
    - Legacy CBC suites (AES_256_CBC_SHA, AES_128_CBC_SHA).

- **Server Certificate Validation:**
  - Verification is effectively disabled:

    ```swift
    sec_protocol_options_set_verify_block(secOptions, { _, _, complete in
        complete(true)
    }, .main)
    ```

  - This is intentionally done for self-signed TAK CA environments but has security implications.
  - For production, ideally restrict accepted CA or use OS trust store.

- **Client Certificate Authentication:**
  - Optional; when certificateName is provided:
    1. Try `CertificateManager.shared` (Keychain).
    2. Try `Documents/Certificates/<name>.p12`.
    3. Try bundle `<name>.p12`.
  - If found and password is valid, configures `sec_protocol_options_set_local_identity`.

- **Loopback Optimization:**
  - For hosts containing `"127.0.0.1"` or `"localhost"`:
    - `parameters.requiredInterfaceType = .loopback`
    - Disables proxies.

#### ArcGIS Authentication

Handled via `ArcGISPortalService` (see External API Dependencies), but in brief:

- Acquires tokens via `generateToken` POST with username/password.
- Saves `ArcGISCredentials` (portalURL, username, token, expiration, referer).
- Persists in `UserDefaults` under `com.omnitak.arcgis.credentials`.
- Exposes `authenticate` and `authenticateWithToken`.

Security considerations:

- Username/password are sent over HTTPS.
- Token is stored locally; ensure device security and consider Keychain for highly sensitive environments.

---

### Rate Limiting & Constraints

There is no explicit global rate-limiting library, but the following constraints apply:

- **Network Timeouts:**
  - `ArcGISPortalService`: `URLSessionConfiguration` with `timeoutIntervalForRequest = 30`, `timeoutIntervalForResource = 60`.
  - Similar patterns likely in `ElevationAPIClient` (not shown here but by convention).

- **Position Broadcast:**
  - Controlled via `updateInterval` default ~30 seconds; prevents excessive PLI spam.

- **Emergency Beacon:**
  - Rapid PLI updates but typically limited in practice; ensure not to set extremely low intervals.

- **Buffer Protection (CoT Receive):**
  - `receiveBuffer` size monitored; resets if > 1,000,000 chars to protect memory.

For external integrators: TAK server itself may enforce rate limits on CoT messages; follow your server’s guidance.

---

## External API Dependencies

### Services Consumed

#### 1. ArcGIS Portal / ArcGIS Online

**Service Name:** ArcGISPortalService  
**File:** `OmniTAKMobile/Services/ArcGISPortalService.swift`  
**Purpose:** Authenticate with ArcGIS Portal/Online, search items, and manage credentials.

##### Base URL / Configuration

- Defaults:

  ```swift
  static let arcGISOnlineURL = "https://www.arcgis.com"
  static let arcGISOnlineSharingURL = "https://www.arcgis.com/sharing/rest"
  ```

- `ArcGISCredentials` contains:
  - `portalURL: String` (e.g., custom ArcGIS Enterprise URL)
  - `username: String`
  - `token: String`
  - `tokenExpiration: Date`
  - `referer: String`

- `URLSession` config:

  ```swift
  let config = URLSessionConfiguration.default
  config.timeoutIntervalForRequest = 30
  config.timeoutIntervalForResource = 60
  session = URLSession(configuration: config)
  ```

##### Endpoints Used

1. **Generate Token**
   - **Method/Path:** `POST {portalURL}/sharing/rest/generateToken`
   - **Request:**
     - Headers:
       - `Content-Type: application/x-www-form-urlencoded`
     - Body (form-encoded):

       | Field        | Description                           |
       | ------------ | ------------------------------------- |
       | `username`   | ArcGIS username                       |
       | `password`   | ArcGIS password                       |
       | `referer`    | Arbitrary string, e.g., `OmniTAK-iOS` |
       | `expiration` | Minutes (e.g., `10080` = 7 days)      |
       | `f`          | Response format, `"json"`             |

   - **Response (Success):**

     ```json
     {
       "token": "abc123...",
       "expires": 1732257623000,
       "ssl": true
     }
     ```

   - **Response (Error):**

     ```json
     {
       "error": {
         "code": 400,
         "message": "Invalid username or password.",
         "details": []
       }
     }
     ```

   - **Error mapping:**
     - `ArcGISError.invalidCredentials` when `"error"` is present.
     - `ArcGISError.networkError` for invalid URL, non-200 status, or generic network issues.
     - `ArcGISError.parseError` if token is missing.

2. **Search Portal Content**
   - **Method/Path:** `GET {credentials.portalURL}/sharing/rest/search`
   - **Request:**
     - Query parameters:

       | Param       | Description                               |
       | ----------- | ----------------------------------------- |
       | `q`         | Search query; may include `type:"<type>"` |
       | `sortField` | Field to sort by, e.g., `modified`        |
       | `sortOrder` | `asc` or `desc`                           |
       | `start`     | Start index (page offset)                 |
       | `num`       | Page size (here `pageSize = 25`)          |
       | `token`     | ArcGIS token                              |
       | `f`         | `json`                                    |

   - **Response (Success):**
     - Parsed into `ArcGISSearchResponse` (includes `results`, `total`, `start`, etc.).
   - **Response (Error):**
     - If `"error"` present:
       - Codes `498` / `499` => `ArcGISError.tokenExpired`
       - Other => `ArcGISError.serviceError(message)`

   - **Auth & State Preconditions:**

     ```swift
     guard isAuthenticated, let creds = credentials else {
         throw ArcGISError.portalNotConfigured
     }

     if !creds.isValid {
         throw ArcGISError.tokenExpired
     }
     ```

##### Authentication Method

- **Token-based:**
  - Primary flow: username/password → `/generateToken` → token persisted.
  - Alternatively: `authenticateWithToken(portalURL:token:username:expiration:)` for pre-provisioned tokens.

##### Error Handling & Resilience

- Thrown errors (to be caught by caller):
  - `ArcGISError.networkError(message)` – URL invalid, non-200 HTTP, or `URLSession` problems.
  - `ArcGISError.invalidCredentials` – invalid username/password.
  - `ArcGISError.portalNotConfigured` – using search without having called authenticate.
  - `ArcGISError.tokenExpired` – token invalid or expired (codes 498/499 or `creds.isValid == false`).
  - `ArcGISError.parseError(message)` – unexpected JSON structure.

- **Retry Patterns:**
  - No built-in automatic retries.
  - Caller is expected to catch `tokenExpired` and re-authenticate, then retry search.

**Usage Example:**

```swift
do {
    try await ArcGISPortalService.shared.authenticate(
        portalURL: "https://www.arcgis.com",
        username: "user",
        password: "secret"
    )

    try await ArcGISPortalService.shared.searchContent(
        query: "type:Feature Layer",
        itemType: .featureService,
        sortField: "modified",
        sortOrder: "desc",
        page: 1
    )
} catch ArcGISError.invalidCredentials {
    // Show login error
} catch ArcGISError.tokenExpired {
    // Prompt for re-login
} catch {
    // Generic error handling
}
```

---

#### 2. Elevation and Terrain Services

**Files:**

- `OmniTAKMobile/Services/ElevationAPIClient.swift`
- `OmniTAKMobile/Services/ElevationProfileService.swift`
- `OmniTAKMobile/Services/LineOfSightService.swift` (mentioned in docs)

Although full `ElevationAPIClient.swift` content wasn’t shown, the naming and usage in `ElevationProfileService` strongly imply:

- A service making HTTP calls to a DEM/Elevation API.
- Generating profiles for routes and single-point elevation queries.

**Conceptual API (based on `docs/API/Services.md`):**

- `ElevationProfileService.generateProfile(for: [CLLocationCoordinate2D])` – asynchronous, uses `ElevationAPIClient` to fetch elevation samples along a path.
- `ElevationProfileService.fetchElevation(at: CLLocationCoordinate2D)` – likely calls underlying HTTP endpoint (e.g., `/elevation?lat=...&lon=...`).

**Typical Request/Response:**

- **Method/Path:** `GET https://<elevation-service>/elevation?lat=<>&lon=<>` or similar.
- **Response (JSON):** heights array or single point elevation.
- **Errors:** network/timeouts; non-200 responses; JSON parsing failures.

Consult `OmniTAKMobile/Services/ElevationAPIClient.swift` for exact endpoints in your environment; they may be configurable (e.g., pointing to TAK server plugins, USGS, or custom services).

---

#### 3. Misc External HTTP Integrations

Other services in `OmniTAKMobile/Services/` may consume HTTP APIs depending on your deployment:

- `ArcGISFeatureService.swift`
- `ArcGISTileSource.swift` (in Map/TileSources)
- `MissionPackageSyncService.swift`
- `VideoStreamService.swift`

The filenames indicate:

- **ArcGISFeatureService:** interacts with ArcGIS feature layer REST endpoints (`/FeatureServer/...`).
- **ArcGISTileSource / OfflineTileOverlay:** fetches map tiles either from online ArcGIS services or cached offline sources.
- **VideoStreamService:** likely consumes RTSP/HTTP video streams; specifics depend on your TAK video infrastructure.
- **MissionPackageSyncService:** may call TAK server REST endpoints for mission package lists and binary downloads.

For exact method/property contracts, see:

- `docs/API/Services.md`
- The individual Swift service files.

---

### Integration Patterns

1. **TAK-centric CoT Pattern**
   - All tactical interactions (chat, position, geofences, teams, digital pointer, emergency beacon) are eventually represented as CoT XML.
   - Flow:

     ```
     UI View -> Manager (e.g., ChatManager, GeofenceManager)
             -> Domain Service (ChatService, PositionBroadcastService, etc.)
             -> TAKService
             -> DirectTCPSender (NWConnection)
             -> TAK Server
     ```

   - Incoming CoT:

     ```
     TAK Server -> DirectTCPSender.receive
                 -> CoTMessageParser.extractCompleteMessages
                 -> CoTEventHandler / Managers
                 -> Services and UI update
     ```

2. **External REST Integration Pattern**
   - ArcGIS and Elevation:

     ```
     UI View (e.g., ArcGISPortalView, ElevationProfileView)
       -> ArcGISPortalService / ElevationProfileService
       -> URLSession-based client
       -> External REST endpoint
       -> Decoders / domain models
       -> Published properties -> UI
     ```

   - Errors bubble back as Swift `Error`s; views observe `@Published lastError` or use `do/try/catch`.

3. **Singleton Services & Observable State**
   - Most services are singletons:

     ```swift
     class ArcGISPortalService: ObservableObject {
         static let shared = ArcGISPortalService()
         @Published var isAuthenticated: Bool
         ...
     }
     ```

   - Views access via `@StateObject` or `@ObservedObject` to automatically update when network results arrive.

4. **Configuration & Secrets**
   - **ArcGIS credentials:** stored in `UserDefaults` (`userDefaultsKey = "com.omnitak.arcgis.credentials"`).
   - **Certificates:** stored via:
     - `CertificateManager` (Keychain-based).
     - `Documents/Certificates/*.p12` for enrolled certs (see `CertificateEnrollmentService`/view).
     - Bundle `.p12` for built-in test/dev client certs.
   - Network endpoints (TAK host/port, ArcGIS base URL, etc.) are chosen via settings UI (`NetworkPreferencesView`, `TAKServersView`, etc.) and persisted locally (see managers and storage files).

---

## Available Documentation

### Internal API & Developer Docs

Located under `./docs`:

- **High-Level Architecture:**
  - `docs/Architecture.md`
  - `docs/guidebook.md`
  - `docs/userguide.md`
  - `docs/errors.md` (error-handling patterns)

- **API-Level Docs:**
  - `docs/API/Services.md` – primary reference for all service classes:
    - TAKService, ChatService, PositionBroadcastService, TrackRecordingService, EmergencyBeaconService, DigitalPointerService, TeamService, MeasurementService, RangeBearingService, ElevationProfileService, LineOfSightService, etc.
  - `docs/API/Managers.md` – describes Manager layer (e.g., ChatManager, CoTFilterManager, OfflineMapManager).
  - `docs/API/Models.md` – describes data models (CoT models, Chat models, Tracks, Routes, etc.).

- **Developer Guides:**
  - `docs/DeveloperGuide/GettingStarted.md` – how to build and run, environment setup.
  - `docs/DeveloperGuide/CodebaseNavigation.md` – how files are organized.
  - `docs/DeveloperGuide/CodingPatterns.md` – common patterns (ObservableObject, singletons, network patterns).

- **Feature-Specific Guides:**
  - `OmniTAKMobile/Resources/Documentation/`:
    - `CHAT_FEATURE_README.md`
    - `FILTER_INTEGRATION_GUIDE.md`
    - `KML_INTEGRATION_GUIDE.md`
    - `OFFLINE_MAPS_INTEGRATION.md`
    - `RADIAL_MENU_INTEGRATION_GUIDE.md`
    - `WAYPOINT_INTEGRATION_GUIDE.md`
    - `MESHTASTIC_PROTOBUF_README.md`
    - `UI_LAYOUT_REFERENCE.md`
    - `USAGE_EXAMPLES.swift` – concrete usage snippets of services and managers.

### Documentation Quality Evaluation

- **Coverage:**
  - Services and managers are well-documented in `docs/API/`.
  - Feature-level docs give concrete integration patterns and code examples.
- **Gaps:**
  - No formal OpenAPI/Swagger or gRPC proto specs (appropriate since the app is a client, not a server).
  - External elevation service details (base URL, exact contract) are not fully captured in the visible docs; refer directly to `ElevationAPIClient.swift` and deployment config.
  - Some legacy / backup Swift files are present; they should not be considered authoritative for new development (e.g., `*.backup` files).

---

### Summary for Integrators

- **If you’re integrating with OmniTAK as a TAK server admin:**
  - Ensure TAK server supports TCP/UDP/TLS ports configured in the app.
  - Provide client certificates (P12) and CA if using mutual TLS.
  - Understand that the client accepts self-signed server certs by design.
  - CoT event formats follow standard TAK conventions (PLI, chat, markers); see `CoT` models and services.

- **If you’re extending the app:**
  - Use existing services (`TAKService`, `ChatService`, `PositionBroadcastService`, etc.) rather than creating new sockets or URLSessions.
  - Follow patterns in `docs/API/Services.md` and `USAGE_EXAMPLES.swift`.
  - For new external REST integrations, mirror `ArcGISPortalService` / `ElevationAPIClient` design: `URLSession`, strongly-typed models, clear error enums, `ObservableObject` with `@Published` state, and async/await or Combine as appropriate.

This documentation should give you a complete picture of what this project “serves” (CoT over TCP/UDP/TLS) and what it “consumes” (ArcGIS, elevation, and TAK-related services), along with the internal APIs you’ll use to build features.
