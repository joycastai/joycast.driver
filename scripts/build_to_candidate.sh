#!/usr/bin/env bash

# JoyCast Driver Release Candidate Builder
# Creates signed and notarized PKG files for driver installation

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
SKIP_BUILD=false

usage() {
    echo "Usage: $0 [--skip-build]"
    echo "  --skip-build  - Skip driver build, use existing drivers (for development only)"
    echo ""
    echo "Creates signed and notarized PKG files for both dev and prod drivers."
    echo "Always rebuilds drivers from source by default for reproducible releases."
    echo ""
    echo "Examples:"
    echo "  $0              # Clean build and create PKG candidates (recommended)"
    echo "  $0 --skip-build # Use existing drivers (development/testing only)"
    exit "${1:-0}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
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
        if [[ "$SKIP_BUILD" = false ]]; then
            echo -e "${GRAY}Current changes will be included in this build${NC}"
        fi
    else
        echo -e "${GREEN}✓ Git working directory is clean${NC}"
    fi
    
    CURRENT_BRANCH=$(git branch --show-current)
    CURRENT_COMMIT=$(git rev-parse --short HEAD)
    echo -e "${GRAY}Building from branch: $CURRENT_BRANCH ($CURRENT_COMMIT)${NC}"
fi

# Build drivers if not skipping
if [[ "$SKIP_BUILD" = false ]]; then
    echo -e "\n${YELLOW}Building drivers from source...${NC}"
    echo -e "${GRAY}This ensures reproducible builds and clean artifacts${NC}"
    ./scripts/build.sh
else
    echo -e "\n${YELLOW}⚠️  WARNING: Skipping driver build (--skip-build flag provided)${NC}"
    echo -e "${GRAY}Using existing drivers - only recommended for development/testing${NC}"
    echo -e "${GRAY}Production releases should always rebuild from source${NC}"
fi

# Check for built drivers
echo -e "\n${YELLOW}Checking for built drivers...${NC}"
PROD_DRIVER="dist/build/JoyCast.driver"
DEV_DRIVER="dist/build/JoyCast Dev.driver"

if [[ ! -d "$PROD_DRIVER" ]]; then
    echo -e "${RED}Error: Production driver not found at $PROD_DRIVER${NC}"
    exit 1
fi

if [[ ! -d "$DEV_DRIVER" ]]; then
    echo -e "${RED}Error: Development driver not found at $DEV_DRIVER${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Production driver: $PROD_DRIVER${NC}"
echo -e "${GREEN}✓ Development driver: $DEV_DRIVER${NC}"

# Generate version (same format as build.sh)
BASE_VERSION=$(date +"%y.%-m.%-d")
VERSION="${BASE_VERSION}.0"

echo -e "\n${YELLOW}Version: $VERSION${NC}"

# Create candidate directory
echo -e "\n${YELLOW}Creating candidate directory...${NC}"
CANDIDATE_DIR="dist/candidate/$VERSION"

rm -rf "$CANDIDATE_DIR"
mkdir -p "$CANDIDATE_DIR"

echo -e "${GREEN}✓ Candidate directory: $CANDIDATE_DIR${NC}"

# Function to create PKG for a driver
create_driver_pkg() {
    local MODE="$1"
    local DRIVER_PATH="$2"
    
    echo -e "\n${BOLD}${YELLOW}=== Creating $MODE PKG ===${NC}"
    
    local DRIVER_NAME=$(basename "$DRIVER_PATH" .driver)
    if [[ "$MODE" == "dev" ]]; then
        local PKG_NAME="JoyCast_Driver_Dev-${VERSION}.pkg"
    else
        local PKG_NAME="JoyCast_Driver-${VERSION}.pkg"
    fi
    
    # Create temporary build directory outside candidate dir
    local TEMP_DIR="/tmp/joycast_pkg_build_$$_$MODE"
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
    
    # Set bundle ID based on mode
    local BUNDLE_ID
    if [[ "$MODE" == "dev" ]]; then
        BUNDLE_ID="com.joycast.virtualmic.dev.installer"
    else
        BUNDLE_ID="com.joycast.virtualmic.installer"
    fi
    
    echo -e "${GRAY}  Building PKG with pkgbuild...${NC}"
    
    # Get installer certificate name
    local INSTALLER_CERT_NAME=$(security find-identity -v -p basic | grep "Developer ID Installer" | head -1 | sed 's/.*"\(Developer ID Installer.*\)"/\1/')
    
    if [[ -z "$INSTALLER_CERT_NAME" ]]; then
        echo -e "${RED}Error: Developer ID Installer certificate not found${NC}"
        exit 1
    fi
    
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
    
    # Clean up temp directory
    rm -rf "$TEMP_DIR"
}

# Create PKGs
echo -e "\n${YELLOW}Creating PKG files...${NC}"

create_driver_pkg "prod" "$PROD_DRIVER"
PROD_PKG="$CANDIDATE_DIR/JoyCast_Driver-${VERSION}.pkg"

create_driver_pkg "dev" "$DEV_DRIVER"
DEV_PKG="$CANDIDATE_DIR/JoyCast_Driver_Dev-${VERSION}.pkg"

# Notarize PKGs (if credentials available)
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

    # Notarize both PKGs
    notarize_pkg "$PROD_PKG"
    notarize_pkg "$DEV_PKG"
else
    echo -e "\n${YELLOW}Skipping notarization (credentials not available)${NC}"
fi



echo -e "\n${BOLD}${GREEN}=== Release Candidates Created ===${NC}"
echo -e "${GREEN}Release directory:${NC} $CANDIDATE_DIR"
echo -e "${GREEN}PKG files:${NC}"
echo -e "  📦 $(basename "$PROD_PKG")"
echo -e "  📦 $(basename "$DEV_PKG")"

echo -e "\n${BLUE}Next steps:${NC}"
echo -e "  1. Test PKG installation on clean system"
echo -e "  2. Verify driver loads correctly in Audio MIDI Setup"
echo -e "  3. Test with applications that use virtual audio devices"
echo -e "  4. Upload to release distribution (if tests pass)"

echo -e "\n${GRAY}Release candidates ready for testing and distribution!${NC}" 