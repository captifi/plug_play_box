#!/bin/sh

# CaptiFi Remote Activation Script
# This script directly calls the CaptiFi live API to activate a PIN
# It works around DNS resolution issues by using hardcoded IP addresses

# Configuration
API_KEY="I0rdMubIPdto5tTCDFr1WT7wcPkyK1S8"
API_SERVER_IP="35.174.11.137"  # Hardcoded IP address for api.captifi.io
API_ENDPOINT="https://$API_SERVER_IP/api/plug-and-play/activate"
PIN="71173735"  # Replace with your PIN

# Get MAC address
MAC_ADDRESS=$(cat /sys/class/net/br-lan/address 2>/dev/null)
if [ -z "$MAC_ADDRESS" ]; then
    MAC_ADDRESS=$(ip link show br-lan 2>/dev/null | grep -o 'link/ether [0-9a-f:]\+' | cut -d' ' -f2)
fi
if [ -z "$MAC_ADDRESS" ]; then
    MAC_ADDRESS="44:d1:fa:63:bf:21"  # Fallback MAC address
fi

# Debug information
echo "Using MAC address: $MAC_ADDRESS"
echo "Using PIN: $PIN"
echo "API endpoint: $API_ENDPOINT"

# Add host entry to bypass DNS issues
echo "$API_SERVER_IP api.captifi.io" >> /etc/hosts

# Verify host entry
echo "Host entry added to /etc/hosts:"
grep "api.captifi.io" /etc/hosts

# Try a basic connectivity test first
echo "Testing connectivity to API server..."
ping -c 3 $API_SERVER_IP

# Make the API request
echo "Sending activation request to CaptiFi API..."
response=$(curl -s -k -L --connect-timeout 30 --max-time 60 -X POST "$API_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "X-API-KEY: $API_KEY" \
    -d "{\"pin\":\"$PIN\",\"box_mac_address\":\"$MAC_ADDRESS\",\"serial\":\"OpenWrt-Device\",\"device_model\":\"OpenWrt\"}")

# Display the response
echo "API Response:"
echo "$response"

# Check if activation was successful
if echo "$response" | grep -q '"success"[[:space:]]*:[[:space:]]*true'; then
    server_id=$(echo "$response" | grep -o '"server_id":[0-9]*' | cut -d':' -f2)
    site_id=$(echo "$response" | grep -o '"site_id":[0-9]*' | cut -d':' -f2)
    
    echo "Activation successful!"
    echo "Server ID: $server_id"
    echo "Site ID: $site_id"
    
    # Store server ID for heartbeat
    mkdir -p /etc/captifi
    echo "$server_id" > /etc/captifi/server_id
    
    # Create heartbeat script with proper API connection
    mkdir -p /etc/captifi/scripts
    cat > /etc/captifi/scripts/heartbeat.sh << 'EOSCRIPT'
#!/bin/sh
MAC_ADDRESS=$(cat /sys/class/net/br-lan/address)
SERVER_ID=$(cat /etc/captifi/server_id)
UPTIME=$(cat /proc/uptime | awk '{print $1}')

# Add host entry to bypass DNS issues (in case it was removed)
grep -q "api.captifi.io" /etc/hosts || echo "35.174.11.137 api.captifi.io" >> /etc/hosts

# Send heartbeat to API
curl -k -L --retry 3 --connect-timeout 10 --max-time 30 -X POST "https://api.captifi.io/api/plug-and-play/heartbeat" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: I0rdMubIPdto5tTCDFr1WT7wcPkyK1S8" \
  -d "{\"mac_address\":\"$MAC_ADDRESS\",\"server_id\":$SERVER_ID,\"uptime\":$UPTIME,\"serial\":\"OpenWrt-Device\",\"device_model\":\"OpenWrt\"}" > /tmp/heartbeat_response.log 2>&1

# Log the result
logger -t captifi "Heartbeat sent to live API for server ID $SERVER_ID"
EOSCRIPT
    chmod +x /etc/captifi/scripts/heartbeat.sh
    
    # Set up cron job for heartbeat
    grep -q "heartbeat.sh" /etc/crontabs/root || {
        mkdir -p /etc/crontabs
        echo "*/5 * * * * /etc/captifi/scripts/heartbeat.sh" >> /etc/crontabs/root
        /etc/init.d/cron restart
    }
    
    # Update the activate.cgi script to immediately return success for future activations
    cat > /www/captifi/api/activate-api.cgi << 'EOF'
#!/bin/sh
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""
echo "{\"success\":true,\"message\":\"Device is already activated\",\"server_id\":$(cat /etc/captifi/server_id),\"site_id\":67890}"
EOF
    chmod +x /www/captifi/api/activate-api.cgi
    
    echo "Setup complete. This device is now fully activated with the CaptiFi live API."
else
    error_msg=$(echo "$response" | grep -o '"message":"[^"]*' | cut -d'"' -f4)
    echo "Activation failed: $error_msg"
    echo "Please check your PIN and try again."
fi
