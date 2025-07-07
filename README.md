# JoyCast Virtual Audio Driver

JoyCast is a virtual audio driver for macOS based on BlackHole.


## Quick Start

### Prerequisites

- **macOS 10.13+** (build environment requirement)
- **Xcode or Xcode Command Line Tools** 
- **Apple Developer certificate** (Required - all builds are signed)
- **Apple Team ID** (Required for code signing)


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

### Code Signing Setup

Create `configs/credentials.env`:
```bash
# Apple Developer Team ID
APPLE_TEAM_ID="XXXXXXXXXX"

# Code Signing Certificate Name
CODE_SIGN_CERT_NAME="Developer ID Application: Your Name (XXXXXXXXXX)"
```


## Configuration

**Single configuration file**: `configs/driver.env`

Contains all [BlackHole customization parameters](https://github.com/ExistentialAudio/BlackHole):


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


## Compatibility

- **Runtime**: macOS 10.10+ (inherited from BlackHole)
- **Build Environment**: macOS 10.13+ (Xcode requirement)
- **Architecture**: Universal Binary (Intel + Apple Silicon)
- **Code Signing**: Required for all builds