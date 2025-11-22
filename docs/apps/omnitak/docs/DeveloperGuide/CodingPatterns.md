# Coding Patterns & Best Practices

## Table of Contents
- [Overview](#overview)
- [MVVM Pattern](#mvvm-pattern)
- [Combine Framework](#combine-framework)
- [SwiftUI Patterns](#swiftui-patterns)
- [CoT Generation](#cot-generation)
- [State Management](#state-management)
- [Networking Patterns](#networking-patterns)
- [Error Handling](#error-handling)
- [Testing Patterns](#testing-patterns)

---

## Overview

OmniTAK Mobile follows established Swift and SwiftUI patterns for consistency and maintainability. This guide documents the patterns used throughout the codebase.

### Architecture Summary

- **Pattern**: MVVM (Model-View-ViewModel)
- **Reactive**: Combine framework
- **UI**: SwiftUI (declarative)
- **State**: ObservableObject + @Published
- **Dependency**: Shared singletons + injection

---

## MVVM Pattern

### Model Layer

**Purpose**: Data structures and business logic

**Pattern**: Pure Swift structs, Codable for persistence

```swift
// ✅ Good Model
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let senderUID: String
    let messageText: String
    let timestamp: Date
    var status: MessageStatus
    
    // Computed properties OK
    var isRecent: Bool {
        Date().timeIntervalSince(timestamp) < 300
    }
}

enum MessageStatus: String, Codable {
    case pending, sent, delivered, failed
}
```

**Anti-patterns**:
```swift
// ❌ Avoid classes for simple models
class ChatMessage {  // Use struct instead
    var id: String
    // ...
}

// ❌ Avoid UI logic in models
struct ChatMessage {
    var bubbleColor: Color  // UI concern, not model
}
```

### ViewModel Layer (Manager/Service)

**Purpose**: State management and business logic

**Pattern**: ObservableObject with @Published properties

```swift
// ✅ Good ViewModel (Manager)
class ChatManager: ObservableObject {
    // Singleton for shared state
    static let shared = ChatManager()
    
    // Published state triggers UI updates
    @Published var messages: [ChatMessage] = []
    @Published var conversations: [Conversation] = []
    @Published var unreadCount: Int = 0
    
    // Dependencies
    private var takService: TAKService?
    private let storage = ChatStorageManager.shared
    
    // Private init for singleton
    private init() {
        loadMessages()
    }
    
    // Public methods for business logic
    func sendMessage(text: String, to conversationId: String) {
        // 1. Create model
        let message = ChatMessage(...)
        
        // 2. Update state
        messages.append(message)
        
        // 3. Persist
        storage.saveMessage(message)
        
        // 4. Network operation
        takService?.send(cotMessage: generateCoT(from: message))
    }
}
```

**Service Layer Pattern**:
```swift
// ✅ Service for specific functionality
class PositionBroadcastService: ObservableObject {
    static let shared = PositionBroadcastService()
    
    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startBroadcasting()
            } else {
                stopBroadcasting()
            }
        }
    }
    
    @Published var updateInterval: TimeInterval = 30.0 {
        didSet {
            restartTimer()
        }
    }
    
    private var timer: Timer?
    
    private func startBroadcasting() {
        timer = Timer.scheduledTimer(
            withTimeInterval: updateInterval,
            repeats: true
        ) { [weak self] _ in
            self?.broadcastPosition()
        }
    }
}
```

### View Layer

**Purpose**: UI presentation

**Pattern**: SwiftUI View, observe ViewModels

```swift
// ✅ Good View
struct ChatView: View {
    // Observe manager
    @ObservedObject var chatManager = ChatManager.shared
    
    // Local state
    @State private var messageText: String = ""
    @State private var showNewConversation: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(chatManager.conversations) { conversation in
                    NavigationLink(destination: ConversationView(conversation: conversation)) {
                        ConversationRow(conversation: conversation)
                    }
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewConversation = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }
}
```

**View Best Practices**:

1. **Extract Subviews** for readability:
```swift
// ✅ Good - extracted subview
struct ChatView: View {
    var body: some View {
        VStack {
            MessageListView()
            MessageInputView()
        }
    }
}

// ❌ Avoid - everything in one view
struct ChatView: View {
    var body: some View {
        VStack {
            ScrollView {
                // 100 lines of message list code...
            }
            HStack {
                // 50 lines of input code...
            }
        }
    }
}
```

2. **Use ViewModifiers** for reusable styling:
```swift
// ✅ Good - custom view modifier
struct TacticalButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

// Usage
Button("Send") { }
    .modifier(TacticalButtonStyle())
```

---

## Combine Framework

### Publisher/Subscriber Pattern

**Use Case**: React to state changes

```swift
// ✅ Good Combine usage
class ChatService: ObservableObject {
    private let chatManager = ChatManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to manager updates
        chatManager.$messages
            .sink { [weak self] messages in
                self?.updateConversations(with: messages)
            }
            .store(in: &cancellables)
        
        // Combine multiple publishers
        chatManager.$messages
            .combineLatest(chatManager.$conversations)
            .sink { messages, conversations in
                // Update when either changes
            }
            .store(in: &cancellables)
    }
}
```

### Common Combine Operators

**debounce**: Delay rapid updates
```swift
searchTextField.$text
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
    .sink { searchText in
        performSearch(searchText)
    }
    .store(in: &cancellables)
```

**removeDuplicates**: Skip duplicate values
```swift
locationManager.$location
    .removeDuplicates { $0?.coordinate == $1?.coordinate }
    .sink { location in
        updateMap(with: location)
    }
    .store(in: &cancellables)
```

**map**: Transform values
```swift
chatManager.$unreadCount
    .map { count in count > 0 ? "\(count)" : "" }
    .assign(to: \.badgeText, on: tabBarItem)
    .store(in: &cancellables)
```

---

## SwiftUI Patterns

### State Management

**@State**: Local view state
```swift
struct MyView: View {
    @State private var isExpanded: Bool = false
    @State private var selectedItem: Item?
    
    var body: some View {
        // Use state in UI
    }
}
```

**@ObservedObject**: External observable object
```swift
struct MyView: View {
    @ObservedObject var manager = MyManager.shared
    
    var body: some View {
        // Automatically updates when manager changes
    }
}
```

**@StateObject**: View-owned observable object
```swift
struct MyView: View {
    @StateObject private var viewModel = MyViewModel()
    
    var body: some View {
        // ViewModel lifecycle tied to view
    }
}
```

**@EnvironmentObject**: Dependency injection
```swift
// App level
@main
struct OmniTAKMobileApp: App {
    @StateObject var locationManager = LocationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
        }
    }
}

// View level
struct MyView: View {
    @EnvironmentObject var locationManager: LocationManager
}
```

### Conditional Views

```swift
// ✅ Good - clear conditionals
var body: some View {
    VStack {
        if isLoading {
            ProgressView()
        } else if messages.isEmpty {
            EmptyStateView()
        } else {
            MessageListView(messages: messages)
        }
    }
}
```

### List Performance

```swift
// ✅ Good - lazy loading with identifiable
List {
    ForEach(messages) { message in
        MessageRow(message: message)
    }
}

// ❌ Avoid - non-lazy, poor performance
ScrollView {
    VStack {
        ForEach(messages) { message in
            MessageRow(message: message)
        }
    }
}
```

---

## CoT Generation

### Generator Pattern

**Purpose**: Create CoT XML from models

```swift
// ✅ Good CoT Generator
class ChatCoTGenerator {
    static func generateChatMessage(
        from message: ChatMessage,
        senderLocation: CLLocationCoordinate2D?
    ) -> String {
        // 1. Create unique CoT UID
        let cotUID = "GeoChat.\(message.senderUID).\(message.recipientCallsign).\(Int(message.timestamp.timeIntervalSince1970))"
        
        // 2. Format timestamps
        let time = ISO8601DateFormatter().string(from: message.timestamp)
        let stale = ISO8601DateFormatter().string(from: message.timestamp.addingTimeInterval(300))
        
        // 3. Build XML
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(cotUID)" type="b-t-f" how="h-g-i-g-o" time="\(time)" start="\(time)" stale="\(stale)">
            <point lat="\(senderLocation?.latitude ?? 0.0)" lon="\(senderLocation?.longitude ?? 0.0)" hae="0.0" ce="9999999.0" le="9999999.0"/>
            <detail>
                <__chat id="\(cotUID)" parent="\(message.recipientUID)" groupOwner="false" chatroom="\(message.recipientCallsign)">
                    <chatgrp uid0="\(message.senderUID)" uid1="\(message.recipientUID)" id="\(message.recipientCallsign)"/>
                </__chat>
                <link uid="\(message.senderUID)" type="a-f-G-U-C" relation="p-p"/>
                <remarks>\(message.messageText.xmlEscaped)</remarks>
            </detail>
        </event>
        """
        
        return xml
    }
}

// XML escaping extension
extension String {
    var xmlEscaped: String {
        self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
```

### Parser Pattern

**Purpose**: Parse CoT XML into models

```swift
// ✅ Good CoT Parser
class CoTMessageParser {
    func parseCoTMessage(_ xml: String) -> CoTEvent? {
        guard let data = xml.data(using: .utf8) else { return nil }
        
        let parser = XMLParser(data: data)
        let delegate = CoTParserDelegate()
        parser.delegate = delegate
        
        guard parser.parse() else { return nil }
        return delegate.cotEvent
    }
}

class CoTParserDelegate: NSObject, XMLParserDelegate {
    var cotEvent: CoTEvent?
    private var currentElement = ""
    private var currentAttributes: [String: String] = [:]
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, attributes: [String: String]) {
        currentElement = elementName
        
        if elementName == "event" {
            // Parse event attributes
            cotEvent = CoTEvent(
                uid: attributes["uid"] ?? "",
                type: attributes["type"] ?? "",
                time: parseDate(attributes["time"] ?? ""),
                // ...
            )
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // Parse element content
        if currentElement == "remarks" {
            cotEvent?.remarks = string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
```

---

## State Management

### Singleton Pattern

```swift
// ✅ Good Singleton
class MyManager: ObservableObject {
    static let shared = MyManager()
    
    @Published var state: [Item] = []
    
    private init() {
        // Initialize
        loadState()
    }
}

// Usage
let manager = MyManager.shared
```

### Dependency Injection

```swift
// ✅ Good - inject dependencies
class MyService {
    private let takService: TAKService
    private let locationManager: LocationManager
    
    func configure(takService: TAKService, locationManager: LocationManager) {
        self.takService = takService
        self.locationManager = locationManager
    }
}
```

---

## Networking Patterns

### Async/Await

```swift
// ✅ Good - modern async/await
func fetchData() async throws -> Data {
    let url = URL(string: "https://api.example.com/data")!
    let (data, response) = try await URLSession.shared.data(from: url)
    
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw NetworkError.invalidResponse
    }
    
    return data
}

// Usage in SwiftUI
.task {
    do {
        let data = try await fetchData()
        processData(data)
    } catch {
        showError(error)
    }
}
```

### Completion Handlers (Legacy)

```swift
// ⚠️ Legacy pattern (prefer async/await)
func connect(completion: @escaping (Bool) -> Void) {
    DispatchQueue.global().async {
        let success = self.performConnection()
        
        DispatchQueue.main.async {
            completion(success)
        }
    }
}
```

---

## Error Handling

### Custom Errors

```swift
enum NetworkError: LocalizedError {
    case connectionFailed
    case invalidResponse
    case timeout
    case certificateError(String)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to server"
        case .invalidResponse:
            return "Invalid server response"
        case .timeout:
            return "Connection timed out"
        case .certificateError(let details):
            return "Certificate error: \(details)"
        }
    }
}
```

### Error Handling Pattern

```swift
// ✅ Good error handling
func processMessage(_ xml: String) {
    do {
        let event = try parseCoT(xml)
        try validateEvent(event)
        handleEvent(event)
    } catch let error as CoTParsingError {
        print("Parsing error: \(error.localizedDescription)")
    } catch let error as ValidationError {
        print("Validation error: \(error.localizedDescription)")
    } catch {
        print("Unknown error: \(error)")
    }
}
```

---

## Testing Patterns

### Unit Tests

```swift
import XCTest
@testable import OmniTAKMobile

class ChatManagerTests: XCTestCase {
    var manager: ChatManager!
    
    override func setUp() {
        super.setUp()
        manager = ChatManager()
    }
    
    func testSendMessage() {
        // Arrange
        let text = "Test message"
        let conversationId = "test-123"
        
        // Act
        manager.sendMessage(text: text, to: conversationId)
        
        // Assert
        XCTAssertEqual(manager.messages.count, 1)
        XCTAssertEqual(manager.messages.first?.messageText, text)
    }
}
```

### Mock Objects

```swift
class MockTAKService: TAKService {
    var sentMessages: [String] = []
    
    override func send(cotMessage: String, priority: MessagePriority) {
        sentMessages.append(cotMessage)
    }
}

// Usage in tests
func testMessageSending() {
    let mockService = MockTAKService()
    chatManager.configure(takService: mockService, locationManager: LocationManager())
    
    chatManager.sendMessage(text: "Test", to: "conv-1")
    
    XCTAssertEqual(mockService.sentMessages.count, 1)
}
```

---

## Best Practices Summary

### Do ✅

1. **Use MVVM**: Separate concerns clearly
2. **Observe state**: Use `@Published` + `@ObservedObject`
3. **Extract views**: Keep views under 200 lines
4. **Type safety**: Use enums for fixed options
5. **Document public APIs**: Add comments to public methods
6. **Handle errors**: Use proper error types
7. **Test critical paths**: Unit test business logic
8. **Use Combine**: React to state changes
9. **Async/await**: Use for network operations

### Don't ❌

1. **Massive files**: Split files over 500 lines
2. **UI in models**: Keep models pure data
3. **Force unwrapping**: Use optional binding
4. **Completion handlers**: Prefer async/await
5. **Hardcode strings**: Use constants or enums
6. **Global mutable state**: Use singletons sparingly
7. **Ignore errors**: Always handle failure cases
8. **Block main thread**: Use background queues

---

## Related Documentation

- **[Architecture](../Architecture.md)** - System design
- **[Codebase Navigation](CodebaseNavigation.md)** - Finding code
- **[Getting Started](GettingStarted.md)** - Dev environment

---

*Last Updated: November 22, 2025*
