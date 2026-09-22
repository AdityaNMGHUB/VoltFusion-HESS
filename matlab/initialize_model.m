%% VOLT FUSION - Model Initialization Script
% Initializes workspace parameters, drive cycle data, and model settings.
% File: initialize_model.m

function sys = initialize_model(cycleName)
    if nargin < 1
        cycleName = 'UDDS';
    end

    % Load parameters
    addpath(fullfile(pwd, 'matlab'));
    addpath(fullfile(pwd, 'controllers'));
    addpath(fullfile(pwd, 'drive_cycles'));
    
    params = parameters();
    params.sim.driveCycle = cycleName;
    
    % Generate drive cycle velocity profile
    driveCycleData = generate_drive_cycles(cycleName, params.sim.sampleTime);
    
    sys.params = params;
    sys.driveCycle = driveCycleData;
    
    fprintf('[VoltFusion] Initialized parameters & drive cycle: %s (Duration: %.1fs)\n', ...
        cycleName, driveCycleData.time(end));
end
