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
               w_y           = $clog2 ( screen_height )
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

    // Microphone, sound output and UART
    input        [         23:0] mic,
    output       [         15:0] sound,

    input                        uart_rx,
    output                       uart_tx,

    // General-purpose Input/Output
    inout        [w_gpio  - 1:0] gpio
);

    // Basic assignments
    assign sound      = '0;
    assign uart_tx    = '1;

    // Constants for circle
    localparam CIRCLE_RADIUS = 150;        // 300 pixel diameter / 2
    localparam CENTER_X = screen_width/2;  // Center of screen X
    localparam CENTER_Y = screen_height/2; // Center of screen Y

    // Function to calculate square of a number
    function automatic int square;
        input int value;
        square = value * value;
    endfunction

    // Calculate distance from current pixel to circle center
    wire [31:0] distance_squared = square(x - CENTER_X) + square(y - CENTER_Y);

    // Circle drawing logic with color selection based on sw[5]
    always_comb
    begin
        // Initialize the colors to black (no color)
        red   = 0;
        green = 0;
        blue  = 0;

        // Draw filled circle
        if (distance_squared <= square(CIRCLE_RADIUS))
        begin
            if (sw[5]) begin
                // Red when sw[5] is pressed
                red   = 4'hF;    // Full red
                green = 4'h0;    // No green
                blue  = 4'h0;    // No blue
            end else begin
                // White when sw[5] is not pressed
                red   = 4'hF;    // Full red
                green = 4'hF;    // Full green
                blue  = 4'hF;    // Full blue
            end
        end
    end

    // Display the current color on LED[5]
    assign led[5] = sw[5];  // LED indicates current color selection

    // Seven segment display logic
    seven_segment_display # (w_digit) i_7segment
    (
        .clk      ( clk                    ),
        .rst      ( rst                    ),
        .number   ( distance_squared[15:0] ),  // Display distance for debug
        .dots     ( 4'b0000                ),
        .abcdefgh ( abcdefgh              ),
        .digit    ( digit                  )
    );

endmodule