#!/bin/bash
# ============================================================
# run_sim.sh  –  Compile and run AXI-Lite PRNG simulations
#
# Usage:
#   chmod +x run_sim.sh
#   ./run_sim.sh          # run both testbenches
#   ./run_sim.sh lfsr     # run only LFSR unit test
#   ./run_sim.sh top      # run only top-level integration test
#   ./run_sim.sh wave     # run top test and open GTKWave
# ============================================================

set -e

# Colour codes
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'   # No colour

# ── Create output directory ──────────────────────────────────
mkdir -p sim

# ── RTL source files ─────────────────────────────────────────
RTL_LFSR="rtl/lfsr_core.v"
RTL_AXI="rtl/axi_lite_slave.v"
RTL_TOP="rtl/axi_prng_top.v"

TB_LFSR="tb/tb_lfsr_core.v"
TB_TOP="tb/tb_axi_prng_top.v"

# ──────────────────────────────────────────────────────────────
run_lfsr_test() {
    echo -e "\n${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Compiling LFSR Core Unit Test      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"

    iverilog -Wall \
             -o sim/sim_lfsr \
             -g2012 \
             "$TB_LFSR" "$RTL_LFSR"

    echo -e "${GREEN}Compilation OK${NC}"
    echo -e "\n${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Running LFSR Core Unit Test        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}\n"

    vvp sim/sim_lfsr
}

# ──────────────────────────────────────────────────────────────
run_top_test() {
    echo -e "\n${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Compiling Top Integration Test     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"

    iverilog -Wall \
             -o sim/sim_top \
             -g2012 \
             "$TB_TOP" "$RTL_TOP" "$RTL_AXI" "$RTL_LFSR"

    echo -e "${GREEN}Compilation OK${NC}"
    echo -e "\n${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Running Top Integration Test       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}\n"

    vvp sim/sim_top
}

# ──────────────────────────────────────────────────────────────
open_wave() {
    if command -v gtkwave &>/dev/null; then
        echo -e "\n${CYAN}Opening GTKWave...${NC}"
        gtkwave sim/dump_top.vcd &
    else
        echo -e "${YELLOW}GTKWave not found. Install it with:${NC}"
        echo "  sudo apt install gtkwave"
        echo -e "VCD files are in ${CYAN}sim/${NC}"
    fi
}

# ──────────────────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────────────────
case "${1:-both}" in
    lfsr)
        run_lfsr_test
        ;;
    top)
        run_top_test
        ;;
    wave)
        run_top_test
        open_wave
        ;;
    both|*)
        run_lfsr_test
        run_top_test
        echo -e "\n${GREEN}Both simulations complete.${NC}"
        echo -e "VCD waveforms saved in ${CYAN}sim/${NC}"
        echo -e "View with: ${YELLOW}gtkwave sim/dump_lfsr.vcd${NC}"
        echo -e "        or ${YELLOW}gtkwave sim/dump_top.vcd${NC}"
        ;;
esac





