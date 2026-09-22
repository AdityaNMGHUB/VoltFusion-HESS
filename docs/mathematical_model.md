# VOLT FUSION - Mathematical Foundations & Modeling Equations

## 1. Longitudinal Vehicle Dynamics
The total tractive effort force \( F_{\text{traction}} \) required to propel the electric vehicle at velocity \( v \) and acceleration \( a = \frac{dv}{dt} \) is governed by Newton's second law:

\[
F_{\text{traction}} = F_{\text{acceleration}} + F_{\text{rolling}} + F_{\text{aerodynamic}} + F_{\text{grade}}
\]

Where:
- \( F_{\text{acceleration}} = m \cdot a \)
- \( F_{\text{rolling}} = C_{rr} \cdot m \cdot g \cdot \cos(\theta) \)
- \( F_{\text{aerodynamic}} = \frac{1}{2} \rho C_d A v^2 \)
- \( F_{\text{grade}} = m \cdot g \cdot \sin(\theta) \)

Mechanical traction power demand:
\[
P_{\text{mech}} = F_{\text{traction}} \cdot v
\]

Electrical power demand on the DC link:
\[
P_{\text{dc}} = 
\begin{cases}
\frac{P_{\text{mech}}}{\eta_{\text{drivetrain}} \cdot \eta_{\text{motor}}}, & P_{\text{mech}} \ge 0 \quad (\text{Traction}) \\[8pt]
P_{\text{mech}} \cdot \eta_{\text{drivetrain}} \cdot \eta_{\text{regen}}, & P_{\text{mech}} < 0 \quad (\text{Regenerative Braking})
\end{cases}
\]

---

## 2. Lithium-ion Battery Pack (Thevenin Equivalent Circuit)
The battery terminal voltage \( V_{\text{bat}} \) accounts for open-circuit voltage \( E_{\text{ocv}}(\text{SOC}) \), internal resistance \( R_{\text{int}} \), and polarization transient voltage \( V_{RC} \):

\[
V_{\text{bat}} = E_{\text{ocv}}(\text{SOC}) - I_{\text{bat}} R_{\text{int}} - V_{RC}
\]

The transient polarization RC dynamics:
\[
\frac{dV_{RC}}{dt} = \frac{I_{\text{bat}} R_{\text{trans}} - V_{RC}}{R_{\text{trans}} C_{\text{trans}}}
\]

State of Charge (SOC) integration:
\[
\text{SOC}(t) = \text{SOC}(0) - \frac{1}{Q_{\text{nominal}} \cdot 3600} \int_0^t I_{\text{bat}}(\tau) \, d\tau
\]

Electrical \( I^2 R \) power loss and thermal proxy:
\[
P_{\text{loss,bat}} = I_{\text{bat}}^2 R_{\text{int}} + \frac{V_{RC}^2}{R_{\text{trans}}}
\]
\[
\frac{dT_{\text{bat}}}{dt} = \frac{P_{\text{loss,bat}} - hA (T_{\text{bat}} - T_{\text{ambient}})}{m_{\text{bat}} \cdot c_p}
\]

---

## 3. Supercapacitor Pack Model
Terminal voltage \( V_{\text{sc}} \) with internal capacitor voltage \( V_c \) and Equivalent Series Resistance (ESR) \( R_{\text{esr}} \):

\[
V_{\text{sc}} = V_c - I_{\text{sc}} R_{\text{esr}}
\]
\[
\frac{dV_c}{dt} = -\frac{I_{\text{sc}}}{C_{\text{sc}}}
\]

Stored electrostatic energy:
\[
E_{\text{sc}} = \frac{1}{2} C_{\text{sc}} V_c^2
\]

Normalized Supercapacitor state of charge:
\[
\text{SOC}_{\text{sc}} = \frac{V_c - V_{\text{min}}}{V_{\text{max}} - V_{\text{min}}}
\]

---

## 4. DC-Link Bus & Active Converter Regulation
Power balance equation at the 400V DC bus capacitor \( C_{\text{dc}} \):

\[
C_{\text{dc}} \frac{dV_{\text{dc}}}{dt} = \eta_{\text{conv}} I_{\text{bat,conv}} + \eta_{\text{conv}} I_{\text{sc,conv}} - I_{\text{load}}
\]
Where \( I_{\text{load}} = \frac{P_{\text{dc}}}{V_{\text{dc}}} \).
