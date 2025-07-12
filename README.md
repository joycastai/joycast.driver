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
│   ├── build.sh                # Self-contained build script
│   ├── build_to_candidate.sh   # Release candidate builder (PKG creation)
│   └── install_driver.sh
├── assets/
│   └── joycast.icns     # Custom icon
├── dist/
│   ├── build/           # Build outputs (gitignored)
│   └── candidate/       # Release candidates by version (gitignored)
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

## Release Candidate Builder

### `./scripts/build_to_candidate.sh [flags]`

Creates signed and notarized PKG installers for distribution. Always builds both dev and prod versions.

**Flags:**
- `--skip-build` - Skip driver build, use existing drivers (development only)
- `--help` - Show usage information

**Examples:**
```bash
./scripts/build_to_candidate.sh                 # Clean build and create PKG candidates (recommended)
./scripts/build_to_candidate.sh --skip-build    # Use existing drivers (development/testing only)
```

**Best Practices:**
- **Always commit changes** before creating release candidates
- **Use clean builds** (default behavior) for production releases
- `--skip-build` flag only for development/testing
- Release info includes Git commit hash for traceability
- Script checks for uncommitted changes and warns appropriately

### Release Candidate Output

Release candidates are stored in a single directory per version:

```
dist/candidate/
└── 25.7.11.0/
    ├── JoyCast Driver.pkg          # Production PKG (signed & notarized)
    └── JoyCast Driver Dev.pkg      # Development PKG (signed & notarized)
```

**Clean and simple:** Only the essential PKG files for distribution.

### PKG Installer Features

- **Signed & Notarized**: All PKG files are signed with Developer ID Installer certificate and notarized by Apple
- **Automatic Cleanup**: Removes existing drivers before installing new ones
- **Permission Setup**: Sets proper ownership (root:wheel) and permissions (755)
- **CoreAudio Restart**: Automatically restarts CoreAudio to load the new driver
- **Simple Distribution**: Clean PKG files ready for immediate distribution

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