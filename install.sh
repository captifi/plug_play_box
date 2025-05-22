#!/bin/sh

# CaptiFi Plug & Play Box Installer
# This script installs CaptiFi on OpenWRT devices
# Website: https://captifi.io

# Step 1: Create the base installer
cat > /tmp/captifi-install.sh << 'EOF'
#!/bin/sh
echo "Installing CaptiFi Captive Portal..."

# Install required packages
opkg update
opkg install curl

# Create necessary directories
mkdir -p /www/captifi/api
mkdir -p /etc/captifi/scripts

# Create API endpoint script
cat > /www/captifi/api/activate.cgi << 'CGI_EOF'
#!/bin/sh
# CaptiFi API Integration
API_ENDPOINT="https://api.captifi.io/api/plug-and-play/activate"
API_KEY="CAPTIFI_API_KEY" # Will be replaced during setup

# Get MAC address
MAC_ADDRESS=$(cat /sys/class/net/br-lan/address 2>/dev/null)
if [ -z "$MAC_ADDRESS" ]; then
    MAC_ADDRESS=$(ip link show br-lan 2>/dev/null | grep -o 'link/ether [0-9a-f:]\+' | cut -d' ' -f2)
fi
if [ -z "$MAC_ADDRESS" ]; then
    MAC_ADDRESS="00:00:00:00:00:00"  # Will be replaced with actual MAC
fi

# Process API request
read POST_DATA
PIN=$(echo $POST_DATA | grep -o '"pin":"[^"]*' | cut -d'"' -f4)

# Send headers
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

# Send API request
RESPONSE=$(curl -s -k -L -X POST "$API_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "X-API-KEY: $API_KEY" \
    -d "{\"pin\":\"$PIN\",\"box_mac_address\":\"$MAC_ADDRESS\",\"serial\":\"OpenWrt-Device\"}")

# Return response
echo "$RESPONSE"

# Setup heartbeat if successful
if echo "$RESPONSE" | grep -q '"success"[[:space:]]*:[[:space:]]*true'; then
    SERVER_ID=$(echo "$RESPONSE" | grep -o '"server_id":[0-9]*' | cut -d':' -f2)
    echo "$SERVER_ID" > /etc/captifi/server_id
    
    # Create heartbeat script
    cat > /etc/captifi/scripts/heartbeat.sh << 'EOSCRIPT'
#!/bin/sh
MAC_ADDRESS=$(cat /sys/class/net/br-lan/address)
SERVER_ID=$(cat /etc/captifi/server_id)
UPTIME=$(cat /proc/uptime | awk '{print $1}')
curl -k -L -X POST "https://api.captifi.io/api/plug-and-play/heartbeat" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: CAPTIFI_API_KEY" \
  -d "{\"mac_address\":\"$MAC_ADDRESS\",\"server_id\":$SERVER_ID,\"uptime\":$UPTIME,\"serial\":\"OpenWrt-Device\",\"device_model\":\"OpenWrt\"}" > /tmp/heartbeat_response.log 2>&1
EOSCRIPT
    chmod +x /etc/captifi/scripts/heartbeat.sh
    
    # Add cron job
    mkdir -p /etc/crontabs
    echo "*/5 * * * * /etc/captifi/scripts/heartbeat.sh" > /etc/crontabs/root
    /etc/init.d/cron restart
fi
CGI_EOF
chmod +x /www/captifi/api/activate.cgi

# Create device info
cat > /www/captifi/api/device_info.json << EOF
{
    "mac_address": "$(cat /sys/class/net/br-lan/address)"
}
EOF

# Create HTML page
cat > /www/captifi/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CaptiFi Setup</title>
    <style>
        body { font-family: Arial; margin: 0; background: #f5f5f5; display: flex; justify-content: center; align-items: center; height: 100vh; }
        .container { background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); padding: 30px; width: 90%; max-width: 400px; text-align: center; }
        h1 { color: #333; margin-bottom: 30px; }
        input { width: 100%; padding: 12px; margin: 10px 0; border: 1px solid #ddd; border-radius: 4px; box-sizing: border-box; font-size: 16px; }
        button { background: #4a89dc; color: white; border: none; padding: 12px 20px; border-radius: 4px; cursor: pointer; font-size: 16px; width: 100%; margin-top: 10px; }
        .error, .success { margin-top: 10px; display: none; }
        .error { color: red; }
        .success { color: green; }
        .loader { display: none; border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; width: 30px; height: 30px; animation: spin 2s linear infinite; margin: 15px auto; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        .debug { margin-top: 20px; text-align: left; font-size: 12px; color: #777; display: none; }
    </style>
</head>
<body>
    <div class="container">
        <h1>CaptiFi Setup</h1>
        <form id="pinForm">
            <input type="text" id="pin" placeholder="Enter PIN" pattern="[0-9]{8}" maxlength="8" required>
            <button type="submit" id="submitBtn">Activate</button>
        </form>
        <div class="loader" id="loader"></div>
        <div id="errorMsg" class="error">Activation failed. Please check your PIN and try again.</div>
        <div id="successMsg" class="success">Activation successful. Redirecting to the internet...</div>
        <div id="debug" class="debug"></div>
    </div>
    <script>
        function debugLog(msg) { const debug = document.getElementById('debug'); debug.style.display = 'block'; debug.innerHTML += msg + '<br>'; }
        async function activatePin(pin) {
            const loader = document.getElementById('loader');
            const errorMsg = document.getElementById('errorMsg');
            const successMsg = document.getElementById('successMsg');
            const submitBtn = document.getElementById('submitBtn');
            errorMsg.style.display = 'none';
            successMsg.style.display = 'none';
            loader.style.display = 'block';
            submitBtn.disabled = true;
            try {
                let macAddress = "";
                try {
                    const response = await fetch('/api/device_info.json');
                    if (response.ok) {
                        const data = await response.json();
                        macAddress = data.mac_address;
                        debugLog('MAC: ' + macAddress);
                    }
                } catch(e) { debugLog('MAC error: ' + e.message); }
                if (!macAddress) macAddress = "00:00:00:00:00:00";
                
                const xhr = new XMLHttpRequest();
                xhr.open('POST', '/api/activate.cgi', true);
                xhr.onload = function() {
                    loader.style.display = 'none';
                    submitBtn.disabled = false;
                    debugLog('Response: ' + xhr.responseText);
                    let result;
                    try { result = JSON.parse(xhr.responseText); } catch(e) { debugLog('Parse error: ' + e.message); }
                    if (result && result.success) {
                        successMsg.style.display = 'block';
                        setTimeout(() => { window.location.href = "http://www.google.com"; }, 3000);
                    } else if (result) {
                        errorMsg.textContent = result.message || 'Activation failed. Please check your PIN.';
                        errorMsg.style.display = 'block';
                    }
                };
                xhr.onerror = function() {
                    loader.style.display = 'none';
                    submitBtn.disabled = false;
                    errorMsg.textContent = 'Network error';
                    errorMsg.style.display = 'block';
                };
                xhr.setRequestHeader('Content-Type', 'application/json');
                xhr.send(JSON.stringify({pin: pin, box_mac_address: macAddress}));
            } catch(error) {
                loader.style.display = 'none';
                submitBtn.disabled = false;
                errorMsg.textContent = 'Error: ' + error.message;
                errorMsg.style.display = 'block';
            }
        }
        document.getElementById('pinForm').addEventListener('submit', function(e) {
            e.preventDefault();
            const pin = document.getElementById('pin').value;
            debugLog('PIN: ' + pin);
            activatePin(pin);
        });
        document.querySelector('h1').addEventListener('click', function() {
            debugLog('Debug mode');
        });
    </script>
</body>
</html>
HTML_EOF

# Configure network and services
echo "Configuring network..."

# Service file
cat > /etc/init.d/captifi << 'SERVICE_EOF'
#!/bin/sh /etc/rc.common
START=99
start() {
    mkdir -p /www/captifi/api
    cat > /www/captifi/api/device_info.json << EOD
{ "mac_address": "$(cat /sys/class/net/br-lan/address)" }
EOD
    if [ -f "/etc/captifi/server_id" ]; then
        /etc/init.d/cron restart
    fi
}
stop() { return 0; }
SERVICE_EOF
chmod +x /etc/init.d/captifi
/etc/init.d/captifi enable

# Configure WiFi
uci set wireless.captifi=wifi-iface
uci set wireless.captifi.device=radio0
uci set wireless.captifi.mode=ap
uci set wireless.captifi.ssid=CaptiFi-Setup
uci set wireless.captifi.encryption=none
uci set wireless.captifi.network=captifi

# Network
uci set network.captifi=interface
uci set network.captifi.proto=static
uci set network.captifi.ipaddr=192.168.8.1
uci set network.captifi.netmask=255.255.255.0
uci set network.captifi.type=bridge

# DHCP
uci set dhcp.captifi=dhcp
uci set dhcp.captifi.interface=captifi
uci set dhcp.captifi.start=100
uci set dhcp.captifi.limit=150
uci set dhcp.captifi.leasetime=1h

# Firewall
uci add firewall zone
uci set firewall.@zone[-1].name=captifi
uci set firewall.@zone[-1].input=ACCEPT
uci set firewall.@zone[-1].output=ACCEPT
uci set firewall.@zone[-1].forward=REJECT
uci set firewall.@zone[-1].network=captifi

# DNS redirects
uci add_list dhcp.@dnsmasq[0].address='/connectivitycheck.gstatic.com/192.168.8.1'
uci add_list dhcp.@dnsmasq[0].address='/www.gstatic.com/192.168.8.1'
uci add_list dhcp.@dnsmasq[0].address='/www.google.com/192.168.8.1'
uci add_list dhcp.@dnsmasq[0].address='/clients3.google.com/192.168.8.1'
uci add_list dhcp.@dnsmasq[0].address='/captive.apple.com/192.168.8.1'
uci add_list dhcp.@dnsmasq[0].address='/detectportal.firefox.com/192.168.8.1'

# Web server
uci set uhttpd.main.home=/www/captifi
uci set uhttpd.main.cgi_prefix=/api
uci set uhttpd.main.interpreter='.cgi=/bin/sh'

# Commit all changes
uci commit wireless
uci commit network
uci commit dhcp
uci commit firewall
uci commit uhttpd

# Restart services
echo "Restarting services..."
/etc/init.d/captifi start
/etc/init.d/network restart
/etc/init.d/firewall restart
/etc/init.d/uhttpd restart
/etc/init.d/dnsmasq restart

echo "CaptiFi installation complete!"
echo "Connect to the 'CaptiFi-Setup' WiFi network to activate the device."
EOF

# Make executable and run
chmod +x /tmp/captifi-install.sh
/tmp/captifi-install.sh
