#!/usr/bin/env bash

# JoyCast Driver Release Script - Simple version
# Takes existing builds and packages them for release

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== JoyCast Driver Release ===${NC}"

# Check that builds exist
PROD_BUILD="build/JoyCast.driver"
DEV_BUILD="build/JoyCast Dev.driver"

if [[ ! -d "$PROD_BUILD" ]]; then
    echo -e "${RED}✗ Production build not found: $PROD_BUILD${NC}"
    echo "Run: scripts/build_driver.sh"
    exit 1
fi

if [[ ! -d "$DEV_BUILD" ]]; then
    echo -e "${RED}✗ Development build not found: $DEV_BUILD${NC}"
    echo "Run: scripts/build_driver.sh"
    exit 1
fi

# Read versions from both builds
PROD_VERSION=$(defaults read "$(pwd)/$PROD_BUILD/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "")
DEV_VERSION=$(defaults read "$(pwd)/$DEV_BUILD/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "")

if [[ -z "$PROD_VERSION" ]]; then
    echo -e "${RED}✗ Cannot read version from $PROD_BUILD${NC}"
    exit 1
fi

if [[ -z "$DEV_VERSION" ]]; then
    echo -e "${RED}✗ Cannot read version from $DEV_BUILD${NC}"
    exit 1
fi

if [[ "$PROD_VERSION" != "$DEV_VERSION" ]]; then
    echo -e "${RED}✗ Version mismatch!${NC}"
    echo -e "${RED}  Production: $PROD_VERSION${NC}"
    echo -e "${RED}  Development: $DEV_VERSION${NC}"
    exit 1
fi

VERSION="$PROD_VERSION"
echo -e "${GREEN}✓ Both drivers have version: $VERSION${NC}"

# Create release directory
RELEASE_DIR="releases/$VERSION"
if [[ -d "$RELEASE_DIR" ]]; then
    echo -e "${YELLOW}Removing existing release $VERSION${NC}"
    rm -rf "$RELEASE_DIR"
fi
mkdir -p "$RELEASE_DIR"

# Copy builds
echo -e "${YELLOW}Copying builds to $RELEASE_DIR${NC}"
cp -R "$PROD_BUILD" "$RELEASE_DIR/"
cp -R "$DEV_BUILD" "$RELEASE_DIR/"

# Verify
echo -e "${YELLOW}Verifying release${NC}"
if [[ ! -d "$RELEASE_DIR/JoyCast.driver" ]]; then
    echo -e "${RED}✗ Production copy failed${NC}"
    exit 1
fi

if [[ ! -d "$RELEASE_DIR/JoyCast Dev.driver" ]]; then
    echo -e "${RED}✗ Development copy failed${NC}"
    exit 1
fi

# Check signatures
if codesign -v "$RELEASE_DIR/JoyCast.driver" 2>/dev/null; then
    echo -e "${GREEN}✓ Production signature OK${NC}"
else
    echo -e "${YELLOW}⚠ Production not signed${NC}"
fi

if codesign -v "$RELEASE_DIR/JoyCast Dev.driver" 2>/dev/null; then
    echo -e "${GREEN}✓ Development signature OK${NC}"
else
    echo -e "${YELLOW}⚠ Development not signed${NC}"
fi

echo -e "${GREEN}🎉 Release $VERSION created successfully!${NC}"
echo -e "${GREEN}Location: $RELEASE_DIR${NC}" 