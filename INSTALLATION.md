# CaptiFi OpenWRT Installation Guide

This guide provides step-by-step instructions for installing CaptiFi on your OpenWRT device.

## Method 1: Using the Simplified Installer (Recommended)

This method uses a simplified, more compact installation script that is easier to copy and paste into your OpenWRT device.

1. Connect to your OpenWRT device via SSH:
   ```
   ssh root@192.168.8.1
   ```

2. Download and run the installer directly:
   ```bash
   wget -O - https://raw.githubusercontent.com/captifi/plug_play_box/main/install.sh | sh
   ```

3. Or manually copy and paste the script from the [install.sh](install.sh) file into your SSH session

4. Wait for the installation to complete. This will:
   - Install required packages
   - Create the CaptiFi web interface
   - Configure the network
   - Set up the captive portal

5. Once installation is complete, you'll see a confirmation message.

6. The OpenWRT device will now broadcast a WiFi network named "CaptiFi-Setup"

7. Connect to this WiFi network from your phone or computer

8. The captive portal should open automatically (if not, open a web browser and visit any website)

9. Enter your 8-digit activation PIN in the setup page

10. Click "Activate" to register your device with the CaptiFi server

## Troubleshooting

If you encounter issues during installation:

1. **Check installation logs:**
   ```
   cat /tmp/captifi_activate.log
   ```

2. **Verify the device's MAC address:**
   ```
   cat /sys/class/net/br-lan/address
   ```

3. **Test network connectivity:**
   ```
   ping -c 3 api.captifi.io
   ```

4. **Check if services are running:**
   ```
   /etc/init.d/uhttpd status
   /etc/init.d/captifi status
   ```

5. **Check firewall configuration:**
   ```
   uci show firewall | grep captifi
   ```

## Setup a Different Network Configuration

By default, the CaptiFi setup creates a WiFi network with the following settings:
- SSID: CaptiFi-Setup
- IP Address: 192.168.8.1
- No encryption (open network)

If you need to change these settings, you can modify the network configuration after installation:

```
# Change the SSID
uci set wireless.captifi.ssid=YourCustomSSID

# Change the IP address
uci set network.captifi.ipaddr=192.168.x.y

# Add encryption (optional)
uci set wireless.captifi.encryption=psk2
uci set wireless.captifi.key=your-password

# Apply changes
uci commit wireless
uci commit network
/etc/init.d/network restart
```

## Getting Help

If you encounter issues with your installation, please reach out to our support team at support@captifi.io or visit [https://captifi.io/support](https://captifi.io/support) for assistance.
