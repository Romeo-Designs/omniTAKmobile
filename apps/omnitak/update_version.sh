#!/bin/bash
# Update iOS app version and build number

INFO_PLIST="/Users/iesouskurios/omniTAK-mobile/apps/omnitak/OmniTAKMobile/Resources/Info.plist"

# Show current version
echo "Current Version:"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST"
echo "Current Build:"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST"

# Update version (optional - only if provided)
if [ ! -z "$1" ]; then
    echo ""
    echo "Updating version to: $1"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $1" "$INFO_PLIST"
fi

# Update build number (increment automatically or set specific number)
if [ ! -z "$2" ]; then
    echo "Setting build number to: $2"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $2" "$INFO_PLIST"
else
    # Auto-increment build number
    CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")
    NEW_BUILD=$((CURRENT_BUILD + 1))
    echo "Auto-incrementing build: $CURRENT_BUILD → $NEW_BUILD"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$INFO_PLIST"
fi

echo ""
echo "New Version:"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST"
echo "New Build:"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST"
