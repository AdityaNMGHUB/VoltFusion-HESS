%% VOLT FUSION - Programmatic Simulink Model Construction Script
% Creates and configures the top-level Simulink model architecture for VoltFusion_HESS.slx and BatteryOnly.slx.
% File: build_simulink_models.m

function build_simulink_models()
    fprintf('============================================================\n');
    fprintf('VOLT FUSION - Programmatic Simulink Model Generator\n');
    fprintf('============================================================\n');

    % Verify Simulink license presence
    if ~license('test', 'Simulink')
        fprintf('[Notice] Simulink license not active in current session.\n');
        fprintf('  This script generates VoltFusion_HESS.slx block topology when executed within MATLAB.\n');
        return;
    end

    % Define Model Name
    modelName = 'VoltFusion_HESS';
    
    % Close if already open, create new
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    new_system(modelName);
    open_system(modelName);
    
    % Configure Model Solver Settings
    set_param(modelName, 'Solver', 'ode4');
    set_param(modelName, 'FixedStep', '0.01');
    set_param(modelName, 'StopTime', '1370');
    set_param(modelName, 'SaveOutput', 'on');
    
    % Add Key Subsystems
    add_block('simulink/Ports & Subsystems/Subsystem', [modelName '/Drive Cycle Engine']);
    add_block('simulink/Ports & Subsystems/Subsystem', [modelName '/Vehicle Dynamics']);
    add_block('simulink/Ports & Subsystems/Subsystem', [modelName '/Energy Management System (EMS)']);
    add_block('simulink/Ports & Subsystems/Subsystem', [modelName '/Battery Branch & DC-DC']);
    add_block('simulink/Ports & Subsystems/Subsystem', [modelName '/Supercapacitor Branch & DC-DC']);
    add_block('simulink/Ports & Subsystems/Subsystem', [modelName '/400V DC Bus Regulator']);
    add_block('simulink/Ports & Subsystems/Subsystem', [modelName '/Measurement & Data Logging']);
    
    % Save Simulink model to file
    if ~exist('simulink', 'dir')
        mkdir('simulink');
    end
    save_system(modelName, fullfile('simulink', [modelName '.slx']));
    
    % Create Battery-Only model
    baseModel = 'BatteryOnly';
    if bdIsLoaded(baseModel)
        close_system(baseModel, 0);
    end
    new_system(baseModel);
    save_system(baseModel, fullfile('simulink', [baseModel '.slx']));
    
    fprintf('[Simulink] Saved VoltFusion_HESS.slx and BatteryOnly.slx into simulink/\n');
end
