// ============================================================
// Testbench : tb_lfsr_core
// Purpose   : Unit test for the 4-bit LFSR core
//
// Tests performed:
//   1. Reset behaviour  – verify seed is loaded correctly
//   2. Zero-seed guard  – all-zero seed must default to 0001
//   3. Full sequence    – verify all 15 unique states appear
//   4. Enable control   – output must hold when enable=0
//   5. Re-seed          – changing seed mid-run restarts sequence
//
// How to run:
//   iverilog -o sim_lfsr tb/tb_lfsr_core.v rtl/lfsr_core.v
//   vvp sim_lfsr
//   gtkwave dump_lfsr.vcd   (optional waveform)
// ============================================================

`timescale 1ns/1ps

module tb_lfsr_core;

    // ── DUT signals ─────────────────────────────────────────
    reg        clk;
    reg        rst_n;
    reg        enable;
    reg  [3:0] seed;
    wire [3:0] rand_out;

    // ── Instantiate DUT ─────────────────────────────────────
    lfsr_core dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .enable   (enable),
        .seed     (seed),
        .rand_out (rand_out)
    );

    // ── Clock generation : 10 ns period (100 MHz) ───────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── VCD dump ────────────────────────────────────────────
    initial begin
        $dumpfile("sim/dump_lfsr.vcd");
        $dumpvars(0, tb_lfsr_core);
    end

    // ── Helper task : apply reset ───────────────────────────
    task apply_reset;
        input [3:0] s;
        begin
            seed  = s;
            rst_n = 0;
            @(posedge clk); #1;
            @(posedge clk); #1;
            rst_n = 1;
        end
    endtask

    // ── Helper task : AXI-like wait cycles ──────────────────
    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
            #1;
        end
    endtask

    // ── Test tracking ───────────────────────────────────────
    integer pass_cnt;
    integer fail_cnt;

    task check;
        input [63:0] test_id;
        input        condition;
        input [127:0] msg;
        begin
            if (condition) begin
                $display("  [PASS] Test %0d : %s", test_id, msg);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  [FAIL] Test %0d : %s  (rand_out=%b)", test_id, msg, rand_out);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // ── Main test sequence ───────────────────────────────────
    integer i;
    reg [3:0] prev_val;
    reg [14:0] seen_mask;   // Bit i set if value (i+1) was seen
    integer unique_count;

    initial begin
        // Init
        pass_cnt = 0;
        fail_cnt = 0;
        enable   = 0;
        seed     = 4'b0001;
        rst_n    = 1;
        #3;

        $display("\n========================================");
        $display("   LFSR Core Unit Tests");
        $display("========================================");

        // ------------------------------------------------
        // TEST 1: Reset with seed=1
        // ------------------------------------------------
        $display("\n--- Test 1: Reset loads seed correctly ---");
        apply_reset(4'b0001);
        check(1, rand_out === 4'b0001, "rand_out == seed after reset");

        // ------------------------------------------------
        // TEST 2: Zero-seed guard (must load 0001 not 0000)
        // ------------------------------------------------
        $display("\n--- Test 2: Zero-seed guard ---");
        apply_reset(4'b0000);
        check(2, rand_out !== 4'b0000, "All-zero seed replaced with 0001");
        check(3, rand_out === 4'b0001, "Guarded seed value is 4'b0001");

        // ------------------------------------------------
        // TEST 3: Enable=0 holds output
        // ------------------------------------------------
        $display("\n--- Test 3: Enable=0 freezes output ---");
        apply_reset(4'b0101);
        enable   = 0;
        prev_val = rand_out;
        wait_cycles(5);
        check(4, rand_out === prev_val, "Output unchanged when enable=0");

        // ------------------------------------------------
        // TEST 4: Full 15-state sequence with seed=0001
        // ------------------------------------------------
        $display("\n--- Test 4: 15 unique states in full sequence ---");
        apply_reset(4'b0001);
        enable      = 1;
        seen_mask   = 15'b0;
        unique_count= 0;

        // The starting seed counts as first state
        if (rand_out != 4'b0000) begin
            seen_mask[rand_out - 1] = 1'b1;
            unique_count = unique_count + 1;
        end

        for (i = 0; i < 15; i = i + 1) begin
            @(posedge clk); #1;
            if (rand_out != 4'b0000 && !seen_mask[rand_out - 1]) begin
                seen_mask[rand_out - 1] = 1'b1;
                unique_count = unique_count + 1;
            end
        end

        check(5, unique_count === 15, "All 15 unique non-zero states observed");
        $display("         Seen mask : %015b", seen_mask);
        $display("         Unique values : %0d / 15", unique_count);

        // ------------------------------------------------
        // TEST 5: Sequence repeats after 15 steps
        // ------------------------------------------------
        $display("\n--- Test 5: Sequence repeats exactly at 15 steps ---");
        apply_reset(4'b0001);
        enable   = 1;
        prev_val = rand_out;     // = seed = 4'b0001

        // Advance 15 cycles – should return to same value
        wait_cycles(15);
        check(6, rand_out === prev_val, "State after 15 cycles == initial seed");

        // ------------------------------------------------
        // TEST 6: Different seeds produce valid sequences
        // ------------------------------------------------
        $display("\n--- Test 6: Seed=1010 generates unique sequence ---");
        apply_reset(4'b1010);
        enable      = 1;
        seen_mask   = 15'b0;
        unique_count= 0;

        if (rand_out != 4'b0000) begin
            seen_mask[rand_out - 1] = 1'b1;
            unique_count = unique_count + 1;
        end

        for (i = 0; i < 15; i = i + 1) begin
            @(posedge clk); #1;
            if (rand_out != 4'b0000 && !seen_mask[rand_out - 1]) begin
                seen_mask[rand_out - 1] = 1'b1;
                unique_count = unique_count + 1;
            end
        end

        check(7, unique_count === 15, "15 unique states from seed 1010");

        // ------------------------------------------------
        // Print the actual sequence for reference
        // ------------------------------------------------
        $display("\n--- Printing LFSR sequence from seed=0001 ---");
        apply_reset(4'b0001);
        enable = 1;
        $display("  Cycle  0 : %04b (%0d)", rand_out, rand_out);
        for (i = 1; i <= 15; i = i + 1) begin
            @(posedge clk); #1;
            $display("  Cycle %2d : %04b (%0d)", i, rand_out, rand_out);
        end

        // ------------------------------------------------
        // Summary
        // ------------------------------------------------
        $display("\n========================================");
        $display("  Results : %0d PASS  |  %0d FAIL", pass_cnt, fail_cnt);
        $display("========================================\n");

        if (fail_cnt == 0)
            $display("  ALL TESTS PASSED ✓\n");
        else
            $display("  SOME TESTS FAILED ✗ – check output above\n");

        $finish;
    end

    // ── Timeout watchdog ─────────────────────────────────────
    initial begin
        #10000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule
