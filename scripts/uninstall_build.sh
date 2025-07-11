#!/usr/bin/env bash
set -euo pipefail
trap 'echo -e "\033[0;31m✖ Uninstallation failed\033[0m"' ERR

# JoyCast Driver Uninstallation Script

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${GREEN}=== JoyCast Driver Uninstallation ===${NC}"

# Environment checks
[[ "$(uname)" == "Darwin" ]] || { echo "Only macOS supported"; exit 1; }

INSTALL_PATH="/Library/Audio/Plug-Ins/HAL"
MODE="${1:-}"
DRY_RUN=false

# Check for dry-run flag
if [[ "$MODE" == "--dry-run" ]]; then
    DRY_RUN=true
    MODE="${2:-}"
    echo -e "${BLUE}DRY RUN MODE - No actual changes will be made${NC}"
fi

# Request sudo credentials once at the start
if [[ "$DRY_RUN" == "false" ]]; then
    echo -e "${BLUE}This script requires admin privileges to remove drivers${NC}"
    sudo -v
fi

# Find all JoyCast drivers - simple approach that handles spaces
DEV_DRIVERS=()
while IFS= read -r -d '' driver; do
    DEV_DRIVERS+=("$driver")
done < <(find "$INSTALL_PATH" -maxdepth 1 -name "*Dev*.driver" -print0 2>/dev/null || true)

PROD_DRIVERS=()
while IFS= read -r -d '' driver; do
    # Check if it's a JoyCast driver but not a Dev driver
    if [[ "$(basename "$driver")" == *"JoyCast"* ]] && [[ "$(basename "$driver")" != *"Dev"* ]]; then
        PROD_DRIVERS+=("$driver")
    fi
done < <(find "$INSTALL_PATH" -maxdepth 1 -name "*.driver" ! -name "*Dev*.driver" -print0 2>/dev/null || true)

# Count total drivers
TOTAL_DRIVERS=$((${#DEV_DRIVERS[@]} + ${#PROD_DRIVERS[@]}))

if [[ $TOTAL_DRIVERS -eq 0 ]]; then
    echo -e "${YELLOW}No JoyCast drivers found in system${NC}"
    exit 0
fi

# Show found drivers
echo -e "${BLUE}Found JoyCast drivers:${NC}"
if [[ ${#DEV_DRIVERS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Dev drivers:${NC}"
    for driver in "${DEV_DRIVERS[@]}"; do
        echo "  - $(basename "$driver")"
    done
fi

if [[ ${#PROD_DRIVERS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Prod drivers:${NC}"
    for driver in "${PROD_DRIVERS[@]}"; do
        echo "  - $(basename "$driver")"
    done
fi

# Determine what to remove
if [[ -n "$MODE" ]]; then
    case "$MODE" in
        "dev")
            DRIVERS_TO_REMOVE=("${DEV_DRIVERS[@]+"${DEV_DRIVERS[@]}"}")
            echo -e "${YELLOW}Removing dev drivers only${NC}"
            ;;
        "prod")
            DRIVERS_TO_REMOVE=("${PROD_DRIVERS[@]+"${PROD_DRIVERS[@]}"}")
            echo -e "${YELLOW}Removing prod drivers only${NC}"
            ;;
        "all")
            DRIVERS_TO_REMOVE=("${DEV_DRIVERS[@]+"${DEV_DRIVERS[@]}"}" "${PROD_DRIVERS[@]+"${PROD_DRIVERS[@]}"}")
            echo -e "${YELLOW}Removing all drivers${NC}"
            ;;
        *)
            echo "Usage: $0 [--dry-run] [dev|prod|all]"
            echo "  --dry-run - Test mode, no actual changes"
            echo "  dev       - Remove only dev drivers"
            echo "  prod      - Remove only prod drivers"
            echo "  all       - Remove all drivers"
            echo "  (no argument) - Interactive mode"
            exit 1
            ;;
    esac
else
    # Interactive mode
    echo -e "${BLUE}Choose what to remove:${NC}"
    echo "1) Dev drivers only"
    echo "2) Prod drivers only"
    echo "3) All drivers"
    echo "4) Cancel"
    
    read -p "Enter your choice (1-4): " choice
    
    case "$choice" in
        1)
            DRIVERS_TO_REMOVE=("${DEV_DRIVERS[@]+"${DEV_DRIVERS[@]}"}")
            echo -e "${YELLOW}Removing dev drivers${NC}"
            ;;
        2)
            DRIVERS_TO_REMOVE=("${PROD_DRIVERS[@]+"${PROD_DRIVERS[@]}"}")
            echo -e "${YELLOW}Removing prod drivers${NC}"
            ;;
        3)
            DRIVERS_TO_REMOVE=("${DEV_DRIVERS[@]+"${DEV_DRIVERS[@]}"}" "${PROD_DRIVERS[@]+"${PROD_DRIVERS[@]}"}")
            echo -e "${YELLOW}Removing all drivers${NC}"
            ;;
        4)
            echo "Cancelled"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
fi

# Remove drivers
if [[ ${#DRIVERS_TO_REMOVE[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No drivers to remove${NC}"
    exit 0
fi

# Filter out non-existent drivers
EXISTING_DRIVERS=()
for driver in "${DRIVERS_TO_REMOVE[@]}"; do
    if [[ -d "$driver" ]]; then
        EXISTING_DRIVERS+=("$driver")
        echo -e "${GREEN}Removing $(basename "$driver")${NC}"
    fi
done

if [[ ${#EXISTING_DRIVERS[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No existing drivers to remove${NC}"
    exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
    for driver in "${EXISTING_DRIVERS[@]}"; do
        echo -e "${BLUE}[DRY RUN] Would remove: $driver${NC}"
    done
else
    # Single sudo command for all drivers - no repeated password prompts
    sudo rm -rf "${EXISTING_DRIVERS[@]}"
fi

if [[ "$DRY_RUN" == "false" ]]; then
    echo -e "${YELLOW}Restarting CoreAudio…${NC}"
    sudo killall -9 coreaudiod 2>/dev/null || true
    sleep 2
fi

echo -e "${GREEN}✔ Uninstallation completed!${NC}" 