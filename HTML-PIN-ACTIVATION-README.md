# CaptiFi HTML PIN Activation System

This README explains the enhancements made to the CaptiFi HTML PIN activation system for OpenWRT devices.

## Improvements Made

The following improvements have been implemented:

1. **Fixed HTML to CGI Path**
   - Updated to use the correct path to the CGI script: `/cgi-bin/activate.cgi`

2. **Enhanced API Communication**
   - Added the crucial `--max-redirs 0` parameter to prevent redirects
   - Added the Accept header to properly handle JSON responses

3. **Security Enhancements**
   - Moved API keys to a separate `.env` file
   - Created a configuration loading system that checks multiple locations

4. **Deployment & Installation**
   - Created a comprehensive installation script that automates the entire setup process
   - Includes proper environment variable handling

## Installation

### Using the Installer Script

The easiest way to install is using the provided installer script:

```bash
./install-captifi-pin-system-final.sh <DEVICE-IP>
```

This script will:
1. Create necessary directories on the OpenWRT device
2. Copy all required files
3. Set appropriate permissions
4. Configure the environment settings
5. Restart the web server

### Manual Installation

If you prefer to install manually:

1. Copy the fixed files to your OpenWRT device:
   ```bash
   scp captifi-installer-package/www/cgi-bin/activate.cgi root@<DEVICE-IP>:/www/cgi-bin/
   scp captifi-installer-package/www/captifi/setup.html root@<DEVICE-IP>:/www/captifi/
   scp captifi-installer-package/.env root@<DEVICE-IP>:/etc/captifi/
   ```

2. Set proper permissions:
   ```bash
   ssh root@<DEVICE-IP> "chmod +x /www/cgi-bin/activate.cgi"
   ```

3. Restart the web server:
   ```bash
   ssh root@<DEVICE-IP> "/etc/init.d/uhttpd restart"
   ```

## API Configuration

The API key and endpoint are now stored in a `.env` file:

```
# CaptiFi API Configuration
CAPTIFI_API_KEY=I0rdMubIPdto5tTCDFr1WT7wcPkyK1S8
CAPTIFI_API_ENDPOINT=https://157.230.53.133/api/plug-and-play/activate
```

You can modify this file on the OpenWRT device at `/etc/captifi/.env` to change the API settings.

## Testing

### Testing Locally

The `test-html-pin-activation.sh` script creates a test environment for local verification:

```bash
./test-html-pin-activation.sh
```

### Verification

The PIN validation system has been successfully tested with:
- PIN `57575324` (previously used)
- PIN `38880051` (currently showing as available in the backend)

## Troubleshooting

If you encounter issues:

1. Check the debug logs by clicking 5 times on the "CaptiFi Setup" header
2. Verify API connectivity from the OpenWRT device
3. Ensure the CGI script has executable permissions
4. Check the logs at `/tmp/captifi_activate.log` on the OpenWRT device
5. Verify the environment configuration in `/etc/captifi/.env`
