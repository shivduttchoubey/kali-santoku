#!/bin/bash
# =============================================================================
# 06_dynamic_analysis.sh
# Covers: Frida, Objection, House, SSL Kill Switch tooling,
#         Magisk bypass scripts, MITM/SSL intercept helpers
# =============================================================================
source "$(dirname "$0")/common.sh"
LOG_FILE="$LOGS/06_dynamic_analysis.log"
mkdir -p "$LOGS" "$TOOLS" "$BIN"

section "DYNAMIC ANALYSIS & INSTRUMENTATION"

# ── Frida + frida-tools ───────────────────────────────────────────────────────
install_frida() {
    info "Installing Frida..."
    mkdir -p "$TOOLS/frida"
    make_venv "frida"
    pip_install "frida" "frida" "frida-tools"
    for cmd in frida frida-ps frida-trace frida-discover frida-ls-devices frida-kill frida-apk; do
        make_wrapper "$cmd" "frida" "$cmd"
    done
    success "Frida installed ($(\"$TOOLS/frida/venv/bin/frida\" --version))"
}

# ── Objection ─────────────────────────────────────────────────────────────────
install_objection() {
    info "Installing Objection..."
    mkdir -p "$TOOLS/objection"
    make_venv "objection"
    pip_install "objection" "objection"
    make_wrapper "objection" "objection" "objection"
    success "Objection installed"
}

# ── House (Frida GUI) ─────────────────────────────────────────────────────────
install_house() {
    info "Installing House (Frida GUI)..."
    local dir="$TOOLS/house"
    mkdir -p "$dir"
    make_venv "house"
    git_clone "https://github.com/nccgroup/house" "$dir/src"
    pip_install "house" "flask" "frida"
    cat > "$BIN/house" <<EOF
#!/bin/bash
source "$TOOLS/house/venv/bin/activate"
cd "$dir/src" && python3 app.py "\$@"
EOF
    chmod +x "$BIN/house"
    success "House installed — start with: house  |  UI at http://localhost:8000"
}

# ── Frida server download helper ──────────────────────────────────────────────
install_frida_server_helper() {
    info "Creating frida-server-push helper..."
    cat > "$BIN/frida-server-push" <<'SCRIPT'
#!/bin/bash
# Usage: frida-server-push [arch]
# arch: arm, arm64 (default), x86, x86_64
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
    success "frida-server-push helper created"
}

# ── Objection patcher (repackage APK with Frida gadget) ──────────────────────
install_apk_patcher() {
    info "Creating apk-patch helper (Frida gadget injection)..."
    cat > "$BIN/apk-patch" <<'SCRIPT'
#!/bin/bash
# Usage: apk-patch <app.apk> [arch]
APK="$1"; ARCH="${2:-arm64-v8a}"
[[ -z "$APK" ]] && { echo "Usage: apk-patch <app.apk> [arch]"; exit 1; }
source /opt/santoku-kali/tools/objection/venv/bin/activate
objection patchapk -s "$APK" --architecture "$ARCH"
SCRIPT
    chmod +x "$BIN/apk-patch"
    success "apk-patch helper created"
}

# ── SSL Pinning bypass script bundle ─────────────────────────────────────────
install_ssl_bypass_scripts() {
    info "Installing SSL pinning bypass scripts..."
    local dir="$TOOLS/ssl-bypass"
    mkdir -p "$dir"
    # Multiple bypass approaches
    download "https://raw.githubusercontent.com/WoohyunSohn/SSL-Pinning-bypass/master/bypass-ssl-pinning.js" \
             "$dir/bypass-ssl-pinning-basic.js" 2>/dev/null || true
    download "https://raw.githubusercontent.com/Magisk-Modules-Repo/MagiskTrustUserCerts/master/README.md" \
             "$dir/README.md" 2>/dev/null || true

    # Universal bypass via Frida
    cat > "$dir/ssl_bypass_universal.js" <<'EOF'
// Universal SSL Pinning Bypass - works for most apps
// Usage: frida -U -f com.target.app -l ssl_bypass_universal.js

Java.perform(function() {
    // OkHttp3
    try {
        var OkHostnameVerifier = Java.use("okhttp3.internal.tls.OkHostnameVerifier");
        OkHostnameVerifier.verify.overload("java.lang.String","javax.net.ssl.SSLSession").implementation = function() { return true; };
        console.log("[+] OkHttp3 hostname verifier bypassed");
    } catch(e) {}

    // TrustManager
    try {
        var TrustManagerImpl = Java.use("com.android.org.conscrypt.TrustManagerImpl");
        TrustManagerImpl.verifyChain.implementation = function() { return this.verifyChain.apply(this, arguments); };
        console.log("[+] TrustManagerImpl hooked");
    } catch(e) {}

    // SSLContext
    try {
        var X509TrustManager = Java.use("javax.net.ssl.X509TrustManager");
        var SSLContext = Java.use("javax.net.ssl.SSLContext");
        var TrustManager = Java.registerClass({
            name: "com.custom.TrustManager",
            implements: [X509TrustManager],
            methods: {
                checkClientTrusted: function() {},
                checkServerTrusted: function() {},
                getAcceptedIssuers: function() { return []; }
            }
        });
        SSLContext.init.overload("[Ljavax.net.ssl.KeyManager;","[Ljavax.net.ssl.TrustManager;","java.security.SecureRandom")
            .implementation = function(km, tm, sr) {
                SSLContext.init.overload("[Ljavax.net.ssl.KeyManager;","[Ljavax.net.ssl.TrustManager;","java.security.SecureRandom")
                    .call(this, km, Java.array("javax.net.ssl.TrustManager", [TrustManager.$new()]), sr);
            };
        console.log("[+] SSLContext trust manager bypassed");
    } catch(e) {}

    // Certificate pinning - OkHttp CertificatePinner
    try {
        var CertificatePinner = Java.use("okhttp3.CertificatePinner");
        CertificatePinner.check.overload("java.lang.String","java.util.List").implementation = function() {
            console.log("[+] OkHttp CertificatePinner bypassed for: " + arguments[0]);
        };
    } catch(e) {}

    console.log("[*] SSL Pinning bypass loaded");
});
EOF

    cat > "$BIN/ssl-bypass" <<EOF
#!/bin/bash
# Usage: ssl-bypass <package> [device_id]
PKG="\$1"
[[ -z "\$PKG" ]] && { echo "Usage: ssl-bypass com.target.app"; exit 1; }
source /opt/santoku-kali/tools/frida/venv/bin/activate
frida -U -f "\$PKG" -l "$dir/ssl_bypass_universal.js"
EOF
    chmod +x "$BIN/ssl-bypass"
    success "SSL bypass scripts installed → $dir"
}

# ── Root detection bypass script ──────────────────────────────────────────────
install_root_bypass() {
    info "Creating root detection bypass script..."
    local dir="$TOOLS/root-bypass"
    mkdir -p "$dir"
    cat > "$dir/root_bypass.js" <<'EOF'
// Root Detection Bypass
// Usage: frida -U -f com.target.app -l root_bypass.js

Java.perform(function() {
    // RootBeer bypass
    try {
        var RootBeer = Java.use("com.scottyab.rootbeer.RootBeer");
        RootBeer.isRooted.implementation = function() { return false; };
        RootBeer.isRootedWithoutBusyBox.implementation = function() { return false; };
        console.log("[+] RootBeer bypassed");
    } catch(e) {}

    // File checks
    var File = Java.use("java.io.File");
    File.exists.implementation = function() {
        var name = this.getAbsolutePath();
        if (name.indexOf("su") !== -1 || name.indexOf("magisk") !== -1 ||
            name.indexOf("superuser") !== -1 || name.indexOf("busybox") !== -1) {
            console.log("[+] Blocked file check: " + name);
            return false;
        }
        return this.exists.call(this);
    };

    // Runtime exec bypass
    var Runtime = Java.use("java.lang.Runtime");
    Runtime.exec.overload("java.lang.String").implementation = function(cmd) {
        if (cmd.indexOf("su") !== -1 || cmd.indexOf("which") !== -1) {
            console.log("[+] Blocked exec: " + cmd);
            cmd = "ls";
        }
        return this.exec.overload("java.lang.String").call(this, cmd);
    };

    console.log("[*] Root bypass loaded");
});
EOF
    cat > "$BIN/root-bypass" <<EOF
#!/bin/bash
PKG="\$1"
[[ -z "\$PKG" ]] && { echo "Usage: root-bypass com.target.app"; exit 1; }
source /opt/santoku-kali/tools/frida/venv/bin/activate
frida -U -f "\$PKG" -l "$dir/root_bypass.js"
EOF
    chmod +x "$BIN/root-bypass"
    success "Root bypass scripts installed"
}

install_frida
install_objection
install_house
install_frida_server_helper
install_apk_patcher
install_ssl_bypass_scripts
install_root_bypass

success "=== Dynamic Analysis tools complete ==="
