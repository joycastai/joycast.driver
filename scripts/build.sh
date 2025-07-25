#!/usr/bin/env bash

# JoyCast Driver Build Script (Clean Architecture)
# Builds JoyCast driver using BlackHole submodule with JoyCast configurations

set -euo pipefail
IFS=$'\n\t'
trap 'echo -e "\033[0m" >&2' ERR EXIT

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# Parse arguments
NO_UPDATE=false
KEEP_DEBUG=false

usage() {
    echo "Usage: $0 [--no-update] [--debug]"
    echo "  --no-update - Skip BlackHole submodule update"
    echo "  --debug     - Keep .dSYM debug files (removed by default)"
    echo ""
    echo "Builds production version only."
    echo ""
    echo "Examples:"
    echo "  $0                    # Build production version (latest BlackHole, no debug)"
    echo "  $0 --no-update      # Build production version (current BlackHole, no debug)"
    echo "  $0 --debug          # Build production version with debug symbols"
    echo "  $0 --no-update --debug  # Build with current BlackHole + debug symbols"
    exit "${1:-0}"
}

# Parse all arguments with proper while/case
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-update)
            NO_UPDATE=true
            ;;
        --debug)
            KEEP_DEBUG=true
            ;;
        --help|-h|help)
            usage 0
            ;;
        *)
            echo -e "${RED}Error: Unknown argument '$1'${NC}"
            usage 1
            ;;
    esac
    shift
done

echo -e "${GREEN}=== JoyCast Driver Build ===${NC}"

# Environment checks
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: This script only works on macOS${NC}"
    exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo -e "${RED}Error: xcodebuild not found. Please install Xcode or Xcode Command Line Tools.${NC}"
    exit 1
fi

# Check if we're in the right directory
if [[ ! -f "scripts/build.sh" ]]; then
    echo -e "${RED}Error: Please run this script from the repository root${NC}"
    exit 1
fi

# Check if BlackHole submodule exists
if [[ ! -d "external/blackhole" ]]; then
    echo -e "${RED}BlackHole submodule not found. Initializing...${NC}"
    git submodule update --init --recursive
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Failed to initialize submodule${NC}"
        exit 1
    fi
fi

# Update submodule to latest version (unless --no-update flag is provided)
if [[ "$NO_UPDATE" = false ]]; then
    echo -e "${YELLOW}Updating BlackHole submodule to latest version...${NC}"
    git submodule update --remote external/blackhole
    if [[ $? -ne 0 ]]; then
        echo -e "${YELLOW}Warning: Failed to update submodule. Continuing with current version.${NC}"
    else
        echo -e "${GREEN}BlackHole submodule updated successfully${NC}"
    fi
else
    echo -e "${YELLOW}Skipping submodule update (--no-update flag provided)${NC}"
fi

# Show BlackHole version for reproducible builds
BLACKHOLE_VERSION=$(cat external/blackhole/VERSION 2>/dev/null || echo "unknown")
echo -e "${GREEN}BlackHole version: $BLACKHOLE_VERSION${NC}"

# Utility functions
generate_preprocessor_defs() {
    # Escape spaces for shell safety
    local safe_driver_name="${DRIVER_NAME// /\\ }"
    local safe_device_name="${DEVICE_NAME// /\\ }"
    local safe_manufacturer_name="${MANUFACTURER_NAME// /\\ }"
    local safe_device2_name="${DEVICE2_NAME// /\\ }"
    
    # Generate comprehensive preprocessor definitions string
    # Based on BlackHole customization parameters: https://github.com/ExistentialAudio/BlackHole
    echo "kDriver_Name=\\\"$safe_driver_name\\\" kPlugIn_BundleID=\\\"$BUNDLE_ID\\\" kPlugIn_Icon=\\\"$DRIVER_ICON\\\" kManufacturer_Name=\\\"$safe_manufacturer_name\\\" kDevice_Name=\\\"$safe_device_name\\\" kDevice_IsHidden=$DEVICE_IS_HIDDEN kDevice_HasInput=$DEVICE_HAS_INPUT kDevice_HasOutput=$DEVICE_HAS_OUTPUT kDevice2_Name=\\\"$safe_device2_name\\\" kDevice2_IsHidden=$DEVICE2_IS_HIDDEN kDevice2_HasInput=$DEVICE2_HAS_INPUT kDevice2_HasOutput=$DEVICE2_HAS_OUTPUT kLatency_Frame_Size=$LATENCY_FRAME_SIZE kNumber_Of_Channels=$NUMBER_OF_CHANNELS kSampleRates='$SAMPLE_RATES'"
}

# Generate driver version (always .0)
echo -e "${YELLOW}Generating driver version...${NC}"
BASE_VERSION=$(date +"%y.%-m.%-d")
DRIVER_VERSION="${BASE_VERSION}.0"

echo "Driver version: $DRIVER_VERSION"

# Load base configuration
CONFIG_FILE="configs/driver.env"
echo "Loading configuration: $CONFIG_FILE"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Error: Configuration file $CONFIG_FILE not found${NC}"
    exit 1
fi

# Source the base configuration
source "$CONFIG_FILE"

# Load code signing credentials if available
CREDENTIALS_FILE="configs/credentials.env"
if [[ -f "$CREDENTIALS_FILE" ]]; then
    echo "Loading credentials: $CREDENTIALS_FILE"
    source "$CREDENTIALS_FILE"
else
    echo -e "${YELLOW}Warning: $CREDENTIALS_FILE not found. Code signing may fail.${NC}"
fi

# Function to build driver
build_driver() {
    echo -e "\n${BOLD}${YELLOW}=== Building driver ===${NC}"
    
    # Use configuration from driver.env
    # Variables are already loaded from driver.env
    
    echo "Build mode: production (signed with $CODE_SIGN_IDENTITY)"
    echo "Driver: $DRIVER_NAME.driver"
    echo "Version: $DRIVER_VERSION"

    # Generate preprocessor definitions
    PREPROCESSOR_DEFS=$(generate_preprocessor_defs)

    echo -e "${YELLOW}Preprocessor definitions:${NC}"
    echo "$PREPROCESSOR_DEFS"

    # Build using BlackHole project but output to our build directory
    echo -e "${YELLOW}Building universal driver (arm64 + x86_64)...${NC}"

    # Prepare build arguments
    BUILD_ARGS=(
        -project external/blackhole/BlackHole.xcodeproj
        -configuration Release
        -target BlackHole
        PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
        PRODUCT_NAME="$DRIVER_NAME"
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
        CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY"
        CODE_SIGN_STYLE="Manual"
        ENABLE_HARDENED_RUNTIME=YES
        ARCHS="arm64 x86_64"
        CONFIGURATION_BUILD_DIR="$(pwd)/dist/build"
        MARKETING_VERSION="$DRIVER_VERSION"
    )

    echo "Will sign with: $CODE_SIGN_IDENTITY"

    # Build with JoyCast customizations
    xcodebuild \
        "${BUILD_ARGS[@]}" \
        "GCC_PREPROCESSOR_DEFINITIONS=\$GCC_PREPROCESSOR_DEFINITIONS $PREPROCESSOR_DEFS"

    echo -e "${GREEN}Build completed!${NC}"

    # Check if driver was created
    DRIVER_PATH="dist/build/$DRIVER_NAME.driver"
    if [[ ! -d "$DRIVER_PATH" ]]; then
        echo -e "${RED}Error: Built driver not found at $DRIVER_PATH${NC}"
        exit 1
    fi

    echo "Driver built successfully at: $DRIVER_PATH"

    # Add JoyCast-specific resources
    RESOURCES_PATH="$DRIVER_PATH/Contents/Resources"

    # Copy JoyCast icon
    if [[ -f "assets/$DRIVER_ICON" ]]; then
        cp "assets/$DRIVER_ICON" "$RESOURCES_PATH/"
        echo "JoyCast icon copied: $DRIVER_ICON"
    else
        echo -e "${YELLOW}Warning: $DRIVER_ICON not found in assets/${NC}"
    fi

    # Replace license with JoyCast license
    if [[ -f "LICENSE" ]]; then
        cp "LICENSE" "$RESOURCES_PATH/LICENSE"
        echo "JoyCast LICENSE installed"
    fi

    # Remove BlackHole icon
    if [[ -f "$RESOURCES_PATH/BlackHole.icns" ]]; then
        rm -f "$RESOURCES_PATH/BlackHole.icns"
        echo "BlackHole icon removed"
    fi

    # Final signing
    if [[ -n "$CODE_SIGN_IDENTITY" ]]; then
        echo -e "${YELLOW}Final code signing...${NC}"
        codesign --force --sign "$CODE_SIGN_IDENTITY" \
                 --options=runtime \
                 --timestamp \
                 "$DRIVER_PATH"
        echo -e "${GREEN}Driver signed successfully${NC}"
    fi
}

# Map credentials to build variables
DEVELOPMENT_TEAM="$APPLE_TEAM_ID"
CODE_SIGN_IDENTITY="Developer ID Application: $DEVELOPER_NAME ($APPLE_TEAM_ID)"

# Validate code signing credentials
if [[ -z "$DEVELOPER_NAME" || -z "$DEVELOPMENT_TEAM" ]]; then
    echo -e "${RED}Error: Code signing credentials not found!${NC}"
    echo "Make sure configs/credentials.env contains:"
    echo "  APPLE_TEAM_ID=your_team_id"
    echo "  DEVELOPER_NAME=your_developer_name"
    exit 1
fi

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf dist/build/
mkdir -p dist/build/

# Build driver
build_driver

# Clean up temporary build files from submodule
echo -e "\n${YELLOW}Cleaning temporary build files from submodule...${NC}"
rm -rf external/blackhole/build/

echo -e "\n${GREEN}=== Build Complete ===${NC}"
echo "Driver built:"
echo "  - dist/build/JoyCast.driver (Production)"

echo -e "\n${BLUE}BlackHole version: $BLACKHOLE_VERSION${NC}"

if [[ "$KEEP_DEBUG" = true ]]; then
    echo "Debug symbols:"
    echo "  - dist/build/JoyCast.driver.dSYM"
fi

# Verify build
echo -e "\n${YELLOW}Verifying signature...${NC}"
if codesign -v "dist/build/JoyCast.driver" 2>/dev/null; then
    echo -e "${GREEN}✓ Driver signature valid${NC}"
else
    echo -e "${YELLOW}! Driver is unsigned${NC}"
fi

# Clean up debug symbols unless --debug flag is provided
if [[ "$KEEP_DEBUG" = false ]]; then
    echo -e "\n${YELLOW}Cleaning up debug symbols...${NC}"
    
    if [[ -d "dist/build/JoyCast.driver.dSYM" ]]; then
        rm -rf "dist/build/JoyCast.driver.dSYM"
        echo -e "${GREEN}✓ Removed JoyCast.driver.dSYM${NC}"
    fi
    
    echo -e "${GRAY}Use --debug flag to keep debug symbols${NC}"
else
    echo -e "\n${BLUE}Debug symbols preserved (--debug flag provided)${NC}"
    echo -e "  📁 dist/build/JoyCast.driver.dSYM"
fi 