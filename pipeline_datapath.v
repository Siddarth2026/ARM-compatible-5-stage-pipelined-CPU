`timescale 1ns / 1ps
module pipeline_datapath(
    input clk,
    input rst,
	 input pc_enable,
    output [31:0] debug_pc,
    output [63:0] debug_reg0,
    output [63:0] debug_reg1,
    output [31:0] debug_instruction,
	 input [8:0] addressB,
	 input [7:0]instruction_address,
	 input [31:0]instruction,
	 input instruction_write,
	 output [63:0] memorydata
);
//============================================================================
//  PC and Instruction memory - Srage 1
//============================================================================
wire [31:0] pc;
reg branch_stage3;
wire [31:0] branch_addr;
reg [31:0]branch_addr_stage3;
wire stall;



//Program Counter
program_counter pc_inst1(.clk(clk),.reset(rst),.branch(branch_taken),.branch_addr(branch_addr),.pc(pc), .pc_stall(stall),.pc_enable(pc_enable));




wire [7:0]addra=pc[9:2];
assign debug_pc = pc;
wire [31:0] instruction_r;
reg [31:0] instruction_stage2;

//Instruction memory
imem1 imem1 (
    .clka(clk),                    
    .addra(addra),              
    .douta(instruction_r),
	 .clkb(clk),
	 .web(instruction_write),
	 .addrb(instruction_address),
	 .dinb(instruction),
	 .ena(~(stall))
);
assign debug_instruction = instruction;
//============================================================================
//  PIPELINE DELAY REGISTER 1 (Stage 1 to 2)
//============================================================================
always@(posedge clk)
begin
if(rst|branch_taken)
instruction_stage2<=32'h0;
else begin 
if(stall)
instruction_stage2<=instruction_stage2;
else
instruction_stage2<=instruction_r;
end
end
////============================================================================
//  Control Unit - Stage 2
//============================================================================

// control  unit 
// instruction fields
wire [3:0] inst_cond = instruction_stage2[31:28]; //Condition Bits
// opcode is bits 27-20
wire [7:0] inst_cu = instruction_stage2[27:20]; //Opcode Bits
// register addresses
wire [3:0] wreg_addr_stage2 = instruction_stage2[15:12];
wire [3:0] reg1_addr_stage2;
wire [3:0] reg2_addr_stage2;

//Control signals
wire [1:0] aluOp;
wire aluSrc;
wire branch;
wire memWrite;
wire regWrite;
wire memtoReg;
wire [4:0] cmd;
wire regDst;

control_unit cu_inst(
    .inst27_20(inst_cu),
    .regDst(regDst),
    .aluOp(aluOp),
    .aluSrc(aluSrc),
    .branch(branch),
    .memWrite(memWrite),
    .regWrite(regWrite),
    .memtoReg(memtoReg),
    .cmd(cmd)
);

wire set=instruction_stage2[20];
wire [3:0] nzcv_flags_ALU; 
wire [3:0] nzcv_flags_reg;
reg condition_met;
assign nzcv_flags_reg = nzcv_flags_ALU; // Update the registered NZCV flags with the latest ALU output flags at the end of each cycle
always@(*)
case(inst_cond)
    //NZCV
    4'b0000: condition_met = (nzcv_flags_ALU[2]==1'b1)?1:0; // EQ: Z=1
    4'b0001: condition_met = (nzcv_flags_ALU[2]==1'b0)?1:0; // NE: Z=0
    4'b0010: condition_met = (nzcv_flags_ALU[1]==1'b1)?1:0; // CS/HS: C=1
    4'b0011: condition_met = (nzcv_flags_ALU[1]==1'b0)?1:0; // CC/LO: C=0
    4'b0100: condition_met = (nzcv_flags_ALU[3]==1'b1)?1:0; // MI: N=1
    4'b0101: condition_met = (nzcv_flags_ALU[3]==1'b0)?1:0; // PL: N=0
    4'b0110: condition_met = (nzcv_flags_ALU[0]==1'b1)?1:0; // VS: V=1
    4'b0111: condition_met = (nzcv_flags_ALU[0]==1'b0)?1:0; // VC: V=0
    4'b1000: condition_met = (nzcv_flags_ALU[1]==1'b1 && nzcv_flags_ALU[2]==1'b0)?1:0; // HI: C=1 and Z=0  
    4'b1001: condition_met = (nzcv_flags_ALU[1]==1'b0 || nzcv_flags_ALU[2]==1'b1)?1:0; // LS: C=0 or Z=1 
    4'b1010: condition_met = (nzcv_flags_ALU[0]==nzcv_flags_ALU[3])?1:0; // GE: N==V 
    4'b1011: condition_met = (nzcv_flags_ALU[0]!=nzcv_flags_ALU[3])?1:0; // LT: N!=V 
    4'b1100: condition_met = ((nzcv_flags_ALU[2]==1'b0) && (nzcv_flags_ALU[3]==nzcv_flags_ALU[0]))?1:0; // GT: Z=0 and N=V
    4'b1101: condition_met = ((nzcv_flags_ALU[2]==1'b1) || (nzcv_flags_ALU[3]!=nzcv_flags_ALU[0]))?1:0; // LE: Z=1 or N!=V
    4'b1110: condition_met = 1'b1; // AL (1110): always
    4'b1111: condition_met = 1'b0; // NV (1111): never
endcase
wire [1:0] type_stage2 = instruction_stage2[27:26];
wire [4:0] shft_amt = instruction_stage2[11:7];
wire [31:0] se_offset;
//If type is 2'b10, sign extend the 24-bit offset and shift left by 2, else for LW/SW, sign extend the 12-bit offset and shift left by 2 and Just sign extend for immediate value.
assign se_offset = (type_stage2 == 2'b10) ?
						 {{6{instruction_stage2[23]}}, instruction_stage2[23:0], 2'b00}:((type_stage2 == 2'b01)?
						 {{18{instruction_stage2[11]}}, instruction_stage2[11:0],2'b00}:{{20{instruction_stage2[11]}}, instruction_stage2[11:0]});


assign branch_addr = pc + 32'd0 + se_offset; //Due to imem latency, pc+offset instead of pc+4+offset
assign branch_taken = branch && condition_met;
//============================================================================
// Hazard Detection Unit
//============================================================================


reg regWrite_stage5;
reg [3:0] wreg_addr_stage4; 
reg [3:0] wreg_addr_stage3; 
reg regWrite_stage3;
reg regWrite_stage4;
reg memtoReg_stage3;
reg [3:0] wreg_addr_stage5;

HDU hdu(.wreg_addr_stage3(wreg_addr_stage3),.wreg_addr_stage4(wreg_addr_stage4),.wreg_addr_stage5(wreg_addr_stage5),
.reg1_addr_stage2(reg1_addr_stage2),.reg2_addr_stage2(reg2_addr_stage2),
.wregen_stage3(regWrite_stage3),.wregen_stage4(regWrite_stage4),.wregen_stage5(regWrite_stage5),.stall(stall),.control(memtoReg_stage3));


//============================================================================
// REGISTER FILE
//============================================================================


wire [63:0] reg1_data;  
wire [63:0] reg2_data;  


wire [63:0] wData_stage5;

// reg1 is bits 15-12, reg2 is bits 3-0
assign reg1_addr_stage2 = instruction_stage2[19:16];
// reg2_addr_stage2 is bits 3-0
assign reg2_addr_stage2 =(regDst == 1)?instruction_stage2[3:0]:instruction_stage2[15:12];

register_file regfile (
    .clk(clk),
    .rst(rst),                      
    .r0addr(reg1_addr_stage2),             
    .r1addr(reg2_addr_stage2),             
    .waddr(wreg_addr_stage5),       
    .wdata(wData_stage5),              
    .wena(regWrite_stage5),          
	 .pc(pc),
    .r0data(reg1_data),             
    .r1data(reg2_data)             
);


assign debug_reg0 = reg1_data;
assign debug_reg1 = reg2_data;

wire [63:0] reg1_data_update;

assign reg1_data_update = (cmd[4:1] == 4'b1101) ? {{59{1'b0}},shft_amt}: reg1_data;
//============================================================================
//  PIPELINE DELAY REGISTER 2 (Stage 2 to 3) ( To dummy)
//============================================================================


reg [3:0] reg1_addr_stage3;
reg [3:0] reg2_addr_stage3;
reg [63:0]reg1_data_stage3;
reg [63:0]reg2_data_stage3;
reg [31:0]se_offset_stage3;
reg [3:0] nzcv_flags_stage3;
// control signals 
reg [1:0] aluOp_stage3;
reg aluSrc_stage3;
reg memWrite_stage3;

reg [4:0] cmd_stage3;

// inst

always @(posedge clk) begin
    if (rst) begin
        wreg_addr_stage3 <= 4'b0;
		  reg1_addr_stage3 <= 4'b0;
        reg2_addr_stage3 <= 4'b0;
        reg1_data_stage3 <= 64'b0;
        reg2_data_stage3 <= 64'b0;
        branch_addr_stage3<=32'b0;
        se_offset_stage3<=32'b0;
        nzcv_flags_stage3 <= 4'b0;
        aluOp_stage3 <= 2'b0;
        aluSrc_stage3 <= 0;
        branch_stage3 <= 0;
        memWrite_stage3 <= 0;
        memtoReg_stage3 <= 0;
        regWrite_stage3 <= 0;
        cmd_stage3 <= 5'b0;
    end 
    else if (branch_stage3|stall) begin                          
        wreg_addr_stage3 <= 4'b0;
		  reg1_addr_stage3 <= 4'b0;
        reg2_addr_stage3 <= 4'b0;
        reg1_data_stage3 <= 64'b0;
        reg2_data_stage3 <= 64'b0;
        se_offset_stage3<=32'b0;
        nzcv_flags_stage3 <= 4'b0;
        aluOp_stage3 <= 2'b0;
        aluSrc_stage3 <= 0;
        branch_stage3 <= 0;
        memWrite_stage3 <= 0;
        memtoReg_stage3 <= 0;
        regWrite_stage3 <= 0;
        cmd_stage3 <= 5'b0;
    end
    else begin
        wreg_addr_stage3 <= wreg_addr_stage2;
		  reg1_addr_stage3 <= reg1_addr_stage2;
        reg2_addr_stage3 <= reg2_addr_stage2;
        reg1_data_stage3 <= reg1_data_update;
        reg2_data_stage3 <= reg2_data;
        branch_stage3<=branch_taken;
        branch_addr_stage3<=branch_addr;
        se_offset_stage3<=se_offset;
        aluOp_stage3 <= aluOp;
        aluSrc_stage3 <= aluSrc;
        memWrite_stage3 <= memWrite;
        memtoReg_stage3 <= memtoReg;
        regWrite_stage3 <= regWrite;
        cmd_stage3 <= cmd;
        nzcv_flags_stage3 <= nzcv_flags_reg;
    end
end
//============================================================================
//  Execution Stage - Stage 3
//============================================================================

wire [1:0]s1,s2;
reg [63:0] aludata_stage4;


FU fu(.reg1_addr_stage3(reg1_addr_stage3),
    .reg2_addr_stage3(reg2_addr_stage3),
	 .wreg_addr_stage4(wreg_addr_stage4),
    .wreg_addr_stage5(wreg_addr_stage5),
    .s1(s1),
    .s2(s2),
    .wregen_stage4(regWrite_stage4),
    .wregen_stage5(regWrite_stage5));
	 
	 
wire [63:0] reg1_data_stage3_fw,reg2_data_stage3_fw;

FMP fmp1(.regdata(reg1_data_stage3),
    .S1data(aludata_stage4),
    .S2data(wData_stage5),
    .select(s1),
	 .fmout(reg1_data_stage3_fw));

FMP fmp2(.regdata(reg2_data_stage3),
    .S1data(aludata_stage4),
    .S2data(wData_stage5),
    .select(s2),
	 .fmout(reg2_data_stage3_fw));


wire [63:0]ALU_leg1 = reg1_data_stage3_fw;
// if aluSrc is 1, ALU_leg2 is the sign-extended offset, else ALU_leg2 is reg2 data

wire [63:0]ALU_leg2 = aluSrc_stage3?({{32{se_offset_stage3[31]}},se_offset_stage3}):(reg2_data_stage3_fw);

wire [3:0]flagout;
// stored NZCV flags register: [3]=N [2]=Z [1]=C [0]=V, updated by S-bit instructions

wire [63:0] aludata;
wire [63:0] alu_base_writeback;

// A_next is the post-indexed base register writeback address for LDR/STR
//A-next = branch_addr_stage3 if branch, else A-next = A

ALU alu(.opcode_initial(cmd_stage3),.A(ALU_leg1),.B(ALU_leg2),.ALU_op(aluOp_stage3),.A_next(alu_base_writeback),.result(aludata),.flag_in(nzcv_flags_stage3),.flag_out(flagout));
assign nzcv_flags_ALU=flagout;

//============================================================================
//  PIPELINE DELAY REGISTER 3 (Stage 3 to 4)
//============================================================================


reg [63:0]reg1_data_stage4;
reg [63:0]reg2_data_stage4;

reg memWrite_stage4;
reg memtoReg_stage4;


always @(posedge clk) begin
    if (rst) begin
       wreg_addr_stage4 <= 4'b0;
	    reg1_data_stage4 <= 64'b0;
	    reg2_data_stage4 <= 64'b0;

    // control signals
        memWrite_stage4 <= 0;
        memtoReg_stage4 <= 0;
        regWrite_stage4 <= 0;

    // alu data
        aludata_stage4 <= 64'b0;
    end else begin
        wreg_addr_stage4 <= wreg_addr_stage3;
	    reg1_data_stage4 <= reg1_data_stage3_fw;
	    reg2_data_stage4 <= reg2_data_stage3_fw;

    // control signals
        memWrite_stage4 <= memWrite_stage3;
        memtoReg_stage4 <= memtoReg_stage3;
        regWrite_stage4 <= regWrite_stage3;

    // alu
        aludata_stage4 <= aludata;
    end
end

//============================================================================
// DATA MEMORY (DMEM)
//============================================================================
wire [63:0] dmemData;

dmem dmem1 (
    .clka(clk),                     // Port A clock
    .wea(memWrite_stage4),           // Write enable
    .addra(aludata_stage4[10:2]),         // Address from Register 1 (9 bits for 512 depth)
    .dina(reg2_data_stage4),               // Write data from Register 2
    .douta(dmemData),         // Read data output
    
    .clkb(clk),
    .addrb(addressB),
    .doutb(memorydata)                        
);

		

//============================================================================
//  PIPELINE DELAY REGISTER 4 (Stage 4 to 5)
//============================================================================
reg [63:0] dmemData_stage5;
reg [63:0] aludata_stage5;
reg memtoReg_stage5;
always @(posedge clk) begin               
    if (rst) begin
        wreg_addr_stage5 <= 4'b0;
        memtoReg_stage5 <= 0;
        regWrite_stage5 <= 0;
        aludata_stage5 <= 64'b0;

    end else begin
        wreg_addr_stage5 <= wreg_addr_stage4;
        memtoReg_stage5 <= memtoReg_stage4;
        regWrite_stage5 <= regWrite_stage4;
        aludata_stage5 <= aludata_stage4;
    end
end

//============================================================================
// 7. WRITEBACK - Memory output to Register File
//============================================================================
assign wData_stage5 =(memtoReg_stage5)?(dmemData):(aludata_stage5);
endmodule