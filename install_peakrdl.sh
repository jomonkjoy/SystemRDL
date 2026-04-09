#!/usr/bin/env bash
# =============================================================================
# install_peakrdl.sh
# Installs PeakRDL and all official plugins into an isolated virtual env.
# Usage:
#   chmod +x install_peakrdl.sh
#   ./install_peakrdl.sh                    # default venv at ./peakrdl_env
#   ./install_peakrdl.sh /path/to/my_venv   # custom venv location
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Configuration ─────────────────────────────────────────────────────────────
VENV_DIR="${1:-./peakrdl_env}"
MIN_PYTHON_MINOR=9   # PeakRDL requires Python >= 3.7; plugins like peakrdl-python need 3.9

# ── Check Python ──────────────────────────────────────────────────────────────
info "Checking Python installation..."
PYTHON=$(command -v python3 || true)
[[ -z "$PYTHON" ]] && die "python3 not found. Please install Python 3.${MIN_PYTHON_MINOR}+."

PY_VERSION=$("$PYTHON" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PY_MINOR=$("$PYTHON"  -c "import sys; print(sys.version_info.minor)")
PY_MAJOR=$("$PYTHON"  -c "import sys; print(sys.version_info.major)")

[[ "$PY_MAJOR" -lt 3 || ( "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt "$MIN_PYTHON_MINOR" ) ]] \
  && die "Python ${PY_VERSION} found, but 3.${MIN_PYTHON_MINOR}+ is required."

success "Python ${PY_VERSION} found at ${PYTHON}"

# ── Create virtual environment ────────────────────────────────────────────────
if [[ -d "$VENV_DIR" ]]; then
  warn "Virtual environment already exists at '${VENV_DIR}'. Skipping creation."
else
  info "Creating virtual environment at '${VENV_DIR}'..."
  "$PYTHON" -m venv "$VENV_DIR"
  success "Virtual environment created."
fi

# Activate venv
# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"
PIP="${VENV_DIR}/bin/pip"

# ── Upgrade pip ───────────────────────────────────────────────────────────────
info "Upgrading pip..."
"$PIP" install --upgrade pip --quiet
success "pip upgraded."

# ── Install PeakRDL core + all official plugins ───────────────────────────────
# peakrdl          — the unified CLI entry point
# peakrdl-regblock — synthesisable SystemVerilog RTL (AXI4-Lite / APB / custom)
# peakrdl-cheader  — C register abstraction header
# peakrdl-html     — rich HTML register documentation
# peakrdl-uvm      — UVM register model (reg_block)
# peakrdl-ipxact   — IP-XACT 2009 / 2014 / 2022 import & export
# peakrdl-systemrdl— write compiled model back to SystemRDL
# peakrdl-python   — Python register access layer (RAL) + simulator

PACKAGES=(
  "peakrdl"
  "peakrdl-regblock"
  "peakrdl-cheader"
  "peakrdl-html"
  "peakrdl-uvm"
  "peakrdl-ipxact"
  "peakrdl-systemrdl"
  "peakrdl-python"
)

info "Installing PeakRDL packages..."
echo ""
for pkg in "${PACKAGES[@]}"; do
  echo -e "  ${BOLD}→ Installing ${pkg}...${NC}"
  "$PIP" install "$pkg" --quiet
  success "${pkg} installed."
done
echo ""

# ── Verify CLI ────────────────────────────────────────────────────────────────
info "Verifying PeakRDL CLI..."
PEAKRDL_BIN="${VENV_DIR}/bin/peakrdl"
[[ ! -x "$PEAKRDL_BIN" ]] && die "peakrdl binary not found at ${PEAKRDL_BIN}"

echo ""
echo -e "${BOLD}──────────────────────────────────────────────────────────────${NC}"
"$PEAKRDL_BIN" --help | head -20
echo -e "${BOLD}──────────────────────────────────────────────────────────────${NC}"
echo ""

# ── Print installed versions ──────────────────────────────────────────────────
info "Installed package versions:"
"$PIP" show "${PACKAGES[@]}" 2>/dev/null \
  | grep -E "^(Name|Version)" \
  | paste - - \
  | awk '{printf "  %-35s %s\n", $2, $4}'

echo ""
success "PeakRDL installation complete!"
echo ""
echo -e "${CYAN}To activate the environment in your current shell, run:${NC}"
echo -e "  ${BOLD}source ${VENV_DIR}/bin/activate${NC}"
echo ""
echo -e "${CYAN}Quick smoke test:${NC}"
echo -e "  ${BOLD}peakrdl --help${NC}"
echo -e "  ${BOLD}peakrdl regblock --help${NC}"
echo -e "  ${BOLD}peakrdl html --help${NC}"
echo ""
