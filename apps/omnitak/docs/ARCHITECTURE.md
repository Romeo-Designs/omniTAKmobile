# Architecture Guide

**OmniTAK Mobile Architecture Documentation**

This document provides a comprehensive overview of the OmniTAK Mobile application architecture, design patterns, component organization, and technical implementation details.

---

## Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Architectural Patterns](#architectural-patterns)
3. [Layer Structure](#layer-structure)
4. [Component Organization](#component-organization)
5. [Data Flow Architecture](#data-flow-architecture)
6. [State Management](#state-management)
7. [Networking Architecture](#networking-architecture)
8. [CoT Message Processing](#cot-message-processing)
9. [Map System Architecture](#map-system-architecture)
10. [Storage & Persistence](#storage--persistence)
11. [Threading & Concurrency](#threading--concurrency)
12. [Memory Management](#memory-management)

---

## High-Level Architecture

OmniTAK Mobile follows a **layered MVVM (Model-View-ViewModel)** architecture with reactive state management using Apple's Combine framework.

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│         SwiftUI Views & UIKit Components (60+ files)        │
│           Declarative UI with reactive bindings             │
└───────────────────────┬─────────────────────────────────────┘
                        │ @StateObject, @ObservedObject
                        │ Environment injection
┌───────────────────────▼─────────────────────────────────────┐
│                    VIEW MODEL LAYER                          │
│              Managers (11 ObservableObjects)                 │
│     ChatManager, ServerManager, CertificateManager...       │
│            Orchestrate business logic & state                │
└───────────────────────┬─────────────────────────────────────┘
                        │ Service method calls
                        │ Publisher subscriptions
┌───────────────────────▼─────────────────────────────────────┐
│                   BUSINESS LOGIC LAYER                       │
│                  Services (27 classes)                       │
│   TAKService, PositionBroadcastService, ChatService...      │
│          Core functionality & integrations                   │
└───────────────────────┬─────────────────────────────────────┘
                        │ Model operations
                        │ Network calls, Storage access
┌───────────────────────▼─────────────────────────────────────┐
│                   FOUNDATION LAYER                           │
│    Models (23 files) • Storage • CoT Parsing • Utilities    │
│         Domain models, persistence, network I/O              │
└─────────────────────────────────────────────────────────────┘
```

### Key Architectural Principles

1. **Separation of Concerns** - Each layer has distinct responsibilities
2. **Unidirectional Data Flow** - Data flows down, events flow up
3. **Reactive State Management** - Combine publishers propagate state changes
4. **Dependency Injection** - Components receive dependencies rather than creating them
5. **Protocol-Oriented Design** - Protocols define contracts for testability
6. **Composition Over Inheritance** - Favor struct composition and protocol conformance

---

## Architectural Patterns

### MVVM (Model-View-ViewModel)

**Implementation:**

```swift
// MODEL - Domain entity
struct ChatMessage: Codable, Identifiable {
    let id: String
    let senderId: String
    var messageText: String
    let timestamp: Date
}

// VIEW MODEL - State management + business logic coordination
class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var conversations: [Conversation] = []

    private let chatService: ChatService
    private let takService: TAKService

    func sendMessage(text: String, to conversationId: String) {
        // Coordinate with services
        chatService.sendGeoChat(text: text, conversationId: conversationId)
    }
}

// VIEW - SwiftUI declarative UI
struct ChatView: View {
    @StateObject private var chatManager = ChatManager.shared

    var body: some View {
        List(chatManager.messages) { message in
            MessageRow(message: message)
        }
    }
}
```

**Benefits:**

- Clear separation between UI and business logic
- Testable view models without UI dependencies
- Reactive UI updates via Combine
- Reusable view models across different views

### Singleton Pattern

**Usage:** Shared managers and services that need application-wide state

```swift
class ChatManager: ObservableObject {
    static let shared = ChatManager()
    private init() { }  // Prevent external instantiation
}

// Usage in views
@StateObject private var chatManager = ChatManager.shared
```

**Singletons in OmniTAK:**

- `ChatManager.shared`
- `ServerManager.shared`
- `CertificateManager.shared`
- `OfflineMapManager.shared`
- `PositionBroadcastService.shared`
- `EmergencyBeaconService.shared`
- `CoTEventHandler.shared`

**Rationale:** These components manage global application state (current server connection, chat history, certificates) that must be consistent across all views.

### Observer Pattern (via Combine)

**Implementation:**

```swift
// Service publishes events
class PositionBroadcastService {
    let positionUpdatePublisher = PassthroughSubject<CoTEvent, Never>()

    func broadcastPosition() {
        let event = createPositionCoT()
        positionUpdatePublisher.send(event)
    }
}

// Manager subscribes
class MapStateManager: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    func observePositionUpdates() {
        PositionBroadcastService.shared.positionUpdatePublisher
            .sink { [weak self] event in
                self?.updateUserMarker(event)
            }
            .store(in: &cancellables)
    }
}
```

### Coordinator Pattern (Map Controllers)

The map system uses a coordinator to manage complex interactions between map views, overlays, and markers.

```swift
class MapOverlayCoordinator {
    private weak var mapView: MKMapView?

    func addMarker(_ marker: EnhancedCoTMarker) { }
    func updateMarker(_ marker: EnhancedCoTMarker) { }
    func removeMarker(uid: String) { }
    func addOverlay(_ overlay: MKOverlay) { }
}
```

---

## Layer Structure

### Presentation Layer

**Location:** `OmniTAKMobile/Views/`, `OmniTAKMobile/UI/`

**Components:**

- **60+ SwiftUI Views** - Screens and components
- **UIKit Controllers** - Map view controllers and legacy components
- **UI Components** - Reusable widgets (MilStd2525, RadialMenu)

**Responsibilities:**

- Render UI based on view model state
- Capture user interactions
- Display loading states and errors
- Navigate between screens

**Example Structure:**

```
Views/
├── Map/
│   ├── ATAKMapView.swift              # Main map interface
│   ├── MapToolbarView.swift           # Map controls
│   └── CoordinateDisplayView.swift    # MGRS/Lat-Lon display
├── Chat/
│   ├── ChatView.swift                 # Chat list
│   ├── ConversationView.swift         # Message thread
│   └── MessageComposerView.swift      # Input field
├── Settings/
│   ├── SettingsView.swift
│   ├── NetworkPreferencesView.swift
│   └── CertificateManagementView.swift
└── Reports/
    ├── SPOTREPView.swift
    ├── MEDEVACRequestView.swift
    └── CASRequestView.swift
```

### View Model Layer

**Location:** `OmniTAKMobile/Managers/`

**11 Manager Classes:**

| Manager                 | Responsibilities                                  | Lines of Code |
| ----------------------- | ------------------------------------------------- | ------------- |
| **ChatManager**         | Message state, conversations, delivery tracking   | 891           |
| **ServerManager**       | TAK server configuration, active server selection | 154           |
| **CertificateManager**  | Certificate storage, keychain management          | 436           |
| **OfflineMapManager**   | Map region downloads, tile caching                | 371           |
| **DrawingToolsManager** | Drawing state (marker, line, circle, polygon)     | 264           |
| **GeofenceManager**     | Geofence storage and state updates                | ~200          |
| **WaypointManager**     | Waypoint management                               | ~150          |
| **MeshtasticManager**   | Mesh network device connection and state          | 613           |
| **MeasurementManager**  | Measurement tool state                            | ~100          |
| **DataPackageManager**  | Data package import/export                        | ~200          |
| **CoTFilterManager**    | CoT message filtering criteria                    | ~100          |

**Common Pattern:**

```swift
class FeatureManager: ObservableObject {
    // MARK: - Published State
    @Published var items: [Item] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    // MARK: - Dependencies
    private let service: FeatureService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    static let shared = FeatureManager()
    private init() {
        service = FeatureService()
        setupObservers()
    }

    // MARK: - Public Methods
    func performAction() {
        service.doSomething()
            .sink(
                receiveCompletion: { [weak self] completion in
                    // Handle completion
                },
                receiveValue: { [weak self] result in
                    self?.items = result
                }
            )
            .store(in: &cancellables)
    }
}
```

### Business Logic Layer

**Location:** `OmniTAKMobile/Services/`

**27 Service Classes:**

**Core Services:**

- **TAKService** (1105 lines) - Core network connectivity, CoT send/receive
- **PositionBroadcastService** (398 lines) - Automatic PLI broadcasting
- **EmergencyBeaconService** (417 lines) - Emergency alert system
- **ChatService** - GeoChat XML generation and handling
- **CertificateEnrollmentService** - QR code-based certificate enrollment

**Navigation Services:**

- **RoutePlanningService** - Route creation and optimization
- **NavigationService** - Turn-by-turn navigation
- **TurnByTurnNavigationService** - Voice guidance
- **WaypointNavigationService** - Waypoint sequencing

**Map Services:**

- **ElevationProfileService** - Elevation calculations
- **LineOfSightService** - LOS analysis
- **TerrainVisualizationService** - 3D terrain
- **TrackRecordingService** - Breadcrumb trails
- **GeofenceService** - Boundary monitoring
- **MeasurementService** - Distance/bearing calculations
- **RangeBearingService** - Range ring calculations

**Integration Services:**

- **MissionPackageSyncService** - Mission data sync
- **ArcGISFeatureService** - ArcGIS integration
- **ArcGISPortalService** - ArcGIS portal access
- **VideoStreamService** - Video feed integration
- **BloodhoundService** - Asset tracking
- **PhotoAttachmentService** - Image handling

**Utility Services:**

- **TeamService** - Team management
- **EchelonService** - Military unit echelons
- **PointDropperService** - Point placement
- **NetworkStatusService** - Connectivity monitoring

**Responsibilities:**

- Implement core business logic
- Interact with external APIs and services
- Perform complex calculations
- Manage background operations
- Publish events via Combine

### Foundation Layer

**Location:** `OmniTAKMobile/Models/`, `OmniTAKMobile/Storage/`, `OmniTAKMobile/CoT/`, `OmniTAKMobile/Utilities/`

**Components:**

**Models (23 files):**

```
ChatModels.swift           (259 lines)
PointMarkerModels.swift    (377 lines)
RouteModels.swift          (508 lines)
TeamModels.swift           (379 lines)
CoTFilterModel.swift
DrawingModels.swift
GeofenceModels.swift
MeshtasticModels.swift
OfflineMapModels.swift
MEDEVACModels.swift
CASRequestModels.swift
EchelonModels.swift
ArcGISModels.swift
... and 10 more
```

**CoT Processing:**

```
CoT/
├── CoTMessageParser.swift      (396 lines) - Parse XML to models
├── CoTEventHandler.swift       (333 lines) - Route events to handlers
├── CoTFilterCriteria.swift     - Filter configuration
├── Generators/                 - CoT XML generation
│   ├── ChatCoTGenerator.swift
│   ├── GeofenceCoTGenerator.swift
│   ├── MarkerCoTGenerator.swift
│   └── TeamCoTGenerator.swift
└── Parsers/                    - Specialized parsing
    ├── ChatXMLParser.swift
    └── ChatXMLGenerator.swift
```

**Storage (5 managers):**

```
Storage/
├── ChatPersistence.swift
├── ChatStorageManager.swift
├── DrawingPersistence.swift
├── RouteStorageManager.swift
└── TeamStorageManager.swift
```

**Utilities:**

```
Utilities/
├── Calculators/        - Distance, bearing, MGRS conversion
├── Converters/         - Coordinate format converters
├── Integration/        - KML/KMZ integration
├── Network/            - Network utilities
└── Parsers/            - Various parsers
```

---

## Data Flow Architecture

### Inbound Data Flow (Receiving CoT)

```
TAK Server
    │
    │ TCP/TLS Socket
    ▼
DirectTCPSender (NWConnection)
    │
    │ Raw bytes
    ▼
TAKService.receiveLoop()
    │
    │ Buffer accumulation
    │ XML extraction
    ▼
CoTMessageParser.parse(xmlString)
    │
    │ XML → CoTEvent model
    ▼
CoTEventHandler.handleEvent(event)
    │
    ├──► handlePosition() ──► Update map markers
    ├──► handleChat() ──────► ChatManager.addMessage()
    ├──► handleEmergency() ─► Show alert
    └──► handleTeam() ──────► TeamService.updateMember()
    │
    ▼
@Published properties updated
    │
    ▼
SwiftUI Views auto-refresh
```

**Code Example:**

```swift
// TAKService.swift
func receiveLoop() {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
        guard let data = data else { return }

        // Accumulate buffer
        self.receiveBuffer.append(data)

        // Extract complete XML messages
        while let xmlString = self.extractXMLMessage() {
            DispatchQueue.main.async {
                // Parse CoT
                if let event = CoTMessageParser.parse(xmlString) {
                    // Route to handler
                    CoTEventHandler.shared.handleEvent(event)
                }
            }
        }

        // Continue receiving
        self.receiveLoop()
    }
}
```

### Outbound Data Flow (Sending CoT)

```
User Action (e.g., send chat message)
    │
    ▼
View captures input
    │
    ▼
Manager.sendMessage(text)
    │
    ▼
Service.generateGeoChat(text)
    │
    │ Create CoT XML
    ▼
ChatCoTGenerator.generate(message)
    │
    │ XML string
    ▼
TAKService.sendCoT(xmlString)
    │
    ▼
DirectTCPSender.send(data)
    │
    │ Network transmission
    ▼
TAK Server
```

**Code Example:**

```swift
// ChatManager.swift
func sendMessage(text: String, to conversationId: String) {
    let message = ChatMessage(
        id: UUID().uuidString,
        conversationId: conversationId,
        senderId: userUID,
        messageText: text,
        timestamp: Date(),
        status: .sending
    )

    messages.append(message)

    // Generate CoT XML
    let xml = ChatCoTGenerator.generate(message)

    // Send via TAK service
    TAKService.shared.sendCoT(xml)

    // Update status
    updateMessageStatus(message.id, status: .sent)
}
```

### Reactive State Propagation

```
Service updates @Published property
    │
    ▼
Combine publishes change event
    │
    ▼
Subscribed views receive update
    │
    ▼
SwiftUI automatically re-renders
```

**Example:**

```swift
// Service
class TAKService: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected

    func connect() {
        connectionStatus = .connecting
        // ... establish connection
        connectionStatus = .connected
    }
}

// View automatically updates when status changes
struct StatusBar: View {
    @ObservedObject var takService: TAKService

    var body: some View {
        Text(takService.connectionStatus.description)
            .foregroundColor(takService.connectionStatus.color)
    }
}
```

---

## State Management

### Combine Framework Usage

**Publisher Types:**

1. **@Published** - Automatic property observation

   ```swift
   @Published var messages: [ChatMessage] = []
   // Automatically creates publisher: $messages
   ```

2. **PassthroughSubject** - Manual event emission

   ```swift
   let eventPublisher = PassthroughSubject<CoTEvent, Never>()
   eventPublisher.send(event)  // Emit event
   ```

3. **CurrentValueSubject** - State + emission
   ```swift
   let statusSubject = CurrentValueSubject<Bool, Never>(false)
   statusSubject.send(true)  // Update and emit
   let current = statusSubject.value  // Access current value
   ```

**Subscription Patterns:**

```swift
// Sink - Subscribe to values and completion
service.dataPublisher
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Error: \(error)")
            }
        },
        receiveValue: { [weak self] value in
            self?.handleValue(value)
        }
    )
    .store(in: &cancellables)

// Assign - Directly assign to property
service.dataPublisher
    .assign(to: \.items, on: self)
    .store(in: &cancellables)

// Chain operators
service.dataPublisher
    .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
    .removeDuplicates()
    .map { $0.uppercased() }
    .sink { [weak self] value in
        self?.processValue(value)
    }
    .store(in: &cancellables)
```

### State Ownership

**Single Source of Truth:**

- Each piece of state is owned by exactly one manager
- Views observe state, never mutate directly
- Changes flow through manager methods

```swift
// ✅ CORRECT
chatManager.sendMessage(text: "Hello")

// ❌ INCORRECT
chatManager.messages.append(newMessage)  // Direct mutation
```

**State Hierarchy:**

```
Application State (App-wide)
    ├─ ServerManager.activeServer
    ├─ CertificateManager.certificates
    └─ ChatManager.conversations
        │
        └─ Feature State (Feature-specific)
            ├─ DrawingToolsManager.drawings
            ├─ GeofenceManager.geofences
            └─ OfflineMapManager.regions
                │
                └─ View State (View-local)
                    └─ @State var showingSheet = false
```

---

## Networking Architecture

### TCP/UDP/TLS Implementation

**Network Stack:**

```
TAKService (high-level interface)
    │
    ▼
DirectTCPSender (NWConnection wrapper)
    │
    ▼
NWConnection (Apple's Network framework)
    │
    ▼
BSD Sockets (kernel-level)
```

**Connection Establishment:**

```swift
// TAKService.swift
func connect(host: String, port: UInt16, useTLS: Bool) {
    let endpoint = NWEndpoint.hostPort(
        host: NWEndpoint.Host(host),
        port: NWEndpoint.Port(rawValue: port)!
    )

    let parameters: NWParameters
    if useTLS {
        parameters = configureTLSParameters()
    } else {
        parameters = .tcp
    }

    let connection = NWConnection(to: endpoint, using: parameters)

    connection.stateUpdateHandler = { [weak self] state in
        self?.handleConnectionState(state)
    }

    connection.start(queue: .global(qos: .userInitiated))
}
```

**TLS Configuration:**

```swift
func configureTLSParameters() -> NWParameters {
    let options = NWProtocolTLS.Options()

    // Set minimum TLS version
    if allowLegacyTLS {
        sec_protocol_options_set_min_tls_protocol_version(
            options.securityProtocolOptions,
            .TLSv10
        )
    } else {
        sec_protocol_options_set_min_tls_protocol_version(
            options.securityProtocolOptions,
            .TLSv12
        )
    }

    // Client certificate
    if let identity = loadCertificateIdentity() {
        sec_protocol_options_set_local_identity(
            options.securityProtocolOptions,
            identity
        )
    }

    // Server verification
    sec_protocol_options_set_verify_block(
        options.securityProtocolOptions,
        { _, _, verify_complete in
            // Accept self-signed certificates for TAK deployments
            verify_complete(true)
        },
        .global()
    )

    let parameters = NWParameters(tls: options, tcp: .init())
    return parameters
}
```

### Message Buffering & Framing

**Challenge:** TCP is a stream protocol - messages are not framed.

**Solution:** Buffer incoming data and extract complete XML documents.

```swift
private var receiveBuffer = Data()

func extractXMLMessage() -> String? {
    // Look for <?xml...?>...</event>
    guard let startRange = receiveBuffer.range(of: "<?xml".data(using: .utf8)!) else {
        return nil
    }

    guard let endRange = receiveBuffer.range(
        of: "</event>".data(using: .utf8)!,
        in: startRange.lowerBound..<receiveBuffer.endIndex
    ) else {
        return nil
    }

    let xmlData = receiveBuffer[startRange.lowerBound...endRange.upperBound]
    receiveBuffer.removeSubrange(startRange.lowerBound...endRange.upperBound)

    return String(data: xmlData, encoding: .utf8)
}
```

### Multi-Server Federation

**Architecture:**

- Each server has its own `DirectTCPSender` instance
- `TAKService` maintains array of active connections
- Outbound messages broadcast to all connected servers
- Inbound messages tagged with source server

```swift
class TAKService: ObservableObject {
    private var connections: [UUID: DirectTCPSender] = [:]
    @Published var activeServers: [TAKServer] = []

    func connectToServer(_ server: TAKServer) {
        let sender = DirectTCPSender()
        sender.connect(server.host, server.port, server.useTLS)
        connections[server.id] = sender
    }

    func broadcastCoT(_ xml: String) {
        for sender in connections.values {
            sender.send(xml)
        }
    }
}
```

---

## CoT Message Processing

### Parsing Pipeline

```
Raw XML String
    │
    ▼
CoTMessageParser.parse()
    │
    ├─ Extract <event> attributes (uid, type, time)
    ├─ Extract <point> element (lat, lon, hae)
    ├─ Extract <detail> children
    └─ Build CoTEvent model
    │
    ▼
CoTEvent (structured model)
    │
    ▼
CoTEventHandler.handleEvent()
    │
    ├─ Determine event type (position, chat, emergency)
    ├─ Apply filters (CoTFilterManager)
    └─ Route to appropriate handler
    │
    ▼
Feature-specific processing
```

### CoTMessageParser Implementation

```swift
// CoTMessageParser.swift (396 lines)
class CoTMessageParser {
    static func parse(_ xmlString: String) -> CoTEvent? {
        guard let xmlData = xmlString.data(using: .utf8) else {
            return nil
        }

        let parser = XMLParser(data: xmlData)
        let delegate = CoTParserDelegate()
        parser.delegate = delegate

        guard parser.parse() else {
            return nil
        }

        return delegate.cotEvent
    }
}

class CoTParserDelegate: NSObject, XMLParserDelegate {
    var cotEvent: CoTEvent?
    private var currentElement: String = ""
    private var eventAttributes: [String: String] = [:]
    private var detailDict: [String: Any] = [:]

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String]
    ) {
        currentElement = elementName

        switch elementName {
        case "event":
            eventAttributes = attributeDict
        case "point":
            parsePoint(attributeDict)
        case "contact":
            parseContact(attributeDict)
        case "__chat":
            parseChat(attributeDict)
        default:
            break
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        // Build CoTEvent from accumulated data
        cotEvent = CoTEvent(
            uid: eventAttributes["uid"] ?? "",
            type: eventAttributes["type"] ?? "",
            time: parseTime(eventAttributes["time"]),
            point: currentPoint,
            detail: CoTDetail(detailDict)
        )
    }
}
```

### Event Routing

```swift
// CoTEventHandler.swift (333 lines)
class CoTEventHandler {
    static let shared = CoTEventHandler()

    func handleEvent(_ event: CoTEvent) {
        // Apply filters
        guard CoTFilterManager.shared.shouldDisplay(event) else {
            return
        }

        // Route based on type
        let typePrefix = String(event.type.prefix(3))

        switch typePrefix {
        case "a-f", "a-h", "a-n", "a-u":
            // Position update
            handlePositionUpdate(event)

        case "b-t":
            // Chat message
            handleChatMessage(event)

        case "b-a":
            // Alert/Emergency
            handleEmergency(event)

        case "b-m-p-w":
            // Waypoint
            handleWaypoint(event)

        default:
            print("⚠️ Unknown CoT type: \(event.type)")
        }
    }

    private func handlePositionUpdate(_ event: CoTEvent) {
        DispatchQueue.main.async {
            // Update or create marker
            let marker = EnhancedCoTMarker(from: event)
            MapStateManager.shared.updateMarker(marker)

            // Update team member position
            TeamService.shared.updateMemberPosition(
                uid: event.uid,
                coordinate: event.point.coordinate
            )
        }
    }

    private func handleChatMessage(_ event: CoTEvent) {
        guard let chatDetail = event.detail.chatDetail else {
            return
        }

        DispatchQueue.main.async {
            let message = ChatMessage(from: chatDetail)
            ChatManager.shared.addReceivedMessage(message)
        }
    }
}
```

---

## Map System Architecture

### MapKit Integration

**Hybrid Architecture:**

- SwiftUI wrapper (`ATAKMapView`) for modern interface
- UIKit `MKMapView` for actual map rendering
- Custom overlays and annotations

```
ATAKMapView (SwiftUI)
    │
    ▼
UIViewRepresentable wrapper
    │
    ▼
EnhancedMapViewController (UIKit)
    │
    ├─► MKMapView
    │   ├─ MKTileOverlay (base map)
    │   ├─ Custom overlays (MGRS grid, range rings)
    │   └─ Annotations (markers)
    │
    ├─► MapOverlayCoordinator
    └─► MarkerManager
```

**Code Structure:**

```swift
// ATAKMapView.swift (SwiftUI)
struct ATAKMapView: View {
    @StateObject private var mapState = MapStateManager.shared

    var body: some View {
        ZStack {
            // Map canvas
            MapViewRepresentable(mapState: mapState)
                .ignoresSafeArea()

            // Overlays
            VStack {
                ATAKStatusBar()
                Spacer()
                ATAKBottomToolbar()
            }
        }
    }
}

// MapViewRepresentable.swift
struct MapViewRepresentable: UIViewControllerRepresentable {
    let mapState: MapStateManager

    func makeUIViewController(context: Context) -> EnhancedMapViewController {
        let controller = EnhancedMapViewController()
        controller.configure(with: mapState)
        return controller
    }

    func updateUIViewController(_ uiViewController: EnhancedMapViewController, context: Context) {
        // Update map based on state changes
    }
}
```

### Marker Rendering (MIL-STD-2525)

**Symbol Components:**

```
┌─────────────────────────┐
│   ┌─────────────┐       │  ← Echelon Indicator (•, I, II, III, X, XX)
│   │  Affiliation │       │  ← Affiliation Frame (Rectangle, Diamond, Square)
│   │     Shape    │       │  ← Unit Type Icon (Infantry, Armor, etc.)
│   │   + Icon     │       │  ← Modifiers (HQ, TF, Feint)
│   └─────────────┘       │
│      CALLSIGN           │  ← Text label
└─────────────────────────┘
```

**Rendering Pipeline:**

```swift
// MilStd2525MarkerView.swift (SwiftUI)
struct MilStd2525MarkerView: View {
    let marker: EnhancedCoTMarker

    var body: some View {
        ZStack {
            // Affiliation frame
            affiliationShape()
                .fill(affiliationColor())
                .frame(width: 40, height: 40)

            // Unit type icon
            Image(systemName: unitTypeIcon())
                .foregroundColor(.white)

            // Echelon indicator (top)
            echelonIndicator()
                .offset(y: -25)

            // Callsign label (bottom)
            Text(marker.callsign)
                .font(.caption)
                .offset(y: 30)
        }
    }

    private func affiliationShape() -> some Shape {
        switch marker.affiliation {
        case .friendly:  return RoundedRectangle(cornerRadius: 4)  // Rectangle
        case .hostile:   return Diamond()
        case .neutral:   return Rectangle()  // Square
        case .unknown:   return Quatrefoil()
        }
    }

    private func affiliationColor() -> Color {
        switch marker.affiliation {
        case .friendly: return .blue
        case .hostile:  return .red
        case .neutral:  return .green
        case .unknown:  return .yellow
        }
    }
}
```

### Tile Source Architecture

**Tile Provider Protocol:**

```swift
protocol TileProvider {
    func tileURL(x: Int, y: Int, zoom: Int) -> URL?
    var maximumZoom: Int { get }
    var minimumZoom: Int { get }
}

// ArcGIS Implementation
class ArcGISTileProvider: TileProvider {
    let serviceURL: String

    func tileURL(x: Int, y: Int, zoom: Int) -> URL? {
        URL(string: "\(serviceURL)/tile/\(zoom)/\(y)/\(x)")
    }
}

// OpenStreetMap Implementation
class OSMTileProvider: TileProvider {
    func tileURL(x: Int, y: Int, zoom: Int) -> URL? {
        URL(string: "https://tile.openstreetmap.org/\(zoom)/\(x)/\(y).png")
    }
}

// Offline Tile Provider
class OfflineTileProvider: TileProvider {
    func tileURL(x: Int, y: Int, zoom: Int) -> URL? {
        let path = documentsDirectory
            .appendingPathComponent("OfflineMaps")
            .appendingPathComponent("\(zoom)")
            .appendingPathComponent("\(x)")
            .appendingPathComponent("\(y).png")
        return path
    }
}
```

---

## Storage & Persistence

### Storage Strategy

| Data Type        | Storage Method | Location               | Reason                |
| ---------------- | -------------- | ---------------------- | --------------------- |
| **Settings**     | UserDefaults   | Standard defaults      | Lightweight, simple   |
| **Certificates** | Keychain       | Secure enclave         | Security requirement  |
| **Chat History** | JSON files     | Documents/             | Structured, queryable |
| **Drawings**     | JSON files     | Documents/             | Structured, queryable |
| **Routes**       | JSON files     | Documents/             | Structured, queryable |
| **Teams**        | JSON files     | Documents/             | Structured, queryable |
| **Map Tiles**    | File system    | Documents/OfflineMaps/ | Large binary data     |
| **Photos**       | File system    | Documents/Attachments/ | Large binary data     |

### Persistence Implementation

```swift
// ChatPersistence.swift
class ChatPersistence {
    private static let messagesFilename = "chat_messages.json"
    private static let conversationsFilename = "conversations.json"

    static func saveMessages(_ messages: [ChatMessage]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(messages) else {
            print("❌ Failed to encode messages")
            return
        }

        let url = documentsDirectory.appendingPathComponent(messagesFilename)

        do {
            try data.write(to: url, options: .atomic)
            print("✅ Saved \(messages.count) messages")
        } catch {
            print("❌ Failed to save messages: \(error)")
        }
    }

    static func loadMessages() -> [ChatMessage] {
        let url = documentsDirectory.appendingPathComponent(messagesFilename)

        guard let data = try? Data(contentsOf: url) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return (try? decoder.decode([ChatMessage].self, from: data)) ?? []
    }

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
```

### Keychain Integration

```swift
// CertificateManager.swift
class CertificateManager {
    func saveCertificate(_ certData: Data, withPassword password: String, name: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: name,
            kSecValueData as String: certData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func loadCertificate(name: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: name,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return data
    }
}
```

---

## Threading & Concurrency

### Main Thread Rules

**Always on Main Thread:**

- UI updates (SwiftUI, UIKit)
- `@Published` property updates
- `ObservableObject` state changes

```swift
// ✅ CORRECT
DispatchQueue.main.async {
    self.messages.append(newMessage)
}

// ❌ INCORRECT - will cause crash
DispatchQueue.global().async {
    self.messages.append(newMessage)  // Not on main thread!
}
```

### Background Operations

**Network I/O:**

```swift
// NWConnection automatically uses background queue
connection.start(queue: .global(qos: .userInitiated))
```

**File I/O:**

```swift
DispatchQueue.global(qos: .utility).async {
    let data = heavyFileOperation()

    DispatchQueue.main.async {
        self.updateUI(with: data)
    }
}
```

**Async/Await (iOS 15+):**

```swift
Task {
    // Background work
    let result = await fetchData()

    // Main actor for UI updates
    await MainActor.run {
        self.data = result
    }
}
```

---

## Memory Management

### ARC (Automatic Reference Counting)

**Retain Cycles Prevention:**

```swift
// ❌ STRONG REFERENCE CYCLE
class Manager {
    var closure: (() -> Void)?

    func setup() {
        closure = {
            self.doSomething()  // Strong reference to self
        }
    }
}

// ✅ WEAK SELF
class Manager {
    var closure: (() -> Void)?

    func setup() {
        closure = { [weak self] in
            self?.doSomething()  // Weak reference, breaks cycle
        }
    }
}
```

**Combine Subscriptions:**

```swift
class MyManager: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    func observe() {
        service.publisher
            .sink { [weak self] value in  // Prevent retain cycle
                self?.handle(value)
            }
            .store(in: &cancellables)  // Auto-cancels on deinit
    }
}
```

### Large Data Handling

**Map Tiles:**

- Tiles loaded on-demand
- LRU cache for recent tiles
- Automatic purging on memory warning

**CoT Messages:**

- Limit stored history (e.g., 1000 most recent)
- Paginated loading for chat history
- Automatic cleanup of old data

---

## Summary

OmniTAK Mobile's architecture demonstrates:

✅ **Clear separation of concerns** across presentation, view model, business logic, and foundation layers  
✅ **Reactive state management** with Combine framework  
✅ **Type-safe networking** with Apple's Network framework  
✅ **Comprehensive CoT protocol** parsing and generation  
✅ **Hybrid SwiftUI/UIKit** map system for performance  
✅ **Persistent storage** with appropriate technologies for each data type  
✅ **Thread-safe operations** with proper main thread discipline  
✅ **Memory-efficient** design with ARC and weak references

The architecture is designed to be:

- **Maintainable** - Clear responsibilities and separation
- **Testable** - Protocols and dependency injection
- **Scalable** - Easy to add new features
- **Performant** - Background operations and efficient rendering
- **Reliable** - Error handling and state recovery

---

**Next:** [Features Guide](FEATURES.md) | [API Reference](API_REFERENCE.md) | [Back to Index](README.md)
