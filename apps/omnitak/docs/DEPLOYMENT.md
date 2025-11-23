# Deployment Guide

**Building and Deploying OmniTAK Mobile**

This guide covers building the app from source, creating distributions, and deploying to TestFlight and the App Store.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Building from Source](#building-from-source)
3. [Build Configuration](#build-configuration)
4. [Version Management](#version-management)
5. [Code Signing & Certificates](#code-signing--certificates)
6. [Creating Archives](#creating-archives)
7. [TestFlight Distribution](#testflight-distribution)
8. [App Store Submission](#app-store-submission)
9. [Enterprise Distribution](#enterprise-distribution)
10. [Continuous Integration](#continuous-integration)
11. [Troubleshooting Build Issues](#troubleshooting-build-issues)

---

## Prerequisites

### Required Software

| Software               | Version          | Purpose             |
| ---------------------- | ---------------- | ------------------- |
| **macOS**              | 12.0+ (Monterey) | Development OS      |
| **Xcode**              | 14.0+            | IDE and build tools |
| **Command Line Tools** | Latest           | Build utilities     |
| **Git**                | 2.x              | Version control     |

**Install Xcode:**

```bash
# From Mac App Store
open "macappstores://apps.apple.com/app/xcode/id497799835"

# Or download from developer.apple.com
```

**Install Command Line Tools:**

```bash
xcode-select --install
```

**Verify Installation:**

```bash
xcode-select -p
# Should output: /Applications/Xcode.app/Contents/Developer

xcodebuild -version
# Should output: Xcode 14.x
```

### Apple Developer Account

**Required for:**

- Testing on physical devices
- Creating distribution certificates
- Submitting to TestFlight
- Publishing to App Store

**Account Types:**

- **Individual/Organization** ($99/year) - Full access
- **Enterprise** ($299/year) - Internal distribution only
- **Free** - Limited (7-day app validity, no TestFlight/App Store)

**Enroll at:** https://developer.apple.com/programs/

---

## Building from Source

### Clone Repository

```bash
# Clone from GitHub
git clone https://github.com/tyroe1998/omniTAKmobile.git
cd omniTAKmobile/apps/omnitak
```

### Initial Setup

**1. Run Setup Script**

```bash
chmod +x setup_xcode.sh
./setup_xcode.sh
```

This script:

- Creates necessary directory structure
- Configures file references in Xcode project
- Sets up build phases
- Configures framework embedding

**2. Open Project**

```bash
open OmniTAKMobile.xcodeproj
```

**3. Select Development Team**

- Click project navigator (OmniTAKMobile)
- Select "OmniTAKMobile" target
- Go to "Signing & Capabilities" tab
- Select your Team from dropdown
- Xcode will automatically create/manage provisioning profiles

### Build for Simulator

**Command Line:**

```bash
xcodebuild -project OmniTAKMobile.xcodeproj \
  -scheme OmniTAKMobile \
  -sdk iphonesimulator \
  -configuration Debug \
  build
```

**Xcode IDE:**

1. Select target: iPhone 15 Pro (simulator)
2. Product → Build (Cmd + B)
3. Product → Run (Cmd + R) to launch

### Build for Device

**Command Line:**

```bash
xcodebuild -project OmniTAKMobile.xcodeproj \
  -scheme OmniTAKMobile \
  -sdk iphoneos \
  -configuration Release \
  build
```

**Xcode IDE:**

1. Connect iOS device via USB
2. Trust device (Settings → General → Device Management)
3. Select device in Xcode target dropdown
4. Product → Build (Cmd + B)
5. Product → Run (Cmd + R) to install and launch

---

## Build Configuration

### Configurations

The project includes three build configurations:

| Configuration           | Use Case     | Optimizations | Debug Info |
| ----------------------- | ------------ | ------------- | ---------- |
| **Debug**               | Development  | Minimal       | Full       |
| **Release**             | Distribution | Full          | Minimal    |
| **Release-Development** | Beta testing | Full          | Some       |

**Selecting Configuration:**

```bash
# In Xcode
Product → Scheme → Edit Scheme → Run → Build Configuration → [Select]

# Command line
xcodebuild -configuration Debug ...
xcodebuild -configuration Release ...
```

### Build Settings

**Key Settings:**

| Setting                | Value                            | Location                        |
| ---------------------- | -------------------------------- | ------------------------------- |
| **Product Name**       | `OmniTAKMobile`                  | General → Identity              |
| **Bundle Identifier**  | `com.engindearing.omnitak.test`  | General → Identity              |
| **Deployment Target**  | `iOS 15.0`                       | General → Deployment Info       |
| **Swift Version**      | `5.0`                            | Build Settings → Swift Compiler |
| **Optimization Level** | `-O` (Release), `-Onone` (Debug) | Build Settings → Swift Compiler |

**Architectures:**

- **iOS Device:** arm64 (64-bit ARM)
- **iOS Simulator:** x86_64 (Intel), arm64 (Apple Silicon)

**Customizing Bundle Identifier:**

```bash
# In Xcode
Select Project → Select Target → General → Bundle Identifier

# Or edit Info.plist
<key>CFBundleIdentifier</key>
<string>com.yourcompany.omnitak</string>
```

### Capabilities & Entitlements

**Required Capabilities:**

- Background Modes
  - ✅ Location updates
  - ✅ Remote notifications
- Push Notifications
- Networking (Multipath TCP)

**Entitlements File:** `OmniTAKMobile/OmniTAKMobile.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>

    <key>com.apple.developer.avfoundation.multitasking-camera-access</key>
    <true/>

    <key>com.apple.developer.kernel.increased-memory-limit</key>
    <true/>

    <key>com.apple.developer.low-latency-streaming</key>
    <true/>

    <key>com.apple.developer.networking.multipath</key>
    <true/>

    <key>com.apple.developer.sustained-execution</key>
    <true/>

    <key>com.apple.developer.usernotifications.communication</key>
    <true/>
</dict>
</plist>
```

**Adding Capabilities:**

1. Select Target
2. Signing & Capabilities tab
3. Click "+ Capability"
4. Select capability from list

---

## Version Management

### Version Numbering Scheme

**Format:** `MAJOR.MINOR.PATCH (BUILD)`

**Example:** `1.2.3 (45)`

- **1** = Major version (breaking changes)
- **2** = Minor version (new features)
- **3** = Patch version (bug fixes)
- **(45)** = Build number (auto-incremented)

### Update Scripts

**update_build.sh** - Primary version management script

**Usage:**

```bash
# Auto-increment build number only
./update_build.sh
# Result: 1.2.0 (34) → 1.2.0 (35)

# Set version, auto-increment build
./update_build.sh 1.3.0
# Result: 1.2.0 (34) → 1.3.0 (35)

# Set both version and build
./update_build.sh 1.3.0 50
# Result: 1.2.0 (34) → 1.3.0 (50)
```

**Script Content:**

```bash
#!/bin/bash
set -e

# Project file
PLIST="OmniTAKMobile/Info.plist"

# Get current values
CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST")
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST")

# Parse arguments
NEW_VERSION=${1:-$CURRENT_VERSION}
NEW_BUILD=${2:-$((CURRENT_BUILD + 1))}

# Update plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST"

echo "✅ Updated version: $NEW_VERSION ($NEW_BUILD)"
```

**update_version.sh** - Alternative version updater

```bash
./update_version.sh 1.3.0 50
```

### Manual Version Update

**In Xcode:**

1. Select project in navigator
2. Select target
3. General tab → Identity section
4. **Version**: Marketing version (e.g., "1.2.0")
5. **Build**: Build number (e.g., "34")

**In Info.plist:**

```xml
<key>CFBundleShortVersionString</key>
<string>1.2.0</string>
<key>CFBundleVersion</key>
<string>34</string>
```

### Version Conventions

**When to increment:**

| Change Type                | Version  | Build |
| -------------------------- | -------- | ----- |
| Major architectural change | ✅ Major | ✅    |
| Breaking API change        | ✅ Major | ✅    |
| New feature                | ✅ Minor | ✅    |
| Bug fix                    | ✅ Patch | ✅    |
| Documentation only         | ❌       | ✅    |
| Internal refactoring       | ❌       | ✅    |

---

## Code Signing & Certificates

### Certificate Types

**Development Certificate:**

- Used for testing on devices
- Valid for 1 year
- Can be shared among team members

**Distribution Certificate:**

- Used for App Store and TestFlight
- Valid for 1 year
- Should be securely stored

### Automatic Signing (Recommended)

**Enable in Xcode:**

1. Select target → Signing & Capabilities
2. Check "Automatically manage signing"
3. Select Team from dropdown
4. Xcode handles certificates and provisioning profiles

**Advantages:**

- ✅ Simplest approach
- ✅ Xcode manages profiles automatically
- ✅ Works for most cases

### Manual Signing (Advanced)

**When to use:**

- Multiple teams
- Specific provisioning profile requirements
- Enterprise distribution
- CI/CD environments

**Steps:**

1. Create certificates in Apple Developer portal
2. Download and install certificates
3. Create provisioning profiles
4. Download profiles to `~/Library/MobileDevice/Provisioning Profiles/`
5. In Xcode, uncheck "Automatically manage signing"
6. Select specific profiles for Debug/Release

**Export Certificates:**

```bash
# Open Keychain Access
# Select certificate → File → Export Items
# Save as .p12 file with password
```

**Import on Another Mac:**

```bash
# Double-click .p12 file
# Enter password
# Certificate added to Keychain
```

---

## Creating Archives

### Archive for Distribution

**In Xcode:**

1. **Select Device Target**
   - Product → Destination → Any iOS Device (arm64)

2. **Select Release Configuration**
   - Product → Scheme → Edit Scheme
   - Run → Build Configuration → Release

3. **Create Archive**
   - Product → Archive (or Cmd + Shift + B)
   - Wait for build to complete
   - Organizer window opens automatically

**Command Line:**

```bash
xcodebuild archive \
  -project OmniTAKMobile.xcodeproj \
  -scheme OmniTAKMobile \
  -configuration Release \
  -archivePath build/OmniTAKMobile.xcarchive
```

### Archive Contents

```
OmniTAKMobile.xcarchive/
├── Info.plist                  # Archive metadata
├── Products/
│   └── Applications/
│       └── OmniTAKMobile.app  # Compiled app
├── dSYMs/                      # Debug symbols for crash analysis
│   └── OmniTAKMobile.app.dSYM
└── SCMBlueprint.plist          # Git commit info
```

### Export Options

**ExportOptions-Development.plist:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>

    <key>signingStyle</key>
    <string>automatic</string>

    <key>compileBitcode</key>
    <false/>

    <key>provisioningProfiles</key>
    <dict>
        <key>com.engindearing.omnitak.test</key>
        <string>OmniTAK Development</string>
    </dict>
</dict>
</plist>
```

**Export Methods:**

- **development** - Ad-hoc distribution to registered devices
- **app-store** - App Store submission
- **ad-hoc** - Limited devices without App Store
- **enterprise** - Enterprise internal distribution

---

## TestFlight Distribution

### Overview

TestFlight allows beta testing with up to 10,000 external testers before App Store release.

### Prerequisites

- ✅ Apple Developer Program membership ($99/year)
- ✅ App Store Connect account
- ✅ App created in App Store Connect
- ✅ Valid distribution certificate

### Upload to TestFlight

**Method 1: Xcode Organizer**

1. **Archive the app** (Product → Archive)

2. **Open Organizer**
   - Window → Organizer (or Cmd + Shift + Option + O)
   - Select archive from list

3. **Distribute App**
   - Click "Distribute App" button
   - Select "App Store Connect"
   - Click "Upload"

4. **Select Options**
   - ☑ Include bitcode: NO (deprecated)
   - ☑ Upload symbols: YES (for crash reports)
   - Click "Next"

5. **Automatic Signing**
   - Click "Automatically manage signing"
   - Click "Upload"

6. **Wait for Processing**
   - Upload completes (few minutes)
   - Processing takes 10-60 minutes
   - Email notification when ready

**Method 2: Command Line (fastlane)**

```bash
# Install fastlane
gem install fastlane

# Initialize fastlane
fastlane init

# Edit Fastfile
lane :beta do
  build_app(scheme: "OmniTAKMobile")
  upload_to_testflight
end

# Run
fastlane beta
```

**Method 3: Transporter App**

```bash
# Export .ipa from Xcode Organizer
# Open Transporter.app
# Drag .ipa file to Transporter
# Click "Deliver"
```

### Configure TestFlight

**In App Store Connect:**

1. Navigate to **My Apps** → **OmniTAK Mobile** → **TestFlight**

2. **Internal Testing:**
   - Add internal testers (up to 100)
   - Internal testers = App Store Connect users
   - No review required
   - Instant access

3. **External Testing:**
   - Create test groups
   - Add external testers by email
   - Requires Apple review (1-2 days first time)
   - Up to 10,000 testers

4. **Test Information:**
   - Beta App Description
   - What to Test (instructions for testers)
   - Feedback Email
   - Privacy Policy URL (if collecting data)

5. **Submit for Review** (external testing only)
   - Click "Submit for Review"
   - Wait for approval (~24-48 hours)

### Invite Testers

**Internal Testers:**

- Automatically have access
- Receive email invitation
- Install TestFlight app
- Redeem invitation

**External Testers:**

- Add individually or in bulk
- Send invitation
- Testers install TestFlight app
- Redeem invitation code

**Public Link:**

- Create public link for easy invitations
- Share link via email, web, social media
- Testers join automatically
- Track via groups

### Managing TestFlight Builds

**Build Details:**

- Version and build number
- Upload date
- Processing status
- Expiration date (90 days)
- Install count
- Crash rate
- Tester feedback

**Actions:**

- Expire build (stop installations)
- Export compliance info
- View crash logs
- Respond to tester feedback

---

## App Store Submission

### Preparation Checklist

**Technical:**

- [ ] App built with Release configuration
- [ ] Version number updated
- [ ] Build number incremented
- [ ] All capabilities configured
- [ ] Privacy manifest included (iOS 17+)
- [ ] No compiler warnings
- [ ] Tested on multiple devices
- [ ] Performance acceptable
- [ ] Crash rate < 1%

**Assets:**

- [ ] App icon (1024x1024 PNG)
- [ ] Screenshots for all required devices
  - 6.7" iPhone (iPhone 15 Pro Max)
  - 6.5" iPhone (iPhone 14 Plus)
  - 5.5" iPhone (iPhone 8 Plus)
  - 12.9" iPad Pro
- [ ] App previews (optional videos)
- [ ] Promotional artwork (optional)

**Metadata:**

- [ ] App name
- [ ] Subtitle
- [ ] Description (4000 chars max)
- [ ] Keywords (100 chars max)
- [ ] Support URL
- [ ] Marketing URL (optional)
- [ ] Privacy policy URL
- [ ] App category (Primary & Secondary)
- [ ] Content rating

**Legal:**

- [ ] Privacy policy
- [ ] Terms of service
- [ ] Export compliance
- [ ] Content rights

### Create App Listing

**In App Store Connect:**

1. **Create New App**
   - Apps → + (Add)
   - Select platform: iOS
   - Name: OmniTAK Mobile
   - Primary language: English
   - Bundle ID: com.engindearing.omnitak.test
   - SKU: omnitak-mobile-001

2. **App Information**
   - Name
   - Subtitle (30 chars)
   - Category: Navigation
   - Secondary category: Utilities

3. **Pricing and Availability**
   - Price: $9.99 (or Free)
   - Availability: All countries
   - Release: Manual or Automatic

4. **App Privacy**
   - Data collection disclosure
   - Privacy policy URL

### Version Information

**1.0 Prepare for Submission:**

1. **Version Details**
   - Version: 1.2.0
   - Copyright: © 2024-2025 OmniTAK
   - What's New: Release notes (4000 chars max)

2. **Screenshots**
   - Drag and drop screenshots for each size
   - Add captions (optional)
   - Reorder by dragging

3. **Description**

```
OmniTAK Mobile brings tactical awareness to iOS and iPadOS.
Connect to TAK servers, exchange Cursor-on-Target (CoT) messages,
view real-time positions on military-grade maps, and coordinate
with your team.

FEATURES:
• Full TAK protocol support (CoT messaging)
• Multi-server federation
• MIL-STD-2525 tactical symbology
• GeoChat messaging with location
• Offline map downloads
• MEDEVAC and tactical reports
• Route planning and navigation
• Emergency beacon (911, In Contact)
• Secure TLS with client certificates
• Meshtastic mesh network integration

Perfect for military operations, emergency response, training
exercises, and any scenario requiring tactical coordination.
```

4. **Keywords**

```
TAK, ATAK, tactical, military, CoT, GeoChat, navigation, map,
offline, situational awareness
```

5. **Support URL**

```
https://github.com/tyroe1998/omniTAKmobile
```

6. **Privacy Policy URL**

```
https://yourcompany.com/privacy
```

7. **Build**
   - Click "+" to select build
   - Choose uploaded build from TestFlight
   - Add export compliance info

8. **Rating**
   - Complete questionnaire
   - Likely rating: 4+ or 9+ (depending on content)

9. **Review Information**
   - Contact information
   - Demo account (if login required)
   - Notes for reviewer

### Submit for Review

**Final Steps:**

1. **Review Summary**
   - Verify all info is correct
   - Check screenshots display properly
   - Test all links

2. **Submit**
   - Click "Submit for Review"
   - Confirmation dialog
   - Status changes to "Waiting for Review"

3. **Review Process**
   - Apple reviews app (1-3 days typically)
   - May request clarifications
   - Approval or rejection notification

4. **If Approved**
   - Status: "Pending Developer Release" or "Ready for Sale"
   - Release manually or automatic based on settings

5. **If Rejected**
   - Review rejection reasons
   - Address issues
   - Resubmit

### App Review Guidelines

**Common Rejection Reasons:**

❌ **Crashes or bugs**

- Test thoroughly before submission

❌ **Incomplete functionality**

- All features must work

❌ **Misleading content**

- Screenshots/description must match app

❌ **Privacy violations**

- Must have privacy policy
- Disclose data collection

❌ **Design issues**

- Follow Human Interface Guidelines
- Provide value on all devices

**App Review Time:**

- Typically 24-48 hours
- Can be faster or slower
- Holiday seasons slower

---

## Enterprise Distribution

### Overview

Enterprise distribution allows internal-only deployment without App Store.

**Requirements:**

- Apple Developer Enterprise Program ($299/year)
- Organization verification by Apple
- Internal use only (not for public)

### In-House Provisioning Profile

1. **Create Profile**
   - Developer Portal → Certificates, IDs & Profiles
   - Provisioning Profiles → In-House
   - Select App ID
   - Select certificate
   - Download profile

2. **Configure Xcode**
   - Select In-House profile
   - Build with Release configuration
   - Archive

3. **Export for Enterprise**
   - Organizer → Distribute App
   - Method: Enterprise
   - Export

### Distribution Methods

**Over-the-Air (OTA):**

```xml
<!-- manifest.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>items</key>
    <array>
        <dict>
            <key>assets</key>
            <array>
                <dict>
                    <key>kind</key>
                    <string>software-package</string>
                    <key>url</key>
                    <string>https://yourserver.com/OmniTAKMobile.ipa</string>
                </dict>
            </array>
            <key>metadata</key>
            <dict>
                <key>bundle-identifier</key>
                <string>com.engindearing.omnitak</string>
                <key>bundle-version</key>
                <string>1.2.0</string>
                <key>kind</key>
                <string>software</string>
                <key>title</key>
                <string>OmniTAK Mobile</string>
            </dict>
        </dict>
    </array>
</dict>
</plist>
```

**Installation Link:**

```html
<a href="itms-services://?action=download-manifest&url=https://yourserver.com/manifest.plist">
  Install OmniTAK Mobile
</a>
```

**MDM (Mobile Device Management):**

- Push to managed devices
- Jamf, AirWatch, MobileIron, etc.
- Automatic updates

---

## Continuous Integration

### GitHub Actions

**Example Workflow:**

```yaml
name: iOS Build

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  build:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v3

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_14.3.app

      - name: Build
        run: |
          cd apps/omnitak
          xcodebuild -project OmniTAKMobile.xcodeproj \
            -scheme OmniTAKMobile \
            -sdk iphonesimulator \
            -configuration Debug \
            build

      - name: Run Tests
        run: |
          xcodebuild test \
            -project OmniTAKMobile.xcodeproj \
            -scheme OmniTAKMobile \
            -sdk iphonesimulator \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Fastlane Automation

**Fastfile Example:**

```ruby
default_platform(:ios)

platform :ios do
  desc "Run tests"
  lane :test do
    run_tests(scheme: "OmniTAKMobile")
  end

  desc "Build for TestFlight"
  lane :beta do
    increment_build_number
    build_app(scheme: "OmniTAKMobile")
    upload_to_testflight
  end

  desc "Build for App Store"
  lane :release do
    increment_build_number
    build_app(scheme: "OmniTAKMobile")
    upload_to_app_store
  end
end
```

---

## Troubleshooting Build Issues

### Common Build Errors

**"No signing certificate found"**

```
Solution:
1. Xcode → Preferences → Accounts
2. Select Apple ID
3. Click "Manage Certificates"
4. Click "+" → iOS Development
```

**"Provisioning profile doesn't include signing certificate"**

```
Solution:
1. Enable "Automatically manage signing"
2. Clean build folder (Cmd + Shift + K)
3. Rebuild
```

**"Command PhaseScriptExecution failed"**

```
Solution:
1. Review build script output
2. Check script permissions: chmod +x script.sh
3. Verify paths in scripts
```

**"Framework not found"**

```
Solution:
1. Project → Target → General → Frameworks
2. Verify framework is added
3. Check "Embed & Sign" status
```

**Swift compiler errors after update**

```
Solution:
1. Clean build folder (Cmd + Shift + K)
2. Delete DerivedData:
   rm -rf ~/Library/Developer/Xcode/DerivedData
3. Rebuild
```

### Performance Issues

**Slow builds:**

- Enable parallel builds: Build Settings → Build Options → Parallelize Build
- Increase derivedDataPath size
- Use SSD for DerivedData
- Close other applications

**Large app size:**

- Enable App Thinning (automatic)
- Remove unused assets
- Optimize images
- Enable bitcode (if required)

---

## Summary

Key deployment steps:

1. ✅ **Build** - Create archive with Release configuration
2. ✅ **Version** - Update version and build numbers
3. ✅ **Sign** - Configure code signing (automatic or manual)
4. ✅ **Archive** - Create .xcarchive for distribution
5. ✅ **Export** - Export IPA with appropriate method
6. ✅ **Upload** - Upload to TestFlight or App Store
7. ✅ **Test** - Beta test with TestFlight
8. ✅ **Submit** - Submit to App Store for review
9. ✅ **Release** - Publish after approval

**Typical Timeline:**

- Build & upload: 30 minutes
- TestFlight processing: 10-60 minutes
- Beta testing: 1-2 weeks
- App Store review: 24-48 hours
- Total: 2-3 weeks for first release

---

**Next:** [Troubleshooting](TROUBLESHOOTING.md) | [Architecture](ARCHITECTURE.md) | [Back to Index](README.md)
