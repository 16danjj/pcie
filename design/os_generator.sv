`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: os_generator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module os_generator();

// control mode 
reg start;
reg [2:0] gen;
reg EQ;

// preset fields (TX/RX) and packed temp buses used by TS1/TS2 (byte[6])
reg [63:0] tx_preset_comb, tx_preset_def;
reg [47:0] rx_preset_comb, rx_preset_def;
reg [127:0] temp1_comb;
reg [127:0] temp2_comb;

// CONSTANTS
localparam [7:0] K28_5 = 8'hBC; //Ordered-set delimiter
localparam [7:0] FILL_4A = 8'h4A; // Filler pattern for TS1
localparam [7:0] FILL_45 = 8'h45; // Filler patter for  TS2
localparam [31:0] SKP_OS = 32'h1C1C_1CBC; // Pad + K
localparam [31:0] EIOS_OS = 32'h7C7C_7CBC; // EIOS ordered set

// Combinational logic block: Build temp1_comb for TS1[55:48]
// Only active when start is asserted, gen is 001/010
// When EQ = 1, mix {1,tx[3:0],rx[2:0]} per byte
// Else, fill with 4A

always @(*) begin
// defaults
tx_preset_comb = tx_preset_def;
rx_preset_comb = rx_preset_def;
temp1_comb = {16{FILL_4A}};


if (start) begin
    if(gen == 3'b001 || gen == 3'b010) begin
        if (EQ) begin
            temp1_comb[7:0] = {1'b1, tx_preset_comb[3:0], rx_preset_comb[2:0]};
            temp1_comb[15:8] = {1'b1, tx_preset_comb[7:4], rx_preset_comb[5:3]};
            temp1_comb[23:16] = {1'b1, tx_preset_comb[11:8], rx_preset_comb[8:6]};
            temp1_comb[31:24] = {1'b1, tx_preset_comb[15:12], rx_preset_comb[11:9]};
            temp1_comb[39:32] = {1'b1, tx_preset_comb[19:16], rx_preset_comb[14:12]};
            temp1_comb[47:40] = {1'b1, tx_preset_comb[23:20], rx_preset_comb[17:15]};
            temp1_comb[55:48] = {1'b1, tx_preset_comb[27:24], rx_preset_comb[20:18]};
            temp1_comb[63:56] = {1'b1, tx_preset_comb[31:28], rx_preset_comb[23:21]};
            temp1_comb[71:64] = {1'b1, tx_preset_comb[35:32], rx_preset_comb[26:24]};
            temp1_comb[79:72] = {1'b1, tx_preset_comb[39:36], rx_preset_comb[29:27]};
            temp1_comb[87:80] = {1'b1, tx_preset_comb[43:40], rx_preset_comb[32:30]};
            temp1_comb[95:88] = {1'b1, tx_preset_comb[47:44], rx_preset_comb[35:33]};
            temp1_comb[103:96] = {1'b1, tx_preset_comb[51:48], rx_preset_comb[38:36]};
            temp1_comb[111:104] = {1'b1, tx_preset_comb[55:52], rx_preset_comb[41:39]};
            temp1_comb[119:112] = {1'b1, tx_preset_comb[59:56], rx_preset_comb[44:42]};
            temp1_comb[127:120] = {1'b1, tx_preset_comb[63:60], rx_preset_comb[47:45]};
        end
    end
end
end

// Combinational logic block: Build temp2_comb for TS2[55:48]
// When EQ = 1, mix {1,tx[3:0],rx[2:0]} per byte
// Else, fill with 45
always @(*) begin
// defaults
temp2_comb = {16{FILL_45}};
if (EQ) begin
    temp1_comb[7:0] = {1'b1, tx_preset_comb[3:0], rx_preset_comb[2:0]};
    temp1_comb[15:8] = {1'b1, tx_preset_comb[7:4], rx_preset_comb[5:3]};
    temp1_comb[23:16] = {1'b1, tx_preset_comb[11:8], rx_preset_comb[8:6]};
    temp1_comb[31:24] = {1'b1, tx_preset_comb[15:12], rx_preset_comb[11:9]};
    temp1_comb[39:32] = {1'b1, tx_preset_comb[19:16], rx_preset_comb[14:12]};
    temp1_comb[47:40] = {1'b1, tx_preset_comb[23:20], rx_preset_comb[17:15]};
    temp1_comb[55:48] = {1'b1, tx_preset_comb[27:24], rx_preset_comb[20:18]};
    temp1_comb[63:56] = {1'b1, tx_preset_comb[31:28], rx_preset_comb[23:21]};
    temp1_comb[71:64] = {1'b1, tx_preset_comb[35:32], rx_preset_comb[26:24]};
    temp1_comb[79:72] = {1'b1, tx_preset_comb[39:36], rx_preset_comb[29:27]};
    temp1_comb[87:80] = {1'b1, tx_preset_comb[43:40], rx_preset_comb[32:30]};
    temp1_comb[95:88] = {1'b1, tx_preset_comb[47:44], rx_preset_comb[35:33]};
    temp1_comb[103:96] = {1'b1, tx_preset_comb[51:48], rx_preset_comb[38:36]};
    temp1_comb[111:104] = {1'b1, tx_preset_comb[55:52], rx_preset_comb[41:39]};
    temp1_comb[119:112] = {1'b1, tx_preset_comb[59:56], rx_preset_comb[44:42]};
    temp1_comb[127:120] = {1'b1, tx_preset_comb[63:60], rx_preset_comb[47:45]};
end     
end


// Ordered set generation (TS1/TS2) base fields
reg pclk, reset_n;
reg [127:0] TS1;
reg [7:0] link_number, lane_number;
reg [2:0] rate;
reg speed_change;
reg loopback;
reg [31:0] skp, EIOS;

always @(*) 
begin
    skp = SKP_OS;
    EIOS = EIOS_OS;
end

// TS1 Field assembly (comb)
// Byte[0] : k28.5 (ordered set marker) 
// Byte[1] : link number
// Byte[2] : lane number
// Byte[3] : reserved (0)
// Byte[4] : rate encoding (7 bits) + part of byte packing
// Bit[39] : speed_change flag
// Byte[5] : loopback indicator
// Byte[6] : will be updated by temp1_comb when *transmitted*
// Byte[7+] : Tail fill with 0x4A (alignment)

always @(*) 
begin

    TS1[7:0] = K28_5;
    TS1[15:8] = link_number;
    TS1[23:16] = lane_number;
    TS1[31:24] = 8'h00;

    // rate encoding bits[38:32] : 7bits
    if (rate == 3'b001) TS1[38:32] = 7'b0000010;
    else if (rate == 3'b010) TS1[38:32] = 7'b0000110;
    else if (rate == 3'b011) TS1[38:32] = 7'b0001110;
    else if (rate == 3'b100) TS1[38:32] = 7'b0011110;
    else TS1[38:32] = 7'b0111110;
    
    TS1[39] = speed_change;
    
    // Loopback indicator [47:40]
    TS1[47:40] = loopback? 8'b0000_0100 : 8'b0000_0000;
    // Fill tail [127:56]
    TS1[127:56] = {9{FILL_4A}};
end


// TS2 Field assembly (comb)
reg [127:0] TS2;
reg req_eq;

always @(*) 
begin

    TS2[7:0] = K28_5;
    TS2[15:8] = link_number;
    TS2[23:16] = lane_number;
    TS2[31:24] = 8'h00;
    
    // rate encoding bits[38:32] : 7bits
    if (rate == 3'b001) TS2[38:32] = 7'b0000010;
    else if (rate == 3'b010) TS2[38:32] = 7'b0000110;
    else if (rate == 3'b011) TS2[38:32] = 7'b0001110;
    else if (rate == 3'b100) TS2[38:32] = 7'b0011110;
    else TS2[38:32] = 7'b0111110;
    
 
    TS2[39] = speed_change;
    TS2[47:40] = loopback? 8'b0000_0100 : 8'b0000_0000;
    TS2[55] = req_eq; // (single bit inside the byte group)

    TS2[127:56] = {9{FILL_45}};

end

// Sequencer for transitting the ordered sets
// Gen1/Gen2, PIPEWIDTH = 8, 16 lanes => 16 bytes per OS (symbol = byte index)
// os_type_reg : 00 = TS1, 01 = TS2, 02 = SKP, 03 = EIOS

reg [4:0] symbol;
reg [127:0] Os_Out;
reg [15:0] DataK; // Control character which is 1 for PAD ('F7) or Comma character, 0 otherwise
reg [15:0] DataValid;
reg finish;
reg busy;
reg [1:0] os_type_reg;

// Symbol counter : each symbol is sent to each lane (total 16 lanes)
always @(posedge pclk or negedge reset_n)
begin
    if (!reset_n)
        symbol <= 5'd0;
    else if (start) begin
        case(os_type_reg)
        
        2'b00, 2'b01: begin // TS1, TS2
        if (symbol < 5'd15)
            symbol <= symbol + 1'b1;
        else
            symbol <= 5'd0;
        end
        
        2'b10, 2'b11: begin // SKP or EIOS
        if (symbol < 5'd3)
            symbol <= symbol + 1'b1;
        else
            symbol <= 5'd0;
        end
        
        default : symbol <= 5'd0;
        endcase  
    end
    else
        symbol <= 5'd0;
end


// Unified transmitter
always @(posedge pclk or negedge reset_n)
begin
    if (!reset_n)
    begin
        Os_Out <= 128'b0;
        DataK <= 16'b0;
        DataValid <= 16'b0;
        finish <= 1'b0;
        busy <= 1'b0;
    end    
    else if (start) begin
        busy <= 1'b1;
        finish <= 1'b0;
        DataValid <= 16'h0000;
        
        case(os_type_reg)
            2'b00: begin // TS1
                case(symbol[3:0])
                    4'h0: begin Os_Out <= {16{TS1[7:0]}}; DataK <= {16{1'b1}}; end
                    4'h1: begin Os_Out <= {16{TS1[15:8]}}; DataK <= (TS1[15:8]== 8'hF7) ? {16{1'b1}} : 16'h0000; end // Initially link_number is PAD, so control character is set
                    4'h2: begin Os_Out <= {16{TS1[23:16]}}; DataK <= (TS1[23:16]== 8'hF7) ? {16{1'b1}} : 16'h0000; end
                    4'h3: begin Os_Out <= {16{TS1[31:24]}}; DataK <= 16'h0000; end
                    4'h4: begin Os_Out <= {16{TS1[39:32]}}; DataK <= 16'h0000; end
                    4'h5: begin Os_Out <= {16{TS1[47:40]}}; DataK <= 16'h0000; end
                    4'h6: begin Os_Out <= temp1_comb; DataK <= 16'h0000; end
                    4'h7: begin Os_Out <= {16{TS1[63:56]}}; DataK <= 16'h0000; end
                    4'h8: begin Os_Out <= {16{TS1[71:64]}}; DataK <= 16'h0000; end
                    4'h9: begin Os_Out <= {16{TS1[79:72]}}; DataK <= 16'h0000; end
                    4'hA: begin Os_Out <= {16{TS1[87:80]}}; DataK <= 16'h0000; end
                    4'hB: begin Os_Out <= {16{TS1[95:88]}}; DataK <= 16'h0000; end
                    4'hC: begin Os_Out <= {16{TS1[103:96]}}; DataK <= 16'h0000; end
                    4'hD: begin Os_Out <= {16{TS1[111:104]}}; DataK <= 16'h0000; end
                    4'hE: begin Os_Out <= {16{TS1[119:112]}}; DataK <= 16'h0000; end
                    4'hF: begin Os_Out <= {16{TS1[127:120]}}; DataK <= 16'h0000; finish <= 1'b1; busy <= 1'b0; end
                    default: begin Os_Out <= 128'b0; DataK <= 16'b0; end 
                endcase
            end
            
            2'b01: begin // TS2
                    case(symbol[3:0])
                    4'h0: begin Os_Out <= {16{TS2[7:0]}}; DataK <= {16{1'b1}}; end
                    4'h1: begin Os_Out <= {16{TS2[15:8]}}; DataK <= (TS2[15:8]== 8'hF7) ? {16{1'b1}} : 16'h0000; end // Initially link_number is PAD, so control character is set
                    4'h2: begin Os_Out <= {16{TS2[23:16]}}; DataK <= (TS2[23:16]== 8'hF7) ? {16{1'b1}} : 16'h0000; end
                    4'h3: begin Os_Out <= {16{TS2[31:24]}}; DataK <= 16'h0000; end
                    4'h4: begin Os_Out <= {16{TS2[39:32]}}; DataK <= 16'h0000; end
                    4'h5: begin Os_Out <= {16{TS2[47:40]}}; DataK <= 16'h0000; end
                    4'h6: begin Os_Out <= temp1_comb; DataK <= 16'h0000; end
                    4'h7: begin Os_Out <= {16{TS2[63:56]}}; DataK <= 16'h0000; end
                    4'h8: begin Os_Out <= {16{TS2[71:64]}}; DataK <= 16'h0000; end
                    4'h9: begin Os_Out <= {16{TS2[79:72]}}; DataK <= 16'h0000; end
                    4'hA: begin Os_Out <= {16{TS2[87:80]}}; DataK <= 16'h0000; end
                    4'hB: begin Os_Out <= {16{TS2[95:88]}}; DataK <= 16'h0000; end
                    4'hC: begin Os_Out <= {16{TS2[103:96]}}; DataK <= 16'h0000; end
                    4'hD: begin Os_Out <= {16{TS2[111:104]}}; DataK <= 16'h0000; end
                    4'hE: begin Os_Out <= {16{TS2[119:112]}}; DataK <= 16'h0000; end
                    4'hF: begin Os_Out <= {16{TS2[127:120]}}; DataK <= 16'h0000; finish <= 1'b1; busy <= 1'b0; end
                    default: begin Os_Out <= 128'b0; DataK <= 16'b0; end 
                endcase
            end
            2'b10: begin // SKP
                case(symbol[3:0])
                4'h0: begin Os_Out <= {16{skp[7:0]}}; DataK <= {16{1'b1}}; end // comma character
                4'h1: begin Os_Out <= {16{skp[15:8]}}; DataK <= 16'h0000; end 
                4'h2: begin Os_Out <= {16{skp[23:16]}}; DataK <= 16'h0000; end 
                4'h3: begin Os_Out <= {16{skp[31:24]}}; DataK <= 16'h0000; end 
                default: begin Os_Out <= 128'b0; DataK <= 16'b0; end
                endcase
            end
            
            2'b11: begin // EIOS
                case(symbol[3:0])
                4'h0: begin Os_Out <= {16{EIOS[7:0]}}; DataK <= {16{1'b1}}; end // comma character
                4'h1: begin Os_Out <= {16{EIOS[15:8]}}; DataK <= 16'h0000; end 
                4'h2: begin Os_Out <= {16{EIOS[23:16]}}; DataK <= 16'h0000; end 
                4'h3: begin Os_Out <= {16{EIOS[31:24]}}; DataK <= 16'h0000; end 
                default: begin Os_Out <= 128'b0; DataK <= 16'b0; end
                endcase
            end
            
            // IDLE 
            default: begin 
            if (symbol != 4'hF)
            begin
                Os_Out <= 128'b0;
                DataK <= 16'b0;
                busy <= 1'b1;
                finish <= 1'b0;
            end
            else 
            begin
                Os_Out <= 128'b0;
                DataK <= 16'b0;
                busy <= 1'b0;
                finish <= 1'b1;
            end
            
            end
        endcase
        
        
        
    end
end

endmodule
