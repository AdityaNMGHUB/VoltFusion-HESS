#!/usr/bin/env python3
"""
VOLT FUSION - Interactive Web Dashboard & API Server
Project: Hybrid Energy Storage System (HESS) for Electric Vehicles
File: dashboard/app.py
"""

import os
import sys
import numpy as np
from flask import Flask, render_template, request, jsonify

# Add project root and sim_engine to path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(PROJECT_ROOT)
sys.path.append(os.path.join(PROJECT_ROOT, 'sim_engine'))

from simulate import VoltFusionSimulator, calculate_metrics

app = Flask(__name__, template_folder='templates', static_folder='static')

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/simulate', methods=['POST'])
def api_simulate():
    data = request.json or {}
    
    # Extract custom parameters or defaults
    sim = VoltFusionSimulator()
    sim.m = float(data.get('mass', 1500.0))
    sim.Q_bat_Ah = float(data.get('battery_capacity', 50.0))
    sim.Q_bat_coulombs = sim.Q_bat_Ah * 3600.0
    sim.C_sc = float(data.get('supercap_capacitance', 58.0))
    sim.lpf_cutoff = float(data.get('lpf_cutoff', 0.05))
    sim.lpf_tau = 1.0 / (2.0 * np.pi * sim.lpf_cutoff)
    cycle = str(data.get('drive_cycle', 'UDDS')).upper()
    
    dt = 0.01
    
    # Execute 3 simulation runs
    res_bat = sim.run_simulation(mode='BATTERY_ONLY', dt=dt)
    res_rule = sim.run_simulation(mode='RULE_BASED', dt=dt)
    res_lpf = sim.run_simulation(mode='LPF_HESS', dt=dt)
    
    m_bat = calculate_metrics(res_bat, 'Battery-Only Baseline')
    m_rule = calculate_metrics(res_rule, 'HESS Rule-Based EMS')
    m_lpf = calculate_metrics(res_lpf, 'HESS Low-Pass Filter EMS')
    
    # Calculate percentage improvements
    peak_red = ((m_bat['Peak_Battery_Current_A'] - m_lpf['Peak_Battery_Current_A']) / m_bat['Peak_Battery_Current_A']) * 100
    rms_red = ((m_bat['RMS_Battery_Current_A'] - m_lpf['RMS_Battery_Current_A']) / m_bat['RMS_Battery_Current_A']) * 100
    loss_red = ((m_bat['Battery_Losses_kJ'] - m_lpf['Battery_Losses_kJ']) / m_bat['Battery_Losses_kJ']) * 100
    temp_red = ((m_bat['Battery_Temp_Rise_C'] - m_lpf['Battery_Temp_Rise_C']) / m_bat['Battery_Temp_Rise_C']) * 100
    
    improvements = {
        'peak_reduction_pct': round(peak_red, 2),
        'rms_reduction_pct': round(rms_red, 2),
        'loss_savings_pct': round(loss_red, 2),
        'thermal_reduction_pct': round(temp_red, 2)
    }
    
    # Downsample time-series vectors for fast browser Chart.js rendering (500 points)
    step = max(1, len(res_lpf['time']) // 500)
    
    time_series = {
        'time': res_lpf['time'][::step].tolist(),
        'speed_kmh': (res_lpf['velocity'][::step] * 3.6).tolist(),
        'power_demand_kw': (res_lpf['P_dem'][::step] / 1000.0).tolist(),
        
        'I_bat_baseline': res_bat['I_bat'][::step].tolist(),
        'I_bat_rule': res_rule['I_bat'][::step].tolist(),
        'I_bat_lpf': res_lpf['I_bat'][::step].tolist(),
        
        'P_bat_baseline_kw': (res_bat['P_bat'][::step] / 1000.0).tolist(),
        'P_bat_lpf_kw': (res_lpf['P_bat'][::step] / 1000.0).tolist(),
        
        'SOC_bat_baseline': (res_bat['SOC_bat'][::step] * 100.0).tolist(),
        'SOC_bat_lpf': (res_lpf['SOC_bat'][::step] * 100.0).tolist(),
        
        'V_supercap': res_lpf['V_sc'][::step].tolist(),
        'SOC_supercap': (res_lpf['SOC_sc'][::step] * 100.0).tolist(),
        'P_supercap_kw': (res_lpf['P_sc'][::step] / 1000.0).tolist(),
        
        'V_dclink': res_lpf['V_dc'][::step].tolist(),
        
        'Loss_bat_baseline_kj': (np.cumsum(res_bat['Loss_bat']) * dt / 1000.0)[::step].tolist(),
        'Loss_bat_lpf_kj': (np.cumsum(res_lpf['Loss_bat']) * dt / 1000.0)[::step].tolist(),
        'T_bat_baseline': res_bat['T_bat'][::step].tolist(),
        'T_bat_lpf': res_lpf['T_bat'][::step].tolist(),
        
        'P_regen_kw': (res_lpf['P_regen'][::step] / 1000.0).tolist(),
        'P_sc_regen_kw': (-np.minimum(0, res_lpf['P_sc'])[::step] / 1000.0).tolist(),
        'P_bat_regen_kw': (-np.minimum(0, res_lpf['P_bat'])[::step] / 1000.0).tolist()
    }
    
    return jsonify({
        'status': 'success',
        'metrics': {
            'baseline': m_bat,
            'rule_based': m_rule,
            'lpf_hess': m_lpf
        },
        'improvements': improvements,
        'series': time_series
    })

if __name__ == '__main__':
    print("Starting VOLT FUSION Web Dashboard on http://127.0.0.1:5000 ...")
    app.run(host='0.0.0.0', port=5000, debug=True)
