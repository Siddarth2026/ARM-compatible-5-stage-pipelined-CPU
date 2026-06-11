`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/18/2026 02:25:57 PM
// Design Name: 
// Module Name: ALU
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module ALU(opcode_initial,A,B,ALU_op,A_next,result,flag_in,flag_out);   
//opcode_initial[4:1] is the opcode, opcode_initial[0] is S bit for R type
input [4:0] opcode_initial;
input [63:0]A,B;
output reg [63:0]A_next;
//ALU_op: 00 for LDR STR, 01 for I-type, 10 for R-type
input [1:0] ALU_op;
//result is the output of ALU, which will be written back to register or for memory address
output reg [63:0] result;
//flag_in is the input flag for ADC and SBC, flag_out is the output flag for TST, TEQ, CMP and CMN
input [3:0]flag_in;
//flag_out[0] is N flag, flag_out[2] is Z flag, flag_out[1] is C flag, flag_out[3] is V flag
output reg [3:0]flag_out;
reg [64:0] temp;
//N is negative flag, Z is zero flag, C is carry flag, V is overflow flag
reg N,Z,C,V;
reg [63:0]offset_addr;
//opcode[3:0] is the opcode, opcode[0] is S bit
wire [3:0]opcode=opcode_initial[4:1];
wire S=opcode_initial[0];
always@(*)
begin
if(ALU_op==2'b10) //R type
begin
case(opcode)
4'b0000: result=A&B;//AND
4'b0001: result=A^B;//XOR
//SUB vs RSUB: SUB is A-B, RSUB is B-A, the flags are different for these two instructions
4'b0010: begin temp={1'b0,A}-{1'b0,B}; result=temp[63:0]; if(S) begin N=result[63]; Z=(result==64'h0);C=~temp[64]; V=((A[63]!==B[63])&&(result[63]!==A[63])); end end  //SUB
4'b0011: begin temp={1'b0,B}-{1'b0,A}; result=temp[63:0];if(S) begin N=result[63]; Z=(result==64'h0);C=~temp[64]; V=((A[63]!==B[63])&&(result[63]!==B[63]));end end//RSUB
//ADD VS ADC: ADD is A+B, ADC is A+B+carry_in, the flags are different for these two instructions
4'b0100: begin temp={1'b0,A}+{1'b0,B}; result=temp[63:0]; if(S) begin N=result[63]; Z=(result==64'h0); C=temp[64]; V=((A[63]==B[63])&&(result[63]!==A[63])); end end  //ADD
4'b0101: begin temp={1'b0,A}+{1'b0,B}+flag_in[1]; result=temp[63:0]; if(S) begin N=result[63]; Z=(result==64'h0); C=temp[64]; V=((A[63]==B[63])&&(result[63]!==A[63])); end end//ADDC
//ADC vs SBC: ADC is A+B+carry_in, SBC is A-B-carry_in, the flags are different for these two instructions
4'b0110: begin temp={1'b0,A}-{1'b0,B}-(~flag_in[1]); result=temp[63:0]; if(S) begin N=result[63]; Z=(result==64'h0); C=temp[64]; V=((A[63]!==B[63])&&(result[63]!==A[63])); end end //SUBC
//SUBC VS RSUBC: SUBC is A-B-carry_in, RSUBC is B-A-carry_in, the flags are different for these two instructions
4'b0111: begin temp={1'b0,B}-{1'b0,A}-(~flag_in[1]); result=temp[63:0]; if(S) begin N=result[63]; Z=(result==64'h0); C=temp[64]; V=((A[63]!==B[63])&&(result[63]!==B[63])); end end  //RSUBC
//TST, TEQ, CMP and CMN are used to update the flags, the result is not written back to register or memory
4'b1000: begin result=A&B; N=result[63]; Z=(result==64'b0); C=1'b0; V=1'b0; end// TST
4'b1001: begin result=A^B; N=result[63]; Z=(result==64'b0); C=1'b0; V=1'b0; end// TEQ
//CMP and CMN are similar to SUB and ADD, but they only update the flags, the result is not written back to register or memory
4'b1010: begin temp={1'b0,A}-{1'b0,B}; result=A; N=temp[63]; Z=(temp==64'b0); C=temp[64]; V=((A[63]!==B[63])&&(temp[63]!==A[63])); end //CMP
4'b1011: begin temp={1'b0,A}+{1'b0,B}; result=A; N=temp[63]; Z=(temp==64'b0); C=temp[64]; V=((A[63]==B[63])&&(temp[63]!==A[63])); end  // CMN
4'b1100: result=A|B; //OR
//LSL and MOV: flags are updated based on the result of the shift operation, the carry flag is updated based on the last bit shifted out, the overflow flag is updated based on the last bit shifted out and the original value of A
4'b1101: begin temp =B << A; result=temp[63:0]; if(S) begin N=result[63]; Z=(result==64'h0); C=temp[64]; V=((A[63]!==temp[63])&&(result[63]!==A[63])); end end//LSL
4'b1110: result=A&(~B); //BIC
4'b1111: result=~A; //INV
endcase
flag_out[3]=N;
flag_out[2]=Z;
flag_out[1]=C;
flag_out[0]=V;
end
else if (ALU_op==2'b00) //LDR STR
//U BIT: is used to determine whether the offset address is added to the base address or subtracted from the base address, if U bit is 1, the offset address is added to the base address, otherwise it is subtracted from the base address
//B BIT: is used to determine whether the data transfer is byte or word, if B bit is 1, the data transfer is byte, otherwise it is word
//P BIT: is used to determine whether the offset address is written back to register or not, if P bit is 1, the offset address is written back to register, otherwise it is not written back to register
//W BIT: is used to determine whether the offset address is written back to register or not, but W bit is only used for STR instruction, for LDR instruction, the offset address is always written back to register
//L BIT: is used to determine whether the instruction is LDR or STR, if L bit is 1, the instruction is LDR, otherwise it is STR
begin
//opcode[3]=P opcode[2]=U opcode[1]=B opcode[0]=W
if(opcode[2])
offset_addr=A+B;
else
offset_addr=A-B;
if(opcode[3])
begin
result=offset_addr;
if(opcode[0])
A_next=offset_addr;
else
A_next=A;
end
else
begin
result=A;
A_next=offset_addr;
end
end
end
endmodule

