# Error Reference

This document summarizes notable error types, failure modes, and fragile areas identified in the OmniTAK Mobile codebase and build system. Use it as a starting point when debugging or hardening the system.

---

## 1. Build & Tooling Errors

### 1.1 Bazel Build Failures

**Context**

- Bazel is the primary orchestrator (`WORKSPACE`, `MODULE.bazel`, `BUILD.bazel`).
- It coordinates Rust (via `cargo`/`rules_rust`), Node/TypeScript, Android, and iOS builds.

**Common Failure Modes**

- Missing or incompatible toolchains (Rust, Android NDK/SDK, Xcode).
- Misconfigured Bazel module dependencies or external repositories.
- Platform-specific targets not building (e.g., Android-only or iOS-only rules).

**Likely Symptoms**

- `bazel build` fails with:
  - “toolchain resolution failed”
  - “no such package” / “no such target”
  - “repository not defined” errors for external deps.
- CI scripts in `tools/ci` failing at the “build core Bazel targets” step.

**Mitigations**

- Ensure required toolchains are installed and match versions expected by the repo:
  - Rust: `rustup show`, confirm toolchain in `rust-toolchain` or docs.
  - Android: SDK/NDK versions used by `src/platform-projects/android`.
  - iOS: Xcode version compatible with the Xcode build server config.
- Run Bazel with verbose output:
  - `bazel build //... --sandbox_debug --verbose_failures`
- Keep `MODULE.bazel` and `WORKSPACE` dependencies in sync; avoid mixing incompatible Bazel module versions.

---

### 1.2 Cargo / Rust Build Errors

**Context**

- Core logic is in `crates/*` (`omnitak-core`, `omnitak-cot`, `omnitak-client`, `omnitak-server`, `omnitak-mobile`, `omnitak-cert`).
- `crates/target/**` directories are build artifacts and not source.

**Common Failure Modes**

- Version conflicts between crates in the workspace.
- Feature mismatches or missing optional dependencies.
- Platform-specific compilation issues (e.g., `cdylib`/`staticlib` for mobile).

**Likely Symptoms**

- `cargo build` fails with:
  - “failed to select a version for the requirement”
  - “duplicate lang item” or conflicting features.
  - Linker errors when building `omnitak-mobile` for iOS/Android.

**Mitigations**

- Always build from the workspace root (if a workspace is defined) to ensure consistent dependency resolution:
  - `cargo build --workspace`
- For mobile:
  - Use provided scripts (`build_ios.sh` or similar) in `crates/omnitak-mobile` to ensure correct target triple and link flags.
- Do not edit or commit `crates/target/**`; if corrupted, remove `target/` and rebuild.

---

### 1.3 Node / TypeScript Tooling Errors

**Context**

- Node-based CLI and ESLint plugin under `npm_modules/*` (e.g., `eslint-plugin-valdi`).
- Used for linting and possibly project-specific tooling.

**Common Failure Modes**

- Missing Node version or mismatched Node/npm/yarn versions.
- ESLint plugin resolution errors in editors or CI.

**Likely Symptoms**

- `npm install` / `yarn install` fails due to engine constraints or missing native build tools.
- ESLint errors like:
  - “Failed to load plugin 'valdi'”
  - “Cannot find module 'eslint-plugin-valdi'”.

**Mitigations**

- Use the Node version specified in `.nvmrc` or documentation.
- Install dependencies from the repo root if package.json is centralized.
- Ensure `NODE_PATH` or ESLint config points correctly to the plugin.

---

### 1.4 Docker / zstd Tooling Errors

**Context**

- `tools/zstd` vendors `zstd` v1.4.5 via Docker-based build.
- Used for compression in tooling (e.g., assets, logs, artifacts).

**Common Failure Modes**

- Docker not installed or not running.
- Platform-specific binary missing or not executable.

**Likely Symptoms**

- Scripts in `tools/zstd` fail with:
  - “docker: command not found”
  - “permission denied” when running `zstdw`.
- Bazel rules that depend on `zstd` fail.

**Mitigations**

- Install and start Docker; ensure user is in the Docker group (Linux).
- Rebuild zstd binaries via provided script in `tools/zstd`.
- On macOS/Linux, ensure `tools/zstd/bin/{macos,linux}/zstd` is executable (`chmod +x`).

---

## 2. Runtime Errors in Rust Crates

### 2.1 `omnitak-core`

**Role**

- Core domain types and utilities (configuration, connection types, Meshtastic settings).

**Common Error Sources**

- Invalid or incomplete configuration structures.
- Misuse of core types (e.g., invalid enum variants, missing required fields).

**Likely Symptoms**

- Panics or `Result::Err` when constructing core types.
- Deserialization errors when loading configuration (e.g., from JSON/TOML).

**Mitigations**

- Validate configuration early:
  - Provide `validate()` methods on config structs where possible.
- Prefer `thiserror`/custom error enums over panics for invalid state.
- Add unit tests in `crates/omnitak-core/src` for configuration parsing and validation.

---

### 2.2 `omnitak-cot`

**Role**

- Cursor-on-Target (CoT) message structures and logic (`CotMessage` and related).

**Common Error Sources**

- Parsing malformed CoT XML/JSON.
- Time/UUID parsing errors.
- Incomplete or invalid CoT messages from external systems.

**Likely Symptoms**

- `Result::Err` on parse functions (e.g., `from_xml`, `from_json`).
- Serialization failures if required fields are missing.

**Mitigations**

- Treat all external CoT input as untrusted:
  - Use robust parsing with detailed error variants (e.g., `ParseError::MissingField`, `ParseError::InvalidTime`).
- Provide “best-effort” parsing where possible:
  - Return partial messages with warnings instead of failing hard.
- Log parse failures with enough context (source, truncated payload) but avoid logging sensitive data.

---

### 2.3 `omnitak-cert`

**Role**

- TLS certificates and enrollment over HTTP (using `rustls`, `reqwest`, `serde`, `base64`, `tokio`, `tracing`).

**Common Error Sources**

- Network failures during enrollment (DNS, timeouts, TLS handshake).
- Invalid or untrusted server certificates.
- Incorrect username/password or enrollment endpoint configuration.
- Parsing/encoding errors for keys and certificates.

**Likely Symptoms**

- Enrollment APIs returning errors like:
  - “TLS error”, “certificate verify failed”.
  - HTTP status errors (4xx/5xx).
  - “invalid PEM” or “failed to parse certificate”.

**Mitigations**

- Distinguish error categories:
  - Network (transient) vs. configuration (persistent) vs. server-side.
- Implement retries with backoff for transient network errors.
- Provide clear error messages for:
  - Invalid CA bundle.
  - Wrong enrollment URL.
  - Authentication failures (401/403).
- Avoid panics on malformed certs; return structured errors.

---

### 2.4 `omnitak-client`

**Role**

- Client-side networking logic to connect to TAK server (TCP/UDP, TLS), integrate Meshtastic, etc.

**Common Error Sources**

- Connection failures (unreachable host, wrong port, TLS mismatch).
- Protocol-level errors (unexpected messages, invalid CoT).
- Concurrency issues in async code (Tokio tasks, channels, cancellation).

**Likely Symptoms**

- Connection attempts timing out or failing repeatedly.
- Unexpected disconnects or dropped messages.
- Panics from unwrapped `Result`/`Option` in async tasks.

**Mitigations**

- Always propagate `Result` from network operations; avoid `unwrap()` and `expect()` in async tasks.
- Use structured error types (e.g., `ClientError::Connect`, `ClientError::Protocol`, `ClientError::Tls`).
- Implement reconnect logic with backoff and jitter.
- Add tracing spans for connection lifecycle (connect, authenticate, subscribe, disconnect).

---

### 2.5 `omnitak-server`

**Role**

- TAK server implementation: TCP CoT routing, multi-client broadcasting, TLS.

**Common Error Sources**

- TLS misconfiguration (wrong cert/key, CA mismatch).
- Resource exhaustion (too many clients, unbounded buffers).
- Broadcast logic errors (deadlocks, dropped clients not cleaned up).

**Likely Symptoms**

- Server fails to start:
  - “failed to bind address”
  - “failed to load certificate/key”
- Runtime panics under load or when clients disconnect unexpectedly.
- Clients connect but do not receive broadcasts.

**Mitigations**

- Validate TLS configuration on startup:
  - Check cert/key files exist and parse correctly.
- Use bounded channels and backpressure for broadcast queues.
- On client disconnect, ensure cleanup of:
  - Connection tasks.
  - Channels/subscriptions.
- Add integration tests in `crates/omnitak-server/examples` to simulate:
  - Multiple clients.
  - TLS and non-TLS connections.
  - Rapid connect/disconnect cycles.

---

## 3. Mobile FFI Errors (`omnitak-mobile`)

### 3.1 C FFI Boundary Issues

**Context**

- `crates/omnitak-mobile/include` exposes C headers (`omnitak_mobile.h`).
- `crates/omnitak-mobile/src` implements C-compatible APIs for iOS/Android.

**Common Error Sources**

- Mismatched type definitions between C header and Rust implementation.
- Incorrect ownership/lifetime handling of pointers across FFI boundary.
- ABI mismatches (calling convention, struct layout, alignment).

**Likely Symptoms**

- Crashes in mobile apps when calling into the Rust library.
- Memory corruption or use-after-free bugs.
- Linker errors about missing symbols or wrong signatures.

**Mitigations**

- Keep C header and Rust FFI definitions in strict sync:
  - Use `#[repr(C)]` on all FFI structs.
  - Avoid Rust-specific types at the boundary (use `uint32_t`, `int32_t`, `const char*`, etc.).
- Document ownership rules in the header:
  - Who allocates, who frees, and which function to call for deallocation.
- Use safe wrappers in Rust around unsafe FFI functions to centralize invariants.

---

### 3.2 Error Reporting Across FFI

**Common Error Sources**

- Returning only integer codes without context.
- Inconsistent error code mappings between Rust and C/Swift/Kotlin.
- Forgetting to set error outputs (e.g., `char** error_message`) on failure.

**Likely Symptoms**

- Mobile code sees generic “unknown error” for many distinct failure cases.
- Hard-to-debug failures because details are lost at the boundary.

**Mitigations**

- Define a stable error code enum in the C header (e.g., `OMNITAK_OK`, `OMNITAK_ERR_NETWORK`, `OMNITAK_ERR_TLS`, `OMNITAK_ERR_CONFIG`).
- Provide a function to translate codes to human-readable strings:
  - `const char* omnitak_error_to_string(int code);`
- When possible, expose a way to retrieve last error details (thread-local or handle-based).

---

### 3.3 Platform-Specific Build/Runtime Issues

**Context**

- iOS: staticlib integrated via Xcode.
- Android: `cdylib` integrated via JNI/NDK.

**Common Error Sources**

- Wrong architectures or missing slices (e.g., missing arm64).
- Incorrect minimum OS version or deployment target.
- JNI signature mismatches on Android.

**Likely Symptoms**

- iOS: Xcode linker errors (“file was built for archive which is not the architecture being linked”).
- Android: `UnsatisfiedLinkError` at runtime, or “No implementation found for …”.

**Mitigations**

- For iOS:
  - Build universal libraries or XCFrameworks with all required architectures.
  - Match deployment target with app’s deployment target.
- For Android:
  - Ensure `CMakeLists.txt`/Gradle config includes all ABIs you ship.
  - Keep JNI function names and signatures consistent with Java/Kotlin declarations.

---

## 4. Configuration & Environment Errors

### 4.1 TAK Server Connectivity

**Common Error Sources**

- Wrong host/port, protocol mismatch (TCP vs UDP, TLS vs plain).
- Firewall or NAT issues.
- Misaligned CoT configuration between client and server.

**Likely Symptoms**

- Client cannot connect or stays disconnected.
- CoT messages not visible on server or other clients.

**Mitigations**

- Provide clear configuration schemas and defaults in `omnitak-core`.
- Log connection attempts with host, port, and protocol (without leaking secrets).
- Offer diagnostic utilities (CLI or example binaries) to test connectivity.

---

### 4.2 Certificate & TLS Configuration

**Common Error Sources**

- Using test PKI from `crates/omnitak-server/certs` in production.
- Expired or revoked certificates.
- Client not trusting server CA.

**Likely Symptoms**

- TLS handshake failures.
- Clients forced to disable certificate verification to connect.

**Mitigations**

- Clearly label test certificates as non-production.
- Add checks/warnings when loading obviously test or self-signed certs in production builds.
- Provide documentation on generating and installing proper CA and client certs.

---

## 5. Code Quality & Robustness Issues

### 5.1 Error Handling Anti-Patterns

**Observed/Expected Risks**

- Use of `unwrap()` / `expect()` in non-test code, especially in:
  - Network paths.
  - FFI-facing functions.
  - Certificate parsing.

**Impact**

- Hard crashes instead of recoverable errors.
- Poor UX on mobile and server.

**Recommendations**

- Replace `unwrap()`/`expect()` with:
  - `?` and structured error types.
  - Graceful fallback or user-visible error messages.
- Add tests that simulate failure conditions and assert graceful behavior.

---

### 5.2 Logging & Observability Gaps

**Context**

- `tracing` is available in several crates.

**Common Issues**

- Missing spans around critical operations:
  - Enrollment.
  - Connection lifecycle.
  - CoT parsing and routing.
- Over-logging sensitive data (certs, credentials).

**Recommendations**

- Add `tracing::instrument` on key async functions.
- Use structured fields (e.g., `client_id`, `conn_id`, `cot_type`) instead of dumping raw payloads.
- Scrub or avoid logging secrets (passwords, private keys).

---

### 5.3 Test Coverage Gaps

**Context**

- Examples exist for `omnitak-server`.
- Some crates may lack comprehensive tests for error paths.

**Risks**

- Regressions in:
  - TLS configuration.
  - Enrollment flows.
  - FFI boundary behavior.

**Recommendations**

- Add integration tests:
  - Client ↔ server over TLS with test certs.
  - Enrollment against a mock TAK server.
- Add FFI tests (where possible) that:
  - Call into the Rust library from C harnesses.
  - Validate error codes and memory safety under invalid inputs.

---

## 6. Quick Triage Checklist

When you hit an error, check:

1. **Build vs Runtime**
   - Build: Bazel/Cargo/Gradle/Xcode logs.
   - Runtime: app/server logs, `tracing` output.

2. **Component**
   - Core types: `omnitak-core`.
   - CoT parsing: `omnitak-cot`.
   - Certificates/TLS: `omnitak-cert`.
   - Client networking: `omnitak-client`.
   - Server routing/TLS: `omnitak-server`.
   - Mobile integration: `omnitak-mobile` + platform projects.

3. **Environment**
   - Toolchain versions (Rust, Node, Bazel, Android SDK/NDK, Xcode).
   - Network reachability and TLS configuration.
   - Correct cert/key files and CA trust.

Use this mapping to narrow down where to look and which mitigations above to apply.
