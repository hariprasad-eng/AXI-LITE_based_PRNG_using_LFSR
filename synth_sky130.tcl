#         # yosys -s synth_sky130.tcl   ----------> run this to view gate-level

# # Read RTL
# read_verilog rtl/lfsr_core.v
# read_verilog rtl/axi_lite_slave.v
# read_verilog rtl/axi_prng_top.v

# # Top module
# hierarchy -check -top axi_prng_top

# # Synthesis
# synth -top axi_prng_top

# # DFF mapping
# dfflibmap -liberty   

# # Combinational mapping
# abc -liberty /home/hariprasad/Documents/AXI-LITE_PRNG/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib \
#     -constr constraints.sdc

#     # Cleanup
# clean

# opt

# # Flatten hierarchy
# flatten


# # Write mapped netlist
# write_verilog -noattr -noexpr synth_sky130_mapped.v

# # Schematic
# show -stretch -format svg -prefix output_schematic axi_prng_top


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


                                            # synth_optimized.tcl

# ── Read RTL ──────────────────────────────────────────────
read_verilog rtl/lfsr_core.v
read_verilog rtl/axi_lite_slave.v
read_verilog rtl/axi_prng_top.v

# ── Elaborate ─────────────────────────────────────────────
hierarchy -check -top axi_prng_top


flatten

# ── RTL optimizations ─────────────────────────────────────
proc                    # convert always blocks
opt_expr -full          # expression simplification
opt_clean               # remove dead logic
fsm                     # extract FSMs
opt -full               # full optimization pass
memory                  # memory inference
opt -full

# ── Coarse-grain synthesis ────────────────────────────────
techmap                 # generic tech mapping
opt -fast

# ── Technology mapping ────────────────────────────────────
dfflibmap -liberty /home/hariprasad/Documents/AXI-LITE_PRNG/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

abc -liberty /home/hariprasad/Documents/AXI-LITE_PRNG/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib -D 8000  # Target: 8ns critical path (125 MHz)

# ── Post-mapping cleanup ──────────────────────────────────
opt_clean -purge
setundef -zero          # replace X with 0 (safer for P&R)
# splitnets               # split multi-bit nets (needed for OpenROAD)
clean


hilomap \
    -hicell sky130_fd_sc_hd__conb_1 HI \
    -locell sky130_fd_sc_hd__conb_1 LO
    
# ── Output ────────────────────────────────────────────────
write_verilog -noattr synth_mapped.v    # For OpenROAD P&R
write_json    netlist.json              # For netlistsvg viewing

# ── View schematic ────────────────────────────────────────
show -stretch -format svg -prefix schematic axi_prng_top

log "=============================================================== FINAL REPORT ============================================================================"
stat -liberty /home/hariprasad/Documents/AXI-LITE_PRNG/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
log "========================================================================================================================================================="   
# Shows: cells, area, flip-flops

