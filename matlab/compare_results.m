%% VOLT FUSION - Results Comparison & Table Generator
% Displays side-by-side metric comparison table and percentage improvements.
% File: compare_results.m

function T = compare_results(m_bat, m_rule, m_lpf)
    Mode = {'Battery-Only Baseline'; 'HESS Rule-Based EMS'; 'HESS Low-Pass Filter EMS'};
    Peak_Current_A = [m_bat.Peak_Battery_Current_A; m_rule.Peak_Battery_Current_A; m_lpf.Peak_Battery_Current_A];
    RMS_Current_A = [m_bat.RMS_Battery_Current_A; m_rule.RMS_Battery_Current_A; m_lpf.RMS_Battery_Current_A];
    Battery_Losses_kJ = [m_bat.Battery_Losses_kJ; m_rule.Battery_Losses_kJ; m_lpf.Battery_Losses_kJ];
    Temp_Rise_C = [m_bat.Battery_Temp_Rise_C; m_rule.Battery_Temp_Rise_C; m_lpf.Battery_Temp_Rise_C];
    Peak_SC_Power_kW = [m_bat.Peak_SC_Power_kW; m_rule.Peak_SC_Power_kW; m_lpf.Peak_SC_Power_kW];
    Energy_Consumed_kWh = [m_bat.Energy_Consumed_kWh; m_rule.Energy_Consumed_kWh; m_lpf.Energy_Consumed_kWh];
    
    T = table(Mode, Peak_Current_A, RMS_Current_A, Battery_Losses_kJ, Temp_Rise_C, Peak_SC_Power_kW, Energy_Consumed_kWh);
    
    disp('================================================================================');
    disp('VOLT FUSION PERFORMANCE COMPARISON SUMMARY');
    disp('================================================================================');
    disp(T);
    
    peak_imp = (m_bat.Peak_Battery_Current_A - m_lpf.Peak_Battery_Current_A) / m_bat.Peak_Battery_Current_A * 100;
    rms_imp = (m_bat.RMS_Battery_Current_A - m_lpf.RMS_Battery_Current_A) / m_bat.RMS_Battery_Current_A * 100;
    loss_imp = (m_bat.Battery_Losses_kJ - m_lpf.Battery_Losses_kJ) / m_bat.Battery_Losses_kJ * 100;
    
    fprintf('\nKey Improvements (HESS LPF vs Battery-Only Baseline):\n');
    fprintf('  • Peak Battery Current Reduction : %.2f%%\n', peak_imp);
    fprintf('  • RMS Battery Current Reduction  : %.2f%%\n', rms_imp);
    fprintf('  • Battery I^2 R Loss Reduction   : %.2f%%\n', loss_imp);
    disp('================================================================================');
end
