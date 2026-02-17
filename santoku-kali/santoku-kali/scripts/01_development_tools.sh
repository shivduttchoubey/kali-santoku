#!/bin/bash
# =============================================================================
# 01_development_tools.sh
# Covers: Android SDK Manager, Android Studio, AXMLPrinter2, Eclipse,
#         Fastboot, Google Play API, Heimdall, Heimdall-GUI, SBF Flash
# =============================================================================
source "$(dirname "$0")/common.sh"
LOG_FILE="$LOGS/01_development_tools.log"
mkdir -p "$LOGS" "$TOOLS" "$BIN"

section "DEVELOPMENT TOOLS"

# ── Android SDK command-line tools (includes SDK Manager + Fastboot + ADB) ──
install_android_sdk() {
    info "Installing Android SDK command-line tools..."
    local dir="$TOOLS/android-sdk"
    mkdir -p "$dir/cmdline-tools"

    local url="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
    download "$url" "/tmp/cmdline-tools.zip"
    unzip -q /tmp/cmdline-tools.zip -d /tmp/clt/
    mv /tmp/clt/cmdline-tools "$dir/cmdline-tools/latest"
    rm -rf /tmp/clt /tmp/cmdline-tools.zip

    export ANDROID_HOME="$dir"
    export PATH="$dir/cmdline-tools/latest/bin:$dir/platform-tools:$PATH"

    yes | "$dir/cmdline-tools/latest/bin/sdkmanager" \
        "platform-tools" "build-tools;34.0.0" >> "$LOG_FILE" 2>&1

    # Write env file sourced by wrappers
    cat > "$dir/env.sh" <<EOF
export ANDROID_HOME="$dir"
export PATH="\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/build-tools/34.0.0:\$PATH"
EOF

    for cmd in adb fastboot sdkmanager avdmanager; do
        local real
        real=$(find "$dir" -name "$cmd" -type f 2>/dev/null | head -1)
        [[ -n "$real" ]] && make_wrapper "$cmd" "android-sdk" "$real"
    done

    # apksigner wrapper
    local signer
    signer=$(find "$dir/build-tools" -name "apksigner" 2>/dev/null | head -1)
    [[ -n "$signer" ]] && make_wrapper "apksigner" "android-sdk" "$signer"

    success "Android SDK installed → $dir"
}

# ── Android Studio ──────────────────────────────────────────────────────────
install_android_studio() {
    info "Installing Android Studio..."
    local dir="$TOOLS/android-studio"
    mkdir -p "$dir"
    local url="https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2023.3.1.18/android-studio-2023.3.1.18-linux.tar.gz"
    download "$url" "/tmp/android-studio.tar.gz"
    tar -xzf /tmp/android-studio.tar.gz -C "$dir" --strip-components=1
    rm /tmp/android-studio.tar.gz

    cat > "$BIN/android-studio" <<EOF
#!/bin/bash
exec "$dir/bin/studio.sh" "\$@"
EOF
    chmod +x "$BIN/android-studio"
    success "Android Studio installed → $dir"
}

# ── AXMLPrinter2 ────────────────────────────────────────────────────────────
install_axmlprinter2() {
    info "Installing AXMLPrinter2..."
    local dir="$TOOLS/axmlprinter2"
    mkdir -p "$dir"
    download "https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/android4me/AXMLPrinter2.jar" \
             "$dir/AXMLPrinter2.jar"
    cat > "$dir/axmlprinter2" <<'EOF'
#!/bin/bash
exec java -jar "$(dirname "$0")/AXMLPrinter2.jar" "$@"
EOF
    chmod +x "$dir/axmlprinter2"
    make_wrapper "axmlprinter2" "axmlprinter2" "$dir/axmlprinter2"
    success "AXMLPrinter2 installed"
}

# ── Eclipse IDE ─────────────────────────────────────────────────────────────
install_eclipse() {
    info "Installing Eclipse IDE for Java..."
    local dir="$TOOLS/eclipse"
    mkdir -p "$dir"
    local url="https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2023-12/R/eclipse-java-2023-12-R-linux-gtk-x86_64.tar.gz&r=1"
    wget -q --show-progress -O /tmp/eclipse.tar.gz "$url" >> "$LOG_FILE" 2>&1
    tar -xzf /tmp/eclipse.tar.gz -C "$dir" --strip-components=1
    rm /tmp/eclipse.tar.gz
    cat > "$BIN/eclipse" <<EOF
#!/bin/bash
exec "$dir/eclipse" "\$@"
EOF
    chmod +x "$BIN/eclipse"
    success "Eclipse installed"
}

# ── Heimdall (Samsung flashing) ─────────────────────────────────────────────
install_heimdall() {
    info "Installing Heimdall..."
    apt_install heimdall-flash heimdall-flash-frontend
    # apt puts heimdall in /usr/bin — just confirm
    command -v heimdall &>/dev/null \
        && success "Heimdall installed" \
        || warn "Heimdall not available via apt — build from source if needed"
}

# ── Google Play API / gplaycli ───────────────────────────────────────────────
install_googleplay_api() {
    info "Installing Google Play API (gplaycli)..."
    mkdir -p "$TOOLS/gplaycli"
    make_venv "gplaycli"
    pip_install "gplaycli" "gplaycli"
    make_wrapper "gplaycli" "gplaycli" "gplaycli"
    success "gplaycli installed"
}

# ── SBF Flash (Motorola) ─────────────────────────────────────────────────────
install_sbf_flash() {
    info "Installing sbf_flash (Motorola)..."
    local dir="$TOOLS/sbf-flash"
    mkdir -p "$dir"
    git_clone "https://github.com/jsharkey13/sbf_flash" "$dir"
    cat > "$BIN/sbf-flash" <<EOF
#!/bin/bash
cd "$dir" && python3 sbf_flash.py "\$@"
EOF
    chmod +x "$BIN/sbf-flash"
    success "sbf_flash installed"
}

install_android_sdk
install_android_studio
install_axmlprinter2
install_eclipse
install_heimdall
install_googleplay_api
install_sbf_flash

success "=== Development Tools complete ==="
