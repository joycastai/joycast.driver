# JoyCast Virtual Audio Driver

JoyCast is a virtual audio driver for macOS based on BlackHole, designed to provide high-quality virtual microphone functionality.

## Architecture

This project uses a clean architecture approach:

- **BlackHole** (submodule) - Core audio driver functionality (GPL-3.0 licensed)
- **JoyCast** (this repo) - Configuration, customizations, and build tooling (MIT licensed)

### Why Submodule Approach?

- ✅ **Clean separation** - BlackHole code remains untouched
- ✅ **Easy updates** - Simple `git submodule update` to get latest BlackHole
- ✅ **Clear licensing** - GPL for BlackHole, MIT for JoyCast additions
- ✅ **Reduced conflicts** - No merging upstream changes
- ✅ **Professional structure** - Clear separation of concerns

## Quick Start

### Prerequisites

- macOS 10.13 or later
- Xcode 12 or later
- Valid Apple Developer certificate (for signing)

### Build and Install

```bash
# Clone with submodules
git clone --recursive https://github.com/your-org/joycast.driver.git
cd joycast.driver

# Or if already cloned, initialize submodules
git submodule update --init

# Build production driver
./scripts/build_driver.sh prod

# Install driver (requires admin privileges)
./scripts/install_driver.sh prod
```

### Development

```bash
# Build development version (unsigned)
./scripts/build_driver.sh dev

# Install development version
./scripts/install_driver.sh dev
```

## Configuration

Driver configuration is stored in `configs/`:

- `configs/joycast_prod.env` - Production configuration
- `configs/joycast_dev.env` - Development configuration

### Environment Variables

Set these environment variables for code signing:

```bash
export APPLE_DEVELOPER_CERT_NAME="Developer ID Application: Your Name"
export APPLE_TEAM_ID="XXXXXXXXXX"
```

## Project Structure

```
joycast.driver/
├── BlackHole/           # Git submodule (GPL-3.0)
├── configs/             # Build configurations
│   ├── joycast_prod.env
│   ├── joycast_dev.env
│   └── build_utils.sh
├── scripts/             # Build and install scripts
│   ├── build_driver.sh
│   └── install_driver.sh
├── assets/              # JoyCast-specific assets
│   └── JoyCast.icns
├── docs/                # Documentation
├── releases/            # Release artifacts
├── build/               # Build output
├── VERSION              # JoyCast version
├── LICENSE              # MIT license for JoyCast
└── README.md            # This file
```

## Updating BlackHole

To update to a newer version of BlackHole:

```bash
cd BlackHole
git fetch origin
git checkout v0.6.2  # or latest tag
cd ..
git add BlackHole
git commit -m "Update BlackHole to v0.6.2"
```

## Customizations

JoyCast customizations are applied via preprocessor definitions at build time:

- Driver name: "JoyCast"
- Bundle ID: `com.joycast.virtualmic`
- Icon: Custom JoyCast icon
- Device names: "JoyCast Virtual Microphone"

All customizations are defined in config files - no BlackHole source code is modified.

## Licensing

- **JoyCast components**: MIT License (see [LICENSE](LICENSE))
- **BlackHole submodule**: GPL-3.0 License (see [BlackHole/LICENSE](BlackHole/LICENSE))

The final driver binary includes both components and is subject to GPL-3.0 due to BlackHole inclusion.

## Credits

- Based on [BlackHole](https://github.com/ExistentialAudio/BlackHole) by Existential Audio Inc.
- JoyCast customizations by JoyCast Gang

## Support

For JoyCast-specific issues, please open an issue in this repository.
For BlackHole-related issues, refer to the [upstream repository](https://github.com/ExistentialAudio/BlackHole). 