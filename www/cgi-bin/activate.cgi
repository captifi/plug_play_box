#!/bin/sh
# Add CORS headers to allow requests
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo "Access-Control-Allow-Methods: POST, GET, OPTIONS"
echo "Access-Control-Allow-Headers: Content-Type"
echo ""

# Create log file with timestamps
LOG_FILE="/tmp/captifi_activate.log"
echo "$(date): Activation attempt started" > $LOG_FILE

# Handle OPTIONS preflight request
if [ "$REQUEST_METHOD" = "OPTIONS" ]; then
    # Just end here for OPTIONS requests
    exit 0
fi

# Read POST data
read POST_DATA
echo "$(date): POST data: $POST_DATA" >> $LOG_FILE

# If POST_DATA is empty, output error
if [ -z "$POST_DATA" ]; then
    echo "{\"success\":false,\"message\":\"No data received\",\"server_id\":null,\"site_id\":null}"
    echo "$(date): No POST data received" >> $LOG_FILE
    exit 1
fi

# Extract PIN and MAC
PIN=$(echo $POST_DATA | grep -o '"pin":"[^"]*' | cut -d'"' -f4)
MAC_ADDRESS=$(echo $POST_DATA | grep -o '"mac_address":"[^"]*' | cut -d'"' -f4)
SERIAL="OpenWrt-Device"

echo "$(date): PIN: $PIN, MAC: $MAC_ADDRESS" >> $LOG_FILE

# Check if PIN and MAC were extracted
if [ -z "$PIN" ]; then
    echo "{\"success\":false,\"message\":\"No PIN provided\",\"server_id\":null,\"site_id\":null}"
    echo "$(date): No PIN extracted from data" >> $LOG_FILE
    exit 1
fi

if [ -z "$MAC_ADDRESS" ]; then
    # If MAC wasn't in the POST data, try to get it from system
    MAC_ADDRESS=$(cat /sys/class/net/br-lan/address)
    echo "$(date): MAC not in POST data, using system MAC: $MAC_ADDRESS" >> $LOG_FILE
fi

# Activate via API
echo "$(date): Sending API request..." >> $LOG_FILE

# Define JSON payload
JSON_PAYLOAD="{\"pin\": \"$PIN\", \"box_mac_address\": \"$MAC_ADDRESS\", \"serial\": \"$SERIAL\"}"
echo "$(date): API payload: $JSON_PAYLOAD" >> $LOG_FILE

# Load API key and endpoint from .env file if it exists
CAPTIFI_API_KEY="I0rdMubIPdto5tTCDFr1WT7wcPkyK1S8"
CAPTIFI_API_ENDPOINT="https://157.230.53.133/api/plug-and-play/activate"

if [ -f /etc/captifi/.env ]; then
    echo "$(date): Loading configuration from /etc/captifi/.env" >> $LOG_FILE
    . /etc/captifi/.env
elif [ -f ../../../.env ]; then
    echo "$(date): Loading configuration from ../../../.env" >> $LOG_FILE
    . ../../../.env
fi

# Send request with verbose output
echo "$(date): Using API endpoint: $CAPTIFI_API_ENDPOINT" >> $LOG_FILE
API_RESPONSE=$(curl -k -L --max-redirs 0 -X POST "$CAPTIFI_API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: $CAPTIFI_API_KEY" \
  -H "Accept: application/json" \
  -d "$JSON_PAYLOAD" 2>>$LOG_FILE)

CURL_EXIT_CODE=$?
echo "$(date): curl exit code: $CURL_EXIT_CODE" >> $LOG_FILE
echo "$(date): API response: $API_RESPONSE" >> $LOG_FILE

# Check if curl failed
if [ $CURL_EXIT_CODE -ne 0 ]; then
    echo "{\"success\":false,\"message\":\"API connection error (code $CURL_EXIT_CODE)\",\"server_id\":null,\"site_id\":null}"
    exit 1
fi

# Send the response back to the client
if [ -z "$API_RESPONSE" ]; then
    echo "{\"success\":false,\"message\":\"Empty response from API\",\"server_id\":null,\"site_id\":null}"
else
    echo "$API_RESPONSE"
fi

# If activation was successful, store server_id and configure heartbeat (in background)
SUCCESS=$(echo $API_RESPONSE | grep -o '"success":true')
if [ ! -z "$SUCCESS" ]; then
    # Run the rest in the background to avoid affecting the response
    (
        echo "$(date): Activation successful" >> $LOG_FILE
        
        # Extract server_id
        SERVER_ID=$(echo $API_RESPONSE | grep -o '"server_id":[0-9]*' | cut -d':' -f2)
        echo "$(date): Server ID: $SERVER_ID" >> $LOG_FILE
        
        # Store server_id for later use
        mkdir -p /etc/captifi
        echo $SERVER_ID > /etc/captifi/server_id
        
        # Create heartbeat script if it doesn't exist
        if [ ! -f "/etc/captifi/scripts/heartbeat.sh" ]; then
            mkdir -p /etc/captifi/scripts
            cat > /etc/captifi/scripts/heartbeat.sh << 'EOSCRIPT'
#!/bin/sh

# Get MAC address and server ID
MAC_ADDRESS=$(cat /sys/class/net/br-lan/address)
SERVER_ID=$(cat /etc/captifi/server_id)
UPTIME=$(cat /proc/uptime | awk '{print $1}')
SERIAL="OpenWrt-Device"
MODEL="OpenWrt"

# Send heartbeat - USING DIRECT IP INSTEAD OF app.captifi.io
curl -k -L -X POST "https://157.230.53.133/api/plug-and-play/heartbeat" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: I0rdMubIPdto5tTCDFr1WT7wcPkyK1S8" \
  -d "{\"mac_address\": \"$MAC_ADDRESS\", \"server_id\": $SERVER_ID, \"uptime\": $UPTIME, \"serial\": \"$SERIAL\", \"device_model\": \"$MODEL\"}" > /tmp/heartbeat_response.log 2>&1
EOSCRIPT
            chmod +x /etc/captifi/scripts/heartbeat.sh
            
            # Add cron job for heartbeat
            mkdir -p /etc/crontabs
            echo "*/5 * * * * /etc/captifi/scripts/heartbeat.sh" > /etc/crontabs/root
            /etc/init.d/cron restart
        fi
        
        # Send first heartbeat
        echo "$(date): Sending first heartbeat" >> $LOG_FILE
        /etc/captifi/scripts/heartbeat.sh &
    ) &
fi
