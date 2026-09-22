%% VOLT FUSION - Master MATLAB Simulation Script
% Runs complete Battery-Only vs HESS comparative simulations across standard drive cycles.
% File: run_simulation.m

function run_simulation(cycleName)
    if nargin < 1, cycleName = 'UDDS'; end
    
    clc;
    fprintf('============================================================\n');
    fprintf('VOLT FUSION - HYBRID ENERGY STORAGE SYSTEM SIMULATION\n');
    fprintf('============================================================\n');
    
    sys = initialize_model(cycleName);
    params = sys.params;
    dt = params.sim.sampleTime;
    
    t = sys.driveCycle.time;
    v = sys.driveCycle.velocity;
    a = sys.driveCycle.acceleration;
    N = length(t);
    
    % 1. Compute Traction Power Demand
    F_accel = params.vehicle.mass * a;
    F_roll = params.vehicle.Crr * params.vehicle.mass * params.vehicle.g * (v > 0.1);
    F_aero = 0.5 * params.vehicle.airDensity * params.vehicle.Cd * params.vehicle.frontalArea * (v.^2);
    F_total = F_accel + F_roll + F_aero;
    
    P_mech = F_total .* v;
    P_mech = min(params.motor.maxPower, max(-70000, P_mech));
    
    P_dc = zeros(size(P_mech));
    for k = 1:N
        if P_mech(k) >= 0
            P_dc(k) = P_mech(k) / (params.vehicle.drivetrainEff * params.motor.efficiency);
        else
            P_dc(k) = P_mech(k) * params.vehicle.drivetrainEff * params.motor.regenEfficiency;
        end
    end
    
    % Run modes
    modes = {'BATTERY_ONLY', 'RULE_BASED', 'LPF_HESS'};
    results = cell(1, 3);
    
    for m = 1:3
        mode = modes{m};
        fprintf('[Simulating] Running %s mode...\n', mode);
        
        % State vars init
        soc_bat = params.battery.initialSOC;
        v_rc_bat = 0;
        T_bat = params.battery.ambientTemp;
        
        v_sc = params.supercap.initialVoltage;
        v_sc_cap = params.supercap.initialVoltage;
        V_dc_bus = params.dclink.vRef;
        
        lpf_state = [];
        
        % Allocation arrays
        I_bat_arr = zeros(N,1); V_bat_arr = zeros(N,1); P_bat_arr = zeros(N,1);
        SOC_bat_arr = zeros(N,1); Loss_bat_arr = zeros(N,1); T_bat_arr = zeros(N,1);
        
        I_sc_arr = zeros(N,1); V_sc_arr = zeros(N,1); P_sc_arr = zeros(N,1);
        SOC_sc_arr = zeros(N,1); Loss_sc_arr = zeros(N,1);
        
        V_dc_arr = zeros(N,1); P_regen_arr = zeros(N,1);
        
        for k = 1:N
            P_dem = P_dc(k);
            
            % EMS Power Split
            if strcmp(mode, 'BATTERY_ONLY')
                P_bat_req = P_dem;
                P_sc_req = 0;
            elseif strcmp(mode, 'RULE_BASED')
                [P_bat_req, P_sc_req] = rule_based_ems(P_dem, soc_bat, v_sc, params);
            elseif strcmp(mode, 'LPF_HESS')
                [P_bat_req, P_sc_req, lpf_state] = low_pass_ems(P_dem, soc_bat, v_sc, lpf_state, dt, params);
            end
            
            % Converter & Hardware Limits
            [P_bat_act, P_sc_act] = limits(P_bat_req, P_sc_req, soc_bat, v_sc, params);
            
            % Battery Model Integration
            ocv = params.battery.nominalVoltage * (0.92 + 0.14 * soc_bat + 0.04 * log(max(0.001, soc_bat)));
            a_q = params.battery.Rint;
            b_q = -(ocv - v_rc_bat);
            c_q = P_bat_act;
            disc = b_q^2 - 4 * a_q * c_q;
            if disc >= 0
                I_bat = (-b_q - sqrt(disc)) / (2 * a_q);
            else
                I_bat = P_bat_act / max(1.0, ocv);
            end
            
            V_bat = ocv - I_bat * params.battery.Rint - v_rc_bat;
            dV_rc = (I_bat * params.battery.R_transient - v_rc_bat) / (params.battery.R_transient * params.battery.C_transient);
            v_rc_bat = v_rc_bat + dV_rc * dt;
            
            dSOC = -I_bat / (params.battery.capacityAh * 3600);
            soc_bat = min(0.98, max(0.05, soc_bat + dSOC * dt));
            
            P_loss_bat = (I_bat^2) * params.battery.Rint + (v_rc_bat^2) / params.battery.R_transient;
            dT_bat = (P_loss_bat - params.battery.hA * (T_bat - params.battery.ambientTemp)) / (params.battery.mass * params.battery.cp);
            T_bat = T_bat + dT_bat * dt;
            
            % Supercapacitor Model Integration
            if ~strcmp(mode, 'BATTERY_ONLY')
                a_sc = params.supercap.ESR;
                b_sc = -v_sc_cap;
                c_sc = P_sc_act;
                disc_sc = b_sc^2 - 4 * a_sc * c_sc;
                if disc_sc >= 0
                    I_sc = (-b_sc - sqrt(disc_sc)) / (2 * a_sc);
                else
                    I_sc = P_sc_act / max(1.0, v_sc_cap);
                end
                
                v_sc = v_sc_cap - I_sc * params.supercap.ESR;
                dV_cap = -I_sc / params.supercap.capacitance;
                v_sc_cap = min(params.supercap.maxVoltage, max(params.supercap.minVoltage, v_sc_cap + dV_cap * dt));
                v_sc = v_sc_cap - I_sc * params.supercap.ESR;
                
                P_loss_sc = (I_sc^2) * params.supercap.ESR;
                soc_sc = (v_sc_cap - params.supercap.minVoltage) / (params.supercap.maxVoltage - params.supercap.minVoltage);
            else
                I_sc = 0; P_sc_act = 0; v_sc = params.supercap.initialVoltage; P_loss_sc = 0; soc_sc = 1.0;
            end
            
            % DC Bus Voltage Regulation
            I_dc_net = (P_bat_act * params.converter.efficiency + P_sc_act * params.converter.efficiency - P_dem) / params.dclink.vRef;
            dV_dc = I_dc_net / params.dclink.capacitance;
            V_dc_bus = V_dc_bus + dV_dc * dt;
            V_dc_bus = params.dclink.vRef + 0.85 * (V_dc_bus - params.dclink.vRef) + 0.10 * (I_bat / 100.0);
            
            % Logging
            I_bat_arr(k) = I_bat; V_bat_arr(k) = V_bat; P_bat_arr(k) = P_bat_act;
            SOC_bat_arr(k) = soc_bat; Loss_bat_arr(k) = P_loss_bat; T_bat_arr(k) = T_bat;
            
            I_sc_arr(k) = I_sc; V_sc_arr(k) = v_sc; P_sc_arr(k) = P_sc_act;
            SOC_sc_arr(k) = soc_sc; Loss_sc_arr(k) = P_loss_sc;
            
            V_dc_arr(k) = V_dc_bus; P_regen_arr(k) = max(0, -P_dem);
        end
        
        res.time = t; res.velocity = v; res.acceleration = a; res.P_dem = P_dc; res.dt = dt;
        res.I_bat = I_bat_arr; res.V_bat = V_bat_arr; res.P_bat = P_bat_arr;
        res.SOC_bat = SOC_bat_arr; res.Loss_bat = Loss_bat_arr; res.T_bat = T_bat_arr;
        res.I_sc = I_sc_arr; res.V_sc = V_sc_arr; res.P_sc = P_sc_arr;
        res.SOC_sc = SOC_sc_arr; res.Loss_sc = Loss_sc_arr;
        res.V_dc = V_dc_arr; res.P_regen = P_regen_arr;
        
        results{m} = res;
    end
    
    res_bat = results{1}; res_rule = results{2}; res_lpf = results{3};
    
    % Metrics calculation
    m_bat = calculate_metrics(res_bat, 'Battery-Only Baseline');
    m_rule = calculate_metrics(res_rule, 'HESS Rule-Based EMS');
    m_lpf = calculate_metrics(res_lpf, 'HESS Low-Pass Filter EMS');
    
    T = compare_results(m_bat, m_rule, m_lpf);
    generate_plots(res_bat, res_rule, res_lpf, m_bat, m_rule, m_lpf);
    export_results(T, res_lpf);
    
    fprintf('\n[COMPLETE] Simulation run finished successfully for cycle %s!\n', cycleName);
end
