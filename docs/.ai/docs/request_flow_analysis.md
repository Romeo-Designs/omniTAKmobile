# Request Flow Analysis

## Entry Points Overview

### iOS App / UI Runtime

- **Main iOS entry**
  - `apps/omnitak/OmniTAKMobile/Core/OmniTAKMobileApp.swift`
    - SwiftUI `@main` `App`.
    - Constructs core managers/services as `@StateObject` / `@EnvironmentObject`.
    - Sets `ContentView` as the root and injects shared state.
  - `apps/omnitak/OmniTAKMobile/Core/ContentView.swift`
    - Composes the main navigation shell and high‑level screens:
      - Map, chat, team management, server picker, settings, offline maps, etc.
    - Binds screens in `Views/` to managers in `Managers/` and services in `Services/`.

- **Feature screens (SwiftUI views)**
  - Located under `apps/omnitak/OmniTAKMobile/Views/` (e.g., `ChatView.swift`, `PositionBroadcastView.swift`, `MissionPackageSyncView.swift`, `TAKServersView.swift`).
  - Each screen:
    - Is configured with one or more `ObservableObject` managers/services.
    - Converts user gestures and inputs into method calls on the relevant manager or service.

- **Valdi/TypeScript app entry (Android / Valdi shell)**
  - `modules/omnitak_mobile/src/index.ts`
    - Exports the Valdi module entry.
  - `modules/omnitak_mobile/src/valdi/omnitak/App.tsx`
    - Root component for the Valdi runtime (Android + possibly desktop shells).
  - `modules/omnitak_mobile/src/valdi/omnitak/AppController.tsx`
    - Controller layer that wires:
      - Screens from `screens/` (e.g., `EnhancedMapScreen.tsx`, `ServerManagementScreen.tsx`).
      - Shared services (e.g., `TakService.ts`, `MultiServerFederation.ts`, `MarkerManager.ts`).

These are UI entry points; they don’t expose network APIs directly but drive all client‑side request flows.

### Mobile Network Entry Points (Client → Server)

On device, “requests” are primarily:

- CoT (Cursor‑on‑Target) streams over TCP/TLS/UDP.
- Supplementary HTTPS requests (elevation, ArcGIS, tiles, etc.).

Key entry classes:

- **TAK CoT channel**
  - `apps/omnitak/OmniTAKMobile/Services/TAKService.swift`
    - Central client‑side networking service for TAK:
      - Opens and maintains TCP/TLS or UDP connections to TAK servers.
      - Sends CoT XML messages.
      - Receives CoT XML from sockets and forwards to parsers.
    - Used by many feature services (`ChatService`, `PositionBroadcastService`, etc.).

- **Meshtastic integration**
  - `apps/omnitak/OmniTAKMobile/Managers/MeshtasticManager.swift`
  - `apps/omnitak/OmniTAKMobile/Services/MeshtasticService.swift`
    - Entry for radio‑based mesh messages.
    - Converts incoming Meshtastic protobuf messages to internal models / CoT equivalents.

- **HTTP/HTTPS API clients**
  - `apps/omnitak/OmniTAKMobile/ElevationAPIClient.swift`
  - `apps/omnitak/OmniTAKMobile/Services/ElevationAPIClient.swift`
  - `apps/omnitak/OmniTAKMobile/Services/ArcGISFeatureService.swift`
  - `apps/omnitak/OmniTAKMobile/Services/ArcGISPortalService.swift`
  - `apps/omnitak/OmniTAKMobile/Map/TileSources/TileDownloader.swift`
  - `apps/omnitak/OmniTAKMobile/Map/TileSources/OfflineTileCache.swift`
    - Build and execute `URLRequest`s to third‑party HTTP services.
    - These are client‑only; there is no HTTP server in the mobile app.

### Embedded / Test TAK Server (Rust)

The repo ships a simple CoT router/server used for testing or small deployments:

- **Crate:** `crates/omnitak-server`
  - `src/server.rs`
    - `TakServer` is the main entry:
      - Binds TCP and/or TLS listening sockets from config.
      - Spawns accept loops per protocol.
      - Holds:
        - A shared `Arc<CotRouter>` (`router.rs`).
        - An MPSC channel (`router_tx`) used by clients to submit CoT messages to the router.

  - `src/router.rs` (`CotRouter`)
    - Core “router” for CoT XML:
      - Maintains a concurrent map of active clients (`DashMap<ClientId, Sender<Arc<String>>>`).
      - Asynchronously receives `(ClientId, String)` messages from clients via `rx: mpsc::Receiver<(ClientId, String)>`.
      - Broadcasts each message to all other registered clients.

  - `src/client.rs`
    - Represents one connected client (TCP or TLS).
    - Entry method:
      - `Client::handle(router_tx: mpsc::Sender<(ClientId, String)>) -> Result<()>`
        - Reads CoT messages from the socket.
        - Sends `(client_id, cot_xml)` into the router channel.
        - Simultaneously listens for broadcast messages from router and writes them to the socket.

  - `src/marti.rs`
    - Placeholder for Marti/HTTP support.
    - Currently not wired from `TakServer::start`; CoT over TCP/TLS is the only active protocol.

There is **no HTTP REST API** implemented on the server side at this time; all request handling is CoT stream‑based.

---

## Request Routing Map

This section traces concrete request paths from entry to response/effect, by major flow.

### 1. CoT Requests: Mobile Client → Rust Server → Other Clients

#### 1.1 Outbound CoT from iOS

**Step 1 – UI action**

User performs an action in a view under `OmniTAKMobile/Views/`:

- Chat:
  - `ChatView.swift` / `ConversationView.swift`
  - Calls into `ChatManager.swift` (manager layer).
- Position broadcast:
  - `PositionBroadcastView.swift`
  - Talks to `PositionBroadcastService.swift`.
- Other CoT‑generating features:
  - Radial menu actions (`RadialMenuView.swift`, `RadialMenuActionExecutor.swift`) hitting:
    - `DigitalPointerService.swift`
    - `MeasurementService.swift`
    - `RoutePlanningService.swift`
    - `GeofenceService.swift`
    - `WaypointManager.swift`, etc.

Views call manager methods such as:

```swift
chatManager.sendMessage(text: ..., to: ...)
positionBroadcastService.broadcastPositionNow()
geofenceManager.createGeofence(...)
```

**Step 2 – Manager → Service**

Managers in `Managers/` translate user‑level intentions to service calls:

- `ChatManager` → `ChatService`
- `ServerManager` → `TAKService`
- `GeofenceManager` → `GeofenceService` → `TAKService`, etc.

For example (pattern taken from docs and code):

```swift
class ChatManager: ObservableObject {
    private let chatService: ChatService

    func sendMessage(text: String, to conversationId: String) {
        chatService.sendTextMessage(text, to: conversationId)
    }
}
```

**Step 3 – CoT message construction**

Services under `OmniTAKMobile/Services/` call CoT generators in `OmniTAKMobile/CoT/Generators/`:

- `ChatCoTGenerator.swift`
- `GeofenceCoTGenerator.swift`
- `MarkerCoTGenerator.swift`
- `TeamCoTGenerator.swift`

Concrete example (structure taken from generators):

```swift
struct ChatCoTGenerator {
    func generateChatCoT(message: ChatMessage) -> String {
        // Builds an XML string with <event> ... </event>
    }
}
```

`ChatService.sendTextMessage` uses this generator then sends via `TAKService`:

```swift
let xml = chatCoTGenerator.generateChatCoT(message)
takService.send(cotMessage: xml, priority: .normal)
```

**Step 4 – TAKService: routing to socket**

`TAKService.swift` contains:

- Connection methods:
  - `connect(host: String, port: Int, protocolType: ProtocolType, useTLS: Bool, certificateName: String?, certificatePassword: String?, completion: ...)`
  - `disconnect()`
- Sending:
  - `send(cotMessage: String, priority: MessagePriority)`

`send`:

- Increments counters (e.g. `messagesSent`, `bytesSent`).
- Applies protocol‑level framing if required (newline terminators, etc.).
- Writes to its underlying stream abstraction (typically a `Stream`/socket handled by Rust FFI or native APIs).

This completes the “request” on the client side: bytes are placed on the wire.

#### 1.2 Inbound CoT on Rust Server

**Step 1 – Accept loop in `TakServer::start`**

Relevant parts in `crates/omnitak-server/src/server.rs`:

```rust
pub async fn start(&mut self) -> Result<()> {
    let addr = format!("0.0.0.0:{}", self.config.tcp_port);
    let listener = TcpListener::bind(addr).await?;

    let router = Arc::clone(&self.router);
    let router_tx = self.router_tx.clone();
    let timeout_secs = self.config.client_timeout_secs;
    let max_clients = self.config.max_clients;

    let handle = tokio::spawn(async move {
        Self::accept_loop(listener, router, router_tx, timeout_secs, max_clients).await
    });

    self.tcp_handle = Some(handle);

    // Similar block for TLS if enabled
    Ok(())
}
```

**Step 2 – Connection handling and `Client` creation**

Inside `accept_loop`:

```rust
async fn accept_loop(
    listener: TcpListener,
    router: Arc<CotRouter>,
    router_tx: mpsc::Sender<(ClientId, String)>,
    timeout_secs: u64,
    max_clients: usize,
) -> Result<()> {
    loop {
        let (stream, addr) = listener.accept().await?;
        // Capacity check omitted here, but present in code.

        let client = Client::new(stream, addr, mpsc::channel(100).1, timeout_secs);
        let client_id = client.info().id;

        let rx_broadcast = router.register_client(client_id);

        let client = Client {
            info: client.info,
            stream: client.stream,
            rx_broadcast,
            read_timeout: client.read_timeout,
        };

        let router_tx_clone = router_tx.clone();
        let router_clone = Arc::clone(&router);

        tokio::spawn(async move {
            let client_id = client.info().id;
            match client.handle(router_tx_clone).await {
                Ok(_) => info!("[Client {}] Disconnected normally", client_id),
                Err(e) => error!("[Client {}] Disconnected with error: {}", client_id, e),
            }
            router_clone.unregister_client(client_id);
        });
    }
}
```

For TLS, `accept_tls_loop` performs a handshake, then wraps the stream passed to `Client::new`.

**Step 3 – Client read loop (`Client::handle`)**

In `crates/omnitak-server/src/client.rs` (shape summarised; code is present but lengthy):

- `Client::handle(router_tx)`:
  - Uses `tokio::select!` or similar to:
    - Read CoT XML from `self.stream` with a read timeout.
    - Receive broadcasted messages from `self.rx_broadcast`.
  - For each inbound CoT message from the socket:
    ```rust
    router_tx.send((self.info.id, cot_xml)).await?;
    ```
  - For each broadcast from router (`Arc<String>`):
    ```rust
    self.send(&message).await?; // Writes to socket
    ```

Once this loop returns (disconnect/error), the accept loop’s spawned task unregisters the client from the router.

#### 1.3 Routing & Broadcast (`CotRouter`)

`crates/omnitak-server/src/router.rs`:

- `run` – main event loop for routing:

  ```rust
  pub async fn run(self: Arc<Self>, mut rx: mpsc::Receiver<(ClientId, String)>) {
      info!("[Router] Started");

      while let Some((client_id, cot_xml)) = rx.recv().await {
          self.route_message(client_id, cot_xml).await;
      }

      info!("[Router] Stopped");
  }
  ```

- `route_message` – broadcast logic:

  ```rust
  pub async fn route_message(&self, from_client_id: ClientId, cot_xml: String) {
      if self.debug {
          info!("[Router] Message from client {}: {}", from_client_id, cot_xml);
      }

      self.total_messages.fetch_add(1, Ordering::Relaxed);

      let message = Arc::new(cot_xml);
      let mut disconnected_clients = Vec::new();

      for entry in self.clients.iter() {
          let client_id = *entry.key();
          let sender = entry.value();

          if client_id == from_client_id {
              continue;
          }

          if let Err(_) = sender.send(Arc::clone(&message)).await {
              warn!("[Router] Client {} channel closed, marking for removal", client_id);
              disconnected_clients.push(client_id);
          }
      }

      for client_id in disconnected_clients {
          self.unregister_client(client_id);
      }
  }
  ```

- `register_client` – invoked by accept loop:

  ```rust
  pub fn register_client(&self, client_id: ClientId) -> mpsc::Receiver<Arc<String>> {
      let (tx, rx) = mpsc::channel(100);
      self.clients.insert(client_id, tx);
      info!("[Router] Registered client {}, total clients: {}", client_id, self.clients.len());
      rx
  }
  ```

Thus, every CoT “request” (from the server’s point of view) is a `(ClientId, String)` message that:

1. Enters `CotRouter::run` via the `mpsc::Receiver`.
2. Is logged / counted.
3. Is fanned out to all other `Client` tasks.

#### 1.4 Inbound CoT on Mobile Clients

On iOS, incoming CoT data flows back through `TAKService.swift`.

Concrete path (Swift):

1. **Socket read in `TAKService`**
   - An internal read loop (e.g., `startReading()`) on a background queue:
     - Reads bytes from the socket or stream.
     - Splits messages based on framing (newline or XML boundary detection).
     - For each full XML packet:
       ```swift
       handleIncomingCoT(xmlString)
       ```

2. **Parse CoT XML** – `CoTMessageParser.swift`
   - Functions like:
     ```swift
     func parse(xml: String) -> CoTEvent?
     ```
   - Uses `XMLParser` / `XMLDocument` to interpret:
     - Event type, UID, time, coordinates.
     - Payload/“detail” elements (chat, mission, routes, etc.).
   - Returns a domain model (e.g. `CoTEvent`, sometimes broken down into specialized enums/structs).

3. **Route parsed event** – `CoTEventHandler.swift`
   - Methods (pattern):
     ```swift
     func handle(event: CoTEvent) {
         switch event.kind {
         case .chat(let message):
             chatManager.handleIncoming(message)
         case .position(let pli):
             trackRecordingService.updateWithPLI(pli)
         case .geofence(let region):
             geofenceManager.updateFromCoT(region)
         ...
         }
     }
     ```
   - Some flows use `NotificationCenter` or Combine publishers to decouple consumers.

4. **Managers update models & persistence**
   - `ChatManager`:
     - Adds message to `@Published var conversations`.
     - Uses `ChatPersistence.swift` / `ChatStorageManager.swift` to persist.
   - `TrackRecordingService` / `BreadcrumbTrailService`:
     - Append location points, manage recording state.
   - `TeamService`, `WaypointManager`, `GeofenceManager`, `EmergencyBeaconService`, etc.:
     - Update in‑memory state and possibly persist via their storage managers.

5. **Views reflect updated state**
   - SwiftUI views binding to `@ObservedObject` managers automatically refresh.

Net effect: A CoT message sent by any client is routed by the Rust server to all others, parsed, dispatched to feature managers, persisted, and rendered.

### 2. HTTP Requests (Client‑side Only)

These flows are unidirectional (client → external APIs); there is no in‑repo HTTP server.

Typical pattern (example: Elevation profile):

1. **UI event**
   - `ElevationProfileView.swift` or other map context UI triggers a profile request.
   - Calls an API on `ElevationProfileService.swift`, e.g.:
     ```swift
     elevationProfileService.loadProfile(for: route)
     ```

2. **Service builds request model**
   - Models from `Models/ElevationProfileModels.swift`:
     - `ElevationProfileRequest`, `ElevationProfilePoint`, `ElevationProfileResponse`, etc.
   - Service prepares input for `ElevationAPIClient`.

3. **API client sends HTTP request**
   - `ElevationAPIClient.swift`:
     ```swift
     func fetchProfile(request: ElevationProfileRequest,
                       completion: @escaping (Result<ElevationProfileResponse, Error>) -> Void) {
         var urlRequest = URLRequest(url: ...)
         urlRequest.httpMethod = "POST"
         urlRequest.httpBody = ...
         URLSession.shared.dataTask(with: urlRequest) { data, response, error in
             // Parse or forward error
         }.resume()
     }
     ```

4. **Parse + publish**
   - JSON decoded into models in `ElevationProfileModels.swift`.
   - `ElevationProfileService` updates `@Published var profile: ElevationProfileResponse?`.
   - UI redraws.

Similar patterns exist for:

- `ArcGISFeatureService` / `ArcGISPortalService` (ArcGIS REST/portal endpoints).
- `TileDownloader` / `OfflineTileCache` (tile HTTP GETs, stored in offline cache).

### 3. Valdi/TS CoT / TAK Flow

On Android / Valdi shells, CoT flows live in TypeScript:

- `modules/omnitak_mobile/src/valdi/omnitak/services/TakService.ts`
  - Manages connection to TAK server (using Valdi HTTP/TCP runtimes).
  - Exposes methods like:
    - `connect(config)`
    - `disconnect()`
    - `sendCoT(xml: string)`
  - Uses `valdi_http` / native bridge modules to talk to the network.

- `modules/omnitak_mobile/src/valdi/omnitak/services/CotParser.ts`
  - Parses incoming CoT XML strings into JS model objects.

- `modules/omnitak_mobile/src/valdi/omnitak/services/MultiServerFederation.ts`
  - Tracks multiple server connections and federated routing logic (client side).

- Event propagation:
  - These services expose observables or Valdi `Provider` state.
  - Screens (e.g., `EnhancedMapScreen.tsx`, `ServerManagementScreen.tsx`, `MapScreenWithMapLibre.tsx`) subscribe and update their UI.

Conceptually, the routing mirrors the Swift side: Screen → Service → TakService (TS) → native → server → back → parser → subscribers.

---

## Middleware Pipeline

There is no traditional HTTP middleware stack; instead, there are layered processing pipelines for CoT and HTTP, with clear stages.

### Client‑Side CoT Receive Pipeline (iOS)

1. **Network I/O layer** – `TAKService.swift`
   - Maintains socket(s) (TCP/UDP/TLS).
   - Performs connection setup/teardown.
   - Reads raw bytes and handles framing:
     - Splits by newline or custom markers into discrete XML messages.
   - Emits raw XML strings.

2. **Parsing layer** – `CoTMessageParser.swift`
   - Converts XML strings → `CoTEvent` or related domain models.
   - Handles malformed XML by:
     - Logging (using OSLog/print).
     - Returning `nil` / error and dropping packet.

3. **Dispatch layer** – `CoTEventHandler.swift`
   - Central in‑process router by event type:
     - Chat, PLI, markers, geofences, teams, missions, emergency, etc.
   - Calls feature‑specific handlers on managers and services.

4. **Domain logic layer** – `Managers/*` and `Services/*`
   - Managers:
     - Apply business rules, conflict resolution, deduplication, merging, stale detection.
     - Expose state as `@Published` properties.
   - Services:
     - Handle I/O to TAK server and local storage.
     - Manage background operations (sync, timeouts, re‑send logic).

5. **Persistence layer** – `Storage/*`
   - Files:
     - `ChatPersistence.swift`, `ChatStorageManager.swift`
     - `RouteStorageManager.swift`, `TeamStorageManager.swift`, etc.
   - Responsible for:
     - Serializing domain models (Codable or custom).
     - Storing in file system / UserDefaults / keychain.
     - Loading at startup or on demand.

6. **Presentation layer** – `Views/*`
   - SwiftUI views observe managers/services and react to updates.

This behaves like a fixed middleware stack: Network → Parse → Route → Domain Logic → Persistence → UI.

### Server‑Side CoT Pipeline

1. **Transport layer**
   - `TakServer::accept_loop` / `accept_tls_loop`:
     - Accept connections.
     - Enforce client limits.
     - Wrap in `Client` instances.

2. **Client handler layer**
   - `Client::handle`:
     - Enforces read timeouts and size limits.
     - Splits the input stream into CoT messages.
     - For each message:
       - Sends `(ClientId, String)` to `router_tx`.
     - For each broadcast from router:
       - Sends to socket.

3. **Routing layer**
   - `CotRouter::run`:
     - Central loop that:
       - Receives messages from all clients.
       - Logs (if debug).
       - Increments `total_messages`.
       - Calls `route_message`.

4. **Broadcasting layer**
   - `CotRouter::route_message`:
     - Sends message to all clients ≠ `from_client_id`.
     - Prunes clients whose channels are closed.

There is no plug‑in chain here; logic is contained in these tightly‑scoped stages.

### HTTP Client Pipelines (iOS)

For each HTTP service:

1. **View** triggers a service method.
2. **Service** builds a request model and passes it to an API client.
3. **API client**:
   - Constructs a `URLRequest` (method, URL, headers, body).
   - Uses `URLSession` to perform network I/O.
4. **Response parsing**:
   - Transform `Data` + `HTTPURLResponse` → domain models with `JSONDecoder` or custom decoders.
5. **Service** updates state / calls completion with `Result<Success, Error>`.
6. **View** responds to new state or error.

Again, this is a fixed stack rather than a configurable middleware pipeline.

### Valdi/TypeScript CoT Pipeline

1. `TakService.ts`:
   - Connects to server, handles reconnection.
   - Writes CoT XML strings via Valdi HTTP/TCP or custom JS/native module.

2. `CotParser.ts`:
   - Parses inbound XML to JS models.

3. Services like `MultiServerFederation.ts`, `MarkerManager.ts`:
   - Maintain in‑memory state.
   - Provide Rx‑style or Valdi provider‑based observables.

4. Screens (`EnhancedMapScreen.tsx`, `ServerManagementScreen.tsx`) subscribe to state.

---

## Controller/Handler Analysis

In this codebase, traditional web controllers are replaced by:

- Swift managers/services.
- CoT event handlers.
- Rust client/router components.
- TS services in the Valdi module.

### iOS – Managers & Services as Controllers

**Key managers (`OmniTAKMobile/Managers`)**

- `ServerManager.swift`
  - Maintains known TAK servers and currently selected one.
  - Interfaces:
    - `addServer(...)`, `removeServer(...)`, `selectServer(...)`.
    - `connectToSelectedServer()` which calls `TAKService.connect(...)`.
  - Observed by:
    - `TAKServersView.swift`, `ServerPickerView.swift`, `QuickConnectView.swift`.

- `ChatManager.swift`
  - Maintains conversations and message lists.
  - Delegates sending to `ChatService`, receiving from `CoTEventHandler`.
  - Persists via `ChatStorageManager`/`ChatPersistence`.

- `CoTFilterManager.swift`
  - Holds filter criteria for map overlays and CoT display.
  - Consumed by `CoTFilterPanel.swift`, `Map*ViewController_FilterIntegration.swift`.

- `GeofenceManager.swift`, `WaypointManager.swift`, `MeasurementManager.swift`, `DrawingToolsManager.swift`, `OfflineMapManager.swift`, `MeshtasticManager.swift`, etc.
  - All act as controllers for their subdomain; they:
    - Interpret UI events (from views, radial menu).
    - Trigger CoT sends or local changes (map overlays, offline tiles).
    - React to inbound CoT events.

**Key services (`OmniTAKMobile/Services`)**

- `TAKService.swift` – network controller for TAK.
- `ChatService.swift` – domain controller for chat (constructs CoT; handles ack/receipt semantics if implemented).
- `PositionBroadcastService.swift` – manages PLI broadcasting schedule and messages.
- `MissionPackageSyncService.swift` – coordinates mission/package sync over TAK.
- `NavigationService.swift`, `RoutePlanningService.swift`, `TurnByTurnNavigationService.swift`.
- `TeamService.swift` – handles team presence, info, roles.

These are generally stateless (or lighter) than managers but contain the procedural logic of “requests” to TAK servers and remote systems.

### CoT Event Handler (`CoTEventHandler.swift`)

This class is the closest analogue to a central request controller on the client:

- Parses or receives pre‑parsed CoT events.
- Routes by type:
  - Chat → `ChatManager`.
  - Route updates → `RoutePlanningService` / `RouteStorageManager`.
  - Markers → `Marker` models + overlay updates.
  - Emergency → `EmergencyBeaconService`.
  - Team / PLI → `TeamService`, `BreadcrumbTrailService`, `TrackRecordingService`.

The routing is done via direct calls and/or broadcast notifications. It defines the mapping between CoT event “kinds” and local handlers.

### Rust TAK Server – Handlers

- **`Client::handle` (in `client.rs`)**
  - Per‑connection handler that:
    - Reads from network.
    - Emits messages to router.
    - Writes broadcast back to network.
  - Handles:
    - Socket read/write errors.
    - Timeouts.

- **`CotRouter` (in `router.rs`)**
  - Central handler for CoT messages across all clients.
  - Its `route_message` logic defines the broadcast semantics:
    - “Send every CoT event to all other connected clients.”

No additional routing (e.g. path‑based) exists; logic is pure pub‑sub.

### Valdi/TS – Controllers

- `TakService.ts`:
  - Acts like `TAKService.swift` but in TS.
- `MultiServerFederation.ts`:
  - Higher‑level controller for multiple servers.
- `MarkerManager.ts`, `MeshtasticService.ts`, `SymbolRenderer.ts`:
  - Feature controllers for JS/Valdi environment.

User interactions on JS screens (e.g., `EnhancedMapScreen.tsx`) translate to method calls on these services, then to CoT sends or local state changes.

---

## Authentication & Authorization Flow

There is no central “auth service” in the Rust server or a generic JWT/OAuth system. Instead, **mutual TLS with client certificates** is the primary security mechanism, combined with certificate management on iOS.

### iOS Certificate & TLS Management

- `OmniTAKMobile/Managers/CertificateManager.swift`
  - Manages certificate inventory on device.
  - Bridges to:
    - `CertificateEnrollmentService.swift` (for SCEP or similar enrollment; see `Services`).
  - Used by UI:
    - `CertificateEnrollmentView.swift`
    - `CertificateManagementView.swift`
    - `CertificateSelectionView.swift`

- `OmniTAKMobile/Services/CertificateEnrollmentService.swift`
  - Handles certificate enrollment/renewal requests to CA/RA servers (HTTPS).

- `TAKService.connect(...)`
  - Accepts `certificateName` and `certificatePassword` (or references).
  - Uses those to configure TLS client credentials for the TAK connection (either via platform TLS APIs or via the Rust `omnitak-mobile` binding).

- Rust crate `crates/omnitak-cert`
  - Implements certificate enrollment and handling logic (SCEP or custom).
  - Exposed via FFI for the iOS and Android bridges.

**Request flow with TLS auth**:

1. User enrolls/chooses certificate through:
   - `CertificateEnrollmentView` / `CertificateManagementView`.
2. `CertificateManager` stores certs in keychain or app storage.
3. `ServerManager` / `TAKServersView` configures server entry to use selected certificate.
4. `TAKService.connect(...)` is called with certificate parameters.
5. TLS handshake on the socket uses that certificate to authenticate to the TAK server.

Authorization beyond TLS (roles, channels) is handled by external TAK servers (not in this repo). The local simple `omnitak-server` does not enforce user‑level authorization; it simply routes CoT.

### Authorization on Rust `omnitak-server`

- `crates/omnitak-server/src/tls.rs`:
  - Defines TLS configuration, CA/root certificates, and optional client auth.
- `src/server.rs`:
  - Uses `tls::load_tls_config` to set up `tokio_rustls::TlsAcceptor`.

Current code does not implement:

- Per‑user access control lists.
- Role‑based filtering of CoT messages.
- Path/method permission checks.

All connected, authenticated (if TLS required) clients participate in the same CoT bus.

---

## Error Handling Pathways

### iOS Client

**Network / TAK errors (`TAKService.swift`)**

- Connection errors:
  - Failures during `connect(...)`:
    - DNS resolution, TLS handshake failure, refusal.
    - Reported via completion handler passed into `connect` or via `@Published var connectionStatus`.
  - Disconnections:
    - Socket close, timeout.
    - `TAKService` updates connection state and notifies `ServerManager` or UI via Combine.

- Send errors:
  - If `send(cotMessage:priority:)` fails:
    - Logs error.
    - May increment an error counter.
    - Depending on implementation, may:
      - Drop the message.
      - Mark connection as unhealthy and trigger reconnection.

**Parsing errors (`CoTMessageParser.swift`)**

- Invalid XML:
  - Caught via XML parser exceptions or `nil` returns.
  - Handler logs and drops.
- Unknown CoT types:
  - Parsed but possibly not dispatched if `CoTEventHandler` lacks a mapping.
  - No crash; event is ignored.

**Service/manager level**

- HTTP services:
  - Wrap errors in `Result<Success, Error>`.
  - Propagate to views which display alerts or inline error messages.
- Managers:
  - May enforce invariants (e.g., non‑empty server host), logging misconfigurations.

### Rust `omnitak-server`

- Uses `anyhow::Result` or custom `Error` (`crates/omnitak-server/src/error.rs`) to represent failures.

**Server start / bind errors (`TakServer::start`)**

- Errors binding ports or setting up TLS bubble up as `Result::Err`.
- Caller is expected to log and exit.

**Accept loop errors**

- A failed `listener.accept()`:
  - Logged via `error!`.
  - Loop continues or propagates (depending on implementation).

**Client handler errors (`Client::handle`)**

- Inside spawned task:

  ```rust
  match client.handle(router_tx_clone).await {
      Ok(_) => info!("[Client {}] Disconnected normally", client_id),
      Err(e) => error!("[Client {}] Disconnected with error: {}", client_id, e),
  }
  router_clone.unregister_client(client_id);
  ```

- Errors:
  - Read timeout.
  - Socket read/write failure.
  - Malformed data (if validated).
- Result:
  - Logs and client is unregistered from router.

**Router broadcast errors**

- `route_message`:

  ```rust
  if let Err(_) = sender.send(Arc::clone(&message)).await {
      warn!("[Router] Client {} channel closed, marking for removal", client_id);
      disconnected_clients.push(client_id);
  }
  ```

- Failed broadcasts do not fail the router loop:
  - They mark clients for removal and unregister them.
- This avoids backpressure from dead clients.

There is no concept of HTTP status codes in this server; all error reporting is via logs and connection lifecycle.

---

## Request Lifecycle Diagram

Below is a textual diagram showing a full CoT lifecycle.

### 1. Client‑side CoT (iOS) – Outbound & Inbound

```text
[User]
  |
  v
[SwiftUI View] (e.g., ChatView, PositionBroadcastView)
  |   - User taps "Send", toggles broadcast, drops marker, etc.
  v
[Manager] (ChatManager, PositionBroadcastService, GeofenceManager, ...)
  |   - Validates input, enriches with context (location, time, etc.)
  v
[Service] (ChatService, DigitalPointerService, ...)
  |   - Uses CoT generator to build XML
  v
[TAKService.send(cotMessage)]  ----------------------------.
  |                                                        |
  |   - Writes CoT XML to TCP/TLS/UDP socket               |
  v                                                        |
[Network stack / OS / TLS]                                 |
  |   - Bytes travel over the network                      |
  v                                                        |
+----------------------------------------------------------+
|                      Remote side (Rust)                 |
|                                                        |
|   [TcpListener / TlsListener]                           |
|      |                                                  |
|      v                                                  |
|   [accept_loop / accept_tls_loop]                       |
|      |  - For each connection:                          |
|      v                                                  |
|   [Client { id, stream, rx_broadcast }]                 |
|      |                                                  |
|      v                                                  |
|   [Client::handle(router_tx)]                           |
|      |  - Reads CoT messages from stream                |
|      |  - router_tx.send((client_id, xml)) ------------>|
|      |                                                  v
|   (simultaneously)                                  [CotRouter::run]
|      ^                                                 /   \
|      |                                                /     \
|      |                                   route_message(from, xml)
|      |                                                \     /
|      |                                                 \   /
|      |                                              [Broadcast loops]
|      |                                              /    |      \
|      |                            tx_to_client_A --'  tx_to_B ... tx_to_N
+------+--------------------------------------------------------------+
       |
       |  (for each other connected client)
       v
[Client::handle] (on other clients)
  |   - Receives Arc<String> from rx_broadcast
  |   - Writes XML to their socket
  v
[Network stack / OS / TLS]
  |
  v
[TAKService] (on each client)
  |   - Reads XML from socket
  v
[CoTMessageParser]
  |   - XML -> CoTEvent
  v
[CoTEventHandler]
  |   - Dispatches to appropriate manager/service
  v
[Managers / Services]
  |   - Update in-memory models & persist if needed
  v
[SwiftUI Views]
  - Automatically update via @Published / @ObservedObject
```

### 2. HTTP Request Lifecycle (iOS, example: Elevation)

```text
[User]
  |
  v
[View] (ElevationProfileView)
  |
  v
[ElevationProfileService.loadProfile(route)]
  |
  v
[ElevationAPIClient.fetchProfile(request)]
  |
  v
[URLSession] --> [Remote HTTP Service (e.g., Elevation API)]
  |
  v
[HTTP Response (status code, body)]
  |
  v
[ElevationAPIClient parses JSON -> ElevationProfileResponse]
  |
  v
[ElevationProfileService updates @Published state]
  |
  v
[View] redraws to show elevation profile or error
```

### 3. Valdi/TS CoT Lifecycle (Conceptual)

```text
[User]
  |
  v
[Valdi Screen] (EnhancedMapScreen.tsx, Chat UI in TS)
  |
  v
[TS Service] (TakService.ts, MarkerManager.ts)
  |
  v
[Native HTTP/TCP module via valdi_http / runtime bridge]
  |
  v
[Network] -> [Rust omnitak-server] -> [Other clients]
  |
  v
[Native bridge -> TakService.ts.onMessage(xml)]
  |
  v
[CotParser.ts xml -> JS model]
  |
  v
[Services update observables / provider state]
  |
  v
[TS Screens] reactively re-render
```

---

This analysis is based on the actual files present in the repository and the documented behavior in `apps/omnitak/docs/Architecture.md`, `docs/api`, and `.ai/docs/request_flow_analysis.md`. It focuses on real, implemented request paths and omits any features that are only stubbed or marked TODO (e.g., Marti HTTP API server).
