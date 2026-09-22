// VOLT FUSION - Interactive Web Dashboard JavaScript Client
document.addEventListener('DOMContentLoaded', () => {
    // 1. UI Elements & Sliders
    const inputMass = document.getElementById('param-mass');
    const valMass = document.getElementById('val-mass');
    const inputBatCap = document.getElementById('param-bat-cap');
    const valBatCap = document.getElementById('val-bat-cap');
    const inputSCCap = document.getElementById('param-sc-cap');
    const valSCCap = document.getElementById('val-sc-cap');
    const inputLPF = document.getElementById('param-lpf');
    const valLPF = document.getElementById('val-lpf');
    const selectCycle = document.getElementById('param-cycle');
    const btnSimulate = document.getElementById('btn-simulate');

    inputMass.addEventListener('input', () => valMass.innerText = `${inputMass.value} kg`);
    inputBatCap.addEventListener('input', () => valBatCap.innerText = `${inputBatCap.value} Ah`);
    inputSCCap.addEventListener('input', () => valSCCap.innerText = `${inputSCCap.value} F`);
    inputLPF.addEventListener('input', () => valLPF.innerText = `${inputLPF.value} Hz`);

    // 2. Tab Switcher
    const tabBtns = document.querySelectorAll('.tab-btn');
    const tabContents = document.querySelectorAll('.tab-content');

    tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            tabBtns.forEach(b => b.classList.remove('active'));
            tabContents.forEach(c => c.classList.remove('active'));

            btn.classList.add('active');
            const target = document.getElementById(btn.dataset.tab);
            if (target) target.classList.add('active');
        });
    });

    // 3. Chart Storage Objects
    let chartObjCurrent = null;
    let chartObjPower = null;
    let chartObjSOCBat = null;
    let chartObjVSC = null;
    let chartObjLosses = null;
    let chartObjThermal = null;
    let chartObjDCLink = null;

    // Common Dark Theme Options for Chart.js
    const commonChartOptions = {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 600 },
        scales: {
            x: {
                grid: { color: 'rgba(255, 255, 255, 0.05)' },
                ticks: { color: '#94a3b8' },
                title: { display: true, text: 'Time (s)', color: '#94a3b8' }
            },
            y: {
                grid: { color: 'rgba(255, 255, 255, 0.05)' },
                ticks: { color: '#94a3b8' }
            }
        },
        plugins: {
            legend: { labels: { color: '#f8fafc', font: { family: 'Outfit', size: 12 } } }
        }
    };

    // 4. Run Simulation API Trigger
    async function runSimulation() {
        btnSimulate.disabled = true;
        btnSimulate.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Running Solver...';

        const payload = {
            mass: parseFloat(inputMass.value),
            battery_capacity: parseFloat(inputBatCap.value),
            supercap_capacitance: parseFloat(inputSCCap.value),
            lpf_cutoff: parseFloat(inputLPF.value),
            drive_cycle: selectCycle.value
        };

        try {
            const response = await fetch('/api/simulate', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            const data = await response.json();
            if (data.status === 'success') {
                updateDashboard(data);
            }
        } catch (err) {
            console.error('Simulation error:', err);
        } finally {
            btnSimulate.disabled = false;
            btnSimulate.innerHTML = '<i class="fa-solid fa-play"></i> Run HESS Simulation';
        }
    }

    btnSimulate.addEventListener('click', runSimulation);

    // 5. Update UI Dashboard & Render Charts
    function updateDashboard(data) {
        const m = data.metrics;
        const imp = data.improvements;
        const s = data.series;

        // Update KPI Cards
        document.getElementById('kpi-peak-current').innerText = `${m.lpf_hess.Peak_Battery_Current_A.toFixed(1)} A`;
        document.getElementById('kpi-peak-red').innerText = `${imp.peak_reduction_pct}%`;

        document.getElementById('kpi-rms-current').innerText = `${m.lpf_hess.RMS_Battery_Current_A.toFixed(1)} A`;
        document.getElementById('kpi-rms-red').innerText = `${imp.rms_reduction_pct}%`;

        document.getElementById('kpi-losses').innerText = `${m.lpf_hess.Battery_Losses_kJ.toFixed(1)} kJ`;
        document.getElementById('kpi-loss-red').innerText = `${imp.loss_savings_pct}%`;

        document.getElementById('kpi-sc-power').innerText = `${m.lpf_hess.Peak_SC_Power_kW.toFixed(1)} kW`;

        document.getElementById('kpi-temp-rise').innerText = `${m.lpf_hess.Battery_Temp_Rise_C.toFixed(2)} °C`;
        document.getElementById('kpi-temp-red').innerText = `${imp.thermal_reduction_pct}%`;

        // Update Benchmark Table
        const tbody = document.getElementById('table-body');
        tbody.innerHTML = `
            <tr>
                <td><strong>Peak Battery Current (A)</strong></td>
                <td>${m.baseline.Peak_Battery_Current_A.toFixed(1)} A</td>
                <td>${m.rule_based.Peak_Battery_Current_A.toFixed(1)} A</td>
                <td><strong style="color:#00f2fe">${m.lpf_hess.Peak_Battery_Current_A.toFixed(1)} A</strong></td>
                <td><span class="highlight-green">-${imp.peak_reduction_pct}% Reduction</span></td>
            </tr>
            <tr>
                <td><strong>RMS Battery Current (A)</strong></td>
                <td>${m.baseline.RMS_Battery_Current_A.toFixed(1)} A</td>
                <td>${m.rule_based.RMS_Battery_Current_A.toFixed(1)} A</td>
                <td><strong style="color:#00f2fe">${m.lpf_hess.RMS_Battery_Current_A.toFixed(1)} A</strong></td>
                <td><span class="highlight-green">-${imp.rms_reduction_pct}% Lower RMS</span></td>
            </tr>
            <tr>
                <td><strong>Battery I²R Losses (kJ)</strong></td>
                <td>${m.baseline.Battery_Losses_kJ.toFixed(1)} kJ</td>
                <td>${m.rule_based.Battery_Losses_kJ.toFixed(1)} kJ</td>
                <td><strong style="color:#00f2fe">${m.lpf_hess.Battery_Losses_kJ.toFixed(1)} kJ</strong></td>
                <td><span class="highlight-green">-${imp.loss_savings_pct}% Loss Savings</span></td>
            </tr>
            <tr>
                <td><strong>Battery Thermal Rise (°C)</strong></td>
                <td>${m.baseline.Battery_Temp_Rise_C.toFixed(2)} °C</td>
                <td>${m.rule_based.Battery_Temp_Rise_C.toFixed(2)} °C</td>
                <td><strong style="color:#00f2fe">${m.lpf_hess.Battery_Temp_Rise_C.toFixed(2)} °C</strong></td>
                <td><span class="highlight-green">-${imp.thermal_reduction_pct}% Cooler Pack</span></td>
            </tr>
            <tr>
                <td><strong>Supercap Peak Power (kW)</strong></td>
                <td>0.0 kW</td>
                <td>${m.rule_based.Peak_SC_Power_kW.toFixed(1)} kW</td>
                <td><strong style="color:#00f2fe">${m.lpf_hess.Peak_SC_Power_kW.toFixed(1)} kW</strong></td>
                <td><span class="highlight-cyan">High Transient Buffer</span></td>
            </tr>
            <tr>
                <td><strong>DC Bus Ripple Deviation (V)</strong></td>
                <td>${m.baseline.DC_Bus_Ripple_V.toFixed(2)} V</td>
                <td>${m.rule_based.DC_Bus_Ripple_V.toFixed(2)} V</td>
                <td><strong style="color:#00f2fe">${m.lpf_hess.DC_Bus_Ripple_V.toFixed(2)} V</strong></td>
                <td><span class="highlight-green">Stable 400V Bus</span></td>
            </tr>
        `;

        // Render Charts
        // Chart 1: Current Peak Shaving
        if (chartObjCurrent) chartObjCurrent.destroy();
        const ctxCurrent = document.getElementById('chartCurrent').getContext('2d');
        chartObjCurrent = new Chart(ctxCurrent, {
            type: 'line',
            data: {
                labels: s.time,
                datasets: [
                    { label: 'Battery-Only Baseline (Peak: ' + m.baseline.Peak_Battery_Current_A.toFixed(1) + 'A)', data: s.I_bat_baseline, borderColor: '#ef4444', borderWidth: 1.2, pointRadius: 0 },
                    { label: 'HESS Rule-Based (Peak: ' + m.rule_based.Peak_Battery_Current_A.toFixed(1) + 'A)', data: s.I_bat_rule, borderColor: '#f59e0b', borderWidth: 1.5, pointRadius: 0 },
                    { label: 'HESS LPF Mode (Peak: ' + m.lpf_hess.Peak_Battery_Current_A.toFixed(1) + 'A)', data: s.I_bat_lpf, borderColor: '#00f2fe', borderWidth: 2, pointRadius: 0 }
                ]
            },
            options: commonChartOptions
        });

        // Chart 2: Power Allocation
        if (chartObjPower) chartObjPower.destroy();
        const ctxPower = document.getElementById('chartPower').getContext('2d');
        chartObjPower = new Chart(ctxPower, {
            type: 'line',
            data: {
                labels: s.time,
                datasets: [
                    { label: 'Total Demand P_dem (kW)', data: s.power_demand_kw, borderColor: 'rgba(239, 68, 68, 0.4)', borderWidth: 1, pointRadius: 0 },
                    { label: 'Low-Pass Battery Power (kW)', data: s.P_bat_lpf_kw, borderColor: '#3b82f6', borderWidth: 2, pointRadius: 0 },
                    { label: 'Transient Supercap Power (kW)', data: s.P_supercap_kw, borderColor: '#10b981', borderWidth: 1.5, pointRadius: 0 }
                ]
            },
            options: commonChartOptions
        });

        // Chart 3: SOC Battery
        if (chartObjSOCBat) chartObjSOCBat.destroy();
        const ctxSOCBat = document.getElementById('chartSOCBat').getContext('2d');
        chartObjSOCBat = new Chart(ctxSOCBat, {
            type: 'line',
            data: {
                labels: s.time,
                datasets: [
                    { label: 'Battery-Only SOC (%)', data: s.SOC_bat_baseline, borderColor: '#ef4444', borderWidth: 1.5, pointRadius: 0 },
                    { label: 'HESS LPF SOC (%)', data: s.SOC_bat_lpf, borderColor: '#00f2fe', borderWidth: 2, pointRadius: 0 }
                ]
            },
            options: commonChartOptions
        });

        // Chart 4: Supercap Voltage
        if (chartObjVSC) chartObjVSC.destroy();
        const ctxVSC = document.getElementById('chartVSC').getContext('2d');
        chartObjVSC = new Chart(ctxVSC, {
            type: 'line',
            data: {
                labels: s.time,
                datasets: [
                    { label: 'Supercap Terminal Voltage (V)', data: s.V_supercap, borderColor: '#10b981', borderWidth: 2, pointRadius: 0 }
                ]
            },
            options: commonChartOptions
        });

        // Chart 5: Losses
        if (chartObjLosses) chartObjLosses.destroy();
        const ctxLosses = document.getElementById('chartLosses').getContext('2d');
        chartObjLosses = new Chart(ctxLosses, {
            type: 'line',
            data: {
                labels: s.time,
                datasets: [
                    { label: 'Battery-Only Loss (kJ)', data: s.Loss_bat_baseline_kj, borderColor: '#ef4444', borderWidth: 1.5, pointRadius: 0 },
                    { label: 'HESS LPF Loss (kJ)', data: s.Loss_bat_lpf_kj, borderColor: '#00f2fe', borderWidth: 2, pointRadius: 0 }
                ]
            },
            options: commonChartOptions
        });

        // Chart 6: Thermal
        if (chartObjThermal) chartObjThermal.destroy();
        const ctxThermal = document.getElementById('chartThermal').getContext('2d');
        chartObjThermal = new Chart(ctxThermal, {
            type: 'line',
            data: {
                labels: s.time,
                datasets: [
                    { label: 'Battery-Only Temp (°C)', data: s.T_bat_baseline, borderColor: '#ef4444', borderWidth: 1.5, pointRadius: 0 },
                    { label: 'HESS LPF Temp (°C)', data: s.T_bat_lpf, borderColor: '#00f2fe', borderWidth: 2, pointRadius: 0 }
                ]
            },
            options: commonChartOptions
        });

        // Chart 7: DC Link
        if (chartObjDCLink) chartObjDCLink.destroy();
        const ctxDCLink = document.getElementById('chartDCLink').getContext('2d');
        chartObjDCLink = new Chart(ctxDCLink, {
            type: 'line',
            data: {
                labels: s.time,
                datasets: [
                    { label: '400V DC Bus Voltage (V)', data: s.V_dclink, borderColor: '#a855f7', borderWidth: 1.5, pointRadius: 0 }
                ]
            },
            options: commonChartOptions
        });
    }

    // Run initial simulation on load
    runSimulation();
});
