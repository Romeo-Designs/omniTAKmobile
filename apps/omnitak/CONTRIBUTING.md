# Contributing to OmniTAK Mobile

Thank you for your interest in contributing to OmniTAK Mobile! This document provides guidelines for contributing to the project.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Required Toolchain Versions](#required-toolchain-versions)
- [Development Workflow](#development-workflow)
- [Coding Style Guidelines](#coding-style-guidelines)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Code Review Guidelines](#code-review-guidelines)

---

## Getting Started

### Prerequisites

Before you begin, ensure you have:

1. A Mac running macOS 12.0 or later
2. Xcode 15.0 or later installed
3. Command Line Tools for Xcode
4. Git installed
5. An Apple ID (for device testing)

### Setting Up Your Development Environment

```bash
# 1. Clone the repository
git clone https://github.com/tyroe1998/omniTAKmobile.git
cd omniTAKmobile/apps/omnitak

# 2. Verify Xcode installation
xcodebuild -version

# 3. Install Command Line Tools (if not already installed)
xcode-select --install

# 4. Open the project in Xcode
open OmniTAKMobile.xcodeproj
```

---

## Required Toolchain Versions

### Current Requirements (Swift/iOS)

| Tool                   | Minimum Version | Recommended Version | Notes                        |
| ---------------------- | --------------- | ------------------- | ---------------------------- |
| **macOS**              | 12.0            | 14.0+               | Required for Xcode           |
| **Xcode**              | 15.0            | Latest stable       | Install from App Store       |
| **Swift**              | 5.9             | 6.2+                | Included with Xcode          |
| **iOS Target**         | 15.0            | 17.0+               | Deployment target            |
| **Command Line Tools** | Latest          | Latest              | Run `xcode-select --install` |
| **Git**                | 2.30+           | Latest              | Usually pre-installed        |

### Future Requirements (Planned Architecture)

The project documentation references a planned multi-platform architecture using:

| Tool               | Version | Purpose              | Status   |
| ------------------ | ------- | -------------------- | -------- |
| **Rust**           | 1.70+   | Core logic crates    | Planned  |
| **Cargo**          | Latest  | Rust package manager | Planned  |
| **Bazel**          | 6.0+    | Build orchestration  | Planned  |
| **Node.js**        | 18+     | Tooling (if needed)  | Optional |
| **Android Studio** | Latest  | Android builds       | Planned  |

> **Note**: If you're working on Rust crates or Bazel integration, please refer to the architecture documentation in `docs/guidebook.md` and `docs/Architecture.md`.

### Verifying Your Environment

```bash
# Check versions
xcodebuild -version          # Should show Xcode 15.0+
swift --version              # Should show Swift 5.9+
git --version                # Should show git 2.30+

# If Rust is installed (for future work)
rustc --version 2>/dev/null  # Check Rust compiler
cargo --version 2>/dev/null  # Check Cargo
bazel --version 2>/dev/null  # Check Bazel
```

---

## Development Workflow

### Branch Strategy

We follow a **feature branch workflow**:

1. **`main`** - The primary development branch
   - Always stable and deployable
   - All PRs merge here
   - Protected branch with required reviews

2. **Feature branches** - For new features or bug fixes
   - Branch from `main`
   - Name pattern: `feature/description` or `fix/issue-number`
   - Examples: `feature/chat-enhancements`, `fix/map-rendering-123`

3. **Experimental branches** - For major architectural changes
   - Name pattern: `experiment/description`
   - Example: `experiment/rust-integration`

### Creating a Feature Branch

```bash
# 1. Ensure your main branch is up to date
git checkout main
git pull origin main

# 2. Create a new feature branch
git checkout -b feature/your-feature-name

# 3. Make your changes
# ... edit files ...

# 4. Commit your changes
git add .
git commit -m "Add feature: brief description"

# 5. Push to your fork or the main repo
git push origin feature/your-feature-name

# 6. Create a Pull Request on GitHub
```

### Commit Message Guidelines

Follow conventional commit format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**

```
feat(map): Add satellite imagery layer support

Implemented satellite tile source integration with ArcGIS.
Includes offline caching and layer switching UI.

Closes #123
```

```
fix(cot): Resolve message parsing crash on malformed XML

Added defensive parsing and error handling for edge cases
when receiving CoT messages from legacy systems.

Fixes #456
```

---

## Coding Style Guidelines

### Swift Style Guide

We follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) with some project-specific conventions:

#### General Principles

1. **Clarity at the point of use** - Code should be clear and concise
2. **Consistency** - Follow existing patterns in the codebase
3. **SwiftUI best practices** - Use proper SwiftUI architecture

#### Naming Conventions

```swift
// Classes, Structs, Protocols: UpperCamelCase
class MapViewController { }
struct CoTMessage { }
protocol LocationServiceDelegate { }

// Functions, Variables, Constants: lowerCamelCase
func calculateDistance() { }
var currentLocation: CLLocation
let maximumRetries = 3

// Enums: UpperCamelCase, cases: lowerCamelCase
enum ConnectionState {
    case disconnected
    case connecting
    case connected
}

// Private properties: leading underscore (optional but common)
private var _internalCache: [String: Any] = [:]
```

#### Code Organization

```swift
// MARK: - Organize code with marks
class ChatManager: ObservableObject {

    // MARK: - Properties

    @Published var conversations: [Conversation] = []
    private let service: ChatService

    // MARK: - Initialization

    init(service: ChatService) {
        self.service = service
    }

    // MARK: - Public Methods

    func sendMessage(_ text: String) {
        // Implementation
    }

    // MARK: - Private Methods

    private func processIncomingMessage(_ message: Message) {
        // Implementation
    }
}
```

#### SwiftUI Views

```swift
// Prefer composition over large views
struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel

    var body: some View {
        VStack {
            ChatHeaderView()
            MessageListView(messages: viewModel.messages)
            ChatInputView(onSend: viewModel.sendMessage)
        }
    }
}

// Extract subviews for clarity
struct ChatHeaderView: View {
    var body: some View {
        // Header implementation
    }
}
```

#### Comments

```swift
// Use comments for non-obvious code
// Prefer self-documenting code over comments

// GOOD: Explains WHY
// Wait 500ms to debounce rapid location updates
Task.sleep(nanoseconds: 500_000_000)

// BAD: Explains WHAT (obvious from code)
// Set the title to "Chat"
title = "Chat"

// Use documentation comments for public APIs
/// Sends a CoT message to all connected clients.
///
/// - Parameters:
///   - message: The CoT message to broadcast
///   - recipients: Optional list of specific recipients
/// - Throws: `NetworkError` if connection is lost
/// - Returns: Number of successful deliveries
func broadcastCoTMessage(_ message: CoTMessage, to recipients: [String]? = nil) throws -> Int {
    // Implementation
}
```

#### Error Handling

```swift
// Use Result type for async operations
func fetchServerList() -> Result<[TAKServer], NetworkError> {
    // Implementation
}

// Use throws for synchronous errors
func parseCoTMessage(_ xml: String) throws -> CoTMessage {
    guard let data = xml.data(using: .utf8) else {
        throw CoTError.invalidEncoding
    }
    // Continue parsing
}

// Handle errors appropriately
do {
    let message = try parseCoTMessage(xmlString)
    processMessage(message)
} catch let error as CoTError {
    logger.error("CoT parsing failed: \(error.localizedDescription)")
    showErrorAlert(error)
} catch {
    logger.error("Unexpected error: \(error)")
}
```

### Rust Style Guide (For Future Crates)

When working with Rust code:

```rust
// Follow standard Rust conventions
// Use rustfmt for automatic formatting
// Run clippy for linting

// Example structure
pub struct CoTMessage {
    pub uid: String,
    pub event_type: String,
    pub timestamp: DateTime<Utc>,
}

impl CoTMessage {
    /// Creates a new CoT message with the given parameters.
    pub fn new(uid: String, event_type: String) -> Self {
        Self {
            uid,
            event_type,
            timestamp: Utc::now(),
        }
    }
}

// Use Result for error handling
pub fn parse_cot_xml(xml: &str) -> Result<CoTMessage, CoTError> {
    // Implementation
}
```

**Rust Tooling:**

```bash
# Format code
cargo fmt

# Run linter
cargo clippy -- -D warnings

# Run tests
cargo test

# Build for specific target
cargo build --target aarch64-apple-ios
```

### TypeScript/JavaScript Style Guide (If Node.js Tools Added)

```typescript
// Use TypeScript for type safety
// Follow Airbnb style guide
// Use ESLint and Prettier

interface ServerConfig {
  host: string;
  port: number;
  useTLS: boolean;
}

export async function connectToServer(config: ServerConfig): Promise<Connection> {
  // Implementation
}
```

### Bazel Style Guide (For Build Files)

```python
# BUILD files should be clean and well-organized
# Use consistent formatting

load("@rules_rust//rust:defs.bzl", "rust_library", "rust_test")

rust_library(
    name = "omnitak_core",
    srcs = glob(["src/**/*.rs"]),
    deps = [
        "//third_party/rust:serde",
        "//third_party/rust:tokio",
    ],
    visibility = ["//visibility:public"],
)

rust_test(
    name = "omnitak_core_test",
    crate = ":omnitak_core",
)
```

---

## Testing

### Swift Unit Tests

```swift
import XCTest
@testable import OmniTAKMobile

final class CoTMessageParserTests: XCTestCase {

    func testParseValidCoTMessage() throws {
        // Given
        let xml = """
        <?xml version="1.0"?>
        <event version="2.0" uid="test-123" type="a-f-G">
        </event>
        """

        // When
        let message = try CoTMessageParser.parse(xml)

        // Then
        XCTAssertEqual(message.uid, "test-123")
        XCTAssertEqual(message.type, "a-f-G")
    }

    func testParseInvalidXMLThrows() {
        // Given
        let invalidXML = "<invalid"

        // When/Then
        XCTAssertThrowsError(try CoTMessageParser.parse(invalidXML)) { error in
            XCTAssertTrue(error is CoTError)
        }
    }
}
```

### Running Tests

```bash
# Run all tests via Xcode
cmd + U

# Or via command line
xcodebuild test -scheme OmniTAKMobile -destination 'platform=iOS Simulator,name=iPhone 15'

# For Rust tests (when available)
cd crates
cargo test

# For specific crate
cargo test -p omnitak-core
```

### Test Coverage

- Aim for 70%+ code coverage on core logic
- All public APIs should have tests
- Critical paths (CoT parsing, networking) require comprehensive tests
- UI tests for main user flows

---

## Pull Request Process

### Before Submitting

**Checklist:**

- [ ] Code follows the style guidelines
- [ ] All tests pass locally
- [ ] New code has appropriate tests
- [ ] Documentation is updated (if needed)
- [ ] Commit messages follow conventions
- [ ] No merge conflicts with `main`
- [ ] Build succeeds without warnings
- [ ] Changes are focused and atomic

### PR Template

When creating a PR, include:

```markdown
## Description

Brief description of changes

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing

How have these changes been tested?

## Screenshots (if applicable)

Include screenshots for UI changes

## Checklist

- [ ] Code follows style guidelines
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No new warnings introduced

## Related Issues

Closes #123
Relates to #456
```

### PR Size Guidelines

- **Small PRs** (< 200 lines): Preferred, quick to review
- **Medium PRs** (200-500 lines): Acceptable, may take longer
- **Large PRs** (> 500 lines): Should be split or have good justification

### Draft PRs

Use draft PRs for:

- Work in progress
- Requesting early feedback
- Demonstrating approach before full implementation

---

## Code Review Guidelines

### For Authors

**Responding to Feedback:**

- Address all comments, even if just to acknowledge
- Mark conversations as resolved when addressed
- Be open to suggestions and alternative approaches
- Ask for clarification if feedback is unclear

**Making Changes:**

```bash
# Make requested changes
git add .
git commit -m "Address review feedback: update error handling"

# Push changes
git push origin feature/your-feature-name

# The PR will automatically update
```

### For Reviewers

**What to Look For:**

1. **Correctness**
   - Does the code work as intended?
   - Are there edge cases not handled?
   - Are there potential bugs?

2. **Design**
   - Is the solution well-architected?
   - Does it follow existing patterns?
   - Is it maintainable?

3. **Style**
   - Does it follow coding standards?
   - Is it readable and clear?
   - Are names descriptive?

4. **Tests**
   - Are there adequate tests?
   - Do tests cover edge cases?
   - Are tests meaningful?

5. **Documentation**
   - Is complex logic documented?
   - Are public APIs documented?
   - Is README/docs updated if needed?

**Review Etiquette:**

```markdown
# Good feedback examples:

✅ "Consider using a guard statement here for early return to reduce nesting."

✅ "This looks good! Minor suggestion: we could extract this into a helper method for reusability."

✅ "I'm not sure I understand the purpose of this change. Could you explain the reasoning?"

✅ "Great work on the error handling! This is much more robust."

# Avoid:

❌ "This is wrong." (not constructive)
❌ "Why didn't you do X?" (confrontational)
❌ "Just use Y instead." (not explaining why)
```

**Approval Process:**

- **1 approval required** for minor changes
- **2 approvals required** for major features or breaking changes
- **Maintainer approval required** for architectural changes

---

## Additional Resources

### Documentation

- [README.md](README.md) - Project overview and setup
- [Architecture.md](docs/Architecture.md) - System architecture
- [guidebook.md](docs/guidebook.md) - Developer guide
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment procedures

### External Resources

- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [iOS Development Guide](https://developer.apple.com/ios/)
- [Git Handbook](https://guides.github.com/introduction/git-handbook/)

### Getting Help

- **Issues**: Open an issue for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: Check existing docs first
- **Code**: Look at similar implementations in the codebase

---

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

## Questions?

If you have questions about contributing, please:

1. Check this guide and other documentation
2. Search existing issues and discussions
3. Open a new discussion or issue
4. Contact the maintainers

Thank you for contributing to OmniTAK Mobile! 🚀
