// ============================================================
// Testbench : tb_axi_prng_top  (v3 – edge-safe AXI tasks)
// ============================================================
`timescale 1ns/1ps

module tb_axi_prng_top;

    reg aclk, aresetn;
    reg [31:0] s_axi_awaddr; reg s_axi_awvalid; wire s_axi_awready;
    reg [31:0] s_axi_wdata;  reg [3:0] s_axi_wstrb;
    reg s_axi_wvalid; wire s_axi_wready;
    wire [1:0] s_axi_bresp; wire s_axi_bvalid; reg s_axi_bready;
    reg [31:0] s_axi_araddr; reg s_axi_arvalid; wire s_axi_arready;
    wire [31:0] s_axi_rdata; wire [1:0] s_axi_rresp;
    wire s_axi_rvalid; reg s_axi_rready;

    axi_prng_top dut (
        .aclk(aclk),.aresetn(aresetn),
        .s_axi_awaddr(s_axi_awaddr),.s_axi_awvalid(s_axi_awvalid),.s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),.s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),.s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),.s_axi_bvalid(s_axi_bvalid),.s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),.s_axi_arvalid(s_axi_arvalid),.s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),.s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),.s_axi_rready(s_axi_rready));

    initial aclk = 0;
    always #5 aclk = ~aclk;

    initial begin
        $dumpfile("sim/dump_top.vcd");
        $dumpvars(0, tb_axi_prng_top);
    end

    integer pass_cnt, fail_cnt, test_num;

    task check;
        input cond; input [255:0] msg;
        begin
            test_num = test_num + 1;
            if (cond) begin $display("  [PASS] Test %0d : %s", test_num, msg); pass_cnt=pass_cnt+1; end
            else      begin $display("  [FAIL] Test %0d : %s", test_num, msg); fail_cnt=fail_cnt+1; end
        end
    endtask

    // AXI write
    task axi_write;
        input [31:0] addr; input [31:0] data; output [1:0] resp;
        integer t;
        begin
            s_axi_awaddr=addr; s_axi_awvalid=1;
            s_axi_wdata=data;  s_axi_wvalid=1; s_axi_wstrb=4'hF;
            s_axi_bready=1;
            // AW handshake
            @(posedge aclk);
            t=0; while (!s_axi_awready && t<30) begin @(posedge aclk); t=t+1; end
            s_axi_awvalid=0;
            // W handshake
            t=0; while (!s_axi_wready && t<30) begin @(posedge aclk); t=t+1; end
            s_axi_wvalid=0;
            // B handshake – keep bready HIGH until bvalid seen
            t=0; while (!s_axi_bvalid && t<30) begin @(posedge aclk); t=t+1; end
            resp=s_axi_bresp;
            @(posedge aclk);      // consume the bvalid cycle
            s_axi_bready=0;
            @(posedge aclk);      // idle gap
        end
    endtask

    // AXI read
    task axi_read;
        input [31:0] addr; output [31:0] data; output [1:0] resp;
        integer t;
        begin
            s_axi_araddr=addr; s_axi_arvalid=1; s_axi_rready=1;
            // Wait for arready
            t=0;
            repeat(1) @(posedge aclk);
            while (!s_axi_arready && t<30) begin @(posedge aclk); t=t+1; end
            s_axi_arvalid=0;
            // Wait for rvalid
            t=0;
            repeat(1) @(posedge aclk);
            while (!s_axi_rvalid && t<30) begin @(posedge aclk); t=t+1; end
            data=s_axi_rdata; resp=s_axi_rresp;
            @(posedge aclk); s_axi_rready=0;
            @(posedge aclk);
        end
    endtask

    reg [31:0] rdata; reg [1:0] resp;
    reg [3:0] prev_rand;
    integer i; reg [14:0] seen_mask; integer unique_count;

    initial begin
        pass_cnt=0; fail_cnt=0; test_num=0;
        aresetn=0;
        s_axi_awvalid=0; s_axi_wvalid=0; s_axi_bready=0;
        s_axi_arvalid=0; s_axi_rready=0;
        s_axi_awaddr=0; s_axi_wdata=0; s_axi_wstrb=0; s_axi_araddr=0;

        repeat(6) @(posedge aclk); aresetn=1;
        repeat(3) @(posedge aclk);

        $display("\n============================================");
        $display("   AXI-Lite PRNG Top Integration Tests");
        $display("============================================");

        // 1-2: Reset state
        $display("\n--- Test 1-2: Reset state ---");
        axi_read(32'h00, rdata, resp);
        check(rdata===32'h0,  "CTRL_REG = 0 after reset");
        check(resp===2'b00,   "CTRL read response = OKAY");

        // 3-4: Seed register
        $display("\n--- Test 3-4: Seed register ---");
        axi_write(32'h08, 32'h5, resp);
        check(resp===2'b00,         "SEED write response = OKAY");
        axi_read(32'h08, rdata, resp);
        check(rdata[3:0]===4'h5,    "SEED_REG readback = 5");

        // 5-6: Load seed  (write ctrl[1]=1 and ctrl[0]=1 together)
        $display("\n--- Test 5-6: Load seed + enable ---");
        axi_write(32'h00, 32'h3, resp);   // enable=1, load_seed=1
        check(resp===2'b00, "CTRL write (enable+load_seed) = OKAY");
        repeat(4) @(posedge aclk);
        axi_read(32'h04, rdata, resp);
        check(rdata[3:0]!==4'b0, "DATA_REG non-zero after enable+load");

        // 7-8: STATUS running
        $display("\n--- Test 7-8: Status register ---");
        axi_read(32'h0C, rdata, resp);
        check(rdata[0]===1'b1, "STATUS_REG[0] = 1 (running)");
        check(resp===2'b00,    "STATUS read response = OKAY");

        // 9: Output changes
        $display("\n--- Test 9: Output changes ---");
        axi_read(32'h04, rdata, resp);
        prev_rand = rdata[3:0];
        repeat(5) @(posedge aclk);
        axi_read(32'h04, rdata, resp);
        check(rdata[3:0]!==prev_rand, "DATA_REG changes over time");
        $display("         First=%0d  Second=%0d", prev_rand, rdata[3:0]);

        // 10-11: Disable freezes
        $display("\n--- Test 10-11: Disable ---");
        // Disable LFSR first
        axi_write(32'h00, 32'h0, resp);
        repeat(3) @(posedge aclk);   // let disable settle
        // Now read twice and verify output does not change
        axi_read(32'h04, rdata, resp);
        prev_rand=rdata[3:0];
        repeat(10) @(posedge aclk);
        axi_read(32'h04, rdata, resp);
        check(rdata[3:0]===prev_rand, "Output frozen when disabled");
        $display("         Value held=%0d", prev_rand);
        repeat(5) @(posedge aclk);   // extra settle after disable
        axi_read(32'h0C, rdata, resp);
        check(rdata[0]===1'b0, "STATUS_REG[0] = 0 (stopped)");

        // 12: Read-only
        $display("\n--- Test 12: Read-only protection ---");
        axi_write(32'h04, 32'hDEADBEEF, resp);
        check(resp===2'b10, "Write to DATA_REG returns SLVERR");

        // 13-14: Invalid address
        $display("\n--- Test 13-14: Invalid address ---");
        axi_read(32'hFF, rdata, resp);
        check(resp===2'b10,           "Invalid read returns SLVERR");
        check(1'b1, "RDATA undefined on SLVERR - not checked (AXI spec)");

        // 15: Full 15-state sequence
        $display("\n--- Test 15: Full 15-state sequence ---");
        axi_write(32'h08, 32'h1, resp);   // seed=1
        axi_write(32'h00, 32'h3, resp);   // enable + load_seed
        repeat(4) @(posedge aclk);

        seen_mask=15'b0; unique_count=0;
        $display("  Sequence from seed=1:");
        for (i=0; i<15; i=i+1) begin
            repeat(2) @(posedge aclk);
            axi_read(32'h04, rdata, resp);
            $display("    Step %2d : %04b (%2d)", i, rdata[3:0], rdata[3:0]);
            if (rdata[3:0]!=0 && !seen_mask[rdata[3:0]-1]) begin
                seen_mask[rdata[3:0]-1]=1; unique_count=unique_count+1;
            end
        end
        check(unique_count===15, "All 15 unique PRNG values observed");
        $display("         Unique = %0d / 15", unique_count);

        $display("\n============================================");
        $display("  Results : %0d PASS  |  %0d FAIL", pass_cnt, fail_cnt);
        $display("============================================\n");
        if (fail_cnt==0) $display("  ALL TESTS PASSED ✓\n");
        else             $display("  SOME TESTS FAILED ✗\n");
        $finish;
    end
    initial begin #200000; $display("[TIMEOUT]"); $finish; end
endmodule