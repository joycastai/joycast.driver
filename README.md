# JoyCast Virtual Audio Driver

JoyCast is a virtual audio driver for macOS based on BlackHole. This is a fork of the [BlackHole Audio Driver](https://github.com/ExistentialAudio/BlackHole) under GPL-3.0 license, with JoyCast-specific customizations applied at build time.

## License

This project is licensed under **GNU General Public License v3.0 (GPL-3.0)** - the same license as BlackHole. All customizations are applied via GCC preprocessor definitions during build time, allowing easy syncing with upstream BlackHole while maintaining GPL compliance.

## Quick Start

### Prerequisites

- **macOS 10.13+** (build environment requirement)
- **Xcode or Xcode Command Line Tools** 
- **Apple Developer certificate** (Required - all builds are signed)
- **Apple Team ID** (Required for code signing)

### Build and Install

```bash
# Clone with submodules
git clone --recursive https://github.com/joycastai/joycast.driver.git
cd joycast.driver

# Load credentials (required for signing)
source configs/credentials.env

# Build driver (auto-updates BlackHole, signed)
./scripts/build.sh

# Install driver (requires admin privileges)
./scripts/install_build.sh
```

### Code Signing Setup

Create `configs/credentials.env` with the following structure:
```bash
#!/bin/bash
# JoyCast Environment Variables
# Автоматическая загрузка данных из macOS Keychain

# Загружаем Apple ID из Keychain
export APPLE_ID=$(security find-generic-password -a "$USER" -s "JoyCast Notarization - Apple ID" -w 2>/dev/null)

# Загружаем App-specific password из Keychain  
export APPLE_APP_PASSWORD=$(security find-generic-password -a "$USER" -s "JoyCast Notarization - Password" -w 2>/dev/null)

# Team ID для подписи
export APPLE_TEAM_ID="XXXXXXXXXX"

# Имя разработчика для подписи сертификатов
export DEVELOPER_NAME="Your Developer Name"
```

**Note:** All builds require code signing. For notarization, add your Apple ID credentials to the macOS Keychain.

## Versioning

JoyCast uses **date-based versioning** in the format **YY.M.D.0** (e.g., 25.7.13.0). Version numbers are automatically generated during build and should not be compared semantically.

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
│   ├── build.sh                # Self-contained build script
│   ├── build_to_candidate.sh   # Release candidate builder (PKG creation)
│   ├── install_build.sh        # Install built driver
│   └── uninstall_driver.sh     # Uninstall script
├── assets/
│   └── joycast.icns     # Custom icon
├── dist/
│   ├── build/           # Build outputs (gitignored)
│   ├── candidate/       # Release candidates during build (gitignored)
│   └── releases/        # Final releases by version (gitignored)
├── LICENSE              # GPL-3.0 License
└── README.md
```

## Build Outputs

### Development Build (`./scripts/build.sh`)

All development build outputs are generated in `dist/build/` directory:

```
dist/build/
├── JoyCast.driver              # Production driver (universal binary)
└── JoyCast.driver.dSYM         # Debug symbols (if --debug)
```

### Release Build (`./scripts/build_to_candidate.sh`)

Release candidates are created in `dist/candidate/VERSION/` during build process, then moved to `dist/releases/VERSION/` for final distribution:

```
dist/releases/
└── 25.7.13.0/
    └── JoyCast Driver.pkg      # Signed and notarized PKG
```

This structure allows you to:
- Clean production builds with automatic versioning
- Support both Intel and Apple Silicon Macs with single binary
- Optional debug symbols for development
- Proper release management with version-based directories

## Build Script Options

### `./scripts/build.sh [flags]`

**Important:** Always run `source configs/credentials.env` before building to load signing credentials.

**Flags:**
- `--no-update` - Skip BlackHole submodule update
- `--debug` - Keep debug symbols (.dSYM files)
- `--help` - Show usage information

**Examples:**
```bash
source configs/credentials.env
./scripts/build.sh                              # Build production version, latest BlackHole
./scripts/build.sh --no-update                  # Build with current BlackHole version
./scripts/build.sh --debug                      # Build with debug symbols
```

## Release Candidate Builder

### `./scripts/build_to_candidate.sh [flags]`

Creates signed and **notarized** PKG installer for distribution. **All production releases must be notarized.**

**Flags:**
- `--skip-build` - Skip driver build, use existing drivers (development only)
- `--help` - Show usage information

**Examples:**
```bash
source configs/credentials.env
./scripts/build_to_candidate.sh                 # Clean build and create PKG candidates (recommended)
./scripts/build_to_candidate.sh --skip-build    # Use existing drivers (development/testing only)
```

**Best Practices:**
- **Always load credentials** with `source configs/credentials.env` before building
- **Always commit changes** before creating release candidates
- **Use clean builds** (default behavior) for production releases
- `--skip-build` flag only for development/testing
- **All production builds are notarized** - skip-notarization option has been removed
- Release info includes Git commit hash for traceability
- Script checks for uncommitted changes and warns appropriately

### Release Candidate Workflow

1. **Development Build**: `./scripts/build.sh` creates drivers in `dist/build/`
2. **Release Candidate**: `./scripts/build_to_candidate.sh` creates signed PKG in `dist/candidate/VERSION/`
3. **Final Release**: After testing, PKG is moved to `dist/releases/VERSION/` for distribution

### PKG Installer Features

- **Signed & Notarized**: All PKG files are signed with Developer ID Installer certificate and notarized by Apple
- **Automatic Cleanup**: Removes existing drivers before installing new ones
- **Permission Setup**: Sets proper ownership (root:wheel) and permissions (755)
- **CoreAudio Restart**: Automatically restarts CoreAudio to load the new driver
- **Simple Distribution**: Clean PKG files ready for immediate distribution

## BlackHole Updates

**Check current version:**
```bash
# View BlackHole version
cat external/blackhole/VERSION
```

**Automatic (recommended):**
```bash
# Build script automatically updates to latest BlackHole
source configs/credentials.env
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

## Installation

### `./scripts/install_build.sh`

Installs the built driver from `dist/build/` directory.

**Features:**
- **Automatic Detection**: Finds built driver in build directory
- **Signature Verification**: Verifies driver signature before installation
- **Automatic Privileges**: Handles sudo authentication
- **CoreAudio Restart**: Restarts audio system after installation
- **Proper Permissions**: Sets correct ownership and permissions

**Usage:**
```bash
# Install built driver
./scripts/install_build.sh
```

## Uninstall Driver

### `./scripts/uninstall_driver.sh`

**Features:**
- **Simple Removal**: Quick and safe driver uninstallation
- **Automatic Privileges**: Handles sudo authentication automatically
- **CoreAudio Restart**: Restarts audio system after removal
- **Verification**: Confirms successful removal from system

**Usage:**
```bash
# Uninstall JoyCast driver
./scripts/uninstall_driver.sh
```

## Compatibility

- **Runtime**: macOS 10.10+ (inherited from BlackHole)
- **Build Environment**: macOS 10.13+ (Xcode requirement)
- **Architecture**: Universal Binary (Intel + Apple Silicon)
- **Code Signing**: Required for all builds
- **Notarization**: Required for all release builds