#!/bin/bash

# Build utilities for JoyCast driver

# Function to generate preprocessor definitions from config
generate_preprocessor_defs() {
    local config_file="$1"
    
    # Source the config file
    source "$config_file"
    
    # Escape spaces for shell safety
    local safe_device_name="${DEVICE_NAME// /\\ }"
    local safe_manufacturer_name="${MANUFACTURER_NAME// /\\ }"
    local safe_device2_name="${DEVICE2_NAME// /\\ }"
    
    # Generate the preprocessor definitions string
    echo "kDriver_Name=\\\"JoyCast\\\" kPlugIn_BundleID=\\\"$BUNDLE_ID\\\" kPlugIn_Icon=\\\"JoyCast.icns\\\" kManufacturer_Name=\\\"$safe_manufacturer_name\\\" kDevice_Name=\\\"$safe_device_name\\\" kDevice2_Name=\\\"$safe_device2_name\\\" kBox_UID=\\\"$BOX_UID\\\" kDevice_UID=\\\"$DEVICE_UID\\\" kDevice2_UID=\\\"$DEVICE2_UID\\\" kHas_Driver_Name_Format=false kNumber_Of_Channels=$NUMBER_OF_CHANNELS kDevice_HasInput=$DEVICE_HAS_INPUT kDevice_HasOutput=$DEVICE_HAS_OUTPUT kDevice2_HasInput=$DEVICE2_HAS_INPUT kDevice2_HasOutput=$DEVICE2_HAS_OUTPUT kDevice_IsHidden=$DEVICE_IS_HIDDEN kDevice2_IsHidden=$DEVICE2_IS_HIDDEN"
}

# Function to validate config file
validate_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file $config_file not found"
        return 1
    fi
    
    # Source and check required variables
    source "$config_file"
    
    local required_vars=(
        "DRIVER_NAME"
        "BUNDLE_ID" 
        "DEVICE_NAME"
        "DEVICE2_NAME"
        "MANUFACTURER_NAME"
        "BOX_UID"
        "DEVICE_UID"
        "DEVICE2_UID"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "Error: Required variable $var not set in $config_file"
            return 1
        fi
    done
    
    echo "Configuration validated successfully"
    return 0
}

# Function to get BlackHole version
get_blackhole_version() {
    if [ -d "external/blackhole/.git" ]; then
        (cd external/blackhole && git describe --tags 2>/dev/null || git rev-parse --short HEAD)
    else
        echo "unknown"
    fi
} 