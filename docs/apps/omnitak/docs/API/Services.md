# Services API Reference

## Table of Contents
- [Overview](#overview)
- [Core Services](#core-services)
- [Location & Tracking](#location--tracking)
- [Communication Services](#communication-services)
- [Map Services](#map-services)
- [Tactical Services](#tactical-services)
- [Data Services](#data-services)
- [External Integration](#external-integration)

---

## Overview

OmniTAK Mobile's service layer implements business logic for all application features. Services are organized by functional domain and follow the singleton pattern for shared state management.

### Service Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Service Layer                         │
│  • Business logic                                        │
│  • Network operations                                    │
│  • Data transformation                                   │
│  • Background processing                                 │
└───────────────────────┬─────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┬───────────────┐
        │               │               │               │
        ▼               ▼               ▼               ▼
  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
  │ Managers │   │ Storage  │   │ Network  │   │   UI     │
  └──────────┘   └──────────┘   └──────────┘   └──────────┘
```

### Files Location

All service files are located in: `OmniTAKMobile/Services/`

---

## Core Services

### TAKService

**File:** `TAKService.swift` (1105 lines)

Core networking service for TAK server communication.

**Declaration:**
```swift
class TAKService: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var messagesSent: Int = 0
    @Published var messagesReceived: Int = 0
    @Published var bytesSent: Int = 0
    @Published var bytesReceived: Int = 0
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `connect(host:port:protocolType:)` | `String`, `UInt16`, `String` | `Void` | Connect to TAK server |
| `disconnect()` | None | `Void` | Disconnect from server |
| `send(cotMessage:priority:)` | `String`, `MessagePriority` | `Void` | Send CoT XML message |
| `reconnect()` | None | `Void` | Attempt reconnection |

**Example:**
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

---

### ChatService

**File:** `ChatService.swift` (310 lines)

Messaging service with queue and retry logic.

**Declaration:**
```swift
class ChatService: ObservableObject {
    static let shared = ChatService()
    
    @Published var messages: [ChatMessage] = []
    @Published var conversations: [Conversation] = []
    @Published var participants: [ChatParticipant] = []
    @Published var unreadCount: Int = 0
    @Published var queuedMessages: [QueuedMessage] = []
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `configure(takService:locationManager:)` | `TAKService`, `LocationManager` | `Void` | Initialize dependencies |
| `sendTextMessage(_:to:)` | `String`, `String` | `Void` | Send text message |
| `sendLocationMessage(location:to:)` | `CLLocation`, `String` | `Void` | Send location share |
| `processQueue()` | None | `Void` | Process queued messages |
| `markAsRead(_:)` | `String` | `Void` | Mark conversation read |

**Example:**
```swift
let chatService = ChatService.shared
chatService.sendTextMessage("Ready to proceed", to: conversationId)
```

---

## Location & Tracking

### PositionBroadcastService

**File:** `PositionBroadcastService.swift` (398 lines)

Automatic Position Location Information (PLI) broadcasting.

**Declaration:**
```swift
class PositionBroadcastService: ObservableObject {
    static let shared = PositionBroadcastService()
    
    @Published var isEnabled: Bool = false
    @Published var updateInterval: TimeInterval = 30.0
    @Published var staleTime: TimeInterval = 180.0
    @Published var lastBroadcastTime: Date?
    @Published var broadcastCount: Int = 0
    @Published var userCallsign: String = "R06"
    @Published var userUID: String
    @Published var teamColor: String = "Dark Blue"
    @Published var teamRole: String = "Team Lead"
    @Published var userUnitType: String = "a-f-G-U-C"
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `configure(takService:locationManager:)` | `TAKService`, `LocationManager` | `Void` | Set up dependencies |
| `startBroadcasting()` | None | `Void` | Start PLI broadcast |
| `stopBroadcasting()` | None | `Void` | Stop PLI broadcast |
| `broadcastPositionNow()` | None | `Void` | Force immediate broadcast |
| `setUpdateInterval(_:)` | `TimeInterval` | `Void` | Change broadcast frequency |

**Example:**
```swift
let pliService = PositionBroadcastService.shared
pliService.userCallsign = "Alpha-1"
pliService.updateInterval = 30.0  // 30 seconds
pliService.isEnabled = true       // Start broadcasting
```

---

### TrackRecordingService

**File:** `TrackRecordingService.swift` (635 lines)

GPS breadcrumb trail recording service.

**Declaration:**
```swift
class TrackRecordingService: ObservableObject {
    static let shared = TrackRecordingService()
    
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentTrack: Track?
    @Published var savedTracks: [Track] = []
    @Published var liveDistance: Double = 0
    @Published var liveSpeed: Double = 0
    @Published var liveAverageSpeed: Double = 0
    @Published var liveElevationGain: Double = 0
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `startRecording(name:)` | `String` | `Void` | Start track recording |
| `pauseRecording()` | None | `Void` | Pause recording |
| `resumeRecording()` | None | `Void` | Resume recording |
| `stopRecording()` | None | `Track?` | Stop and save track |
| `exportTrack(_:format:)` | `Track`, `ExportFormat` | `URL?` | Export as GPX/KML |

**Example:**
```swift
let trackService = TrackRecordingService.shared
trackService.startRecording(name: "Patrol Route Alpha")

// Later...
if let track = trackService.stopRecording() {
    print("Recorded \(track.distance)m in \(track.duration)s")
}
```

---

### EmergencyBeaconService

**File:** `EmergencyBeaconService.swift`

Emergency SOS beacon with rapid PLI updates.

**Declaration:**
```swift
class EmergencyBeaconService: ObservableObject {
    static let shared = EmergencyBeaconService()
    
    @Published var isActive: Bool = false
    @Published var beaconType: BeaconType = .emergency911
    @Published var lastBeaconTime: Date?
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `activateBeacon(type:)` | `BeaconType` | `Void` | Start emergency beacon |
| `cancelBeacon()` | None | `Void` | Cancel emergency |
| `sendBeaconUpdate()` | None | `Void` | Send beacon CoT |

---

## Communication Services

### PhotoAttachmentService

**File:** `PhotoAttachmentService.swift`

Image compression and transmission for chat.

**Declaration:**
```swift
class PhotoAttachmentService {
    func sendPhoto(_ image: UIImage, to conversationId: String)
    func compressImage(_ image: UIImage, maxSize: Int) -> Data?
    func saveAttachment(_ data: Data, filename: String) -> URL?
}
```

---

### DigitalPointerService

**File:** `DigitalPointerService.swift`

Laser pointer functionality for map coordination.

**Declaration:**
```swift
class DigitalPointerService: ObservableObject {
    @Published var isActive: Bool = false
    @Published var currentPointer: DigitalPointer?
    @Published var receivedPointers: [DigitalPointer] = []
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `startPointing(at:)` | `CLLocationCoordinate2D` | `Void` | Start laser pointer |
| `updatePointer(to:)` | `CLLocationCoordinate2D` | `Void` | Move pointer |
| `stopPointing()` | None | `Void` | Stop pointer |

---

### TeamService

**File:** `TeamService.swift`

Team management and coordination.

**Declaration:**
```swift
class TeamService: ObservableObject {
    @Published var teams: [Team] = []
    @Published var currentUserTeams: [Team] = []
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `createTeam(name:color:)` | `String`, `Color` | `Team` | Create new team |
| `inviteToTeam(_:uid:)` | `Team`, `String` | `Void` | Invite member |
| `leaveTeam(_:)` | `Team` | `Void` | Leave team |
| `broadcastTeamMessage(_:)` | `String` | `Void` | Team broadcast |

---

## Map Services

### MeasurementService

**File:** `MeasurementService.swift` (422 lines)

Distance and area measurement tools.

**Declaration:**
```swift
class MeasurementService: ObservableObject {
    @Published var manager: MeasurementManager
    @Published var overlays: [MKOverlay] = []
    @Published var annotations: [MKPointAnnotation] = []
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `startMeasurement(type:)` | `MeasurementType` | `Void` | Begin measurement |
| `addPoint(_:)` | `CLLocationCoordinate2D` | `Void` | Add measurement point |
| `completeMeasurement()` | None | `Measurement?` | Finish & save |
| `addRangeRing(center:radius:)` | `CLLocationCoordinate2D`, `Double` | `Void` | Add range ring |

**Example:**
```swift
let service = MeasurementService()
service.startMeasurement(type: .distance)
service.addPoint(coord1)
service.addPoint(coord2)
let measurement = service.completeMeasurement()
print("Distance: \(measurement.distanceMeters)m")
```

---

### RangeBearingService

**File:** `RangeBearingService.swift`

Range and bearing line calculations.

**Declaration:**
```swift
class RangeBearingService: ObservableObject {
    @Published var activeLines: [RangeBearingLine] = []
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `createLine(from:to:)` | `CLLocationCoordinate2D`, `CLLocationCoordinate2D` | `RangeBearingLine` | Create R&B line |
| `calculateBearing(from:to:)` | `CLLocationCoordinate2D`, `CLLocationCoordinate2D` | `Double` | True bearing (degrees) |
| `calculateDistance(from:to:)` | `CLLocationCoordinate2D`, `CLLocationCoordinate2D` | `Double` | Distance (meters) |

---

### ElevationProfileService

**File:** `ElevationProfileService.swift`

Elevation profile generation for routes.

**Declaration:**
```swift
class ElevationProfileService: ObservableObject {
    @Published var currentProfile: ElevationProfile?
    @Published var isLoading: Bool = false
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `generateProfile(for:)` | `[CLLocationCoordinate2D]` | Async | Generate elevation profile |
| `fetchElevation(at:)` | `CLLocationCoordinate2D` | `Double?` | Get single point elevation |

---

### LineOfSightService

**File:** `LineOfSightService.swift`

Line-of-sight visibility analysis.

**Declaration:**
```swift
class LineOfSightService: ObservableObject {
    @Published var activeAnalysis: LOSAnalysis?
    @Published var isCalculating: Bool = false
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `calculateLOS(from:to:)` | `CLLocationCoordinate2D`, `CLLocationCoordinate2D` | Async | Calculate LOS |
| `findObstructions(along:)` | `[CLLocationCoordinate2D]` | `[LOSObstruction]` | Find blocking terrain |

---

### NavigationService

**File:** `NavigationService.swift`

Route navigation and guidance.

**Declaration:**
```swift
class NavigationService: ObservableObject {
    @Published var activeRoute: Route?
    @Published var isNavigating: Bool = false
    @Published var distanceToNextWaypoint: Double = 0
    @Published var bearingToNextWaypoint: Double = 0
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `startNavigation(route:)` | `Route` | `Void` | Begin navigation |
| `stopNavigation()` | None | `Void` | End navigation |
| `updateLocation(_:)` | `CLLocation` | `Void` | Update nav position |

---

## Tactical Services

### GeofenceService

**File:** `GeofenceService.swift` (538 lines)

Geofence monitoring with entry/exit detection.

**Declaration:**
```swift
class GeofenceService: ObservableObject {
    static let shared = GeofenceService()
    
    @Published var activeAlerts: [GeofenceAlert] = []
    @Published var recentEvents: [GeofenceEvent] = []
    @Published var isMonitoring: Bool = false
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `addGeofence(_:)` | `Geofence` | `Void` | Add monitored fence |
| `startMonitoring()` | None | `Void` | Start monitoring all |
| `stopMonitoring()` | None | `Void` | Stop monitoring |
| `checkLocation(_:)` | `CLLocation` | `[GeofenceEvent]` | Check for events |

**Example:**
```swift
let service = GeofenceService.shared
let fence = Geofence(
    name: "Base Perimeter",
    center: baseCoord,
    radius: 500,  // meters
    notifyOnEntry: true,
    notifyOnExit: true
)
service.addGeofence(fence)
service.startMonitoring()
```

---

### RoutePlanningService

**File:** `RoutePlanningService.swift`

Multi-waypoint route planning with optimization.

**Declaration:**
```swift
class RoutePlanningService: ObservableObject {
    @Published var routes: [Route] = []
    @Published var activeRoute: Route?
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `createRoute(waypoints:)` | `[Waypoint]` | `Route` | Create route |
| `optimizeRoute(_:)` | `Route` | `Route` | Optimize order |
| `calculateETA(for:speed:)` | `Route`, `Double` | `TimeInterval` | Estimate time |

---

### PointDropperService

**File:** `PointDropperService.swift`

Quick point marker creation tool.

**Declaration:**
```swift
class PointDropperService: ObservableObject {
    @Published var droppedPoints: [PointMarker] = []
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `dropPoint(at:type:)` | `CLLocationCoordinate2D`, `String` | `PointMarker` | Drop marker |
| `deletePoint(_:)` | `PointMarker` | `Void` | Remove marker |

---

### EchelonService

**File:** `EchelonService.swift`

Military unit hierarchy management.

**Declaration:**
```swift
class EchelonService: ObservableObject {
    @Published var units: [MilitaryUnit] = []
    @Published var hierarchy: UnitHierarchy?
}
```

---

## Data Services

### MissionPackageSyncService

**File:** `MissionPackageSyncService.swift`

Data package synchronization.

**Declaration:**
```swift
class MissionPackageSyncService: ObservableObject {
    @Published var packages: [MissionPackage] = []
    @Published var isSyncing: Bool = false
    @Published var syncProgress: Double = 0
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `syncPackage(_:)` | `MissionPackage` | Async | Sync package |
| `importPackage(url:)` | `URL` | `MissionPackage?` | Import from file |
| `exportPackage(_:)` | `MissionPackage` | `URL?` | Export to file |

---

### CertificateEnrollmentService

**File:** `CertificateEnrollmentService.swift`

Automated certificate enrollment.

**Declaration:**
```swift
class CertificateEnrollmentService: ObservableObject {
    @Published var enrollmentStatus: EnrollmentStatus = .idle
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `enrollWithServer(url:username:password:)` | `String`, `String`, `String` | Async | Request certificate |
| `checkEnrollmentStatus()` | None | `EnrollmentStatus` | Check status |

---

## External Integration

### ArcGISFeatureService

**File:** `ArcGISFeatureService.swift`

ArcGIS REST API integration.

**Declaration:**
```swift
class ArcGISFeatureService: ObservableObject {
    @Published var features: [ArcGISFeature] = []
    @Published var isLoading: Bool = false
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `queryFeatures(serviceURL:where:)` | `String`, `String` | Async | Query features |
| `addFeature(_:to:)` | `ArcGISFeature`, `String` | Async | Add feature |

---

### VideoStreamService

**File:** `VideoStreamService.swift`

Video feed integration.

**Declaration:**
```swift
class VideoStreamService: ObservableObject {
    @Published var activeStreams: [VideoStream] = []
}
```

**Key Methods:**

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `connectToStream(url:)` | `String` | `VideoStream?` | Connect video feed |
| `disconnectStream(_:)` | `VideoStream` | `Void` | Disconnect |

---

### BloodhoundService

**File:** `BloodhoundService.swift`

Personnel tracking integration.

**Declaration:**
```swift
class BloodhoundService: ObservableObject {
    @Published var trackedPersonnel: [TrackedPerson] = []
}
```

---

## Service Patterns

### Singleton Pattern

Most services use singleton pattern for shared state:

```swift
class MyService: ObservableObject {
    static let shared = MyService()
    
    private init() {
        // Initialize
    }
}

// Usage
let service = MyService.shared
```

### Dependency Injection

Services accept dependencies via configuration:

```swift
func configure(takService: TAKService, locationManager: LocationManager) {
    self.takService = takService
    self.locationManager = locationManager
}
```

### Async Operations

Services use async/await for network operations:

```swift
func fetchData() async throws -> Data {
    let url = URL(string: "https://api.example.com/data")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}
```

---

## Related Documentation

- **[Managers API](Managers.md)** - State management layer
- **[Models API](Models.md)** - Data structures
- **[Architecture](../Architecture.md)** - System design

---

*Last Updated: November 22, 2025*
