%% VOLT FUSION - Frequency-Decoupled Low-Pass Filter (LPF) EMS
% Splits power demand into low-frequency (Battery) and high-frequency (Supercapacitor) spectra.
% File: low_pass_ems.m

function [P_bat_cmd, P_sc_cmd, state_next] = low_pass_ems(P_dem, bat_soc, sc_v, state_prev, dt, params)
    tau = params.control.lpfTau;
    v_sc_ref = params.supercap.initialVoltage;
    
    % Initialize discrete filter state if empty
    if isempty(state_prev)
        state_prev.P_bat_filtered = 0;
        state_prev.v_sc_err_int = 0;
    end
    
    % 1. Continuous/Discrete Low-Pass Filter step:
    % P_bat_filt(k) = P_bat_filt(k-1) + (dt / (tau + dt)) * (P_dem - P_bat_filt(k-1))
    alpha = dt / (tau + dt);
    P_bat_filtered = state_prev.P_bat_filtered + alpha * (P_dem - state_prev.P_bat_filtered);
    
    % 2. SC State of Charge / Voltage Restoration Controller (PI control)
    v_sc_err = v_sc_ref - sc_v;
    v_sc_err_int = state_prev.v_sc_err_int + v_sc_err * dt;
    % Clamp integral accumulator to prevent windup
    v_sc_err_int = min(500, max(-500, v_sc_err_int));
    
    P_sc_recharge = params.control.scKp * v_sc_err + params.control.scKi * v_sc_err_int;
    
    % 3. Raw Power Allocations
    % Battery handles filtered low-frequency power + slow SC voltage restoration demand
    P_bat_raw = P_bat_filtered + P_sc_recharge;
    
    % Supercapacitor handles high-frequency transient power
    P_sc_raw = P_dem - P_bat_raw;
    
    % 4. Hardware limit enforcement
    [P_bat_cmd, P_sc_cmd] = limits(P_bat_raw, P_sc_raw, bat_soc, sc_v, params);
    
    % Update controller state vector
    state_next.P_bat_filtered = P_bat_filtered;
    state_next.v_sc_err_int = v_sc_err_int;
end
