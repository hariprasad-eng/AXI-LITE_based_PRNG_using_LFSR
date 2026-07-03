// ============================================================
// Module  : axi_lite_slave  (Zero-Bloat, Single-Cycle Handshake)
// ============================================================

module axi_lite_slave (
    input  wire        aclk,
    input  wire        aresetn,

    input  wire [31:0] awaddr,
    input  wire        awvalid,
    output reg         awready,

    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    input  wire        wvalid,
    output reg         wready,

    output wire [1:0]  bresp,   // Changed to wire to save FFs
    output reg         bvalid,
    input  wire        bready,

    input  wire [31:0] araddr,
    input  wire        arvalid,
    output reg         arready,

    output wire [31:0] rdata,
    output wire [1:0]  rresp,   // Changed to wire to save FFs
    output reg         rvalid,
    input  wire        rready
);

    // ── Minimal State Registers ──────────────────────────────
    reg        ctrl_enable;
    reg        ctrl_load_seed;
    reg [3:0]  seed_reg;
    
    // Error state latches (We only need 1 bit since bit 0 is always 0)
    reg bresp_err;
    reg rresp_err;
    assign bresp = {bresp_err, 1'b0};
    assign rresp = {rresp_err, 1'b0};

    wire [3:0] rand_out;
    wire lfsr_rstn = aresetn & ~ctrl_load_seed;

    lfsr_core u_lfsr (
        .clk      (aclk),
        .rst_n    (lfsr_rstn),
        .enable   (ctrl_enable),
        .seed     (seed_reg),
        .rand_out (rand_out)
    );

    // ── Single-Cycle Write Channel (Zero Latches) ────────────
    // Only trigger when both valid signals are present
    wire write_trigger = awvalid && wvalid && !awready && !bvalid;

    always @(posedge aclk) begin
        if (!aresetn) begin
            awready        <= 0;
            wready         <= 0;
            bvalid         <= 0;
            bresp_err      <= 0;
            ctrl_enable    <= 0;
            ctrl_load_seed <= 0;
            seed_reg       <= 4'h1;
        end else begin
            // Self-clearing load
            if (ctrl_load_seed) ctrl_load_seed <= 0;

            // Fire Write Transaction
            if (write_trigger) begin
                awready <= 1;
                wready  <= 1;
                bvalid  <= 1;
                
                // Bit-Level Address Decode: Valid are 0x0 (...000) and 0x8 (...000)
                if (awaddr[2:0] == 3'b000) begin
                    bresp_err <= 0; // RESP_OKAY
                    if (awaddr[3] == 1'b0) begin
                        ctrl_enable    <= wdata[0];
                        ctrl_load_seed <= wdata[1];
                    end else begin
                        seed_reg       <= wdata[3:0];
                    end
                end else begin
                    bresp_err <= 1; // RESP_SLVERR
                end
            end else begin
                awready <= 0;
                wready  <= 0;
                if (bvalid && bready) bvalid <= 0;
            end
        end
    end

    // ── Single-Cycle Read Channel ─────────────────────────────
    reg [3:0] rdata_lat;
    assign rdata = {28'b0, rdata_lat};

    always @(posedge aclk) begin
        if (!aresetn) begin
            arready   <= 0;
            rvalid    <= 0;
            rresp_err <= 0;
            rdata_lat <= 0;
        end else begin
            if (arvalid && !arready && !rvalid) begin
                arready <= 1;
                rvalid  <= 1;
                
                // SLVERR if bottom 2 bits aren't 00
                rresp_err <= (araddr[1:0] != 2'b00);
                
                // 4-to-1 Multiplexer directly latching into output
                case (araddr[3:2])
                    2'b00: rdata_lat <= {2'b00, ctrl_load_seed, ctrl_enable}; // 0x0
                    2'b01: rdata_lat <= rand_out;                             // 0x4
                    2'b10: rdata_lat <= seed_reg;                             // 0x8
                    2'b11: rdata_lat <= {3'b000, ctrl_enable};                // 0xC
                endcase
            end else begin
                arready <= 0;
                if (rvalid && rready) rvalid <= 0;
            end
        end
    end

endmodule
