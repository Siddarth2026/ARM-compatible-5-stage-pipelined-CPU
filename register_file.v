`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:45:36 02/12/2026 
// Design Name: 
// Module Name:    register_file 
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
module register_file(
    input clk,
    input rst,
    input [3:0] r0addr,
    input [3:0] r1addr,
    input [3:0] waddr,
    input [63:0] wdata,
    input wena,
	 input [31:0] pc,
    output [63:0] r0data,
    output [63:0] r1data
    );
    //16 registers, each 64 bits wide
	 reg [63:0] rf [15:0];

always @(posedge clk) begin
    if (rst) begin
        rf[0] <= 64'd0;
        rf[1] <= 64'd0;
        rf[2] <= 64'd0;
        rf[3] <= 64'd0;
        rf[4] <= 64'd0;
        rf[5] <= 64'd0;
        rf[6] <= 64'd0;
        rf[7] <= 64'd0;
		  rf[8] <= 64'd0;
        rf[9] <= 64'd0;
        rf[10] <= 64'd0;
        rf[11] <= 64'd0;
        rf[12] <= 64'h0;
        rf[13] <= 64'h400;
        rf[14] <= 64'd0;
        rf[15] <= 64'd0;
	end
	 else begin
			rf[15] <= {32'd0,pc}; //pc
			if (wena)
				rf[waddr] <= wdata;
	 end

end
    assign r0data = (wena&(waddr==r0addr))?wdata:rf[r0addr];
    assign r1data = (wena&(waddr==r1addr))?wdata:rf[r1addr];
	 

endmodule
