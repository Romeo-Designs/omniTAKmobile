//
//  MeshtasticProtoMessages.swift
//  OmniTAKMobile
//
//  Meshtastic Protobuf message structures
//  Based on Meshtastic protocol specifications
//

import Foundation

// MARK: - Protobuf Message Types

/// Main message envelope for Meshtastic mesh packets
public struct MeshPacket {
    var from: UInt32
    var to: UInt32
    var channel: UInt32
    var id: UInt32
    var rxTime: UInt32
    var rxSnr: Float
    var hopLimit: UInt32
    var wantAck: Bool
    var priority: Priority
    var rxRssi: Int32
    var delayed: UInt32
    var wantResponse: Bool
    var payloadVariant: PayloadVariant
    
    enum Priority: Int {
        case unset = 0
        case min = 1
        case background = 10
        case `default` = 64
        case reliable = 70
        case ack = 120
        case max = 127
    }
    
    enum PayloadVariant {
        case decoded(Data)
        case encrypted(Data)
    }
}

/// Node information message
public struct NodeInfo {
    var num: UInt32
    var user: User?
    var position: Position?
    var snr: Float
    var lastHeard: UInt32
    var deviceMetrics: DeviceMetrics?
    var channel: UInt32
    var viaMqtt: Bool
    var hopsAway: UInt32
}

/// User information
public struct User {
    var id: String
    var longName: String
    var shortName: String
    var macaddr: Data
    var hwModel: HardwareModel
    var isLicensed: Bool
    var role: Role
    
    enum HardwareModel: Int {
        case unset = 0
        case tloraV2 = 1
        case tloraV1 = 2
        case tloraV21 = 3
        case tbeam = 4
        case heltec = 5
        case tbeamV07 = 6
        case techo = 7
        case tloraV21_16 = 8
        case stationG1 = 25
        case rak4631 = 26
        case htcc_ab02s = 27
        case htcc_ab02 = 28
        case tbeamS3_core = 29
        case rak11200 = 30
        case nano_g1 = 31
        case tloraT3s3 = 32
        case nano_g1_explorer = 33
        case stationG2 = 34
    }
    
    enum Role: Int {
        case client = 0
        case clientMute = 1
        case router = 2
        case routerClient = 3
    }
}

/// Position information
public struct Position {
    var latitudeI: Int32  // Latitude * 1e-7
    var longitudeI: Int32 // Longitude * 1e-7
    var altitude: Int32
    var time: UInt32
    var locationSource: LocationSource
    var altitudeSource: AltitudeSource
    var timestamp: UInt32
    var timestampMillisAdjust: Int32
    var altitudeHae: Int32
    var altitudeGeoidalSeparation: Int32
    var pdop: UInt32
    var hdop: UInt32
    var vdop: UInt32
    var gpsAccuracy: UInt32
    var groundSpeed: UInt32
    var groundTrack: UInt32
    var fixQuality: UInt32
    var fixType: UInt32
    var satsInView: UInt32
    var sensorId: UInt32
    var nextUpdate: UInt32
    var seqNumber: UInt32
    var precisionBits: UInt32
    
    enum LocationSource: Int {
        case unset = 0
        case manual = 1
        case `internal` = 2
        case external = 3
    }
    
    enum AltitudeSource: Int {
        case unset = 0
        case manual = 1
        case `internal` = 2
        case external = 3
        case barometric = 4
    }
    
    var latitude: Double {
        Double(latitudeI) / 1e7
    }
    
    var longitude: Double {
        Double(longitudeI) / 1e7
    }
}

/// Device metrics
public struct DeviceMetrics {
    var batteryLevel: UInt32
    var voltage: Float
    var channelUtilization: Float
    var airUtilTx: Float
    var uptimeSeconds: UInt32
}

/// Data message payload
public struct MeshtasticData {
    var portnum: PortNum
    var payload: Foundation.Data
    var wantResponse: Bool
    var dest: UInt32
    var source: UInt32
    var requestId: UInt32
    var replyId: UInt32
    var emoji: UInt32
    
    enum PortNum: Int {
        case unknownApp = 0
        case textMessageApp = 1
        case remoteHardwareApp = 2
        case positionApp = 3
        case nodeinfoApp = 4
        case routingApp = 5
        case adminApp = 6
        case textMessageCompressedApp = 7
        case waypointApp = 8
        case audioApp = 9
        case detectionSensorApp = 10
        case replyApp = 32
        case ipTunnelApp = 33
        case paxcounterApp = 34
        case serialApp = 64
        case storeForwardApp = 65
        case rangeTestApp = 66
        case telemetryApp = 67
        case zpsApp = 68
        case simulatorApp = 69
        case tracerouteApp = 70
        case neighborinfoApp = 71
        case atakPlugin = 72
        case mapReportApp = 73
        case privateApp = 256
        case atakForwarder = 257
        case max = 511
    }
}

/// Route discovery message
public struct RouteDiscovery {
    var route: [UInt32]
    var snrTowards: [Int32]
    var snrBack: [Int32]
}

/// Routing message
public struct Routing {
    var variant: RoutingVariant
    
    enum RoutingVariant {
        case routeRequest(RouteDiscovery)
        case routeReply(RouteDiscovery)
        case errorReason(ErrorReason)
    }
    
    enum ErrorReason: Int {
        case none = 0
        case noRoute = 1
        case gotNak = 2
        case timeout = 3
        case noInterface = 4
        case maxRetransmit = 5
        case noChannel = 6
        case tooLarge = 7
        case noResponse = 8
        case dutyCycleLimit = 9
        case badRequest = 10
        case notAuthorized = 11
    }
}
