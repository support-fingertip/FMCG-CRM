import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getInitData from '@salesforce/apex/DKD_Dashboard_Controller.getInitData';
import getKpiValues from '@salesforce/apex/DKD_Dashboard_Controller.getKpiValues';
import getMetricData from '@salesforce/apex/DKD_Dashboard_Controller.getMetricData';
import getTimeSeries from '@salesforce/apex/DKD_Dashboard_Controller.getTimeSeries';
import getPreviousPeriodValues from '@salesforce/apex/DKD_Dashboard_Controller.getPreviousPeriodValues';
import getForecast from '@salesforce/apex/DKD_Dashboard_Controller.getForecast';

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

    // Breakdown chart (by dimension)
    @track selectedChartMetric = '';
    @track selectedGroupBy = 'Status__c';
    @track breakdownChartType = 'bar';
    @track breakdownLabels = [];
    @track breakdownDatasets = [];

    // Trend chart (time series)
    @track selectedTrendMetric = '';
    @track selectedTrendInterval = 'MONTH';
    @track trendLabels = [];
    @track trendDatasets = [];

    // Forecast chart
    @track selectedForecastMetric = '';
    @track selectedForecastInterval = 'MONTH';
    @track selectedForecastHorizon = 6;
    @track forecastLabels = [];
    @track forecastDatasets = [];
    @track forecastInsight = '';
    @track forecastStats = null;

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
                this.selectedTrendMetric = this.selectedMetricKeys[0];
                // For the forecast, prefer a metric with Allow_Forecast__c = true
                const forecastable = this.allMetrics.find(m => m.allowForecast);
                this.selectedForecastMetric = forecastable ? forecastable.key : this.selectedMetricKeys[0];
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

    get chartTypeOptions() {
        return [
            { label: 'Bar', value: 'bar' },
            { label: 'Horizontal Bar', value: 'horizontalBar' },
            { label: 'Line', value: 'line' },
            { label: 'Pie', value: 'pie' },
            { label: 'Doughnut', value: 'doughnut' }
        ];
    }

    get groupByOptions() {
        // Options depend on the source object of the selected chart metric.
        const metric = this.allMetrics.find(m => m.key === this.selectedChartMetric);
        const obj = metric ? metric.sourceObject : '';
        const base = [
            { label: 'Status', value: 'Status__c' }
        ];
        if (obj === 'Sales_Order__c') {
            return [
                { label: 'Status', value: 'Status__c' },
                { label: 'Channel', value: 'Channel__c' },
                { label: 'Territory', value: 'Territory__c' },
                { label: 'Order Type', value: 'Order_Type__c' }
            ];
        }
        if (obj === 'Visit__c') {
            return [
                { label: 'Status', value: 'Visit_Status__c' },
                { label: 'Is Productive', value: 'Is_Productive__c' },
                { label: 'Is Ad-Hoc', value: 'Is_Ad_Hoc__c' }
            ];
        }
        if (obj === 'Collection__c') {
            return [
                { label: 'Payment Mode', value: 'Payment_Mode__c' },
                { label: 'Status', value: 'Status__c' }
            ];
        }
        if (obj === 'Account') {
            return [
                { label: 'Type', value: 'Type' },
                { label: 'Channel', value: 'Channel__c' }
            ];
        }
        return base;
    }

    get trendIntervalOptions() {
        return [
            { label: 'Daily', value: 'DAY' },
            { label: 'Weekly', value: 'WEEK' },
            { label: 'Monthly', value: 'MONTH' },
            { label: 'Quarterly', value: 'QUARTER' },
            { label: 'Yearly', value: 'YEAR' }
        ];
    }

    get breakdownChartFormat() {
        const metric = this.allMetrics.find(m => m.key === this.selectedChartMetric);
        return metric ? metric.format : 'Number';
    }

    get trendChartFormat() {
        const metric = this.allMetrics.find(m => m.key === this.selectedTrendMetric);
        return metric ? metric.format : 'Number';
    }

    get breakdownChartTitle() {
        const metric = this.allMetrics.find(m => m.key === this.selectedChartMetric);
        const label = metric ? metric.label : 'Metric';
        const dim = this.groupByOptions.find(g => g.value === this.selectedGroupBy);
        const dimLabel = dim ? dim.label : this.selectedGroupBy;
        return label + ' by ' + dimLabel;
    }

    get trendChartTitle() {
        const metric = this.allMetrics.find(m => m.key === this.selectedTrendMetric);
        const label = metric ? metric.label : 'Metric';
        const intv = this.trendIntervalOptions.find(i => i.value === this.selectedTrendInterval);
        const intvLabel = intv ? intv.label : 'Time';
        return label + ' — ' + intvLabel + ' Trend';
    }

    // Forecast widget options
    get forecastMetricOptions() {
        return this.allMetrics
            .filter(m => m.allowForecast)
            .map(m => ({ label: m.label, value: m.key }));
    }

    get forecastHorizonOptions() {
        return [
            { label: 'Next 3 Periods', value: 3 },
            { label: 'Next 6 Periods', value: 6 },
            { label: 'Next 12 Periods', value: 12 }
        ];
    }

    get forecastChartFormat() {
        const metric = this.allMetrics.find(m => m.key === this.selectedForecastMetric);
        return metric ? metric.format : 'Number';
    }

    get forecastChartTitle() {
        const metric = this.allMetrics.find(m => m.key === this.selectedForecastMetric);
        const label = metric ? metric.label : 'Metric';
        const intv = this.trendIntervalOptions.find(i => i.value === this.selectedForecastInterval);
        const intvLabel = intv ? intv.label : 'Time';
        return label + ' — ' + intvLabel + ' Forecast';
    }

    get hasForecastData() {
        return this.forecastDatasets && this.forecastDatasets.length > 0;
    }

    get forecastStatsItems() {
        if (!this.forecastStats) return [];
        return [
            {
                key: 'growth',
                label: 'Historical Growth',
                value: this.forecastStats.growthRatePercent + '%',
                positive: this.forecastStats.growthRatePercent >= 0
            },
            {
                key: 'slope',
                label: 'Trend Slope',
                value: this.formatValue(this.forecastStats.slope, this.selectedForecastMetric) + '/period',
                positive: this.forecastStats.slope >= 0
            },
            {
                key: 'confidence',
                label: 'Fit (R²)',
                value: (this.forecastStats.rSquared * 100).toFixed(0) + '%',
                positive: this.forecastStats.rSquared >= 0.5
            }
        ];
    }

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
        this.loadBreakdownChart();
    }

    handleGroupByChange(event) {
        this.selectedGroupBy = event.detail.value;
        this.loadBreakdownChart();
    }

    handleChartTypeChange(event) {
        this.breakdownChartType = event.detail.value;
    }

    handleTrendMetricChange(event) {
        this.selectedTrendMetric = event.detail.value;
        this.loadTrendChart();
    }

    handleTrendIntervalChange(event) {
        this.selectedTrendInterval = event.detail.value;
        this.loadTrendChart();
    }

    handleForecastMetricChange(event) {
        this.selectedForecastMetric = event.detail.value;
        this.loadForecastChart();
    }

    handleForecastIntervalChange(event) {
        this.selectedForecastInterval = event.detail.value;
        this.loadForecastChart();
    }

    handleForecastHorizonChange(event) {
        this.selectedForecastHorizon = parseInt(event.detail.value, 10);
        this.loadForecastChart();
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

            // Load charts in parallel after KPI cards are ready
            await Promise.all([
                this.selectedChartMetric ? this.loadBreakdownChart() : Promise.resolve(),
                this.selectedTrendMetric ? this.loadTrendChart() : Promise.resolve(),
                this.selectedForecastMetric ? this.loadForecastChart() : Promise.resolve()
            ]);

            const now = new Date();
            this.lastUpdated = now.toLocaleTimeString();
        } catch (error) {
            this.showToast('Error', 'Failed to refresh data: ' + this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadBreakdownChart() {
        if (!this.selectedChartMetric) return;
        try {
            const rows = await getMetricData({
                metricKey: this.selectedChartMetric,
                filtersJson: null,
                groupBy: this.selectedGroupBy,
                dateFrom: this.dateFrom,
                dateTo: this.dateTo,
                userScope: this.userScope
            });
            const metric = this.allMetrics.find(m => m.key === this.selectedChartMetric);
            const color = metric ? metric.color : '#0176d3';
            const labels = rows.map(r => r.label || '(blank)');
            const data = rows.map(r => Number(r.value) || 0);
            this.breakdownLabels = labels;
            this.breakdownDatasets = [{
                label: metric ? metric.label : 'Value',
                data: data,
                color: color
            }];
        } catch (error) {
            console.error('Breakdown chart load failed', error);
            this.breakdownLabels = [];
            this.breakdownDatasets = [];
        }
    }

    async loadTrendChart() {
        if (!this.selectedTrendMetric) return;
        try {
            // Use a longer window for trends so there's enough data to see the pattern
            const trendFrom = this.extendedTrendStart();
            const rows = await getTimeSeries({
                metricKey: this.selectedTrendMetric,
                filtersJson: null,
                dateFrom: trendFrom,
                dateTo: this.dateTo,
                interval: this.selectedTrendInterval,
                userScope: this.userScope
            });
            const metric = this.allMetrics.find(m => m.key === this.selectedTrendMetric);
            const color = metric ? metric.color : '#0176d3';
            const labels = rows.map(r => r.label || '');
            const data = rows.map(r => Number(r.value) || 0);
            this.trendLabels = labels;
            this.trendDatasets = [{
                label: metric ? metric.label : 'Value',
                data: data,
                color: color
            }];
        } catch (error) {
            console.error('Trend chart load failed', error);
            this.trendLabels = [];
            this.trendDatasets = [];
        }
    }

    extendedTrendStart() {
        return this.extendedWindowStart(this.selectedTrendInterval);
    }

    extendedWindowStart(interval) {
        // For trends/forecasts, extend the window backwards to provide enough history
        if (!this.dateTo) return this.dateFrom;
        const end = new Date(this.dateTo);
        let start;
        switch (interval) {
            case 'DAY':
                start = new Date(end.getFullYear(), end.getMonth(), end.getDate() - 30);
                break;
            case 'WEEK':
                start = new Date(end.getFullYear(), end.getMonth(), end.getDate() - 84);
                break;
            case 'MONTH':
                start = new Date(end.getFullYear(), end.getMonth() - 11, 1);
                break;
            case 'QUARTER':
                start = new Date(end.getFullYear() - 2, 0, 1);
                break;
            case 'YEAR':
                start = new Date(end.getFullYear() - 4, 0, 1);
                break;
            default:
                start = new Date(end.getFullYear(), end.getMonth() - 5, 1);
        }
        return this.toISODate(start);
    }

    async loadForecastChart() {
        if (!this.selectedForecastMetric) return;
        try {
            const fromDate = this.extendedWindowStart(this.selectedForecastInterval);
            const result = await getForecast({
                metricKey: this.selectedForecastMetric,
                filtersJson: null,
                dateFrom: fromDate,
                dateTo: this.dateTo,
                interval: this.selectedForecastInterval,
                forecastPeriods: this.selectedForecastHorizon,
                userScope: this.userScope
            });

            const metric = this.allMetrics.find(m => m.key === this.selectedForecastMetric);
            const color = metric ? metric.color : '#0176d3';

            const historical = result.historical || [];
            const forecast = result.forecast || [];

            // Build combined X-axis labels (historical + forecast)
            const labels = [
                ...historical.map(h => h.label || ''),
                ...forecast.map(f => f.label || '')
            ];

            // Historical dataset: actual values, null for forecast positions
            const histValues = historical.map(h => Number(h.value) || 0);
            const histData = [...histValues, ...forecast.map(() => null)];

            // Forecast dataset: null for historical positions, then projected values
            // Include one transition point (last historical value) so the line connects
            const fcData = historical.map(() => null);
            if (histValues.length > 0 && forecast.length > 0) {
                // Replace the last historical null with the actual last value to connect lines
                fcData[fcData.length - 1] = histValues[histValues.length - 1];
            }
            forecast.forEach(f => fcData.push(Number(f.value) || 0));

            // Upper confidence band
            const upperData = historical.map(() => null);
            if (histValues.length > 0 && forecast.length > 0) {
                upperData[upperData.length - 1] = histValues[histValues.length - 1];
            }
            forecast.forEach(f => upperData.push(Number(f.upper) || 0));

            // Lower confidence band
            const lowerData = historical.map(() => null);
            if (histValues.length > 0 && forecast.length > 0) {
                lowerData[lowerData.length - 1] = histValues[histValues.length - 1];
            }
            forecast.forEach(f => lowerData.push(Number(f.lower) || 0));

            this.forecastLabels = labels;
            this.forecastDatasets = [
                {
                    label: 'Upper Bound',
                    data: upperData,
                    color: color,
                    bandUpper: true
                },
                {
                    label: 'Lower Bound',
                    data: lowerData,
                    color: color,
                    bandLower: true
                },
                {
                    label: 'Historical',
                    data: histData,
                    color: color
                },
                {
                    label: 'Forecast',
                    data: fcData,
                    color: color,
                    dashed: true,
                    fill: false
                }
            ];

            this.forecastInsight = result.insight || '';
            this.forecastStats = {
                slope: Number(result.slope) || 0,
                rSquared: Number(result.rSquared) || 0,
                growthRatePercent: Number(result.growthRatePercent) || 0,
                standardError: Number(result.standardError) || 0
            };
        } catch (error) {
            console.error('Forecast load failed', error);
            this.forecastLabels = [];
            this.forecastDatasets = [];
            this.forecastInsight = 'Unable to generate forecast: ' + this.reduceError(error);
            this.forecastStats = null;
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
