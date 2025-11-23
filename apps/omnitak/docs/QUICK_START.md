# Quick Start Guide

**Get Up and Running with OmniTAK Mobile**

This guide will help you quickly set up OmniTAK Mobile and perform common tasks.

---

## Table of Contents

1. [Installation](#installation)
2. [First Launch Setup](#first-launch-setup)
3. [Connecting to a TAK Server](#connecting-to-a-tak-server)
4. [Sending Your First Chat Message](#sending-your-first-chat-message)
5. [Creating Waypoints](#creating-waypoints)
6. [Drawing on the Map](#drawing-on-the-map)
7. [Downloading Offline Maps](#downloading-offline-maps)
8. [Common Tasks](#common-tasks)
9. [Troubleshooting](#troubleshooting)

---

## Installation

### Requirements
- iOS 15.0 or later
- iPhone 6s or newer, or any iPad supporting iOS 15+
- Approximately 200 MB free storage (more for offline maps)

### Installation Methods

**TestFlight (Beta):**
1. Install TestFlight from the App Store (if not already installed)
2. Receive TestFlight invitation link from administrator
3. Tap link on your iOS device
4. Tap "Install" in TestFlight
5. Launch OmniTAK Mobile

**App Store:**
1. Open App Store
2. Search for "OmniTAK Mobile"
3. Tap "Get" or price button
4. Authenticate with Face ID/Touch ID/password
5. Wait for installation to complete
6. Launch from Home Screen

---

## First Launch Setup

### Initial Configuration

**1. Permissions Setup**

On first launch, OmniTAK will request several permissions:

```
┌─────────────────────────────────────────┐
│  OmniTAK would like to access           │
│  your location                          │
│                                         │
│  Required for map display and          │
│  position broadcasting to TAK servers  │
│                                         │
│  [Allow While Using] [Allow Always]    │
│  [Don't Allow]                         │
└─────────────────────────────────────────┘
```

**Recommended Permissions:**
- ✅ **Location: Allow Always** - Required for background position updates
- ✅ **Notifications** - For emergency alerts and chat messages
- ✅ **Camera** - For photo attachments and QR code scanning
- ✅ **Photo Library** - For saving and sharing screenshots

**2. User Profile Setup**

Configure your operator identity:

1. Tap Settings icon (gear)
2. Navigate to "User Profile"
3. Enter your information:
   - **Callsign**: Your tactical identifier (e.g., "ALPHA-1")
   - **Team Color**: Select from standard ATAK colors (Cyan default)
   - **Team Role**: Your function (Team Lead, Member, etc.)
   - **Unit Type**: Infantry, Armor, Aviation, etc.

**3. Choose Map Type**

Select your preferred base map:
- **Standard**: Apple Maps standard view (default)
- **Satellite**: Satellite imagery
- **Hybrid**: Satellite with road overlay
- **Custom**: ArcGIS or OpenStreetMap tiles

---

## Connecting to a TAK Server

### Prerequisites

You'll need from your TAK server administrator:
- Server hostname or IP address
- Port number (typically 8087 or 8089)
- Protocol type (TCP/TLS)
- Client certificate (if TLS) - P12 file with password

### Method 1: Manual Configuration

**Step 1: Add Server**
1. Tap **Settings** (gear icon)
2. Tap **Servers**
3. Tap **+ Add Server**

**Step 2: Configure Server**
```
┌─────────────────────────────────┐
│  Add TAK Server                 │
├─────────────────────────────────┤
│  Name: My TAK Server            │
│  Host: 192.168.1.100            │
│  Port: 8089                     │
│  Protocol: [TCP] [TLS]          │
│                                 │
│  ☑ Use TLS Encryption           │
│  Certificate: (None selected)   │
│  [ Select Certificate ]         │
│                                 │
│  ☐ Allow Legacy TLS 1.0/1.1     │
│  (Not recommended)              │
│                                 │
│  [Cancel]  [Save]               │
└─────────────────────────────────┘
```

**Fill in:**
- **Name**: Friendly name for this server
- **Host**: IP address (e.g., `192.168.1.100`) or hostname
- **Port**: Port number (common: `8087` for TCP, `8089` for TLS)
- **Protocol**: Select TCP or TLS
- **Certificate**: If TLS, select imported certificate

**Step 3: Connect**
1. Tap **Save**
2. Server appears in server list
3. Tap server row to connect
4. Connection status shows in status bar

### Method 2: QR Code Enrollment

**If your administrator provides a QR code:**

1. Tap **Settings** → **Servers**
2. Tap **Enroll via QR Code**
3. Point camera at QR code
4. Auto-configuration completes:
   - Certificate imported
   - Server added
   - Connection established
5. Enter your callsign when prompted

### Verifying Connection

**Connected Successfully:**
- 🟢 Green dot in status bar
- Server name displayed
- Message counters active (📤 Sent / 📥 Received)

**Connection Failed:**
- 🔴 Red dot in status bar
- "Disconnected" message
- Check server configuration
- Verify network connectivity

**Quick Connection Test:**
```swift
// Your position should broadcast automatically
// Check status bar for "📤 Sent: 1" after ~30 seconds
```

---

## Sending Your First Chat Message

### Send to All Chat Rooms

**Step 1: Open Chat**
1. Tap **Chat** icon (speech bubble)
2. Select **All Chat Rooms** conversation

**Step 2: Compose Message**
```
┌─────────────────────────────────┐
│  All Chat Rooms              ⓘ  │
├─────────────────────────────────┤
│                                 │
│  [Other users' messages here]   │
│                                 │
├─────────────────────────────────┤
│  Type a message...        [📷] │
│  [                        ] 📤  │
└─────────────────────────────────┘
```

**Step 3: Send**
1. Type your message
2. Tap Send button (📤)
3. Message status: ⏳ → ⬆️ → ✓

**Your first message sent!** 🎉

### Send Direct Message

**To message a specific user:**

1. Tap **Chat** icon
2. Tap **+** (New Conversation)
3. Select user from contact list
4. Type and send message

**Note:** User must be online and broadcasting position to appear in contact list.

### Send Photo

1. Open conversation
2. Tap camera icon (📷)
3. Choose:
   - **Take Photo** - Use camera
   - **Photo Library** - Select existing photo
4. Photo attaches to message
5. Add caption (optional)
6. Tap Send

---

## Creating Waypoints

### Method 1: Long Press on Map

1. Long press on desired location
2. Radial menu appears
3. Select **Add Waypoint**
4. Enter waypoint details:
   ```
   ┌───────────────────────────┐
   │  New Waypoint             │
   ├───────────────────────────┤
   │  Name: Checkpoint Alpha   │
   │  Category: [Checkpoint ▼] │
   │  Color: [🔵 Blue      ▼]  │
   │  Icon: [📍 Pin       ▼]  │
   │  Notes:                   │
   │  [                     ]  │
   │                           │
   │  Location:                │
   │  38.8977°N, 77.0365°W     │
   │  18SUJ2337506390 (MGRS)   │
   │                           │
   │  [Cancel]  [Save]         │
   └───────────────────────────┘
   ```
5. Tap **Save**
6. Waypoint appears on map

### Method 2: Search Location

1. Tap search bar at top
2. Enter address or place name
3. Select result from list
4. Tap **Add Waypoint** button
5. Configure and save

### Method 3: Current Location

1. Tap **Tools** → **Drop Point**
2. Waypoint created at your GPS position
3. Edit name and properties
4. Save

### Navigate to Waypoint

1. Tap waypoint on map
2. Tap **Navigate**
3. Turn-by-turn guidance activates:
   ```
   ┌───────────────────────────┐
   │  → Checkpoint Alpha       │
   │                           │
   │  Distance: 2.5 km         │
   │  Bearing: 045° (NE)       │
   │  ETA: 15 minutes          │
   │                           │
   │  [Stop Navigation]        │
   └───────────────────────────┘
   ```

---

## Drawing on the Map

### Create a Line

**Use case:** Mark a route, boundary, or path

1. Tap **Tools** → **Drawing Tools**
2. Select **Line** tool
3. Tap map to place first point
4. Tap again to add more points
5. Tap **Complete** when finished
6. Choose color and name:
   ```
   ┌───────────────────────────┐
   │  Line Drawing             │
   ├───────────────────────────┤
   │  Name: Route to Base      │
   │  Color: [🔴 Red       ▼]  │
   │  Width: ─────●─── (3px)   │
   │  Style: [Solid      ▼]    │
   │                           │
   │  Distance: 3.2 km         │
   │  Points: 8                │
   │                           │
   │  [Cancel]  [Save]         │
   └───────────────────────────┘
   ```
7. Tap **Save**

### Create a Circle

**Use case:** Perimeter, danger zone, range circle

1. Select **Circle** tool
2. Tap map for center point
3. Drag to set radius OR enter radius value
4. Configure:
   - Name: "1km Perimeter"
   - Color: Red
   - Fill opacity: 30%
5. Save

### Create a Polygon

**Use case:** Area of operations, geofence, objective area

1. Select **Polygon** tool
2. Tap vertices around desired area
3. Tap first point again to close polygon
4. Configure name, color, fill
5. Save

### Edit Existing Drawing

1. Tap drawing on map
2. Tap **Edit** button
3. Drag points to move
4. Tap **Delete** to remove points
5. Tap **Complete** to save changes

---

## Downloading Offline Maps

### Why Offline Maps?

- ✅ Operate without internet/cellular
- ✅ Faster map loading
- ✅ Reduced data usage
- ✅ Mission-critical reliability

### Download a Region

**Step 1: Navigate to Area**
1. Pan/zoom map to desired region
2. Ensure entire area of interest is visible

**Step 2: Define Region**
1. Tap **Settings** → **Offline Maps**
2. Tap **+ Download Region**
3. Adjust region bounds:
   ```
   ┌─────────────────────────────┐
   │  Download Offline Map       │
   ├─────────────────────────────┤
   │  [        Map View       ]  │
   │  [  ┌───────────────┐    ]  │
   │  [  │  Selection    │    ]  │
   │  [  │  Rectangle    │    ]  │
   │  [  └───────────────┘    ]  │
   │                             │
   │  Zoom Levels: 10-16         │
   │  [────●──────────] (10)     │
   │  [───────────●───] (16)     │
   │                             │
   │  Estimated:                 │
   │  • Tiles: ~85,000           │
   │  • Size: ~2.1 GB            │
   │  • Time: ~45 minutes        │
   │                             │
   │  Name: [Mission Area     ]  │
   │                             │
   │  [Cancel]  [Download]       │
   └─────────────────────────────┘
   ```

**Step 3: Configure Download**
- **Zoom Levels**: 
  - Lower (10-12): Overview, large area
  - Medium (13-15): Tactical detail
  - Higher (16-18): High detail, small area
- **Name**: Descriptive name for region
- Review estimated size and time

**Step 4: Start Download**
1. Tap **Download**
2. Download begins in background
3. Progress shown in Offline Maps list
4. Continue using app during download

**Step 5: Verify**
- Checkmark (✓) appears when complete
- Tap region to view details
- Test by enabling Airplane Mode

### Manage Downloaded Regions

**View All Regions:**
```
┌─────────────────────────────────┐
│  Offline Maps                   │
├─────────────────────────────────┤
│  ✓ Mission Area        2.1 GB   │
│    Downloaded Nov 23            │
│    Zoom: 10-16                  │
│                                 │
│  ⏳ Training Site      1.5 GB   │
│    45% complete                 │
│    Est. 15 minutes remaining    │
│                                 │
│  ✓ Base Camp           850 MB   │
│    Downloaded Nov 20            │
│    Zoom: 12-17                  │
│                                 │
│  Total: 4.45 GB                 │
│                                 │
│  [+ Download Region]            │
└─────────────────────────────────┘
```

**Region Actions:**
- **View on Map** - Center map on region
- **Refresh** - Re-download updated tiles
- **Delete** - Remove cached tiles

---

## Common Tasks

### Change Your Callsign

```
Settings → User Profile → Callsign → [Enter new callsign] → Save
```

### Change Team Color

```
Settings → User Profile → Team Color → [Select color] → Save
```

### View All Connected Users

```
Chat → Contacts → Shows all users broadcasting position
```

### Measure Distance

```
Tools → Measurement → Tap start point → Tap end point → View distance
```

### Create a Route

```
1. Tools → Route Planning → New Route
2. Tap map to add waypoints
3. Reorder by dragging
4. Tap "Save Route"
5. Tap "Start Navigation" (optional)
```

### Send SPOTREP

```
1. Reports → SPOTREP
2. Fill in all lines
3. Location auto-populated
4. Tap "Send to TAK"
```

### Request MEDEVAC

```
1. Reports → MEDEVAC
2. Complete 9-line request
3. Select urgency level
4. Tap "Send to TAK"
⚠️ Only use for actual medical emergencies!
```

### Activate Emergency Beacon

```
1. Hold EMERGENCY button (red)
2. Confirm emergency type:
   - 911 Emergency
   - In Contact
   - General Alert
3. Beacon broadcasts every 30 seconds
4. Tap "Cancel Emergency" to stop
```

### Import KML File

```
1. Receive KML/KMZ file (AirDrop, email, Files)
2. Tap file → Share → OmniTAK
3. Features automatically added to map
4. View in: Tools → Data Packages
```

### Connect via Bluetooth to Meshtastic

```
1. Settings → Meshtastic
2. Tap "Scan for Devices"
3. Select your Meshtastic device
4. Tap "Connect"
5. Enable "Bridge to TAK"
```

### Enable Dark Mode

```
Settings → Appearance → [Dark] → Map automatically switches to dark style
```

### Clear Chat History

```
Settings → Chat → Clear History → Confirm
⚠️ This action cannot be undone!
```

### Export Data Package

```
1. Tools → Data Packages → Export
2. Select items to include
3. Choose format (KML/TAK Package)
4. Tap Share icon
5. Choose destination (Files, AirDrop, etc.)
```

---

## Troubleshooting

### "Cannot Connect to Server"

**Possible causes and solutions:**

1. **Incorrect server address**
   - Verify IP address and port
   - Try ping test: Settings → Servers → [server] → Test Connection

2. **Network connectivity**
   - Check WiFi/cellular connection
   - Try opening web browser to verify internet
   - Check firewall rules (if on corporate network)

3. **Certificate issues (TLS)**
   - Verify certificate is imported
   - Check certificate password
   - Ensure certificate not expired
   - Try without TLS first (if server supports)

4. **Server offline**
   - Contact server administrator
   - Verify server is running
   - Check server logs for connection attempts

### "Position Not Broadcasting"

**Solutions:**

1. **Check GPS**
   - Ensure Location Services enabled
   - Check for GPS signal (may take 30-60 seconds outdoors)
   - Blue dot should appear on map at your location

2. **Verify Broadcasting Enabled**
   - Settings → Position Broadcasting → Toggle ON
   - Check update interval (default: 30 seconds)

3. **Connection Required**
   - Must be connected to TAK server
   - Verify 🟢 green connection status

4. **Background Mode**
   - iOS may pause broadcasting when app backgrounded
   - Keep app in foreground during operations
   - Settings → General → Background App Refresh → Enable for OmniTAK

### "Messages Not Sending"

**Solutions:**

1. **Verify connection**
   - Check 🟢 green connection indicator
   - Try disconnecting and reconnecting

2. **Check message queue**
   - Settings → Chat → View Queue
   - Clear failed messages if many accumulated

3. **Recipient online?**
   - For direct messages, recipient must be broadcasting
   - Check Contacts list for online status

4. **Server issues**
   - Contact server administrator
   - Check server capacity/load

### "Map Not Loading"

**Solutions:**

1. **Online maps**
   - Verify internet connection
   - Try different map type (Settings → Map → Base Map)

2. **Offline maps**
   - Ensure region downloaded (Settings → Offline Maps)
   - Check available storage space
   - Try refreshing region

3. **Cache issues**
   - Settings → Advanced → Clear Map Cache
   - Restart app

### "App Crashes on Launch"

**Solutions:**

1. **Force quit and reopen**
   - Double-tap Home button (or swipe up)
   - Swipe up on OmniTAK to close
   - Reopen from Home Screen

2. **Update app**
   - Check App Store for updates
   - Install latest version

3. **Clear cache**
   - Settings → Advanced → Reset App Data
   - ⚠️ This will clear all local data!

4. **Reinstall**
   - Delete app
   - Reinstall from App Store/TestFlight
   - Reconfigure settings

### "High Battery Drain"

**Optimization tips:**

1. **Adjust position broadcast interval**
   - Settings → Position Broadcasting → Update Interval
   - Increase from 30s to 60s or 120s

2. **Disable unused features**
   - Turn off breadcrumb trails if not needed
   - Disable 3D terrain rendering
   - Reduce MGRS grid density

3. **Use offline maps**
   - Pre-download regions to avoid cellular data
   - Faster and more battery-efficient

4. **Enable Low Power Mode**
   - iOS Settings → Battery → Low Power Mode
   - Note: May reduce GPS accuracy

5. **Close background apps**
   - Free up system resources
   - Improve overall device performance

---

## Need More Help?

**Documentation:**
- [Full Features Guide](FEATURES.md)
- [Architecture Documentation](ARCHITECTURE.md)
- [API Reference](API_REFERENCE.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)

**Support:**
- GitHub Issues: [Report a bug](https://github.com/tyroe1998/omniTAKmobile/issues)
- Community: TAK Discord/Forums
- Administrator: Contact your TAK server administrator

---

## Quick Reference Card

**Essential Shortcuts:**

| Action | Method |
|--------|--------|
| **Drop Waypoint** | Long press map → Add Waypoint |
| **Measure Distance** | Tools → Measure → Tap points |
| **Send Chat** | Chat icon → Select conversation → Type |
| **Emergency** | Hold red EMERGENCY button |
| **Navigate** | Tap waypoint → Navigate |
| **Draw Line** | Tools → Drawing → Line → Tap points |
| **Connect Server** | Settings → Servers → Select |
| **Change Map** | Tap layers icon → Select base map |
| **View MGRS** | Tap coordinate display (toggles formats) |
| **Screenshot** | iOS: Volume Up + Power button |

**Status Bar Indicators:**
- 🟢 Connected to TAK server
- 🔴 Disconnected
- 🟡 Connecting
- 📤 Messages sent counter
- 📥 Messages received counter
- 🛰️ GPS accuracy indicator
- 🔋 Device battery level

---

**Welcome to OmniTAK Mobile!** 🎖️

You're now ready to join the TAK network and maintain tactical awareness. Practice these common tasks in a training environment before operational use.

**Stay safe and mission-focused!**

---

**Next:** [Features Guide](FEATURES.md) | [Architecture](ARCHITECTURE.md) | [Back to Index](README.md)
