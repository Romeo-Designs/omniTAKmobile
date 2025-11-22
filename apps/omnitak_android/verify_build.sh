#!/bin/bash

####################
## OmniTAK Android Build Verification Script
##
## Checks that all prerequisites and files are in place
## for building the Android app.
####################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODULE_DIR="$PROJECT_ROOT/modules/omnitak_mobile"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}OmniTAK Android - Build Verification${NC}"
echo -e "${BLUE}=========================================${NC}"

ERRORS=0
WARNINGS=0

# Check function
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $2"
        return 0
    else
        echo -e "${RED}✗${NC} $2 (missing: $1)"
        ((ERRORS++))
        return 1
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $2"
        return 0
    else
        echo -e "${RED}✗${NC} $2 (missing: $1)"
        ((ERRORS++))
        return 1
    fi
}

check_command() {
    if command -v "$1" &> /dev/null; then
        VERSION=$($1 --version 2>&1 | head -1)
        echo -e "${GREEN}✓${NC} $2 ($VERSION)"
        return 0
    else
        echo -e "${RED}✗${NC} $2 (command not found: $1)"
        ((ERRORS++))
        return 1
    fi
}

warn_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $2"
        return 0
    else
        echo -e "${YELLOW}!${NC} $2 (missing: $1)"
        ((WARNINGS++))
        return 1
    fi
}

# Check build tools
echo -e "\n${BLUE}Build Tools:${NC}"
check_command bazel "Bazel build system"
check_command rustc "Rust compiler"
check_command cargo "Cargo (Rust package manager)"
check_command node "Node.js"
check_command npm "npm package manager"

# Check Bazel version
echo -e "\n${BLUE}Bazel Version:${NC}"
EXPECTED_BAZEL_VERSION=$(cat "$PROJECT_ROOT/.bazelversion" 2>/dev/null || echo "7.2.1")
ACTUAL_BAZEL_VERSION=$(bazel version 2>&1 | grep "Build label" | cut -d' ' -f3)
if [ "$ACTUAL_BAZEL_VERSION" = "$EXPECTED_BAZEL_VERSION" ]; then
    echo -e "${GREEN}✓${NC} Bazel version matches: $EXPECTED_BAZEL_VERSION"
else
    echo -e "${YELLOW}!${NC} Bazel version mismatch (expected: $EXPECTED_BAZEL_VERSION, actual: $ACTUAL_BAZEL_VERSION)"
    ((WARNINGS++))
fi

# Check Android SDK/NDK
echo -e "\n${BLUE}Android Environment:${NC}"
if [ -n "$ANDROID_HOME" ]; then
    echo -e "${GREEN}✓${NC} ANDROID_HOME set: $ANDROID_HOME"
else
    echo -e "${YELLOW}!${NC} ANDROID_HOME not set"
    ((WARNINGS++))
fi

if [ -n "$ANDROID_NDK_HOME" ]; then
    echo -e "${GREEN}✓${NC} ANDROID_NDK_HOME set: $ANDROID_NDK_HOME"
else
    echo -e "${YELLOW}!${NC} ANDROID_NDK_HOME not set (needed for Rust builds)"
    ((WARNINGS++))
fi

# Check Rust targets
echo -e "\n${BLUE}Rust Android Targets:${NC}"
RUST_TARGETS=(
    "aarch64-linux-android:arm64-v8a"
    "armv7-linux-androideabi:armeabi-v7a"
    "x86_64-linux-android:x86_64"
    "i686-linux-android:x86"
)

for TARGET_PAIR in "${RUST_TARGETS[@]}"; do
    TARGET="${TARGET_PAIR%%:*}"
    ABI="${TARGET_PAIR##*:}"
    if rustup target list | grep -q "^$TARGET (installed)"; then
        echo -e "${GREEN}✓${NC} Rust target: $TARGET ($ABI)"
    else
        echo -e "${YELLOW}!${NC} Rust target: $TARGET ($ABI) - not installed"
        echo -e "   Install with: ${GREEN}rustup target add $TARGET${NC}"
        ((WARNINGS++))
    fi
done

# Check app structure
echo -e "\n${BLUE}App Structure:${NC}"
check_file "$SCRIPT_DIR/BUILD.bazel" "BUILD.bazel file"
check_file "$SCRIPT_DIR/README.md" "README.md"
check_dir "$SCRIPT_DIR/src/valdi/omnitak_app" "TypeScript source directory"
check_file "$SCRIPT_DIR/src/valdi/omnitak_app/App.tsx" "App.tsx entry point"
check_dir "$SCRIPT_DIR/app_assets/android" "Android resources directory"

# Check Android resources
echo -e "\n${BLUE}Android Resources:${NC}"
check_file "$SCRIPT_DIR/app_assets/android/values/themes.xml" "themes.xml"
check_file "$SCRIPT_DIR/app_assets/android/values/colors.xml" "colors.xml"
check_file "$SCRIPT_DIR/app_assets/android/values/strings.xml" "strings.xml"
check_file "$SCRIPT_DIR/app_assets/android/drawable-nodpi/splash.xml" "splash.xml"

# Check app icons
echo -e "\n${BLUE}App Icons:${NC}"
ICON_DENSITIES=("mdpi" "hdpi" "xhdpi" "xxhdpi" "xxxhdpi")
for DENSITY in "${ICON_DENSITIES[@]}"; do
    check_file "$SCRIPT_DIR/app_assets/android/mipmap-$DENSITY/app_icon.png" "mipmap-$DENSITY icon"
done

# Check module structure
echo -e "\n${BLUE}OmniTAK Mobile Module:${NC}"
check_file "$MODULE_DIR/BUILD.bazel" "Module BUILD.bazel"
check_file "$MODULE_DIR/module.yaml" "Module YAML config"
check_dir "$MODULE_DIR/src/valdi/omnitak" "TypeScript module sources"
check_file "$MODULE_DIR/src/valdi/omnitak/App.tsx" "Module App.tsx"

# Check Android native layer
echo -e "\n${BLUE}Android Native Layer:${NC}"
check_file "$MODULE_DIR/android/native/OmniTAKNativeBridge.kt" "Kotlin native bridge"
check_file "$MODULE_DIR/android/native/omnitak_jni.cpp" "JNI C++ bridge"
check_file "$MODULE_DIR/android/native/CMakeLists.txt" "CMake build config"
check_file "$MODULE_DIR/android/native/include/omnitak_mobile.h" "C FFI header"
check_file "$MODULE_DIR/android/maplibre/MapLibreMapView.kt" "MapLibre view"
check_file "$MODULE_DIR/build_android.sh" "Android build script"

# Check Rust libraries
echo -e "\n${BLUE}Rust Native Libraries:${NC}"
ABIS=("arm64-v8a" "armeabi-v7a" "x86_64" "x86")
for ABI in "${ABIS[@]}"; do
    LIB_PATH="$MODULE_DIR/android/native/lib/$ABI/libomnitak_mobile.a"
    if [ -f "$LIB_PATH" ]; then
        SIZE=$(du -h "$LIB_PATH" | cut -f1)
        echo -e "${GREEN}✓${NC} $ABI/libomnitak_mobile.a ($SIZE)"
    else
        echo -e "${YELLOW}!${NC} $ABI/libomnitak_mobile.a (not built)"
        echo -e "   Build with: ${GREEN}cd $MODULE_DIR && ./build_android.sh${NC}"
        ((WARNINGS++))
    fi
done

# Check iOS build (for reference)
echo -e "\n${BLUE}iOS Build (for reference):${NC}"
if [ -d "$MODULE_DIR/ios/native/OmniTAKMobile.xcframework" ]; then
    echo -e "${GREEN}✓${NC} iOS XCFramework exists"
else
    echo -e "${YELLOW}!${NC} iOS XCFramework not built (iOS only)"
fi

# Summary
echo -e "\n${BLUE}=========================================${NC}"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo -e "\nReady to build:"
    echo -e "  ${GREEN}bazel build //apps/omnitak_android${NC}"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}! Build possible with warnings${NC}"
    echo -e "${YELLOW}  Warnings: $WARNINGS${NC}"
    echo -e "\nYou can try building, but some features may not work:"
    echo -e "  ${YELLOW}bazel build //apps/omnitak_android${NC}"
    echo -e "\nRecommended: Fix warnings first"
else
    echo -e "${RED}✗ Build verification failed${NC}"
    echo -e "${RED}  Errors: $ERRORS${NC}"
    echo -e "${YELLOW}  Warnings: $WARNINGS${NC}"
    echo -e "\nFix errors before building"
fi
echo -e "${BLUE}=========================================${NC}"

# Exit code
if [ $ERRORS -eq 0 ]; then
    exit 0
else
    exit 1
fi
