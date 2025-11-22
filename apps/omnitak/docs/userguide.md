# OmniTAK Mobile – User Guide

This guide explains what OmniTAK Mobile is, what you can do with it, and how to get started as an end user (or power user) without needing to understand the full codebase.

---

## 1. What OmniTAK Mobile Is

OmniTAK Mobile is a cross‑platform TAK (Team Awareness Kit) client built around a Rust core. It focuses on:

- **Cursor‑on‑Target (CoT)** messaging: sending and receiving situational awareness events.
- **Secure connectivity** to TAK servers using TLS and client certificates.
- **Mobile integration**: a Rust library (`omnitak-mobile`) exposed via a C FFI interface so that native iOS/Android apps can use the same core logic.
- **Meshtastic integration**: support for Meshtastic radio‑based networks via the `omnitak-meshtastic` and `omnitak-core` crates.
- **Server component**: an optional Rust TAK server (`omnitak-server`) you can run yourself for testing or small deployments.

You will typically interact with OmniTAK Mobile in one of two ways:

1. As a **mobile app user** (through an iOS/Android app that embeds `omnitak-mobile`).
2. As a **self‑hoster/power user** running the Rust server and tools on your own machine.

---

## 2. Main Components (User‑Relevant)

You do not need to know every crate, but it helps to understand the high‑level pieces:

- **`omnitak-core`**  
  Core types and configuration shared across the system (e.g., Meshtastic connection settings, general config structs).

- **`omnitak-cot`**  
  CoT message types and logic (e.g., `CotMessage`), used to represent and parse CoT events.

- **`omnitak-client`**  
  Client‑side networking logic: connects to TAK servers (TCP/UDP, TLS), sends/receives CoT messages.

- **`omnitak-cert`**  
  Certificate and TLS utilities:
  - Builds TLS client configurations (via `rustls`).
  - Handles certificate enrollment from TAK servers over HTTP using username/password.

- **`omnitak-mobile`**  
  Mobile‑facing library:
  - Compiled as a static library for iOS and a dynamic library for Android.
  - Exposes a C interface (`include/omnitak_mobile.h`) for native apps.
  - Wraps client, CoT, and certificate logic into a simpler API for mobile apps.

- **`omnitak-server`**  
  A TAK server implementation:
  - Listens for CoT messages over TCP/TLS.
  - Routes/broadcasts messages between connected clients.
  - Ships with example TLS certificates for development.

---

## 3. Typical User Scenarios

### 3.1 Using a Mobile App Powered by OmniTAK

If you are using an iOS/Android app that embeds OmniTAK Mobile:

1. **Install the app** from your distribution source (App Store, internal MDM, or APK).
2. **Obtain server details** from your administrator:
   - Server hostname or IP.
   - Port number.
   - Whether TLS is required.
   - Any special protocol settings (e.g., Meshtastic gateway, UDP vs TCP).
3. **Obtain credentials/certificates**:
   - Username/password for certificate enrollment, or
   - Pre‑issued client certificate and key, or
   - Shared secret / token (depending on your environment).
4. **Configure the app**:
   - Enter server address and port.
   - Enable TLS if required.
   - Import or enroll your client certificate (see section 4).
5. **Start the connection**:
   - Connect to the TAK server.
   - Confirm you appear on the map or in the contact list.
   - Verify that you can send/receive CoT events (e.g., your location, markers, chat).

The app’s UI will differ depending on how your organization integrates OmniTAK, but under the hood it uses the same Rust core and FFI interface.

---

### 3.2 Running Your Own Test TAK Server

If you want a local server for testing:

1. **Install Rust** (if not already installed):  
   See <https://www.rust-lang.org/tools/install>.

2. **Build the server** (from the repo root):

   ```bash
   cd crates/omnitak-server
   cargo build --release
   ```

3. **Run a basic server** (example; exact binary name may vary):

   ```bash
   cargo run --release --example basic_server
   ```

   Or, if there is a main binary:

   ```bash
   cargo run --release
   ```

4. **TLS testing**:
   - The `crates/omnitak-server/certs` directory contains:
     - A local certificate authority (CA).
     - Server and client certificates/keys.
   - You can run a TLS‑enabled example (e.g., `tls_server`) and connect your client using the provided test certificates.

5. **Connect from your mobile app or another client** using:
   - Host: `127.0.0.1` or your machine’s IP.
   - Port: the port configured in the example.
   - TLS: enabled/disabled depending on the example.

> Note: The bundled certificates are for development only. Do not use them in production.

---

## 4. Certificates and Secure Connections

OmniTAK Mobile uses the `omnitak-cert` crate to manage TLS and certificate enrollment.

### 4.1 How Certificate Enrollment Typically Works

1. **You receive**:
   - TAK server enrollment URL (e.g., `https://tak.example.org/enroll`).
   - A username and password (or other credentials).

2. **The mobile app**:
   - Calls into the Rust `omnitak-cert` logic via `omnitak-mobile`.
   - Sends an enrollment request over HTTPS.
   - Receives a client certificate and key if the credentials are valid.

3. **The app stores**:
   - The client certificate and private key securely (e.g., Keychain/Keystore).
   - The CA certificate or trust anchor for the TAK server.

4. **Subsequent connections**:
   - Use mutual TLS (mTLS) with your client certificate.
   - The server can authenticate and authorize you based on that certificate.

From your perspective as a user, this usually appears as:

- A **“Enroll certificate”** or **“Request certificate”** button.
- A prompt for **server URL**, **username**, and **password**.
- A success/failure message and possibly certificate details.

---

## 5. CoT Messages and What You See in the App

The `omnitak-cot` crate defines CoT message structures (e.g., `CotMessage`), which correspond to the events you see in TAK‑style apps:

- **Your own position**: periodic CoT events with your GPS location.
- **Other team members**: positions, status, or roles.
- **Markers / points of interest**: manually created or received from others.
- **Alerts / tasks**: special CoT types indicating tasks, warnings, or other operational data.

As a user, you typically:

- See these events visualized on a **map** or **list**.
- Can **create or edit** certain CoT events (e.g., drop a marker, send a quick message).
- Rely on the app to:
  - Serialize your actions into CoT messages.
  - Send them via `omnitak-client` to the server.
  - Receive and decode incoming CoT messages.

---

## 6. Meshtastic and Other Transport Options

The core library (`omnitak-core`, `omnitak-client`) includes support for Meshtastic and other transport types.

What this means for you:

- Your app may offer **Meshtastic connectivity**:
  - Connect to a Meshtastic device (e.g., via Bluetooth or serial).
  - Use it as a gateway to send/receive CoT messages over radio instead of (or in addition to) IP networks.
- You might see configuration options like:
  - **Meshtastic device address/port**.
  - **Channel or frequency settings**.
  - **Gateway mode** (bridge between Meshtastic and TAK server).

The exact UI depends on your app, but the underlying logic is provided by the shared Rust crates.

---

## 7. Platform Notes

### 7.1 iOS

- The Rust library `omnitak-mobile` is compiled as a **static library** (`staticlib`).
- A C header (`crates/omnitak-mobile/include/omnitak_mobile.h`) defines the functions the iOS app can call.
- As an end user:
  - You install a standard iOS app.
  - All Rust logic is bundled inside; you do not interact with Rust directly.

### 7.2 Android

- `omnitak-mobile` is compiled as a **dynamic library** (`cdylib`) for Android.
- The Android app uses JNI or a similar mechanism to call into the Rust library.
- As an end user:
  - You install an APK or Play Store app.
  - All Rust logic is embedded; you just use the app normally.

---

## 8. Getting Help and Troubleshooting

If your app or deployment provides documentation, follow that first. In general:

### 8.1 Connection Issues

- **Cannot connect to server**:
  - Verify hostname/IP and port.
  - Check whether TLS is required and that you have the correct setting.
  - Ensure your device has network connectivity and can reach the server.

- **Certificate errors**:
  - Confirm that your certificate is still valid (not expired or revoked).
  - Re‑enroll your certificate if your credentials have changed.
  - Make sure the server’s CA certificate is trusted by your app.

### 8.2 CoT/Map Issues

- **You don’t see yourself on the map**:
  - Ensure location permissions are granted to the app.
  - Confirm that the app is configured to send position updates.
  - Check that you are connected to the server or Meshtastic gateway.

- **You don’t see other users**:
  - Verify that they are connected to the same server/network.
  - Confirm that filters or layers in the app are not hiding their icons.

### 8.3 Local Server Testing

- If using the bundled `omnitak-server` examples:
  - Use the provided certificates only for local testing.
  - Check the server logs for connection attempts and errors.
  - Ensure firewall rules allow the chosen port.

---

## 9. What You Don’t Need to Worry About

The repository contains many build artifacts and internal tools you can safely ignore as an end user:

- `crates/target/**`: Rust build outputs and incremental compilation caches.
- `tools/zstd/**`: internal compression tooling.
- `tools/ci/**`: CI scripts for automated builds and tests.
- Bazel configuration (`BUILD.bazel`, `WORKSPACE`, `MODULE.bazel`): used by developers and CI.

These are important for developers and maintainers but not for day‑to‑day usage.

---

## 10. Summary

- **OmniTAK Mobile** is a cross‑platform TAK client stack built in Rust, with:
  - A secure, certificate‑based client.
  - A mobile‑friendly FFI layer for iOS and Android.
  - Optional server and Meshtastic integration.
- As a user, your main tasks are:
  - Configure server connection and TLS.
  - Enroll or import your client certificate.
  - Use the app to send and receive CoT‑based situational awareness data.

For app‑specific instructions (screens, buttons, exact flows), refer to the documentation or help provided with your particular iOS/Android application that embeds OmniTAK Mobile.
