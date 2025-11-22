# Troubleshooting Guide

## Table of Contents

- [Connection Issues](#connection-issues)
- [Certificate Problems](#certificate-problems)
- [GPS and Location Issues](#gps-and-location-issues)
- [Map Display Problems](#map-display-problems)
- [Chat and Messaging Issues](#chat-and-messaging-issues)
- [Performance Issues](#performance-issues)
- [Crash and Stability](#crash-and-stability)
- [Bluetooth and Meshtastic](#bluetooth-and-meshtastic)
- [Data Package Issues](#data-package-issues)
- [App Store and Installation](#app-store-and-installation)

---

## Connection Issues

### Cannot Connect to TAK Server

**Symptoms:**

- "Disconnected" status in top bar
- No position updates from other users
- Messages not sending

#### Check 1: Network Connectivity

```
✓ Verify WiFi or cellular is enabled
✓ Test internet: Open Safari and load a website
✓ Check firewall/VPN settings
```

**Solution:** Enable network access in Settings > Cellular > OmniTAK Mobile

#### Check 2: Server Address

```
✓ Verify hostname/IP is correct
✓ Verify port number (usually 8089 for TLS, 8087 for TCP)
✓ Try pinging server from another device
```

**Common errors:**

- `tak.example.com` (needs `.com` or correct TLD)
- `192.168.1.100:8089` (port should be in separate field)
- Local IP when on different network

#### Check 3: Protocol Mismatch

**Error:** "Connection failed" or "SSL handshake failed"

**Cause:** Wrong protocol selected (TCP vs TLS)

**Solution:**

1. Settings > Servers > Edit server
2. If server uses TLS, select "TLS" protocol
3. If plain TCP, select "TCP"
4. Save and reconnect

#### Check 4: Firewall Blocking

**Symptoms:** Connection times out after 30 seconds

**Solution:**

- Ask server admin to whitelist your IP
- Check if server port is open: `telnet tak.example.com 8089`
- Try different network (cellular vs WiFi)

### Connection Drops Frequently

**Symptoms:**

- Connects but disconnects after few minutes
- Intermittent "Reconnecting..." status

#### Cause 1: Mobile Network Switching

**Solution:**

1. Settings > Network Preferences
2. Enable "Aggressive Reconnect"
3. Set reconnect interval to 10 seconds

#### Cause 2: Server Timeout

**Solution:**

1. Increase position broadcast frequency (keeps connection alive)
2. Settings > Position Broadcast > Interval: 30 seconds

#### Cause 3: Certificate Expiry

**Check certificate:**

1. Settings > Certificates
2. Look for warning icon 📛 next to certificate
3. If expired, import new certificate

### "SSL Handshake Failed"

**Error:** `TLS/SSL negotiation failed`

#### Solution 1: Legacy TLS

Some older TAK servers use TLS 1.0/1.1:

1. Settings > Servers > Edit server
2. Enable "Allow Legacy TLS" ⚠️
3. Save and reconnect

**⚠️ Warning:** This reduces security. Ask admin to upgrade server.

#### Solution 2: Wrong Certificate

1. Verify certificate matches server
2. Re-import correct .p12 file
3. Check certificate name in Settings > Certificates
4. Select correct certificate for server

#### Solution 3: Self-Signed CA

If server uses self-signed certificate:

1. Server should provide both .p12 (client cert) and CA cert
2. Ensure .p12 includes full certificate chain
3. Try re-exporting from server with full chain

---

## Certificate Problems

### Cannot Import Certificate

**Error:** "Invalid certificate" or "Wrong password"

#### Check 1: File Format

**Supported formats:**

- ✅ .p12 (PKCS#12)
- ✅ .pfx (same as .p12)
- ❌ .pem (not directly supported)
- ❌ .crt/.cer (not directly supported)

**Convert PEM to P12:**

```bash
openssl pkcs12 -export \
  -in client.pem \
  -inkey client.key \
  -out client.p12 \
  -name "My Certificate"
```

#### Check 2: Password

**Common issues:**

- Extra spaces when typing
- Caps Lock enabled
- Wrong password provided

**Solution:**

- Copy/paste password from secure source
- Contact admin for correct password
- Try empty password (some certs have no password)

#### Check 3: File Corruption

**Test certificate:**

```bash
# On Mac/Linux:
openssl pkcs12 -info -in certificate.p12 -noout
# Enter password when prompted
# Should output certificate details
```

### Certificate Expired

**Warning:** 📛 "Certificate expires soon" or "Certificate expired"

**Impact:**

- May not be able to connect to server
- TLS handshake may fail

**Solution:**

1. Contact TAK server administrator
2. Request new certificate
3. Import new certificate
4. Select new certificate in server settings
5. Reconnect

### Certificate Not in Keychain

**Error:** "Certificate not found in Keychain"

**This happens after:**

- iOS update
- App reinstall
- iCloud Keychain sync issues

**Solution:**

1. Re-import certificate from original .p12 file
2. Or scan QR code again for re-enrollment

---

## GPS and Location Issues

### "No GPS Signal"

**Symptoms:**

- Your position not showing on map
- Blue puck missing
- "GPS: 0/0" in status bar

#### Solution 1: Location Permissions

1. iOS Settings > Privacy & Security > Location Services
2. Ensure Location Services enabled (top toggle)
3. Scroll to OmniTAK Mobile
4. Select "Always" or "While Using the App"

**Recommendation:** Use "Always" for background position tracking

#### Solution 2: Improve GPS Accuracy

```
✓ Move outdoors (GPS doesn't work well indoors)
✓ Clear view of sky (buildings/trees block signals)
✓ Wait 30-60 seconds for GPS lock
✓ Enable WiFi (assists GPS on iOS)
```

#### Solution 3: Reset Location Services

```bash
# Last resort:
iOS Settings > General > Transfer or Reset iPhone > Reset > Reset Location & Privacy
# This resets all app location permissions
```

### Position Not Updating

**Symptoms:**

- Blue puck on map but doesn't move
- Stale coordinate in status bar
- Other users' positions update but not yours

#### Cause: Background Restrictions

**Solution:**

1. iOS Settings > OmniTAK Mobile
2. Background App Refresh: Enable
3. Location: "Always"

#### Cause: Low Power Mode

**Solution:**

- Disable Low Power Mode (Settings > Battery)
- Or keep app in foreground when in Low Power Mode

### Inaccurate Position

**Symptoms:**

- Position jumps around
- Shows wrong location
- GPS accuracy > 50 meters

#### Solutions:

1. **Calibrate compass:**
   - Open Maps app
   - Follow calibration prompt (figure-8 motion)

2. **Check GPS mode:**
   - Settings > Location Preferences
   - GPS Mode: High Accuracy

3. **Environment factors:**
   - Move to open area
   - Away from metal buildings
   - Clear weather (heavy cloud cover affects GPS)

---

## Map Display Problems

### Map Tiles Not Loading

**Symptoms:**

- Gray squares instead of map
- "Loading..." tiles that never load
- Partial map display

#### Solution 1: Network Connection

```
✓ Check internet connectivity
✓ Try switching WiFi/cellular
✓ Test other apps using maps
```

#### Solution 2: Tile Source

1. Tap Layers ☰
2. Select different base map:
   - Try "Satellite" if "Standard" fails
   - Try "OpenStreetMap" if ArcGIS fails
3. Some tile sources have rate limits

#### Solution 3: Clear Tile Cache

1. Settings > Advanced > Clear Map Cache
2. Confirm deletion
3. Reload map

**Note:** This deletes offline tiles too. Re-download if needed.

### Markers Not Appearing

**Symptoms:**

- Connected but no team markers visible
- Only your position shows

#### Check 1: CoT Filter

1. Tap Tools > Filters
2. Ensure "Enable Filters" is OFF
3. Or check filter criteria not too restrictive

#### Check 2: Map Zoom

- Some markers only visible at certain zoom levels
- Zoom in closer
- Increase "Maximum Zoom" in Settings

#### Check 3: Marker Stale Time

- Markers disappear after "stale" time
- Other users may be offline
- Check TAK server web interface to verify users

### MGRS Grid Not Showing

**Solution:**

1. Tap Layers ☰
2. Enable "MGRS Grid"
3. Zoom in (grid only shows at zoom level 10+)
4. Adjust grid opacity in Settings > Map

### Map Performance Issues

**Symptoms:**

- Lag when panning/zooming
- Choppy animations
- App feels sluggish

#### Solutions:

1. **Reduce active markers:**
   - Use CoT filters to limit displayed markers
   - Settings > Markers > Max Markers: 100

2. **Disable trails:**
   - Tap Layers ☰ > Disable "Breadcrumb Trails"
   - Or Settings > Trails > Trail Length: Short

3. **Simplify overlays:**
   - Disable MGRS grid
   - Hide drawings when not needed
   - Remove unused tile overlays

4. **Close other apps:**
   - Free up device memory
   - Restart device if very slow

---

## Chat and Messaging Issues

### Messages Not Sending

**Symptoms:**

- Message stuck with "Sending..." status
- Messages in pending state
- No delivery confirmation

#### Solution 1: Connection Status

```
✓ Verify "Connected" in status bar
✓ Check TX counter incrementing
✓ Try sending position update (automatic)
```

#### Solution 2: Recipient UID

- Ensure recipient UID is correct
- For group chat, use "All Chat Users"
- Verify recipient is online (recent position update)

#### Solution 3: Message Queue

**If many pending messages:**

1. Wait for connection to stabilize
2. Messages will send automatically when connected
3. Or delete pending messages and resend

### Messages Not Receiving

**Symptoms:**

- Can send but not receive messages
- No notifications from chat
- Conversation appears one-sided

#### Solution 1: Notification Permissions

1. iOS Settings > Notifications > OmniTAK Mobile
2. Allow Notifications: Enable
3. Banner Style: Persistent or Temporary
4. Sounds: Enable

#### Solution 2: Chat Participant List

- Participants must have recent position update
- Ensure their UID matches exactly
- Case-sensitive matching

### Photo Attachments Failing

**Symptoms:**

- "Failed to attach photo"
- Photo shows but doesn't send
- Recipient sees placeholder

#### Solution 1: Photo Size

**Large photos may fail:**

1. Settings > Chat > Photo Quality: Medium
2. Or use Photos app to resize before sharing

#### Solution 2: Photo Permissions

1. iOS Settings > Privacy > Photos > OmniTAK Mobile
2. Select "All Photos" or "Selected Photos"

#### Solution 3: Network Speed

- Large photos require good connection
- Wait for WiFi if on slow cellular
- Consider sending via data package for large files

---

## Performance Issues

### App Running Slow

**Common causes:**

- Too many markers on map
- Large message history
- Memory leaks
- Background tasks

#### Solutions:

1. **Restart app:**
   - Swipe up to close
   - Reopen app

2. **Reduce marker count:**
   - Settings > Markers > Max Markers: 50
   - Enable CoT filters

3. **Clear chat history:**
   - Settings > Chat > Clear All Conversations
   - This deletes local messages only

4. **Free up device storage:**
   - iOS Settings > General > iPhone Storage
   - Delete unused apps
   - Offload large files

### High Battery Drain

**Expected behavior:**

- Location services use significant battery
- Continuous network connection drains battery
- Real-time position updates require power

#### Mitigation:

1. **Reduce update frequency:**
   - Settings > Position Broadcast > Interval: 60 seconds
   - (Default: 30 seconds)

2. **Disable when not needed:**
   - Turn off position broadcast when stationary
   - Disconnect from server when not in use

3. **Use Low Power Mode:**
   - iOS Settings > Battery > Low Power Mode
   - App works but with reduced background activity

4. **External battery:**
   - Carry power bank for extended operations

### App Using Too Much Data

**Check data usage:**

- iOS Settings > Cellular > OmniTAK Mobile

#### Reduce data usage:

1. **Limit position updates:**
   - Settings > Position Broadcast > Interval: Increase

2. **Disable auto-downloads:**
   - Settings > Data Packages > Auto-Download: Off

3. **Use WiFi for offline maps:**
   - Download maps on WiFi only
   - Settings > Offline Maps > Use Cellular: Off

4. **Compress photos:**
   - Settings > Chat > Photo Quality: Low

---

## Crash and Stability

### App Crashes on Launch

**Common causes:**

- Corrupted settings
- Bad certificate data
- iOS update incompatibility

#### Solution 1: Reset Settings

**Warning:** This deletes all app data

1. Delete app
2. Reinstall from TestFlight/App Store
3. Set up fresh configuration

#### Solution 2: Update iOS

1. iOS Settings > General > Software Update
2. Install latest iOS version
3. Restart device

#### Solution 3: Report Crash

1. iOS Settings > Privacy > Analytics & Improvements > Analytics Data
2. Find crash logs starting with "OmniTAKMobile"
3. Share with developer via GitHub Issues

### App Freezes

**Symptoms:**

- UI unresponsive
- Can't tap buttons
- Map doesn't pan

#### Force quit:

1. **iPhone with Face ID:** Swipe up and hold
2. **iPhone with Home button:** Double-click Home
3. Swipe up on OmniTAK preview
4. Reopen app

### Repeated Crashes

**If app crashes repeatedly:**

1. **Check iOS version:**
   - Requires iOS 15.0+
   - Update if older

2. **Free up storage:**
   - Need at least 500MB free
   - Delete old downloads/photos

3. **Check device compatibility:**
   - Minimum: iPhone 7, iOS 15.0
   - Older devices may struggle

---

## Bluetooth and Meshtastic

### Cannot Find Meshtastic Device

**Symptoms:**

- Device list empty
- "Scanning..." never completes
- Known device not appearing

#### Solution 1: Bluetooth Permissions

1. iOS Settings > Privacy > Bluetooth > OmniTAK Mobile
2. Enable Bluetooth access

#### Solution 2: Bluetooth Enabled

1. Ensure Bluetooth enabled in Control Center
2. Or Settings > Bluetooth > On

#### Solution 3: Device Pairing

Some Meshtastic devices need iOS pairing:

1. iOS Settings > Bluetooth
2. Wait for device to appear
3. Tap to pair
4. Return to OmniTAK > Meshtastic

#### Solution 4: Device Powered On

- Verify Meshtastic device is on
- Check battery level
- Device LED should be blinking
- Try power cycling device

### Meshtastic Connection Drops

**Solutions:**

1. **Stay in range:**
   - Bluetooth range: ~10 meters
   - Keep device close

2. **Reduce interference:**
   - Move away from WiFi routers
   - Away from microwave ovens
   - Minimize obstacles

3. **Device firmware:**
   - Update Meshtastic device firmware
   - Check compatibility with iOS

---

## Data Package Issues

### Cannot Import KML File

**Error:** "Invalid KML" or "Parse failed"

#### Solution 1: Validate KML

```xml
<!-- KML must have proper structure: -->
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <!-- Content here -->
  </Document>
</kml>
```

**Test with:**

- Google Earth (should open without errors)
- KML validator online

#### Solution 2: File Size

- Large KML files may timeout
- Split into smaller files
- Or import via TAK server

#### Solution 3: Compressed KMZ

- Try extracting .kmz to .kml
- Import .kml directly

### Data Package Not Syncing

**Symptoms:**

- Package imported locally but not on server
- Server packages not downloading

#### Solutions:

1. **Check connection:**
   - Must be connected to TAK server
   - Packages sync automatically when connected

2. **Manual sync:**
   - Settings > Data Packages > Sync Now

3. **Storage limit:**
   - Check device storage
   - Delete old packages

---

## App Store and Installation

### Cannot Install from TestFlight

**Error:** "Unable to Install"

#### Solutions:

1. **TestFlight full:**
   - Max 10,000 testers
   - Contact developer for new build

2. **iOS version:**
   - Requires iOS 15.0+
   - Update iOS if older

3. **Region restriction:**
   - App may not be available in your region
   - Contact developer

### Update Available But Won't Install

**Solution:**

1. Delete existing app
2. Restart device
3. Reinstall latest version

### App Size Too Large

**OmniTAK app size:**

- Download: ~50MB
- Installed: ~100MB
- With offline maps: Variable (500MB+ possible)

**Free up space:**

- Delete unused apps
- Offload apps (Settings > General > iPhone Storage)
- Delete offline maps in OmniTAK if not needed

---

## Getting More Help

### Collect Diagnostic Information

Before contacting support, gather:

1. **App version:**
   - Settings > About > Version

2. **iOS version:**
   - iOS Settings > General > About > iOS Version

3. **Device model:**
   - iOS Settings > General > About > Model Name

4. **Connection details:**
   - Server hostname (if applicable)
   - Connection protocol (TCP/TLS)
   - Error messages (take screenshots)

5. **Reproduction steps:**
   - Exact steps that cause the issue
   - Frequency (always, sometimes, once)

### Report an Issue

**GitHub Issues:**
https://github.com/tyroe1998/omniTAKmobile/issues

**Include:**

- Diagnostic information (above)
- Screenshots
- Crash logs (if available)
- Expected vs actual behavior

### Community Support

- **GitHub Discussions:** Q&A and feature requests
- **Documentation:** Check docs/ folder
- **Stack Overflow:** Tag `omnitak-mobile`

---

## Troubleshooting Checklist

Before reporting an issue, try these steps:

- [ ] Restart the app
- [ ] Check internet connection
- [ ] Verify server settings
- [ ] Check certificate expiry
- [ ] Update iOS to latest version
- [ ] Restart device
- [ ] Delete and reinstall app (last resort)
- [ ] Review relevant section above

---

_Last Updated: November 22, 2025_
