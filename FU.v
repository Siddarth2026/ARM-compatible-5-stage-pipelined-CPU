`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    23:35:31 05/22/2026 
// Design Name: 
// Module Name:    FU 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module FU(
    input [3:0] reg1_addr_stage3,
    input [3:0] reg2_addr_stage3,
    input [3:0] wreg_addr_stage4,
    input [3:0] wreg_addr_stage5,
    output reg [1:0] s1,
    output reg [1:0] s2,
    input wregen_stage4,
    input wregen_stage5
    );

//Forwarding mux-1
always@(*)
begin
if((wreg_addr_stage4==reg1_addr_stage3)&&wregen_stage4)
s1=2'b01;
else if ((wreg_addr_stage5==reg1_addr_stage3)&&wregen_stage5)
s1=2'b10;
else
s1=2'b00;

//Forwarding mux-2
if((wreg_addr_stage4==reg2_addr_stage3)&&wregen_stage4)
s2=2'b01;
else if ((wreg_addr_stage5==reg2_addr_stage3)&&wregen_stage5)
s2=2'b10;
else
s2=2'b00;
end

endmodule
