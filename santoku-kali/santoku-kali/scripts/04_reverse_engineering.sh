#!/bin/bash
# =============================================================================
# 04_reverse_engineering.sh
# Covers: Androguard, AntiLVL, APKTool, Baksmali/Smali, Bulb Security SPF,
#         dex2jar, Drozer, Jasmin, JD-GUI, Procyon, radare2, Smali
# Plus modern additions: JADX, Ghidra, Quark-Engine, APKiD, MobSF
# =============================================================================
source "$(dirname "$0")/common.sh"
LOG_FILE="$LOGS/04_reverse_engineering.log"
mkdir -p "$LOGS" "$TOOLS" "$BIN"

section "REVERSE ENGINEERING"

# ── Androguard ───────────────────────────────────────────────────────────────
install_androguard() {
    info "Installing Androguard..."
    mkdir -p "$TOOLS/androguard"
    make_venv "androguard"
    pip_install "androguard" "androguard[magic,GUI]" "networkx" "matplotlib"
    for cmd in androguard androaxml androarsc androsign androdis; do
        make_wrapper "$cmd" "androguard" "$cmd"
    done
    success "Androguard installed"
}

# ── AntiLVL ──────────────────────────────────────────────────────────────────
install_antilvl() {
    info "Installing AntiLVL..."
    local dir="$TOOLS/antilvl"
    mkdir -p "$dir"
    git_clone "https://github.com/strazzere/android-crackme" "$dir/src" 2>/dev/null || true
    # AntiLVL is a patch tool — download reference jar
    download "https://github.com/franktip/antiLVL/raw/master/antiLVL.jar" \
             "$dir/antiLVL.jar" 2>/dev/null || warn "AntiLVL jar not downloadable — legacy tool"
    cat > "$BIN/antilvl" <<'EOF'
#!/bin/bash
exec java -jar /opt/santoku-kali/tools/antilvl/antiLVL.jar "$@"
EOF
    chmod +x "$BIN/antilvl"
    success "AntiLVL installed (legacy tool)"
}

# ── Apktool ──────────────────────────────────────────────────────────────────
install_apktool() {
    info "Installing Apktool..."
    local dir="$TOOLS/apktool"
    mkdir -p "$dir"
    local ver="2.9.3"
    download "https://github.com/iBotPeaches/Apktool/releases/download/v${ver}/apktool_${ver}.jar" \
             "$dir/apktool.jar"
    download "https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool" \
             "$dir/apktool"
    chmod +x "$dir/apktool"
    # Patch the jar path inside the wrapper
    sed -i "s|jar_name=.*|jar_name=\"$dir/apktool.jar\"|" "$dir/apktool" 2>/dev/null || true
    cat > "$BIN/apktool" <<EOF
#!/bin/bash
exec java -jar "$dir/apktool.jar" "\$@"
EOF
    chmod +x "$BIN/apktool"
    success "Apktool v${ver} installed"
}

# ── Smali / Baksmali ─────────────────────────────────────────────────────────
install_smali() {
    info "Installing Smali/Baksmali..."
    local dir="$TOOLS/smali"
    mkdir -p "$dir"
    local ver="2.5.2"
    download "https://github.com/JesusFreke/smali/releases/download/v${ver}/smali-${ver}.jar" \
             "$dir/smali.jar"
    download "https://github.com/JesusFreke/smali/releases/download/v${ver}/baksmali-${ver}.jar" \
             "$dir/baksmali.jar"
    for tool in smali baksmali; do
        cat > "$BIN/$tool" <<EOF
#!/bin/bash
exec java -jar "$dir/${tool}.jar" "\$@"
EOF
        chmod +x "$BIN/$tool"
    done
    success "Smali/Baksmali v${ver} installed"
}

# ── Bulb Security SPF (Smartphone Pentest Framework) ─────────────────────────
install_spf() {
    info "Installing Smartphone Pentest Framework (SPF)..."
    local dir="$TOOLS/spf"
    mkdir -p "$dir"
    make_venv "spf"
    pip_install "spf" "pexpect" "python-nmap" 2>/dev/null || true
    git_clone "https://github.com/georgiaw/Smartphone-Pentest-Framework" "$dir/src"
    apt_install libpcap-dev ruby ruby-dev 2>/dev/null || true
    cat > "$BIN/spf" <<EOF
#!/bin/bash
source "$TOOLS/spf/venv/bin/activate"
cd "$dir/src" && python3 spf.py "\$@"
EOF
    chmod +x "$BIN/spf"
    success "SPF installed"
}

# ── dex2jar ───────────────────────────────────────────────────────────────────
install_dex2jar() {
    info "Installing dex2jar..."
    local dir="$TOOLS/dex2jar"
    mkdir -p "$dir"
    local ver="2.1"
    download "https://github.com/pxb1988/dex2jar/releases/download/v${ver}/dex-tools-v${ver}.zip" \
             "/tmp/dex2jar.zip"
    unzip -q /tmp/dex2jar.zip -d /tmp/d2j/
    mv /tmp/d2j/dex-tools-*/* "$dir/" 2>/dev/null || mv /tmp/d2j/*/* "$dir/"
    rm -rf /tmp/d2j /tmp/dex2jar.zip
    chmod +x "$dir"/*.sh 2>/dev/null || true
    for sh in "$dir"/*.sh; do
        local name
        name=$(basename "$sh" .sh)
        make_wrapper "$name" "dex2jar" "$sh"
    done
    success "dex2jar v${ver} installed"
}

# ── Drozer ────────────────────────────────────────────────────────────────────
install_drozer() {
    info "Installing Drozer..."
    local dir="$TOOLS/drozer"
    mkdir -p "$dir"
    make_venv "drozer"
    git_clone "https://github.com/WithSecureLabs/drozer" "$dir/src"
    "$TOOLS/drozer/venv/bin/pip" install "$dir/src/" >> "$LOG_FILE" 2>&1
    make_wrapper "drozer" "drozer" "drozer"
    # Download agent APK
    download "https://github.com/WithSecureLabs/drozer-agent/releases/download/3.0.0/drozer-agent.apk" \
             "$dir/drozer-agent.apk"
    success "Drozer installed | Agent APK: $dir/drozer-agent.apk"
}

# ── Jasmin ────────────────────────────────────────────────────────────────────
install_jasmin() {
    info "Installing Jasmin (JVM assembler)..."
    local dir="$TOOLS/jasmin"
    mkdir -p "$dir"
    download "https://sourceforge.net/projects/jasmin/files/jasmin/2.4/jasmin-2.4.zip/download" \
             "/tmp/jasmin.zip" 2>/dev/null || \
    download "https://github.com/Sable/jasmin/releases/download/jasmin-2.5.0/jasmin-2.5.0.jar" \
             "$dir/jasmin.jar"
    if [[ -f /tmp/jasmin.zip ]]; then
        unzip -q /tmp/jasmin.zip -d /tmp/jasmin_src/
        find /tmp/jasmin_src/ -name "*.jar" -exec cp {} "$dir/jasmin.jar" \;
        rm -rf /tmp/jasmin.zip /tmp/jasmin_src/
    fi
    cat > "$BIN/jasmin" <<'EOF'
#!/bin/bash
exec java -jar /opt/santoku-kali/tools/jasmin/jasmin.jar "$@"
EOF
    chmod +x "$BIN/jasmin"
    success "Jasmin installed"
}

# ── JD-GUI ────────────────────────────────────────────────────────────────────
install_jdgui() {
    info "Installing JD-GUI..."
    local dir="$TOOLS/jd-gui"
    mkdir -p "$dir"
    local ver="1.6.6"
    download "https://github.com/java-decompiler/jd-gui/releases/download/v${ver}/jd-gui-${ver}.jar" \
             "$dir/jd-gui.jar"
    cat > "$BIN/jd-gui" <<'EOF'
#!/bin/bash
exec java -jar /opt/santoku-kali/tools/jd-gui/jd-gui.jar "$@"
EOF
    chmod +x "$BIN/jd-gui"
    success "JD-GUI v${ver} installed"
}

# ── Procyon Java Decompiler ──────────────────────────────────────────────────
install_procyon() {
    info "Installing Procyon decompiler..."
    local dir="$TOOLS/procyon"
    mkdir -p "$dir"
    local ver="0.6.0"
    download "https://github.com/mstrobel/procyon/releases/download/v${ver}/procyon-decompiler-${ver}.jar" \
             "$dir/procyon.jar"
    cat > "$BIN/procyon" <<'EOF'
#!/bin/bash
exec java -jar /opt/santoku-kali/tools/procyon/procyon.jar "$@"
EOF
    chmod +x "$BIN/procyon"
    success "Procyon v${ver} installed"
}

# ── Radare2 ───────────────────────────────────────────────────────────────────
install_radare2() {
    info "Installing Radare2..."
    apt_install radare2
    if ! command -v radare2 &>/dev/null; then
        # Fallback: install from GitHub
        local dir="$TOOLS/radare2"
        git_clone "https://github.com/radareorg/radare2" "$dir/src"
        cd "$dir/src" && sys/install.sh >> "$LOG_FILE" 2>&1
    fi
    command -v radare2 &>/dev/null \
        && success "Radare2 installed ($(radare2 -version | head -1))" \
        || warn "Radare2 install failed"
    # r2frida plugin
    r2pm -ci r2frida >> "$LOG_FILE" 2>&1 || warn "r2frida not installed"
}

# ── JADX (modern replacement for dex2jar+JD-GUI) ─────────────────────────────
install_jadx() {
    info "Installing JADX..."
    local dir="$TOOLS/jadx"
    mkdir -p "$dir"
    local ver="1.5.0"
    download "https://github.com/skylot/jadx/releases/download/v${ver}/jadx-${ver}.zip" \
             "/tmp/jadx.zip"
    unzip -q /tmp/jadx.zip -d "$dir"
    rm /tmp/jadx.zip
    chmod +x "$dir/bin/jadx" "$dir/bin/jadx-gui"
    make_wrapper "jadx"     "jadx" "$dir/bin/jadx"
    make_wrapper "jadx-gui" "jadx" "$dir/bin/jadx-gui"
    success "JADX v${ver} installed"
}

# ── Ghidra ────────────────────────────────────────────────────────────────────
install_ghidra() {
    info "Installing Ghidra..."
    local dir="$TOOLS/ghidra"
    mkdir -p "$dir"
    local ver="11.1.2"
    local build="20240709"
    download "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${ver}_build/ghidra_${ver}_PUBLIC_${build}.zip" \
             "/tmp/ghidra.zip"
    unzip -q /tmp/ghidra.zip -d /tmp/ghidra_tmp/
    mv /tmp/ghidra_tmp/ghidra_*/* "$dir/"
    rm -rf /tmp/ghidra.zip /tmp/ghidra_tmp/
    cat > "$BIN/ghidra" <<EOF
#!/bin/bash
exec "$dir/ghidraRun" "\$@"
EOF
    chmod +x "$BIN/ghidra"
    success "Ghidra v${ver} installed"
}

# ── Quark-Engine (Android malware analysis) ───────────────────────────────────
install_quark() {
    info "Installing Quark-Engine..."
    mkdir -p "$TOOLS/quark"
    make_venv "quark"
    pip_install "quark" "quark-engine"
    make_wrapper "quark" "quark" "quark"
    success "Quark-Engine installed"
}

# ── APKiD ─────────────────────────────────────────────────────────────────────
install_apkid() {
    info "Installing APKiD..."
    mkdir -p "$TOOLS/apkid"
    make_venv "apkid"
    pip_install "apkid" "apkid"
    make_wrapper "apkid" "apkid" "apkid"
    success "APKiD installed"
}

# ── MobSF ─────────────────────────────────────────────────────────────────────
install_mobsf() {
    info "Installing MobSF..."
    local dir="$TOOLS/mobsf"
    mkdir -p "$dir"
    apt_install wkhtmltopdf
    make_venv "mobsf"
    git_clone "https://github.com/MobSF/Mobile-Security-Framework-MobSF" "$dir/src"
    "$TOOLS/mobsf/venv/bin/pip" install -r "$dir/src/requirements.txt" >> "$LOG_FILE" 2>&1
    cat > "$BIN/mobsf" <<EOF
#!/bin/bash
source "$TOOLS/mobsf/venv/bin/activate"
cd "$dir/src"
if [[ "\$1" == "setup" ]]; then
    python setup.py
else
    python manage.py runserver 0.0.0.0:8000
fi
EOF
    chmod +x "$BIN/mobsf"
    # First-time setup
    (source "$TOOLS/mobsf/venv/bin/activate" && cd "$dir/src" && python setup.py >> "$LOG_FILE" 2>&1) || true
    success "MobSF installed — start with: mobsf  |  web UI: http://localhost:8000"
}

install_androguard
install_antilvl
install_apktool
install_smali
install_spf
install_dex2jar
install_drozer
install_jasmin
install_jdgui
install_procyon
install_radare2
install_jadx
install_ghidra
install_quark
install_apkid
install_mobsf

success "=== Reverse Engineering tools complete ==="
