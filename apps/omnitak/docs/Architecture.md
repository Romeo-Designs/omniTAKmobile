# Architecture Overview

## Table of Contents

- [Introduction](#introduction)
- [Design Principles](#design-principles)
- [Architectural Pattern](#architectural-pattern)
- [System Architecture](#system-architecture)
- [Component Relationships](#component-relationships)
- [Data Flow](#data-flow)
- [Threading Model](#threading-model)
- [Memory Management](#memory-management)

---

## Introduction

OmniTAK Mobile is built using a modern iOS architecture that emphasizes:

- **Reactive Programming** - Real-time updates via Combine framework
- **Separation of Concerns** - Clear boundaries between UI, business logic, and data
- **Testability** - Loosely coupled components with dependency injection
- **Scalability** - Modular feature organization for easy extension

The application follows Apple's recommended patterns for SwiftUI apps while implementing the complex CoT (Cursor on Target) protocol for tactical awareness.

---

## Design Principles

### 1. **Single Responsibility**

Each class has one primary responsibility:

- **Managers** - State management for specific features
- **Services** - Business logic and external integrations
- **Views** - UI presentation only
- **Models** - Data structures

### 2. **Dependency Injection**

Components receive dependencies through initializers or published properties:

```swift
// Example: CoTEventHandler receives dependencies
func configure(takService: TAKService, chatManager: ChatManager) {
    self.takService = takService
    self.chatManager = chatManager
}
```

### 3. **Reactive State Management**

All state changes propagate through Combine publishers:

```swift
class ChatManager: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var unreadCount: Int = 0
}
```

### 4. **Protocol-Oriented Design**

Interfaces defined through protocols for flexibility and testing:

```swift
protocol CoTMessageGenerator {
    func generateCoTMessage() -> String
}
```

---

## Architectural Pattern

### MVVM (Model-View-ViewModel)

OmniTAK Mobile implements **MVVM** with Combine for reactive bindings:

```
┌─────────────────────────────────────────────────────────────┐
│                          Views                              │
│                       (SwiftUI)                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ ATAKMapView  │  │  ChatView    │  │ SettingsView │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
│         │                  │                  │             │
│         └──────────────────┼──────────────────┘             │
│                            │ @ObservedObject                │
└────────────────────────────┼─────────────────────────────────┘
                             │
┌────────────────────────────┼─────────────────────────────────┐
│                    ViewModels (Managers)                     │
│                     @Published Properties                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ TAKService   │  │ ChatManager  │  │ServerManager │    │
│  │ (Observable) │  │ (Observable) │  │ (Observable) │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
│         │                  │                  │             │
│         └──────────────────┼──────────────────┘             │
│                            │ Interacts with                 │
└────────────────────────────┼─────────────────────────────────┘
                             │
┌────────────────────────────┼─────────────────────────────────┐
│                         Services                             │
│                    (Business Logic)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   Network    │  │  Persistence │  │  Validation  │    │
│  │   Service    │  │   Service    │  │   Service    │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
│         │                  │                  │             │
│         └──────────────────┼──────────────────┘             │
│                            │ Operates on                    │
└────────────────────────────┼─────────────────────────────────┘
                             │
┌────────────────────────────┼─────────────────────────────────┐
│                         Models                               │
│                    (Data Structures)                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │  CoTEvent    │  │ChatMessage   │  │  TAKServer   │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Component Layers

#### 1. **View Layer** (`Views/`)

- SwiftUI views for UI presentation
- Observes ViewModels via `@ObservedObject` or `@EnvironmentObject`
- Handles user interactions
- No business logic

**Example:**

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

#### 2. **ViewModel Layer** (`Managers/`)

- `ObservableObject` classes that manage feature state
- Expose `@Published` properties for view binding
- Coordinate between services and views
- Handle user actions

**Example:**

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

#### 3. **Service Layer** (`Services/`)

- Business logic implementation
- External API integrations
- Network operations
- Background tasks

**Example:**

```swift
class ChatService {
    func createMessage(_ text: String, _ recipient: String) -> ChatMessage {
        // Generate GeoChat XML
        let xml = generateGeoChatXML(text: text, recipient: recipient)
        return ChatMessage(text: text, recipient: recipient, cotXML: xml)
    }

    func send(_ message: ChatMessage) {
        // Send via TAKService
        TAKService.shared.send(cotMessage: message.cotXML)
    }
}
```

#### 4. **Model Layer** (`Models/`)

- Pure data structures
- Codable for persistence
- Identifiable for SwiftUI
- No business logic

**Example:**

```swift
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let text: String
    let sender: String
    let recipient: String
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D?
}
```

---

## System Architecture

### High-Level Component Diagram

```
┌───────────────────────────────────────────────────────────────┐
│                      OmniTAKMobileApp                         │
│                         (Entry Point)                         │
└───────────────────────┬───────────────────────────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────────────────────────┐
│                      ATAKMapView                              │
│                   (Main Coordinator)                          │
│                                                               │
│  Integrates all managers and services:                       │
│  • TAKService          • LocationManager                     │
│  • ChatManager         • DrawingToolsManager                 │
│  • ServerManager       • OfflineMapManager                   │
│  • CertificateManager  • GeofenceManager                     │
└───────────────────────┬───────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
┌──────────────┐ ┌─────────────┐ ┌─────────────┐
│   Network    │ │    Map      │ │   Storage   │
│  Subsystem   │ │  Subsystem  │ │  Subsystem  │
└──────────────┘ └─────────────┘ └─────────────┘
```

### Core Subsystems

#### 1. **Network Subsystem**

Handles all TAK server communication:

```
┌─────────────────────────────────────────────────────────────┐
│                       TAKService                            │
│                    (Network Manager)                        │
│                                                             │
│  ┌─────────────────────────────────────────────────┐      │
│  │           DirectTCPSender                       │      │
│  │  • TCP/UDP/TLS connection                       │      │
│  │  • Receive buffer for fragmented XML            │      │
│  │  • Certificate authentication                   │      │
│  └─────────────┬───────────────────────────────────┘      │
│                │                                            │
│                ▼                                            │
│  ┌─────────────────────────────────────────────────┐      │
│  │        CoTMessageParser                         │      │
│  │  • XML parsing with regex                       │      │
│  │  • Event type detection                         │      │
│  └─────────────┬───────────────────────────────────┘      │
│                │                                            │
│                ▼                                            │
│  ┌─────────────────────────────────────────────────┐      │
│  │        CoTEventHandler                          │      │
│  │  • Route events to subsystems                   │      │
│  │  • Publish via Combine                          │      │
│  │  • NotificationCenter integration               │      │
│  └─────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

**Key Components:**

- **TAKService** - Main networking coordinator
- **DirectTCPSender** - Low-level socket communication
- **CoTMessageParser** - XML to structured events
- **CoTEventHandler** - Event routing and distribution

#### 2. **Map Subsystem**

Renders tactical map with overlays:

```
┌─────────────────────────────────────────────────────────────┐
│                  Map Subsystem                              │
│                                                             │
│  ┌─────────────────────────────────────────────────┐      │
│  │      EnhancedMapViewController                  │      │
│  │  • MapKit integration                           │      │
│  │  • Annotation management                        │      │
│  │  • User interaction handling                    │      │
│  └─────────────┬───────────────────────────────────┘      │
│                │                                            │
│    ┌───────────┼───────────┐                              │
│    ▼           ▼           ▼                              │
│  ┌──────┐  ┌──────┐  ┌──────────┐                        │
│  │Markers│  │Overlays││TileSources│                       │
│  └──────┘  └──────┘  └──────────┘                        │
│                                                             │
│  ┌─────────────────────────────────────────────────┐      │
│  │      MapOverlayCoordinator                      │      │
│  │  • MGRS grid                                    │      │
│  │  • Drawing overlays                             │      │
│  │  • Breadcrumb trails                            │      │
│  └─────────────────────────────────────────────────┘      │
│                                                             │
│  ┌─────────────────────────────────────────────────┐      │
│  │      RadialMenuMapCoordinator                   │      │
│  │  • Context menus                                │      │
│  │  • Long-press actions                           │      │
│  └─────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

#### 3. **Storage Subsystem**

Manages data persistence:

```
┌─────────────────────────────────────────────────────────────┐
│                  Storage Subsystem                          │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   UserDefaults│  │   Keychain   │  │  FileSystem  │    │
│  │  • Settings   │  │• Certificates│  │  • Tiles     │    │
│  │  • Chat hist  │  │• Credentials │  │  • DataPkgs  │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                             │
│  Managed by:                                                │
│  • ChatPersistence                                          │
│  • DrawingPersistence                                       │
│  • CertificateManager                                       │
│  • OfflineMapManager                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Component Relationships

### Dependency Graph

```
ATAKMapView
  ├─► TAKService
  │     ├─► DirectTCPSender
  │     ├─► CoTMessageParser
  │     └─► CoTEventHandler
  │           ├─► ChatManager
  │           ├─► TrackRecordingService
  │           └─► EmergencyBeaconService
  │
  ├─► ChatManager
  │     ├─► ChatService
  │     ├─► ChatPersistence
  │     └─► PhotoAttachmentService
  │
  ├─► ServerManager
  │     └─► CertificateManager
  │
  ├─► DrawingToolsManager
  │     └─► DrawingPersistence
  │
  ├─► OfflineMapManager
  │
  ├─► LocationManager (CoreLocation)
  │
  └─► EnhancedMapViewController
        ├─► MapOverlayCoordinator
        └─► RadialMenuMapCoordinator
```

### Communication Patterns

#### 1. **Combine Publishers** (Primary)

Real-time state updates flow through published properties:

```swift
// TAKService publishes connection state
@Published var isConnected: Bool = false

// ChatManager observes and reacts
takService.$isConnected
    .sink { [weak self] connected in
        self?.handleConnectionChange(connected)
    }
    .store(in: &cancellables)
```

#### 2. **Delegate Pattern**

For one-to-one callbacks:

```swift
protocol CoTMessageDelegate: AnyObject {
    func didReceiveMessage(_ message: String)
}

class DirectTCPSender {
    weak var delegate: CoTMessageDelegate?
}
```

#### 3. **NotificationCenter**

For cross-app events:

```swift
NotificationCenter.default.post(
    name: CoTEventHandler.chatMessageNotification,
    object: message
)
```

#### 4. **Closures/Callbacks**

For async operations:

```swift
func connect(host: String, completion: @escaping (Bool) -> Void) {
    // Async network operation
    completion(success)
}
```

---

## Data Flow

### CoT Message Flow (Receiving)

```
1. TAK Server
       │
       │ TCP/TLS stream
       ▼
2. DirectTCPSender
       │
       │ Raw bytes → receiveBuffer
       ▼
3. XML extraction
       │
       │ Complete XML document
       ▼
4. CoTMessageParser
       │
       │ Parse XML → CoTEventType enum
       ▼
5. CoTEventHandler
       │
       ├─► Position Update → Update map markers
       ├─► Chat Message → ChatManager → UI update
       ├─► Emergency → Alert user
       └─► Waypoint → WaypointManager

6. UI Updates (via @Published)
       │
       │ Combine propagation
       ▼
7. SwiftUI Views re-render
```

### CoT Message Flow (Sending)

```
1. User Action (e.g., send chat)
       │
       ▼
2. ChatView → ChatManager
       │
       │ sendMessage()
       ▼
3. ChatService
       │
       │ Generate GeoChat XML
       ▼
4. TAKService
       │
       │ Queue message
       ▼
5. DirectTCPSender
       │
       │ Send over TCP/TLS
       ▼
6. TAK Server
```

### State Update Flow

```
User Interaction
       │
       ▼
View calls ViewModel method
       │
       ▼
ViewModel updates @Published property
       │
       │ (May call Service layer)
       ▼
Combine publishes change
       │
       ▼
All observers receive update
       │
       ├─► UI views re-render
       ├─► Persistence saves state
       └─► Other managers react
```

---

## Threading Model

### Thread Safety Strategy

#### Main Thread

- **All UI updates** must be on main thread
- **@Published property updates** automatically dispatch to main
- **SwiftUI view rendering**

```swift
DispatchQueue.main.async {
    self.isConnected = true  // Updates UI
}
```

#### Background Threads

**Network Operations:**

```swift
private let queue = DispatchQueue(label: "com.omnitak.network")

func connect() {
    queue.async {
        // Network operations
        self.performConnection()
    }
}
```

**File I/O:**

```swift
DispatchQueue.global(qos: .utility).async {
    // Save to disk
    self.saveChatHistory()
}
```

**GPS/Location:**

```swift
// CoreLocation automatically uses background thread
locationManager.startUpdatingLocation()
```

### Synchronization Primitives

#### NSLock (for buffer access)

```swift
private let bufferLock = NSLock()

func appendToBuffer(_ data: String) {
    bufferLock.lock()
    receiveBuffer += data
    bufferLock.unlock()
}
```

#### Serial Dispatch Queue (for ordered operations)

```swift
private let messageQueue = DispatchQueue(label: "com.omnitak.messages")

messageQueue.async {
    self.processNextMessage()
}
```

---

## Memory Management

### Retention Strategy

#### 1. **Weak References for Delegates**

Prevent retain cycles:

```swift
protocol CoTEventHandlerDelegate: AnyObject { }

class CoTEventHandler {
    weak var delegate: CoTEventHandlerDelegate?
}
```

#### 2. **Cancellables Management**

Store Combine subscriptions:

```swift
class ChatManager {
    private var cancellables = Set<AnyCancellable>()

    func setupBindings() {
        takService.$isConnected
            .sink { /* ... */ }
            .store(in: &cancellables)
    }
}
```

#### 3. **Capture Lists in Closures**

Avoid retain cycles:

```swift
connection.stateUpdateHandler = { [weak self] state in
    guard let self = self else { return }
    self.handleStateChange(state)
}
```

### Resource Cleanup

#### Connection Cleanup

```swift
deinit {
    connection?.cancel()
    print("TAKService deinitialized")
}
```

#### Subscription Cleanup

```swift
// Cancellables automatically cleaned up when Set is deallocated
private var cancellables = Set<AnyCancellable>()
```

---

## Performance Considerations

### 1. **Lazy Loading**

Load data on-demand:

```swift
lazy var offlineMapManager = OfflineMapManager()
```

### 2. **Debouncing**

Reduce update frequency:

```swift
searchText.publisher
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
    .sink { /* search */ }
```

### 3. **Caching**

Cache expensive computations:

```swift
private var tileCache: [String: UIImage] = [:]
```

### 4. **Background Processing**

Move heavy tasks off main thread:

```swift
DispatchQueue.global(qos: .userInitiated).async {
    let parsed = self.parseXML(data)
    DispatchQueue.main.async {
        self.updateUI(parsed)
    }
}
```

---

## Testing Architecture

### Unit Testing Strategy

- **Models** - Pure data structures, easy to test
- **Services** - Business logic with injected dependencies
- **ViewModels** - Test state changes via published properties

### Mock Objects

```swift
class MockTAKService: TAKService {
    var shouldSucceed = true

    override func connect() {
        isConnected = shouldSucceed
    }
}
```

---

## Next Steps

- **[Data Flow Details](DataFlow.md)** - Detailed sequence diagrams
- **[State Management](StateManagement.md)** - Combine patterns
- **[Feature Documentation](Features/)** - Individual subsystems
- **[API Reference](API/)** - Complete API documentation

---

_Last Updated: November 22, 2025_
