//
//  MeshtasticProtobufParser.swift
//  OmniTAKMobile
//
//  Parser for Meshtastic Protobuf messages using varint encoding
//

import Foundation

// MARK: - Protobuf Parser

public class MeshtasticProtobufParser {
    
    // MARK: - Parsing Methods
    
    /// Parse MeshPacket from binary data
    public static func parseMeshPacket(from data: Foundation.Data) throws -> MeshPacket? {
        var decoder = ProtobufDecoder(data: data)
        return try decoder.decodeMeshPacket()
    }
    
    /// Parse NodeInfo from binary data
    public static func parseNodeInfo(from data: Foundation.Data) throws -> NodeInfo? {
        var decoder = ProtobufDecoder(data: data)
        return try decoder.decodeNodeInfo()
    }
    
    /// Parse User from binary data
    public static func parseUser(from data: Foundation.Data) throws -> User? {
        var decoder = ProtobufDecoder(data: data)
        return try decoder.decodeUser()
    }
    
    /// Parse Position from binary data
    public static func parsePosition(from data: Foundation.Data) throws -> Position? {
        var decoder = ProtobufDecoder(data: data)
        return try decoder.decodePosition()
    }
    
    /// Parse Data message from binary data
    public static func parseData(from data: Foundation.Data) throws -> MeshtasticData? {
        var decoder = ProtobufDecoder(data: data)
        return try decoder.decodeData()
    }
}

// MARK: - Protobuf Decoder

private struct ProtobufDecoder {
    private var data: Foundation.Data
    private var position: Int = 0
    
    init(data: Foundation.Data) {
        self.data = data
    }
    
    // MARK: - Varint Decoding
    
    mutating func decodeVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        
        while position < data.count {
            let byte = data[position]
            position += 1
            
            result |= UInt64(byte & 0x7F) << shift
            
            if (byte & 0x80) == 0 {
                return result
            }
            
            shift += 7
            if shift >= 64 {
                throw ProtobufError.invalidVarint
            }
        }
        
        throw ProtobufError.truncatedMessage
    }
    
    mutating func decodeSignedVarint() throws -> Int64 {
        let value = try decodeVarint()
        // ZigZag decoding
        return Int64(value >> 1) ^ -Int64(value & 1)
    }
    
    mutating func decodeFixed32() throws -> UInt32 {
        guard position + 4 <= data.count else {
            throw ProtobufError.truncatedMessage
        }
        
        let value = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: position, as: UInt32.self)
        }
        position += 4
        return value.littleEndian
    }
    
    mutating func decodeFixed64() throws -> UInt64 {
        guard position + 8 <= data.count else {
            throw ProtobufError.truncatedMessage
        }
        
        let value = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: position, as: UInt64.self)
        }
        position += 8
        return value.littleEndian
    }
    
    mutating func decodeFloat() throws -> Float {
        let bits = try decodeFixed32()
        return Float(bitPattern: bits)
    }
    
    mutating func decodeDouble() throws -> Double {
        let bits = try decodeFixed64()
        return Double(bitPattern: bits)
    }
    
    mutating func decodeBytes() throws -> Foundation.Data {
        let length = try Int(decodeVarint())
        guard position + length <= data.count else {
            throw ProtobufError.truncatedMessage
        }
        
        let bytes = data.subdata(in: position..<(position + length))
        position += length
        return bytes
    }
    
    mutating func decodeString() throws -> String {
        let bytes = try decodeBytes()
        guard let string = String(data: bytes, encoding: .utf8) else {
            throw ProtobufError.invalidString
        }
        return string
    }
    
    // MARK: - Message Decoding
    
    mutating func decodeMeshPacket() throws -> MeshPacket? {
        var from: UInt32 = 0
        var to: UInt32 = 0
        var channel: UInt32 = 0
        var id: UInt32 = 0
        var rxTime: UInt32 = 0
        var rxSnr: Float = 0
        var hopLimit: UInt32 = 0
        var wantAck: Bool = false
        var priority: MeshPacket.Priority = .default
        var rxRssi: Int32 = 0
        var delayed: UInt32 = 0
        var wantResponse: Bool = false
        var payloadVariant: MeshPacket.PayloadVariant = .decoded(Foundation.Data())
        
        while position < data.count {
            let tag = try decodeVarint()
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x7)
            
            switch fieldNumber {
            case 1: from = UInt32(try decodeVarint())
            case 2: to = UInt32(try decodeVarint())
            case 3: channel = UInt32(try decodeVarint())
            case 6: id = try decodeFixed32()
            case 11: rxTime = try decodeFixed32()
            case 7: rxSnr = try decodeFloat()
            case 8: hopLimit = UInt32(try decodeVarint())
            case 9: wantAck = try decodeVarint() != 0
            case 10: priority = MeshPacket.Priority(rawValue: Int(try decodeVarint())) ?? .default
            case 13: rxRssi = Int32(try decodeSignedVarint())
            case 14: delayed = UInt32(try decodeVarint())
            case 15: wantResponse = try decodeVarint() != 0
            case 16: payloadVariant = .decoded(try decodeBytes())
            case 17: payloadVariant = .encrypted(try decodeBytes())
            default:
                try skipField(wireType: wireType)
            }
        }
        
        return MeshPacket(
            from: from, to: to, channel: channel, id: id,
            rxTime: rxTime, rxSnr: rxSnr, hopLimit: hopLimit,
            wantAck: wantAck, priority: priority, rxRssi: rxRssi,
            delayed: delayed, wantResponse: wantResponse,
            payloadVariant: payloadVariant
        )
    }
    
    mutating func decodeNodeInfo() throws -> NodeInfo? {
        var num: UInt32 = 0
        var user: User?
        var nodePosition: Position?
        var snr: Float = 0
        var lastHeard: UInt32 = 0
        var deviceMetrics: DeviceMetrics?
        var channel: UInt32 = 0
        var viaMqtt: Bool = false
        var hopsAway: UInt32 = 0
        
        while position < data.count {
            let tag = try decodeVarint()
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x7)
            
            switch fieldNumber {
            case 1: num = UInt32(try decodeVarint())
            case 2: user = try decodeUser()
            case 3: nodePosition = try decodePosition()
            case 4: snr = try decodeFloat()
            case 5: lastHeard = try decodeFixed32()
            case 6: deviceMetrics = try decodeDeviceMetrics()
            case 7: channel = UInt32(try decodeVarint())
            case 8: viaMqtt = try decodeVarint() != 0
            case 9: hopsAway = UInt32(try decodeVarint())
            default:
                try skipField(wireType: wireType)
            }
        }
        
        return NodeInfo(
            num: num, user: user, position: nodePosition,
            snr: snr, lastHeard: lastHeard, deviceMetrics: deviceMetrics,
            channel: channel, viaMqtt: viaMqtt, hopsAway: hopsAway
        )
    }
    
    mutating func decodeUser() throws -> User? {
        var id: String = ""
        var longName: String = ""
        var shortName: String = ""
        var macaddr: Foundation.Data = Foundation.Data()
        var hwModel: User.HardwareModel = .unset
        var isLicensed: Bool = false
        var role: User.Role = .client
        
        let userData = try decodeBytes()
        var userDecoder = ProtobufDecoder(data: userData)
        
        while userDecoder.position < userData.count {
            let tag = try userDecoder.decodeVarint()
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x7)
            
            switch fieldNumber {
            case 1: id = try userDecoder.decodeString()
            case 2: longName = try userDecoder.decodeString()
            case 3: shortName = try userDecoder.decodeString()
            case 4: macaddr = try userDecoder.decodeBytes()
            case 5: hwModel = User.HardwareModel(rawValue: Int(try userDecoder.decodeVarint())) ?? .unset
            case 6: isLicensed = try userDecoder.decodeVarint() != 0
            case 7: role = User.Role(rawValue: Int(try userDecoder.decodeVarint())) ?? .client
            default:
                try userDecoder.skipField(wireType: wireType)
            }
        }
        
        return User(
            id: id, longName: longName, shortName: shortName,
            macaddr: macaddr, hwModel: hwModel, isLicensed: isLicensed, role: role
        )
    }
    
    mutating func decodePosition() throws -> Position? {
        var latitudeI: Int32 = 0
        var longitudeI: Int32 = 0
        var altitude: Int32 = 0
        var time: UInt32 = 0
        var locationSource: Position.LocationSource = .unset
        var altitudeSource: Position.AltitudeSource = .unset
        var timestamp: UInt32 = 0
        var timestampMillisAdjust: Int32 = 0
        var altitudeHae: Int32 = 0
        var altitudeGeoidalSeparation: Int32 = 0
        var pdop: UInt32 = 0
        var hdop: UInt32 = 0
        var vdop: UInt32 = 0
        var gpsAccuracy: UInt32 = 0
        var groundSpeed: UInt32 = 0
        var groundTrack: UInt32 = 0
        var fixQuality: UInt32 = 0
        var fixType: UInt32 = 0
        var satsInView: UInt32 = 0
        var sensorId: UInt32 = 0
        var nextUpdate: UInt32 = 0
        var seqNumber: UInt32 = 0
        var precisionBits: UInt32 = 0
        
        let posData = try decodeBytes()
        var posDecoder = ProtobufDecoder(data: posData)
        
        while posDecoder.position < posData.count {
            let tag = try posDecoder.decodeVarint()
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x7)
            
            switch fieldNumber {
            case 1: latitudeI = Int32(try posDecoder.decodeSignedVarint())
            case 2: longitudeI = Int32(try posDecoder.decodeSignedVarint())
            case 3: altitude = Int32(try posDecoder.decodeSignedVarint())
            case 4: time = try posDecoder.decodeFixed32()
            case 5: locationSource = Position.LocationSource(rawValue: Int(try posDecoder.decodeVarint())) ?? .unset
            case 6: altitudeSource = Position.AltitudeSource(rawValue: Int(try posDecoder.decodeVarint())) ?? .unset
            case 7: timestamp = try posDecoder.decodeFixed32()
            case 8: timestampMillisAdjust = Int32(try posDecoder.decodeSignedVarint())
            case 9: altitudeHae = Int32(try posDecoder.decodeSignedVarint())
            case 10: altitudeGeoidalSeparation = Int32(try posDecoder.decodeSignedVarint())
            case 11: pdop = UInt32(try posDecoder.decodeVarint())
            case 12: hdop = UInt32(try posDecoder.decodeVarint())
            case 13: vdop = UInt32(try posDecoder.decodeVarint())
            case 14: gpsAccuracy = UInt32(try posDecoder.decodeVarint())
            case 15: groundSpeed = UInt32(try posDecoder.decodeVarint())
            case 16: groundTrack = UInt32(try posDecoder.decodeVarint())
            case 17: fixQuality = UInt32(try posDecoder.decodeVarint())
            case 18: fixType = UInt32(try posDecoder.decodeVarint())
            case 19: satsInView = UInt32(try posDecoder.decodeVarint())
            case 20: sensorId = UInt32(try posDecoder.decodeVarint())
            case 21: nextUpdate = UInt32(try posDecoder.decodeVarint())
            case 22: seqNumber = UInt32(try posDecoder.decodeVarint())
            case 23: precisionBits = UInt32(try posDecoder.decodeVarint())
            default:
                try posDecoder.skipField(wireType: wireType)
            }
        }
        
        return Position(
            latitudeI: latitudeI, longitudeI: longitudeI, altitude: altitude,
            time: time, locationSource: locationSource, altitudeSource: altitudeSource,
            timestamp: timestamp, timestampMillisAdjust: timestampMillisAdjust,
            altitudeHae: altitudeHae, altitudeGeoidalSeparation: altitudeGeoidalSeparation,
            pdop: pdop, hdop: hdop, vdop: vdop, gpsAccuracy: gpsAccuracy,
            groundSpeed: groundSpeed, groundTrack: groundTrack,
            fixQuality: fixQuality, fixType: fixType, satsInView: satsInView,
            sensorId: sensorId, nextUpdate: nextUpdate, seqNumber: seqNumber,
            precisionBits: precisionBits
        )
    }
    
    mutating func decodeDeviceMetrics() throws -> DeviceMetrics? {
        var batteryLevel: UInt32 = 0
        var voltage: Float = 0
        var channelUtilization: Float = 0
        var airUtilTx: Float = 0
        var uptimeSeconds: UInt32 = 0
        
        let metricsData = try decodeBytes()
        var metricsDecoder = ProtobufDecoder(data: metricsData)
        
        while metricsDecoder.position < metricsData.count {
            let tag = try metricsDecoder.decodeVarint()
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x7)
            
            switch fieldNumber {
            case 1: batteryLevel = UInt32(try metricsDecoder.decodeVarint())
            case 2: voltage = try metricsDecoder.decodeFloat()
            case 3: channelUtilization = try metricsDecoder.decodeFloat()
            case 4: airUtilTx = try metricsDecoder.decodeFloat()
            case 5: uptimeSeconds = UInt32(try metricsDecoder.decodeVarint())
            default:
                try metricsDecoder.skipField(wireType: wireType)
            }
        }
        
        return DeviceMetrics(
            batteryLevel: batteryLevel, voltage: voltage,
            channelUtilization: channelUtilization, airUtilTx: airUtilTx,
            uptimeSeconds: uptimeSeconds
        )
    }
    
    mutating func decodeData() throws -> MeshtasticData? {
        var portnum: MeshtasticData.PortNum = .unknownApp
        var payload: Foundation.Data = Foundation.Data()
        var wantResponse: Bool = false
        var dest: UInt32 = 0
        var source: UInt32 = 0
        var requestId: UInt32 = 0
        var replyId: UInt32 = 0
        var emoji: UInt32 = 0
        
        while position < data.count {
            let tag = try decodeVarint()
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x7)
            
            switch fieldNumber {
            case 1: portnum = MeshtasticData.PortNum(rawValue: Int(try decodeVarint())) ?? .unknownApp
            case 2: payload = try decodeBytes()
            case 3: wantResponse = try decodeVarint() != 0
            case 4: dest = UInt32(try decodeVarint())
            case 5: source = UInt32(try decodeVarint())
            case 6: requestId = UInt32(try decodeVarint())
            case 7: replyId = UInt32(try decodeVarint())
            case 8: emoji = UInt32(try decodeVarint())
            default:
                try skipField(wireType: wireType)
            }
        }
        
        return MeshtasticData(
            portnum: portnum, payload: payload, wantResponse: wantResponse,
            dest: dest, source: source, requestId: requestId,
            replyId: replyId, emoji: emoji
        )
    }
    
    mutating func skipField(wireType: Int) throws {
        switch wireType {
        case 0: // Varint
            _ = try decodeVarint()
        case 1: // 64-bit
            position += 8
        case 2: // Length-delimited
            let length = try Int(decodeVarint())
            position += length
        case 5: // 32-bit
            position += 4
        default:
            throw ProtobufError.invalidWireType
        }
    }
}

// MARK: - Protobuf Errors

enum ProtobufError: Error {
    case invalidVarint
    case truncatedMessage
    case invalidString
    case invalidWireType
    case unknownField
}
