# JoyCast Virtual Audio Driver

JoyCast is a virtual audio driver for macOS based on BlackHole, designed to provide high-quality virtual microphone functionality with clean dev/prod separation.

## ✨ Recent Updates

- **✅ Universal Architecture** - Native support for Intel and Apple Silicon (arm64 + x86_64)
- **✅ Strict Environment Validation** - Automatic checks for macOS, Xcode, and code signing certificates
- **✅ Reproducible Builds** - BlackHole commit SHA tracked for build reproducibility
- **✅ Enhanced Installation** - Automatic backup, signature verification, and safe CoreAudio restart
- **✅ Production-Ready Security** - All builds require code signing (no unsigned drivers)
- **✅ Improved Build Scripts** - Strict bash flags, better error handling, and enhanced logging

## Architecture

This project uses a clean submodule architecture:

- **BlackHole** (`external/blackhole/`) - Core audio driver functionality (GPL-3.0 licensed)
- **JoyCast** (this repo) - Minimal configuration and build tooling

### Why This Architecture?

- ✅ **Zero source modifications** - BlackHole code remains completely untouched
- ✅ **Automatic updates** - Build script auto-updates to latest BlackHole
- ✅ **Clean builds** - All artifacts in separate `build/dev/` and `build/prod/` directories, submodule stays clean
- ✅ **Minimal configuration** - Single config file with auto-generated dev/prod differences
- ✅ **Universal compatibility** - Native support for Intel and Apple Silicon Macs
- ✅ **Reproducible builds** - BlackHole commit SHA tracked for consistent results

## Quick Start

### Prerequisites

- **macOS 10.13+** (build environment requirement)
- **Xcode or Xcode Command Line Tools** 
- **Apple Developer certificate** (Required - all builds are signed)
- **Apple Team ID** (Required for code signing)

### Code Signing Setup

Create `configs/credentials.env`:
```bash
# Apple Developer Team ID
APPLE_TEAM_ID="XXXXXXXXXX"

# Code Signing Certificate Name
CODE_SIGN_CERT_NAME="Developer ID Application: Your Name (XXXXXXXXXX)"
```

### Build and Install

```bash
# Clone with submodules
git clone --recursive https://github.com/your-org/joycast.driver.git
cd joycast.driver

# Build production driver (auto-updates BlackHole, signed)
./scripts/build_driver.sh prod

# Install driver (requires admin privileges)
./scripts/install_driver.sh prod

# Build dev driver (auto-updates BlackHole, signed)
./scripts/build_driver.sh dev

# Install development version (requires admin privileges)
./scripts/install_driver.sh dev
```

## Configuration

**Single configuration file**: `configs/driver.env`

Contains all [BlackHole customization parameters](https://github.com/ExistentialAudio/BlackHole):

### Core Driver Parameters
- `BASE_NAME` - Driver name (JoyCast)
- `BASE_BUNDLE_ID` - Bundle identifier
- `PLUGIN_ICON` - Driver icon file
- `MANUFACTURER_NAME` - Manufacturer display name

### Device Configuration  
- `BASE_DEVICE_NAME` / `BASE_DEVICE2_NAME` - Device display names
- `DEVICE_IS_HIDDEN` / `DEVICE2_IS_HIDDEN` - Device visibility
- `DEVICE_HAS_INPUT` / `DEVICE2_HAS_INPUT` - Input capabilities
- `DEVICE_HAS_OUTPUT` / `DEVICE2_HAS_OUTPUT` - Output capabilities

### Audio Parameters
- `NUMBER_OF_CHANNELS` - Channel count (2)
- `LATENCY_FRAME_SIZE` - Latency in frames (0 = zero latency)
- `SAMPLE_RATES` - Supported sample rates (48000)

### Build Differences
The build script automatically generates dev/prod differences:
- **dev**: Adds "Dev" suffixes, ".dev" bundle IDs  
- **prod**: Clean names and bundle IDs

### Resulting Audio Devices
After installation, you'll see these devices in **System Preferences > Sound**:

**Production Build:**
- `JoyCast Virtual Microphone` (2 channels, 48kHz)

**Development Build:**  
- `JoyCast Dev Virtual Microphone` (2 channels, 48kHz)

Both devices can run simultaneously without conflicts, allowing seamless testing and production use.

## Project Structure

```
joycast.driver/
├── external/blackhole/  # Git submodule (always clean)
├── configs/
│   ├── driver.env       # Single configuration file
│   └── credentials.env  # Code signing credentials
├── scripts/
│   ├── build_driver.sh  # Self-contained build script
│   └── install_driver.sh
├── assets/
│   └── joycast.icns     # Custom icon
├── build/               # Build outputs (gitignored)
│   ├── dev/             # Development builds
│   └── prod/            # Production builds
├── LICENSE              
└── README.md
```

## Build Outputs

All build outputs are generated in separate directories to avoid conflicts:

```
build/
├── dev/
│   ├── JoyCast Dev.driver      # Development driver (universal binary)
│   └── JoyCast Dev.driver.dSYM # Debug symbols for dev
└── prod/
    ├── JoyCast.driver          # Production driver (universal binary)
    └── JoyCast.driver.dSYM     # Debug symbols for prod
```

This structure allows you to:
- Keep both dev and prod builds simultaneously
- Switch between versions quickly without rebuilding
- Compare outputs between different configurations
- Support both Intel and Apple Silicon Macs with single binary

## Build Script Options

### `./scripts/build_driver.sh [mode] [flags]`

**Modes:**
- `dev` - Development build with "Dev" suffixes
- `prod` - Production build with clean names (default)

**Flags:**
- `--no-update` - Skip BlackHole submodule update
- `--help` - Show usage information

**Examples:**
```bash
./scripts/build_driver.sh dev                    # Dev build, latest BlackHole, signed
./scripts/build_driver.sh prod --no-update      # Prod build, current BlackHole, signed  
```

### Build Features

- **Universal Binaries**: All builds support both Intel and Apple Silicon
- **Reproducible Builds**: BlackHole commit SHA displayed for consistency
- **Strict Validation**: Automatic checks for macOS, Xcode, and credentials
- **Safe Builds**: Comprehensive error handling and cleanup

## Installation Script Features

### `./scripts/install_driver.sh [mode]`

**Modes:**
- `dev` - Install development driver
- `prod` - Install production driver (default)

**Features:**
- **Automatic Backup**: Creates timestamped backups of existing drivers
- **Signature Verification**: Verifies driver signature before installation
- **Safe Installation**: Proper permissions and ownership setup
- **CoreAudio Restart**: Automatic restart for immediate driver availability

## BlackHole Updates

**Automatic (recommended):**
```bash
# Build script automatically updates to latest BlackHole
./scripts/build_driver.sh prod
```

**Manual:**
```bash
# Update submodule manually
git submodule update --remote external/blackhole

# Or pin to specific version
cd external/blackhole
git checkout v0.6.2
cd ../..
git add external/blackhole
git commit -m "Pin BlackHole to v0.6.2"
```

## How It Works

1. **Clean Architecture**: JoyCast configurations are applied via GCC preprocessor definitions at build time
2. **No Source Changes**: BlackHole source code is never modified
3. **Compile-Time Customization**: All JoyCast branding applied during compilation
4. **Automatic Cleanup**: Build script removes temporary files from submodule
5. **Universal Compilation**: Single build creates both Intel and Apple Silicon binaries

## Compatibility

- **Runtime**: macOS 10.10+ (inherited from BlackHole)
- **Build Environment**: macOS 10.13+ (Xcode requirement)
- **Architecture**: Universal Binary (Intel + Apple Silicon)
- **Code Signing**: Required for all builds