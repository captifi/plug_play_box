#!/usr/bin/lua

-- CaptiFi Setup - Lua script for handling box activation
-- This script processes the setup form and activates the box with the CaptiFi server

local uhttpd = require "uhttpd"
local io = require "io"

-- Function to get device MAC address
local function get_mac_address()
    local handle = io.popen("ifconfig br-lan | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' | head -n 1")
    local mac = handle:read("*a")
    handle:close()
    
    if mac and #mac > 0 then
        return mac:gsub("%s+", "")
    end
    
    -- Fallback to eth0 if br-lan doesn't exist
    handle = io.popen("ifconfig eth0 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' | head -n 1")
    mac = handle:read("*a")
    handle:close()
    
    if mac and #mac > 0 then
        return mac:gsub("%s+", "")
    end
    
    return "00:00:00:00:00:00" -- Fallback if no MAC address found
end

-- Function to call captifi-client.sh script
local function activate_with_pin(pin)
    local mac = get_mac_address()
    local cmd = string.format("/usr/bin/captifi-client.sh activate %s", pin)
    
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    local success = handle:close()
    
    if result:match("Box activated successfully") then
        -- Successful activation
        return {
            success = true,
            message = "Device activated successfully!",
            mac_address = mac
        }
    else
        -- Activation failed
        local error_msg = result:match("Activation failed: (.+)") or "Activation failed"
        return {
            success = false,
            message = error_msg,
            mac_address = mac
        }
    end
end

-- Function to render HTML with given MAC address
local function render_page(mac, params)
    -- Read the HTML template
    local file = io.open("/www/captifi/setup.html", "r")
    if not file then
        uhttpd.send("Status: 500 Internal Server Error\r\n")
        uhttpd.send("Content-Type: text/html\r\n\r\n")
        uhttpd.send("<h1>Error: Could not load setup page template</h1>")
        return
    end
    
    local html = file:read("*a")
    file:close()
    
    -- Replace MAC address placeholder
    html = html:gsub("@@MAC_ADDRESS@@", mac)
    
    -- Insert error message if present
    if params and params.error then
        html = html:gsub('<div id="error%-message" class="error%-message" style="display: none;"></div>', 
                         string.format('<div id="error-message" class="error-message">%s</div>', params.error))
    end
    
    -- Insert success message if present
    if params and params.success then
        html = html:gsub('<div id="success%-message" class="success%-message" style="display: none;"></div>', 
                         string.format('<div id="success-message" class="success-message">%s</div>', params.success))
        -- Hide the form if activation was successful
        html = html:gsub('<form id="activation%-form">', '<form id="activation-form" style="display: none;">')
    end
    
    -- Send the rendered HTML
    uhttpd.send("Status: 200 OK\r\n")
    uhttpd.send("Content-Type: text/html\r\n\r\n")
    uhttpd.send(html)
end

-- Check if the config file exists and if the box is already activated
local function is_box_activated()
    local file = io.open("/etc/captifi_config", "r")
    if not file then
        return false
    end
    
    local content = file:read("*a")
    file:close()
    
    return content:match("ACTIVATED=true") ~= nil
end

-- Main request handler
local function handle_request()
    -- Get MAC address
    local mac = get_mac_address()
    
    -- Check if already activated
    if is_box_activated() then
        -- If already activated, redirect to splash page
        uhttpd.send("Status: 302 Found\r\n")
        uhttpd.send("Location: /splash\r\n")
        uhttpd.send("\r\n")
        return
    end
    
    -- Check if this is a POST request (form submission)
    if uhttpd.request_method == "POST" then
        local pin = uhttpd.vars.pin
        
        if not pin or pin == "" then
            render_page(mac, { error = "PIN is required" })
            return
        end
        
        -- Validate PIN format (8 digits)
        if not pin:match("^%d%d%d%d%d%d%d%d$") then
            render_page(mac, { error = "PIN must be 8 digits" })
            return
        end
        
        -- Try to activate the box
        local result = activate_with_pin(pin)
        
        if result.success then
            render_page(mac, { success = "Device activated successfully! Redirecting to captive portal..." })
            
            -- Schedule a reload of services to apply the new configuration
            os.execute("(sleep 5 && /etc/init.d/captifi restart && /etc/init.d/uhttpd restart) &")
        else
            render_page(mac, { error = result.message })
        end
    else
        -- GET request - just display the form
        render_page(mac)
    end
end

-- Execute the request handler
handle_request()
