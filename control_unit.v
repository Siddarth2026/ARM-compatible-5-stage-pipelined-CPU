module control_unit( 
    input [7:0] inst27_20,
    output reg regDst,
    output reg [1:0] aluOp,
    output reg aluSrc,
    output reg branch,
    output reg memWrite,
    output reg regWrite,
    output reg memtoReg,
    //CMD: for R-type instructions, cmd[4:1] is the opcode, cmd[0] is S bit, 
	 //for LDR and STR instructions, cmd[4] is P bit, cmd[3] is U bit, cmd[2] is B bit, cmd[1] is W bit
    output [4:0] cmd
);

wire [1:0] type = inst27_20[7:6];
// 00 -> R type
// 01 -> LDR/STR, L = 1 for LDR and L = 0 for STR
wire imm = inst27_20[5];
// 101 -> branch
assign cmd = inst27_20[4:0]; // for r type -> aluctrl(4 bits)+ S(set NVZC flag) // for ldr/str // PUBWL
// cmd[4] -> L for branch 

// 3'b000	R type  
// 3'b001	R type Immediate
// 3'b010	LDR / STR
// 3'b101	Branch

always @(*) begin
    case(type) 
        2'b00: begin // rtype 
            regDst = 1;
            aluOp = 2'b10;
            aluSrc = (imm == 1)? 1 : 0;
            branch = 0;
            memWrite = 0;
            regWrite = 1;
            memtoReg = 0;
        end
        2'b01: begin //ldr(cmd[4](l) = 1) and str(cmd[4](l) = 1)
        // for LDR and STR instructions, the opcode is determined by cmd[4:1], the flags are not updated for LDR and STR instructions
		  // for LDR instruction, the result is written back to register
		  //for STR instruction, the result is not written back to register, the second operand is either register or immediate, if imm is 1, the second operand is immediate, otherwise it is register
            regDst = (cmd[0] == 1)? 1 : 0;
            aluOp = 2'b00;
            aluSrc = 1;
            branch = 0;
            memWrite = (cmd[0] == 1)? 0 : 1;
            regWrite = (cmd[0] == 1)? 1 : 0;
            memtoReg = (cmd[0] == 1)? 1 : 0;
        end
    endcase
	 begin
    if (({type,imm} == 3'b101) && (cmd[4] == 0)) begin //branch
        regDst = 0;
        aluOp = 2'b01;
        aluSrc = 0;
        branch = 1;
        memWrite = 0;
        regWrite = 0;
        memtoReg = 0;
    end

end
end
endmodule
    