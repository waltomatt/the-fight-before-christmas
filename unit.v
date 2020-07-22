`define S_IDLE 		0
`define	S_C_ACK 	1
`define S_DR_REQ 	2
`define S_DR_ACK 	3
`define S_DR_DATA 	4
`define S_DW_REQ	5
`define S_DW_ACK	6

module drawing_rectangle( input  wire        clk,
                      input  wire        req,
                      output wire         ack,
                      output wire        busy,
                      input  wire [15:0] r0, // X
                      input  wire [15:0] r1, // Y
                      input  wire [15:0] r2, // W
                      input  wire [15:0] r3, // H
                      input  wire [15:0] r4, // colour
                      input  wire [15:0] r5,
                      input  wire [15:0] r6,
                      input  wire [15:0] r7,
                      output wire        de_req,
                      input  wire        de_ack,
                      output reg [17:0] de_addr,
                      output reg  [3:0] de_nbyte,
                      output wire        de_rnw,
                      output reg [31:0] de_w_data,
                      input  wire [31:0] de_r_data );

// FSM state
reg [3:0] state;
reg [15:0] cur_y;
reg [15:0] end_y;

reg [17:0] word_startln;
reg [17:0] word_endln;

reg [7:0] color_and, color_xor;
reg [3:0] nbyte_start, nbyte_end;

wire [15:0] start_x, end_x, width, height, color;
wire [31:0] x_color_and, x_color_xor;

reg [31:0] buffer;

// Combinatorial logic

assign ack = (state == `S_C_ACK);
assign busy = (state > `S_IDLE);
assign de_req = (state == `S_DR_REQ || state == `S_DW_REQ);
assign de_rnw = (state < `S_DW_REQ);

assign x_color_and = {color_and, color_and, color_and, color_and};
assign x_color_xor = {color_xor, color_xor, color_xor, color_xor};


initial 
begin
	state = `S_IDLE;

end



always @ (posedge clk) // Latch our data
begin
	if (state == `S_DR_DATA)
	begin
		de_w_data <= (de_r_data & x_color_and) ^ x_color_xor;

	end	
end

/*
	FSM!!
*/

always @ (posedge clk)
begin
	case(state)
		`S_IDLE: if (req) state <= `S_C_ACK;
		`S_C_ACK: begin
			state <= `S_DR_REQ;

			// calculate the first address, which will be the same as our word_startln reg
			de_addr <= (((r1 << 9) + (r1 << 7) + r0) >> 2);

			// we calculate the first & last words of each line, as this is a rectangle
			word_startln <= (((r1 << 9) + (r1 << 7) + r0) >> 2);
			word_endln <= (((r1 << 9) + (r1 << 7) + r0) >> 2) + (r2 >> 2);
	
			// keep track of our y values so we know when to stop
			cur_y <= r1;
			end_y <= r1 + r3 - 1; 

			// set our color regs
			color_and <= ((r4 >> 8) & 8'hFF); // left 8 bits 
			color_xor <= (r4 & 8'hFF);	// right 8 bits

			// the nbyte will be 0000 unless we're at the start/end of a line
			// using some bitshifting to work out which bits we need for line start/end

			nbyte_start <= ~(4'b1111 >> (r0 - ((r0 >> 2) << 2)));
			nbyte_end <= (4'b1111 >> ((r0 + r2) - (((r0 + r2) >> 2) << 2)));

			de_nbyte <= ~(4'b1111 >> (r0 - ((r0 >> 2) << 2)));
		end

		`S_DR_REQ: if (de_ack) state <= `S_DR_ACK;
		`S_DR_ACK: state <= `S_DR_DATA;
		`S_DR_DATA: state <= `S_DW_REQ;
		`S_DW_REQ: if (de_ack) state <= `S_DW_ACK;

		`S_DW_ACK: begin
			

			// Finished this line, so move onto the next
			if (de_addr == word_endln) begin
				// We've finished drawing!
				if (cur_y == end_y) state <= `S_IDLE; else

				begin
					// Move onto the next line
					cur_y <= cur_y + 1;

					// the new start + end ln words will just be what they were before + the width of the screen in words
					de_addr <= (word_startln + 160);
					word_startln <= word_startln + 160;
					word_endln <= word_endln + 160;

					de_nbyte <= nbyte_start;

					state <= `S_DR_REQ;
				end		
			
			end else
 begin
				// On the last word of the line, so set de_nbyte to our nbyte_end value
				if (de_addr + 1 == word_endln)
					de_nbyte <= nbyte_end;
				else
					de_nbyte <= 4'b0000; // else, the nbyte will just be 0000 (all bytes)

				// Move onto the next word & go back to S_DR_REQ
				de_addr <= de_addr + 1;
				state <= `S_DR_REQ;
			end
		end
	endcase
end 

endmodule
