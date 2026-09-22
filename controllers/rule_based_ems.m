%% VOLT FUSION - Rule-Based Energy Management Strategy (EMS)
% Logic-driven power split between Battery and Supercapacitor.
% File: rule_based_ems.m

function [P_bat_cmd, P_sc_cmd] = rule_based_ems(P_dem, bat_soc, sc_v, params)
    p_low_thresh = params.control.pBatteryLowThresh;
    p_bat_max_cont = params.control.pBatteryMaxContinuous;
    v_sc_nom = params.supercap.initialVoltage;
    v_sc_min = params.supercap.minVoltage;
    v_sc_max = params.supercap.maxVoltage;
    
    if P_dem >= 0
        % ACCELERATION / TRACTION DEMAND
        if P_dem <= p_low_thresh
            % Low power demand -> Battery supplies 100%
            P_bat_req = P_dem;
            P_sc_req = 0;
        elseif P_dem <= p_bat_max_cont
            % Moderate power demand -> Battery supplies base, SC assists slightly
            P_bat_req = p_low_thresh + 0.5 * (P_dem - p_low_thresh);
            P_sc_req = P_dem - P_bat_req;
        else
            % High transient peak acceleration -> Battery capped at continuous limit, SC handles transient peak
            P_bat_req = p_bat_max_cont;
            P_sc_req = P_dem - P_bat_req;
        end
        
        % Check if SC voltage is depleted
        if sc_v <= v_sc_min + 10.0
            % Supercap low -> transfer unsupplied load to battery
            P_bat_req = P_bat_req + P_sc_req;
            P_sc_req = 0;
        end
        
    else
        % REGENERATIVE BRAKING DEMAND (P_dem < 0)
        % Supercapacitor preferentially absorbs high-power braking energy pulse
        if sc_v < v_sc_max - 5.0
            % SC has headroom -> SC absorbs braking pulse up to its max current limit
            p_sc_max_regen = params.supercap.maxCurrent * sc_v;
            P_sc_req = max(P_dem, -p_sc_max_regen);
            P_bat_req = P_dem - P_sc_req; % Battery absorbs leftover if any
        else
            % SC full -> Battery absorbs all regen power
            P_sc_req = 0;
            P_bat_req = P_dem;
        end
    end
    
    % SC Voltage Restoration Mode: If vehicle is stopped or low load, recharge SC slowly from battery if needed
    if P_dem < 2000 && P_dem >= 0 && sc_v < v_sc_nom && bat_soc > 0.40
        p_recharge = 3000; % 3 kW slow trickle charge from battery to SC
        P_bat_req = P_bat_req + p_recharge;
        P_sc_req = P_sc_req - p_recharge;
    end
    
    % Apply physical protection bounds
    [P_bat_cmd, P_sc_cmd] = limits(P_bat_req, P_sc_req, bat_soc, sc_v, params);
end
