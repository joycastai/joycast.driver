#!/usr/bin/env bash

# JoyCast Driver Release Script
# Creates versioned releases from current builds

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${GREEN}Creating JoyCast Driver Release${NC}"

# Change to repo root
cd "$REPO_ROOT"

# Get version from production build (or fallback to dev)
VERSION=""
if [[ -d "build/prod/JoyCast.driver" ]]; then
    VERSION=$(defaults read "$(pwd)/build/prod/JoyCast.driver/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "")
elif [[ -d "build/dev/JoyCast Dev.driver" ]]; then
    VERSION=$(defaults read "$(pwd)/build/dev/JoyCast Dev.driver/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "")
fi

if [[ -z "$VERSION" ]]; then
    echo -e "${RED}Error: No builds found or version could not be determined${NC}"
    echo "Please build the driver first: ./scripts/build_driver.sh prod"
    exit 1
fi

echo -e "${GREEN}Found version: $VERSION${NC}"

# Create release directory
RELEASE_DIR="releases/$VERSION"
if [[ -d "$RELEASE_DIR" ]]; then
    rm -rf "$RELEASE_DIR"
fi
mkdir -p "$RELEASE_DIR"

# Copy production driver if exists
if [[ -d "build/prod/JoyCast.driver" ]]; then
    cp -R "build/prod/JoyCast.driver" "$RELEASE_DIR/JoyCast-$VERSION.driver"
    echo "✓ JoyCast-$VERSION.driver"
fi

# Copy development driver if exists
if [[ -d "build/dev/JoyCast Dev.driver" ]]; then
    cp -R "build/dev/JoyCast Dev.driver" "$RELEASE_DIR/JoyCast-Dev-$VERSION.driver"
    echo "✓ JoyCast-Dev-$VERSION.driver"
fi

echo -e "${GREEN}✅ Release v$VERSION created in $RELEASE_DIR${NC}" 