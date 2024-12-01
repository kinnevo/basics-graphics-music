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

    assign sound      = '0;
    assign uart_tx    = '1;

    // Constants for circles
    localparam CIRCLE_RADIUS = 10;        // 20 pixel diameter / 2
    localparam RED_CIRCLE_START_Y = screen_height - CIRCLE_RADIUS * 2;
    localparam GREEN_CIRCLE_START_X = screen_width - CIRCLE_RADIUS * 2;
    localparam MAX_CIRCLES = 4;  // Maximum number of circles per direction
    
    // Generate pulse for movement timing
    logic pulse;
    strobe_gen
    # (
        .clk_mhz   ( clk_mhz ),
        .strobe_hz ( 60      )
    )
    i_strobe_gen (clk, rst, pulse);

    // Circle tracking structures
    typedef struct {
        logic active;
        logic [31:0] pos;
    } circle_t;

    // Arrays to store multiple circles
    circle_t red_circles[MAX_CIRCLES];    // Vertical moving circles
    circle_t green_circles[MAX_CIRCLES];  // Horizontal moving circles
    
    logic [1:0] red_circle_index;   // Index for next red circle
    logic [1:0] green_circle_index; // Index for next green circle
    
    logic [3:0] active_red_count;   // Count of active red circles
    logic [3:0] active_green_count; // Count of active green circles

    // Edge detection for sw[1] and sw[2]
    logic sw1_delayed, sw2_delayed;
    wire sw1_posedge = ~sw1_delayed & sw[1];
    wire sw2_posedge = ~sw2_delayed & sw[2];

    // Register for edge detection
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sw1_delayed <= 0;
            sw2_delayed <= 0;
        end
        else begin
            sw1_delayed <= sw[1];
            sw2_delayed <= sw[2];
        end
    end

    // Initialize and manage red circles
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < MAX_CIRCLES; i++) begin
                red_circles[i].active <= 0;
                red_circles[i].pos <= RED_CIRCLE_START_Y;
            end
            red_circle_index <= 0;
            active_red_count <= 0;
        end
        else begin
            // Launch new red circle
            if (sw1_posedge && active_red_count < MAX_CIRCLES) begin
                red_circles[red_circle_index].active <= 1;
                red_circles[red_circle_index].pos <= RED_CIRCLE_START_Y;
                red_circle_index <= red_circle_index + 1;
                active_red_count <= active_red_count + 1;
            end
            
            // Move active circles
            if (pulse) begin
                for (int i = 0; i < MAX_CIRCLES; i++) begin
                    if (red_circles[i].active) begin
                        if (red_circles[i].pos <= CIRCLE_RADIUS) begin
                            red_circles[i].active <= 0;
                            active_red_count <= active_red_count - 1;
                        end
                        else begin
                            red_circles[i].pos <= red_circles[i].pos - 2;
                        end
                    end
                end
            end
        end
    end

    // Initialize and manage green circles
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < MAX_CIRCLES; i++) begin
                green_circles[i].active <= 0;
                green_circles[i].pos <= GREEN_CIRCLE_START_X;
            end
            green_circle_index <= 0;
            active_green_count <= 0;
        end
        else begin
            // Launch new green circle
            if (sw2_posedge && active_green_count < MAX_CIRCLES) begin
                green_circles[green_circle_index].active <= 1;
                green_circles[green_circle_index].pos <= GREEN_CIRCLE_START_X;
                green_circle_index <= green_circle_index + 1;
                active_green_count <= active_green_count + 1;
            end
            
            // Move active circles
            if (pulse) begin
                for (int i = 0; i < MAX_CIRCLES; i++) begin
                    if (green_circles[i].active) begin
                        if (green_circles[i].pos <= CIRCLE_RADIUS) begin
                            green_circles[i].active <= 0;
                            active_green_count <= active_green_count - 1;
                        end
                        else begin
                            green_circles[i].pos <= green_circles[i].pos - 2;
                        end
                    end
                end
            end
        end
    end

    // Function to calculate square of a number
    function automatic int square;
        input int value;
        square = value * value;
    endfunction

    // Circle drawing logic
    logic [31:0] distance_squared;
    logic draw_red, draw_green;
    
    always_comb begin
        // Initialize colors to black
        red   = 0;
        green = 0;
        blue  = 0;
        draw_red = 0;
        draw_green = 0;

        // Check all red circles
        for (int i = 0; i < MAX_CIRCLES; i++) begin
            if (red_circles[i].active) begin
                distance_squared = square(x - screen_width/2) + 
                                 square(y - red_circles[i].pos);
                if (distance_squared <= square(CIRCLE_RADIUS)) begin
                    draw_red = 1;
                end
            end
        end

        // Check all green circles
        for (int i = 0; i < MAX_CIRCLES; i++) begin
            if (green_circles[i].active) begin
                distance_squared = square(x - green_circles[i].pos) + 
                                 square(y - screen_height/2);
                if (distance_squared <= square(CIRCLE_RADIUS)) begin
                    draw_green = 1;
                end
            end
        end

        // Set final colors
        if (draw_red) begin
            red   = 4'hF;
            green = 0;
            blue  = 0;
        end
        else if (draw_green) begin
            red   = 0;
            green = 4'hF;
            blue  = 0;
        end
    end

    // Seven segment display to show active circle counts
    logic display_toggle;
    logic [15:0] display_value;

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            display_toggle <= 0;
        else if (pulse)
            display_toggle <= ~display_toggle;
    end

    always_comb begin
        if (display_toggle)
            display_value = {12'b0, active_red_count};
        else
            display_value = {12'b0, active_green_count};
    end

    seven_segment_display # (w_digit) i_7segment
    (
        .clk      ( clk          ),
        .rst      ( rst          ),
        .number   ( display_value ),
        .dots     ( 4'b0000      ),
        .abcdefgh ( abcdefgh     ),
        .digit    ( digit        )
    );

    // Show active counts on LEDs
    assign led[3:0] = active_red_count;
    assign led[7:4] = active_green_count;

endmodule