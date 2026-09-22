%% VOLT FUSION - Control Safety & Saturation Limits Module
% Enforces physical hardware boundaries for Battery, Supercapacitor, DC Bus, and Converters.
% File: limits.m

function [P_bat_bounded, P_sc_bounded] = limits(P_bat_req, P_sc_req, bat_soc, sc_v, params)
    % Extract limits
    min_soc = params.battery.minSOC;
    max_soc = params.battery.maxSOC;
    i_bat_dis_max = params.battery.maxDischargeCurrent;
    i_bat_chg_max = params.battery.maxChargeCurrent;
    v_bat_nom = params.battery.nominalVoltage;
    
    v_sc_min = params.supercap.minVoltage;
    v_sc_max = params.supercap.maxVoltage;
    i_sc_max = params.supercap.maxCurrent;
    
    % 1. Battery Power Saturation
    p_bat_max_dis = i_bat_dis_max * v_bat_nom;
    p_bat_max_chg = -i_bat_chg_max * v_bat_nom;
    
    P_bat_bounded = P_bat_req;
    
    % SOC Protection
    if bat_soc <= min_soc && P_bat_bounded > 0
        P_bat_bounded = 0; % Prevent discharge below min SOC
    elseif bat_soc >= max_soc && P_bat_bounded < 0
        P_bat_bounded = 0; % Prevent charging above max SOC
    end
    
    % Current/Power Saturation
    P_bat_bounded = min(p_bat_max_dis, max(p_bat_max_chg, P_bat_bounded));
    
    % 2. Supercapacitor Power Saturation
    p_sc_max_dis = i_sc_max * sc_v;
    p_sc_max_chg = -i_sc_max * sc_v;
    
    P_sc_bounded = P_sc_req;
    
    % SC Voltage Protection
    if sc_v <= v_sc_min && P_sc_bounded > 0
        P_sc_bounded = 0; % Cannot discharge SC if voltage is at min limit
    elseif sc_v >= v_sc_max && P_sc_bounded < 0
        P_sc_bounded = 0; % Cannot charge SC if voltage is at max limit
    end
    
    % Current/Power Saturation
    P_sc_bounded = min(p_sc_max_dis, max(p_sc_max_chg, P_sc_bounded));
end
