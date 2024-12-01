`include "config.svh"

module lcd_color_fill (
    input  logic        clk,
    input  logic        rst,
    input  logic [1:0]  sw,          // Switch inputs
    output logic        lcd_cs,       // LCD chip select
    output logic        lcd_dc,       // LCD data/command
    output logic        lcd_wr,       // LCD write signal
    output logic [15:0] lcd_data      // LCD RGB565 data
);

    // LCD parameters (adjust based on your LCD)
    parameter LCD_WIDTH = 320;
    parameter LCD_HEIGHT = 240;

    // RGB565 color definitions
    parameter RED = 16'hF800;   // Full red in RGB565
    parameter BLUE = 16'h001F;  // Full blue in RGB565

    // FSM states
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        SET_COLUMN,
        SET_ROW,
        WRITE_DATA
    } state_t;

    state_t current_state, next_state;
    
    // Counters for pixel position
    logic [9:0] x_count;
    logic [8:0] y_count;
    logic [16:0] pixel_count;

    // Selected color based on switches
    logic [15:0] selected_color;

    // Color selection logic
    always_comb begin
        if (sw[0])
            selected_color = BLUE;
        else if (sw[1])
            selected_color = RED;
        else
            selected_color = 16'h0000;  // Black if no switch pressed
    end

    // Main FSM
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
            x_count <= 0;
            y_count <= 0;
            pixel_count <= 0;
            lcd_cs <= 1;
            lcd_dc <= 1;
            lcd_wr <= 1;
            lcd_data <= 16'h0000;
        end
        else begin
            case (current_state)
                IDLE: begin
                    if (sw[0] || sw[1]) begin
                        current_state <= INIT;
                        x_count <= 0;
                        y_count <= 0;
                        pixel_count <= 0;
                    end
                end

                INIT: begin
                    lcd_cs <= 0;
                    lcd_dc <= 0;  // Command mode
                    lcd_data <= 16'h2C;  // Memory write command
                    current_state <= SET_COLUMN;
                end

                SET_COLUMN: begin
                    lcd_dc <= 1;  // Data mode
                    current_state <= WRITE_DATA;
                end

                WRITE_DATA: begin
                    lcd_data <= selected_color;
                    
                    if (pixel_count < LCD_WIDTH * LCD_HEIGHT - 1) begin
                        pixel_count <= pixel_count + 1;
                        
                        if (x_count < LCD_WIDTH - 1)
                            x_count <= x_count + 1;
                        else begin
                            x_count <= 0;
                            y_count <= y_count + 1;
                        end
                    end
                    else begin
                        current_state <= IDLE;
                        lcd_cs <= 1;
                    end
                end

                default: current_state <= IDLE;
            endcase
        end
    end

endmodule