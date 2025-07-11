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

# Build both drivers (auto-updates BlackHole, signed)
./scripts/build.sh

# Install production driver (requires admin privileges)
./scripts/install_driver.sh prod

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
│   ├── build.sh         # Self-contained build script
│   └── install_driver.sh
├── assets/
│   └── joycast.icns     # Custom icon
├── dist/build/          # Build outputs (gitignored)
├── LICENSE              
└── README.md
```

## Build Outputs

All build outputs are generated in `dist/build/` directory:

```
dist/build/
├── JoyCast.driver              # Production driver (universal binary)
├── JoyCast Dev.driver          # Development driver (universal binary)
├── JoyCast.driver.dSYM         # Debug symbols for prod (if --debug)
└── JoyCast Dev.driver.dSYM     # Debug symbols for dev (if --debug)
```

This structure allows you to:
- Keep both dev and prod builds simultaneously
- Switch between versions quickly without rebuilding
- Compare outputs between different configurations
- Support both Intel and Apple Silicon Macs with single binary

## Build Script Options

### `./scripts/build.sh [flags]`

**Flags:**
- `--no-update` - Skip BlackHole submodule update
- `--debug` - Keep debug symbols (.dSYM files)
- `--help` - Show usage information

**Examples:**
```bash
./scripts/build.sh                              # Build both versions, latest BlackHole
./scripts/build.sh --no-update                  # Build with current BlackHole version
./scripts/build.sh --debug                      # Build with debug symbols
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

**Check current version:**
```bash
# View BlackHole version
cat external/blackhole/VERSION
```

**Automatic (recommended):**
```bash
# Build script automatically updates to latest BlackHole
./scripts/build.sh
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