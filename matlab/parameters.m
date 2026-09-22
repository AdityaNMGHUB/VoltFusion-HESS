%% VOLT FUSION - Centralized System Parameters Script
% Project: Hybrid Energy Storage System (HESS) for Electric Vehicles
% Authors: Senior Power Electronics & EV Systems Engineering Team
% File: parameters.m

function params = parameters()
    %% 1. SIMULATION SETTINGS
    params.sim.sampleTime = 0.01;            % Simulation step size (s)
    params.sim.solver = 'ode4';               % Fixed-step Runge-Kutta solver
    params.sim.driveCycle = 'UDDS';          % Default drive cycle ('UDDS' or 'WLTP')
    params.sim.duration = 1370;              % Simulation length for UDDS (s)

    %% 2. VEHICLE DYNAMICS PARAMETERS (Mid-size Passenger EV)
    params.vehicle.mass = 1500;              % Vehicle curb mass + payload (kg)
    params.vehicle.wheelRadius = 0.31;        % Tire rolling radius (m)
    params.vehicle.Cd = 0.28;                 % Aerodynamic drag coefficient
    params.vehicle.frontalArea = 2.3;         % Frontal area (m^2)
    params.vehicle.Crr = 0.012;               % Rolling resistance coefficient
    params.vehicle.airDensity = 1.225;        % Air density at sea level (kg/m^3)
    params.vehicle.g = 9.81;                  % Gravitational acceleration (m/s^2)
    params.vehicle.gearRatio = 8.5;           % Reduction gear ratio
    params.vehicle.drivetrainEff = 0.95;      % Mechanical transmission efficiency

    %% 3. ELECTRIC MOTOR & INVERTER PARAMETERS
    params.motor.maxPower = 100e3;            % Peak electrical power (W)
    params.motor.maxTorque = 280;             % Peak motor torque (Nm)
    params.motor.maxSpeed = 12000;            % Max motor speed (RPM)
    params.motor.efficiency = 0.92;           % Average inverter + PMSM efficiency
    params.motor.regenEfficiency = 0.85;      % Regenerative braking capture efficiency

    %% 4. LITHIUM-ION BATTERY PACK PARAMETERS (Thevenin Model)
    % 96S2P LiFePO4 / NMC Configuration
    params.battery.nominalVoltage = 320;      % Pack nominal voltage (V)
    params.battery.capacityAh = 50;           % Rated capacity (Ah)
    params.battery.energyCapacityKWh = (params.battery.nominalVoltage * params.battery.capacityAh) / 1000; % 16 kWh
    params.battery.initialSOC = 0.80;         % Initial State of Charge (80%)
    params.battery.minSOC = 0.20;             % Lower SOC threshold (20%)
    params.battery.maxSOC = 0.90;             % Upper SOC threshold (90%)
    params.battery.Rint = 0.08;               % Internal resistance (Ohms)
    params.battery.R_transient = 0.04;        % RC parallel transient resistance (Ohms)
    params.battery.C_transient = 2500;        % RC parallel transient capacitance (F)
    params.battery.maxDischargeCurrent = 150; % Max continuous discharge current (A)
    params.battery.maxChargeCurrent = 75;     % Max continuous charge current (A)
    
    % Battery Thermal Model Proxy Parameters
    params.battery.mass = 120;                % Battery pack mass (kg)
    params.battery.cp = 900;                  % Specific heat capacity (J/kg-K)
    params.battery.hA = 12.0;                 % Heat transfer coefficient x Area (W/K)
    params.battery.ambientTemp = 25.0;        % Ambient temperature (deg C)

    %% 5. SUPERCAPACITOR MODULE PARAMETERS (Maxwell BMOD0058 E016 B02 Class)
    % 108 Cells in series
    params.supercap.capacitance = 58.0;       % Nominal stack capacitance (F)
    params.supercap.initialVoltage = 270;     % Initial terminal voltage (V)
    params.supercap.maxVoltage = 290;         % Max rated voltage (V)
    params.supercap.minVoltage = 140;         % Min usable voltage (V)
    params.supercap.ESR = 0.015;              % Equivalent Series Resistance (Ohms)
    params.supercap.maxCurrent = 220;         % Peak allowable current (A)
    params.supercap.ratedEnergykJ = 0.5 * params.supercap.capacitance * (params.supercap.maxVoltage^2) / 1000; % stored energy

    %% 6. DC BUS / DC-LINK PARAMETERS
    params.dclink.vRef = 400.0;               % Regulated DC-link voltage (V)
    params.dclink.capacitance = 4700e-6;      % DC-link bulk capacitor (F)
    params.dclink.vMin = 370.0;               % Min acceptable DC bus voltage (V)
    params.dclink.vMax = 430.0;               % Max acceptable DC bus voltage (V)

    %% 7. BIDIRECTIONAL DC/DC CONVERTERS
    params.converter.batteryInductance = 1.5e-3;   % Battery converter inductor (H)
    params.converter.supercapInductance = 1.0e-3;  % Supercap converter inductor (H)
    params.converter.switchingFreq = 20000;        % PWM switching frequency (Hz)
    params.converter.efficiency = 0.97;            % Average converter conversion efficiency

    %% 8. ENERGY MANAGEMENT SYSTEM (EMS) CONTROLLER TUNING
    % Rule-Based Thresholds
    params.control.pBatteryLowThresh = 8000;       % Low power demand threshold (W)
    params.control.pBatteryMaxContinuous = 25000;  % Maximum continuous battery power target (W)
    params.control.iBatteryPeakMax = 75.0;         % Target maximum battery discharge current (A)
    
    % Low-Pass Filter EMS Parameters
    params.control.lpfCutoffFreq = 0.05;           % Cutoff frequency Hz (fc = 0.05 Hz -> Tau ~ 3.18 s)
    params.control.lpfTau = 1.0 / (2 * pi * params.control.lpfCutoffFreq); % Time constant (s)
    
    % Supercapacitor Voltage Restoration Controller (PI)
    params.control.scKp = 45.0;                    % Proportional gain for SC SOC maintenance
    params.control.scKi = 0.5;                     % Integral gain for SC SOC maintenance

end
