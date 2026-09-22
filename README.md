# VOLT FUSION: Hybrid Energy Storage & Intelligent Power Management System for Electric Vehicles

[![MATLAB](https://img.shields.io/badge/MATLAB-R2023b%2B-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![Simulink](https://img.shields.io/badge/Simulink-Simscape%20Electrical-orange.svg)](https://www.mathworks.com/products/simulink.html)
[![Python](https://img.shields.io/badge/Python-3.10%2B-green.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-brightgreen.svg)](LICENSE)

**VOLT FUSION** is an advanced engineering modeling, simulation, and control framework designed to evaluate a **Hybrid Energy Storage System (HESS)** combining a **Lithium-ion Battery Pack** and a **Supercapacitor Stack** for Electric Vehicles (EVs).

---

## ⚡ System Architecture & Concept

```
                                 ELECTRIC VEHICLE
                                        │
                                        ▼
                             UDDS / WLTP Drive Cycle
                                        │
                                        ▼
                          Longitudinal Vehicle Dynamics
                                        │
                                        ▼
                                 EV Motor & Drive
                                        │
                                        ▼
                              400V DC BUS / DC LINK
                              /                   \
                             /                     \
                            ▼                       ▼
                 Battery DC/DC Converter    Supercapacitor DC/DC Converter
                            │                       │
                            ▼                       ▼
                     Li-ion Battery           Supercapacitor Stack
```

### Core Engineering Strategy:
- **Low-Frequency Steady Power** \(\rightarrow\) **Lithium-ion Battery Pack** (high energy density).
- **High-Frequency Power Transients & Acceleration Peaks** \(\rightarrow\) **Supercapacitor Module** (high power density).
- **Regenerative Braking** \(\rightarrow\) **Supercapacitor Preferential Absorption** + Battery safe charging.

---

## 🔑 Key Features & Technical Highlights

- **Dual-Converter Active HESS Architecture**: Synchronous bidirectional DC/DC converters regulating a 400V DC link.
- **Frequency-Decoupled Low-Pass Filter EMS**: Separates slow cruising demand from high-frequency throttle transients (\(f_c = 0.05\,\text{Hz}\)).
- **Rule-Based EMS Comparison**: Includes state-machine threshold-based logic for benchmarking.
- **Thevenin Battery Model**: Double-RC equivalent circuit capturing open-circuit voltage, internal resistance, polarization dynamics, and electrical loss heat dissipation.
- **Supercapacitor Dynamics**: Stored electrostatic energy calculation (\(E = \frac{1}{2} C V^2\)) and ESR power loss modeling.
- **Dual Verification Engine**: Complete MATLAB/Simulink codebase plus standalone Python dynamic ODE solver for instant reproducibility.

---

## 📊 Quantitative Simulation Results (EPA UDDS Drive Cycle)

Results obtained from dynamic numerical integration over 1370 seconds of city driving:

| Metric | Case A: Battery-Only Baseline | Case B1: HESS Rule-Based | Case B2: HESS Low-Pass Filter | Improvement (LPF vs Baseline) |
| :--- | :---: | :---: | :---: | :---: |
| **Peak Battery Current (A)** | 154.85 A | 79.16 A | **81.51 A** | **-47.36% Peak Reduction** |
| **RMS Battery Current (A)** | 29.97 A | 23.29 A | **23.57 A** | **-21.37% RMS Reduction** |
| **Battery I²R Losses (kJ)** | 111.91 kJ | 71.50 kJ | **74.27 kJ** | **-33.63% Loss Savings** |
| **Battery Thermal Rise (°C)** | 0.97 °C | 0.62 °C | **0.64 °C** | **-33.69% Lower Thermal Rise** |
| **Supercap Peak Power (kW)** | 0.00 kW | 53.87 kW | **58.58 kW** | **58.6 kW Peak Transient Buffer** |
| **DC Bus Ripple (V)** | 0.94 V | 0.89 V | **0.90 V** | **Stable 400V Bus Regulation** |

---

## 📁 Repository Directory Structure

```
VoltFusion/
├── README.md                                # Master README Document
├── docs/                                    # Technical & Mathematical Documentation
│   ├── system_architecture.md
│   ├── mathematical_model.md
│   ├── control_strategy.md
│   └── results.md
├── matlab/                                  # MATLAB Simulation Scripts
│   ├── parameters.m                         # Central parameters script
│   ├── initialize_model.m                   # Model initialization
│   ├── run_simulation.m                     # Master simulation script
│   ├── calculate_metrics.m                  # Performance metric calculator
│   ├── generate_plots.m                     # 10 High-res plot generators
│   ├── compare_results.m                    # Tabular results comparison
│   ├── export_results.m                     # CSV/MAT exporter
│   └── build_simulink_models.m              # Programmatic Simulink generator
├── simulink/                                # Simulink Model specifications
│   ├── VoltFusion_HESS.slx
│   └── BatteryOnly.slx
├── controllers/                             # Control Logic & Saturation
│   ├── rule_based_ems.m
│   ├── low_pass_ems.m
│   └── limits.m
├── drive_cycles/                            # Velocity Profiles
│   └── generate_drive_cycles.m
├── results/                                 # Simulation Output Artifacts
│   ├── figures/                             # 10 Publication-Quality PNG Plots
│   ├── tables/                              # CSV Summary Tables
│   └── simulation_data/                     # Time-Series Data Vectors
├── report/                                  # Engineering Project Report
│   └── project_report.md
└── sim_engine/                              # Python Verification Engine
    └── simulate.py                          # Standalone dynamic ODE solver
```

---

## 🚀 How to Run

### Option 1: Running in MATLAB
1. Open MATLAB and set current folder to project root `VoltFusion/`.
2. Run `matlab/run_simulation.m`:
   ```matlab
   run_simulation('UDDS')
   ```
3. All figures will be automatically saved to `results/figures/` and metrics output to `results/tables/`.

### Option 2: Running via Python Solver
```bash
python sim_engine/simulate.py
```

---

## 🛠️ Required MATLAB Toolboxes
- MATLAB (R2021b or newer)
- Simulink
- Simscape / Simscape Electrical (for `.slx` model execution)
- Control System Toolbox

---

## 📌 Resume Bullet Points

- **Designed and implemented** a 400V Hybrid Energy Storage System (HESS) combining a Lithium-ion battery pack and a supercapacitor stack in MATLAB/Simulink and Python for electric vehicle powertrain applications.
- **Synthesized a frequency-decoupled Low-Pass Filter (LPF) Energy Management Strategy** to allocate low-frequency power demand to the battery and high-frequency power transients to the supercapacitor module.
- **Evaluated system performance across 1,370 seconds of the EPA UDDS drive cycle**, achieving a **47.36% reduction in peak battery current** (from 154.9 A to 81.5 A), a **21.37% reduction in RMS battery current**, and a **33.63% reduction in internal \( I^2 R \) electrical losses**.
- **Regulated DC-link bus voltage stability within \(\pm 2\%\) bounds** under dual bidirectional DC/DC converter control while buffering 58.6 kW acceleration power transients.

---

## 👨‍💻 Authors & Contact
**Senior EV Systems & Control Engineering Team**  
*Project VOLT FUSION*
