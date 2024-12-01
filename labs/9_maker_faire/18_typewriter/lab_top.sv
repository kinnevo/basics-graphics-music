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

               // Character display parameters
               CHAR_WIDTH    = 6,    // 5 pixels + 1 spacing
               CHAR_HEIGHT   = 10,   // 9 pixels + 1 spacing
               CHARS_PER_ROW = (screen_width / CHAR_WIDTH),
               CHAR_ROWS     = (screen_height / CHAR_HEIGHT)
)
(
    input                        clk,
    input                        slow_clk,
    input                        rst,

    // Keys, switches, LEDs
    input        [w_key   - 1:0] key,
    input        [w_sw    - 1:0] sw,
    output logic [w_led   - 1:0] led,

    // A dynamic seven-segment display
    output logic [          7:0] abcdefgh,
    output logic [w_digit - 1:0] digit,

    // Graphics
    input        [w_x     - 1:0] x,
    input        [w_y     - 1:0] y,

    output logic [w_red   - 1:0] red,
    output logic [w_green - 1:0] green,
    output logic [w_blue  - 1:0] blue,

    // Other interfaces
    input        [         23:0] mic,
    output       [         15:0] sound,
    input                        uart_rx,
    output                       uart_tx,
    inout        [w_gpio  - 1:0] gpio
);

    // Basic assignments
    assign sound   = '0;
    assign uart_tx = '1;

    // Character position counters
    logic [$clog2(CHARS_PER_ROW)-1:0] char_x;
    logic [$clog2(CHAR_ROWS)-1:0]     char_y;
    
    // Example character bitmap for 'A' (5x9 pixels)
    logic [44:0] char_A = {
        5'b01110,  // ..XXX..
        5'b10001,  // .X...X.
        5'b10001,  // .X...X.
        5'b10001,  // .X...X.
        5'b11111,  // .XXXXX.
        5'b10001,  // .X...X.
        5'b10001,  // .X...X.
        5'b10001,  // .X...X.
        5'b10001   // .X...X.
    };

    // Calculate relative position within character
    wire [$clog2(CHAR_WIDTH)-1:0]  pixel_x = x % CHAR_WIDTH;
    wire [$clog2(CHAR_HEIGHT)-1:0] pixel_y = y % CHAR_HEIGHT;
    
    // Calculate which character position we're in
    wire [$clog2(CHARS_PER_ROW)-1:0] curr_char_x = x / CHAR_WIDTH;
    wire [$clog2(CHAR_ROWS)-1:0]     curr_char_y = y / CHAR_HEIGHT;

    // Character display logic
    always_comb begin
        // Default to black background
        red   = 0;
        green = 0;
        blue  = 0;

        // Check if we're within the active character area (5x9, not including spacing)
        if (pixel_x < 5 && pixel_y < 9) begin
            // Check if we should display this pixel of the character
            if (char_A[44 - (pixel_y * 5 + pixel_x)] == 1'b1) begin
                // Display white text
                red   = 4'hF;
                green = 4'hF;
                blue  = 4'hF;
            end
        end
    end

    // Character position update logic
    always_ff @(posedge slow_clk or posedge rst) begin
        if (rst) begin
            char_x <= 0;
            char_y <= 0;
        end else if (key[0]) begin  // Use key[0] to advance character position
            if (char_x < CHARS_PER_ROW - 1) begin
                char_x <= char_x + 1;
            end else begin
                char_x <= 0;
                if (char_y < CHAR_ROWS - 1) begin
                    char_y <= char_y + 1;
                end else begin
                    char_y <= 0;  // Wrap back to top
                end
            end
        end
    end

    // Seven segment display for debugging
    seven_segment_display # (w_digit) i_7segment
    (
        .clk      ( clk      ),
        .rst      ( rst      ),
        .number   ( {char_y, char_x} ),  // Display current position
        .dots     ( 4'b0000  ),
        .abcdefgh ( abcdefgh ),
        .digit    ( digit    )
    );

endmodule