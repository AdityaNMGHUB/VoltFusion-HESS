%% VOLT FUSION - Data Export Handler
% Exports metric tables and time-series vectors to CSV and MAT formats.
% File: export_results.m

function export_results(T, res_lpf)
    % Create output paths
    if ~exist(fullfile('results', 'tables'), 'dir')
        mkdir(fullfile('results', 'tables'));
    end
    if ~exist(fullfile('results', 'simulation_data'), 'dir')
        mkdir(fullfile('results', 'simulation_data'));
    end

    % 1. Write Summary Table CSV
    writetable(T, fullfile('results', 'tables', 'summary_metrics_matlab.csv'));
    
    % 2. Save Time-Series Simulation Data
    simData.time = res_lpf.time;
    simData.velocity = res_lpf.velocity;
    simData.P_demand = res_lpf.P_dem;
    simData.I_battery = res_lpf.I_bat;
    simData.P_battery = res_lpf.P_bat;
    simData.SOC_battery = res_lpf.SOC_bat;
    simData.V_supercap = res_lpf.V_sc;
    simData.P_supercap = res_lpf.P_sc;
    simData.V_dclink = res_lpf.V_dc;
    
    save(fullfile('results', 'simulation_data', 'hess_simulation_results.mat'), '-struct', 'simData');
    fprintf('[Export] Exported summary table to CSV and time-series data to MAT file.\n');
end
