`include "config.svh"

module lab_top
# (
    parameter  clk_mhz       = 50,
               w_key         = 4,
               w_sw          = 8,
               w_led         = 8,
               w_digit       = 8,
               w_gpio        = 100,

               screen_width  = 640,
               screen_height = 480,

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

    //------------------------------------------------------------------------

    // assign led        = '0;
    // assign abcdefgh   = '0;
    // assign digit      = '0;
    // assign red        = '0;
    // assign green      = '0;
    // assign blue       = '0;
       assign sound      = '0;
       assign uart_tx    = '1;

    //------------------------------------------------------------------------
    //
    //  NOTE! Since the 9_maker_faire series of Verilog examples
    //  is for absolute beginners,
    //  we are using a simplified, more relaxed Verilog style
    //  that may have many lint issues. For example,
    //  we use "100" instead of "w_x' (100)" or "screen_width / 2".
    //
    //------------------------------------------------------------------------

    logic pulse;

    strobe_gen
    # (
        .clk_mhz   ( clk_mhz ),
        .strobe_hz ( 30      )
    )
    i_strobe_gen (clk, rst, pulse);

    //------------------------------------------------------------------------

    logic [7:0] dx, dy;

    always_ff @ (posedge clk or posedge rst)
        if (rst)
        begin
            dx <= 0;
            dy <= 0;
        end
        else if (pulse)
        begin
            if (key [0])
                dx <= dx - 1;
            else
                dx <= dx + 1;
                
            if (key [1])
                dy <= dy - 1;
            else
                dy <= dy + 1;
        end

    assign led = dy;

    // Declare the center of the circles
    reg [9:0] center_x;
    reg [9:0] center_y;

    // Declare the radius for each color in the rainbow
    reg [9:0] radius_red;
    reg [9:0] radius_orange;
    reg [9:0] radius_yellow;
    reg [9:0] radius_green;
    reg [9:0] radius_blue;
    reg [9:0] radius_indigo;
    reg [9:0] radius_violet;
    
        // Declare the center and radius for the blue circle
    reg [9:0] center_x;
    reg [9:0] center_y;
    reg [9:0] radius_blue;

    always_comb
    begin
        // Initialize the colors to black (no color)
        red   = 0;
        green = 0;
        blue  = 0;

        // Set the center of the circle and its radius
        center_x = 320;  // Horizontal center (screen_width / 2)
        center_y = 240;  // Vertical center (screen_height / 2)
        radius_blue = 100;  // Adjust radius as needed

        // Check if the point (x, y) is inside the blue circle
        if ((x - center_x)*(x - center_x) + (y - center_y)*(y - center_y) <= radius_blue*radius_blue)
        begin
            if ( key [0] ) 
            begin
                blue = 15;  // Maximum intensity for the blue channel
                green = 0;
            end
            else begin
                green = 15;
                blue = 0;
            end
        end
    end
  


    //------------------------------------------------------------------------

    seven_segment_display # (w_digit) i_7segment
    (
        .clk      ( clk      ),
        .rst      ( rst      ),
        .number   ( counter  ),
        .dots     ( 0        ),
        .abcdefgh ( abcdefgh ),
        .digit    ( digit    )
    );

endmodule
