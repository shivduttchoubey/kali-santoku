#!/bin/bash
# =============================================================================
# 02_device_forensics.sh
# Covers: AF Logical OSE, Android Brute Force Encryption, ExifTool,
#         iOS Backup Analyzer 2, libimobiledevice, scalpel, SleuthKit, Yaffey
# =============================================================================
source "$(dirname "$0")/common.sh"
LOG_FILE="$LOGS/02_device_forensics.log"
mkdir -p "$LOGS" "$TOOLS" "$BIN"

section "DEVICE FORENSICS"

# ── AF Logical OSE ───────────────────────────────────────────────────────────
install_aflogical() {
    info "Installing AF Logical OSE..."
    local dir="$TOOLS/aflogical-ose"
    git_clone "https://github.com/nowsecure/android-forensics" "$dir"
    cat > "$BIN/aflogical" <<EOF
#!/bin/bash
cd "$dir" && python3 aflogical_ose.py "\$@"
EOF
    chmod +x "$BIN/aflogical"
    success "AF Logical OSE installed"
}

# ── Android Brute Force Encryption ─────────────────────────────────────────
install_android_bfe() {
    info "Installing Android Brute Force Encryption..."
    mkdir -p "$TOOLS/android-bfe"
    make_venv "android-bfe"
    pip_install "android-bfe" "hashcat-utils" 2>/dev/null || true
    # bruteforce-android-encryption
    git_clone "https://github.com/nicowillis/android-crypto" "$TOOLS/android-bfe/src"
    cat > "$BIN/android-bfe" <<EOF
#!/bin/bash
source "$TOOLS/android-bfe/venv/bin/activate"
cd "$TOOLS/android-bfe/src"
python3 bruteforce_stdcrypto.py "\$@"
EOF
    chmod +x "$BIN/android-bfe"
    success "Android Brute Force Encryption installed"
}

# ── ExifTool ─────────────────────────────────────────────────────────────────
install_exiftool() {
    info "Installing ExifTool..."
    apt_install libimage-exiftool-perl
    command -v exiftool &>/dev/null \
        && success "ExifTool installed ($(exiftool -ver))" \
        || warn "ExifTool not found via apt"
}

# ── iOS Backup Analyzer 2 ────────────────────────────────────────────────────
install_ios_backup_analyzer() {
    info "Installing iOS Backup Analyzer 2..."
    local dir="$TOOLS/ios-backup-analyzer"
    mkdir -p "$dir"
    make_venv "ios-backup-analyzer"
    pip_install "ios-backup-analyzer" "iphone-backup-decrypt" "biplist"
    git_clone "https://github.com/PicciMario/iPhone-Backup-Analyzer-2" "$dir/src"
    cat > "$BIN/ios-backup-analyzer" <<EOF
#!/bin/bash
source "$TOOLS/ios-backup-analyzer/venv/bin/activate"
cd "$dir/src" && python3 iBckpAn.py "\$@"
EOF
    chmod +x "$BIN/ios-backup-analyzer"
    success "iOS Backup Analyzer 2 installed"
}

# ── libimobiledevice ─────────────────────────────────────────────────────────
install_libimobiledevice() {
    info "Installing libimobiledevice..."
    apt_install libimobiledevice6 libimobiledevice-utils \
                ifuse ideviceinstaller
    for cmd in ideviceinfo idevicepair ideviceinstaller; do
        command -v "$cmd" &>/dev/null \
            && success "$cmd available" \
            || warn "$cmd not found"
    done
}

# ── Scalpel (file carver) ────────────────────────────────────────────────────
install_scalpel() {
    info "Installing scalpel..."
    apt_install scalpel
    command -v scalpel &>/dev/null \
        && success "scalpel installed" \
        || warn "scalpel not found via apt"
}

# ── SleuthKit ────────────────────────────────────────────────────────────────
install_sleuthkit() {
    info "Installing SleuthKit..."
    apt_install sleuthkit autopsy
    command -v fls &>/dev/null \
        && success "SleuthKit installed" \
        || warn "SleuthKit not found via apt"
}

# ── Yaffey (Android YAFFS2 editor) ──────────────────────────────────────────
install_yaffey() {
    info "Installing Yaffey..."
    local dir="$TOOLS/yaffey"
    mkdir -p "$dir"
    make_venv "yaffey"
    pip_install "yaffey" "pyside2" 2>/dev/null || true
    git_clone "https://github.com/travisgoodspeed/yaffey" "$dir/src"
    cat > "$BIN/yaffey" <<EOF
#!/bin/bash
source "$TOOLS/yaffey/venv/bin/activate"
cd "$dir/src" && python3 yaffey.py "\$@"
EOF
    chmod +x "$BIN/yaffey"
    success "Yaffey installed"
}

# ── Android Backup Extractor (bonus — essential for forensics) ───────────────
install_abe() {
    info "Installing Android Backup Extractor (abe)..."
    local dir="$TOOLS/abe"
    mkdir -p "$dir"
    download "https://github.com/nelenkov/android-backup-extractor/releases/download/master-20221109063121-8fdfc5e/abe.jar" \
             "$dir/abe.jar"
    cat > "$dir/abe" <<'EOF'
#!/bin/bash
exec java -jar "$(dirname "$0")/abe.jar" "$@"
EOF
    chmod +x "$dir/abe"
    make_wrapper "abe" "abe" "$dir/abe"
    success "Android Backup Extractor installed"
}

install_aflogical
install_android_bfe
install_exiftool
install_ios_backup_analyzer
install_libimobiledevice
install_scalpel
install_sleuthkit
install_yaffey
install_abe

success "=== Device Forensics complete ==="
