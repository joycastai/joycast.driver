#!/usr/bin/env bash
set -euo pipefail
trap 'echo -e "\033[0;31m✖ Installation failed\033[0m"' ERR

# JoyCast Driver Installation Script

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${GREEN}=== JoyCast Driver Installation ===${NC}"

# Environment checks
[[ "$(uname)" == "Darwin" ]] || { echo "Only macOS supported"; exit 1; }

# Check if we're in the right directory
[[ -f "scripts/install_driver.sh" ]] || { echo -e "${RED}Error: Please run this script from the repository root${NC}"; exit 1; }

MODE="${1:-prod}"
[[ "$MODE" =~ ^(dev|prod)$ ]] || { echo "Usage: $0 [dev|prod]"; exit 1; }

source "configs/driver.env" || { echo "configs/driver.env not found"; exit 1; }

DRIVER_NAME="$BASE_NAME"
[[ "$MODE" == "dev" ]] && DRIVER_NAME+=" Dev"
DRIVER_PATH="build/$MODE/$DRIVER_NAME.driver"
INSTALL_PATH="/Library/Audio/Plug-Ins/HAL"

[[ -d "$DRIVER_PATH" ]] || { echo -e "${RED}Driver not found: $DRIVER_PATH${NC}"; exit 1; }

echo -e "${GREEN}Installing $DRIVER_NAME.driver → $INSTALL_PATH${NC}"

sudo install -d "$INSTALL_PATH"
[[ -d "$INSTALL_PATH/$DRIVER_NAME.driver" ]] && \
  sudo mv "$INSTALL_PATH/$DRIVER_NAME.driver" "$INSTALL_PATH/$DRIVER_NAME.driver.$(date +%Y%m%d%H%M%S).bak"

# Verify signature
codesign --verify --deep --strict "$DRIVER_PATH"

sudo cp -R "$DRIVER_PATH" "$INSTALL_PATH/"
sudo chown -R root:wheel "$INSTALL_PATH/$DRIVER_NAME.driver"
sudo chmod -R 755 "$INSTALL_PATH/$DRIVER_NAME.driver"

echo -e "${YELLOW}Restarting CoreAudio…${NC}"
sudo killall -9 coreaudiod 2>/dev/null || true
sleep 2
echo -e "${GREEN}✔ Done!${NC}"