# CaptiFi Plug & Play Box

This repository contains the installation scripts and documentation for setting up a CaptiFi captive portal on OpenWRT devices.

## Overview

CaptiFi Plug & Play Box is a solution for quickly setting up captive portal WiFi hotspots on OpenWRT-compatible devices. It provides:

- Simple one-script installation
- PIN-based activation system
- Integration with CaptiFi server
- Automatic device registration
- Heartbeat monitoring

## Quick Start

1. Connect to your OpenWRT device via SSH:
   ```
   ssh root@192.168.8.1
   ```

2. Download and run the installer directly:
   ```bash
   wget -O - https://raw.githubusercontent.com/captifi/plug_play_box/main/install.sh | sh
   ```

3. Or manually copy and paste the [installation script](install.sh) into your SSH session

4. Once installed, the device will broadcast a "CaptiFi-Setup" WiFi network

5. Connect to this network from another device and follow the activation prompts

## Documentation

- [Installation Guide](INSTALLATION.md) - Detailed installation instructions
- [Troubleshooting](INSTALLATION.md#troubleshooting) - Help with common issues

## Development

To contribute to this project:

1. Clone the repository:
   ```
   git clone git@github.com:captifi/plug_play_box.git
   ```

2. Make your changes

3. Submit a pull request

## License

© 2025 CaptiFi. All rights reserved.
