#!/bin/bash
set -e

####################
## Build OmniTAK Mobile Rust Libraries for Android
##
## This script cross-compiles the Rust omnitak-mobile library
## for all Android architectures and copies them to the correct locations.
##
## Prerequisites:
## 1. Rust toolchain installed
## 2. Android NDK installed
## 3. Rust Android targets installed
## 4. omni-TAK repository cloned
## 5. Cargo Android NDK configuration
##
## See BUILD_GUIDE.md for detailed setup instructions.
####################

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
OMNI_TAK_DIR="${OMNI_TAK_DIR:-$HOME/Downloads/omni-TAK}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/android/native/lib"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}OmniTAK Mobile - Android Build${NC}"
echo -e "${BLUE}=========================================${NC}"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

# Check Rust
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: Rust/Cargo not found${NC}"
    echo "Install from: https://rustup.rs/"
    exit 1
fi
echo -e "${GREEN}✓ Rust found: $(rustc --version)${NC}"

# Check Android NDK
if [ -z "$ANDROID_NDK_HOME" ]; then
    echo -e "${YELLOW}Warning: ANDROID_NDK_HOME not set${NC}"
    echo "Set it to your NDK directory, e.g.:"
    echo "export ANDROID_NDK_HOME=\$HOME/Library/Android/sdk/ndk/25.1.8937393"
    echo ""
    # Try to auto-detect
    if [ -d "$HOME/Library/Android/sdk/ndk" ]; then
        ANDROID_NDK_HOME="$(find $HOME/Library/Android/sdk/ndk -maxdepth 1 -type d | tail -1)"
        echo -e "${GREEN}Auto-detected: $ANDROID_NDK_HOME${NC}"
    elif [ -d "$HOME/Android/Sdk/ndk" ]; then
        ANDROID_NDK_HOME="$(find $HOME/Android/Sdk/ndk -maxdepth 1 -type d | tail -1)"
        echo -e "${GREEN}Auto-detected: $ANDROID_NDK_HOME${NC}"
    else
        echo -e "${RED}Could not auto-detect NDK location${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Android NDK: $ANDROID_NDK_HOME${NC}"

# Check omni-TAK directory
if [ ! -d "$OMNI_TAK_DIR" ]; then
    echo -e "${RED}Error: omni-TAK directory not found: $OMNI_TAK_DIR${NC}"
    echo "Set OMNI_TAK_DIR environment variable or clone the repository:"
    echo "git clone <omni-TAK-repo-url> $OMNI_TAK_DIR"
    exit 1
fi
echo -e "${GREEN}✓ omni-TAK directory: $OMNI_TAK_DIR${NC}"

# Check Rust targets
echo -e "\n${YELLOW}Checking Rust targets...${NC}"
TARGETS=(
    "aarch64-linux-android"
    "armv7-linux-androideabi"
    "x86_64-linux-android"
    "i686-linux-android"
)

MISSING_TARGETS=()
for TARGET in "${TARGETS[@]}"; do
    if rustup target list | grep -q "^$TARGET (installed)"; then
        echo -e "${GREEN}✓ $TARGET${NC}"
    else
        echo -e "${YELLOW}✗ $TARGET (will install)${NC}"
        MISSING_TARGETS+=("$TARGET")
    fi
done

# Install missing targets
if [ ${#MISSING_TARGETS[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}Installing missing targets...${NC}"
    for TARGET in "${MISSING_TARGETS[@]}"; do
        rustup target add "$TARGET"
    done
fi

# Navigate to Rust project
echo -e "\n${BLUE}Building Rust libraries...${NC}"
cd "$OMNI_TAK_DIR/crates/omnitak-mobile"

# Build for each Android architecture
echo -e "\n${YELLOW}Building for arm64-v8a (aarch64)...${NC}"
cargo build --release --target aarch64-linux-android
echo -e "${GREEN}✓ arm64-v8a complete${NC}"

echo -e "\n${YELLOW}Building for armeabi-v7a (armv7)...${NC}"
cargo build --release --target armv7-linux-androideabi
echo -e "${GREEN}✓ armeabi-v7a complete${NC}"

echo -e "\n${YELLOW}Building for x86_64...${NC}"
cargo build --release --target x86_64-linux-android
echo -e "${GREEN}✓ x86_64 complete${NC}"

echo -e "\n${YELLOW}Building for x86...${NC}"
cargo build --release --target i686-linux-android
echo -e "${GREEN}✓ x86 complete${NC}"

# Create output directories
echo -e "\n${YELLOW}Creating output directories...${NC}"
mkdir -p "$OUTPUT_DIR"/{arm64-v8a,armeabi-v7a,x86_64,x86}

# Copy libraries
echo -e "\n${YELLOW}Copying libraries to module...${NC}"
cd "$OMNI_TAK_DIR"

cp "target/aarch64-linux-android/release/libomnitak_mobile.a" \
   "$OUTPUT_DIR/arm64-v8a/"
echo -e "${GREEN}✓ Copied arm64-v8a/libomnitak_mobile.a${NC}"

cp "target/armv7-linux-androideabi/release/libomnitak_mobile.a" \
   "$OUTPUT_DIR/armeabi-v7a/"
echo -e "${GREEN}✓ Copied armeabi-v7a/libomnitak_mobile.a${NC}"

cp "target/x86_64-linux-android/release/libomnitak_mobile.a" \
   "$OUTPUT_DIR/x86_64/"
echo -e "${GREEN}✓ Copied x86_64/libomnitak_mobile.a${NC}"

cp "target/i686-linux-android/release/libomnitak_mobile.a" \
   "$OUTPUT_DIR/x86/"
echo -e "${GREEN}✓ Copied x86/libomnitak_mobile.a${NC}"

# Verify builds
echo -e "\n${YELLOW}Verifying builds...${NC}"
for ABI in arm64-v8a armeabi-v7a x86_64 x86; do
    LIB_PATH="$OUTPUT_DIR/$ABI/libomnitak_mobile.a"
    if [ -f "$LIB_PATH" ]; then
        SIZE=$(du -h "$LIB_PATH" | cut -f1)
        echo -e "${GREEN}✓ $ABI/libomnitak_mobile.a ($SIZE)${NC}"
    else
        echo -e "${RED}✗ Missing: $ABI/libomnitak_mobile.a${NC}"
    fi
done

# Summary
echo -e "\n${BLUE}=========================================${NC}"
echo -e "${GREEN}Build complete!${NC}"
echo -e "${BLUE}=========================================${NC}"
echo -e "Output directory: $OUTPUT_DIR"
echo -e "\nLibraries built:"
echo -e "  • arm64-v8a/libomnitak_mobile.a  (64-bit ARM - phones/tablets)"
echo -e "  • armeabi-v7a/libomnitak_mobile.a (32-bit ARM - older devices)"
echo -e "  • x86_64/libomnitak_mobile.a      (64-bit Intel - emulators)"
echo -e "  • x86/libomnitak_mobile.a         (32-bit Intel - legacy)"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "1. Build the Valdi app: ${GREEN}bazel build //apps/omnitak_android${NC}"
echo -e "2. Or use the Android build system with Gradle"
echo -e "3. Test on an emulator or device"
echo ""
