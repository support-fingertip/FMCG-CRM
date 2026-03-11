import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getEmployeeDetails from '@salesforce/apex/EmployeeThreeSixtyController.getEmployeeDetails';
import getEmployeeKPIs from '@salesforce/apex/EmployeeThreeSixtyController.getEmployeeKPIs';
import getAttendanceHistory from '@salesforce/apex/EmployeeThreeSixtyController.getAttendanceHistory';
import getLeaveHistory from '@salesforce/apex/EmployeeThreeSixtyController.getLeaveHistory';
import getAssignedBeats from '@salesforce/apex/EmployeeThreeSixtyController.getAssignedBeats';
import getPerformanceTrend from '@salesforce/apex/EmployeeThreeSixtyController.getPerformanceTrend';
import getRecentActivity from '@salesforce/apex/EmployeeThreeSixtyController.getRecentActivity';
import getDirectReports from '@salesforce/apex/EmployeeThreeSixtyController.getDirectReports';
import getMyEmployeeId from '@salesforce/apex/EmployeeThreeSixtyController.getMyEmployeeId';

const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];
const MONTH_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export default class EmployeeThreeSixty extends NavigationMixin(LightningElement) {
    @api employeeId;
    @api recordId;

    get effectiveEmployeeId() {
        return this.employeeId || this.recordId || this._resolvedEmployeeId;
    }

    // Resolved employee ID for current user (used when no employeeId/recordId provided)
    _resolvedEmployeeId;

    // ── Core Data ────────────────────────────────────────────────
    @track employee = {};
    @track kpis = {};
    @track performanceTrend = [];
    @track recentActivity = [];
    @track attendanceRecords = [];
    @track calendarWeeks = [];
    @track leaveHistory = [];
    @track beats = [];
    @track teamMembers = [];

    // ── UI State ─────────────────────────────────────────────────
    activeTab = 'overview';
    isLoading = true;
    isTabLoading = false;

    // Lazy loading tracker
    _tabsLoaded = {};

    // Attendance calendar state
    @track calendarYear;
    @track calendarMonth;

    // Leave filter
    @track leaveYear;

    // ── Lifecycle ────────────────────────────────────────────────

    connectedCallback() {
        const now = new Date();
        this.calendarYear = now.getFullYear();
        this.calendarMonth = now.getMonth();
        this.leaveYear = now.getFullYear();
        this.loadInitialData();
    }

    async loadInitialData() {
        this.isLoading = true;
        try {
            // If no employeeId or recordId provided (e.g. Tab context), resolve from current user
            if (!this.effectiveEmployeeId) {
                this._resolvedEmployeeId = await getMyEmployeeId();
            }
            await Promise.all([
                this.loadEmployeeDetails(),
                this.loadKPIs()
            ]);
            // Load overview tab data after details are loaded
            this._tabsLoaded.overview = true;
            await Promise.all([
                this.loadPerformanceTrend(),
                this.loadRecentActivity()
            ]);
        } catch (error) {
            this.showToast('Error', 'Failed to load employee data', 'error');
            console.error('Error loading employee 360:', error);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Data Loaders ─────────────────────────────────────────────

    async loadEmployeeDetails() {
        try {
            const result = await getEmployeeDetails({ employeeId: this.effectiveEmployeeId });
            if (result) {
                this.employee = result;
            }
        } catch (error) {
            console.error('Error loading employee details:', error);
            throw error;
        }
    }

    async loadKPIs() {
        try {
            const result = await getEmployeeKPIs({ employeeId: this.effectiveEmployeeId });
            if (result) {
                this.kpis = result;
            }
        } catch (error) {
            console.error('Error loading KPIs:', error);
        }
    }

    async loadPerformanceTrend() {
        try {
            const result = await getPerformanceTrend({ employeeId: this.effectiveEmployeeId, months: 6 });
            this.performanceTrend = result || [];
        } catch (error) {
            console.error('Error loading performance trend:', error);
            this.performanceTrend = [];
        }
    }

    async loadRecentActivity() {
        try {
            const result = await getRecentActivity({ employeeId: this.effectiveEmployeeId, limitCount: 10 });
            this.recentActivity = (result || []).map((item, idx) => ({
                ...item,
                key: item.Id || 'act-' + idx,
                dateFormatted: this.formatDate(item.Attendance_Date__c || item.Date__c),
                dayLabel: this.getDayLabel(item.Attendance_Date__c || item.Date__c),
                visits: item.Total_Visits__c || 0,
                orders: item.Total_Orders__c || 0,
                collectionFormatted: this.formatCurrencyShort(item.Total_Collection__c || 0),
                hoursWorked: item.Hours_Worked__c ? Number(item.Hours_Worked__c).toFixed(1) : '0.0',
                statusClass: this.getActivityStatusClass(item.Status__c),
                statusIcon: this.getActivityStatusIcon(item.Status__c),
                isPresent: item.Status__c === 'Present',
                isLast: false
            }));
            if (this.recentActivity.length > 0) {
                this.recentActivity[this.recentActivity.length - 1].isLast = true;
            }
        } catch (error) {
            console.error('Error loading recent activity:', error);
            this.recentActivity = [];
        }
    }

    async loadAttendanceData() {
        this.isTabLoading = true;
        try {
            const result = await getAttendanceHistory({
                employeeId: this.effectiveEmployeeId,
                year: this.calendarYear,
                month: this.calendarMonth + 1
            });
            this.attendanceRecords = result || [];
            this.buildCalendar();
        } catch (error) {
            console.error('Error loading attendance:', error);
            this.attendanceRecords = [];
            this.buildCalendar();
        } finally {
            this.isTabLoading = false;
        }
    }

    async loadLeaveData() {
        this.isTabLoading = true;
        try {
            const result = await getLeaveHistory({
                employeeId: this.effectiveEmployeeId,
                year: this.leaveYear
            });
            this.leaveHistory = (result || []).map(leave => ({
                ...leave,
                key: leave.Id,
                dateRange: this.formatDate(leave.Start_Date__c) + ' - ' + this.formatDate(leave.End_Date__c),
                typeBadgeClass: this.getLeaveTypeBadgeClass(leave.Leave_Type__c),
                statusBadgeClass: this.getLeaveStatusBadgeClass(leave.Status__c),
                days: leave.Number_of_Days__c || 1,
                reason: leave.Reason__c || '-'
            }));
        } catch (error) {
            console.error('Error loading leaves:', error);
            this.leaveHistory = [];
        } finally {
            this.isTabLoading = false;
        }
    }

    async loadBeatsData() {
        this.isTabLoading = true;
        try {
            const result = await getAssignedBeats({ employeeId: this.effectiveEmployeeId });
            this.beats = (result || []).map(beat => ({
                ...beat,
                key: beat.Id,
                beatName: beat.Name,
                beatCode: beat.Beat_Code__c || '',
                outletCount: beat.Total_Outlets__c || beat.Outlet_Count__c || 0,
                statusLabel: beat.Is_Active__c !== false ? 'Active' : 'Inactive',
                statusClass: beat.Is_Active__c !== false ? 'beat-status-active' : 'beat-status-inactive',
                territoryName: beat.Territory__r ? beat.Territory__r.Name : '',
                dayIndicators: this.buildDayIndicators(beat.Visit_Days__c || beat.Days_of_Week__c || '')
            }));
        } catch (error) {
            console.error('Error loading beats:', error);
            this.beats = [];
        } finally {
            this.isTabLoading = false;
        }
    }

    async loadTeamData() {
        this.isTabLoading = true;
        try {
            const result = await getDirectReports({ employeeId: this.effectiveEmployeeId });
            this.teamMembers = (result || []).map(member => ({
                ...member,
                key: member.employeeId || member.Id,
                empId: member.employeeId || member.Id,
                fullName: member.fullName || ((member.First_Name__c || '') + ' ' + (member.Last_Name__c || '')),
                initials: this.getInitials(member.firstName || member.First_Name__c, member.lastName || member.Last_Name__c),
                designation: member.designation || member.Designation__c || '',
                department: member.department || member.Department__c || '',
                attendancePercent: member.attendancePercent != null ? Number(member.attendancePercent).toFixed(0) : '0',
                mtdOrders: member.mtdOrders || member.mtdOrderCount || 0,
                mtdCollectionFormatted: this.formatCurrencyShort(member.mtdCollection || 0),
                avatarGradient: this.getAvatarGradient(member.firstName || member.First_Name__c)
            }));
        } catch (error) {
            console.error('Error loading team:', error);
            this.teamMembers = [];
        } finally {
            this.isTabLoading = false;
        }
    }

    // ── Tab Handler ──────────────────────────────────────────────

    handleTabClick(event) {
        const tab = event.currentTarget.dataset.tab;
        if (tab === this.activeTab) return;
        this.activeTab = tab;

        if (!this._tabsLoaded[tab]) {
            this._tabsLoaded[tab] = true;
            this.loadTabContent(tab);
        }
    }

    async loadTabContent(tab) {
        switch (tab) {
            case 'overview':
                await Promise.all([this.loadPerformanceTrend(), this.loadRecentActivity()]);
                break;
            case 'attendance':
                await this.loadAttendanceData();
                break;
            case 'leaves':
                await this.loadLeaveData();
                break;
            case 'beats':
                await this.loadBeatsData();
                break;
            case 'team':
                await this.loadTeamData();
                break;
            default:
                break;
        }
    }

    // ── Calendar Builder ─────────────────────────────────────────

    buildCalendar() {
        const year = this.calendarYear;
        const month = this.calendarMonth;
        const firstDay = new Date(year, month, 1);
        const lastDay = new Date(year, month + 1, 0);
        const daysInMonth = lastDay.getDate();
        const startDayOfWeek = firstDay.getDay();

        // Build attendance lookup
        const attendanceMap = {};
        this.attendanceRecords.forEach(rec => {
            const dateStr = rec.Attendance_Date__c || rec.Date__c;
            if (dateStr) {
                const day = new Date(dateStr).getDate();
                attendanceMap[day] = rec;
            }
        });

        const weeks = [];
        let currentWeek = [];

        // Fill leading blanks
        for (let i = 0; i < startDayOfWeek; i++) {
            currentWeek.push({ key: 'blank-' + i, day: '', isEmpty: true, cssClass: 'cal-day cal-day-empty' });
        }

        for (let day = 1; day <= daysInMonth; day++) {
            const date = new Date(year, month, day);
            const dayOfWeek = date.getDay();
            const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
            const rec = attendanceMap[day];

            let status = 'none';
            let hours = '';
            let cssClass = 'cal-day';

            if (rec) {
                const recStatus = (rec.Status__c || '').toLowerCase();
                if (recStatus === 'present') {
                    status = 'present';
                    cssClass += ' cal-day-present';
                    hours = rec.Hours_Worked__c ? Number(rec.Hours_Worked__c).toFixed(1) + 'h' : '';
                } else if (recStatus === 'absent') {
                    status = 'absent';
                    cssClass += ' cal-day-absent';
                } else if (recStatus === 'leave' || recStatus === 'on leave') {
                    status = 'leave';
                    cssClass += ' cal-day-leave';
                } else if (recStatus === 'holiday') {
                    status = 'holiday';
                    cssClass += ' cal-day-holiday';
                } else if (recStatus === 'half day' || recStatus === 'half-day') {
                    status = 'present';
                    cssClass += ' cal-day-present';
                    hours = rec.Hours_Worked__c ? Number(rec.Hours_Worked__c).toFixed(1) + 'h' : 'HD';
                } else {
                    cssClass += isWeekend ? ' cal-day-weekend' : '';
                }
            } else {
                if (isWeekend) {
                    cssClass += ' cal-day-weekend';
                    status = 'weekend';
                }
            }

            // Check if this day is in the future
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            if (date > today) {
                cssClass += ' cal-day-future';
                status = 'future';
            }

            currentWeek.push({
                key: 'day-' + day,
                day: day,
                isEmpty: false,
                status: status,
                hours: hours,
                cssClass: cssClass,
                isPresent: status === 'present',
                isAbsent: status === 'absent',
                isLeave: status === 'leave',
                isHoliday: status === 'holiday',
                isWeekend: status === 'weekend',
                showHours: !!hours
            });

            if (currentWeek.length === 7) {
                weeks.push({ key: 'week-' + weeks.length, days: currentWeek });
                currentWeek = [];
            }
        }

        // Fill trailing blanks
        if (currentWeek.length > 0) {
            while (currentWeek.length < 7) {
                currentWeek.push({
                    key: 'blank-end-' + currentWeek.length,
                    day: '',
                    isEmpty: true,
                    cssClass: 'cal-day cal-day-empty'
                });
            }
            weeks.push({ key: 'week-' + weeks.length, days: currentWeek });
        }

        this.calendarWeeks = weeks;
    }

    handlePrevMonth() {
        if (this.calendarMonth === 0) {
            this.calendarMonth = 11;
            this.calendarYear--;
        } else {
            this.calendarMonth--;
        }
        this.loadAttendanceData();
    }

    handleNextMonth() {
        if (this.calendarMonth === 11) {
            this.calendarMonth = 0;
            this.calendarYear++;
        } else {
            this.calendarMonth++;
        }
        this.loadAttendanceData();
    }

    handlePrevLeaveYear() {
        this.leaveYear--;
        this.loadLeaveData();
    }

    handleNextLeaveYear() {
        this.leaveYear++;
        this.loadLeaveData();
    }

    // ── Beat Day Indicators ──────────────────────────────────────

    buildDayIndicators(daysString) {
        const activeDays = (daysString || '').toLowerCase().split(/[,;|]+/).map(d => d.trim());
        const dayMap = {
            'sun': 0, 'sunday': 0,
            'mon': 1, 'monday': 1,
            'tue': 2, 'tuesday': 2,
            'wed': 3, 'wednesday': 3,
            'thu': 4, 'thursday': 4,
            'fri': 5, 'friday': 5,
            'sat': 6, 'saturday': 6
        };
        const activeIndices = new Set();
        activeDays.forEach(d => {
            if (dayMap[d] !== undefined) activeIndices.add(dayMap[d]);
        });

        return DAY_NAMES.map((name, idx) => ({
            key: name,
            label: name.charAt(0),
            isActive: activeIndices.has(idx),
            cssClass: activeIndices.has(idx) ? 'day-dot day-dot-active' : 'day-dot'
        }));
    }

    // ── Performance Chart Computations ───────────────────────────

    get chartData() {
        if (!this.performanceTrend || this.performanceTrend.length === 0) return null;

        const data = this.performanceTrend;
        const values = data.map(d => d.orderValue || 0);
        const maxVal = Math.max(...values, 1);
        const chartHeight = 200;
        const chartWidth = 500;
        const barWidth = 50;
        const barGap = (chartWidth - (data.length * barWidth)) / (data.length + 1);

        const bars = data.map((item, idx) => {
            const val = item.orderValue || 0;
            const barHeight = Math.max((val / maxVal) * (chartHeight - 30), 2);
            const x = barGap + idx * (barWidth + barGap);
            const y = chartHeight - barHeight - 20;
            return {
                key: 'bar-' + idx,
                x: x,
                y: y,
                width: barWidth,
                height: barHeight,
                value: val,
                valueFormatted: this.formatCurrencyShort(val),
                month: item.month || MONTH_SHORT[idx] || '',
                monthX: x + barWidth / 2,
                monthY: chartHeight - 4,
                labelX: x + barWidth / 2,
                labelY: y - 6,
                rx: 4
            };
        });

        // Y-axis labels
        const yLabels = [];
        const steps = 4;
        for (let i = 0; i <= steps; i++) {
            const val = (maxVal / steps) * i;
            const yPos = chartHeight - 20 - ((chartHeight - 30) / steps) * i;
            yLabels.push({
                key: 'ylabel-' + i,
                label: this.formatCurrencyShort(val),
                y: yPos,
                lineY: yPos
            });
        }

        return { bars, yLabels, chartHeight, chartWidth: chartWidth + 20 };
    }

    get hasChartData() {
        return this.chartData != null && this.chartData.bars.length > 0;
    }

    // ── Computed Properties: Profile Header ──────────────────────

    get employeeName() {
        return ((this.employee.First_Name__c || '') + ' ' + (this.employee.Last_Name__c || '')).trim() || 'Employee';
    }

    get employeeInitials() {
        const first = this.employee.First_Name__c ? this.employee.First_Name__c.charAt(0) : '';
        const last = this.employee.Last_Name__c ? this.employee.Last_Name__c.charAt(0) : '';
        return (first + last).toUpperCase() || 'E';
    }

    get hasProfilePhoto() {
        return !!this.employee.Profile_Photo_URL__c;
    }

    get profilePhotoUrl() {
        return this.employee.Profile_Photo_URL__c || '';
    }

    get employeeDesignation() {
        return this.employee.Designation__c || '';
    }

    get employeeDepartment() {
        return this.employee.Department__c || '';
    }

    get hasDepartment() {
        return !!this.employee.Department__c;
    }

    get employeeCode() {
        return this.employee.Employee_Code__c || this.employee.Name || '';
    }

    get isActive() {
        return this.employee.Is_Active__c !== false;
    }

    get statusLabel() {
        return this.isActive ? 'Active' : 'Inactive';
    }

    get statusBadgeClass() {
        return this.isActive ? 'status-pill status-active' : 'status-pill status-inactive';
    }

    get employeeEmail() {
        return this.employee.Email__c || '';
    }

    get hasEmail() {
        return !!this.employee.Email__c;
    }

    get employeePhone() {
        return this.employee.Phone__c || '';
    }

    get hasPhone() {
        return !!this.employee.Phone__c;
    }

    get reportingManagerName() {
        if (this.employee.Reporting_Manager__r) {
            const mgr = this.employee.Reporting_Manager__r;
            return ((mgr.First_Name__c || '') + ' ' + (mgr.Last_Name__c || '')).trim();
        }
        return '';
    }

    get hasReportingManager() {
        return !!this.reportingManagerName;
    }

    get managerInitials() {
        if (this.employee.Reporting_Manager__r) {
            const mgr = this.employee.Reporting_Manager__r;
            const f = mgr.First_Name__c ? mgr.First_Name__c.charAt(0) : '';
            const l = mgr.Last_Name__c ? mgr.Last_Name__c.charAt(0) : '';
            return (f + l).toUpperCase();
        }
        return '';
    }

    get tenure() {
        if (!this.employee.Date_of_Joining__c) return '';
        const joinDate = new Date(this.employee.Date_of_Joining__c);
        const now = new Date();
        let years = now.getFullYear() - joinDate.getFullYear();
        let months = now.getMonth() - joinDate.getMonth();
        if (months < 0) {
            years--;
            months += 12;
        }
        const parts = [];
        if (years > 0) parts.push(years + (years === 1 ? ' year' : ' years'));
        if (months > 0) parts.push(months + (months === 1 ? ' month' : ' months'));
        return parts.join(' ') || 'Just joined';
    }

    get hasTenure() {
        return !!this.employee.Date_of_Joining__c;
    }

    get joiningDate() {
        return this.formatDate(this.employee.Date_of_Joining__c);
    }

    // ── Computed Properties: KPI Tiles ───────────────────────────

    get attendancePercent() {
        return this.kpis.attendancePercentage != null ? Number(this.kpis.attendancePercentage).toFixed(0) : '0';
    }

    get attendanceColorClass() {
        const pct = Number(this.kpis.attendancePercentage || 0);
        if (pct >= 90) return 'kpi-color-success';
        if (pct >= 75) return 'kpi-color-warning';
        return 'kpi-color-error';
    }

    get attendanceRingDasharray() {
        const pct = Math.min(Number(this.kpis.attendancePercentage || 0), 100);
        const circumference = 2 * Math.PI * 16;
        const filled = (pct / 100) * circumference;
        return filled + ' ' + circumference;
    }

    get attendanceRingColor() {
        const pct = Number(this.kpis.attendancePercentage || 0);
        if (pct >= 90) return '#2e844a';
        if (pct >= 75) return '#dd7a01';
        return '#ea001e';
    }

    get mtdAttendance() {
        return this.kpis.mtdAttendanceCount || 0;
    }

    get totalWorkingDays() {
        return this.kpis.mtdTotalWorkingDays || 0;
    }

    get mtdOrderCount() {
        return this.kpis.mtdOrderCount || 0;
    }

    get mtdOrderValue() {
        return this.formatCurrencyShort(this.kpis.mtdOrderValue || 0);
    }

    get mtdCollection() {
        return this.formatCurrencyShort(this.kpis.mtdCollectionTotal || 0);
    }

    get mtdVisits() {
        return this.kpis.mtdVisitCount || 0;
    }

    get mtdProductiveCalls() {
        return this.kpis.mtdProductiveCalls || 0;
    }

    get productivePercent() {
        const visits = this.kpis.mtdVisitCount || 0;
        const productive = this.kpis.mtdProductiveCalls || 0;
        if (visits === 0) return '0';
        return Math.round((productive / visits) * 100);
    }

    get totalBeats() {
        return this.kpis.totalBeatsAssigned || 0;
    }

    get totalOutlets() {
        return this.kpis.totalOutletsCovered || 0;
    }

    get totalLeaveBalance() {
        return this.kpis.totalLeaveBalance || 0;
    }

    get clBalance() {
        return this.kpis.clBalance || this.employee.CL_Balance__c || 0;
    }

    get slBalance() {
        return this.kpis.slBalance || this.employee.SL_Balance__c || 0;
    }

    get elBalance() {
        return this.kpis.elBalance || this.employee.EL_Balance__c || 0;
    }

    get coBalance() {
        return this.kpis.coBalance || this.employee.CO_Balance__c || 0;
    }

    get avgHoursWorked() {
        const val = this.kpis.avgHoursWorked || 0;
        return Number(val).toFixed(1);
    }

    // Leave ring computations
    get clRingDasharray() { return this.computeLeaveRing(this.clBalance, 12); }
    get slRingDasharray() { return this.computeLeaveRing(this.slBalance, 12); }
    get elRingDasharray() { return this.computeLeaveRing(this.elBalance, 30); }
    get coRingDasharray() { return this.computeLeaveRing(this.coBalance, 5); }

    computeLeaveRing(balance, total) {
        const pct = Math.min((balance / total) * 100, 100);
        const circumference = 2 * Math.PI * 28;
        const filled = (pct / 100) * circumference;
        return filled + ' ' + circumference;
    }

    // ── Computed Properties: Attendance Summary ──────────────────

    get calendarMonthLabel() {
        return MONTH_NAMES[this.calendarMonth] + ' ' + this.calendarYear;
    }

    get attendanceSummaryPresent() {
        return this.attendanceRecords.filter(r => (r.Status__c || '').toLowerCase() === 'present' || (r.Status__c || '').toLowerCase() === 'half day' || (r.Status__c || '').toLowerCase() === 'half-day').length;
    }

    get attendanceSummaryAbsent() {
        return this.attendanceRecords.filter(r => (r.Status__c || '').toLowerCase() === 'absent').length;
    }

    get attendanceSummaryLeave() {
        return this.attendanceRecords.filter(r => (r.Status__c || '').toLowerCase() === 'leave' || (r.Status__c || '').toLowerCase() === 'on leave').length;
    }

    get attendanceSummaryHoliday() {
        return this.attendanceRecords.filter(r => (r.Status__c || '').toLowerCase() === 'holiday').length;
    }

    get calendarAttendancePercent() {
        const total = this.attendanceSummaryPresent + this.attendanceSummaryAbsent;
        if (total === 0) return 0;
        return Math.round((this.attendanceSummaryPresent / total) * 100);
    }

    get calendarAttendanceBarStyle() {
        return 'width: ' + this.calendarAttendancePercent + '%';
    }

    get calendarAvgHours() {
        const presentDays = this.attendanceRecords.filter(r =>
            (r.Status__c || '').toLowerCase() === 'present' && r.Hours_Worked__c
        );
        if (presentDays.length === 0) return '0.0';
        const total = presentDays.reduce((sum, r) => sum + (Number(r.Hours_Worked__c) || 0), 0);
        return (total / presentDays.length).toFixed(1);
    }

    // ── Computed Properties: Tab State ───────────────────────────

    get isOverviewTab() { return this.activeTab === 'overview'; }
    get isAttendanceTab() { return this.activeTab === 'attendance'; }
    get isLeavesTab() { return this.activeTab === 'leaves'; }
    get isBeatsTab() { return this.activeTab === 'beats'; }
    get isTeamTab() { return this.activeTab === 'team'; }

    get overviewTabClass() { return this.activeTab === 'overview' ? 'nav-tab nav-tab-active' : 'nav-tab'; }
    get attendanceTabClass() { return this.activeTab === 'attendance' ? 'nav-tab nav-tab-active' : 'nav-tab'; }
    get leavesTabClass() { return this.activeTab === 'leaves' ? 'nav-tab nav-tab-active' : 'nav-tab'; }
    get beatsTabClass() { return this.activeTab === 'beats' ? 'nav-tab nav-tab-active' : 'nav-tab'; }
    get teamTabClass() { return this.activeTab === 'team' ? 'nav-tab nav-tab-active' : 'nav-tab'; }

    get showTeamTab() {
        // Show team tab if employee has any direct reports or if team data was loaded
        return this.teamMembers.length > 0 || !this._tabsLoaded.team;
    }

    get hasRecentActivity() { return this.recentActivity && this.recentActivity.length > 0; }
    get hasLeaveHistory() { return this.leaveHistory && this.leaveHistory.length > 0; }
    get hasBeats() { return this.beats && this.beats.length > 0; }
    get hasTeamMembers() { return this.teamMembers && this.teamMembers.length > 0; }

    // ── Beats / Territory ────────────────────────────────────────

    get territoryZone() { return this.employee.Zone__c || '-'; }
    get territoryRegion() { return this.employee.Region__c || '-'; }
    get territoryName() {
        return this.employee.Territory__r ? this.employee.Territory__r.Name : '-';
    }
    get hasTerritory() {
        return !!(this.employee.Zone__c || this.employee.Region__c || (this.employee.Territory__r && this.employee.Territory__r.Name));
    }

    get totalBeatOutlets() {
        return this.beats.reduce((sum, b) => sum + (b.outletCount || 0), 0);
    }

    // ── Team Summary ─────────────────────────────────────────────

    get teamCount() { return this.teamMembers.length; }

    get teamAvgAttendance() {
        if (this.teamMembers.length === 0) return '0';
        const sum = this.teamMembers.reduce((s, m) => s + Number(m.attendancePercent || 0), 0);
        return Math.round(sum / this.teamMembers.length);
    }

    get teamTotalOrderValue() {
        const sum = this.teamMembers.reduce((s, m) => s + (m.mtdCollection || 0), 0);
        return this.formatCurrencyShort(sum);
    }

    // ── Navigation ───────────────────────────────────────────────

    handleTeamMemberClick(event) {
        const memberId = event.currentTarget.dataset.id;
        if (memberId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: memberId,
                    objectApiName: 'Employee__c',
                    actionName: 'view'
                }
            });
        }
    }

    handleEditEmployee() {
        if (this.employee.Id) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.employee.Id,
                    objectApiName: 'Employee__c',
                    actionName: 'edit'
                }
            });
        }
    }

    handleSendEmail() {
        if (this.employeeEmail) {
            window.open('mailto:' + this.employeeEmail, '_blank');
        }
    }

    handleViewAttendance() {
        this.activeTab = 'attendance';
        if (!this._tabsLoaded.attendance) {
            this._tabsLoaded.attendance = true;
            this.loadAttendanceData();
        }
    }

    handleRefresh() {
        this._tabsLoaded = {};
        this.loadInitialData();
    }

    // ── Formatting Utilities ─────────────────────────────────────

    formatCurrencyShort(value) {
        if (!value || value === 0) return '0';
        const absVal = Math.abs(value);
        const sign = value < 0 ? '-' : '';
        if (absVal >= 10000000) return sign + (absVal / 10000000).toFixed(1) + ' Cr';
        if (absVal >= 100000) return sign + (absVal / 100000).toFixed(1) + ' L';
        if (absVal >= 1000) return sign + (absVal / 1000).toFixed(1) + ' K';
        return sign + new Intl.NumberFormat('en-IN').format(Math.round(absVal));
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: 'INR',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(value || 0);
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        return new Date(dateStr).toLocaleDateString('en-IN', {
            day: '2-digit', month: 'short', year: 'numeric'
        });
    }

    getDayLabel(dateStr) {
        if (!dateStr) return '';
        const date = new Date(dateStr);
        return DAY_NAMES[date.getDay()];
    }

    getInitials(firstName, lastName) {
        const first = firstName ? firstName.charAt(0) : '';
        const last = lastName ? lastName.charAt(0) : '';
        return (first + last).toUpperCase() || '?';
    }

    getAvatarGradient(name) {
        if (!name) return '1';
        const code = name.charCodeAt(0) % 5;
        return String(code + 1);
    }

    getActivityStatusClass(status) {
        const s = (status || '').toLowerCase();
        if (s === 'present') return 'activity-dot-present';
        if (s === 'absent') return 'activity-dot-absent';
        if (s === 'leave' || s === 'on leave') return 'activity-dot-leave';
        return 'activity-dot-default';
    }

    getActivityStatusIcon(status) {
        const s = (status || '').toLowerCase();
        if (s === 'present') return 'utility:check';
        if (s === 'absent') return 'utility:close';
        if (s === 'leave' || s === 'on leave') return 'utility:event';
        return 'utility:record';
    }

    getLeaveTypeBadgeClass(leaveType) {
        const map = {
            'Casual Leave': 'leave-type-badge leave-type-cl',
            'CL': 'leave-type-badge leave-type-cl',
            'Sick Leave': 'leave-type-badge leave-type-sl',
            'SL': 'leave-type-badge leave-type-sl',
            'Earned Leave': 'leave-type-badge leave-type-el',
            'EL': 'leave-type-badge leave-type-el',
            'Comp Off': 'leave-type-badge leave-type-co',
            'CO': 'leave-type-badge leave-type-co'
        };
        return map[leaveType] || 'leave-type-badge leave-type-cl';
    }

    getLeaveStatusBadgeClass(status) {
        const map = {
            'Approved': 'leave-status-badge leave-status-approved',
            'Pending': 'leave-status-badge leave-status-pending',
            'Rejected': 'leave-status-badge leave-status-rejected',
            'Cancelled': 'leave-status-badge leave-status-rejected'
        };
        return map[status] || 'leave-status-badge leave-status-pending';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
