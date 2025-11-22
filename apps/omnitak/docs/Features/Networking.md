# Networking & TLS Configuration

## Table of Contents

- [Overview](#overview)
- [TAKService Architecture](#takservice-architecture)
- [Connection Protocols](#connection-protocols)
- [TLS Configuration](#tls-configuration)
- [Certificate Authentication](#certificate-authentication)
- [Network Security](#network-security)
- [Connection Management](#connection-management)
- [Message Queue](#message-queue)
- [Troubleshooting](#troubleshooting)
- [Code Examples](#code-examples)

---

## Overview

The networking layer of OmniTAK Mobile handles all communication with TAK servers using industry-standard protocols. Built on Apple's modern Network framework, it provides reliable, secure connections with automatic reconnection and message queuing.

### Key Features

- ✅ TCP, UDP, and TLS protocols
- ✅ TLS 1.0-1.3 support (including legacy)
- ✅ Client certificate authentication
- ✅ Self-signed CA acceptance
- ✅ Automatic reconnection
- ✅ Message queue for offline operation
- ✅ Fragmented XML handling
- ✅ Connection statistics

### Files

- **Main Service**: `OmniTAKMobile/Services/TAKService.swift` (1105 lines)
- **Certificate Management**: `OmniTAKMobile/Managers/CertificateManager.swift` (436 lines)
- **Models**: `OmniTAKMobile/Models/ServerModels.swift`

---

## TAKService Architecture

### Class Structure

```swift
class TAKService: ObservableObject {
    // Connection state
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"

    // Statistics
    @Published var messagesSent: Int = 0
    @Published var messagesReceived: Int = 0
    @Published var bytesSent: Int = 0
    @Published var bytesReceived: Int = 0

    // Network sender
    private var sender: DirectTCPSender?

    // Message queue
    private var messageQueue: [String] = []
}
```

### DirectTCPSender

Low-level network communication class:

```swift
class DirectTCPSender {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.omnitak.network")

    // Receive buffer for fragmented XML
    private var receiveBuffer: String = ""
    private let bufferLock = NSLock()

    // Callbacks
    var onMessageReceived: ((String) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?

    // Statistics
    private(set) var bytesReceived: Int = 0
    private(set) var messagesReceived: Int = 0
}
```

### Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    TAKService                           │
│             (ObservableObject)                          │
│                                                         │
│  @Published var isConnected: Bool                      │
│  @Published var connectionStatus: String               │
│                                                         │
│  ┌────────────────────────────────────────┐            │
│  │      DirectTCPSender                   │            │
│  │  • NWConnection (Network.framework)    │            │
│  │  • Receive buffer (fragmented XML)     │            │
│  │  • Message callbacks                   │            │
│  └────────────┬───────────────────────────┘            │
│               │                                         │
│               ▼                                         │
│  ┌────────────────────────────────────────┐            │
│  │      TCP/UDP/TLS Socket                │            │
│  │  • Protocol negotiation                │            │
│  │  • TLS handshake                       │            │
│  │  • Certificate authentication          │            │
│  └────────────┬───────────────────────────┘            │
└───────────────┼─────────────────────────────────────────┘
                │
                ▼
        ┌───────────────┐
        │  TAK Server   │
        └───────────────┘
```

---

## Connection Protocols

### TCP (Transmission Control Protocol)

**Use case:** Reliable connection, no encryption

```swift
func connect(host: String, port: UInt16, protocolType: "tcp") {
    let parameters = NWParameters.tcp
    connection = NWConnection(to: endpoint, using: parameters)
    connection?.start(queue: queue)
}
```

**Characteristics:**

- ✅ Reliable, ordered delivery
- ✅ Automatic retransmission
- ❌ No encryption
- ❌ Visible to network observers

**When to use:**

- Development/testing on trusted networks
- Internal networks behind firewall
- When TLS overhead is not acceptable

### UDP (User Datagram Protocol)

**Use case:** Low-latency, connectionless

```swift
func connect(host: String, port: UInt16, protocolType: "udp") {
    let parameters = NWParameters.udp
    connection = NWConnection(to: endpoint, using: parameters)
    connection?.start(queue: queue)
}
```

**Characteristics:**

- ✅ Low latency
- ✅ No connection overhead
- ❌ No delivery guarantee
- ❌ No encryption
- ❌ Messages may arrive out of order

**When to use:**

- High-frequency position updates
- Networks with very low latency requirements
- When packet loss is acceptable

### TLS (Transport Layer Security)

**Use case:** Secure, encrypted communication (RECOMMENDED)

```swift
func connect(
    host: String,
    port: UInt16,
    protocolType: "tls",
    certificateName: String?,
    certificatePassword: String?,
    allowLegacyTLS: Bool = false
) {
    let tlsOptions = NWProtocolTLS.Options()
    let secOptions = tlsOptions.securityProtocolOptions

    // Configure TLS version
    if allowLegacyTLS {
        sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv10)
    } else {
        sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv12)
    }
    sec_protocol_options_set_max_tls_protocol_version(secOptions, .TLSv13)

    // Load client certificate
    if let identity = loadClientCertificate(name: certificateName, password: certificatePassword) {
        sec_protocol_options_set_local_identity(secOptions, identity)
    }

    connection = NWConnection(to: endpoint, using: NWParameters(tls: tlsOptions))
}
```

**Characteristics:**

- ✅ End-to-end encryption
- ✅ Certificate-based authentication
- ✅ Data integrity verification
- ✅ Industry standard security
- ⚠️ Slightly higher latency

**When to use:**

- Production deployments (REQUIRED)
- Internet connections
- Sensitive tactical data
- Client certificate authentication

---

## TLS Configuration

### TLS Version Support

OmniTAK supports TLS 1.0 through 1.3:

| Version     | Status         | Security | Use Case                  |
| ----------- | -------------- | -------- | ------------------------- |
| **TLS 1.3** | ✅ Recommended | Highest  | Modern TAK servers        |
| **TLS 1.2** | ✅ Default     | High     | Most TAK servers          |
| **TLS 1.1** | ⚠️ Legacy only | Medium   | Old servers (opt-in)      |
| **TLS 1.0** | ⚠️ Legacy only | Low      | Very old servers (opt-in) |

### Default Configuration (Secure)

```swift
// TLS 1.2 minimum (secure)
sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv12)
sec_protocol_options_set_max_tls_protocol_version(secOptions, .TLSv13)
```

### Legacy Configuration (Less Secure)

```swift
// TLS 1.0+ for old servers
// ⚠️ WARNING: Reduces security
sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv10)
```

**Enable legacy mode:**

1. Settings > Servers > Edit Server
2. Enable "Allow Legacy TLS" toggle
3. Save and reconnect

### Cipher Suites

OmniTAK supports legacy cipher suites for compatibility with older TAK servers:

```swift
// Modern cipher suites (preferred)
sec_protocol_options_append_tls_ciphersuite(secOptions,
    TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384)
sec_protocol_options_append_tls_ciphersuite(secOptions,
    TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256)

// Legacy cipher suites (compatibility)
sec_protocol_options_append_tls_ciphersuite(secOptions,
    TLS_RSA_WITH_AES_256_GCM_SHA384)
sec_protocol_options_append_tls_ciphersuite(secOptions,
    TLS_RSA_WITH_AES_256_CBC_SHA)
```

**Cipher Suite Priority:**

1. ECDHE + AES-GCM (best)
2. RSA + AES-GCM (good)
3. RSA + AES-CBC (acceptable for legacy)

### Self-Signed Certificate Acceptance

TAK servers typically use self-signed certificates:

```swift
sec_protocol_options_set_verify_block(secOptions, { (metadata, trust, complete) in
    // Accept all server certificates (similar to verify_server: false)
    complete(true)
}, .main)
```

**Security Implications:**

- ⚠️ Bypasses certificate chain validation
- ⚠️ Vulnerable to MITM attacks
- ✅ Necessary for self-signed TAK server CAs
- ✅ Client certificate still provides authentication

---

## Certificate Authentication

### Certificate Types

#### 1. Server Certificate (Server-side)

- Identifies the TAK server
- Self-signed or CA-signed
- Validated by client (or bypassed for self-signed)

#### 2. Client Certificate (Client-side)

- Identifies the iOS device/user
- Required for TAK Server 5.5+
- Stored in iOS Keychain as .p12 (PKCS#12)

### Certificate Import Flow

```
User has certificate.p12 + password
         │
         ▼
┌─────────────────────────────────────┐
│  CertificateManager.importCertificate()
│  1. Read .p12 file data
│  2. Extract SecIdentity
│  3. Validate certificate
│  4. Store in iOS Keychain
└─────────┬───────────────────────────┘
          │
          ▼
┌─────────────────────────────────────┐
│  SecIdentity stored in Keychain
│  • Private key (encrypted)
│  • Public certificate
│  • Metadata (expiry, issuer)
└─────────┬───────────────────────────┘
          │
          ▼
┌─────────────────────────────────────┐
│  TAKService uses identity for TLS
│  sec_protocol_options_set_local_identity()
└─────────────────────────────────────┘
```

### Certificate Storage

Certificates are stored in iOS Keychain using `kSecClassGenericPassword`:

```swift
func saveCertificate(_ name: String, data: Data, password: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: name,
        kSecAttrService as String: "com.omnitak.certificates",
        kSecValueData as String: data
    ]

    // Store password separately
    let passwordQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "\(name)_password",
        kSecAttrService as String: "com.omnitak.certificates",
        kSecValueData as String: password.data(using: .utf8)!
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    let passwordStatus = SecItemAdd(passwordQuery as CFDictionary, nil)
}
```

### Certificate Validation

```swift
func validateCertificate(_ certificate: TAKCertificate) -> CertificateValidationResult {
    let now = Date()

    if certificate.expiryDate < now {
        return .expired
    } else if certificate.expiryDate.timeIntervalSince(now) < 30 * 24 * 3600 {
        return .expiringSoon
    } else {
        return .valid
    }
}
```

### Using Certificate for Connection

```swift
// Load identity from Keychain
func loadClientCertificate(name: String, password: String) -> SecIdentity? {
    guard let (data, _) = try? CertificateManager.shared.getCertificateData(for: name),
          let identity = try? CertificateManager.shared.getIdentity(for: data, password: password) else {
        return nil
    }
    return identity
}

// Apply to TLS connection
if let identity = loadClientCertificate(name: certName, password: certPassword) {
    sec_protocol_options_set_local_identity(secOptions, identity)
}
```

---

## Network Security

### Security Best Practices

1. **Always Use TLS in Production**

   ```swift
   // ✅ Good
   server.protocol = "tls"
   server.useTLS = true

   // ❌ Bad (unless development)
   server.protocol = "tcp"
   ```

2. **Use Strong Certificates**
   - 2048-bit RSA minimum
   - Valid expiry dates
   - Proper certificate chain

3. **Avoid Legacy TLS**
   - Only enable for old servers
   - Request server upgrade to TLS 1.2+

4. **Secure Certificate Storage**
   - iOS Keychain provides encryption
   - Never store passwords in UserDefaults
   - Clear certificates on app uninstall

### Network Permissions

Required Info.plist keys:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Purpose:**

- Allows TLS connections with self-signed certificates
- Enables local network server discovery
- Required for TAK server compatibility

---

## Connection Management

### Connection Lifecycle

```
Disconnected
     │
     │ connect()
     ▼
  Waiting
     │
     │ TLS handshake
     ▼
   Ready ──────┐
     │         │
     │         │ Network error
     │         ▼
     │     Failed
     │         │
     │         │ reconnect()
     └─────────┘
```

### Automatic Reconnection

```swift
func reconnect() {
    guard !isConnected else { return }

    reconnectAttempts += 1
    let delay = min(reconnectAttempts * 5, 30) // Max 30 seconds

    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
        self.connect(
            host: self.currentServer.host,
            port: self.currentServer.port,
            // ... other parameters
        )
    }
}
```

**Reconnect Strategy:**

- Initial delay: 5 seconds
- Exponential backoff: 5s, 10s, 15s, 20s, 25s, 30s
- Maximum delay: 30 seconds
- Continues until successful or user disconnects

### Connection State Monitoring

```swift
connection?.stateUpdateHandler = { state in
    switch state {
    case .ready:
        print("✅ Connected")
        self.onConnectionStateChanged?(true)
        self.startReceiveLoop()

    case .failed(let error):
        print("❌ Connection failed: \(error)")
        self.onConnectionStateChanged?(false)
        self.scheduleReconnect()

    case .waiting(let error):
        print("⏳ Waiting to connect: \(error)")

    case .cancelled:
        print("🔌 Connection cancelled")
        self.onConnectionStateChanged?(false)

    default:
        break
    }
}
```

---

## Message Queue

### Queue Architecture

Messages are queued when offline and sent when connection restores:

```swift
class TAKService {
    private var messageQueue: [QueuedMessage] = []
    private let queueLimit = 1000

    struct QueuedMessage {
        let xml: String
        let timestamp: Date
        let priority: MessagePriority
        var retryCount: Int = 0
    }
}
```

### Sending with Queue

```swift
func send(cotMessage xml: String, priority: MessagePriority = .normal) {
    if isConnected {
        // Send immediately
        sendDirect(xml)
    } else {
        // Queue for later
        let message = QueuedMessage(xml: xml, timestamp: Date(), priority: priority)
        messageQueue.append(message)

        // Limit queue size
        if messageQueue.count > queueLimit {
            messageQueue.removeFirst()
        }
    }
}
```

### Queue Processing

```swift
func processMessageQueue() {
    guard isConnected, !messageQueue.isEmpty else { return }

    // Sort by priority and timestamp
    messageQueue.sort { (msg1, msg2) in
        if msg1.priority != msg2.priority {
            return msg1.priority.rawValue > msg2.priority.rawValue
        }
        return msg1.timestamp < msg2.timestamp
    }

    // Send queued messages
    while !messageQueue.isEmpty && isConnected {
        let message = messageQueue.removeFirst()
        sendDirect(message.xml)
    }
}
```

### Message Priorities

```swift
enum MessagePriority: Int {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}
```

**Priority Guidelines:**

- **Critical**: Emergency alerts (911, In Contact)
- **High**: Chat messages, tactical reports
- **Normal**: Position updates
- **Low**: Bulk data, analytics

---

## Troubleshooting

### Connection Issues

#### Cannot Connect

**Diagnostic steps:**

```swift
// 1. Test basic connectivity
let url = URL(string: "https://\(host):\(port)")!
URLSession.shared.dataTask(with: url) { data, response, error in
    // Check if server is reachable
}

// 2. Verify TLS handshake
let parameters = NWParameters(tls: tlsOptions)
let connection = NWConnection(to: endpoint, using: parameters)
// Monitor state updates

// 3. Check certificate
if let identity = loadClientCertificate() {
    print("✅ Certificate loaded")
} else {
    print("❌ Certificate not found")
}
```

#### SSL Errors

**Common errors and solutions:**

| Error                   | Cause                | Solution                |
| ----------------------- | -------------------- | ----------------------- |
| `SSL handshake failed`  | TLS version mismatch | Enable legacy TLS       |
| `Certificate not found` | Missing client cert  | Import .p12 file        |
| `Invalid certificate`   | Wrong password       | Verify password         |
| `Certificate expired`   | Expired cert         | Request new certificate |

#### Connection Drops

**Enable aggressive reconnect:**

```swift
// Settings > Network
self.reconnectInterval = 10 // seconds
self.enableAggressiveReconnect = true
```

### Performance Monitoring

```swift
// Connection statistics
print("TX: \(messagesSent) messages, \(bytesSent) bytes")
print("RX: \(messagesReceived) messages, \(bytesReceived) bytes")

// Latency measurement
let startTime = Date()
send(cotMessage: testMessage)
// Measure response time
let latency = Date().timeIntervalSince(startTime)
```

---

## Code Examples

### Example 1: Basic TCP Connection

```swift
let takService = TAKService()

takService.connect(
    host: "192.168.1.100",
    port: 8087,
    protocolType: "tcp"
) { success in
    if success {
        print("Connected via TCP")
    }
}
```

### Example 2: Secure TLS Connection with Certificate

```swift
// Import certificate
let certData = try Data(contentsOf: certURL)
let cert = try CertificateManager.shared.importCertificate(
    from: certData,
    password: "mypassword"
)

// Connect with TLS
takService.connect(
    host: "tak.example.com",
    port: 8089,
    protocolType: "tls",
    useTLS: true,
    certificateName: cert.name,
    certificatePassword: "mypassword"
) { success in
    if success {
        print("Connected via TLS with client certificate")
    }
}
```

### Example 3: Monitor Connection State

```swift
takService.$isConnected
    .sink { connected in
        if connected {
            print("✅ Connected - can send messages")
        } else {
            print("❌ Disconnected - messages queued")
        }
    }
    .store(in: &cancellables)
```

### Example 4: Send with Automatic Queuing

```swift
// Sends immediately if connected, queues if offline
takService.send(cotMessage: positionUpdateXML, priority: .normal)

// Emergency message (highest priority)
takService.send(cotMessage: emergencyAlertXML, priority: .critical)
```

### Example 5: Legacy TLS for Old Servers

```swift
takService.connect(
    host: "oldserver.mil",
    port: 8089,
    protocolType: "tls",
    useTLS: true,
    allowLegacyTLS: true  // ⚠️ Enable TLS 1.0/1.1
) { success in
    print("Connected with legacy TLS")
}
```

---

## Related Documentation

- **[Architecture](../Architecture.md)** - System architecture overview
- **[Certificate Management](CertificateManagement.md)** - Detailed certificate guide
- **[CoT Messaging](CoTMessaging.md)** - Protocol implementation
- **[Troubleshooting](../UserGuide/Troubleshooting.md#connection-issues)** - User-facing issues

---

_Last Updated: November 22, 2025_
