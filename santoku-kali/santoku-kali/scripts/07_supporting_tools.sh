#!/bin/bash
# =============================================================================
# 07_supporting_tools.sh
# Covers screenshots 6-8:
#   Programming: iPython, Sqliteman
#   System Tools: (GDebi etc already on system)
#   Internet: Chromium, Firefox, Pidgin, Sylpheed, Transmission, Zenmap
#   Plus: YARA, binwalk, metasploit, sqlmap, nuclei, apkleaks, APKiD extras
# =============================================================================
source "$(dirname "$0")/common.sh"
LOG_FILE="$LOGS/07_supporting_tools.log"
mkdir -p "$LOGS" "$TOOLS" "$BIN"

section "PROGRAMMING & SUPPORTING TOOLS"

# ── iPython ───────────────────────────────────────────────────────────────────
install_ipython() {
    info "Installing iPython..."
    mkdir -p "$TOOLS/ipython"
    make_venv "ipython"
    pip_install "ipython" "ipython" "ipython[all]"
    make_wrapper "ipython" "ipython" "ipython"
    make_wrapper "ipython3" "ipython" "ipython3"
    success "iPython installed"
}

# ── Sqliteman / DB Browser for SQLite ────────────────────────────────────────
install_sqliteman() {
    info "Installing DB Browser for SQLite (sqliteman replacement)..."
    apt_install sqlitebrowser sqlite3
    command -v sqlitebrowser &>/dev/null \
        && success "DB Browser for SQLite installed" \
        || warn "sqlitebrowser not found via apt"
    # Also install sqliteman if available
    apt_install sqliteman 2>/dev/null || true
}

# ── YARA ─────────────────────────────────────────────────────────────────────
install_yara() {
    info "Installing YARA..."
    apt_install yara
    mkdir -p "$TOOLS/yara"
    make_venv "yara"
    pip_install "yara" "yara-python"
    make_wrapper "yara" "yara" "yara"
    success "YARA installed"
}

# ── binwalk ───────────────────────────────────────────────────────────────────
install_binwalk() {
    info "Installing binwalk..."
    apt_install binwalk
    command -v binwalk &>/dev/null \
        && success "binwalk installed" \
        || {
            mkdir -p "$TOOLS/binwalk"
            make_venv "binwalk"
            pip_install "binwalk" "binwalk"
            make_wrapper "binwalk" "binwalk" "binwalk"
        }
}

# ── Metasploit Framework ──────────────────────────────────────────────────────
install_metasploit() {
    info "Installing Metasploit Framework..."
    if command -v msfconsole &>/dev/null; then
        success "Metasploit already installed on Kali"
    else
        apt_install metasploit-framework
        command -v msfconsole &>/dev/null \
            && success "Metasploit installed" \
            || warn "Metasploit not available via apt — may need manual install"
    fi
}

# ── sqlmap ────────────────────────────────────────────────────────────────────
install_sqlmap() {
    info "Installing sqlmap..."
    apt_install sqlmap 2>/dev/null || {
        mkdir -p "$TOOLS/sqlmap"
        make_venv "sqlmap"
        pip_install "sqlmap" "sqlmap"
        make_wrapper "sqlmap" "sqlmap" "sqlmap"
    }
    success "sqlmap installed"
}

# ── Nuclei ────────────────────────────────────────────────────────────────────
install_nuclei() {
    info "Installing Nuclei..."
    apt_install nuclei 2>/dev/null || {
        local dir="$TOOLS/nuclei"
        mkdir -p "$dir"
        # Install Go if needed
        apt_install golang-go
        GOPATH="$dir/go" go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest >> "$LOG_FILE" 2>&1
        make_wrapper "nuclei" "nuclei" "$dir/go/bin/nuclei"
    }
    success "Nuclei installed"
}

# ── APKLeaks ──────────────────────────────────────────────────────────────────
install_apkleaks() {
    info "Installing APKLeaks (secret finder in APKs)..."
    mkdir -p "$TOOLS/apkleaks"
    make_venv "apkleaks"
    pip_install "apkleaks" "apkleaks"
    make_wrapper "apkleaks" "apkleaks" "apkleaks"
    success "APKLeaks installed"
}

# ── Pidgin ────────────────────────────────────────────────────────────────────
install_pidgin() {
    info "Installing Pidgin..."
    apt_install pidgin
    command -v pidgin &>/dev/null \
        && success "Pidgin installed" \
        || warn "Pidgin not found"
}

# ── Wireshark / tshark / Zenmap already handled in other scripts ──────────────

# ── Additional forensic utilities ─────────────────────────────────────────────
install_forensic_utils() {
    info "Installing additional forensic utilities..."
    apt_install \
        foremost \
        strings \
        hexedit \
        xxd \
        file \
        ltrace \
        strace \
        gdb \
        patchelf \
        checksec
    success "Forensic utilities installed"
}

# ── Python security libraries (used across multiple tools) ────────────────────
install_python_security_libs() {
    info "Installing Python security libraries (shared venv)..."
    local dir="$TOOLS/pylibs"
    mkdir -p "$dir"
    make_venv "pylibs"
    pip_install "pylibs" \
        "pycryptodome" \
        "paramiko" \
        "scapy" \
        "impacket" \
        "pyopenssl" \
        "requests" \
        "beautifulsoup4" \
        "lxml" \
        "pwntools"
    success "Python security libraries installed"
}

# ── ADB Wrapper with common shortcuts ────────────────────────────────────────
install_adb_helpers() {
    info "Creating ADB helper shortcuts..."
    cat > "$BIN/adb-screenshot" <<'SCRIPT'
#!/bin/bash
adb shell screencap -p /sdcard/screen.png
adb pull /sdcard/screen.png ./screen_$(date +%s).png
adb shell rm /sdcard/screen.png
echo "[+] Screenshot saved"
SCRIPT

    cat > "$BIN/adb-logcat-app" <<'SCRIPT'
#!/bin/bash
# Usage: adb-logcat-app com.target.app
PID=$(adb shell pidof "$1" 2>/dev/null)
[[ -z "$PID" ]] && { echo "App not running"; exit 1; }
adb logcat --pid="$PID"
SCRIPT

    cat > "$BIN/adb-pull-apk" <<'SCRIPT'
#!/bin/bash
# Usage: adb-pull-apk com.target.app
PKG="$1"
PATH_ON_DEVICE=$(adb shell pm path "$PKG" | cut -d: -f2 | tr -d '\r')
echo "[*] Pulling from: $PATH_ON_DEVICE"
adb pull "$PATH_ON_DEVICE" "./${PKG}.apk"
echo "[+] Saved: ./${PKG}.apk"
SCRIPT

    cat > "$BIN/adb-frida-start" <<'SCRIPT'
#!/bin/bash
# Start frida-server on device (assumes already pushed)
adb shell "su -c '/data/local/tmp/frida-server &'" 2>/dev/null || \
adb shell "/data/local/tmp/frida-server &"
echo "[+] Frida server started"
SCRIPT

    chmod +x "$BIN/adb-screenshot" "$BIN/adb-logcat-app" "$BIN/adb-pull-apk" "$BIN/adb-frida-start"
    success "ADB helpers created"
}

install_ipython
install_sqliteman
install_yara
install_binwalk
install_metasploit
install_sqlmap
install_nuclei
install_apkleaks
install_pidgin
install_forensic_utils
install_python_security_libs
install_adb_helpers

success "=== Supporting Tools complete ==="
