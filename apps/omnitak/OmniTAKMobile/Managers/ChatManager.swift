//
//  ChatManager.swift
//  OmniTAKTest
//
//  ObservableObject for chat state, sendMessage(), receiveMessage(), conversation management
//

import Foundation
import Combine
import CoreLocation
import UIKit

class ChatManager: ObservableObject {
    static let shared = ChatManager()

    @Published var conversations: [Conversation] = []
    @Published var messages: [ChatMessage] = []
    @Published var participants: [ChatParticipant] = []
    @Published var currentUserId: String = "SELF-\(UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString)"
    @Published var currentUserCallsign: String = "OmniTAK-iOS"
    @Published var blockedContacts: Set<String> = []

    private let persistence = ChatPersistence.shared
    private var takService: TAKService?
    private var locationManager: LocationManager?
    
    // MARK: - Message Queue
    
    /// Queue for messages waiting to be sent when TAKService becomes available
    private struct PendingMessage {
        let message: ChatMessage
        let conversationId: String
        let xml: String
        let queuedAt: Date
        let isImageMessage: Bool
    }
    
    private var pendingMessages: [PendingMessage] = []
    private let queueLock = NSLock()
    private let maxQueueSize = 100 // Prevent memory issues

    private init() {
        loadData()
        loadBlockedContacts()
        setupDefaultConversations()
    }

    // MARK: - Setup

    func configure(takService: TAKService, locationManager: LocationManager) {
        print("🔧 ChatManager.configure() called - takService instance: \(ObjectIdentifier(takService)), isConnected: \(takService.isConnected)")
        self.takService = takService
        self.locationManager = locationManager
        print("🔧 ChatManager.configure() completed - stored takService is now: \(self.takService != nil ? "SET" : "NIL")")
        
        // Process any pending messages that were queued before TAKService was available
        processPendingMessages()
    }

    private func loadData() {
        conversations = persistence.loadConversations()
        messages = persistence.loadMessages()
        participants = persistence.loadParticipants()

        print("ChatManager loaded: \(conversations.count) conversations, \(messages.count) messages, \(participants.count) participants")
    }

    private func setupDefaultConversations() {
        // Create "All Chat Users" group conversation if it doesn't exist
        if !conversations.contains(where: { $0.id == ChatRoom.allUsersId }) {
            let allUsersConversation = ChatRoom.createAllUsersConversation()
            conversations.append(allUsersConversation)
            saveConversations()
        }
    }

    // MARK: - Send Message

    func sendMessage(text: String, to conversationId: String) {
        print("📤 ChatManager.sendMessage() called - takService: \(takService != nil ? "SET (instance: \(ObjectIdentifier(takService!)), connected: \(takService!.isConnected))" : "NIL")")
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Cannot send empty message")
            return
        }

        guard let conversation = conversations.first(where: { $0.id == conversationId }) else {
            print("Conversation not found: \(conversationId)")
            return
        }

        // Create message
        let message = ChatMessage(
            conversationId: conversationId,
            senderId: currentUserId,
            senderCallsign: currentUserCallsign,
            recipientId: conversation.isGroupChat ? nil : conversation.participants.first?.id,
            recipientCallsign: conversation.isGroupChat ? nil : conversation.participants.first?.callsign,
            messageText: text,
            timestamp: Date(),
            status: .sending,
            type: .geochat,
            isFromSelf: true
        )

        // Add to messages array
        messages.append(message)
        saveMessages()

        // Update conversation
        updateConversation(conversationId: conversationId, with: message)

        // Generate and send GeoChat XML
        let xml = ChatXMLGenerator.generateGeoChatXML(
            message: message,
            senderUid: currentUserId,
            senderCallsign: currentUserCallsign,
            location: locationManager?.location,
            isGroupChat: conversation.isGroupChat,
            groupName: conversation.isGroupChat ? conversation.title : nil
        )

        // Send via TAK service or queue if not available
        guard let takService = takService, takService.isConnected else {
            // TAKService not yet configured or not connected - queue the message
            queueMessage(message: message, conversationId: conversationId, xml: xml, isImageMessage: false)
            
            // Update message status to pending
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].status = .pending
                saveMessages()
            }
            
            let reason = takService == nil ? "TAKService not configured" : "TAKService not connected"
            print("📥 Message queued (\(reason)) - will send when available: \(text.prefix(50))...")
            return
        }
        
        // TAKService is available and connected - send immediately
        let success = takService.sendCoT(xml: xml)
        if success {
            // Update message status to sent
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].status = .sent
                saveMessages()
            }
            print("✅ Sent chat message to \(conversation.displayTitle): \(text)")
        } else {
            // Update message status to failed
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].status = .failed
                saveMessages()
            }
            print("❌ Failed to send chat message")
        }
    }

    // MARK: - Send Message with Image

    func sendMessageWithImage(text: String, imageAttachment: ImageAttachment, to conversationId: String) {
        guard let conversation = conversations.first(where: { $0.id == conversationId }) else {
            print("Conversation not found: \(conversationId)")
            return
        }

        // Create message with image attachment
        let message = ChatMessage(
            id: imageAttachment.id, // Use same ID for message and attachment
            conversationId: conversationId,
            senderId: currentUserId,
            senderCallsign: currentUserCallsign,
            recipientId: conversation.isGroupChat ? nil : conversation.participants.first?.id,
            recipientCallsign: conversation.isGroupChat ? nil : conversation.participants.first?.callsign,
            messageText: text,
            timestamp: Date(),
            status: .sending,
            type: .geochat,
            isFromSelf: true,
            attachmentType: .image,
            imageAttachment: imageAttachment
        )

        // Add to messages array
        messages.append(message)
        saveMessages()

        // Update conversation
        updateConversation(conversationId: conversationId, with: message)

        // Generate and send GeoChat XML with attachment
        let xml = ChatXMLGenerator.generateGeoChatXML(
            message: message,
            senderUid: currentUserId,
            senderCallsign: currentUserCallsign,
            location: locationManager?.location,
            isGroupChat: conversation.isGroupChat,
            groupName: conversation.isGroupChat ? conversation.title : nil
        )

        // Send via TAK service or queue if not available
        guard let takService = takService, takService.isConnected else {
            // TAKService not yet configured or not connected - queue the message
            queueMessage(message: message, conversationId: conversationId, xml: xml, isImageMessage: true)
            
            // Update message status to pending
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].status = .pending
                saveMessages()
            }
            
            let reason = takService == nil ? "TAKService not configured" : "TAKService not connected"
            let sizeString = PhotoAttachmentService.shared.formatStorageSize(Int64(imageAttachment.fileSize))
            print("📥 Image message queued (\(reason)) - will send when available (\(sizeString))")
            return
        }
        
        // TAKService is available and connected - send immediately
        let success = takService.sendCoT(xml: xml)
        if success {
            // Update message status to sent
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].status = .sent
                saveMessages()
            }
            let sizeString = PhotoAttachmentService.shared.formatStorageSize(Int64(imageAttachment.fileSize))
            print("✅ Sent image message to \(conversation.displayTitle) (\(sizeString))")
        } else {
            // Update message status to failed
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].status = .failed
                saveMessages()
            }
            print("❌ Failed to send image message")
        }
    }

    // MARK: - Receive Message

    func receiveMessage(_ message: ChatMessage) {
        // Check if message already exists
        guard !messages.contains(where: { $0.id == message.id }) else {
            print("Duplicate message ignored: \(message.id)")
            return
        }

        // Add message
        messages.append(message)
        saveMessages()

        // Update or create conversation
        if conversations.first(where: { $0.id == message.conversationId }) != nil {
            updateConversation(conversationId: message.conversationId, with: message)
        } else {
            createConversation(from: message)
        }

        print("Received chat message from \(message.senderCallsign): \(message.messageText)")
    }

    // MARK: - Conversation Management

    func getOrCreateDirectConversation(with participant: ChatParticipant) -> Conversation {
        // Create conversation ID
        let conversationId = createDirectConversationId(
            uid1: currentUserId,
            uid2: participant.id
        )

        // Check if conversation exists
        if let existing = conversations.first(where: { $0.id == conversationId }) {
            return existing
        }

        // Create new conversation
        let conversation = Conversation(
            id: conversationId,
            title: participant.callsign,
            participants: [participant],
            isGroupChat: false
        )

        conversations.append(conversation)
        saveConversations()

        print("Created direct conversation with \(participant.callsign)")
        return conversation
    }
    
    // MARK: - Start Direct Chat (for marker interactions)
    
    func startDirectChat(with uid: String, callsign: String) {
        // Check if conversation already exists
        if let existingConversation = conversations.first(where: { conv in
            conv.participants.contains(where: { $0.id == uid })
        }) {
            print("📬 Direct chat already exists with \(callsign)")
            return
        }
        
        // Create participant
        let participant = ChatParticipant(id: uid, callsign: callsign)
        
        // Add to participants list if not present
        if !participants.contains(where: { $0.id == uid }) {
            participants.append(participant)
            saveParticipants()
        }
        
        // Create conversation using existing method
        _ = getOrCreateDirectConversation(with: participant)
        
        print("✅ Started direct chat with \(callsign)")
    }

    private func createConversation(from message: ChatMessage) {
        // Create participant for sender
        let sender = ChatParticipant(
            id: message.senderId,
            callsign: message.senderCallsign
        )

        // Add to participants if not already present
        if !participants.contains(where: { $0.id == sender.id }) {
            participants.append(sender)
            saveParticipants()
        }

        // Create conversation
        let conversation = Conversation(
            id: message.conversationId,
            title: message.senderCallsign,
            participants: [sender],
            lastMessage: message,
            unreadCount: 1,
            isGroupChat: message.recipientId == nil,
            lastActivity: message.timestamp
        )

        conversations.append(conversation)
        saveConversations()

        print("Created new conversation: \(conversation.displayTitle)")
    }

    private func updateConversation(conversationId: String, with message: ChatMessage) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return
        }

        var conversation = conversations[index]
        conversation.lastMessage = message
        conversation.lastActivity = message.timestamp

        // Increment unread count if message is not from self
        if !message.isFromSelf {
            conversation.unreadCount += 1
        }

        conversations[index] = conversation
        saveConversations()
    }

    func markConversationAsRead(conversationId: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return
        }

        conversations[index].unreadCount = 0
        saveConversations()
    }

    func getMessages(for conversationId: String) -> [ChatMessage] {
        return messages
            .filter { $0.conversationId == conversationId }
            .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Message History Management

    /// Get recent messages across all conversations, sorted by timestamp
    func getRecentMessages(limit: Int = 50) -> [ChatMessage] {
        return messages
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }

    /// Get messages within a specific time range
    func getMessages(from startDate: Date, to endDate: Date) -> [ChatMessage] {
        return messages
            .filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Get conversation statistics
    func getConversationStats(for conversationId: String) -> ConversationStats {
        let conversationMessages = getMessages(for: conversationId)
        let sentMessages = conversationMessages.filter { $0.isFromSelf }
        let receivedMessages = conversationMessages.filter { !$0.isFromSelf }

        return ConversationStats(
            totalMessages: conversationMessages.count,
            sentMessages: sentMessages.count,
            receivedMessages: receivedMessages.count,
            firstMessageDate: conversationMessages.first?.timestamp,
            lastMessageDate: conversationMessages.last?.timestamp
        )
    }

    /// Delete old messages beyond a certain age (for memory management)
    func deleteOldMessages(olderThan days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let oldCount = messages.count

        // Delete attachments for old messages
        let oldMessages = messages.filter { $0.timestamp < cutoffDate }
        for message in oldMessages {
            if message.hasImage {
                PhotoAttachmentService.shared.deleteAttachment(for: message.id)
            }
        }

        messages.removeAll { $0.timestamp < cutoffDate }
        saveMessages()

        let deletedCount = oldCount - messages.count
        if deletedCount > 0 {
            print("Deleted \(deletedCount) old messages and their attachments")
        }

        // Also cleanup orphaned attachments
        PhotoAttachmentService.shared.cleanupOldAttachments(olderThan: days)
    }

    // MARK: - Participant Management

    func updateParticipant(_ participant: ChatParticipant) {
        if let index = participants.firstIndex(where: { $0.id == participant.id }) {
            participants[index] = participant
        } else {
            participants.append(participant)
        }
        saveParticipants()

        // Update "All Chat Users" conversation participants
        if let index = conversations.firstIndex(where: { $0.id == ChatRoom.allUsersId }) {
            conversations[index].participants = participants
            saveConversations()
        }
    }

    func getParticipant(byId id: String) -> ChatParticipant? {
        return participants.first { $0.id == id }
    }

    func getParticipant(byCallsign callsign: String) -> ChatParticipant? {
        return participants.first { $0.callsign == callsign }
    }

    // MARK: - Contact Status Management

    /// Update contact online status based on last seen time
    /// Contacts are considered offline if not seen for more than 5 minutes
    func updateContactStatuses() {
        let offlineThreshold: TimeInterval = 300 // 5 minutes
        let now = Date()
        var updated = false

        for index in participants.indices {
            let timeSinceLastSeen = now.timeIntervalSince(participants[index].lastSeen)
            let shouldBeOnline = timeSinceLastSeen < offlineThreshold

            if participants[index].isOnline != shouldBeOnline {
                participants[index].isOnline = shouldBeOnline
                updated = true
            }
        }

        if updated {
            saveParticipants()
        }
    }

    /// Update participant last seen timestamp
    func updateParticipantLastSeen(id: String) {
        if let index = participants.firstIndex(where: { $0.id == id }) {
            participants[index].lastSeen = Date()
            participants[index].isOnline = true
            saveParticipants()
        }
    }

    /// Get total message count for a specific contact
    func getMessageCount(forContactId contactId: String) -> Int {
        return messages.filter { message in
            message.senderId == contactId || message.recipientId == contactId
        }.count
    }

    /// Get unread message count across all conversations
    var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    // MARK: - Persistence

    private func saveConversations() {
        persistence.saveConversations(conversations)
    }

    private func saveMessages() {
        persistence.saveMessages(messages)
    }

    private func saveParticipants() {
        persistence.saveParticipants(participants)
    }

    // MARK: - Helpers

    private func createDirectConversationId(uid1: String, uid2: String) -> String {
        let sorted = [uid1, uid2].sorted()
        return "DM-\(sorted[0])-\(sorted[1])"
    }

    // MARK: - Delete Conversation

    func deleteConversation(_ conversation: Conversation) {
        // Remove conversation
        conversations.removeAll { $0.id == conversation.id }
        saveConversations()

        // Delete attachments for messages in this conversation
        let conversationMessages = messages.filter { $0.conversationId == conversation.id }
        for message in conversationMessages {
            if message.hasImage {
                PhotoAttachmentService.shared.deleteAttachment(for: message.id)
            }
        }

        // Remove associated messages
        messages.removeAll { $0.conversationId == conversation.id }
        saveMessages()

        print("Deleted conversation: \(conversation.displayTitle) and associated attachments")
    }

    // MARK: - Clear All Data

    func clearAllData() {
        // Delete all attachments
        for message in messages {
            if message.hasImage {
                PhotoAttachmentService.shared.deleteAttachment(for: message.id)
            }
        }

        conversations.removeAll()
        messages.removeAll()
        participants.removeAll()

        persistence.clearAllData()
        setupDefaultConversations()

        print("Cleared all chat data and attachments")
    }

    // MARK: - Storage Statistics

    /// Get total attachment storage used
    func getAttachmentStorageUsed() -> Int64 {
        return PhotoAttachmentService.shared.getStorageUsed()
    }

    /// Get formatted storage usage string
    func getFormattedStorageUsed() -> String {
        let bytes = getAttachmentStorageUsed()
        return PhotoAttachmentService.shared.formatStorageSize(bytes)
    }

    /// Get count of messages with attachments
    func getAttachmentCount() -> Int {
        return messages.filter { $0.hasImage }.count
    }
    
    // MARK: - Message Queue Management
    
    /// Queue a message to be sent when TAKService becomes available
    private func queueMessage(message: ChatMessage, conversationId: String, xml: String, isImageMessage: Bool) {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        // Check queue size limit
        if pendingMessages.count >= maxQueueSize {
            print("⚠️ Message queue full (\(maxQueueSize) messages) - dropping oldest message")
            pendingMessages.removeFirst()
        }
        
        let pendingMessage = PendingMessage(
            message: message,
            conversationId: conversationId,
            xml: xml,
            queuedAt: Date(),
            isImageMessage: isImageMessage
        )
        
        pendingMessages.append(pendingMessage)
        print("📥 Message queued (queue size: \(pendingMessages.count))")
    }
    
    /// Process all pending messages when TAKService becomes available
    private func processPendingMessages() {
        queueLock.lock()
        let messagesToProcess = pendingMessages
        queueLock.unlock()
        
        guard !messagesToProcess.isEmpty else {
            print("📭 No pending messages to process")
            return
        }
        
        guard let takService = takService, takService.isConnected else {
            print("⚠️ Cannot process pending messages - TAKService not available or not connected")
            return
        }
        
        print("📤 Processing \(messagesToProcess.count) pending message(s)...")
        
        var successCount = 0
        var failCount = 0
        var processedIds: [String] = []
        
        for pending in messagesToProcess {
            let success = takService.sendCoT(xml: pending.xml)
            
            if success {
                successCount += 1
                processedIds.append(pending.message.id)
                
                // Update message status to sent
                if let index = messages.firstIndex(where: { $0.id == pending.message.id }) {
                    messages[index].status = .sent
                }
                
                let messageType = pending.isImageMessage ? "image message" : "message"
                let queueTime = Date().timeIntervalSince(pending.queuedAt)
                print("✅ Sent queued \(messageType) (queued for \(String(format: "%.1f", queueTime))s): \(pending.message.messageText.prefix(50))...")
            } else {
                failCount += 1
                
                // Update message status to failed
                if let index = messages.firstIndex(where: { $0.id == pending.message.id }) {
                    messages[index].status = .failed
                }
                
                print("❌ Failed to send queued message: \(pending.message.messageText.prefix(50))...")
            }
        }
        
        // Save updated message statuses
        if successCount > 0 || failCount > 0 {
            saveMessages()
        }
        
        // Remove successfully sent messages from queue
        if !processedIds.isEmpty {
            queueLock.lock()
            pendingMessages.removeAll { pending in
                processedIds.contains(pending.message.id)
            }
            let remainingCount = pendingMessages.count
            queueLock.unlock()
            
            print("📤 Processed pending messages - Success: \(successCount), Failed: \(failCount), Remaining in queue: \(remainingCount)")
        }
    }
    
    /// Get count of pending messages in queue
    var pendingMessageCount: Int {
        queueLock.lock()
        defer { queueLock.unlock() }
        return pendingMessages.count
    }
    
    /// Manually trigger processing of pending messages (useful for retry after connection restored)
    func retryPendingMessages() {
        print("🔄 Manual retry of pending messages requested")
        processPendingMessages()
    }
    
    // MARK: - Contact Blocking
    
    /// Block a contact by UID
    func blockContact(_ uid: String) {
        blockedContacts.insert(uid)
        saveBlockedContacts()
        print("🚫 Blocked contact: \(uid)")
    }
    
    /// Unblock a contact by UID
    func unblockContact(_ uid: String) {
        blockedContacts.remove(uid)
        saveBlockedContacts()
        print("✅ Unblocked contact: \(uid)")
    }
    
    /// Check if a contact is blocked
    func isBlocked(_ uid: String) -> Bool {
        return blockedContacts.contains(uid)
    }
    
    /// Save blocked contacts to persistence
    private func saveBlockedContacts() {
        UserDefaults.standard.set(Array(blockedContacts), forKey: "chat_blocked_contacts")
    }
    
    /// Load blocked contacts from persistence
    private func loadBlockedContacts() {
        if let blocked = UserDefaults.standard.array(forKey: "chat_blocked_contacts") as? [String] {
            blockedContacts = Set(blocked)
        }
    }
    
    // MARK: - Message Management
    
    /// Edit an existing message
    func editMessage(_ messageId: String, newText: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        var message = messages[index]
        message.messageText = newText
        message.isEdited = true
        messages[index] = message
        saveMessages()
        
        // Send update via CoT if online
        if let takService = takService, takService.isConnected {
            let updateXML = ChatXMLGenerator.generateMessageUpdateXML(message: message)
            _ = takService.sendCoT(xml: updateXML)
        }
        
        print("✏️ Message edited: \(messageId)")
    }
    
    /// Delete a message
    func deleteMessage(_ messageId: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        let message = messages[index]
        messages.remove(at: index)
        saveMessages()
        
        // Send deletion notification via CoT if online
        if let takService = takService, takService.isConnected {
            let deleteXML = ChatXMLGenerator.generateMessageDeleteXML(messageId: messageId)
            _ = takService.sendCoT(xml: deleteXML)
        }
        
        print("🗑️ Message deleted: \(messageId)")
    }
    
    /// Search messages by text
    func searchMessages(query: String) -> [ChatMessage] {
        let lowercaseQuery = query.lowercased()
        return messages.filter { message in
            message.messageText.lowercased().contains(lowercaseQuery) ||
            message.senderCallsign.lowercased().contains(lowercaseQuery)
        }
    }
    
    /// Export chat history for a conversation
    func exportChatHistory(conversationId: String, format: ExportFormat = .text) -> String {
        let conversationMessages = messages
            .filter { $0.conversationId == conversationId }
            .sorted { $0.timestamp < $1.timestamp }
        
        guard !conversationMessages.isEmpty else {
            return "No messages to export"
        }
        
        let conversation = conversations.first(where: { $0.id == conversationId })
        let title = conversation?.displayTitle ?? "Chat Export"
        
        switch format {
        case .text:
            return exportAsText(messages: conversationMessages, title: title)
        case .json:
            return exportAsJSON(messages: conversationMessages, title: title)
        case .csv:
            return exportAsCSV(messages: conversationMessages, title: title)
        }
    }
    
    private func exportAsText(messages: [ChatMessage], title: String) -> String {
        var output = "=== \(title) ===\n"
        output += "Exported: \(Date())\n"
        output += "Total Messages: \(messages.count)\n\n"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        for message in messages {
            output += "[\(formatter.string(from: message.timestamp))] "
            output += "\(message.senderCallsign): "
            output += "\(message.messageText)\n"
        }
        
        return output
    }
    
    private func exportAsJSON(messages: [ChatMessage], title: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let exportData: [String: Any] = [
            "title": title,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "messageCount": messages.count,
            "messages": messages.map { message in
                [
                    "id": message.id,
                    "timestamp": ISO8601DateFormatter().string(from: message.timestamp),
                    "sender": message.senderCallsign,
                    "text": message.messageText,
                    "status": message.status.rawValue
                ]
            }
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "{}"
    }
    
    private func exportAsCSV(messages: [ChatMessage], title: String) -> String {
        var csv = "Timestamp,Sender,Recipient,Message,Status\n"
        
        let formatter = ISO8601DateFormatter()
        
        for message in messages {
            let timestamp = formatter.string(from: message.timestamp)
            let sender = message.senderCallsign.replacingOccurrences(of: ",", with: ";")
            let recipient = message.recipientCallsign?.replacingOccurrences(of: ",", with: ";") ?? "All"
            let text = message.messageText.replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " ")
            let status = message.status.rawValue
            
            csv += "\(timestamp),\(sender),\(recipient),\"\(text)\",\(status)\n"
        }
        
        return csv
    }
    
    // MARK: - Typing Indicators
    
    /// Send typing indicator to conversation
    func sendTypingIndicator(to conversationId: String) {
        guard let takService = takService, takService.isConnected else { return }
        
        let xml = ChatXMLGenerator.generateTypingIndicatorXML(
            senderUid: currentUserId,
            senderCallsign: currentUserCallsign,
            conversationId: conversationId
        )
        
        _ = takService.sendCoT(xml: xml)
    }
    
    /// Handle received typing indicator
    func handleTypingIndicator(from uid: String, conversationId: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name("TypingIndicatorReceived"),
            object: nil,
            userInfo: ["uid": uid, "conversationId": conversationId]
        )
    }
}

// MARK: - Export Format

enum ExportFormat {
    case text
    case json
    case csv
}

