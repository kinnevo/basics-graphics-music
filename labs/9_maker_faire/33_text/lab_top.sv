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

    assign sound   = '0;
    assign uart_tx = '1;
    assign led     = sw;  // Connect switches to LEDs directly

    // Character set - 36 characters (A-Z, 0-9)
    logic [15:0] charset [0:35] [0:19];  // 36 characters, each 20x16
    
    // Initialize character set
    initial begin
        // Letter 'A'
        charset[0] = '{
            16'b0000111111110000,
            16'b0001111111111000,
            16'b0011111111111100,
            16'b0111111111111110,
            16'b0111110000111110,
            16'b0111100000011110,
            16'b0111100000011110,
            16'b0111100000011110,
            16'b0111111111111110,
            16'b0111111111111110,
            16'b0111111111111110,
            16'b0111100000011110,
            16'b0111100000011110,
            16'b0111100000011110,
            16'b0111100000011110,
            16'b0111100000011110,
            16'b0111100000011110,
            16'b0111100000011110,
            16'b0111100000011110,
            16'b0111100000011110
        };

        // [Add remaining character definitions...]

        // Numbers for index display (smaller 8x6 matrix within the array)
        charset[26] = '{  // '0'
            16'b0000111100000000,
            16'b0001111110000000,
            16'b0011000110000000,
            16'b0011000110000000,
            16'b0011000110000000,
            16'b0011000110000000,
            16'b0011000110000000,
            16'b0001111110000000,
            16'b0000111100000000,
            16'b0000000000000000,
            16'b0000000000000000,
            16'b0000000000000000,
            16'b0000000000000000,
            16'b0000000000000000,
            16'b0000000000000000,
            16'b0000000000000000,
            16'b0000000000000000,
            16'b0000000000000000,
            16'b0000000000000000,
            16'b0000000000000000
        };

        // [Add remaining number definitions...]
    end

    // Display parameters
    localparam CHAR_HEIGHT = 24;    // Display height
    localparam MATRIX_HEIGHT = 20;  // Matrix height
    localparam MATRIX_WIDTH = 16;   // Matrix width
    localparam START_X = 200;       // Main character position
    localparam START_Y = 124;       // Vertical position
    localparam INDEX_X = 260;       // Position for index number

    // Character selection logic
    logic [5:0] current_char;
    logic prev_key;
    logic key_pressed;

    // Key press detection
    assign key_pressed = |key & ~prev_key;

    // Character counter
    always_ff @(posedge clk or posedge rst)
        if (rst) begin
            current_char <= 0;
            prev_key <= 0;
        end
        else begin
            prev_key <= |key;
            if (key_pressed)
                current_char <= (current_char + 1) % 36;
        end

    // Function to get digit from number
    function logic [5:0] get_digit;
        input [5:0] number;
        input [1:0] digit_pos;  // 0=ones, 1=tens
        begin
            case(digit_pos)
                0: get_digit = number % 10;
                1: get_digit = (number / 10) % 10;
                default: get_digit = 0;
            endcase
        end
    endfunction

    // Calculate position within character matrix
    logic [4:0] matrix_x, matrix_y;
    logic [5:0] digit_char;
    logic drawing_index;
    
    always_comb begin
        // Default black background
        red   = 0;
        green = 0;
        blue  = 0;

        // Determine if we're drawing main character or index
        if (x >= START_X && x < START_X + MATRIX_WIDTH &&
            y >= START_Y && y < START_Y + CHAR_HEIGHT) begin
            
            // Main character
            matrix_x = x - START_X;
            matrix_y = (y - START_Y) * MATRIX_HEIGHT / CHAR_HEIGHT;

            if (matrix_y < MATRIX_HEIGHT && charset[current_char][matrix_y][matrix_x]) begin
                red   = 15;
                green = 15;
                blue  = 15;
            end
        end
        else if (x >= INDEX_X && x < INDEX_X + MATRIX_WIDTH &&
                 y >= START_Y && y < START_Y + CHAR_HEIGHT) begin
            
            // Index number
            matrix_x = x - INDEX_X;
            matrix_y = (y - START_Y) * MATRIX_HEIGHT / CHAR_HEIGHT;

            // Get proper digit based on x position
            digit_char = get_digit(current_char + 1, // Add 1 to display 1-36 instead of 0-35
                                 (x - INDEX_X) < MATRIX_WIDTH/2 ? 1 : 0);
            
            if (matrix_y < MATRIX_HEIGHT && charset[digit_char + 26][matrix_y][matrix_x]) begin
                red   = 15;
                green = 15;
                blue  = 15;
            end
        end
    end

    // Simple 7-segment display
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