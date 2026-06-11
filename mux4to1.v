`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:54:05 06/03/2026 
// Design Name: 
// Module Name:    mux4to1 
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
module mux4to1(
    input [31:0] pc1,
    input [31:0] pc2,
    input [31:0] pc3,
    input [31:0] pc4,
    input [1:0] select,
    output reg [31:0] pc
    );
always@(*)
begin
case (select):
2'b00:pc=pc1;
2'b01:pc=pc2;
2'b10:pc=pc3;
2'b11:pc=pc4;
endcase

end
endmodule
