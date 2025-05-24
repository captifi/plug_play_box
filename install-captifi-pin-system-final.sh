#!/bin/bash
# CaptiFi PIN Validation System Installer - Final Version
# This script installs the complete PIN validation system on an OpenWRT device
# with environment variable support

# Check if target IP is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <OpenWRT-IP-Address>"
    echo "Example: $0 192.168.1.1"
    exit 1
fi

TARGET_IP="$1"
echo "================================================================"
echo "CaptiFi PIN Validation System Installer"
echo "Target OpenWRT device: $TARGET_IP"
echo "================================================================"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf $TEMP_DIR' EXIT

echo "Creating installation package..."

# Copy necessary files to temp directory
cp captifi-installer-package/www/cgi-bin/activate.cgi $TEMP_DIR/
cp captifi-installer-package/www/captifi/setup.html $TEMP_DIR/
cp captifi-installer-package/.env $TEMP_DIR/

# Make scripts executable
chmod +x $TEMP_DIR/activate.cgi

echo "Deploying to OpenWRT device..."

# Create necessary directories on the target
ssh root@$TARGET_IP "mkdir -p /www/cgi-bin /www/captifi /etc/captifi"

# Copy files to the target
scp $TEMP_DIR/activate.cgi root@$TARGET_IP:/www/cgi-bin/
scp $TEMP_DIR/setup.html root@$TARGET_IP:/www/captifi/
scp $TEMP_DIR/.env root@$TARGET_IP:/etc/captifi/

# Set permissions
ssh root@$TARGET_IP "chmod +x /www/cgi-bin/activate.cgi"

# Restart the web server
ssh root@$TARGET_IP "/etc/init.d/uhttpd restart"

echo "================================================================"
echo "Installation complete!"
echo "The PIN validation system has been installed on $TARGET_IP"
echo "You can access the setup page at: http://$TARGET_IP/captifi/setup.html"
echo "The API key and endpoint are configured in: /etc/captifi/.env"
echo "================================================================"
