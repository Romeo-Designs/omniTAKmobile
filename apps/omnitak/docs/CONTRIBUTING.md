# Contributing Guide

**How to Contribute to OmniTAK Mobile**

Thank you for your interest in contributing to OmniTAK Mobile! This guide will help you set up your development environment, understand our coding standards, and submit contributions.

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Environment](#development-environment)
4. [Project Structure](#project-structure)
5. [Coding Standards](#coding-standards)
6. [Git Workflow](#git-workflow)
7. [Testing](#testing)
8. [Submitting Changes](#submitting-changes)
9. [Documentation](#documentation)
10. [Community](#community)

---

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors, regardless of background or experience level.

### Expected Behavior

- ✅ Be respectful and professional
- ✅ Accept constructive criticism gracefully
- ✅ Focus on what is best for the project
- ✅ Show empathy towards other contributors
- ✅ Give credit where credit is due

### Unacceptable Behavior

- ❌ Harassment, discrimination, or offensive comments
- ❌ Personal attacks or trolling
- ❌ Publishing others' private information
- ❌ Deliberately introducing bugs or security vulnerabilities
- ❌ Spam or off-topic discussions

### Enforcement

Violations of the Code of Conduct should be reported to the project maintainers. All reports will be reviewed and investigated promptly.

---

## Getting Started

### Prerequisites

**Required:**
- macOS 12.0 (Monterey) or later
- Xcode 14.0 or later
- Git
- Apple Developer account (for device testing)

**Recommended:**
- Familiarity with Swift and SwiftUI
- Understanding of MVVM architecture
- Basic knowledge of the TAK protocol (can be learned)
- iOS development experience

### Fork and Clone

**1. Fork the Repository**
```bash
# Navigate to GitHub repository
https://github.com/tyroe1998/omniTAKmobile

# Click "Fork" button (top right)
# Creates your own copy: https://github.com/YOUR-USERNAME/omniTAKmobile
```

**2. Clone Your Fork**
```bash
git clone https://github.com/YOUR-USERNAME/omniTAKmobile.git
cd omniTAKmobile/apps/omnitak
```

**3. Add Upstream Remote**
```bash
git remote add upstream https://github.com/tyroe1998/omniTAKmobile.git
git fetch upstream
```

**4. Verify Remotes**
```bash
git remote -v
# origin    https://github.com/YOUR-USERNAME/omniTAKmobile.git (fetch)
# origin    https://github.com/YOUR-USERNAME/omniTAKmobile.git (push)
# upstream  https://github.com/tyroe1998/omniTAKmobile.git (fetch)
# upstream  https://github.com/tyroe1998/omniTAKmobile.git (push)
```

---

## Development Environment

### Xcode Setup

**1. Open Project**
```bash
cd apps/omnitak
open OmniTAKMobile.xcodeproj
```

**2. Configure Signing**
- Select project in navigator
- Select "OmniTAKMobile" target
- Go to "Signing & Capabilities" tab
- Change "Team" to your Apple Developer account
- Xcode will automatically manage provisioning

**3. Select Simulator/Device**
- Choose target device from Xcode toolbar
- Recommended: iPhone 15 Pro simulator or physical device
- iPad also fully supported

**4. Build and Run**
```bash
# Keyboard shortcut
Cmd + R

# Or click Play button in Xcode toolbar
```

### Build Scripts

The project includes several utility scripts:

**setup_xcode.sh** - Initialize Xcode project
```bash
./setup_xcode.sh
```

**update_build.sh** - Update version and build numbers
```bash
# Auto-increment build number
./update_build.sh

# Set version, auto-increment build
./update_build.sh 1.2.0

# Set both version and build
./update_build.sh 1.2.0 42
```

**update_version.sh** - Alternative version updater
```bash
./update_version.sh 1.2.0 42
```

### Recommended Xcode Settings

**Editor:**
- Enable "Show Invisibles" (Control + Cmd + I)
- Enable "Trim Trailing Whitespace"
- Indent using spaces (4 spaces per tab)

**Source Control:**
- Enable "Show Source Control Changes"
- Enable "Enable Git Ignore"

---

## Project Structure

### Directory Organization

```
apps/omnitak/
├── OmniTAKMobile/              # Main source code
│   ├── Core/                   # App entry point
│   │   ├── OmniTAKMobileApp.swift
│   │   └── ContentView.swift
│   ├── Views/                  # SwiftUI screens (60+)
│   ├── UI/                     # Reusable components
│   ├── Managers/               # View models (11)
│   ├── Services/               # Business logic (27)
│   ├── Models/                 # Data structures (23)
│   ├── CoT/                    # CoT parsing/generation
│   ├── Map/                    # Map system
│   ├── Storage/                # Persistence
│   ├── Utilities/              # Helpers
│   ├── Meshtastic/             # Mesh integration
│   └── Resources/              # Assets, entitlements
├── OmniTAKMobile.xcodeproj/    # Xcode project
├── docs/                       # Documentation
├── screenshots/                # App screenshots
└── *.sh                        # Build scripts
```

### Key Files

**App Entry:**
- `Core/OmniTAKMobileApp.swift` - @main entry point

**Core Services:**
- `Services/TAKService.swift` - TAK connectivity (1105 lines)
- `Services/PositionBroadcastService.swift` - PLI broadcasting (398 lines)
- `Services/EmergencyBeaconService.swift` - Emergency system (417 lines)

**Core Managers:**
- `Managers/ChatManager.swift` - Chat state (891 lines)
- `Managers/ServerManager.swift` - Server config (154 lines)
- `Managers/CertificateManager.swift` - Certificates (436 lines)

**CoT Processing:**
- `CoT/CoTMessageParser.swift` - XML parsing (396 lines)
- `CoT/CoTEventHandler.swift` - Event routing (333 lines)

### Architecture Layers

```
Views (Presentation)
  ↓
Managers (View Models)
  ↓
Services (Business Logic)
  ↓
Models + Storage + Utilities (Foundation)
```

See [Architecture Guide](ARCHITECTURE.md) for detailed information.

---

## Coding Standards

### Swift Style Guide

We follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) with some project-specific conventions.

### Naming Conventions

**Files:**
- `PascalCase` for Swift files
- Match primary type name: `ChatManager.swift`, `ChatModels.swift`

**Types:**
```swift
// Classes, Structs, Enums, Protocols - PascalCase
class ChatManager { }
struct ChatMessage { }
enum MessageStatus { }
protocol NetworkServiceProtocol { }
```

**Variables and Functions:**
```swift
// camelCase
var messageCount: Int
func sendMessage(_ text: String) { }
```

**Constants:**
```swift
// camelCase for let constants
let defaultUpdateInterval: TimeInterval = 30.0

// SCREAMING_SNAKE_CASE for static/class constants
static let MAX_RETRY_ATTEMPTS = 3
```

**Enums:**
```swift
// Case should be lowerCamelCase
enum MessageStatus {
    case pending
    case sending
    case sent
    case delivered
    case failed
}
```

### Code Organization

**File Structure:**
```swift
// MARK: - Imports
import SwiftUI
import Combine

// MARK: - Type Definition
class MyManager: ObservableObject {
    
    // MARK: - Properties
    @Published var items: [Item] = []
    private let service: MyService
    
    // MARK: - Initialization
    init(service: MyService = MyService()) {
        self.service = service
    }
    
    // MARK: - Public Methods
    func performAction() {
        // Implementation
    }
    
    // MARK: - Private Methods
    private func helperMethod() {
        // Implementation
    }
}

// MARK: - Extensions
extension MyManager {
    // Grouped functionality
}
```

**MARK Comments:**
Use `// MARK:` to organize code into logical sections:
- `// MARK: - Properties`
- `// MARK: - Initialization`
- `// MARK: - Lifecycle`
- `// MARK: - Public Methods`
- `// MARK: - Private Methods`
- `// MARK: - Combine Subscriptions`

### SwiftUI Conventions

**View Structure:**
```swift
struct MyView: View {
    // MARK: - Properties
    @StateObject private var viewModel = MyViewModel()
    @State private var showingAlert = false
    
    // MARK: - Body
    var body: some View {
        content
    }
    
    // MARK: - View Components
    private var content: some View {
        VStack {
            headerView
            mainContentView
            footerView
        }
    }
    
    private var headerView: some View {
        Text("Header")
    }
    
    // MARK: - Actions
    private func handleButtonTap() {
        // Action implementation
    }
}
```

**Extract Complex Views:**
```swift
// ❌ Don't do this - too complex
var body: some View {
    VStack {
        // 100 lines of nested views...
    }
}

// ✅ Do this - extract subviews
var body: some View {
    VStack {
        headerSection
        contentSection
        footerSection
    }
}

private var headerSection: some View {
    // Focused component
}
```

### Combine Patterns

**Memory Management:**
```swift
class MyManager: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    func observePublisher() {
        publisher
            .sink { [weak self] value in  // Always use [weak self]
                self?.handleValue(value)
            }
            .store(in: &cancellables)  // Store to prevent premature deallocation
    }
}
```

**Publisher Naming:**
```swift
// Suffix with "Publisher" or use $property for @Published
let eventPublisher = PassthroughSubject<Event, Never>()
@Published var messages: [Message]  // Automatically creates $messages publisher
```

### Error Handling

**Optional Unwrapping:**
```swift
// Prefer guard let for early exit
guard let value = optionalValue else {
    print("❌ Error: value is nil")
    return
}

// Use if let for scoped access
if let value = optionalValue {
    // Use value
}

// Use nil coalescing for defaults
let finalValue = optionalValue ?? defaultValue
```

**Error Propagation:**
```swift
// Do-catch for recoverable errors
do {
    try performRiskyOperation()
} catch {
    print("❌ Error: \(error.localizedDescription)")
    showErrorAlert(error)
}

// Result type for async operations
func fetchData() -> AnyPublisher<Data, Error> {
    // Implementation
}
```

### Comments and Documentation

**File Headers:**
```swift
//
//  ChatManager.swift
//  OmniTAKMobile
//
//  Created by [Name] on [Date].
//

import SwiftUI
```

**DocC Comments:**
```swift
/// Manages chat state and message delivery.
///
/// This manager orchestrates chat conversations, message sending/receiving,
/// and integration with the TAK messaging system.
///
/// - Note: Singleton - use `ChatManager.shared`
class ChatManager: ObservableObject {
    
    /// Sends a text message to the specified conversation.
    ///
    /// - Parameters:
    ///   - text: The message text to send
    ///   - conversationId: The target conversation ID
    /// - Returns: True if message queued successfully, false otherwise
    func sendMessage(text: String, to conversationId: String) -> Bool {
        // Implementation
    }
}
```

**Inline Comments:**
```swift
// Use comments to explain "why", not "what"

// ❌ Don't do this
let interval = 30  // Set interval to 30

// ✅ Do this
let interval = 30  // TAK protocol recommends 30-second PLI intervals for mobile units
```

### Code Smell Checks

**Avoid:**
- ❌ Force unwrapping (`!`) unless absolutely certain
- ❌ Implicitly unwrapped optionals (`var value: String!`)
- ❌ Magic numbers (use named constants)
- ❌ Deep nesting (extract functions)
- ❌ Massive view controllers (split into smaller components)
- ❌ God objects (single class doing too much)

**Prefer:**
- ✅ Optional binding (`guard let`, `if let`)
- ✅ Named constants for configuration values
- ✅ Flat code structure (early returns)
- ✅ Small, focused functions/methods
- ✅ Dependency injection
- ✅ Protocol-oriented design

---

## Git Workflow

### Branch Strategy

**Main Branches:**
- `main` - Production-ready code
- `develop` - Integration branch for features

**Feature Branches:**
- Create from `develop`
- Naming: `feature/short-description`
- Example: `feature/medevac-report`, `feature/offline-maps`

**Bugfix Branches:**
- Create from `main` (hotfix) or `develop` (regular fix)
- Naming: `bugfix/issue-description`
- Example: `bugfix/chat-crash`, `bugfix/certificate-import`

**Release Branches:**
- Create from `develop`
- Naming: `release/version`
- Example: `release/1.3.0`

### Creating a Feature Branch

```bash
# Sync with upstream
git checkout develop
git pull upstream develop

# Create feature branch
git checkout -b feature/my-awesome-feature

# Work on your feature
# ... make changes ...

# Commit frequently
git add .
git commit -m "Add initial structure for my feature"

# Push to your fork
git push origin feature/my-awesome-feature
```

### Commit Messages

**Format:**
```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `style:` - Code style changes (formatting, no logic change)
- `refactor:` - Code restructuring (no behavior change)
- `perf:` - Performance improvements
- `test:` - Adding or updating tests
- `chore:` - Build process, dependencies, etc.

**Examples:**
```bash
# Good commit messages
git commit -m "feat: Add MEDEVAC 9-line report generation"
git commit -m "fix: Resolve crash when importing KML without points"
git commit -m "docs: Update Quick Start guide with offline maps section"

# Bad commit messages
git commit -m "Update stuff"
git commit -m "Fix bug"
git commit -m "WIP"
```

**Detailed Commit:**
```bash
git commit -m "feat: Add offline map tile downloader

Implements background tile downloading for offline map regions.
Users can now define geographic regions and download tiles at
specified zoom levels for offline use.

- Added OfflineMapManager for region management
- Implemented TileDownloader with progress tracking
- Added UI in Settings for region configuration
- Includes tile caching with LRU eviction

Closes #123"
```

### Keeping Your Fork Updated

```bash
# Fetch latest changes from upstream
git fetch upstream

# Merge upstream changes into your local branch
git checkout develop
git merge upstream/develop

# Push to your fork
git push origin develop
```

### Rebasing (Optional, Advanced)

```bash
# Rebase your feature branch on latest develop
git checkout feature/my-feature
git rebase develop

# Resolve conflicts if any
# ... edit conflicting files ...
git add <resolved-files>
git rebase --continue

# Force push (only to your fork!)
git push origin feature/my-feature --force
```

---

## Testing

### Unit Tests

**Location:** `OmniTAKMobileTests/`

**Running Tests:**
```bash
# In Xcode: Cmd + U
# Or: Product → Test
```

**Writing Tests:**
```swift
import XCTest
@testable import OmniTAKMobile

class CoTMessageParserTests: XCTestCase {
    
    func testParsePositionUpdate() {
        // Arrange
        let xmlString = """
        <?xml version="1.0"?>
        <event version="2.0" uid="TEST-123" type="a-f-G-E-S" ...>
            <point lat="38.8977" lon="-77.0365" hae="50.0" ce="10.0" le="5.0"/>
        </event>
        """
        
        // Act
        let event = CoTMessageParser.parse(xmlString)
        
        // Assert
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.uid, "TEST-123")
        XCTAssertEqual(event?.type, "a-f-G-E-S")
        XCTAssertEqual(event?.point.lat, 38.8977, accuracy: 0.0001)
    }
}
```

**Test Coverage:**
- Core functionality should have unit tests
- CoT parsing/generation
- Coordinate conversions
- Data model validation
- Business logic in services

### UI Tests

**Location:** `OmniTAKMobileUITests/`

**Example:**
```swift
import XCTest

class ChatFlowUITests: XCTestCase {
    
    func testSendChatMessage() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to chat
        app.buttons["Chat"].tap()
        app.buttons["All Chat Rooms"].tap()
        
        // Type message
        let messageField = app.textFields["Type a message"]
        messageField.tap()
        messageField.typeText("Test message")
        
        // Send
        app.buttons["Send"].tap()
        
        // Verify message appears
        XCTAssertTrue(app.staticTexts["Test message"].exists)
    }
}
```

### Manual Testing

**Before Submitting PR, Test:**
1. ✅ Build succeeds with no warnings
2. ✅ Feature works as expected
3. ✅ No crashes or freezes
4. ✅ Works on both iPhone and iPad
5. ✅ Works on iOS 15 minimum version
6. ✅ Handles error cases gracefully
7. ✅ Doesn't break existing functionality

**Test Devices:**
- iPhone (any size class)
- iPad (large size class)
- Simulator + physical device

---

## Submitting Changes

### Creating a Pull Request

**1. Push Your Feature Branch**
```bash
git push origin feature/my-awesome-feature
```

**2. Open Pull Request on GitHub**
- Navigate to your fork on GitHub
- Click "Compare & pull request" button
- Select base: `develop` ← compare: `feature/my-awesome-feature`

**3. Fill Out PR Template**
```markdown
## Description
Brief summary of changes.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [x] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [x] Unit tests added/updated
- [x] Tested on iPhone simulator
- [x] Tested on iPad simulator
- [x] Tested on physical device
- [x] No regressions in existing features

## Screenshots (if applicable)
[Add screenshots here]

## Checklist
- [x] My code follows the project's coding standards
- [x] I have performed a self-review of my code
- [x] I have commented my code, particularly in hard-to-understand areas
- [x] I have made corresponding changes to the documentation
- [x] My changes generate no new warnings
- [x] I have added tests that prove my fix is effective or that my feature works
- [x] New and existing unit tests pass locally with my changes

## Related Issues
Closes #123
```

**4. Wait for Review**
- Maintainers will review your PR
- Address any feedback promptly
- Make requested changes and push to same branch
- PR will auto-update

**5. Merge**
- Once approved, maintainer will merge
- Your contribution is live! 🎉

### PR Guidelines

**Good PRs:**
- ✅ Focused on a single feature/fix
- ✅ Well-described with clear purpose
- ✅ Include tests
- ✅ Update documentation if needed
- ✅ No unrelated changes
- ✅ Passes all CI checks

**Avoid:**
- ❌ Mixing multiple unrelated changes
- ❌ Massive PRs with 1000+ line changes
- ❌ No description or context
- ❌ Breaking existing functionality
- ❌ Introducing compiler warnings

---

## Documentation

### When to Update Docs

**Always update documentation for:**
- New features (add to FEATURES.md)
- API changes (update API_REFERENCE.md)
- Architecture changes (update ARCHITECTURE.md)
- New configuration options (update settings docs)
- Changed workflows (update QUICK_START.md)

### Documentation Structure

```
docs/
├── README.md                    # Documentation index
├── ARCHITECTURE.md              # System architecture
├── FEATURES.md                  # Feature documentation
├── API_REFERENCE.md             # API reference
├── QUICK_START.md               # Quick start guide
├── CONTRIBUTING.md              # This file
├── DEPLOYMENT.md                # Build and deployment
├── TROUBLESHOOTING.md           # Common issues
├── COT_PROTOCOL.md              # CoT protocol details
├── SECURITY.md                  # Security guide
├── OFFLINE_MAPS.md              # Offline maps guide
└── MESHTASTIC.md                # Meshtastic integration
```

### Writing Style

**Clear and Concise:**
- Use simple language
- Short paragraphs
- Bullet points for lists
- Code examples where helpful

**Structure:**
- Start with brief overview
- Include step-by-step instructions
- Provide code examples
- Add screenshots/diagrams when useful
- Link to related documentation

---

## Community

### Getting Help

**Questions?**
- Review existing documentation
- Check GitHub Issues for similar questions
- Open a new Discussion on GitHub
- Join TAK community forums/Discord

### Reporting Bugs

**Before Reporting:**
1. Check if bug already reported
2. Verify it's reproducible
3. Collect relevant information

**Bug Report Template:**
```markdown
**Description**
Clear description of the bug.

**Steps to Reproduce**
1. Go to '...'
2. Click on '...'
3. Scroll down to '...'
4. See error

**Expected Behavior**
What you expected to happen.

**Actual Behavior**
What actually happened.

**Screenshots**
If applicable, add screenshots.

**Environment:**
- Device: iPhone 15 Pro
- iOS Version: 17.0
- App Version: 1.2.0
- Server: TAK Server 4.5

**Additional Context**
Any other relevant information.
```

### Feature Requests

**Feature Request Template:**
```markdown
**Feature Description**
Clear description of the proposed feature.

**Use Case**
Why is this feature needed? What problem does it solve?

**Proposed Solution**
How you envision the feature working.

**Alternatives Considered**
Other approaches you've thought about.

**Additional Context**
Mockups, examples from other apps, etc.
```

### Recognition

Contributors will be recognized in:
- Release notes
- Contributors list in README
- GitHub Contributors graph

---

## Thank You!

Thank you for contributing to OmniTAK Mobile! Your efforts help make tactical awareness more accessible to iOS users.

**Happy Coding!** 🚀

---

**Next:** [Architecture Guide](ARCHITECTURE.md) | [Quick Start](QUICK_START.md) | [Back to Index](README.md)
