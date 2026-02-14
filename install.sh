#!/bin/bash

# Unifi PPPoE MTU Fix Installer
# Installs or updates the fix-mtu scripts on UnifiOS.

REPO_USER="ishioni"
REPO_NAME="unifi-pppoe-fix-mtu"
BRANCH="master"
INSTALL_DIR="/data/fix-mtu"
SERVICE_DEST="/etc/systemd/system/fix-mtu.service"
TEMP_DIR="/tmp/unifi-pppoe-fix-mtu-install"
CONF_FILE="$INSTALL_DIR/fix-mtu.conf"
OLD_SCRIPT="$INSTALL_DIR/fix-mtu.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check for root
if [ "$EUID" -ne 0 ]; then
  log_error "Please run as root."
  exit 1
fi

# Ensure /data exists (UnifiOS specific)
if [ ! -d "/data" ]; then
    log_error "/data directory does not exist. This script must be run on a UnifiOS device."
    exit 1
fi

# Setup cleanup trap
cleanup() {
  rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# 1. Download
log_info "Downloading latest version..."
rm -rf "${TEMP_DIR}"
mkdir -p "${TEMP_DIR}"

TAR_URL="https://github.com/${REPO_USER}/${REPO_NAME}/archive/refs/heads/${BRANCH}.tar.gz"
TAR_FILE="$TEMP_DIR/repo.tar.gz"

if command -v curl >/dev/null 2>&1; then
    curl -L -o "$TAR_FILE" "$TAR_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -O "$TAR_FILE" "$TAR_URL"
else
    log_error "Neither curl nor wget found. Please install one."
    exit 1
fi

if [ ! -f "$TAR_FILE" ]; then
    log_error "Download failed."
    exit 1
fi

# 2. Extract
log_info "Extracting..."
tar -xzf "$TAR_FILE" -C "$TEMP_DIR"
if [ $? -ne 0 ]; then
    log_error "Extraction failed."
    exit 1
fi

EXTRACTED_DIR=$(ls -d "$TEMP_DIR"/*/ | head -n 1)

# 3. Install Files
log_info "Installing to $INSTALL_DIR..."
if ! [ -d $INSTALL_DIR ]; then
  mkdir -p "$INSTALL_DIR"
  if [ $? -ne 0 ]; then
      log_error "$INSTALL_DIR creation failed."
      exit 1
  fi
fi

# Config file not present, preserve old values
if [[ -f "$OLD_SCRIPT" && ! -f "$CONF_FILE" ]]; then
    mv "$OLD_SCRIPT" "$OLD_SCRIPT.old"
fi

cp "${EXTRACTED_DIR}"/*.{sh,service} "${INSTALL_DIR}/"
if ! [ -f ${CONF_FILE} ]; then
  cp "${EXTRACTED_DIR}/*.conf" "${INSTALL_DIR}/"
  echo ""
  echo "IMPORTANT:"
  echo "Configuration is now stored in $CONF_FILE."
  echo "Your previous settings are preserved in $OLD_SCRIPT.old"
  echo ""
  echo "Please edit this file if you need to change your Interface or VLAN settings."
  echo ""
fi
# Make executable
chmod +x "$INSTALL_DIR/"*.sh

# 4. Configure Service
log_info "Installing service..."
cp "$INSTALL_DIR/fix-mtu.service" "$SERVICE_DEST"
systemctl daemon-reload
echo "Start with systemctl start fix-mtu.service"
echo "Enable on boot with systemctl enable fix-mtu.service"
log_info "Installation complete!"
