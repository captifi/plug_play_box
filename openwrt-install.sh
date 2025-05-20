#!/bin/sh

# CaptiFi Plug & Play Box Installation Script for OpenWrt
# -------------------------------------------------------
# This script downloads and installs all necessary files for CaptiFi integration

# Configuration
SERVER_URL="https://app.captifi.io/api"
REPO_URL="https://github.com/captifi/plug_play_box/archive/refs/heads/main.zip"
TEMP_DIR="/tmp/captifi_install"
LOG_FILE="/var/log/captifi_install.log"

# Function to log messages
log_message() {
    echo "$(date): $1" >> $LOG_FILE
    echo "$1"
}

# Function to check if a package is installed
is_package_installed() {
    opkg list-installed | grep -q "^$1 "
    return $?
}

# Function to install required packages
install_requirements() {
    log_message "Checking and installing required packages..."
    
    # Update package lists
    opkg update
    
    # List of required packages
    REQ_PACKAGES="curl wget unzip uhttpd uhttpd-mod-lua"
    
    # Check and install each package
    for pkg in $REQ_PACKAGES; do
        if ! is_package_installed $pkg; then
            log_message "Installing $pkg..."
            opkg install $pkg
            if [ $? -ne 0 ]; then
                log_message "Failed to install $pkg. Installation cannot continue."
                return 1
            fi
        else
            log_message "Package $pkg is already installed."
        fi
    done
    
    return 0
}

# Function to download the repository files
download_files() {
    log_message "Downloading files from repository..."
    
    # Create temporary directory
    mkdir -p $TEMP_DIR
    
    # Download the repository zip file
    wget -q $REPO_URL -O $TEMP_DIR/captifi.zip
    
    if [ $? -ne 0 ]; then
        log_message "Failed to download files from the repository. Check your internet connection."
        return 1
    fi
    
    # Extract the zip file
    unzip -q -o $TEMP_DIR/captifi.zip -d $TEMP_DIR
    
    if [ $? -ne 0 ]; then
        log_message "Failed to extract the downloaded files."
        return 1
    fi
    
    log_message "Files downloaded and extracted successfully."
    return 0
}

# Function to install the files to their respective locations
install_files() {
    log_message "Installing files to their respective locations..."
    
    # Source directory with all extracted files
    SRC_DIR="$TEMP_DIR/plug_play_box-main"
    
    # Create necessary directories if they don't exist
    mkdir -p /www/captifi/assets
    
    # Copy web files
    cp -r $SRC_DIR/www/captifi/* /www/captifi/
    
    # Set executable permissions for CGI scripts
    chmod +x /www/captifi/activate.cgi
    
    # Copy configuration files
    cp -r $SRC_DIR/etc/config/* /etc/config/
    
    # Copy and enable the init script
    cp $SRC_DIR/etc/init.d/captifi /etc/init.d/
    chmod +x /etc/init.d/captifi
    
    # Copy the client script
    cp /usr/bin/captifi-client.sh /usr/bin/captifi-client.sh.backup 2>/dev/null
    
    log_message "Files installed successfully."
    return 0
}

# Function to configure the system
configure_system() {
    log_message "Configuring the system..."
    
    # Update the server URL in the client script if needed
    if [ -n "$SERVER_URL" ]; then
        if [ -f /usr/bin/captifi-client.sh ]; then
            sed -i "s|CAPTIFI_SERVER=.*|CAPTIFI_SERVER=\"$SERVER_URL\"|g" /usr/bin/captifi-client.sh
        fi
    fi
    
    # Enable the captifi service to start on boot
    /etc/init.d/captifi enable
    
    # Restart necessary services
    /etc/init.d/uhttpd restart
    /etc/init.d/firewall restart
    /etc/init.d/captifi restart
    
    log_message "System configured successfully."
    return 0
}

# Function to clean up temporary files
cleanup() {
    log_message "Cleaning up..."
    rm -rf $TEMP_DIR
    log_message "Cleanup completed."
}

# Main installation process
main() {
    log_message "Starting CaptiFi Plug & Play Box installation..."
    
    # Create log file directory if it doesn't exist
    mkdir -p $(dirname $LOG_FILE)
    
    # Step 1: Install requirements
    install_requirements
    if [ $? -ne 0 ]; then
        log_message "Failed to install required packages. Aborting installation."
        cleanup
        return 1
    fi
    
    # Step 2: Download files
    download_files
    if [ $? -ne 0 ]; then
        log_message "Failed to download required files. Aborting installation."
        cleanup
        return 1
    fi
    
    # Step 3: Install files
    install_files
    if [ $? -ne 0 ]; then
        log_message "Failed to install files. Aborting installation."
        cleanup
        return 1
    fi
    
    # Step 4: Configure system
    configure_system
    if [ $? -ne 0 ]; then
        log_message "Failed to configure system. Installation may be incomplete."
        cleanup
        return 1
    fi
    
    # Step 5: Clean up
    cleanup
    
    log_message "CaptiFi Plug & Play Box installation completed successfully!"
    log_message "To activate your box, use: captifi-client.sh activate <YOUR_PIN>"
    
    return 0
}

# Run the main installation process
main

exit $?
