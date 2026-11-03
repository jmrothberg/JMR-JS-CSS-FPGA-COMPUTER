// Canvas-space absolute mouse samples -> ordered JavaScript events.
// Packet layout: {type[1:0], x[9:0], y[8:0], buttons[2:0], button[1:0],
//                 signed movementX[10:0], signed movementY[10:0]}.
// Types: 0 move, 1 down, 2 up, 3 primary click. DOM button numbering.
// Producers must hold/retry a sample until sample_ready. Six queue slots
// are reserved before accepting it, so no button edge is silently lost.
module jmr_mouse_events (
    input logic clk, rst_n,
    input logic sample_valid,
    output logic sample_ready,
    input logic [9:0] sample_x,
    input logic [8:0] sample_y,
    input logic [2:0] sample_buttons,
    output logic event_valid,
    output logic [47:0] event_data,
    input logic event_pop
);
    (* ram_style = "distributed" *) logic [47:0] fifo [0:63];
    logic [5:0] wp, rp;
    logic [6:0] count;
    logic [2:0] phase;
    logic [9:0] old_x, x;
    logic [8:0] old_y, y;
    logic [2:0] old_buttons, buttons, changed;
    logic signed [10:0] dx, dy;
    logic enqueue;
    logic [47:0] enqueue_data;
    logic pop_q;
    wire dequeue = event_pop && !pop_q && event_valid;
    assign event_valid = count != 0;
    assign event_data = fifo[rp];
    assign sample_ready = phase == 0 && count <= 58;
    always_comb begin
        enqueue = 0;
        enqueue_data = 0;
        case (phase)
            1: if (dx != 0 || dy != 0) begin
                enqueue = 1;
                enqueue_data = {2'd0,x,y,old_buttons,2'd0,dx,dy};
            end
            2: if (changed[0]) begin
                enqueue = 1;
                enqueue_data = {buttons[0] ? 2'd1 : 2'd2,x,y,buttons,2'd0,22'd0};
            end
            3: if (changed[0] && !buttons[0]) begin
                enqueue = 1;
                enqueue_data = {2'd3,x,y,buttons,2'd0,22'd0};
            end
            4: if (changed[1]) begin
                enqueue = 1;
                enqueue_data = {buttons[1] ? 2'd1 : 2'd2,x,y,buttons,2'd2,22'd0};
            end
            5: if (changed[2]) begin
                enqueue = 1;
                enqueue_data = {buttons[2] ? 2'd1 : 2'd2,x,y,buttons,2'd1,22'd0};
            end
            default: ;
        endcase
    end
    always_ff @(posedge clk)
        if (enqueue) fifo[wp] <= enqueue_data;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wp <= 0; rp <= 0; count <= 0; phase <= 0; pop_q <= 0;
            old_x <= 320; old_y <= 240; old_buttons <= 0;
            x <= 320; y <= 240; buttons <= 0; changed <= 0; dx <= 0; dy <= 0;
        end else begin
            pop_q <= event_pop;
            case ({enqueue,dequeue})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: ;
            endcase
            if (enqueue) wp <= wp + 1'b1;
            if (dequeue) rp <= rp + 1'b1;
            if (phase == 0) begin
                if (sample_valid && sample_ready) begin
                    x <= sample_x > 639 ? 10'd639 : sample_x;
                    y <= sample_y > 479 ? 9'd479 : sample_y;
                    buttons <= sample_buttons;
                    changed <= old_buttons ^ sample_buttons;
                    dx <= $signed({1'b0,(sample_x > 639 ? 10'd639 : sample_x)}) - $signed({1'b0,old_x});
                    dy <= $signed({2'b0,(sample_y > 479 ? 9'd479 : sample_y)}) - $signed({2'b0,old_y});
                    phase <= 1;
                end
            end else if (phase == 5) begin
                old_x <= x; old_y <= y; old_buttons <= buttons; phase <= 0;
            end else phase <= phase + 1'b1;
        end
    end
endmodule
