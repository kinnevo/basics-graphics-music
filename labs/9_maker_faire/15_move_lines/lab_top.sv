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

    // assign led = counter;

    //------------------------------------------------------------------------

    // Constants for circle
    localparam CIRCLE_RADIUS = 100;        // 100 pixel diameter / 2
    localparam LINE_WIDTH = 2;           // 10 pixel line width
    localparam CENTER_X = screen_width/2;  // Center of screen X
    localparam CENTER_Y = screen_height/2; // Center of screen Y

    // Line parameters
    localparam LINE_Y = screen_height/2;  // Middle of screen
    localparam LINE_THICKNESS = 10;       // 10 pixels thick


    // Function to calculate square of a number
    function automatic int square;
        input int value;
        square = value * value;
    endfunction

    
    assign led [3] = sw[3];

// Register to store the most recent distance_squared value
    logic [31:0] display_value;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            display_value <= 0;
        else
            display_value <= distance_squared;
    end

// State flip-flop
    logic state_ff;
    
    // Edge detection for sw[5]
    logic sw5_delayed;
    wire sw5_posedge = ~sw5_delayed & sw[5];  // Detect rising edge of sw[5]

// Edge detection for sw[6] and sw[7]
    logic sw6_delayed, sw7_delayed;
    wire sw6_posedge = ~sw6_delayed & sw[6];  // Detect rising edge of sw[7]
    wire sw7_posedge = ~sw7_delayed & sw[7];  // Detect rising edge of sw[8]
    
    // Register for edge detection
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            sw5_delayed <= 0;
        else
            sw5_delayed <= sw[5];
    end
    
    // State flip-flop logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state_ff <= 0;
        else if (sw5_posedge)  // Toggle on rising edge of sw[5]
            state_ff <= ~state_ff;
    end

    // Show state on LED[5]
    // assign led[5] = state_ff;

    // Register for edge detection
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sw5_delayed <= 0;
            sw6_delayed <= 0;
            sw7_delayed <= 0;
        end
        else begin
            sw5_delayed <= sw[5];
            sw6_delayed <= sw[6];
            sw7_delayed <= sw[7];
        end
    end
    
    // State flip-flop logic for sw5
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state_ff <= 0;
        else if (sw5_posedge)
            state_ff <= ~state_ff;
    end

    // Line position control
    logic [31:0] line_position;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            line_position <= screen_height/2;  // Start in middle
        else if (sw6_posedge && line_position >= 20)  // Move up if not too high
            line_position <= line_position - 20;
        else if (sw7_posedge && line_position <= screen_height - 20)  // Move down if not too low
            line_position <= line_position + 20;
    end

    // Show state on LED[5]
    // assign led[5] = state_ff;
    // Show line position on other LEDs
    //assign led[4:0] = line_position[4:0];

    // Calculate distance for display
    wire [31:0] distance_squared = y;  // Just showing y coordinate for reference

    // Register to store the display value
    logic [31:0] display_value;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            display_value <= 0;
        else
            display_value <= distance_squared;
    end

    // Line drawing logic
    always_comb
    begin
        // Initialize the colors to black (no color)
        red   = 0;
        green = 0;
        blue  = 0;

// Draw orange horizontal line at current position
        if (y >= (line_position - LINE_THICKNESS/2) && 
            y <= (line_position + LINE_THICKNESS/2))
        begin
            red   = 15;    // Full red
            green = 7;     // Half green for orange color
            blue  = 0;     // No blue
        end    
    end

    //------------------------------------------------------------------------

    // Seven segment display logic
    // Modified to show only first 4 digits of distance_squared
    seven_segment_display # (w_digit) i_7segment
    (
        .clk      ( clk                    ),
        .rst      ( rst                    ),
        .number   ( display_value[15:0]    ),  // Show only lower 16 bits
        .dots     ( 4'b0000                ),  // No decimal points
        .abcdefgh ( abcdefgh              ),
        .digit    ( digit                  )
    );

endmodule
