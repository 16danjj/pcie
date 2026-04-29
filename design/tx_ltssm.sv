`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/28/2026 10:26:17 PM
// Design Name: 
// Module Name: tx_ltssm
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


module tx_ltssm(

    );
    
    
reg pclk;
reg rst_n;

initial begin
pclk = 1'b0;
forever #5 pclk = ~pclk; // 100 MHz
end

initial begin
rst_n = 1'b0;
repeat (5) @(posedge pclk);
rst_n = 1'b1;
end

// Generic counter for per-state timeouts
reg [31:0] count;

// LTSSM State Encoding

localparam 
DetectQuiet = 5'd0,
DetectActive = 5'd1,
PollingActive = 5'd2,
PollingConfig = 5'd3,
ConfigLinkWidthStart = 5'd4,
ConfigLinkWidthAccept = 5'd5,
ConfigLaneWidthAccept = 5'd6,
ConfigLaneNumActive = 5'd7,
ConfigComplete = 5'd8,
ConfigIdle = 5'd9,
L0 = 5'd10,
RecoveryRcvrLock = 5'd11,
RecoveryRcvrCfg = 5'd12,
RecoverySpeed = 5'd13,
Ph0 = 5'd14,
Ph1 = 5'd15,
Ph2 = 5'd16,
Ph3 = 5'd17,
RecoveryIdle = 5'd18,
recoverySpeedeieos = 5'd19,
recoveryWait = 5'd20,
Idle = 5'd31;

// Current/Next state

reg [4:0] state; // registered current state
reg [4:0] tx_exit_to; // combinational next state proposal
reg exit_to_flag; // combinational "take transition now" flag
reg [4:0] state_prev;
reg tx_finish_flag;


/* Timing constants in 100MHz cycles (1 tick = 10ns) */
localparam t0ms = 32'd0; // 0ms
localparam t2ms = 32'd200_000; // 2ms
localparam t12ms = 32'd1_200_000; // 12ms
localparam t24ms = 32'd2_400_000; // 24 ms
localparam t48ms = 32'd4_800_000; // 48ms

localparam t22_5ms = 32'd2_250_000; // 22.5ms
localparam t12_5ms = 32'd1_250_000; // 12.5ms
localparam t100us = 32'd10_000; // 100us


// Misc control/status 

reg [15:0] DetectStatus; // per-lane receiver detect status
reg speed_change; // request for rate-change during Recovery
reg [10:0] OSCount; // ordered-set counter
reg OSGeneratorFinish; // pulses when one OS is sent
reg TimeOut; // generic timeout flag (external logic)
reg [15:0] IDLEcount; // Idle OS Counter

// Pipe/OS-generator control 
reg turnOffScrambler_flag_next;
reg HoldFIFOData;
reg [15:0] ElecIdleReq;
reg [15:0] DetectReq;
reg [15:0] pipe_off;
reg MuxSel;
reg [1:0] OSType; // 00 : TS1, 01: TS2, 10: IDLE, 11: EIOS
reg [7:0] LaneNumber;
reg [7:0] LinkNumber;
reg [1:0] Rate;
reg Loopback;
reg OSGeneratorStart;
reg OSGeneratorBusy;

// CONSTANTS, paramaters (kept internal)
localparam integer LANESNUMBER = 16;
localparam [1:0] MAX_GEN = 2'b10; // example: Gen3 = 2'b10 if mapped so
localparam DownStream = 1'b0;
localparam DEVICETYPE = DownStream;

reg [7:0] assigned_lane_number, assigned_link_number;

// State-change

always@(posedge pclk or negedge rst_n)
begin
    if(!rst_n) begin
        state <= Idle;
        state_prev <= Idle;
        tx_finish_flag <= 1'b0;
    end
    else
    begin
        state_prev <= state;
        if (exit_to_flag) begin
            state <= tx_exit_to;
            tx_finish_flag <= 1'b1;
        end
        else begin
            tx_finish_flag <= 1'b0;
        end
            
    end
end

// "State Changed" Detecter

wire state_changed = (state_prev != state);

// Timeout-counter

always@(posedge pclk or negedge rst_n)
begin
    if(!rst_n) begin
        count <= 32'd0;
    end
    else if (state_changed) begin
        count <= 32'd0;
    end
    else begin
        case(state)
            DetectQuiet: count <= (count < t12ms)? count + 1 : 32'd0;
            DetectActive: count <= (count < t12ms)? count + 1 : 32'd0;
            PollingActive: count <= (count < t24ms)? count + 1 : 32'd0;
            PollingConfig: count <= (count < t48ms)? count + 1 : 32'd0;
            ConfigLinkWidthStart: count <= (count < t22_5ms)? count + 1 : 32'd0;
            ConfigLinkWidthAccept: count <= (count < t12_5ms)? count + 1 : 32'd0; 
            ConfigComplete: count <= (count < t22_5ms)? count + 1 : 32'd0; 
            ConfigIdle: count <= (count < t100us)? count + 1 : 32'd0; 
            RecoveryRcvrCfg: count <= (count < t48ms)? count + 1 : 32'd0; 
            RecoverySpeed: count <= (count < t48ms)? count + 1 : 32'd0; 
            RecoveryIdle: count <= (count < t2ms)? count + 1 : 32'd0; 
            default: count <= 32'd0;
        endcase
    end
end

always @(*) begin
// safe defaults
tx_exit_to = state;
exit_to_flag = 1'b0;

case (state)
    // DETECT
    DetectQuiet: begin
        if (count >= t12ms) begin
            tx_exit_to = DetectActive;
            exit_to_flag = 1'b1;
        end
    end
    
    DetectActive: begin
    
        if(|DetectStatus) begin
            tx_exit_to = PollingActive;
            exit_to_flag = 1'b1;
        end
        else if ((count >= t12ms) && (DetectStatus == 16'h0000)) begin
            tx_exit_to = DetectQuiet;
            exit_to_flag = 1'b1;
        end
    end
    
    // POLLING
    PollingActive: begin
        if (OSCount >= 11'd1024) begin
            tx_exit_to = PollingConfig;
            exit_to_flag = 1'b1;
        end
        else if (count >= t24ms) begin
            tx_exit_to = DetectQuiet;
            exit_to_flag = 1'b1;
        end
    end
    
    PollingConfig: begin
        if (OSCount >= 11'd16) begin
            tx_exit_to = ConfigLinkWidthStart;
            exit_to_flag = 1'b1;
        end
        else if (count >= t24ms) begin
            tx_exit_to = DetectQuiet;
            exit_to_flag = 1'b1;
        end
    end
    
    // CONFIGURATION
    ConfigLinkWidthStart: begin 
        if (OSCount >= 11'd16) begin
            tx_exit_to = ConfigLaneWidthAccept;
            exit_to_flag = 1'b1;
        end
        else if (count >= t22_5ms) begin
            tx_exit_to = DetectQuiet;
            exit_to_flag = 1'b1;
        end
    end
    
    ConfigLaneWidthAccept: begin
        if (OSCount >= 11'd16) begin
            tx_exit_to = ConfigComplete;
            exit_to_flag = 1'b1;
        end
        else if (count >= t12_5ms) begin
            tx_exit_to = DetectQuiet;
            exit_to_flag = 1'b1;
        end   
    end
    
    ConfigComplete: begin
        if (OSCount >= 11'd16) begin
            tx_exit_to = ConfigIdle;
            exit_to_flag = 1'b1;
        end
        else if (count >= t22_5ms) begin
            tx_exit_to = DetectQuiet;
            exit_to_flag = 1'b1;
        end       
    end
    
    ConfigIdle: begin
        if (OSCount >= 11'd16) begin
            tx_exit_to = L0;
            exit_to_flag = 1'b1;
        end
        else if (count >= t100us) begin
            tx_exit_to = DetectQuiet;
            exit_to_flag = 1'b1;
        end     
    end
    
    // RECOVERY
    RecoveryRcvrLock: begin
        if (OSCount >= 11'd32) begin
            tx_exit_to = RecoveryRcvrCfg;
            exit_to_flag = 1'b1;
        end  
    end
    
    RecoveryRcvrCfg: begin
        if (OSCount >= 11'd32) begin
            if (speed_change) begin
                tx_exit_to = RecoverySpeed;
                exit_to_flag = 1'b1;
            end else begin
                tx_exit_to = RecoveryIdle;
                exit_to_flag = 1'b1;
            end
        end      
    end
    
    RecoverySpeed: begin
        if (TimeOut && OSCount >= 11'd4) begin
            tx_exit_to = RecoveryRcvrLock;
            exit_to_flag = 1'b1;
        end
    end
    
    RecoveryIdle: begin
        if (OSCount >= 11'd16) begin
            tx_exit_to = L0;
            exit_to_flag = 1'b1;
        end     
    end

    
    default: begin
        tx_exit_to = state; // hold
        exit_to_flag = 1'b0;
    end
    
endcase
end

// Ordered Set Counter (OSCount)

always @(posedge pclk or negedge rst_n) begin
    if (!rst_n) begin
        OSCount <= 11'd0;
    end
    else if (state_changed) begin
        OSCount <= 11'd0;
    end
    else begin
        case(state)
            DetectQuiet,
            DetectActive,
            RecoveryRcvrCfg: begin
                OSCount <= 11'd0;
            end
            
            PollingActive,
            PollingConfig,
            ConfigLinkWidthStart,
            ConfigLaneWidthAccept,
            ConfigComplete,
            ConfigIdle,
            RecoverySpeed,
            RecoveryIdle : begin
                if(OSGeneratorFinish)
                    OSCount <= OSCount + 11'd1;
            end
            
            default: begin
                OSCount <= 11'd0;
            end
            
        endcase
    end
end

// PIPE, Ordered Set Generation control (combinational)

always @(*) begin
turnOffScrambler_flag_next = 1'b0;
HoldFIFOData = 1'b0;
ElecIdleReq = {LANESNUMBER{1'b0}};
DetectReq = {LANESNUMBER{1'b0}};
pipe_off = 16'h0000;
MuxSel = 1'b0; // 0: OSGen, 1: FIFO Data
OSType = 2'b11; // default to EIOS as a safe idle
LaneNumber = 8'hF7; // pad
LinkNumber = 8'hF7; // pad
Rate = MAX_GEN;
Loopback = 1'b0;
OSGeneratorStart = 1'b0;


case (state)
    DetectQuiet,
    DetectActive: begin
        turnOffScrambler_flag_next = 1'b1;
        HoldFIFOData = 1'b1;
        pipe_off = 16'hFFFF;
    end
    
    PollingActive: begin
        turnOffScrambler_flag_next = 1'b1;
        HoldFIFOData = 1'b1;
        pipe_off = 16'h0000;   // Turn ON
        MuxSel = 1'b0;
        
        if (!OSGeneratorBusy) begin
            OSType = 2'b00; // TS1
            LaneNumber = 8'hF7; // pad
            LinkNumber = 8'hF7; // pad  
            Rate = MAX_GEN;
            Loopback = 1'b0;
            OSGeneratorStart = 1'b1;         
        end
    end
    
    PollingConfig: begin // send TS2s
        turnOffScrambler_flag_next = 1'b1;
        HoldFIFOData = 1'b1;
        pipe_off = 16'h0000;   
        MuxSel = 1'b0;
        
        if (!OSGeneratorBusy) begin
            OSType = 2'b01; // TS2
            LaneNumber = 8'hF7; // pad
            LinkNumber = 8'hF7; // pad  
            Rate = MAX_GEN;
            OSGeneratorStart = 1'b1;         
        end   
    end
    
    ConfigLinkWidthStart: begin
        turnOffScrambler_flag_next = 1'b1;
        HoldFIFOData = 1'b1;
        pipe_off = 16'h0000;   
        MuxSel = 1'b0;
        
        if (!OSGeneratorBusy) begin
            OSType = 2'b00; // TS1
            LaneNumber = 8'hF7; // pad
            Rate = MAX_GEN;
            LinkNumber = (DEVICETYPE == DownStream)? assigned_link_number : 8'hF7;
            OSGeneratorStart = 1'b1;         
        end     
    end
    
    ConfigLaneWidthAccept: begin
        turnOffScrambler_flag_next = 1'b1;
        HoldFIFOData = 1'b1;
        pipe_off = 16'h0000;   
        MuxSel = 1'b0;
        
        if (!OSGeneratorBusy) begin
            OSType = 2'b00; // TS1
            LaneNumber = assigned_lane_number; 
            Rate = MAX_GEN;
            LinkNumber = (DEVICETYPE == DownStream)? assigned_link_number : 8'hF7;
            OSGeneratorStart = 1'b1;         
        end     
    end
    
    ConfigComplete: begin
        turnOffScrambler_flag_next = 1'b1;
        HoldFIFOData = 1'b1;
        pipe_off = 16'h0000;   
        MuxSel = 1'b0;
        
        if (!OSGeneratorBusy) begin
            OSType = 2'b01; // TS2
            LaneNumber = assigned_lane_number; 
            Rate = MAX_GEN;
            LinkNumber = (DEVICETYPE == DownStream)? assigned_link_number : 8'hF7;
            OSGeneratorStart = 1'b1;         
        end   
    end
    
    ConfigIdle: begin
        turnOffScrambler_flag_next = 1'b1;
        HoldFIFOData = 1'b1;
        pipe_off = 16'h0000;   
        MuxSel = 1'b0;
        
        if (!OSGeneratorBusy) begin
            OSType = 2'b11; // EIOS
            LaneNumber = 8'h00;
            LinkNumber = 8'h00;
            Rate = MAX_GEN;
            OSGeneratorStart = 1'b1;         
        end    
    end
    
    // RECOVERY
    RecoveryRcvrLock: begin
        turnOffScrambler_flag_next = 1'b1;
        HoldFIFOData = 1'b1;
        pipe_off = 16'h0000;   
        MuxSel = 1'b0;
        
        if (!OSGeneratorBusy) begin
            OSType = 2'b00; // TS1
            OSGeneratorStart = 1'b1;         
        end 
    end
    
    RecoveryRcvrCfg: begin
        turnOffScrambler_flag_next = 1'b1;
        HoldFIFOData = 1'b1;
        pipe_off = 16'h0000;   
        MuxSel = 1'b0;
        
        if (!OSGeneratorBusy) begin
            OSType = 2'b01; // TS2
            OSGeneratorStart = 1'b1;         
        end 
    end
    
    RecoverySpeed: begin
        turnOffScrambler_flag_next = 1'b1;
        HoldFIFOData = 1'b1;
        pipe_off = 16'h0000;   
        MuxSel = 1'b0;
        
        if (!OSGeneratorBusy) begin
            OSType = 2'b11; // EIOS
            OSGeneratorStart = 1'b1;         
        end 
    end
    
    RecoveryIdle: begin
        turnOffScrambler_flag_next = 1'b1;
        HoldFIFOData = 1'b1;
        pipe_off = 16'h0000;   
        MuxSel = 1'b0;
        
        if (!OSGeneratorBusy) begin
            OSType = 2'b10; // IDLE
            OSGeneratorStart = 1'b1;         
        end 
    end   
    
    default: begin
    
    end 
endcase
end

endmodule
