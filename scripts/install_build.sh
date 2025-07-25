#!/usr/bin/env bash
set -euo pipefail
trap 'echo -e "\033[0;31m✖ Installation failed\033[0m"' ERR

# JoyCast Driver Installation Script

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'

# Parse arguments
usage() {
    echo "Usage: $0 [--help]"
    echo ""
    echo "Installs JoyCast driver from dist/build/ directory."
    echo ""
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0            # Install driver from dist/build/"
    exit "${1:-0}"
}

# Check for help flag
case "${1:-}" in
    --help|-h|help)
        usage 0
        ;;
    "")
        # No arguments, proceed normally
        ;;
    *)
        echo -e "${RED}Error: Unknown argument '$1'${NC}"
        usage 1
        ;;
esac

echo -e "${GREEN}=== JoyCast Driver Installation ===${NC}"

# Environment checks
[[ "$(uname)" == "Darwin" ]] || { echo "Only macOS supported"; exit 1; }

# Check if we're in the right directory
[[ -f "scripts/install_build.sh" ]] || { echo -e "${RED}Error: Please run this script from the repository root${NC}"; exit 1; }

# Find driver in dist/build directory
[[ -d "dist/build" ]] || { echo -e "${RED}Build directory not found${NC}"; exit 1; }

DRIVER_PATH=$(find dist/build -maxdepth 1 -name "*.driver" | head -1)

[[ -n "$DRIVER_PATH" ]] || { echo -e "${RED}No driver found in build directory${NC}"; exit 1; }

# Extract driver name from path
DRIVER_NAME=$(basename "$DRIVER_PATH" .driver)

INSTALL_PATH="/Library/Audio/Plug-Ins/HAL"

echo -e "${GREEN}Installing $DRIVER_NAME.driver → $INSTALL_PATH${NC}"

sudo install -d "$INSTALL_PATH"

# Remove existing driver if present
[[ -d "$INSTALL_PATH/$DRIVER_NAME.driver" ]] && \
  sudo rm -rf "$INSTALL_PATH/$DRIVER_NAME.driver"

# Verify signature
codesign --verify --deep --strict "$DRIVER_PATH"

sudo cp -R "$DRIVER_PATH" "$INSTALL_PATH/"
sudo chown -R root:wheel "$INSTALL_PATH/$DRIVER_NAME.driver"
sudo chmod -R 755 "$INSTALL_PATH/$DRIVER_NAME.driver"

echo -e "${YELLOW}Restarting CoreAudio…${NC}"
sudo killall -9 coreaudiod 2>/dev/null || true
sleep 2
echo -e "${GREEN}✔ Done!${NC}"