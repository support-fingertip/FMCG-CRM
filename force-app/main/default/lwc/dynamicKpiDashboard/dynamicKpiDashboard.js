import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getInitData from '@salesforce/apex/DKD_Dashboard_Controller.getInitData';
import getKpiValues from '@salesforce/apex/DKD_Dashboard_Controller.getKpiValues';
import getMetricData from '@salesforce/apex/DKD_Dashboard_Controller.getMetricData';
import getPreviousPeriodValues from '@salesforce/apex/DKD_Dashboard_Controller.getPreviousPeriodValues';

const USER_SCOPES = [
    { label: 'Self', value: 'self' },
    { label: 'My Team', value: 'team' },
    { label: 'Organization', value: 'org' }
];

const DATE_PRESETS = [
    { label: 'Today', value: 'today' },
    { label: 'Yesterday', value: 'yesterday' },
    { label: 'This Week', value: 'this_week' },
    { label: 'Month to Date', value: 'mtd' },
    { label: 'Last Month', value: 'last_month' },
    { label: 'Quarter to Date', value: 'qtd' },
    { label: 'Year to Date', value: 'ytd' },
    { label: 'Last 30 Days', value: 'last_30' },
    { label: 'Last 90 Days', value: 'last_90' },
    { label: 'Custom', value: 'custom' }
];

export default class DynamicKpiDashboard extends LightningElement {
    @track isLoading = true;
    @track initError;

    // Filter state
    @track dateFrom;
    @track dateTo;
    @track datePreset = 'mtd';
    @track userScope = 'self';
    @track selectedCategory = '';
    @track selectedMetricKeys = [];

    // Data
    @track allMetrics = [];
    @track categoryOptions = [];
    @track territoryOptions = [];
    @track currentUser;
    @track kpiCards = [];
    @track chartData = [];
    @track selectedChartMetric = '';

    // UI state
    @track showFilterPanel = true;
    @track lastUpdated;

    // ── Lifecycle ────────────────────────────────────────────────

    connectedCallback() {
        this.loadInit();
    }

    async loadInit() {
        this.isLoading = true;
        try {
            const data = await getInitData();
            this.allMetrics = data.metrics || [];
            this.currentUser = data.currentUser;
            this.userScope = data.defaultScope || 'self';

            // Build category options
            const cats = [{ label: 'All Categories', value: '' }];
            (data.categories || []).forEach(c => cats.push({ label: c, value: c }));
            this.categoryOptions = cats;

            // Territory options
            this.territoryOptions = [{ label: 'All Territories', value: '' }]
                .concat((data.territories || []).map(t => ({ label: t.name, value: t.id })));

            // Default date range
            if (data.defaultDateRange) {
                this.dateFrom = data.defaultDateRange.from;
                this.dateTo = data.defaultDateRange.to;
            }

            // Default metric selection (first 4 Sales metrics)
            this.selectedMetricKeys = data.defaultMetricKeys || [];
            if (this.selectedMetricKeys.length > 0) {
                this.selectedChartMetric = this.selectedMetricKeys[0];
            }

            await this.refreshData();
        } catch (error) {
            this.initError = this.reduceError(error);
            this.showToast('Error', 'Failed to load dashboard: ' + this.initError, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Getters ──────────────────────────────────────────────────

    get userScopeOptions() { return USER_SCOPES; }
    get datePresetOptions() { return DATE_PRESETS; }
    get isCustomRange() { return this.datePreset === 'custom'; }

    get filteredMetricOptions() {
        if (!this.selectedCategory) {
            return this.allMetrics.map(m => ({
                label: m.category + ' — ' + m.label, value: m.key
            }));
        }
        return this.allMetrics
            .filter(m => m.category === this.selectedCategory)
            .map(m => ({ label: m.label, value: m.key }));
    }

    get chartMetricOptions() {
        return this.allMetrics.map(m => ({ label: m.label, value: m.key }));
    }

    get hasKpiCards() { return this.kpiCards.length > 0; }
    get hasChartData() { return this.chartData.length > 0; }

    get activeFilterChips() {
        const chips = [];
        chips.push({ key: 'scope', label: 'Scope: ' + this.scopeLabel });
        chips.push({ key: 'range', label: 'Period: ' + this.dateRangeLabel });
        if (this.selectedCategory) {
            chips.push({ key: 'cat', label: 'Category: ' + this.selectedCategory });
        }
        return chips;
    }

    get scopeLabel() {
        const s = USER_SCOPES.find(o => o.value === this.userScope);
        return s ? s.label : this.userScope;
    }

    get dateRangeLabel() {
        if (!this.dateFrom || !this.dateTo) return 'Not set';
        return this.formatDate(this.dateFrom) + ' → ' + this.formatDate(this.dateTo);
    }

    get lastUpdatedLabel() {
        if (!this.lastUpdated) return '';
        return 'Last updated: ' + this.lastUpdated;
    }

    get filterPanelClass() {
        return this.showFilterPanel ? 'dkd-filter-panel dkd-filter-panel-open' : 'dkd-filter-panel';
    }

    get bodyClass() {
        return this.showFilterPanel ? 'dkd-body' : 'dkd-body dkd-body-collapsed';
    }

    get toggleFilterIcon() {
        return this.showFilterPanel ? 'utility:chevronleft' : 'utility:filterList';
    }

    // ── Filter handlers ──────────────────────────────────────────

    handleDatePresetChange(event) {
        this.datePreset = event.detail.value;
        this.applyDatePreset(this.datePreset);
    }

    applyDatePreset(preset) {
        const today = new Date();
        const y = today.getFullYear();
        const m = today.getMonth();
        const d = today.getDate();

        switch (preset) {
            case 'today':
                this.dateFrom = this.toISODate(new Date(y, m, d));
                this.dateTo = this.toISODate(new Date(y, m, d));
                break;
            case 'yesterday':
                this.dateFrom = this.toISODate(new Date(y, m, d - 1));
                this.dateTo = this.toISODate(new Date(y, m, d - 1));
                break;
            case 'this_week': {
                const day = today.getDay();
                const monday = new Date(y, m, d - (day === 0 ? 6 : day - 1));
                this.dateFrom = this.toISODate(monday);
                this.dateTo = this.toISODate(new Date(y, m, d));
                break;
            }
            case 'mtd':
                this.dateFrom = this.toISODate(new Date(y, m, 1));
                this.dateTo = this.toISODate(new Date(y, m, d));
                break;
            case 'last_month':
                this.dateFrom = this.toISODate(new Date(y, m - 1, 1));
                this.dateTo = this.toISODate(new Date(y, m, 0));
                break;
            case 'qtd': {
                const q = Math.floor(m / 3) * 3;
                this.dateFrom = this.toISODate(new Date(y, q, 1));
                this.dateTo = this.toISODate(new Date(y, m, d));
                break;
            }
            case 'ytd':
                this.dateFrom = this.toISODate(new Date(y, 0, 1));
                this.dateTo = this.toISODate(new Date(y, m, d));
                break;
            case 'last_30':
                this.dateFrom = this.toISODate(new Date(y, m, d - 30));
                this.dateTo = this.toISODate(new Date(y, m, d));
                break;
            case 'last_90':
                this.dateFrom = this.toISODate(new Date(y, m, d - 90));
                this.dateTo = this.toISODate(new Date(y, m, d));
                break;
            // custom: leave as-is
        }
    }

    handleDateFromChange(event) { this.dateFrom = event.detail.value; }
    handleDateToChange(event) { this.dateTo = event.detail.value; }

    handleScopeChange(event) { this.userScope = event.detail.value; }
    handleCategoryChange(event) { this.selectedCategory = event.detail.value; }

    handleMetricToggle(event) {
        const key = event.currentTarget.dataset.metricKey;
        if (!key) return;
        const idx = this.selectedMetricKeys.indexOf(key);
        if (idx >= 0) {
            this.selectedMetricKeys = this.selectedMetricKeys.filter(k => k !== key);
        } else {
            this.selectedMetricKeys = [...this.selectedMetricKeys, key];
        }
    }

    handleChartMetricChange(event) {
        this.selectedChartMetric = event.detail.value;
        this.loadChartData();
    }

    handleToggleFilterPanel() {
        this.showFilterPanel = !this.showFilterPanel;
    }

    handleApplyFilters() { this.refreshData(); }

    handleResetFilters() {
        this.userScope = 'self';
        this.selectedCategory = '';
        this.datePreset = 'mtd';
        this.applyDatePreset('mtd');
        this.refreshData();
    }

    handleRefresh() { this.refreshData(); }

    // ── Data loading ─────────────────────────────────────────────

    async refreshData() {
        if (!this.selectedMetricKeys.length) {
            this.kpiCards = [];
            return;
        }
        this.isLoading = true;
        try {
            const [current, previous] = await Promise.all([
                getKpiValues({
                    metricKeys: this.selectedMetricKeys,
                    filtersJson: null,
                    dateFrom: this.dateFrom,
                    dateTo: this.dateTo,
                    userScope: this.userScope
                }),
                getPreviousPeriodValues({
                    metricKeys: this.selectedMetricKeys,
                    filtersJson: null,
                    dateFrom: this.dateFrom,
                    dateTo: this.dateTo,
                    userScope: this.userScope
                })
            ]);

            this.kpiCards = this.buildKpiCards(current, previous);

            if (this.selectedChartMetric) {
                await this.loadChartData();
            }

            const now = new Date();
            this.lastUpdated = now.toLocaleTimeString();
        } catch (error) {
            this.showToast('Error', 'Failed to refresh data: ' + this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadChartData() {
        if (!this.selectedChartMetric) return;
        try {
            const rows = await getMetricData({
                metricKey: this.selectedChartMetric,
                filtersJson: null,
                groupBy: 'Status__c',
                dateFrom: this.dateFrom,
                dateTo: this.dateTo,
                userScope: this.userScope
            });
            const max = rows.reduce((m, r) => Math.max(m, Number(r.value) || 0), 0) || 1;
            this.chartData = rows.map(r => ({
                label: r.label,
                value: r.value,
                formattedValue: this.formatValue(r.value, this.selectedChartMetric),
                barStyle: 'width: ' + Math.round((Number(r.value) / max) * 100) + '%;'
            }));
        } catch (error) {
            console.error('Chart load failed', error);
            this.chartData = [];
        }
    }

    // ── KPI card builder ─────────────────────────────────────────

    buildKpiCards(current, previous) {
        const cards = [];
        for (const key of this.selectedMetricKeys) {
            const metric = this.allMetrics.find(m => m.key === key);
            if (!metric) continue;

            const curVal = Number(current[key]) || 0;
            const prevVal = Number(previous[key]) || 0;
            const delta = curVal - prevVal;
            let deltaPct = 0;
            if (prevVal !== 0) {
                deltaPct = (delta / Math.abs(prevVal)) * 100;
            } else if (curVal !== 0) {
                deltaPct = 100;
            }

            const trendClass = delta > 0
                ? 'dkd-trend dkd-trend-up'
                : (delta < 0 ? 'dkd-trend dkd-trend-down' : 'dkd-trend dkd-trend-flat');
            const trendIcon = delta > 0
                ? 'utility:arrowup'
                : (delta < 0 ? 'utility:arrowdown' : 'utility:dash');

            cards.push({
                key,
                label: metric.label,
                category: metric.category,
                icon: metric.icon || 'utility:chart',
                color: metric.color || '#0176d3',
                cardStyle: 'border-left-color: ' + (metric.color || '#0176d3') + ';',
                iconStyle: 'background: ' + (metric.color || '#0176d3') + '1a; color: ' + (metric.color || '#0176d3') + ';',
                value: curVal,
                formattedValue: this.formatValue(curVal, key),
                prevValue: prevVal,
                formattedPrevValue: this.formatValue(prevVal, key),
                delta,
                deltaPct: Math.abs(deltaPct).toFixed(1) + '%',
                trendClass,
                trendIcon,
                hasComparison: prevVal !== 0
            });
        }
        return cards;
    }

    // ── Formatting ───────────────────────────────────────────────

    formatValue(value, metricKey) {
        const metric = this.allMetrics.find(m => m.key === metricKey);
        const format = metric ? metric.format : 'Number';
        const num = Number(value) || 0;
        if (format === 'Currency') {
            return new Intl.NumberFormat('en-IN', {
                style: 'currency', currency: 'INR', maximumFractionDigits: 0
            }).format(num);
        }
        if (format === 'Percent') {
            return num.toFixed(1) + '%';
        }
        if (format === 'Duration') {
            return Math.round(num) + ' min';
        }
        return new Intl.NumberFormat('en-IN').format(Math.round(num));
    }

    formatDate(isoDate) {
        if (!isoDate) return '';
        const d = new Date(isoDate);
        return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    toISODate(date) {
        const y = date.getFullYear();
        const m = String(date.getMonth() + 1).padStart(2, '0');
        const d = String(date.getDate()).padStart(2, '0');
        return `${y}-${m}-${d}`;
    }

    // ── Utilities ────────────────────────────────────────────────

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (!error) return 'Unknown error';
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}
