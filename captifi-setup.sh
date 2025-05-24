#!/bin/sh

# CaptiFi One-Time Setup Script
# This script performs the initial setup for CaptiFi on OpenWRT devices
# It collects necessary configuration, sets up firewall rules, and configures the environment

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo or switch to root user."
    exit 1
fi

# Define colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${BLUE}=======================================================${NC}"
echo "${BLUE}       CaptiFi OpenWRT Installation and Setup          ${NC}"
echo "${BLUE}=======================================================${NC}"
echo
echo "${YELLOW}This script will:${NC}"
echo "  1. Collect API credentials and server information"
echo "  2. Set up the necessary directory structure"
echo "  3. Configure firewall rules for secure communication"
echo "  4. Install required components"
echo
echo "${RED}IMPORTANT:${NC} Make sure you have a working internet connection."
echo

# Confirm before proceeding
echo -n "Do you want to continue? [y/N]: "
read CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Setup cancelled."
    exit 0
fi

# Check if it's an OpenWRT system
if [ ! -f "/etc/openwrt_release" ]; then
    echo "${RED}Warning:${NC} This doesn't appear to be an OpenWRT system."
    echo -n "Continue anyway? [y/N]: "
    read CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        echo "Setup cancelled."
        exit 0
    fi
fi

# Create necessary directories
mkdir -p /etc/captifi
mkdir -p /var/log/captifi
mkdir -p /www/cgi-bin

# Collect API information
echo "${BLUE}=======================================================${NC}"
echo "${YELLOW}API Configuration${NC}"
echo "${BLUE}=======================================================${NC}"

# Default values
DEFAULT_API_ENDPOINT="https://api.captifi.io/api/plug-and-play/activate"
DEFAULT_API_SERVER_IP="157.230.53.133"

# Ask for API key
echo -n "Enter your CaptiFi API key: "
read API_KEY

# Validate API key
if [ -z "$API_KEY" ]; then
    echo "${RED}API key cannot be empty. Using placeholder - you must update this later!${NC}"
    API_KEY="YOUR_API_KEY_HERE"
fi

# Ask for API endpoint
echo -n "Enter API endpoint [${DEFAULT_API_ENDPOINT}]: "
read API_ENDPOINT
if [ -z "$API_ENDPOINT" ]; then
    API_ENDPOINT="${DEFAULT_API_ENDPOINT}"
fi

# Ask for API server IP
echo -n "Enter API server IP [${DEFAULT_API_SERVER_IP}]: "
read API_SERVER_IP
if [ -z "$API_SERVER_IP" ]; then
    API_SERVER_IP="${DEFAULT_API_SERVER_IP}"
fi

# Create environment file
cat > /etc/captifi/.env << EOF
# CaptiFi API Configuration
# Generated on $(date)

# API Key for CaptiFi services
CAPTIFI_API_KEY=${API_KEY}

# API Endpoints
CAPTIFI_API_ENDPOINT=${API_ENDPOINT}
CAPTIFI_API_SERVER_IP=${API_SERVER_IP}
EOF

# Set proper permissions
chmod 600 /etc/captifi/.env
chmod 755 /etc/captifi
chmod 755 /var/log/captifi

echo "${GREEN}API configuration saved to /etc/captifi/.env${NC}"

# Firewall configuration
echo "${BLUE}=======================================================${NC}"
echo "${YELLOW}Firewall Configuration${NC}"
echo "${BLUE}=======================================================${NC}"

# Check if firewall config exists
if [ ! -f "/etc/config/firewall" ]; then
    echo "${RED}Warning:${NC} Firewall configuration not found at /etc/config/firewall"
    echo "Skipping firewall configuration. You will need to configure the firewall manually."
else
    # Check if captifi zone already exists
    if grep -q "option name 'captifi'" /etc/config/firewall; then
        echo "CaptiFi zone already exists in firewall configuration."
    else
        # Add captifi zone
        cat >> /etc/config/firewall << EOF

config zone
	option name 'captifi'
	option input 'ACCEPT'
	option output 'ACCEPT'
	option forward 'REJECT'
	option network 'captifi'
EOF
        echo "${GREEN}Added CaptiFi zone to firewall configuration.${NC}"
    fi

    # Check if API rule already exists
    if grep -q "Allow-Captifi-API" /etc/config/firewall; then
        echo "CaptiFi API rule already exists in firewall configuration."
    else
        # Add API rule
        cat >> /etc/config/firewall << EOF

config rule
	option name 'Allow-Captifi-API'
	option src 'lan'
	option dest 'wan'
	option dest_ip '${API_SERVER_IP}'
	option proto 'tcp'
	option dest_port '443'
	option target 'ACCEPT'
EOF
        echo "${GREEN}Added CaptiFi API rule to firewall configuration.${NC}"
    fi

    # Restart firewall to apply changes
    echo "Restarting firewall to apply changes..."
    /etc/init.d/firewall restart
    echo "${GREEN}Firewall restarted successfully.${NC}"
fi

# Copy activation scripts
echo "${BLUE}=======================================================${NC}"
echo "${YELLOW}Installing Activation Scripts${NC}"
echo "${BLUE}=======================================================${NC}"

# Copy CGI script
cat > /www/cgi-bin/activate.cgi << 'EOF'
#!/bin/sh

# CaptiFi Activation CGI Script
# This script handles device activation with PINs

# Set up logging
LOG_DIR="/var/log/captifi"
LOG_FILE="$LOG_DIR/activation.log"

# Create log directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

# Initialize log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
fi

# Log start of script execution
echo "$(date): Activation script started" >> $LOG_FILE

# Set content type to JSON
echo "Content-Type: application/json"
echo ""

# Parse query string for GET method
if [ "$REQUEST_METHOD" = "GET" ]; then
    # Process query string
    QUERY_STRING_DECODED=$(printf "%b" "${QUERY_STRING//%/\\x}")
    
    # Extract PIN and MAC address from query string
    PIN=$(echo "$QUERY_STRING_DECODED" | grep -oE "(^|&)pin=([^&]+)" | cut -d= -f2)
    MAC_ADDRESS=$(echo "$QUERY_STRING_DECODED" | grep -oE "(^|&)mac_address=([^&]+)" | cut -d= -f2)
    
    echo "$(date): GET request - PIN: $PIN, MAC: $MAC_ADDRESS" >> $LOG_FILE
fi

# Parse request body for POST method
if [ "$REQUEST_METHOD" = "POST" ]; then
    # Get content length
    CONTENT_LENGTH=$CONTENT_LENGTH
    
    if [ -z "$CONTENT_LENGTH" ]; then
        CONTENT_LENGTH=$(echo "$HTTP_CONTENT_LENGTH" | tr -cd '0-9')
    fi
    
    if [ -n "$CONTENT_LENGTH" ]; then
        # Read POST data
        POST_DATA=$(dd bs=1 count=$CONTENT_LENGTH 2>/dev/null)
        
        # Extract PIN and MAC address from POST data (assuming JSON)
        PIN=$(echo "$POST_DATA" | grep -o '"pin":"[^"]*"' | cut -d'"' -f4)
        MAC_ADDRESS=$(echo "$POST_DATA" | grep -o '"mac_address":"[^"]*"' | cut -d'"' -f4)
        
        echo "$(date): POST request - PIN: $PIN, MAC: $MAC_ADDRESS" >> $LOG_FILE
    fi
fi

# Generate a serial number if not provided
SERIAL=$(cat /proc/cpuinfo | grep Serial | cut -d ":" -f 2 | tr -d ' ' || echo "OpenWrt-$(cat /sys/class/net/eth0/address 2>/dev/null || echo "$MAC_ADDRESS")")

# Validate required parameters
if [ -z "$PIN" ]; then
    echo "{\"success\":false,\"message\":\"PIN is required\"}"
    echo "$(date): Error - PIN not provided" >> $LOG_FILE
    exit 1
fi

if [ -z "$MAC_ADDRESS" ]; then
    # Try to get MAC address automatically
    MAC_ADDRESS=$(cat /sys/class/net/eth0/address 2>/dev/null || cat /sys/class/net/br-lan/address 2>/dev/null)
    
    if [ -z "$MAC_ADDRESS" ]; then
        echo "{\"success\":false,\"message\":\"MAC address is required\"}"
        echo "$(date): Error - MAC address not provided and couldn't be detected" >> $LOG_FILE
        exit 1
    fi
    
    echo "$(date): Auto-detected MAC address: $MAC_ADDRESS" >> $LOG_FILE
fi

# Define JSON payload
JSON_PAYLOAD="{\"pin\": \"$PIN\", \"box_mac_address\": \"$MAC_ADDRESS\", \"serial\": \"$SERIAL\"}"
echo "$(date): API payload: $JSON_PAYLOAD" >> $LOG_FILE

# Default API configuration
CAPTIFI_API_KEY="YOUR_API_KEY_HERE"
CAPTIFI_API_ENDPOINT="https://api.captifi.io/api/plug-and-play/activate"

# Load API key and endpoint from .env file if it exists
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

# Check for curl errors
if [ $CURL_EXIT_CODE -ne 0 ]; then
    echo "{\"success\":false,\"message\":\"Network error ($CURL_EXIT_CODE): Could not connect to API server\"}"
    echo "$(date): Network error ($CURL_EXIT_CODE)" >> $LOG_FILE
    exit 1
fi

# Check response
echo "$(date): API Response: $API_RESPONSE" >> $LOG_FILE

# Extract server_id from successful response
if echo "$API_RESPONSE" | grep -q "\"success\":true"; then
    SERVER_ID=$(echo "$API_RESPONSE" | sed -n 's/.*"server_id":"\([^"]*\)".*/\1/p')
    if [ -z "$SERVER_ID" ]; then
        SERVER_ID=$(echo "$API_RESPONSE" | sed -n 's/.*"server_id":[ ]*\([0-9]*\).*/\1/p')
    fi
    
    # Format the success response
    SUCCESS_RESPONSE="{\"success\":true,\"message\":\"Device activated successfully!\",\"server_id\":\"$SERVER_ID\"}"
    echo "$SUCCESS_RESPONSE"
    echo "$(date): Activation successful - Server ID: $SERVER_ID" >> $LOG_FILE
    
    # Restart services in the background
    (sleep 5 && /etc/init.d/captifi restart && /etc/init.d/uhttpd restart) &
else
    # Extract error message
    ERROR_MSG=$(echo "$API_RESPONSE" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
    if [ -z "$ERROR_MSG" ]; then
        ERROR_MSG="Failed to activate device"
    fi
    
    # JSON escape the error message
    ERROR_MSG=$(echo "$ERROR_MSG" | sed 's/"/\\"/g')
    
    # Return error response
    echo "{\"success\":false,\"message\":\"$ERROR_MSG\"}"
    echo "$(date): Activation failed - $ERROR_MSG" >> $LOG_FILE
fi

# Log end of script execution
echo "$(date): Activation script completed" >> $LOG_FILE
EOF

# Make CGI script executable
chmod 755 /www/cgi-bin/activate.cgi

# Copy PIN sync script
cat > /usr/bin/captifi-pin-sync << 'EOF'
#!/bin/sh

# OpenWRT PIN Synchronization Script
# This script marks PINs as used through the CaptiFi API directly from an OpenWRT device

# Usage: ./captifi-pin-sync [PIN] [MAC_ADDRESS] [API_KEY]

# Default values and argument parsing
PIN="$1"
MAC_ADDRESS="$2"
API_KEY="${3:-YOUR_API_KEY_HERE}"  # Default API key placeholder

# Try to load API key from environment file
if [ -f /etc/captifi/.env ]; then
    . /etc/captifi/.env
    if [ -n "$CAPTIFI_API_KEY" ]; then
        # Only override if not provided as argument
        if [ "$#" -lt 3 ]; then
            API_KEY="$CAPTIFI_API_KEY"
        fi
    fi
fi

# Interactive mode if arguments not provided
if [ -z "$PIN" ]; then
    # Prompt for PIN
    echo -n "Enter PIN code: "
    read PIN
fi

if [ -z "$MAC_ADDRESS" ]; then
    # Try to auto-detect MAC address
    AUTO_MAC=$(cat /sys/class/net/eth0/address 2>/dev/null || cat /sys/class/net/br-lan/address 2>/dev/null)
    
    if [ -n "$AUTO_MAC" ]; then
        echo "Auto-detected MAC address: $AUTO_MAC"
        echo -n "Use this MAC address? [Y/n]: "
        read USE_AUTO_MAC
        
        if [ -z "$USE_AUTO_MAC" ] || [ "$USE_AUTO_MAC" = "Y" ] || [ "$USE_AUTO_MAC" = "y" ]; then
            MAC_ADDRESS="$AUTO_MAC"
        else
            # Prompt for MAC address
            echo -n "Enter MAC address: "
            read MAC_ADDRESS
        fi
    else
        # Prompt for MAC address
        echo -n "Enter MAC address: "
        read MAC_ADDRESS
    fi
fi

if [ "$#" -lt 3 ] && [ -z "$CAPTIFI_API_KEY" ]; then
    # Prompt for API key
    echo -n "Enter API key (or press Enter to use default): "
    read CUSTOM_API_KEY
    if [ -n "$CUSTOM_API_KEY" ]; then
        API_KEY="$CUSTOM_API_KEY"
    fi
fi

# Validate input
if [ -z "$PIN" ]; then
    echo "Error: PIN is required"
    exit 1
fi

if [ -z "$MAC_ADDRESS" ]; then
    echo "Error: MAC address is required"
    exit 1
fi

# API endpoint configuration
API_ENDPOINT="${CAPTIFI_API_ENDPOINT:-https://api.captifi.io/api/plug-and-play/activate}"

# Temporary files for the request
TEMP_DIR="/tmp/captifi"
mkdir -p "$TEMP_DIR"
JSON_DATA="$TEMP_DIR/pin_sync_request.json"
RESPONSE_FILE="$TEMP_DIR/pin_sync_response.json"

# Create the JSON request data
cat > "$JSON_DATA" << EOF2
{
  "pin": "$PIN",
  "box_mac_address": "$MAC_ADDRESS",
  "serial": "OpenWrt-Device",
  "device_model": "OpenWrt"
}
EOF2

# Log the request
echo "Sending PIN activation request with PIN: $PIN, MAC: $MAC_ADDRESS"
echo "API Endpoint: $API_ENDPOINT"

# Send the request to the API
HTTP_CODE=$(curl -s -k -w "%{http_code}" -o "$RESPONSE_FILE" -X POST "$API_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "X-API-KEY: $API_KEY" \
    --data-binary @"$JSON_DATA" \
    --connect-timeout 10 \
    --max-time 30)

# Check HTTP response code
if [ "$HTTP_CODE" = "000" ]; then
    echo "Error: Could not connect to API server"
    exit 1
fi

# Parse and display the response
if [ -f "$RESPONSE_FILE" ]; then
    # Check if response contains success status
    SUCCESS=$(grep -o '"success":true' "$RESPONSE_FILE" || echo "")
    
    if [ -n "$SUCCESS" ]; then
        SERVER_ID=$(grep -o '"server_id":[0-9]*' "$RESPONSE_FILE" | cut -d':' -f2)
        echo "Box activated successfully!"
        echo "Server ID: $SERVER_ID"
        
        # Create needed configuration files and directories
        mkdir -p /etc/captifi
        
        # Save server ID for future reference
        echo "SERVER_ID=$SERVER_ID" > /etc/captifi/server_config
        
        # Success - restart required services if needed
        if [ -x /etc/init.d/captifi ]; then
            echo "Restarting CaptiFi services..."
            /etc/init.d/captifi restart
        fi
        
        exit 0
    else
        # Try to extract error message
        ERROR_MSG=$(grep -o '"message":"[^"]*"' "$RESPONSE_FILE" | cut -d':' -f2- | tr -d '"')
        
        if [ -n "$ERROR_MSG" ]; then
            echo "Activation failed: $ERROR_MSG"
        else
            echo "Activation failed: Unknown error"
            cat "$RESPONSE_FILE"
        fi
        
        exit 1
    fi
else
    echo "Error: No response received from server"
    exit 1
fi
EOF

# Make PIN sync script executable
chmod 755 /usr/bin/captifi-pin-sync

# Copy test script
cat > /usr/bin/captifi-test << 'EOF'
#!/bin/sh

# Test PIN Activation Script
# This script tests PIN activation with the new environment-based security changes

# Set default values
PIN=${1:-71173735}  # Default PIN to test with (mentioned in the documentation)
MAC_ADDRESS=${2:-"00:11:22:33:44:55"}  # Default MAC address for testing
ENV_FILE="/etc/captifi/.env"

echo "============================================================="
echo "CaptiFi PIN Activation Test"
echo "============================================================="
echo "This script will test PIN activation with the following values:"
echo "PIN: $PIN"
echo "MAC Address: $MAC_ADDRESS"
echo "Environment file: $ENV_FILE (if available)"
echo "============================================================="

# Check if environment file exists
if [ -f "$ENV_FILE" ]; then
    echo "Loading configuration from $ENV_FILE"
    . "$ENV_FILE"
    API_KEY="$CAPTIFI_API_KEY"
    API_ENDPOINT="$CAPTIFI_API_ENDPOINT"
else
    # Prompt for API key if environment file doesn't exist
    echo "No environment file found at $ENV_FILE"
    echo -n "Enter API key: "
    read API_KEY
    
    # Use default API endpoint if not specified
    API_ENDPOINT="https://api.captifi.io/api/plug-and-play/activate"
fi

# Validate required parameters
if [ -z "$API_KEY" ]; then
    echo "Error: API key is required. Either provide it through $ENV_FILE or when prompted."
    exit 1
fi

if [ -z "$PIN" ]; then
    echo "Error: PIN is required"
    exit 1
fi

if [ -z "$MAC_ADDRESS" ]; then
    echo "Error: MAC address is required"
    exit 1
fi

echo "Using API endpoint: $API_ENDPOINT"

# Create JSON payload
JSON_PAYLOAD="{\"pin\": \"$PIN\", \"box_mac_address\": \"$MAC_ADDRESS\", \"serial\": \"TestDevice\", \"device_model\": \"TestModel\"}"
echo "Request payload: $JSON_PAYLOAD"

# Send request
echo "Sending request..."
RESPONSE=$(curl -s -k -L -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: $API_KEY" \
  -H "Accept: application/json" \
  -d "$JSON_PAYLOAD")

# Check response
echo "API Response: $RESPONSE"

if echo "$RESPONSE" | grep -q "\"success\":true"; then
    echo "============================================================="
    echo "✅ PIN Activation SUCCESSFUL!"
    
    # Extract server_id from successful response
    SERVER_ID=$(echo "$RESPONSE" | sed -n 's/.*"server_id":"\([^"]*\)".*/\1/p')
    if [ -z "$SERVER_ID" ]; then
        SERVER_ID=$(echo "$RESPONSE" | sed -n 's/.*"server_id":[ ]*\([0-9]*\).*/\1/p')
    fi
    
    if [ -n "$SERVER_ID" ]; then
        echo "Server ID: $SERVER_ID"
    fi
    echo "============================================================="
    exit 0
else
    # Extract error message
    ERROR_MSG=$(echo "$RESPONSE" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
    if [ -z "$ERROR_MSG" ]; then
        ERROR_MSG="Unknown error occurred"
    fi
    
    echo "============================================================="
    echo "❌ PIN Activation FAILED: $ERROR_MSG"
    echo "============================================================="
    exit 1
fi
EOF

# Make test script executable
chmod 755 /usr/bin/captifi-test

echo "${GREEN}Activation scripts installed successfully.${NC}"

# Configure uhttpd
echo "${BLUE}=======================================================${NC}"
echo "${YELLOW}Configuring Web Server${NC}"
echo "${BLUE}=======================================================${NC}"

# Check if uhttpd is installed
if [ -f "/etc/config/uhttpd" ]; then
    # Enable CGI
    sed -i 's/option cgi_prefix.*/option cgi_prefix "\/cgi-bin"/' /etc/config/uhttpd
    
    # Restart uhttpd
    /etc/init.d/uhttpd restart
    echo "${GREEN}Web server configured and restarted.${NC}"
else
    echo "${YELLOW}Warning:${NC} uhttpd configuration not found. You may need to configure your web server manually."
fi

# Setup complete
echo "${BLUE}=======================================================${NC}"
echo "${GREEN}CaptiFi Setup Complete!${NC}"
echo "${BLUE}=======================================================${NC}"
echo
echo "You can now use the following commands:"
echo "  ${YELLOW}captifi-pin-sync${NC} - Synchronize a PIN with the server"
echo "  ${YELLOW}captifi-test${NC} - Test PIN activation"
echo
echo "Your configuration is stored in ${YELLOW}/etc/captifi/.env${NC}"
echo "To update your API key or server information, edit this file."
echo
echo "Thank you for installing CaptiFi!"
echo "${BLUE}=======================================================${NC}"
