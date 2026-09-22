%% VOLT FUSION - Visualization & Publication Plotting Suite
% Generates 10 high-resolution MATLAB figures comparing Battery-Only vs HESS strategies.
% File: generate_plots.m

function generate_plots(res_bat, res_rule, res_lpf, metrics_bat, metrics_rule, metrics_lpf)
    t = res_lpf.time;
    
    % Figure 1: Drive Cycle & Power Demand
    figure('Name', 'Fig 1: Drive Cycle Profile', 'Color', 'w', 'Position', [100 100 900 500]);
    subplot(2,1,1);
    plot(t, res_lpf.velocity * 3.6, 'Color', [0 0.2 0.6], 'LineWidth', 1.5);
    title('EPA UDDS Drive Cycle Profile');
    ylabel('Velocity (km/h)'); grid on;
    subplot(2,1,2);
    plot(t, res_lpf.P_dem / 1000, 'Color', [0.8 0.1 0.1], 'LineWidth', 1.2);
    title('Traction Power Demand');
    xlabel('Time (s)'); ylabel('Power (kW)'); grid on;
    saveas(gcf, fullfile('results', 'figures', 'matlab_01_drive_cycle.png'));
    
    % Figure 2: Battery Current Comparison
    figure('Name', 'Fig 2: Battery Current Comparison', 'Color', 'w', 'Position', [100 100 900 450]);
    plot(t, res_bat.I_bat, 'Color', [0.7 0 0], 'LineWidth', 1.0); hold on;
    plot(t, res_rule.I_bat, 'Color', [0.9 0.5 0], 'LineWidth', 1.2);
    plot(t, res_lpf.I_bat, 'Color', [0 0.5 0.5], 'LineWidth', 1.5);
    title(sprintf('Battery Current Comparison (Peak Shaving: %.1f%% Reduction)', ...
        (metrics_bat.Peak_Battery_Current_A - metrics_lpf.Peak_Battery_Current_A)/metrics_bat.Peak_Battery_Current_A * 100));
    xlabel('Time (s)'); ylabel('Battery Current (A)');
    legend('Battery-Only Baseline', 'HESS Rule-Based', 'HESS Low-Pass Filter', 'Location', 'northright');
    grid on;
    saveas(gcf, fullfile('results', 'figures', 'matlab_02_battery_current.png'));
    
    % Figure 3: Battery Power Allocation
    figure('Name', 'Fig 3: Battery Power Peak Shaving', 'Color', 'w', 'Position', [100 100 900 450]);
    plot(t, res_bat.P_bat / 1000, 'Color', [0.8 0 0], 'LineWidth', 1.0); hold on;
    plot(t, res_lpf.P_bat / 1000, 'Color', [0 0.1 0.5], 'LineWidth', 1.5);
    title('Battery Power Demand Peak-Shaving');
    xlabel('Time (s)'); ylabel('Power (kW)');
    legend('Battery Power (Battery-Only)', 'Battery Power (HESS LPF)', 'Location', 'northright');
    grid on;
    saveas(gcf, fullfile('results', 'figures', 'matlab_03_battery_power.png'));
    
    % Figure 4: Battery SOC Trajectory
    figure('Name', 'Fig 4: Battery SOC Profile', 'Color', 'w', 'Position', [100 100 900 450]);
    plot(t, res_bat.SOC_bat * 100, 'Color', [0.8 0 0], 'LineWidth', 1.5); hold on;
    plot(t, res_lpf.SOC_bat * 100, 'Color', [0 0.5 0.5], 'LineWidth', 1.8);
    title('Battery State-of-Charge (SOC) Depletion Trajectory');
    xlabel('Time (s)'); ylabel('Battery SOC (%)');
    legend('Battery-Only Baseline', 'HESS LPF Mode', 'Location', 'northright');
    grid on;
    saveas(gcf, fullfile('results', 'figures', 'matlab_04_battery_soc.png'));

    % Figure 5: Supercapacitor Voltage & SOC
    figure('Name', 'Fig 5: Supercapacitor Voltage', 'Color', 'w', 'Position', [100 100 900 500]);
    subplot(2,1,1);
    plot(t, res_lpf.V_sc, 'Color', [0 0.5 0], 'LineWidth', 1.5);
    title('Supercapacitor Terminal Voltage (V)');
    ylabel('Voltage (V)'); grid on;
    subplot(2,1,2);
    plot(t, res_lpf.SOC_sc * 100, 'Color', [0.2 0.7 0.2], 'LineWidth', 1.5);
    title('Supercapacitor SOC (%)');
    xlabel('Time (s)'); ylabel('SOC (%)'); grid on;
    saveas(gcf, fullfile('results', 'figures', 'matlab_05_supercap_voltage.png'));

    % Figure 6: Supercapacitor Power Trajectory
    figure('Name', 'Fig 6: Supercap Power', 'Color', 'w', 'Position', [100 100 900 450]);
    plot(t, res_lpf.P_sc / 1000, 'Color', [0.1 0.6 0.2], 'LineWidth', 1.2);
    title('Supercapacitor Transient Power Buffer');
    xlabel('Time (s)'); ylabel('SC Power (kW)'); grid on;
    saveas(gcf, fullfile('results', 'figures', 'matlab_06_supercap_power.png'));

    % Figure 7: DC Bus Voltage Regulation
    figure('Name', 'Fig 7: DC-Link Voltage', 'Color', 'w', 'Position', [100 100 900 450]);
    plot(t, res_lpf.V_dc, 'Color', [0.5 0 0.5], 'LineWidth', 1.2);
    title('400V DC-Link Voltage Stability');
    xlabel('Time (s)'); ylabel('DC Bus Voltage (V)'); grid on;
    saveas(gcf, fullfile('results', 'figures', 'matlab_07_dclink_voltage.png'));

    % Figure 8: Regenerative Braking Split
    figure('Name', 'Fig 8: Regen Braking Split', 'Color', 'w', 'Position', [100 100 900 450]);
    plot(t, res_lpf.P_regen / 1000, 'k:', 'LineWidth', 1.0); hold on;
    plot(t, -min(0, res_lpf.P_sc)/1000, 'Color', [0.1 0.6 0.2], 'LineWidth', 1.5);
    plot(t, -min(0, res_lpf.P_bat)/1000, 'Color', [0 0.5 0.5], 'LineWidth', 1.5);
    title('Regenerative Braking Power Distribution');
    xlabel('Time (s)'); ylabel('Regen Power (kW)');
    legend('Total Regen Available', 'SC Regen Absorption', 'Battery Regen Absorption');
    grid on;
    saveas(gcf, fullfile('results', 'figures', 'matlab_08_regen_split.png'));

    % Figure 9: Battery Losses & Thermal Stress
    figure('Name', 'Fig 9: Battery Losses', 'Color', 'w', 'Position', [100 100 900 500]);
    subplot(2,1,1);
    plot(t, cumsum(res_bat.Loss_bat)*res_bat.dt/1000, 'Color', [0.8 0 0], 'LineWidth', 1.5); hold on;
    plot(t, cumsum(res_lpf.Loss_bat)*res_lpf.dt/1000, 'Color', [0 0.5 0.5], 'LineWidth', 1.8);
    title(sprintf('Cumulative Battery I^2 R Losses (%.1f%% Savings)', ...
        (metrics_bat.Battery_Losses_kJ - metrics_lpf.Battery_Losses_kJ)/metrics_bat.Battery_Losses_kJ*100));
    ylabel('Losses (kJ)'); legend('Battery-Only', 'HESS LPF'); grid on;
    subplot(2,1,2);
    plot(t, res_bat.T_bat, 'Color', [0.8 0 0], 'LineWidth', 1.5); hold on;
    plot(t, res_lpf.T_bat, 'Color', [0 0.5 0.5], 'LineWidth', 1.8);
    title('Battery Thermal Profile Proxy');
    xlabel('Time (s)'); ylabel('Temperature (deg C)'); grid on;
    saveas(gcf, fullfile('results', 'figures', 'matlab_09_battery_thermal.png'));

    % Figure 10: Frequency Split Spectrum
    figure('Name', 'Fig 10: Power Spectrum Split', 'Color', 'w', 'Position', [100 100 900 450]);
    plot(t, res_lpf.P_dem / 1000, 'Color', [0.8 0.1 0.1 0.4], 'LineWidth', 1.0); hold on;
    plot(t, res_lpf.P_bat / 1000, 'Color', [0 0 0.6], 'LineWidth', 1.8);
    plot(t, res_lpf.P_sc / 1000, 'Color', [0.1 0.6 0.2], 'LineWidth', 1.2);
    title('Frequency-Decoupled Power Distribution (LPF EMS)');
    xlabel('Time (s)'); ylabel('Power (kW)');
    legend('Total Demand P_{dem}', 'Filtered Battery Power P_{bat}', 'Transient SC Power P_{sc}');
    grid on;
    saveas(gcf, fullfile('results', 'figures', 'matlab_10_frequency_split.png'));
    
    fprintf('[Plots] Successfully saved 10 MATLAB figures to results/figures/\n');
end
