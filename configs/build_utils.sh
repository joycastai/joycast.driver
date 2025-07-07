#!/bin/bash

# Build utilities for JoyCast driver

# Function to generate preprocessor definitions from variables
generate_preprocessor_defs() {
    # Variables are now set globally by build script
    # No need to source config file
    
    # Escape spaces for shell safety
    local safe_device_name="${DEVICE_NAME// /\\ }"
    local safe_manufacturer_name="${MANUFACTURER_NAME// /\\ }"
    local safe_device2_name="${DEVICE2_NAME// /\\ }"
    
    # Generate the preprocessor definitions string
    echo "kDriver_Name=\\\"JoyCast\\\" kPlugIn_BundleID=\\\"$BUNDLE_ID\\\" kPlugIn_Icon=\\\"JoyCast.icns\\\" kManufacturer_Name=\\\"$safe_manufacturer_name\\\" kDevice_Name=\\\"$safe_device_name\\\" kDevice2_Name=\\\"$safe_device2_name\\\" kBox_UID=\\\"$BOX_UID\\\" kDevice_UID=\\\"$DEVICE_UID\\\" kDevice2_UID=\\\"$DEVICE2_UID\\\" kHas_Driver_Name_Format=false kNumber_Of_Channels=$NUMBER_OF_CHANNELS kDevice_HasInput=$DEVICE_HAS_INPUT kDevice_HasOutput=$DEVICE_HAS_OUTPUT kDevice2_HasInput=$DEVICE2_HAS_INPUT kDevice2_HasOutput=$DEVICE2_HAS_OUTPUT kDevice_IsHidden=$DEVICE_IS_HIDDEN kDevice2_IsHidden=$DEVICE2_IS_HIDDEN"
}

# Config validation is no longer needed - variables are auto-generated

# Function to get BlackHole version
get_blackhole_version() {
    if [ -d "external/blackhole/.git" ]; then
        (cd external/blackhole && git describe --tags 2>/dev/null || git rev-parse --short HEAD)
    else
        echo "unknown"
    fi
} 