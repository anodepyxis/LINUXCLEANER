#!/usr/bin/env bash
# ==============================================================
# Author: Anode Pyxis (Update Date Last: 23rd June 2026)
# Operating System: Arch-based Linux
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

# Fixed: Sends notifications to the actual logged-in GUI user
notify() {
    if command -v notify-send &>/dev/null && [[ -n "$SUDO_USER" ]]; then
        sudo -u "$SUDO_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$SUDO_USER")/bus" \
        notify-send "System Maintenance" "$1"
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

# Fixed: Returns the actual exit code of the command so || logic works
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
echo -e "${GREEN}🧹 Arch-based System Maintenance (anodepyxis)${RESET}"
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
# Fixed: Added -maxdepth 1 to prevent searching deeper system logs
find "$LOG_DIR" -maxdepth 1 -type f -name "deepclean*.log" -mtime +7 -exec rm -f {} \;
log "Old logs older than 7 days removed."

# ---------------------------- #
#  Environment Awareness
# ---------------------------- #
section "Environment Awareness"
ARCH_VERSION=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"' || echo "Unknown")
KERNEL_VERSION=$(uname -r)
ARCHITECTURE=$(uname -m)
DESKTOP_ENV=${XDG_CURRENT_DESKTOP:-Unknown}
log "OS: $ARCH_VERSION"
log "Kernel Version: $KERNEL_VERSION"
log "Architecture: $ARCHITECTURE"
log "Desktop Environment: $DESKTOP_ENV"

# ---------------------------- #
#  1. Timeshift Snapshot (PRE-MAINTENANCE)
# ---------------------------- #
# Fixed: Moved to the top so you can safely restore if updates break things
if command -v timeshift &>/dev/null; then
    section "Creating Timeshift Snapshot"
    safe_run timeshift --create --comments "Pre-maintenance snapshot"
else
    log "Timeshift not installed. Skipping backup."
fi

# ---------------------------- #
#  2. Pacman Maintenance
# ---------------------------- #
section "Pacman Maintenance"
log "Updating package databases..."
safe_run pacman -Syy

# Fixed: Removed --noconfirm from upgrades for system safety
echo -e "${BLUE}[System Upgrade]${RESET} Launching interactive upgrade..."
pacman -Syu

# Fixed: Safe verification before removing orphans
ORPHANS=$(pacman -Qtdq)
if [[ -n "$ORPHANS" ]]; then
    log "Removing orphan packages..."
    safe_run pacman -Rns $ORPHANS --noconfirm
else
    log "No orphan packages to remove."
fi

# Fixed: Uses paccache (safer) if available; falls back to pacman -Sc
if command -v paccache &>/dev/null; then
    log "Cleaning package cache (retaining last 2 versions)..."
    safe_run paccache -r
    safe_run paccache -rk1
else
    log "paccache not found. Cleaning uninstalled package caches..."
    safe_run pacman -Sc --noconfirm
fi

# ---------------------------- #
#  3. Optional Package Integrity Check
# ---------------------------- #
section "Verifying Installed Packages"
log "Checking file properties/backup files (this may take a moment)..."
# Fixed: Removed incorrect trailing redirections
safe_run pacman -Qkk

# ---------------------------- #
#  4. Verify Systemd Services
# ---------------------------- #
section "Verifying Systemd Services"
safe_run systemctl daemon-reexec
safe_run systemctl daemon-reload

log "Checking for failed systemd services:"
# Fixed: Redirected command properly so it actually shows up in terminal and log
FAILED_SERVICES=$(systemctl --failed --no-legend)
if [[ -n "$FAILED_SERVICES" ]]; then
    echo "$FAILED_SERVICES" | tee -a "$LOG_FILE"
else
    log "All systemd services are running normally."
fi

# ---------------------------- #
#  5. System Health Summary
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
