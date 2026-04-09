# =============================================================================
# Makefile  —  PeakRDL CSR Generation Framework
#
# Targets:
#   make install        — install PeakRDL into ./peakrdl_env
#   make all            — generate all outputs from RDL_FILE
#   make rtl            — SystemVerilog RTL only
#   make cheader        — C header only
#   make html           — HTML docs only
#   make uvm            — UVM model only
#   make ipxact         — IP-XACT XML only
#   make systemrdl      — normalised SystemRDL only
#   make clean          — delete output directory
#   make help           — print this message
# =============================================================================

# ── User configuration ────────────────────────────────────────────────────────
RDL_FILE   ?= example_csr.rdl   # override: make all RDL_FILE=my_chip.rdl
OUT_DIR    ?= output
VENV_DIR   ?= peakrdl_env
CPU_IF     ?= axi4-lite          # axi4-lite | apb3 | apb4 | passthrough

# ── Internal ──────────────────────────────────────────────────────────────────
SHELL      := /bin/bash
PEAKRDL    := $(VENV_DIR)/bin/peakrdl
GEN_SCRIPT := ./generate_csr.sh

# Colour macros (GNU make)
CYAN  := \033[0;36m
BOLD  := \033[1m
NC    := \033[0m

.PHONY: all install rtl cheader html uvm ipxact systemrdl clean help

# ── Default ───────────────────────────────────────────────────────────────────
all: install
	@$(GEN_SCRIPT) -o $(OUT_DIR) -e $(VENV_DIR) -c $(CPU_IF) \
	               -t rtl,cheader,html,uvm,ipxact,systemrdl \
	               $(RDL_FILE)

# ── Install ───────────────────────────────────────────────────────────────────
install: install_peakrdl.sh
	@if [ ! -x "$(PEAKRDL)" ]; then \
	  echo -e "$(CYAN)[MAKE]$(NC) Running PeakRDL installer..."; \
	  bash install_peakrdl.sh $(VENV_DIR); \
	else \
	  echo -e "$(CYAN)[MAKE]$(NC) PeakRDL already installed at $(PEAKRDL)"; \
	fi

# ── Individual targets ────────────────────────────────────────────────────────
rtl: install
	@$(GEN_SCRIPT) -o $(OUT_DIR) -e $(VENV_DIR) -c $(CPU_IF) -t rtl $(RDL_FILE)

cheader: install
	@$(GEN_SCRIPT) -o $(OUT_DIR) -e $(VENV_DIR) -t cheader $(RDL_FILE)

html: install
	@$(GEN_SCRIPT) -o $(OUT_DIR) -e $(VENV_DIR) -t html $(RDL_FILE)

uvm: install
	@$(GEN_SCRIPT) -o $(OUT_DIR) -e $(VENV_DIR) -t uvm $(RDL_FILE)

ipxact: install
	@$(GEN_SCRIPT) -o $(OUT_DIR) -e $(VENV_DIR) -t ipxact $(RDL_FILE)

systemrdl: install
	@$(GEN_SCRIPT) -o $(OUT_DIR) -e $(VENV_DIR) -t systemrdl $(RDL_FILE)

# ── Clean ─────────────────────────────────────────────────────────────────────
clean:
	@echo -e "$(CYAN)[MAKE]$(NC) Removing $(OUT_DIR)..."
	@rm -rf $(OUT_DIR)
	@echo "Done."

# ── Help ──────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo -e "$(BOLD)PeakRDL CSR Generation Framework$(NC)"
	@echo ""
	@echo "  make install                   Install PeakRDL toolchain"
	@echo "  make all [RDL_FILE=foo.rdl]    Generate all outputs"
	@echo "  make rtl                       SystemVerilog RTL only"
	@echo "  make cheader                   C header only"
	@echo "  make html                      HTML register docs only"
	@echo "  make uvm                       UVM register model only"
	@echo "  make ipxact                    IP-XACT XML only"
	@echo "  make systemrdl                 Normalised SystemRDL only"
	@echo "  make clean                     Remove output directory"
	@echo ""
	@echo "  Variables (override on command line):"
	@echo "    RDL_FILE = $(RDL_FILE)"
	@echo "    OUT_DIR  = $(OUT_DIR)"
	@echo "    VENV_DIR = $(VENV_DIR)"
	@echo "    CPU_IF   = $(CPU_IF)   (axi4-lite | apb3 | apb4 | passthrough)"
	@echo ""
