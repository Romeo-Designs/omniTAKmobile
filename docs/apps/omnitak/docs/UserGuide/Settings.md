# Settings Reference

## Table of Contents

- [Overview](#overview)
- [General Settings](#general-settings)
- [Server Settings](#server-settings)
- [Display Settings](#display-settings)
- [Position Broadcast](#position-broadcast)
- [Notifications](#notifications)
- [Map Settings](#map-settings)
- [Data & Storage](#data--storage)
- [Privacy & Security](#privacy--security)
- [Advanced Settings](#advanced-settings)

---

## Overview

Access settings by tapping the gear icon (⚙) in the app. This reference documents all available settings and their effects.

### Settings Navigation

```
Settings (⚙)
├── General
├── Servers
├── Display
├── Position Broadcast
├── Notifications
├── Map
├── Data & Storage
├── Privacy & Security
└── Advanced
```

---

## General Settings

### User Identity

**Callsign**

- **Type**: Text field
- **Default**: "OmniTAK-iOS"
- **Description**: Your display name visible to other users
- **Range**: 1-30 characters
- **Example**: "Alpha-1", "Bravo-2-Lead"

**User ID**

- **Type**: Read-only
- **Default**: Auto-generated UUID
- **Description**: Unique identifier for your device
- **Format**: `IOS-{UUID}`

### Team Settings

**Team Name**

- **Type**: Text field
- **Default**: "Dark Blue"
- **Options**:
  - White
  - Yellow
  - Orange
  - Magenta
  - Red
  - Maroon
  - Purple
  - Dark Blue
  - Cyan
  - Teal
  - Green
  - Dark Green

**Team Role**

- **Type**: Dropdown
- **Default**: "Team Lead"
- **Options**:
  - Team Lead
  - Team Member
  - HQ
  - Sniper
  - Medic
  - RTO
  - Forward Observer

**Unit Type**

- **Type**: Picker (MIL-STD-2525)
- **Default**: `a-f-G-U-C` (Friendly Ground Unit Combat)
- **Description**: Military symbology code
- **Common Options**:
  - `a-f-G-U-C`: Friendly Ground Unit Combat
  - `a-f-G-E-V`: Friendly Ground Equipment Vehicle
  - `a-f-A`: Friendly Air
  - `a-n-G`: Neutral Ground

### Language & Region

**Language**

- **Type**: System (follows iOS)
- **Options**: English (primary)

**Date Format**

- **Type**: System
- **Options**: 12hr / 24hr

**Distance Units**

- **Type**: Toggle
- **Default**: Metric
- **Options**:
  - Metric (meters, kilometers)
  - Imperial (feet, miles)

---

## Server Settings

### TAK Servers

**Server List**

Each server has:

- Name
- Host (IP/hostname)
- Port
- Protocol (TCP/UDP/TLS)
- Status indicator (🟢/🔴)

**Add Server**

1. Tap "+" button
2. Configure:

**Server Name**

- **Type**: Text field
- **Example**: "Ops Center", "TAK Server Alpha"

**Host**

- **Type**: Text field
- **Format**: IP address or hostname
- **Example**: "192.168.1.100", "tak.example.com"

**Port**

- **Type**: Number
- **Default**:
  - 8087 (TCP)
  - 8088 (UDP)
  - 8089 (TLS)
- **Range**: 1-65535

**Protocol**

- **Type**: Segmented control
- **Options**:
  - **TCP**: Reliable, unencrypted
  - **UDP**: Fast, unreliable
  - **TLS**: Encrypted, recommended

**Use TLS**

- **Type**: Toggle
- **Default**: OFF for TCP/UDP, ON for TLS
- **Description**: Enable encryption

**Certificate**

- **Type**: Picker
- **Options**: List of imported certificates
- **Description**: Client certificate for authentication

**Allow Legacy TLS**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Enable TLS 1.0/1.1 (less secure)
- **Use**: Old servers only

**Auto-Connect**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Connect automatically on app launch

### Certificates

**Import Certificate**

1. Tap "Import Certificate"
2. Select .p12 file
3. Enter password
4. Certificate added to list

**Certificate List Shows**:

- Certificate name
- Expiry date
- Issuer
- Status:
  - ✅ Valid
  - ⚠️ Expiring soon (<30 days)
  - ❌ Expired

**Delete Certificate**:

- Swipe left, tap Delete

---

## Display Settings

### Map Display

**Show Coordinates**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Display coordinates at map center

**Coordinate Format**

- **Type**: Picker
- **Options**:
  - Decimal Degrees (37.7749, -122.4194)
  - Degrees Minutes Seconds (37°46'29.6"N)
  - MGRS (10SEG1234567890)
  - UTM (10S 551620E 4181213N)

**Show Compass**

- **Type**: Toggle
- **Default**: ON
- **Description**: Display compass indicator

**Show Scale Bar**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Display distance scale

**Show Grid**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Display coordinate grid overlay

**Grid Type**

- **Type**: Picker
- **Options**:
  - MGRS
  - UTM
  - Lat/Lon

### Marker Display

**Show Callsigns**

- **Type**: Toggle
- **Default**: ON
- **Description**: Display callsign labels below markers

**Show Breadcrumb Trails**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Display movement history trails

**Trail Length**

- **Type**: Slider
- **Range**: 10-200 points
- **Default**: 50
- **Description**: Number of trail points to keep

**Show Range & Bearing Lines**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Display R&B lines to markers

### UI Preferences

**Theme**

- **Type**: Segmented control
- **Options**:
  - Light
  - Dark
  - Auto (follows system)
- **Default**: Auto

**Show Toolbar**

- **Type**: Toggle
- **Default**: ON
- **Description**: Display quick action toolbar

**Icon Size**

- **Type**: Slider
- **Range**: Small - Large
- **Default**: Medium

---

## Position Broadcast

### Broadcast Configuration

**Enable Broadcasting**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Automatically broadcast your position
- **Requires**: Server connection, GPS permission

**Update Interval**

- **Type**: Slider
- **Range**: 10 seconds - 5 minutes
- **Default**: 30 seconds
- **Description**: How often to send position updates
- **Note**: Lower = more battery usage

**Stale Time**

- **Type**: Slider
- **Range**: 1 - 30 minutes
- **Default**: 3 minutes
- **Description**: When your position is considered stale

### Broadcast Content

**Include Speed**

- **Type**: Toggle
- **Default**: ON
- **Description**: Include current speed in broadcast

**Include Heading**

- **Type**: Toggle
- **Default**: ON
- **Description**: Include direction of travel

**Include Altitude**

- **Type**: Toggle
- **Default**: ON
- **Description**: Include elevation (HAE)

**Include Battery Level**

- **Type**: Toggle
- **Default**: ON
- **Description**: Include device battery percentage

---

## Notifications

### Alert Types

**Chat Messages**

- **Type**: Toggle
- **Default**: ON
- **Sound**: ON
- **Banner**: ON
- **Badge**: ON

**Geofence Alerts**

- **Type**: Toggle
- **Default**: ON
- **Sound**: ON
- **Description**: Entry/exit notifications

**Emergency Beacons**

- **Type**: Toggle
- **Default**: ON
- **Sound**: ON
- **Priority**: Critical
- **Description**: 911/In Contact alerts

**Team Invites**

- **Type**: Toggle
- **Default**: ON

**Connection Status**

- **Type**: Toggle
- **Default**: ON
- **Description**: Server connect/disconnect

### Notification Settings

**Do Not Disturb Mode**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Silence all notifications

**DND Schedule**

- **Type**: Time range picker
- **Example**: 22:00 - 06:00

**Vibration**

- **Type**: Toggle
- **Default**: ON

**Sound Volume**

- **Type**: Slider
- **Range**: 0% - 100%
- **Default**: 80%

---

## Map Settings

### Map Layers

**Default Map Type**

- **Type**: Segmented control
- **Options**:
  - Standard
  - Satellite
  - Hybrid
  - Terrain
- **Default**: Standard

**Show Traffic**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Display traffic conditions (when available)

**Show Buildings**

- **Type**: Toggle
- **Default**: ON
- **Description**: Display 3D buildings

**Show Points of Interest**

- **Type**: Toggle
- **Default**: OFF

### Layer Visibility

**Show Friendly**

- **Type**: Toggle
- **Default**: ON
- **Color**: Blue

**Show Hostile**

- **Type**: Toggle
- **Default**: ON
- **Color**: Red

**Show Neutral**

- **Type**: Toggle
- **Default**: ON
- **Color**: Green

**Show Unknown**

- **Type**: Toggle
- **Default**: ON
- **Color**: Yellow

### Performance

**Maximum Markers**

- **Type**: Number field
- **Range**: 100 - 10000
- **Default**: 1000
- **Description**: Limit visible markers for performance

**Marker Clustering**

- **Type**: Toggle
- **Default**: ON
- **Description**: Group nearby markers when zoomed out

**Trail Smoothing**

- **Type**: Toggle
- **Default**: ON
- **Description**: Interpolate breadcrumb trails

---

## Data & Storage

### Offline Maps

**Cached Regions**

List shows:

- Region name
- Size (MB)
- Tile count
- Download date

**Storage Usage**

- **Display**: Total size of cached tiles
- **Action**: "Clear Cache" button

**Download Quality**

- **Type**: Segmented control
- **Options**:
  - Low (fewer zoom levels)
  - Medium
  - High (more zoom levels, larger size)
- **Default**: Medium

### Data Management

**Chat History**

- **Type**: Dropdown
- **Options**:
  - Keep Forever
  - 30 days
  - 7 days
  - 24 hours
- **Default**: Keep Forever

**Track Recording**

- **Action**: "Export All Tracks"
- **Action**: "Delete All Tracks"

**Waypoints & Routes**

- **Action**: "Export All"
- **Action**: "Import"

**Clear All Data**

- **Type**: Button (destructive)
- **Action**: Delete all app data
- **Confirmation**: Required

---

## Privacy & Security

### Location Privacy

**Share Location**

- **Type**: Toggle
- **Default**: ON (when broadcasting)
- **Description**: Allow position sharing via PLI

**Precise Location**

- **Type**: Toggle
- **Default**: ON
- **Description**: Share exact coordinates vs approximate

### Data Privacy

**Analytics**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Share anonymous usage data

**Crash Reports**

- **Type**: Toggle
- **Default**: ON
- **Description**: Send crash logs for debugging

### Security

**Require Passcode**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Lock app with device passcode

**Biometric Authentication**

- **Type**: Toggle
- **Default**: OFF
- **Requires**: Face ID or Touch ID enabled
- **Description**: Use biometric to unlock app

**Auto-Lock Timeout**

- **Type**: Picker
- **Options**: 1, 5, 15, 30 minutes, Never
- **Default**: Never

---

## Advanced Settings

### Network

**Connection Timeout**

- **Type**: Number field
- **Range**: 5-60 seconds
- **Default**: 30
- **Description**: Server connection timeout

**Reconnect Attempts**

- **Type**: Number field
- **Range**: 0-10
- **Default**: 5
- **Description**: Auto-reconnect retry count

**Reconnect Interval**

- **Type**: Slider
- **Range**: 5-60 seconds
- **Default**: 10
- **Description**: Delay between reconnect attempts

**Enable IPv6**

- **Type**: Toggle
- **Default**: ON

**Use Cellular Data**

- **Type**: Toggle
- **Default**: ON
- **Description**: Allow connections over cellular

### Debug

**Enable Logging**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Save debug logs to file

**Log Level**

- **Type**: Picker
- **Options**:
  - Error
  - Warning
  - Info
  - Debug
  - Verbose
- **Default**: Info

**Show FPS Counter**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Display frame rate overlay

**Export Logs**

- **Type**: Button
- **Action**: Share log file via system share sheet

### Developer

**Enable Developer Mode**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Show developer tools

**Show CoT XML**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Display raw CoT messages

**Simulate GPS**

- **Type**: Toggle
- **Default**: OFF
- **Description**: Use simulated location (testing only)

---

## Settings Import/Export

### Export Settings

1. Settings > Data & Storage
2. Tap "Export Settings"
3. Creates JSON file with:
   - User identity
   - Server configurations
   - Display preferences
   - Map settings
   - Notification settings
4. Share or save to Files

### Import Settings

1. Settings > Data & Storage
2. Tap "Import Settings"
3. Select JSON file
4. Review changes
5. Confirm import

**Note**: Imported settings overwrite current settings.

---

## Reset Options

### Reset Settings

**Reset to Defaults**

- **Location**: Settings > Advanced
- **Action**: Restore all default values
- **Preserves**: User data (waypoints, routes, tracks, chat)
- **Confirmation**: Required

**Reset and Erase**

- **Location**: Settings > Advanced
- **Action**: Reset settings AND delete all data
- **Confirmation**: Double confirmation required
- **Warning**: Cannot be undone

---

## Related Documentation

- **[Getting Started](GettingStarted.md)** - Initial configuration
- **[Features](Features.md)** - Using app features
- **[Troubleshooting](Troubleshooting.md)** - Common issues

---

_Last Updated: November 22, 2025_
