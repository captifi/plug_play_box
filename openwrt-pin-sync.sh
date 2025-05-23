#!/bin/sh

# CaptiFi OpenWRT PIN Sync Tool
# This script marks PINs as used through the CaptiFi API directly from an OpenWRT device
#
# Usage: ./openwrt-pin-sync.sh [PIN] [MAC_ADDRESS] [API_KEY]

# Default values and argument parsing
PIN="$1"
MAC_ADDRESS="$2"
API_KEY="${3:-I0rdMubIPdto5tTCDFr1WT7wcPkyK1S8}"  # Default API key if not provided

# Interactive mode if arguments not provided
if [ -z "$PIN" ] || [ -z "$MAC_ADDRESS" ]; then
    echo "CaptiFi OpenWRT PIN Sync Tool"
    echo "============================"
    echo "This tool marks PINs as used through the CaptiFi API."
    echo ""
    
    # Prompt for PIN
    echo -n "Enter the PIN to mark as used: "
    read PIN
    
    # Prompt for MAC address
    echo -n "Enter the device MAC address (or press Enter to use this device's MAC): "
    read MAC_ADDRESS
    
    # Use current device MAC if not provided
    if [ -z "$MAC_ADDRESS" ]; then
        MAC_ADDRESS=$(cat /sys/class/net/br-lan/address 2>/dev/null)
        if [ -z "$MAC_ADDRESS" ]; then
            MAC_ADDRESS=$(ip link show br-lan 2>/dev/null | grep -o 'link/ether [0-9a-f:]\+' | cut -d' ' -f2)
        fi
        if [ -z "$MAC_ADDRESS" ]; then
            echo "ERROR: Could not determine device MAC address. Please provide it manually."
            exit 1
        fi
        echo "Using device MAC address: $MAC_ADDRESS"
    fi
    
    # Prompt for API key
    echo -n "Enter API key (or press Enter to use default): "
    read CUSTOM_API_KEY
    if [ -n "$CUSTOM_API_KEY" ]; then
        API_KEY="$CUSTOM_API_KEY"
    fi
fi

# Standardize MAC address (lowercase with colons)
MAC_ADDRESS=$(echo "$MAC_ADDRESS" | tr 'A-Z' 'a-z' | tr '-' ':')

echo ""
echo "Synchronizing device with MAC $MAC_ADDRESS using PIN $PIN..."

# Add API server to hosts file to ensure proper resolution
echo "Adding API server to hosts file..."
API_SERVER_IP="35.174.11.137"
grep -q "api.captifi.io" /etc/hosts || echo "$API_SERVER_IP api.captifi.io" >> /etc/hosts

# Test connectivity to API server
echo "Testing connectivity to API server..."
ping -c 1 $API_SERVER_IP > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "WARNING: Cannot reach API server at $API_SERVER_IP"
    echo "Will attempt API call anyway, but it may fail."
fi

# API endpoint
API_ENDPOINT="https://api.captifi.io/api/plug-and-play/activate"

# Create JSON data file
JSON_DATA="/tmp/captifi-api-request.json"
cat > $JSON_DATA << EOF
{
  "pin": "$PIN",
  "box_mac_address": "$MAC_ADDRESS",
  "serial": "OpenWrt-Device",
  "device_model": "OpenWrt"
}
EOF

echo "Sending request to CaptiFi API..."
echo "API Endpoint: $API_ENDPOINT"
echo "Request Data:"
cat $JSON_DATA
echo ""

# Make curl request
RESPONSE_FILE="/tmp/captifi-api-response.txt"
HTTP_CODE=$(curl -s -k -w "%{http_code}" -o "$RESPONSE_FILE" -X POST "$API_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "X-API-KEY: $API_KEY" \
    --data-binary @"$JSON_DATA" \
    --connect-timeout 10 \
    --max-time 30)

CURL_STATUS=$?

# Check if curl was successful
if [ $CURL_STATUS -ne 0 ]; then
    echo "ERROR: Failed to connect to CaptiFi API (curl error $CURL_STATUS)"
    exit 1
fi

echo "API Response (HTTP Code: $HTTP_CODE):"
cat "$RESPONSE_FILE"
echo ""

# Check for success in response
if grep -q '"success"[[:space:]]*:[[:space:]]*true' "$RESPONSE_FILE"; then
    echo "SUCCESS! PIN $PIN has been marked as used in the CaptiFi system."
    
    # Extract server_id and site_id if available
    SERVER_ID=$(grep -o '"server_id":[0-9]*' "$RESPONSE_FILE" | cut -d':' -f2)
    SITE_ID=$(grep -o '"site_id":[0-9]*' "$RESPONSE_FILE" | cut -d':' -f2)
    
    if [ -n "$SERVER_ID" ]; then
        echo "Server ID: $SERVER_ID"
        
        # Store server ID for future use
        mkdir -p /etc/captifi
        echo "$SERVER_ID" > /etc/captifi/server_id
    fi
    
    if [ -n "$SITE_ID" ]; then
        echo "Site ID: $SITE_ID"
    fi
    
    echo ""
    echo "The device is now properly registered in the CaptiFi backend."
    echo "You can continue using it in offline mode."
    
    # Clean up temporary files
    rm -f "$JSON_DATA" "$RESPONSE_FILE"
    
    exit 0
else
    # Extract error message if available
    ERROR_MSG=$(grep -o '"message":"[^"]*' "$RESPONSE_FILE" | cut -d'"' -f4)
    
    if [ -n "$ERROR_MSG" ]; then
        echo "ERROR: API call failed: $ERROR_MSG"
    else
        echo "ERROR: API call failed with HTTP code $HTTP_CODE"
    fi
    
    # Clean up temporary files
    rm -f "$JSON_DATA" "$RESPONSE_FILE"
    
    exit 1
fi
