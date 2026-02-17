#!/bin/bash
# =============================================================================
# 03_penetration_testing.sh
# Covers: Burp Suite, Ettercap, nmap, SSLStrip, w3af (Console+GUI), ZAP, Zenmap
# =============================================================================
source "$(dirname "$0")/common.sh"
LOG_FILE="$LOGS/03_penetration_testing.log"
mkdir -p "$LOGS" "$TOOLS" "$BIN"

section "PENETRATION TESTING"

# ── Burp Suite Community ─────────────────────────────────────────────────────
install_burpsuite() {
    info "Installing Burp Suite Community Edition..."
    local dir="$TOOLS/burpsuite"
    mkdir -p "$dir"

    # Latest community jar via GitHub releases API fallback URL
    local url="https://portswigger-cdn.net/burp/releases/download?product=community&version=2024.1.1.6&type=Jar"
    download "$url" "$dir/burpsuite_community.jar"

    cat > "$dir/burpsuite" <<'EOF'
#!/bin/bash
exec java -jar "$(dirname "$0")/burpsuite_community.jar" "$@"
EOF
    chmod +x "$dir/burpsuite"
    make_wrapper "burpsuite" "burpsuite" "$dir/burpsuite"
    success "Burp Suite Community installed"
}

# ── Ettercap ─────────────────────────────────────────────────────────────────
install_ettercap() {
    info "Installing Ettercap..."
    apt_install ettercap-text-only ettercap-graphical
    command -v ettercap &>/dev/null \
        && success "Ettercap installed" \
        || warn "Ettercap not found via apt"
}

# ── nmap + Zenmap ────────────────────────────────────────────────────────────
install_nmap() {
    info "Installing nmap + zenmap..."
    apt_install nmap zenmap-kbx 2>/dev/null || apt_install nmap
    # zenmap may be called zenmap-kbx on newer Kali
    command -v nmap &>/dev/null \
        && success "nmap installed ($(nmap --version | head -1))" \
        || warn "nmap not found"
}

# ── SSLStrip ─────────────────────────────────────────────────────────────────
install_sslstrip() {
    info "Installing SSLStrip..."
    local dir="$TOOLS/sslstrip"
    mkdir -p "$dir"
    make_venv "sslstrip"
    pip_install "sslstrip" "twisted" "pyOpenSSL"
    git_clone "https://github.com/moxie0/sslstrip" "$dir/src"
    cat > "$BIN/sslstrip" <<EOF
#!/bin/bash
source "$TOOLS/sslstrip/venv/bin/activate"
cd "$dir/src" && python3 sslstrip.py "\$@"
EOF
    chmod +x "$BIN/sslstrip"
    success "SSLStrip installed"
}

# ── w3af ─────────────────────────────────────────────────────────────────────
install_w3af() {
    info "Installing w3af..."
    local dir="$TOOLS/w3af"
    mkdir -p "$dir"
    make_venv "w3af"

    # w3af dependencies
    pip_install "w3af" \
        "pyOpenSSL" "ndg-httpsclient" "pyasn1" \
        "setuptools" "lxml" "scapy" 2>/dev/null || true

    git_clone "https://github.com/andresriancho/w3af" "$dir/src"
    cd "$dir/src"
    # Install pip reqs from w3af
    "$TOOLS/w3af/venv/bin/pip" install -r requirements.txt >> "$LOG_FILE" 2>&1 || true

    # Console wrapper
    cat > "$BIN/w3af-console" <<EOF
#!/bin/bash
source "$TOOLS/w3af/venv/bin/activate"
cd "$dir/src" && python3 w3af_console "\$@"
EOF
    chmod +x "$BIN/w3af-console"

    # GUI wrapper
    cat > "$BIN/w3af-gui" <<EOF
#!/bin/bash
source "$TOOLS/w3af/venv/bin/activate"
cd "$dir/src" && python3 w3af_gui "\$@"
EOF
    chmod +x "$BIN/w3af-gui"
    success "w3af installed"
}

# ── OWASP ZAP ────────────────────────────────────────────────────────────────
install_zap() {
    info "Installing OWASP ZAP..."
    local dir="$TOOLS/zap"
    mkdir -p "$dir"
    local url="https://github.com/zaproxy/zaproxy/releases/download/v2.15.0/ZAP_2.15.0_Linux.tar.gz"
    download "$url" "/tmp/zap.tar.gz"
    tar -xzf /tmp/zap.tar.gz -C "$dir" --strip-components=1
    rm /tmp/zap.tar.gz
    cat > "$BIN/zap" <<EOF
#!/bin/bash
exec "$dir/zap.sh" "\$@"
EOF
    chmod +x "$BIN/zap"
    success "OWASP ZAP installed"
}

# ── mitmproxy (also in wireless but installed here with venv) ─────────────────
install_mitmproxy() {
    info "Installing mitmproxy..."
    local dir="$TOOLS/mitmproxy"
    mkdir -p "$dir"
    make_venv "mitmproxy"
    pip_install "mitmproxy" "mitmproxy"
    for cmd in mitmproxy mitmdump mitmweb; do
        make_wrapper "$cmd" "mitmproxy" "$cmd"
    done
    success "mitmproxy installed"
}

install_burpsuite
install_ettercap
install_nmap
install_sslstrip
install_w3af
install_zap
install_mitmproxy

success "=== Penetration Testing tools complete ==="
