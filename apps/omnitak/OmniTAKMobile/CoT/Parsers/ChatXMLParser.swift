//
//  ChatXMLParser.swift
//  OmniTAKTest
//
//  Parse incoming GeoChat CoT messages, extract sender, recipient, message text
//

import Foundation
import UIKit

class ChatXMLParser {

    // Parse a GeoChat message from CoT XML
    static func parseGeoChatMessage(xml: String) -> ChatMessage? {
        // Check if this is a GeoChat message (type="b-t-f")
        guard xml.contains("type=\"b-t-f\"") else {
            return nil
        }
        
        // DEBUG: Log the incoming XML to diagnose parsing issues
        print("🔍 ChatXMLParser: Received GeoChat XML (\(xml.count) chars)")
        print("🔍 XML Preview: \(xml.prefix(500))...")

        // Extract message UID
        guard extractAttribute("uid", from: xml) != nil else {
            print("Failed to extract UID from GeoChat message")
            return nil
        }

        // Extract chat details from __chat element
        guard let chatId = extractChatAttribute("id", from: xml) else {
            print("Failed to extract chat ID")
            return nil
        }

        // Try to resolve sender callsign (prefer link parent_callsign, then __chat attribute, then known participant)
        let linkCallsign = extractLinkAttribute("parent_callsign", from: xml)
        let chatSenderCallsign = extractChatAttribute("senderCallsign", from: xml)

        // Extract chatroom/callsign target
        let chatroom = extractChatAttribute("chatroom", from: xml)

        // Extract sender UID from chatgrp or link element (fallback to remarks source)
        var senderUid: String?
        if let uid0 = extractChatgrpAttribute("uid0", from: xml) {
            senderUid = uid0
        } else if let linkUid = extractLinkAttribute("uid", from: xml) {
            senderUid = linkUid
        } else if let remarksSource = extractRemarksAttribute("source", from: xml) {
            senderUid = sanitizedUid(from: remarksSource)
        }

        // Extract sender callsign from participants if we later find a match by UID
        let participantFromUid = senderUid.flatMap { uid in
            ChatManager.shared.participants.first(where: { $0.id == uid })
        }

        guard let senderId = senderUid else {
            print("Failed to extract sender UID")
            return nil
        }

        // Prefer known participant callsign if we have presence for this UID
        let participantCallsign = participantFromUid?.callsign

        // Some TAK variants put the sender UID in remarks source as BAO.F.ATAK.<uid>
        let remarksSourceCallsign = participantFromUid?.callsign

        // Try to resolve sender callsign from link, __chat, or known participants
        var senderCallsign = linkCallsign
            ?? chatSenderCallsign
            ?? remarksSourceCallsign
            ?? participantCallsign

        // If the callsign we parsed matches our own but the UID does not, prefer the participant or UID to avoid self-labeling
        if let myCallsign = ChatManager.shared.currentUserCallsign as String?,
           let call = senderCallsign,
           call == myCallsign,
           senderId != ChatManager.shared.currentUserId {
            if let participantCallsign {
                senderCallsign = participantCallsign
            } else if let chatroom {
                senderCallsign = chatroom
            } else {
                senderCallsign = senderId
            }
        }

        guard var resolvedSenderCallsign = senderCallsign else {
            print("Failed to resolve sender callsign")
            return nil
        }

        // Extract recipient info early (before isFromSelf check)
        var recipientCallsign: String?
        var recipientId: String?

        // Determine if this message originated from the current user (server echo)
        let isFromSelf = senderId == ChatManager.shared.currentUserId
        if isFromSelf {
            // For echoes of our own messages, label sender as the recipient/chatroom to avoid self-thread names
            if let fromRecipientId = recipientId,
               let recipientParticipant = ChatManager.shared.participants.first(where: { $0.id == fromRecipientId }) {
                resolvedSenderCallsign = recipientParticipant.callsign
            } else if let recipientCallsign {
                resolvedSenderCallsign = recipientCallsign
            } else if let chatroom {
                resolvedSenderCallsign = chatroom
            }
        }

        // Extract message text from remarks element
        guard let messageText = extractRemarksContent(from: xml) else {
            print("❌ Failed to extract message text from remarks element")
            print("🔍 Searching for <remarks> tag in XML...")
            if xml.contains("<remarks") {
                print("✅ Found <remarks> tag")
                if xml.contains("</remarks>") {
                    print("✅ Found </remarks> closing tag")
                } else {
                    print("❌ Missing </remarks> closing tag!")
                }
            } else {
                print("❌ No <remarks> tag found in XML!")
            }
            return nil
        }

        // Extract timestamp
        let timestamp = extractTimestamp(from: xml) ?? Date()

        // Determine if this is a group message or direct message
        let isGroupChat = chatroom == ChatRoom.allUsersTitle || chatroom == "All Chat Users"

        // Extract recipient info (for direct messages) - already declared above
        if !isGroupChat, let chatroom = chatroom {
            recipientCallsign = chatroom
            if let uid1 = extractChatgrpAttribute("uid1", from: xml), uid1 != chatroom {
                recipientId = uid1
            }

            // If we know the participant for uid1, prefer their callsign so the thread title matches the contact
            if let uid1 = recipientId,
               let knownRecipient = ChatManager.shared.participants.first(where: { $0.id == uid1 }) {
                recipientCallsign = knownRecipient.callsign
            } else if let knownRecipient = ChatManager.shared.participants.first(where: { $0.callsign == chatroom }) {
                // Some TAK clients use callsign for uid1; map it back to known participant
                recipientId = knownRecipient.id
                recipientCallsign = knownRecipient.callsign
            } else {
                // Fall back to using chatroom as an ID so we treat this as a direct thread (not a group)
                recipientId = chatroom
            }
        }

        // For direct messages that are not from self, prefer a non-default sender callsign:
        // - sender presence callsign
        // - recipient callsign/chatroom (common for TAK direct chats)
        // This prevents everything from collapsing under the default local callsign.
        if !isGroupChat && !isFromSelf {
            if let participantFromUid {
                resolvedSenderCallsign = participantFromUid.callsign
            } else if let recipientCallsign {
                resolvedSenderCallsign = recipientCallsign
            } else if let chatroom {
                resolvedSenderCallsign = chatroom
            }
        }

        // Create conversation ID
        let conversationId: String
        if isGroupChat {
            conversationId = ChatRoom.allUsersId
        } else {
            // For direct messages, use a consistent ID based on both participants
            conversationId = createDirectConversationId(uid1: senderId, uid2: recipientId ?? chatroom ?? "")
        }

        // Parse image attachment if present
        let (attachmentType, imageAttachment) = parseFileshareElement(from: xml, messageId: chatId)

        let message = ChatMessage(
            id: chatId,
            conversationId: conversationId,
            senderId: senderId,
            senderCallsign: resolvedSenderCallsign,
            recipientId: recipientId,
            recipientCallsign: recipientCallsign,
            messageText: messageText,
            timestamp: timestamp,
            status: .delivered,
            type: .geochat,
            isFromSelf: isFromSelf,
            attachmentType: attachmentType,
            imageAttachment: imageAttachment
        )

        if imageAttachment != nil {
            print("Parsed GeoChat message with image from \(resolvedSenderCallsign): \(messageText)")
        } else {
            print("Parsed GeoChat message from \(resolvedSenderCallsign): \(messageText)")
        }
        return message
    }

    // Parse fileshare element for image attachments
    private static func parseFileshareElement(from xml: String, messageId: String) -> (AttachmentType, ImageAttachment?) {
        // Look for fileshare element
        guard let fileshareRange = xml.range(of: "<fileshare[^>]+/>", options: .regularExpression) else {
            return (.none, nil)
        }

        let fileshareTag = String(xml[fileshareRange])

        // Extract filename
        guard let filename = extractAttribute("filename", from: fileshareTag) else {
            return (.none, nil)
        }

        // Check if it's an image file
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp"]
        let fileExtension = (filename as NSString).pathExtension.lowercased()
        guard imageExtensions.contains(fileExtension) else {
            return (.file, nil) // It's a file but not an image
        }

        // Extract other attributes
        let senderUrl = extractAttribute("senderUrl", from: fileshareTag) ?? ""
        let sizeString = extractAttribute("size", from: fileshareTag) ?? "0"
        let fileSize = Int(sizeString) ?? 0
        let mimeType = extractAttribute("mimeType", from: fileshareTag) ?? "image/jpeg"

        // Parse senderUrl for base64 or remote URL
        var base64Data: String?
        var remoteURL: String?

        if senderUrl.hasPrefix("base64:") {
            base64Data = String(senderUrl.dropFirst(7)) // Remove "base64:" prefix
        } else if senderUrl.hasPrefix("http://") || senderUrl.hasPrefix("https://") {
            remoteURL = senderUrl
        } else if senderUrl.hasPrefix("local:") {
            // Local reference - we don't have access to sender's local files
            // The image will be unavailable unless we have base64 data
        }

        // If we have base64 data, save it locally
        var localPath: String?
        var thumbnailPath: String?

        if let base64 = base64Data,
           let imageData = Data(base64Encoded: base64),
           let image = UIImage(data: imageData) {
            if let paths = PhotoAttachmentService.shared.saveImage(image, for: messageId) {
                localPath = paths.localPath
                thumbnailPath = paths.thumbnailPath
            }
        }

        let attachment = ImageAttachment(
            id: messageId,
            filename: filename,
            mimeType: mimeType,
            fileSize: fileSize,
            localPath: localPath,
            thumbnailPath: thumbnailPath,
            base64Data: base64Data,
            remoteURL: remoteURL
        )

        return (.image, attachment)
    }

    // MARK: - Helper Functions

    private static func extractAttribute(_ name: String, from xml: String) -> String? {
        guard let range = xml.range(of: "\(name)=\"([^\"]+)\"", options: .regularExpression) else {
            return nil
        }
        let parts = xml[range].split(separator: "\"")
        return parts.count > 1 ? String(parts[1]) : nil
    }

    private static func extractChatAttribute(_ name: String, from xml: String) -> String? {
        // Extract attributes from __chat element
        guard let chatRange = xml.range(of: "<__chat[^>]+>", options: .regularExpression) else {
            return nil
        }
        let chatTag = String(xml[chatRange])
        return extractAttribute(name, from: chatTag)
    }

    private static func extractChatgrpAttribute(_ name: String, from xml: String) -> String? {
        // Extract attributes from chatgrp element (self-closing or paired)
        if let chatgrpRange = xml.range(of: "<chatgrp[^>]+?/?>", options: .regularExpression) {
            let chatgrpTag = String(xml[chatgrpRange])
            if let value = extractAttribute(name, from: chatgrpTag) {
                return value
            }
        }

        // Fallback to paired tag form
        // (?s) enables dot to match newlines so we can capture multi-line tags without needing dotMatchesLineSeparators
        if let chatgrpRange = xml.range(of: "(?s)<chatgrp[^>]*>.*?</chatgrp>", options: .regularExpression) {
            let chatgrpTag = String(xml[chatgrpRange])
            return extractAttribute(name, from: chatgrpTag)
        }

        return nil
    }

    private static func extractLinkAttribute(_ name: String, from xml: String) -> String? {
        // Extract attributes from link element
        guard let linkRange = xml.range(of: "<link[^>]+/>", options: .regularExpression) else {
            return nil
        }
        let linkTag = String(xml[linkRange])
        return extractAttribute(name, from: linkTag)
    }

    private static func extractRemarksAttribute(_ name: String, from xml: String) -> String? {
        guard let remarksRange = xml.range(of: "<remarks[^>]*>", options: .regularExpression) else {
            return nil
        }
        let remarksTag = String(xml[remarksRange])
        return extractAttribute(name, from: remarksTag)
    }

    private static func extractRemarksContent(from xml: String) -> String? {
        // Extract content from <remarks>...</remarks>
        guard let startRange = xml.range(of: "<remarks[^>]*>", options: .regularExpression),
              let endRange = xml.range(of: "</remarks>") else {
            print("🔍 extractRemarksContent: Failed to find <remarks> tags with regex")
            return nil
        }

        let startIndex = xml.index(startRange.upperBound, offsetBy: 0)
        let endIndex = endRange.lowerBound

        guard startIndex < endIndex else {
            print("🔍 extractRemarksContent: startIndex >= endIndex (empty or invalid range)")
            return nil
        }

        let content = String(xml[startIndex..<endIndex])
        print("🔍 extractRemarksContent: Extracted raw content: '\(content)'")
        print("🔍 extractRemarksContent: Content length: \(content.count) chars")

        // Decode XML entities
        let decoded = content
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 extractRemarksContent: Decoded content: '\(decoded)'")
        
        return decoded.isEmpty ? nil : decoded
    }

    private static func extractTimestamp(from xml: String) -> Date? {
        guard let timeStr = extractAttribute("time", from: xml) else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        return formatter.date(from: timeStr)
    }

    private static func sanitizedUid(from source: String) -> String {
        let prefix = "BAO.F.ATAK."
        if source.hasPrefix(prefix) {
            return String(source.dropFirst(prefix.count))
        }
        return source
    }

    private static func createDirectConversationId(uid1: String, uid2: String) -> String {
        // Create a consistent conversation ID for direct messages
        // Sort UIDs to ensure the same ID regardless of sender/recipient order
        let sorted = [uid1, uid2].sorted()
        return "DM-\(sorted[0])-\(sorted[1])"
    }

    // Parse participant information from presence CoT
    static func parseParticipantFromPresence(xml: String) -> ChatParticipant? {
        // Extract UID
        guard let uid = extractAttribute("uid", from: xml) else {
            return nil
        }

        // Extract callsign from contact element
        guard let contactRange = xml.range(of: "<contact[^>]+/>", options: .regularExpression) else {
            return nil
        }
        let contactTag = String(xml[contactRange])
        guard let callsign = extractAttribute("callsign", from: contactTag) else {
            return nil
        }

        // Extract endpoint if available
        let endpoint = extractAttribute("endpoint", from: contactTag)

        // Extract timestamp
        let lastSeen = extractTimestamp(from: xml) ?? Date()

        return ChatParticipant(
            id: uid,
            callsign: callsign,
            endpoint: endpoint,
            lastSeen: lastSeen,
            isOnline: true
        )
    }
}
