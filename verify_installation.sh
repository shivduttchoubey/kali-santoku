#!/bin/bash
# =============================================================================
# Santoku-Kali Installation Verification & Report Generator
# Tests all tools and generates detailed HTML + text reports
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

BASE="/opt/santoku-kali"
REPORT_DIR="$BASE/reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_TXT="$REPORT_DIR/verification_${TIMESTAMP}.txt"
REPORT_HTML="$REPORT_DIR/verification_${TIMESTAMP}.html"

mkdir -p "$REPORT_DIR"

# Test results arrays
declare -a INSTALLED=()
declare -a MISSING=()
declare -a VENV_OK=()
declare -a VENV_FAIL=()

# =============================================================================
# Tool definitions - COMPLETE list from all Santoku screenshots
# =============================================================================

# Development Tools (Screenshot 1)
DEV_TOOLS=(
    "adb:Android Debug Bridge"
    "fastboot:Fastboot tool"
    "sdkmanager:Android SDK Manager"
    "android-studio:Android Studio IDE"
    "axmlprinter2:AXML Printer 2"
    "eclipse:Eclipse IDE"
    "heimdall:Heimdall flash tool"
    "gplaycli:Google Play CLI"
    "sbf-flash:SBF Flash (Motorola)"
)

# Device Forensics (Screenshot 2)
FORENSICS_TOOLS=(
    "aflogical:AF Logical OSE"
    "android-bfe:Android Brute Force Encryption"
    "exiftool:ExifTool"
    "ios-backup-analyzer:iOS Backup Analyzer 2"
    "ideviceinfo:libimobiledevice"
    "scalpel:Scalpel file carver"
    "fls:SleuthKit"
    "yaffey:Yaffey YAFFS2 editor"
    "abe:Android Backup Extractor"
)

# Penetration Testing (Screenshot 3)
PENTEST_TOOLS=(
    "burpsuite:Burp Suite"
    "ettercap:Ettercap"
    "nmap:Nmap"
    "zenmap:Zenmap GUI"
    "sslstrip:SSLStrip"
    "w3af-console:w3af Console"
    "w3af-gui:w3af GUI"
    "zap:OWASP ZAP"
    "mitmproxy:mitmproxy"
    "mitmdump:mitmdump"
    "mitmweb:mitmweb"
)

# Reverse Engineering (Screenshot 4)
REVERSE_TOOLS=(
    "androguard:Androguard"
    "antilvl:AntiLVL"
    "apktool:Apktool"
    "smali:Smali"
    "baksmali:Baksmali"
    "spf:Smartphone Pentest Framework"
    "d2j-dex2jar:dex2jar"
    "drozer:Drozer"
    "jasmin:Jasmin"
    "jd-gui:JD-GUI"
    "procyon:Procyon"
    "radare2:Radare2"
    "jadx:JADX CLI"
    "jadx-gui:JADX GUI"
    "ghidra:Ghidra"
    "quark:Quark-Engine"
    "apkid:APKiD"
    "mobsf:Mobile Security Framework"
)

# Wireless Analyzers (Screenshot 5)
WIRELESS_TOOLS=(
    "chaosreader:Chaosreader"
    "dnschef:DNSChef"
    "dsniff:DSniff"
    "tcpdump:tcpdump"
    "wifite:Wifite"
    "wireshark:Wireshark"
    "aircrack-ng:Aircrack-ng"
    "bettercap:Bettercap"
)

# Dynamic Analysis (Modern additions)
DYNAMIC_TOOLS=(
    "frida:Frida"
    "frida-ps:Frida PS"
    "frida-trace:Frida Trace"
    "objection:Objection"
    "house:House Frida GUI"
    "frida-server-push:Frida server helper"
    "apk-patch:APK patcher"
    "ssl-bypass:SSL bypass script"
    "root-bypass:Root bypass script"
)

# Supporting Tools (Screenshots 6-8)
SUPPORT_TOOLS=(
    "ipython:iPython"
    "sqlitebrowser:DB Browser for SQLite"
    "yara:YARA"
    "binwalk:binwalk"
    "msfconsole:Metasploit Framework"
    "sqlmap:sqlmap"
    "nuclei:Nuclei"
    "apkleaks:APKLeaks"
)

# ADB Helpers
ADB_HELPERS=(
    "adb-screenshot:ADB screenshot helper"
    "adb-logcat-app:ADB logcat helper"
    "adb-pull-apk:ADB pull APK helper"
    "adb-frida-start:ADB Frida starter"
)

# System tools that should be present
SYSTEM_TOOLS=(
    "python3:Python 3"
    "java:Java"
    "git:Git"
    "wget:wget"
    "curl:curl"
    "sqlite3:SQLite3"
    "strings:strings"
    "file:file"
    "hexedit:hexedit"
)

# =============================================================================
# Test functions
# =============================================================================

test_command() {
    local cmd="$1"
    local desc="$2"
    
    if command -v "$cmd" &>/dev/null; then
        local version
        version=$("$cmd" --version 2>&1 | head -1 | cut -c1-60 || echo "installed")
        INSTALLED+=("$cmd|$desc|$version")
        return 0
    else
        MISSING+=("$cmd|$desc")
        return 1
    fi
}

test_venv_tool() {
    local tool="$1"
    local desc="$2"
    local venv="$BASE/tools/$tool/venv"
    
    if [[ -d "$venv" ]] && [[ -f "$venv/bin/activate" ]]; then
        # Check if python works in venv
        if "$venv/bin/python" --version &>/dev/null; then
            VENV_OK+=("$tool|$desc|$venv")
            return 0
        fi
    fi
    VENV_FAIL+=("$tool|$desc")
    return 1
}

test_wrapper() {
    local wrapper="$1"
    local desc="$2"
    
    if [[ -f "$BASE/bin/$wrapper" ]] && [[ -x "$BASE/bin/$wrapper" ]]; then
        INSTALLED+=("$wrapper|$desc|wrapper script")
        return 0
    else
        MISSING+=("$wrapper|$desc")
        return 1
    fi
}

# =============================================================================
# Main testing
# =============================================================================

echo -e "${CYAN}${BOLD}"
cat << 'BANNER'
╔══════════════════════════════════════════════════════════════╗
║     SANTOKU-KALI INSTALLATION VERIFICATION REPORT           ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${BLUE}Testing all tools...${NC}\n"

# Test each category
echo -e "${CYAN}[1/9] Development Tools${NC}"
for tool in "${DEV_TOOLS[@]}"; do
    cmd="${tool%%:*}"
    desc="${tool##*:}"
    test_command "$cmd" "$desc" && echo -e "  ${GREEN}✓${NC} $desc" || echo -e "  ${RED}✗${NC} $desc"
done

echo -e "\n${CYAN}[2/9] Device Forensics${NC}"
for tool in "${FORENSICS_TOOLS[@]}"; do
    cmd="${tool%%:*}"
    desc="${tool##*:}"
    test_command "$cmd" "$desc" && echo -e "  ${GREEN}✓${NC} $desc" || echo -e "  ${RED}✗${NC} $desc"
done

echo -e "\n${CYAN}[3/9] Penetration Testing${NC}"
for tool in "${PENTEST_TOOLS[@]}"; do
    cmd="${tool%%:*}"
    desc="${tool##*:}"
    test_command "$cmd" "$desc" && echo -e "  ${GREEN}✓${NC} $desc" || echo -e "  ${RED}✗${NC} $desc"
done

echo -e "\n${CYAN}[4/9] Reverse Engineering${NC}"
for tool in "${REVERSE_TOOLS[@]}"; do
    cmd="${tool%%:*}"
    desc="${tool##*:}"
    test_command "$cmd" "$desc" && echo -e "  ${GREEN}✓${NC} $desc" || echo -e "  ${RED}✗${NC} $desc"
done

echo -e "\n${CYAN}[5/9] Wireless Analyzers${NC}"
for tool in "${WIRELESS_TOOLS[@]}"; do
    cmd="${tool%%:*}"
    desc="${tool##*:}"
    test_command "$cmd" "$desc" && echo -e "  ${GREEN}✓${NC} $desc" || echo -e "  ${RED}✗${NC} $desc"
done

echo -e "\n${CYAN}[6/9] Dynamic Analysis${NC}"
for tool in "${DYNAMIC_TOOLS[@]}"; do
    cmd="${tool%%:*}"
    desc="${tool##*:}"
    test_command "$cmd" "$desc" && echo -e "  ${GREEN}✓${NC} $desc" || echo -e "  ${RED}✗${NC} $desc"
done

echo -e "\n${CYAN}[7/9] Supporting Tools${NC}"
for tool in "${SUPPORT_TOOLS[@]}"; do
    cmd="${tool%%:*}"
    desc="${tool##*:}"
    test_command "$cmd" "$desc" && echo -e "  ${GREEN}✓${NC} $desc" || echo -e "  ${RED}✗${NC} $desc"
done

echo -e "\n${CYAN}[8/9] ADB Helpers${NC}"
for tool in "${ADB_HELPERS[@]}"; do
    cmd="${tool%%:*}"
    desc="${tool##*:}"
    test_wrapper "$cmd" "$desc" && echo -e "  ${GREEN}✓${NC} $desc" || echo -e "  ${RED}✗${NC} $desc"
done

echo -e "\n${CYAN}[9/9] System Tools${NC}"
for tool in "${SYSTEM_TOOLS[@]}"; do
    cmd="${tool%%:*}"
    desc="${tool##*:}"
    test_command "$cmd" "$desc" && echo -e "  ${GREEN}✓${NC} $desc" || echo -e "  ${RED}✗${NC} $desc"
done

# Test virtual environments
echo -e "\n${CYAN}[VENV] Checking Python Virtual Environments${NC}"
VENV_TOOLS=("frida" "objection" "androguard" "mitmproxy" "mobsf" "drozer" "house")
for tool in "${VENV_TOOLS[@]}"; do
    test_venv_tool "$tool" "$tool venv" && echo -e "  ${GREEN}✓${NC} $tool venv" || echo -e "  ${YELLOW}⚠${NC} $tool venv"
done

# Calculate statistics
TOTAL_INSTALLED=${#INSTALLED[@]}
TOTAL_MISSING=${#MISSING[@]}
TOTAL_TESTS=$((TOTAL_INSTALLED + TOTAL_MISSING))
SUCCESS_RATE=$((TOTAL_INSTALLED * 100 / TOTAL_TESTS))

# =============================================================================
# Generate Text Report
# =============================================================================

cat > "$REPORT_TXT" << EOF
================================================================================
  SANTOKU-KALI INSTALLATION VERIFICATION REPORT
  Generated: $(date)
================================================================================

SUMMARY
--------
Total Tools Tested:     $TOTAL_TESTS
✓ Installed:           $TOTAL_INSTALLED
✗ Missing:             $TOTAL_MISSING
Success Rate:          ${SUCCESS_RATE}%

================================================================================
INSTALLED TOOLS ($TOTAL_INSTALLED)
================================================================================

EOF

for entry in "${INSTALLED[@]}"; do
    IFS='|' read -r cmd desc version <<< "$entry"
    printf "%-25s %-30s %s\n" "$cmd" "$desc" "$version" >> "$REPORT_TXT"
done

cat >> "$REPORT_TXT" << EOF

================================================================================
MISSING TOOLS ($TOTAL_MISSING)
================================================================================

EOF

for entry in "${MISSING[@]}"; do
    IFS='|' read -r cmd desc <<< "$entry"
    printf "%-25s %s\n" "$cmd" "$desc" >> "$REPORT_TXT"
done

cat >> "$REPORT_TXT" << EOF

================================================================================
VIRTUAL ENVIRONMENTS
================================================================================

Working:
EOF

for entry in "${VENV_OK[@]}"; do
    IFS='|' read -r tool desc path <<< "$entry"
    printf "  ✓ %-20s %s\n" "$tool" "$path" >> "$REPORT_TXT"
done

cat >> "$REPORT_TXT" << EOF

Missing/Broken:
EOF

for entry in "${VENV_FAIL[@]}"; do
    IFS='|' read -r tool desc <<< "$entry"
    printf "  ✗ %-20s %s\n" "$tool" "$desc" >> "$REPORT_TXT"
done

# =============================================================================
# Generate HTML Report
# =============================================================================

cat > "$REPORT_HTML" << 'HTMLHEAD'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Santoku-Kali Verification Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; border-left: 4px solid #3498db; padding-left: 10px; }
        .summary { display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; margin: 20px 0; }
        .stat-box { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; }
        .stat-box.success { background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); }
        .stat-box.warning { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); }
        .stat-number { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .stat-label { font-size: 14px; opacity: 0.9; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background: #34495e; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ecf0f1; }
        tr:hover { background: #f8f9fa; }
        .status-ok { color: #27ae60; font-weight: bold; }
        .status-fail { color: #e74c3c; font-weight: bold; }
        .badge { display: inline-block; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: bold; }
        .badge-success { background: #d4edda; color: #155724; }
        .badge-danger { background: #f8d7da; color: #721c24; }
        .progress-bar { width: 100%; height: 30px; background: #ecf0f1; border-radius: 15px; overflow: hidden; margin: 20px 0; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, #11998e 0%, #38ef7d 100%); display: flex; align-items: center; justify-content: center; color: white; font-weight: bold; }
    </style>
</head>
<body>
<div class="container">
    <h1>🔒 Santoku-Kali Installation Verification Report</h1>
    <p><strong>Generated:</strong> TIMESTAMP_PLACEHOLDER</p>
HTMLHEAD

# Replace timestamp
sed -i "s/TIMESTAMP_PLACEHOLDER/$(date)/" "$REPORT_HTML"

cat >> "$REPORT_HTML" << HTMLSUMMARY
    <h2>📊 Summary</h2>
    <div class="summary">
        <div class="stat-box">
            <div class="stat-label">Total Tested</div>
            <div class="stat-number">$TOTAL_TESTS</div>
        </div>
        <div class="stat-box success">
            <div class="stat-label">✓ Installed</div>
            <div class="stat-number">$TOTAL_INSTALLED</div>
        </div>
        <div class="stat-box warning">
            <div class="stat-label">✗ Missing</div>
            <div class="stat-number">$TOTAL_MISSING</div>
        </div>
        <div class="stat-box">
            <div class="stat-label">Success Rate</div>
            <div class="stat-number">${SUCCESS_RATE}%</div>
        </div>
    </div>
    
    <div class="progress-bar">
        <div class="progress-fill" style="width: ${SUCCESS_RATE}%;">${SUCCESS_RATE}%</div>
    </div>
HTMLSUMMARY

# Installed tools table
cat >> "$REPORT_HTML" << 'HTMLTABLE1'
    <h2>✅ Installed Tools</h2>
    <table>
        <thead>
            <tr>
                <th>Command</th>
                <th>Description</th>
                <th>Version/Status</th>
            </tr>
        </thead>
        <tbody>
HTMLTABLE1

for entry in "${INSTALLED[@]}"; do
    IFS='|' read -r cmd desc version <<< "$entry"
    echo "            <tr><td><code>$cmd</code></td><td>$desc</td><td><span class=\"badge badge-success\">$version</span></td></tr>" >> "$REPORT_HTML"
done

cat >> "$REPORT_HTML" << 'HTMLTABLE2'
        </tbody>
    </table>

    <h2>❌ Missing Tools</h2>
    <table>
        <thead>
            <tr>
                <th>Command</th>
                <th>Description</th>
                <th>Status</th>
            </tr>
        </thead>
        <tbody>
HTMLTABLE2

if [[ ${#MISSING[@]} -eq 0 ]]; then
    echo "            <tr><td colspan=\"3\" style=\"text-align:center;\">🎉 All tools installed successfully!</td></tr>" >> "$REPORT_HTML"
else
    for entry in "${MISSING[@]}"; do
        IFS='|' read -r cmd desc <<< "$entry"
        echo "            <tr><td><code>$cmd</code></td><td>$desc</td><td><span class=\"badge badge-danger\">Not Found</span></td></tr>" >> "$REPORT_HTML"
    done
fi

cat >> "$REPORT_HTML" << 'HTMLEND'
        </tbody>
    </table>

    <h2>🐍 Virtual Environments Status</h2>
    <table>
        <thead>
            <tr>
                <th>Tool</th>
                <th>Path</th>
                <th>Status</th>
            </tr>
        </thead>
        <tbody>
HTMLEND

for entry in "${VENV_OK[@]}"; do
    IFS='|' read -r tool desc path <<< "$entry"
    echo "            <tr><td><code>$tool</code></td><td><small>$path</small></td><td><span class=\"status-ok\">✓ OK</span></td></tr>" >> "$REPORT_HTML"
done

for entry in "${VENV_FAIL[@]}"; do
    IFS='|' read -r tool desc <<< "$entry"
    echo "            <tr><td><code>$tool</code></td><td>-</td><td><span class=\"status-fail\">✗ Missing</span></td></tr>" >> "$REPORT_HTML"
done

cat >> "$REPORT_HTML" << 'HTMLFOOTER'
        </tbody>
    </table>
    
    <div style="margin-top: 40px; padding: 20px; background: #e8f4f8; border-left: 4px solid #3498db; border-radius: 4px;">
        <h3>💡 Quick Fixes for Missing Tools</h3>
        <ul>
            <li>Re-run individual installer: <code>sudo bash /opt/santoku-kali/scripts/XX_category.sh</code></li>
            <li>Check logs: <code>ls /opt/santoku-kali/logs/</code></li>
            <li>Verify PATH: <code>echo $PATH | grep santoku-kali</code></li>
            <li>Re-run master installer: <code>sudo bash /path/to/run_all.sh</code></li>
        </ul>
    </div>
</div>
</body>
</html>
HTMLFOOTER

# =============================================================================
# Display summary to terminal
# =============================================================================

echo -e "\n${CYAN}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  VERIFICATION COMPLETE${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}\n"

echo -e "${BOLD}Summary:${NC}"
echo -e "  Total Tools:    $TOTAL_TESTS"
echo -e "  ${GREEN}✓ Installed:   $TOTAL_INSTALLED${NC}"
echo -e "  ${RED}✗ Missing:     $TOTAL_MISSING${NC}"
echo -e "  ${BLUE}Success Rate:  ${SUCCESS_RATE}%${NC}"
echo ""

if [[ $TOTAL_MISSING -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}🎉 ALL TOOLS INSTALLED SUCCESSFULLY! 🎉${NC}\n"
else
    echo -e "${YELLOW}⚠ Some tools are missing. Check the reports for details.${NC}\n"
fi

echo -e "${BOLD}Reports generated:${NC}"
echo -e "  📄 Text:  ${BLUE}$REPORT_TXT${NC}"
echo -e "  🌐 HTML:  ${BLUE}$REPORT_HTML${NC}"
echo ""
echo -e "${CYAN}View HTML report in browser:${NC}"
echo -e "  firefox $REPORT_HTML"
echo ""

# Print missing tools if any
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo -e "${YELLOW}${BOLD}Missing Tools:${NC}"
    for entry in "${MISSING[@]}"; do
        IFS='|' read -r cmd desc <<< "$entry"
        echo -e "  ${RED}✗${NC} $cmd - $desc"
    done
    echo ""
fi

# Exit code based on results
if [[ $SUCCESS_RATE -ge 90 ]]; then
    exit 0  # Success
elif [[ $SUCCESS_RATE -ge 70 ]]; then
    exit 1  # Partial success
else
    exit 2  # Many failures
fi
