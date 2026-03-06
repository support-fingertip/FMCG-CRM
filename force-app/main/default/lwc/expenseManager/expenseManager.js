import { LightningElement, track } from 'lwc';
import getOrCreateReport from '@salesforce/apex/ExpenseController.getOrCreateReport';
import getEligibleDates from '@salesforce/apex/ExpenseController.getEligibleDates';
import getEligibilityRules from '@salesforce/apex/ExpenseController.getEligibilityRules';
import getExpenseItemsForDate from '@salesforce/apex/ExpenseController.getExpenseItemsForDate';
import saveExpenseItems from '@salesforce/apex/ExpenseController.saveExpenseItems';
import deleteExpenseItems from '@salesforce/apex/ExpenseController.deleteExpenseItems';
import submitReport from '@salesforce/apex/ExpenseController.submitReport';
import approveReport from '@salesforce/apex/ExpenseController.approveReport';
import rejectReport from '@salesforce/apex/ExpenseController.rejectReport';
import getReportSummary from '@salesforce/apex/ExpenseController.getReportSummary';
import getMonthlyOverview from '@salesforce/apex/ExpenseController.getMonthlyOverview';
import getExpenseConfig from '@salesforce/apex/ExpenseController.getExpenseConfig';
import getTeamExpenseReports from '@salesforce/apex/ExpenseController.getTeamExpenseReports';
import markAsPaid from '@salesforce/apex/ExpenseController.markAsPaid';
import getExpenseItemFiles from '@salesforce/apex/ExpenseController.getExpenseItemFiles';
import deleteExpenseItemFile from '@salesforce/apex/ExpenseController.deleteExpenseItemFile';

const MONTHS = [
    { label: 'January', value: 'January' },
    { label: 'February', value: 'February' },
    { label: 'March', value: 'March' },
    { label: 'April', value: 'April' },
    { label: 'May', value: 'May' },
    { label: 'June', value: 'June' },
    { label: 'July', value: 'July' },
    { label: 'August', value: 'August' },
    { label: 'September', value: 'September' },
    { label: 'October', value: 'October' },
    { label: 'November', value: 'November' },
    { label: 'December', value: 'December' }
];

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export default class ExpenseManager extends LightningElement {
    // ── State ─────────────────────────────────────────────────────
    @track currentScreen = 'LOADING';
    @track selectedMonth;
    @track selectedYear;
    @track expense = {};
    @track eligibleDates = [];
    @track eligibilityRules = [];
    @track calendarDays = [];
    @track dayItems = [];
    @track summary = {};
    @track monthlyOverview = [];
    @track teamReports = [];
    @track config = {};

    // Day entry modal
    @track showDayModal = false;
    @track selectedDate = null;
    @track selectedDateInfo = {};
    @track editItems = [];

    // Approval modal
    @track showApprovalModal = false;
    @track approvalRemarks = '';
    @track approvalAction = '';
    @track approvalExpenseId = null;
    @track approvalLevel = '';

    // Summary modal
    @track showSummaryModal = false;

    // Active tab
    @track activeTab = 'expense';

    // Loading/error
    @track isLoading = false;
    @track errorMessage = '';
    @track successMessage = '';

    // Options
    monthOptions = MONTHS;

    get yearOptions() {
        const now = new Date();
        const y = now.getFullYear();
        return [
            { label: String(y - 1), value: y - 1 },
            { label: String(y), value: y },
            { label: String(y + 1), value: y + 1 }
        ];
    }

    // ── Lifecycle ────────────────────────────────────────────────
    connectedCallback() {
        const now = new Date();
        this.selectedMonth = MONTHS[now.getMonth()].value;
        this.selectedYear = now.getFullYear();
        this.loadConfig();
    }

    async loadConfig() {
        try {
            this.isLoading = true;
            this.config = await getExpenseConfig();
            await this.loadReport();
            this.currentScreen = 'MAIN';
        } catch (e) {
            this.showError(e);
            this.currentScreen = 'MAIN';
        } finally {
            this.isLoading = false;
        }
    }

    async loadReport() {
        try {
            this.isLoading = true;
            this.clearMessages();
            this.expense = await getOrCreateReport({ month: this.selectedMonth, year: this.selectedYear });
            await Promise.all([
                this.loadEligibleDates(),
                this.loadEligibilityRules()
            ]);
            this.buildCalendar();
        } catch (e) {
            this.showError(e);
        } finally {
            this.isLoading = false;
        }
    }

    async loadEligibleDates() {
        this.eligibleDates = await getEligibleDates({ month: this.selectedMonth, year: this.selectedYear });
    }

    async loadEligibilityRules() {
        try {
            this.eligibilityRules = await getEligibilityRules();
        } catch (e) {
            this.eligibilityRules = [];
            this.showError(e);
        }
    }

    get hasNoEditItems() {
        return !this.editItems || this.editItems.length === 0;
    }

    // ── Calendar Builder ─────────────────────────────────────────
    buildCalendar() {
        const monthIndex = MONTHS.findIndex(m => m.value === this.selectedMonth);
        const year = this.selectedYear;
        const firstDay = new Date(year, monthIndex, 1);
        const lastDay = new Date(year, monthIndex + 1, 0);
        const startDayOfWeek = firstDay.getDay();
        const daysInMonth = lastDay.getDate();

        // Build date lookup from eligible dates
        const dateMap = {};
        this.eligibleDates.forEach(d => {
            const dateStr = typeof d.date === 'string' ? d.date : d.date;
            dateMap[dateStr] = d;
        });

        const days = [];

        // Leading empty cells
        for (let i = 0; i < startDayOfWeek; i++) {
            days.push({ key: `empty-${i}`, day: '', isEmpty: true, cssClass: 'cal-cell cal-empty' });
        }

        // Calendar days
        for (let d = 1; d <= daysInMonth; d++) {
            const dateObj = new Date(year, monthIndex, d);
            const dateStr = this.formatDate(year, monthIndex + 1, d);
            const info = dateMap[dateStr];
            const hasAttendance = !!info;
            const expenseCount = info ? (info.expenseCount || 0) : 0;
            const gpsDistance = info ? (info.gpsDistance || 0) : 0;
            const isToday = this.isToday(year, monthIndex, d);

            let cssClass = 'cal-cell';
            if (hasAttendance) {
                cssClass += expenseCount > 0 ? ' cal-has-expense' : ' cal-eligible';
            } else {
                cssClass += ' cal-disabled';
            }
            if (isToday) cssClass += ' cal-today';

            days.push({
                key: `day-${d}`,
                day: d,
                dateStr,
                isEmpty: false,
                hasAttendance,
                expenseCount,
                gpsDistance: gpsDistance.toFixed(1),
                isToday,
                cssClass,
                showBadge: expenseCount > 0
            });
        }

        this.calendarDays = days;
    }

    formatDate(y, m, d) {
        return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    }

    isToday(y, m, d) {
        const now = new Date();
        return y === now.getFullYear() && m === now.getMonth() && d === now.getDate();
    }

    get weekdayHeaders() {
        return WEEKDAYS.map(d => ({ key: d, label: d }));
    }

    // ── Event Handlers ───────────────────────────────────────────
    handleMonthChange(event) {
        this.selectedMonth = event.detail.value;
        this.loadReport();
    }

    handleYearChange(event) {
        this.selectedYear = parseInt(event.detail.value, 10);
        this.loadReport();
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
        if (this.activeTab === 'overview') {
            this.loadMonthlyOverview();
        } else if (this.activeTab === 'team') {
            this.loadTeamReports();
        } else if (this.activeTab === 'summary') {
            this.loadSummary();
        }
    }

    // ── Calendar Day Click ───────────────────────────────────────
    async handleDayClick(event) {
        const dateStr = event.currentTarget.dataset.date;
        const dayInfo = this.eligibleDates.find(d => d.date === dateStr);
        if (!dayInfo) return;

        this.selectedDate = dateStr;
        this.selectedDateInfo = dayInfo;
        this.showDayModal = true;

        try {
            this.isLoading = true;
            const existingItems = await getExpenseItemsForDate({
                expenseId: this.expense.Id,
                expenseDate: dateStr
            });

            // Build edit items from eligibility rules
            this.editItems = this.eligibilityRules.map(rule => {
                const existing = existingItems.find(i => i.Expense_Type__c === rule.Expense_Type__c);
                return {
                    key: rule.Expense_Type__c,
                    id: existing ? existing.Id : null,
                    expenseType: rule.Expense_Type__c,
                    category: rule.Expense_Category__c,
                    rateType: rule.Rate_Type__c,
                    rateAmount: rule.Rate_Amount__c || 0,
                    maxPerDay: rule.Max_Per_Day__c || 0,
                    minDistance: rule.Min_Distance_KM__c || 0,
                    receiptRequired: rule.Receipt_Required__c,
                    gpsDistance: existing ? existing.GPS_Distance_KM__c : (dayInfo.gpsDistance || 0),
                    manualDistance: existing ? existing.Manual_Distance_KM__c : null,
                    overrideReason: existing ? existing.Distance_Override_Reason__c : '',
                    eligibleAmount: existing ? existing.Eligible_Amount__c : 0,
                    claimedAmount: existing ? existing.Claimed_Amount__c : 0,
                    receiptUrl: existing ? existing.Receipt_URL__c : '',
                    notes: existing ? existing.Notes__c : '',
                    isEligible: existing ? existing.Is_Eligible__c : true,
                    rateLabel: this.getRateLabel(rule),
                    hasExisting: !!existing,
                    showDistance: rule.Rate_Type__c === 'Per KM' || (rule.Min_Distance_KM__c && rule.Min_Distance_KM__c > 0),
                    isActual: rule.Rate_Type__c === 'Actual',
                    files: [],
                    hasFiles: false
                };
            });

            await this.loadFilesForItems();
        } catch (e) {
            this.showError(e);
        } finally {
            this.isLoading = false;
        }
    }

    getRateLabel(rule) {
        if (rule.Rate_Type__c === 'Per Day') return `${rule.Rate_Amount__c}/day`;
        if (rule.Rate_Type__c === 'Per KM') return `${rule.Rate_Amount__c}/km`;
        if (rule.Rate_Type__c === 'Flat Monthly') return `${rule.Rate_Amount__c}/month`;
        if (rule.Rate_Type__c === 'Actual') return 'Actual';
        return '';
    }

    // ── Day Modal Handlers ───────────────────────────────────────
    handleItemFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const type = event.currentTarget.dataset.type;
        const value = event.detail.value;
        const idx = this.editItems.findIndex(i => i.expenseType === type);
        if (idx >= 0) {
            const items = [...this.editItems];
            const item = { ...items[idx] };

            if (field === 'manualDistance') {
                item.manualDistance = value ? parseFloat(value) : null;
                item.eligibleAmount = this.recalcEligible(item);
            } else if (field === 'claimedAmount') {
                item.claimedAmount = value ? parseFloat(value) : 0;
                if (item.isActual) {
                    item.eligibleAmount = this.recalcEligible(item);
                }
            } else if (field === 'overrideReason') {
                item.overrideReason = value;
            } else if (field === 'receiptUrl') {
                item.receiptUrl = value;
            } else if (field === 'notes') {
                item.notes = value;
            }
            items[idx] = item;
            this.editItems = items;
        }
    }

    recalcEligible(item) {
        const dist = item.manualDistance != null ? item.manualDistance : (item.gpsDistance || 0);
        let eligible = 0;

        if (item.minDistance > 0 && dist < item.minDistance) return 0;

        if (item.rateType === 'Per Day') {
            eligible = item.rateAmount;
        } else if (item.rateType === 'Per KM') {
            eligible = dist * item.rateAmount;
        } else if (item.rateType === 'Actual') {
            eligible = item.claimedAmount || 0;
        } else if (item.rateType === 'Flat Monthly') {
            const wd = this.expense.Working_Days__c || 22;
            eligible = wd > 0 ? item.rateAmount / wd : 0;
        }

        if (item.maxPerDay > 0 && eligible > item.maxPerDay) {
            eligible = item.maxPerDay;
        }
        return Math.round(eligible * 100) / 100;
    }

    async handleSaveDayItems() {
        try {
            this.isLoading = true;
            const itemsToSave = this.editItems
                .filter(i => (i.claimedAmount && i.claimedAmount > 0) || i.hasExisting)
                .map(i => {
                    const item = {
                        Expense_Date__c: this.selectedDate,
                        Expense_Type__c: i.expenseType,
                        Expense_Category__c: i.category,
                        GPS_Distance_KM__c: i.gpsDistance,
                        Manual_Distance_KM__c: i.manualDistance,
                        Distance_Override_Reason__c: i.overrideReason,
                        Eligible_Amount__c: i.eligibleAmount,
                        Claimed_Amount__c: i.claimedAmount || 0,
                        Receipt_URL__c: i.receiptUrl,
                        Notes__c: i.notes,
                        Rate_Type__c: i.rateType,
                        Rate_Amount__c: i.rateAmount,
                        Receipt_Required__c: i.receiptRequired,
                        Is_Eligible__c: i.isEligible,
                        Day_Attendance__c: this.selectedDateInfo.attendanceId || null
                    };
                    if (i.id) item.Id = i.id;
                    return item;
                });

            if (itemsToSave.length > 0) {
                await saveExpenseItems({
                    expenseId: this.expense.Id,
                    itemsJson: JSON.stringify(itemsToSave)
                });
                this.showSuccess('Expense items saved successfully.');
            }

            this.closeDayModal();
            await this.loadReport();
        } catch (e) {
            this.showError(e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleDeleteDayItems() {
        const idsToDelete = this.editItems
            .filter(i => i.id)
            .map(i => i.id);

        if (idsToDelete.length === 0) {
            this.closeDayModal();
            return;
        }

        try {
            this.isLoading = true;
            await deleteExpenseItems({ itemIds: idsToDelete });
            this.showSuccess('Expense items deleted.');
            this.closeDayModal();
            await this.loadReport();
        } catch (e) {
            this.showError(e);
        } finally {
            this.isLoading = false;
        }
    }

    closeDayModal() {
        this.showDayModal = false;
        this.selectedDate = null;
        this.editItems = [];
    }

    // ── File Upload Handlers ──────────────────────────────────────
    async loadFilesForItems() {
        const itemIds = this.editItems.filter(i => i.id).map(i => i.id);
        if (itemIds.length === 0) return;

        try {
            const files = await getExpenseItemFiles({ itemIds });
            const filesByItem = {};
            files.forEach(f => {
                const itemId = f.expenseItemId;
                if (!filesByItem[itemId]) filesByItem[itemId] = [];
                filesByItem[itemId].push(f);
            });

            this.editItems = this.editItems.map(item => ({
                ...item,
                files: item.id ? (filesByItem[item.id] || []) : [],
                hasFiles: item.id ? (filesByItem[item.id] || []).length > 0 : false
            }));
        } catch (e) {
            this.showError(e);
        }
    }

    async handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles && uploadedFiles.length > 0) {
            this.showSuccess(uploadedFiles.length + ' receipt(s) uploaded.');
            await this.loadFilesForItems();
        }
    }

    async handleDeleteFile(event) {
        const docId = event.currentTarget.dataset.docid;
        try {
            this.isLoading = true;
            await deleteExpenseItemFile({ contentDocumentId: docId });
            this.showSuccess('Receipt deleted.');
            await this.loadFilesForItems();
        } catch (e) {
            this.showError(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Submit / Approve / Reject ────────────────────────────────
    async handleSubmit() {
        try {
            this.isLoading = true;
            this.expense = await submitReport({ expenseId: this.expense.Id });
            this.showSuccess('Expense submitted for approval.');
            await this.loadReport();
        } catch (e) {
            this.showError(e);
        } finally {
            this.isLoading = false;
        }
    }

    handleOpenApproval(event) {
        this.approvalAction = event.currentTarget.dataset.action;
        this.approvalLevel = event.currentTarget.dataset.level || 'manager';
        this.approvalExpenseId = event.currentTarget.dataset.id || this.expense.Id;
        this.approvalRemarks = '';
        this.showApprovalModal = true;
    }

    handleRemarksChange(event) {
        this.approvalRemarks = event.detail.value;
    }

    async handleApprovalConfirm() {
        try {
            this.isLoading = true;
            if (this.approvalAction === 'approve') {
                await approveReport({
                    expenseId: this.approvalExpenseId,
                    remarks: this.approvalRemarks,
                    level: this.approvalLevel
                });
                this.showSuccess('Expense approved.');
            } else if (this.approvalAction === 'reject') {
                if (!this.approvalRemarks) {
                    this.showError({ body: { message: 'Rejection reason is required.' } });
                    this.isLoading = false;
                    return;
                }
                await rejectReport({
                    expenseId: this.approvalExpenseId,
                    reason: this.approvalRemarks,
                    level: this.approvalLevel
                });
                this.showSuccess('Expense rejected.');
            } else if (this.approvalAction === 'paid') {
                await markAsPaid({ expenseId: this.approvalExpenseId });
                this.showSuccess('Expense marked as paid.');
            }
            this.showApprovalModal = false;
            await this.loadReport();
            if (this.activeTab === 'team') {
                await this.loadTeamReports();
            }
        } catch (e) {
            this.showError(e);
        } finally {
            this.isLoading = false;
        }
    }

    closeApprovalModal() {
        this.showApprovalModal = false;
    }

    // ── Summary ──────────────────────────────────────────────────
    async loadSummary() {
        if (!this.expense.Id) return;
        try {
            this.isLoading = true;
            this.summary = await getReportSummary({ expenseId: this.expense.Id });
        } catch (e) {
            this.showError(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Monthly Overview ─────────────────────────────────────────
    async loadMonthlyOverview() {
        try {
            this.isLoading = true;
            this.monthlyOverview = await getMonthlyOverview({ year: this.selectedYear });
        } catch (e) {
            this.showError(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Team Reports ─────────────────────────────────────────────
    async loadTeamReports() {
        try {
            this.isLoading = true;
            this.teamReports = await getTeamExpenseReports({
                month: this.selectedMonth,
                year: this.selectedYear
            });
        } catch (e) {
            this.showError(e);
            this.teamReports = [];
        } finally {
            this.isLoading = false;
        }
    }

    // ── Computed ──────────────────────────────────────────────────
    get isMainScreen() { return this.currentScreen === 'MAIN'; }
    get isLoadingScreen() { return this.currentScreen === 'LOADING'; }
    get isDraft() { return this.expense.Status__c === 'Draft'; }
    get isSubmitted() { return this.expense.Status__c === 'Submitted'; }
    get isRejected() { return this.expense.Status__c === 'Rejected'; }
    get canSubmit() { return this.isDraft || this.isRejected; }
    get canEdit() { return this.isDraft || this.isRejected; }
    get cannotEdit() { return !this.canEdit; }
    get isExpenseTab() { return this.activeTab === 'expense'; }
    get isSummaryTab() { return this.activeTab === 'summary'; }
    get isOverviewTab() { return this.activeTab === 'overview'; }
    get isTeamTab() { return this.activeTab === 'team'; }

    get expenseTabClass() { return 'tab-btn' + (this.isExpenseTab ? ' tab-active' : ''); }
    get summaryTabClass() { return 'tab-btn' + (this.isSummaryTab ? ' tab-active' : ''); }
    get overviewTabClass() { return 'tab-btn' + (this.isOverviewTab ? ' tab-active' : ''); }
    get teamTabClass() { return 'tab-btn' + (this.isTeamTab ? ' tab-active' : ''); }

    get statusBadgeClass() {
        const s = this.expense.Status__c;
        if (s === 'Draft') return 'status-badge status-draft';
        if (s === 'Submitted') return 'status-badge status-submitted';
        if (s === 'Manager Approved') return 'status-badge status-manager-approved';
        if (s === 'Finance Approved') return 'status-badge status-finance-approved';
        if (s === 'Rejected') return 'status-badge status-rejected';
        if (s === 'Paid') return 'status-badge status-paid';
        return 'status-badge';
    }

    get formattedSelectedDate() {
        if (!this.selectedDate) return '';
        const d = new Date(this.selectedDate + 'T00:00:00');
        return d.toLocaleDateString('en-IN', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
    }

    get totalClaimed() { return this.expense.Total_Claimed__c || 0; }
    get totalEligible() { return this.expense.Total_Eligible__c || 0; }
    get totalApproved() { return this.expense.Total_Approved__c || 0; }
    get workingDays() { return this.expense.Working_Days__c || 0; }
    get totalDistance() { return this.expense.Total_Distance_KM__c || 0; }

    get summaryTypeBreakdown() {
        return this.summary.typeBreakdown || [];
    }

    get summaryDayBreakdown() {
        return this.summary.dayBreakdown || [];
    }

    get hasTeamReports() { return this.teamReports.length > 0; }

    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'];
    }

    get approvalModalTitle() {
        if (this.approvalAction === 'approve') return 'Approve Expense';
        if (this.approvalAction === 'reject') return 'Reject Expense';
        if (this.approvalAction === 'paid') return 'Mark as Paid';
        return 'Confirmation';
    }

    get approvalActionLabel() {
        if (this.approvalAction === 'approve') return 'Approve';
        if (this.approvalAction === 'reject') return 'Reject';
        if (this.approvalAction === 'paid') return 'Mark Paid';
        return 'Confirm';
    }

    get approvalActionVariant() {
        return this.approvalAction === 'reject' ? 'destructive' : 'brand';
    }

    get showRemarksField() {
        return this.approvalAction === 'approve' || this.approvalAction === 'reject';
    }

    // ── Helpers ──────────────────────────────────────────────────
    showError(e) {
        let msg = 'An error occurred.';
        if (e && e.body && e.body.message) msg = e.body.message;
        else if (e && e.message) msg = e.message;
        this.errorMessage = msg;
        this.successMessage = '';
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.errorMessage = ''; }, 6000);
    }

    showSuccess(msg) {
        this.successMessage = msg;
        this.errorMessage = '';
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.successMessage = ''; }, 4000);
    }

    clearMessages() {
        this.errorMessage = '';
        this.successMessage = '';
    }

    getStatusClass(status) {
        if (status === 'Draft') return 'status-badge status-draft';
        if (status === 'Submitted') return 'status-badge status-submitted';
        if (status === 'Manager Approved') return 'status-badge status-manager-approved';
        if (status === 'Finance Approved') return 'status-badge status-finance-approved';
        if (status === 'Rejected') return 'status-badge status-rejected';
        if (status === 'Paid') return 'status-badge status-paid';
        return 'status-badge';
    }
}
