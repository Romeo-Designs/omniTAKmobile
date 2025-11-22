# Getting Started Guide

## Table of Contents

- [Welcome to OmniTAK Mobile](#welcome-to-omnitak-mobile)
- [System Requirements](#system-requirements)
- [Installation](#installation)
- [First Launch](#first-launch)
- [Connecting to a TAK Server](#connecting-to-a-tak-server)
- [Understanding the Interface](#understanding-the-interface)
- [Your First Mission](#your-first-mission)
- [Next Steps](#next-steps)

---

## Welcome to OmniTAK Mobile

**OmniTAK Mobile** brings the power of tactical awareness to iOS devices. Whether you're conducting military operations, coordinating emergency response, or managing field teams, OmniTAK provides real-time situational awareness compatible with the TAK ecosystem.

### What Can You Do?

- 📍 **Track Team Positions** - See your team's location in real-time
- 💬 **Secure Chat** - Text and photo messages with location
- 🗺️ **Advanced Mapping** - Satellite imagery, terrain, offline maps
- 🚨 **Emergency Alerts** - One-tap SOS and emergency notifications
- 📐 **Drawing Tools** - Mark targets, routes, and areas of interest
- 🔐 **Secure Communications** - TLS encryption with client certificates
- 📡 **Multi-Network** - Internet, Meshtastic mesh, or offline capable

---

## System Requirements

### Minimum Requirements

| Requirement | Specification                                     |
| ----------- | ------------------------------------------------- |
| **Device**  | iPhone 7 or newer, iPad (5th generation) or newer |
| **OS**      | iOS 15.0 or later                                 |
| **Storage** | 100 MB (plus space for offline maps)              |
| **Network** | WiFi, Cellular, or Mesh (Meshtastic)              |

### Recommended

| Requirement | Specification                                               |
| ----------- | ----------------------------------------------------------- |
| **Device**  | iPhone 12 or newer, iPad Pro                                |
| **OS**      | iOS 16.0 or later                                           |
| **Storage** | 500 MB+ for offline maps                                    |
| **GPS**     | Device with built-in GPS (all iPhones, WiFi+Cellular iPads) |

### Permissions Required

OmniTAK Mobile requires these iOS permissions:

- ✅ **Location** (Always) - For position tracking and broadcasting
- ✅ **Camera** - For QR code scanning and photo attachments
- ✅ **Photo Library** - For sharing photos in chat
- ✅ **Notifications** - For emergency alerts and chat messages
- ✅ **Bluetooth** - For Meshtastic device connection (optional)
- ✅ **Local Network** - For discovering TAK servers on LAN

---

## Installation

### TestFlight Installation (Recommended)

1. **Install TestFlight** from the App Store (if not already installed)
2. **Open the invitation link** provided by your administrator
3. **Tap "Start Testing"** in TestFlight
4. **Install OmniTAK Mobile** from TestFlight

### App Store Installation

1. **Open the App Store** on your iOS device
2. **Search for "OmniTAK Mobile"**
3. **Tap "Get"** to download and install
4. **Open** the app when installation completes

### Enterprise Distribution

If your organization uses enterprise distribution:

1. **Download the .ipa file** from your organization's portal
2. **Install via MDM** or sideloading tool
3. **Trust the enterprise certificate** in Settings > General > VPN & Device Management

---

## First Launch

### Initial Setup Wizard

When you first launch OmniTAK Mobile, you'll see a setup wizard:

#### Step 1: Permissions

Grant the required permissions:

```
📍 Location Services
   "Allow While Using App" or "Always" (recommended)

📷 Camera Access
   "OK" to enable QR code scanning

📸 Photo Library
   "Select Photos" or "Allow Access to All Photos"

🔔 Notifications
   "Allow" to receive alerts and chat messages
```

**Tip:** You can change permissions later in iOS Settings > OmniTAK Mobile

#### Step 2: Callsign

Enter your callsign (tactical identifier):

```
Callsign: Alpha-1
```

**Guidelines:**

- 3-20 characters
- Letters, numbers, hyphens only
- Unique within your team
- Avoid spaces or special characters

**Examples:** `Alpha-1`, `Bravo-Team-Lead`, `Medic-3`, `Command-Post`

#### Step 3: Unit Type (Optional)

Select your unit type for proper map symbology:

- Infantry
- Armor
- Artillery
- Aviation
- Medical
- Command & Control
- Logistics
- Engineer
- Other

**Note:** This affects your map icon per MIL-STD-2525 standards

#### Step 4: Team/Group (Optional)

Enter your team or group name:

```
Team: Blue Force
```

This groups you with other team members on the map.

---

## Connecting to a TAK Server

### Prerequisites

Before connecting, you need:

1. **Server Address** - Hostname or IP address (e.g., `tak.example.com` or `192.168.1.100`)
2. **Port Number** - Usually 8089 for TLS or 8087 for TCP
3. **Protocol** - TCP, UDP, or TLS (recommended)
4. **Client Certificate** - .p12 file and password (for TLS servers)

**Ask your TAK server administrator for these details.**

### Method 1: QR Code Enrollment (Easiest)

Many TAK servers support QR code certificate enrollment:

1. **Tap Settings** (gear icon in top-right)
2. **Tap "Servers"**
3. **Tap "+" to add server**
4. **Tap "Scan QR Code"**
5. **Point camera at QR code** (provided by admin)
6. **App auto-configures** server and certificate
7. **Tap "Connect"**

✅ **Done!** You should see "Connected" status.

### Method 2: Manual Server Configuration

If you have server details manually:

1. **Tap Settings** > **Servers** > **"+"**
2. **Enter server details:**

```
Name: Production TAK
Host: tak.example.com
Port: 8089
Protocol: TLS
```

3. **Tap "Save"**
4. **Import Certificate** (see below)
5. **Select server** from list
6. **Tap "Connect"**

### Method 3: Certificate Import

For TLS servers, import your .p12 certificate:

#### Option A: Via Files App

1. **Save .p12 file** to iCloud Drive or Files app
2. **In OmniTAK:** Settings > **Certificates** > **"+"**
3. **Tap "Import from Files"**
4. **Select your .p12 file**
5. **Enter certificate password**
6. **Certificate saved** to Keychain

#### Option B: Via AirDrop

1. **AirDrop .p12 file** from another device
2. **Tap "Copy to OmniTAK"** in share sheet
3. **Enter password** when prompted
4. **Certificate imported** automatically

#### Option C: Via URL

1. **Settings** > **Certificates** > **"+"**
2. **Tap "Import from URL"**
3. **Enter HTTPS URL** to .p12 file
4. **Enter password**
5. **Certificate downloaded** and imported

### Verify Connection

Look for these indicators:

✅ **Green "Connected" status** in top status bar  
✅ **Upload/download stats** incrementing  
✅ **Other users appearing** on map  
✅ **Your position broadcasting** (blue puck on map)

**Troubleshooting:** See [Troubleshooting Guide](Troubleshooting.md#connection-issues)

---

## Understanding the Interface

### Main Screen Layout

```
┌────────────────────────────────────────┐
│  📡 Connected  GPS: 8/15  🔋 85%  10:30 │ ← Status Bar
├────────────────────────────────────────┤
│                                        │
│           🗺️ Map View                  │
│      (Satellite/Terrain/Standard)      │
│                                        │
│  ● You                                 │
│  ▲ Team Members                        │
│  ▼ Hostile                             │
│                                        │
├────────────────────────────────────────┤
│ 🔍 ☰ ✏️ 💬 📍 ⚙️                        │ ← Bottom Toolbar
└────────────────────────────────────────┘
```

### Status Bar (Top)

| Icon                | Meaning                            |
| ------------------- | ---------------------------------- |
| 📡 **Connected**    | Connected to TAK server            |
| 📡 **Disconnected** | Not connected                      |
| 📍 **GPS: 12/15**   | GPS accuracy (12 of 15 satellites) |
| 🔋 **85%**          | Device battery level               |
| **10:30**           | Current time                       |
| **N 37.7749**       | Your latitude                      |
| **W 122.4194**      | Your longitude                     |

### Bottom Toolbar

| Button          | Function                                         |
| --------------- | ------------------------------------------------ |
| 🔍 **Zoom**     | Center on your location                          |
| ☰ **Layers**   | Toggle map layers (satellite, MGRS grid, trails) |
| ✏️ **Draw**     | Drawing tools (marker, line, circle, polygon)    |
| 💬 **Chat**     | Open chat conversations                          |
| 📍 **Tools**    | Tools menu (measurements, waypoints, routes)     |
| ⚙️ **Settings** | App settings and configuration                   |

### Map Gestures

| Gesture               | Action                       |
| --------------------- | ---------------------------- |
| **Single tap**        | Select marker/waypoint       |
| **Long press**        | Open radial menu at location |
| **Double tap**        | Zoom in                      |
| **Two-finger tap**    | Zoom out                     |
| **Pinch**             | Zoom in/out                  |
| **Drag**              | Pan map                      |
| **Two-finger rotate** | Rotate map                   |

### Radial Menu (Long Press)

Long-press anywhere on the map to open the radial menu:

```
        Drop Marker
             │
    ────────●────────
    │       │       │
  Chat    Select   Measure
         Here
```

Options:

- **Drop Marker** - Place waypoint at location
- **Measure** - Start distance measurement
- **Send Location** - Share coordinates in chat
- **Navigate Here** - Start navigation to point

---

## Your First Mission

Let's walk through a basic mission scenario to learn the essential features.

### Scenario: Reconnaissance Patrol

**Mission:** Patrol to grid 38SMB12345678, observe and report.

#### Step 1: Mark the Objective

1. **Long-press** on the objective location
2. **Tap "Drop Marker"** in radial menu
3. **Enter name:** `Objective Alpha`
4. **Select icon:** Target
5. **Tap "Save"**

✅ Marker appears on map and broadcasts to team

#### Step 2: Plan Your Route

1. **Tap Tools** 📍 > **Route Planning**
2. **Tap map** to add waypoints along route
3. **Review distance** and estimated time
4. **Tap "Start Navigation"**

✅ Turn-by-turn directions displayed

#### Step 3: Communicate with Team

1. **Tap Chat** 💬
2. **Select "All Chat Users"** or specific team member
3. **Type message:** `Moving to Objective Alpha, ETA 15 minutes`
4. **Tap Send** ✉️

✅ Message delivered with your location

#### Step 4: Take a Photo

1. **At objective, tap Camera** 📷 in chat
2. **Take photo** of area
3. **Add caption:** `Objective Alpha - All clear`
4. **Send** to team

✅ Photo with location sent to team

#### Step 5: Report Back

1. **Tap Tools** 📍 > **Reports** > **SPOTREP**
2. **Fill out report form:**
   - Location: (auto-filled)
   - Activity: No movement observed
   - Description: Area secure
3. **Submit**

✅ Structured report sent via CoT

#### Step 6: Return to Base

1. **Tap Navigation** arrow
2. **Select "Base"** from waypoints
3. **Follow route** home

✅ Navigation guides you back

---

## Next Steps

### Learn More Features

- **[Features Guide](Features.md)** - Complete feature walkthrough
- **[Drawing Tools](Features.md#drawing-tools)** - Mark targets and areas
- **[Offline Maps](Features.md#offline-maps)** - Download maps for no-coverage areas
- **[Emergency Beacon](Features.md#emergency-beacon)** - SOS alerts
- **[Tactical Reports](Features.md#tactical-reports)** - CAS, MEDEVAC, SPOTREP

### Advanced Topics

- **[Meshtastic Setup](Features.md#meshtastic)** - Off-grid mesh networking
- **[Multi-Server Federation](Features.md#multi-server)** - Connect to multiple TAK servers
- **[Custom Map Layers](Features.md#custom-layers)** - Add ArcGIS services
- **[Data Packages](Features.md#data-packages)** - Import/export KML, mission packages

### Get Help

- **[FAQ](FAQ.md)** - Frequently asked questions
- **[Troubleshooting](Troubleshooting.md)** - Common issues and solutions
- **[Settings Reference](Settings.md)** - All configuration options explained

### Join the Community

- **GitHub Discussions** - Ask questions, share tips
- **Issue Tracker** - Report bugs, request features
- **Documentation** - Contribute improvements

---

## Quick Reference Card

### Essential Shortcuts

| Action            | Method                               |
| ----------------- | ------------------------------------ |
| **Center on me**  | Tap 🔍 button                        |
| **Quick marker**  | Long-press map, select "Drop Marker" |
| **Send location** | Long-press, select "Send Location"   |
| **Emergency**     | Hold Tools button 📍 for 2 seconds   |
| **Toggle layers** | Tap ☰ button                        |
| **Quick chat**    | Tap 💬, select contact, type message |

### Status Icons

| Icon         | Meaning         |
| ------------ | --------------- |
| ● **Blue**   | You             |
| ▲ **Blue**   | Friendly unit   |
| ▼ **Red**    | Hostile unit    |
| ◆ **Yellow** | Neutral         |
| ◆ **Gray**   | Unknown         |
| 🚩           | Waypoint/marker |
| 🚨           | Emergency alert |
| ⚠️           | Warning/caution |

---

## Welcome Aboard!

You're now ready to start using OmniTAK Mobile for tactical operations. Remember:

- ✅ Keep location services enabled for accurate tracking
- ✅ Stay connected to your TAK server when possible
- ✅ Download offline maps for areas without coverage
- ✅ Practice using the interface before critical missions
- ✅ Keep your device charged (bring power banks!)

**Stay safe and maintain situational awareness!**

---

_Last Updated: November 22, 2025_
