# OmniTAK Mobile – Developer Guide

## Overview

OmniTAK Mobile is a cross‑platform TAK (Team Awareness Kit) client built primarily in Rust, with mobile bindings and tooling for Android and iOS. The repository is organized around:

- A Rust workspace (`crates/*`) implementing core logic, CoT handling, client/server, Meshtastic integration, and mobile FFI.
- Bazel as the top‑level build/orchestration system.
- Mobile integration layers (C FFI header, mobile crates, Android/iOS build glue).
- Supporting tools (Docker, CI scripts, zstd tooling).

This document focuses on the parts relevant to developers extending or integrating with the system.

---

## Architecture

### High‑Level Components

- **Core Rust crates (`crates/*`)**
  - `omnitak-core`: foundational types, configuration, shared utilities.
  - `omnitak-cot`: Cursor‑on‑Target (CoT) data structures and serialization.
  - `omnitak-cert`: certificate and TLS handling, including enrollment.
  - `omnitak-client`: TAK client library (networking, protocol handling).
  - `omnitak-server`: TAK server implementation (TCP/TLS, routing).
  - `omnitak-mobile`: mobile FFI wrapper around the core/client functionality.

- **Mobile integration**
  - `crates/omnitak-mobile/include/omnitak_mobile.h`: C FFI API surface.
  - `crates/omnitak-mobile/src`: Rust implementation of the FFI bridge.
  - Android/iOS platform projects and glue code (Bazel and native build systems).

- **Tooling**
  - `tools/ci`: CI helper scripts for building/testing key targets.
  - `tools/zstd`: vendored zstd binaries and Bazel integration.
  - Dockerfiles and scripts for reproducible builds (esp. Android).

- **Build systems**
  - **Bazel**: primary orchestrator for multi‑language builds.
  - **Cargo**: Rust workspace management and crate builds.
  - **Gradle/Xcode**: used indirectly via platform projects.

---

## Rust Workspace (`crates`)

### Workspace Layout

- `crates/Cargo.toml` (or equivalent) defines a Rust workspace including:
  - `omnitak-core`
  - `omnitak-cot`
  - `omnitak-cert`
  - `omnitak-client`
  - `omnitak-server`
  - `omnitak-mobile`
  - (and possibly Meshtastic‑related crates, not fully listed in the snippet)

The `crates/target` directory is standard Cargo build output and should not be edited.

### `omnitak-core`

- **Location**: `crates/omnitak-core/src`
- **Role**:
  - Core domain types and utilities shared across the workspace.
  - Configuration models (e.g., Meshtastic connection types/settings).
  - Common serialization/time/UUID/error handling helpers.

**When to modify**:

- Adding new cross‑cutting types or configuration options.
- Introducing shared utilities used by multiple crates.

### `omnitak-cot`

- **Location**: `crates/omnitak-cot/src`
- **Role**:
  - CoT message representation (`CotMessage` and related types).
  - Parsing/generation of CoT XML/JSON.
  - Time/UUID integration for CoT events.

**When to modify**:

- Supporting new CoT message variants or fields.
- Changing serialization formats or adding convenience APIs for CoT.

### `omnitak-cert`

- **Location**: `crates/omnitak-cert/src`
- **Role**:
  - TLS certificate and key parsing/validation.
  - Building `rustls` client configurations.
  - TAK server certificate enrollment over HTTP (async via `tokio` + `reqwest`).
  - Encoding/decoding (e.g., base64, JSON) for enrollment flows.

**Key dependencies**:

- `rustls`, `webpki-roots` for TLS.
- `reqwest`, `tokio` for async HTTP.
- `serde` for configuration and protocol payloads.

**When to modify**:

- Changing how certificates are loaded or validated.
- Implementing new enrollment flows or authentication mechanisms.

### `omnitak-client`

- **Location**: `crates/omnitak-client/src`
- **Role**:
  - TAK client networking logic:
    - TCP/UDP connections to TAK servers.
    - TLS integration via `omnitak-cert`.
  - Protocol handling for CoT and Meshtastic.
  - High‑level client API consumed by mobile and other frontends.

**When to modify**:

- Adding new connection modes or transports.
- Changing reconnection, retry, or routing logic.
- Exposing new client‑side features to the FFI/mobile layer.

### `omnitak-server`

- **Location**:
  - Crate root: `crates/omnitak-server`
  - Examples: `crates/omnitak-server/examples`
  - Test PKI: `crates/omnitak-server/certs`
- **Role**:
  - TAK server implementation:
    - TCP CoT message routing.
    - Multi‑client broadcasting.
    - TLS support (including mutual TLS) using the bundled certs for dev/test.
  - Example binaries for:
    - Basic server startup.
    - TLS‑enabled server.
    - Client connection/broadcast demos.

**When to modify**:

- Changing server behavior (routing, authentication, logging).
- Adding new server‑side protocols or endpoints.
- Updating TLS configuration or PKI handling.

### `omnitak-mobile`

- **Location**:
  - Crate root: `crates/omnitak-mobile`
  - FFI header: `crates/omnitak-mobile/include/omnitak_mobile.h`
  - Implementation: `crates/omnitak-mobile/src`
- **Role**:
  - Mobile‑facing wrapper around core/client functionality.
  - Builds as:
    - `staticlib` for iOS.
    - `cdylib` for Android.
  - Exposes a C ABI for:
    - Establishing connections to TAK servers.
    - Sending/receiving CoT messages.
    - Certificate enrollment and TLS configuration.
    - Registering callbacks for events and errors.

**Key responsibilities**:

- Translate between C‑friendly types and Rust types.
- Manage lifetimes and ownership of connections and callbacks.
- Provide a stable API surface for native mobile code.

**When to modify**:

- Exposing new client/server features to mobile.
- Adjusting FFI types for better ergonomics or safety.
- Adding new callbacks or configuration options.

---

## Mobile FFI (`omnitak_mobile.h` and `crates/omnitak-mobile/src`)

### C API Surface

- **Header**: `crates/omnitak-mobile/include/omnitak_mobile.h`
  - Declares:
    - Opaque handle types (e.g., connection handles).
    - C‑compatible structs for configuration (server address, ports, TLS options).
    - Function signatures for:
      - Library initialization/shutdown.
      - Creating/destroying client instances.
      - Connecting/disconnecting.
      - Sending CoT messages (likely as XML/JSON or structured fields).
      - Registering callbacks for:
        - Incoming CoT messages.
        - Connection state changes.
        - Errors/logging.

### Rust FFI Implementation

- **Location**: `crates/omnitak-mobile/src`
- **Patterns**:
  - `#[no_mangle] extern "C"` functions implementing the header API.
  - Conversion between:
    - Raw pointers and Rust references.
    - C strings (`const char*`) and `String`.
    - C enums/integers and Rust enums.
  - Use of `tokio` or similar runtime to drive async client operations.
  - Error handling:
    - Mapping Rust errors into numeric codes or callback invocations.

### Extending the FFI

When adding a new feature to the mobile API:

1. **Add Rust functionality**:
   - Implement the feature in `omnitak-core` / `omnitak-client` / `omnitak-server` as appropriate.

2. **Expose via `omnitak-mobile`**:
   - Add a new Rust FFI function in `crates/omnitak-mobile/src`:
     - Ensure `extern "C"` and `#[no_mangle]`.
     - Use only C‑compatible types in the signature.
   - Update `omnitak_mobile.h` with the new declaration.
   - If needed, add new C structs/enums and mirror them in Rust.

3. **Threading and safety**:
   - Ensure that any callbacks are invoked on a thread acceptable to the platform (often a background thread; UI updates must be marshaled by platform code).
   - Document whether functions are thread‑safe and how handles can be shared.

4. **Versioning**:
   - Consider how changes affect ABI compatibility.
   - Avoid breaking changes to existing function signatures where possible.

---

## Build System

### Bazel

- **Role**:
  - Primary orchestrator for multi‑language builds.
  - Integrates:
    - Rust crates (via `rules_rust` or similar).
    - Android and iOS platform projects.
    - zstd tooling and other native utilities.
- **Key files**:
  - `WORKSPACE`, `MODULE.bazel`: define external dependencies and modules.
  - `BUILD.bazel` files across the repo: define targets for:
    - Rust libraries/binaries.
    - Mobile artifacts.
    - Tools and tests.

**Typical usage** (examples, exact targets may differ):

```bash
# Build all core Rust targets
bazel build //crates/...

# Build mobile library for Android
bazel build //path/to/android:omnitak_mobile

# Run tests
bazel test //...
```

Check the root `BUILD.bazel` and module‑specific `BUILD.bazel` files for concrete targets.

### Cargo

- **Role**:
  - Manages the Rust workspace under `crates/`.
  - Used for local development, unit tests, and examples.

**Examples**:

```bash
cd crates

# Build all workspace crates in debug mode
cargo build

# Build in release mode
cargo build --release

# Run tests for all crates
cargo test

# Run a specific example from omnitak-server
cargo run -p omnitak-server --example basic_server
```

**Note**: When building via Bazel, Cargo is invoked indirectly; prefer Bazel for CI‑equivalent builds.

### Mobile Build Tooling

- **iOS**:
  - `omnitak-mobile` builds as a `staticlib`.
  - Integrated into Xcode projects via:
    - Bazel‑generated Xcode projects or
    - Prebuilt static libraries + `omnitak_mobile.h`.
  - There may be helper scripts (e.g., `build_ios.sh`) under `crates/omnitak-mobile` or root scripts to produce iOS artifacts.

- **Android**:
  - `omnitak-mobile` builds as a `cdylib` (shared library).
  - Integrated via:
    - JNI wrappers in Android modules.
    - Gradle tasks that depend on Bazel or Cargo outputs.
  - Platform projects under `src/platform-projects/android/*`:
    - `dummy`: minimal app for validation.
    - `client`: likely a reference client app.

- **Docker**:
  - Used for reproducible Android builds and zstd compilation.
  - Look for Dockerfiles and scripts at the repo root and under `tools/zstd`.

---

## Tooling and Utilities

### `tools/ci`

- **Location**: `tools/ci`
- **Role**:
  - Helper scripts for CI pipelines:
    - Install platform dependencies.
    - Build core Bazel targets.
    - Install/smoke‑test CLI tools.
    - Bootstrap sample app environments.
    - Run selected test suites.

**Usage**:

- Typically invoked by CI (GitHub Actions, etc.).
- Can be used locally to reproduce CI behavior.

### `tools/zstd`

- **Location**: `tools/zstd`
- **Role**:
  - Vendors a specific `zstd` version (v1.4.5) for macOS and Linux.
  - Provides:
    - Docker‑based workflow to build zstd.
    - Platform‑specific binaries under:
      - `tools/zstd/bin/macos`
      - `tools/zstd/bin/linux`
    - A wrapper script `zstdw` to call the right binary.
  - Exposed as a Bazel target for use in build rules.

**When relevant**:

- If you add build steps that require compression/decompression, prefer using the Bazel‑integrated zstd rather than system binaries.

---

## Platform Projects

### Android

- **Location**: `src/platform-projects/android`
  - `dummy`: minimal test app.
  - `client`: more complete client application.

**Role**:

- Validate integration of the `omnitak-mobile` library into Android.
- Provide reference implementations for:
  - Loading the shared library.
  - Wiring JNI to the C FFI.
  - Handling callbacks and threading.

### iOS

- **Location**: under `src/platform-projects/ios` or similar (not fully listed in the snippet).
- **Role**:
  - Reference Xcode projects integrating the static library and header.
  - Demonstrate bridging from Objective‑C/Swift to the C FFI.

---

## Development Workflow

### 1. Set Up Environment

- Install:
  - Rust toolchain (`rustup`).
  - Bazel (version per repo docs).
  - Node.js (if working on JS tooling/CLI).
  - Android/iOS SDKs if building mobile apps.
- Optionally:
  - Docker, for Android/zstd builds.

### 2. Build and Test Rust Workspace

```bash
cd crates
cargo build
cargo test
```

Use `cargo run -p omnitak-server --example ...` to explore server examples.

### 3. Build via Bazel

From the repo root:

```bash
bazel build //...
bazel test //...
```

Or target specific modules as needed.

### 4. Mobile Integration

- **iOS**:
  - Build `omnitak-mobile` static library (via Bazel or helper scripts).
  - Add the library and `omnitak_mobile.h` to your Xcode project.
  - Write Swift/Obj‑C wrappers around the C API.

- **Android**:
  - Build the `cdylib` for the required ABIs.
  - Integrate with Gradle and JNI.
  - Use the `client` platform project as a reference.

---

## Guidelines for Contributors

### Where to Put New Code

- **Core/shared logic**: `crates/omnitak-core`.
- **CoT‑specific logic**: `crates/omnitak-cot`.
- **TLS/cert/enrollment**: `crates/omnitak-cert`.
- **Client networking/protocols**: `crates/omnitak-client`.
- **Server behavior**: `crates/omnitak-server`.
- **Mobile API surface**: `crates/omnitak-mobile` (Rust + header).

### Avoid Editing Generated/Build Output

Do not modify:

- `crates/target/**` (Rust build artifacts).
- Bazel `bazel-out/**` (if present).
- Generated headers/binaries under `tools/zstd/bin/**`.

These are produced by the build system and should be ignored by version control.

### Testing

- Add unit tests in the appropriate crate under `tests/` or `mod tests`.
- For integration tests (e.g., client ↔ server), consider:
  - Rust integration tests.
  - Bazel test targets.
  - Platform‑specific tests in Android/iOS projects.

---

## Security and TLS

- Development/test certificates are stored in:
  - `crates/omnitak-server/certs`
- `omnitak-cert` encapsulates:
  - How certificates and keys are loaded.
  - How TLS clients are configured.
  - How enrollment is performed.

When changing TLS behavior:

- Ensure you understand how `rustls` and `webpki-roots` are used.
- Keep test certificates separate from production deployments.
- Update server examples and documentation as needed.

---

## Further Exploration

To understand specific behaviors:

- **Client/server flows**:
  - Inspect `crates/omnitak-client/src` and `crates/omnitak-server/examples`.
- **CoT handling**:
  - Inspect `crates/omnitak-cot/src`.
- **Mobile API**:
  - Inspect `crates/omnitak-mobile/include/omnitak_mobile.h` and `crates/omnitak-mobile/src`.
- **Build configuration**:
  - Inspect root `WORKSPACE`, `MODULE.bazel`, and top‑level `BUILD.bazel`.

This structure should give you a clear starting point for extending OmniTAK Mobile, integrating it into mobile apps, and contributing new features.
