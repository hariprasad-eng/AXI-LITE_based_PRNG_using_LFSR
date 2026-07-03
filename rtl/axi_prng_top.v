// ============================================================
// Module  : axi_prng_top
// Project : AXI-Lite PRNG RTL2GDS
// Description:
//   Top-level wrapper that ties together:
//     - axi_lite_slave  (bus interface + register map)
//     - lfsr_core       (instantiated inside axi_lite_slave)
//
//   This is the module that will be synthesised and taken
//   through the complete RTL-to-GDS flow.
//
//   Pin naming follows the AXI4-Lite standard so this module
//   can be dropped directly into a Vivado/Quartus block design
//   or connected to an OpenROAD harness.
// ============================================================

module axi_prng_top (
    // ── Clock & Reset ────────────────────────────────────────
    input  wire        aclk,
    input  wire        aresetn,

    // ── AXI4-Lite Write Address Channel ─────────────────────
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    // ── AXI4-Lite Write Data Channel ────────────────────────
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    // ── AXI4-Lite Write Response Channel ────────────────────
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,

    // ── AXI4-Lite Read Address Channel ──────────────────────
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    // ── AXI4-Lite Read Data Channel ─────────────────────────
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready
);

    // --------------------------------------------------------
    // Instantiate AXI-Lite slave (contains LFSR core inside)
    // --------------------------------------------------------
    axi_lite_slave u_axi_slave (
        .aclk      (aclk),
        .aresetn   (aresetn),

        // Write address
        .awaddr    (s_axi_awaddr),
        .awvalid   (s_axi_awvalid),
        .awready   (s_axi_awready),

        // Write data
        .wdata     (s_axi_wdata),
        .wstrb     (s_axi_wstrb),
        .wvalid    (s_axi_wvalid),
        .wready    (s_axi_wready),

        // Write response
        .bresp     (s_axi_bresp),
        .bvalid    (s_axi_bvalid),
        .bready    (s_axi_bready),

        // Read address
        .araddr    (s_axi_araddr),
        .arvalid   (s_axi_arvalid),
        .arready   (s_axi_arready),

        // Read data
        .rdata     (s_axi_rdata),
        .rresp     (s_axi_rresp),
        .rvalid    (s_axi_rvalid),
        .rready    (s_axi_rready)
    );

endmodule
