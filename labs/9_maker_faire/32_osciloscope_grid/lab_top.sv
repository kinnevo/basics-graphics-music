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
               
               ARROW_SIZE    = 20,    // Arrow size
               TEXT_SIZE     = 16     // Text size
)
(
    // ... [Port declarations remain the same]
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

    // Grid layout parameters
    localparam MARGIN_LEFT = 80;
    localparam MARGIN_BOTTOM = 60;
    localparam GRID_WIDTH = screen_width - MARGIN_LEFT - 40;
    localparam GRID_HEIGHT = screen_height - MARGIN_BOTTOM - 40;
    localparam DIV_WIDTH = GRID_WIDTH / 10;
    localparam DIV_HEIGHT = GRID_HEIGHT / 10;

    // Function to detect if a point is within line width
    function logic is_in_line;
        input [w_x-1:0] x1, x2;    // Line endpoints x
        input [w_y-1:0] y1, y2;    // Line endpoints y
        input [w_x-1:0] px;        // Point to check x
        input [w_y-1:0] py;        // Point to check y
        input [3:0] width;         // Line width
        logic signed [31:0] dx, dy, distance;
    begin
        dx = x2 - x1;
        dy = y2 - y1;
        
        if (dx == 0 && dy == 0) begin
            // Point line
            distance = ((px - x1) * (px - x1) + (py - y1) * (py - y1));
            is_in_line = (distance <= width * width);
        end
        else begin
            // Normal line
            distance = ((py - y1) * dx - (px - x1) * dy);
            distance = (distance * distance) / (dx * dx + dy * dy);
            is_in_line = (distance <= width * width);
        end
    end
    endfunction

    // Drawing logic
    always_comb begin
        // Default black background
        red   = 0;
        green = 0;
        blue  = 0;

        // Draw grid
        if (x >= MARGIN_LEFT && x <= MARGIN_LEFT + GRID_WIDTH &&
            y >= MARGIN_BOTTOM && y <= MARGIN_BOTTOM + GRID_HEIGHT) begin
            
            // Draw grid lines
            if ((x - MARGIN_LEFT) % DIV_WIDTH == 0 || 
                (y - MARGIN_BOTTOM) % DIV_HEIGHT == 0) begin
                red   = 4;
                green = 4;
                blue  = 4;
            end
        end

        // Draw main axes with thickness
        // Vertical axis
        if (x >= MARGIN_LEFT + GRID_WIDTH/2 - 2 && 
            x <= MARGIN_LEFT + GRID_WIDTH/2 + 2 &&
            y >= MARGIN_BOTTOM) begin
            red   = 15;
            green = 15;
            blue  = 15;
        end

        // Horizontal axis
        if (y >= MARGIN_BOTTOM + GRID_HEIGHT/2 - 2 && 
            y <= MARGIN_BOTTOM + GRID_HEIGHT/2 + 2 &&
            x >= MARGIN_LEFT) begin
            red   = 15;
            green = 15;
            blue  = 15;
        end

        // Draw arrows
        // Vertical arrow (at the top)
        if (y < MARGIN_BOTTOM/2) begin
            // Arrow shaft
            if (x >= MARGIN_LEFT + GRID_WIDTH/2 - 2 &&
                x <= MARGIN_LEFT + GRID_WIDTH/2 + 2) begin
                red   = 15;
                green = 15;
                blue  = 15;
            end
            
            // Arrow head
            if (y < ARROW_SIZE) begin
                logic signed [31:0] arrow_x, arrow_y;
                arrow_x = x - (MARGIN_LEFT + GRID_WIDTH/2);
                arrow_y = ARROW_SIZE - y;
                
                if (arrow_x * arrow_x <= (ARROW_SIZE * ARROW_SIZE - arrow_y * arrow_y) * 2) begin
                    red   = 15;
                    green = 15;
                    blue  = 15;
                end
            end
        end

        // Horizontal arrow (at the right)
        if (x > MARGIN_LEFT + GRID_WIDTH) begin
            // Arrow shaft
            if (y >= MARGIN_BOTTOM + GRID_HEIGHT/2 - 2 &&
                y <= MARGIN_BOTTOM + GRID_HEIGHT/2 + 2) begin
                red   = 15;
                green = 15;
                blue  = 15;
            end
            
            // Arrow head
            if (x < MARGIN_LEFT + GRID_WIDTH + ARROW_SIZE) begin
                logic signed [31:0] arrow_x, arrow_y;
                arrow_x = MARGIN_LEFT + GRID_WIDTH + ARROW_SIZE - x;
                arrow_y = y - (MARGIN_BOTTOM + GRID_HEIGHT/2);
                
                if (arrow_y * arrow_y <= (ARROW_SIZE * ARROW_SIZE - arrow_x * arrow_x) * 2) begin
                    red   = 15;
                    green = 15;
                    blue  = 15;
                end
            end
        end

        // Draw text "AMPLITUDE" (simplified vertical text)
        if (y >= MARGIN_BOTTOM + GRID_HEIGHT/4 && 
            y <= MARGIN_BOTTOM + GRID_HEIGHT*3/4) begin
            // Draw 'A' vertically
            if ((x >= 30 && x <= 50) || (y >= MARGIN_BOTTOM + GRID_HEIGHT/2 - 10 &&
                y <= MARGIN_BOTTOM + GRID_HEIGHT/2 + 10)) begin
                red   = 15;
                green = 15;
                blue  = 15;
            end
        end

        // Draw text "TIME" (simplified horizontal text)
        if (y >= screen_height - 40 && y <= screen_height - 20) begin
            // Draw 'T' horizontally
            if ((x >= MARGIN_LEFT + GRID_WIDTH/2 - 20 &&
                 x <= MARGIN_LEFT + GRID_WIDTH/2 + 20) ||
                (x >= MARGIN_LEFT + GRID_WIDTH/2 - 2 &&
                 x <= MARGIN_LEFT + GRID_WIDTH/2 + 2)) begin
                red   = 15;
                green = 15;
                blue  = 15;
            end
        end
    end

    // Simple 7-segment display output
    assign led = sw;
    
    seven_segment_display # (w_digit) i_7segment
    (
        .clk      ( clk      ),
        .rst      ( rst      ),
        .number   ( 0        ),
        .dots     ( 0        ),
        .abcdefgh ( abcdefgh ),
        .digit    ( digit    )
    );

endmodule