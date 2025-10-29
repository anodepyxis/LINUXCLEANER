#!/usr/bin/env bash
# ==============================================================
# Author: Anode Pyxis
# Operating System: Debian-based Linux
# Version: 1.0
# ==============================================================

# ---------------------------- #
#  Paths & Logging
# ---------------------------- #
LOG_DIR="/var/log"
LOG_FILE="$LOG_DIR/deepclean-$(date '+%Y%m%d-%H%M%S').log"
DATE_NOW=$(date '+%Y-%m-%d %H:%M:%S')
NOTIFY_CMD=$(command -v notify-send)

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

notify() {
    [[ -n "$NOTIFY_CMD" ]] && notify-send "🧹 System Maintenance" "$1"
}

section() {
    echo -e "\n${YELLOW}=== $1 ===${RESET}"
    log ">> $1"
}

require_root() {
    [[ $EUID -ne 0 ]] && { echo -e "${RED}⚠️ Please run as root (sudo).${RESET}"; exit 1; }
}

safe_run() {
    "$@" >> "$LOG_FILE" 2>&1 || log "⚠️ Command failed: $*"
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
find "$LOG_DIR" -type f -name "deepclean*.log" -mtime +7 -exec rm -f {} \;
log "Old logs older than 7 days removed."

# ---------------------------- #
#  Environment Awareness
# ---------------------------- #
section "Environment Awareness"
DEBIAN_VERSION=$(lsb_release -d 2>/dev/null | awk -F"\t" '{print $2}' || cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2)
KERNEL_VERSION=$(uname -r)
ARCHITECTURE=$(uname -m)
DESKTOP_ENV=${XDG_CURRENT_DESKTOP:-Unknown}
log "Debian Version: $DEBIAN_VERSION"
log "Kernel Version: $KERNEL_VERSION"
log "Architecture: $ARCHITECTURE"
log "Desktop Environment: $DESKTOP_ENV"

# ---------------------------- #
#  1. APT Maintenance
# ---------------------------- #
section "APT Maintenance"
safe_run apt-get update -y
safe_run apt-get upgrade -y
safe_run apt-get autoremove -y
safe_run apt-get autoclean -y

# ---------------------------- #
#  2. Verify Package Integrity (Optional)
# ---------------------------- #
if command -v debsums &>/dev/null; then
    section "Verifying Installed Packages"
    safe_run debsums -s >> "$LOG_FILE" 2>&1
else
    log "Debsums not installed, skipping package verification."
fi

# ---------------------------- #
#  3. Rebuild System Caches
# ---------------------------- #
section "Rebuilding System Caches"
safe_run fc-cache -fv
safe_run update-mime-database /usr/share/mime
safe_run update-desktop-database

# ---------------------------- #
#  4. Verify Systemd Services
# ---------------------------- #
section "Verifying Systemd Services"
safe_run systemctl daemon-reexec
safe_run systemctl daemon-reload
safe_run systemctl --failed | tee -a "$LOG_FILE"

# ---------------------------- #
#  5. Optional: Timeshift Snapshot (if installed)
# ---------------------------- #
if command -v timeshift &>/dev/null; then
    section "Creating Timeshift Snapshot (Pre-Maintenance)"
    safe_run timeshift --create --comments "Pre-maintenance snapshot"
fi

# ---------------------------- #
#  6. System Health Summary
# ---------------------------- #
section "System Health Summary"
echo "Uptime: $(uptime -p)" | tee -a "$LOG_FILE"
echo "Disk Usage:" | tee -a "$LOG_FILE"
df -h --total | grep total | tee -a "$LOG_FILE"
free -h | grep Mem: | tee -a "$LOG_FILE"

# ---------------------------- #
#  Done
# ---------------------------- #
notify "Maintenance complete! System verified and optimized."
section "Maintenance Complete ✅"
log "Maintenance finished successfully at $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${GREEN}✅ All done!${RESET}"
echo "Check $LOG_FILE for full report."
echo "------------------------------------------------------"
