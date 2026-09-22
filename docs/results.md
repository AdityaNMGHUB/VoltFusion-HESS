# VOLT FUSION - Simulation Results & Performance Benchmark

## Executive Summary
Dynamic simulation over the EPA UDDS drive cycle (1370 seconds) demonstrates significant stress reduction and loss savings for the hybrid energy storage system (HESS) compared to a conventional battery-only EV powertrain.

---

## Performance Summary Table

| Metric | Case A: Battery-Only Baseline | Case B1: HESS Rule-Based EMS | Case B2: HESS Low-Pass Filter EMS | Improvement (LPF vs Baseline) |
| :--- | :---: | :---: | :---: | :---: |
| **Peak Battery Current (A)** | 154.85 | 79.16 | **81.51** | **-47.36% Reduction** |
| **RMS Battery Current (A)** | 29.97 | 23.29 | **23.57** | **-21.37% Reduction** |
| **Std Dev Battery Current (A)** | 26.80 | 18.95 | **19.42** | **-27.53% Reduction** |
| **Battery I²R Losses (kJ)** | 111.91 | 71.50 | **74.27** | **-33.63% Savings** |
| **Battery Thermal Rise (°C)** | 0.97 | 0.62 | **0.64** | **-33.69% Lower Rise** |
| **Supercap Peak Power (kW)** | 0.00 | 53.87 | **58.58** | **High Transient Buffer** |
| **Regen Energy Recovered (kWh)**| 0.363 | 0.363 | **0.363** | **100% Captured** |
| **DC-Link Voltage Stability (V)**| 400.93 | 400.89 | **400.90** | **Tight Bus Regulation** |

---

## Key Technical Takeaways

1. **Peak Current Reduction (-47.36%)**:
   In the Battery-Only configuration, sudden heavy acceleration pulses force battery discharge current up to **154.85 A**. Under HESS LPF control, the supercapacitor buffers all high-frequency transients, capping battery current at **81.51 A**.

2. **Electrical Loss Savings (-33.63%)**:
   Because internal resistance losses scale quadratically with current (\(P_{\text{loss}} = I^2 R\)), reducing peak and RMS current significantly decreases pack heat generation from **111.91 kJ** down to **74.27 kJ**.

3. **Thermal Stress Mitigation (-33.69%)**:
   The lower heat generation reduces thermal accumulation inside the pack, protecting cells from thermal degradation and extending overall battery operational life.

4. **Regenerative Braking Buffer**:
   The supercapacitor absorbs fast high-power kinetic energy pulses during deceleration without stressing the battery with high pulse-charging currents.
