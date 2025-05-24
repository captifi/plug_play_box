# CaptiFi Plug & Play Box

This repository contains the installation scripts and documentation for setting up a CaptiFi captive portal on OpenWRT devices.

## Overview

CaptiFi Plug & Play Box is a solution for quickly setting up captive portal WiFi hotspots on OpenWRT-compatible devices. It provides:

- Simple one-script installation
- PIN-based activation system with enhanced security
- Integration with CaptiFi server
- Automatic device registration
- Heartbeat monitoring
- Device information retrieval (MAC address and model)

## Device Information Scripts

The latest version includes dedicated CGI scripts for retrieving device information:

- **get-mac.cgi**: Retrieves the device MAC address through multiple fallback methods
- **get-model.cgi**: Retrieves the device model from system information

These scripts provide:
- JSON-formatted responses for easy consumption
- Integration with the setup interface to display device information

You can access this information directly via API endpoints.
