#!/bin/bash

# JoyCast Driver Build Script (Clean Architecture)
# Builds JoyCast driver using BlackHole submodule with JoyCast configurations

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== JoyCast Driver Build (Clean Architecture) ===${NC}"

# Check if we're in the right directory
if [ ! -f "scripts/build_driver.sh" ]; then
    echo -e "${RED}Error: Please run this script from the repository root${NC}"
    exit 1
fi

# Check if BlackHole submodule exists
if [ ! -d "external/blackhole" ]; then
    echo -e "${RED}BlackHole submodule not found. Run: git submodule update --init${NC}"
    exit 1
fi

# Parse arguments
MODE="${1:-prod}"
if [ "$MODE" != "dev" ] && [ "$MODE" != "prod" ]; then
    echo "Usage: $0 [dev|prod]"
    echo "  dev  - Development build (unsigned)"
    echo "  prod - Production build (signed)"
    exit 1
fi

# Load utilities
source configs/build_utils.sh

# Load configuration
CONFIG_FILE="configs/joycast_${MODE}.env"
echo "Loading configuration: $CONFIG_FILE"

# Validate configuration
if ! validate_config "$CONFIG_FILE"; then
    exit 1
fi

# Source the configuration
source "$CONFIG_FILE"

# Get versions
BLACKHOLE_VERSION=$(get_blackhole_version)
JOYCAST_VERSION=$(cat VERSION 2>/dev/null | tr -d '\n' || echo "0.6.1")

echo "Build mode: $MODE"
echo "BlackHole version: $BLACKHOLE_VERSION"
echo "JoyCast version: $JOYCAST_VERSION"
echo "Driver: $DRIVER_NAME.driver"

# Generate preprocessor definitions
PREPROCESSOR_DEFS=$(generate_preprocessor_defs "$CONFIG_FILE")

echo -e "${YELLOW}Preprocessor definitions:${NC}"
echo "$PREPROCESSOR_DEFS"

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf build/
mkdir -p build/

# Build using BlackHole project but output to our build directory
echo -e "${YELLOW}Building driver...${NC}"

# Prepare build arguments
BUILD_ARGS=(
    -project external/blackhole/BlackHole.xcodeproj
    -configuration Release
    -target BlackHole
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
    PRODUCT_NAME="$DRIVER_NAME"
    MARKETING_VERSION="$JOYCAST_VERSION"
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
    MACOSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET"
    ENABLE_HARDENED_RUNTIME=YES
    CONFIGURATION_BUILD_DIR="$(pwd)/build"
)

# Add code signing configuration
if [ -n "$CODE_SIGN_IDENTITY" ]; then
    BUILD_ARGS+=(CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY")
    BUILD_ARGS+=(CODE_SIGN_STYLE="Manual")
    echo "Will sign with: $CODE_SIGN_IDENTITY"
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
DRIVER_PATH="build/$DRIVER_NAME.driver"
if [ ! -d "$DRIVER_PATH" ]; then
    echo -e "${RED}Error: Built driver not found at $DRIVER_PATH${NC}"
    exit 1
fi

echo "Driver built successfully at: $DRIVER_PATH"

# Add JoyCast-specific resources
RESOURCES_PATH="$DRIVER_PATH/Contents/Resources"

# Copy JoyCast icon
if [ -f "assets/JoyCast.icns" ]; then
    cp "assets/JoyCast.icns" "$RESOURCES_PATH/"
    echo "JoyCast icon copied"
else
    echo -e "${YELLOW}Warning: JoyCast.icns not found in assets/${NC}"
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

# Final signing for production
if [ "$MODE" == "prod" ] && [ -n "$CODE_SIGN_IDENTITY" ]; then
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
echo "BlackHole version: $BLACKHOLE_VERSION"
echo "JoyCast version: $JOYCAST_VERSION"

# Verify the build
if codesign -v "$DRIVER_PATH" 2>/dev/null; then
    echo -e "${GREEN}✓ Code signature valid${NC}"
else
    echo -e "${YELLOW}! Driver is unsigned${NC}"
fi 