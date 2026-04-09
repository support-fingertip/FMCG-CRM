import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import ChartJs from '@salesforce/resourceUrl/ChartJs';

/**
 * Universal Chart widget for the Dynamic KPI Dashboard.
 *
 * Usage:
 *   <c-dkd-chart-widget
 *       chart-type="bar"                          // bar | horizontalBar | line | pie | doughnut
 *       labels={labelsArray}                      // ['Q1','Q2','Q3','Q4']
 *       datasets={datasetsArray}                  // [{label:'Rev', data:[1,2,3,4], color:'#0176d3'}]
 *       title="Revenue by Quarter"
 *       height="300"
 *       format="Currency">
 *   </c-dkd-chart-widget>
 */
const DEFAULT_COLORS = [
    '#0176d3', '#2e844a', '#7b61ff', '#dd7a01',
    '#c23934', '#7e5cef', '#06a59a', '#ffa41c',
    '#0b827c', '#9c4aa1', '#f04e2e', '#3b9855'
];

export default class DkdChartWidget extends LightningElement {
    @api chartType = 'bar';          // bar | horizontalBar | line | pie | doughnut
    @api title = '';
    @api height = 300;
    @api format = 'Number';          // Currency | Number | Percent | Duration
    @api showLegend = true;

    _labels = [];
    _datasets = [];
    chartJsLoaded = false;
    chartInstance = null;
    renderPending = false;

    @api
    get labels() { return this._labels; }
    set labels(value) {
        this._labels = value || [];
        this.scheduleRender();
    }

    @api
    get datasets() { return this._datasets; }
    set datasets(value) {
        this._datasets = value || [];
        this.scheduleRender();
    }

    connectedCallback() {
        if (window.Chart) {
            this.chartJsLoaded = true;
            this.scheduleRender();
            return;
        }
        loadScript(this, ChartJs)
            .then(() => {
                this.chartJsLoaded = true;
                this.scheduleRender();
            })
            .catch(err => {
                console.error('Chart.js load failed', err);
            });
    }

    disconnectedCallback() {
        if (this.chartInstance) {
            this.chartInstance.destroy();
            this.chartInstance = null;
        }
    }

    renderedCallback() {
        if (this.renderPending && this.chartJsLoaded) {
            this.renderPending = false;
            this.renderChart();
        }
    }

    // ── Rendering ────────────────────────────────────────────────

    scheduleRender() {
        this.renderPending = true;
        if (this.chartJsLoaded) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                if (this.renderPending) {
                    this.renderPending = false;
                    this.renderChart();
                }
            }, 50);
        }
    }

    renderChart() {
        const canvas = this.template.querySelector('canvas');
        if (!canvas || !window.Chart) return;

        // Destroy previous instance to avoid canvas conflicts
        if (this.chartInstance) {
            this.chartInstance.destroy();
            this.chartInstance = null;
        }

        if (!this._datasets.length || !this._labels.length) {
            return;
        }

        const isPie = this.chartType === 'pie' || this.chartType === 'doughnut';
        const isHorizontal = this.chartType === 'horizontalBar';
        const actualType = isHorizontal ? 'bar' : this.chartType;

        const datasets = this._datasets.map((ds, idx) => {
            const color = ds.color || DEFAULT_COLORS[idx % DEFAULT_COLORS.length];
            if (isPie) {
                // Pie/doughnut: use color array per slice
                return {
                    label: ds.label || '',
                    data: ds.data || [],
                    backgroundColor: this._labels.map((_, i) => DEFAULT_COLORS[i % DEFAULT_COLORS.length]),
                    borderWidth: 2,
                    borderColor: '#fff'
                };
            }
            if (this.chartType === 'line') {
                const lineDs = {
                    label: ds.label || '',
                    data: ds.data || [],
                    borderColor: color,
                    backgroundColor: ds.fill === false ? 'transparent' : this.hexToRgba(color, 0.12),
                    fill: ds.fill !== false,
                    tension: 0.3,
                    pointRadius: ds.pointRadius !== undefined ? ds.pointRadius : 4,
                    pointBackgroundColor: color,
                    borderWidth: 2
                };
                // Dashed line support (for forecast/projection datasets)
                if (ds.dashed) {
                    lineDs.borderDash = [6, 6];
                }
                // Confidence band datasets typically use no points and no fill
                // Expected order: Upper bound (bandUpper), then Lower bound (bandLower).
                // Lower fills back to the previous dataset (-1 = Upper) to shade the band.
                if (ds.bandUpper) {
                    lineDs.fill = false;
                    lineDs.borderWidth = 0;
                    lineDs.pointRadius = 0;
                }
                if (ds.bandLower) {
                    lineDs.fill = '-1';  // fill to previous dataset (the Upper bound)
                    lineDs.backgroundColor = this.hexToRgba(color, 0.1);
                    lineDs.borderWidth = 0;
                    lineDs.pointRadius = 0;
                }
                return lineDs;
            }
            // Bar / horizontal bar
            return {
                label: ds.label || '',
                data: ds.data || [],
                backgroundColor: color,
                borderColor: color,
                borderWidth: 1,
                borderRadius: 4
            };
        });

        const options = {
            responsive: true,
            maintainAspectRatio: false,
            indexAxis: isHorizontal ? 'y' : 'x',
            plugins: {
                legend: {
                    display: this.showLegend && (datasets.length > 1 || isPie),
                    position: isPie ? 'bottom' : 'top',
                    labels: { font: { size: 11 }, padding: 10, boxWidth: 12 }
                },
                tooltip: {
                    callbacks: {
                        label: (ctx) => {
                            const label = ctx.dataset.label || ctx.label || '';
                            const value = ctx.parsed.y !== undefined ? ctx.parsed.y
                                        : (ctx.parsed.x !== undefined ? ctx.parsed.x : ctx.parsed);
                            return label + ': ' + this.formatValue(value);
                        }
                    }
                }
            }
        };

        if (!isPie) {
            options.scales = {
                y: {
                    beginAtZero: true,
                    ticks: {
                        callback: (v) => this.formatValue(v)
                    },
                    grid: { color: 'rgba(0,0,0,0.06)' }
                },
                x: {
                    grid: { display: false }
                }
            };
        } else {
            options.cutout = this.chartType === 'doughnut' ? '60%' : '0%';
        }

        this.chartInstance = new window.Chart(canvas.getContext('2d'), {
            type: actualType,
            data: { labels: this._labels, datasets },
            options
        });
    }

    // ── Formatting helpers ──────────────────────────────────────

    formatValue(value) {
        const num = Number(value) || 0;
        if (this.format === 'Currency') {
            if (num >= 10000000) return '₹' + (num / 10000000).toFixed(1) + 'Cr';
            if (num >= 100000) return '₹' + (num / 100000).toFixed(1) + 'L';
            if (num >= 1000) return '₹' + (num / 1000).toFixed(1) + 'K';
            return '₹' + num.toFixed(0);
        }
        if (this.format === 'Percent') return num.toFixed(1) + '%';
        if (this.format === 'Duration') return Math.round(num) + 'm';
        if (num >= 10000000) return (num / 10000000).toFixed(1) + 'Cr';
        if (num >= 100000) return (num / 100000).toFixed(1) + 'L';
        if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
        return new Intl.NumberFormat('en-IN').format(Math.round(num));
    }

    hexToRgba(hex, alpha) {
        if (!hex) return 'rgba(1, 118, 211, ' + alpha + ')';
        let h = hex.replace('#', '');
        if (h.length === 3) {
            h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
        }
        const r = parseInt(h.substring(0, 2), 16);
        const g = parseInt(h.substring(2, 4), 16);
        const b = parseInt(h.substring(4, 6), 16);
        return 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
    }

    get canvasContainerStyle() {
        return 'position: relative; height: ' + this.height + 'px; width: 100%;';
    }

    get hasData() {
        return this._labels && this._labels.length > 0 &&
               this._datasets && this._datasets.length > 0 &&
               this._datasets.some(d => d.data && d.data.length > 0);
    }
}
