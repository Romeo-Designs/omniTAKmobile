# OmniTAK Mobile – TODO

## 1. Repository Hygiene & Structure

- [ ] Add a top-level `ARCHITECTURE.md` describing:
  
  - [ ] Overall system (server, client, mobile FFI, Meshtastic integration).
  - [ ] Responsibilities and dependencies of each Rust crate:
    - [ ] `omnitak-core`
    - [ ] `omnitak-cot`
    - [ ] `omnitak-cert`
    - [ ] `omnitak-client`
    - [ ] `omnitak-server`
    - [ ] `omnitak-mobile`
  - [ ] High-level data flow: TAK server ↔ client ↔ mobile apps ↔ Meshtastic.

- [ ] Ensure `crates/target/` and other build artifacts are excluded from VCS:
  
  - [ ] Confirm `.gitignore` rules for:
    - [ ] `crates/target/`
    - [ ] Bazel output directories
    - [ ] Node `node_modules/` (if present)
    - [ ] Platform build outputs (Android/iOS).

- [ ] Add or update `docs/CONTRIBUTING.md` with:
  
  - [ ] Required toolchain versions (Rust, Bazel, Node, Android Studio/Xcode).
  - [ ] Standard workflow for feature branches, PRs, and code review.
  - [ ] Coding style guidelines (Rust, TypeScript, Bazel).

## 2. Build & Tooling

### 2.1 Bazel & Rust Integration

- [ ] Document Bazel entry points:
  
  - [ ] Primary build commands (e.g., `bazel build //...`).
  - [ ] How Rust crates are wired into Bazel (rules, macros, toolchains).
  - [ ] How to run tests via Bazel vs via `cargo`.

- [ ] Add `BUILD.bazel`/`MODULE.bazel` comments where missing:
  
  - [ ] Explain key targets (server, client, mobile library).
  - [ ] Clarify external dependencies (e.g., zstd, Docker-based toolchains).

- [ ] Provide a “from scratch” build guide:
  
  - [ ] Linux/macOS setup:
    - [ ] Install Bazel, Rust, Node, Docker (if required).
    - [ ] Environment variables needed (e.g., for Android/iOS SDKs).
  - [ ] Example commands:
    - [ ] Build server binary.
    - [ ] Build mobile FFI library.
    - [ ] Run unit/integration tests.

### 2.2 Mobile FFI Build (iOS/Android)

- [ ] Document `crates/omnitak-mobile` build process:
  
  - [ ] iOS:
    - [ ] How to run `build_ios.sh` (or equivalent).
    - [ ] Output artifacts (staticlib, headers).
    - [ ] How to integrate into Xcode projects.
  - [ ] Android:
    - [ ] Bazel/Gradle integration steps.
    - [ ] ABI targets and resulting `.so` libraries.
    - [ ] How to consume the C header in JNI/NDK code.

- [ ] Clarify FFI versioning:
  
  - [ ] How breaking changes to the C API are managed.
  - [ ] How mobile apps should pin to specific versions.

### 2.3 Tooling & CI

- [ ] Document `tools/ci` scripts:
  
  - [ ] Purpose of each script.
  - [ ] Which CI jobs call which scripts.
  - [ ] How to run them locally for debugging.

- [ ] Document `tools/zstd`:
  
  - [ ] When/why zstd is required.
  - [ ] How the Docker-based build works.
  - [ ] How to update zstd version safely.

- [ ] Add a `CI.md`:
  
  - [ ] Overview of CI pipeline stages (lint, test, build, package).
  - [ ] How to reproduce CI steps locally.
  - [ ] Any required secrets or environment variables (described, not exposed).

## 3. Rust Crates – API & Usage

### 3.1 `omnitak-core`

- [ ] Add crate-level documentation:
  
  - [ ] Core domain concepts and types.
  - [ ] Relationship to `omnitak-client`, `omnitak-cot`, and `omnitak-mobile`.

- [ ] Add examples:
  
  - [ ] Creating and configuring core types (e.g., Meshtastic connection settings).
  - [ ] Typical usage patterns.

### 3.2 `omnitak-cot`

- [ ] Document CoT model:
  
  - [ ] `CotMessage` structure and key fields.
  - [ ] Supported serialization formats (JSON, XML).
  - [ ] Time/UUID handling.

- [ ] Provide examples:
  
  - [ ] Parsing a CoT message from XML/JSON.
  - [ ] Constructing and serializing a CoT event.

- [ ] Add notes on interoperability:
  
  - [ ] Known TAK/CoT compatibility constraints.
  - [ ] Any deviations/extensions from standard CoT.

### 3.3 `omnitak-cert`

- [ ] Document certificate enrollment flow:
  
  - [ ] Inputs (username/password, URLs, CA roots).
  - [ ] Outputs (client certs, keys, trust stores).
  - [ ] Error handling and retry behavior.

- [ ] Provide example code:
  
  - [ ] Enrolling a client certificate via HTTP.
  - [ ] Building a `rustls` client configuration from enrolled material.

- [ ] Security notes:
  
  - [ ] Storage recommendations for private keys.
  - [ ] TLS versions/cipher suites used.

### 3.4 `omnitak-client`

- [ ] Document client API:
  
  - [ ] How to configure and establish connections to a TAK server.
  - [ ] Supported transports (TCP/UDP, TLS).
  - [ ] How to send and receive CoT messages.

- [ ] Add examples:
  
  - [ ] Minimal client that connects, sends a CoT event, and listens for updates.
  - [ ] Using Meshtastic integration (if applicable).

- [ ] Clarify threading/async model:
  
  - [ ] Tokio usage expectations.
  - [ ] How callers should manage runtimes and tasks.

### 3.5 `omnitak-server`

- [ ] Document server capabilities:
  
  - [ ] Supported protocols and ports.
  - [ ] TLS/mTLS configuration (using `crates/omnitak-server/certs` as examples).
  - [ ] Routing/broadcasting behavior for CoT messages.

- [ ] Improve examples:
  
  - [ ] Ensure example programs are documented and runnable:
    - [ ] Basic TAK server.
    - [ ] TLS-enabled server.
    - [ ] Multi-client/broadcast demo.

- [ ] Operational guidance:
  
  - [ ] Recommended deployment topology.
  - [ ] Logging and metrics (if present).
  - [ ] Configuration file format (e.g., `TAKServer Core Config.xml`).

### 3.6 `omnitak-mobile`

- [ ] Fully document FFI C API (`omnitak_mobile.h`):
  
  - [ ] Each public type and function:
    - [ ] Purpose and semantics.
    - [ ] Thread-safety guarantees.
    - [ ] Ownership and lifetime rules for pointers and buffers.
  - [ ] Error codes and how to interpret them.
  - [ ] Callback conventions (threading, reentrancy).

- [ ] Provide platform-specific integration guides:
  
  - [ ] iOS (Objective‑C/Swift):
    - [ ] Bridging header usage.
    - [ ] Example wrapper class around FFI.
  - [ ] Android (Kotlin/Java + JNI):
    - [ ] Example JNI bindings.
    - [ ] Safe resource management patterns.

- [ ] Add minimal sample apps:
  
  - [ ] iOS sample that:
    - [ ] Initializes the library.
    - [ ] Connects to a test TAK server.
    - [ ] Sends and receives a CoT message.
  - [ ] Android sample with equivalent behavior.

## 4. Security & Certificates

- [ ] Audit and document certificate handling:
  
  - [ ] Where certificates/keys are loaded from and stored.
  - [ ] How trust roots are configured (webpki-roots, custom CAs).
  - [ ] How mTLS is configured between client and server.

- [ ] Clarify development vs production certs:
  
  - [ ] Mark `crates/omnitak-server/certs` as development/test only.
  - [ ] Provide instructions to generate production-ready certs.
  - [ ] Document `generate_certs.sh` (or equivalent) usage and limitations.

- [ ] Add security best practices section:
  
  - [ ] Recommended TLS configuration.
  - [ ] Hardening tips for server deployment.
  - [ ] Handling of credentials for certificate enrollment.

## 5. Testing & Quality

- [ ] Consolidate test documentation:
  
  - [ ] How to run:
    - [ ] Rust unit tests (`cargo test` per crate, workspace-wide).
    - [ ] Bazel tests.
    - [ ] Any integration/system tests (e.g., server + client end-to-end).
  - [ ] How to run tests for mobile FFI (if any).

- [ ] Add missing tests:
  
  - [ ] CoT parsing/serialization edge cases.
  - [ ] Certificate enrollment error paths (network failures, invalid creds).
  - [ ] Client reconnection and failure handling.
  - [ ] FFI boundary tests (null pointers, invalid sizes, lifecycle misuse).

- [ ] Introduce or document linting:
  
  - [ ] Rust:
    - [ ] `cargo fmt` and `cargo clippy` usage.
    - [ ] Enforce via CI.
  - [ ] Bazel:
    - [ ] Any buildifier/buildozer usage.
  - [ ] TypeScript/JS (if applicable):
    - [ ] ESLint configuration and commands.

## 6. Operations & Deployment

- [ ] Create a `DEPLOYMENT.md`:
  
  - [ ] Deploying `omnitak-server`:
    - [ ] Binary distribution vs container images.
    - [ ] Configuration files and environment variables.
    - [ ] Health checks and monitoring hooks (if available).
  - [ ] Upgrading server and client versions safely.

- [ ] Logging & observability:
  
  - [ ] Document logging configuration (Rust `tracing` or similar).
  - [ ] Recommended log levels for development vs production.
  - [ ] Any metrics endpoints or integrations (Prometheus, etc.).

- [ ] Backup & recovery:
  
  - [ ] If any persistent state exists, document:
    - [ ] Where it is stored.
    - [ ] Backup strategy.
    - [ ] Recovery procedure.

## 7. Future Enhancements / Open Questions

- [ ] Clarify Meshtastic integration:
  
  - [ ] Document current feature set.
  - [ ] Roadmap for additional capabilities (if planned).

- [ ] Evaluate API stability:
  
  - [ ] Decide on semver policy for Rust crates and FFI.
  - [ ] Document deprecation process.

- [ ] Performance considerations:
  
  - [ ] Benchmark critical paths (CoT parsing, message routing, TLS handshakes).
  - [ ] Document tuning options (thread pools, buffer sizes, timeouts).

- [ ] Cross-platform consistency:
  
  - [ ] Ensure behavior parity between:
    - [ ] Desktop/server clients.
    - [ ] Mobile clients via FFI.
  - [ ] Document any known platform-specific differences or limitations.