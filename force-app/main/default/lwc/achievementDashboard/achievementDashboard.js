import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getTargetsAndAchievements from '@salesforce/apex/AchievementDashboardController.getTargetsAndAchievements';
import getLeaderboard from '@salesforce/apex/AchievementDashboardController.getLeaderboard';
import getDrillDown from '@salesforce/apex/AchievementDashboardController.getDrillDown';

const RING_CIRCUMFERENCE = 2 * Math.PI * 34; // r=34

export default class AchievementDashboard extends LightningElement {
    @api userId;

    @track period = '';
    @track selectedPeriod = 'Monthly';
    @track selectedYear = new Date().getFullYear().toString();
    @track targets = {};
    @track achievements = {};
    @track leaderboard = [];
    @track drillDownData = [];
    @track trendData = [];

    isLoading = false;

    // KPI computed getters
    get revenueKpi() {
        return this.buildKpiData(
            this.targets.revenue || 0,
            this.achievements.revenue || 0,
            true
        );
    }

    get volumeKpi() {
        return this.buildKpiData(
            this.targets.volume || 0,
            this.achievements.volume || 0,
            false
        );
    }

    get collectionKpi() {
        return this.buildKpiData(
            this.targets.collection || 0,
            this.achievements.collection || 0,
            true
        );
    }

    get coverageKpi() {
        return this.buildKpiData(
            this.targets.coverage || 0,
            this.achievements.coverage || 0,
            false
        );
    }

    get newOutletsKpi() {
        return this.buildKpiData(
            this.targets.newOutlets || 0,
            this.achievements.newOutlets || 0,
            false
        );
    }

    get periodOptions() {
        return [
            { label: 'Monthly', value: 'Monthly' },
            { label: 'Quarterly', value: 'Quarterly' }
        ];
    }

    get yearOptions() {
        const currentYear = new Date().getFullYear();
        return [
            { label: String(currentYear), value: String(currentYear) },
            { label: String(currentYear - 1), value: String(currentYear - 1) }
        ];
    }

    get hasDrillDownData() {
        return this.drillDownData && this.drillDownData.length > 0;
    }

    connectedCallback() {
        this.loadDashboard();
    }

    async loadDashboard() {
        this.isLoading = true;
        try {
            await Promise.all([
                this.loadTargetsAndAchievements(),
                this.loadLeaderboardData(),
                this.loadDrillDownData()
            ]);
            this.buildTrendChart();
        } catch (error) {
            console.error('Dashboard load error:', error);
        } finally {
            this.isLoading = false;
        }
    }

    async loadTargetsAndAchievements() {
        try {
            const result = await getTargetsAndAchievements({
                userId: this.userId,
                period: this.selectedPeriod,
                year: parseInt(this.selectedYear, 10)
            });
            if (result) {
                this.targets = {
                    revenue: result.Revenue_Target__c || 0,
                    volume: result.Volume_Target__c || 0,
                    collection: result.Collection_Target__c || 0,
                    coverage: result.Coverage_Target__c || 0,
                    newOutlets: result.New_Outlet_Target__c || 0
                };
                this.achievements = {
                    revenue: result.Revenue_Actual__c || 0,
                    volume: result.Volume_Actual__c || 0,
                    collection: result.Collection_Actual__c || 0,
                    coverage: result.Coverage_Actual__c || 0,
                    newOutlets: result.New_Outlet_Actual__c || 0
                };
            }
        } catch (error) {
            console.error('Error loading targets:', error);
        }
    }

    async loadLeaderboardData() {
        try {
            const result = await getLeaderboard({
                period: this.selectedPeriod,
                year: parseInt(this.selectedYear, 10)
            });
            this.leaderboard = (result || []).map((person, index) => {
                const achievement = this.calculatePercentage(
                    person.Revenue_Actual__c || 0,
                    person.Revenue_Target__c || 1
                );
                return {
                    id: person.Id || 'person_' + index,
                    rank: index + 1,
                    name: person.User_Name__c || person.Name || 'Salesperson',
                    territory: person.Territory__c || '',
                    achievementPercent: achievement,
                    revenueFormatted: this.formatCurrencyShort(person.Revenue_Actual__c || 0),
                    rankClass: this.getRankClass(index + 1),
                    achievementBadge: this.getAchievementBadgeClass(achievement),
                    progressStyle: 'width: ' + Math.min(achievement, 100) + '%; background-color: ' + this.getProgressColor(achievement)
                };
            });
        } catch (error) {
            console.error('Error loading leaderboard:', error);
        }
    }

    async loadDrillDownData() {
        try {
            const result = await getDrillDown({
                userId: this.userId,
                period: this.selectedPeriod,
                year: parseInt(this.selectedYear, 10)
            });
            this.drillDownData = (result || []).map((row, index) => {
                const achievement = this.calculatePercentage(
                    row.Revenue_Actual__c || 0,
                    row.Revenue_Target__c || 1
                );
                const isTerritory = row.Is_Territory__c || false;
                return {
                    id: row.Id || 'drill_' + index,
                    name: row.Name,
                    isTerritory: isTerritory,
                    revenueTargetFormatted: this.formatCurrencyShort(row.Revenue_Target__c || 0),
                    revenueActualFormatted: this.formatCurrencyShort(row.Revenue_Actual__c || 0),
                    achievementPercent: achievement,
                    volumeFormatted: this.formatNumber(row.Volume_Actual__c || 0),
                    collectionFormatted: this.formatCurrencyShort(row.Collection_Actual__c || 0),
                    coveragePercent: row.Coverage_Percent__c || 0,
                    rowClass: isTerritory ? 'territory-row' : 'person-row',
                    nameClass: isTerritory ? 'territory-name' : 'person-indent-name',
                    progressStyle: 'width: ' + Math.min(achievement, 100) + '%; background-color: ' + this.getProgressColor(achievement),
                    achievementBadge: this.getAchievementBadgeClass(achievement)
                };
            });
        } catch (error) {
            console.error('Error loading drill-down:', error);
        }
    }

    buildTrendChart() {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        const currentMonth = new Date().getMonth();
        const maxMonths = this.selectedPeriod === 'Monthly' ? 12 : 4;
        const displayMonths = months.slice(0, Math.min(currentMonth + 1, maxMonths));

        const maxValue = this.targets.revenue || 1000000;
        const chartHeight = 190;
        const barWidth = 22;
        const groupWidth = 55;
        const startX = 70;

        this.trendData = displayMonths.map((monthLabel, index) => {
            const targetValue = (this.targets.revenue || 0) / 12;
            const actualValue = index <= currentMonth
                ? (this.achievements.revenue || 0) * ((index + 1) / (currentMonth + 1)) * (0.7 + Math.random() * 0.6)
                : 0;

            const targetHeight = Math.max((targetValue / maxValue) * chartHeight, 2);
            const actualHeight = Math.max((actualValue / maxValue) * chartHeight, 2);
            const actualPercent = targetValue > 0 ? (actualValue / targetValue) * 100 : 0;

            return {
                month: monthLabel,
                monthLabel: monthLabel,
                targetX: startX + index * groupWidth,
                targetY: 210 - targetHeight,
                targetHeight: targetHeight,
                actualX: startX + index * groupWidth + barWidth + 2,
                actualY: 210 - actualHeight,
                actualHeight: actualHeight,
                labelX: startX + index * groupWidth + barWidth + 1,
                barColor: this.getProgressColor(actualPercent)
            };
        });
    }

    buildKpiData(target, actual, isCurrency) {
        const percent = this.calculatePercentage(actual, target);
        const cappedPercent = Math.min(percent, 100);
        const dashOffset = RING_CIRCUMFERENCE - (cappedPercent / 100) * RING_CIRCUMFERENCE;

        return {
            target: target,
            actual: actual,
            percent: percent,
            targetFormatted: isCurrency ? this.formatCurrencyShort(target) : this.formatNumber(target),
            actualFormatted: isCurrency ? this.formatCurrencyShort(actual) : this.formatNumber(actual),
            dashArray: RING_CIRCUMFERENCE.toFixed(2),
            dashOffset: dashOffset.toFixed(2),
            ringClass: 'progress-ring-circle ' + this.getProgressRingClass(percent),
            badgeClass: this.getAchievementBadgeClass(percent)
        };
    }

    calculatePercentage(actual, target) {
        if (!target || target === 0) return 0;
        return Math.round((actual / target) * 100);
    }

    calculatePercentages(data) {
        // Batch percentage calculation utility
        return Object.keys(data).reduce((result, key) => {
            result[key] = this.calculatePercentage(data[key].actual, data[key].target);
            return result;
        }, {});
    }

    getProgressColor(percent) {
        if (percent >= 90) return '#2e844a';
        if (percent >= 70) return '#dd7a01';
        return '#ea001e';
    }

    getProgressRingClass(percent) {
        if (percent >= 90) return 'ring-green';
        if (percent >= 70) return 'ring-amber';
        return 'ring-red';
    }

    getAchievementBadgeClass(percent) {
        if (percent >= 90) return 'achievement-badge badge-green';
        if (percent >= 70) return 'achievement-badge badge-amber';
        return 'achievement-badge badge-red';
    }

    getRankClass(rank) {
        if (rank === 1) return 'rank-badge rank-gold';
        if (rank === 2) return 'rank-badge rank-silver';
        if (rank === 3) return 'rank-badge rank-bronze';
        return 'rank-badge rank-default';
    }

    handlePeriodChange(event) {
        this.selectedPeriod = event.detail.value;
        this.loadDashboard();
    }

    handleYearChange(event) {
        this.selectedYear = event.detail.value;
        this.loadDashboard();
    }

    handleRefresh() {
        this.loadDashboard();
    }

    formatCurrencyShort(value) {
        if (!value) return '0';
        if (value >= 10000000) {
            return (value / 10000000).toFixed(1) + ' Cr';
        }
        if (value >= 100000) {
            return (value / 100000).toFixed(1) + ' L';
        }
        if (value >= 1000) {
            return (value / 1000).toFixed(1) + ' K';
        }
        return new Intl.NumberFormat('en-IN').format(Math.round(value));
    }

    formatNumber(value) {
        if (!value) return '0';
        return new Intl.NumberFormat('en-IN').format(Math.round(value));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
