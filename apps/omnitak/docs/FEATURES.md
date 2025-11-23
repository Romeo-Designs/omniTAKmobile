# Features Guide

**OmniTAK Mobile Complete Feature Documentation**

This document provides comprehensive documentation for all features in OmniTAK Mobile, including usage instructions, technical details, and configuration options.

---

## Table of Contents

1. [CoT Protocol & TAK Connectivity](#cot-protocol--tak-connectivity)
2. [Map System & Visualization](#map-system--visualization)
3. [Chat & Messaging (GeoChat)](#chat--messaging-geochat)
4. [Position Broadcasting (PLI)](#position-broadcasting-pli)
5. [Emergency Beacon System](#emergency-beacon-system)
6. [Team Management](#team-management)
7. [Waypoints & Route Planning](#waypoints--route-planning)
8. [Drawing Tools](#drawing-tools)
9. [Measurement Tools](#measurement-tools)
10. [Geofencing](#geofencing)
11. [Offline Maps](#offline-maps)
12. [Certificate Management & Security](#certificate-management--security)
13. [Tactical Reports](#tactical-reports)
14. [Meshtastic Integration](#meshtastic-integration)
15. [Data Packages](#data-packages)
16. [Additional Features](#additional-features)

---

## CoT Protocol & TAK Connectivity

### Overview

The Cursor-on-Target (CoT) protocol is the foundation of TAK interoperability. OmniTAK Mobile implements full CoT message parsing, generation, and exchange with TAK servers.

### Supported CoT Event Types

| Type Prefix | Category | Description | Examples |
|-------------|----------|-------------|----------|
| **a-f-*** | Friendly Units | Blue force positions | `a-f-G-U-C-I` (Infantry) |
| **a-h-*** | Hostile Units | Red force positions | `a-h-G-E-V-A` (Armor) |
| **a-n-*** | Neutral Units | Green force positions | `a-n-G` (Neutral) |
| **a-u-*** | Unknown Units | Yellow force positions | `a-u-G` (Unknown) |
| **b-t-f** | Chat/Text | GeoChat messages | `b-t-f` (Text message) |
| **b-a-*** | Alerts | Emergency alerts | `b-a-o-can` (Cancel), `b-a-o-tac` (Emergency) |
| **b-m-p-w** | Waypoints | Map waypoints | `b-m-p-w` (Waypoint marker) |

### CoT Message Structure

**Example Position Update:**
```xml
<?xml version="1.0"?>
<event version="2.0" uid="ANDROID-12345678" 
       type="a-f-G-U-C-I" time="2025-11-23T10:30:00Z" 
       start="2025-11-23T10:30:00Z" stale="2025-11-23T10:33:00Z" 
       how="m-g">
    <point lat="38.8977" lon="-77.0365" hae="50.0" ce="10.0" le="5.0"/>
    <detail>
        <contact callsign="ALPHA-1" endpoint="192.168.1.100:4242:tcp"/>
        <__group name="Cyan" role="Team Member"/>
        <precisionlocation altsrc="GPS" geopointsrc="GPS"/>
        <track speed="2.5" course="45.0"/>
        <status battery="85"/>
    </detail>
</event>
```

**Key Fields:**
- **uid** - Unique identifier for the entity
- **type** - CoT type string (determines icon and affiliation)
- **time** - Event timestamp (ISO 8601 UTC)
- **start** - Event validity start
- **stale** - When event becomes stale (typically start + 3 minutes)
- **how** - How the position was obtained (`m-g` = GPS)
- **point** - Geographic location
  - `lat/lon` - Coordinates in decimal degrees
  - `hae` - Height above ellipsoid (meters)
  - `ce` - Circular error (horizontal accuracy, meters)
  - `le` - Linear error (vertical accuracy, meters)
- **detail** - Extensible metadata
  - `contact` - Callsign and network endpoint
  - `__group` - Team assignment
  - `track` - Speed and course
  - `status` - Device status

### Server Configuration

**Supported Protocols:**
- **TCP** - Unencrypted TCP connection
- **UDP** - Connectionless UDP (less common)
- **TLS** - Encrypted TCP with TLS 1.2/1.3

**Configuration Fields:**
```swift
struct TAKServer {
    var name: String              // Display name
    var host: String              // IP or hostname
    var port: UInt16              // Port number (8087, 8089)
    var protocolType: String      // "tcp", "udp", "tls"
    var useTLS: Bool              // Enable TLS encryption
    var certificateName: String?  // Client certificate (P12)
    var allowLegacyTLS: Bool      // TLS 1.0/1.1 (not recommended)
}
```

**Common TAK Server Ports:**
- **8087** - TCP (unencrypted)
- **8089** - TLS (encrypted with client certificate)
- **4242** - Alternative UDP port

### Multi-Server Federation

OmniTAK supports connecting to multiple TAK servers simultaneously.

**Use Cases:**
- Connect to multiple tactical networks
- Bridge between classified and unclassified networks
- Redundant connectivity for reliability

**Behavior:**
- Outbound CoT messages broadcast to ALL connected servers
- Inbound messages from any server processed identically
- Each server has independent connection state
- Automatic reconnection on failure

**Code Example:**
```swift
// Add multiple servers
let server1 = TAKServer(name: "Primary", host: "192.168.1.10", port: 8089, useTLS: true)
let server2 = TAKServer(name: "Secondary", host: "10.0.0.50", port: 8087, useTLS: false)

ServerManager.shared.addServer(server1)
ServerManager.shared.addServer(server2)

// Connect to both
ServerManager.shared.connectToServer(server1)
ServerManager.shared.connectToServer(server2)

// Messages sent to both servers
TAKService.shared.broadcastCoT(cotXML)
```

### Connection Status Monitoring

**Connection States:**
- **Disconnected** - No connection established
- **Connecting** - Connection in progress
- **Connected** - Active connection, exchanging data
- **Error** - Connection failed or lost

**Status Indicators:**
- Green dot = Connected
- Yellow dot = Connecting
- Red dot = Disconnected/Error
- Message counters (sent/received)

---

## Map System & Visualization

### Map Modes

| Mode | Description | Activation |
|------|-------------|------------|
| **Normal** | Standard map interaction (pan, zoom) | Default |
| **Cursor** | Crosshair cursor for precise targeting | Tap cursor button |
| **Drawing** | Active drawing mode (line, polygon, etc.) | Select drawing tool |
| **Measurement** | Measure distances and bearings | Tap measure tool |
| **Range Bearing** | Calculate range and bearing to point | Long press + select |
| **Point Drop** | Drop markers at location | Tap point drop button |
| **Track Recording** | Record breadcrumb trail | Enable track recording |

### MIL-STD-2525 Symbology

**Affiliation Frames:**

```
Friendly (Blue)          Hostile (Red)           Neutral (Green)         Unknown (Yellow)
┌──────────┐             ◆────────◆              ┌──────────┐             ✦────────✦
│ Rectangle │            │  Diamond │             │  Square  │             │Quatrefoil│
│  (Blue)  │            │  (Red)   │             │ (Green)  │             │ (Yellow) │
└──────────┘             ◆────────◆              └──────────┘             ✦────────✦
```

**Unit Types (SF Symbols):**
- `person.fill` - Infantry
- `car.fill` - Wheeled vehicle
- `airplane` - Aviation
- `antenna.radiowaves.left.and.right` - Communications
- `scope` - Reconnaissance
- Custom icons for specialized units

**Echelon Indicators:**
- No indicator - Individual
- **•** - Team/Crew (2-4 personnel)
- **••** - Squad (8-13 personnel)
- **•••** - Section/Platoon (16-44 personnel)
- **I** - Company (62-190 personnel)
- **II** - Battalion (300-1000 personnel)
- **III** - Regiment/Brigade (3000-5000 personnel)
- **X** - Division (10,000-15,000 personnel)
- **XX** - Corps (20,000-45,000 personnel)
- **XXX** - Army (50,000-200,000 personnel)

**Modifiers:**
- **HQ** - Headquarters (staff indicator)
- **TF** - Task Force
- **FD** - Feint/Dummy (deception)

**Example Symbols:**

```
     ••                    HQ
┌─────────┐           ┌─────────┐
│  Infantry│          │ Infantry│
│  [icon] │          │ [icon]  │
└─────────┘           └─────────┘
  ALPHA-1              COMMAND-1
(Friendly Squad)    (Friendly HQ)

     I                     X
 ◆─────────◆           ◆─────────◆
 │  Armor  │           │ Infantry│
 │ [tank]  │           │ [icon]  │
 ◆─────────◆           ◆─────────◆
   ENEMY-1              ENEMY-DIV
(Hostile Company)    (Hostile Division)
```

### Coordinate Display Systems

**Supported Formats:**
1. **Decimal Degrees (DD):** `38.8977°N, 77.0365°W`
2. **Degrees Decimal Minutes (DDM):** `38°53.862'N, 77°02.190'W`
3. **Degrees Minutes Seconds (DMS):** `38°53'51.7"N, 77°02'11.4"W`
4. **MGRS (Military Grid Reference System):** `18SUJ2337506390`

**MGRS Format:**
- **18S** - Grid zone designation (GZD)
- **UJ** - 100km grid square
- **23375** - Easting (5-digit precision = 1 meter)
- **06390** - Northing (5-digit precision = 1 meter)

**Switching Formats:**
- Tap coordinate display in status bar
- Select preferred format in Settings

### Map Layers & Overlays

**Base Map Layers:**
- **Standard** - Apple Maps standard view
- **Satellite** - Satellite imagery
- **Hybrid** - Satellite with road/label overlay
- **Custom Tile Sources:**
  - ArcGIS World Topo Map
  - ArcGIS World Imagery
  - OpenStreetMap
  - Offline cached tiles

**Overlay Layers:**
- **MGRS Grid** - Military grid overlay with labels
- **Range Rings** - Distance rings around points (customizable radii)
- **Compass Rose** - North indicator
- **Scale Bar** - Distance scale
- **Breadcrumb Trails** - Unit movement history
- **Geofence Boundaries** - Active geofences
- **User Drawings** - Tactical graphics

**Layer Controls:**
```swift
// Toggle MGRS grid
MapStateManager.shared.showMGRSGrid = true

// Add range rings (1km, 5km, 10km)
MapStateManager.shared.addRangeRings(
    center: coordinate,
    radii: [1000, 5000, 10000]
)

// Show breadcrumb trails
MapStateManager.shared.showBreadcrumbs = true
```

### 3D Terrain Visualization

**Features:**
- Elevation-aware terrain rendering
- Tilt and rotation controls
- Hillshade rendering
- Line-of-sight analysis with terrain occlusion

**Activation:**
- Long press on map type button
- Select "3D Terrain" mode
- Use two-finger gestures to tilt/rotate

---

## Chat & Messaging (GeoChat)

### GeoChat Protocol

GeoChat is TAK's location-aware text messaging system. Messages are exchanged as CoT events with chat metadata.

**GeoChat CoT Structure:**
```xml
<?xml version="1.0"?>
<event version="2.0" uid="GeoChat.ANDROID-12345678.All Chat Rooms.UUID" 
       type="b-t-f" time="2025-11-23T10:30:00Z" 
       start="2025-11-23T10:30:00Z" stale="2025-11-23T10:33:00Z">
    <point lat="38.8977" lon="-77.0365" hae="50.0" ce="10.0" le="5.0"/>
    <detail>
        <__chat parent="RootContactGroup" groupOwner="false" 
                messageId="UUID" chatroom="All Chat Rooms" 
                id="ANDROID-12345678" senderCallsign="ALPHA-1">
            <chatgrp uid0="ANDROID-12345678" uid1="All Chat Rooms" id="All Chat Rooms"/>
        </__chat>
        <link uid="ANDROID-12345678" production_time="2025-11-23T10:30:00Z" 
              type="a-f-G-U-C-I" parent_callsign="ALPHA-1" relation="p-p"/>
        <remarks source="BAO.F.ATAK.ANDROID-12345678" 
                 to="All Chat Rooms" time="2025-11-23T10:30:00Z">
            Hello from OmniTAK Mobile!
        </remarks>
    </detail>
</event>
```

### Message Types

**Direct Messages (1-on-1):**
- Private conversation between two users
- `chatroom` attribute contains recipient UID
- Only visible to sender and recipient

**Group Chat (All Chat Rooms):**
- Broadcast to all connected users
- `chatroom="All Chat Rooms"`
- Visible to everyone on the network

**Custom Chat Rooms:**
- Named rooms for team-specific communication
- Custom `chatroom` attribute
- Users must join room to see messages

### Message Status Tracking

**Status States:**
```swift
enum MessageStatus {
    case pending    // Created, not yet sent
    case sending    // Transmission in progress
    case sent       // Successfully sent to TAK server
    case delivered  // Acknowledged by recipient (if supported)
    case failed     // Transmission failed
}
```

**Visual Indicators:**
- ⏳ Pending (gray)
- ⬆️ Sending (blue, animated)
- ✓ Sent (blue)
- ✓✓ Delivered (blue)
- ❌ Failed (red)

**Retry Mechanism:**
- Failed messages queued for retry
- Automatic retry on reconnection
- Manual retry option
- Maximum 3 retry attempts

### Photo Attachments

**Supported Formats:**
- JPEG, PNG, HEIC
- Maximum size: 10 MB per image
- Automatic compression for large images

**Attachment Flow:**
1. Select image from photo library or camera
2. Image attached to chat message
3. CoT message includes image data (Base64 encoded)
4. Recipient decodes and displays image

**CoT Structure with Image:**
```xml
<detail>
    <__chat ...>
        <chatgrp .../>
    </__chat>
    <link .../>
    <remarks>Photo attached</remarks>
    <image>
        <data>BASE64_ENCODED_IMAGE_DATA</data>
        <mime>image/jpeg</mime>
    </image>
</detail>
```

### Location Sharing

All GeoChat messages include sender's location in the `<point>` element.

**Recipient Experience:**
- Tap message to view location on map
- "Navigate to sender" option
- Location timestamp displayed

### Conversation Management

**Features:**
- Unread message badges
- Last message preview
- Participant online/offline status
- Conversation search and filtering
- Archive/delete conversations
- Block contacts

**Data Persistence:**
- Chat history saved locally
- Automatic sync across app launches
- Configurable history retention (default: 30 days)

---

## Position Broadcasting (PLI)

### Overview

Position Location Information (PLI) is automatic periodic broadcasting of your GPS location to the TAK network.

### Configuration

**Settings:**
```swift
// Update interval (seconds)
PositionBroadcastService.shared.updateInterval = 30  // Default: 30s

// Stale time (seconds)
PositionBroadcastService.shared.staleTime = 180  // Default: 3 minutes

// Enable/disable
PositionBroadcastService.shared.isEnabled = true

// User identity
PositionBroadcastService.shared.callsign = "ALPHA-1"
PositionBroadcastService.shared.teamColor = .cyan
PositionBroadcastService.shared.teamRole = "Team Lead"
```

**Recommended Intervals:**
- **Stationary:** 60-120 seconds
- **Walking:** 30-60 seconds
- **Vehicle:** 10-30 seconds
- **Aircraft:** 5-10 seconds
- **Emergency:** 5 seconds

### Generated CoT

**Position Update Message:**
```xml
<event version="2.0" uid="OMNITAK-IOS-DEVICE-UUID" 
       type="a-f-G-E-S" time="2025-11-23T10:30:00Z" 
       start="2025-11-23T10:30:00Z" stale="2025-11-23T10:33:00Z" 
       how="m-g">
    <point lat="38.8977" lon="-77.0365" hae="50.0" ce="10.0" le="5.0"/>
    <detail>
        <contact callsign="ALPHA-1" endpoint="*:-1:stcp"/>
        <__group name="Cyan" role="Team Lead"/>
        <precisionlocation altsrc="GPS" geopointsrc="GPS"/>
        <track speed="2.5" course="45.0"/>
        <status battery="85"/>
        <takv platform="OmniTAK Mobile" version="1.2.0" device="iPhone 15 Pro" os="iOS 17.0"/>
    </detail>
</event>
```

### Background Broadcasting

**iOS Background Modes:**
- Location updates (continuous)
- Background task completion (finite time)

**Limitations:**
- iOS may suspend broadcasting if app backgrounded for extended period
- Enable "Location Always" permission for best results
- Battery optimization may reduce update frequency

**Recommendations:**
- Keep app in foreground during operations
- Use Low Power Mode with caution
- Monitor battery level

---

## Emergency Beacon System

### Emergency Types

```swift
enum EmergencyType {
    case alert911       // 911 Emergency - life-threatening
    case inContact      // In Contact - need immediate assistance
    case alert          // General alert - urgent but not critical
    case cancel         // Cancel emergency
}
```

### Emergency Activation

**UI:**
- Red "EMERGENCY" button (prominent placement)
- Hold-to-activate (prevent accidental activation)
- Confirmation dialog with type selection
- Visual and haptic feedback

**Behavior:**
1. Immediate CoT broadcast with emergency type
2. Repeated broadcasting every 30 seconds
3. Visual indicator (flashing red border on map)
4. Audio alert (optional, configurable)
5. Prevents app from sleeping
6. Continues until manually canceled

### Emergency CoT Messages

**911 Emergency:**
```xml
<event version="2.0" uid="OMNITAK-IOS-DEVICE-UUID" 
       type="b-a-o-tac" time="2025-11-23T10:30:00Z" 
       start="2025-11-23T10:30:00Z" stale="2025-11-23T10:33:00Z">
    <point lat="38.8977" lon="-77.0365" hae="50.0" ce="10.0" le="5.0"/>
    <detail>
        <emergency type="911"/>
        <contact callsign="ALPHA-1"/>
        <link uid="OMNITAK-IOS-DEVICE-UUID" type="a-f-G-E-S"/>
        <remarks>Emergency beacon activated</remarks>
    </detail>
</event>
```

**In Contact:**
```xml
<event type="b-a-o-can" ...>  <!-- "can" = troops in contact -->
    <detail>
        <emergency type="In Contact"/>
        <contact callsign="ALPHA-1"/>
        <remarks>Need immediate assistance</remarks>
    </detail>
</event>
```

**Cancel Emergency:**
```xml
<event type="b-a-o-can" ...>  <!-- "can" = cancel -->
    <detail>
        <emergency type="cancel"/>
        <contact callsign="ALPHA-1"/>
        <remarks>Emergency situation resolved</remarks>
    </detail>
</event>
```

### Safety Features

**Fail-Safes:**
- Emergency state persists across app restart
- Auto-resume broadcasting if connection lost and restored
- Warning if attempting to close app during emergency
- Emergency log saved locally

**Testing Mode:**
- "Test Emergency Beacon" option in settings
- Sends emergency CoT with `<test>true</test>` tag
- No actual alert triggered on receiving end

---

## Team Management

### Team Structure

```swift
struct Team {
    var name: String              // Team name
    var color: TeamColor          // Visual identifier
    var members: [TeamMember]     // Team roster
}

struct TeamMember {
    let uid: String               // CoT UID
    var callsign: String          // Display name
    var role: TeamRole            // Team function
    var coordinate: CLLocationCoordinate2D?  // Last known position
    var isOnline: Bool            // Connection status
    var lastSeen: Date            // Last position update
}
```

### Team Colors (ATAK Standard)

| Color | Hex | Usage |
|-------|-----|-------|
| **Cyan** | `#00FFFF` | Default team |
| **Green** | `#00FF00` | Team 2 |
| **Yellow** | `#FFFF00` | Team 3 |
| **Magenta** | `#FF00FF` | Team 4 |
| **Red** | `#FF0000` | Team 5 |
| **Blue** | `#0000FF` | Team 6 |
| **White** | `#FFFFFF` | Team 7 |
| **Orange** | `#FFA500` | Team 8 |
| **Purple** | `#800080` | Team 9 |
| **Dark Green** | `#006400` | Team 10 |

### Team Roles

- **Team Lead** - Primary decision maker
- **Team Member** - Standard role
- **Forward Observer** - Reports intel
- **Medic** - Medical support
- **Communications** - Radio operator
- **Support** - Logistics/support role

### Team CoT Encoding

**Team Information in CoT:**
```xml
<detail>
    <__group name="Cyan" role="Team Lead"/>
</detail>
```

**Automatic Features:**
- Team members' markers color-coded on map
- Team roster auto-populated from CoT traffic
- Online/offline status from stale times
- Last seen timestamp tracking

### Team Management UI

**Features:**
- Create/edit/delete teams
- Assign members to teams
- View team roster with status
- Filter map by team
- Team-specific chat rooms
- Team statistics (online count, last activity)

---

## Waypoints & Route Planning

### Waypoint Creation

**Methods:**
1. **Long press on map** - Drop waypoint at location
2. **Search address** - Enter address or coordinates
3. **Current location** - Waypoint at GPS position
4. **Import from file** - KML/KMZ import

**Waypoint Properties:**
```swift
struct Waypoint {
    var name: String                     // Waypoint name
    var coordinate: CLLocationCoordinate2D  // Location
    var elevation: Double?               // Altitude (meters)
    var notes: String?                   // Description
    var category: WaypointCategory       // Type (checkpoint, objective, etc.)
    var color: Color                     // Visual color
    var icon: String                     // Icon name
}
```

**Waypoint Categories:**
- Checkpoint
- Objective
- Rally Point
- Landing Zone (LZ)
- Pickup Zone (PZ)
- Observation Post (OP)
- Target
- Hazard
- Custom

### Route Planning

**Route Creation:**
```swift
struct Route {
    var name: String
    var waypoints: [RouteWaypoint]
    var status: RouteStatus        // planning/active/completed
    var totalDistance: Double      // meters
    var estimatedTime: TimeInterval  // seconds
    var color: Color
}

struct RouteWaypoint {
    var coordinate: CLLocationCoordinate2D
    var name: String
    var order: Int                 // Sequence in route
    var instruction: String?       // Turn-by-turn instruction
    var distanceToNext: Double?    // meters to next waypoint
}
```

**Route Planning Tools:**
- Drag-and-drop waypoint reordering
- Auto-calculate distances
- Estimated time calculation (based on speed profile)
- Elevation profile visualization
- Reverse route direction
- Duplicate/copy routes
- Share route via CoT

### Navigation

**Turn-by-Turn Navigation:**
```
┌─────────────────────────────┐
│  ALPHA-1 → Checkpoint 2     │
│                             │
│  Next: Turn right in 250m   │
│  Distance: 1.2 km           │
│  ETA: 5 minutes             │
│  Bearing: 045°              │
│                             │
│  [◀ Prev]  [Stop]  [Next ▶] │
└─────────────────────────────┘
```

**Features:**
- Auto-advance to next waypoint
- Distance and bearing to waypoint
- ETA calculation
- Off-route warnings
- Voice guidance (optional)
- Route completion notification

**Voice Guidance:**
- "In 500 meters, turn right"
- "Arriving at checkpoint"
- "You have reached your destination"
- "You are off route. Rerouting..."

---

## Drawing Tools

### Drawing Modes

```swift
enum DrawingMode {
    case marker      // Single point marker
    case line        // Multi-segment line
    case circle      // Center + radius circle
    case polygon     // Closed multi-point shape
    case freehand    // Free drawing (future)
}
```

### Drawing Workflow

**Creating Drawings:**

**1. Marker:**
- Select marker tool
- Tap map location
- Marker placed immediately
- Customize color, label, icon

**2. Line:**
- Select line tool
- Tap map to add points
- Tap existing point to finish
- Customize color, width, style

**3. Circle:**
- Select circle tool
- Tap center point
- Drag to set radius OR enter radius value
- Customize color, fill opacity

**4. Polygon:**
- Select polygon tool
- Tap to add vertices
- Close polygon by tapping first vertex
- Customize color, fill, border

### Drawing Properties

```swift
struct Drawing {
    var name: String
    var color: DrawingColor
    var lineWidth: CGFloat        // For lines/polygons
    var fillOpacity: Double       // For circles/polygons (0-1)
    var dashPattern: [CGFloat]?   // Dashed line (nil = solid)
    var label: String?
}

enum DrawingColor: String, CaseIterable {
    case red, blue, green, yellow, orange, purple, black, white
    
    var cgColor: CGColor {
        // Color conversions
    }
}
```

### Drawing Management

**Operations:**
- **Edit** - Modify points, colors, labels
- **Move** - Reposition entire drawing
- **Duplicate** - Copy drawing
- **Delete** - Remove from map
- **Hide/Show** - Toggle visibility
- **Export** - Save as KML/KMZ
- **Share** - Send via CoT

**Drawing List:**
- View all drawings
- Search/filter by name, color, type
- Bulk operations (show all, hide all, delete all)
- Sort by name, date created, type

### Drawing CoT Encoding

**Line/Polygon CoT:**
```xml
<event type="u-d-f" uid="DRAWING-UUID" ...>
    <point lat="38.8977" lon="-77.0365" hae="0" ce="9999999" le="9999999"/>
    <detail>
        <shape>
            <polyline closed="false">
                <vertex lat="38.8977" lon="-77.0365" hae="0"/>
                <vertex lat="38.8980" lon="-77.0360" hae="0"/>
                <vertex lat="38.8975" lon="-77.0355" hae="0"/>
            </polyline>
        </shape>
        <stroke color="-65536" weight="3"/>  <!-- Red, 3px -->
        <labels_on value="true"/>
        <__labels>
            <label text="Route Alpha"/>
        </__labels>
    </detail>
</event>
```

---

## Measurement Tools

### Distance Measurement

**Tool:** Measure straight-line distance between two or more points.

**Usage:**
1. Select measurement tool
2. Tap start point
3. Tap end point (or multiple intermediate points)
4. View total distance

**Display:**
- Cumulative distance (total)
- Segment distances (between each pair)
- Units: meters, kilometers, feet, miles, nautical miles

**Features:**
- Real-time distance updates as you drag points
- Elevation-aware distance (3D distance if elevation data available)
- Copy measurement to clipboard

### Bearing Calculation

**Tool:** Calculate azimuth/bearing from one point to another.

**Usage:**
1. Select bearing tool
2. Tap start point
3. Tap end point
4. View bearing

**Display:**
- True bearing (0-360°)
- Magnetic bearing (if declination known)
- Back bearing (reciprocal)

**Formats:**
- **Degrees:** `045°`
- **Mils:** `800 mils`
- **Compass:** `NE` (Northeast)

### Area Calculation

**Tool:** Calculate area enclosed by a polygon.

**Usage:**
1. Select area tool
2. Tap vertices to create polygon
3. Close polygon
4. View area

**Units:**
- Square meters (m²)
- Square kilometers (km²)
- Square feet (ft²)
- Acres
- Hectares

### Range & Bearing

**Tool:** Combined distance and bearing from your current position to a target.

**Usage:**
1. Long press on map
2. Select "Range & Bearing" from radial menu
3. View range and bearing in HUD

**HUD Display:**
```
┌─────────────────────────┐
│  Range & Bearing        │
│                         │
│  Distance: 2.5 km       │
│  Bearing:  045° (NE)    │
│  Elevation: +120m       │
│                         │
│  [Center] [Clear]       │
└─────────────────────────┘
```

### Elevation Profile

**Tool:** Visualize terrain elevation along a path.

**Usage:**
1. Create route or measurement line
2. Select "Elevation Profile"
3. View profile graph

**Profile Graph:**
```
Elevation (m)
  800 ┤     ╱╲
  700 ┤    ╱  ╲     ╱╲
  600 ┤   ╱    ╲   ╱  ╲
  500 ┤  ╱      ╲ ╱    ╲
  400 ┤ ╱        ╲╱      ╲___
      └─────────────────────── Distance (km)
      0    2    4    6    8
```

**Data Displayed:**
- Min/max elevation
- Elevation gain/loss
- Average grade
- Steepest section

**Data Source:**
- Apple's elevation API
- External elevation service (USGS, SRTM)
- Cached elevation data

---

## Geofencing

### Geofence Types

```swift
enum GeofenceShape {
    case circle(center: CLLocationCoordinate2D, radius: Double)
    case polygon(coordinates: [CLLocationCoordinate2D])
}
```

### Creating Geofences

**Circle Geofence:**
1. Long press on map
2. Select "Create Geofence"
3. Choose "Circle"
4. Set radius (meters)
5. Name and configure

**Polygon Geofence:**
1. Select geofence tool
2. Choose "Polygon"
3. Tap vertices on map
4. Close polygon
5. Name and configure

### Geofence Configuration

```swift
struct Geofence {
    var name: String
    var shape: GeofenceShape
    var isActive: Bool            // Monitor or ignore
    var notifyOnEntry: Bool       // Alert when entering
    var notifyOnExit: Bool        // Alert when exiting
    var soundAlert: Bool          // Play sound
    var color: Color
    var notes: String?
}
```

### Monitoring & Alerts

**Entry Alert:**
```
┌─────────────────────────────────┐
│  🟢 Geofence Entry               │
│                                 │
│  You entered: "Base Perimeter"  │
│  Time: 10:30:45                 │
│                                 │
│  [View on Map]  [Dismiss]       │
└─────────────────────────────────┘
```

**Exit Alert:**
```
┌─────────────────────────────────┐
│  🔴 Geofence Exit                │
│                                 │
│  You exited: "Base Perimeter"   │
│  Time: 14:22:18                 │
│                                 │
│  [View on Map]  [Dismiss]       │
└─────────────────────────────────┘
```

### Geofence Status Tracking

**Tracked Data:**
- Current status (inside/outside)
- Entry time (if inside)
- Dwell time (time spent inside)
- Entry/exit history
- Total time inside (cumulative)

**Dwell Time Display:**
```
Geofence: Base Perimeter
Status: Inside
Entry Time: 10:30:45
Dwell Time: 3h 24m 15s
Total Time (24h): 8h 15m 30s
```

### Geofence Sharing

**Export Geofence:**
- Share as CoT message
- Export as KML/KMZ
- Send to team members

**Geofence CoT:**
```xml
<event type="u-d-f" uid="GEOFENCE-UUID" ...>
    <point lat="38.8977" lon="-77.0365" hae="0" ce="9999999" le="9999999"/>
    <detail>
        <shape>
            <ellipse major="1000" minor="1000" angle="0"/>  <!-- Circle, 1000m radius -->
        </shape>
        <stroke color="-16776961"/>  <!-- Blue -->
        <__geofence name="Base Perimeter" active="true"/>
    </detail>
</event>
```

---

## Offline Maps

### Overview

Offline maps allow operation without internet connectivity by pre-downloading map tiles.

### Downloading Regions

**Region Configuration:**
```swift
struct OfflineMapRegion {
    var name: String
    var coordinate: CLLocationCoordinate2D  // Center
    var region: MKCoordinateRegion          // Bounds
    var minZoom: Int                        // Min zoom level (e.g., 10)
    var maxZoom: Int                        // Max zoom level (e.g., 16)
    var totalTiles: Int                     // Estimated tile count
    var downloadedTiles: Int                // Progress
    var isComplete: Bool
}
```

**Download Process:**
1. Navigate to desired location on map
2. Tap "Offline Maps"
3. Tap "Define Region"
4. Adjust bounds and zoom levels
5. View tile count estimate
6. Tap "Download"
7. Monitor progress

**Tile Calculation:**
```
Tiles = Σ(zoom=minZoom to maxZoom) [4^zoom × area_fraction]

Example:
  Area: 10km × 10km
  Zoom levels: 10-16
  Estimated tiles: ~85,000
  Estimated size: 2.1 GB (at 25KB/tile)
```

### Storage Management

**Storage Locations:**
```
Documents/
└── OfflineMaps/
    ├── regions.json          // Region metadata
    └── [region-uuid]/
        └── tiles/
            └── [zoom]/
                └── [x]/
                    └── [y].png
```

**Operations:**
- View total storage used
- Delete individual regions
- Refresh expired tiles
- Export/import region definitions

**Storage Limits:**
- iOS limits app storage based on device capacity
- Warn if download exceeds 1 GB
- Automatic cleanup of oldest tiles if storage full

### Offline Tile Serving

**Tile Request Flow:**
```
Map requests tile (zoom, x, y)
    │
    ▼
Check offline cache
    │
    ├─ Found? ──► Serve cached tile
    │
    └─ Not found? ──► Fetch from network (if online)
                       └─► Cache for future use
```

**Tile Overlay:**
```swift
class OfflineTileOverlay: MKTileOverlay {
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let filePath = documentsDirectory
            .appendingPathComponent("OfflineMaps")
            .appendingPathComponent(regionID.uuidString)
            .appendingPathComponent("tiles")
            .appendingPathComponent("\(path.z)")
            .appendingPathComponent("\(path.x)")
            .appendingPathComponent("\(path.y).png")
        
        if FileManager.default.fileExists(atPath: filePath.path) {
            return filePath
        } else {
            // Fall back to online tile
            return onlineTileURL(path)
        }
    }
}
```

---

## Certificate Management & Security

### Client Certificates

**Supported Formats:**
- **P12 (PKCS#12)** - Certificate + private key
- **PEM** - Certificate only (if private key separate)

**Import Methods:**
1. **Files App** - Select P12 file, share to OmniTAK
2. **AirDrop** - Receive P12 from another device
3. **QR Code** - Scan QR code with enrollment data
4. **Email** - Open attachment in OmniTAK

**Import Workflow:**
```
Select P12 file
    │
    ▼
Enter password (if encrypted)
    │
    ▼
Extract certificate and private key
    │
    ▼
Save to Keychain
    │
    ▼
Available for TAK server authentication
```

### Keychain Storage

**Security:**
- Certificates stored in iOS Keychain (secure enclave)
- Encrypted at rest
- Requires device unlock for access
- Protected by iOS biometric authentication

**Keychain Operations:**
```swift
// Save certificate
func saveCertificate(data: Data, password: String, name: String) -> Bool {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: name,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
    ]
    
    SecItemDelete(query as CFDictionary)  // Delete existing
    let status = SecItemAdd(query as CFDictionary, nil)
    return status == errSecSuccess
}

// Load certificate
func loadCertificate(name: String) -> Data? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: name,
        kSecReturnData as String: true
    ]
    
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    
    return (status == errSecSuccess) ? result as? Data : nil
}
```

### QR Code Enrollment

**QR Code Format:**
```json
{
  "serverUrl": "https://tak.example.com:8089",
  "certificate": "BASE64_ENCODED_P12",
  "password": "certificate_password",
  "callsign": "ALPHA-1"
}
```

**Enrollment Process:**
1. TAK administrator generates QR code
2. User taps "Enroll via QR"
3. Scan QR code with camera
4. Parse enrollment data
5. Import certificate
6. Configure server connection
7. Auto-connect

### TLS Configuration

**TLS Version Support:**
- **TLS 1.3** (recommended)
- **TLS 1.2** (widely supported)
- **TLS 1.1** (legacy, disabled by default)
- **TLS 1.0** (legacy, disabled by default)

**Legacy TLS Warning:**
```
⚠️ Warning: Legacy TLS Enabled

TLS 1.0 and 1.1 have known security 
vulnerabilities. Only enable if 
required for legacy TAK servers.

Recommended: Upgrade TAK server to 
support TLS 1.2 or higher.
```

**Server Certificate Verification:**
- **Enabled (Default)** - Verify server certificate against system trust store
- **Disabled** - Accept self-signed certificates (common for tactical deployments)

**Self-Signed CA Support:**
- Import custom CA certificate
- Add to system trust store
- All certificates signed by CA will be trusted

---

## Tactical Reports

### Report Types

OmniTAK Mobile supports generation of standardized military tactical reports:

1. **SPOTREP** (Spot Report)
2. **SALUTE** Report
3. **MEDEVAC** Request (9-line)
4. **CAS Request** (Close Air Support)
5. **Custom Reports**

### SPOTREP (Spot Report)

**Purpose:** Report immediate intelligence of tactical significance.

**Format:**
```
Line 1: DTG (Date-Time Group)
Line 2: Location (MGRS or Lat/Lon)
Line 3: Activity observed
Line 4: Number and type of enemy/equipment
Line 5: Unit identification
Line 6: Time of observation
Line 7: Equipment
Line 8: Assessment and narrative
Line 9: Reporting unit
```

**Example:**
```
1. 231030ZNOV2025
2. 18SUJ2337506390
3. Enemy patrol observed moving north
4. 8-10 personnel, small arms
5. Unknown unit, possible local militia
6. 231025ZNOV2025
7. AK-47 rifles, one RPG
8. Patrol appears to be conducting reconnaissance
9. ALPHA-1
```

**CoT Transmission:**
- Sent as `b-r-s` (report-SPOTREP) type
- Includes location of observation
- Formatted text in `<remarks>` element

### SALUTE Report

**Purpose:** Standardized format for intelligence reports.

**Acronym:**
- **S** - Size (number of personnel/equipment)
- **A** - Activity (what they're doing)
- **L** - Location (where observed)
- **U** - Unit (identification)
- **T** - Time (when observed)
- **E** - Equipment (weapons, vehicles)

**UI:**
```
┌─────────────────────────────────┐
│  SALUTE Report                  │
├─────────────────────────────────┤
│  Size: [          ]             │
│  Activity: [                 ]  │
│  Location: [Use current] [Pin]  │
│  Unit: [             ]          │
│  Time: [231030ZNOV25] [Now]     │
│  Equipment: [                ]  │
│                                 │
│  Additional Info:               │
│  [                           ]  │
│  [                           ]  │
│                                 │
│  [Cancel]  [Send to TAK]        │
└─────────────────────────────────┘
```

### MEDEVAC Request (9-Line)

**Purpose:** Request medical evacuation for casualties.

**9-Line Format:**
```
Line 1: Location of pickup site (MGRS)
Line 2: Radio frequency and call sign
Line 3: Number of patients by precedence
  A. Urgent
  B. Priority
  C. Routine
Line 4: Special equipment required
  A. None
  B. Hoist
  C. Extraction equipment
  D. Ventilator
Line 5: Number of patients by type
  A. Litter
  B. Ambulatory
Line 6: Security at pickup site
  A. No enemy troops
  B. Possible enemy troops
  C. Enemy troops in area
  D. Enemy troops in area (armed escort required)
Line 7: Method of marking pickup site
  A. Panels
  B. Pyrotechnic signal
  C. Smoke signal
  D. None
  E. Other
Line 8: Patient nationality and status
  A. US Military
  B. US Civilian
  C. Non-US Military
  D. Non-US Civilian
  E. EPW (Enemy Prisoner of War)
Line 9: NBC contamination
  A. None
  B. Chemical
  C. Biological
  D. Radiological
```

**UI Features:**
- Auto-populate location with current GPS
- Dropdowns for standardized selections
- Precedence calculation based on injuries
- Copy to clipboard
- Send as CoT report
- Print/export as PDF

**CoT Structure:**
```xml
<event type="b-r-f-h-c" uid="MEDEVAC-UUID" ...>  <!-- Medical report -->
    <point lat="38.8977" lon="-77.0365" hae="50.0" ce="10.0" le="5.0"/>
    <detail>
        <medevac>
            <line1>18SUJ2337506390</line1>
            <line2>Freq: 50.000 MHz, Callsign: ALPHA-1</line2>
            <line3>A:1 B:0 C:0</line3>
            <line4>A</line4>
            <line5>A:1 B:0</line5>
            <line6>A</line6>
            <line7>C</line7>
            <line8>A</line8>
            <line9>A</line9>
        </medevac>
        <remarks>MEDEVAC request from ALPHA-1</remarks>
    </detail>
</event>
```

### CAS Request (Close Air Support)

**Purpose:** Request close air support from aircraft.

**Format:**
```
Line 1: IP/BP (Initial Point/Battle Position)
Line 2: Heading and distance to target
Line 3: Target elevation
Line 4: Target description
Line 5: Target location (MGRS)
Line 6: Type of mark/control
Line 7: Friendly location
Line 8: Egress direction
Line 9: Remarks (threats, hazards, restrictions)
```

**UI:**
- Map-based target selection
- Auto-calculate heading/distance from IP
- Target type dropdown (vehicle, personnel, structure)
- Mark type selection (laser, smoke, GPS)
- Voice remarks recording
- Send to air assets via CoT

---

## Meshtastic Integration

### Overview

Meshtastic is a long-range, low-power mesh network protocol using LoRa radios. OmniTAK can bridge TAK traffic to Meshtastic mesh networks.

### Connection Types

**Bluetooth LE (iOS):**
- Pair with Meshtastic device via Bluetooth
- Automatic reconnection
- Low power consumption

**Serial/USB (macOS):**
- Direct USB connection
- Higher data rate
- Continuous power

**TCP/IP (Network):**
- Connect to Meshtastic device over WiFi
- Multiple simultaneous connections
- Remote access

### Device Configuration

**Connection Settings:**
```swift
struct MeshtasticConnection {
    var connectionType: ConnectionType  // bluetooth, serial, tcp
    var deviceName: String               // Bluetooth device name
    var ipAddress: String?               // TCP/IP address
    var port: UInt16?                    // TCP port (default: 4403)
}
```

**Connection Process:**
1. Scan for Meshtastic devices
2. Select device from list
3. Pair (Bluetooth) or connect (TCP)
4. Configure bridge settings
5. Enable bridging

### Message Bridging

**TAK → Meshtastic:**
- Selected CoT messages forwarded to mesh
- Configurable message types (position, chat, emergency)
- Automatic message compression
- Rate limiting (mesh has low bandwidth)

**Meshtastic → TAK:**
- Mesh messages converted to CoT
- Position updates → CoT PLI
- Text messages → GeoChat
- Telemetry → CoT sensor data

**Bridge Configuration:**
```swift
struct MeshtasticBridge {
    var bridgeEnabled: Bool
    var forwardPositions: Bool       // Forward PLI to mesh
    var forwardChat: Bool            // Forward chat to mesh
    var forwardEmergency: Bool       // Forward emergency alerts to mesh
    var meshToTAK: Bool              // Forward mesh messages to TAK
    var maxMessageRate: Int          // Messages per minute (limit bandwidth)
}
```

### Mesh Network Visualization

**Node Display:**
- Mesh nodes shown on map
- Node ID and callsign
- Signal strength indicator (RSSI/SNR)
- Battery level
- Last heard timestamp

**Network Topology:**
- Visualize mesh network structure
- Show hop count to each node
- Identify network bottlenecks
- Route tracing

**Mesh Status:**
```
┌─────────────────────────────────┐
│  Meshtastic Status              │
├─────────────────────────────────┤
│  Device: Meshtastic-ABC123      │
│  Status: Connected ✓            │
│  Battery: 87%                   │
│  Signal: -65 dBm (Excellent)    │
│                                 │
│  Mesh Network:                  │
│  • Nodes: 12 visible            │
│  • Max hops: 3                  │
│  • Channel: LongFast            │
│                                 │
│  Bridge: Active                 │
│  • TAK → Mesh: 5 msgs/min       │
│  • Mesh → TAK: 8 msgs/min       │
│                                 │
│  [Configure] [Disconnect]       │
└─────────────────────────────────┘
```

### Protobuf Message Handling

Meshtastic uses Protocol Buffers for message encoding.

**Message Types:**
- `POSITION_APP` - GPS position
- `TEXT_MESSAGE_APP` - Text chat
- `NODEINFO_APP` - Node identification
- `TELEMETRY_APP` - Battery, temperature, etc.

**Parsing Example:**
```swift
func parsePositionMessage(_ data: Data) -> MeshtasticPosition? {
    // Decode protobuf
    guard let proto = try? Position(serializedData: data) else {
        return nil
    }
    
    // Convert to OmniTAK model
    return MeshtasticPosition(
        nodeId: proto.nodeID,
        latitude: proto.latitudeI / 1e7,
        longitude: proto.longitudeI / 1e7,
        altitude: proto.altitude,
        timestamp: Date(timeIntervalSince1970: Double(proto.time))
    )
}
```

---

## Data Packages

### Overview

Data packages are bundles of tactical data (waypoints, routes, overlays, imagery) that can be imported, created, and shared.

### Supported Formats

**Import:**
- **KML** (Keyhole Markup Language)
- **KMZ** (Compressed KML)
- **GPX** (GPS Exchange Format)
- **GeoJSON**
- **TAK Data Package** (.zip with manifest)

**Export:**
- **KML/KMZ** - Google Earth compatible
- **TAK Data Package** - Full TAK compatibility
- **GPX** - GPS device compatible

### Importing Data Packages

**Import Sources:**
1. **Files App** - Browse and select file
2. **AirDrop** - Receive from another device
3. **Email** - Open attachment
4. **Downloads** - Safari downloads folder
5. **Share Sheet** - From other apps

**Import Process:**
```
Select file (KML/KMZ/GPX)
    │
    ▼
Parse file structure
    │
    ├─ Extract waypoints → Add to waypoint list
    ├─ Extract routes → Add to routes
    ├─ Extract overlays → Add to map layers
    ├─ Extract imagery → Cache locally
    └─ Extract styles → Apply to features
    │
    ▼
Display on map
    │
    ▼
Save to local database
```

**KML Parsing:**
```swift
func parseKML(_ data: Data) -> [MapFeature] {
    let parser = XMLParser(data: data)
    let delegate = KMLParserDelegate()
    parser.delegate = delegate
    
    guard parser.parse() else {
        return []
    }
    
    // Convert KML features to OmniTAK features
    var features: [MapFeature] = []
    
    for placemark in delegate.placemarks {
        if let point = placemark.point {
            // Waypoint
            features.append(Waypoint(from: point))
        } else if let lineString = placemark.lineString {
            // Route
            features.append(Route(from: lineString))
        } else if let polygon = placemark.polygon {
            // Area/geofence
            features.append(Geofence(from: polygon))
        }
    }
    
    return features
}
```

### Creating Data Packages

**Package Contents:**
- Waypoints (selected or all)
- Routes (selected or all)
- Drawings (selected or all)
- Geofences (selected or all)
- Map snapshots (images)
- Metadata (creator, timestamp, description)

**Export Workflow:**
```
User selects "Export Data Package"
    │
    ▼
Select features to include
    │
    ▼
Choose export format (KML/KMZ/TAK)
    │
    ▼
Generate package file
    │
    ├─ Create KML/XML structure
    ├─ Add style definitions
    ├─ Include imagery (if KMZ)
    └─ Compress (if KMZ or TAK package)
    │
    ▼
Save to Files or Share
```

### Mission Package Sync

**TAK Server Sync:**
- Upload data packages to TAK server
- Download packages from server
- Auto-sync on connection
- Conflict resolution (server wins / local wins / merge)

**Sync Process:**
```
Connect to TAK server
    │
    ▼
Query available mission packages
    │
    ▼
Compare with local packages
    │
    ├─ New remote packages → Download
    ├─ New local packages → Upload
    ├─ Updated packages → Sync (based on timestamps)
    └─ Deleted packages → Remove locally
    │
    ▼
Apply changes to local database
    │
    ▼
Notify user of sync results
```

---

## Additional Features

### Video Streams

**Supported Protocols:**
- RTSP (Real-Time Streaming Protocol)
- HTTP/HLS (HTTP Live Streaming)
- RTMP (Real-Time Messaging Protocol)

**Video Stream Management:**
- Add/edit/delete video feeds
- Video overlay on map (picture-in-picture)
- Full-screen video player
- Multiple simultaneous streams
- Recording (if supported)

### ArcGIS Integration

**ArcGIS Feature Services:**
- Query ArcGIS feature layers
- Display features on map
- Attribute viewing
- Feature search

**ArcGIS Portal:**
- Connect to ArcGIS Online or Portal
- Browse organization content
- Add web maps to OmniTAK
- Authenticate with ArcGIS credentials

### Bloodhound (Asset Tracking)

**Tracking Assets:**
- Non-human tracked entities (vehicles, supplies, equipment)
- Asset status monitoring
- Movement history
- Maintenance alerts

### Range Rings

**Purpose:** Visualize distance circles around a point (e.g., weapon range, communication range).

**Configuration:**
- Center point (current location, waypoint, or custom)
- Multiple rings (e.g., 1km, 5km, 10km)
- Ring colors and labels
- Persistent or temporary

### 3D Visualization

**Features:**
- 3D terrain with elevation data
- Tilt and rotation controls
- Building extrusion (in supported areas)
- Flyover mode
- Line-of-sight with terrain occlusion

### Coordinate Systems

**Supported Systems:**
- **WGS84** (World Geodetic System 1984) - GPS standard
- **MGRS** (Military Grid Reference System)
- **UTM** (Universal Transverse Mercator)
- **USNG** (United States National Grid)

**Conversion:**
- Real-time conversion between formats
- Copy coordinates to clipboard
- Share coordinates via message

---

## Feature Summary Table

| Feature | Status | Description |
|---------|--------|-------------|
| **CoT Protocol** | ✅ Full | Send/receive CoT messages |
| **Multi-Server** | ✅ Full | Connect to multiple TAK servers |
| **GeoChat** | ✅ Full | Text messaging with location |
| **Photo Attachments** | ✅ Full | Send images in chat |
| **Position Broadcasting** | ✅ Full | Automatic PLI updates |
| **Emergency Beacon** | ✅ Full | 911, In Contact alerts |
| **MIL-STD-2525** | ✅ Full | Military symbology |
| **MGRS Grid** | ✅ Full | Grid overlay and conversion |
| **Offline Maps** | ✅ Full | Download regions for offline use |
| **Certificate Auth** | ✅ Full | P12 client certificates |
| **QR Enrollment** | ✅ Full | QR code-based setup |
| **Waypoints** | ✅ Full | Create, edit, navigate to waypoints |
| **Route Planning** | ✅ Full | Multi-waypoint routes |
| **Turn-by-Turn Nav** | ✅ Full | Voice-guided navigation |
| **Drawing Tools** | ✅ Full | Markers, lines, circles, polygons |
| **Measurement Tools** | ✅ Full | Distance, bearing, area |
| **Geofencing** | ✅ Full | Entry/exit monitoring |
| **SPOTREP** | ✅ Full | Spot reports |
| **MEDEVAC** | ✅ Full | 9-line MEDEVAC request |
| **CAS Request** | ✅ Full | Close air support request |
| **SALUTE** | ✅ Full | Intelligence reports |
| **Meshtastic** | ✅ Full | Mesh network integration |
| **KML/KMZ Import** | ✅ Full | Google Earth files |
| **Data Packages** | ✅ Full | Import/export/sync |
| **Team Management** | ✅ Full | Organize operators |
| **Video Streams** | ✅ Full | RTSP/HTTP video |
| **ArcGIS** | ✅ Full | Feature services |
| **3D Terrain** | ✅ Full | Elevation visualization |
| **Breadcrumb Trails** | ✅ Full | Movement history |
| **Range Rings** | ✅ Full | Distance circles |
| **Elevation Profile** | ✅ Full | Terrain profile graphs |
| **Line of Sight** | ✅ Full | LOS analysis |

---

**Next:** [API Reference](API_REFERENCE.md) | [Quick Start](QUICK_START.md) | [Back to Index](README.md)
