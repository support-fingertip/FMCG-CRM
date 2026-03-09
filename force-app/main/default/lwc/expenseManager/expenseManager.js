import { LightningElement, track } from 'lwc';
import getOrCreateReport from '@salesforce/apex/ExpenseController.getOrCreateReport';
import getEligibleDates from '@salesforce/apex/ExpenseController.getEligibleDates';
import getEligibilityRules from '@salesforce/apex/ExpenseController.getEligibilityRules';
import getAllExpenseItemsForReport from '@salesforce/apex/ExpenseController.getAllExpenseItemsForReport';
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

export default class ExpenseManager extends LightningElement {
    // ── State ─────────────────────────────────────────────────────
    @track currentScreen = 'LOADING';
    @track selectedMonth;
    @track selectedYear;
    @track expense = {};
    @track eligibleDates = [];
    @track eligibilityRules = [];
    @track config = {};

    // Accordion day list
    @track dayRows = [];
    @track showDayExpenses = false;
    @track selectAllDays = false;

    // Summary / Overview / Team
    @track summary = {};
    @track monthlyOverview = [];
    @track teamReports = [];

    // Approval modal
    @track showApprovalModal = false;
    @track approvalRemarks = '';
    @track approvalAction = '';
    @track approvalExpenseId = null;
    @track approvalLevel = '';

    // Active tab
    @track activeTab = 'expense';

    // Loading/error/messages
    @track isLoading = false;
    @track errorMessage = '';
    @track successMessage = '';
    @track saveError = '';

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
            this.showDayExpenses = false;
            this.dayRows = [];
            this.selectAllDays = false;
            this.expense = await getOrCreateReport({ month: this.selectedMonth, year: this.selectedYear });
            await Promise.all([
                this.loadEligibleDates(),
                this.loadEligibilityRules()
            ]);
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

    // ── ADD DAY EXPENSES ─────────────────────────────────────────
    async handleAddDayExpenses() {
        if (this.eligibleDates.length === 0) return;

        try {
            this.isLoading = true;
            this.saveError = '';

            // Load all existing expense items for this report
            const allItems = this.expense.Id
                ? await getAllExpenseItemsForReport({ expenseId: this.expense.Id })
                : [];

            // Group existing items by date
            const itemsByDate = {};
            allItems.forEach(item => {
                const d = item.Expense_Date__c;
                if (!itemsByDate[d]) itemsByDate[d] = [];
                itemsByDate[d].push(item);
            });

            // Build day rows from eligible dates
            this.dayRows = this.eligibleDates.map((dayInfo, idx) => {
                const dateStr = dayInfo.date;
                const existingItems = itemsByDate[dateStr] || [];
                const beatName = dayInfo.beatName || '';

                // Build expense items for this day from eligibility rules
                const items = this.eligibilityRules.map(rule => {
                    const existing = existingItems.find(i => i.Expense_Type__c === rule.Expense_Type__c);
                    const item = {
                        key: dateStr + '-' + rule.Expense_Type__c,
                        id: existing ? existing.Id : null,
                        expenseType: rule.Expense_Type__c,
                        category: rule.Expense_Category__c,
                        rateType: rule.Rate_Type__c,
                        rateAmount: rule.Rate_Amount__c || 0,
                        maxPerDay: rule.Max_Per_Day__c || 0,
                        minDistance: rule.Min_Distance_KM__c || 0,
                        receiptRequired: rule.Receipt_Required__c,
                        receiptThreshold: rule.Receipt_Threshold__c || 0,
                        gpsDistance: existing ? existing.GPS_Distance_KM__c : (dayInfo.gpsDistance || 0),
                        manualDistance: existing ? existing.Manual_Distance_KM__c : null,
                        overrideReason: existing ? existing.Distance_Override_Reason__c : '',
                        eligibleAmount: existing ? existing.Eligible_Amount__c : 0,
                        claimedAmount: existing ? existing.Claimed_Amount__c : 0,
                        fromLocation: existing ? existing.From_Location__c : '',
                        toLocation: existing ? existing.To_Location__c : '',
                        notes: existing ? existing.Notes__c : '',
                        isEligible: existing ? existing.Is_Eligible__c : true,
                        hasExisting: !!existing,
                        isActual: rule.Rate_Type__c === 'Actual',
                        isTravel: rule.Rate_Type__c === 'Per KM' || (rule.Min_Distance_KM__c && rule.Min_Distance_KM__c > 0),
                        showFromTo: rule.Expense_Category__c === 'Travel' && rule.Rate_Type__c === 'Per KM',
                        showRemarks: rule.Rate_Type__c === 'Actual' || rule.Expense_Category__c === 'Miscellaneous',
                        exceedsEligible: false,
                        statusLabel: existing ? 'Saved' : 'New',
                        statusClass: existing ? 'item-status item-status-saved' : 'item-status item-status-new',
                        files: [],
                        hasFiles: false,
                        dirty: false
                    };

                    if (!existing) {
                        item.eligibleAmount = this.recalcEligible(item);
                    }
                    return item;
                });

                const dayTotal = items.reduce((sum, i) => sum + (i.claimedAmount || 0), 0);

                return {
                    key: dateStr,
                    dateStr: dateStr,
                    formattedDate: this.formatDisplayDate(dateStr),
                    beatName: beatName,
                    attendanceId: dayInfo.attendanceId,
                    gpsDistance: dayInfo.gpsDistance || 0,
                    expanded: false,
                    selected: false,
                    items: items,
                    dayTotal: Math.round(dayTotal * 100) / 100,
                    dayTotalClass: dayTotal > 0 ? 'day-total-badge day-total-positive' : 'day-total-badge',
                    rowClass: 'day-accordion-row'
                };
            });

            this.showDayExpenses = true;

            // Load files for all items with IDs
            await this.loadAllFiles();
        } catch (e) {
            this.showError(e);
        } finally {
            this.isLoading = false;
        }
    }

    formatDisplayDate(dateStr) {
        const parts = dateStr.split('-');
        const d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
        return d.toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' });
    }

    // ── Accordion Toggle ─────────────────────────────────────────
    handleToggleDay(event) {
        const dateStr = event.currentTarget.dataset.date;
        this.dayRows = this.dayRows.map(row => {
            if (row.dateStr === dateStr) {
                return { ...row, expanded: !row.expanded };
            }
            return row;
        });
    }

    // ── Day Selection (checkboxes) ───────────────────────────────
    handleSelectAllDays(event) {
        this.selectAllDays = event.target.checked;
        this.dayRows = this.dayRows.map(row => ({
            ...row,
            selected: this.selectAllDays
        }));
    }

    handleSelectDay(event) {
        const dateStr = event.currentTarget.dataset.date;
        const checked = event.target.checked;
        this.dayRows = this.dayRows.map(row => {
            if (row.dateStr === dateStr) {
                return { ...row, selected: checked };
            }
            return row;
        });
        this.selectAllDays = this.dayRows.every(r => r.selected);
    }

    // ── Item Field Changes ───────────────────────────────────────
    handleItemFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const itemKey = event.currentTarget.dataset.key;
        const value = event.detail.value;

        this.dayRows = this.dayRows.map(row => {
            const itemIdx = row.items.findIndex(i => i.key === itemKey);
            if (itemIdx < 0) return row;

            const items = [...row.items];
            const item = { ...items[itemIdx] };

            if (field === 'claimedAmount') {
                item.claimedAmount = value ? parseFloat(value) : 0;
                if (item.isActual) {
                    item.eligibleAmount = this.recalcEligible(item);
                }
                item.exceedsEligible = !item.isActual && item.claimedAmount > 0 && item.claimedAmount > item.eligibleAmount;
            } else if (field === 'manualDistance') {
                item.manualDistance = value ? parseFloat(value) : null;
                item.eligibleAmount = this.recalcEligible(item);
            } else if (field === 'fromLocation') {
                item.fromLocation = value;
            } else if (field === 'toLocation') {
                item.toLocation = value;
            } else if (field === 'notes') {
                item.notes = value;
            } else if (field === 'overrideReason') {
                item.overrideReason = value;
            }

            item.dirty = true;
            items[itemIdx] = item;

            const dayTotal = items.reduce((sum, i) => sum + (i.claimedAmount || 0), 0);
            return {
                ...row,
                items,
                dayTotal: Math.round(dayTotal * 100) / 100,
                dayTotalClass: dayTotal > 0 ? 'day-total-badge day-total-positive' : 'day-total-badge'
            };
        });
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

    // ── File Upload ──────────────────────────────────────────────
    async loadAllFiles() {
        const allItemIds = [];
        this.dayRows.forEach(row => {
            row.items.forEach(item => {
                if (item.id) allItemIds.push(item.id);
            });
        });
        if (allItemIds.length === 0) return;

        try {
            const files = await getExpenseItemFiles({ itemIds: allItemIds });
            const filesByItem = {};
            files.forEach(f => {
                const itemId = f.expenseItemId;
                if (!filesByItem[itemId]) filesByItem[itemId] = [];
                filesByItem[itemId].push(f);
            });

            this.dayRows = this.dayRows.map(row => ({
                ...row,
                items: row.items.map(item => ({
                    ...item,
                    files: item.id ? (filesByItem[item.id] || []) : [],
                    hasFiles: item.id ? (filesByItem[item.id] || []).length > 0 : false
                }))
            }));
        } catch (e) {
            this.showError(e);
        }
    }

    async handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles && uploadedFiles.length > 0) {
            this.showSuccess(uploadedFiles.length + ' receipt(s) uploaded.');
            await this.loadAllFiles();
        }
    }

    async handleDeleteFile(event) {
        const docId = event.currentTarget.dataset.docid;
        try {
            this.isLoading = true;
            await deleteExpenseItemFile({ contentDocumentId: docId });
            this.showSuccess('Receipt deleted.');
            await this.loadAllFiles();
        } catch (e) {
            this.showError(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Save All ─────────────────────────────────────────────────
    async handleSaveAll() {
        this.saveError = '';

        // Client-side validation: notes required when claimed exceeds eligible
        const exceededNoNotes = [];
        this.dayRows.forEach(row => {
            row.items.forEach(item => {
                if (!item.isActual && item.claimedAmount > 0 && item.claimedAmount > item.eligibleAmount
                    && (!item.notes || item.notes.trim() === '')) {
                    exceededNoNotes.push(item.expenseType + ' on ' + row.formattedDate);
                }
            });
        });

        if (exceededNoNotes.length > 0) {
            this.saveError = 'Notes/Remarks are required when claimed amount exceeds eligible amount: ' + exceededNoNotes.join(', ');
            return;
        }

        try {
            this.isLoading = true;

            // Collect all items to save across all days
            const itemsToSave = [];
            this.dayRows.forEach(row => {
                row.items.forEach(item => {
                    if ((item.claimedAmount && item.claimedAmount > 0) || item.hasExisting) {
                        const rec = {
                            Expense_Date__c: row.dateStr,
                            Expense_Type__c: item.expenseType,
                            Expense_Category__c: item.category,
                            GPS_Distance_KM__c: item.gpsDistance,
                            Manual_Distance_KM__c: item.manualDistance,
                            Distance_Override_Reason__c: item.overrideReason,
                            Eligible_Amount__c: item.eligibleAmount,
                            Claimed_Amount__c: item.claimedAmount || 0,
                            From_Location__c: item.fromLocation || '',
                            To_Location__c: item.toLocation || '',
                            Notes__c: item.notes,
                            Rate_Type__c: item.rateType,
                            Rate_Amount__c: item.rateAmount,
                            Receipt_Required__c: item.receiptRequired,
                            Is_Eligible__c: item.isEligible,
                            Day_Attendance__c: row.attendanceId || null
                        };
                        if (item.id) rec.Id = item.id;
                        itemsToSave.push(rec);
                    }
                });
            });

            if (itemsToSave.length > 0) {
                const savedItems = await saveExpenseItems({
                    expenseId: this.expense.Id,
                    itemsJson: JSON.stringify(itemsToSave)
                });

                // Map saved IDs back to dayRows
                this.dayRows = this.dayRows.map(row => ({
                    ...row,
                    items: row.items.map(item => {
                        const saved = savedItems.find(
                            s => s.Expense_Date__c === row.dateStr && s.Expense_Type__c === item.expenseType
                        );
                        if (saved) {
                            return {
                                ...item,
                                id: saved.Id,
                                hasExisting: true,
                                dirty: false,
                                statusLabel: 'Saved',
                                statusClass: 'item-status item-status-saved'
                            };
                        }
                        return item;
                    })
                }));

                await this.loadAllFiles();
                this.showSuccess('All expense items saved successfully.');
            }

            // Refresh the expense record for updated totals
            this.expense = await getOrCreateReport({ month: this.selectedMonth, year: this.selectedYear });
        } catch (e) {
            let msg = 'An error occurred.';
            if (e && e.body && e.body.message) msg = e.body.message;
            else if (e && e.message) msg = e.message;
            this.saveError = msg;
        } finally {
            this.isLoading = false;
        }
    }

    // ── Save & Submit ────────────────────────────────────────────
    async handleSaveAndSubmit() {
        await this.handleSaveAll();
        if (this.saveError) return;

        try {
            this.isLoading = true;
            this.expense = await submitReport({ expenseId: this.expense.Id });
            this.showSuccess('Expense submitted for approval.');
            this.showDayExpenses = false;
        } catch (e) {
            this.showError(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Cancel ───────────────────────────────────────────────────
    handleCancel() {
        this.showDayExpenses = false;
        this.dayRows = [];
        this.saveError = '';
        this.selectAllDays = false;
    }

    // ── Delete Day Items ─────────────────────────────────────────
    async handleDeleteItem(event) {
        const itemKey = event.currentTarget.dataset.key;
        let itemId = null;

        this.dayRows = this.dayRows.map(row => {
            const itemIdx = row.items.findIndex(i => i.key === itemKey);
            if (itemIdx < 0) return row;

            const items = [...row.items];
            const item = items[itemIdx];
            itemId = item.id;

            // Reset item to defaults
            items[itemIdx] = {
                ...item,
                id: null,
                claimedAmount: 0,
                fromLocation: '',
                toLocation: '',
                notes: '',
                manualDistance: null,
                overrideReason: '',
                hasExisting: false,
                dirty: false,
                files: [],
                hasFiles: false,
                statusLabel: 'New',
                statusClass: 'item-status item-status-new',
                exceedsEligible: false
            };

            const dayTotal = items.reduce((sum, i) => sum + (i.claimedAmount || 0), 0);
            return {
                ...row,
                items,
                dayTotal: Math.round(dayTotal * 100) / 100,
                dayTotalClass: dayTotal > 0 ? 'day-total-badge day-total-positive' : 'day-total-badge'
            };
        });

        if (itemId) {
            try {
                this.isLoading = true;
                await deleteExpenseItems({ itemIds: [itemId] });
                this.showSuccess('Expense item deleted.');
            } catch (e) {
                this.showError(e);
            } finally {
                this.isLoading = false;
            }
        }
    }

    // ── Submit / Approve / Reject ────────────────────────────────
    async handleSubmit() {
        try {
            this.isLoading = true;
            this.expense = await submitReport({ expenseId: this.expense.Id });
            this.showSuccess('Expense submitted for approval.');
            this.showDayExpenses = false;
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

    // ── Computed Properties ──────────────────────────────────────
    get isMainScreen() { return this.currentScreen === 'MAIN'; }
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

    get totalClaimed() { return this.expense.Total_Claimed__c || 0; }
    get totalEligible() { return this.expense.Total_Eligible__c || 0; }
    get totalApproved() { return this.expense.Total_Approved__c || 0; }
    get workingDays() { return this.expense.Working_Days__c || 0; }
    get totalDistance() { return this.expense.Total_Distance_KM__c || 0; }

    get grandTotal() {
        return this.dayRows.reduce((sum, row) => sum + row.dayTotal, 0);
    }

    get hasEligibleDates() { return this.eligibleDates.length > 0; }
    get noAttendanceMessage() {
        if (this.eligibleDates.length > 0) return '';
        const monthIdx = MONTHS.findIndex(m => m.value === this.selectedMonth);
        const start = new Date(this.selectedYear, monthIdx, 1);
        const end = new Date(this.selectedYear, monthIdx + 1, 0);
        const fmt = d => d.toISOString().split('T')[0];
        return 'There are no attendance entries available between ' + fmt(start) + ' and ' + fmt(end) + '.';
    }

    get summaryTypeBreakdown() { return this.summary.typeBreakdown || []; }
    get summaryDayBreakdown() { return this.summary.dayBreakdown || []; }
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

    get employeeName() {
        return this.expense.Employee__r
            ? (this.expense.Employee__r.First_Name__c + ' ' + this.expense.Employee__r.Last_Name__c)
            : '';
    }

    get expenseStartDate() {
        const monthIdx = MONTHS.findIndex(m => m.value === this.selectedMonth);
        const d = new Date(this.selectedYear, monthIdx, 1);
        return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    get expenseEndDate() {
        const monthIdx = MONTHS.findIndex(m => m.value === this.selectedMonth);
        const d = new Date(this.selectedYear, monthIdx + 1, 0);
        return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
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
        this.saveError = '';
    }
}
