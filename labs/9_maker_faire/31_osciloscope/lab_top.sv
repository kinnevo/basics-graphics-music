`include "config.svh"

module lab_top
# (
    parameter  clk_mhz       = 50,
               w_key         = 4,
               w_sw          = 8,
               w_led         = 8,
               w_digit       = 8,
               w_gpio        = 100,

               screen_width  = 480,
               screen_height = 272,

               w_red         = 4,
               w_green       = 4,
               w_blue        = 4,

               w_x           = $clog2 ( screen_width  ),
               w_y           = $clog2 ( screen_height ),
               
               BUFFER_SIZE   = 480,   // One point per x-pixel
               LINE_WIDTH    = 5      // Width of the waveform line
)
(
    input                        clk,
    input                        slow_clk,
    input                        rst,

    input        [w_key   - 1:0] key,
    input        [w_sw    - 1:0] sw,
    output logic [w_led   - 1:0] led,

    output logic [          7:0] abcdefgh,
    output logic [w_digit - 1:0] digit,

    input        [w_x     - 1:0] x,
    input        [w_y     - 1:0] y,

    output logic [w_red   - 1:0] red,
    output logic [w_green - 1:0] green,
    output logic [w_blue  - 1:0] blue,

    input        [         23:0] mic,
    output       [         15:0] sound,

    input                        uart_rx,
    output                       uart_tx,

    inout        [w_gpio  - 1:0] gpio
);

    assign sound   = '0;
    assign uart_tx = '1;

    // Generate update pulse for waveform
    logic pulse;
    strobe_gen
    # (
        .clk_mhz   ( clk_mhz ),
        .strobe_hz ( 60      )  // 60 Hz refresh rate
    )
    i_strobe_gen (clk, rst, pulse);

    // Color selection for the waveform
    logic [w_red-1:0] current_red;
    logic [w_green-1:0] current_green;
    logic [w_blue-1:0] current_blue;
    logic [3:0] color_index;

    // Color palette
    always_comb begin
        case(color_index)
            4'd0: begin current_red = 15; current_green = 0;  current_blue = 0;  end  // Red
            4'd1: begin current_red = 0;  current_green = 15; current_blue = 0;  end  // Green
            4'd2: begin current_red = 0;  current_green = 0;  current_blue = 15; end  // Blue
            4'd3: begin current_red = 15; current_green = 15; current_blue = 0;  end  // Yellow
            4'd4: begin current_red = 15; current_green = 0;  current_blue = 15; end  // Magenta
            4'd5: begin current_red = 0;  current_green = 15; current_blue = 15; end  // Cyan
            4'd6: begin current_red = 15; current_green = 15; current_blue = 15; end  // White
            4'd7: begin current_red = 10; current_green = 5;  current_blue = 0;  end  // Orange
            default: begin current_red = 15; current_green = 15; current_blue = 15; end
        endcase
    end

    // Waveform buffer to store points
    logic [8:0] wave_buffer [BUFFER_SIZE-1:0];  // 9-bit values for y-position
    logic [8:0] write_pos;  // Current position in buffer
    
    // Sine wave generator using lookup table
    logic [7:0] sine_table [0:255];
    initial begin
        for (int i = 0; i < 256; i++) begin
            // Generate sine wave values scaled to screen height
            sine_table[i] = (128 + $sin(2.0 * 3.14159 * i / 256.0) * 127.0);
        end
    end

    // Counter for sine wave generation
    logic [7:0] sine_pos;
    
    // Frequency control using switches
    logic [3:0] freq_div;
    assign freq_div = sw[3:0] + 1;  // Avoid division by zero

    // Key press detection
    logic prev_key;
    logic key_pressed;
    assign key_pressed = |key & ~prev_key;  // Any key press

    // Wave generation and buffer management
    always_ff @(posedge clk or posedge rst)
        if (rst) begin
            write_pos <= 0;
            sine_pos <= 0;
            color_index <= 0;
            prev_key <= 0;
        end
        else begin
            prev_key <= |key;
            
            if (key_pressed) begin
                // Reset position and change color on key press
                write_pos <= 0;
                sine_pos <= 0;
                color_index <= color_index + 1;
                if (color_index >= 7) color_index <= 0;
            end
            else if (pulse) begin
                // Generate new point
                wave_buffer[write_pos] <= sine_table[sine_pos];
                
                // Update positions
                write_pos <= (write_pos + 1) % BUFFER_SIZE;
                sine_pos <= sine_pos + freq_div;  // Frequency control
            end
        end

    // Drawing logic
    logic [8:0] read_pos;
    logic [8:0] prev_y, current_y;
    logic [8:0] line_y_min, line_y_max;
    logic in_wave_area;

    always_comb begin
        // Default to black
        red   = 0;
        green = 0;
        blue  = 0;

        // Calculate reading position based on x coordinate
        read_pos = (write_pos + x) % BUFFER_SIZE;
        
        // Get current and previous y values
        current_y = wave_buffer[read_pos];
        prev_y = wave_buffer[(read_pos == 0) ? BUFFER_SIZE-1 : read_pos-1];

        // Calculate line boundaries for thickness
        if (current_y > prev_y) begin
            line_y_min = prev_y - LINE_WIDTH/2;
            line_y_max = current_y + LINE_WIDTH/2;
        end else begin
            line_y_min = current_y - LINE_WIDTH/2;
            line_y_max = prev_y + LINE_WIDTH/2;
        end

        // Draw grid
        if (x % 40 == 0 || y % 40 == 0) begin
            red   = 2;
            green = 2;
            blue  = 2;
        end

        // Draw center line
        if (y >= (screen_height/2 - 1) && y <= (screen_height/2 + 1)) begin
            red   = 4;
            green = 4;
            blue  = 4;
        end

        // Draw thick waveform
        if (x < screen_width - 1) begin
            // Check if pixel is within the thick line area
            if (y >= line_y_min && y <= line_y_max) begin
                // Apply current color
                red   = current_red;
                green = current_green;
                blue  = current_blue;
                
                // Add brightness variation for 3D effect
                if (y == current_y) begin  // Center of line is brightest
                    red   = |current_red   ? 15 : 0;
                    green = |current_green ? 15 : 0;
                    blue  = |current_blue  ? 15 : 0;
                end
            end
        end
    end

    // Display frequency setting on 7-segment display
    seven_segment_display # (w_digit) i_7segment
    (
        .clk      ( clk         ),
        .rst      ( rst         ),
        .number   ( color_index ),
        .dots     ( 0           ),
        .abcdefgh ( abcdefgh    ),
        .digit    ( digit       )
    );

    // Show some status on LEDs
    assign led = {color_index, freq_div};

endmodule