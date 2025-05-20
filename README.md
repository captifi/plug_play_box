# CaptiFi Plug & Play Box - OpenWrt Implementation

This folder contains all the necessary files to implement a custom setup splash page for CaptiFi Plug & Play boxes running on OpenWrt devices. The implementation allows users to easily activate their OpenWrt devices with a PIN before they can be used with the main CaptiFi captive portal.

## File Structure

```
/Plug and Play Box/
├── README.md                      # This file
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

To install on an actual OpenWrt device:

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

## Customization

To customize the appearance of the setup page:
- Edit the HTML/CSS in `setup.html`
- Replace the logo placeholder with your actual logo
- Adjust the firewall rules in `firewall` if needed

## Troubleshooting

If you encounter issues:
1. Check the log file: `/var/log/captifi.log`
2. Verify connectivity to the CaptiFi API server
3. Ensure the device has internet access
4. Check the activation status: `captifi-client.sh status`

## Security Notes

- All API communication is encrypted using HTTPS
- The PIN is only used once during activation
- After activation, the box automatically uses the standard CaptiFi security measures
- The MAC address of the device is verified with each request to prevent unauthorized access
