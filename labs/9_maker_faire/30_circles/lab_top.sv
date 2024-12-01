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
               
               MAX_CIRCLES   = 10  // Maximum number of circles to keep on screen
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

    // Generate 1 Hz pulse for circle updates
    logic pulse;
    strobe_gen
    # (
        .clk_mhz   ( clk_mhz ),
        .strobe_hz ( 1       )  // 1 Hz for one circle per second
    )
    i_strobe_gen (clk, rst, pulse);

    // Random number generation using LFSR with multiple taps for better randomness
    logic [31:0] lfsr;
    always_ff @(posedge clk or posedge rst)
        if (rst)
            lfsr <= 32'hACE1_B0D1;  // Non-zero seed
        else
            lfsr <= {lfsr[30:0], 
                    lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};

    // Structure to store circle information
    typedef struct {
        logic [w_x-1:0] x;
        logic [w_y-1:0] y;
        logic [w_red-1:0] circle_red;
        logic [w_green-1:0] circle_green;
        logic [w_blue-1:0] circle_blue;
        logic valid;
    } circle_t;

    // Array to store multiple circles
    circle_t circles [MAX_CIRCLES-1:0];
    logic [$clog2(MAX_CIRCLES)-1:0] circle_count;

    // Circle management logic
    always_ff @(posedge clk or posedge rst)
        if (rst) begin
            circle_count <= 0;
            for (int i = 0; i < MAX_CIRCLES; i++) begin
                circles[i].valid <= 0;
            end
        end
        else if (pulse) begin
            // Add new circle with new random position and color
            if (circle_count < MAX_CIRCLES) begin
                // Calculate random position ensuring circle stays completely on screen
                circles[circle_count].x <= 50 + (lfsr[7:0] % (screen_width - 100));
                circles[circle_count].y <= 50 + (lfsr[15:8] % (screen_height - 100));
                
                // Generate truly random colors using different bits of LFSR
                circles[circle_count].circle_red   <= lfsr[19:16];
                circles[circle_count].circle_green <= lfsr[23:20];
                circles[circle_count].circle_blue  <= lfsr[27:24];
                
                circles[circle_count].valid <= 1;
                circle_count <= circle_count + 1;
            end
            // If we reach maximum circles, reset to start over
            else begin
                circle_count <= 0;
                for (int i = 0; i < MAX_CIRCLES; i++) begin
                    circles[i].valid <= 0;
                end
            end
        end

    // Calculate if current pixel is within any circle
    logic [31:0] dx, dy, distance_squared;
    logic pixel_in_any_circle;
    logic [2:0] active_circle_idx;

    always_comb begin
        pixel_in_any_circle = 0;
        active_circle_idx = 0;
        
        // Check each valid circle
        for (int i = 0; i < MAX_CIRCLES; i++) begin
            if (circles[i].valid) begin
                // Calculate distance from current pixel to circle center
                dx = (x > circles[i].x) ? (x - circles[i].x) : (circles[i].x - x);
                dy = (y > circles[i].y) ? (y - circles[i].y) : (circles[i].y - y);
                distance_squared = dx * dx + dy * dy;
                
                // If pixel is within circle radius (50 pixels)
                if (distance_squared <= 2500) begin  // 50^2 = 2500
                    pixel_in_any_circle = 1;
                    active_circle_idx = i;
                end
            end
        end
        
        // Set pixel color based on circle membership
        if (pixel_in_any_circle) begin
            red   = circles[active_circle_idx].circle_red;
            green = circles[active_circle_idx].circle_green;
            blue  = circles[active_circle_idx].circle_blue;
        end
        else begin
            red   = 0;
            green = 0;
            blue  = 0;
        end
    end

    // Display number of active circles on 7-segment display
    seven_segment_display # (w_digit) i_7segment
    (
        .clk      ( clk          ),
        .rst      ( rst          ),
        .number   ( circle_count ),
        .dots     ( 0            ),
        .abcdefgh ( abcdefgh     ),
        .digit    ( digit        )
    );

    // Show some status on LEDs
    assign led = circle_count;

endmodule