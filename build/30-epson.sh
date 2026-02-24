#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Epson Printer/Scanner Packages Installation
###############################################################################
# This script downloads and installs Epson printer and scanner packages from
# the official Epson Download Center (https://download-center.epson.com/).
#
# Packages installed:
#   - Epson Inkjet Printer Driver (ESC/P-R) for Linux
#   - Epson Printer Utility for Linux
#   - Epson Scan2 for Linux
#
# The script uses the Epson Download Center API to automatically discover
# and download the latest RPM packages. A reference device ID is used to
# query the API, but the packages themselves are generic and support many
# Epson printer/scanner models.
#
# API documentation: https://download-center.epson.com/
# Reference: https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ep/epson-escpr2/update.sh
###############################################################################

# Epson Download Center API configuration
EPSON_API_BASE="https://download-center.epson.com/api/v1/modules"
# Use a multifunction inkjet printer/scanner that supports all three packages
EPSON_DEVICE_ID="ET-2850 Series"
EPSON_API_URL="${EPSON_API_BASE}/?device_id=${EPSON_DEVICE_ID// /%20}&os=RPM&region=US&language=en"

echo "::group:: Install Epson Printer/Scanner Packages"

# Query the Epson Download Center API to get current download URLs
echo "Querying Epson Download Center API: ${EPSON_API_URL}"
API_RESPONSE=$(curl -sSL "${EPSON_API_URL}")

# Parse download URLs from API response using Python3 (available in base image)
# Each package is identified by its module_name in the API response
read -r ESCPR_URL ESCPR_VERSION < <(echo "${API_RESPONSE}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('items', []):
    name = item.get('module_name', '')
    cat = item.get('cti_category', '')
    if 'ESC/P-R' in name and 'Source' not in cat:
        print(item['url'], item.get('version', 'unknown'))
        break
else:
    print('', '')
")

read -r UTILITY_URL UTILITY_VERSION < <(echo "${API_RESPONSE}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('items', []):
    name = item.get('module_name', '')
    if 'Printer Utility' in name:
        print(item['url'], item.get('version', 'unknown'))
        break
else:
    print('', '')
")

read -r SCAN2_URL SCAN2_VERSION < <(echo "${API_RESPONSE}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('items', []):
    name = item.get('module_name', '')
    cat = item.get('cti_category', '')
    if ('Scan 2' in name or 'Scan2' in name) and 'Source' not in cat:
        print(item['url'], item.get('version', 'unknown'))
        break
else:
    print('', '')
")

# Verify all URLs were obtained
if [[ -z "${ESCPR_URL}" ]]; then
    echo "ERROR: Could not get ESC/P-R driver URL from Epson Download Center API"
    exit 1
fi

if [[ -z "${UTILITY_URL}" ]]; then
    echo "ERROR: Could not get Printer Utility URL from Epson Download Center API"
    exit 1
fi

if [[ -z "${SCAN2_URL}" ]]; then
    echo "ERROR: Could not get Scan2 URL from Epson Download Center API"
    exit 1
fi

echo "Epson Inkjet Printer Driver (ESC/P-R) version: ${ESCPR_VERSION}"
echo "  URL: ${ESCPR_URL}"
echo "Epson Printer Utility version: ${UTILITY_VERSION}"
echo "  URL: ${UTILITY_URL}"
echo "Epson Scan2 version: ${SCAN2_VERSION}"
echo "  URL: ${SCAN2_URL}"

# Download packages from Epson Download Center
echo "Downloading Epson packages..."
curl -Lo /tmp/epson-escpr.rpm "${ESCPR_URL}"
curl -Lo /tmp/epson-utility.rpm "${UTILITY_URL}"
curl -Lo /tmp/epson-scan2.rpm "${SCAN2_URL}"

# Install all Epson packages
# Note: lsb is required as a dependency for some Epson RPM packages
dnf5 install -y \
    /tmp/epson-escpr.rpm \
    /tmp/epson-utility.rpm \
    /tmp/epson-scan2.rpm

# Clean up downloaded RPMs
rm -f /tmp/epson-escpr.rpm /tmp/epson-utility.rpm /tmp/epson-scan2.rpm

echo "::endgroup::"

echo "Epson packages installation complete!"
