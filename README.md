# CaptiFi Plug & Play Box - OpenWrt Implementation

This repository contains all the necessary files to implement a custom setup splash page for CaptiFi Plug & Play boxes running on OpenWrt devices. The implementation allows users to easily activate their OpenWrt devices with a PIN before they can be used with the main CaptiFi captive portal.

## Quick Installation

For quick setup, use our automated installation script:

```bash
# One-line installation
curl -sSL https://raw.githubusercontent.com/captifi/plug_play_box/main/openwrt-install.sh | sh
```

For more detailed installation instructions, see [README-OPENWRT-INSTALL.md](README-OPENWRT-INSTALL.md).

## File Structure

```
/
├── README.md                      # This file
├── openwrt-install.sh             # Automated installation script
├── etc/                           # OpenWrt system configuration
│   ├── config/                    # Configuration files
│   │   ├── firewall               # Firewall rules for captive portal
│   │   └── uhttpd                 # Web server configuration
│   └── init.d/                    # Init scripts
│       └── captifi                # CaptiFi service startup script
└── www/                           # Web root directory
    └── captifi/                   # CaptiFi setup application
        ├── activate.cgi           # CGI script to handle PIN activation
        ├── setup.html             # Main setup page HTML template
        ├── setup.lua              # Lua handler for setup page
        ├── splash.html            # Transition page after activation
        └── assets/                # Static assets
            └── logo-placeholder.txt # Placeholder for logo image
```

## How It Works

1. **Initial Boot**: When the OpenWrt device boots for the first time, the `captifi` init script checks if the device is activated:
   - If not activated, it enables the captive portal redirect
   - All HTTP traffic is redirected to the setup page

2. **Setup Page**: Users see the `setup.html` page which:
   - Shows the device's MAC address
   - Provides a form to enter their 8-digit activation PIN
   - Validates input client-side

3. **Activation Process**:
   - When the PIN is submitted, the `activate.cgi` script calls `captifi-client.sh activate`
   - If successful, the device is registered with the CaptiFi server
   - Configuration is updated to disable the redirect
   - The device now serves the real splash page from the CaptiFi server

4. **Post-Activation**:
   - After activation, the `captifi` service detects the change
   - Firewall redirect is disabled
   - Web server is reconfigured to serve the real splash page
   - The device inherits all settings from the associated site in CaptiFi

## Installation on OpenWrt

### Automated Installation (Recommended)

Our automated installation script handles all the setup for you:

```bash
curl -sSL https://raw.githubusercontent.com/captifi/plug_play_box/main/openwrt-install.sh | sh
```

This will:
1. Install all required packages
2. Download and place all files in the correct locations
3. Configure your system properly
4. Enable necessary services

### Manual Installation

If you prefer a more hands-on approach:

1. Install required packages:
   ```
   opkg update
   opkg install curl uhttpd uhttpd-mod-lua
   ```

2. Copy the files to the corresponding locations on your OpenWrt device:
   - The `etc` directory files to `/etc`
   - The `www` directory files to `/www`

3. Make the scripts executable:
   ```
   chmod +x /etc/init.d/captifi
   chmod +x /www/captifi/activate.cgi
   ```

4. Enable the CaptiFi service:
   ```
   /etc/init.d/captifi enable
   /etc/init.d/captifi start
   ```

5. Customize the configuration:
   - Update the CaptiFi server URL in `captifi-client.sh`
   - Replace the logo placeholder with your actual logo

## Activating Your Box

After installation:

1. Generate a PIN in your CaptiFi admin panel
2. On the OpenWrt device, run:
   ```
   captifi-client.sh activate YOUR_PIN_HERE
   ```
3. Verify status with:
   ```
   captifi-client.sh status
   ```

## Troubleshooting

If you encounter issues:
1. Check the log file: `/var/log/captifi.log`
2. Verify connectivity to the CaptiFi API server
3. Ensure the device has internet access
4. Check the firewall rules: `uci show firewall`

## Security Notes

- All API communication is encrypted using HTTPS
- The PIN is only used once during activation
- After activation, the box automatically uses the standard CaptiFi security measures
- The MAC address of the device is verified with each request to prevent unauthorized access

## Customization

To customize the appearance of the setup page:
- Edit the HTML/CSS in `setup.html`
- Replace the logo placeholder with your actual logo
- Adjust the firewall rules in `firewall` if needed

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
