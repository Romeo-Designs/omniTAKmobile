#!/bin/bash
# Quick script to update iOS app version before archiving
# Usage:
#   ./update_build.sh              # Auto-increment build number
#   ./update_build.sh 1.2.0        # Set version to 1.2.0 and auto-increment build
#   ./update_build.sh 1.2.0 42     # Set version to 1.2.0 and build to 42

PLIST="OmniTAKMobile/Resources/Info.plist"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  OmniTAK Build Version Updater"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Ensure version keys exist
if ! /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" &>/dev/null; then
    echo "Adding CFBundleShortVersionString key..."
    /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0.0" "$PLIST"
fi

if ! /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST" &>/dev/null; then
    echo "Adding CFBundleVersion key..."
    /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$PLIST"
fi

# Get current values
CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")

echo ""
echo "📱 Current Version: $CURRENT_VERSION"
echo "🔢 Current Build:   $CURRENT_BUILD"
echo ""

# Update version if provided
if [ ! -z "$1" ]; then
    echo "Updating version: $CURRENT_VERSION → $1"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $1" "$PLIST"
    CURRENT_VERSION="$1"
fi

# Update or increment build number
if [ ! -z "$2" ]; then
    echo "Setting build number: $CURRENT_BUILD → $2"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $2" "$PLIST"
    NEW_BUILD="$2"
else
    # Auto-increment build number
    NEW_BUILD=$((CURRENT_BUILD + 1))
    echo "Auto-incrementing build: $CURRENT_BUILD → $NEW_BUILD"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST"
fi

echo ""
echo "✅ Updated successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 New Version: $CURRENT_VERSION"
echo "🔢 New Build:   $NEW_BUILD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Ready to archive! 🚀"
echo ""
echo "Next steps:"
echo "  1. Open Xcode"
echo "  2. Product → Archive"
echo "  3. Distribute App → App Store Connect"
