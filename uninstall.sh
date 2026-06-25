#!/bin/bash

# UniFi PPPoE MTU Fix Uninstaller
# Removes the fix-mtu service and files from UniFiOS.
#
# By default, this script does NOT modify /etc/ppp/peers/* because
# UniFi Network 10.5+ now supports PPPoE 1500 MTU natively.
#
# Optional flags:
#   --restore-peer        Restore mtu/mru values in /etc/ppp/peers/<PPP_INTERFACE>
#   --restore-mtu <mtu>   Target mtu/mru to restore when using --restore-peer (default: 1492)
#   --reboot              Reboot the gateway after uninstall completes
#   --help                Show usage

INSTALL_DIR="/data/fix-mtu"
SERVICE_NAME="fix-mtu.service"
SERVICE_DEST="/etc/systemd/system/${SERVICE_NAME}"
CONF_FILE="${INSTALL_DIR}/fix-mtu.conf"
DEFAULT_PPP_INTERFACE="ppp0"
DEFAULT_RESTORE_MTU="1492"

RESTORE_PEER=false
RESTORE_MTU="${DEFAULT_RESTORE_MTU}"
REBOOT_AFTER=false
PPP_INTERFACE="${DEFAULT_PPP_INTERFACE}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --restore-peer        Restore mtu/mru values in /etc/ppp/peers/<PPP_INTERFACE>
  --restore-mtu <mtu>   Target mtu/mru to restore with --restore-peer (default: ${DEFAULT_RESTORE_MTU})
  --reboot              Reboot after uninstall completes
  --help                Show this help message

Examples:
  $0
  $0 --restore-peer
  $0 --restore-peer --restore-mtu 1492 --reboot
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --restore-peer)
      RESTORE_PEER=true
      shift
      ;;
    --restore-mtu)
      if [ -z "$2" ]; then
        log_error "Missing value for --restore-mtu"
        usage
        exit 1
      fi
      RESTORE_MTU="$2"
      shift 2
      ;;
    --reboot)
      REBOOT_AFTER=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [ "$EUID" -ne 0 ]; then
  log_error "Please run as root."
  exit 1
fi

if ! [[ "$RESTORE_MTU" =~ ^[0-9]+$ ]]; then
  log_error "--restore-mtu must be a numeric value."
  exit 1
fi

if [ -f "$CONF_FILE" ]; then
  CONF_PPP_INTERFACE=$(grep -E '^PPP_INTERFACE=' "$CONF_FILE" | tail -n 1 | cut -d'=' -f2-)
  if [ -n "$CONF_PPP_INTERFACE" ]; then
    PPP_INTERFACE="$CONF_PPP_INTERFACE"
  fi
fi

restore_peer_file() {
  local peer_file="/etc/ppp/peers/${PPP_INTERFACE}"
  local backup_file
  backup_file="${peer_file}.fix-mtu-uninstall.bak.$(date +%Y%m%d%H%M%S)"

  if [ ! -f "$peer_file" ]; then
    log_warn "PPP peer file not found: $peer_file"
    return 0
  fi

  if ! cp "$peer_file" "$backup_file"; then
    log_error "Failed to back up $peer_file"
    return 1
  fi

  if ! sed -E -i '' "s/^([[:space:]]*(mtu|mru)[[:space:]]+)1500([[:space:]]*)$/\1${RESTORE_MTU}\3/" "$peer_file" 2>/dev/null; then
    sed -E -i "s/^([[:space:]]*(mtu|mru)[[:space:]]+)1500([[:space:]]*)$/\1${RESTORE_MTU}\3/" "$peer_file"
  fi

  log_info "Backed up PPP peer file to $backup_file"
  log_info "Restored mtu/mru 1500 -> ${RESTORE_MTU} in $peer_file where present"
}

log_info "Stopping ${SERVICE_NAME} if present..."
systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true

log_info "Disabling ${SERVICE_NAME} if present..."
systemctl disable "$SERVICE_NAME" >/dev/null 2>&1 || true

if [ "$RESTORE_PEER" = true ]; then
  log_info "Restoring PPP peer settings for ${PPP_INTERFACE}..."
  restore_peer_file || exit 1
else
  log_warn "Skipping PPP peer restore. This is the correct default for UniFi Network 10.5+ native PPPoE 1500 MTU support."
  log_warn "If you want to roll back mtu/mru entries to ${RESTORE_MTU}, rerun with: --restore-peer --restore-mtu ${RESTORE_MTU}"
fi

if [ -f "$SERVICE_DEST" ]; then
  log_info "Removing service file ${SERVICE_DEST}..."
  rm -f "$SERVICE_DEST"
else
  log_info "Service file already absent: ${SERVICE_DEST}"
fi

log_info "Reloading systemd..."
systemctl daemon-reload >/dev/null 2>&1 || true

if [ -d "$INSTALL_DIR" ]; then
  log_info "Removing install directory ${INSTALL_DIR}..."
  rm -rf "$INSTALL_DIR"
else
  log_info "Install directory already absent: ${INSTALL_DIR}"
fi

log_info "Uninstall complete."
log_info "Recommended next step: reboot the gateway or reconnect WAN so UniFi can fully reapply its managed network configuration."

if [ "$REBOOT_AFTER" = true ]; then
  log_warn "Rebooting now..."
  reboot
fi
