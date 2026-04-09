#!/usr/bin/env bash
# =============================================================================
# generate_csr.sh  —  PeakRDL CSR generation framework
#
# Drives all PeakRDL output generators from a single SystemRDL source file.
#
# Usage:
#   ./generate_csr.sh [OPTIONS] <top.rdl>
#
# Options:
#   -o DIR         Output root directory  (default: ./output)
#   -e VENV        PeakRDL venv directory (default: ./peakrdl_env)
#   -c CPUIF       CPU interface for RTL  (default: axi4-lite)
#                  Choices: axi4-lite | apb3 | apb4 | passthrough
#   -t TARGET      Comma-separated list of targets to generate
#                  Choices: rtl,cheader,html,uvm,ipxact,systemrdl
#                  (default: all)
#   -v             Verbose mode
#   -h             Show this help
#
# Examples:
#   ./generate_csr.sh my_regs.rdl
#   ./generate_csr.sh -o build/csr -c apb4 -t rtl,cheader,html my_regs.rdl
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}════ $* ════${NC}"; }

# ── Defaults ─────────────────────────────────────────────────────────────────
OUT_DIR="./output"
VENV_DIR="./peakrdl_env"
CPU_IF="axi4-lite"
TARGETS="rtl,cheader,html,uvm,ipxact,systemrdl"
VERBOSE=0

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,2\}//'
  exit 0
}

while getopts "o:e:c:t:vh" opt; do
  case $opt in
    o) OUT_DIR="$OPTARG"       ;;
    e) VENV_DIR="$OPTARG"      ;;
    c) CPU_IF="$OPTARG"        ;;
    t) TARGETS="$OPTARG"       ;;
    v) VERBOSE=1               ;;
    h) usage                   ;;
    *) die "Unknown option -${OPTARG}. Use -h for help." ;;
  esac
done
shift $((OPTIND - 1))

[[ $# -eq 0 ]] && die "No .rdl file specified. Usage: $0 [OPTIONS] <top.rdl>"
RDL_FILE="$1"
[[ ! -f "$RDL_FILE" ]] && die "RDL file not found: ${RDL_FILE}"

RDL_BASENAME=$(basename "$RDL_FILE" .rdl)

# ── Activate venv ─────────────────────────────────────────────────────────────
if [[ -d "$VENV_DIR" ]]; then
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
  PEAKRDL="${VENV_DIR}/bin/peakrdl"
elif command -v peakrdl &>/dev/null; then
  PEAKRDL="peakrdl"
  warn "Venv '${VENV_DIR}' not found; using system peakrdl: $(command -v peakrdl)"
else
  die "PeakRDL not found. Run install_peakrdl.sh first, or specify -e <venv>."
fi

[[ ! -x "$PEAKRDL" ]] && die "peakrdl not executable at: ${PEAKRDL}"

# ── Output directories ────────────────────────────────────────────────────────
RTL_DIR="${OUT_DIR}/rtl"
CHEADER_DIR="${OUT_DIR}/cheader"
HTML_DIR="${OUT_DIR}/html"
UVM_DIR="${OUT_DIR}/uvm"
IPXACT_DIR="${OUT_DIR}/ipxact"
SYSRDL_DIR="${OUT_DIR}/systemrdl"
LOG_DIR="${OUT_DIR}/logs"

mkdir -p "$RTL_DIR" "$CHEADER_DIR" "$HTML_DIR" "$UVM_DIR" \
         "$IPXACT_DIR" "$SYSRDL_DIR" "$LOG_DIR"

# ── Verbose flag ──────────────────────────────────────────────────────────────
V_FLAG=""
[[ "$VERBOSE" -eq 1 ]] && V_FLAG="--verbose"

# ── Helper: run a peakrdl command and log output ──────────────────────────────
run_peakrdl() {
  local target="$1"; shift
  local log_file="${LOG_DIR}/${target}.log"
  info "Running: peakrdl ${target} $*"
  if [[ "$VERBOSE" -eq 1 ]]; then
    "$PEAKRDL" "$target" "$@" 2>&1 | tee "$log_file"
  else
    "$PEAKRDL" "$target" "$@" > "$log_file" 2>&1 || {
      warn "peakrdl ${target} failed. See log: ${log_file}"
      cat "$log_file" >&2
      return 1
    }
  fi
  success "${target} output written. Log: ${log_file}"
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║           PeakRDL CSR Generation Framework                  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
info "Source RDL : ${RDL_FILE}"
info "Output dir : ${OUT_DIR}"
info "CPU IF     : ${CPU_IF}"
info "Targets    : ${TARGETS}"
echo ""

# Convert comma-separated targets to array
IFS=',' read -ra TARGET_LIST <<< "$TARGETS"

GENERATED=()
SKIPPED=()
FAILED=()

for target in "${TARGET_LIST[@]}"; do
  target=$(echo "$target" | tr -d ' ')
  case "$target" in

    # ── 1. SystemVerilog RTL register block ────────────────────────────────
    rtl)
      step "Generating SystemVerilog RTL (${CPU_IF})"
      if run_peakrdl regblock \
          "$RDL_FILE" \
          -o "${RTL_DIR}" \
          --cpuif "${CPU_IF}" \
          $V_FLAG; then
        GENERATED+=("rtl → ${RTL_DIR}")
        info "Generated files:"
        ls -1 "${RTL_DIR}/"
      else
        FAILED+=("rtl")
      fi
      ;;

    # ── 2. C register abstraction header ──────────────────────────────────
    cheader)
      step "Generating C Header"
      if run_peakrdl c-header \
          "$RDL_FILE" \
          -o "${CHEADER_DIR}/${RDL_BASENAME}.h" \
          $V_FLAG; then
        GENERATED+=("c-header → ${CHEADER_DIR}/${RDL_BASENAME}.h")
      else
        FAILED+=("c-header")
      fi
      ;;

    # ── 3. HTML documentation ──────────────────────────────────────────────
    html)
      step "Generating HTML Documentation"
      if run_peakrdl html \
          "$RDL_FILE" \
          -o "${HTML_DIR}" \
          $V_FLAG; then
        GENERATED+=("html → ${HTML_DIR}")
        info "Open: ${HTML_DIR}/index.html"
      else
        FAILED+=("html")
      fi
      ;;

    # ── 4. UVM register model ──────────────────────────────────────────────
    uvm)
      step "Generating UVM Register Model"
      if run_peakrdl uvm \
          "$RDL_FILE" \
          -o "${UVM_DIR}" \
          $V_FLAG; then
        GENERATED+=("uvm → ${UVM_DIR}")
        info "Generated files:"
        ls -1 "${UVM_DIR}/"
      else
        FAILED+=("uvm")
      fi
      ;;

    # ── 5. IP-XACT export ──────────────────────────────────────────────────
    ipxact)
      step "Generating IP-XACT"
      if run_peakrdl ip-xact \
          "$RDL_FILE" \
          -o "${IPXACT_DIR}/${RDL_BASENAME}.xml" \
          $V_FLAG; then
        GENERATED+=("ip-xact → ${IPXACT_DIR}/${RDL_BASENAME}.xml")
      else
        FAILED+=("ip-xact")
      fi
      ;;

    # ── 6. Write back to normalised SystemRDL ─────────────────────────────
    systemrdl)
      step "Exporting normalised SystemRDL"
      if run_peakrdl systemrdl \
          "$RDL_FILE" \
          -o "${SYSRDL_DIR}/${RDL_BASENAME}_out.rdl" \
          $V_FLAG; then
        GENERATED+=("systemrdl → ${SYSRDL_DIR}/${RDL_BASENAME}_out.rdl")
      else
        FAILED+=("systemrdl")
      fi
      ;;

    *)
      warn "Unknown target '${target}' — skipping. Valid: rtl cheader html uvm ipxact systemrdl"
      SKIPPED+=("$target")
      ;;
  esac
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                       SUMMARY                               ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ ${#GENERATED[@]} -gt 0 ]]; then
  echo -e "${GREEN}Generated:${NC}"
  for g in "${GENERATED[@]}"; do echo "  ✔  $g"; done
fi

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  echo -e "${YELLOW}Skipped:${NC}"
  for s in "${SKIPPED[@]}"; do echo "  ⚠  $s"; done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo -e "${RED}Failed:${NC}"
  for f in "${FAILED[@]}"; do echo "  ✘  $f  (see ${LOG_DIR}/${f}.log)"; done
  echo ""
  die "Some targets failed. Check logs under ${LOG_DIR}/"
fi

echo ""
success "All targets generated successfully under: ${OUT_DIR}"
echo ""
