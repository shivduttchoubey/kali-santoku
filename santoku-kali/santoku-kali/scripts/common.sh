#!/bin/bash
# =============================================================================
# common.sh — Shared helpers for all installers
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

BASE="/opt/santoku-kali"
TOOLS="$BASE/tools"
BIN="$BASE/bin"
LOGS="$BASE/logs"

info()    { echo -e "${BLUE}[INFO]${NC}    $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[OK]${NC}      $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $*" | tee -a "$LOG_FILE"; }
err()     { echo -e "${RED}[ERROR]${NC}   $*" | tee -a "$LOG_FILE"; }
section() { echo -e "\n${CYAN}══════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
            echo -e "${CYAN}  $*${NC}" | tee -a "$LOG_FILE"
            echo -e "${CYAN}══════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"; }

# Create a Python venv and upgrade pip inside it
make_venv() {
    local tool="$1"
    local venv="$TOOLS/$tool/venv"
    info "Creating venv for $tool..."
    python3 -m venv "$venv" >> "$LOG_FILE" 2>&1
    "$venv/bin/pip" install --upgrade pip setuptools wheel >> "$LOG_FILE" 2>&1
    echo "$venv"
}

# Install pip packages into a tool's venv
pip_install() {
    local tool="$1"; shift
    "$TOOLS/$tool/venv/bin/pip" install "$@" >> "$LOG_FILE" 2>&1
}

# Write a wrapper in $BIN that activates the right venv then runs the binary
make_wrapper() {
    local wrapper_name="$1"   # name of command in $BIN
    local tool="$2"           # tool directory name
    local binary="$3"         # binary path (relative to venv/bin OR absolute)
    local w="$BIN/$wrapper_name"

    # Decide if it's a venv binary or a plain binary
    if [[ "$binary" == /* ]]; then
        # absolute path — no venv needed
        cat > "$w" <<EOF
#!/bin/bash
exec "$binary" "\$@"
EOF
    else
        local venv="$TOOLS/$tool/venv"
        cat > "$w" <<EOF
#!/bin/bash
source "$venv/bin/activate"
exec "$venv/bin/$binary" "\$@"
EOF
    fi
    chmod +x "$w"
}

# Download a file with retries
download() {
    local url="$1"; local dest="$2"
    wget -q --show-progress --tries=3 -O "$dest" "$url" >> "$LOG_FILE" 2>&1
}

# Install apt packages, ignoring individual failures
apt_install() {
    for pkg in "$@"; do
        apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1 \
            && success "apt: $pkg" \
            || warn    "apt: $pkg not found — skipping"
    done
}

# Clone or update a git repo
git_clone() {
    local url="$1"; local dest="$2"
    if [[ -d "$dest/.git" ]]; then
        git -C "$dest" pull --ff-only >> "$LOG_FILE" 2>&1
    else
        git clone --depth=1 "$url" "$dest" >> "$LOG_FILE" 2>&1
    fi
}
