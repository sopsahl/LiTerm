`timescale 1ns / 1ps
`default_nettype none

// immediate_interpreter: takes the immediate value (0 - FF_FF_FF_FF)
// and converts to a hex immediate value
// Suppots up to 4 bytes of data (8 characters)
// done_flag is high 1 cycle after the delimiter (" " or ",")

import constants::*;

module immediate_interpreter (
    input wire clk_in,
    input wire rst_in,
    input wire valid_data,
    input wire new_character,
    input wire [7 : 0] incoming_ascii,
    output logic error_flag,
    output logic done_flag,

    input wire isUtype,
    output logic [31:0] immediate
);

    typedef enum {
        IDLE, 
        FIRST_NUM,
        BUSY,
        RETURN,
        ERROR
    } state_t state;

    assign error_flag = (state == ERROR);
    assign done_flag = (state == RETURN);

    logic isValid;
    assign isValid = isAlpha(incoming_ascii) || isNum(incoming_ascii);

    logic [3:0] hex_value;
    assign hex_value = ascii_to_hex(incoming_ascii);

    always_ff @(posedge clk_in) begin
        
        if (valid_data && !rst_in) begin
            if (new_character) begin
                case (state) 
                    IDLE: if (incoming_ascii == "x" || incoming_ascii == "X") state <= FIRST_NUM;
                    FIRST_NUM: begin
                        immediate <= (isUtype) ? {28'b0, hex_value} : {28{hex_value[3]}, hex_value}; // Extend the MSB
                        state <= (isValid) ? BUSY : IDLE;
                    end BUSY: begin
                        if (isValid) immediate <= ((immediate << 4) | hex_value);
                        else state <= (incoming_ascii == " " || incoming_ascii == ",") ? RETURN : ERROR;
                    end
                endcase
            end else state <= (state == RETURN) ? IDLE : state; // Allows for single high pulse of done_flag
        end else state <= IDLE;
    end

endmodule // immediate_interpreter

`default_nettype wire