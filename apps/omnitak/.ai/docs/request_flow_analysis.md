# Request Flow Analysis

## Entry Points Overview

OmniTAK Mobile is an iOS client; “requests” are primarily:

1. **Outbound TAK network requests (CoT/XML over TCP/UDP/TLS)**  
   - Entry point: service/manager methods that call `TAKService` which uses `DirectTCPSender`.
   - Examples:
     - `ChatService.sendTextMessage(_:to:)`
     - `PositionBroadcastService.broadcastPositionNow()`
     - Other feature services (routes, markers, packages) that ultimately call `TAKService.send(...)`.

2. **Inbound TAK network messages (CoT/XML from TAK server)**  
   - Entry point: `DirectTCPSender`’s receive loop (`startReceiveLoop` → `processReceivedData`).
   - CoT XML is parsed by `CoTMessageParser` and dispatched to feature managers/handlers such as `CoTEventHandler`, `ChatManager`, map/track services, etc.

3. **Local user-initiated flows (UI as entry)**  
   - Views in `OmniTAKMobile/Views` are the top‑level entry for user actions.
   - They depend on `Managers/` (view models) that in turn call `Services/`.
   - Examples:
     - `ChatView` → `ChatManager` → `ChatService` → `TAKService` → network.
     - `PositionBroadcastView` → `PositionBroadcastService` → `TAKService`.
     - `TAKServersView` / `ServerPickerView` → `ServerManager` + `TAKService.connect(...)`.

There is no HTTP/REST API exposed by this app; the “API endpoints” are TAK server sockets (TCP/UDP/TLS) and internal Swift service methods.

---

## Request Routing Map

### 1. Outbound CoT / Feature Requests

**General pattern (documented in `Architecture.md` / `Services.md` and visible in code):**

1. **UI View**  
   - SwiftUI view under `OmniTAKMobile/Views/` reacts to user action.
   - Examples: `ChatView`, `PositionBroadcastView`, `RoutePlanningView`.

2. **Manager (ViewModel) layer** (`OmniTAKMobile/Managers/`)  
   - `ObservableObject` holds state and orchestrates operations.
   - Example (`Architecture.md`):

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

   - Request routing: Manager takes UI input, calls the appropriate `Service` method.

3. **Service layer** (`OmniTAKMobile/Services/`)  
   - Business logic and protocol translation.
   - Example from `docs/API/Services.md`:

     ```swift
     class ChatService: ObservableObject {
         static let shared = ChatService()
         // ...
         func configure(takService: TAKService, locationManager: LocationManager) { ... }
         func sendTextMessage(_ text: String, to: String) { ... } // internally uses TAKService
     }
     ```

   - Typical route:
     - Domain service builds CoT XML (`ChatCoTGenerator`, `MarkerCoTGenerator`, etc. in `CoT/Generators`).
     - Calls `TAKService.send(cotMessage:priority:)`.

4. **TAKService** (`OmniTAKMobile/Services/TAKService.swift`)  
   - Central network orchestrator for TAK.
   - Holds statistics and connection state (per `Services.md` / `Networking.md`).

   - For sending messages (simplified flow):
     - Validates connectivity and/or queues if offline (`messageQueue` as per `Networking.md`).
     - Delegates to `DirectTCPSender.send(xml:)` for immediate send if connected.

5. **DirectTCPSender** (`TAKService.swift`, top of file)  
   - Lowest-level network sender:

     ```swift
     class DirectTCPSender {
         private var connection: NWConnection?
         private let queue = DispatchQueue(label: "com.omnitak.network")
         // ...
         func send(xml: String) -> Bool {
             guard let connection = connection, connection.state == .ready else {
                 print("❌ DirectNetwork: Not connected")
                 return false
             }
             let message = xml + "\n"
             let data = message.data(using: .utf8)!
             connection.send(content: data, completion: .contentProcessed { error in ... })
             return true
         }
     }
     ```

   - Routing: all outbound CoT XML leaves the app through this class’ `NWConnection`.

6. **Network layer**  
   - `NWConnection` (Network framework) sends to TAK server host/port using chosen protocol (TCP/UDP/TLS).

**Summary path (outbound):**

`SwiftUI View` → `Manager (ObservableObject)` → `Feature Service` → `TAKService` → `DirectTCPSender` → `NWConnection` → **TAK server**

---

### 2. Inbound CoT / Server Messages

1. **Network receive loop** (`DirectTCPSender.startReceiveLoop()`):

   ```swift
   private func startReceiveLoop() {
       guard let connection = connection else { return }
       connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
           // error handling
           if let data = data, !data.isEmpty {
               self.bytesReceived += data.count
               self.processReceivedData(data)
           }
           if isComplete { self.onConnectionStateChanged?(false); return }
           self.startReceiveLoop()
       }
   }
   ```

2. **Buffer and parse XML** (`processReceivedData` → `extractAndProcessMessages`):

   ```swift
   private func processReceivedData(_ data: Data) {
       guard let receivedString = String(data: data, encoding: .utf8) else { return }
       bufferLock.lock()
       receiveBuffer += receivedString
       bufferLock.unlock()
       extractAndProcessMessages()
   }

   private func extractAndProcessMessages() {
       bufferLock.lock()
       defer { bufferLock.unlock() }
       let (messages, remaining) = CoTMessageParser.extractCompleteMessages(from: receiveBuffer)
       receiveBuffer = remaining

       for message in messages {
           if CoTMessageParser.isValidCoTMessage(message) {
               messagesReceived += 1
               DispatchQueue.main.async { [weak self] in
                   self?.onMessageReceived?(message)
               }
           }
       }
   }
   ```

3. **Routing into app domain**  
   - `TAKService` sets `DirectTCPSender.onMessageReceived` to its internal handler.
   - That handler:
     - Updates `messagesReceived`/`bytesReceived` stats.
     - Feeds raw CoT XML into **CoT-related components**:
       - `CoTEventHandler` (for generic events and markers).
       - `ChatXMLParser` / `ChatManager` (for GeoChat).
       - Other managers/services relying on CoT (tracks, PLI, geofences, etc.).

   - These components update domain models and `@Published` properties on managers, which propagate to UI.

**Summary path (inbound):**

`TAK server` → `NWConnection` → `DirectTCPSender.receive` → `CoTMessageParser` → `TAKService` → `CoTEventHandler` / `ChatManager` / other managers → `SwiftUI Views`

---

## Middleware Pipeline

The app doesn’t use middleware in the HTTP-server sense, but the request flow *does* pass through layered processing steps that act like middleware:

### Outbound “Middleware” Phases

1. **View-level input collection**
   - Views gather user input and call manager methods.
   - Example: `ChatView` calling `chatManager.sendMessage(...)`.

2. **Manager-level pre-processing**
   - E.g., `ChatManager`:
     - Validate UI inputs (non-empty message, selected recipient).
     - Update local state optimistically.
     - Delegate to `ChatService`.

3. **Service-level transformation**
   - Build CoT XML, apply domain rules and metadata:
     - Chat → `ChatCoTGenerator` + `ChatXMLGenerator`.
     - Waypoints/routes → generators in `CoT/Generators`.
     - PLI → position formatting.

4. **TAKService-level network policy**
   - Decide whether to:
     - Send immediately via `DirectTCPSender` if connected.
     - Enqueue into `messageQueue` if disconnected as described in `Networking.md`.
   - Potential logging/statistics.

5. **DirectTCPSender-level finalization**
   - Append newline terminator.
   - Convert to UTF‑8 `Data`.
   - Submit to `NWConnection.send`.

These layers form a linear, ordered pipeline, but there’s no plug‑in middleware registry; the pipeline is explicit in each feature’s service code.

### Inbound “Middleware” Phases

1. **Network fragmentation handling**
   - `DirectTCPSender`’s `receiveBuffer` collects potentially partial messages.
   - `CoTMessageParser.extractCompleteMessages` performs message boundary detection.

2. **Validation**
   - `CoTMessageParser.isValidCoTMessage(message)` checks that the XML is a valid CoT event before it’s passed further.

3. **Dispatch**
   - `TAKService`’s message handler routes messages to:
     - `CoTEventHandler` (global event routing).
     - Feature-specific managers/services (Chat, Map, Tracks, etc.).

4. **Domain-level handling**
   - Feature managers interpret parsed CoT, update their in‑memory models, and publish via `@Published`.

Again, there’s no declarative middleware chain; the logic is in specialized handlers.

---

## Controller/Handler Analysis

### SwiftUI Views (Entry Controllers)

- Located at `OmniTAKMobile/Views/`.
- Each view is essentially the “controller” for its domain in MVVM.
- Examples of request‑initiating views:
  - `ChatView`, `ConversationView` → chat send/receive flow.
  - `PositionBroadcastView` → PLI broadcast settings and toggling.
  - `TAKServersView`, `QuickConnectView`, `ServerPickerView` → connection requests via `TAKService`.
  - `RoutePlanningView`, `PointDropperView`, `DigitalPointerView`, etc. → generate CoT markers/routes and send.

**Patterns (from `docs/Architecture.md`):**

```swift
struct ChatView: View {
    @ObservedObject var chatManager: ChatManager
    
    var body: some View {
        List(chatManager.conversations) { conversation in
            ConversationRow(conversation: conversation)
        }
    }
}
```

### Managers as Controllers/ViewModels

- Under `OmniTAKMobile/Managers/`:
  - `ChatManager`, `PositionBroadcastService` (also a service), `ServerManager`, `CoTFilterManager`, `WaypointManager`, etc.
- Responsibilities:
  - Accept actions from views.
  - Mutate local `@Published` state.
  - Call underlying services.

Example pattern from docs:

```swift
class ChatManager: ObservableObject {
    @Published var conversations: [Conversation] = []
    // ...
    private let chatService: ChatService

    func sendMessage(_ text: String, to recipient: String) {
        let message = chatService.createMessage(text, recipient)
        chatService.send(message)
    }
}
```

These managers effectively *route* UI‑initiated “requests” to service‑level handlers.

### Services (Core Handlers)

Key services involved in request flow (from `docs/API/Services.md` and FS listing):

- `TAKService`: central network handler; entry and exit for all CoT to/from TAK server.
- `ChatService`: orchestrates chat CoT generation and sending; handles queue/retry.
- `PositionBroadcastService`: periodically composes and sends position reports.
- `BreadcrumbTrailService`, `TrackRecordingService`, `RoutePlanningService`, `GeofenceService`, etc.: each handles its own CoT shapes/messages and interacts with `TAKService`.

Each service exposes methods like:

- `configure(takService:..., locationManager:...)`
- `start…()`, `stop…()`
- Domain-specific operations (`sendTextMessage`, `broadcastPositionNow`, `syncMissionPackage`, etc.)

### CoT and XML Handlers

- `OmniTAKMobile/CoT/CoTEventHandler.swift`:
  - Central handler for incoming CoT events.
  - Likely accepts parsed CoT models and routes to:
    - Map overlay systems (markers, tracks).
    - Chat system (`ChatManager`).
    - Team/unit tracking.

- `CoTMessageParser.swift`:
  - Extracts and validates CoT messages from raw XML text, used directly by `DirectTCPSender`.

- `OmniTAKMobile/CoT/Parsers/ChatXMLParser.swift`:
  - Specialized parser for GeoChat XML, converting inbound chat CoT to `ChatMessage` models.

- `OmniTAKMobile/CoT/Parsers/ChatXMLGenerator.swift` and `CoT/Generators/*`:
  - Generate CoT XML from internal models for outbound messages.

---

## Authentication & Authorization Flow

There is no per‑request application‑level authorization pipeline (no roles attached to each message at app layer). Security is concentrated at the **transport/certificate** level:

### TLS & Client Certificates

`DirectTCPSender.connect(...)`:

```swift
if useTLS || protocolType.lowercased() == "tls" {
    currentProtocol = .tls
    let tlsOptions = NWProtocolTLS.Options()
    let secOptions = tlsOptions.securityProtocolOptions

    if allowLegacyTLS {
        sec_protocol_options_set_min_tls_protocol_version(secOptions, tls_protocol_version_t(rawValue: 769)!) // TLS 1.0
    } else {
        sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv12)
    }
    sec_protocol_options_set_max_tls_protocol_version(secOptions, .TLSv13)

    // Accept self-signed server certificates
    sec_protocol_options_set_verify_block(secOptions, { (metadata, trust, complete) in
        complete(true)
    }, .main)

    // Optional client certificate
    if let certName = certificateName, !certName.isEmpty {
        if let identity = loadClientCertificate(name: certName, password: certificatePassword ?? "atakatak") {
            sec_protocol_options_set_local_identity(secOptions, identity)
        }
    }

    parameters = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
}
```

**Authentication steps:**

1. **Server Authentication**  
   - Default behavior: accept any server certificate (including self‑signed).
   - This is documented explicitly in `docs/Features/Networking.md` as a TAK‑compatibility choice.

2. **Client Authentication (mTLS)**  
   - If a `certificateName` is provided:
     - `loadClientCertificate(name:password:)` attempts:
       1. `CertificateManager.shared` (Keychain‑stored certs, `CertificateManager.swift`).
       2. Documents directory: `Documents/Certificates/<name>.p12`.
       3. App bundle: `<name>.p12`.
     - If an identity is found, it is attached via `sec_protocol_options_set_local_identity`.
   - TAK server then uses this identity to authorize operations.

**App-level authorization:**

- The app does not have a formal authorization middleware or ACL per message.
- Authorization is implied by:
  - TAK server’s mTLS client identity.
  - Team/role settings included in certain models (e.g., `PositionBroadcastService` includes `teamColor`, `teamRole`, `userUnitType` in PLI messages), but no local enforcement of allowed actions is evident in the inspected code/docs.

---

## Error Handling Pathways

### Network Connection Errors

In `DirectTCPSender.connect`:

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

- Errors are surfaced via:
  - Console logs (debug and production).
  - `onConnectionStateChanged` callback, which `TAKService` uses to update `@Published` fields (`isConnected`, `connectionStatus`).
  - The completion closure called with `false` on failure.

`TAKService` then exposes human‑readable status for UI (e.g., `ConnectionStatusWidget` in `UI/Components`).

### Receive Errors

`startReceiveLoop`:

```swift
if let error = error {
    print("❌ DirectNetwork: Receive error: \(error)")
    return
}
if isComplete {
    print("🔌 DirectNetwork: Connection closed by server")
    self.onConnectionStateChanged?(false)
    return
}
```

- On error: log, terminate receive; connection state callback not updated to “failed” here but `onConnectionStateChanged(false)` is called when `isComplete` is true.
- Higher levels (TAKService, ServerManager) implement reconnection/queueing logic (documented in `docs/Features/Networking.md`, though the exact reconnect code is deeper in `TAKService.swift` beyond the snippet).

### Message Validation / Parsing Errors

- `processReceivedData`: if UTF‑8 decode fails, logs a warning and discards data.
- `extractAndProcessMessages`:
  - Uses `CoTMessageParser.isValidCoTMessage(message)`:
    - If invalid: logs warning `⚠️ DirectNetwork: Invalid CoT message discarded`.
  - Buffer growth protection:
    - Warn > 100,000 chars.
    - Clear buffer completely if > 1,000,000 chars to avoid memory issues.

No retry/repair is attempted for invalid messages; they’re dropped.

### Certificate Errors

- `loadClientCertificate`:
  - Logs if:
    - Certificate not found in any location.
    - Identity cannot be loaded (`Failed to read certificate data`, `Failed to load from CertificateManager`).
  - Returns `nil` → TLS is established without client cert; no crash.

### Service-Level Errors

- Individual services (as documented in `docs/API/Services.md`) typically:
  - Update `@Published` error/status properties.
  - Log failures (e.g., queue processing failures in `ChatService.processQueue()`).
- There is no centralized global error bus; each manager/service exposes its own state.

---

## Request Lifecycle Diagram

Below is a textual diagram of the **standard outbound** and **inbound** request lifecycles as implemented.

### Outbound CoT / Feature Request (e.g., Send Chat Message)

```text
[User taps "Send" in ChatView]
          │
          ▼
[ChatView (SwiftUI)]
  • Calls chatManager.sendMessage(text, recipient)
          │
          ▼
[ChatManager (Manager/ViewModel)]
  • Validates input
  • Builds domain model (ChatMessage) or delegates to ChatService
          │
          ▼
[ChatService (Service)]
  • createMessage(text, recipient) → ChatMessage + CoT XML via ChatCoTGenerator/ChatXMLGenerator
  • send(message):
        TAKService.send(cotMessage: message.cotXML, priority: ...)
          │
          ▼
[TAKService (Core networking service)]
  • If connected → use DirectTCPSender.send(xml)
  • If not connected → enqueue in messageQueue for later processing
  • Update messagesSent, bytesSent stats
          │
          ▼
[DirectTCPSender]
  • Append "\n", convert to UTF‑8 Data
  • connection.send(content: data, completion: ...)
          │
          ▼
[NWConnection (TCP/UDP/TLS socket)]
  • OS-level send over network
          │
          ▼
[TAK Server]
  • Interprets CoT XML and applies its own authorization and routing
```

### Inbound CoT / Server Message (e.g., Incoming Chat/PLI)

```text
[TAK Server sends CoT XML over TCP/UDP/TLS]
          │
          ▼
[NWConnection]
  • Delivers raw bytes to app
          │
          ▼
[DirectTCPSender.startReceiveLoop()]
  • connection.receive(...) → data, isComplete, error
  • On data:
      processReceivedData(data)
          │
          ▼
[DirectTCPSender.processReceivedData]
  • Decode UTF‑8 string
  • Append to receiveBuffer (with NSLock)
  • extractAndProcessMessages()
          │
          ▼
[extractAndProcessMessages()]
  • (messages, remaining) = CoTMessageParser.extractCompleteMessages(receiveBuffer)
  • receiveBuffer = remaining
  • For each message:
       if CoTMessageParser.isValidCoTMessage(message):
           messagesReceived += 1
           DispatchQueue.main.async {
               onMessageReceived?(message)
           }
       else:
           discard and log
          │
          ▼
[TAKService.onMessageReceived handler]
  • Parses CoT XML into strongly-typed models (CoTEvent, ChatMessage, etc.)
  • Dispatches to:
      - CoTEventHandler (general events)
      - ChatManager/ChatService (chat)
      - TrackRecordingService / BreadcrumbTrailService (tracks)
      - PositionBroadcastService / TeamService (PLI/team updates)
          │
          ▼
[Managers (ObservableObjects)]
  • Update @Published domain state
  • Persist via Storage managers if needed (ChatPersistence, RouteStorageManager, etc.)
          │
          ▼
[SwiftUI Views]
  • Observe managers via @ObservedObject / @EnvironmentObject
  • UI automatically reflects new messages, tracks, markers, etc.
```

### Connection Establishment Lifecycle (Authentication Context)

```text
[User configures TAK server & taps "Connect"]
          │
          ▼
[ServerPickerView / TAKServersView]
  • Calls serverManager.connect(to: server)
          │
          ▼
[ServerManager]
  • Reads TAKServer model: host, port, protocolType, TLS options, certificateName
  • TAKService.connect(host:port:protocolType:useTLS:certificateName:certificatePassword:allowLegacyTLS: completion:)
          │
          ▼
[TAKService]
  • Configures DirectTCPSender callbacks (onMessageReceived, onConnectionStateChanged)
  • Calls sender.connect(...)
          │
          ▼
[DirectTCPSender.connect]
  • Builds NWEndpoint.hostPort
  • Chooses NWParameters:
      - TLS + TCP   if useTLS / protocolType == "tls"
      - UDP         if protocolType == "udp"
      - TCP         otherwise
  • For TLS:
      - Configure TLS versions (min/max)
      - Accept all server certs (verify_block always true)
      - Load client cert via CertificateManager / Documents / Bundle
      - Attach identity if present
  • Set stateUpdateHandler to relay connection state
  • connection.start(queue)
          │
          ▼
[NWConnection]
  • Performs DNS, TCP/UDP handshake, TLS handshake
  • On success → stateUpdateHandler(.ready) → startReceiveLoop()
  • On failure → stateUpdateHandler(.failed(error)) → completion(false)
```

This describes the actual implemented control flow based on the inspected files and documentation.