//
//  MeshtasticManager.swift
//  OmniTAK Mobile
//
//  High-level Meshtastic mesh network manager with state management
//

import Foundation
import Combine
import CoreBluetooth
import CoreLocation

@MainActor
public class MeshtasticManager: ObservableObject {

    // MARK: - Published Properties

    @Published public var devices: [MeshtasticDevice] = []
    @Published public var connectedDevice: MeshtasticDevice?
    @Published public var meshNodes: [MeshNode] = []
    @Published public var networkStats: MeshNetworkStats = MeshNetworkStats()
    @Published public var isScanning: Bool = false
    @Published public var signalHistory: [SignalStrengthReading] = []
    @Published public var lastError: String?

    // MARK: - Private Properties

    private var bridge: OmniTAKNativeBridge?
    private var connectionId: UInt64 = 0
    private var signalMonitorTimer: Timer?
    private var nodeDiscoveryTimer: Timer?

    // MARK: - Initialization

    public init(bridge: OmniTAKNativeBridge? = nil) {
        self.bridge = bridge
    }

    // MARK: - Device Discovery

    /// Scan for available Meshtastic devices
    public func scanForDevices() {
        isScanning = true
        lastError = nil

        // Discover Serial/USB devices
        discoverSerialDevices()

        // Discover Bluetooth devices
        discoverBluetoothDevices()

        // Discover TCP-enabled devices
        discoverTCPDevices()

        // Stop scanning after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.isScanning = false
        }
    }

    private func discoverSerialDevices() {
        #if os(macOS)
        let serialPaths = [
            "/dev/cu.usbserial",
            "/dev/cu.SLAB_USBtoUART",
            "/dev/cu.wchusbserial",
            "/dev/tty.usbserial"
        ]

        for basePath in serialPaths {
            if let paths = try? FileManager.default.contentsOfDirectory(atPath: "/dev")
                .filter({ $0.contains(basePath.replacingOccurrences(of: "/dev/", with: "")) })
                .map({ "/dev/\($0)" }) {

                for path in paths {
                    if !devices.contains(where: { $0.devicePath == path }) {
                        let device = MeshtasticDevice(
                            id: UUID().uuidString,
                            name: "Meshtastic USB",
                            connectionType: .serial,
                            devicePath: path,
                            isConnected: false,
                            lastSeen: Date()
                        )
                        devices.append(device)
                    }
                }
            }
        }
        #endif

        #if os(iOS)
        // iOS doesn't support direct serial access, but document for completeness
        // Users would need MFi-certified USB accessories
        #endif
    }

    private func discoverBluetoothDevices() {
        // Bluetooth LE scanning will be implemented in BluetoothManager
        // For now, add a placeholder for manual entry
        let btDevice = MeshtasticDevice(
            id: "bluetooth-manual",
            name: "Bluetooth Meshtastic (Manual)",
            connectionType: .bluetooth,
            devicePath: "00:00:00:00:00:00",
            isConnected: false
        )

        if !devices.contains(where: { $0.id == btDevice.id }) {
            devices.append(btDevice)
        }
    }

    private func discoverTCPDevices() {
        // Add common TCP device entry
        let tcpDevice = MeshtasticDevice(
            id: "tcp-local",
            name: "TCP Meshtastic (192.168.x.x)",
            connectionType: .tcp,
            devicePath: "192.168.1.100",
            isConnected: false
        )

        if !devices.contains(where: { $0.id == tcpDevice.id }) {
            devices.append(tcpDevice)
        }
    }

    // MARK: - Connection Management

    /// Connect to a Meshtastic device
    public func connect(to device: MeshtasticDevice) {
        guard let bridge = bridge else {
            lastError = "Native bridge not initialized"
            return
        }

        lastError = nil

        let config = MeshtasticConfig(
            connectionType: device.connectionType,
            devicePath: device.devicePath,
            port: device.connectionType == .tcp ? 4403 : nil,
            nodeId: device.nodeId,
            deviceName: device.name
        )

        connectionId = bridge.connectMeshtastic(config: config)

        if connectionId > 0 {
            var updatedDevice = device
            updatedDevice.isConnected = true
            updatedDevice.lastSeen = Date()

            connectedDevice = updatedDevice

            // Update device in list
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index] = updatedDevice
            }

            // Start monitoring
            startSignalMonitoring()
            startNodeDiscovery()

            print("✅ Connected to Meshtastic: \(device.name)")
        } else {
            lastError = "Failed to connect to \(device.name)"
            print("❌ Connection failed")
        }
    }

    /// Disconnect from current device
    public func disconnect() {
        guard let bridge = bridge, connectionId > 0 else { return }

        bridge.disconnect(connectionId: Int(connectionId))

        if var device = connectedDevice {
            device.isConnected = false
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index] = device
            }
        }

        connectedDevice = nil
        connectionId = 0

        stopSignalMonitoring()
        stopNodeDiscovery()

        print("⚡ Disconnected from Meshtastic")
    }

    // MARK: - Signal Monitoring

    private func startSignalMonitoring() {
        signalMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateSignalStrength()
            }
        }
    }

    private func stopSignalMonitoring() {
        signalMonitorTimer?.invalidate()
        signalMonitorTimer = nil
    }

    private func updateSignalStrength() {
        guard var device = connectedDevice else { return }

        // Simulate signal readings (real implementation would query device)
        let rssi = Int.random(in: -100...(-40))
        device.signalStrength = rssi

        let reading = SignalStrengthReading(
            timestamp: Date(),
            rssi: rssi,
            snr: Double.random(in: -10...20)
        )

        signalHistory.append(reading)

        // Keep only last 100 readings
        if signalHistory.count > 100 {
            signalHistory.removeFirst()
        }

        connectedDevice = device

        // Update in devices list
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
        }
    }

    // MARK: - Node Discovery

    private func startNodeDiscovery() {
        nodeDiscoveryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.discoverMeshNodes()
            }
        }

        // Immediate first discovery
        discoverMeshNodes()
    }

    private func stopNodeDiscovery() {
        nodeDiscoveryTimer?.invalidate()
        nodeDiscoveryTimer = nil
    }

    private func discoverMeshNodes() {
        // Parse NODEINFO_APP messages from connected Meshtastic device
        guard let device = connectedDevice else {
            print("⚠️ No connected device for node discovery")
            return
        }
        
        print("📡 Discovering mesh nodes from device: \(device.name)")
        
        var discoveredNodes: [MeshNode] = []
        
        // Query device for node database via bridge
        if let bridge = bridge, connectionId > 0 {
            // Request node database from device
            // In production, this would query the device's node DB via the bridge
            // For now, we simulate receiving protobuf messages
            
            // Simulate receiving NodeInfo protobuf messages from device
            // In real implementation, bridge would provide actual binary data
            let nodeData = getNodeDatabaseFromDevice()
            
            for data in nodeData {
                do {
                    // Parse NodeInfo protobuf message
                    if let nodeInfo = try MeshtasticProtobufParser.parseNodeInfo(from: data) {
                        // Convert NodeInfo to MeshNode
                        let meshPosition: MeshPosition?
                        if let pos = nodeInfo.position {
                            meshPosition = MeshPosition(
                                latitude: pos.latitude,
                                longitude: pos.longitude,
                                altitude: Int(pos.altitude)
                            )
                        } else {
                            meshPosition = nil
                        }
                        
                        let lastHeardDate = Date(timeIntervalSince1970: TimeInterval(nodeInfo.lastHeard))
                        
                        let node = MeshNode(
                            id: nodeInfo.num,
                            shortName: nodeInfo.user?.shortName ?? "NODE-\(nodeInfo.num)",
                            longName: nodeInfo.user?.longName ?? "Unknown Node",
                            position: meshPosition,
                            lastHeard: lastHeardDate,
                            snr: Double(nodeInfo.snr),
                            hopDistance: Int(nodeInfo.hopsAway),
                            batteryLevel: nodeInfo.deviceMetrics.map { Int($0.batteryLevel) }
                        )
                        
                        discoveredNodes.append(node)
                        print("✅ Parsed node: \(node.shortName) (SNR: \(node.snr ?? 0), Hops: \(node.hopDistance ?? 0))")
                    }
                } catch {
                    print("⚠️ Failed to parse NodeInfo protobuf: \(error)")
                }
            }
        } else {
            // Fallback: Generate simulated nodes for testing when no bridge available
            print("⚠️ No bridge connection, using simulated nodes for testing")
            let nodeCount = Int.random(in: 2...8)
            
            for i in 0..<nodeCount {
                let node = MeshNode(
                    id: UInt32.random(in: 0x10000000...0xFFFFFFFF),
                    shortName: "NODE-\(i+1)",
                    longName: "Mesh Node \(i+1)",
                    position: generateRandomNearbyPosition(),
                    lastHeard: Date().addingTimeInterval(-Double.random(in: 0...300)),
                    snr: Double.random(in: -10...15),
                    hopDistance: Int.random(in: 0...5),
                    batteryLevel: Int.random(in: 20...100)
                )
                discoveredNodes.append(node)
            }
        }
        
        // Update mesh nodes
        meshNodes = discoveredNodes
        
        // Calculate network statistics
        let activeNodes = discoveredNodes.filter { 
            Date().timeIntervalSince($0.lastHeard) < 300 // 5 minutes
        }
        
        let avgHops = discoveredNodes.compactMap { $0.hopDistance }.reduce(0, +)
        let hopCount = Double(max(discoveredNodes.filter { $0.hopDistance != nil }.count, 1))
        
        networkStats = MeshNetworkStats(
            connectedNodes: activeNodes.count,
            totalNodes: discoveredNodes.count,
            averageHops: Double(avgHops) / hopCount,
            packetSuccessRate: calculatePacketSuccessRate(),
            networkUtilization: calculateNetworkUtilization(),
            lastUpdate: Date()
        )
        
        print("📡 Discovered \(discoveredNodes.count) mesh nodes (\(activeNodes.count) active)")
    }
    
    private func generateRandomNearbyPosition() -> MeshPosition? {
        // Generate position within ~10km radius for testing
        let baseLat = 37.7749
        let baseLon = -122.4194
        let latOffset = Double.random(in: -0.1...0.1)
        let lonOffset = Double.random(in: -0.1...0.1)
        return MeshPosition(
            latitude: baseLat + latOffset,
            longitude: baseLon + lonOffset,
            altitude: Int.random(in: 0...500)
        )
    }
    
    private func calculatePacketSuccessRate() -> Double {
        // Calculate based on received vs sent packets
        // In production, query device statistics
        return Double.random(in: 0.85...0.98)
    }
    
    private func calculateNetworkUtilization() -> Double {
        // Calculate channel utilization percentage
        // In production, query device for channel activity
        return Double.random(in: 0.15...0.45)
    }

    // MARK: - Messaging

    /// Send a CoT message through the mesh
    public func sendCoT(_ cotXML: String) -> Bool {
        guard let bridge = bridge, connectionId > 0 else {
            lastError = "Not connected to Meshtastic device"
            return false
        }

        let result = bridge.sendCot(connectionId: Int(connectionId), cotXml: cotXML)

        if result == 0 {
            print("📡 Sent CoT through mesh network")
            return true
        } else {
            lastError = "Failed to send CoT message"
            print("❌ Failed to send CoT")
            return false
        }
    }

    /// Get signal quality for current connection
    public var signalQuality: SignalQuality {
        return SignalQuality.from(rssi: connectedDevice?.signalStrength)
    }

    /// Check if device is connected
    public var isConnected: Bool {
        return connectedDevice?.isConnected ?? false
    }

    /// Get formatted connection status
    public var connectionStatus: String {
        if let device = connectedDevice {
            return "Connected: \(device.name)"
        } else {
            return "Not Connected"
        }
    }

    /// Get mesh network health indicator
    public var networkHealth: NetworkHealth {
        if !isConnected {
            return .disconnected
        }

        let connectedRatio = Double(networkStats.connectedNodes) / Double(max(networkStats.totalNodes, 1))

        if connectedRatio > 0.8 && networkStats.packetSuccessRate > 0.9 {
            return .excellent
        } else if connectedRatio > 0.6 && networkStats.packetSuccessRate > 0.7 {
            return .good
        } else if connectedRatio > 0.4 {
            return .fair
        } else {
            return .poor
        }
    }
    
    // MARK: - Protobuf Message Handling
    
    /// Get node database from connected device
    /// In production, this queries the device via bridge and returns binary protobuf data
    private func getNodeDatabaseFromDevice() -> [Data] {
        // This method would interface with the native bridge to request node database
        // For now, return empty array - actual implementation requires bridge enhancement
        
        // Example of what bridge would provide:
        // bridge.requestNodeDatabase(connectionId) -> [Data] of serialized NodeInfo messages
        
        return []
    }
    
    /// Parse incoming Meshtastic packet
    /// Call this when receiving data from the mesh network
    public func handleIncomingPacket(data: Data) {
        do {
            // Parse MeshPacket envelope
            guard let packet = try MeshtasticProtobufParser.parseMeshPacket(from: data) else {
                print("⚠️ Failed to parse MeshPacket")
                return
            }
            
            print("📨 Received packet from node: \(packet.from)")
            
            // Extract payload based on variant
            let payloadData: Data
            switch packet.payloadVariant {
            case .decoded(let data):
                payloadData = data
            case .encrypted(let data):
                print("🔒 Encrypted packet - decryption not yet implemented")
                payloadData = data
            }
            
            // Parse Data message to determine port/type
            if let dataMsg = try MeshtasticProtobufParser.parseData(from: payloadData) {
                handleDataMessage(dataMsg, packet: packet)
            }
            
        } catch {
            print("⚠️ Failed to parse incoming packet: \(error)")
        }
    }
    
    /// Handle different types of data messages
    private func handleDataMessage(_ dataMsg: MeshtasticData, packet: MeshPacket) {
        switch dataMsg.portnum {
        case .nodeinfoApp:
            // Node information update
            if let nodeInfo = try? MeshtasticProtobufParser.parseNodeInfo(from: dataMsg.payload) {
                updateNodeInfo(nodeInfo)
            }
            
        case .positionApp:
            // Position update
            if let position = try? MeshtasticProtobufParser.parsePosition(from: dataMsg.payload) {
                updateNodePosition(nodeId: packet.from, position: position)
            }
            
        case .textMessageApp:
            // Text message received
            if let message = String(data: dataMsg.payload, encoding: .utf8) {
                print("💬 Message from \(packet.from): \(message)")
            }
            
        case .telemetryApp:
            // Telemetry data (metrics, battery, etc)
            print("📊 Telemetry received from node \(packet.from)")
            
        default:
            print("📦 Received message on port: \(dataMsg.portnum)")
        }
    }
    
    /// Update node information from parsed NodeInfo
    private func updateNodeInfo(_ nodeInfo: NodeInfo) {
        // Update or add node to mesh nodes list
        if let index = meshNodes.firstIndex(where: { $0.id == nodeInfo.num }) {
            // Update existing node
            var updatedNode = meshNodes[index]
            updatedNode.shortName = nodeInfo.user?.shortName ?? updatedNode.shortName
            updatedNode.longName = nodeInfo.user?.longName ?? updatedNode.longName
            updatedNode.lastHeard = Date(timeIntervalSince1970: TimeInterval(nodeInfo.lastHeard))
            
            if let pos = nodeInfo.position {
                updatedNode.position = MeshPosition(
                    latitude: pos.latitude,
                    longitude: pos.longitude,
                    altitude: Int(pos.altitude)
                )
            }
            
            if let metrics = nodeInfo.deviceMetrics {
                updatedNode.batteryLevel = Int(metrics.batteryLevel)
            }
            
            meshNodes[index] = updatedNode
            print("🔄 Updated node: \(updatedNode.shortName)")
        } else {
            // Add new node
            let newNode = MeshNode(
                id: nodeInfo.num,
                shortName: nodeInfo.user?.shortName ?? "NODE-\(nodeInfo.num)",
                longName: nodeInfo.user?.longName ?? "Unknown Node",
                position: nodeInfo.position.map { MeshPosition(
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    altitude: Int($0.altitude)
                )},
                lastHeard: Date(timeIntervalSince1970: TimeInterval(nodeInfo.lastHeard)),
                snr: Double(nodeInfo.snr),
                hopDistance: Int(nodeInfo.hopsAway),
                batteryLevel: nodeInfo.deviceMetrics.map { Int($0.batteryLevel) }
            )
            meshNodes.append(newNode)
            print("➕ Added new node: \(newNode.shortName)")
        }
    }
    
    /// Update node position from parsed Position message
    private func updateNodePosition(nodeId: UInt32, position: Position) {
        if let index = meshNodes.firstIndex(where: { $0.id == nodeId }) {
            var updatedNode = meshNodes[index]
            updatedNode.position = MeshPosition(
                latitude: position.latitude,
                longitude: position.longitude,
                altitude: Int(position.altitude)
            )
            updatedNode.lastHeard = Date()
            meshNodes[index] = updatedNode
            print("📍 Updated position for node: \(updatedNode.shortName)")
        }
    }
}

// MARK: - Supporting Types

public struct SignalStrengthReading: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let rssi: Int
    public let snr: Double
}

public enum NetworkHealth {
    case disconnected
    case poor
    case fair
    case good
    case excellent

    var color: String {
        switch self {
        case .disconnected: return "gray"
        case .poor: return "red"
        case .fair: return "orange"
        case .good: return "blue"
        case .excellent: return "green"
        }
    }

    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
}
