#!/usr/bin/env bash
# ==============================================================
# Author: Anode Pyxis (Last Update Date: 23rd June 2026)
# For Operating Systems: Fedora Based Linux
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

# Fixed: Locates the active GUI user session so notifications render on-screen
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

# Fixed: Captures and returns valid terminal return codes for conditional statements
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
echo -e "${GREEN}🧹 Fedora System Maintenance (anodepyxis)${RESET}"
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
FEDORA_VERSION=$(rpm -E %fedora)
KERNEL_VERSION=$(uname -r)
ARCHITECTURE=$(uname -m)
DESKTOP_ENV=${XDG_CURRENT_DESKTOP:-Unknown}
log "Fedora Version: $FEDORA_VERSION"
log "Kernel Version: $KERNEL_VERSION"
log "Architecture: $ARCHITECTURE"
log "Desktop Environment: $DESKTOP_ENV"

# ---------------------------- #
#  1. Timeshift Snapshot (PRE-MAINTENANCE)
# ---------------------------- #
# Fixed: Repositioned to the top so you can safely rollback if updates break the system
if command -v timeshift &>/dev/null; then
    section "Creating Timeshift Snapshot"
    safe_run timeshift --create --comments "Pre-maintenance snapshot"
else
    log "Timeshift not installed. Skipping backup."
fi

# ---------------------------- #
#  2. DNF System Upgrades
# ---------------------------- #
section "DNF Package Optimization & Upgrades"

# Fixed: Switched upgrade to interactive mode to allow reviewing package updates safely
echo -e "${BLUE}[System Upgrade]${RESET} Synchronizing mirrors and running upgrades..."
dnf upgrade --refresh

log "Running post-upgrade integrity verification check..."
safe_run dnf check

log "Removing orphaned/unused dependencies..."
safe_run dnf autoremove -y

log "Purging systemic DNF download caches..."
safe_run dnf clean all

# ---------------------------- #
#  3. System Integrity Check
# ---------------------------- #
section "RPM Verification"
log "Verifying package file attributes against RPM database..."
# Fixed: Resolved the broken pipeline syntax inside safe_run
RPM_VERIFY=$(rpm --verify --all 2>/dev/null | grep -v "missing")
if [[ -n "$RPM_VERIFY" ]]; then
    echo "$RPM_VERIFY" >> "$LOG_FILE"
else
    log "All system files passed RPM verification."
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
# Fixed: Extracted standard output safely to prevent command execution blocking
FAILED_SERVICES=$(systemctl --failed --no-legend)
if [[ -n "$FAILED_SERVICES" ]]; then
    echo "$FAILED_SERVICES" | tee -a "$LOG_FILE"
else
    log "All systemd units are running cleanly."
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
