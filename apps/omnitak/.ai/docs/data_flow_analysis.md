# Data Flow Analysis

## Data Models Overview

OmniTAK Mobile is strongly model‑driven: almost all feature data lives in Swift `struct` models that are `Codable`, `Identifiable`, and often `Equatable`. Models are grouped by domain in `OmniTAKMobile/Models/`.

Key patterns (from `docs/API/Models.md` and model files):

- **Protocols**
  - `Identifiable` – gives each entity a stable `id` for SwiftUI lists and persistence.
  - `Codable` – enables JSON/Plist and file storage.
  - `Equatable` – supports diffing, deduplication, and comparison.

- **Naming**
  - Singular model names: `ChatMessage`, `Conversation`, `Track`, `Waypoint`, `TAKServer`, etc.
  - Suffix `Model` only where necessary (e.g. `CoTFilterModel`).

Representative models and their roles in data flow:

### CoT / Tactical Awareness

- **`CoTEvent`** (documented in `docs/API/Models.md`, code in `OmniTAKMobile/Models/CoTModels.swift` – referenced):
  - Represents a normalized CoT event:
    - Identity & timing: `id`, `uid`, `type`, `time`, `start`, `stale`, `how`.
    - Location: `coordinate: CLLocationCoordinate2D`, `hae`, `ce`, `le`.
    - Detail: `callsign`, `team`, `role`, `remarks`.
  - Used as the canonical in‑app representation of CoT XML “event” elements.

- **`EnhancedCoTMarker`** (`Models/ArcGISModels.swift` & `docs/API/Models.md`):
  - UI‑oriented structure mapping CoT events onto map markers:
    - `uid`, `coordinate`, `callsign`, `type`, `team`, `lastUpdate`.
    - Trail: `trailCoordinates`, `trailTimestamps`.
    - Status: `battery`, `speed`, `course`, computed `isStale`.
  - Acts as a *view model* for displaying SA on map overlays.

- **`EmergencyAlert`** (in `CoTMessageParser.swift`):
  - Not `Codable`, but `Identifiable` + `Equatable`.
  - Fields: `uid`, `alertType`, `callsign`, `coordinate`, `timestamp`, `message`, `cancel`.
  - Produced only by parsing CoT XML, consumed by alert handling UI/services.

### Chat System

From `docs/API/Models.md` and `OmniTAKMobile/Models/ChatModels.swift`:

- **`ChatMessage`**
  - `id` (message UID), `senderUID`, `senderCallsign`, `recipientUID`, `recipientCallsign`, `messageText`, `timestamp`.
  - `coordinate: CLLocationCoordinate2D?` for location‐aware messages.
  - `attachment: ImageAttachment?` for photo/file.
  - `status: MessageStatus` (pending/sending/sent/delivered/failed).
  - `isRead: Bool`.

- **`MessageStatus`** (`enum String, Codable`)
  - Lifecycle states used by queueing, delivery, and UI.

- **`Conversation`**
  - `id`, `[ChatParticipant]`, `[ChatMessage]`, `unreadCount`, `lastMessage`, `isGroupChat`, `name`.
  - Represents logical thread / chat room; used heavily in `ChatManager` for UI and persistence.

- **`ChatParticipant`**
  - `id` = CoT UID, `callsign`, `endpoint`, `lastSeen`, `isOnline`, `coordinate`.

- **`ImageAttachment`**
  - Metadata + multiple storage/transmission forms:
    - Disk: `localPath`, `thumbnailPath`.
    - Wire: `base64Data`.
    - Remote: `remoteURL`.
  - Used by `PhotoAttachmentService` and chat flows.

- **Queue Models (`ChatStorageManager.swift`)**
  - `QueuedMessageStatus` (`pending`, `sending`, `failed`, `completed`).
  - `QueuedMessage: Codable, Identifiable`
    - `message: ChatMessage`
    - `xmlPayload: String` (the actual GeoChat CoT XML for wire)
    - `retryCount`, `createdAt`, `lastAttempt`, `status`.
  - These models are specifically for offline/unstable network handling.

### Server & Certificate Models

Described in `docs/API/Managers.md`:

- **`TAKServer`** (code in `Models`):
  - Holds server connection details: name, host, port, protocol (`tls`/`tcp`), TLS flags, etc.
  - Persisted by `ServerManager` to `UserDefaults`.

- **`TAKCertificate`** (in `Models` / certificate flows):
  - Metadata for .p12 client certs (common name, expiration, keychain reference).
  - Managed by `CertificateManager` & `CertificateEnrollmentService`.

### Offline Maps, Routes, Tracks, Waypoints, etc.

Other model groups are consistent:

- **Routes/Tracks**: `Route`, `RouteWaypoint`, `Track`, `TrackPoint` in `RouteModels.swift` / `TrackModels.swift`. Used by `TrackRecordingService`, `RoutePlanningService`, `RouteStorageManager`.
- **Waypoints**: `Waypoint` in `WaypointModels.swift`, associated with CoT waypoint events and persistent waypoint lists.
- **Geofences, Echelons, Teams, Video streams, Offline maps**: each has its own model file and is used by its associated Manager + Service.

### Summary

- **Domain models** are simple, typed Swift structs with minimal logic.
- **Transport/protocol** is almost always transformed into these models before entering app logic (CoT XML → `CoTEvent`, GeoChat XML → `ChatMessage`).
- **Persistence** uses these models directly via `Codable` (JSON files, `UserDefaults`).

---

## Data Transformation Map

This section focuses on how data changes shape as it crosses boundaries: network ↔ CoT ↔ domain models ↔ storage ↔ UI.

### 1. CoT XML → Internal Models

**Entry point:** CoT XML strings arriving from TAK server through `TAKService`.

- **`TAKService`** (docs/API/Services.md):
  - Reads raw XML from underlying Rust/iOS framework (the `omnitak_mobile` xcframework).
  - For each message, it dispatches XML to `CoTMessageParser.parse(xml:)`.

- **`CoTMessageParser.parse(xml:)`** (`CoTMessageParser.swift`):

  ```swift
  static func parse(xml: String) -> CoTEventType? {
      guard let eventType = extractAttribute("type", from: xml) else { ... }

      if eventType.hasPrefix("a-") {
          if let cotEvent = parsePositionUpdate(xml: xml) {
              return .positionUpdate(cotEvent)
          }
      } else if eventType == "b-t-f" {
          if let chatMessage = parseChatMessage(xml: xml) {
              return .chatMessage(chatMessage)
          }
      } else if eventType.hasPrefix("b-a-") {
          if let alert = parseEmergencyAlert(xml: xml) {
              return .emergencyAlert(alert)
          }
      } else if eventType == "b-m-p-w" || eventType.hasPrefix("b-m-p-s-p-i") {
          if let cotEvent = parseWaypoint(xml: xml) {
              return .waypoint(cotEvent)
          }
      } else if eventType == "t-x-takp-v" { ... } // logged & ignored
      ...
      return .unknown(eventType)
  }
  ```

  Transformations:

  - **Type inspection** (`type` attribute) determines which parser is used.
  - Each parser extracts data using custom regex/string helpers (`extractAttribute`, `extractPoint`, `extractDetail`, `extractTimestamp`, etc.).
  - Output is polymorphic:
    - `CoTEventType.positionUpdate(CoTEvent)`
    - `CoTEventType.chatMessage(ChatMessage)`
    - `CoTEventType.emergencyAlert(EmergencyAlert)`
    - `CoTEventType.waypoint(CoTEvent)`
    - `CoTEventType.unknown(String)`

- **`parsePositionUpdate(xml:)`**:
  - Extracts `uid`, `type`, `<point>` lat/lon/hae/ce/le.
  - Maps to `CoTEvent`:

    ```swift
    return CoTEvent(
        uid: uid,
        type: typeStr,
        time: time,
        point: point,
        detail: detail
    )
    ```

  - Here `detail` is a custom struct defined in CoT models for callsign/team/remarks.

- **`parseChatMessage(xml:)`**:
  - Delegates to `ChatXMLParser.parseGeoChatMessage(xml:)` (defined in `CoT/Parsers/ChatXMLParser.swift`, documented in `ChatSystem.md`).
  - That parser uses `XMLParser` to reconstruct a `ChatMessage` from GeoChat CoT events.

- **`parseEmergencyAlert(xml:)`**:
  - Parses `EmergencyAlert` by:
    - Attributes from `<event>` and `<emergency>` elements.
    - `<remarks>` for message text.
    - `<point>` for coordinates.
  - Normalises alert types via `AlertType.from(type:)`.

**Downstream flow:**

- `TAKService` or `CoTEventHandler` (file `CoTEventHandler.swift`) receive `CoTEventType` and dispatch:
  - Position updates → Map managers / `MapStateManager` / `BreadcrumbTrailService`.
  - Chat messages → `ChatManager.processIncomingMessage(_:)`.
  - Emergency alerts → dedicated manager/view.
  - Waypoints → `WaypointManager`.

### 2. Domain Models → CoT XML (Outbound)

Several generators convert internal models back to CoT XML.

#### Chat: `ChatManager` → `ChatCoTGenerator` → `TAKService`

From `ChatSystem.md`:

- **Sending message from UI:**

  ```swift
  func sendMessage(text: String, to conversationId: String) {
      guard let conversation = getConversation(id: conversationId) else { return }

      let message = ChatMessage(
          id: UUID().uuidString,
          senderUID: currentUserId,
          senderCallsign: currentUserCallsign,
          recipientUID: conversation.recipientUID,
          recipientCallsign: conversation.name,
          messageText: text,
          timestamp: Date(),
          status: .pending
      )

      messages.append(message)
      updateConversation(with: message)

      let cotXML = ChatCoTGenerator.generateChatMessage(
          from: message,
          senderLocation: locationManager?.location?.coordinate
      )

      takService?.send(cotMessage: cotXML, priority: .high)

      updateMessageStatus(message.id, status: .sent)
  }
  ```

- **Transformation steps:**
  1. **UI** (e.g. `ConversationView`) captures user text.
  2. `ChatManager` builds a `ChatMessage` with local metadata.
  3. `ChatCoTGenerator.generate...` transforms this model to protocol‑compliant `String` (GeoChat CoT XML).
  4. `TAKService.send(cotMessage:priority:)` takes XML string, passes to Rust/iOS underlying library for network transmission.
  5. Queue logic (if TAK not connected) wraps this XML + `ChatMessage` in a `QueuedMessage` stored by `ChatStorageManager`.

- **`ChatCoTGenerator.generateGeoChatCoT`** (in `CoT/Generators/ChatCoTGenerator.swift`):

  ```swift
  static func generateGeoChatCoT(message: ChatMessage, conversation: Conversation) -> String {
      ...
      let uid = "GeoChat.\(message.senderId).\(conversation.id).\(message.id)"
      let chatType = "b-t-f"
      let chatRoom = conversation.title

      let xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <event version="2.0" uid="\(uid)" type="\(chatType)" time="\(timeStr)" start="\(startStr)" stale="\(staleStr)" how="h-g-i-g-o">
          <point lat="0.0" lon="0.0" hae="0.0" ce="9999999" le="9999999"/>
          <detail>
              <__chat id="\(conversation.id)" chatroom="\(chatRoom)" senderCallsign="\(message.senderCallsign)">
                  <chatgrp uid0="\(message.senderId)" uid1="\(conversation.id)" id="\(conversation.id)"/>
              </__chat>
              <link uid="\(message.senderId)" type="a-f-G" relation="p-p"/>
              <remarks source="\(message.senderId)" time="\(startStr)">\(escapeXML(message.messageText))</remarks>
              <__serverdestination destinations="\(conversation.id)"/>
          </detail>
      </event>
      """
      return xml
  }
  ```

  - **Important:** This is a *pure transformation* from strongly typed `ChatMessage`/`Conversation` → XML string; any XML quirks (escaping, attribute names) are isolated here.
  - `escapeXML` ensures message text does not break XML.

#### PLI, Waypoints, etc.

Similar generators exist:

- `GeofenceCoTGenerator.swift`
- `MarkerCoTGenerator.swift`
- `TeamCoTGenerator.swift`

These transform models like `Waypoint`, `Team`, `Geofence` into specific CoT event types.

### 3. Domain Models ↔ Persistence Models

In this codebase, **domain models are directly made `Codable`**, so there is no separate persistence DTO layer. The main transformations are:

- **Encoding strategies**:
  - `JSONEncoder` with `dateEncodingStrategy = .iso8601`.
- **Storage formats**:
  - JSON files in app documents directory.
  - `UserDefaults` for simple key/value and small arrays.

Examples:

- **ChatPersistence** (`ChatPersistence.swift`):

  ```swift
  func saveConversations(_ conversations: [Conversation]) {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(conversations)
      try data.write(to: conversationsURL)
  }

  func loadConversations() -> [Conversation] {
      let data = try Data(contentsOf: conversationsURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return try decoder.decode([Conversation].self, from: data)
  }
  ```

- **ChatStorageManager**:

  ```swift
  func loadQueuedMessages() -> [QueuedMessage] {
      guard let data = defaults.data(forKey: queuedMessagesKey) else { return [] }
      return (try? decoder.decode([QueuedMessage].self, from: data)) ?? []
  }

  func saveQueuedMessages(_ messages: [QueuedMessage]) {
      if let data = try? encoder.encode(messages) {
          defaults.set(data, forKey: queuedMessagesKey)
      }
  }
  ```

Other Storage modules (`RouteStorageManager`, `TeamStorageManager`, `DrawingPersistence`) follow similar patterns: encode domain models directly to JSON.

### 4. Domain Models ↔ View State

- **Managers as ViewModels** (`Managers/*.swift`):
  - `ObservableObject` + `@Published` state.
  - Models (e.g. `[Conversation]`, `[Waypoint]`) are exposed directly to SwiftUI views.
- **Views** (`Views/*`):
  - Use `@ObservedObject` / `@EnvironmentObject` to bind to managers.
  - They don’t transform data beyond basic filtering/sorting for display.

Example from architecture doc:

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

Transformation is minimal: UI components read `Conversation` items as-is.

---

## Storage Interactions

Storage is implemented via a small set of concrete persistence classes under `OmniTAKMobile/Storage` and some uses of `UserDefaults` in managers.

### 1. File-Based JSON Storage

**ChatPersistence** (`ChatPersistence.swift`):

- **Scope:** Chat history and participants.
- **Files:**
  - `conversations.json`
  - `messages.json`
  - `participants.json`
- **Location:** App’s Documents directory:

  ```swift
  private func getDocumentsDirectory() -> URL {
      FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }
  ```

- **Encoding/decoding:**
  - Uses `JSONEncoder`/`JSONDecoder` with ISO‑8601 date strategies.
  - Writes atomically to disk; errors are printed to console.

- **Migration:**
  - `migrateFromUserDefaults()` reads any legacy JSON from `UserDefaults` keys (`chat_conversations`, etc.), decodes, writes to files, then clears the old keys.

**DrawingPersistence**, `RouteStorageManager`, `TeamStorageManager`:

- Similar pattern: JSON in Documents:
  - `RouteStorageManager` handles `Track`/`Route` objects.
  - `TeamStorageManager` handles `Team` and membership lists.
  - Errors are logged but not thrown to UI; managers must handle potential empty results.

### 2. UserDefaults-Based Storage

- **ChatStorageManager** (`ChatStorageManager.swift`):
  - Stores queued outbound messages under key `com.omnitak.chat.queue`.
  - Lifecycle:
    - On app launch or ChatManager initialization: `queuedMessages = storage.loadQueuedMessages()`.
    - On modification: `storage.saveQueuedMessages(queuedMessages)`.

- **ServerManager** (`Managers/ServerManager.swift`, from docs):  

  ```swift
  private func saveServers() {
      if let encoded = try? JSONEncoder().encode(servers) {
          UserDefaults.standard.set(encoded, forKey: "tak_servers")
      }
  }
  ```

  - On start: attempts to load/deserialize the same key.
  - Used to persist user’s configured TAK endpoints.

- Similar patterns likely used in other managers for simple preferences (e.g., broadcast interval, map settings).

### 3. Keychain / Secure Storage

- **CertificateManager** (docs/API/Managers.md):
  - Methods:
    - `importCertificate(from:password:)` – parse .p12.
    - `saveCertificate(_:data:password:)` – writes to iOS Keychain.
    - `getCertificateData(for:)` – reads from Keychain when establishing TLS connections.
  - Data is not directly serialised with `Codable`; instead, uses Security APIs.

### 4. External/Remote Storage

- **TAK Server**: Actual authoritative state lives on TAK servers. The app’s local storage is mostly:
  - Cache (chat history, contacts, tracks).
  - Last-known configuration (servers, certs, UI settings).

- **ArcGIS / Offline Maps**:
  - Offline map downloads are managed by `OfflineMapManager` + `OfflineTileCache` and persisted as local tile packages; details reside in those service/storage classes.

---

## Validation Mechanisms

Validation is distributed across several layers: model construction, parsing, and managers.

### 1. Parsing-Level Validation

**CoTMessageParser**:

- **Structural validation:**  
  For each parser, required attributes must be present; otherwise returns `nil`.

  ```swift
  guard let uid = extractAttribute("uid", from: xml),
        let typeStr = extractAttribute("type", from: xml),
        let point = extractPoint(from: xml) else {
      return nil
  }
  ```

- **Event type validation:**  
  Events with unsupported `type` get mapped to `.unknown(eventType)`; some known, unhandled types are logged and ignored (`t-x-takp-v`, `t-x-d-d`).

- **Chat parsing:**  
  If `ChatXMLParser` fails to parse GeoChat, `parseChatMessage` returns `nil`, which drops the message before it reaches chat flows.

**EmergencyAlert** parsing:

- Validates that `<emergency>` tag exists and tries to extract a valid `type`; falls back to `.custom` if unknown.

### 2. Model Construction Validation

**Managers** enforce logical rules before creating models:

- `ChatManager.sendMessage`:
  - Validates conversation existence (`guard let conversation = getConversation...`).
  - Sets proper `senderUID`/`recipientUID` from current state.
  - Ensures duplicate message IDs don’t exist when processing inbound messages:

    ```swift
    guard !messages.contains(where: { $0.id == message.id }) else { return }
    ```

- `ServerManager.addServer` (from docs):
  - Typically ensures nonempty host/port range.
  - May deduplicate servers by host/port.

### 3. Service-Level Validation

Examples inferred from docs:

- **ChatService**:
  - When sending, ensures `takService.isConnected` or enqueues into `queuedMessages`.
  - `processQueue()` updates `QueuedMessageStatus` and increments `retryCount`.
  - Likely stops retry after N attempts and marks as `.failed`.

- **PositionBroadcastService**:
  - Checks if location permissions are granted and `isEnabled` before broadcasting.
  - Validates update interval and stale time.

- **CertificateEnrollmentService**:
  - Validates certificate formats, CN, expiration.

### 4. UI-Level Validation

- Many views validate user input before invoking managers (as documented in feature docs):
  - E.g., `ServerPickerView`, `NetworkPreferencesView`, `CASRequestView`, `MEDEVACRequestView` ensure required fields are filled.
  - `ChatView` / `ConversationView` may disable send button on empty text.

Error handling strategy:

- **Parsing & Storage**: log errors with `print("Failed to ...: \(error)")`, then fallback to defaults (empty arrays).
- **Managers**: Fail fast with `guard` and early returns; UI often shows a passive failure (no crash, operation just doesn’t occur).
- **Network**: `TAKService` exposes human-readable `connectionStatus` and counters (`messagesSent`, etc.) for diagnosing issues.

---

## State Management Analysis

State is primarily managed with **Combine** + `ObservableObject` managers, which act as feature-level view models.

### 1. Managers as ViewModels

From `docs/API/Managers.md` and architecture:

- Each manager:
  - `class XManager: ObservableObject`
  - `@Published` properties for UI-bound state.
  - Singleton via `static let shared` or injected into views.

Examples:

- **ChatManager**:
  - `@Published var messages: [ChatMessage]`
  - `@Published var conversations: [Conversation]`
  - `@Published var participants: [ChatParticipant]`
  - `@Published var unreadCount: Int`
  - Also holds dependencies: `takService`, `locationManager`, `storage`.

- **ServerManager**:
  - `@Published var servers: [TAKServer]`
  - `@Published var selectedServer: TAKServer?`
  - `@Published var activeServerIndex: Int`

- **PositionBroadcastService / TrackRecordingService / TeamService / GeofenceService**:
  - Cohesive state specific to their domain (`isEnabled`, `isRecording`, `savedTracks`, `teams`, etc.).

### 2. Lifecycle of State

- **Initialization**:
  - Managers often have `configure(...)` methods called from app bootstrap (`OmniTAKMobileApp.swift`) to wire dependencies:
    - Example from docs:

      ```swift
      func configure(takService: TAKService, chatManager: ChatManager) {
          self.takService = takService
          self.chatManager = chatManager
      }
      ```

  - Managers that persist data load on startup:
    - `ChatManager.configure` calls `loadMessages()` which uses `ChatPersistence`.
    - `ServerManager` loads servers from `UserDefaults`.

- **Mutation**:
  - Methods on managers mutate `@Published` arrays or properties.
  - Many mutations trigger side effects:
    - Save to persistence (`ChatPersistence`, `RouteStorageManager`).
    - Send CoT via services.
    - Update derived properties (e.g., `unreadCount`).

- **Observation**:
  - Views bind to these managers with `@ObservedObject` or `@EnvironmentObject`.
  - Combine automatically updates views when `@Published` changes.

### 3. Shared vs Local State

- **Global/Shared singletons**:
  - `TAKService.shared`, `ChatService.shared`, `PositionBroadcastService.shared`, etc.
  - `ChatManager.shared`, `ServerManager.shared`, etc.

  Used where there is a clear single source of truth across the app.

- **Injected instances**:
  - Some views accept non-singleton `ObservableObject` references for testing or modularity.
  - Feature docs emphasize dependency injection patterns.

### 4. Caching

- **Short-term in-memory cache**:
  - `messages`, `conversations`, `participants`, `tracks`, etc. all live in managers as in-memory caches.
  - Underlying services may maintain their own ephemeral cache (e.g. `OfflineTileCache` for map tiles).

- **Long-term offline cache**:
  - Persisted via JSON files and `UserDefaults` as described above.
  - On startup, this state is loaded and rehydrated into managers.

---

## Serialization Processes

Serialization/deserialization is central to three concerns:

1. **Network protocol (CoT XML).**
2. **Local persistence (JSON).**
3. **System integration (Keychain, iOS frameworks).**

### 1. XML (CoT / GeoChat)

**Outbound:**

- Generators in `OmniTAKMobile/CoT/Generators`:
  - `ChatCoTGenerator` for GeoChat.
  - `GeofenceCoTGenerator`, `MarkerCoTGenerator`, `TeamCoTGenerator` for other message types.
- XML is built manually as `String` with interpolation.
- Time formatting uses `ISO8601DateFormatter` with `.withInternetDateTime` and `.withFractionalSeconds`.
- Example from `ChatCoTGenerator` (see above).

**Inbound:**

- `CoTMessageParser`:
  - Uses custom `extractAttribute`, regex matches, and simple parsing to avoid full DOM building for performance & simplicity.
- `ChatXMLParser` (GeoChat):
  - Uses `XMLParser` delegate pattern (`GeoChatXMLParser` inside `ChatCoTGenerator.swift` provides a second, simplified implementation).
  - Reads attributes and inner text to construct `ChatMessage`.

**Key aspects:**

- Transformation boundaries are explicit:
  - XML enters/exits *only* inside CoT generators/parsers and `TAKService`.
  - Rest of the app sees typed models.

### 2. JSON (Persistence)

- **Serialization**:
  - `JSONEncoder` with ISO‑8601 dates.
  - Serializes directly from domain structs (no DTO layer).
- **Deserialization**:
  - `JSONDecoder` with matching date strategy.
  - Defensive coding: `try?` or `do/catch` + fallback to empty arrays.

- These processes are used in:
  - `ChatPersistence`
  - `RouteStorageManager`
  - `TeamStorageManager`
  - Possibly other storage classes.

### 3. UserDefaults

- Uses `JSONEncoder`/`JSONDecoder` to store structured arrays in a single key (e.g., servers, queued messages).
- **No custom date strategy** set explicitly in `ChatStorageManager`, but uses the default `JSONEncoder`/`JSONDecoder`; ensure date fields in `QueuedMessage` are safe.

### 4. Keychain / Certificates

- `CertificateManager` doesn’t use `Codable`; integrates directly with Security.framework to import/export `.p12` data.

---

## Data Lifecycle Diagrams

Below are text diagrams describing the primary data lifecycles.

### 1. Incoming CoT Position Message → Map Marker

```text
TAK Server
  |
  v  (CoT XML: <event type="a-f-G-U-C" ...>)
[TAKService]
  - Receives raw XML from omnitak_mobile framework
  - Forwards to CoTMessageParser.parse(xml:)
  |
  v
[CoTMessageParser]
  - Extracts "type" attribute -> "a-f-G-U-C"
  - parsePositionUpdate(xml:) -> CoTEvent
  |
  v
[CoTEventHandler / Map-related Managers]
  - Update or create EnhancedCoTMarker for this UID
  - Append coordinate/time to trail arrays
  |
  v
[MapStateManager / EnhancedMapViewController]
  - Maintains collection of markers
  - Notifies SwiftUI views via ObservableObject / delegate
  |
  v
SwiftUI Map Views (IntegratedMapView, MarkerAnnotationView)
  - Render markers, trails, and overlays based on EnhancedCoTMarker state
```

**Data shapes across this flow:**

- `String` (XML) → `CoTEvent` → `EnhancedCoTMarker` → view state.

### 2. Outgoing Chat Message (Online)

```text
User types message in ConversationView
  |
  v
[ChatView / ConversationView]
  - Calls ChatManager.sendMessage(text:to:)
  |
  v
[ChatManager]
  - Validates conversationId
  - Constructs ChatMessage (status = .pending)
  - Appends to local messages, updates Conversation
  - Asks ChatCoTGenerator to generate XML
  |
  v
[ChatCoTGenerator]
  - Converts ChatMessage + Conversation to GeoChat CoT XML String
  |
  v
[ChatManager]
  - takService?.send(cotMessage: xml, priority: .high)
  - updateMessageStatus(message.id, status: .sent)
  |
  v
[TAKService]
  - Passes XML to underlying networking layer
  |
  v
TAK Server and remote TAK clients
```

**Persistence side-channel:**

- After message list changes, `ChatManager` may call `ChatPersistence.saveMessages(messages)` to persist new state.

### 3. Outgoing Chat Message (Offline Queue)

```text
User sends message while TAKService.isConnected == false
  |
  v
[ChatManager]
  - Create ChatMessage (status = .pending)
  - Generate GeoChat XML via ChatCoTGenerator
  - Wrap into QueuedMessage { id, message, xmlPayload, retryCount=0, createdAt, status=.pending }
  - Append QueuedMessage to queuedMessages
  - ChatStorageManager.saveQueuedMessages(queuedMessages)
  |
  v
Later: ChatService.processQueue()
  - For each QueuedMessage with status .pending or .failed and retryCount < limit:
      - Set status = .sending
      - Attempt takService.send(cotMessage:)
      - On success: status = .completed; update underlying ChatMessage.status = .sent
      - On failure: increment retryCount; status = .failed or schedule retry
  - ChatStorageManager.saveQueuedMessages(updatedArray)
```

**Data shapes:**

- `ChatMessage` + XML `String` → `QueuedMessage` (`Codable`) → persisted to `UserDefaults` as JSON blob → rehydrated and retried.

### 4. Chat History Load on App Start

```text
App Launch
  |
  v
OmniTAKMobileApp.swift
  - Instantiate ChatManager.shared, TAKService, etc.
  - chatManager.configure(takService:..., locationManager:...)
  |
  v
[ChatManager.configure]
  - messages = ChatPersistence.loadMessages()
  - conversations = ChatPersistence.loadConversations()
  - participants = ChatPersistence.loadParticipants()
  - queuedMessages = ChatStorageManager.loadQueuedMessages()
  - subscribeToIncomingMessages() on TAKService / CoTEventHandler
  |
  v
SwiftUI Chat Views
  - Bind to ChatManager.@Published properties
  - Immediately show persisted history
```

### 5. Position Broadcast Lifecycle

```text
User enables PLI broadcasting in PositionBroadcastView
  |
  v
[PositionBroadcastService]
  - isEnabled = true
  - configure(takService, locationManager)
  - startBroadcasting()
  |
  v
Timer / background loop triggers broadcast
  - Obtain current CLLocation from locationManager
  - Build CoTEvent-like data (UID, type, time, coordinate, team, role)
  - Generate CoT XML (via dedicated generator or inline)
  |
  v
[TAKService.send(cotMessage:)]
  - Send PLI message
  - Update messagesSent, bytesSent, broadcastCount
  |
  v
Remote clients see updated marker for user's UID
```

---

This analysis is based strictly on the existing files and documentation under `apps/omnitak/OmniTAKMobile` and `apps/omnitak/docs`. It maps how data structures are defined, transformed between layers, and persisted on disk or transmitted over the network.