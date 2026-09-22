# VOLT FUSION - Intelligent Energy Management Control Strategies

## 1. Overview
The primary objective of the Energy Management System (EMS) is to split total powertrain electrical demand \( P_{\text{dc}} \) between the high-energy Battery and the high-power Supercapacitor:

\[
P_{\text{dc}} = P_{\text{battery}} + P_{\text{supercap}}
\]

---

## 2. Rule-Based Energy Management Strategy (EMS)
The Rule-Based EMS applies conditional state-machine logic based on load power magnitude and state-of-charge limits:

- **Low Power Acceleration (\(P_{\text{dc}} \le 8\,\text{kW}\))**:
  - Battery handles 100% of power demand.
  - Supercapacitor is idle.
- **Moderate Power Acceleration (\(8\,\text{kW} < P_{\text{dc}} \le 25\,\text{kW}\))**:
  - Battery supplies base load: \(P_{\text{bat}} = 8\,\text{kW} + 0.5 (P_{\text{dc}} - 8\,\text{kW})\).
  - Supercapacitor supplies transient assist: \(P_{\text{sc}} = P_{\text{dc}} - P_{\text{bat}}\).
- **Peak Transient Acceleration (\(P_{\text{dc}} > 25\,\text{kW}\))**:
  - Battery output is capped at continuous rating (\(25\,\text{kW}\)).
  - Supercapacitor absorbs 100% of the peak transient excess (\(P_{\text{sc}} = P_{\text{dc}} - 25\,\text{kW}\)).
- **Regenerative Braking (\(P_{\text{dc}} < 0\))**:
  - Supercapacitor preferentially absorbs high-power regenerative pulses up to its max current limit (\(220\,\text{A}\)).
  - Excess braking energy is safely absorbed by the battery.

---

## 3. Frequency-Decoupled Low-Pass Filter (LPF) EMS
The Low-Pass Filter EMS decouples power demand by frequency content:

1. **Low-Pass Filtering**:
   Total demand \( P_{\text{dc}} \) is filtered with time constant \(\tau = \frac{1}{2\pi f_c} \approx 3.18\,\text{s}\) (\(f_c = 0.05\,\text{Hz}\)):
   \[
   P_{\text{bat,lpf}}(k) = P_{\text{bat,lpf}}(k-1) + \frac{dt}{\tau + dt} \left( P_{\text{dc}}(k) - P_{\text{bat,lpf}}(k-1) \right)
   \]

2. **Supercapacitor SOC Center Restoration Controller**:
   A PI controller regulates supercapacitor terminal voltage toward target nominal voltage (\(270\,\text{V}\)):
   \[
   P_{\text{recharge}} = K_p (V_{\text{sc,ref}} - V_{\text{sc}}) + K_i \int (V_{\text{sc,ref}} - V_{\text{sc}}) dt
   \]

3. **Power Commands**:
   \[
   P_{\text{battery}} = P_{\text{bat,lpf}} + P_{\text{recharge}}
   \]
   \[
   P_{\text{supercap}} = P_{\text{dc}} - P_{\text{battery}}
   \]

4. **Hardware Saturation & Protection**:
   `limits.m` checks battery SOC limits (\(20\% - 90\%\)), SC voltage limits (\(140\,\text{V} - 290\,\text{V}\)), and converter current bounds.
