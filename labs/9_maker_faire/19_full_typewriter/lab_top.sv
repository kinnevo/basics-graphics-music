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

               CHAR_WIDTH    = 6,    // 5 pixels + 1 spacing
               CHAR_HEIGHT   = 10,   // 9 pixels + 1 spacing
               CHARS_PER_ROW = (screen_width / CHAR_WIDTH),
               CHAR_ROWS     = (screen_height / CHAR_HEIGHT)
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

    // Basic assignments
    assign sound   = '0;
    assign uart_tx = '1;

    // Character position counters
    logic [$clog2(CHARS_PER_ROW)-1:0] char_x;
    logic [$clog2(CHAR_ROWS)-1:0]     char_y;
    logic [4:0] current_letter;  // 0-25 for a-z

    // Improved key debouncing logic
    logic [19:0] debounce_counter;
    logic key_pressed;

    // Debouncing state machine
    typedef enum logic [1:0] {
        IDLE,
        WAIT_STABLE,
        PRESSED,
        WAIT_RELEASE
    } debounce_state_t;

    debounce_state_t current_state;

    // Improved debouncing FSM
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
            debounce_counter <= '0;
            key_pressed <= 1'b0;
        end else begin
            key_pressed <= 1'b0; // Default state, only high for one clock cycle when pressed
            
            case (current_state)
                IDLE: begin
                    if (!key[0]) begin // Key is pressed (active low)
                        current_state <= WAIT_STABLE;
                        debounce_counter <= 20'd50000; // 1ms at 50MHz
                    end
                end

                WAIT_STABLE: begin
                    if (key[0]) begin // Key released during debounce
                        current_state <= IDLE;
                    end else if (debounce_counter == 0) begin
                        current_state <= PRESSED;
                        key_pressed <= 1'b1; // Signal a valid key press
                    end else begin
                        debounce_counter <= debounce_counter - 1;
                    end
                end

                PRESSED: begin
                    if (key[0]) begin // Key released
                        current_state <= WAIT_RELEASE;
                        debounce_counter <= 20'd50000; // 1ms at 50MHz
                    end
                end

                WAIT_RELEASE: begin
                    if (!key[0]) begin // Key pressed again during release debounce
                        current_state <= PRESSED;
                    end else if (debounce_counter == 0) begin
                        current_state <= IDLE;
                    end else begin
                        debounce_counter <= debounce_counter - 1;
                    end
                end
            endcase
        end
    end

    // LED output to show debouncing state (for debugging)
    assign led = {
        4'b0000,
        
        current_state == IDLE,
        current_state == WAIT_STABLE,
        current_state == PRESSED,
        current_state == WAIT_RELEASE
    };

    // Character position and letter update logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            char_x <= 0;
            char_y <= 0;
            current_letter <= 0;
        end else if (key_pressed) begin  // Only update on clean key press
            // Move to next character position
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
            
            // Update to next letter
            if (current_letter < 25) begin
                current_letter <= current_letter + 1;
            end else begin
                current_letter <= 0;
            end
        end
    end

    // Calculate relative position within character
    wire [$clog2(CHAR_WIDTH)-1:0]  pixel_x = x % CHAR_WIDTH;
    wire [$clog2(CHAR_HEIGHT)-1:0] pixel_y = y % CHAR_HEIGHT;
    
    // Calculate which character position we're in
    wire [$clog2(CHARS_PER_ROW)-1:0] curr_char_x = x / CHAR_WIDTH;
    wire [$clog2(CHAR_ROWS)-1:0]     curr_char_y = y / CHAR_HEIGHT;

    // Lowercase alphabet bitmaps (5x9 pixels each)
    logic [44:0] char_bitmap;
    always_comb begin
        case (current_letter)
            0: char_bitmap = { // a
                5'b00000, 5'b00000, 5'b01110, 5'b00001, 5'b01111,
                5'b10001, 5'b01111, 5'b00000, 5'b00000
            };
            1: char_bitmap = { // b
                5'b10000, 5'b10000, 5'b10110, 5'b11001, 5'b10001,
                5'b10001, 5'b11110, 5'b00000, 5'b00000
            };
            2: char_bitmap = { // c
                5'b00000, 5'b00000, 5'b01110, 5'b10000, 5'b10000,
                5'b10001, 5'b01110, 5'b00000, 5'b00000
            };
            3: char_bitmap = { // d
                5'b00001, 5'b00001, 5'b01101, 5'b10011, 5'b10001,
                5'b10011, 5'b01101, 5'b00000, 5'b00000
            };
            4: char_bitmap = { // e
                5'b00000, 5'b00000, 5'b01110, 5'b10001, 5'b11111,
                5'b10000, 5'b01110, 5'b00000, 5'b00000
            };
            5: char_bitmap = { // f
                5'b00110, 5'b01001, 5'b01000, 5'b11110, 5'b01000,
                5'b01000, 5'b01000, 5'b00000, 5'b00000
            };
            6: char_bitmap = { // g
                5'b00000, 5'b01111, 5'b10001, 5'b01111, 5'b00001,
                5'b10001, 5'b01110, 5'b00000, 5'b00000
            };
            7: char_bitmap = { // h
                5'b10000, 5'b10000, 5'b10110, 5'b11001, 5'b10001,
                5'b10001, 5'b10001, 5'b00000, 5'b00000
            };
            8: char_bitmap = { // i
                5'b00100, 5'b00000, 5'b01100, 5'b00100, 5'b00100,
                5'b00100, 5'b01110, 5'b00000, 5'b00000
            };
            9: char_bitmap = { // j
                5'b00010, 5'b00000, 5'b00110, 5'b00010, 5'b00010,
                5'b10010, 5'b01100, 5'b00000, 5'b00000
            };
            10: char_bitmap = { // k
                5'b10000, 5'b10000, 5'b10010, 5'b10100, 5'b11000,
                5'b10100, 5'b10010, 5'b00000, 5'b00000
            };
            11: char_bitmap = { // l
                5'b01100, 5'b00100, 5'b00100, 5'b00100, 5'b00100,
                5'b00100, 5'b01110, 5'b00000, 5'b00000
            };
            12: char_bitmap = { // m
                5'b00000, 5'b00000, 5'b11010, 5'b10101, 5'b10101,
                5'b10101, 5'b10101, 5'b00000, 5'b00000
            };
            13: char_bitmap = { // n
                5'b00000, 5'b00000, 5'b10110, 5'b11001, 5'b10001,
                5'b10001, 5'b10001, 5'b00000, 5'b00000
            };
            14: char_bitmap = { // o
                5'b00000, 5'b00000, 5'b01110, 5'b10001, 5'b10001,
                5'b10001, 5'b01110, 5'b00000, 5'b00000
            };
            15: char_bitmap = { // p
                5'b00000, 5'b00000, 5'b11110, 5'b10001, 5'b11110,
                5'b10000, 5'b10000, 5'b00000, 5'b00000
            };
            16: char_bitmap = { // q
                5'b00000, 5'b00000, 5'b01101, 5'b10011, 5'b01111,
                5'b00001, 5'b00001, 5'b00000, 5'b00000
            };
            17: char_bitmap = { // r
                5'b00000, 5'b00000, 5'b10110, 5'b11001, 5'b10000,
                5'b10000, 5'b10000, 5'b00000, 5'b00000
            };
            18: char_bitmap = { // s
                5'b00000, 5'b00000, 5'b01110, 5'b10000, 5'b01110,
                5'b00001, 5'b11110, 5'b00000, 5'b00000
            };
            19: char_bitmap = { // t
                5'b01000, 5'b01000, 5'b11110, 5'b01000, 5'b01000,
                5'b01001, 5'b00110, 5'b00000, 5'b00000
            };
            20: char_bitmap = { // u
                5'b00000, 5'b00000, 5'b10001, 5'b10001, 5'b10001,
                5'b10011, 5'b01101, 5'b00000, 5'b00000
            };
            21: char_bitmap = { // v
                5'b00000, 5'b00000, 5'b10001, 5'b10001, 5'b10001,
                5'b01010, 5'b00100, 5'b00000, 5'b00000
            };
            22: char_bitmap = { // w
                5'b00000, 5'b00000, 5'b10001, 5'b10001, 5'b10101,
                5'b10101, 5'b01010, 5'b00000, 5'b00000
            };
            23: char_bitmap = { // x
                5'b00000, 5'b00000, 5'b10001, 5'b01010, 5'b00100,
                5'b01010, 5'b10001, 5'b00000, 5'b00000
            };
            24: char_bitmap = { // y
                5'b00000, 5'b00000, 5'b10001, 5'b10001, 5'b01111,
                5'b00001, 5'b01110, 5'b00000, 5'b00000
            };
            25: char_bitmap = { // z
                5'b00000, 5'b00000, 5'b11111, 5'b00010, 5'b00100,
                5'b01000, 5'b11111, 5'b00000, 5'b00000
            };
            default: char_bitmap = 45'b0;
        endcase
    end

    // Character display logic
    always_comb begin
        // Default to black background
        red   = 0;
        green = 0;
        blue  = 0;

        // Check if we're at the current character position and within the active character area
        if (curr_char_x == char_x && curr_char_y == char_y && 
            pixel_x < 5 && pixel_y < 9) begin
            // Check if we should display this pixel of the current character
            if (char_bitmap[44 - (pixel_y * 5 + pixel_x)] == 1'b1)
            begin
                // Display white text
                red   = 4'hF;
                green = 4'hF;
                blue  = 4'hF;
            end
        end
    end

    // Seven segment display shows current letter (a=0, b=1, etc.)
    seven_segment_display # (w_digit) i_7segment
    (
        .clk      ( clk            ),
        .rst      ( rst            ),
        .number   ( current_letter ),
        .dots     ( 4'b0000        ),
        .abcdefgh ( abcdefgh       ),
        .digit    ( digit          )
    );

endmodule