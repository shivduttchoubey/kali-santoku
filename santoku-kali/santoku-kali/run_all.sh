#!/bin/bash
# =============================================================================
#
#   SANTOKU-KALI MASTER INSTALLER
#   Android Application Penetration Testing Toolkit
#
#   Based on Santoku Linux (all tools from screenshots) + modern additions
#
#   Usage:  sudo bash run_all.sh
#           sudo bash run_all.sh --skip-heavy   (skips Ghidra/Android Studio)
#           sudo bash run_all.sh --only 04      (run only script 04)
#
# =============================================================================

set -euo pipefail
SKIP_HEAVY=false
ONLY_SCRIPT=""

for arg in "$@"; do
    [[ "$arg" == "--skip-heavy" ]] && SKIP_HEAVY=true
    [[ "$arg" =~ --only=?([0-9]+) ]] && ONLY_SCRIPT="${BASH_REMATCH[1]}"
done

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Dirs ──────────────────────────────────────────────────────────────────────
BASE="/opt/santoku-kali"
SCRIPTS_DIR="$(cd "$(dirname "$0")/scripts" && pwd)"
LOG_DIR="$BASE/logs"
MASTER_LOG="$LOG_DIR/master_$(date +%Y%m%d_%H%M%S).log"

# ── Checks ────────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && { echo -e "${RED}Run as root: sudo bash $0${NC}"; exit 1; }

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${CYAN}"
cat << 'BANNER'
 ███████╗ █████╗ ███╗   ██╗████████╗ ██████╗ ██╗  ██╗██╗   ██╗
 ██╔════╝██╔══██╗████╗  ██║╚══██╔══╝██╔═══██╗██║ ██╔╝██║   ██║
 ███████╗███████║██╔██╗ ██║   ██║   ██║   ██║█████╔╝ ██║   ██║
 ╚════██║██╔══██║██║╚██╗██║   ██║   ██║   ██║██╔═██╗ ██║   ██║
 ███████║██║  ██║██║ ╚████║   ██║   ╚██████╔╝██║  ██╗╚██████╔╝
 ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝ ╚═════╝
                         KALI EDITION
        Android Application Penetration Testing Toolkit
BANNER
echo -e "${NC}"
echo -e "${BOLD}All tools from Santoku Linux screenshots + modern additions${NC}"
echo -e "${YELLOW}Install base: $BASE${NC}"
echo ""

# ── Prep ─────────────────────────────────────────────────────────────────────
mkdir -p "$BASE/tools" "$BASE/bin" "$LOG_DIR"

# Make ALL scripts in this repo executable automatically
chmod +x "$0"
find "$(dirname "$0")" -name "*.sh" -exec chmod +x {} \;
log "${GREEN}[OK] All .sh scripts marked executable${NC}"

# Copy scripts to install base so wrappers can reference them
cp -r "$SCRIPTS_DIR" "$BASE/scripts" 2>/dev/null || true

log() { echo -e "$*" | tee -a "$MASTER_LOG"; }

# ── System update + base packages ─────────────────────────────────────────────
log "${CYAN}[STEP 0] System update & base packages${NC}"
{
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y \
        build-essential git wget curl unzip zip p7zip-full \
        python3 python3-pip python3-venv python3-dev python3-setuptools \
        default-jdk default-jre \
        libssl-dev libffi-dev libxml2-dev libxslt1-dev zlib1g-dev \
        libpcap-dev libsqlite3-dev \
        android-sdk-platform-tools \
        openjdk-17-jdk openjdk-17-jre \
        ruby ruby-dev \
        golang-go \
        nodejs npm \
        sqlite3 \
        hexedit xxd file strings \
        net-tools iputils-ping \
        2>/dev/null
} >> "$MASTER_LOG" 2>&1
log "${GREEN}[OK] Base packages ready${NC}"

# ── PATH setup ───────────────────────────────────────────────────────────────
PROFILE_LINE="export PATH=\"$BASE/bin:\$PATH\""
for rc in /root/.bashrc /root/.zshrc /home/*/.bashrc /home/*/.zshrc; do
    [[ -f "$rc" ]] && grep -qF "$BASE/bin" "$rc" || echo "$PROFILE_LINE" >> "$rc" 2>/dev/null || true
done
export PATH="$BASE/bin:$PATH"

# ── Script runner ─────────────────────────────────────────────────────────────
PASS=(); FAIL=()

run_script() {
    local num="$1"
    local name="$2"
    local script="$SCRIPTS_DIR/${num}_${name}.sh"

    [[ ! -f "$script" ]] && { log "${YELLOW}[SKIP] $script not found${NC}"; return; }

    log ""
    log "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "${BOLD}[$(date '+%H:%M:%S')] Running: $num — $name${NC}"
    log "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if bash "$script" 2>&1 | tee -a "$MASTER_LOG"; then
        PASS+=("$num $name")
        log "${GREEN}✔ $name COMPLETE${NC}"
    else
        FAIL+=("$num $name")
        log "${RED}✘ $name FAILED — check $LOG_DIR/${num}_${name}.log${NC}"
    fi
}

# ── Run all scripts ───────────────────────────────────────────────────────────
if [[ -n "$ONLY_SCRIPT" ]]; then
    # Find and run only the matching script
    SCRIPT=$(find "$SCRIPTS_DIR" -name "${ONLY_SCRIPT}_*.sh" | head -1)
    [[ -n "$SCRIPT" ]] && bash "$SCRIPT" || log "${RED}Script $ONLY_SCRIPT not found${NC}"
else
    run_script "01" "development_tools"
    run_script "02" "device_forensics"
    run_script "03" "penetration_testing"
    run_script "04" "reverse_engineering"
    run_script "05" "wireless_analyzers"
    run_script "06" "dynamic_analysis"
    run_script "07" "supporting_tools"
fi

# ── Final PATH refresh ────────────────────────────────────────────────────────
export PATH="$BASE/bin:$PATH"

# ── Summary ───────────────────────────────────────────────────────────────────
log ""
log "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
log "${BOLD}  INSTALLATION SUMMARY${NC}"
log "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
log ""

TOTAL_WRAPPERS=$(ls "$BASE/bin" | wc -l)
log "${GREEN}Wrapper commands installed: $TOTAL_WRAPPERS${NC}"
log ""

if [[ ${#PASS[@]} -gt 0 ]]; then
    log "${GREEN}✔ PASSED (${#PASS[@]}):${NC}"
    for p in "${PASS[@]}"; do log "    ✔ $p"; done
fi
if [[ ${#FAIL[@]} -gt 0 ]]; then
    log ""
    log "${RED}✘ FAILED (${#FAIL[@]}):${NC}"
    for f in "${FAIL[@]}"; do log "    ✘ $f"; done
fi

log ""
log "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
log "${BOLD}  AVAILABLE COMMANDS (in $BASE/bin/)${NC}"
log "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
ls "$BASE/bin/" | column | tee -a "$MASTER_LOG"

log ""
log "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
log "${BOLD}  QUICK START${NC}"
log "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
cat << 'QUICKSTART' | tee -a "$MASTER_LOG"

  1. Reload shell:     source ~/.bashrc   (or open new terminal)

  2. Decompile APK:    apktool d app.apk
                       jadx app.apk -d ./output
                       jadx-gui app.apk

  3. Dynamic hook:     frida-server-push        # push to device
                       frida-ps -U              # list processes
                       objection explore        # explore app
                       ssl-bypass com.app       # bypass SSL pinning
                       root-bypass com.app      # bypass root detection

  4. Network capture:  mitmproxy -p 8080
                       wireshark
                       tcpdump -i any

  5. Auto scan:        mobsf                    # http://localhost:8000
                       apkleaks -f app.apk      # find secrets

  6. ADB shortcuts:    adb-pull-apk com.app     # pull APK from device
                       adb-screenshot           # capture screen
                       adb-frida-start          # start frida server

  7. Forensics:        abe info backup.ab       # android backup
                       sleuthkit / autopsy      # disk forensics
                       scalpel -c /etc/scalpel/scalpel.conf device.img

QUICKSTART
log ""
log "${GREEN}${BOLD}  ✔ Santoku-Kali toolkit installed!${NC}"
log "  Tools: $BASE/tools"
log "  Bin:   $BASE/bin"
log "  Logs:  $MASTER_LOG"
log ""
