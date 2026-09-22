// VOLT FUSION — Dashboard JavaScript

const CHART_DEFAULTS = {
    responsive: true,
    maintainAspectRatio: false,
    animation: { duration: 500, easing: 'easeInOutQuart' },
    interaction: { mode: 'index', intersect: false },
    plugins: {
        legend: {
            labels: {
                color: '#a3a3a3',
                font: { family: 'Inter', size: 11, weight: '500' },
                boxWidth: 12,
                boxHeight: 2,
                padding: 16
            }
        },
        tooltip: {
            backgroundColor: '#1f1f1f',
            borderColor: '#333',
            borderWidth: 1,
            titleColor: '#f5f5f5',
            bodyColor: '#a3a3a3',
            titleFont: { family: 'DM Sans', size: 12, weight: '600' },
            bodyFont: { family: 'JetBrains Mono', size: 11 },
            padding: 12,
            cornerRadius: 6,
            displayColors: true,
            boxWidth: 10,
            boxHeight: 10
        }
    },
    scales: {
        x: {
            grid: { color: 'rgba(255,255,255,0.04)', drawBorder: false },
            ticks: {
                color: '#525252',
                font: { family: 'JetBrains Mono', size: 10 },
                maxTicksLimit: 10
            },
            title: {
                display: true,
                text: 'Time (s)',
                color: '#525252',
                font: { family: 'Inter', size: 11 }
            }
        },
        y: {
            grid: { color: 'rgba(255,255,255,0.04)', drawBorder: false },
            ticks: {
                color: '#525252',
                font: { family: 'JetBrains Mono', size: 10 }
            }
        }
    }
};

const COLORS = {
    orange: '#f97316',
    amber: '#f59e0b',
    red: '#ef4444',
    green: '#22c55e',
    neutral: '#737373',
    white: '#f5f5f5'
};

// Chart registry
const charts = {};

function destroyChart(id) {
    if (charts[id]) { charts[id].destroy(); delete charts[id]; }
}

function makeChart(id, cfg) {
    destroyChart(id);
    const ctx = document.getElementById(id).getContext('2d');
    charts[id] = new Chart(ctx, cfg);
}

function mkDataset(label, data, color, width = 1.5) {
    return {
        label,
        data,
        borderColor: color,
        backgroundColor: 'transparent',
        borderWidth: width,
        pointRadius: 0,
        tension: 0.2
    };
}

// Slider bindings
const sliders = [
    { el: 'param-mass', out: 'val-mass', fmt: v => `${v} kg` },
    { el: 'param-bat',  out: 'val-bat',  fmt: v => `${v} Ah` },
    { el: 'param-sc',   out: 'val-sc',   fmt: v => `${v} F` },
    { el: 'param-lpf',  out: 'val-lpf',  fmt: v => `${parseFloat(v).toFixed(2)} Hz` }
];

sliders.forEach(({ el, out, fmt }) => {
    const input = document.getElementById(el);
    const label = document.getElementById(out);
    input.addEventListener('input', () => { label.textContent = fmt(input.value); });
});

// Tabs
document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        btn.classList.add('active');
        document.getElementById(btn.dataset.tab)?.classList.add('active');
    });
});

// ── Simulation ──────────────────────────────────────────
async function runSimulation() {
    const overlay = document.getElementById('loading-overlay');
    const msg = document.getElementById('loading-msg');
    const btn = document.getElementById('run-btn');

    overlay.classList.add('visible');
    btn.disabled = true;
    msg.textContent = 'Running HESS simulation...';

    const payload = {
        mass: +document.getElementById('param-mass').value,
        battery_capacity: +document.getElementById('param-bat').value,
        supercap_capacitance: +document.getElementById('param-sc').value,
        lpf_cutoff: +document.getElementById('param-lpf').value,
        drive_cycle: document.getElementById('param-cycle').value
    };

    try {
        const res = await fetch('/api/simulate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const data = await res.json();
        if (data.status === 'success') updateUI(data);
    } catch (e) {
        console.error(e);
        msg.textContent = 'Error — check console.';
    } finally {
        overlay.classList.remove('visible');
        btn.disabled = false;
    }
}

document.getElementById('run-btn').addEventListener('click', runSimulation);

// ── UI Update ────────────────────────────────────────────
function updateUI(data) {
    const { metrics: m, improvements: imp, series: s } = data;

    // KPI cards
    setText('kpi-peak', `${m.lpf_hess.Peak_Battery_Current_A.toFixed(1)} A`);
    setText('kpi-peak-imp', `${imp.peak_reduction_pct}% reduction vs baseline`);
    setText('kpi-rms', `${m.lpf_hess.RMS_Battery_Current_A.toFixed(1)} A`);
    setText('kpi-rms-imp', `${imp.rms_reduction_pct}% lower sustained stress`);
    setText('kpi-loss', `${m.lpf_hess.Battery_Losses_kJ.toFixed(1)} kJ`);
    setText('kpi-loss-imp', `${imp.loss_savings_pct}% electrical loss savings`);
    setText('kpi-sc', `${m.lpf_hess.Peak_SC_Power_kW.toFixed(1)} kW`);
    setText('kpi-temp', `${m.lpf_hess.Battery_Temp_Rise_C.toFixed(2)} °C`);
    setText('kpi-temp-imp', `${imp.thermal_reduction_pct}% cooler pack`);

    // Sidebar mini metrics
    setText('mm-bat-peak', `${m.baseline.Peak_Battery_Current_A.toFixed(1)} A`);
    setText('mm-hess-peak', `${m.lpf_hess.Peak_Battery_Current_A.toFixed(1)} A`);
    setText('mm-bat-loss', `${m.baseline.Battery_Losses_kJ.toFixed(1)} kJ`);
    setText('mm-hess-loss', `${m.lpf_hess.Battery_Losses_kJ.toFixed(1)} kJ`);
    setText('mm-sc-power', `${m.lpf_hess.Peak_SC_Power_kW.toFixed(1)} kW`);
    setText('mm-regen', `${m.lpf_hess.Regen_Energy_kWh.toFixed(2)} kWh`);

    const t = s.time;

    // Chart 1: Battery Current
    makeChart('chart-current', {
        type: 'line',
        data: {
            labels: t,
            datasets: [
                mkDataset(`Baseline  (Peak: ${m.baseline.Peak_Battery_Current_A.toFixed(1)} A)`, s.I_bat_baseline, 'rgba(239,68,68,0.7)', 1),
                mkDataset(`Rule-Based (Peak: ${m.rule_based.Peak_Battery_Current_A.toFixed(1)} A)`, s.I_bat_rule, COLORS.amber, 1.2),
                mkDataset(`LPF HESS  (Peak: ${m.lpf_hess.Peak_Battery_Current_A.toFixed(1)} A)`, s.I_bat_lpf, COLORS.orange, 2)
            ]
        },
        options: {
            ...CHART_DEFAULTS,
            scales: {
                ...CHART_DEFAULTS.scales,
                y: { ...CHART_DEFAULTS.scales.y, title: { display: true, text: 'Current (A)', color: '#525252', font: { family: 'Inter', size: 11 } } }
            }
        }
    });

    // Chart 2: Power Split
    makeChart('chart-power', {
        type: 'line',
        data: {
            labels: t,
            datasets: [
                { ...mkDataset('Total Demand', s.power_demand_kw, 'rgba(239,68,68,0.3)', 1) },
                mkDataset('Battery Power (Low-Freq)', s.P_bat_lpf_kw, COLORS.orange, 2),
                mkDataset('Supercap Power (High-Freq)', s.P_supercap_kw, COLORS.green, 1.5)
            ]
        },
        options: {
            ...CHART_DEFAULTS,
            scales: { ...CHART_DEFAULTS.scales, y: { ...CHART_DEFAULTS.scales.y, title: { display: true, text: 'Power (kW)', color: '#525252', font: { family: 'Inter', size: 11 } } } }
        }
    });

    // Chart 3: SOC Battery
    makeChart('chart-soc-bat', {
        type: 'line',
        data: {
            labels: t,
            datasets: [
                mkDataset('Battery-Only SOC (%)', s.SOC_bat_baseline, 'rgba(239,68,68,0.7)', 1.2),
                mkDataset('HESS LPF SOC (%)', s.SOC_bat_lpf, COLORS.orange, 2)
            ]
        },
        options: {
            ...CHART_DEFAULTS,
            scales: { ...CHART_DEFAULTS.scales, y: { ...CHART_DEFAULTS.scales.y, title: { display: true, text: 'SOC (%)', color: '#525252', font: { family: 'Inter', size: 11 } } } }
        }
    });

    // Chart 4: Supercap Voltage
    makeChart('chart-vsc', {
        type: 'line',
        data: {
            labels: t,
            datasets: [mkDataset('SC Terminal Voltage (V)', s.V_supercap, COLORS.amber, 1.5)]
        },
        options: {
            ...CHART_DEFAULTS,
            scales: { ...CHART_DEFAULTS.scales, y: { ...CHART_DEFAULTS.scales.y, title: { display: true, text: 'Voltage (V)', color: '#525252', font: { family: 'Inter', size: 11 } } } }
        }
    });

    // Chart 5: Losses
    makeChart('chart-losses', {
        type: 'line',
        data: {
            labels: t,
            datasets: [
                mkDataset(`Baseline (${m.baseline.Battery_Losses_kJ.toFixed(1)} kJ)`, s.Loss_bat_baseline_kj, 'rgba(239,68,68,0.7)', 1.2),
                mkDataset(`HESS LPF (${m.lpf_hess.Battery_Losses_kJ.toFixed(1)} kJ)`, s.Loss_bat_lpf_kj, COLORS.orange, 2)
            ]
        },
        options: {
            ...CHART_DEFAULTS,
            scales: { ...CHART_DEFAULTS.scales, y: { ...CHART_DEFAULTS.scales.y, title: { display: true, text: 'Cumulative Loss (kJ)', color: '#525252', font: { family: 'Inter', size: 11 } } } }
        }
    });

    // Chart 6: Thermal
    makeChart('chart-temp', {
        type: 'line',
        data: {
            labels: t,
            datasets: [
                mkDataset(`Baseline (+${m.baseline.Battery_Temp_Rise_C.toFixed(2)} °C)`, s.T_bat_baseline, 'rgba(239,68,68,0.7)', 1.2),
                mkDataset(`HESS LPF (+${m.lpf_hess.Battery_Temp_Rise_C.toFixed(2)} °C)`, s.T_bat_lpf, COLORS.orange, 2)
            ]
        },
        options: {
            ...CHART_DEFAULTS,
            scales: { ...CHART_DEFAULTS.scales, y: { ...CHART_DEFAULTS.scales.y, title: { display: true, text: 'Temperature (°C)', color: '#525252', font: { family: 'Inter', size: 11 } } } }
        }
    });

    // Chart 7: DC Bus
    makeChart('chart-dc', {
        type: 'line',
        data: {
            labels: t,
            datasets: [mkDataset('DC Bus Voltage (V)', s.V_dclink, COLORS.amber, 1.5)]
        },
        options: {
            ...CHART_DEFAULTS,
            scales: { ...CHART_DEFAULTS.scales, y: { ...CHART_DEFAULTS.scales.y, min: 390, max: 410, title: { display: true, text: 'Voltage (V)', color: '#525252', font: { family: 'Inter', size: 11 } } } }
        }
    });

    // Benchmark table
    const tb = document.getElementById('table-body');
    const rows = [
        ['Peak Battery Current', `${m.baseline.Peak_Battery_Current_A.toFixed(1)} A`, `${m.rule_based.Peak_Battery_Current_A.toFixed(1)} A`, `${m.lpf_hess.Peak_Battery_Current_A.toFixed(1)} A`, `↓ ${imp.peak_reduction_pct}% reduction`],
        ['RMS Battery Current', `${m.baseline.RMS_Battery_Current_A.toFixed(1)} A`, `${m.rule_based.RMS_Battery_Current_A.toFixed(1)} A`, `${m.lpf_hess.RMS_Battery_Current_A.toFixed(1)} A`, `↓ ${imp.rms_reduction_pct}% lower`],
        ['Battery I²R Losses', `${m.baseline.Battery_Losses_kJ.toFixed(1)} kJ`, `${m.rule_based.Battery_Losses_kJ.toFixed(1)} kJ`, `${m.lpf_hess.Battery_Losses_kJ.toFixed(1)} kJ`, `↓ ${imp.loss_savings_pct}% savings`],
        ['Battery Thermal Rise', `${m.baseline.Battery_Temp_Rise_C.toFixed(2)} °C`, `${m.rule_based.Battery_Temp_Rise_C.toFixed(2)} °C`, `${m.lpf_hess.Battery_Temp_Rise_C.toFixed(2)} °C`, `↓ ${imp.thermal_reduction_pct}% cooler`],
        ['SC Peak Transient Power', '— kW', `${m.rule_based.Peak_SC_Power_kW.toFixed(1)} kW`, `${m.lpf_hess.Peak_SC_Power_kW.toFixed(1)} kW`, '↑ High buffer'],
        ['DC Bus Ripple', `${m.baseline.DC_Bus_Ripple_V.toFixed(2)} V`, `${m.rule_based.DC_Bus_Ripple_V.toFixed(2)} V`, `${m.lpf_hess.DC_Bus_Ripple_V.toFixed(2)} V`, '✓ Stable 400V'],
        ['Regen Recovered', `${m.baseline.Regen_Energy_kWh.toFixed(2)} kWh`, `${m.rule_based.Regen_Energy_kWh.toFixed(2)} kWh`, `${m.lpf_hess.Regen_Energy_kWh.toFixed(2)} kWh`, '✓ 100% captured']
    ];

    tb.innerHTML = rows.map(([label, bat, rule, lpf, imp]) => `
        <tr>
            <td>${label}</td>
            <td>${bat}</td>
            <td>${rule}</td>
            <td class="hess-best">${lpf}</td>
            <td class="improvement">${imp}</td>
        </tr>
    `).join('');
}

function setText(id, val) {
    const el = document.getElementById(id);
    if (el) el.textContent = val;
}

// Auto-run on load
runSimulation();
