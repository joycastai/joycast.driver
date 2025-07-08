#!/usr/bin/env bash

# JoyCast Driver Release Script
# Creates versioned releases with mandatory version validation

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Usage function
usage() {
    echo "Usage: $0 <VERSION>"
    echo ""
    echo "Creates releases for JoyCast driver with mandatory version validation."
    echo ""
    echo "Arguments:"
    echo "  VERSION    Version to release (e.g., 25.1.15.1)"
    echo ""
    echo "Requirements:"
    echo "  - Both prod and dev builds must exist"
    echo "  - Both builds must have the specified version"
    echo ""
    echo "Examples:"
    echo "  $0 25.1.15.1"
    echo ""
    exit "${1:-1}"
}

# Check arguments
if [[ $# -ne 1 ]]; then
    echo -e "${RED}Error: Version parameter is required${NC}"
    usage 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage 0
fi

EXPECTED_VERSION="$1"

echo -e "${GREEN}Creating JoyCast Driver Release v$EXPECTED_VERSION${NC}"

# Change to repo root
cd "$REPO_ROOT"

# Define required builds
PROD_BUILD="build/prod/JoyCast.driver"
DEV_BUILD="build/dev/JoyCast Dev.driver"

# Pre-flight checks
echo -e "\n${YELLOW}=== Pre-flight Checks ===${NC}"

PREFLIGHT_ERRORS=0

# Check if both builds exist
if [[ ! -d "$PROD_BUILD" ]]; then
    echo -e "${RED}✗ Production build not found: $PROD_BUILD${NC}"
    ((PREFLIGHT_ERRORS++))
else
    echo -e "${GREEN}✓ Production build found${NC}"
fi

if [[ ! -d "$DEV_BUILD" ]]; then
    echo -e "${RED}✗ Development build not found: $DEV_BUILD${NC}"
    ((PREFLIGHT_ERRORS++))
else
    echo -e "${GREEN}✓ Development build found${NC}"
fi

# If builds don't exist, no point in continuing
if [[ $PREFLIGHT_ERRORS -gt 0 ]]; then
    echo -e "\n${RED}Build both versions first:${NC}"
    echo "  ./scripts/build_driver.sh prod"
    echo "  ./scripts/build_driver.sh dev"
    exit 1
fi

# Check version consistency
echo -e "\n${YELLOW}=== Version Validation ===${NC}"

VERSION_ERRORS=0

# Check production version
if [[ -d "$PROD_BUILD" ]]; then
    prod_version=$(defaults read "$(pwd)/$PROD_BUILD/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "")
    if [[ "$prod_version" != "$EXPECTED_VERSION" ]]; then
        echo -e "${RED}✗ Production version mismatch: expected $EXPECTED_VERSION, got $prod_version${NC}"
        ((VERSION_ERRORS++))
    else
        echo -e "${GREEN}✓ Production version correct: $prod_version${NC}"
    fi
fi

# Check development version
if [[ -d "$DEV_BUILD" ]]; then
    dev_version=$(defaults read "$(pwd)/$DEV_BUILD/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "")
    if [[ "$dev_version" != "$EXPECTED_VERSION" ]]; then
        echo -e "${RED}✗ Development version mismatch: expected $EXPECTED_VERSION, got $dev_version${NC}"
        ((VERSION_ERRORS++))
    else
        echo -e "${GREEN}✓ Development version correct: $dev_version${NC}"
    fi
fi

# If versions don't match, abort
if [[ $VERSION_ERRORS -gt 0 ]]; then
    echo -e "\n${RED}Version validation failed!${NC}"
    echo "Update versions first:"
    echo "  ./scripts/build_driver.sh prod"
    echo "  ./scripts/build_driver.sh dev"
    exit 1
fi

# Create release directory
RELEASE_DIR="releases/$EXPECTED_VERSION"
if [[ -d "$RELEASE_DIR" ]]; then
    echo -e "\n${YELLOW}Release directory already exists, removing...${NC}"
    rm -rf "$RELEASE_DIR"
fi
mkdir -p "$RELEASE_DIR"

# Function to copy and verify driver
copy_and_verify_driver() {
    local build_path="$1"
    local release_name="$2"
    local build_type="$3"
    
    echo -e "\n${YELLOW}Processing $build_type build...${NC}"
    
    # Copy with signature preservation
    ditto "$build_path" "$RELEASE_DIR/$release_name"
    
    # Verify signature preservation
    local original_signed=false
    local copy_signed=false
    
    if codesign -v "$build_path" 2>/dev/null; then
        original_signed=true
    fi
    
    if codesign -v "$RELEASE_DIR/$release_name" 2>/dev/null; then
        copy_signed=true
    fi
    
    if [[ "$original_signed" = true && "$copy_signed" = true ]]; then
        echo -e "${GREEN}✓ $release_name copied with signature preserved${NC}"
        
        # Show signature details
        local signature_info
        signature_info=$(codesign -dv "$RELEASE_DIR/$release_name" 2>&1 | grep "Authority=" | head -1 | sed 's/^.*Authority= *//')
        if [[ -n "$signature_info" ]]; then
            echo -e "${GREEN}  Signed by: $signature_info${NC}"
        fi
    elif [[ "$original_signed" = true && "$copy_signed" = false ]]; then
        echo -e "${RED}✗ CRITICAL: Code signature lost during copy!${NC}"
        return 1
    else
        echo -e "${YELLOW}✓ $release_name copied (unsigned)${NC}"
    fi
    
    # Verify bundle structure
    local driver_path="$RELEASE_DIR/$release_name"
    
    if [[ ! -f "$driver_path/Contents/Info.plist" ]]; then
        echo -e "${RED}✗ Info.plist missing${NC}"
        return 1
    fi
    
    if [[ ! -d "$driver_path/Contents/MacOS" ]] || [[ -z "$(ls -A "$driver_path/Contents/MacOS" 2>/dev/null)" ]]; then
        echo -e "${RED}✗ Executable missing${NC}"
        return 1
    fi
    
    if [[ ! -d "$driver_path/Contents/Resources" ]]; then
        echo -e "${RED}✗ Resources directory missing${NC}"
        return 1
    fi
    
    # Final version check
    local actual_version
    actual_version=$(defaults read "$(pwd)/$driver_path/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "")
    if [[ "$actual_version" != "$EXPECTED_VERSION" ]]; then
        echo -e "${RED}✗ Version corruption during copy: expected $EXPECTED_VERSION, got $actual_version${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ $build_type verification passed${NC}"
    return 0
}

# Create releases
echo -e "\n${GREEN}=== Creating Releases ===${NC}"

RELEASE_ERRORS=0

# Copy production build
if ! copy_and_verify_driver "$PROD_BUILD" "JoyCast.driver" "Production"; then
    ((RELEASE_ERRORS++))
fi

# Copy development build
if ! copy_and_verify_driver "$DEV_BUILD" "JoyCast Dev.driver" "Development"; then
    ((RELEASE_ERRORS++))
fi

# Final status
echo -e "\n${GREEN}=== Final Status ===${NC}"
if [[ $RELEASE_ERRORS -gt 0 ]]; then
    echo -e "${RED}Release creation failed with $RELEASE_ERRORS error(s)${NC}"
    echo -e "${RED}Cleaning up incomplete release...${NC}"
    rm -rf "$RELEASE_DIR"
    exit 1
else
    echo -e "${GREEN}🎉 Release v$EXPECTED_VERSION created successfully!${NC}"
    echo -e "${GREEN}Location: $RELEASE_DIR${NC}"
    echo -e "${GREEN}Contents:${NC}"
    echo "  - JoyCast.driver (Production)"
    echo "  - JoyCast Dev.driver (Development)"
    echo -e "${GREEN}Ready for distribution${NC}"
fi 