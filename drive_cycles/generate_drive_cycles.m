%% VOLT FUSION - Standard Drive Cycle Generator
% Generates velocity profiles (m/s) and acceleration (m/s^2) for UDDS and WLTP drive cycles.
% File: generate_drive_cycles.m

function cycleData = generate_drive_cycles(cycleName, dt)
    if nargin < 2, dt = 0.01; end
    if nargin < 1, cycleName = 'UDDS'; end
    
    switch upper(cycleName)
        case 'UDDS'
            duration = 1370; % seconds
            t = (0:dt:duration)';
            
            % Multi-phase synthetic representation of EPA UDDS (FTP-72/75) profile
            % Includes transient stop-and-go, acceleration spikes, cruising, and braking
            v_mph = zeros(size(t));
            
            % Cycle segment construction (mph)
            v_mph = v_mph + 18.0 * (t > 20 & t <= 120) .* sin(pi * (t - 20)/100).^0.8;
            v_mph = v_mph + 32.0 * (t > 130 & t <= 300) .* (0.5 + 0.5*sin(2*pi*(t-130)/170 - pi/2));
            v_mph = v_mph + 25.0 * (t > 310 & t <= 500) .* (0.5 + 0.5*sin(4*pi*(t-310)/190 - pi/2));
            v_mph = v_mph + 56.7 * (t > 520 & t <= 850) .* (0.5 + 0.5*sin(pi*(t-520)/330));
            v_mph = v_mph + 28.5 * (t > 870 & t <= 1100) .* (0.5 + 0.5*sin(3*pi*(t-870)/230));
            v_mph = v_mph + 45.0 * (t > 1120 & t <= 1350) .* (0.5 + 0.5*sin(pi*(t-1120)/230));
            
            % Add micro-transients to simulate realistic driving power pulses
            micro = 2.5 * sin(2*pi*t/15) .* (v_mph > 5);
            v_mph = max(0, v_mph + micro);
            
            v_ms = v_mph * 0.44704; % convert mph to m/s
            
        case 'WLTP'
            duration = 1800;
            t = (0:dt:duration)';
            v_kmh = zeros(size(t));
            
            % WLTP Class 3 phases: Low, Medium, High, Extra High
            v_kmh = v_kmh + 50 * (t <= 589) .* sin(pi * t / 589).^0.7;
            v_kmh = v_kmh + 76.5 * (t > 589 & t <= 1022) .* sin(pi * (t-589) / 433).^0.7;
            v_kmh = v_kmh + 97.4 * (t > 1022 & t <= 1477) .* sin(pi * (t-1022) / 455).^0.7;
            v_kmh = v_kmh + 131.3 * (t > 1477 & t <= 1800) .* sin(pi * (t-1477) / 323).^0.7;
            
            v_ms = max(0, v_kmh / 3.6);
            
        otherwise
            error('Unknown drive cycle: %s. Use UDDS or WLTP.', cycleName);
    end
    
    % Compute continuous acceleration dv/dt using central differences
    a_ms2 = [0; diff(v_ms) / dt];
    
    cycleData.time = t;
    cycleData.velocity = v_ms;            % m/s
    cycleData.velocityKmh = v_ms * 3.6;   % km/h
    cycleData.acceleration = a_ms2;       % m/s^2
    cycleData.name = cycleName;
    cycleData.dt = dt;
end
