# Suggestions for the OmniTAK Mobile Project

## 1. Repository Hygiene and Build Artifacts

### 1.1 Exclude `target/` and Other Build Outputs

**Issue:** A large portion of the analyzed tree is under `crates/target/debug/...` and similar incremental compilation directories. These are compiler artifacts, not source.

**Suggestions:**

- Ensure `.gitignore` (or equivalent) contains at least:

  ```gitignore
  /crates/target/
  /target/
  **/node_modules/
  **/.gradle/
  **/build/
  ```

- If already present, verify that:
  - No `target/` content is checked in.
  - CI and local docs clearly state that `target/` is generated and should not be committed.

**Benefits:** Smaller repo, faster clones, fewer merge conflicts, and clearer source tree.

### 1.2 Separate Source From Generated Code

If any generated Rust, C headers, or protobuf outputs are checked in:

- Prefer generating them in `target/` or a dedicated `generated/` directory.
- Add a short `README.md` in any directory that intentionally contains generated artifacts, explaining:
  - How they are generated.
  - Which command regenerates them.
  - Whether they should be committed.

---

## 2. Documentation and Onboarding

### 2.1 Top-Level Architecture Overview

**Observation:** The JSON summary shows multiple Rust crates (`omnitak-core`, `omnitak-cot`, `omnitak-client`, `omnitak-cert`, `omnitak-server`, `omnitak-mobile`), Bazel, and mobile FFI.

**Suggestions:**

- Add or expand a top-level `ARCHITECTURE.md` (or a section in `README.md`) that:
  - Describes each core crate and how they relate:
    - `omnitak-core`: shared domain types and utilities.
    - `omnitak-cot`: CoT message types and serialization.
    - `omnitak-cert`: certificate enrollment and TLS utilities.
    - `omnitak-client`: client-side networking and protocol handling.
    - `omnitak-server`: TAK server implementation.
    - `omnitak-mobile`: FFI surface for iOS/Android.

  - Shows a simple diagram, for example:

    ```text
    [omnitak-core] <---- [omnitak-cot]
          ^                  ^
          |                  |
    [omnitak-client]   [omnitak-cert]
          ^                  ^
          |                  |
    [omnitak-mobile]    [omnitak-server]
    ```

  - Explains where Bazel fits vs. Cargo (e.g., Bazel orchestrates multi-language builds; Rust crates are still standard Cargo packages).

### 2.2 Getting Started for Different Personas

Given the mixed environment (Rust, Bazel, mobile, Node/TS):

- Add a “Choose Your Path” section in `README.md`:
  - **Rust core developer**
    - Prereqs: Rust toolchain, `cargo`, `rustup`.
    - Commands:

      ```bash
      cd crates
      cargo test
      cargo build --all
      ```

  - **Server developer**
    - How to run `omnitak-server` locally:

      ```bash
      cd crates/omnitak-server
      cargo run --example basic_server
      ```

    - How to enable TLS using the `certs/` directory.

  - **Mobile integrator (iOS/Android)**
    - Pointer to `crates/omnitak-mobile/README.md` (see below).
    - High-level explanation of the FFI boundary and supported platforms.

  - **Build/CI engineer**
    - Where Bazel entry points are (`WORKSPACE`, `MODULE.bazel`, key `BUILD.bazel` files).
    - How to run the main Bazel targets and tests.

---

## 3. Rust Crate Improvements

### 3.1 Per-Crate `README.md`

For each crate under `crates/`:

- Add a minimal `README.md` with:
  - Purpose and scope.
  - Public API highlights (1–2 examples).
  - How to run tests:

    ```bash
    cargo test -p omnitak-cot
    ```

  - Any feature flags or optional dependencies.

This is especially valuable for:

- `omnitak-core`
- `omnitak-cot`
- `omnitak-client`
- `omnitak-cert`
- `omnitak-server`
- `omnitak-mobile`

### 3.2 Public API and Error Handling Consistency

Without code details, general but actionable suggestions:

- **Error Types:**
  - Prefer crate-specific error enums (e.g., `OmnitakCotError`, `OmnitakCertError`) implementing `std::error::Error`.
  - Provide `From` conversions where appropriate so higher-level crates can wrap lower-level errors cleanly.

- **Result Aliases:**
  - In each crate:

    ```rust
    pub type Result<T> = std::result::Result<T, Error>;
    ```

  - This simplifies signatures and keeps error handling consistent.

- **Logging and Tracing:**
  - Standardize on `tracing` across crates.
  - Ensure that FFI-facing code in `omnitak-mobile` logs enough context for debugging without leaking sensitive data.

### 3.3 Testing Strategy

- Ensure each crate has:
  - Unit tests colocated with modules.
  - At least one integration test in `tests/` where it makes sense (e.g., end-to-end CoT serialization round-trip for `omnitak-cot`, TLS handshake and certificate enrollment for `omnitak-cert`).

- For `omnitak-server`:
  - Add example-based tests that:
    - Start a server on an ephemeral port.
    - Connect a client using `omnitak-client`.
    - Exchange a simple CoT message and assert it is received.

---

## 4. Mobile FFI (`omnitak-mobile`)

### 4.1 FFI Header and ABI Stability

**Observation:** `crates/omnitak-mobile/include` contains a C header for the FFI.

**Suggestions:**

- Add `crates/omnitak-mobile/README.md` describing:
  - Supported platforms (iOS/Android, architectures).
  - Build commands:

    ```bash
    ./build_ios.sh
    # or
    cargo build -p omnitak-mobile --target aarch64-apple-ios
    ```

  - How to integrate the generated static/dynamic library and header into:
    - Xcode projects.
    - Android (JNI/NDK) projects.

- In the header file:
  - Document each function with:
    - Threading expectations (can be called from any thread?).
    - Ownership rules (who allocates/frees memory, especially strings and buffers).
    - Lifetime of callbacks and how to unregister them.

- Consider versioning the FFI:
  - Add a function like:

    ```c
    const char* omnitak_mobile_version(void);
    ```

  - Optionally, a struct with ABI version fields to detect mismatches at runtime.

### 4.2 Safety and Panic Boundaries

In the Rust FFI implementation (`crates/omnitak-mobile/src`):

- Ensure all `extern "C"` functions:
  - Wrap internal logic with `std::panic::catch_unwind` and convert panics into error codes or logs, to avoid unwinding across the FFI boundary.
  - Validate all pointers and lengths before dereferencing.
  - Use `#[repr(C)]` on any structs shared with C.

- Document in the header:
  - That the library never throws exceptions or panics across the boundary.
  - The set of error codes and their meaning.

---

## 5. TLS and Certificate Handling (`omnitak-cert`, `omnitak-server`)

### 5.1 Secure Defaults and Configuration

**Observation:** `omnitak-cert` uses `rustls`, `webpki-roots`, `reqwest`, and `omnitak-server/certs` contains test PKI material.

**Suggestions:**

- In `omnitak-cert`:
  - Provide a single high-level builder API, e.g.:

    ```rust
    pub struct EnrollmentConfig { /* ... */ }

    pub async fn enroll(config: EnrollmentConfig) -> Result<ClientCertificate> { /* ... */ }
    ```

  - Document:
    - Which cipher suites and protocol versions are used.
    - How certificate validation is performed.
    - How to override trust roots (for test vs production).

- In `omnitak-server`:
  - Clearly mark `certs/` as **development/test only** in a `README.md` inside that directory.
  - Add configuration options to:
    - Load server and CA certs from external paths or environment variables.
    - Enable/disable mutual TLS.
  - Consider a CLI flag or config file for TLS settings, rather than hardcoding paths.

### 5.2 Example Workflows

- Add example programs or docs that show:
  - How to:
    1. Run `omnitak-server` with TLS enabled.
    2. Use `omnitak-cert` to enroll a client certificate.
    3. Connect using `omnitak-client` with the enrolled certificate.

- Provide copy-pasteable commands in `omnitak-server/examples/README.md`.

---

## 6. Bazel, Cargo, and Multi-Tooling

### 6.1 Clear Build Entry Points

**Observation:** Bazel is used as the main orchestrator, but Rust crates are standard Cargo packages.

**Suggestions:**

- In the root `README.md` or `BUILDING.md`:
  - Document:
    - **Pure Rust workflow** (for Rust-only contributors):

      ```bash
      cd crates
      cargo build --all
      cargo test --all
      ```

    - **Bazel workflow** (for full-stack builds):

      ```bash
      bazel build //...
      bazel test //...
      ```

  - Explain when Bazel is required (e.g., cross-language builds, mobile packaging) vs when Cargo is sufficient.

### 6.2 Syncing Dependencies

- If Bazel and Cargo both describe dependencies:
  - Consider using `rules_rust` or a single source of truth to avoid drift.
  - Document the process for updating dependencies:
    - Update `Cargo.toml`.
    - Regenerate Bazel `Cargo.Bazel.lock` or equivalent, if used.
    - Run tests under both Cargo and Bazel.

---

## 7. CI and Tooling

### 7.1 CI Coverage

**Observation:** `tools/ci` contains helper scripts for CI.

**Suggestions:**

- Ensure CI runs at least:
  - `cargo test --all` in `crates/`.
  - `cargo clippy --all-targets --all-features -D warnings`.
  - `cargo fmt --all -- --check`.

- If Bazel is the primary CI driver:
  - Add Bazel targets that wrap the above commands, and document them (e.g., `//tools/ci:rust_tests`).

### 7.2 Developer Tooling

- Provide a `CONTRIBUTING.md` section describing:
  - Required tools (Rust version, Bazel version, Node version if needed).
  - Recommended workflow:
    - Run `cargo fmt` before committing.
    - Run `cargo clippy` and fix warnings.
    - Run the relevant `tools/ci` script locally before opening a PR.

---

## 8. CoT and Protocol-Level Documentation

**Observation:** `omnitak-cot` is central to CoT handling.

**Suggestions:**

- Add protocol-focused docs in `crates/omnitak-cot/README.md`:
  - Describe:
    - Supported CoT message types.
    - Any deviations or extensions from standard CoT.
    - Serialization formats (XML, JSON, binary?).

  - Include simple examples:

    ```rust
    use omnitak_cot::{CotMessage};

    let xml = "<event ...>...</event>";
    let msg = CotMessage::from_xml(xml)?;
    let xml_out = msg.to_xml()?;
    ```

- If there are interoperability constraints with TAKServer or other systems, document them explicitly (e.g., required fields, known quirks).

---

## 9. Security and Hardening

Even without full code, some general but concrete steps:

- **Secrets Management:**
  - Ensure no real private keys or passwords are committed; keep only test keys with clear warnings.
  - Document how to provide secrets in production (env vars, config files, secret managers).

- **Input Validation:**
  - For all network-facing crates (`omnitak-client`, `omnitak-server`), ensure:
    - CoT messages are validated before processing.
    - Size limits are enforced on incoming messages.
    - Timeouts and connection limits are configurable.

- **Logging:**
  - Avoid logging sensitive data (credentials, private keys).
  - Provide a way to configure log level at runtime.

---

## 10. Future Enhancements

### 10.1 Observability

- Add optional integration with metrics (e.g., `metrics`, `opentelemetry`) in `omnitak-server`:
  - Expose:
    - Number of connected clients.
    - Messages per second.
    - TLS handshake failures, etc.

- Document how to enable/disable metrics in production.

### 10.2 Example Apps and Demos

- Provide a small end-to-end demo:
  - A script or doc that:
    - Starts `omnitak-server`.
    - Runs a simple Rust client (or mobile test harness) that sends a CoT message.
    - Shows the server logging the received event.

- This can live under `examples/` at the root or under `crates/omnitak-server/examples`.

---

These suggestions focus on making the project easier to understand, safer to integrate (especially on mobile), and more maintainable over time, while aligning with the existing Rust/Bazel/mobile architecture described in the findings.
