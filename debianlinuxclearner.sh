#!/usr/bin/env bash
# ==============================================================
# Author: Anode Pyxis (Last Update Date: 23rd June 2026)
# Operating System: Debian-based Linux
# Version: 1.0
# ==============================================================

# ---------------------------- #
#  Paths & Logging
# ---------------------------- #
LOG_DIR="/var/log"
LOG_FILE="$LOG_DIR/deepclean-$(date '+%Y%m%d-%H%M%S').log"
DATE_NOW=$(date '+%Y-%m-%d %H:%M:%S')

# Color Codes
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

# ---------------------------- #
#  Functions
# ---------------------------- #
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${RESET} $1" | tee -a "$LOG_FILE"
}

# Fixed: Forwards notification to the actual logged-in user session through sudo
notify() {
    if command -v notify-send &>/dev/null && [[ -n "$SUDO_USER" ]]; then
        sudo -u "$SUDO_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$SUDO_USER")/bus" \
        notify-send "🧹 System Maintenance" "$1"
    fi
}

section() {
    echo -e "\n${YELLOW}=== $1 ===${RESET}"
    log ">> $1"
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}⚠️ Please run as root (sudo).${RESET}"
        exit 1
    fi
}

# Fixed: Returns execution status seamlessly so downstream conditional checks work
safe_run() {
    "$@" >> "$LOG_FILE" 2>&1
    local status=$?
    if [[ $status -ne 0 ]]; then
        log "⚠️ Command failed: $* (Exit Code: $status)"
    fi
    return $status
}

# ---------------------------- #
#  Start
# ---------------------------- #
clear
echo -e "${GREEN}🧹 Debian-based System Maintenance (anodepyxis)${RESET}"
echo "Started at: $DATE_NOW"
echo "Log file: $LOG_FILE"
echo "------------------------------------------------------"

require_root
notify "Starting system maintenance..."

# ---------------------------- #
#  Log Rotation: Keep only 7 days
# ---------------------------- #
section "Log Rotation"
mkdir -p "$LOG_DIR"
find "$LOG_DIR" -maxdepth 1 -type f -name "deepclean*.log" -mtime +7 -exec rm -f {} \;
log "Old logs older than 7 days removed."

# ---------------------------- #
#  Environment Awareness
# ---------------------------- #
section "Environment Awareness"
DEBIAN_VERSION=$(lsb_release -d 2>/dev/null | awk -F"\t" '{print $2}' || grep '^PRETTY_NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
KERNEL_VERSION=$(uname -r)
ARCHITECTURE=$(uname -m)
DESKTOP_ENV=${XDG_CURRENT_DESKTOP:-Unknown}
log "Debian Version: $DEBIAN_VERSION"
log "Kernel Version: $KERNEL_VERSION"
log "Architecture: $ARCHITECTURE"
log "Desktop Environment: $DESKTOP_ENV"

# ---------------------------- #
#  1. Timeshift Snapshot (PRE-MAINTENANCE)
# ---------------------------- #
# Fixed: Moved to top so you have a functional fallback if an upgrade goes south
if command -v timeshift &>/dev/null; then
    section "Creating Timeshift Snapshot"
    safe_run timeshift --create --comments "Pre-maintenance snapshot"
else
    log "Timeshift not installed. Skipping backup."
fi

# ---------------------------- #
#  2. APT Maintenance
# ---------------------------- #
section "APT Maintenance"
log "Updating package indexes..."
safe_run apt-get update -y

# Fixed: Switched to interactive full-upgrade to avoid breaking package transitions silently
echo -e "${BLUE}[System Upgrade]${RESET} Launching interactive distribution upgrade..."
apt-get dist-upgrade

log "Removing unneeded packages and purging leftover configuration files..."
safe_run apt-get autoremove --purge -y

log "Clearing local repository cache..."
safe_run apt-get autoclean -y
safe_run apt-get clean -y

# ---------------------------- #
#  3. Optional Package Integrity Check
# ---------------------------- #
section "Verifying Installed Packages"
if command -v debsums &>/dev/null; then
    log "Running debsums verification (checking MD5 sums)..."
    # Fixed: Removed double redirection syntax error
    safe_run debsums -s
else
    log "debsums not installed. Skipping integrity verification."
fi

# ---------------------------- #
#  4. Rebuild System Caches
# ---------------------------- #
section "Rebuilding System Caches"
safe_run fc-cache -fv
safe_run update-mime-database /usr/share/mime
if command -v update-desktop-database &>/dev/null; then
    safe_run update-desktop-database
fi

# ---------------------------- #
#  5. Verify Systemd Services
# ---------------------------- #
section "Verifying Systemd Services"
safe_run systemctl daemon-reexec
safe_run systemctl daemon-reload

log "Checking for failed systemd services..."
# Fixed: Fixed pipeline blocking logic to capture output safely
FAILED_SERVICES=$(systemctl --failed --no-legend)
if [[ -n "$FAILED_SERVICES" ]]; then
    echo "$FAILED_SERVICES" | tee -a "$LOG_FILE"
else
    log "All systemd services are healthy."
fi

# ---------------------------- #
#  6. System Health Summary
# ---------------------------- #
section "System Health Summary"
{
    echo "Uptime: $(uptime -p)"
    echo "Disk Usage:"
    df -h --total | grep total
    free -h | grep Mem:
} | tee -a "$LOG_FILE"

# ---------------------------- #
#  Done
# ---------------------------- #
notify "Maintenance complete! System verified and optimized."
section "Maintenance Complete ✅"
log "Maintenance finished successfully at $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${GREEN}✅ All done!${RESET}"
echo "Check $LOG_FILE for full report."
echo "------------------------------------------------------"
