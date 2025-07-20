#!/usr/bin/env bash

# JoyCast Driver Release Candidate Builder
# Creates signed and notarized PKG files for driver installation

set -euo pipefail
IFS=$'\n\t'

# Cleanup function
cleanup() {
    echo -e "\033[0m" >&2
    # Clean up any temporary directories
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
    # Also clean up any other temp directories from this process
    rm -rf /tmp/joycast_pkg_build_$$ /tmp/joycast_pkg_build_$$_* 2>/dev/null || true
}

trap cleanup ERR EXIT

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
    echo "Usage: $0"
    echo ""
    echo "Creates signed and notarized PKG file for production driver."
    echo "Always rebuilds driver from source for reproducible releases."
    echo ""
    echo "Examples:"
    echo "  $0              # Clean build and create PKG candidate"
    exit "${1:-0}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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

echo -e "${BOLD}${BLUE}=== JoyCast Driver Release Candidate Builder ===${NC}"

# Environment checks
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: This script only works on macOS${NC}"
    exit 1
fi

if ! command -v pkgbuild >/dev/null 2>&1; then
    echo -e "${RED}Error: pkgbuild not found. Please install Xcode Command Line Tools.${NC}"
    exit 1
fi

if ! command -v productbuild >/dev/null 2>&1; then
    echo -e "${RED}Error: productbuild not found. Please install Xcode Command Line Tools.${NC}"
    exit 1
fi

# Check if we're in the right directory
if [[ ! -f "scripts/build_to_candidate.sh" ]]; then
    echo -e "${RED}Error: Please run this script from the repository root${NC}"
    exit 1
fi

# Load code signing credentials
CREDENTIALS_FILE="configs/credentials.env"
if [[ -f "$CREDENTIALS_FILE" ]]; then
    echo -e "${YELLOW}Loading credentials: $CREDENTIALS_FILE${NC}"
    source "$CREDENTIALS_FILE"
else
    echo -e "${RED}Error: $CREDENTIALS_FILE not found. Code signing required for PKG creation.${NC}"
    exit 1
fi

# Validate required credentials for signing
if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
    echo -e "${RED}Error: Missing required signing credentials!${NC}"
    echo "Make sure configs/credentials.env contains:"
    echo "  APPLE_TEAM_ID=your_team_id"
    echo "  DEVELOPER_NAME=your_name"
    exit 1
fi

if [[ -z "${DEVELOPER_NAME:-}" ]]; then
    echo -e "${RED}Error: Missing required signing credentials!${NC}"
    echo "Make sure configs/credentials.env contains:"
    echo "  APPLE_TEAM_ID=your_team_id"
    echo "  DEVELOPER_NAME=your_name"
    exit 1
fi

# Certificate names (same as in main joycast repo)
CODE_SIGN_CERT_NAME="Developer ID Application: $DEVELOPER_NAME ($APPLE_TEAM_ID)"
INSTALLER_CERT_NAME="Developer ID Installer: $DEVELOPER_NAME ($APPLE_TEAM_ID)"

# Check if notarization credentials are available
ENABLE_NOTARIZATION=false
if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    ENABLE_NOTARIZATION=true
    echo -e "${GREEN}✓ Notarization credentials found${NC}"
else
    echo -e "${YELLOW}⚠ Notarization credentials not found, PKGs will be signed but not notarized${NC}"
    echo "  Add APPLE_ID and APPLE_APP_PASSWORD to configs/credentials.env for notarization"
fi

# Check for installer certificate
if ! security find-identity -v -p basic | grep -q "Developer ID Installer"; then
    echo -e "${RED}Error: Developer ID Installer certificate not found${NC}"
    echo "Required for signing PKG files"
    exit 1
fi

# Check Git status for clean builds (warning only)
if [[ -d ".git" ]]; then
    echo -e "\n${YELLOW}Checking Git status...${NC}"
    if [[ -n "$(git status --porcelain)" ]]; then
        echo -e "${YELLOW}⚠️  WARNING: Uncommitted changes detected${NC}"
        echo -e "${GRAY}For production releases, commit all changes first${NC}"
        echo -e "${GRAY}Current changes will be included in this build${NC}"
    else
        echo -e "${GREEN}✓ Git working directory is clean${NC}"
    fi
    
    CURRENT_BRANCH=$(git branch --show-current)
    CURRENT_COMMIT=$(git rev-parse --short HEAD)
    echo -e "${GRAY}Building from branch: $CURRENT_BRANCH ($CURRENT_COMMIT)${NC}"
fi

# Build driver from source
echo -e "\n${YELLOW}Building driver from source...${NC}"
echo -e "${GRAY}This ensures reproducible builds and clean artifacts${NC}"
./scripts/build.sh

# Check for built driver
echo -e "\n${YELLOW}Checking for built driver...${NC}"

# Find driver in dist/build directory (more flexible approach)
PROD_DRIVER=$(find dist/build -maxdepth 1 -name "*.driver" | head -1)

if [[ -z "$PROD_DRIVER" ]]; then
    echo -e "${RED}Error: No driver found in dist/build directory${NC}"
    exit 1
fi

if [[ ! -d "$PROD_DRIVER" ]]; then
    echo -e "${RED}Error: Production driver not found at $PROD_DRIVER${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Production driver: $PROD_DRIVER${NC}"

# Get version from built driver's Info.plist
echo -e "\n${YELLOW}Getting version from built driver...${NC}"
VERSION=$(plutil -p "$PROD_DRIVER/Contents/Info.plist" | grep "CFBundleShortVersionString" | sed 's/.*=> "\(.*\)"/\1/')

if [[ -z "$VERSION" ]]; then
    echo -e "${RED}Error: Could not extract version from driver${NC}"
    exit 1
fi

# Validate version format (YY.M.D.0)
if ! [[ "$VERSION" =~ ^[0-9]{2}\.[0-9]{1,2}\.[0-9]{1,2}\.0$ ]]; then
    echo -e "${RED}Error: Version '$VERSION' does not match expected format YY.M.D.0${NC}"
    echo -e "${GRAY}Expected format: YY.M.D.0 (e.g., 25.7.20.0)${NC}"
    exit 1
fi

echo -e "${YELLOW}Version: $VERSION${NC}"

# Create candidate directory
echo -e "\n${YELLOW}Creating candidate directory...${NC}"
CANDIDATE_DIR="dist/candidate"

rm -rf "$CANDIDATE_DIR"
mkdir -p "$CANDIDATE_DIR"

echo -e "${GREEN}✓ Candidate directory: $CANDIDATE_DIR${NC}"

# Function to create PKG for a driver
create_driver_pkg() {
    local DRIVER_PATH="$1"
    
    echo -e "\n${BOLD}${YELLOW}=== Creating PKG ===${NC}"
    
    local DRIVER_NAME=$(basename "$DRIVER_PATH" .driver)
    local PKG_NAME="JoyCast.driver-$VERSION.pkg"
    
    # Create temporary build directory outside candidate dir
    local TEMP_DIR="/tmp/joycast_pkg_build_$$"
    mkdir -p "$TEMP_DIR/payload/Library/Audio/Plug-Ins/HAL"
    
    # Copy driver to payload
    echo -e "${GRAY}  Copying driver to payload...${NC}"
    cp -R "$DRIVER_PATH" "$TEMP_DIR/payload/Library/Audio/Plug-Ins/HAL/"
    
    # Create scripts directory
    mkdir -p "$TEMP_DIR/scripts"
    
    # Create preinstall script
    cat > "$TEMP_DIR/scripts/preinstall" << 'EOF'
#!/bin/bash
# Preinstall script for JoyCast Driver
set -e

# Check if old driver exists and remove it
DRIVER_NAME="DRIVER_NAME_PLACEHOLDER"
HAL_PATH="/Library/Audio/Plug-Ins/HAL"

if [[ -d "$HAL_PATH/$DRIVER_NAME.driver" ]]; then
    echo "Removing existing $DRIVER_NAME.driver..."
    rm -rf "$HAL_PATH/$DRIVER_NAME.driver"
fi

exit 0
EOF

    # Create postinstall script
    cat > "$TEMP_DIR/scripts/postinstall" << 'EOF'
#!/bin/bash
# Postinstall script for JoyCast Driver
set -e

DRIVER_NAME="DRIVER_NAME_PLACEHOLDER"
HAL_PATH="/Library/Audio/Plug-Ins/HAL"

# Set proper permissions
echo "Setting permissions for $DRIVER_NAME.driver..."
chown -R root:wheel "$HAL_PATH/$DRIVER_NAME.driver"
chmod -R 755 "$HAL_PATH/$DRIVER_NAME.driver"

# Restart CoreAudio to load the new driver
echo "Restarting CoreAudio..."
killall -9 coreaudiod 2>/dev/null || true

# Wait a moment for CoreAudio to restart
sleep 2

echo "$DRIVER_NAME.driver installed successfully!"
exit 0
EOF

    # Replace placeholder with actual driver name
    sed -i '' "s/DRIVER_NAME_PLACEHOLDER/$DRIVER_NAME/g" "$TEMP_DIR/scripts/preinstall"
    sed -i '' "s/DRIVER_NAME_PLACEHOLDER/$DRIVER_NAME/g" "$TEMP_DIR/scripts/postinstall"
    
    # Make scripts executable
    chmod +x "$TEMP_DIR/scripts/"*
    
    # Set bundle ID
    local BUNDLE_ID="com.joycast.driver.installer"
    
    echo -e "${GRAY}  Building PKG with pkgbuild...${NC}"
    
    # Use installer certificate from credentials
    echo -e "${GRAY}  Using installer certificate: $INSTALLER_CERT_NAME${NC}"
    
    # Build PKG directly in candidate directory
    pkgbuild \
        --root "$TEMP_DIR/payload" \
        --install-location "/" \
        --scripts "$TEMP_DIR/scripts" \
        --identifier "$BUNDLE_ID" \
        --version "$VERSION" \
        --sign "$INSTALLER_CERT_NAME" \
        "$CANDIDATE_DIR/$PKG_NAME"
    
    echo -e "${GREEN}✓ PKG created: $PKG_NAME${NC}"
}

# Create PKG
echo -e "\n${YELLOW}Creating PKG file...${NC}"

create_driver_pkg "$PROD_DRIVER"
PROD_PKG="$CANDIDATE_DIR/JoyCast.driver-$VERSION.pkg"

# Notarize PKG (if credentials available)
if [[ "$ENABLE_NOTARIZATION" = true ]]; then
    echo -e "\n${YELLOW}Notarizing PKG files...${NC}"

    notarize_pkg() {
        local PKG_PATH="$1"
        local PKG_NAME=$(basename "$PKG_PATH")
        
        echo -e "${GRAY}  Notarizing $PKG_NAME...${NC}"
        
        # Submit for notarization
        xcrun notarytool submit "$PKG_PATH" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_APP_PASSWORD" \
            --team-id "$APPLE_TEAM_ID" \
            --wait
        
        # Staple the notarization
        xcrun stapler staple "$PKG_PATH"
        
        echo -e "${GREEN}✓ $PKG_NAME notarized and stapled${NC}"
    }

    # Notarize PKG
    notarize_pkg "$PROD_PKG"
else
    echo -e "\n${YELLOW}Skipping notarization (credentials not available)${NC}"
fi



echo -e "\n${BOLD}${GREEN}=== Release Candidate Created ===${NC}"
echo -e "${GREEN}Release directory:${NC} $CANDIDATE_DIR"
echo -e "${GREEN}PKG file:${NC}"
echo -e "  📦 $(basename "$PROD_PKG")"

# Display file size and checksum
PKG_SIZE=$(ls -lh "$PROD_PKG" | awk '{print $5}')
PKG_SHA256=$(shasum -a 256 "$PROD_PKG" | awk '{print $1}')
echo -e "${GREEN}File size:${NC} $PKG_SIZE"
echo -e "${GREEN}SHA-256:${NC} $PKG_SHA256"

echo -e "\n${BLUE}Next steps:${NC}"
echo -e "  1. Test PKG installation on clean system"
echo -e "  2. Verify driver loads correctly in Audio MIDI Setup"
echo -e "  3. Test with applications that use virtual audio devices"
echo -e "  4. Upload to release distribution (if tests pass)"

echo -e "\n${GRAY}Release candidate ready for testing and distribution!${NC}" 