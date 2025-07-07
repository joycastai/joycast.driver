#!/bin/bash

# Build script for JoyCast Virtual Audio Driver
# Uses BlackHole source with JoyCast customizations via preprocessor definitions

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== JoyCast Driver Build Script ===${NC}"

# Parse arguments
MODE="${1:-prod}"  # Default to prod

if [ "$MODE" != "dev" ] && [ "$MODE" != "prod" ]; then
    echo "Usage: $0 [dev|prod]"
    echo "Default: prod"
    exit 1
fi

# Set parameters based on mode
if [ "$MODE" == "dev" ]; then
    DRIVER_NAME="JoyCast Dev"
    BUNDLE_ID="com.joycast.virtualmic.dev"
    DEVICE_NAME="JoyCast Dev Virtual Microphone"
    BOX_UID="JoyCastDEV_UID"
    DEVICE_UID="JoyCast_Dev_Virtual_Microphone_UID"
    DEVICE2_UID="JoyCast_Dev_Virtual_Microphone_2_UID"
else
    DRIVER_NAME="JoyCast"
    BUNDLE_ID="com.joycast.virtualmic"
    DEVICE_NAME="JoyCast Virtual Microphone"
    BOX_UID="JoyCast_UID"
    DEVICE_UID="JoyCast_Virtual_Microphone_UID"
    DEVICE2_UID="JoyCast_Virtual_Microphone_2_UID"
fi

# Additional names  
MANUFACTURER_NAME="JoyCast Gang"
DEVICE2_NAME="JoyCast Virtual Output"

# Escape spaces for preprocessor definitions (shell-safe)
SAFE_DEVICE_NAME="${DEVICE_NAME// /\\ }"
SAFE_MANUFACTURER_NAME="${MANUFACTURER_NAME// /\\ }"
SAFE_DEVICE2_NAME="${DEVICE2_NAME// /\\ }"

# Read driver version from VERSION file
DRIVER_VERSION=$(cat VERSION 2>/dev/null | tr -d '\n')

echo "Build mode: $MODE"
echo "Driver: $DRIVER_NAME.driver"
echo "Driver version: $DRIVER_VERSION"

# Clean previous builds completely
rm -rf build/

# Ensure Xcode derived data for this project is clean (optional)

# Always sign with Developer ID Application for notarization
echo "Building unsigned version first..."
CERT_NAME="${APPLE_DEVELOPER_CERT_NAME:-Developer ID Application}"
BUILD_ARGS=(
    -project BlackHole.xcodeproj
    -configuration Release
    -target BlackHole
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
    PRODUCT_NAME="$DRIVER_NAME"
    MARKETING_VERSION="$DRIVER_VERSION"
    DEVELOPMENT_TEAM="${APPLE_TEAM_ID:-XXXXXXXXXX}"
    CODE_SIGN_IDENTITY=""
    CODE_SIGN_STYLE="Manual" 
    ENABLE_HARDENED_RUNTIME=YES
    MACOSX_DEPLOYMENT_TARGET="10.13"
)

# Build the driver using BlackHole project with JoyCast customizations
xcodebuild \
  "${BUILD_ARGS[@]}" \
  "GCC_PREPROCESSOR_DEFINITIONS=\$GCC_PREPROCESSOR_DEFINITIONS kDriver_Name=\\\"JoyCast\\\" kPlugIn_BundleID=\\\"$BUNDLE_ID\\\" kPlugIn_Icon=\\\"JoyCast.icns\\\" kManufacturer_Name=\\\"$SAFE_MANUFACTURER_NAME\\\" kDevice_Name=\\\"$SAFE_DEVICE_NAME\\\" kDevice2_Name=\\\"$SAFE_DEVICE2_NAME\\\" kBox_UID=\\\"$BOX_UID\\\" kDevice_UID=\\\"$DEVICE_UID\\\" kDevice2_UID=\\\"$DEVICE2_UID\\\" kHas_Driver_Name_Format=false kNumber_Of_Channels=2 kDevice_HasInput=true kDevice_HasOutput=false kDevice2_HasInput=true kDevice2_HasOutput=false kDevice_IsHidden=false kDevice2_IsHidden=true"

echo -e "${GREEN}Build complete (unsigned)!${NC}"
echo "Driver location: build/Release/$DRIVER_NAME.driver"

# Add LICENSE.txt for GPL compliance (before signing)
echo -e "${YELLOW}Adding LICENSE.txt for GPL compliance...${NC}"
DRIVER_PATH="build/Release/$DRIVER_NAME.driver"
RESOURCES_PATH="$DRIVER_PATH/Contents/Resources"

if [ -f "LICENSE.txt" ]; then
    cp "LICENSE.txt" "$RESOURCES_PATH/"
    echo "LICENSE.txt copied to driver Resources"
    
    # Now sign the driver with LICENSE.txt included
    echo "Signing driver with LICENSE.txt included..."
    codesign --force --sign "$CERT_NAME" \
             --options=runtime \
             --timestamp \
             "$DRIVER_PATH"
    
    echo -e "${GREEN}Driver signed successfully${NC}"
else
    echo -e "${RED}Warning: LICENSE.txt not found in repository root${NC}"
    # Still sign the driver even without LICENSE.txt
    codesign --force --sign "$CERT_NAME" \
             --options=runtime \
             --timestamp \
             "$DRIVER_PATH"
fi

# Create install script
cat > install_joycast_driver.sh << EOF
#!/bin/bash

# Install JoyCast Virtual Audio Driver

set -e

DRIVER_NAME="$DRIVER_NAME.driver"
DRIVER_PATH="build/Release/\$DRIVER_NAME"
INSTALL_PATH="/Library/Audio/Plug-Ins/HAL"

if [ ! -d "\$DRIVER_PATH" ]; then
    echo "Error: Driver not found at \$DRIVER_PATH"
    echo "Please run build_joycast.driver first"
    exit 1
fi

echo "Installing JoyCast Virtual Audio Driver..."

# Check if we need sudo
if [ -w "\$INSTALL_PATH" ]; then
    cp -R "\$DRIVER_PATH" "\$INSTALL_PATH/"
else
    echo "Administrator privileges required for installation"
    sudo cp -R "\$DRIVER_PATH" "\$INSTALL_PATH/"
fi

echo "Restarting CoreAudio..."
sudo killall -9 coreaudiod 2>/dev/null || true

echo "Installation complete!"
echo "$DRIVER_NAME Virtual Microphone should now appear in your audio devices"
EOF

chmod +x install_joycast_driver.sh

echo -e "${GREEN}Created install_joycast_driver.sh script${NC}" 