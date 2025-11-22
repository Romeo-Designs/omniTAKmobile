# Map System Documentation

## Table of Contents
- [Overview](#overview)
- [Map Architecture](#map-architecture)
- [Map Controllers](#map-controllers)
- [Markers & Icons](#markers--icons)
- [Map Overlays](#map-overlays)
- [Tile Sources](#tile-sources)
- [Map Types & Layers](#map-types--layers)
- [User Tracking](#user-tracking)
- [Coordinate Systems](#coordinate-systems)
- [Performance](#performance)
- [Code Examples](#code-examples)

---

## Overview

OmniTAK Mobile's map system provides a tactical mapping interface built on Apple's MapKit framework with extensive customization for military operations. The system supports multiple map types, real-time position tracking, tactical overlays, offline caching, and MIL-STD-2525 symbology.

### Key Features
- ✅ **MapKit Integration** - Native iOS mapping with smooth performance
- ✅ **Multiple Map Types** - Standard, satellite, hybrid, terrain
- ✅ **Tactical Markers** - MIL-STD-2525 compatible symbology
- ✅ **Real-time Updates** - Live position tracking and CoT markers
- ✅ **Overlays** - Circles, polygons, lines, geofences
- ✅ **Offline Tiles** - Pre-cached map regions for no-connectivity ops
- ✅ **Custom Tile Sources** - OpenStreetMap, ArcGIS, satellite imagery
- ✅ **Coordinate Display** - MGRS, UTM, Lat/Lon formats
- ✅ **Breadcrumb Trails** - Movement history visualization
- ✅ **Range & Bearing** - Distance/direction measurement tools

### Files
- **Main View**: `OmniTAKMobile/Map/Controllers/MapViewController.swift` (3210 lines)
- **State Manager**: `OmniTAKMobile/Map/Controllers/MapStateManager.swift`
- **Markers**: `OmniTAKMobile/Map/Markers/`
- **Overlays**: `OmniTAKMobile/Map/Overlays/`
- **Tile Sources**: `OmniTAKMobile/Map/TileSources/`

---

## Map Architecture

### Component Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                  ATAKMapView (SwiftUI)                      │
│  • Main map container                                       │
│  • Tactical UI overlays                                     │
│  • Tool coordination                                        │
└───────────────────────┬─────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌───────────────┐ ┌──────────┐ ┌──────────────┐
│ MapKit View   │ │ Overlays │ │ UI Controls  │
│ • MKMapView   │ │ • Circles│ │ • Compass    │
│ • Annotations │ │ • Polygons│ │ • Scale      │
│ • User Track  │ │ • Lines  │ │ • Coordinates│
└───────┬───────┘ └────┬─────┘ └──────┬───────┘
        │              │               │
        ▼              ▼               ▼
┌──────────────────────────────────────────────┐
│         MapStateManager                      │
│  • Region tracking                           │
│  • Zoom level                                │
│  • Center coordinate                         │
│  • Map type                                  │
└──────────────────────────────────────────────┘
```

### State Management

```swift
class MapStateManager: ObservableObject {
    @Published var region: MKCoordinateRegion
    @Published var mapType: MKMapType = .standard
    @Published var trackingMode: MapUserTrackingMode = .none
    @Published var zoomLevel: Double = 15.0
    
    // Layer visibility
    @Published var showFriendly: Bool = true
    @Published var showHostile: Bool = true
    @Published var showUnknown: Bool = true
    @Published var showNeutral: Bool = true
    
    // Overlay visibility
    @Published var showCompass: Bool = true
    @Published var showCoordinates: Bool = false
    @Published var showScaleBar: Bool = false
    @Published var showGrid: Bool = false
    @Published var showBreadcrumbTrails: Bool = false
}
```

---

## Map Controllers

### ATAKMapView

Primary map interface with tactical features.

**Declaration:**
```swift
struct ATAKMapView: View {
    @StateObject private var takService = TAKService()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var drawingStore: DrawingStore
    @StateObject private var mapStateManager = MapStateManager()
    
    @State private var mapRegion: MKCoordinateRegion
    @State private var mapType: MKMapType = .standard
    @State private var trackingMode: MapUserTrackingMode = .none
    
    var body: some View {
        ZStack {
            // Base map
            Map(coordinateRegion: $mapRegion,
                interactionModes: .all,
                showsUserLocation: true,
                userTrackingMode: $trackingMode,
                annotationItems: markers) { marker in
                    MapAnnotation(coordinate: marker.coordinate) {
                        MarkerView(marker: marker)
                    }
                }
            
            // Tactical overlays
            MapOverlayView()
            
            // UI controls
            MapControlsView()
        }
    }
}
```

**Key Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `mapRegion` | `MKCoordinateRegion` | Current visible region |
| `mapType` | `MKMapType` | Standard, satellite, hybrid |
| `trackingMode` | `MapUserTrackingMode` | User tracking: none, follow, followWithHeading |
| `showTraffic` | `Bool` | Show traffic overlay |
| `showCompass` | `Bool` | Display compass |
| `showCoordinates` | `Bool` | Display center coordinates |

### MapOverlayCoordinator

Manages dynamic overlays (circles, polygons, lines).

```swift
class MapOverlayCoordinator: ObservableObject {
    @Published var circles: [CircleOverlay] = []
    @Published var polygons: [PolygonOverlay] = []
    @Published var polylines: [PolylineOverlay] = []
    
    func addCircle(center: CLLocationCoordinate2D, radius: Double, color: Color) {
        let circle = CircleOverlay(
            center: center,
            radius: radius,
            fillColor: color.withAlphaComponent(0.3),
            strokeColor: color
        )
        circles.append(circle)
    }
    
    func addPolygon(coordinates: [CLLocationCoordinate2D], color: Color) {
        let polygon = PolygonOverlay(
            coordinates: coordinates,
            fillColor: color.withAlphaComponent(0.3),
            strokeColor: color
        )
        polygons.append(polygon)
    }
}
```

### MapCursorModeCoordinator

ATAK-style cursor mode for tactical operations.

```swift
class MapCursorModeCoordinator: ObservableObject {
    @Published var isActive: Bool = false
    @Published var cursorLocation: CLLocationCoordinate2D?
    @Published var showRadialMenu: Bool = false
    
    func activateCursor(at location: CLLocationCoordinate2D) {
        isActive = true
        cursorLocation = location
        showRadialMenu = true
    }
    
    func deactivate() {
        isActive = false
        cursorLocation = nil
        showRadialMenu = false
    }
}
```

---

## Markers & Icons

### EnhancedCoTMarker

Enhanced marker with trail history and metadata.

```swift
struct EnhancedCoTMarker: Identifiable, Equatable {
    let uid: String
    var coordinate: CLLocationCoordinate2D
    var callsign: String
    var type: String               // CoT type (a-f-G, a-h-G, etc.)
    var team: String?
    var affiliation: Affiliation   // Friendly, hostile, neutral, unknown
    var lastUpdate: Date
    
    // Visual properties
    var icon: String               // Icon identifier
    var color: Color               // Team color
    var heading: Double?           // Orientation (degrees)
    
    // Trail
    var trailCoordinates: [CLLocationCoordinate2D] = []
    var trailTimestamps: [Date] = []
    var showTrail: Bool = false
    
    // Status
    var battery: Int?
    var speed: Double?             // m/s
    var altitude: Double?          // meters HAE
    var isStale: Bool {
        Date().timeIntervalSince(lastUpdate) > 300 // 5 minutes
    }
}
```

### Affiliation

Military affiliation classification.

```swift
enum Affiliation: String, Codable {
    case friendly = "f"
    case hostile = "h"
    case neutral = "n"
    case unknown = "u"
    
    var color: Color {
        switch self {
        case .friendly: return .blue
        case .hostile: return .red
        case .neutral: return .green
        case .unknown: return .yellow
        }
    }
}
```

### MarkerView

SwiftUI view for rendering markers.

```swift
struct MarkerView: View {
    let marker: EnhancedCoTMarker
    
    var body: some View {
        ZStack {
            // Icon
            Image(systemName: marker.icon)
                .foregroundColor(marker.color)
                .font(.system(size: 24))
            
            // Heading indicator
            if let heading = marker.heading {
                Image(systemName: "arrowtriangle.up.fill")
                    .rotationEffect(.degrees(heading))
                    .foregroundColor(marker.color)
                    .offset(y: -20)
            }
            
            // Callsign label
            Text(marker.callsign)
                .font(.caption)
                .foregroundColor(.white)
                .padding(4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                .offset(y: 20)
            
            // Stale indicator
            if marker.isStale {
                Circle()
                    .strokeBorder(Color.red, lineWidth: 2)
                    .frame(width: 30, height: 30)
            }
        }
    }
}
```

### MIL-STD-2525 Symbol Mapping

CoT types mapped to military symbols:

| CoT Type | Description | Symbol | Color |
|----------|-------------|--------|-------|
| `a-f-G-E-V` | Friendly Ground Equipment Vehicle | 🚙 | Blue |
| `a-f-G-U-C` | Friendly Ground Unit Combat | 🎖️ | Blue |
| `a-f-A` | Friendly Air | ✈️ | Blue |
| `a-h-G-U-C` | Hostile Ground Unit Combat | ⚔️ | Red |
| `a-h-A` | Hostile Air | ✈️ | Red |
| `a-n-G` | Neutral Ground | 🚶 | Green |
| `a-u-G` | Unknown Ground | ❓ | Yellow |
| `b-m-p-w` | Point Waypoint | 📍 | White |

---

## Map Overlays

### Circle Overlay

Circular area (range rings, geofences).

```swift
struct CircleOverlay: Identifiable {
    let id = UUID()
    var center: CLLocationCoordinate2D
    var radius: Double             // meters
    var fillColor: Color
    var strokeColor: Color
    var strokeWidth: CGFloat = 2.0
}

// Render as MKOverlay
extension CircleOverlay {
    func toMKCircle() -> MKCircle {
        MKCircle(center: center, radius: radius)
    }
    
    func renderer() -> MKCircleRenderer {
        let renderer = MKCircleRenderer(circle: toMKCircle())
        renderer.fillColor = UIColor(fillColor)
        renderer.strokeColor = UIColor(strokeColor)
        renderer.lineWidth = strokeWidth
        return renderer
    }
}
```

### Polygon Overlay

Area boundaries (zones, sectors).

```swift
struct PolygonOverlay: Identifiable {
    let id = UUID()
    var coordinates: [CLLocationCoordinate2D]
    var fillColor: Color
    var strokeColor: Color
    var strokeWidth: CGFloat = 2.0
}

extension PolygonOverlay {
    func toMKPolygon() -> MKPolygon {
        var coords = coordinates
        return MKPolygon(coordinates: &coords, count: coords.count)
    }
}
```

### Polyline Overlay

Lines (routes, tracks, range-bearing).

```swift
struct PolylineOverlay: Identifiable {
    let id = UUID()
    var coordinates: [CLLocationCoordinate2D]
    var strokeColor: Color
    var strokeWidth: CGFloat = 3.0
    var isDashed: Bool = false
}

extension PolylineOverlay {
    func toMKPolyline() -> MKPolyline {
        var coords = coordinates
        return MKPolyline(coordinates: &coords, count: coords.count)
    }
    
    func renderer() -> MKPolylineRenderer {
        let renderer = MKPolylineRenderer(polyline: toMKPolyline())
        renderer.strokeColor = UIColor(strokeColor)
        renderer.lineWidth = strokeWidth
        if isDashed {
            renderer.lineDashPattern = [10, 5]
        }
        return renderer
    }
}
```

### Breadcrumb Trail

Movement history visualization.

```swift
class BreadcrumbTrailService: ObservableObject {
    @Published var trails: [String: [CLLocationCoordinate2D]] = [:]
    
    func addBreadcrumb(for uid: String, at coordinate: CLLocationCoordinate2D) {
        if trails[uid] == nil {
            trails[uid] = []
        }
        trails[uid]?.append(coordinate)
        
        // Limit trail length
        if trails[uid]!.count > 100 {
            trails[uid]?.removeFirst()
        }
    }
    
    func clearTrail(for uid: String) {
        trails[uid] = []
    }
}
```

---

## Tile Sources

### TileSourceType

```swift
enum TileSourceType: String, Codable {
    case standard           // Apple Maps
    case satellite          // Apple Satellite
    case hybrid             // Satellite + labels
    case openStreetMap      // OSM tiles
    case arcGISSatellite    // ArcGIS World Imagery
    case arcGISTopo         // ArcGIS Topographic
    case offline            // Cached tiles
}
```

### OpenStreetMap Tiles

```swift
class OSMTileOverlay: MKTileOverlay {
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        // OSM tile server: {z}/{x}/{y}.png
        let urlString = "https://tile.openstreetmap.org/\(path.z)/\(path.x)/\(path.y).png"
        return URL(string: urlString)!
    }
}

// Usage
let osmOverlay = OSMTileOverlay(urlTemplate: nil)
osmOverlay.canReplaceMapContent = true
mapView.addOverlay(osmOverlay, level: .aboveLabels)
```

### ArcGIS Tile Source

```swift
class ArcGISTileOverlay: MKTileOverlay {
    let serviceType: ArcGISServiceType
    
    enum ArcGISServiceType {
        case satellite      // World_Imagery
        case topographic    // World_Topo_Map
        case streets        // World_Street_Map
    }
    
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let baseURL: String
        switch serviceType {
        case .satellite:
            baseURL = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer"
        case .topographic:
            baseURL = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer"
        case .streets:
            baseURL = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer"
        }
        
        return URL(string: "\(baseURL)/tile/\(path.z)/\(path.y)/\(path.x)")!
    }
}
```

### Offline Tile Cache

```swift
class OfflineTileCache {
    func cacheTile(_ tileData: Data, for path: MKTileOverlayPath) {
        let filename = "\(path.z)_\(path.x)_\(path.y).png"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        try? tileData.write(to: fileURL)
    }
    
    func getCachedTile(for path: MKTileOverlayPath) -> Data? {
        let filename = "\(path.z)_\(path.x)_\(path.y).png"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        return try? Data(contentsOf: fileURL)
    }
}
```

---

## Map Types & Layers

### Map Types

```swift
extension MKMapType {
    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .satellite: return "Satellite"
        case .hybrid: return "Hybrid"
        case .satelliteFlyover: return "3D Satellite"
        case .hybridFlyover: return "3D Hybrid"
        case .mutedStandard: return "Muted"
        @unknown default: return "Unknown"
        }
    }
}
```

### Layer Filtering

```swift
func filterMarkers() -> [EnhancedCoTMarker] {
    markers.filter { marker in
        switch marker.affiliation {
        case .friendly: return showFriendly
        case .hostile: return showHostile
        case .neutral: return showNeutral
        case .unknown: return showUnknown
        }
    }
}
```

---

## User Tracking

### Tracking Modes

```swift
enum MapUserTrackingMode {
    case none               // No tracking
    case follow             // Center on user
    case followWithHeading  // Center + rotate to heading
}
```

### Location Updates

```swift
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var heading: CLHeading?
    
    private let manager = CLLocationManager()
    
    func locationManager(_ manager: CLLocationManager, 
                        didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        
        // Update map region if tracking
        if trackingMode != .none {
            updateMapRegion(to: location!)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, 
                        didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
        
        // Rotate map if followWithHeading
        if trackingMode == .followWithHeading {
            updateMapHeading(to: newHeading.trueHeading)
        }
    }
}
```

---

## Coordinate Systems

### Supported Formats

| Format | Example | Use Case |
|--------|---------|----------|
| **Decimal Degrees** | 37.7749, -122.4194 | GPS, API |
| **Degrees Minutes Seconds** | 37°46'29.6"N 122°25'9.8"W | Navigation |
| **MGRS** | 10SEG1234567890 | Military grid |
| **UTM** | 10S 551620E 4181213N | Survey |

### Coordinate Conversion

```swift
class CoordinateConverter {
    // Lat/Lon to MGRS
    func toMGRS(_ coordinate: CLLocationCoordinate2D) -> String {
        // Implementation using MGRS library
        return "10SEG1234567890"
    }
    
    // Lat/Lon to UTM
    func toUTM(_ coordinate: CLLocationCoordinate2D) -> (zone: Int, easting: Double, northing: Double) {
        let zone = Int((coordinate.longitude + 180) / 6) + 1
        // UTM calculation...
        return (zone: zone, easting: 551620, northing: 4181213)
    }
    
    // Degrees to DMS
    func toDMS(_ coordinate: CLLocationCoordinate2D) -> String {
        let latDegrees = abs(Int(coordinate.latitude))
        let latMinutes = abs(Int((coordinate.latitude - Double(latDegrees)) * 60))
        let latSeconds = abs((coordinate.latitude - Double(latDegrees) - Double(latMinutes)/60) * 3600)
        let latDir = coordinate.latitude >= 0 ? "N" : "S"
        
        let lonDegrees = abs(Int(coordinate.longitude))
        let lonMinutes = abs(Int((coordinate.longitude - Double(lonDegrees)) * 60))
        let lonSeconds = abs((coordinate.longitude - Double(lonDegrees) - Double(lonMinutes)/60) * 3600)
        let lonDir = coordinate.longitude >= 0 ? "E" : "W"
        
        return "\(latDegrees)°\(latMinutes)'\(String(format: "%.1f", latSeconds))\"\(latDir) \(lonDegrees)°\(lonMinutes)'\(String(format: "%.1f", lonSeconds))\"\(lonDir)"
    }
}
```

---

## Performance

### Optimization Techniques

1. **Marker Clustering**
```swift
func clusterMarkers(in region: MKCoordinateRegion) -> [MarkerCluster] {
    // Group nearby markers when zoomed out
    let clusters: [MarkerCluster] = []
    // Implementation...
    return clusters
}
```

2. **Viewport Culling**
```swift
func visibleMarkers(in region: MKCoordinateRegion) -> [EnhancedCoTMarker] {
    markers.filter { marker in
        region.contains(marker.coordinate)
    }
}
```

3. **Lazy Loading**
```swift
// Only load markers within visible region + buffer
let bufferFactor = 1.5
let bufferedRegion = region.expanded(by: bufferFactor)
```

### Performance Metrics

| Operation | Target | Typical |
|-----------|--------|---------|
| Marker render | <16ms | 8-12ms |
| Region update | <100ms | 50-80ms |
| Overlay render | <50ms | 20-40ms |
| Tile load | <500ms | 200-400ms |

---

## Code Examples

### Example 1: Basic Map Setup

```swift
struct BasicMapView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var body: some View {
        Map(coordinateRegion: $region,
            showsUserLocation: true)
    }
}
```

### Example 2: Adding Markers

```swift
Map(coordinateRegion: $region,
    annotationItems: markers) { marker in
        MapAnnotation(coordinate: marker.coordinate) {
            MarkerView(marker: marker)
        }
    }
```

### Example 3: Drawing Circle Overlay

```swift
func addRangeRing(center: CLLocationCoordinate2D, radius: Double) {
    let circle = CircleOverlay(
        center: center,
        radius: radius,
        fillColor: .blue.opacity(0.2),
        strokeColor: .blue
    )
    overlayCoordinator.circles.append(circle)
}
```

### Example 4: Custom Tile Source

```swift
let customTiles = MKTileOverlay(urlTemplate: "https://example.com/tiles/{z}/{x}/{y}.png")
customTiles.canReplaceMapContent = true
mapView.addOverlay(customTiles, level: .aboveLabels)
```

---

## Related Documentation

- **[CoT Messaging](CoTMessaging.md)** - Marker data from CoT events
- **[Networking](Networking.md)** - Real-time marker updates
- **[Architecture](../Architecture.md)** - System design

---

*Last Updated: November 22, 2025*
