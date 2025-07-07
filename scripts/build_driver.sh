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
NC='\033[0m'

# Parse arguments
MODE=""
NO_UPDATE=false

usage() {
    echo "Usage: $0 [dev|prod] [--no-update]"
    echo "  dev         - Development build with Dev suffix"
    echo "  prod        - Production build with clean names"
    echo "  --no-update - Skip BlackHole submodule update"
    echo ""
    echo "Examples:"
    echo "  $0 dev                    # Build dev version (latest BlackHole)"
    echo "  $0 prod --no-update      # Build prod version (current BlackHole)"
    exit "${1:-0}"
}

# Parse all arguments with proper while/case
while [[ $# -gt 0 ]]; do
    case $1 in
        dev|prod)
            MODE="$1"
            ;;
        --no-update)
            NO_UPDATE=true
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

# Set default mode if not specified
MODE="${MODE:-prod}"

echo -e "${GREEN}=== JoyCast Driver Build (Clean Architecture) ===${NC}"

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
if [[ ! -f "scripts/build_driver.sh" ]]; then
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

# Show BlackHole commit for reproducible builds
BLACKHOLE_COMMIT=$(git -C external/blackhole rev-parse --short HEAD)
echo -e "${GREEN}BlackHole commit: $BLACKHOLE_COMMIT${NC}"

# Utility functions
generate_preprocessor_defs() {
    # Escape spaces for shell safety
    local safe_driver_name="${DRIVER_NAME// /\\ }"
    local safe_device_name="${DEVICE_NAME// /\\ }"
    local safe_manufacturer_name="${MANUFACTURER_NAME// /\\ }"
    local safe_device2_name="${DEVICE2_NAME// /\\ }"
    
    # Generate comprehensive preprocessor definitions string
    # Based on BlackHole customization parameters: https://github.com/ExistentialAudio/BlackHole
    echo "kDriver_Name=\\\"$safe_driver_name\\\" kPlugIn_BundleID=\\\"$BUNDLE_ID\\\" kPlugIn_Icon=\\\"$PLUGIN_ICON\\\" kManufacturer_Name=\\\"$safe_manufacturer_name\\\" kDevice_Name=\\\"$safe_device_name\\\" kDevice_IsHidden=$DEVICE_IS_HIDDEN kDevice_HasInput=$DEVICE_HAS_INPUT kDevice_HasOutput=$DEVICE_HAS_OUTPUT kDevice2_Name=\\\"$safe_device2_name\\\" kDevice2_IsHidden=$DEVICE2_IS_HIDDEN kDevice2_HasInput=$DEVICE2_HAS_INPUT kDevice2_HasOutput=$DEVICE2_HAS_OUTPUT kBox_UID=\\\"$BOX_UID\\\" kDevice_UID=\\\"$DEVICE_UID\\\" kDevice2_UID=\\\"$DEVICE2_UID\\\" kLatency_Frame_Size=$LATENCY_FRAME_SIZE kNumber_Of_Channels=$NUMBER_OF_CHANNELS kSampleRates='$SAMPLE_RATES'"
}

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

# Generate dev/prod specific variables
if [[ "$MODE" == "dev" ]]; then
    DRIVER_NAME="$BASE_NAME Dev"
    BUNDLE_ID="$BASE_BUNDLE_ID.dev"
    DEVICE_NAME="$BASE_DEVICE_NAME"
    DEVICE_NAME="${DEVICE_NAME/JoyCast/JoyCast Dev}"
    DEVICE2_NAME="$BASE_DEVICE2_NAME"
    DEVICE2_NAME="${DEVICE2_NAME/JoyCast/JoyCast Dev}"
    BOX_UID="${BASE_NAME}DEV_UID"
    DEVICE_UID="${BASE_NAME}_Dev_Virtual_Microphone_UID"
    DEVICE2_UID="${BASE_NAME}_Dev_Virtual_Microphone_2_UID"
else
    DRIVER_NAME="$BASE_NAME"
    BUNDLE_ID="$BASE_BUNDLE_ID"
    DEVICE_NAME="$BASE_DEVICE_NAME"
    DEVICE2_NAME="$BASE_DEVICE2_NAME"
    BOX_UID="${BASE_NAME}_UID"
    DEVICE_UID="${BASE_NAME}_Virtual_Microphone_UID"
    DEVICE2_UID="${BASE_NAME}_Virtual_Microphone_2_UID"
fi

# Set audio parameters from config (same for dev/prod)
# These correspond directly to BlackHole customization parameters

# Map credentials to build variables
DEVELOPMENT_TEAM="$APPLE_TEAM_ID"
CODE_SIGN_IDENTITY="$CODE_SIGN_CERT_NAME"

# Validate code signing credentials
if [[ -z "$CODE_SIGN_IDENTITY" || -z "$DEVELOPMENT_TEAM" ]]; then
    echo -e "${RED}Error: Code signing credentials not found!${NC}"
    echo "Make sure configs/credentials.env contains:"
    echo "  APPLE_TEAM_ID=your_team_id"
    echo "  CODE_SIGN_CERT_NAME=your_cert_name"
    exit 1
fi

echo "Build mode: $MODE (signed with $CODE_SIGN_IDENTITY)"
echo "Driver: $DRIVER_NAME.driver"

# Generate preprocessor definitions
PREPROCESSOR_DEFS=$(generate_preprocessor_defs)

echo -e "${YELLOW}Preprocessor definitions:${NC}"
echo "$PREPROCESSOR_DEFS"

# Clean previous build for this mode
echo "Cleaning previous $MODE build..."
rm -rf build/$MODE/
mkdir -p build/$MODE/

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
    CONFIGURATION_BUILD_DIR="$(pwd)/build/$MODE"
)

echo "Will sign with: $CODE_SIGN_IDENTITY"

# Build with JoyCast customizations
xcodebuild \
    "${BUILD_ARGS[@]}" \
    "GCC_PREPROCESSOR_DEFINITIONS=\$GCC_PREPROCESSOR_DEFINITIONS $PREPROCESSOR_DEFS"

echo -e "${GREEN}Build completed!${NC}"

# Check if driver was created
DRIVER_PATH="build/$MODE/$DRIVER_NAME.driver"
if [[ ! -d "$DRIVER_PATH" ]]; then
    echo -e "${RED}Error: Built driver not found at $DRIVER_PATH${NC}"
    exit 1
fi

echo "Driver built successfully at: $DRIVER_PATH"

# Add JoyCast-specific resources
RESOURCES_PATH="$DRIVER_PATH/Contents/Resources"

# Copy JoyCast icon
if [[ -f "assets/$PLUGIN_ICON" ]]; then
    cp "assets/$PLUGIN_ICON" "$RESOURCES_PATH/"
    echo "JoyCast icon copied: $PLUGIN_ICON"
else
    echo -e "${YELLOW}Warning: $PLUGIN_ICON not found in assets/${NC}"
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

# Clean up temporary build files from submodule
echo "Cleaning temporary build files from submodule..."
rm -rf external/blackhole/build/

echo -e "${GREEN}=== Build Complete ===${NC}"
echo "Driver location: $DRIVER_PATH"

# Verify the build
if codesign -v "$DRIVER_PATH" 2>/dev/null; then
    echo -e "${GREEN}✓ Code signature valid${NC}"
else
    echo -e "${YELLOW}! Driver is unsigned${NC}"
fi 