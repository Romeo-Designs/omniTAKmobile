# Refactor and Cleanup Plan

## 1. High-priority issues

### 1.1 Clarify service vs. manager responsibilities

- **Affected areas**
  - `OmniTAKMobile/Managers/*.swift`
  - `OmniTAKMobile/Services/*.swift`
  - Documentation under `docs/API/Managers.md`, `docs/API/Services.md`
- **Why it matters**
  - Several services and managers currently have overlapping or circular responsibilities (e.g., a service depending on a manager and vice versa, or both owning state).
  - This blurs the MVVM boundaries, makes reasoning about data flow harder, and complicates testing and dependency injection.
- **Planned changes**
  - Introduce a clear rule set for responsibilities:
    - Managers (ViewModels): UI-facing state + orchestration, no direct networking.
    - Services: business logic + I/O, no direct SwiftUI bindings where avoidable.
  - Refactor services that currently depend directly on managers (e.g., `ChatService`, possibly others) so they depend only on models and lower layers.
  - Refactor managers to depend on services via protocols and composition, not singletons.
  - Update documentation to reflect clarified roles and dependency direction.

### 1.2 Reduce singleton and global state usage

- **Affected areas**
  - Many services and managers are exposed as `static let shared` singletons (e.g., `ChatService`, `ArcGISPortalService`, position and track services, etc.).
  - App bootstrap in `OmniTAKMobile/Core/OmniTAKMobileApp.swift` and `ContentView.swift`.
- **Why it matters**
  - Singletons make dependencies implicit, hinder testability, and encourage tight coupling.
  - SwiftUI provides better patterns via `@StateObject` + `@EnvironmentObject` and dependency injection.
- **Planned changes**
  - Introduce a lightweight dependency container or composition root in `OmniTAKMobileApp` that constructs services and managers.
  - Refactor key singletons (starting with high-value ones: `TAKService`, `ChatService`, `PositionBroadcastService`, `ArcGISPortalService`) to be injected instances.
  - Keep static `shared` only as a thin, deprecated façade during migration; gradually migrate call sites to injected instances.

### 1.3 Harden CoT parsing and validation

- **Affected areas**
  - `OmniTAKMobile/CoT/CoTMessageParser.swift`
  - `CoT/Parsers/ChatXMLParser.swift`
  - `CoT/Generators/*`
  - Interaction with `TAKService` and `CoTEventHandler`
- **Why it matters**
  - CoT XML is security- and safety-critical. Parsing is currently string/regex-heavy and can fail silently or produce partial models.
  - Robust parsing and validation are important for reliability, security, and interoperability with various TAK servers.
- **Planned changes**
  - Introduce a stronger typed `CoTEventType` hierarchy with explicit error cases and reasons.
  - Replace or augment string parsing helpers with `XMLParser`-based implementations where feasible.
  - Add stricter validation for required attributes (`uid`, `type`, timestamps, coordinates) and well-defined behavior for malformed packets (logging + metrics + drop).
  - Add unit tests for CoT parsing covering:
    - Happy paths for position, chat, emergency, waypoint, and other known event types.
    - Malformed or partial XML.
    - Large payloads and edge timestamp formats.

### 1.4 Simplify and stabilize TAK networking layer

- **Affected areas**
  - `OmniTAKMobile/Services/TAKService.swift` (including `DirectTCPSender` and its callbacks)
  - TLS behavior as documented in `TLS_LEGACY_SUPPORT.md`
  - Integration points: `ServerManager`, certificate handling
- **Why it matters**
  - The networking layer is central and complex, with responsibilities spanning: connection lifecycle, TLS configuration, message framing, buffer management, and error interpretation.
  - Current behavior accepts all server certificates and permits legacy TLS; this is necessary for compatibility but must be controlled and auditable.
- **Planned changes**
  - Extract low-level transport (`DirectTCPSender`) into its own file/module with a small, testable interface.
  - Introduce a `TAKConnectionConfiguration` model that consolidates host, port, protocol, TLS, and certificate parameters.
  - Add explicit state machine for connection states with well-defined transitions and backoff logic.
  - Introduce configurable TLS policy (e.g., strict vs. legacy) surfaced in settings and enforced in code.
  - Add tests for message framing, buffer overflow handling, and connection state transitions using a mock `NWConnection` wrapper where feasible.

### 1.5 Consolidate map controllers and reduce duplication

- **Affected areas**
  - `OmniTAKMobile/Map/Controllers/*` including:
    - `EnhancedMapViewController.swift`
    - `MapViewController.swift` and its variants (`MapViewController_Enhanced.swift`, `MapViewController_FilterIntegration.swift`, `MapViewController_Modified.swift`)
    - Backup files (`*.backup`)
  - Map overlays, markers, and integration with SwiftUI (`EnhancedMapViewRepresentable`, `IntegratedMapView.swift` etc.)
- **Why it matters**
  - Multiple map controller variants and backup files indicate experimental or duplicated logic.
  - This increases maintenance cost and risk of inconsistent behavior between map entry points.
- **Planned changes**
  - Identify a single canonical `MapViewController` and `EnhancedMapViewController` design and consolidate related functionality into them.
  - Remove or archive to a separate branch old `*Modified`, `*Enhanced`, `*FilterIntegration`, and `.backup` files once functionality is merged.
  - Extract shared concerns (cursor mode, context menus, overlay coordination) into dedicated helper classes or protocols, used by a single controller implementation.
  - Document the map integration contract between controllers, `MapStateManager`, and SwiftUI wrappers.

### 1.6 Normalize persistence layer patterns

- **Affected areas**
  - `OmniTAKMobile/Storage/*.swift` (Chat, Drawing, Route, Team storage managers)
  - Managers using `UserDefaults` or bespoke file storage directly.
- **Why it matters**
  - Persistence logic is scattered and implemented inconsistently (e.g., some managers talk directly to `UserDefaults`, others through dedicated storage managers).
  - This complicates future migrations (e.g., CoreData, SQLite) and makes testing of persistence-heavy logic harder.
- **Planned changes**
  - Introduce a small `Persistence` abstraction (protocols) for common operations: key-value config, structured file storage, and secure storage.
  - Refactor existing storage managers to conform to these protocols.
  - Refactor managers to depend on these abstractions instead of directly using `UserDefaults` or file URLs.
  - Add tests for migration/upgrade paths where default data is seeded (e.g., default servers).

### 1.7 Tighten boundary between UI and domain logic

- **Affected areas**
  - SwiftUI Views in `OmniTAKMobile/Views/*.swift`
  - UI components in `OmniTAKMobile/UI/*`
  - Direct service usage in views (if present, as per docs)
- **Why it matters**
  - Some views may call services directly for convenience (e.g., network calls, CoT sending), bypassing managers.
  - This breaks MVVM separation, makes view code harder to reason about, and complicates re-use or testing.
- **Planned changes**
  - Audit views for direct service usage and introduce or strengthen corresponding managers (view models) where missing.
  - Move business logic (validation, calculation, CoT preparation) into managers/services.
  - Keep views focused on presentation and simple input validation.

### 1.8 Unify error handling and user feedback

- **Affected areas**
  - All services (`Services/*.swift`), especially networked ones
  - `Errors` documentation under `/docs/errors.md`
  - User-facing views that display error banners, alerts, or toasts
- **Why it matters**
  - Error handling is likely inconsistent, with a mix of thrown errors, optional returns, `Result` types, and silent failures.
  - Users may get cryptic or no feedback for important failures (cert issues, server errors, parsing problems).
- **Planned changes**
  - Define a small, shared error taxonomy (e.g., `AppError` or feature-specific enums) with user-facing and log-facing descriptions.
  - Standardize the way services surface errors (Combine publishers or async/await `throws`).
  - Introduce a central error presentation strategy (e.g., environment-based alert manager) for user-visible issues.
  - Add logging hooks (and optionally analytics hooks) for critical error categories.

---

## 2. Architecture and modularity

### 2.1 Enforce clean layering and dependency direction

- Introduce architectural guidelines:
  - Views → Managers (ViewModels) → Services → Infrastructure (network, storage, xcframework) → External systems.
  - Explicitly discourage dependencies in the opposite direction (e.g., services importing views/managers).
- Add a short `ARCHITECTURE.md` or extend the existing one with:
  - Allowed import directions.
  - Examples of good and bad patterns.

### 2.2 Introduce feature modules (logical, then physical)

- Identify coherent feature slices:
  - Connectivity & Servers (TAKService, ServerManager, certificate flows).
  - Chat & Messaging.
  - Mapping & Overlays.
  - Tracks/Waypoints/Navigation.
  - Offline Maps & ArcGIS integration.
  - Meshtastic.
  - Video.
- Initially, maintain a single Xcode target but:
  - Group related managers, services, models, and views into sub-folders with clear namespace conventions.
  - Introduce feature-level protocols (e.g., `ChatServiceProtocol`, `MapStateProviding`) that views and managers depend upon.
- In later phases, evaluate extraction of some domains (e.g., Chat, Map) into Swift packages or framework targets for stronger isolation.

### 2.3 Stabilize interfaces to the Rust/xcframework core

- Clearly define the Swift boundary layer around `omnitak_mobile.h`:
  - Introduce a dedicated `CoreTAKClient` wrapper in Swift that hides low-level C/Rust details.
  - Make `TAKService` depend on this wrapper instead of directly bridging into C.
- Document:
  - Which functions are called from Swift.
  - Expected threading and callback behavior.
  - Error semantics (return codes vs. callbacks).

### 2.4 Normalize map subsystem responsibilities

- Clarify and document how these pieces interact:
  - Map controllers (`MapViewController`, `EnhancedMapViewController`, `Map3DViewController`).
  - Overlays (`BreadcrumbTrailOverlay`, `MGRSGridOverlay`, etc.).
  - State managers (`MapStateManager`, `DrawingToolsManager`, `MeasurementManager`).
- Extract a `MapRenderingEngine` protocol that map controllers implement and managers depend on, so that managers do not import specific controller classes.
- Introduce a consistent pattern for:
  - Registering overlays.
  - Synchronizing map camera/region with higher-level navigation state.

### 2.5 Improve cross-cutting utilities

- Review utilities in `Utilities/Calculators`, `Converters`, `Network`, `Integration`, `Parsers`.
- Introduce small, well-named protocols where utilities are used widely (e.g., `CoordinateConverter` for MGRS/BNG, `NetworkReachabilityProviding`).
- Avoid having utilities import high-level managers or services; keep them dependency-free or depending only on `Foundation`/`CoreLocation`/`MapKit`.

---

## 3. Testing and reliability

### 3.1 Establish a testing strategy and targets

- Ensure a dedicated unit test target exists for the app.
- Add logical grouping of tests mirroring the main code structure:
  - CoT & Networking
  - Chat & Storage
  - Map & Spatial Calculations
  - ArcGIS & Offline Maps
- Define guidelines for testing levels:
  - Unit tests for pure logic and parsing.
  - Integration tests using lightweight harnesses (e.g., fake TAK server, mock HTTP server).

### 3.2 CoT parsing and generation tests

- Add unit tests for `CoTMessageParser`:
  - Validating XML extraction, handling of multiple concatenated messages, and invalid fragments.
  - Ensuring each event type routes to the correct `CoTEventType` case.
- Add tests for chat-specific XML parsing and generation:
  - `ChatXMLParser` and `ChatXMLGenerator` round-trip tests for basic and complex messages.
- Add validation tests for emergency alerts and waypoint parsing.

### 3.3 Networking and connection management tests

- Introduce a protocol abstraction over `NWConnection` and inject it into `DirectTCPSender`.
- Add tests using a fake connection to verify:
  - Reconnection logic on `failed` and `cancelled` states.
  - Buffer handling when messages are split or concatenated.
  - Behavior when buffer thresholds are exceeded.

### 3.4 Persistence and model round-trip tests

- Add tests for storage components in `Storage/`:
  - Chat history save/load, including queued messages.
  - Route and track persistence.
  - Team and waypoint persistence.
- Validate `Codable` round trips for critical domain models (servers, certificates metadata, mission packages.)

### 3.5 Map and spatial calculations

- Add unit tests for `MeasurementCalculator`, `MGRSConverter`, and `BNGConverter`:
  - Known-value conversions and edge coordinates.
  - Distance and bearing correctness for typical tactical scenarios.
- Add snapshot-like tests for overlay calculations where feasible (e.g., breadcrumb path resolution for a given Track).

### 3.6 End-to-end or scenario tests (where feasible)

- Introduce a small number of integration tests that:
  - Start a fake TAK endpoint (e.g., local TCP server) and send canned CoT streams; verify that:
    - Chat, tracks, emergency alerts, and waypoints reach the appropriate managers.
  - Exercise a subset of ArcGIS API calls against a mock or dev endpoint.

---

## 4. Error handling and observability

### 4.1 Standardize error types

- Define a top-level `AppError` enum or protocol with cases for:
  - Network (connection, TLS, DNS, timeouts).
  - Parsing (CoT, XML, JSON, KML/KMZ).
  - Storage (I/O, permissions, data corruption).
  - External service errors (ArcGIS, Elevation API).
  - User input / configuration errors.
- Refactor services to:
  - Throw `AppError` (or feature-specific error enums) from async functions.
  - Wrap lower-level errors (`URLError`, `NWError`, etc.) while preserving diagnostics.

### 4.2 Improve logging

- Introduce a lightweight logging abstraction (protocol + default implementation) instead of ad-hoc `print` or `NSLog`.
- Classify logs by level (debug, info, warning, error) and domain (network, CoT, map, storage).
- Ensure critical paths log enough context (server host/port, event type, uid, etc.) without leaking sensitive data.

### 4.3 Add metrics and counters where appropriate

- Extend `TAKService` metrics beyond basic counters to include:
  - Failed connection attempts.
  - Reconnection count and total downtime.
  - Number of malformed or dropped CoT messages.
- Add lightweight in-memory metrics for:
  - CoT parse errors by type.
  - ArcGIS request failures.
  - Storage read/write failures.
- Optionally expose a developer diagnostics screen summarizing these metrics.

### 4.4 Surface errors consistently in the UI

- Define a shared `ErrorPresenter` or environment object used by views.
- Update key views (e.g., server connection, chat send, offline maps download, certificate enrollment) to:
  - Report errors consistently via this presenter.
  - Provide user-friendly messages with possible remediation steps (e.g., “Check certificate password”, “Verify TAK server IP/port”).

---

## 5. Incremental roadmap

### Phase 1 – Foundations & quick wins

- Establish and document architectural guidelines (MVVM layering, dependency direction).
- Introduce logging abstraction and error taxonomy (`AppError`).
- Start refactoring `CoTMessageParser` with added unit tests for existing behavior (no functional changes yet).
- Extract `DirectTCPSender` into its own file and introduce a protocol for its interface.
- Audit views for direct service usage and create or connect managers where necessary (no behavior changes).

### Phase 2 – Core networking and CoT robustness

- Implement connection state machine and reconnection policy in `TAKService`.
- Introduce `TAKConnectionConfiguration` and refactor connection entry points to use it.
- Implement TLS policy abstraction with options for strict and legacy modes, and wire it into settings.
- Complete CoT parser hardening:
  - Introduce richer `CoTEventType` enums.
  - Add validation logic and enhanced logging for malformed messages.
- Add unit tests for `DirectTCPSender` using a mock `NWConnection` to verify buffer and framing logic.

### Phase 3 – Service/manager separation and DI

- Introduce a simple dependency container instantiated in `OmniTAKMobileApp`.
- Refactor high-impact services away from singletons, starting with:
  - `TAKService`
  - `ChatService`
  - `PositionBroadcastService`
  - `ArcGISPortalService`
- Refactor corresponding managers to receive injected services (constructor injection or environment objects).
- Update views to obtain managers/services through SwiftUI environment rather than accessing singletons directly.
- Add unit tests for managers using mocks of services and storage.

### Phase 4 – Map subsystem consolidation and persistence normalization

- Consolidate map controllers:
  - Merge functionality from `MapViewController_*` variants into a single canonical implementation.
  - Remove deprecated/backup files from the active target (after confirming no required behavior is lost).
- Introduce `MapRenderingEngine` or similar abstraction and apply it to map-related managers.
- Introduce persistence protocols and refactor storage components to conform.
- Refactor managers that directly hit `UserDefaults` or file system to use these storage abstractions.
- Add tests for persistence round-trips and migration behavior where default values are seeded.

### Phase 5 – Advanced testing, observability, and modularization

- Add integration tests for CoT flows using a fake TAK server.
- Add integration tests for ArcGIS and Elevation APIs using mocked HTTP responses.
- Introduce additional metrics and a developer diagnostics view.
- Evaluate and, if beneficial, extract one or two major domains (e.g., Chat, Map) into separate Swift packages or local frameworks to enforce modularity.
- Refine and expand documentation (`docs/DeveloperGuide`, `docs/API`) to align with the refactored structure and patterns.
