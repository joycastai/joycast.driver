# JoyCast Virtual Audio Driver

JoyCast is a virtual audio driver for macOS based on BlackHole, designed to provide high-quality virtual microphone functionality.

## Architecture

This project uses a clean submodule architecture:

- **BlackHole** (`external/blackhole/`) - Core audio driver functionality (GPL-3.0 licensed)
- **JoyCast** (this repo) - Minimal configuration and build tooling

### Why This Architecture?

- ✅ **Zero source modifications** - BlackHole code remains completely untouched
- ✅ **Automatic updates** - Build script auto-updates to latest BlackHole
- ✅ **Clean builds** - All artifacts in root `build/`, submodule stays clean
- ✅ **Minimal configuration** - Single config file with auto-generated dev/prod differences
- ✅ **Maximum compatibility** - Inherits BlackHole's `macOS 10.10+` support

## Quick Start

### Prerequisites

- **macOS 10.10+** (inherited from BlackHole)
- **Xcode 12+** 
- **Apple Developer certificate** (optional, use `--no-sign` flag for testing)

### Build and Install

```bash
# Clone with submodules
git clone --recursive https://github.com/your-org/joycast.driver.git
cd joycast.driver

# Build production driver (auto-updates BlackHole, signed)
./scripts/build_driver.sh prod

# Install driver (requires admin privileges)
./scripts/install_driver.sh prod
```

### Development Workflow

```bash
# Build development version (auto-updates BlackHole, signed)
./scripts/build_driver.sh dev

# Build without signing (for testing)
./scripts/build_driver.sh dev --no-sign

# Build with current BlackHole version (no update)
./scripts/build_driver.sh dev --no-update

# Install development version
./scripts/install_driver.sh dev
```

## Configuration

**Single configuration file**: `configs/config.env`

The build script automatically generates dev/prod differences:
- **dev**: Adds "Dev" suffixes, ".dev" bundle IDs  
- **prod**: Clean names and bundle IDs

### Environment Variables (Optional)

For code signing (skip with `--no-sign` flag):

```bash
export APPLE_DEVELOPER_CERT_NAME="Developer ID Application: Your Name"
export APPLE_TEAM_ID="XXXXXXXXXX"
```

## Project Structure

```
joycast.driver/
├── external/blackhole/  # Git submodule (always clean)
├── configs/
│   └── config.env       # Single configuration file
├── scripts/
│   ├── build_driver.sh  # Smart build script with all utilities
│   └── install_driver.sh
├── assets/
│   └── JoyCast.icns     # Custom icon
├── build/               # Build outputs (gitignored)
├── VERSION              # JoyCast version
├── LICENSE              # MIT license for JoyCast code
└── README.md
```

## Build Script Options

### `./scripts/build_driver.sh [mode] [flags]`

**Modes:**
- `dev` - Development build with "Dev" suffixes
- `prod` - Production build with clean names (default)

**Flags:**
- `--no-update` - Skip BlackHole submodule update
- `--no-sign` - Build unsigned (for testing without certificates)
- `--help` - Show usage information

**Examples:**
```bash
./scripts/build_driver.sh dev                    # Dev build, latest BlackHole, signed
./scripts/build_driver.sh prod --no-update      # Prod build, current BlackHole, signed  
./scripts/build_driver.sh dev --no-sign         # Dev build, unsigned (for testing)
./scripts/build_driver.sh prod --no-sign --no-update  # Prod build, current, unsigned
```

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

### JoyCast Customizations

Applied at compile time via preprocessor definitions:

- **Driver name**: "JoyCast" / "JoyCast Dev"
- **Bundle ID**: `com.joycast.virtualmic` / `com.joycast.virtualmic.dev`
- **Device names**: "JoyCast Virtual Microphone" / "JoyCast Dev Virtual Microphone"
- **Icon**: Custom JoyCast.icns
- **Unique IDs**: JoyCast-specific device UIDs

## Compatibility

- **Driver**: macOS 10.10+ (inherited from BlackHole)
- **Build Environment**: macOS 10.13+ (Xcode requirement)
- **Architecture**: Universal Binary (Intel + Apple Silicon)

## License

- **JoyCast code**: MIT License
- **BlackHole**: GPL-3.0 License (separate submodule)

This clean separation ensures license compliance while maintaining a professional development workflow.