#!/bin/bash

# JoyCast Driver Installation Script

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== JoyCast Driver Installation ===${NC}"

# Check if we're in the right directory
if [ ! -f "scripts/install_driver.sh" ]; then
    echo -e "${RED}Error: Please run this script from the repository root${NC}"
    exit 1
fi

# Parse arguments
MODE="${1:-prod}"
if [ "$MODE" != "dev" ] && [ "$MODE" != "prod" ]; then
    echo "Usage: $0 [dev|prod]"
    echo "  dev  - Install development driver"
    echo "  prod - Install production driver"
    exit 1
fi

# Load configuration to get driver name
source "configs/joycast_${MODE}.env"

DRIVER_PATH="build/$DRIVER_NAME.driver"
INSTALL_PATH="/Library/Audio/Plug-Ins/HAL"

# Check if driver is built
if [ ! -d "$DRIVER_PATH" ]; then
    echo -e "${RED}Error: Driver not found at $DRIVER_PATH${NC}"
    echo "Please run: ./scripts/build_driver.sh $MODE"
    exit 1
fi

echo "Installing $DRIVER_NAME.driver..."
echo "Source: $DRIVER_PATH"
echo "Destination: $INSTALL_PATH"

# Check if we need sudo
if [ -w "$INSTALL_PATH" ]; then
    echo "Installing driver..."
    cp -R "$DRIVER_PATH" "$INSTALL_PATH/"
else
    echo "Administrator privileges required for installation"
    sudo cp -R "$DRIVER_PATH" "$INSTALL_PATH/"
fi

# Set proper permissions
echo "Setting permissions..."
sudo chown -R root:wheel "$INSTALL_PATH/$DRIVER_NAME.driver"
sudo chmod -R 755 "$INSTALL_PATH/$DRIVER_NAME.driver"

echo "Restarting CoreAudio..."
sudo killall -9 coreaudiod 2>/dev/null || true

# Wait a moment for CoreAudio to restart
sleep 2

echo -e "${GREEN}Installation complete!${NC}"
echo "$DRIVER_NAME should now appear in your audio devices"
echo ""
echo "To verify installation:"
echo "  - Open Audio MIDI Setup"
echo "  - Look for '$DEVICE_NAME' in the device list"
echo ""
echo "To uninstall:"
echo "  sudo rm -rf '$INSTALL_PATH/$DRIVER_NAME.driver'"
echo "  sudo killall -9 coreaudiod" 