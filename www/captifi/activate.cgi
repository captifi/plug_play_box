#!/bin/sh

# CaptiFi Activation CGI Script
# This script is called by the setup page to activate the box

# Send headers
echo "Content-Type: application/json"
echo ""

# Parse form data
eval $(echo "$QUERY_STRING" | sed 's/&/;/g;s/+/ /g;s/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\\\\\x\1/g;s/=/ = /')

# Also handle POST data if method is POST
if [ "$REQUEST_METHOD" = "POST" ]; then
    # Get content length
    read_content_length=$(echo "$HTTP_CONTENT_LENGTH" | tr -cd '0-9')
    
    if [ -n "$read_content_length" ]; then
        # Read POST data
        post_data=$(dd bs=1 count=$read_content_length 2>/dev/null)
        
        # Parse POST data
        eval $(echo "$post_data" | sed 's/&/;/g;s/+/ /g;s/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\\\\\x\1/g;s/=/ = /')
    fi
fi

# Validate PIN
if [ -z "$pin" ]; then
    echo '{"success":false,"message":"PIN is required"}'
    exit 1
fi

# Call captifi-client.sh to activate the box
RESULT=$(captifi-client.sh "$pin" 2>&1)

if echo "$RESULT" | grep -q "Box activated successfully"; then
    # Extract server_id from the successful result
    SERVER_ID=$(echo "$RESULT" | sed -n 's/.*Server ID: \([0-9]*\).*/\1/p')
    
    echo "{\"success\":true,\"message\":\"Device activated successfully!\",\"server_id\":$SERVER_ID}"
    
    # Schedule a restart of services (runs in background so response isn't delayed)
    (sleep 5 && /etc/init.d/captifi restart && /etc/init.d/uhttpd restart) &
else
    # Extract error message
    ERROR_MSG=$(echo "$RESULT" | sed -n 's/.*Activation failed: \(.*\)/\1/p')
    if [ -z "$ERROR_MSG" ]; then
        ERROR_MSG="Unknown error occurred"
    fi
    
    # JSON escape the error message
    ERROR_MSG=$(echo "$ERROR_MSG" | sed 's/"/\\"/g')
    
    echo "{\"success\":false,\"message\":\"$ERROR_MSG\"}"
fi
