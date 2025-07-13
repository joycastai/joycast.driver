#!/usr/bin/env bash

# JoyCast Driver Uninstaller
# Simple and fast driver removal script

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== JoyCast Driver Uninstaller ===${NC}"

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: This script only works on macOS${NC}"
    exit 1
fi

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}This script requires administrator privileges${NC}"
    echo "Please run with sudo or enter your password when prompted"
    echo
    exec sudo "$0" "$@"
fi

DRIVER_PATH="/Library/Audio/Plug-Ins/HAL/JoyCast.driver"

# Check if driver exists
if [[ ! -d "$DRIVER_PATH" ]]; then
    echo -e "${YELLOW}JoyCast driver not found at $DRIVER_PATH${NC}"
    echo "Driver may already be uninstalled"
    exit 0
fi

echo -e "${YELLOW}Found JoyCast driver at: $DRIVER_PATH${NC}"

# Remove the driver
echo -e "${YELLOW}Removing JoyCast driver...${NC}"
rm -rf "$DRIVER_PATH"

# Restart CoreAudio
echo -e "${YELLOW}Restarting CoreAudio...${NC}"
killall -9 coreaudiod 2>/dev/null || true

# Wait a moment for CoreAudio to restart
sleep 2

# Verify removal
if [[ -d "$DRIVER_PATH" ]]; then
    echo -e "${RED}Error: Failed to remove driver${NC}"
    exit 1
fi

echo -e "${GREEN}✓ JoyCast driver successfully removed!${NC}"
echo -e "${GREEN}✓ CoreAudio restarted${NC}"

# Check system audio
echo -e "\n${YELLOW}Checking system audio status...${NC}"
if system_profiler SPAudioDataType | grep -q "JoyCast"; then
    echo -e "${YELLOW}Warning: JoyCast devices may still be visible in system${NC}"
    echo -e "${YELLOW}You may need to restart your computer or wait a moment${NC}"
else
    echo -e "${GREEN}✓ JoyCast driver completely removed from system${NC}"
fi

echo -e "\n${GREEN}Uninstallation complete!${NC}" 