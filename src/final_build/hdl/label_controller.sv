`timescale 1ns / 1ps
`default_nettype none

import constants::*;

module label_controller #(
    parameter NUMBER_LINES = 256,
    parameter NUMBER_LETTERS = 6,
    parameter NUM_LABELS = 8
    ) (
    input wire clk_in,
    input wire rst_in,
    input wire new_line, 
    input wire new_character,
    input wire valid_data,
    input wire [$clog2(NUMBER_LINES) + 1 : 0] pc,
    input wire [7:0] incoming_character, // Each new character 
    output logic done_flag, // Instruction is Ready
    output logic error_flag, // Error encountered

    input assembler_state_t assembler_state, // Determines what we are doing at any given point
    output logic [31 : 0] offset
);  

    enum {
        IDLE,
        BUSY,
        RETURN,
        ERROR
    } state;
    
    assign error_flag = (state == ERROR);
    assign done_flag = (state == RETURN) || (mapping_state == SKIP) ;

    logic [NUMBER_LETTERS - 1:0][4:0] label_buffer;
    logic [31 : 0] offset_buffer;

    label_storage #(.NUMBER_LINES(NUMBER_LINES), .NUMBER_LETTERS(NUMBER_LETTERS), .STORAGE_SIZE(NUM_LABELS)) _label_storage (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .current_label(label_buffer),
        .pc(pc),
        .write_enable(assembler_state == PC_MAPPING && mapping_state == CLEAN && state == RETURN),
        .offset(offset_buffer)
    ); 

    enum {
        CLEAN,
        SKIP
    } mapping_state;


    logic isAlpha;
    assign isAlpha = (incoming_character >= "a" && incoming_character <= "z") || (incoming_character >= "A" && incoming_character <= "Z");

    always_ff @(posedge clk_in) begin
        if (valid_data && !rst_in && !new_line) begin
            if (new_character) begin
                case (state) 
                    IDLE: begin
                        if ((isAlpha || incoming_character == "/") && assembler_state == PC_MAPPING) mapping_state <= SKIP;
                        else if (incoming_character == ".") begin 
                            state <= BUSY;
                            label_buffer <= 0;
                        end 
                    end BUSY: begin
                        if (isAlpha) begin
                            label_buffer <= {label_buffer[NUMBER_LETTERS - 2 : 0], incoming_character[4:0]};
                        end else begin
                            if (incoming_character == ".") begin
                                state <= RETURN; 
                                offset <= offset_buffer;
                            end else state <= ERROR;
                        end
                    end
                endcase
            end else state <= (state == RETURN) ? IDLE : state; // Allows for single high pulse of done_flag
        end else begin
            state <= IDLE; 
            mapping_state <= CLEAN;
        end
    end

endmodule // immediate_interpreter

module label_storage #(
    parameter NUMBER_LINES = 256,
    parameter NUMBER_LETTERS = 6,
    parameter STORAGE_SIZE = 8
    ) (     
    input wire clk_in,
    input wire rst_in,
    input wire [NUMBER_LETTERS - 1:0][4:0] current_label,
    
    input wire write_enable,
    input wire [$clog2(NUMBER_LINES) + 1 : 0] pc,

    output logic signed [31 : 0] offset
);  
    logic [STORAGE_SIZE - 1:0][(NUMBER_LETTERS * 5) - 1: 0] label_storage;
    logic [STORAGE_SIZE - 1:0][$clog2(NUMBER_LINES) + 1 : 0] pc_storage;

    always_ff @(posedge clk_in) begin
        if (rst_in) label_storage <= 0;
        else if (write_enable) begin // In write mode
            label_storage <= {label_storage[STORAGE_SIZE - 2:0], current_label};
            pc_storage <= {pc_storage[STORAGE_SIZE - 2:0], pc};
        end 
    end

    always_comb begin // Single Cycle Reads
        case (current_label)
            label_storage[0] : offset = pc_storage[0] - pc;
            label_storage[1] : offset = pc_storage[1] - pc;
            label_storage[2] : offset = pc_storage[2] - pc;
            label_storage[3] : offset = pc_storage[3] - pc;
            label_storage[4] : offset = pc_storage[4] - pc;
            label_storage[5] : offset = pc_storage[5] - pc;
            label_storage[6] : offset = pc_storage[6] - pc;
            label_storage[7] : offset = pc_storage[7] - pc;
            default : offset = 0;
        endcase
    end

endmodule // label_storage

`default_nettype wire