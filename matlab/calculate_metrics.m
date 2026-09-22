%% VOLT FUSION - Performance Metrics Calculator Module
% Computes peak battery current, RMS current, I^2 R losses, thermal rise proxy, and SC power metrics.
% File: calculate_metrics.m

function metrics = calculate_metrics(res, modeName)
    dt = res.dt;
    I_bat = res.I_bat;
    P_bat = res.P_bat;
    Loss_bat = res.Loss_bat;
    P_sc = res.P_sc;
    P_regen = res.P_regen;
    V_dc = res.V_dc;
    T_bat = res.T_bat;

    metrics.Mode = modeName;
    metrics.Peak_Battery_Current_A = max(abs(I_bat));
    metrics.RMS_Battery_Current_A = sqrt(mean(I_bat.^2));
    metrics.Std_Battery_Current_A = std(I_bat);
    metrics.Battery_Losses_kJ = sum(Loss_bat) * dt / 1000.0;
    metrics.Battery_Temp_Rise_C = T_bat(end) - T_bat(1);
    metrics.Peak_SC_Power_kW = max(abs(P_sc)) / 1000.0;
    metrics.Energy_Consumed_kWh = sum(max(0, P_bat)) * dt / 3600000.0;
    metrics.Regen_Energy_kWh = sum(P_regen) * dt / 3600000.0;
    metrics.DC_Bus_Ripple_V = max(V_dc) - min(V_dc);
end
