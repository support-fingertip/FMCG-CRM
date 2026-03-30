import { LightningElement, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import ChartJs from '@salesforce/resourceUrl/ChartJs';
import getDashboardData from '@salesforce/apex/TAM_KpiDashboard_Controller.getDashboardData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TamKpiDashboard extends LightningElement {

    @track isLoading = false;
    chartJsLoaded = false;

    @track periodOptions = [];
    selectedPeriod = '';
    @track selectedView = 'self';

    @track kpis = [];
    @track grandTarget = 0;
    @track grandActual = 0;
    @track grandPercent = 0;
    @track incentiveSummary = {};
    @track team = [];
    @track trend = [];

    trendChart = null;
    incentiveChart = null;

    connectedCallback() {
        loadScript(this, ChartJs)
            .then(() => { this.chartJsLoaded = true; })
            .catch(() => {});
        this.loadData();
    }

    loadData() {
        this.isLoading = true;
        getDashboardData({ periodId: this.selectedPeriod, viewType: this.selectedView })
            .then(result => {
                this.periodOptions = (result.periods || []).map(p => ({ label: p.Name, value: p.Id }));
                if (!this.selectedPeriod) this.selectedPeriod = result.currentPeriodId || '';

                this.kpis = result.kpis || [];
                this.grandTarget = result.grandTarget || 0;
                this.grandActual = result.grandActual || 0;
                this.grandPercent = result.grandPercent || 0;
                this.incentiveSummary = result.incentiveSummary || {};
                this.team = result.team || [];
                this.trend = result.trend || [];

                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => { this.renderCharts(); }, 300);
            })
            .catch(e => { this.showToast('Error', e?.body?.message || 'Failed to load', 'error'); })
            .finally(() => { this.isLoading = false; });
    }

    // ===== VIEW TOGGLE =====
    get viewOptions() {
        return [
            { value: 'self', label: 'My KPIs', pillClass: 'kd-pill' + (this.selectedView === 'self' ? ' kd-pill-active' : '') },
            { value: 'team', label: 'Team', pillClass: 'kd-pill' + (this.selectedView === 'team' ? ' kd-pill-active' : '') },
            { value: 'org', label: 'Organization', pillClass: 'kd-pill' + (this.selectedView === 'org' ? ' kd-pill-active' : '') }
        ];
    }

    handleViewChange(event) {
        this.selectedView = event.currentTarget.dataset.value;
        this.loadData();
    }

    handlePeriodChange(event) {
        this.selectedPeriod = event.target.value;
        this.loadData();
    }

    handleRefresh() { this.loadData(); }

    // ===== GETTERS =====
    get hasKpis() { return this.kpis.length > 0; }
    get hasTeam() { return this.team.length > 0; }
    get showTeam() { return this.selectedView !== 'self'; }

    get grandPercentDisplay() { return Number(this.grandPercent).toFixed(1); }
    get grandTargetDisplay() { return this.fmt(this.grandTarget); }
    get grandActualDisplay() { return this.fmt(this.grandActual); }
    get totalIncentiveDisplay() { return this.fmt(this.incentiveSummary.total_amount || 0); }

    get computedKpis() {
        const colors = ['#0176d3', '#2e844a', '#7e5cef', '#e65100', '#c23934', '#00796b', '#1565c0', '#ad1457'];
        const circ = 2 * Math.PI * 34;

        return this.kpis.map((k, i) => {
            const pct = Number(k.percent) || 0;
            return {
                key: k.name || String(i),
                name: k.name,
                weight: k.weight,
                percent: pct.toFixed(1),
                color: colors[i % colors.length],
                circumference: circ,
                offset: circ - (circ * Math.min(pct, 100) / 100),
                targetDisplay: this.fmt(k.target),
                actualDisplay: this.fmt(k.actual),
                percentClass: pct >= 100 ? 'kd-pct-green' : pct >= 70 ? 'kd-pct-amber' : 'kd-pct-red'
            };
        });
    }

    get computedTeam() {
        return this.team.map(row => {
            const pct = Number(row.percent) || 0;
            return {
                ...row,
                percentDisplay: pct.toFixed(1),
                targetDisplay: this.fmt(row.target),
                actualDisplay: this.fmt(row.actual),
                incentiveDisplay: this.fmt(row.incentive || 0),
                progressWidth: `width: ${Math.min(pct, 100)}%`,
                percentClass: pct >= 100 ? 'kd-pct-green' : pct >= 70 ? 'kd-pct-amber' : 'kd-pct-red'
            };
        });
    }

    // ===== CHARTS =====
    renderCharts() {
        if (!this.chartJsLoaded) return;
        this.renderTrendChart();
        this.renderIncentiveChart();
    }

    renderTrendChart() {
        const canvas = this.template.querySelector('.kd-trend-canvas');
        if (!canvas) return;
        if (this.trendChart) this.trendChart.destroy();

        const labels = this.trend.map(d => d.label || '');
        const targets = this.trend.map(d => d.target || 0);
        const actuals = this.trend.map(d => d.actual || 0);

        this.trendChart = new window.Chart(canvas.getContext('2d'), {
            type: 'line',
            data: {
                labels,
                datasets: [
                    {
                        label: 'Target',
                        data: targets,
                        borderColor: '#0176d3',
                        backgroundColor: 'rgba(1, 118, 211, 0.1)',
                        fill: true,
                        tension: 0.3,
                        pointRadius: 4,
                        pointBackgroundColor: '#0176d3'
                    },
                    {
                        label: 'Achievement',
                        data: actuals,
                        borderColor: '#2e844a',
                        backgroundColor: 'rgba(46, 132, 74, 0.1)',
                        fill: true,
                        tension: 0.3,
                        pointRadius: 4,
                        pointBackgroundColor: '#2e844a'
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { position: 'top' } },
                scales: {
                    y: { beginAtZero: true },
                    x: {}
                }
            }
        });
    }

    renderIncentiveChart() {
        const canvas = this.template.querySelector('.kd-incentive-canvas');
        if (!canvas) return;
        if (this.incentiveChart) this.incentiveChart.destroy();

        const s = this.incentiveSummary;
        const data = [
            s['Calculated_amount'] || 0,
            s['Pending Approval_amount'] || 0,
            s['Approved_amount'] || 0,
            s['Paid_amount'] || 0
        ];

        // Only render if there's data
        if (data.every(d => d === 0)) return;

        this.incentiveChart = new window.Chart(canvas.getContext('2d'), {
            type: 'doughnut',
            data: {
                labels: ['Calculated', 'Pending', 'Approved', 'Paid'],
                datasets: [{
                    data,
                    backgroundColor: ['#0176d3', '#f5a742', '#2e844a', '#7e5cef'],
                    borderWidth: 2,
                    borderColor: '#fff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '60%',
                plugins: { legend: { position: 'bottom', labels: { font: { size: 11 }, padding: 10 } } }
            }
        });
    }

    // ===== HELPERS =====
    fmt(val) {
        if (val == null) return '0';
        val = Number(val);
        if (val >= 10000000) return (val / 10000000).toFixed(1) + 'Cr';
        if (val >= 100000) return (val / 100000).toFixed(1) + 'L';
        if (val >= 1000) return (val / 1000).toFixed(1) + 'K';
        return String(Math.round(val));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
