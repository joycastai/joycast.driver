#!/bin/bash

# JoyCast Driver Build Script (Clean Architecture)
# Builds JoyCast driver using BlackHole submodule with JoyCast configurations

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Parse arguments first
MODE=""
NO_UPDATE=false
NO_SIGN=false

# Parse all arguments
for arg in "$@"; do
    case $arg in
        dev|prod)
            MODE="$arg"
            ;;
        --no-update)
            NO_UPDATE=true
            ;;
        --no-sign)
            NO_SIGN=true
            ;;
        --help|-h|help)
            echo "Usage: $0 [dev|prod] [--no-update] [--no-sign]"
            echo "  dev         - Development build with Dev suffix"
            echo "  prod        - Production build with clean names"
            echo "  --no-update - Skip BlackHole submodule update"
            echo "  --no-sign   - Skip code signing (unsigned build)"
            echo ""
            echo "Examples:"
            echo "  $0 dev                    # Build dev version (signed, latest BlackHole)"
            echo "  $0 prod --no-update      # Build prod version (signed, current BlackHole)"
            echo "  $0 dev --no-sign         # Build dev version (unsigned, for testing)"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown argument '$arg'${NC}"
            echo "Usage: $0 [dev|prod] [--no-update] [--no-sign]"
            echo "Use --help for more information"
            exit 1
            ;;
    esac
done

# Set default mode if not specified
MODE="${MODE:-prod}"

echo -e "${GREEN}=== JoyCast Driver Build (Clean Architecture) ===${NC}"

# Check if we're in the right directory
if [ ! -f "scripts/build_driver.sh" ]; then
    echo -e "${RED}Error: Please run this script from the repository root${NC}"
    exit 1
fi

# Check if BlackHole submodule exists
if [ ! -d "external/blackhole" ]; then
    echo -e "${RED}BlackHole submodule not found. Initializing...${NC}"
    git submodule update --init --recursive
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to initialize submodule${NC}"
        exit 1
    fi
fi

# Update submodule to latest version (unless --no-update flag is provided)
if [ "$NO_UPDATE" = false ]; then
    echo -e "${YELLOW}Updating BlackHole submodule to latest version...${NC}"
    git submodule update --remote external/blackhole
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Warning: Failed to update submodule. Continuing with current version.${NC}"
    else
        echo -e "${GREEN}BlackHole submodule updated successfully${NC}"
    fi
else
    echo -e "${YELLOW}Skipping submodule update (--no-update flag provided)${NC}"
fi

# Utility functions
generate_preprocessor_defs() {
    # Escape spaces for shell safety
    local safe_device_name="${DEVICE_NAME// /\\ }"
    local safe_manufacturer_name="${MANUFACTURER_NAME// /\\ }"
    local safe_device2_name="${DEVICE2_NAME// /\\ }"
    
    # Generate comprehensive preprocessor definitions string
    # Based on BlackHole customization parameters: https://github.com/ExistentialAudio/BlackHole
    echo "kDriver_Name=\\\"JoyCast\\\" kPlugIn_BundleID=\\\"$BUNDLE_ID\\\" kPlugIn_Icon=\\\"$PLUGIN_ICON\\\" kManufacturer_Name=\\\"$safe_manufacturer_name\\\" kDevice_Name=\\\"$safe_device_name\\\" kDevice_IsHidden=$DEVICE_IS_HIDDEN kDevice_HasInput=$DEVICE_HAS_INPUT kDevice_HasOutput=$DEVICE_HAS_OUTPUT kDevice2_Name=\\\"$safe_device2_name\\\" kDevice2_IsHidden=$DEVICE2_IS_HIDDEN kDevice2_HasInput=$DEVICE2_HAS_INPUT kDevice2_HasOutput=$DEVICE2_HAS_OUTPUT kBox_UID=\\\"$BOX_UID\\\" kDevice_UID=\\\"$DEVICE_UID\\\" kDevice2_UID=\\\"$DEVICE2_UID\\\" kLatency_Frame_Size=$LATENCY_FRAME_SIZE kNumber_Of_Channels=$NUMBER_OF_CHANNELS kSampleRates='$SAMPLE_RATES'"
}



# Load base configuration
CONFIG_FILE="configs/driver.env"
echo "Loading configuration: $CONFIG_FILE"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Configuration file $CONFIG_FILE not found${NC}"
    exit 1
fi

# Source the base configuration
source "$CONFIG_FILE"

# Load code signing credentials if available
CREDENTIALS_FILE="configs/credentials.env"
if [ -f "$CREDENTIALS_FILE" ]; then
    echo "Loading credentials: $CREDENTIALS_FILE"
    source "$CREDENTIALS_FILE"
else
    echo -e "${YELLOW}Warning: $CREDENTIALS_FILE not found. Code signing may fail.${NC}"
fi

# Generate dev/prod specific variables
if [ "$MODE" == "dev" ]; then
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

# Code signing logic (same for both dev and prod)
if [ "$NO_SIGN" = true ]; then
    FINAL_CODE_SIGN_IDENTITY=""
    echo "Build mode: $MODE (unsigned)"
else
    FINAL_CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY"
    echo "Build mode: $MODE (signed)"
fi

echo "Build mode: $MODE"
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
echo -e "${YELLOW}Building driver...${NC}"

# Prepare build arguments
BUILD_ARGS=(
    -project external/blackhole/BlackHole.xcodeproj
    -configuration Release
    -target BlackHole
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
    PRODUCT_NAME="$DRIVER_NAME"
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
    ENABLE_HARDENED_RUNTIME=YES
    CONFIGURATION_BUILD_DIR="$(pwd)/build/$MODE"
)

# Add code signing configuration
if [ -n "$FINAL_CODE_SIGN_IDENTITY" ]; then
    BUILD_ARGS+=(CODE_SIGN_IDENTITY="$FINAL_CODE_SIGN_IDENTITY")
    BUILD_ARGS+=(CODE_SIGN_STYLE="Manual")
    echo "Will sign with: $FINAL_CODE_SIGN_IDENTITY"
else
    BUILD_ARGS+=(CODE_SIGN_IDENTITY="")
    BUILD_ARGS+=(CODE_SIGN_STYLE="Manual")
    echo "Building unsigned (development mode)"
fi

# Build with JoyCast customizations
xcodebuild \
    "${BUILD_ARGS[@]}" \
    "GCC_PREPROCESSOR_DEFINITIONS=\$GCC_PREPROCESSOR_DEFINITIONS $PREPROCESSOR_DEFS"

echo -e "${GREEN}Build completed!${NC}"

# Check if driver was created
DRIVER_PATH="build/$MODE/$DRIVER_NAME.driver"
if [ ! -d "$DRIVER_PATH" ]; then
    echo -e "${RED}Error: Built driver not found at $DRIVER_PATH${NC}"
    exit 1
fi

echo "Driver built successfully at: $DRIVER_PATH"

# Add JoyCast-specific resources
RESOURCES_PATH="$DRIVER_PATH/Contents/Resources"

# Copy JoyCast icon
if [ -f "assets/$PLUGIN_ICON" ]; then
    cp "assets/$PLUGIN_ICON" "$RESOURCES_PATH/"
    echo "JoyCast icon copied: $PLUGIN_ICON"
else
    echo -e "${YELLOW}Warning: $PLUGIN_ICON not found in assets/${NC}"
fi

# Add license files for GPL compliance
if [ -f "external/blackhole/LICENSE" ]; then
    cp "external/blackhole/LICENSE" "$RESOURCES_PATH/BLACKHOLE_LICENSE"
    echo "BlackHole LICENSE copied"
fi

if [ -f "LICENSE" ]; then
    cp "LICENSE" "$RESOURCES_PATH/JOYCAST_LICENSE"
    echo "JoyCast LICENSE copied"
fi

# Final signing
if [ -n "$FINAL_CODE_SIGN_IDENTITY" ]; then
    echo -e "${YELLOW}Final code signing...${NC}"
    codesign --force --sign "$FINAL_CODE_SIGN_IDENTITY" \
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