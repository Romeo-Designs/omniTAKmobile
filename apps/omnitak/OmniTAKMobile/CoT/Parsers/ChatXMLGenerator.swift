//
//  ChatXMLGenerator.swift
//  OmniTAKTest
//
//  Generate TAK GeoChat XML (b-t-f format) for group and direct messages
//

import Foundation
import CoreLocation

class ChatXMLGenerator {

    // Generate GeoChat XML for a chat message
    static func generateGeoChatXML(
        message: ChatMessage,
        senderUid: String,
        senderCallsign: String,
        location: CLLocation?,
        isGroupChat: Bool = false,
        groupName: String? = nil
    ) -> String {
        let messageId = message.id
        let now = ISO8601DateFormatter().string(from: Date())
        let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)) // 1 hour

        // Use current location or default
        let lat = location?.coordinate.latitude ?? 0.0
        let lon = location?.coordinate.longitude ?? 0.0
        let hae = location?.altitude ?? 0.0
        let ce = location?.horizontalAccuracy ?? 999999.0
        let le = location?.verticalAccuracy ?? 999999.0

        // Determine chatroom and recipients
        let chatroom: String
        let destCallsign: String

        if isGroupChat {
            // Group chat - send to "All Chat Users"
            chatroom = groupName ?? ChatRoom.allUsersTitle
            destCallsign = chatroom
        } else if let recipientCallsign = message.recipientCallsign {
            // Direct message
            chatroom = recipientCallsign
            destCallsign = recipientCallsign
        } else {
            // Default to All Chat Users
            chatroom = ChatRoom.allUsersTitle
            destCallsign = chatroom
        }

        // Build fileshare element if image attachment present
        let fileshareElement = generateFileshareElement(for: message)

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="GeoChat.\(senderUid).\(messageId)" type="b-t-f" time="\(now)" start="\(now)" stale="\(stale)" how="h-g-i-g-o">
            <point lat="\(lat)" lon="\(lon)" hae="\(hae)" ce="\(ce)" le="\(le)"/>
            <detail>
                <__chat id="\(messageId)" chatroom="\(chatroom)" senderCallsign="\(senderCallsign)" parent="RootContactGroup">
                    <chatgrp uid0="\(senderUid)" uid1="\(chatroom)" id="\(chatroom)"/>
                </__chat>
                <link uid="\(senderUid)" production_time="\(now)" type="a-f-G-E-S" parent_callsign="\(senderCallsign)" relation="p-p"/>
                <remarks source="BAO.F.ATAK.\(senderUid)" to="\(chatroom)" time="\(now)">\(escapeXML(message.messageText))</remarks>\(fileshareElement)
                <__serverdestination>
                    <dest callsign="\(destCallsign)"/>
                </__serverdestination>
                <marti>
                    <dest callsign="\(chatroom)"/>
                </marti>
            </detail>
        </event>
        """

        return xml
    }

    // Generate fileshare element for image attachments
    static func generateFileshareElement(for message: ChatMessage) -> String {
        guard message.hasImage,
              let attachment = message.imageAttachment else {
            return ""
        }

        // Build senderUrl - prefer base64 for inline, otherwise use remote URL
        let senderUrl: String
        if let base64Data = attachment.base64Data {
            senderUrl = "base64:\(base64Data)"
        } else if let remoteURL = attachment.remoteURL {
            senderUrl = remoteURL
        } else {
            // Fallback to local path reference
            senderUrl = "local:\(attachment.localPath ?? attachment.filename)"
        }

        let fileshareXML = """

                <fileshare filename="\(escapeXML(attachment.filename))" senderUrl="\(senderUrl)" size="\(attachment.fileSize)" sha256="" senderUid="\(message.senderId)" senderCallsign="\(escapeXML(message.senderCallsign))" name="\(escapeXML(attachment.filename))" mimeType="\(attachment.mimeType)"/>
        """

        return fileshareXML
    }

    // Generate GeoChat XML specifically for image messages
    static func generateImageGeoChatXML(
        message: ChatMessage,
        senderUid: String,
        senderCallsign: String,
        location: CLLocation?,
        isGroupChat: Bool = false,
        groupName: String? = nil
    ) -> String {
        // Use the standard generator which now supports attachments
        return generateGeoChatXML(
            message: message,
            senderUid: senderUid,
            senderCallsign: senderCallsign,
            location: location,
            isGroupChat: isGroupChat,
            groupName: groupName
        )
    }

    // Escape special XML characters
    static func escapeXML(_ string: String) -> String {
        var escaped = string
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }

    // Generate presence CoT with chat endpoint information
    static func generatePresenceWithChatEndpoint(
        uid: String,
        callsign: String,
        location: CLLocation,
        endpoint: String = "*:-1:stcp"
    ) -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(300)) // 5 minutes

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="a-f-G-E-S" how="m-g" time="\(now)" start="\(now)" stale="\(stale)">
            <point lat="\(location.coordinate.latitude)" lon="\(location.coordinate.longitude)" hae="\(location.altitude)" ce="\(location.horizontalAccuracy)" le="\(location.verticalAccuracy)"/>
            <detail>
                <contact callsign="\(callsign)" endpoint="\(endpoint)"/>
                <__group name="Cyan" role="Team Member"/>
                <status battery="100"/>
                <takv device="iPhone" platform="OmniTAK" os="iOS" version="1.0.0"/>
                <track speed="\(location.speed)" course="\(location.course)"/>
            </detail>
        </event>
        """

        return xml
    }
    
    // MARK: - Message Management XML
    
    /// Generate XML for message update (edit)
    static func generateMessageUpdateXML(message: ChatMessage) -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="MessageUpdate.\(message.id)" type="b-t-f-u" time="\(now)" start="\(now)" stale="\(stale)" how="h-g-i-g-o">
            <point lat="0.0" lon="0.0" hae="0.0" ce="999999.0" le="999999.0"/>
            <detail>
                <messageUpdate originalId="\(message.id)" action="edit">
                    <remarks>\(escapeXML(message.messageText))</remarks>
                </messageUpdate>
            </detail>
        </event>
        """
        
        return xml
    }
    
    /// Generate XML for message deletion
    static func generateMessageDeleteXML(messageId: String) -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="MessageDelete.\(messageId)" type="b-t-f-d" time="\(now)" start="\(now)" stale="\(stale)" how="h-g-i-g-o">
            <point lat="0.0" lon="0.0" hae="0.0" ce="999999.0" le="999999.0"/>
            <detail>
                <messageDelete originalId="\(messageId)" action="delete"/>
            </detail>
        </event>
        """
        
        return xml
    }
    
    // MARK: - Typing Indicators
    
    /// Generate XML for typing indicator
    static func generateTypingIndicatorXML(senderUid: String, senderCallsign: String, conversationId: String) -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(5)) // 5 seconds
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="Typing.\(senderUid).\(UUID().uuidString)" type="b-t-f-t" time="\(now)" start="\(now)" stale="\(stale)" how="h-g-i-g-o">
            <point lat="0.0" lon="0.0" hae="0.0" ce="999999.0" le="999999.0"/>
            <detail>
                <typingIndicator senderUid="\(senderUid)" senderCallsign="\(escapeXML(senderCallsign))" conversationId="\(conversationId)" isTyping="true"/>
            </detail>
        </event>
        """
        
        return xml
    }
    
    // MARK: - Read Receipts
    
    /// Generate XML for read receipt
    static func generateReadReceiptXML(messageId: String, readerUid: String, readerCallsign: String) -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="ReadReceipt.\(messageId).\(readerUid)" type="b-t-f-r" time="\(now)" start="\(now)" stale="\(stale)" how="h-g-i-g-o">
            <point lat="0.0" lon="0.0" hae="0.0" ce="999999.0" le="999999.0"/>
            <detail>
                <readReceipt messageId="\(messageId)" readerUid="\(readerUid)" readerCallsign="\(escapeXML(readerCallsign))" readTime="\(now)"/>
            </detail>
        </event>
        """
        
        return xml
    }
}
