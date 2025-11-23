# Chat System Documentation

## Table of Contents

- [Overview](#overview)
- [GeoChat Protocol](#geochat-protocol)
- [ChatManager](#chatmanager)
- [ChatService](#chatservice)
- [Message Queue & Retry](#message-queue--retry)
- [Conversations](#conversations)
- [Photo Attachments](#photo-attachments)
- [Persistence](#persistence)
- [UI Integration](#ui-integration)
- [Code Examples](#code-examples)

---

## Overview

OmniTAK Mobile's chat system implements the TAK GeoChat protocol for tactical messaging with support for one-on-one and group communication, location sharing, photo attachments, and offline message queuing.

### Key Features

- ✅ **GeoChat Protocol** - TAK-compatible XML messaging
- ✅ **Direct & Group Chat** - One-on-one and team conversations
- ✅ **Location Sharing** - Send current position with messages
- ✅ **Photo Attachments** - Image sharing via base64 encoding
- ✅ **Message Queue** - Offline message queuing with retry
- ✅ **Read Receipts** - Message delivery confirmation
- ✅ **Persistence** - Local message storage
- ✅ **Unread Tracking** - Conversation badge counts
- ✅ **Participant Status** - Online/offline indicators

### Files

- **Main Manager**: `OmniTAKMobile/Managers/ChatManager.swift` (790 lines)
- **Service Layer**: `OmniTAKMobile/Services/ChatService.swift` (310 lines)
- **Storage**: `OmniTAKMobile/Storage/ChatStorageManager.swift`
- **Models**: `OmniTAKMobile/Models/ChatModels.swift` (259 lines)
- **UI**: `OmniTAKMobile/Views/ChatView.swift`
- **CoT Generator**: `OmniTAKMobile/CoT/Generators/ChatCoTGenerator.swift`

---

## GeoChat Protocol

### Message Format

GeoChat messages are transmitted as CoT events with type `b-t-f` (bit-tactical-freetext):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0" uid="GeoChat.IOS-789.Alpha-1.1234567890"
       type="b-t-f" how="h-g-i-g-o" time="2025-11-22T10:30:00Z"
       start="2025-11-22T10:30:00Z" stale="2025-11-22T10:35:00Z">
    <point lat="37.7749" lon="-122.4194" hae="10.0" ce="9999999.0" le="9999999.0"/>
    <detail>
        <__chat id="GeoChat.IOS-789.Alpha-1.1234567890"
                parent="All Chat Rooms" groupOwner="false"
                chatroom="All Chat Rooms" messageId="1234567890">
            <chatgrp uid0="IOS-789" uid1="All Chat Rooms" id="All Chat Rooms"/>
        </__chat>
        <link uid="IOS-789" production_time="2025-11-22T10:30:00Z"
              type="a-f-G-U-C" parent_callsign="Alpha-1" relation="p-p"/>
        <remarks source="BAO.F.ATAK.IOS-789"
                 to="All Chat Rooms" time="2025-11-22T10:30:00Z">
            Hello Team, ready to proceed.
        </remarks>
    </detail>
</event>
```

### Protocol Elements

| Element        | Attribute                              | Purpose                            |
| -------------- | -------------------------------------- | ---------------------------------- |
| `event.type`   | `b-t-f`                                | GeoChat message identifier         |
| `event.uid`    | `GeoChat.{UID}.{callsign}.{timestamp}` | Unique message ID                  |
| `__chat`       | Message metadata                       | Chat routing information           |
| `chatgrp.uid0` | Sender UID                             | Who sent the message               |
| `chatgrp.uid1` | Recipient UID                          | Who receives (or "All Chat Rooms") |
| `remarks`      | Message text                           | Actual message content             |
| `link`         | Sender metadata                        | Sender's current status            |

### Message Types

```swift
enum ChatMessageType: String {
    case text           // Plain text message
    case location       // Location share with coordinates
    case image          // Photo attachment
    case contact        // Contact card share
    case geochat        // Standard GeoChat
}
```

---

## ChatManager

Main state management for the chat system.

### Class Declaration

```swift
class ChatManager: ObservableObject {
    static let shared = ChatManager()

    // MARK: - Published Properties

    @Published var messages: [ChatMessage] = []
    @Published var conversations: [Conversation] = []
    @Published var participants: [ChatParticipant] = []
    @Published var unreadCount: Int = 0

    // User identity
    @Published var currentUserCallsign: String = ""
    @Published var currentUserId: String

    // Dependencies
    private var takService: TAKService?
    private var locationManager: LocationManager?

    // Storage
    private let storage = ChatStorageManager.shared
}
```

### Key Methods

#### configure(takService:locationManager:)

Set up chat system with required dependencies.

```swift
func configure(takService: TAKService, locationManager: LocationManager) {
    self.takService = takService
    self.locationManager = locationManager

    // Load persisted messages
    loadMessages()

    // Subscribe to incoming CoT events
    subscribeToIncomingMessages()
}
```

#### sendMessage(text:to:)

Send a text message to a conversation.

```swift
func sendMessage(text: String, to conversationId: String) {
    guard let conversation = getConversation(id: conversationId) else { return }

    let message = ChatMessage(
        id: UUID().uuidString,
        senderUID: currentUserId,
        senderCallsign: currentUserCallsign,
        recipientUID: conversation.recipientUID,
        recipientCallsign: conversation.name,
        messageText: text,
        timestamp: Date(),
        status: .pending
    )

    // Add to local storage
    messages.append(message)
    updateConversation(with: message)

    // Generate CoT XML
    let cotXML = ChatCoTGenerator.generateChatMessage(
        from: message,
        senderLocation: locationManager?.location?.coordinate
    )

    // Send via TAKService
    takService?.send(cotMessage: cotXML, priority: .high)

    // Update status
    updateMessageStatus(message.id, status: .sent)
}
```

#### processIncomingMessage(\_:)

Handle incoming GeoChat CoT event.

```swift
func processIncomingMessage(_ event: CoTEvent) {
    guard event.type == "b-t-f" else { return }

    // Parse message from CoT
    guard let message = parseGeoChat(from: event) else { return }

    // Check for duplicate
    guard !messages.contains(where: { $0.id == message.id }) else { return }

    // Add to messages
    messages.append(message)

    // Update conversation
    updateConversation(with: message)

    // Increment unread count if not from current user
    if message.senderUID != currentUserId {
        incrementUnreadCount(for: message.conversationId)
    }

    // Persist
    storage.saveMessage(message)

    // Notify user
    if message.senderUID != currentUserId {
        sendLocalNotification(for: message)
    }
}
```

#### createConversation(with:)

Create a new conversation with a participant.

```swift
func createConversation(with participant: ChatParticipant) -> Conversation {
    // Check if conversation already exists
    if let existing = conversations.first(where: { $0.recipientUID == participant.id }) {
        return existing
    }

    let conversation = Conversation(
        id: UUID().uuidString,
        recipientUID: participant.id,
        recipientCallsign: participant.callsign,
        name: participant.callsign,
        participants: [participant],
        messages: [],
        unreadCount: 0,
        lastMessage: nil,
        isGroupChat: false
    )

    conversations.append(conversation)
    storage.saveConversation(conversation)

    return conversation
}
```

---

## ChatService

Service layer with message queue and retry logic.

### Class Declaration

```swift
class ChatService: ObservableObject {
    static let shared = ChatService()

    @Published var queuedMessages: [QueuedMessage] = []
    @Published var isConnected: Bool = false

    private let chatManager = ChatManager.shared
    private let storageManager = ChatStorageManager.shared
    private var retryTimer: Timer?
    private let maxRetries = 3
    private let retryInterval: TimeInterval = 30.0
}
```

### Message Queue

#### QueuedMessage

```swift
struct QueuedMessage: Identifiable, Codable {
    let id: String
    let message: ChatMessage
    var retryCount: Int = 0
    var lastAttempt: Date?
    var status: QueuedMessageStatus
}

enum QueuedMessageStatus: String, Codable {
    case pending        // Not yet sent
    case retrying       // Failed, will retry
    case failed         // Max retries exceeded
    case sent           // Successfully sent
}
```

#### Queue Management

```swift
func queueMessage(_ message: ChatMessage) {
    let queued = QueuedMessage(
        id: message.id,
        message: message,
        status: .pending
    )
    queuedMessages.append(queued)
    storageManager.saveQueuedMessage(queued)
}

func processQueue() {
    guard isConnected else { return }

    let pending = queuedMessages.filter { $0.status == .pending || $0.status == .retrying }

    for var queuedMsg in pending {
        sendQueuedMessage(&queuedMsg)
    }
}

private func sendQueuedMessage(_ queuedMsg: inout QueuedMessage) {
    // Attempt send
    chatManager.sendMessage(
        text: queuedMsg.message.messageText,
        to: queuedMsg.message.recipientUID
    )

    queuedMsg.retryCount += 1
    queuedMsg.lastAttempt = Date()

    if queuedMsg.retryCount >= maxRetries {
        queuedMsg.status = .failed
    } else {
        queuedMsg.status = .retrying
    }

    storageManager.updateQueuedMessage(queuedMsg)
}
```

### Retry Timer

```swift
private func startRetryTimer() {
    retryTimer = Timer.scheduledTimer(withTimeInterval: retryInterval, repeats: true) { [weak self] _ in
        self?.processQueue()
    }
}
```

---

## Conversations

### Conversation Model

```swift
struct Conversation: Identifiable, Codable, Equatable {
    let id: String
    var recipientUID: String
    var recipientCallsign: String
    var name: String                    // Display name
    var participants: [ChatParticipant]
    var messages: [ChatMessage]
    var unreadCount: Int
    var lastMessage: ChatMessage?
    var isGroupChat: Bool
}
```

### Group Chat

Group chat uses special recipient UID "All Chat Rooms":

```swift
func sendGroupMessage(text: String) {
    let message = ChatMessage(
        id: UUID().uuidString,
        senderUID: currentUserId,
        senderCallsign: currentUserCallsign,
        recipientUID: "All Chat Rooms",
        recipientCallsign: "All Chat Rooms",
        messageText: text,
        timestamp: Date()
    )

    sendMessage(message)
}
```

### Conversation Updates

```swift
func updateConversation(with message: ChatMessage) {
    guard let index = conversations.firstIndex(where: { $0.id == message.conversationId }) else {
        return
    }

    // Update last message
    conversations[index].lastMessage = message

    // Add to messages array
    conversations[index].messages.append(message)

    // Sort by timestamp (most recent first)
    conversations.sort { ($0.lastMessage?.timestamp ?? .distantPast) > ($1.lastMessage?.timestamp ?? .distantPast) }

    // Persist
    storage.saveConversation(conversations[index])
}
```

---

## Photo Attachments

### PhotoAttachmentService

Handles image compression, encoding, and transmission.

```swift
class PhotoAttachmentService {
    func sendPhoto(_ image: UIImage, to conversationId: String) {
        // Compress image
        guard let jpegData = image.jpegData(compressionQuality: 0.7) else { return }

        // Resize if too large (max 1MB)
        let resizedData = resizeIfNeeded(jpegData, maxSize: 1_000_000)

        // Encode to base64
        let base64String = resizedData.base64EncodedString()

        // Create attachment
        let attachment = ImageAttachment(
            id: UUID().uuidString,
            filename: "photo_\(Date().timeIntervalSince1970).jpg",
            mimeType: "image/jpeg",
            fileSize: resizedData.count,
            base64Data: base64String
        )

        // Create message with attachment
        let message = ChatMessage(
            id: UUID().uuidString,
            // ... standard fields
            attachment: attachment
        )

        // Send
        chatManager.sendMessage(message)
    }

    private func resizeIfNeeded(_ data: Data, maxSize: Int) -> Data {
        guard data.count > maxSize else { return data }

        guard let image = UIImage(data: data) else { return data }

        let ratio = sqrt(Double(maxSize) / Double(data.count))
        let newSize = CGSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resized?.jpegData(compressionQuality: 0.7) ?? data
    }
}
```

### Image Attachment in CoT

```xml
<detail>
    <image>
        <data encoding="base64" mime-type="image/jpeg">
            /9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a...
        </data>
    </image>
</detail>
```

---

## Persistence

### ChatStorageManager

Handles local message storage using CoreData or JSON.

```swift
class ChatStorageManager {
    static let shared = ChatStorageManager()

    private let fileManager = FileManager.default
    private var messagesURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chat_messages.json")
    }

    func saveMessage(_ message: ChatMessage) {
        var messages = loadMessages()
        messages.append(message)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(messages) {
            try? data.write(to: messagesURL)
        }
    }

    func loadMessages() -> [ChatMessage] {
        guard let data = try? Data(contentsOf: messagesURL) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return (try? decoder.decode([ChatMessage].self, from: data)) ?? []
    }

    func deleteMessage(_ id: String) {
        var messages = loadMessages()
        messages.removeAll { $0.id == id }

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(messages) {
            try? data.write(to: messagesURL)
        }
    }

    func clearAllMessages() {
        try? fileManager.removeItem(at: messagesURL)
    }
}
```

---

## UI Integration

### ChatView

Main chat interface.

```swift
struct ChatView: View {
    @ObservedObject var chatService = ChatService.shared
    @State private var selectedConversation: Conversation?
    @State private var messageText: String = ""

    var body: some View {
        NavigationView {
            List {
                ForEach(chatService.conversations) { conversation in
                    NavigationLink(destination: ConversationView(conversation: conversation)) {
                        ConversationRow(conversation: conversation)
                    }
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { /* New conversation */ }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }
}
```

### ConversationView

Individual conversation screen.

```swift
struct ConversationView: View {
    let conversation: Conversation
    @ObservedObject var chatService = ChatService.shared
    @State private var messageText: String = ""

    var body: some View {
        VStack {
            // Messages list
            ScrollView {
                LazyVStack {
                    ForEach(conversation.messages) { message in
                        MessageBubble(message: message)
                    }
                }
            }

            // Input bar
            HStack {
                TextField("Message", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .navigationTitle(conversation.name)
    }

    func sendMessage() {
        chatService.sendTextMessage(messageText, to: conversation.id)
        messageText = ""
    }
}
```

### MessageBubble

Message display component.

```swift
struct MessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool

    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }

            VStack(alignment: isCurrentUser ? .trailing : .leading) {
                // Callsign
                Text(message.senderCallsign)
                    .font(.caption)
                    .foregroundColor(.gray)

                // Message text
                Text(message.messageText)
                    .padding(10)
                    .background(isCurrentUser ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(12)

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            if !isCurrentUser { Spacer() }
        }
        .padding(.horizontal)
    }
}
```

---

## Code Examples

### Example 1: Send Simple Text Message

```swift
let chatService = ChatService.shared

chatService.sendTextMessage("Ready to proceed", to: conversationId)
```

### Example 2: Send Location with Message

```swift
let location = locationManager.location

chatService.sendLocationMessage(location: location!, to: conversationId)
```

### Example 3: Create Group Conversation

```swift
let participants = [
    ChatParticipant(id: "IOS-123", callsign: "Alpha-1"),
    ChatParticipant(id: "IOS-456", callsign: "Bravo-2"),
    ChatParticipant(id: "IOS-789", callsign: "Charlie-3")
]

let conversation = chatManager.createGroupConversation(
    name: "Blue Team",
    participants: participants
)
```

### Example 4: Handle Incoming Message

```swift
// In CoTEventHandler
func handleCoTEvent(_ event: CoTEvent) {
    if event.type == "b-t-f" {
        chatManager.processIncomingMessage(event)
    }
}
```

### Example 5: Mark Conversation as Read

```swift
chatManager.markConversationAsRead(conversationId)
```

---

## Related Documentation

- **[CoT Messaging](CoTMessaging.md)** - GeoChat protocol details
- **[Managers API](../API/Managers.md)** - ChatManager reference
- **[Models API](../API/Models.md)** - ChatMessage data structures

---

_Last Updated: November 22, 2025_
