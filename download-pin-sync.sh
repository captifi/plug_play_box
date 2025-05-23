#!/bin/sh

# CaptiFi PIN Sync Tool Downloader
# This script downloads the PIN sync tool directly from GitHub
# and makes it executable on an OpenWRT device.

echo "CaptiFi PIN Sync Tool Downloader"
echo "================================"
echo ""

# Create temporary directory for download
TEMP_DIR="/tmp/captifi-pin-sync"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo "Downloading PIN sync tool from GitHub..."
curl -k -L -o pin-sync.sh https://raw.githubusercontent.com/captifi/plug_play_box/main/openwrt-pin-sync.sh

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to download PIN sync tool from GitHub."
    echo "Please check your internet connection and try again."
    exit 1
fi

echo "Making script executable..."
chmod +x pin-sync.sh

echo ""
echo "SUCCESS! PIN sync tool has been downloaded to: $TEMP_DIR/pin-sync.sh"
echo ""
echo "To run the tool now, use the command:"
echo "  $TEMP_DIR/pin-sync.sh"
echo ""
echo "Or to run with specific PIN and MAC address:"
echo "  $TEMP_DIR/pin-sync.sh 71173735 \"44:d1:fa:63:bf:21\""
echo ""
echo "For permanent installation, you can copy to /usr/local/bin:"
echo "  mkdir -p /usr/local/bin"
echo "  cp $TEMP_DIR/pin-sync.sh /usr/local/bin/"
echo "  chmod +x /usr/local/bin/pin-sync.sh"
echo ""

# Ask if user wants to run the tool now
echo -n "Would you like to run the PIN sync tool now? (y/n): "
read RUN_NOW

if [ "$RUN_NOW" = "y" ] || [ "$RUN_NOW" = "Y" ]; then
    echo ""
    echo "Running PIN sync tool..."
    echo "-------------------------"
    $TEMP_DIR/pin-sync.sh
fi
