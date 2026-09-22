#!/usr/bin/env python3
"""
VOLT FUSION - Dynamic Simulation Engine & Quantitative Analysis
Project: Hybrid Energy Storage System (HESS) for Electric Vehicles
File: sim_engine/simulate.py
"""

import os
import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# Enable clean styling
plt.style.use('seaborn-v0_8-whitegrid' if 'seaborn-v0_8-whitegrid' in plt.style.available else 'default')
plt.rcParams['font.sans-serif'] = 'DejaVu Sans'
plt.rcParams['font.size'] = 10
plt.rcParams['axes.labelsize'] = 11
plt.rcParams['axes.titlesize'] = 12
plt.rcParams['xtick.labelsize'] = 10
plt.rcParams['ytick.labelsize'] = 10
plt.rcParams['legend.fontsize'] = 10
plt.rcParams['figure.titlesize'] = 14

class VoltFusionSimulator:
    def __init__(self):
        # 1. Vehicle Parameters
        self.m = 1500.0            # kg
        self.r_wheel = 0.31        # m
        self.Cd = 0.28
        self.A = 2.3               # m^2
        self.Crr = 0.012
        self.rho = 1.225           # kg/m^3
        self.g = 9.81              # m/s^2
        self.eta_drivetrain = 0.95
        
        # 2. Motor/Inverter
        self.P_motor_max = 100e3   # 100 kW peak motor power
        self.eta_motor = 0.92
        self.eta_regen = 0.85
        
        # 3. Battery (Thevenin Model)
        self.V_bat_nom = 320.0     # V
        self.Q_bat_Ah = 50.0       # Ah
        self.Q_bat_coulombs = self.Q_bat_Ah * 3600.0
        self.R_bat_int = 0.08      # Ohms
        self.R_bat_trans = 0.04    # Ohms
        self.C_bat_trans = 2500.0  # F
        self.SOC_init = 0.80
        self.SOC_min = 0.20
        self.SOC_max = 0.90
        self.I_bat_dis_max = 150.0 # A
        self.I_bat_chg_max = 75.0  # A
        
        # Battery Thermal Proxy
        self.m_bat = 120.0         # kg
        self.cp_bat = 900.0        # J/(kg K)
        self.hA_bat = 12.0         # W/K
        self.T_amb = 25.0          # deg C
        
        # 4. Supercapacitor (ESR + Ideal Capacitance)
        self.C_sc = 58.0           # F
        self.V_sc_init = 270.0     # V
        self.V_sc_max = 290.0      # V
        self.V_sc_min = 140.0      # V
        self.R_sc_esr = 0.015      # Ohms
        self.I_sc_max = 220.0      # A
        
        # 5. DC Link & Converters
        self.V_dc_ref = 400.0      # V
        self.C_dc = 4700e-6        # F
        self.eta_conv = 0.97
        
        # 6. EMS Tuning
        self.P_low_thresh = 8000.0       # W
        self.P_bat_max_cont = 25000.0   # W (25 kW continuous target)
        self.lpf_cutoff = 0.05           # Hz
        self.lpf_tau = 1.0 / (2.0 * np.pi * self.lpf_cutoff) # s (~3.18 s)
        self.sc_Kp = 45.0
        self.sc_Ki = 0.5

    def generate_udds_cycle(self, dt=0.01):
        duration = 1370.0
        t = np.arange(0, duration + dt, dt)
        v_mph = np.zeros_like(t)
        
        v_mph += 18.0 * ((t > 20) & (t <= 120)) * np.maximum(0.0, np.sin(np.pi * (t - 20) / 100.0))**0.8
        v_mph += 32.0 * ((t > 130) & (t <= 300)) * (0.5 + 0.5 * np.sin(2 * np.pi * (t - 130) / 170.0 - np.pi / 2))
        v_mph += 25.0 * ((t > 310) & (t <= 500)) * (0.5 + 0.5 * np.sin(4 * np.pi * (t - 310) / 190.0 - np.pi / 2))
        v_mph += 56.7 * ((t > 520) & (t <= 850)) * (0.5 + 0.5 * np.sin(np.pi * (t - 520) / 330.0))
        v_mph += 28.5 * ((t > 870) & (t <= 1100)) * (0.5 + 0.5 * np.sin(3 * np.pi * (t - 870) / 230.0))
        v_mph += 45.0 * ((t > 1120) & (t <= 1350)) * (0.5 + 0.5 * np.sin(np.pi * (t - 1120) / 230.0))
        
        micro = 2.5 * np.sin(2 * np.pi * t / 15.0) * (v_mph > 5)
        v_mph = np.maximum(0.0, v_mph + micro)
        v_ms = v_mph * 0.44704
        
        # Smooth velocity profile using moving average filter to avoid discrete differentiation noise
        window_size = int(0.5 / dt)
        v_ms_smooth = np.convolve(v_ms, np.ones(window_size)/window_size, mode='same')
        
        a_ms2 = np.zeros_like(v_ms_smooth)
        a_ms2[1:] = np.diff(v_ms_smooth) / dt
        # Clip acceleration to realistic passenger EV limits
        a_ms2 = np.clip(a_ms2, -4.0, 3.2)
        
        return t, v_ms_smooth, a_ms2

    def compute_power_demand(self, v, a):
        F_accel = self.m * a
        F_roll = self.Crr * self.m * self.g * (v > 0.1)
        F_aero = 0.5 * self.rho * self.Cd * self.A * (v**2)
        F_total = F_accel + F_roll + F_aero
        
        P_mech = F_total * v
        # Saturated motor power boundaries (-70 kW regen, +100 kW traction)
        P_mech = np.clip(P_mech, -70000.0, self.P_motor_max)
        
        P_dc = np.where(P_mech >= 0, 
                        P_mech / (self.eta_drivetrain * self.eta_motor),
                        P_mech * self.eta_drivetrain * self.eta_regen)
        return P_dc, P_mech

    def ocv_curve(self, soc):
        # Realistic LiFePO4 / NMC OCV relationship (V)
        return self.V_bat_nom * (0.92 + 0.14 * soc + 0.04 * np.log(np.maximum(0.001, soc)))

    def run_simulation(self, mode='LPF_HESS', dt=0.01):
        t, v, a = self.generate_udds_cycle(dt=dt)
        P_dc, P_mech = self.compute_power_demand(v, a)
        N = len(t)
        
        # State variables init
        soc_bat = self.SOC_init
        v_rc_bat = 0.0
        T_bat = self.T_amb
        
        v_sc = self.V_sc_init
        v_sc_cap = self.V_sc_init # internal capacitor voltage
        
        V_dc_bus = self.V_dc_ref
        
        # LPF controller internal states
        P_bat_lpf_state = 0.0
        v_sc_int_err = 0.0
        
        # Storage arrays
        I_bat_arr = np.zeros(N)
        V_bat_arr = np.zeros(N)
        P_bat_arr = np.zeros(N)
        SOC_bat_arr = np.zeros(N)
        Loss_bat_arr = np.zeros(N)
        T_bat_arr = np.zeros(N)
        
        I_sc_arr = np.zeros(N)
        V_sc_arr = np.zeros(N)
        P_sc_arr = np.zeros(N)
        SOC_sc_arr = np.zeros(N)
        Loss_sc_arr = np.zeros(N)
        
        V_dc_arr = np.zeros(N)
        P_regen_arr = np.zeros(N)
        
        for k in range(N):
            P_dem = P_dc[k]
            
            # 1. Determine Power Split based on mode
            if mode == 'BATTERY_ONLY':
                P_bat_req = P_dem
                P_sc_req = 0.0
                
            elif mode == 'RULE_BASED':
                if P_dem >= 0:
                    if P_dem <= self.P_low_thresh:
                        P_bat_req = P_dem
                        P_sc_req = 0.0
                    elif P_dem <= self.P_bat_max_cont:
                        P_bat_req = self.P_low_thresh + 0.5 * (P_dem - self.P_low_thresh)
                        P_sc_req = P_dem - P_bat_req
                    else:
                        P_bat_req = self.P_bat_max_cont
                        P_sc_req = P_dem - P_bat_req
                        
                    if v_sc <= self.V_sc_min + 5.0:
                        P_bat_req += P_sc_req
                        P_sc_req = 0.0
                else: # Regen
                    if v_sc < self.V_sc_max - 2.0:
                        p_sc_max_regen = self.I_sc_max * v_sc
                        P_sc_req = max(P_dem, -p_sc_max_regen)
                        P_bat_req = P_dem - P_sc_req
                    else:
                        P_sc_req = 0.0
                        P_bat_req = P_dem
                        
                # Trickle recharge SC at low load
                if P_dem < 2000 and P_dem >= 0 and v_sc < self.V_sc_init and soc_bat > 0.3:
                    P_bat_req += 2500.0
                    P_sc_req -= 2500.0
                    
            elif mode == 'LPF_HESS':
                alpha = dt / (self.lpf_tau + dt)
                P_bat_lpf_state += alpha * (P_dem - P_bat_lpf_state)
                
                v_sc_err = self.V_sc_init - v_sc
                v_sc_int_err += v_sc_err * dt
                v_sc_int_err = np.clip(v_sc_int_err, -300.0, 300.0)
                
                P_sc_recharge = self.sc_Kp * v_sc_err + self.sc_Ki * v_sc_int_err
                
                P_bat_req = P_bat_lpf_state + P_sc_recharge
                P_sc_req = P_dem - P_bat_req
                
            # Hardware protection saturation
            if v_sc <= self.V_sc_min and P_sc_req > 0:
                P_bat_req += P_sc_req
                P_sc_req = 0.0
            elif v_sc >= self.V_sc_max and P_sc_req < 0:
                P_bat_req += P_sc_req
                P_sc_req = 0.0
                
            p_bat_max_dis = self.I_bat_dis_max * self.V_bat_nom
            p_bat_max_chg = -self.I_bat_chg_max * self.V_bat_nom
            P_bat_act = np.clip(P_bat_req, p_bat_max_chg, p_bat_max_dis)
            P_sc_act = P_dem - P_bat_act if mode != 'BATTERY_ONLY' else 0.0
            
            p_sc_max_dis = self.I_sc_max * v_sc
            p_sc_max_chg = -self.I_sc_max * v_sc
            P_sc_act = np.clip(P_sc_act, p_sc_max_chg, p_sc_max_dis)
            
            # 2. Battery Dynamics (Thevenin Model)
            ocv = self.ocv_curve(soc_bat)
            a_quad = self.R_bat_int
            b_quad = -(ocv - v_rc_bat)
            c_quad = P_bat_act
            disc = b_quad**2 - 4 * a_quad * c_quad
            if disc >= 0:
                I_bat = (-b_quad - np.sqrt(disc)) / (2 * a_quad)
            else:
                I_bat = P_bat_act / max(1.0, ocv)
                
            V_bat = ocv - I_bat * self.R_bat_int - v_rc_bat
            
            dV_rc = (I_bat * self.R_bat_trans - v_rc_bat) / (self.R_bat_trans * self.C_bat_trans)
            v_rc_bat += dV_rc * dt
            
            dSOC = -I_bat / self.Q_bat_coulombs
            soc_bat += dSOC * dt
            soc_bat = np.clip(soc_bat, 0.05, 0.98)
            
            P_loss_bat = (I_bat**2) * self.R_bat_int + (v_rc_bat**2) / self.R_bat_trans
            dT_bat = (P_loss_bat - self.hA_bat * (T_bat - self.T_amb)) / (self.m_bat * self.cp_bat)
            T_bat += dT_bat * dt
            
            # 3. Supercapacitor Dynamics
            if mode != 'BATTERY_ONLY':
                a_sc = self.R_sc_esr
                b_sc = -v_sc_cap
                c_sc = P_sc_act
                disc_sc = b_sc**2 - 4 * a_sc * c_sc
                if disc_sc >= 0:
                    I_sc = (-b_sc - np.sqrt(disc_sc)) / (2 * a_sc)
                else:
                    I_sc = P_sc_act / max(1.0, v_sc_cap)
                    
                v_sc = v_sc_cap - I_sc * self.R_sc_esr
                dV_cap = -I_sc / self.C_sc
                v_sc_cap += dV_cap * dt
                v_sc_cap = np.clip(v_sc_cap, self.V_sc_min, self.V_sc_max)
                v_sc = v_sc_cap - I_sc * self.R_sc_esr
                
                P_loss_sc = (I_sc**2) * self.R_sc_esr
                soc_sc = (v_sc_cap - self.V_sc_min) / (self.V_sc_max - self.V_sc_min)
            else:
                I_sc = 0.0
                P_sc_act = 0.0
                v_sc = self.V_sc_init
                P_loss_sc = 0.0
                soc_sc = 1.0
                
            # 4. DC Bus Dynamics & Voltage Regulation
            I_dc_net = (P_bat_act * self.eta_conv + P_sc_act * self.eta_conv - P_dem) / self.V_dc_ref
            dV_dc = I_dc_net / self.C_dc
            V_dc_bus += dV_dc * dt
            V_dc_bus = self.V_dc_ref + 0.85 * (V_dc_bus - self.V_dc_ref) + 0.10 * (I_bat / 100.0)
            
            # Store values
            I_bat_arr[k] = I_bat
            V_bat_arr[k] = V_bat
            P_bat_arr[k] = P_bat_act
            SOC_bat_arr[k] = soc_bat
            Loss_bat_arr[k] = P_loss_bat
            T_bat_arr[k] = T_bat
            
            I_sc_arr[k] = I_sc
            V_sc_arr[k] = v_sc
            P_sc_arr[k] = P_sc_act
            SOC_sc_arr[k] = soc_sc
            Loss_sc_arr[k] = P_loss_sc
            
            V_dc_arr[k] = V_dc_bus
            P_regen_arr[k] = -P_dem if P_dem < 0 else 0.0
            
        res = {
            'time': t, 'velocity': v, 'acceleration': a,
            'P_dem': P_dc, 'P_mech': P_mech,
            'I_bat': I_bat_arr, 'V_bat': V_bat_arr, 'P_bat': P_bat_arr,
            'SOC_bat': SOC_bat_arr, 'Loss_bat': Loss_bat_arr, 'T_bat': T_bat_arr,
            'I_sc': I_sc_arr, 'V_sc': V_sc_arr, 'P_sc': P_sc_arr,
            'SOC_sc': SOC_sc_arr, 'Loss_sc': Loss_sc_arr,
            'V_dc': V_dc_arr, 'P_regen': P_regen_arr, 'dt': dt
        }
        return res

def calculate_metrics(res, mode_name):
    dt = res['dt']
    I_bat = res['I_bat']
    P_bat = res['P_bat']
    Loss_bat = res['Loss_bat']
    P_sc = res['P_sc']
    P_regen = res['P_regen']
    V_dc = res['V_dc']
    
    peak_I_bat = float(np.max(np.abs(I_bat)))
    rms_I_bat = float(np.sqrt(np.mean(I_bat**2)))
    std_I_bat = float(np.std(I_bat))
    
    total_energy_kWh = float(np.sum(np.maximum(0, P_bat)) * dt / 3600000.0)
    total_regen_kWh = float(np.sum(P_regen) * dt / 3600000.0)
    
    total_bat_loss_kJ = float(np.sum(Loss_bat) * dt / 1000.0)
    temp_rise = float(res['T_bat'][-1] - res['T_bat'][0])
    
    peak_P_sc_kW = float(np.max(np.abs(P_sc)) / 1000.0)
    vdc_ripple = float(np.max(V_dc) - np.min(V_dc))
    
    return {
        'Mode': mode_name,
        'Peak_Battery_Current_A': peak_I_bat,
        'RMS_Battery_Current_A': rms_I_bat,
        'Std_Battery_Current_A': std_I_bat,
        'Battery_Losses_kJ': total_bat_loss_kJ,
        'Battery_Temp_Rise_C': temp_rise,
        'Peak_SC_Power_kW': peak_P_sc_kW,
        'Energy_Consumed_kWh': total_energy_kWh,
        'Regen_Energy_kWh': total_regen_kWh,
        'DC_Bus_Ripple_V': vdc_ripple
    }

def main():
    print("="*60)
    print("VOLT FUSION - HYBRID ENERGY STORAGE SYSTEM SIMULATION")
    print("="*60)
    
    sim = VoltFusionSimulator()
    dt = 0.01
    
    print("[1/4] Simulating CASE A: Battery-Only Baseline EV...")
    res_bat = sim.run_simulation(mode='BATTERY_ONLY', dt=dt)
    
    print("[2/4] Simulating CASE B1: Battery + Supercap (Rule-Based EMS)...")
    res_rule = sim.run_simulation(mode='RULE_BASED', dt=dt)
    
    print("[3/4] Simulating CASE B2: Battery + Supercap (Low-Pass Filter EMS)...")
    res_lpf = sim.run_simulation(mode='LPF_HESS', dt=dt)
    
    print("[4/4] Calculating Quantitative Performance Metrics...")
    m_bat = calculate_metrics(res_bat, 'Battery-Only Baseline')
    m_rule = calculate_metrics(res_rule, 'HESS Rule-Based EMS')
    m_lpf = calculate_metrics(res_lpf, 'HESS Low-Pass Filter EMS')
    
    df_metrics = pd.DataFrame([m_bat, m_rule, m_lpf])
    
    # Calculate percentage improvements over baseline
    peak_red_rule = ((m_bat['Peak_Battery_Current_A'] - m_rule['Peak_Battery_Current_A']) / m_bat['Peak_Battery_Current_A']) * 100
    peak_red_lpf = ((m_bat['Peak_Battery_Current_A'] - m_lpf['Peak_Battery_Current_A']) / m_bat['Peak_Battery_Current_A']) * 100
    
    rms_red_lpf = ((m_bat['RMS_Battery_Current_A'] - m_lpf['RMS_Battery_Current_A']) / m_bat['RMS_Battery_Current_A']) * 100
    loss_red_lpf = ((m_bat['Battery_Losses_kJ'] - m_lpf['Battery_Losses_kJ']) / m_bat['Battery_Losses_kJ']) * 100
    temp_red_lpf = ((m_bat['Battery_Temp_Rise_C'] - m_lpf['Battery_Temp_Rise_C']) / m_bat['Battery_Temp_Rise_C']) * 100
    
    print("\n" + "="*80)
    print("SIMULATION SUMMARY METRICS TABLE")
    print("="*80)
    print(df_metrics.to_string(index=False))
    print("="*80)
    print(f"\n[KEY IMPROVEMENT HIGHLIGHTS (HESS LPF vs Battery-Only)]")
    print(f"  • Peak Battery Current Reduction : {peak_red_lpf:.2f}% (from {m_bat['Peak_Battery_Current_A']:.1f} A -> {m_lpf['Peak_Battery_Current_A']:.1f} A)")
    print(f"  • RMS Battery Current Reduction  : {rms_red_lpf:.2f}% (from {m_bat['RMS_Battery_Current_A']:.1f} A -> {m_lpf['RMS_Battery_Current_A']:.1f} A)")
    print(f"  • Battery I²R Electrical Losses  : {loss_red_lpf:.2f}% Reduction (from {m_bat['Battery_Losses_kJ']:.1f} kJ -> {m_lpf['Battery_Losses_kJ']:.1f} kJ)")
    print(f"  • Battery Thermal Rise Reduction : {temp_red_lpf:.2f}% lower temperature increase")
    print("="*80 + "\n")
    
    # Export Tables & Data
    os.makedirs('results/tables', exist_ok=True)
    os.makedirs('results/figures', exist_ok=True)
    os.makedirs('results/simulation_data', exist_ok=True)
    
    df_metrics.to_csv('results/tables/summary_metrics.csv', index=False)
    
    t = res_lpf['time']
    df_sim_export = pd.DataFrame({
        'time': t,
        'velocity_m_s': res_lpf['velocity'],
        'P_demand_W': res_lpf['P_dem'],
        'I_bat_baseline_A': res_bat['I_bat'],
        'I_bat_hess_lpf_A': res_lpf['I_bat'],
        'P_bat_hess_lpf_W': res_lpf['P_bat'],
        'SOC_bat_baseline': res_bat['SOC_bat'],
        'SOC_bat_hess_lpf': res_lpf['SOC_bat'],
        'V_supercap_V': res_lpf['V_sc'],
        'P_supercap_W': res_lpf['P_sc'],
        'V_dclink_V': res_lpf['V_dc'],
        'Loss_bat_baseline_W': res_bat['Loss_bat'],
        'Loss_bat_hess_lpf_W': res_lpf['Loss_bat']
    })
    df_sim_export.to_csv('results/simulation_data/udds_hess_simulation_results.csv', index=False)
    
    # Plotting Engine - 10 Figures
    print("[Plotting] Generating 10 High-Resolution Analysis Figures...")
    
    # Fig 1: Drive Cycle & Power Demand
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 6), sharex=True)
    ax1.plot(t, res_lpf['velocity'] * 3.6, 'navy', lw=1.5, label='Vehicle Velocity (km/h)')
    ax1.set_ylabel('Speed (km/h)')
    ax1.set_title('EPA UDDS Drive Cycle Profile & Power Demand')
    ax1.grid(True)
    ax1.legend(loc='upper right')
    
    ax2.plot(t, res_lpf['P_dem'] / 1000.0, 'crimson', lw=1.2, label='Traction Power Demand (kW)')
    ax2.axhline(0, color='black', lw=0.8, linestyle='--')
    ax2.set_xlabel('Time (s)')
    ax2.set_ylabel('Power (kW)')
    ax2.grid(True)
    ax2.legend(loc='upper right')
    plt.tight_layout()
    plt.savefig('results/figures/01_drive_cycle_velocity_power.png', dpi=300)
    plt.close()
    
    # Fig 2: Battery Current Comparison
    plt.figure(figsize=(10, 5))
    plt.plot(t, res_bat['I_bat'], color='darkred', alpha=0.7, lw=1.0, label=f"Battery-Only (Peak: {m_bat['Peak_Battery_Current_A']:.1f}A)")
    plt.plot(t, res_rule['I_bat'], color='darkorange', alpha=0.8, lw=1.2, label=f"HESS Rule-Based (Peak: {m_rule['Peak_Battery_Current_A']:.1f}A)")
    plt.plot(t, res_lpf['I_bat'], color='teal', lw=1.5, label=f"HESS LPF Frequency Split (Peak: {m_lpf['Peak_Battery_Current_A']:.1f}A)")
    plt.axhline(sim.P_bat_max_cont/320.0, color='gray', linestyle=':', label='Target Continuous Current')
    plt.title(f'Battery Current Profile Comparison ({peak_red_lpf:.1f}% Peak Reduction)')
    plt.xlabel('Time (s)')
    plt.ylabel('Battery Current (A)')
    plt.grid(True)
    plt.legend(loc='upper right')
    plt.tight_layout()
    plt.savefig('results/figures/02_battery_current_comparison.png', dpi=300)
    plt.close()

    # Fig 3: Battery Power Allocation
    plt.figure(figsize=(10, 5))
    plt.plot(t, res_bat['P_bat'] / 1000.0, 'crimson', alpha=0.5, lw=1.0, label='Battery Power (Battery-Only)')
    plt.plot(t, res_lpf['P_bat'] / 1000.0, 'navy', lw=1.5, label='Battery Power (HESS LPF)')
    plt.axhline(sim.P_bat_max_cont/1000.0, color='red', linestyle='--', label='Continuous Power Limit')
    plt.title('Battery Power Demand Peak-Shaving')
    plt.xlabel('Time (s)')
    plt.ylabel('Power (kW)')
    plt.grid(True)
    plt.legend(loc='upper right')
    plt.tight_layout()
    plt.savefig('results/figures/03_battery_power_comparison.png', dpi=300)
    plt.close()

    # Fig 4: Battery SOC Trajectory
    plt.figure(figsize=(10, 5))
    plt.plot(t, res_bat['SOC_bat'] * 100.0, 'crimson', lw=1.5, label='Battery SOC (Battery-Only Baseline)')
    plt.plot(t, res_lpf['SOC_bat'] * 100.0, 'teal', lw=1.8, label='Battery SOC (HESS LPF Mode)')
    plt.title('Battery State-of-Charge (SOC) Depletion Trajectory')
    plt.xlabel('Time (s)')
    plt.ylabel('Battery SOC (%)')
    plt.grid(True)
    plt.legend(loc='upper right')
    plt.tight_layout()
    plt.savefig('results/figures/04_battery_soc_trajectory.png', dpi=300)
    plt.close()

    # Fig 5: Supercapacitor Voltage & SOC
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 6), sharex=True)
    ax1.plot(t, res_lpf['V_sc'], 'darkgreen', lw=1.5, label='Supercapacitor Voltage (V)')
    ax1.axhline(sim.V_sc_max, color='red', linestyle='--', label='V_max (290V)')
    ax1.axhline(sim.V_sc_min, color='orange', linestyle='--', label='V_min (140V)')
    ax1.set_ylabel('Terminal Voltage (V)')
    ax1.set_title('Supercapacitor State & Voltage Regulation (HESS LPF)')
    ax1.grid(True)
    ax1.legend(loc='lower right')

    ax2.plot(t, res_lpf['SOC_sc'] * 100.0, 'green', lw=1.5, label='Supercap Energy SOC (%)')
    ax2.set_xlabel('Time (s)')
    ax2.set_ylabel('Supercap SOC (%)')
    ax2.grid(True)
    ax2.legend(loc='lower right')
    plt.tight_layout()
    plt.savefig('results/figures/05_supercap_voltage_soc.png', dpi=300)
    plt.close()

    # Fig 6: Supercapacitor Power Trajectory
    plt.figure(figsize=(10, 5))
    plt.plot(t, res_lpf['P_sc'] / 1000.0, 'forestgreen', lw=1.2, label='Supercapacitor Power (kW)')
    plt.axhline(0, color='black', lw=0.8, linestyle='--')
    plt.title(f'Supercapacitor Transient Power Buffer (Peak Transient: {m_lpf["Peak_SC_Power_kW"]:.1f} kW)')
    plt.xlabel('Time (s)')
    plt.ylabel('SC Power (kW)')
    plt.grid(True)
    plt.legend(loc='upper right')
    plt.tight_layout()
    plt.savefig('results/figures/06_supercap_power_trajectory.png', dpi=300)
    plt.close()

    # Fig 7: DC-Link Voltage Stability
    plt.figure(figsize=(10, 5))
    plt.plot(t, res_lpf['V_dc'], 'purple', lw=1.2, label='400V DC Bus Voltage (V)')
    plt.axhline(400.0, color='black', linestyle='--', label='V_ref (400V)')
    plt.ylim(385, 415)
    plt.title('DC Bus Voltage Stability Under Dynamic Drive Load')
    plt.xlabel('Time (s)')
    plt.ylabel('DC Bus Voltage (V)')
    plt.grid(True)
    plt.legend(loc='upper right')
    plt.tight_layout()
    plt.savefig('results/figures/07_dclink_voltage_stability.png', dpi=300)
    plt.close()

    # Fig 8: Regenerative Braking Split
    plt.figure(figsize=(10, 5))
    plt.plot(t, res_lpf['P_regen']/1000.0, 'black', lw=1.0, linestyle=':', label='Total Regen Power Available (kW)')
    plt.plot(t, -np.minimum(0, res_lpf['P_sc'])/1000.0, 'forestgreen', lw=1.5, label='Regen Power Absorbed by Supercap')
    plt.plot(t, -np.minimum(0, res_lpf['P_bat'])/1000.0, 'teal', lw=1.5, label='Regen Power Absorbed by Battery')
    plt.title('Regenerative Braking Power Allocation Spectrum')
    plt.xlabel('Time (s)')
    plt.ylabel('Regen Power (kW)')
    plt.grid(True)
    plt.legend(loc='upper right')
    plt.tight_layout()
    plt.savefig('results/figures/08_regen_braking_split.png', dpi=300)
    plt.close()

    # Fig 9: Battery Losses & Thermal Stress
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 6), sharex=True)
    ax1.plot(t, np.cumsum(res_bat['Loss_bat'])*dt/1000.0, 'crimson', lw=1.5, label=f"Battery-Only Cumulative Loss ({m_bat['Battery_Losses_kJ']:.1f} kJ)")
    ax1.plot(t, np.cumsum(res_lpf['Loss_bat'])*dt/1000.0, 'teal', lw=1.8, label=f"HESS LPF Cumulative Loss ({m_lpf['Battery_Losses_kJ']:.1f} kJ)")
    ax1.set_ylabel('Cumulative Loss (kJ)')
    ax1.set_title(f'Battery Electrical Losses & Thermal Rise ({loss_red_lpf:.1f}% Loss Reduction)')
    ax1.grid(True)
    ax1.legend(loc='upper left')

    ax2.plot(t, res_bat['T_bat'], 'crimson', lw=1.5, label=f"Battery-Only Temp (+{m_bat['Battery_Temp_Rise_C']:.2f}°C)")
    ax2.plot(t, res_lpf['T_bat'], 'teal', lw=1.8, label=f"HESS LPF Temp (+{m_lpf['Battery_Temp_Rise_C']:.2f}°C)")
    ax2.set_xlabel('Time (s)')
    ax2.set_ylabel('Temperature (°C)')
    ax2.grid(True)
    ax2.legend(loc='upper left')
    plt.tight_layout()
    plt.savefig('results/figures/09_battery_losses_thermal_stress.png', dpi=300)
    plt.close()

    # Fig 10: Frequency Split Spectrum Analysis
    plt.figure(figsize=(10, 5))
    plt.plot(t, res_lpf['P_dem']/1000.0, 'crimson', alpha=0.4, lw=1.0, label='Total Demand P_dem (High + Low Freq)')
    plt.plot(t, res_lpf['P_bat']/1000.0, 'navy', lw=1.8, label='Low-Pass Filtered Battery Power P_bat')
    plt.plot(t, res_lpf['P_sc']/1000.0, 'forestgreen', lw=1.2, label='High-Pass Filtered Supercap Power P_sc')
    plt.title('Frequency Decoupling Power Split (Low-Pass Filter EMS)')
    plt.xlabel('Time (s)')
    plt.ylabel('Power (kW)')
    plt.grid(True)
    plt.legend(loc='upper right')
    plt.tight_layout()
    plt.savefig('results/figures/10_power_spectrum_frequency_split.png', dpi=300)
    plt.close()

    print("\n[SUCCESS] Simulation completed successfully!")
    print("All 10 figures and summary CSV metrics have been created in results/.")

if __name__ == '__main__':
    main()
