`timescale 1us / 1ps

module ARTAU(
        input radar_echo,
        input scan_for_target,
        input [31:0] jet_speed,
        input [31:0] max_safe_distance,
        input RST,
        input CLK,
        output reg radar_pulse_trigger,
        output reg [31:0] distance_to_target,
        output reg threat_detected,
        output reg [1:0] ARTAU_state
    );

    parameter NULL = 1_000_000;
    parameter LIGHT_SPEED = 300_000_000;

    // bools
    reg switch_to_listening = 0; 
    reg switch_to_assessing = 0; 
    reg switch_to_emitting = 0; 

    reg time_clk = 0;
    integer pulse_count = 0;
    reg [31:0] old_distance_to_target = 0;

    reg [63:0] pulse_emmision_started_at = NULL; 
    reg [63:0] listen_to_echo_started_at = NULL; 
    reg [63:0] status_update_timer_started_at = NULL; 

    initial begin
        forever #1 time_clk = $time;
    end

    initial begin
        radar_pulse_trigger = 0;
        distance_to_target = 0;
        threat_detected = 0;
        ARTAU_state = 0;
        pulse_count = 0;
        pulse_emmision_started_at = NULL;
        listen_to_echo_started_at = NULL;
        status_update_timer_started_at = NULL;
    end

    always @(posedge CLK) begin
        if (RST) begin
            radar_pulse_trigger = 0;
            distance_to_target = 0;
            threat_detected = 0;
            ARTAU_state = 0;
            pulse_count = 0;
            pulse_emmision_started_at = NULL;
            listen_to_echo_started_at = NULL;
            status_update_timer_started_at = NULL;
        end
        else begin
            case (ARTAU_state)
                2'b00, 2'b11: begin
                    if (switch_to_emitting) begin
                        switch_to_emitting = 0;
                        ARTAU_state <= 2'b01;
                    end
                end
                2'b01: begin
                    if (switch_to_listening) begin
                        switch_to_listening = 0;
                        ARTAU_state = 2'b10;
                    end
                end
                2'b10: begin
                    if ($time - listen_to_echo_started_at >= 2000) begin
                        listen_to_echo_started_at = NULL;
                        ARTAU_state <= 2'b00;

                        radar_pulse_trigger = 0;    
                        distance_to_target = 0;
                        threat_detected = 0;
                        ARTAU_state = 0;
                        pulse_count = 0;
                        pulse_emmision_started_at = NULL;
                        listen_to_echo_started_at = NULL;
                        status_update_timer_started_at = NULL;
                    end
                    if (switch_to_assessing) begin
                        switch_to_assessing = 0;
                        ARTAU_state <= 2'b11;
                    end
                    if (switch_to_emitting) begin
                        switch_to_emitting = 0;
                        ARTAU_state <= 2'b01;
                    end
                end
                2'b11: begin
                    if (($time - status_update_timer_started_at) >= 3000 & scan_for_target == 0) begin
                        status_update_timer_started_at = NULL;
                        ARTAU_state <= 2'b00;

                        radar_pulse_trigger = 0;
                        distance_to_target = 0;
                        threat_detected = 0;
                        ARTAU_state = 0;
                        pulse_count = 0;
                        pulse_emmision_started_at = NULL;
                        listen_to_echo_started_at = NULL;
                        status_update_timer_started_at = NULL;
                    end
                end
            endcase
        end
    end

    always @(time_clk) begin
        case (ARTAU_state)
            2'b00, 2'b11: begin
                if (scan_for_target) begin
                    if (switch_to_emitting == 0) begin
                        if (pulse_count > 0)
                            distance_to_target = LIGHT_SPEED * ($time - listen_to_echo_started_at) / 2;
                        radar_pulse_trigger = 1;
                        pulse_emmision_started_at = $time;
                        pulse_count = pulse_count + 1;
                        switch_to_emitting = 1;
                    end
                end
            end
            2'b01: begin
                if (($time - pulse_emmision_started_at) >= 300) begin
                    if (switch_to_listening == 0) begin
                        pulse_emmision_started_at = NULL;
                        radar_pulse_trigger = 0;
                        listen_to_echo_started_at = $time;
                        switch_to_listening = 1;
                    end
                end
            end
            2'b10: begin
                if (radar_echo & pulse_count == 1) begin
                    if (switch_to_emitting == 0) begin
                        if (pulse_count > 0)
                            distance_to_target = LIGHT_SPEED * ($time - listen_to_echo_started_at) / 1000_000 / 2;
                        radar_pulse_trigger = 1;
                        pulse_emmision_started_at = $time;
                        pulse_count = pulse_count + 1;
                        switch_to_emitting = 1;
                    end
                end
                else if (switch_to_emitting == 0 & radar_echo & pulse_count == 2) begin
                    if (switch_to_assessing == 0) begin
                        old_distance_to_target = distance_to_target;
                        distance_to_target = LIGHT_SPEED * ($time - listen_to_echo_started_at) / 1000_000 / 2;
                        if (distance_to_target + jet_speed * ($time - listen_to_echo_started_at) < old_distance_to_target)begin
                            if (distance_to_target < max_safe_distance) begin
                                threat_detected = 1;
                            end
                        end
                        status_update_timer_started_at = $time;
                        pulse_count = 0;
                        switch_to_assessing = 1;
                    end
                end
            end
            2'b11: begin

            end
        endcase
    end

endmodule