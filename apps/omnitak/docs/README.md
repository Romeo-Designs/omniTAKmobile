# OmniTAK Mobile Documentation

## Overview

**OmniTAK Mobile** is a full-featured native iOS tactical awareness application designed to provide ATAK (Android Team Awareness Kit) compatibility on Apple devices. It implements the CoT (Cursor on Target) messaging protocol for real-time tactical situational awareness, map visualization, secure communications, and mission coordination.

**Current Version:** 1.2.0  
**Platform:** iOS 15.0+  
**Language:** Swift/SwiftUI  
**License:** Proprietary

---

## Documentation Structure

### 📐 Architecture Documentation

- **[Architecture Overview](Architecture.md)** - System architecture, design patterns, and component relationships
- **[Data Flow](DataFlow.md)** - How data moves through the application
- **[State Management](StateManagement.md)** - Reactive programming with Combine framework

### 🎯 Feature Documentation

- **[CoT Messaging System](Features/CoTMessaging.md)** - Cursor on Target protocol implementation ✅
- **[Map System](Features/MapSystem.md)** - MapKit integration, markers, overlays, and tile sources ✅
- **[Networking & TLS](Features/Networking.md)** - TAK server connectivity and TLS configuration ✅
- **[Chat System](Features/ChatSystem.md)** - GeoChat protocol and messaging ✅

### 📚 API Reference

- **[Managers API](API/Managers.md)** - State management classes (11 managers) ✅
- **[Services API](API/Services.md)** - Business logic and integrations (27 services) ✅
- **[Models API](API/Models.md)** - Data structures and entities (23 model files) ✅

### 👤 User Guides

- **[Getting Started](UserGuide/GettingStarted.md)** - Installation and first-time setup ✅
- **[Features Guide](UserGuide/Features.md)** - Complete feature walkthrough ✅
- **[Troubleshooting](UserGuide/Troubleshooting.md)** - Common issues and solutions ✅
- **[Settings Reference](UserGuide/Settings.md)** - All configuration options explained ✅

### 🔧 Developer Guide

- **[Getting Started](DeveloperGuide/GettingStarted.md)** - Development environment setup ✅
- **[Codebase Navigation](DeveloperGuide/CodebaseNavigation.md)** - File organization and structure ✅
- **[Coding Patterns](DeveloperGuide/CodingPatterns.md)** - Best practices and conventions ✅

---

## Quick Links

### For New Users

1. [Getting Started Guide](UserGuide/GettingStarted.md)
2. [Connecting to a TAK Server](UserGuide/ServerConnection.md)
3. [Basic Features Overview](UserGuide/Features.md)

### For Developers

1. [Development Environment Setup](DeveloperGuide/GettingStarted.md)
2. [Architecture Overview](Architecture.md)
3. [Coding Patterns & Best Practices](DeveloperGuide/CodingPatterns.md)

### For System Administrators

1. [Server Connection Guide](UserGuide/ServerConnection.md)
2. [Certificate Management](Features/CertificateManagement.md)
3. [TLS Configuration](Features/Networking.md#tls-configuration)

---

## Key Features

### 🗺️ Map & Visualization

- Apple MapKit with custom tile sources (ArcGIS, OSM)
- MIL-STD-2525 military symbology
- MGRS grid overlay
- 3D terrain visualization
- Breadcrumb trails
- Offline map caching

### 📡 Communications

- CoT (Cursor on Target) protocol
- TCP, UDP, and TLS connectivity
- Multi-server federation
- Real-time position updates
- GeoChat messaging
- Emergency beacon (911, Ring the Bell, In Contact)

### 🔐 Security

- Client certificate authentication
- TLS 1.0-1.3 support
- Keychain integration
- QR code enrollment
- Self-signed CA support

### 🛠️ Tools & Features

- Drawing tools (marker, line, circle, polygon)
- Measurement tools (distance, bearing, area)
- Route planning with navigation
- Waypoint management
- Geofencing with alerts
- Data package import/export
- Tactical report generation (CAS, MEDEVAC, SPOTREP)

### 🌐 Off-Grid Capability

- Meshtastic mesh networking
- Offline map tiles
- Message queue for intermittent connectivity
- Background position broadcasting

---

## Technology Stack

### Frameworks

- **SwiftUI** - Modern declarative UI framework
- **Combine** - Reactive programming and state management
- **MapKit** - Map rendering and location services
- **Network** - Modern networking with NWConnection
- **Security** - Keychain and certificate management
- **CoreLocation** - GPS tracking and geofencing
- **UserNotifications** - Local and push notifications
- **CoreBluetooth** - Bluetooth LE for Meshtastic

### External Services

- **ArcGIS REST Services** - Basemap tile sources
- **OpenStreetMap** - Open tile source
- **TAK Server** - Tactical awareness server

### Design Patterns

- **MVVM** (Model-View-ViewModel)
- **Reactive Programming** (Combine Publishers)
- **Singleton** (Shared managers)
- **Delegate** (Event handling)
- **Observer** (State observation)

---

## Project Statistics

| Metric               | Value          |
| -------------------- | -------------- |
| **Swift Files**      | 150+           |
| **Lines of Code**    | 25,000+        |
| **Managers**         | 11             |
| **Services**         | 27             |
| **Views**            | 60+            |
| **Models**           | 23 model files |
| **CoT Event Types**  | 6+ supported   |
| **Map Tile Sources** | 8+ basemaps    |
| **Supported iOS**    | 15.0+          |

---

## Documentation Conventions

### Code Examples

All code examples in this documentation are written in Swift and follow the project's coding standards. Examples are fully functional unless otherwise noted.

### File Paths

File paths are shown relative to the project root:

```
OmniTAKMobile/
  Core/
    OmniTAKMobileApp.swift
  Managers/
    ServerManager.swift
```

### Symbols

- 📁 **Folder/Directory**
- 📄 **File**
- 🔧 **Configuration**
- ⚙️ **Setting**
- 🔐 **Security-related**
- 📡 **Network-related**
- 🗺️ **Map-related**

### Terminology

- **CoT** - Cursor on Target (tactical messaging protocol)
- **TAK** - Team Awareness Kit (tactical awareness system)
- **ATAK** - Android Team Awareness Kit
- **GeoChat** - Location-aware chat system
- **MGRS** - Military Grid Reference System
- **MIL-STD-2525** - Military symbology standard
- **TLS** - Transport Layer Security

---

## Contributing to Documentation

Found an error or want to improve the documentation? See the [Contributing Guide](DeveloperGuide/Contributing.md) for information on how to submit documentation updates.

---

## Support & Resources

- **GitHub Repository**: [omniTAKmobile](https://github.com/tyroe1998/omniTAKmobile)
- **Issue Tracker**: Report bugs and feature requests
- **Original README**: See [../README.md](../README.md) for quick start guide

---

## Version History

| Version | Date     | Changes                                                                                     |
| ------- | -------- | ------------------------------------------------------------------------------------------- |
| 1.2.0   | Nov 2025 | Certificate enrollment, enhanced CoT receiving, emergency beacon, KML import, photo sharing |
| 1.1.0   | Oct 2025 | Multi-server federation, offline maps, data packages                                        |
| 1.0.0   | Sep 2025 | Initial release with core TAK functionality                                                 |

---

_Last Updated: November 22, 2025_
