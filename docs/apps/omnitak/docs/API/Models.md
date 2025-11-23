# Models API Reference

## Table of Contents

- [Overview](#overview)
- [CoT Models](#cot-models)
- [Chat Models](#chat-models)
- [Map Models](#map-models)
- [Tactical Report Models](#tactical-report-models)
- [Team Models](#team-models)
- [Server & Certificate Models](#server--certificate-models)
- [Drawing Models](#drawing-models)
- [Geofence Models](#geofence-models)
- [Offline Map Models](#offline-map-models)
- [Mission Package Models](#mission-package-models)

---

## Overview

OmniTAK Mobile uses Swift `struct` types for all data models, following these patterns:

### Common Protocols

```swift
protocol Identifiable {
    var id: String { get }  // Unique identifier
}

protocol Codable {
    // JSON/Plist encoding/decoding
}

protocol Equatable {
    // Value equality comparison
}
```

### Naming Conventions

- **Singular names**: `ChatMessage`, `Waypoint`, `Team`
- **Descriptive suffixes**: `ChatParticipant`, `GeofenceEvent`
- **Model suffix**: Only when disambiguating (e.g., `CoTFilterModel`)

---

## CoT Models

### CoTEvent

**File:** `OmniTAKMobile/Models/CoTModels.swift`

Core CoT event data structure.

```swift
struct CoTEvent: Identifiable, Codable, Equatable {
    let id: String              // UUID or UID from message
    let uid: String             // CoT UID (e.g., "ANDROID-123")
    let type: String            // CoT type (e.g., "a-f-G-U-C")
    let time: Date              // Event timestamp
    let start: Date             // Start time
    let stale: Date             // Stale time
    let how: String             // How acquired (e.g., "m-g" = GPS)

    // Location
    let coordinate: CLLocationCoordinate2D
    let hae: Double             // Height above ellipsoid (meters)
    let ce: Double              // Circular error (meters)
    let le: Double              // Linear error (meters)

    // Detail
    let callsign: String
    let team: String?
    let role: String?
    let remarks: String?
}
```

**Usage:**

```swift
let event = CoTEvent(
    id: UUID().uuidString,
    uid: "IOS-789",
    type: "a-f-G-U-C",
    time: Date(),
    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    callsign: "Alpha-1"
)
```

### EnhancedCoTMarker

Enhanced marker with trail history.

```swift
struct EnhancedCoTMarker: Identifiable, Equatable {
    let uid: String
    var coordinate: CLLocationCoordinate2D
    var callsign: String
    var type: String
    var team: String?
    var lastUpdate: Date

    // Trail
    var trailCoordinates: [CLLocationCoordinate2D] = []
    var trailTimestamps: [Date] = []

    // Status
    var battery: Int?
    var speed: Double?
    var course: Double?
    var isStale: Bool {
        Date().timeIntervalSince(lastUpdate) > 300 // 5 minutes
    }
}
```

---

## Chat Models

### ChatMessage

**File:** `OmniTAKMobile/Models/ChatModels.swift`

```swift
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String              // Message UID
    let senderUID: String       // Sender CoT UID
    let senderCallsign: String
    let recipientUID: String    // Recipient UID or "All Chat Users"
    let recipientCallsign: String
    let messageText: String
    let timestamp: Date

    // Location
    var coordinate: CLLocationCoordinate2D?

    // Attachment
    var attachment: ImageAttachment?

    // Status
    var status: MessageStatus = .pending
    var isRead: Bool = false
}
```

### MessageStatus

```swift
enum MessageStatus: String, Codable {
    case pending    // Queued, waiting for connection
    case sending    // Currently being sent
    case sent       // Successfully sent
    case delivered  // Delivery confirmed
    case failed     // Send failed
}
```

### Conversation

```swift
struct Conversation: Identifiable, Codable, Equatable {
    let id: String
    var participants: [ChatParticipant]
    var messages: [ChatMessage]
    var unreadCount: Int
    var lastMessage: ChatMessage?
    var isGroupChat: Bool
    var name: String            // "Alpha-1" or "Blue Team"
}
```

### ChatParticipant

```swift
struct ChatParticipant: Identifiable, Codable, Equatable {
    let id: String              // CoT UID
    var callsign: String
    var endpoint: String?       // IP:port:protocol
    var lastSeen: Date
    var isOnline: Bool
    var coordinate: CLLocationCoordinate2D?
}
```

### ImageAttachment

```swift
struct ImageAttachment: Codable, Equatable {
    let id: String
    let filename: String
    let mimeType: String
    let fileSize: Int
    var localPath: String?      // Local storage path
    var thumbnailPath: String?
    var base64Data: String?     // For inline transmission
    var remoteURL: String?      // External link
}
```

---

## Map Models

### Waypoint

**File:** `OmniTAKMobile/Models/WaypointModels.swift`

```swift
struct Waypoint: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var coordinate: CLLocationCoordinate2D
    var elevation: Double?
    var icon: String            // Icon identifier
    var color: Color
    var notes: String?
    var createdAt: Date
    var modifiedAt: Date
    var cotType: String         // CoT type (default: "b-m-p-w")
}
```

**Usage:**

```swift
let waypoint = Waypoint(
    id: UUID(),
    name: "Objective Alpha",
    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    icon: "target",
    color: .red
)
```

### Route

```swift
struct Route: Identifiable, Codable {
    let id: UUID
    var name: String
    var waypoints: [Waypoint]
    var totalDistance: Double   // meters
    var estimatedTime: TimeInterval
    var createdAt: Date
}
```

### PointMarker

```swift
struct PointMarker: Identifiable, Codable, Equatable {
    let id: UUID
    let uid: String             // CoT UID
    var name: String
    var coordinate: CLLocationCoordinate2D
    var elevation: Double
    var cotType: String
    var icon: String
    var color: UIColor
    var notes: String?
    var createdBy: String       // Callsign
    var createdAt: Date
}
```

---

## Tactical Report Models

### CASRequest (Close Air Support)

**File:** `OmniTAKMobile/Models/CASRequestModels.swift`

9-line CAS request.

```swift
struct CASRequest: Identifiable, Codable {
    let id: UUID

    // Line 1-3: Location
    var ipLocation: CLLocationCoordinate2D      // Initial Point
    var targetLocation: CLLocationCoordinate2D  // Target
    var egress: String                          // Egress direction

    // Line 4: Target Type
    var targetType: String                      // "Troops in open", etc.

    // Line 5: Target Description
    var targetDescription: String

    // Line 6: Location of Friendly Forces
    var friendlyLocation: CLLocationCoordinate2D
    var friendlyMarking: String

    // Line 7: Mark Type
    var markType: String                        // "Smoke", "IR", etc.

    // Line 8: Location of Target
    var targetMarking: String

    // Line 9: Egress
    var egressDirection: String

    // Metadata
    var requestedBy: String
    var timestamp: Date
    var status: RequestStatus
}
```

### MEDEVACRequest

**File:** `OmniTAKMobile/Models/MEDEVACModels.swift`

9-line MEDEVAC request.

```swift
struct MEDEVACRequest: Identifiable, Codable {
    let id: UUID

    // Line 1: Location of pickup site
    var pickupLocation: CLLocationCoordinate2D
    var frequency: String                       // Radio freq
    var callsign: String

    // Line 2: Call sign and frequency at pickup site
    var pickupCallsign: String
    var pickupFrequency: String

    // Line 3: Number of patients by precedence
    var urgentPatients: Int
    var priorityPatients: Int
    var routinePatients: Int

    // Line 4: Special equipment required
    var specialEquipment: [String]              // "Hoist", "Ventilator"

    // Line 5: Number of patients by type
    var litterPatients: Int
    var ambulatoryPatients: Int

    // Line 6: Security at pickup site
    var securityStatus: String                  // "No enemy", "Possible"

    // Line 7: Method of marking pickup site
    var marking: String                         // "Smoke", "Panels"

    // Line 8: Patient nationality and status
    var nationality: String
    var combatStatus: String                    // "US Military", "EPW"

    // Line 9: NBC contamination
    var nbcContamination: String                // "None", "Chemical"

    var requestedBy: String
    var timestamp: Date
    var status: RequestStatus
}
```

### SPOTREPReport (Spot Report)

**File:** `OmniTAKMobile/Models/SPOTREPModels.swift`

```swift
struct SPOTREPReport: Identifiable, Codable {
    let id: UUID
    var location: CLLocationCoordinate2D
    var dateTime: Date
    var activity: String                        // What happened
    var size: String                            // Unit size
    var unit: String                            // Unit type/ID
    var time: Date                              // Time observed
    var equipment: String                       // Equipment observed
    var reportedBy: String
    var status: ReportStatus
}
```

---

## Team Models

### Team

**File:** `OmniTAKMobile/Models/TeamModels.swift`

```swift
struct Team: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var color: Color
    var members: [TeamMember]
    var createdAt: Date
    var createdBy: String
}
```

### TeamMember

```swift
struct TeamMember: Identifiable, Codable, Equatable {
    let id: String              // CoT UID
    var callsign: String
    var role: TeamRole
    var joinedAt: Date
}

enum TeamRole: String, Codable {
    case leader
    case member
    case observer
}
```

---

## Server & Certificate Models

### TAKServer

**File:** `OmniTAKMobile/Models/ServerModels.swift`

```swift
struct TAKServer: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var host: String                            // Hostname or IP
    var port: UInt16
    var protocol: String                        // "tcp", "udp", "tls"
    var useTLS: Bool
    var certificateName: String?                // Associated cert
    var allowLegacyTLS: Bool                    // TLS 1.0/1.1
    var autoConnect: Bool
    var createdAt: Date
}
```

### TAKCertificate

```swift
struct TAKCertificate: Identifiable, Codable {
    let id: UUID
    var name: String
    var commonName: String
    var issuer: String
    var expiryDate: Date
    var serialNumber: String
    var thumbprint: String
    var importedAt: Date
}
```

---

## Drawing Models

### Drawing Types

**File:** `OmniTAKMobile/Models/DrawingModels.swift`

```swift
enum Drawing {
    case marker(MarkerDrawing)
    case line(LineDrawing)
    case circle(CircleDrawing)
    case polygon(PolygonDrawing)
}
```

### MarkerDrawing

```swift
struct MarkerDrawing: Identifiable, Codable {
    let id: UUID
    var coordinate: CLLocationCoordinate2D
    var name: String
    var color: Color
    var icon: String
}
```

### LineDrawing

```swift
struct LineDrawing: Identifiable, Codable {
    let id: UUID
    var coordinates: [CLLocationCoordinate2D]
    var name: String
    var color: Color
    var width: Double                           // Line width in points
}
```

### CircleDrawing

```swift
struct CircleDrawing: Identifiable, Codable {
    let id: UUID
    var center: CLLocationCoordinate2D
    var radius: Double                          // meters
    var name: String
    var color: Color
}
```

### PolygonDrawing

```swift
struct PolygonDrawing: Identifiable, Codable {
    let id: UUID
    var coordinates: [CLLocationCoordinate2D]
    var name: String
    var fillColor: Color
    var strokeColor: Color
}
```

---

## Geofence Models

### Geofence

**File:** `OmniTAKMobile/Models/GeofenceModels.swift`

```swift
struct Geofence: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var center: CLLocationCoordinate2D
    var radius: Double                          // meters
    var notifyOnEntry: Bool
    var notifyOnExit: Bool
    var isActive: Bool
    var createdAt: Date
}
```

### GeofenceEvent

```swift
struct GeofenceEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let geofenceUID: String
    let geofenceName: String
    var eventType: GeofenceEventType
    var coordinate: CLLocationCoordinate2D
    var timestamp: Date
    var userCallsign: String
}

enum GeofenceEventType: String, Codable {
    case entry
    case exit
}
```

---

## Offline Map Models

### CachedRegion

**File:** `OmniTAKMobile/Models/OfflineMapModels.swift`

```swift
struct CachedRegion: Identifiable, Codable {
    let id: UUID
    var name: String
    var bounds: MapBounds                       // Lat/lon boundaries
    var minZoom: Int
    var maxZoom: Int
    var tileSource: TileSourceType
    var downloadedAt: Date
    var tileCount: Int
    var sizeBytes: Int64
}

struct MapBounds: Codable {
    var minLat: Double
    var maxLat: Double
    var minLon: Double
    var maxLon: Double
}

enum TileSourceType: String, Codable {
    case openStreetMap
    case satellite
    case hybrid
    case terrain
}
```

### DownloadProgress

```swift
struct DownloadProgress: Identifiable {
    let id: UUID
    var regionName: String
    var completedTiles: Int
    var totalTiles: Int
    var downloadedBytes: Int64
    var progress: Double {
        Double(completedTiles) / Double(totalTiles)
    }
}
```

---

## Mission Package Models

### MissionPackage

**File:** `OmniTAKMobile/Models/MissionPackageModels.swift`

```swift
struct MissionPackage: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var contents: [MissionPackageContent]
    var author: String
    var createdAt: Date
    var modifiedAt: Date
    var fileSize: Int64
    var hash: String                            // SHA-256
}
```

### MissionPackageContent

```swift
struct MissionPackageContent: Codable, Equatable {
    var filename: String
    var type: ContentType
    var data: Data

    enum ContentType: String, Codable {
        case kml
        case image
        case document
        case certificate
        case other
    }
}
```

---

## Common Patterns

### Identifiable Implementation

```swift
struct MyModel: Identifiable {
    let id: UUID = UUID()       // Auto-generated
    // or
    let id: String              // From external source
}
```

### Codable for Persistence

```swift
// Encode
let encoder = JSONEncoder()
let data = try encoder.encode(model)
UserDefaults.standard.set(data, forKey: "myModel")

// Decode
let decoder = JSONDecoder()
let model = try decoder.decode(MyModel.self, from: data)
```

### Equatable for Comparison

```swift
struct MyModel: Equatable {
    // Auto-synthesized if all properties are Equatable
}

// Custom implementation
static func == (lhs: MyModel, rhs: MyModel) -> Bool {
    lhs.id == rhs.id && lhs.name == rhs.name
}
```

---

## Related Documentation

- **[Managers API](Managers.md)** - State management classes
- **[Services API](Services.md)** - Business logic implementations
- **[Architecture](../Architecture.md)** - MVVM pattern

---

_Last Updated: November 22, 2025_
