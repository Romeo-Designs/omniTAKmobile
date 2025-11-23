# Managers API Reference

## Table of Contents

- [Overview](#overview)
- [ServerManager](#servermanager)
- [CertificateManager](#certificatemanager)
- [ChatManager](#chatmanager)
- [CoTFilterManager](#cotfiltermanager)
- [DrawingToolsManager](#drawingtoolsmanager)
- [GeofenceManager](#geofencemanager)
- [MeasurementManager](#measurementmanager)
- [MeshtasticManager](#meshtasticmanager)
- [OfflineMapManager](#offlinemapmanager)
- [WaypointManager](#waypointmanager)
- [DataPackageManager](#datapackagemanager)

---

## Overview

**Managers** are `ObservableObject` classes that manage state for specific features in OmniTAK Mobile. They expose `@Published` properties for reactive SwiftUI binding and coordinate between Services and Views.

### Common Patterns

All managers follow these patterns:

1. **Observable**: Conform to `ObservableObject`
2. **Published State**: Use `@Published` for reactive properties
3. **Singleton or Injected**: Either singleton pattern or dependency injection
4. **Persistence**: Auto-save state changes via `didSet`
5. **Service Coordination**: Delegate business logic to Service classes

---

## ServerManager

**File:** `OmniTAKMobile/Managers/ServerManager.swift`

Manages TAK server configurations and connection profiles.

### Class Declaration

```swift
class ServerManager: ObservableObject {
    static let shared = ServerManager()

    @Published var servers: [TAKServer] = []
    @Published var selectedServer: TAKServer?
    @Published var activeServerIndex: Int = 0
}
```

### Properties

| Property            | Type          | Description                |
| ------------------- | ------------- | -------------------------- |
| `servers`           | `[TAKServer]` | List of configured servers |
| `selectedServer`    | `TAKServer?`  | Currently selected server  |
| `activeServerIndex` | `Int`         | Index of active server     |

### Methods

#### addServer(\_:)

```swift
func addServer(_ server: TAKServer)
```

Adds a new server configuration.

**Parameters:**

- `server`: TAKServer - Server configuration to add

**Example:**

```swift
let server = TAKServer(
    name: "Production TAK",
    host: "tak.example.com",
    port: 8089,
    protocol: "tls",
    useTLS: true
)
ServerManager.shared.addServer(server)
```

#### removeServer(at:)

```swift
func removeServer(at index: Int)
```

Removes a server at the specified index.

#### updateServer(at:with:)

```swift
func updateServer(at index: Int, with server: TAKServer)
```

Updates an existing server configuration.

#### selectServer(\_:)

```swift
func selectServer(_ server: TAKServer)
```

Sets the active server and triggers reconnection.

**Example:**

```swift
if let server = ServerManager.shared.servers.first {
    ServerManager.shared.selectServer(server)
}
```

### Persistence

Server configurations are automatically persisted to `UserDefaults` using `Codable`:

```swift
private func saveServers() {
    if let encoded = try? JSONEncoder().encode(servers) {
        UserDefaults.standard.set(encoded, forKey: "tak_servers")
    }
}
```

---

## CertificateManager

**File:** `OmniTAKMobile/Managers/CertificateManager.swift`

Manages client certificates for TLS authentication with TAK servers.

### Class Declaration

```swift
class CertificateManager: ObservableObject {
    static let shared = CertificateManager()

    @Published var certificates: [TAKCertificate] = []
    @Published var selectedCertificate: TAKCertificate?
}
```

### Properties

| Property              | Type               | Description                        |
| --------------------- | ------------------ | ---------------------------------- |
| `certificates`        | `[TAKCertificate]` | Available certificates             |
| `selectedCertificate` | `TAKCertificate?`  | Active certificate for connections |

### Methods

#### importCertificate(from:password:)

```swift
func importCertificate(from data: Data, password: String) throws -> TAKCertificate
```

Imports a .p12 certificate file.

**Parameters:**

- `data`: Data - Raw .p12 file data
- `password`: String - Certificate password

**Returns:** TAKCertificate - Imported certificate metadata

**Throws:** `CertificateError` if import fails

**Example:**

```swift
do {
    let fileURL = URL(fileURLWithPath: "/path/to/cert.p12")
    let data = try Data(contentsOf: fileURL)
    let cert = try CertificateManager.shared.importCertificate(from: data, password: "password123")
    print("Imported certificate: \(cert.commonName)")
} catch {
    print("Import failed: \(error)")
}
```

#### saveCertificate(\_:data:password:)

```swift
func saveCertificate(_ name: String, data: Data, password: String) throws
```

Saves certificate to iOS Keychain.

**Parameters:**

- `name`: String - Certificate identifier
- `data`: Data - .p12 certificate data
- `password`: String - Certificate password

#### getCertificateData(for:)

```swift
func getCertificateData(for name: String) throws -> (Data, String)
```

Retrieves certificate data from Keychain.

**Returns:** Tuple of (certificate data, password)

#### deleteCertificate(\_:)

```swift
func deleteCertificate(_ name: String) throws
```

Removes certificate from Keychain.

#### getIdentity(for:password:)

```swift
func getIdentity(for data: Data, password: String) throws -> SecIdentity
```

Extracts `SecIdentity` for TLS authentication.

**Returns:** `SecIdentity` - Identity for TLS client authentication

**Example:**

```swift
let (data, password) = try CertificateManager.shared.getCertificateData(for: "my-cert")
let identity = try CertificateManager.shared.getIdentity(for: data, password: password)
// Use identity in TLS connection
```

### Certificate Validation

#### validateCertificate(\_:)

```swift
func validateCertificate(_ certificate: TAKCertificate) -> CertificateValidationResult
```

Checks certificate expiry and validity.

**Returns:**

- `.valid` - Certificate is valid
- `.expiringSoon` - Expires within 30 days
- `.expired` - Certificate has expired

---

## ChatManager

**File:** `OmniTAKMobile/Managers/ChatManager.swift`

Manages chat conversations, messages, and participants.

### Class Declaration

```swift
class ChatManager: ObservableObject {
    static let shared = ChatManager()

    @Published var conversations: [Conversation] = []
    @Published var activeConversation: Conversation?
    @Published var unreadCount: Int = 0
    @Published var participants: [ChatParticipant] = []
}
```

### Properties

| Property             | Type                | Description                              |
| -------------------- | ------------------- | ---------------------------------------- |
| `conversations`      | `[Conversation]`    | All chat conversations                   |
| `activeConversation` | `Conversation?`     | Currently open conversation              |
| `unreadCount`        | `Int`               | Total unread message count               |
| `participants`       | `[ChatParticipant]` | Known participants from position updates |

### Methods

#### sendMessage(\_:to:)

```swift
func sendMessage(_ text: String, to recipient: String)
```

Sends a chat message to a recipient or group.

**Parameters:**

- `text`: String - Message text
- `recipient`: String - Recipient UID or "All Chat Users"

**Example:**

```swift
ChatManager.shared.sendMessage("Enemy sighted at grid 12345678", to: "ANDROID-789")
```

#### receiveMessage(\_:)

```swift
func receiveMessage(_ message: ChatMessage)
```

Processes incoming chat message from CoT handler.

#### sendPhotoMessage(\_:image:to:)

```swift
func sendPhotoMessage(_ caption: String?, image: UIImage, to recipient: String)
```

Sends a photo attachment with optional caption.

**Example:**

```swift
let image = UIImage(named: "recon_photo")!
ChatManager.shared.sendPhotoMessage("Target building", image: image, to: "ANDROID-789")
```

#### getOrCreateConversation(with:)

```swift
func getOrCreateConversation(with uid: String) -> Conversation
```

Retrieves existing conversation or creates new one.

#### markConversationAsRead(\_:)

```swift
func markConversationAsRead(_ conversation: Conversation)
```

Clears unread count for conversation.

#### deleteConversation(\_:)

```swift
func deleteConversation(_ conversation: Conversation)
```

Removes conversation and messages.

#### updateParticipant(uid:callsign:coordinate:)

```swift
func updateParticipant(uid: String, callsign: String, coordinate: CLLocationCoordinate2D?)
```

Updates participant info from position updates.

**Called by:** `CoTEventHandler` when position updates received

---

## CoTFilterManager

**File:** `OmniTAKMobile/Managers/CoTFilterManager.swift`

Manages message filtering criteria for CoT events.

### Class Declaration

```swift
class CoTFilterManager: ObservableObject {
    static let shared = CoTFilterManager()

    @Published var activeFilters: [CoTFilterCriteria] = []
    @Published var filterEnabled: Bool = false
}
```

### Properties

| Property        | Type                  | Description           |
| --------------- | --------------------- | --------------------- |
| `activeFilters` | `[CoTFilterCriteria]` | Active filter rules   |
| `filterEnabled` | `Bool`                | Master enable/disable |

### Methods

#### addFilter(\_:)

```swift
func addFilter(_ filter: CoTFilterCriteria)
```

Adds a filter criterion.

**Example:**

```swift
let filter = CoTFilterCriteria(
    type: .affiliation(Affiliation.friendly),
    enabled: true
)
CoTFilterManager.shared.addFilter(filter)
```

#### removeFilter(at:)

```swift
func removeFilter(at index: Int)
```

Removes filter at index.

#### shouldDisplay(\_:)

```swift
func shouldDisplay(_ event: CoTEvent) -> Bool
```

Tests if event passes all active filters.

**Returns:** `true` if event should be displayed

**Example:**

```swift
if CoTFilterManager.shared.shouldDisplay(cotEvent) {
    // Add to map
}
```

### Filter Types

```swift
enum FilterType {
    case affiliation(Affiliation)  // Friendly, hostile, neutral, unknown
    case range(Double)              // Max distance from user
    case team(String)               // Specific team name
    case type(String)               // CoT type prefix
}
```

---

## DrawingToolsManager

**File:** `OmniTAKMobile/Managers/DrawingToolsManager.swift`

Manages drawing mode and temporary drawing state.

### Class Declaration

```swift
class DrawingToolsManager: ObservableObject {
    @Published var drawingMode: DrawingMode = .none
    @Published var selectedColor: Color = .red
    @Published var currentDrawing: Drawing?
}
```

### Properties

| Property         | Type          | Description         |
| ---------------- | ------------- | ------------------- |
| `drawingMode`    | `DrawingMode` | Active drawing tool |
| `selectedColor`  | `Color`       | Drawing color       |
| `currentDrawing` | `Drawing?`    | In-progress drawing |

### Drawing Modes

```swift
enum DrawingMode {
    case none
    case marker
    case line
    case circle
    case polygon
}
```

### Methods

#### startDrawing(mode:color:)

```swift
func startDrawing(mode: DrawingMode, color: Color)
```

Activates drawing mode.

**Example:**

```swift
DrawingToolsManager.shared.startDrawing(mode: .line, color: .blue)
```

#### addPoint(\_:)

```swift
func addPoint(_ coordinate: CLLocationCoordinate2D)
```

Adds point to current drawing.

#### finishDrawing() -> Drawing?

```swift
func finishDrawing() -> Drawing?
```

Completes drawing and returns result.

**Returns:** Completed Drawing object

#### cancelDrawing()

```swift
func cancelDrawing()
```

Cancels current drawing.

---

## GeofenceManager

**File:** `OmniTAKMobile/Managers/GeofenceManager.swift`

Manages geofences and monitors location events.

### Class Declaration

```swift
class GeofenceManager: ObservableObject {
    static let shared = GeofenceManager()

    @Published var geofences: [Geofence] = []
    @Published var activeGeofenceEvents: [GeofenceEvent] = []
}
```

### Properties

| Property               | Type              | Description              |
| ---------------------- | ----------------- | ------------------------ |
| `geofences`            | `[Geofence]`      | Defined geofences        |
| `activeGeofenceEvents` | `[GeofenceEvent]` | Recent entry/exit events |

### Methods

#### addGeofence(\_:)

```swift
func addGeofence(_ geofence: Geofence)
```

Adds and starts monitoring geofence.

**Example:**

```swift
let geofence = Geofence(
    id: UUID(),
    name: "Base Perimeter",
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    radius: 500, // meters
    notifyOnEntry: true,
    notifyOnExit: true
)
GeofenceManager.shared.addGeofence(geofence)
```

#### removeGeofence(\_:)

```swift
func removeGeofence(_ geofence: Geofence)
```

Removes and stops monitoring geofence.

#### checkLocation(\_:)

```swift
func checkLocation(_ location: CLLocation)
```

Manually checks location against all geofences.

**Called by:** Location manager updates

---

## MeasurementManager

**File:** `OmniTAKMobile/Managers/MeasurementManager.swift`

Manages measurement tool state (distance, bearing, area).

### Class Declaration

```swift
class MeasurementManager: ObservableObject {
    @Published var measurementMode: MeasurementMode = .none
    @Published var measurementPoints: [CLLocationCoordinate2D] = []
    @Published var result: MeasurementResult?
}
```

### Measurement Modes

```swift
enum MeasurementMode {
    case none
    case distance       // Multi-point distance
    case rangeBearing   // Single line with range & bearing
    case area           // Polygon area
}
```

### Methods

#### startMeasurement(mode:)

```swift
func startMeasurement(mode: MeasurementMode)
```

Begins measurement.

#### addMeasurementPoint(\_:)

```swift
func addMeasurementPoint(_ coordinate: CLLocationCoordinate2D)
```

Adds point to measurement.

#### completeMeasurement() -> MeasurementResult?

```swift
func completeMeasurement() -> MeasurementResult?
```

Finalizes and calculates result.

**Returns:** MeasurementResult with distance/area/bearing

---

## MeshtasticManager

**File:** `OmniTAKMobile/Managers/MeshtasticManager.swift`

Manages Meshtastic mesh network connections.

### Class Declaration

```swift
public class MeshtasticManager: ObservableObject {
    static let shared = MeshtasticManager()

    @Published public var isConnected: Bool = false
    @Published public var discoveredDevices: [MeshtasticDevice] = []
    @Published public var connectedDevice: MeshtasticDevice?
    @Published public var meshNodes: [MeshNode] = []
}
```

### Connection Methods

#### startBluetoothScan()

```swift
func startBluetoothScan()
```

Begins BLE scan for Meshtastic devices.

#### connectToDevice(\_:)

```swift
func connectToDevice(_ device: MeshtasticDevice)
```

Connects to Meshtastic device.

**Example:**

```swift
if let device = MeshtasticManager.shared.discoveredDevices.first {
    MeshtasticManager.shared.connectToDevice(device)
}
```

#### disconnect()

```swift
func disconnect()
```

Disconnects from current device.

#### sendMessage(\_:)

```swift
func sendMessage(_ message: String) throws
```

Sends text message over mesh network.

---

## OfflineMapManager

**File:** `OmniTAKMobile/Managers/OfflineMapManager.swift`

Manages offline map tile downloads and storage.

### Class Declaration

```swift
class OfflineMapManager: ObservableObject {
    static let shared = OfflineMapManager()

    @Published var downloadedRegions: [OfflineRegion] = []
    @Published var currentDownload: DownloadProgress?
    @Published var isDownloading: Bool = false
}
```

### Methods

#### downloadRegion(\_:)

```swift
func downloadRegion(_ region: OfflineRegion)
```

Downloads tiles for specified region.

**Parameters:**

- `region`: OfflineRegion with bounds, zoom range, tile source

**Example:**

```swift
let region = OfflineRegion(
    name: "San Francisco",
    bounds: MKMapRect(...),
    minZoom: 10,
    maxZoom: 16,
    tileSource: .satellite
)
OfflineMapManager.shared.downloadRegion(region)
```

#### cancelDownload()

```swift
func cancelDownload()
```

Cancels active download.

#### deleteRegion(\_:)

```swift
func deleteRegion(_ region: OfflineRegion)
```

Removes downloaded tiles for region.

---

## WaypointManager

**File:** `OmniTAKMobile/Managers/WaypointManager.swift`

Manages tactical waypoints and markers.

### Class Declaration

```swift
class WaypointManager: ObservableObject {
    static let shared = WaypointManager()

    @Published var waypoints: [Waypoint] = []
    @Published var selectedWaypoint: Waypoint?
}
```

### Methods

#### addWaypoint(\_:)

```swift
func addWaypoint(_ waypoint: Waypoint)
```

Adds waypoint and broadcasts to TAK server.

**Example:**

```swift
let waypoint = Waypoint(
    name: "Rally Point Alpha",
    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    icon: "rally_point",
    notes: "Emergency rally point"
)
WaypointManager.shared.addWaypoint(waypoint)
```

#### removeWaypoint(\_:)

```swift
func removeWaypoint(_ waypoint: Waypoint)
```

Removes waypoint and sends delete CoT.

#### updateWaypoint(\_:)

```swift
func updateWaypoint(_ waypoint: Waypoint)
```

Updates existing waypoint.

---

## DataPackageManager

**File:** `OmniTAKMobile/Managers/DataPackageManager.swift`

Manages data package import/export (KML, KMZ, mission packages).

### Class Declaration

```swift
class DataPackageManager: ObservableObject {
    static let shared = DataPackageManager()

    @Published var importedPackages: [DataPackage] = []
}
```

### Methods

#### importKML(from:)

```swift
func importKML(from url: URL) throws -> DataPackage
```

Imports KML/KMZ file.

**Returns:** DataPackage with extracted features

**Example:**

```swift
do {
    let package = try DataPackageManager.shared.importKML(from: fileURL)
    print("Imported \(package.features.count) features")
} catch {
    print("Import failed: \(error)")
}
```

#### exportPackage(\_:)

```swift
func exportPackage(_ package: DataPackage) throws -> URL
```

Exports data package to file.

**Returns:** URL of exported file

#### sharePackage(\_:)

```swift
func sharePackage(_ package: DataPackage)
```

Shares package via system share sheet.

---

## Usage Examples

### Example 1: Complete Server Setup

```swift
// Configure server
let server = TAKServer(
    name: "My TAK Server",
    host: "192.168.1.100",
    port: 8089,
    protocol: "tls",
    useTLS: true
)
ServerManager.shared.addServer(server)

// Import certificate
let certData = try Data(contentsOf: certURL)
let cert = try CertificateManager.shared.importCertificate(from: certData, password: "pass")
CertificateManager.shared.selectedCertificate = cert

// Connect
ServerManager.shared.selectServer(server)
```

### Example 2: Chat with Location

```swift
// Get current location
guard let location = locationManager.location else { return }

// Create message with location
let message = "Meeting at coordinates"
ChatManager.shared.sendMessage(message, to: "ANDROID-456")
```

### Example 3: Geofence with Notification

```swift
let geofence = Geofence(
    id: UUID(),
    name: "Restricted Area",
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    radius: 1000,
    notifyOnEntry: true,
    notifyOnExit: false
)
GeofenceManager.shared.addGeofence(geofence)

// Events published automatically
GeofenceManager.shared.$activeGeofenceEvents
    .sink { events in
        if let latest = events.last {
            print("Geofence event: \(latest.eventType)")
        }
    }
    .store(in: &cancellables)
```

---

## Related Documentation

- **[Services API](Services.md)** - Business logic implementations
- **[Architecture](../Architecture.md)** - MVVM pattern details
- **[State Management](../StateManagement.md)** - Combine patterns

---

_Last Updated: November 22, 2025_
