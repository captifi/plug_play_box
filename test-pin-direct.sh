#!/bin/sh
# CaptiFi PIN Testing Script for OpenWRT
# Tests a PIN against the direct API endpoint

# Text colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_PIN="29360580"
DEFAULT_MAC_ADDRESS=$(ifconfig | grep -o -E '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -n 1)
DEFAULT_SERIAL="OpenWrt-Device"

# Display banner
echo "${BLUE}╔═════════════════════════════════════════════╗${NC}"
echo "${BLUE}║           CaptiFi PIN Test Tool             ║${NC}"
echo "${BLUE}╚═════════════════════════════════════════════╝${NC}"

# Get input or use defaults
echo "${YELLOW}Enter PIN to test [${DEFAULT_PIN}]:${NC}"
read PIN
PIN=${PIN:-$DEFAULT_PIN}

echo "${YELLOW}Enter MAC Address [${DEFAULT_MAC_ADDRESS}]:${NC}"
read MAC_ADDRESS
MAC_ADDRESS=${MAC_ADDRESS:-$DEFAULT_MAC_ADDRESS}

echo "${YELLOW}Enter Serial Number [${DEFAULT_SERIAL}]:${NC}"
read SERIAL
SERIAL=${SERIAL:-$DEFAULT_SERIAL}

echo "${BLUE}Testing PIN: ${PIN}${NC}"
echo "${BLUE}MAC Address: ${MAC_ADDRESS}${NC}"
echo "${BLUE}Serial: ${SERIAL}${NC}"
echo ""
echo "${YELLOW}Sending request to API...${NC}"

# Generate JSON data
JSON_DATA="{\"pin\": \"${PIN}\", \"box_mac_address\": \"${MAC_ADDRESS}\", \"serial\": \"${SERIAL}\"}"

# Make API request with curl
RESPONSE=$(curl -s -k -L -X POST "https://157.230.53.133/api/plug-and-play/activate" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: I0rdMubIPdto5tTCDFr1WT7wcPkyK1S8" \
  -d "$JSON_DATA")

# Check if curl request succeeded
if [ $? -ne 0 ]; then
  echo "${RED}Error: Failed to connect to API server${NC}"
  echo "${YELLOW}Possible causes:${NC}"
  echo "• Network connectivity issue"
  echo "• API server is down"
  echo "• DNS resolution problem"
  exit 1
fi

# Extract success value using grep and sed
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":[^,}]*' | sed 's/"success"://g')
MESSAGE=$(echo "$RESPONSE" | grep -o '"message":"[^"]*"' | sed 's/"message":"//g' | sed 's/"//g')
SERVER_ID=$(echo "$RESPONSE" | grep -o '"server_id":[^,}]*' | sed 's/"server_id"://g')

echo ""
echo "${BLUE}╔═════════════════════════════════════════════╗${NC}"
echo "${BLUE}║               RESULT                        ║${NC}"
echo "${BLUE}╚═════════════════════════════════════════════╝${NC}"

if [ "$SUCCESS" = "true" ]; then
  echo "${GREEN}✓ SUCCESS: PIN validated successfully${NC}"
  echo "${BLUE}PIN:${NC} $PIN"
  echo "${BLUE}Server ID:${NC} $SERVER_ID"
  echo "${BLUE}Message:${NC} $MESSAGE"
else
  echo "${RED}✗ ERROR: PIN validation failed${NC}"
  echo "${BLUE}PIN:${NC} $PIN"
  echo "${BLUE}Message:${NC} $MESSAGE"
fi

echo ""
echo "${BLUE}Full API Response:${NC}"
echo "$RESPONSE" | sed 's/,/,\n/g' | sed 's/{/{\n/g' | sed 's/}/\n}/g'
echo ""
echo "${YELLOW}Script completed. To test another PIN, run this script again.${NC}"
