
// Verilog stimulus file.
// Please do not create a module in this file.

/*
	COMP32111 - Implementing SoC designs
	Matt Walton c10360mw
*/

`define CMD_STAGE_INIT 	2'b00 	// Initial stage / rest stage, waiting for command to be sent
`define CMD_STAGE_REQ 	2'b01 	// request stage, req is high and waiting for ack
`define CMD_STAGE_RUN 	2'b10 	// ack received, command running

`define DRAW_STAGE_INIT 2'b00	// Initial drawing stage, waiting for de_req
`define DRAW_STAGE_ACK	2'b01	// req received, ack sent 


reg [1:0] cmd_stage, draw_stage;

reg [17:0] write_address;
reg [3:0] write_nbyte;
reg [8:0] write_data;

integer last_addr;
integer x, y, wx, wy;

reg memory_busy;
reg cmd_finished;
reg out_requested;

reg [32:0] frame_store [76800:0];
reg [7:0] expect_screen [639:0][479:0];
reg [7:0] screen [639:0][479:0];

wire [15:0] addr_x, addr_y;


initial cmd_stage = `CMD_STAGE_INIT; // set our initial states
initial draw_stage = `DRAW_STAGE_INIT;

// define our output defaults
initial
begin
	de_ack = 0;
	req = 0;

	memory_busy = 0;

	last_addr = 0;
	out_requested = 0;
end

// define our clock
initial clk = 0;
always #5 clk = ~clk;

initial de_r_data = {32{1'b0}};



always @ (posedge clk)
begin
	if (cmd_stage == `CMD_STAGE_REQ && ack) // 'ack' is high
	begin
		cmd_stage <= `CMD_STAGE_RUN;
		req <= 0; // req goes low to prevent unit firing again
	end

	if (cmd_stage == `CMD_STAGE_RUN && ack)
	begin
		$display("[%t] ERROR: ack was high for more than one clock cycle", $time);
		fail_test;
	end

	if (cmd_stage == `CMD_STAGE_RUN && de_req && ~memory_busy) // drawing interface req
	begin
		de_ack <= #1 1; // acknowledge request with a 1ns delay
		de_ack <= #11 0; // de_ack should be high for 1 clock cyc

		if (de_rnw)
		begin
			de_r_data <= #19 frame_store[de_addr];
		end
		else begin

			if ((~de_nbyte & 4'b1000) == 4'b1000) begin
				frame_store[de_addr][7:0] <= de_w_data[7:0];

			end

			if ((~de_nbyte & 4'b0100) == 4'b0100) begin
				frame_store[de_addr][15:8] <= de_w_data[15:8];

			end

			if ((~de_nbyte & 4'b0010) == 4'b0010) begin
				frame_store[de_addr][23:16] <= de_w_data[23:16];

			end

			if ((~de_nbyte & 4'b0001) == 4'b0001) begin
				frame_store[de_addr][31:24] <= de_w_data[31:24];

			end
		end
	
		last_addr = de_addr;

		// simulate the memory cycle taking 2 clock cycles
		memory_busy <= 1;
		memory_busy <= #19 0; 
	end
end


// Test to make sure the unit waits until an input request arrives before sending an ack
always @ (posedge ack)
begin
	if (cmd_stage == `CMD_STAGE_INIT)
	begin
		$display("[%t] ERROR: got ack before we sent a req", $time);
		fail_test;
	end

	if (cmd_stage == `CMD_STAGE_RUN)
	begin
		$display("[%t] ERROR: got a second ack for a single request", $time);
		fail_test;
	end
end 



always @ (posedge de_req)
begin
	if (cmd_stage == `CMD_STAGE_INIT)
	begin
		$display("[%t] ERROR: got de_req before we sent a req", $time);
		fail_test;
	end

	out_requested = 1;
end

always @ (posedge req)
begin
	#10000 // wait 10000ns for a de_req after a req, otherwise its a timeout
	if (!out_requested)
	begin
		$display("[%t] ERROR: timeout waiting for de_req!", $time);
		fail_test;
	end
end




initial 
begin
	// DEFINE TESTS HERE!

	draw_rect_test(1, 50, 50, 100, 100, 122, 122); // normal 100x100 square
	clear_screen;
	draw_rect_test(2, 0, 0, 640, 480, 122, 122); // full screen rectangle
	
	clear_screen;
	draw_rect_test(3, 1, 0, 5, 2, 122, 122); // word edge case
	clear_screen;
	draw_rect_test(4, 50, 0, 100, 1, 122, 122); // horizontal 1px height case
	clear_screen;

	clear_screen;
	draw_rect_test(5, 3, 50, 1, 1, 122, 122); // 1x1 square test case
	
	$stop;
end



integer c_last_addr;
integer fp, fp_scan;
integer ix, iy, icol;
reg the_same, testing;


task draw_rect_test(	input integer id,
			input [15:0] x, 
			input [15:0] y, 
			input [15:0] w, 
			input [15:0] h,
			input [7:0] color_and,
			input [7:0] color_xor );
begin

	$display("[%t] Running output test %03d", $time, id);
	
	// read into our 'expected screen'
	fp = $fopen($sformatf("tests/%0d_exp", id), "r");
	

	while (!$feof(fp))
	begin
		$fscanf(fp, "%03d %03d %3d", ix, iy, icol);
		expect_screen[ix][iy] = icol;
	end
	
	$fclose(fp);

	$display("[%t] Testing drawing rect from (%03d, %03d) of size (%03d, %03d) in color_and=%x, color_xor=%d", $time, x, y, w, h, color_and, color_xor);
	// set registers
	r0 = x;
	r1 = y;
	
	r2 = w;
	r3 = h;

	r4 = {color_and, color_xor};
	send_command;

	// calculate the last address that we should be writing to
	c_last_addr = ((y + h -1) * 160) + $floor( (x + w -1)/4);
	
	

	wait (busy == 1);
	wait (busy == 0);

	if (last_addr < c_last_addr)
	begin
		$display("[%t] ERROR: busy went low before command has finished", $time);
		//fail_test;
	end else begin
		$display("[%t] Draw finished", $time);
		testing = 0;
	end
	
	// now convert frame store to screen

	for (fp=0; fp<76800; fp = fp +1)
	begin
		ix = (fp * 4) % 640;
		iy = $floor(fp / 160);
		
		log_write(ix, iy, frame_store[fp][7:0]);
		log_write(ix+1, iy, frame_store[fp][15:8]);
		log_write(ix+2, iy, frame_store[fp][23:16]);
		log_write(ix+3, iy, frame_store[fp][31:24]);
	end

	// now we compare 'screen' with 'expected_screen', they -should- be the same!
	the_same = 1;

	for (ix=0; ix<640; ix = ix + 1)
	begin
		for (iy=0; iy<480; iy = iy + 1)
		begin
			if (screen[ix][iy] != expect_screen[ix][iy]) 
			begin
				$display("[%t] ERROR in test %03d output! (%03d, %03d) is not correct value (%03d) (expecting %03d)", $time, id, ix, iy, screen[ix][iy], expect_screen[ix][iy]);
				the_same = 0;
			end
		end
	end

	if (~the_same) fail_test; else $display("[%t] Passed output test %03d", $time, id);

	
		
end
endtask

task log_write(input integer x, input integer y, input [7:0] color);
begin
	//if (color != 0) $display("Wrote %x to (%d, %d)", color, x, y);
	screen[x][y] = color;

end
endtask



// Task to send a command with
task send_command();
begin
	cmd_finished = 0;
	// set req high & wait for ack
	req = 1;
	cmd_stage = `CMD_STAGE_REQ;

	//#200 // check that we've received an ack before 200ns
	//if (cmd_stage == `CMD_STAGE_REQ)
end
endtask

integer cx, cy, fs;


task clear_screen();
begin
	for (cx=0; cx<640; cx = cx + 1)
	begin
		for (cy=0; cy<480; cy = cy + 1) begin
			screen[cx][cy] = 0;
			expect_screen[cx][cy] = 0;
		end
	end

	for (fs=0; fs<76800; fs = fs + 1) frame_store[fs] = 0;
end
endtask


task fail_test;
begin
	$display("[%t] Testing failed! see log for errors", $time);	
	$stop;
end
endtask



