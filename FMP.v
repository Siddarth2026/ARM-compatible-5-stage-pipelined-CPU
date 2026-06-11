`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:56:48 05/23/2026 
// Design Name: 
// Module Name:    FMP 
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
module FMP(
    input [63:0] regdata,
    input [63:0] S1data,
    input [63:0] S2data,
    input [1:0] select,
    output reg [63:0] fmout
    );
	 
always@(*)
begin
case(select)
2'b00: fmout=regdata;
2'b01: fmout=S1data;
2'b10: fmout=S2data;
2'b11: fmout=regdata; //default
endcase
end

endmodule
