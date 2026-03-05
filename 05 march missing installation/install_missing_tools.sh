#!/bin/bash
# =============================================================================
# Missing Tools Installer - Direct System Installation (No venv)
# Installs all tools that were missing from the initial installation
# =============================================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

BASE="/opt/santoku-kali"
TOOLS="$BASE/tools"
BIN="$BASE/bin"
LOGS="$BASE/logs"
LOG_FILE="$LOGS/missing_tools_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$TOOLS" "$BIN" "$LOGS"

info()    { echo -e "${BLUE}[INFO]${NC}    $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[OK]${NC}      $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $*" | tee -a "$LOG_FILE"; }
err()     { echo -e "${RED}[ERROR]${NC}   $*" | tee -a "$LOG_FILE"; }

echo -e "${CYAN}${BOLD}"
cat << 'BANNER'
╔══════════════════════════════════════════════════════════════╗
║         MISSING TOOLS INSTALLER (DIRECT INSTALL)            ║
║              No Virtual Environments                         ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}\n"

# Check root
[[ $EUID -ne 0 ]] && { err "Run as root: sudo bash $0"; exit 1; }

# Update package lists
info "Updating package lists..."
apt-get update -qq >> "$LOG_FILE" 2>&1

# =============================================================================
# 1. sdkmanager - Already handled by Android SDK but create wrapper
# =============================================================================
install_sdkmanager() {
    info "Setting up sdkmanager..."
    if [[ -d "$TOOLS/android-sdk" ]]; then
        local SDK="$TOOLS/android-sdk"
        cat > "$BIN/sdkmanager" <<EOF
#!/bin/bash
export ANDROID_HOME="$SDK"
exec "$SDK/cmdline-tools/latest/bin/sdkmanager" "\$@"
EOF
        chmod +x "$BIN/sdkmanager"
        success "sdkmanager wrapper created"
    else
        warn "Android SDK not found - run 01_development_tools.sh first"
    fi
}

# =============================================================================
# 2. android-studio - Download and install
# =============================================================================
install_android_studio() {
    info "Installing Android Studio..."
    local dir="$TOOLS/android-studio"
    mkdir -p "$dir"
    
    # Download latest version
    local url="https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2023.3.1.18/android-studio-2023.3.1.18-linux.tar.gz"
    wget -q --show-progress -O /tmp/android-studio.tar.gz "$url" >> "$LOG_FILE" 2>&1
    tar -xzf /tmp/android-studio.tar.gz -C "$dir" --strip-components=1
    rm /tmp/android-studio.tar.gz
    
    cat > "$BIN/android-studio" <<EOF
#!/bin/bash
exec "$dir/bin/studio.sh" "\$@"
EOF
    chmod +x "$BIN/android-studio"
    success "Android Studio installed"
}

# =============================================================================
# 3. axmlprinter2 - Already should be installed, create wrapper
# =============================================================================
install_axmlprinter2() {
    info "Installing AXMLPrinter2..."
    local dir="$TOOLS/axmlprinter2"
    mkdir -p "$dir"
    
    wget -q -O "$dir/AXMLPrinter2.jar" \
        "https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/android4me/AXMLPrinter2.jar" \
        >> "$LOG_FILE" 2>&1
    
    cat > "$BIN/axmlprinter2" <<EOF
#!/bin/bash
exec java -jar "$dir/AXMLPrinter2.jar" "\$@"
EOF
    chmod +x "$BIN/axmlprinter2"
    success "AXMLPrinter2 installed"
}

# =============================================================================
# 4. eclipse - Download and install
# =============================================================================
install_eclipse() {
    info "Installing Eclipse IDE..."
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

# =============================================================================
# 5. heimdall - Install from apt
# =============================================================================
install_heimdall() {
    info "Installing Heimdall..."
    apt-get install -y heimdall-flash heimdall-flash-frontend >> "$LOG_FILE" 2>&1
    success "Heimdall installed"
}

# =============================================================================
# 6. gplaycli - Install via pip (system-wide)
# =============================================================================
install_gplaycli() {
    info "Installing gplaycli..."
    pip3 install --break-system-packages gplaycli >> "$LOG_FILE" 2>&1 || \
    pip3 install gplaycli >> "$LOG_FILE" 2>&1
    success "gplaycli installed"
}

# =============================================================================
# 7. sbf-flash - Clone from GitHub
# =============================================================================
install_sbf_flash() {
    info "Installing sbf-flash..."
    local dir="$TOOLS/sbf-flash"
    git clone --depth=1 https://github.com/jsharkey13/sbf_flash "$dir" >> "$LOG_FILE" 2>&1
    
    cat > "$BIN/sbf-flash" <<EOF
#!/bin/bash
cd "$dir" && python3 sbf_flash.py "\$@"
EOF
    chmod +x "$BIN/sbf-flash"
    success "sbf-flash installed"
}

# =============================================================================
# 8. aflogical - Clone from GitHub
# =============================================================================
install_aflogical() {
    info "Installing AF Logical OSE..."
    local dir="$TOOLS/aflogical-ose"
    git clone --depth=1 https://github.com/nowsecure/android-forensics "$dir" >> "$LOG_FILE" 2>&1
    
    cat > "$BIN/aflogical" <<EOF
#!/bin/bash
cd "$dir" && python3 aflogical_ose.py "\$@"
EOF
    chmod +x "$BIN/aflogical"
    success "AF Logical OSE installed"
}

# =============================================================================
# 9. android-bfe - Install dependencies and script
# =============================================================================
install_android_bfe() {
    info "Installing Android Brute Force Encryption..."
    local dir="$TOOLS/android-bfe"
    mkdir -p "$dir"
    
    git clone --depth=1 https://github.com/nicowillis/android-crypto "$dir/src" >> "$LOG_FILE" 2>&1
    
    cat > "$BIN/android-bfe" <<EOF
#!/bin/bash
cd "$dir/src" && python3 bruteforce_stdcrypto.py "\$@"
EOF
    chmod +x "$BIN/android-bfe"
    success "Android BFE installed"
}

# =============================================================================
# 10. ios-backup-analyzer - Clone and setup
# =============================================================================
install_ios_backup_analyzer() {
    info "Installing iOS Backup Analyzer 2..."
    local dir="$TOOLS/ios-backup-analyzer"
    mkdir -p "$dir"
    
    pip3 install --break-system-packages iphone-backup-decrypt biplist >> "$LOG_FILE" 2>&1 || \
    pip3 install iphone-backup-decrypt biplist >> "$LOG_FILE" 2>&1
    
    git clone --depth=1 https://github.com/PicciMario/iPhone-Backup-Analyzer-2 "$dir/src" >> "$LOG_FILE" 2>&1
    
    cat > "$BIN/ios-backup-analyzer" <<EOF
#!/bin/bash
cd "$dir/src" && python3 iBckpAn.py "\$@"
EOF
    chmod +x "$BIN/ios-backup-analyzer"
    success "iOS Backup Analyzer installed"
}

# =============================================================================
# 11. ideviceinfo - Install libimobiledevice
# =============================================================================
install_ideviceinfo() {
    info "Installing libimobiledevice tools..."
    apt-get install -y libimobiledevice6 libimobiledevice-utils \
                      ifuse ideviceinstaller >> "$LOG_FILE" 2>&1
    success "libimobiledevice tools installed"
}

# =============================================================================
# 12. yaffey - Clone and setup
# =============================================================================
install_yaffey() {
    info "Installing Yaffey..."
    local dir="$TOOLS/yaffey"
    mkdir -p "$dir"
    
    pip3 install --break-system-packages pyside2 >> "$LOG_FILE" 2>&1 || \
    pip3 install pyside2 >> "$LOG_FILE" 2>&1
    
    git clone --depth=1 https://github.com/travisgoodspeed/yaffey "$dir/src" >> "$LOG_FILE" 2>&1
    
    cat > "$BIN/yaffey" <<EOF
#!/bin/bash
cd "$dir/src" && python3 yaffey.py "\$@"
EOF
    chmod +x "$BIN/yaffey"
    success "Yaffey installed"
}

# =============================================================================
# 13. abe - Android Backup Extractor
# =============================================================================
install_abe() {
    info "Installing Android Backup Extractor..."
    local dir="$TOOLS/abe"
    mkdir -p "$dir"
    
    wget -q -O "$dir/abe.jar" \
        "https://github.com/nelenkov/android-backup-extractor/releases/download/master-20221109063121-8fdfc5e/abe.jar" \
        >> "$LOG_FILE" 2>&1
    
    cat > "$BIN/abe" <<EOF
#!/bin/bash
exec java -jar "$dir/abe.jar" "\$@"
EOF
    chmod +x "$BIN/abe"
    success "ABE installed"
}

# =============================================================================
# 14-16. w3af - Already installed, just verify
# =============================================================================
install_w3af() {
    info "Verifying w3af installation..."
    if ! command -v w3af-console &>/dev/null; then
        warn "w3af not found - run 03_penetration_testing.sh"
    else
        success "w3af already installed"
    fi
}

# =============================================================================
# 17. nuclei - Install from apt or binary
# =============================================================================
install_nuclei() {
    info "Installing Nuclei..."
    
    apt-get install -y nuclei >> "$LOG_FILE" 2>&1 || {
        local dir="$TOOLS/nuclei"
        mkdir -p "$dir"
        apt-get install -y golang-go >> "$LOG_FILE" 2>&1
        GOPATH="$dir/go" go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest >> "$LOG_FILE" 2>&1
        
        cat > "$BIN/nuclei" <<EOF
#!/bin/bash
exec "$dir/go/bin/nuclei" "\$@"
EOF
        chmod +x "$BIN/nuclei"
    }
    success "Nuclei installed"
}

# =============================================================================
# All remaining tools - Direct pip/apt install
# =============================================================================
install_remaining_tools() {
    info "Installing remaining Python tools..."
    
    # Install all via pip (system-wide, no venv)
    pip3 install --break-system-packages \
        androguard \
        frida frida-tools \
        objection \
        mitmproxy \
        apkid \
        apkleaks \
        ipython \
        yara-python \
        >> "$LOG_FILE" 2>&1 || \
    pip3 install \
        androguard \
        frida frida-tools \
        objection \
        mitmproxy \
        apkid \
        apkleaks \
        ipython \
        yara-python \
        >> "$LOG_FILE" 2>&1
    
    success "Python tools installed system-wide"
}

# =============================================================================
# Frida helpers
# =============================================================================
install_frida_helpers() {
    info "Creating Frida helper scripts..."
    
    # frida-server-push
    cat > "$BIN/frida-server-push" <<'SCRIPT'
#!/bin/bash
ARCH="${1:-arm64}"
VER=$(frida --version 2>/dev/null | tr -d '\n')
[[ -z "$VER" ]] && { echo "frida not found"; exit 1; }
URL="https://github.com/frida/frida/releases/download/${VER}/frida-server-${VER}-android-${ARCH}.xz"
echo "[*] Downloading frida-server ${VER} for ${ARCH}..."
wget -q "$URL" -O "/tmp/frida-server.xz"
unxz -f /tmp/frida-server.xz
adb push /tmp/frida-server /data/local/tmp/frida-server
adb shell "chmod 755 /data/local/tmp/frida-server"
echo "[+] Pushed. Run: adb shell '/data/local/tmp/frida-server &'"
SCRIPT
    chmod +x "$BIN/frida-server-push"
    
    # apk-patch
    cat > "$BIN/apk-patch" <<'SCRIPT'
#!/bin/bash
APK="$1"; ARCH="${2:-arm64-v8a}"
[[ -z "$APK" ]] && { echo "Usage: apk-patch <app.apk> [arch]"; exit 1; }
objection patchapk -s "$APK" --architecture "$ARCH"
SCRIPT
    chmod +x "$BIN/apk-patch"
    
    # ssl-bypass
    local dir="$TOOLS/ssl-bypass"
    mkdir -p "$dir"
    cat > "$dir/ssl_bypass_universal.js" <<'EOF'
Java.perform(function() {
    try {
        var OkHostnameVerifier = Java.use("okhttp3.internal.tls.OkHostnameVerifier");
        OkHostnameVerifier.verify.overload("java.lang.String","javax.net.ssl.SSLSession").implementation = function() { return true; };
        console.log("[+] OkHttp3 bypassed");
    } catch(e) {}
    
    try {
        var TrustManagerImpl = Java.use("com.android.org.conscrypt.TrustManagerImpl");
        TrustManagerImpl.verifyChain.implementation = function() { return this.verifyChain.apply(this, arguments); };
        console.log("[+] TrustManager bypassed");
    } catch(e) {}
    
    try {
        var CertificatePinner = Java.use("okhttp3.CertificatePinner");
        CertificatePinner.check.overload("java.lang.String","java.util.List").implementation = function() {
            console.log("[+] CertificatePinner bypassed");
        };
    } catch(e) {}
});
EOF
    
    cat > "$BIN/ssl-bypass" <<EOF
#!/bin/bash
PKG="\$1"
[[ -z "\$PKG" ]] && { echo "Usage: ssl-bypass com.target.app"; exit 1; }
frida -U -f "\$PKG" -l "$dir/ssl_bypass_universal.js"
EOF
    chmod +x "$BIN/ssl-bypass"
    
    # root-bypass
    cat > "$dir/root_bypass.js" <<'EOF'
Java.perform(function() {
    try {
        var RootBeer = Java.use("com.scottyab.rootbeer.RootBeer");
        RootBeer.isRooted.implementation = function() { return false; };
        console.log("[+] RootBeer bypassed");
    } catch(e) {}
    
    var File = Java.use("java.io.File");
    File.exists.implementation = function() {
        var name = this.getAbsolutePath();
        if (name.indexOf("su") !== -1 || name.indexOf("magisk") !== -1) {
            return false;
        }
        return this.exists.call(this);
    };
    console.log("[+] Root bypass loaded");
});
EOF
    
    cat > "$BIN/root-bypass" <<EOF
#!/bin/bash
PKG="\$1"
[[ -z "\$PKG" ]] && { echo "Usage: root-bypass com.target.app"; exit 1; }
frida -U -f "\$PKG" -l "$dir/root_bypass.js"
EOF
    chmod +x "$BIN/root-bypass"
    
    success "Frida helpers created"
}

# =============================================================================
# House (Frida GUI)
# =============================================================================
install_house() {
    info "Installing House (Frida GUI)..."
    local dir="$TOOLS/house"
    mkdir -p "$dir"
    
    pip3 install --break-system-packages flask frida >> "$LOG_FILE" 2>&1 || \
    pip3 install flask frida >> "$LOG_FILE" 2>&1
    
    git clone --depth=1 https://github.com/nccgroup/house "$dir/src" >> "$LOG_FILE" 2>&1
    
    cat > "$BIN/house" <<EOF
#!/bin/bash
cd "$dir/src" && python3 app.py "\$@"
EOF
    chmod +x "$BIN/house"
    success "House installed"
}

# =============================================================================
# Main execution
# =============================================================================

echo -e "${CYAN}Starting installation of missing tools...${NC}\n"

install_sdkmanager
install_android_studio
install_axmlprinter2
install_eclipse
install_heimdall
install_gplaycli
install_sbf_flash
install_aflogical
install_android_bfe
install_ios_backup_analyzer
install_ideviceinfo
install_yaffey
install_abe
install_w3af
install_nuclei
install_remaining_tools
install_frida_helpers
install_house

echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║            INSTALLATION COMPLETE!                           ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}All tools installed system-wide (no venvs)${NC}"
echo -e "${CYAN}Wrapper scripts created in: $BIN${NC}"
echo -e "${CYAN}Installation log: $LOG_FILE${NC}\n"

echo -e "${YELLOW}Reload your shell or run:${NC}"
echo -e "  ${BOLD}source ~/.bashrc${NC}\n"

echo -e "${BLUE}Test commands:${NC}"
echo -e "  frida --version"
echo -e "  objection --version"
echo -e "  apktool --version"
echo -e "  androguard --version"
echo -e "  ssl-bypass com.example.app"
echo ""
