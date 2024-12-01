`include "config.svh"

// Memory parameters
`define ROM_ADDRESS_WIDTH 8  // 256 instructions
`define RAM_ADDRESS_WIDTH 8  // 256 words of RAM
`define DATA_WIDTH 32

module lab_top # (
    parameter clk_mhz = 50, w_key = 4, w_sw = 8, w_led = 8, w_digit = 8, w_gpio = 100,
    screen_width = 480, screen_height = 272,
    w_red = 4, w_green = 4, w_blue = 4,
    w_x = $clog2(screen_width), w_y = $clog2(screen_height)
) (
    input clk, input slow_clk, input rst,
    input [w_key - 1:0] key,
    input [w_sw - 1:0] sw,
    output logic [w_led - 1:0] led,
    output logic [7:0] abcdefgh,
    output logic [w_digit - 1:0] digit,
    input [w_x - 1:0] x,
    input [w_y - 1:0] y,
    output logic [w_red - 1:0] red,
    output logic [w_green - 1:0] green,
    output logic [w_blue - 1:0] blue,
    input [23:0] mic,
    output [15:0] sound,
    input uart_rx,
    output uart_tx,
    inout [w_gpio - 1:0] gpio
);

    // CPU signals
    wire [31:0] cpu_address;
    wire [31:0] cpu_data_out;
    wire [31:0] cpu_data_in;
    wire cpu_write_enable;
    wire cpu_read_enable;

    // Memory signals
    wire [31:0] rom_data;
    wire [31:0] ram_data;
    
    // Memory map decoder
    wire select_ram = cpu_address[31:28] == 4'h0;
    wire select_periph = cpu_address[31:28] == 4'h1;
    
    // Simple RISC-V CPU instance
    riscv_cpu cpu (
        .clk(slow_clk),
        .rst(rst),
        .instr_data(rom_data),
        .data_in(cpu_data_in),
        .data_out(cpu_data_out),
        .address(cpu_address),
        .write_enable(cpu_write_enable),
        .read_enable(cpu_read_enable)
    );

    // ROM for program storage
    program_rom #(
        .ADDRESS_WIDTH(`ROM_ADDRESS_WIDTH),
        .DATA_WIDTH(`DATA_WIDTH)
    ) rom (
        .clk(slow_clk),
        .address(cpu_address[`ROM_ADDRESS_WIDTH-1:0]),
        .data_out(rom_data)
    );

    // RAM for data storage
    ram_memory #(
        .ADDRESS_WIDTH(`RAM_ADDRESS_WIDTH),
        .DATA_WIDTH(`DATA_WIDTH)
    ) ram (
        .clk(slow_clk),
        .write_enable(cpu_write_enable & select_ram),
        .address(cpu_address[`RAM_ADDRESS_WIDTH-1:0]),
        .data_in(cpu_data_out),
        .data_out(ram_data)
    );

    // Original circle drawing logic
    localparam CIRCLE_RADIUS = 150;
    localparam CENTER_X = screen_width/2;
    localparam CENTER_Y = screen_height/2;

    function automatic int square;
        input int value;
        square = value * value;
    endfunction

    wire [31:0] distance_squared = square(x - CENTER_X) + square(y - CENTER_Y);

    // Modified to allow CPU control of circle color
    reg [3:0] cpu_red, cpu_green, cpu_blue;
    
    always_comb begin
        red = 0;
        green = 0;
        blue = 0;

        if (distance_squared <= square(CIRCLE_RADIUS)) begin
            red = cpu_red;
            green = cpu_green;
            blue = cpu_blue;
        end
    end

    // Peripheral handling (mapped to 0x1xxxxxxx address range)
    always_ff @(posedge slow_clk) begin
        if (rst) begin
            cpu_red <= 4'hF;
            cpu_green <= 4'hF;
            cpu_blue <= 4'hF;
        end else if (cpu_write_enable && select_periph) begin
            case (cpu_address[7:0])
                8'h00: cpu_red <= cpu_data_out[3:0];
                8'h04: cpu_green <= cpu_data_out[3:0];
                8'h08: cpu_blue <= cpu_data_out[3:0];
            endcase
        end
    end

    // Memory read multiplexer
    assign cpu_data_in = select_ram ? ram_data : 32'h0;

    // Connect some LEDs to CPU activity
    assign led = {cpu_write_enable, cpu_read_enable, cpu_red[1:0], cpu_green[1:0], cpu_blue[1:0]};

    // Seven segment display shows lower 16 bits of CPU address
    seven_segment_display #(w_digit) i_7segment (
        .clk(clk),
        .rst(rst),
        .number(cpu_address[15:0]),
        .dots(4'b0000),
        .abcdefgh(abcdefgh),
        .digit(digit)
    );

    // Unused outputs
    assign sound = '0;
    assign uart_tx = '1;

endmodule

module riscv_cpu (
    input wire clk,
    input wire rst,
    input wire [31:0] instr_data,
    input wire [31:0] data_in,
    output reg [31:0] data_out,
    output reg [31:0] address,
    output reg write_enable,
    output reg read_enable
);
    // CPU registers
    reg [31:0] registers [31:0];
    reg [31:0] pc;
    
    // Instruction decode
    wire [6:0] opcode = instr_data[6:0];
    wire [4:0] rd = instr_data[11:7];
    wire [4:0] rs1 = instr_data[19:15];
    wire [4:0] rs2 = instr_data[24:20];
    
    // Immediate value decode for different instruction types
    wire [31:0] imm_i = {{20{instr_data[31]}}, instr_data[31:20]};
    
    // JAL immediate decode
    wire [20:0] jal_imm = {
        instr_data[31],    // imm[20]
        instr_data[19:12], // imm[19:12]
        instr_data[20],    // imm[11]
        instr_data[30:21]  // imm[10:1]
    };
    // Sign extend and shift left 1 bit for byte addressing
    wire [31:0] jump_offset = {{11{jal_imm[20]}}, jal_imm} << 1;
    
    // State machine
    reg [1:0] state;
    localparam FETCH = 2'b00;
    localparam EXECUTE = 2'b01;
    localparam MEMORY = 2'b10;
    localparam WRITEBACK = 2'b11;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 32'h0;
            state <= FETCH;
            write_enable <= 0;
            read_enable <= 0;
            // Initialize registers
            for (int i = 0; i < 32; i = i + 1)
                registers[i] <= 32'h0;
        end else begin
            case (state)
                FETCH: begin
                    address <= pc;
                    read_enable <= 1;
                    write_enable <= 0;
                    state <= EXECUTE;
                end
                
                EXECUTE: begin
                    case (opcode)
                        7'b0110011: begin // R-type
                            case (instr_data[14:12])
                                3'b000: registers[rd] <= registers[rs1] + registers[rs2]; // ADD
                            endcase
                            pc <= pc + 4;
                        end
                        
                        7'b0010011: begin // I-type
                            case (instr_data[14:12])
                                3'b000: registers[rd] <= registers[rs1] + imm_i; // ADDI
                            endcase
                            pc <= pc + 4;
                        end
                        
                        7'b0100011: begin // S-type (store)
                            address <= registers[rs1] + imm_i;
                            data_out <= registers[rs2];
                            write_enable <= 1;
                            state <= MEMORY;
                            pc <= pc + 4;
                        end
                        
                        7'b1101111: begin // JAL
                            // Save return address if rd != 0
                            if (rd != 0)
                                registers[rd] <= pc + 4;
                            // Calculate next PC
                            pc <= pc + jump_offset;
                        end
                    endcase
                    
                    if (opcode != 7'b0100011) // If not store
                        state <= FETCH;
                end
                
                MEMORY: begin
                    write_enable <= 0;
                    state <= FETCH;
                end
            endcase
        end
    end
endmodule

// ROM module for program storage
module program_rom #(
    parameter ADDRESS_WIDTH = 8,
    parameter DATA_WIDTH = 32
) (
    input wire clk,
    input wire [ADDRESS_WIDTH-1:0] address,
    output reg [DATA_WIDTH-1:0] data_out
);
    // ROM storage
    reg [DATA_WIDTH-1:0] rom [0:(2**ADDRESS_WIDTH)-1];
    
    initial begin
        // Test program: Change circle colors
        // All values are in hex
        rom[0] = 32'h00100093;  // addi x1, x0, 1    # x1 = 1
        rom[1] = 32'h00f00113;  // addi x2, x0, 15   # x2 = 15 (max color value)
        rom[2] = 32'h10000237;  // lui x4, 0x10000   # x4 = 0x10000000 (peripheral base)
        // Main loop
        rom[3] = 32'h00222023;  // sw x2, 0(x4)      # Set red
        rom[4] = 32'h00022223;  // sw x0, 4(x4)      # Clear green
        rom[5] = 32'h00022423;  // sw x0, 8(x4)      # Clear blue
        rom[6] = 32'h00000013;  // nop (delay)
        rom[7] = 32'h00022023;  // sw x0, 0(x4)      # Clear red
        rom[8] = 32'h00222223;  // sw x2, 4(x4)      # Set green
        rom[9] = 32'h00022423;  // sw x0, 8(x4)      # Clear blue
        rom[10] = 32'h00000013; // nop (delay)
        rom[11] = 32'h00022023; // sw x0, 0(x4)      # Clear red
        rom[12] = 32'h00022223; // sw x0, 4(x4)      # Clear green
        rom[13] = 32'h00222423; // sw x2, 8(x4)      # Set blue
        rom[14] = 32'h00000013; // nop (delay)
        rom[15] = 32'hfedff06f; // j -20             # Jump back to start of color cycle
    end
    
    always @(posedge clk) begin
        data_out <= rom[address];
    end
endmodule

// RAM module for data storage
module ram_memory #(
    parameter ADDRESS_WIDTH = 8,
    parameter DATA_WIDTH = 32
) (
    input wire clk,
    input wire write_enable,
    input wire [ADDRESS_WIDTH-1:0] address,
    input wire [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out
);
    reg [DATA_WIDTH-1:0] ram [0:(2**ADDRESS_WIDTH)-1];
    
    always @(posedge clk) begin
        if (write_enable)
            ram[address] <= data_in;
        data_out <= ram[address];
    end
endmodule