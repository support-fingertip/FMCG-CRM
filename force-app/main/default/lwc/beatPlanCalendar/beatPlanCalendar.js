import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getJourneyPlan from '@salesforce/apex/BeatPlanController.getJourneyPlan';
import getBeatsForTerritory from '@salesforce/apex/BeatPlanController.getBeatsForTerritory';
import submitForApproval from '@salesforce/apex/BeatPlanController.submitForApproval';

const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];

const BEAT_COLORS = [
    '#1abc9c', '#3498db', '#9b59b6', '#e74c3c', '#f39c12',
    '#2ecc71', '#e67e22', '#1a5276', '#c0392b', '#27ae60',
    '#8e44ad', '#2980b9', '#d35400', '#16a085', '#7f8c8d'
];

export default class BeatPlanCalendar extends LightningElement {
    @api userId;
    @api month;
    @api year;

    @track calendarData = {};
    @track journeyPlan = {};
    @track weekView = true;
    @track weekDays = [];
    @track monthWeeks = [];
    @track summaryStats = {
        totalPlannedVisits: 0,
        coveragePercent: 0,
        assignedBeats: 0,
        totalOutlets: 0,
        avgVisitsPerDay: 0
    };
    @track selectedDayDetail = null;
    @track availableBeats = [];
    @track pjpStatus = 'Draft';

    currentDate = new Date();
    currentWeekStart = null;
    currentMonth = null;
    currentYear = null;
    isLoading = false;
    beatColorMap = {};
    allBeats = [];

    get calendarTitle() {
        if (this.weekView) {
            if (!this.weekDays || this.weekDays.length === 0) return '';
            const start = this.weekDays[0];
            const end = this.weekDays[this.weekDays.length - 1];
            return (start ? start.dateDisplay : '') + ' - ' + (end ? end.dateDisplay : '');
        }
        return MONTH_NAMES[this.currentMonth] + ' ' + this.currentYear;
    }

    get weekBtnVariant() {
        return this.weekView ? 'brand' : 'neutral';
    }

    get monthBtnVariant() {
        return this.weekView ? 'neutral' : 'brand';
    }

    get pjpStatusBadgeClass() {
        const statusMap = {
            'Draft': 'pjp-badge pjp-draft',
            'Pending Approval': 'pjp-badge pjp-pending',
            'Approved': 'pjp-badge pjp-approved',
            'Active': 'pjp-badge pjp-active',
            'Rejected': 'pjp-badge pjp-rejected'
        };
        return statusMap[this.pjpStatus] || 'pjp-badge pjp-draft';
    }

    get isApprovalDisabled() {
        return this.pjpStatus !== 'Draft' && this.pjpStatus !== 'Rejected';
    }

    connectedCallback() {
        const today = new Date();
        this.currentMonth = this.month !== undefined ? this.month : today.getMonth();
        this.currentYear = this.year !== undefined ? this.year : today.getFullYear();
        this.currentWeekStart = this.getWeekStart(today);
        this.loadCalendar();
        this.loadBeats();
    }

    async loadCalendar() {
        this.isLoading = true;
        try {
            const result = await getJourneyPlan({
                userId: this.userId,
                month: this.currentMonth + 1,
                year: this.currentYear
            });

            if (result) {
                this.journeyPlan = result.journeyPlan || {};
                this.pjpStatus = result.journeyPlan?.Status__c || 'Draft';
                this.calendarData = this.buildCalendarData(result.planDays || []);
                this.calculateSummaryStats(result.planDays || []);
            }

            if (this.weekView) {
                this.buildWeekView();
            } else {
                this.buildMonthView();
            }
        } catch (error) {
            console.error('Error loading journey plan:', error);
            if (this.weekView) {
                this.buildWeekView();
            } else {
                this.buildMonthView();
            }
        } finally {
            this.isLoading = false;
        }
    }

    async loadBeats() {
        try {
            const result = await getBeatsForTerritory({ userId: this.userId });
            this.allBeats = (result || []).map((beat, index) => {
                const color = BEAT_COLORS[index % BEAT_COLORS.length];
                this.beatColorMap[beat.Id] = color;
                return {
                    id: beat.Id,
                    name: beat.Name,
                    outletCount: beat.Outlet_Count__c || 0,
                    territory: beat.Territory__c || '',
                    colorStyle: 'background-color: ' + color,
                    color: color
                };
            });
            this.availableBeats = [...this.allBeats];
        } catch (error) {
            console.error('Error loading beats:', error);
        }
    }

    buildCalendarData(planDays) {
        const data = {};
        planDays.forEach(day => {
            const dateKey = day.Plan_Date__c;
            if (!data[dateKey]) {
                data[dateKey] = { beats: [], totalVisits: 0 };
            }
            const beatColor = this.beatColorMap[day.Beat__c] ||
                BEAT_COLORS[Object.keys(data).length % BEAT_COLORS.length];

            data[dateKey].beats.push({
                id: day.Beat__c || day.Id,
                name: day.Beat_Name__c || day.Beat__r?.Name || 'Beat',
                outletCount: day.Outlet_Count__c || 0,
                colorStyle: 'background-color: ' + beatColor,
                color: beatColor
            });
            data[dateKey].totalVisits += day.Outlet_Count__c || 0;
        });
        return data;
    }

    calculateSummaryStats(planDays) {
        const uniqueDates = new Set();
        const uniqueBeats = new Set();
        let totalVisits = 0;
        let totalOutlets = 0;

        planDays.forEach(day => {
            uniqueDates.add(day.Plan_Date__c);
            uniqueBeats.add(day.Beat__c);
            totalVisits += day.Outlet_Count__c || 0;
            totalOutlets += day.Outlet_Count__c || 0;
        });

        const workingDays = this.weekView ? 6 : this.getWorkingDaysInMonth();
        const coverage = workingDays > 0 ? Math.round((uniqueDates.size / workingDays) * 100) : 0;

        this.summaryStats = {
            totalPlannedVisits: totalVisits,
            coveragePercent: Math.min(coverage, 100),
            assignedBeats: uniqueBeats.size,
            totalOutlets: totalOutlets,
            avgVisitsPerDay: uniqueDates.size > 0 ? Math.round(totalVisits / uniqueDates.size) : 0
        };
    }

    buildWeekView() {
        const weekStart = new Date(this.currentWeekStart);
        const days = [];
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        for (let i = 0; i < 7; i++) {
            const date = new Date(weekStart);
            date.setDate(weekStart.getDate() + i);
            const dateKey = this.formatDateKey(date);
            const dayData = this.calendarData[dateKey] || { beats: [], totalVisits: 0 };
            const isToday = date.getTime() === today.getTime();
            const isSunday = date.getDay() === 0;

            days.push({
                dateKey: dateKey,
                dayName: DAY_NAMES[date.getDay()],
                dateDisplay: date.getDate() + ' ' + MONTH_NAMES[date.getMonth()].substring(0, 3),
                dateNumber: date.getDate(),
                beats: dayData.beats.length > 0 ? dayData.beats : null,
                totalVisits: dayData.totalVisits,
                headerClass: 'day-header' + (isToday ? ' today-header' : '') + (isSunday ? ' sunday-header' : ''),
                cellClass: 'day-cell' + (isToday ? ' today-cell' : '') + (isSunday ? ' sunday-cell' : '')
            });
        }
        this.weekDays = days;
    }

    buildMonthView() {
        const firstDay = new Date(this.currentYear, this.currentMonth, 1);
        const lastDay = new Date(this.currentYear, this.currentMonth + 1, 0);
        const startDay = firstDay.getDay();
        const totalDays = lastDay.getDate();
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const weeks = [];
        let currentDay = 1 - startDay;
        let weekNum = 0;

        while (currentDay <= totalDays) {
            const week = { id: 'week_' + weekNum, days: [] };

            for (let i = 0; i < 7; i++) {
                const date = new Date(this.currentYear, this.currentMonth, currentDay);
                const dateKey = this.formatDateKey(date);
                const dayData = this.calendarData[dateKey] || { beats: [], totalVisits: 0 };
                const isCurrentMonth = currentDay >= 1 && currentDay <= totalDays;
                const isToday = isCurrentMonth && date.getTime() === today.getTime();
                const isSunday = i === 0;

                week.days.push({
                    dateKey: dateKey,
                    dateNumber: isCurrentMonth ? currentDay : '',
                    beats: dayData.beats.length > 0 ? dayData.beats : null,
                    totalVisits: dayData.totalVisits,
                    monthCellClass: 'month-cell' +
                        (isCurrentMonth ? '' : ' other-month') +
                        (isToday ? ' today-cell' : '') +
                        (isSunday ? ' sunday-cell' : ''),
                    dateNumberClass: 'date-number' + (isToday ? ' today-date' : '')
                });
                currentDay++;
            }
            weeks.push(week);
            weekNum++;
        }
        this.monthWeeks = weeks;
    }

    switchToWeekView() {
        this.weekView = true;
        this.buildWeekView();
    }

    switchToMonthView() {
        this.weekView = false;
        this.buildMonthView();
    }

    selectDay(event) {
        const dateKey = event.currentTarget.dataset.date;
        if (!dateKey) return;

        const dayData = this.calendarData[dateKey] || { beats: [], totalVisits: 0 };
        const date = new Date(dateKey);

        this.selectedDayDetail = {
            dateKey: dateKey,
            dateDisplay: date.toLocaleDateString('en-IN', {
                weekday: 'long',
                day: '2-digit',
                month: 'long',
                year: 'numeric'
            }),
            beats: dayData.beats.length > 0 ? dayData.beats : null,
            totalVisits: dayData.totalVisits
        };

        // Filter available beats (exclude already assigned)
        const assignedBeatIds = (dayData.beats || []).map(b => b.id);
        this.availableBeats = this.allBeats.filter(b => !assignedBeatIds.includes(b.id));
    }

    assignBeatToDay(event) {
        const beatId = event.currentTarget.dataset.beatId;
        if (!this.selectedDayDetail || !beatId) return;

        const beat = this.allBeats.find(b => b.id === beatId);
        if (!beat) return;

        const dateKey = this.selectedDayDetail.dateKey;
        if (!this.calendarData[dateKey]) {
            this.calendarData[dateKey] = { beats: [], totalVisits: 0 };
        }

        this.calendarData[dateKey].beats.push({
            id: beat.id,
            name: beat.name,
            outletCount: beat.outletCount,
            colorStyle: beat.colorStyle,
            color: beat.color
        });
        this.calendarData[dateKey].totalVisits += beat.outletCount;

        // Refresh views
        this.selectDay({ currentTarget: { dataset: { date: dateKey } } });
        if (this.weekView) {
            this.buildWeekView();
        } else {
            this.buildMonthView();
        }

        this.showToast('Success', beat.name + ' assigned to ' + this.selectedDayDetail.dateDisplay, 'success');
    }

    handlePrevious() {
        if (this.weekView) {
            this.currentWeekStart.setDate(this.currentWeekStart.getDate() - 7);
            this.buildWeekView();
        } else {
            this.currentMonth--;
            if (this.currentMonth < 0) {
                this.currentMonth = 11;
                this.currentYear--;
            }
            this.loadCalendar();
        }
    }

    handleNext() {
        if (this.weekView) {
            this.currentWeekStart.setDate(this.currentWeekStart.getDate() + 7);
            this.buildWeekView();
        } else {
            this.currentMonth++;
            if (this.currentMonth > 11) {
                this.currentMonth = 0;
                this.currentYear++;
            }
            this.loadCalendar();
        }
    }

    handleToday() {
        const today = new Date();
        this.currentMonth = today.getMonth();
        this.currentYear = today.getFullYear();
        this.currentWeekStart = this.getWeekStart(today);
        this.loadCalendar();
    }

    async handleSubmitApproval() {
        if (!this.journeyPlan.Id) {
            this.showToast('Warning', 'No journey plan to submit', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            await submitForApproval({ journeyPlanId: this.journeyPlan.Id });
            this.pjpStatus = 'Pending Approval';
            this.showToast('Success', 'Journey Plan submitted for approval', 'success');
        } catch (error) {
            this.showToast('Error', 'Approval submission failed: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Helper methods
    getWeekStart(date) {
        const d = new Date(date);
        const day = d.getDay();
        d.setDate(d.getDate() - day);
        d.setHours(0, 0, 0, 0);
        return d;
    }

    getWorkingDaysInMonth() {
        const firstDay = new Date(this.currentYear, this.currentMonth, 1);
        const lastDay = new Date(this.currentYear, this.currentMonth + 1, 0);
        let count = 0;
        for (let d = new Date(firstDay); d <= lastDay; d.setDate(d.getDate() + 1)) {
            if (d.getDay() !== 0) count++; // Exclude Sundays
        }
        return count;
    }

    formatDateKey(date) {
        const y = date.getFullYear();
        const m = String(date.getMonth() + 1).padStart(2, '0');
        const d = String(date.getDate()).padStart(2, '0');
        return y + '-' + m + '-' + d;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'Unknown error';
    }
}