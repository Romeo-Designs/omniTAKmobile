# CoT Messaging System

## Table of Contents

- [Overview](#overview)
- [CoT Protocol Fundamentals](#cot-protocol-fundamentals)
- [Architecture](#architecture)
- [Message Flow](#message-flow)
- [Parsing System](#parsing-system)
- [Event Handling](#event-handling)
- [Message Generators](#message-generators)
- [Supported Event Types](#supported-event-types)
- [Code Examples](#code-examples)

---

## Overview

The **Cursor on Target (CoT)** messaging system is the core communication protocol of OmniTAK Mobile. It enables real-time tactical awareness by exchanging standardized XML messages with TAK servers and other TAK clients.

### Key Features

- ✅ Full CoT XML parsing and generation
- ✅ Real-time event routing via Combine
- ✅ Support for 6+ message types
- ✅ Automatic marker updates
- ✅ Chat message integration
- ✅ Emergency alert handling
- ✅ Waypoint synchronization

### Files

- **Parser**: `OmniTAKMobile/CoT/CoTMessageParser.swift` (396 lines)
- **Handler**: `OmniTAKMobile/CoT/CoTEventHandler.swift` (333 lines)
- **Generators**: `OmniTAKMobile/CoT/Generators/` (4 generator files)
- **Parsers**: `OmniTAKMobile/CoT/Parsers/` (Chat XML parsers)

---

## CoT Protocol Fundamentals

### What is CoT?

**Cursor on Target (CoT)** is an XML-based protocol for sharing tactical information. Each message represents an event with:

- **Who** - Unique identifier and callsign
- **What** - Event type (position, chat, alert, etc.)
- **Where** - Latitude/longitude/elevation
- **When** - Timestamp and stale time
- **Detail** - Additional metadata

### CoT Message Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0" uid="ANDROID-123456" type="a-f-G-U-C" time="2025-11-22T10:30:00Z" start="2025-11-22T10:30:00Z" stale="2025-11-22T11:30:00Z" how="m-g">
    <point lat="37.7749" lon="-122.4194" hae="10.0" ce="9999999.0" le="9999999.0"/>
    <detail>
        <contact callsign="Alpha-1" endpoint="*:-1:stcp"/>
        <uid Droid="Alpha-1"/>
        <precisionlocation geopointsrc="GPS" altsrc="GPS"/>
        <__group name="Blue Force" role="Team Member"/>
        <status battery="85"/>
        <takv device="OmniTAK Mobile" platform="iOS" os="18" version="1.2.0"/>
        <track speed="2.5" course="45.0"/>
    </detail>
</event>
```

### Event Type Taxonomy

CoT types follow a hierarchical naming convention:

```
a-f-G-U-C
│ │ │ │ └─ Category (C = Combat)
│ │ │ └─── Unit (U = Unit)
│ │ └───── Ground (G)
│ └─────── Friendly (f)
└───────── Atom (a = Position)
```

**Common Prefixes:**

- `a-` = Atom (position/SA messages)
- `b-` = Bit (tactical data)
- `t-` = Task (metadata/protocol)

---

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    CoT Messaging System                     │
│                                                             │
│  1. Incoming XML from TAKService                           │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────────────────────────────────┐             │
│  │      CoTMessageParser                    │             │
│  │  • XML regex extraction                  │             │
│  │  • Event type detection                  │             │
│  │  • Specialized parsers                   │             │
│  └──────────────┬───────────────────────────┘             │
│                 │ Returns CoTEventType enum                │
│                 ▼                                           │
│  ┌──────────────────────────────────────────┐             │
│  │      CoTEventHandler                     │             │
│  │  • Route events to subsystems            │             │
│  │  • Publish via Combine                   │             │
│  │  • Trigger notifications                 │             │
│  └──────────────┬───────────────────────────┘             │
│                 │                                           │
│     ┌───────────┼───────────┐                             │
│     ▼           ▼           ▼                             │
│  ┌──────┐  ┌──────┐  ┌──────────┐                        │
│  │Markers│ │ Chat │  │Emergency │                        │
│  └──────┘  └──────┘  └──────────┘                        │
│                                                             │
│  2. Outgoing Messages                                      │
│         ▲                                                   │
│         │                                                   │
│  ┌──────────────────────────────────────────┐             │
│  │      Message Generators                  │             │
│  │  • ChatCoTGenerator                      │             │
│  │  • MarkerCoTGenerator                    │             │
│  │  • GeofenceCoTGenerator                  │             │
│  │  • TeamCoTGenerator                      │             │
│  └──────────────────────────────────────────┘             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Message Flow

### Receiving Messages

```
┌───────────────┐
│  TAK Server   │
└───────┬───────┘
        │ TCP/TLS Stream
        ▼
┌───────────────────────────────────────────────────┐
│ DirectTCPSender                                   │
│ • Receive buffer: accumulates bytes               │
│ • Extract complete XML documents                  │
└───────┬───────────────────────────────────────────┘
        │ Complete XML string
        ▼
┌───────────────────────────────────────────────────┐
│ CoTMessageParser.parse(xml:)                      │
│                                                   │
│ 1. Extract "type" attribute                      │
│ 2. Route to specialized parser:                  │
│    • a-* → parsePositionUpdate()                 │
│    • b-t-f → parseChatMessage()                  │
│    • b-a-* → parseEmergencyAlert()               │
│    • b-m-p-w → parseWaypoint()                   │
│ 3. Return CoTEventType enum                      │
└───────┬───────────────────────────────────────────┘
        │ CoTEventType (.positionUpdate, .chatMessage, etc.)
        ▼
┌───────────────────────────────────────────────────┐
│ CoTEventHandler.handle(event:)                    │
│                                                   │
│ Switch on event type:                            │
│ • .positionUpdate → handlePositionUpdate()       │
│ • .chatMessage → handleChatMessage()             │
│ • .emergencyAlert → handleEmergencyAlert()       │
│ • .waypoint → handleWaypoint()                   │
└───────┬───────────────────────────────────────────┘
        │
        ├─► Publish via Combine (positionUpdatePublisher)
        ├─► Post NotificationCenter notification
        ├─► Update @Published properties
        └─► Call subsystem methods
                │
                ▼
        ┌───────────────────┐
        │ UI Updates        │
        │ • Map markers     │
        │ • Chat messages   │
        │ • Alert dialogs   │
        └───────────────────┘
```

### Sending Messages

```
┌───────────────┐
│  User Action  │
│ (e.g., send   │
│  chat message)│
└───────┬───────┘
        │
        ▼
┌───────────────────────────────────────────────────┐
│ View calls Manager/Service                        │
│ Example: ChatManager.sendMessage()                │
└───────┬───────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────┐
│ Generator creates CoT XML                         │
│ Example: ChatCoTGenerator.generateGeoChatCoT()    │
└───────┬───────────────────────────────────────────┘
        │ XML string
        ▼
┌───────────────────────────────────────────────────┐
│ TAKService.send(cotMessage:)                      │
│ • Add to message queue                            │
│ • Prepend length header (if needed)               │
└───────┬───────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────┐
│ DirectTCPSender.send(data:)                       │
│ • Convert to Data                                 │
│ • Send over NWConnection                          │
└───────┬───────────────────────────────────────────┘
        │ TCP/TLS Stream
        ▼
┌───────────────┐
│  TAK Server   │
└───────────────┘
```

---

## Parsing System

### CoTMessageParser

**File:** `OmniTAKMobile/CoT/CoTMessageParser.swift`

The parser converts raw XML into structured Swift types using regex extraction.

#### Main Entry Point

```swift
class CoTMessageParser {
    /// Parse a CoT XML message and return the appropriate event type
    static func parse(xml: String) -> CoTEventType? {
        // Extract type first to determine message category
        guard let eventType = extractAttribute("type", from: xml) else {
            print("CoTMessageParser: Failed to extract event type")
            return nil
        }

        // Route based on type prefix
        if eventType.hasPrefix("a-") {
            // Position/SA message
            if let cotEvent = parsePositionUpdate(xml: xml) {
                return .positionUpdate(cotEvent)
            }
        } else if eventType == "b-t-f" {
            // Chat message
            if let chatMessage = parseChatMessage(xml: xml) {
                return .chatMessage(chatMessage)
            }
        } else if eventType.hasPrefix("b-a-") {
            // Emergency alert
            if let alert = parseEmergencyAlert(xml: xml) {
                return .emergencyAlert(alert)
            }
        } else if eventType == "b-m-p-w" {
            // Waypoint marker
            if let cotEvent = parseWaypoint(xml: xml) {
                return .waypoint(cotEvent)
            }
        }

        return .unknown(eventType)
    }
}
```

#### CoTEventType Enum

```swift
enum CoTEventType {
    case positionUpdate(CoTEvent)      // a-f-G-*, a-h-*, a-n-*, a-u-*
    case chatMessage(ChatMessage)       // b-t-f
    case emergencyAlert(EmergencyAlert) // b-a-*
    case waypoint(CoTEvent)             // b-m-p-w
    case unknown(String)                // Unrecognized type
}
```

### Specialized Parsers

#### Position Update Parser

Extracts position data for map markers:

```swift
private static func parsePositionUpdate(xml: String) -> CoTEvent? {
    guard let uid = extractAttribute("uid", from: xml),
          let type = extractAttribute("type", from: xml),
          let timeStr = extractAttribute("time", from: xml),
          let staleStr = extractAttribute("stale", from: xml),
          let lat = extractPointAttribute("lat", from: xml),
          let lon = extractPointAttribute("lon", from: xml) else {
        return nil
    }

    let hae = extractPointAttribute("hae", from: xml) ?? 0.0
    let callsign = extractDetailValue("callsign", from: xml) ?? uid
    let team = extractDetailValue("__group", attributeName: "name", from: xml)
    let role = extractDetailValue("__group", attributeName: "role", from: xml)

    return CoTEvent(
        uid: uid,
        type: type,
        time: parseISO8601(timeStr),
        stale: parseISO8601(staleStr),
        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
        hae: hae,
        callsign: callsign,
        team: team,
        role: role
    )
}
```

#### Chat Message Parser

Delegates to specialized `ChatXMLParser`:

```swift
private static func parseChatMessage(xml: String) -> ChatMessage? {
    // Use specialized ChatXMLParser for GeoChat
    return ChatXMLParser.parse(xml: xml)
}
```

#### Emergency Alert Parser

```swift
private static func parseEmergencyAlert(xml: String) -> EmergencyAlert? {
    guard let uid = extractAttribute("uid", from: xml),
          let type = extractAttribute("type", from: xml),
          let lat = extractPointAttribute("lat", from: xml),
          let lon = extractPointAttribute("lon", from: xml) else {
        return nil
    }

    let callsign = extractDetailValue("callsign", from: xml) ?? "Unknown"
    let alertType = EmergencyAlert.AlertType.from(type: type)
    let message = extractDetailValue("remarks", from: xml)
    let cancel = xml.contains("cancel=\"true\"")

    return EmergencyAlert(
        id: UUID().uuidString,
        uid: uid,
        alertType: alertType,
        callsign: callsign,
        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
        timestamp: Date(),
        message: message,
        cancel: cancel
    )
}
```

### Extraction Utilities

#### Attribute Extraction

```swift
/// Extract an attribute from XML using regex
private static func extractAttribute(_ name: String, from xml: String) -> String? {
    let pattern = "\(name)=\"([^\"]*)\""
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
          let range = Range(match.range(at: 1), in: xml) else {
        return nil
    }
    return String(xml[range])
}
```

#### Point Attribute Extraction

```swift
/// Extract a point coordinate attribute (lat, lon, hae)
private static func extractPointAttribute(_ name: String, from xml: String) -> Double? {
    let pattern = "<point[^>]*\(name)=\"([^\"]*)\""
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
          let range = Range(match.range(at: 1), in: xml) else {
        return nil
    }
    return Double(String(xml[range]))
}
```

#### Detail Value Extraction

```swift
/// Extract a value from detail element
private static func extractDetailValue(_ elementName: String, from xml: String) -> String? {
    let pattern = "<\(elementName)[^>]*callsign=\"([^\"]*)\""
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
          let range = Range(match.range(at: 1), in: xml) else {
        return nil
    }
    return String(xml[range])
}
```

---

## Event Handling

### CoTEventHandler

**File:** `OmniTAKMobile/CoT/CoTEventHandler.swift`

The event handler routes parsed CoT events to appropriate subsystems and publishes updates via Combine.

#### Singleton Instance

```swift
class CoTEventHandler: ObservableObject {
    static let shared = CoTEventHandler()

    // Private initializer ensures single instance
    private init() {
        requestNotificationPermissions()
    }
}
```

#### Published Properties

```swift
@Published var latestPositionUpdate: CoTEvent?
@Published var latestChatMessage: ChatMessage?
@Published var activeEmergencies: [EmergencyAlert] = []
@Published var receivedEventCount: Int = 0
@Published var lastEventTime: Date?
```

#### Event Publishers (Combine)

```swift
let positionUpdatePublisher = PassthroughSubject<CoTEvent, Never>()
let chatMessagePublisher = PassthroughSubject<ChatMessage, Never>()
let emergencyAlertPublisher = PassthroughSubject<EmergencyAlert, Never>()
let waypointPublisher = PassthroughSubject<CoTEvent, Never>()
let unknownEventPublisher = PassthroughSubject<String, Never>()
```

#### Configuration

```swift
func configure(takService: TAKService, chatManager: ChatManager) {
    self.takService = takService
    self.chatManager = chatManager

    print("CoTEventHandler: Configured with TAKService and ChatManager")
}
```

#### Main Routing Method

```swift
/// Handle a parsed CoT event and route to appropriate handlers
func handle(event: CoTEventType) {
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }

        self.receivedEventCount += 1
        self.lastEventTime = Date()

        switch event {
        case .positionUpdate(let cotEvent):
            self.handlePositionUpdate(cotEvent)

        case .chatMessage(let message):
            self.handleChatMessage(message)

        case .emergencyAlert(let alert):
            self.handleEmergencyAlert(alert)

        case .waypoint(let waypoint):
            self.handleWaypoint(waypoint)

        case .unknown(let type):
            self.handleUnknownEvent(type)
        }
    }
}
```

### Specialized Handlers

#### Position Update Handler

```swift
private func handlePositionUpdate(_ event: CoTEvent) {
    // Update latest position
    self.latestPositionUpdate = event

    // Publish to subscribers
    positionUpdatePublisher.send(event)

    // Post notification
    NotificationCenter.default.post(
        name: Self.positionUpdateNotification,
        object: event
    )

    // Update TAKService markers
    takService?.updateMarker(from: event)

    // Update chat participant (for presence)
    chatManager?.updateParticipant(uid: event.uid, callsign: event.callsign, coordinate: event.coordinate)

    #if DEBUG
    print("📍 Position Update: \(event.callsign) at (\(event.coordinate.latitude), \(event.coordinate.longitude))")
    #endif
}
```

#### Chat Message Handler

```swift
private func handleChatMessage(_ message: ChatMessage) {
    // Update latest chat
    self.latestChatMessage = message

    // Publish to subscribers
    chatMessagePublisher.send(message)

    // Post notification
    NotificationCenter.default.post(
        name: Self.chatMessageNotification,
        object: message
    )

    // Add to ChatManager
    chatManager?.receiveMessage(message)

    // Show local notification if app in background
    if enableNotifications {
        scheduleLocalNotification(for: message)
    }

    #if DEBUG
    print("💬 Chat Message: \(message.senderCallsign): \(message.messageText)")
    #endif
}
```

#### Emergency Alert Handler

```swift
private func handleEmergencyAlert(_ alert: EmergencyAlert) {
    if alert.cancel {
        // Remove from active alerts
        activeEmergencies.removeAll { $0.uid == alert.uid }
        print("🟢 Emergency Cancelled: \(alert.callsign)")
    } else {
        // Add to active alerts
        activeEmergencies.append(alert)

        // Publish to subscribers
        emergencyAlertPublisher.send(alert)

        // Post notification
        NotificationCenter.default.post(
            name: Self.emergencyAlertNotification,
            object: alert
        )

        // Show critical notification
        if enableEmergencyAlerts {
            scheduleCriticalNotification(for: alert)
        }

        print("🚨 Emergency Alert: \(alert.alertType.rawValue) - \(alert.callsign)")
    }
}
```

---

## Message Generators

Generators create outgoing CoT XML messages from Swift objects.

### ChatCoTGenerator

**File:** `OmniTAKMobile/CoT/Generators/ChatCoTGenerator.swift`

```swift
class ChatCoTGenerator {
    /// Generate GeoChat CoT XML for a chat message
    static func generateGeoChatCoT(message: ChatMessage, conversation: Conversation) -> String {
        let uid = UUID().uuidString
        let now = ISO8601DateFormatter().string(from: Date())
        let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))

        let recipientUIDs = conversation.isGroupChat ? "All Chat Users" : conversation.participants.map { $0.uid }.joined(separator: ",")

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="b-t-f" time="\(now)" start="\(now)" stale="\(stale)" how="h-g-i-g-o">
            <point lat="\(message.coordinate?.latitude ?? 0.0)" lon="\(message.coordinate?.longitude ?? 0.0)" hae="0.0" ce="9999999.0" le="9999999.0"/>
            <detail>
                <__chat id="\(uid)" chatroom="\(conversation.id)" groupOwner="false" parent="RootContactGroup" senderCallsign="\(message.senderCallsign)">
                    <chatgrp uid0="\(message.senderUID)" uid1="\(recipientUIDs)" id="\(conversation.id)"/>
                </__chat>
                <link uid="\(message.senderUID)" relation="p-p" type="a-f-G-U-C"/>
                <remarks>\(message.messageText)</remarks>
                <__serverdestination destinations="\(recipientUIDs)"/>
                <marti>
                    <dest callsign="\(recipientUIDs)"/>
                </marti>
            </detail>
        </event>
        """

        return xml
    }
}
```

### MarkerCoTGenerator

**File:** `OmniTAKMobile/CoT/Generators/MarkerCoTGenerator.swift`

```swift
class MarkerCoTGenerator {
    /// Generate CoT XML for a point marker
    static func generateCoT(for marker: PointMarker, staleTime: TimeInterval = 3600) -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(staleTime))

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(marker.uid)" type="\(marker.cotType)" time="\(now)" start="\(now)" stale="\(stale)" how="h-e">
            <point lat="\(marker.coordinate.latitude)" lon="\(marker.coordinate.longitude)" hae="\(marker.elevation)" ce="9999999.0" le="9999999.0"/>
            <detail>
                <contact callsign="\(marker.name)"/>
                <usericon iconsetpath="\(marker.icon)"/>
                <color value="\(marker.color.argbHex)"/>
                <remarks>\(marker.notes ?? "")</remarks>
            </detail>
        </event>
        """

        return xml
    }

    /// Generate batch of CoT messages
    static func generateBatchCoT(markers: [PointMarker], staleTime: TimeInterval = 3600) -> [String] {
        return markers.map { generateCoT(for: $0, staleTime: staleTime) }
    }
}
```

### GeofenceCoTGenerator

**File:** `OmniTAKMobile/CoT/Generators/GeofenceCoTGenerator.swift`

```swift
class GeofenceCoTGenerator {
    /// Generate CoT for geofence entry/exit event
    static func generateEventCoT(for event: GeofenceEvent, callsign: String) -> String {
        let uid = UUID().uuidString
        let now = ISO8601DateFormatter().string(from: Date())
        let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(300))

        let eventType = event.eventType == .entry ? "geofence-entry" : "geofence-exit"

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="b-m-p-s-p-loc" time="\(now)" start="\(now)" stale="\(stale)" how="h-e">
            <point lat="\(event.coordinate.latitude)" lon="\(event.coordinate.longitude)" hae="0.0" ce="9999999.0" le="9999999.0"/>
            <detail>
                <contact callsign="\(callsign)"/>
                <remarks>\(eventType): \(event.geofenceName)</remarks>
                <link uid="\(event.geofenceUID)" relation="p-p"/>
            </detail>
        </event>
        """

        return xml
    }
}
```

### TeamCoTGenerator

**File:** `OmniTAKMobile/CoT/Generators/TeamCoTGenerator.swift`

```swift
class TeamCoTGenerator {
    /// Generate CoT for team membership announcement
    static func generateTeamMembershipCoT(team: Team, member: TeamMember, callsign: String) -> String {
        let uid = UUID().uuidString
        let now = ISO8601DateFormatter().string(from: Date())
        let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="t-x-m-c" time="\(now)" start="\(now)" stale="\(stale)" how="h-e">
            <point lat="0.0" lon="0.0" hae="0.0" ce="9999999.0" le="9999999.0"/>
            <detail>
                <__group name="\(team.name)" role="\(member.role.rawValue)"/>
                <link uid="\(member.uid)" relation="p-p"/>
                <contact callsign="\(callsign)"/>
            </detail>
        </event>
        """

        return xml
    }
}
```

---

## Supported Event Types

### Position Updates (`a-*`)

Position/Situational Awareness messages for map markers.

#### Type Hierarchy

```
a- (Atom)
├─ a-f- (Friendly)
│  └─ a-f-G- (Ground)
│     ├─ a-f-G-U- (Unit)
│     │  └─ a-f-G-U-C (Combat)
│     ├─ a-f-G-E- (Equipment)
│     └─ a-f-G-I- (Installation)
├─ a-h- (Hostile)
├─ a-n- (Neutral)
└─ a-u- (Unknown)
```

#### Common Types

| Type        | Description                         |
| ----------- | ----------------------------------- |
| `a-f-G-U-C` | Friendly ground unit (combat)       |
| `a-f-G-E-V` | Friendly ground equipment (vehicle) |
| `a-h-G-U-C` | Hostile ground unit                 |
| `a-n-G`     | Neutral ground                      |
| `a-u-G`     | Unknown ground                      |

### Chat Messages (`b-t-f`)

GeoChat text messages with location and recipients.

**Structure:**

- Type: `b-t-f`
- Text in `<remarks>` element
- Recipients in `<chatgrp>` and `<dest>` elements
- Sender link with `relation="p-p"`

### Emergency Alerts (`b-a-*`)

Critical alerts for emergency situations.

#### Alert Types

| Type        | Description                    |
| ----------- | ------------------------------ |
| `b-a-o-tfc` | 911 Emergency                  |
| `b-a-o-can` | Ring the Bell (alert all)      |
| `b-a-o-opn` | In Contact (troops in contact) |

**Cancellation:**

- Set `cancel="true"` attribute
- Same UID as original alert

### Waypoints (`b-m-p-w`)

Tactical markers/waypoints.

**Structure:**

- Type: `b-m-p-w`
- Name in `<contact callsign=""/>`
- Icon in `<usericon iconsetpath=""/>`
- Color in `<color value=""/>`
- Notes in `<remarks>`

### Data Delete (`t-x-d-d`)

Delete messages to remove entities.

```xml
<event version="2.0" uid="MARKER-123" type="t-x-d-d" ...>
    <detail>
        <link uid="MARKER-123" relation="p-p"/>
    </detail>
</event>
```

### Protocol Version (`t-x-takp-v`)

TAK protocol version announcement (informational).

---

## Code Examples

### Example 1: Parsing a Position Update

```swift
let xml = """
<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0" uid="ANDROID-123" type="a-f-G-U-C" time="2025-11-22T10:00:00Z" stale="2025-11-22T11:00:00Z">
    <point lat="37.7749" lon="-122.4194" hae="10.0"/>
    <detail>
        <contact callsign="Alpha-1"/>
        <__group name="Blue Team"/>
    </detail>
</event>
"""

if let eventType = CoTMessageParser.parse(xml: xml) {
    switch eventType {
    case .positionUpdate(let event):
        print("Received position: \(event.callsign) at \(event.coordinate)")
    default:
        break
    }
}
```

### Example 2: Generating a Chat Message

```swift
let message = ChatMessage(
    senderUID: "IOS-456",
    senderCallsign: "Bravo-2",
    recipientUID: "ANDROID-123",
    recipientCallsign: "Alpha-1",
    messageText: "Enemy spotted at coordinates",
    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
)

let conversation = Conversation(
    id: "chat-12345",
    participants: [/* ... */],
    isGroupChat: false
)

let cotXML = ChatCoTGenerator.generateGeoChatCoT(message: message, conversation: conversation)
TAKService.shared.send(cotMessage: cotXML)
```

### Example 3: Handling Events with Combine

```swift
class MapViewModel: ObservableObject {
    @Published var markers: [EnhancedCoTMarker] = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Subscribe to position updates
        CoTEventHandler.shared.positionUpdatePublisher
            .sink { [weak self] event in
                self?.updateMarker(from: event)
            }
            .store(in: &cancellables)

        // Subscribe to emergency alerts
        CoTEventHandler.shared.emergencyAlertPublisher
            .sink { [weak self] alert in
                self?.showEmergencyAlert(alert)
            }
            .store(in: &cancellables)
    }

    private func updateMarker(from event: CoTEvent) {
        if let index = markers.firstIndex(where: { $0.uid == event.uid }) {
            markers[index].update(from: event)
        } else {
            let marker = EnhancedCoTMarker(from: event)
            markers.append(marker)
        }
    }
}
```

### Example 4: Sending a Position Update

```swift
class PositionBroadcastService {
    func broadcastPosition(location: CLLocation, callsign: String) {
        let uid = "IOS-\(UIDevice.current.identifierForVendor?.uuidString ?? "Unknown")"
        let now = ISO8601DateFormatter().string(from: Date())
        let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(60))

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="a-f-G-U-C" time="\(now)" start="\(now)" stale="\(stale)" how="m-g">
            <point lat="\(location.coordinate.latitude)" lon="\(location.coordinate.longitude)" hae="\(location.altitude)" ce="9999999.0" le="9999999.0"/>
            <detail>
                <contact callsign="\(callsign)" endpoint="*:-1:stcp"/>
                <uid Droid="\(callsign)"/>
                <takv device="OmniTAK Mobile" platform="iOS" version="1.2.0"/>
                <track speed="\(location.speed)" course="\(location.course)"/>
            </detail>
        </event>
        """

        TAKService.shared.send(cotMessage: xml)
    }
}
```

### Example 5: Creating a Custom Event Handler

```swift
class MyCoTObserver {
    private var cancellables = Set<AnyCancellable>()

    func startObserving() {
        // Method 1: Combine publisher
        CoTEventHandler.shared.positionUpdatePublisher
            .filter { $0.team == "Red Team" }
            .sink { event in
                print("Red Team member updated: \(event.callsign)")
            }
            .store(in: &cancellables)

        // Method 2: NotificationCenter
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChatMessage),
            name: CoTEventHandler.chatMessageNotification,
            object: nil
        )
    }

    @objc private func handleChatMessage(_ notification: Notification) {
        if let message = notification.object as? ChatMessage {
            print("Chat received: \(message.messageText)")
        }
    }
}
```

---

## Integration Points

### With TAKService

```swift
// TAKService receives message and parses
func didReceiveMessage(_ xml: String) {
    if let eventType = CoTMessageParser.parse(xml: xml) {
        CoTEventHandler.shared.handle(event: eventType)
    }
}
```

### With ChatManager

```swift
// ChatManager generates and sends chat
func sendMessage(_ text: String, to recipient: String) {
    let message = createMessage(text, recipient)
    let xml = ChatCoTGenerator.generateGeoChatCoT(message: message, conversation: currentConversation)
    TAKService.shared.send(cotMessage: xml)
}
```

### With Map View

```swift
// Map subscribes to position updates
CoTEventHandler.shared.positionUpdatePublisher
    .receive(on: DispatchQueue.main)
    .sink { [weak self] event in
        self?.addOrUpdateAnnotation(for: event)
    }
    .store(in: &cancellables)
```

---

## Performance Considerations

### 1. **Buffered Receiving**

The receive buffer handles fragmented XML efficiently:

```swift
private var receiveBuffer: String = ""
private let bufferLock = NSLock()
```

### 2. **Regex Caching**

Parsers could cache regex patterns (future optimization):

```swift
private static let uidPattern = try! NSRegularExpression(pattern: "uid=\"([^\"]*)\"")
```

### 3. **Main Thread Dispatching**

UI updates always dispatched to main thread:

```swift
DispatchQueue.main.async {
    self.latestPositionUpdate = event
}
```

### 4. **Selective Parsing**

Only parse messages that match expected types:

```swift
guard eventType.hasPrefix("a-") || eventType == "b-t-f" else {
    return .unknown(eventType)
}
```

---

## Related Documentation

- **[Networking & TLS](Networking.md)** - TAKService and connection management
- **[Chat System](ChatSystem.md)** - GeoChat implementation details
- **[API Reference: CoT Types](../API/CoTTypes.md)** - Complete type catalog
- **[Architecture](../Architecture.md)** - Overall system design

---

_Last Updated: November 22, 2025_
