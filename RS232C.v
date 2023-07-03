module UART_RX
#(
	parameter BAUD_RATE = 115200,
  parameter CLK_FREQ = 50000000  // Assuming 50 MHz clock
)
(
  input wire       clk, 
  input wire       rst_n,
  input wire       rx,        // UART RX signal
  input wire       full,      // Signal indicating if FIFO is full
  output reg       w_en,      // Signal to write data to FIFO
  output reg [7:0] data_out   // 8-bit data to FIFO
);

  localparam IDLE  = 2'b00;   // State definitions
  localparam START = 2'b01;
  localparam DATA  = 2'b10;
  localparam STOP  = 2'b11;

  reg [31:0] baud_cnt = 0;    // Counter for baud rate
  reg [1:0] state     = IDLE; // State variable
  reg [3:0] bit_cnt   = 4'b0; // Bit counter


	/////////////////////////////////////////////////
	/// State Machine
	/////////////////////////////////////////////////
  
	always@(posedge clk or posedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (!rx && rx_prev) begin
            state <= START;
          end
        end
        START: begin
          if (baud_cnt == CLK_FREQ/(2*BAUD_RATE)) begin
            if (rx) begin
              state <= IDLE;
            end
						else begin
              state <= DATA;
            end
          end
        end
        DATA: begin
          if (baud_cnt == CLK_FREQ/BAUD_RATE) begin
            if (bit_cnt == 7) begin
              state <= STOP;
            end
          end
        end
        STOP: begin
          if (baud_cnt == CLK_FREQ/BAUD_RATE) begin
            state <= IDLE;
          end
        end
      endcase
    end
  end

	/////////////////////////////////////////////////
	/// baud counter 
	/////////////////////////////////////////////////

	always@(posedge clk or posedge rst_n) begin
    if (!rst_n) begin
      baud_cnt <= 0;
    end
		else begin
      case (state)
        IDLE: begin
          if (!rx && rx_prev) begin
            baud_cnt <= 0;
          end
        end
        default: begin
          baud_cnt <= baud_cnt + 1;
          if (baud_cnt == CLK_FREQ/BAUD_RATE) begin
            baud_cnt <= 0;
          end
        end
      endcase
    end
  end

	/////////////////////////////////////////////////
	/// write enable
	/////////////////////////////////////////////////

	always @(posedge clk or posedge rst_n) begin
    if (!rst_n) begin
      w_en <= 0;
    end else begin
      case (state)
        STOP: begin
          if (baud_cnt == CLK_FREQ/BAUD_RATE) begin
            if (!full) begin
              w_en <= 1;
            end
          end
        end
				default: begin
					w_en <= 0;
				end
      endcase
      if (state == IDLE) begin
        w_en <= 0;
      end
    end
  end
	
	/////////////////////////////////////////////////
	/// data out 
	/////////////////////////////////////////////////

	always @(posedge clk or posedge rst_n) begin
    if (!rst_n) begin
      data_out <= 0;
    end
		else begin
      case (state)
        DATA: begin
          if (baud_cnt == CLK_FREQ/BAUD_RATE) begin
            data_out[bit_cnt] <= rx;
          end
        end
      endcase
    end
  end

	/////////////////////////////////////////////////
	/// receive bit counter 
	/////////////////////////////////////////////////
	
	always @(posedge clk or posedge rst_n) begin
    if (!rst_n) begin
      bit_cnt <= 0;
    end else begin
      case (state)
        DATA: begin
          if (baud_cnt == CLK_FREQ/BAUD_RATE) begin
            if (bit_cnt != 7) begin
              bit_cnt <= bit_cnt + 1;
            end
          end
        end
        STOP: begin
          if (baud_cnt == CLK_FREQ/BAUD_RATE) begin
            bit_cnt <= 0;
          end
        end
      endcase
    end
  end

endmodule




module UART_TX
#(
  parameter BAUD_RATE = 115200,
  parameter CLK_FREQ = 50000000  // Assuming 50 MHz clock
)
(
  input wire clk,                 // Clock signal
  input wire rst_n,               // Reset signal
  input wire empty,               // Signal indicating if FIFO is empty
  output reg read_en,             // Signal to read data from FIFO
  input wire [7:0] data_in,       // 8-bit data from FIFO
  output reg tx                   // UART TX signal
);

  localparam IDLE = 2'b00;  // State definitions
  localparam START = 2'b01;
  localparam DATA = 2'b10;
  localparam STOP = 2'b11;

  reg [31:0] baud_cnt = 0;  // Counter for baud rate
  reg [1:0] state = IDLE;       // State variable
  reg [7:0] tx_data = 8'b0;     // Data to be transmitted
  reg [3:0] bit_cnt = 4'b0; // Bit counter

  always @(posedge clk or posedge rst_n) begin
    if (!rst_n) begin
      baud_cnt <= 0;
      state <= IDLE;
      tx <= 1;  // Idle state is high for UART
      read_en <= 0;  // Default to not reading from FIFO
    end else begin
      baud_cnt <= baud_cnt + 1;
      if (baud_cnt == CLK_FREQ/BAUD_RATE) begin
        baud_cnt <= 0;
        case (state)
          IDLE: begin
            if (!empty) begin
              read_en <= 1;  // Enable reading from FIFO
              tx_data <= data_in;
              state <= START;
            end else begin
              read_en <= 0;  // Disable reading from FIFO if it's empty
            end
          end
          START: begin
            read_en <= 0;  // Disable reading from FIFO
            tx <= 0;
            state <= DATA;
          end
          DATA: begin
            if (bit_cnt == 7) begin
              state <= STOP;
            end else begin
              bit_cnt <= bit_cnt + 1;
              tx <= tx_data[bit_cnt];
            end
          end
          STOP: begin
            tx <= 1;
            state <= IDLE;
          end
        endcase
      end
    end
  end
endmodule

`default_nettype wire
