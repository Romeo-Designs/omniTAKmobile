# Features Guide

## Table of Contents

- [Overview](#overview)
- [Map & Navigation](#map--navigation)
- [Communication](#communication)
- [Tactical Tools](#tactical-tools)
- [Planning & Analysis](#planning--analysis)
- [Data Management](#data-management)
- [Integration Features](#integration-features)

---

## Overview

OmniTAK Mobile provides comprehensive tactical awareness capabilities for military and emergency operations. This guide walks through all major features with step-by-step instructions.

### Feature Categories

| Category                | Features                                                |
| ----------------------- | ------------------------------------------------------- |
| **Map & Navigation**    | Map types, markers, overlays, offline maps, coordinates |
| **Communication**       | GeoChat, team chat, location sharing, photo messaging   |
| **Tactical Tools**      | Drawing, measurement, geofencing, waypoints, routes     |
| **Planning & Analysis** | Line-of-sight, elevation profile, tactical reports      |
| **Data Management**     | Mission packages, data sync, import/export              |
| **Integration**         | Meshtastic, ArcGIS, video feeds, external sensors       |

---

## Map & Navigation

### Viewing the Map

The map is the central interface for situational awareness.

**To navigate the map:**

1. **Pan**: Drag with one finger
2. **Zoom**: Pinch with two fingers
3. **Rotate**: Two-finger rotation gesture
4. **Tilt** (3D): Two-finger swipe up/down

**Map Types:**

1. Tap the layers button (◰) in the top-right
2. Select map type:
   - **Standard**: Street map with labels
   - **Satellite**: Aerial imagery
   - **Hybrid**: Satellite + labels
   - **Terrain**: Topographic

### Location Tracking

**Enable location tracking:**

1. Tap the location button (⊙) in the bottom-left
2. First tap: Center on your location
3. Second tap: Follow mode (map centers as you move)
4. Third tap: Follow with heading (map rotates to match your direction)
5. Fourth tap: Disable tracking

**Your position shows:**

- Blue dot with accuracy circle
- Heading arrow when moving
- Altitude displayed below position

### Finding Coordinates

**Display current coordinates:**

1. Tap Settings (⚙) > Display
2. Enable "Show Coordinates"
3. Coordinates appear at map center

**Change coordinate format:**

1. Settings > Display > Coordinate Format
2. Choose:
   - **Decimal Degrees**: 37.7749, -122.4194
   - **Degrees Minutes Seconds**: 37°46'29.6"N
   - **MGRS**: 10SEG1234567890
   - **UTM**: 10S 551620E 4181213N

### Markers & Icons

**View friendly positions:**

- Blue icons show friendly units
- Callsigns display below icons
- Tap marker to see details:
  - Location coordinates
  - Altitude
  - Speed & heading
  - Battery level
  - Last update time

**Filter markers:**

1. Tap layers button (◰)
2. Toggle marker types:
   - ☑ Friendly (blue)
   - ☑ Hostile (red)
   - ☑ Neutral (green)
   - ☑ Unknown (yellow)

### Offline Maps

**Download region for offline use:**

1. Tap Settings > Offline Maps
2. Tap "+" to add region
3. Enter region name
4. Adjust map to desired area
5. Select zoom levels (higher = more detail, larger size)
6. Tap "Download"

**Progress shows:**

- Tiles downloaded / total
- Estimated file size
- Cancel option

**Use offline maps:**

- Automatically used when no internet
- Indicator shows "Offline Mode"
- Limited to downloaded regions

---

## Communication

### GeoChat

**Send a message:**

1. Tap Chat (💬) button
2. Select conversation or tap "+" for new
3. Type message
4. Tap send (↑)

**Message appears:**

- In conversation list
- On recipient's device
- In All Chat Rooms (if broadcast)

**Message types:**

- **Text**: Plain text message
- **Location**: Tap 📍 to share current location
- **Photo**: Tap 📷 to attach image

### Direct Messages

**Start 1-on-1 conversation:**

1. Chat > "+" button
2. Select contact from list
3. Type message and send

**Contacts show:**

- Callsign
- Distance from you
- Online status (green = online)
- Last seen time

### Team Chat

**Send to team:**

1. Chat > Select team conversation
2. Type message
3. All team members receive

**Create team:**

1. Settings > Teams > "+"
2. Enter team name
3. Choose color
4. Invite members
5. Tap "Create"

### Photo Messaging

**Send photo:**

1. In conversation, tap camera (📷)
2. Choose:
   - Take Photo
   - Photo Library
3. Select/capture image
4. Add optional caption
5. Tap "Send"

**Photo features:**

- Auto-compressed for transmission
- Thumbnail preview in chat
- Tap to view full size
- Location embedded

---

## Tactical Tools

### Drawing Tools

**Access drawing tools:**

1. Tap Tools (🛠) > Drawing
2. Select tool:
   - **Marker**: Single point
   - **Line**: Connect points
   - **Circle**: Tap center, drag radius
   - **Polygon**: Tap points, double-tap to close
   - **Freehand**: Drag to draw

**Drawing options:**

- Color picker
- Line width
- Fill transparency
- Label text

**Save drawing:**

1. Complete shape
2. Enter name/description
3. Tap "Save"
4. Drawing persists on map

### Waypoints

**Drop waypoint:**

1. Long-press map location
2. Select "Add Waypoint"
3. Configure:
   - Name
   - Icon (📍🎯⭐🏁)
   - Color
   - Notes
4. Tap "Save"

**Edit waypoint:**

1. Tap waypoint marker
2. Tap "Edit"
3. Modify properties
4. Tap "Save"

**Delete waypoint:**

1. Tap waypoint
2. Tap "Delete"
3. Confirm

### Routes

**Create route:**

1. Tools > Route Planning
2. Tap "New Route"
3. Add waypoints:
   - Tap map to add
   - Or select from existing waypoints
4. Enter route name
5. Tap "Save"

**Route shows:**

- Line connecting waypoints
- Total distance
- Estimated time (at set speed)
- Elevation profile (if enabled)

**Navigate route:**

1. Select route from list
2. Tap "Navigate"
3. Navigation panel shows:
   - Distance to next waypoint
   - Bearing to next waypoint
   - ETA
4. Tap "Stop" to end

### Measurement Tools

**Measure distance:**

1. Tools > Measurement > Distance
2. Tap points on map
3. Line shows distance between points
4. Total distance displays at bottom
5. Double-tap to finish

**Measure area:**

1. Tools > Measurement > Area
2. Tap points to outline area
3. Double-tap to close polygon
4. Area displays in m² or acres

**Range rings:**

1. Tools > Measurement > Range Ring
2. Tap center point
3. Enter radius (meters)
4. Circle appears on map
5. Add multiple rings as needed

### Geofencing

**Create geofence:**

1. Tools > Geofences > "+"
2. Tap center on map
3. Set radius (meters)
4. Configure alerts:
   - ☑ Notify on entry
   - ☑ Notify on exit
5. Enter name
6. Tap "Save"

**Geofence alerts:**

- Notification when you/team enters/exits
- Alert sound/vibration
- Visual indicator on map
- Log of all events

**Monitor geofences:**

1. Tools > Geofences
2. Toggle "Monitoring" ON
3. View active alerts
4. See event history

---

## Planning & Analysis

### Elevation Profile

**View terrain elevation:**

1. Tools > Elevation Profile
2. Tap two points on map
3. Profile graph shows:
   - Elevation along path
   - Total elevation gain/loss
   - Maximum/minimum elevation
   - Distance markers

**Use cases:**

- Route planning
- Line-of-sight analysis
- Landing zone selection
- Obstacle identification

### Line of Sight

**Calculate visibility:**

1. Tools > Line of Sight
2. Tap observer position
3. Tap target position
4. Analysis shows:
   - ✅ Visible: Green line
   - ❌ Obstructed: Red line + obstruction point
   - Terrain profile
   - Clearance altitude

**Parameters:**

- Observer height (default: 1.5m)
- Target height (default: 1.5m)
- Earth curvature correction

### Tactical Reports

#### 9-Line CAS Request

**Create Close Air Support request:**

1. Tools > Tactical Reports > CAS
2. Fill 9 lines:
   - **Line 1-3**: IP, Target, Egress
   - **Line 4**: Target type
   - **Line 5**: Description
   - **Line 6**: Friendly location
   - **Line 7**: Mark type
   - **Line 8**: Target marking
   - **Line 9**: Egress direction
3. Tap "Submit"
4. Sent via CoT to all recipients

#### 9-Line MEDEVAC

**Request medical evacuation:**

1. Tools > Tactical Reports > MEDEVAC
2. Fill 9 lines:
   - **Line 1**: Pickup location + freq
   - **Line 2**: Callsign/freq at site
   - **Line 3**: Patient count by precedence
   - **Line 4**: Special equipment
   - **Line 5**: Litter/ambulatory
   - **Line 6**: Security
   - **Line 7**: Marking
   - **Line 8**: Nationality/status
   - **Line 9**: NBC contamination
3. Tap "Submit"

#### SPOTREP

**Submit spot report:**

1. Tools > Tactical Reports > SPOTREP
2. Enter SALUTE:
   - **S**ize
   - **A**ctivity
   - **L**ocation (tap map)
   - **U**nit
   - **T**ime
   - **E**quipment
3. Add remarks
4. Tap "Submit"

---

## Data Management

### Mission Packages

**Import mission package:**

1. Settings > Data Packages
2. Tap "Import"
3. Select source:
   - Files app
   - Email attachment
   - AirDrop
   - URL
4. Select .zip package
5. Tap "Import"

**Package contains:**

- KML overlays
- Imagery
- Documents
- Certificates
- Routes/waypoints

**Export package:**

1. Settings > Data Packages
2. Select package
3. Tap "Export"
4. Choose destination:
   - Share via AirDrop
   - Email
   - Save to Files
   - Send via TAK

### Data Synchronization

**Sync with server:**

1. Connect to TAK server
2. Settings > Sync
3. Tap "Sync Now"
4. Progress shows:
   - Items uploaded
   - Items downloaded
   - Conflicts (if any)

**Auto-sync:**

1. Settings > Sync
2. Enable "Auto Sync"
3. Set interval (5min - 1hr)

### Import/Export

**Export all data:**

1. Settings > Data Management
2. Tap "Export All"
3. Creates .zip containing:
   - Waypoints
   - Routes
   - Drawings
   - Geofences
   - Chat history
   - Settings
4. Save to Files or share

**Import data:**

1. Settings > Data Management
2. Tap "Import"
3. Select .zip file
4. Choose what to import:
   - ☑ Waypoints
   - ☑ Routes
   - ☑ Drawings
   - ☑ Settings
5. Tap "Import"

---

## Integration Features

### Meshtastic

**Connect Meshtastic device:**

1. Settings > Meshtastic
2. Tap "Scan for Devices"
3. Select device from list
4. Tap "Connect"

**Features:**

- Off-grid messaging via LoRa
- Position reports shared
- Mesh network visualization
- Battery monitoring

**Send via mesh:**

1. In chat, tap recipient
2. Toggle "Use Meshtastic"
3. Message routes through mesh network

### Position Broadcasting

**Enable automatic PLI:**

1. Settings > Position Broadcast
2. Toggle "Enable Broadcasting"
3. Set interval (10s - 5min)
4. Configure:
   - Callsign
   - Team color
   - Role
   - Unit type

**Your position:**

- Broadcasts to all connected users
- Shows on their maps
- Updates at set interval
- Includes speed, heading, altitude

### Emergency Beacon

**Activate emergency:**

1. Hold SOS button (3 seconds)
2. Select type:
   - **911 Emergency**
   - **In Contact**
   - **Ring Given**
3. Confirm activation

**Emergency features:**

- Rapid PLI updates (5 second intervals)
- Alert sent to all users
- Icon changes to emergency state
- Audio/visual alarm
- Cancel button to stop

**Cancel emergency:**

1. Tap "Cancel Emergency"
2. Confirm cancellation
3. Return to normal PLI

### Track Recording

**Record your movement:**

1. Tools > Track Recording
2. Tap "Start Recording"
3. Enter track name
4. Track records:
   - All GPS points
   - Timestamps
   - Speed
   - Altitude
5. Tap "Stop" when done

**Track statistics:**

- Total distance
- Duration
- Average speed
- Max speed
- Elevation gain/loss

**Export track:**

1. Select track from list
2. Tap "Export"
3. Choose format:
   - GPX (GPS Exchange)
   - KML (Google Earth)
   - JSON
4. Share or save

---

## Tips & Best Practices

### Battery Conservation

- Reduce PLI update frequency
- Disable breadcrumb trails when not needed
- Use Standard map instead of Satellite
- Enable Low Power Mode (iOS)

### Network Optimization

- Queue messages when offline (auto-sends when connected)
- Use lower quality for photo attachments
- Sync mission packages over WiFi when possible

### Situational Awareness

- Enable layer filtering to reduce clutter
- Use team colors for quick identification
- Set up geofences for key areas
- Monitor chat for team coordination

### Data Organization

- Name waypoints/routes descriptively
- Use consistent color coding
- Export backups regularly
- Delete old tracks/drawings

---

## Related Documentation

- **[Getting Started](GettingStarted.md)** - Initial setup
- **[Settings](Settings.md)** - Configuration reference
- **[Troubleshooting](Troubleshooting.md)** - Problem resolution

---

_Last Updated: November 22, 2025_
