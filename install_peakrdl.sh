#!/bin/bash

set -e

echo "========================================="
echo " Installing PeakRDL FULL Plugin Suite   "
echo "========================================="

ENV_DIR="peakrdl_env"

# 1. Check Python
if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 not found (need Python 3.8+)"
    exit 1
fi

# 2. Create virtual environment
python3 -m venv $ENV_DIR
source $ENV_DIR/bin/activate

# 3. Upgrade pip
pip install --upgrade pip setuptools wheel

# 4. Install PeakRDL core
pip install peakrdl
pip install peakrdl-regblock        # SystemVerilog RTL
pip install peakrdl-uvm             # UVM RAL model
pip install peakrdl-html            # HTML docs
pip install peakrdl-markdown        # Markdown docs
pip install peakrdl-ipxact          # IP-XACT export/import
#pip install peakrdl-csv             # CSV export (if available)
#pip install peakrdl-json            # JSON export
#pip install peakrdl-yaml            # YAML export

# Some plugins may not exist in PyPI for all versions
# So ignore failure for optional ones
set +e
pip install peakrdl-cheader         # C header generation
pip install peakrdl-python          # Python access layer
set -e

echo "========================================="
echo " PeakRDL Full Installation Complete     "
echo "========================================="

echo ""
echo "Activate environment:"
echo "  source $ENV_DIR/bin/activate"
echo ""

echo "List installed plugins:"
echo "  peakrdl plugins"
echo ""

echo "Try commands:"
echo "  peakrdl regblock file.rdl -o rtl/"
echo "  peakrdl uvm file.rdl -o uvm/"
echo "  peakrdl html file.rdl -o docs/"
