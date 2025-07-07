#!/bin/bash

# Install JoyCast Virtual Audio Driver

set -e

DRIVER_NAME="JoyCast Dev.driver"
DRIVER_PATH="build/Release/$DRIVER_NAME"
INSTALL_PATH="/Library/Audio/Plug-Ins/HAL"

if [ ! -d "$DRIVER_PATH" ]; then
    echo "Error: Driver not found at $DRIVER_PATH"
    echo "Please run build_joycast.driver first"
    exit 1
fi

echo "Installing JoyCast Virtual Audio Driver..."

# Check if we need sudo
if [ -w "$INSTALL_PATH" ]; then
    cp -R "$DRIVER_PATH" "$INSTALL_PATH/"
else
    echo "Administrator privileges required for installation"
    sudo cp -R "$DRIVER_PATH" "$INSTALL_PATH/"
fi

echo "Restarting CoreAudio..."
sudo killall -9 coreaudiod 2>/dev/null || true

echo "Installation complete!"
echo "JoyCast Dev Virtual Microphone should now appear in your audio devices"
