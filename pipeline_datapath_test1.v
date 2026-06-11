`timescale 1ns / 1ps

module pipeline_datapath_test1;

    // Testbench signals
	 //Inputs
    reg clk;
    reg rst;
	 reg [8:0] addressB;
	 reg [7:0]instruction_address;
	 reg [31:0]instruction;
	 reg instruction_write;
	 reg pc_enable;
	 
	 //Outputs
    wire [31:0] debug_pc;
    wire [63:0] debug_reg0;
    wire [63:0] debug_reg1;
    wire [31:0] debug_instruction;
	 wire [63:0] memorydata;
	 
    pipeline_datapath uut (
        .clk(clk),
        .rst(rst),
		  .addressB(addressB),
        .debug_pc(debug_pc),
        .debug_reg0(debug_reg0),
        .debug_reg1(debug_reg1),
        .debug_instruction(debug_instruction),
		  .memorydata(memorydata),
		  .instruction_address(instruction_address),
		  .instruction(instruction),
		  .instruction_write(instruction_write),
		  .pc_enable(pc_enable)
    );

    // ============================================
    // Clock Generation
    // ============================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;   // 100MHz clock
    end

    // ============================================
    // Reset and Simulation Control
    // ============================================
    initial begin
        
        // Initialize reset
        rst = 1;
		  pc_enable=0;
        #10;
        rst = 0;
		  instruction_write=1'b1;
		  instruction_address=8'h0;
		  instruction=32'he320f000;
		  instruction_address=8'h1;
		  instruction=32'he320f000;
		  instruction_address=8'h2;
		  instruction=32'he320f000;
		  instruction_address=8'h3;
		  instruction=32'he3a01001;
		  #10
		  instruction_address=8'h4;
		  instruction=32'he3a02002;
		  #10
		  instruction_address=8'h5;
		  instruction=32'he3a03003;
		  #10
		  instruction_address=8'h6;
		  instruction=32'he3a04004;
		  #10
		  instruction_address=8'h7;
		  instruction=32'he3a05005;
		  #10
		  instruction_address=8'h8;
		  instruction=32'he0816002;
		  #10
		  instruction_address=8'h9;
		  instruction=32'he0837004;
		  #10
		  instruction_address=8'ha;
		  instruction=32'he0868007;
		  #10
		  instruction_address=8'hb;
		  instruction=32'he4808001;
		  #10
		  instruction_address=8'hc;
		  instruction=32'he4909001;
		  #10
		  instruction_address=8'hd;
		  instruction=32'he0890005;
		  #10
		  instruction_address=8'he;
		  instruction=32'he1580009;
		  #10
		  instruction_address=8'hf;
		  instruction=32'h0afffffa;
		  #10
		  instruction_address=8'h10;
		  instruction=32'he320f000;
		  #10
		  instruction_address=8'h11;
		  instruction=32'he320f000;
		  instruction_write=1'b0;
		  #10
		  pc_enable=1;
		  //Start
    end

  

endmodule
