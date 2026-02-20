import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import Id from '@salesforce/user/Id';

import getJourneyPlanById from '@salesforce/apex/BeatPlanController.getJourneyPlanById';
import getJourneyPlan from '@salesforce/apex/BeatPlanController.getJourneyPlan';
import getBeatsForUser from '@salesforce/apex/BeatPlanController.getBeatsForUser';
import submitForApproval from '@salesforce/apex/BeatPlanController.submitForApproval';

// Fields to read from the Journey_Plan__c record page context
const JP_SALESPERSON_FIELD = 'Journey_Plan__c.Salesperson__c';
const JP_MONTH_FIELD = 'Journey_Plan__c.Month__c';
const JP_YEAR_FIELD = 'Journey_Plan__c.Year__c';
const JP_STATUS_FIELD = 'Journey_Plan__c.Status__c';

const JP_FIELDS = [JP_SALESPERSON_FIELD, JP_MONTH_FIELD, JP_YEAR_FIELD, JP_STATUS_FIELD];

const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];

const BEAT_COLORS = [
    '#1abc9c', '#3498db', '#9b59b6', '#e74c3c', '#f39c12',
    '#2ecc71', '#e67e22', '#1a5276', '#c0392b', '#27ae60',
    '#8e44ad', '#2980b9', '#d35400', '#16a085', '#7f8c8d'
];

export default class BeatPlanCalendar extends LightningElement {
    // recordId is auto-set when placed on a Journey_Plan__c record page
    @api recordId;

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

    currentUserId = Id;
    resolvedUserId = null;
    currentDate = new Date();
    currentWeekStart = null;
    currentMonth = null;
    currentYear = null;
    isLoading = false;
    beatColorMap = {};
    allBeats = [];
    dataLoaded = false;

    /**
     * Wire adapter: reads the Journey_Plan__c record fields when on a record page.
     * Once we have the Salesperson__c, we use it to load beats.
     */
    @wire(getRecord, { recordId: '$recordId', fields: JP_FIELDS })
    wiredJourneyPlanRecord({ error, data }) {
        if (data) {
            this.resolvedUserId = getFieldValue(data, JP_SALESPERSON_FIELD);
            const monthName = getFieldValue(data, JP_MONTH_FIELD);
            const yearStr = getFieldValue(data, JP_YEAR_FIELD);
            this.pjpStatus = getFieldValue(data, JP_STATUS_FIELD) || 'Draft';

            // Set month/year from the record
            if (monthName) {
                const monthIdx = MONTH_NAMES.indexOf(monthName);
                if (monthIdx >= 0) {
                    this.currentMonth = monthIdx;
                }
            }
            if (yearStr) {
                this.currentYear = parseInt(yearStr, 10);
            }

            // Load data once we have the user resolved
            if (!this.dataLoaded) {
                this.dataLoaded = true;
                this.loadCalendar();
                this.loadBeats();
            }
        } else if (error) {
            console.error('Error loading Journey Plan record:', error);
            // Fallback: load with current user
            if (!this.dataLoaded) {
                this.resolvedUserId = this.currentUserId;
                this.dataLoaded = true;
                this.loadCalendar();
                this.loadBeats();
            }
        }
    }

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
            'Submitted': 'pjp-badge pjp-pending',
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
        if (this.currentMonth === null) {
            this.currentMonth = today.getMonth();
        }
        if (this.currentYear === null) {
            this.currentYear = today.getFullYear();
        }
        this.currentWeekStart = this.getWeekStart(today);

        // If there's no recordId (e.g. placed on a Home/App page), load immediately
        // using the current user. If recordId is present, the @wire will handle it.
        if (!this.recordId) {
            this.resolvedUserId = this.currentUserId;
            this.dataLoaded = true;
            this.loadCalendar();
            this.loadBeats();
        }
    }

    /**
     * Loads the journey plan. Uses getJourneyPlanById when we have a recordId,
     * otherwise falls back to getJourneyPlan with user/month/year.
     */
    async loadCalendar() {
        this.isLoading = true;
        try {
            let result;

            if (this.recordId) {
                // On a Journey Plan record page - load by record Id directly
                result = await getJourneyPlanById({ journeyPlanId: this.recordId });
            } else if (this.resolvedUserId) {
                // Standalone usage - load by user + month + year
                const monthName = MONTH_NAMES[this.currentMonth];
                const yearStr = String(this.currentYear);
                result = await getJourneyPlan({
                    userId: this.resolvedUserId,
                    month: monthName,
                    year: yearStr
                });
            }

            if (result) {
                this.journeyPlan = result.journeyPlan || {};
                this.pjpStatus = result.journeyPlan?.Status__c || this.pjpStatus || 'Draft';
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

    /**
     * Loads beats for the salesperson by calling getBeatsForUser,
     * which resolves the territory automatically on the server.
     */
    async loadBeats() {
        try {
            const userId = this.resolvedUserId || this.currentUserId;
            if (!userId) {
                console.warn('No userId available to load beats');
                return;
            }

            const result = await getBeatsForUser({ userId: userId });
            this.allBeats = (result || []).map((beat, index) => {
                const color = BEAT_COLORS[index % BEAT_COLORS.length];
                this.beatColorMap[beat.Id] = color;
                return {
                    id: beat.Id,
                    name: beat.Name,
                    outletCount: beat.Total_Outlets__c || 0,
                    territory: beat.Territory__r?.Name || '',
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
        // Map Journey_Plan_Day__c records into the calendar.
        // Each day has Day_of_Week__c (Monday, Tuesday...) and Week_Number__c (Week 1, Week 2...).
        // We need to convert these into actual date keys for the calendar grid.
        const effectiveFrom = this.journeyPlan?.Effective_From__c;
        const monthStart = effectiveFrom
            ? new Date(effectiveFrom)
            : new Date(this.currentYear, this.currentMonth, 1);

        // Build a lookup from (weekNumber, dayOfWeek) → actual date
        const dayNameToIndex = {
            'Sunday': 0, 'Monday': 1, 'Tuesday': 2, 'Wednesday': 3,
            'Thursday': 4, 'Friday': 5, 'Saturday': 6
        };

        planDays.forEach(day => {
            // Calculate the actual date for this plan day entry
            const weekNum = this.parseWeekNumber(day.Week_Number__c); // 1-based
            const dayIdx = dayNameToIndex[day.Day_of_Week__c];

            if (dayIdx === undefined || !weekNum) {
                return; // Skip invalid entries
            }

            // Find the first occurrence of the day in the month, then offset by week
            const firstOfMonth = new Date(this.currentYear, this.currentMonth, 1);
            const firstDayOfWeekInMonth = firstOfMonth.getDay();
            let dateOffset = dayIdx - firstDayOfWeekInMonth;
            if (dateOffset < 0) dateOffset += 7;
            const actualDate = new Date(this.currentYear, this.currentMonth, 1 + dateOffset + (weekNum - 1) * 7);

            const dateKey = this.formatDateKey(actualDate);

            if (!data[dateKey]) {
                data[dateKey] = { beats: [], totalVisits: 0 };
            }

            const beatColor = this.beatColorMap[day.Beat__c] ||
                BEAT_COLORS[Object.keys(data).length % BEAT_COLORS.length];

            // Assign color to map for consistency
            if (day.Beat__c) {
                this.beatColorMap[day.Beat__c] = beatColor;
            }

            data[dateKey].beats.push({
                id: day.Beat__c || day.Id,
                name: day.Beat__r?.Name || 'Beat',
                outletCount: day.Planned_Outlets__c || day.Beat__r?.Total_Outlets__c || 0,
                colorStyle: 'background-color: ' + beatColor,
                color: beatColor
            });
            data[dateKey].totalVisits += day.Planned_Outlets__c || day.Beat__r?.Total_Outlets__c || 0;
        });
        return data;
    }

    /**
     * Parses "Week 1", "Week 2", etc. into the numeric value 1, 2, etc.
     */
    parseWeekNumber(weekStr) {
        if (!weekStr) return 1;
        const match = weekStr.match(/(\d+)/);
        return match ? parseInt(match[1], 10) : 1;
    }

    calculateSummaryStats(planDays) {
        const uniqueDates = new Set();
        const uniqueBeats = new Set();
        let totalVisits = 0;

        planDays.forEach(day => {
            const key = (day.Week_Number__c || '') + '_' + (day.Day_of_Week__c || '');
            uniqueDates.add(key);
            if (day.Beat__c) {
                uniqueBeats.add(day.Beat__c);
            }
            totalVisits += day.Planned_Outlets__c || day.Beat__r?.Total_Outlets__c || 0;
        });

        const workingDays = this.weekView ? 6 : this.getWorkingDaysInMonth();
        const coverage = workingDays > 0 ? Math.round((uniqueDates.size / workingDays) * 100) : 0;

        this.summaryStats = {
            totalPlannedVisits: totalVisits,
            coveragePercent: Math.min(coverage, 100),
            assignedBeats: uniqueBeats.size,
            totalOutlets: totalVisits,
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
        const planId = this.journeyPlan?.Id || this.recordId;
        if (!planId) {
            this.showToast('Warning', 'No journey plan to submit', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            await submitForApproval({ journeyPlanId: planId });
            this.pjpStatus = 'Submitted';
            this.showToast('Success', 'Journey Plan submitted for approval', 'success');
        } catch (error) {
            this.showToast('Error', 'Approval submission failed: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Helper methods ────────────────────────────────────────────────────────

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
