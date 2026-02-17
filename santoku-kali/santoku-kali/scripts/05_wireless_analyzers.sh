#!/bin/bash
# =============================================================================
# 05_wireless_analyzers.sh
# Covers: Chaosreader, dnschef, DSniff, mitmproxy (venv), tcpdump, wifite, Wireshark
# =============================================================================
source "$(dirname "$0")/common.sh"
LOG_FILE="$LOGS/05_wireless_analyzers.log"
mkdir -p "$LOGS" "$TOOLS" "$BIN"

section "WIRELESS ANALYZERS"

# ── Chaosreader ──────────────────────────────────────────────────────────────
install_chaosreader() {
    info "Installing Chaosreader..."
    apt_install chaosreader
    if ! command -v chaosreader &>/dev/null; then
        # Manual install from GitHub
        local dir="$TOOLS/chaosreader"
        mkdir -p "$dir"
        download "https://raw.githubusercontent.com/brendangregg/Chaosreader/master/chaosreader" \
                 "$dir/chaosreader"
        chmod +x "$dir/chaosreader"
        make_wrapper "chaosreader" "chaosreader" "$dir/chaosreader"
    fi
    success "Chaosreader installed"
}

# ── dnschef ───────────────────────────────────────────────────────────────────
install_dnschef() {
    info "Installing dnschef..."
    apt_install dnschef 2>/dev/null || {
        local dir="$TOOLS/dnschef"
        mkdir -p "$dir"
        make_venv "dnschef"
        pip_install "dnschef" "dnspython" "IPy"
        git_clone "https://github.com/iphelix/dnschef" "$dir/src"
        cat > "$BIN/dnschef" <<EOF
#!/bin/bash
source "$TOOLS/dnschef/venv/bin/activate"
cd "$dir/src" && python3 dnschef.py "\$@"
EOF
        chmod +x "$BIN/dnschef"
    }
    success "dnschef installed"
}

# ── DSniff ────────────────────────────────────────────────────────────────────
install_dsniff() {
    info "Installing dsniff..."
    apt_install dsniff
    command -v dsniff &>/dev/null \
        && success "dsniff installed" \
        || warn "dsniff not available"
}

# ── tcpdump ───────────────────────────────────────────────────────────────────
install_tcpdump() {
    info "Installing tcpdump..."
    apt_install tcpdump
    command -v tcpdump &>/dev/null \
        && success "tcpdump installed ($(tcpdump --version 2>&1 | head -1))" \
        || warn "tcpdump not found"
}

# ── Wifite ────────────────────────────────────────────────────────────────────
install_wifite() {
    info "Installing wifite2..."
    apt_install wifite 2>/dev/null || {
        local dir="$TOOLS/wifite"
        mkdir -p "$dir"
        make_venv "wifite"
        git_clone "https://github.com/derv82/wifite2" "$dir/src"
        "$TOOLS/wifite/venv/bin/pip" install -r "$dir/src/requirements.txt" >> "$LOG_FILE" 2>&1 || true
        cat > "$BIN/wifite" <<EOF
#!/bin/bash
source "$TOOLS/wifite/venv/bin/activate"
cd "$dir/src" && python3 Wifite.py "\$@"
EOF
        chmod +x "$BIN/wifite"
    }
    success "wifite installed"
}

# ── Wireshark ─────────────────────────────────────────────────────────────────
install_wireshark() {
    info "Installing Wireshark..."
    # Pre-answer debconf to allow non-root capture
    echo "wireshark-common wireshark-common/install-setuid boolean true" \
        | debconf-set-selections 2>/dev/null || true
    apt_install wireshark tshark
    command -v wireshark &>/dev/null \
        && success "Wireshark installed ($(wireshark --version | head -1))" \
        || warn "Wireshark not found"
}

# ── Aircrack-ng suite (bonus) ─────────────────────────────────────────────────
install_aircrack() {
    info "Installing Aircrack-ng suite..."
    apt_install aircrack-ng
    command -v aircrack-ng &>/dev/null \
        && success "Aircrack-ng installed" \
        || warn "Aircrack-ng not found"
}

# ── Bettercap (modern ettercap alternative) ───────────────────────────────────
install_bettercap() {
    info "Installing Bettercap..."
    apt_install bettercap 2>/dev/null || {
        local dir="$TOOLS/bettercap"
        mkdir -p "$dir"
        download "https://github.com/bettercap/bettercap/releases/download/v2.32.0/bettercap_linux_amd64_v2.32.0.zip" \
                 "/tmp/bettercap.zip"
        unzip -q /tmp/bettercap.zip -d "$dir"
        rm /tmp/bettercap.zip
        make_wrapper "bettercap" "bettercap" "$dir/bettercap"
    }
    success "Bettercap installed"
}

install_chaosreader
install_dnschef
install_dsniff
install_tcpdump
install_wifite
install_wireshark
install_aircrack
install_bettercap

success "=== Wireless Analyzers complete ==="
