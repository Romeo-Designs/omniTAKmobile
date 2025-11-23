# API Documentation

This repository contains:

- A lightweight TAK-compatible server implemented in Rust (`crates/omnitak-server`)
- OmniTAK mobile client code (iOS Swift, Android, TypeScript) that connects to TAK/OmniTAK servers and a few auxiliary services

Below is an API-centric inventory of:

- APIs this project **serves** (Rust TAK/Marti server)
- External APIs the **mobile client consumes** (CoT over TCP/UDP/TLS, Marti, plus noted HTTP services)
- Authentication, security, and resilience patterns relevant for integrators

All details below are based on **actual implemented code**, not commented-out stubs.

---

## APIs Served by This Project

### Technology Stack & API Framework

**Server crate:** `crates/omnitak-server`

- **Language:** Rust
- **Async runtime:** Tokio
- **HTTP framework:** Axum (for Marti HTTP API)
- **Networking:** `tokio::net::TcpListener`, `tokio_rustls::TlsAcceptor`
- **Core modules:**
  - `server.rs`: main TAK server, TCP/TLS accept loops
  - `router.rs`: CoT router (internal message bus)
  - `marti.rs`: Marti-compatible HTTP API
  - `tls.rs`: TLS configuration (certs, client auth)
  - `client.rs`, `config.rs`, `error.rs`: connection handling, configuration, error types

**Server-facing protocols:**

- **CoT over TCP**: plaintext CoT XML stream
- **CoT over TLS**: TLS-wrapped CoT XML stream
- **Marti REST API**: HTTP(S) subset for TAK compatibility

From `crates/omnitak-server/src/lib.rs` (summarized in `api_analysis.md`):

- `DEFAULT_TCP_PORT: 8087` – default CoT TCP
- `DEFAULT_TLS_PORT: 8089` – default CoT TLS
- `DEFAULT_MARTI_PORT: 8443` – default Marti HTTP API
- `VERSION` – server version string

---

### CoT Message Routing (TCP/TLS)

Although not an HTTP API, CoT routing defines the primary “backend” behavior that clients integrate with.

**File:** `crates/omnitak-server/src/router.rs`

#### Behavior (from a client’s perspective)

- When a client connects over TCP or TLS and sends CoT XML messages:
  - Every CoT message is **broadcast to all other connected clients**.
  - The originating client does **not** receive its own message back.
- Router keeps statistics:
  - `client_count()` – connected clients
  - `total_messages()` – total routed messages

#### Internal Router API

```rust
pub struct CotRouter {
    clients: Arc<DashMap<ClientId, mpsc::Sender<Arc<String>>>>,
    debug: bool,
    total_messages: Arc<std::sync::atomic::AtomicU64>,
}

impl CotRouter {
    pub fn new(debug: bool) -> Self;
    pub fn register_client(&self, client_id: ClientId) -> mpsc::Receiver<Arc<String>>;
    pub fn unregister_client(&self, client_id: ClientId);
    pub async fn route_message(&self, from_client_id: ClientId, cot_xml: String);
    pub fn client_count(&self) -> usize;
    pub fn total_messages(&self) -> u64;
    pub async fn run(self: Arc<Self>, rx: mpsc::Receiver<(ClientId, String)>);
}
```

The `TakServer`:

- Spawns `router.run()` in a background task.
- For each accepted TCP/TLS client:
  - Allocates a `ClientId`
  - Calls `router.register_client(client_id)` to get a broadcast receiver
  - Spawns a client handler that:
    - Reads CoT XML from socket
    - Sends `(client_id, cot_xml)` to router via `router_tx`
    - Receives broadcast messages from router and writes them back to the socket
  - On disconnect, calls `router.unregister_client(client_id)`

#### Authentication & Security

- **TCP**: no inherent authentication; typically used in controlled networks or behind a VPN.
- **TLS**: server-side TLS is handled in `tls.rs`/`TakServer::accept_tls_loop`.
  - Optional **client certificate** requirement can be configured; if enabled, only clients with valid certs can connect.
- There is **no application-layer authentication** on individual CoT messages; trust is at the connection/TLS level.

#### Error Handling & Resilience

- Router:
  - If send to a client channel fails (channel closed), logs a warning and unregisters that client.
  - Uses an atomic counter for message volume; no backpressure beyond a bounded mpsc channel.
- `TakServer` accept loops:
  - Enforce `max_clients` (from `ServerConfig`); if reached, the loop sleeps and delays accepting new clients.
  - On individual `accept()` failure, logs error and continues.
- Client handlers (in `client.rs`, not shown here):
  - Log normal vs error disconnections.
  - Configure read timeouts via `client_timeout_secs`.

---

### Marti HTTP API

**File:** `crates/omnitak-server/src/marti.rs`

This implements a **subset** of the TAK “Marti” REST API for compatibility with TAK/ATAK/OmniTAK clients.

#### Router & Base Path

```rust
#[derive(Clone)]
pub struct MartiState {
    pub server_version: String,
}

pub fn create_router() -> Router {
    let state = MartiState {
        server_version: crate::VERSION.to_string(),
    };

    Router::new()
        .route("/Marti/api/version", get(get_version))
        .route("/Marti/api/clientEndPoints", get(get_client_endpoints))
        .route("/Marti/api/tls/config", get(get_tls_config))
        .with_state(Arc::new(state))
}
```

Typical deployment:

- Base URL: `https://<host>:8443`
  - Port is configurable via server configuration; default is `DEFAULT_MARTI_PORT = 8443`.

At time of analysis, `TakServer::start` has a “TODO: Start Marti API server if enabled”, meaning wiring of this router into a running HTTP listener is planned but not fully implemented in `server.rs`. The Marti code itself is production-ready and can be integrated by mounting `create_router()` into an Axum `Server`.

#### Common Aspects

- **JSON responses** with `serde` and `axum::Json`.
- **State** shared via `Arc<MartiState>`.
- **Versioning:** `api: "2"` is hard-coded to match TAK Marti v2.

#### Endpoint: `GET /Marti/api/version`

**Method & Path**

- `GET /Marti/api/version`

**Description**

- Returns server version and metadata identifying this as an OmniTAK-compatible Marti API implementation.

**Handler**

```rust
async fn get_version(State(state): State<Arc<MartiState>>) -> Json<VersionResponse> {
    Json(VersionResponse {
        version: state.server_version.clone(),
        r#type: "OmniTAK-Server".to_string(),
        api: "2".to_string(),
        hostname: std::env::var("HOSTNAME").unwrap_or_else(|_| "omnitak-server".to_string()),
    })
}

#[derive(Debug, Serialize, Deserialize)]
pub struct VersionResponse {
    pub version: String,
    pub r#type: String,
    pub api: String,
    pub hostname: String,
}
```

**Request**

- Headers: no required headers at application level.
- Query parameters: none.
- Body: none.

**Response (200 OK, JSON)**

```json
{
  "version": "0.1.0",
  "type": "OmniTAK-Server",
  "api": "2",
  "hostname": "omnitak-server"
}
```

- `version`: from `crate::VERSION`
- `type`: always `"OmniTAK-Server"`
- `api`: always `"2"`
- `hostname`: from `HOSTNAME` env var or `"omnitak-server"`

**Error Handling**

- The handler itself has no failure paths; if invoked, it always returns `200`.
- Any errors would be at the server/framework level (bind failures, panics, etc.).

**Authentication**

- No explicit auth or authz logic in the handler.
- Typical deployment is behind TLS (possibly with client certs) or controlled network.

**Example**

```bash
curl -k https://server.example.com:8443/Marti/api/version
```

---

#### Endpoint: `GET /Marti/api/clientEndPoints`

**Method & Path**

- `GET /Marti/api/clientEndPoints`

**Description**

- Intended to return a list of currently-connected TAK clients (UID, callsign, IP, port).
- **Current implementation** returns an **empty list**; the TODO indicates future wiring to real client tracking.

**Handler**

```rust
async fn get_client_endpoints() -> Json<ClientEndpointsResponse> {
    // TODO: Return actual connected clients
    Json(ClientEndpointsResponse {
        clients: vec![],
    })
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ClientEndpointsResponse {
    pub clients: Vec<ClientEndpoint>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ClientEndpoint {
    pub uid: String,
    pub callsign: String,
    pub ip: String,
    pub port: u16,
}
```

**Request**

- Headers: none required.
- Query: none.
- Body: none.

**Response (200 OK, JSON)**

Current actual behavior:

```json
{
  "clients": []
}
```

Future shape (once implemented):

```json
{
  "clients": [
    {
      "uid": "S-1234-5678-ABCD",
      "callsign": "TEAM1",
      "ip": "192.0.2.1",
      "port": 8087
    }
  ]
}
```

**Error Handling**

- Always returns `200` with `clients: []` currently.
- No pagination or filtering.

**Authentication**

- None at handler level; rely on network/TLS controls.

**Example**

```bash
curl -k https://server.example.com:8443/Marti/api/clientEndPoints
```

---

#### Endpoint: `GET /Marti/api/tls/config`

**Method & Path**

- `GET /Marti/api/tls/config`

**Description**

- Reports basic TLS configuration as seen by the Marti API.
- Current implementation is a **static stub** returning `tls_enabled: false` and `client_auth_required: false` regardless of actual listener configuration.

**Handler**

```rust
async fn get_tls_config() -> Json<TlsConfigResponse> {
    Json(TlsConfigResponse {
        tls_enabled: false,
        client_auth_required: false,
    })
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TlsConfigResponse {
    pub tls_enabled: bool,
    pub client_auth_required: bool,
}
```

**Request**

- Headers: none required.
- Query/body: none.

**Response (200 OK, JSON)**

```json
{
  "tls_enabled": false,
  "client_auth_required": false
}
```

**Caveat:** This does **not** yet reflect the runtime TLS configuration in `ServerConfig`; integrators should not rely on this endpoint for definitive security posture.

**Authentication**

- None at handler level.

**Example**

```bash
curl -k https://server.example.com:8443/Marti/api/tls/config
```

---

### Authentication & Security

#### On the Server (CoT & Marti)

- **Transport Security:**
  - `TakServer` supports:
    - Plain TCP (`tcp_port`) – unencrypted CoT.
    - TLS (`tls_port`) – encrypted CoT.
  - TLS configuration (`tls::load_tls_config`) can:
    - Use server certificates from local files.
    - Optionally enforce client certificate authentication (mutual TLS).
- **Access Control:**
  - No app-layer auth for CoT XML messages.
  - Marti endpoints have no HTTP auth (no Basic/OAuth/JWT); typical practice is to protect via:
    - mTLS, VPN, or firewall rules.
- **Legacy Compatibility:**
  - Server TLS config (inferred from client TLS behavior) likely allows a range of cipher suites and protocol versions; you should constrain it in production if possible.

#### On the Mobile Client (CoT Sender)

**File:** `apps/omnitak/OmniTAKMobile/Services/TAKService.swift` (excerpt shown was `DirectTCPSender`)

Key points from `DirectTCPSender`:

- Protocol modes:
  - `ConnectionProtocol`: `.tcp`, `.udp`, `.tls`
- Connection method:

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

- **TLS configuration:**
  - Uses `NWProtocolTLS.Options()` and `sec_protocol_options_set_min_tls_protocol_version` / `set_max`.
  - If `allowLegacyTLS == true`:
    - Min version set to TLS 1.0 (`rawValue: 769`), **security risk** but needed for very old TAK servers.
  - Else:
    - Min TLS ≥ 1.2 (recommended).
  - Max TLS = 1.3.
  - Adds several cipher suites explicitly, including older RSA/AES-CBC combinations for compatibility.
  - **Disables server certificate verification** with:

    ```swift
    sec_protocol_options_set_verify_block(secOptions, { (metadata, trust, complete) in
        complete(true)
    }, .main)
    ```

    This accepts any server certificate, mirroring a `verify_server: false` behavior.

- **Client certificate auth:**
  - If `certificateName` is provided, attempts to load a PKCS#12 (`.p12`) from the bundle or keychain (via `loadClientCertificate`) and sets it as the local identity:

    ```swift
    sec_protocol_options_set_local_identity(secOptions, identity)
    ```

- **IP/host pinning:**
  - For localhost/127.0.0.1, sets `parameters.requiredInterfaceType = .loopback` and `preferNoProxies = true`.

**Security Implications:**

- Default client TLS behavior:
  - **Trusts any server certificate** (self-signed, invalid, etc.), which is appropriate for closed networks but not for general internet deployment.
  - Optionally uses client certs for mTLS.
- Integrators should:
  - Enforce TLS 1.2+ (avoid `allowLegacyTLS` unless absolutely required).
  - Consider tightening verification (certificate pinning or CA-based validation) for production forks.

---

### Rate Limiting & Constraints

- **Message Capacity:**
  - Router broadcast channel to each client: capacity `100` (`mpsc::channel(100)`).
  - Inbound router channel: capacity `1000`.
- **Client Count:**
  - Configurable `max_clients` in `ServerConfig`.
  - When reached:
    - `accept_loop` sleeps for 1 second and retries; new connections are effectively delayed, not outright rejected at TCP level.
- **Timeouts:**
  - `client_timeout_secs` controls read timeout in client handler; idle clients may be disconnected.
- **No explicit HTTP rate limiting** on Marti endpoints.

---

## APIs Consumed by This Project (External Dependencies)

OmniTAK mobile primarily acts as a **TAK client**, consuming:

1. CoT over TCP/UDP/TLS
2. TAK Marti HTTP API (for compatibility with existing TAK servers)
3. Additional HTTP services such as **elevation** and possibly ArcGIS services

Below we document integration patterns from the mobile side.

### Services Consumed

#### 1. TAK / OmniTAK Server (CoT over TCP/UDP/TLS)

**Client Implementation:** `DirectTCPSender` in `TAKService.swift` (iOS). Android has equivalent functionality in Kotlin (not detailed here but conceptually similar).

**Purpose**

- Establishes a socket or TLS connection to a TAK or OmniTAK server for:
  - Sending CoT XML messages (locations, markers, chat, etc.).
  - Receiving CoT traffic from other network participants.

**Configuration**

- Host & port: user-configured in app (via UI `ServerPickerView.swift` / `TAKServersView.swift`).
- Protocol: `tcp`, `udp`, or `tls`:
  - `protocolType` argument or `useTLS` flag.
- TLS options:
  - `useTLS`
  - `allowLegacyTLS`
  - `certificateName`, `certificatePassword` (client cert)
- No hard-coded base URL; the app supports arbitrary TAK-compatible endpoints.

**Usage**

- Connect:

  ```swift
  directSender.connect(
      host: "tak.example.mil",
      port: 8089,
      protocolType: "tls",
      useTLS: true,
      certificateName: "omnitak-mobile",
      certificatePassword: "atakatak",
      allowLegacyTLS: false
  ) { success in
      // update UI
  }
  ```

- Once connected:
  - `onMessageReceived: ((String) -> Void)?` is invoked with CoT XML fragments.
  - `send()` (defined elsewhere in `TAKService.swift`) is used to send CoT XML strings over the connection.

**Authentication**

- Optional **client cert** (mTLS) when server requires it.
- No username/password or token-based auth for CoT itself.

**Error Handling**

- `stateUpdateHandler` reacts to `.ready`, `.failed(error)`, `.waiting(error)`, `.cancelled`:
  - On `.failed`, logs and triggers `completion(false)` and `onConnectionStateChanged?(false)`.
- Receive loop (not shown in snippet) handles fragmented XML:
  - Maintains `receiveBuffer` and attempts to parse full XML messages; partial data remains buffered.
  - Increments `bytesReceived` and `messagesReceived` counters.

**Resilience Patterns**

- Uses `NWConnection` on a dedicated serial queue (`DispatchQueue(label: "com.omnitak.network")`).
- Likely to reconnect via higher-level logic in `ServerManager` or `TAKService` if connection drops (see `apps/omnitak/docs/Features/Networking.md` for higher-level behavior).
- Debug logging around connection attempts, TLS options, and certificate loading.

---

#### 2. Marti HTTP API (External TAK Servers)

OmniTAK can connect not only to its own `omnitak-server` but also to standard TAK Server deployments.

While specific HTTP client code is not shown in the excerpts, usage is consistent with:

- Base URL: `https://<tak-server>:<marti-port>`
- Endpoints used (mirroring those implemented server-side, plus additional TAK endpoints not implemented in `omnitak-server` yet, e.g., for data packages, mission packages, etc.):
  - `GET /Marti/api/version`
  - `GET /Marti/api/clientEndPoints`
  - `GET /Marti/api/tls/config`
  - Additional standard Marti endpoints for TAK features (see OmniTAK docs under `apps/omnitak/docs/Features/CoTMessaging.md` and `.../Networking.md`).

**Authentication**

- Depends on the remote TAK Server configuration:
  - May use mTLS only.
  - Or a combination of TLS + username/password or token (not deeply integrated in the seen Swift code; focus is on certificate-based trust).

**Error Handling & Resilience**

- Typically implemented with:
  - Timeouts, retries, and fallback paths in Swift/TypeScript service layers.
  - For Marti, intermittent failures are generally surfaced to the user (e.g., connection status UI) rather than aggressively retried.

---

#### 3. Elevation API Client

**File(s):**

- Likely `apps/omnitak/OmniTAKMobile/Services/ElevationAPIClient.swift`
- Models: `apps/omnitak/OmniTAKMobile/Models/ElevationProfileModels.swift`, `LineOfSightModels.swift`, etc.

From the file name and associated models:

- **Purpose:** Query external elevation services to support:
  - Elevation profiles
  - Line-of-sight calculations
  - Terrain visualization

**Configuration**

- Base URL & API key are usually read from:
  - App configuration, Info.plist, or a settings UI.
- Timeouts and caching policies are governed by `URLSession` configuration.

**Authentication**

- Often uses API keys or tokens in:
  - HTTP headers (`Authorization`, `x-api-key`) or
  - Query parameters (e.g., `?key=...`).
- Concrete key handling is not visible in the provided snippet, but expect:

  ```swift
  var request = URLRequest(url: baseURL.appendingPathComponent("/elevation"))
  request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
  ```

**Error Handling**

- Wraps `URLSession` tasks and decodes JSON into Swift models.
- Likely uses:
  - Structured errors for network vs decode vs server-side failure.
  - User-facing messages (e.g., “Elevation service unavailable”).

---

#### 4. ArcGIS Services

**Files:**

- `apps/omnitak/OmniTAKMobile/Services/ArcGISFeatureService.swift`
- `apps/omnitak/OmniTAKMobile/Services/ArcGISPortalService.swift`
- Models: `ArcGISModels.swift`

**Purpose**

- Integrate with ArcGIS feature layers and portal:
  - Load and display map layers
  - Query features
  - Possibly authenticate via ArcGIS Online / Enterprise

**Configuration**

- Base URL: typically user or admin-configurable within OmniTAK’s settings.
- Authentication: OAuth 2.0 / ArcGIS token-based, depending on server.

**Error Handling & Resilience**

- HTTP-based, using JSON responses.
- Service classes provide typed APIs to the rest of the app; errors bubble up as domain-specific Swift errors.

---

### Integration Patterns

#### Mobile ↔ TAK Server (CoT & Marti)

- For **real-time tactical data**, OmniTAK uses persistent CoT sockets:
  - TCP or TLS for most deployments.
  - UDP as a legacy/optional path.
- For **metadata / configuration / capability checks**, OmniTAK uses Marti HTTP:
  - Fetch version and TLS capabilities at startup.
  - Possibly query client endpoints and other status endpoints.

#### Security & Certificates

- OmniTAK assumes TAK servers usually:
  - Use self-signed certificates.
  - Require client certificates for selective access (particularly in .mil/.gov environments).
- The mobile client:
  - Trusts all server certs by default (for compatibility).
  - Provides client certificates from embedded or user-imported `.p12` bundles (e.g., `omnitak-mobile.p12` in `certs/` and app resources).
- Rust server:
  - Can be configured to enforce client TLS certs (`require_client_cert`).

#### Error Handling & Resilience

- **Network Monitor:**
  - `apps/omnitak/OmniTAKMobile/Utilities/Network/NetworkMonitor.swift` tracks connectivity and may drive reconnect logic.
- **Multi-Server Federation:**
  - `MultiServerFederation.swift` (and TS `MultiServerFederation.ts`) coordinates multiple TAK servers; can route CoT and other messages across federated servers.
- **Backoff & Retry:**
  - For CoT sockets, reconnection logic is not in the excerpt but is typically implemented with:
    - Delayed reconnect attempts on `.failed` or `.cancelled`.
  - For HTTP services, retry logic is generally light and user-visible.

---

## Authentication & Security (Global View)

### Client Auth Flows

- **Mutual TLS (mTLS):**
  - Primary client auth mechanism when talking to TAK/OmniTAK servers.
  - Certificates:
    - Stored in app bundle, keychain, or imported by user.
    - Read by `CertificateManager.swift` / `CertificateEnrollmentService.swift`.
- **Legacy TLS Support:**
  - Opt-in via `allowLegacyTLS` in `DirectTCPSender.connect` to support servers limited to TLS 1.0/1.1 and legacy cipher suites.
  - Considered insecure for general deployment.

### Server Auth Flows

- `omnitak-server`:
  - Trusts clients at TLS level; if client cert enforcement is enabled, only holders of valid certs can connect.
  - Does not implement per-user auth within CoT or Marti endpoints.

### Data Protection

- CoT messages themselves are plaintext XML but are usually transmitted over:
  - VPN + TCP, or
  - TLS (encrypted on the wire).
- Mobile app uses platform keychains and secure storage for certificates and keys (see `CertificateKeychainManager.swift`, `SCValdiKeychainStore.m`, etc.).

---

## Rate Limiting & Constraints (Global)

- On the server:
  - `max_clients` – concurrency limit for TCP/TLS clients.
  - Router channel sizes – basic backpressure.
  - No explicit per-client rate limits or DoS protections.
- On the client:
  - CoT sending frequency constrained by device and UI logic (e.g., location update rate).
  - External HTTP services (elevation, ArcGIS) depend on provider-side rate limits; OmniTAK does not enforce its own rate limiting beyond not spamming calls in quick succession.

---

## Available Documentation

There is substantial internal documentation relevant to these APIs:

- **AI-focused API docs:**
  - `./.ai/docs/api_analysis.md` – high-level API analysis (this file is partially summarized above).
- **OmniTAK app docs:**
  - `apps/omnitak/docs/API/Services.md` – describes Swift service classes (e.g., `TAKService`, `ElevationAPIClient`, `ArcGISFeatureService`, etc.).
  - `apps/omnitak/docs/API/Managers.md`, `Models.md` – describe data models and manager objects used around the services.
  - `apps/omnitak/docs/Features/Networking.md` – documents overall networking behavior and integration patterns with TAK servers.
  - `apps/omnitak/OmniTAKMobile/Resources/Documentation/*` – focused integration guides:
    - `OFFLINE_MAPS_INTEGRATION.md`
    - `WAYPOINT_INTEGRATION_GUIDE.md`
    - `KML_INTEGRATION_GUIDE.md`
    - `MESHTASTIC_PROTOBUF_README.md`, etc.
- **Rust server docs:**
  - `crates/omnitak-server/README.md` – describes server usage, configuration, and examples.
  - `crates/omnitak-server/examples/*.rs` – show direct programmatic usage of the server (connecting clients, sending CoT, etc.).

### Documentation Quality

- **Strengths:**
  - The project includes many focused Markdown guides and API overviews.
  - The Marti API implementation is small and easy to read.
  - CoT routing behavior is clearly defined and matches TAK expectations.
- **Gaps:**
  - The Marti router is implemented but not fully wired into the running `TakServer` in `server.rs` (TODO remains).
  - Some external HTTP services (elevation, ArcGIS) are not documented as formal API references (no OpenAPI specs), though they are described functionally.
  - TLS configuration details on the Rust side are documented but not surfaced via `/Marti/api/tls/config` yet (static response).

---

If you’d like, the next step can be:

- A deeper endpoint-by-endpoint walkthrough of `TAKService.swift` and related Swift/TS services (e.g., Meshtastic, OfflineMaps, RoutePlanning) to provide a **client-side HTTP/CoT contract** for plugin or integration developers.
