# JoyCast Virtual Audio Driver

JoyCast is a virtual audio driver for macOS based on BlackHole, designed to provide high-quality virtual microphone functionality.

## Architecture

This project uses a clean submodule architecture:

- **BlackHole** (`external/blackhole/`) - Core audio driver functionality (GPL-3.0 licensed)
- **JoyCast** (this repo) - Minimal configuration and build tooling

### Why This Architecture?

- ✅ **Zero source modifications** - BlackHole code remains completely untouched
- ✅ **Automatic updates** - Build script auto-updates to latest BlackHole
- ✅ **Clean builds** - All artifacts in separate `build/dev/` and `build/prod/` directories, submodule stays clean
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
- `SAMPLE_RATES` - Supported sample rates (44100,48000)

### Build Differences
The build script automatically generates dev/prod differences:
- **dev**: Adds "Dev" suffixes, ".dev" bundle IDs  
- **prod**: Clean names and bundle IDs

### Advanced Customization Examples

**High-resolution audio support:**
```bash
# Edit configs/driver.env
SAMPLE_RATES="44100,48000,88200,96000,176400,192000"
```

**Multi-channel setup (16 channels):**
```bash
# Edit configs/driver.env  
NUMBER_OF_CHANNELS=16
LATENCY_FRAME_SIZE=512  # Higher latency for stability
```

**Custom device visibility:**
```bash
# Edit configs/driver.env
DEVICE_IS_HIDDEN=false      # Primary device visible
DEVICE2_IS_HIDDEN=false     # Mirror device also visible  
```

**Separate input/output devices:**
```bash
# Edit configs/driver.env
DEVICE_HAS_INPUT=true       # Primary: input only
DEVICE_HAS_OUTPUT=false
DEVICE2_HAS_INPUT=false     # Mirror: output only  
DEVICE2_HAS_OUTPUT=true
```

All changes apply to both dev and prod builds automatically.

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
│   └── driver.env       # Single configuration file
├── scripts/
│   ├── build_driver.sh  # Self-contained build script
│   └── install_driver.sh
├── assets/
│   └── JoyCast.icns     # Custom icon
├── build/               # Build outputs (gitignored)
│   ├── dev/             # Development builds
│   └── prod/            # Production builds
├── LICENSE              # MIT license for JoyCast code
└── README.md
```

## Build Outputs

All build outputs are generated in separate directories to avoid conflicts:

```
build/
├── dev/
│   ├── JoyCast Dev.driver      # Development driver
│   └── JoyCast Dev.driver.dSYM # Debug symbols for dev
└── prod/
    ├── JoyCast.driver          # Production driver
    └── JoyCast.driver.dSYM     # Debug symbols for prod
```

This structure allows you to:
- Keep both dev and prod builds simultaneously
- Switch between versions quickly without rebuilding
- Compare outputs between different configurations

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

Applied at compile time via [BlackHole preprocessor definitions](https://github.com/ExistentialAudio/BlackHole):

**Core Driver:**
- `kDriver_Name`: "JoyCast" 
- `kPlugIn_BundleID`: com.joycast.virtualmic / com.joycast.virtualmic.dev
- `kPlugIn_Icon`: "JoyCast.icns"

**Primary Device:**
- `kDevice_Name`: "JoyCast Virtual Microphone" / "JoyCast Dev Virtual Microphone"
- `kDevice_IsHidden`: false (visible device)
- `kDevice_HasInput`: true, `kDevice_HasOutput`: false

**Mirror Device:** 
- `kDevice2_Name`: "JoyCast Virtual Output" / "JoyCast Dev Virtual Output"  
- `kDevice2_IsHidden`: true (hidden device)
- `kDevice2_HasInput`: true, `kDevice2_HasOutput`: false

**Audio Settings:**
- `kNumber_Of_Channels`: 2
- `kLatency_Frame_Size`: 0 (zero additional latency)
- `kSampleRates`: "44100,48000"

## Compatibility

- **Driver**: macOS 10.10+ (inherited from BlackHole)
- **Build Environment**: macOS 10.13+ (Xcode requirement)
- **Architecture**: Universal Binary (Intel + Apple Silicon)

## License

- **JoyCast code**: MIT License
- **BlackHole**: GPL-3.0 License (separate submodule)

This clean separation ensures license compliance while maintaining a professional development workflow.