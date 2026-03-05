import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getInitialContext from '@salesforce/apex/VisitManagerController.getInitialContext';
import startDayApex from '@salesforce/apex/VisitManagerController.startDay';
import endDayApex from '@salesforce/apex/VisitManagerController.endDay';
import selectBeatApex from '@salesforce/apex/VisitManagerController.selectBeat';
import switchBeatApex from '@salesforce/apex/VisitManagerController.switchBeat';
import checkInVisitApex from '@salesforce/apex/VisitManagerController.checkInVisit';
import checkOutVisitApex from '@salesforce/apex/VisitManagerController.checkOutVisit';
import skipVisitApex from '@salesforce/apex/VisitManagerController.skipVisit';
import skipPlannedVisitApex from '@salesforce/apex/VisitManagerController.skipPlannedVisit';
import refreshDayData from '@salesforce/apex/VisitManagerController.refreshDayData';
import refreshVisitSummary from '@salesforce/apex/VisitManagerController.refreshVisitSummary';
import searchOutletsApex from '@salesforce/apex/VisitManagerController.searchOutlets';
import searchEmployeesApex from '@salesforce/apex/VisitManagerController.searchEmployees';
import getOutletSummaryApex from '@salesforce/apex/VisitManagerController.getOutletSummary';

// ── SCREEN STATES ──
const SCREEN = {
    LOADING: 'loading',
    DAY_START: 'day_start',
    BEAT_SELECT: 'beat_select',
    VISIT_BOARD: 'visit_board',
    VISIT_ACTIVE: 'visit_active',
    VISIT_DETAIL: 'visit_detail'
};

const VISIT_STATUS = {
    PLANNED: 'Planned',
    CHECKED_IN: 'Checked In',
    IN_PROGRESS: 'In Progress',
    COMPLETED: 'Completed',
    SKIPPED: 'Skipped',
    MISSED: 'Missed'
};

const INR = new Intl.NumberFormat('en-IN', {
    style: 'currency', currency: 'INR',
    minimumFractionDigits: 0, maximumFractionDigits: 0
});

const ADDR_LEN = 45;

export default class VisitManager extends LightningElement {

    // ── SCREEN STATE ──
    @track currentScreen = SCREEN.LOADING;
    @track isProcessing = false;

    // ── CONFIG ──
    @track config = {};

    // ── DAY ATTENDANCE ──
    @track dayAttendance = null;
    @track dayStats = {};

    // ── LOCATION & DEVICE ──
    @track latitude = 0;
    @track longitude = 0;
    @track accuracy = 0;
    @track locationCaptured = false;
    @track batteryLevel = 0;
    @track networkStatus = 'Online';

    // ── BEATS ──
    @track todaysBeats = [];
    @track selectedBeatId = null;
    @track activeBeatId = null;
    @track showBeatConfirmModal = false;

    // ── DAY START FORM ──
    @track odometerStart = null;
    @track withCompanion = false;
    @track companionId = null;
    @track companionName = '';
    @track companionSearchTerm = '';
    @track companionSearchResults = [];
    @track showCompanionDropdown = false;
    @track startSelfiePreview = null;
    _startSelfieBase64 = null;

    // ── VISITS ──
    @track allVisits = [];
    @track boardTab = 'planned';

    // ── ACTIVE VISIT ──
    @track activeVisit = null;
    @track activeVisitSummary = {};
    @track visitActivities = [];
    @track outletSummary = {};
    @track visitDuration = 0;
    @track activeVisitTab = 'activities';

    // ── COMPLETED VISIT DETAIL ──
    @track detailVisit = null;
    @track detailVisitSummary = {};
    @track detailVisitTab = 'orders';

    // ── AD-HOC ──
    @track showAdHocModal = false;
    @track adHocSearchTerm = '';
    @track adHocSearchResults = [];
    @track adHocSelectedAccount = null;
    @track adHocReason = '';
    @track showAdHocDropdown = false;

    // ── SKIP ──
    @track showSkipModal = false;
    @track skipVisitId = null;
    @track skipReason = '';

    // ── SWITCH BEAT ──
    @track showSwitchBeatModal = false;
    @track switchBeatId = null;
    @track switchBeatReason = '';

    // ── CHECKOUT ──
    @track showCheckoutModal = false;
    @track isProductive = true;
    @track nonProductiveReason = '';
    @track visitNotes = '';
    @track checklistItems = [];

    // ── DAY END ──
    @track showEndDayModal = false;
    @track odometerEnd = null;
    @track endDayRemarks = '';
    @track endSelfiePreview = null;
    _endSelfieBase64 = null;

    // ── CLOCK ──
    @track currentTime = '';
    @track dayStartTime = null;

    // ── INTERNALS ──
    _clockInterval = null;
    _statsInterval = null;
    _timerInterval = null;
    _searchTimer = null;
    _companionTimer = null;
    _deviceInfo = '';
    _hasLoaded = false;

    // ═══════════════════════════════════════════════════
    // LIFECYCLE
    // ═══════════════════════════════════════════════════
    connectedCallback() {
        this._updateClock();
        this._clockInterval = setInterval(() => this._updateClock(), 1000);
        this._captureLocation();
        this._captureDeviceInfo();
        this._loadInitialContext();
    }

    disconnectedCallback() {
        if (this._clockInterval) clearInterval(this._clockInterval);
        if (this._statsInterval) clearInterval(this._statsInterval);
        if (this._timerInterval) clearInterval(this._timerInterval);
    }

    // ═══════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════
    async _loadInitialContext() {
        try {
            const ctx = await getInitialContext();
            this.config = ctx.config || {};
            this.todaysBeats = (ctx.todaysBeats || []).map(b => ({
                ...b,
                cardClass: 'vm-beat-card',
                outletsLabel: (b.outletCount || 0) + ' Outlets'
            }));

            if (ctx.isDayStarted && ctx.dayAttendance) {
                this.dayAttendance = ctx.dayAttendance;
                this.dayStats = ctx.dayStats || {};
                this.activeBeatId = ctx.currentBeatId || null;
                this.dayStartTime = new Date(ctx.dayAttendance.Day_Start_Time__c || ctx.dayAttendance.Start_Time__c);

                // If day started but user hasn't explicitly selected a beat yet
                // (Original_Beat__c is set by selectBeat to confirm user's choice)
                const beatConfirmed = ctx.dayAttendance.Original_Beat__c != null;
                if (!beatConfirmed) {
                    this.currentScreen = SCREEN.BEAT_SELECT;
                } else {
                    this._processVisits(ctx.todaysVisits || [], ctx.plannedVisits || []);

                    // Auto-redirect to in-progress visit
                    if (ctx.hasActiveVisit && ctx.activeVisit) {
                        this.activeVisit = ctx.activeVisit;
                        this.activeVisitSummary = ctx.activeVisitSummary || {};
                        this.visitActivities = this._processActivities(ctx.visitActivities || []);
                        this._startVisitTimer();
                        this._loadOutletSummary(ctx.activeVisit.Account__c);
                        this.currentScreen = SCREEN.VISIT_ACTIVE;
                    } else {
                        this.currentScreen = SCREEN.VISIT_BOARD;
                    }

                    this._startStatsRefresh();
                }
            } else {
                this.currentScreen = SCREEN.DAY_START;
            }

            this._hasLoaded = true;
        } catch (err) {
            this._toast('Error', 'Failed to load: ' + this._err(err), 'error');
            this.currentScreen = SCREEN.DAY_START;
        }
    }

    // ═══════════════════════════════════════════════════
    // SCREEN GETTERS
    // ═══════════════════════════════════════════════════
    get isLoadingScreen() { return this.currentScreen === SCREEN.LOADING; }
    get isDayStartScreen() { return this.currentScreen === SCREEN.DAY_START; }
    get isBeatSelectScreen() { return this.currentScreen === SCREEN.BEAT_SELECT; }
    get isVisitBoardScreen() { return this.currentScreen === SCREEN.VISIT_BOARD; }
    get isVisitActiveScreen() { return this.currentScreen === SCREEN.VISIT_ACTIVE; }
    get isVisitDetailScreen() { return this.currentScreen === SCREEN.VISIT_DETAIL; }

    // ═══════════════════════════════════════════════════
    // CLOCK & TIME
    // ═══════════════════════════════════════════════════
    _updateClock() {
        const now = new Date();
        this.currentTime = now.toLocaleTimeString('en-IN', {
            hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: true
        });
    }

    get todayDateDisplay() {
        return new Date().toLocaleDateString('en-IN', {
            weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
        });
    }

    get greetingMessage() {
        const h = new Date().getHours();
        if (h < 12) return 'Good Morning';
        if (h < 17) return 'Good Afternoon';
        return 'Good Evening';
    }

    get dayDurationDisplay() {
        // Reference currentTime to create a reactive dependency that ticks every second
        void this.currentTime;
        if (!this.dayStartTime) return '00:00:00';
        const diff = Math.floor((Date.now() - this.dayStartTime.getTime()) / 1000);
        const h = Math.floor(diff / 3600);
        const m = Math.floor((diff % 3600) / 60);
        const s = diff % 60;
        return `${this._pad(h)}:${this._pad(m)}:${this._pad(s)}`;
    }

    get dayStartTimeDisplay() {
        if (!this.dayStartTime) return '--';
        return this.dayStartTime.toLocaleTimeString('en-IN', {
            hour: '2-digit', minute: '2-digit', hour12: true
        });
    }

    // ═══════════════════════════════════════════════════
    // LOCATION & DEVICE
    // ═══════════════════════════════════════════════════
    _captureLocation() {
        if (!navigator.geolocation) return;
        navigator.geolocation.getCurrentPosition(
            (pos) => {
                this.latitude = pos.coords.latitude;
                this.longitude = pos.coords.longitude;
                this.accuracy = pos.coords.accuracy;
                this.locationCaptured = true;
            },
            () => { this.locationCaptured = false; },
            { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
        );
    }

    _captureLocationAsync() {
        return new Promise((resolve) => {
            if (!navigator.geolocation) {
                resolve({ latitude: 0, longitude: 0, accuracy: 0 });
                return;
            }
            navigator.geolocation.getCurrentPosition(
                (pos) => {
                    this.latitude = pos.coords.latitude;
                    this.longitude = pos.coords.longitude;
                    this.accuracy = pos.coords.accuracy;
                    this.locationCaptured = true;
                    resolve({ latitude: pos.coords.latitude, longitude: pos.coords.longitude, accuracy: pos.coords.accuracy });
                },
                () => resolve({ latitude: this.latitude, longitude: this.longitude, accuracy: this.accuracy }),
                { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
            );
        });
    }

    async _captureDeviceInfo() {
        this._deviceInfo = navigator.userAgent || '';
        this.networkStatus = navigator.onLine ? 'Online' : 'Offline';
        try {
            if (navigator.getBattery) {
                const bat = await navigator.getBattery();
                this.batteryLevel = Math.round(bat.level * 100);
            }
        } catch (e) { /* ignore */ }
    }

    get locationStatusText() {
        return this.locationCaptured
            ? `${this.latitude.toFixed(5)}, ${this.longitude.toFixed(5)}`
            : 'Fetching...';
    }

    // ═══════════════════════════════════════════════════
    // DAY START
    // ═══════════════════════════════════════════════════
    get startDayDisabled() {
        return this.isProcessing || !this.locationCaptured ||
            (this.config.selfieRequired && !this._startSelfieBase64);
    }

    handleOdometerStartChange(e) { this.odometerStart = e.detail.value ? Number(e.detail.value) : null; }

    handleCompanionToggle(e) {
        this.withCompanion = e.target.checked;
        if (!this.withCompanion) {
            this.companionId = null;
            this.companionName = '';
            this.companionSearchTerm = '';
        }
    }

    handleCompanionSearch(e) {
        const term = e.target.value || '';
        this.companionSearchTerm = term;
        if (this._companionTimer) clearTimeout(this._companionTimer);
        if (term.length < 2) { this.companionSearchResults = []; this.showCompanionDropdown = false; return; }
        this._companionTimer = setTimeout(() => this._doCompanionSearch(term), 300);
    }

    async _doCompanionSearch(term) {
        try {
            const results = await searchEmployeesApex({ searchTerm: term });
            this.companionSearchResults = (results || []).map(emp => ({
                id: emp.Id, name: emp.Name, subtitle: emp.Employee_Code__c || ''
            }));
            this.showCompanionDropdown = this.companionSearchResults.length > 0;
        } catch (err) { this.showCompanionDropdown = false; }
    }

    handleCompanionSelect(e) {
        const emp = this.companionSearchResults.find(r => r.id === e.currentTarget.dataset.id);
        if (emp) {
            this.companionId = emp.id;
            this.companionName = emp.name;
            this.companionSearchTerm = emp.name;
            this.showCompanionDropdown = false;
        }
    }

    clearCompanion() {
        this.companionId = null;
        this.companionName = '';
        this.companionSearchTerm = '';
    }

    handleStartSelfieCapture(e) {
        this._processPhoto(e, (base64, preview) => {
            this._startSelfieBase64 = base64;
            this.startSelfiePreview = preview;
        });
    }

    removeStartSelfie() {
        this._startSelfieBase64 = null;
        this.startSelfiePreview = null;
    }

    async handleStartDay() {
        if (this.startDayDisabled) return;
        this.isProcessing = true;
        try {
            await this._captureLocationAsync();
            const dayData = {
                startLatitude: this.latitude,
                startLongitude: this.longitude,
                startAccuracy: this.accuracy,
                selfieBase64: this._startSelfieBase64 || '',
                batteryLevel: this.batteryLevel,
                networkStatus: this.networkStatus,
                deviceInfo: this._deviceInfo,
                odometerStart: this.odometerStart || 0,
                withCompanion: this.withCompanion,
                companionId: this.companionId
            };

            const result = await startDayApex({ dayJson: JSON.stringify(dayData) });
            this.dayAttendance = result;
            this.dayStartTime = new Date(result.Day_Start_Time__c || result.Start_Time__c);

            this._toast('Success', 'Day started! Now select your beat.', 'success');
            this.currentScreen = SCREEN.BEAT_SELECT;
        } catch (err) {
            this._toast('Error', 'Failed to start day: ' + this._err(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ═══════════════════════════════════════════════════
    // BEAT SELECTION (after day start)
    // ═══════════════════════════════════════════════════
    get hasBeats() { return this.todaysBeats.length > 0; }

    get assignedBeats() {
        return this.todaysBeats.filter(b => b.isAssigned);
    }

    get otherBeats() {
        return this.todaysBeats.filter(b => !b.isAssigned);
    }

    get hasOtherBeats() { return this.otherBeats.length > 0; }

    get selectedBeatName() {
        const b = this.todaysBeats.find(bt => bt.beatId === this.selectedBeatId);
        return b ? b.beatName : '';
    }

    get selectedBeatOutletCount() {
        const b = this.todaysBeats.find(bt => bt.beatId === this.selectedBeatId);
        return b ? (b.outletCount || 0) : 0;
    }

    get selectedBeatIsAssigned() {
        const b = this.todaysBeats.find(bt => bt.beatId === this.selectedBeatId);
        return b ? b.isAssigned : false;
    }

    get beatsWithSelection() {
        return this.todaysBeats.map(b => ({
            ...b,
            cardClass: b.beatId === this.selectedBeatId
                ? 'vm-beat-card vm-beat-selected'
                : b.isAssigned ? 'vm-beat-card vm-beat-assigned' : 'vm-beat-card',
            isSelected: b.beatId === this.selectedBeatId
        }));
    }

    get assignedBeatsWithSelection() {
        return this.beatsWithSelection.filter(b => b.isAssigned);
    }

    get otherBeatsWithSelection() {
        return this.beatsWithSelection.filter(b => !b.isAssigned);
    }

    get selectBeatDisabled() {
        return this.isProcessing || !this.selectedBeatId;
    }

    handleBeatSelect(e) {
        this.selectedBeatId = e.currentTarget.dataset.beatId;
    }

    handleBeatConfirm() {
        if (!this.selectedBeatId) {
            this._toast('Warning', 'Please select a beat first.', 'warning');
            return;
        }
        this.showBeatConfirmModal = true;
    }

    handleBeatConfirmClose() {
        this.showBeatConfirmModal = false;
    }

    async handleSelectBeatConfirm() {
        if (!this.selectedBeatId || !this.dayAttendance) return;
        this.showBeatConfirmModal = false;
        this.isProcessing = true;
        try {
            const selectedBeat = this.todaysBeats.find(b => b.beatId === this.selectedBeatId);
            const jpDayId = selectedBeat ? selectedBeat.journeyPlanDayId : null;

            const result = await selectBeatApex({
                attendanceId: this.dayAttendance.Id,
                beatId: this.selectedBeatId,
                journeyPlanDayId: jpDayId
            });

            this.dayAttendance = result;
            this.activeBeatId = this.selectedBeatId;

            await this._refreshAllData();
            this._startStatsRefresh();
            this.currentScreen = SCREEN.VISIT_BOARD;
            this._toast('Success', 'Beat selected: ' + this.selectedBeatName, 'success');
        } catch (err) {
            this._toast('Error', 'Failed to select beat: ' + this._err(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ═══════════════════════════════════════════════════
    // VISIT BOARD
    // ═══════════════════════════════════════════════════
    _processVisits(todaysVisits, plannedVisitsMaps) {
        const processed = (todaysVisits || []).map(v => this._enrichVisit(v));
        const visitedAccountIds = new Set(todaysVisits.map(v => v.Account__c));

        const planned = (plannedVisitsMaps || [])
            .filter(p => !visitedAccountIds.has(p.accountId))
            .map((p, idx) => ({
                Id: 'planned_' + p.accountId + '_' + idx,
                Account__c: p.accountId,
                Account__r: { Name: p.accountName, BillingCity: p.city || '' },
                Beat__c: p.beatId,
                Beat__r: { Name: p.beatName },
                Visit_Status__c: VISIT_STATUS.PLANNED,
                Visit_Sequence__c: p.sequence || (idx + 1),
                Is_Planned__c: true,
                Is_Ad_Hoc__c: false,
                _journeyPlanDayId: p.journeyPlanDayId,
                _isFromPlan: true,
                outletName: p.accountName || 'Unknown Outlet',
                beatName: p.beatName || '',
                truncatedAddress: p.city || 'No address',
                checkInTimeDisplay: '--',
                durationDisplay: '--',
                orderValueFormatted: '',
                collectionFormatted: ''
            }));

        this.allVisits = [...planned, ...processed];
    }

    _enrichVisit(v) {
        const name = v.Account__r ? v.Account__r.Name : 'Unknown';
        const street = v.Account__r ? (v.Account__r.BillingStreet || '') : '';
        const city = v.Account__r ? (v.Account__r.BillingCity || '') : '';
        const addr = [street, city].filter(Boolean).join(', ');
        return {
            ...v,
            outletName: name,
            truncatedAddress: addr.length > ADDR_LEN ? addr.substring(0, ADDR_LEN) + '...' : addr || 'No address',
            beatName: v.Beat__r ? v.Beat__r.Name : '',
            checkInTimeDisplay: this._fmtTime(v.Check_In_Time__c),
            checkOutTimeDisplay: this._fmtTime(v.Check_Out_Time__c),
            durationDisplay: this._fmtDuration(v.Duration_Minutes__c),
            orderValueFormatted: v.Order_Value__c ? INR.format(v.Order_Value__c) : '',
            collectionFormatted: v.Collection_Amount__c ? INR.format(v.Collection_Amount__c) : ''
        };
    }

    // Board data getters — filtered by active beat
    get plannedVisits() {
        return this.allVisits
            .filter(v => v.Visit_Status__c === VISIT_STATUS.PLANNED &&
                (!this.activeBeatId || v.Beat__c === this.activeBeatId))
            .sort((a, b) => (a.Visit_Sequence__c || 0) - (b.Visit_Sequence__c || 0));
    }

    get activeVisits() {
        return this.allVisits.filter(v =>
            v.Visit_Status__c === VISIT_STATUS.CHECKED_IN ||
            v.Visit_Status__c === VISIT_STATUS.IN_PROGRESS
        );
    }
    get completedVisits() {
        return this.allVisits.filter(v => v.Visit_Status__c === VISIT_STATUS.COMPLETED);
    }
    get skippedVisits() {
        return this.allVisits.filter(v => v.Visit_Status__c === VISIT_STATUS.SKIPPED);
    }


    // Enriched planned visits — all can check in (no sequence restriction)
    get plannedVisitsEnriched() {
        return this.plannedVisits.map(v => ({
            ...v,
            canCheckIn: v._isFromPlan,
            isLocked: false,
            rowClass: 'vm-visit-row vm-row-planned vm-row-next'
        }));
    }

    // Stats
    get statCompleted() { return this.completedVisits.length; }
    get statPlanned() { return this.plannedVisits.length; }
    get statActive() { return this.activeVisits.length; }
    get statSkipped() { return this.skippedVisits.length; }
    get statProductivity() { return this.dayStats.Productivity_Percent__c || 0; }
    get statOrders() { return this.dayStats.Orders_Today__c || 0; }
    get statOrderValue() { return INR.format(this.dayStats.Order_Value__c || 0); }
    get statCollection() { return INR.format(this.dayStats.Collection_Total__c || 0); }
    get currentBeatName() {
        if (this.dayAttendance && this.dayAttendance.Beat__r) return this.dayAttendance.Beat__r.Name;
        const b = this.todaysBeats.find(bt => bt.beatId === this.activeBeatId);
        return b ? b.beatName : 'No Beat Assigned';
    }

    // Board tabs
    get isPlannedTab() { return this.boardTab === 'planned'; }
    get isCompletedTab() { return this.boardTab === 'completed'; }
    get isSkippedTab() { return this.boardTab === 'skipped'; }
    get plannedTabCls() { return 'vm-tab' + (this.isPlannedTab ? ' vm-tab-active vm-tab-planned' : ''); }
    get completedTabCls() { return 'vm-tab' + (this.isCompletedTab ? ' vm-tab-active vm-tab-done' : ''); }
    get skippedTabCls() { return 'vm-tab' + (this.isSkippedTab ? ' vm-tab-active vm-tab-skip' : ''); }

    handleBoardTab(e) { this.boardTab = e.currentTarget.dataset.tab; }

    // ═══════════════════════════════════════════════════
    // CHECK-IN
    // ═══════════════════════════════════════════════════
    async handleCheckIn(e) {
        e.stopPropagation();
        const accountId = e.currentTarget.dataset.accountId;
        const beatId = e.currentTarget.dataset.beatId;
        const jpdayId = e.currentTarget.dataset.jpdayId;
        const existingVisitId = e.currentTarget.dataset.id || null;

        if (!accountId) { this._toast('Error', 'No outlet found.', 'error'); return; }


        // Block if active visit exists
        if (this.activeVisits.length > 0) {
            this._toast('Warning', 'Complete the current active visit first.', 'warning');
            return;
        }

        this.isProcessing = true;
        try {
            const pos = await this._captureLocationAsync();
            const visitData = {
                accountId, beatId: beatId || this.activeBeatId,
                dayAttendanceId: this.dayAttendance.Id,
                journeyPlanDayId: jpdayId || null,
                latitude: pos.latitude, longitude: pos.longitude, accuracy: pos.accuracy,
                batteryLevel: this.batteryLevel,
                networkStatus: this.networkStatus,
                isPlanned: true,
                existingVisitId: existingVisitId
            };

            const visit = await checkInVisitApex({ visitJson: JSON.stringify(visitData) });
            this._toast('Success', 'Checked in successfully!', 'success');

            this.activeVisit = visit;
            await this._loadActiveVisitData(visit.Id, accountId);
            this._startVisitTimer();
            this.currentScreen = SCREEN.VISIT_ACTIVE;
            await this._refreshAllData();
        } catch (err) {
            this._toast('Error', 'Check-in failed: ' + this._err(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    async _loadActiveVisitData(visitId, accountId) {
        try {
            const [summary, , outlet] = await Promise.all([
                refreshVisitSummary({ visitId }),
                this._loadActivitiesData(),
                accountId ? getOutletSummaryApex({ accountId }) : Promise.resolve({})
            ]);
            this.activeVisitSummary = summary || {};
            this.outletSummary = outlet || {};
        } catch (err) {
            console.error('Error loading visit data:', err);
        }
    }

    async _loadActivitiesData() {
        try {
            const acts = await getInitialContext();
            if (acts && acts.visitActivities) {
                this.visitActivities = this._processActivities(acts.visitActivities);
            }
        } catch (e) {
            this.visitActivities = [
                { id: 'order', label: 'Order', icon: 'standard:orders', completed: false, cardClass: 'va-act-card' },
                { id: 'collection', label: 'Collection', icon: 'standard:currency', completed: false, cardClass: 'va-act-card' },
                { id: 'returns', label: 'Returns', icon: 'standard:return_order', completed: false, cardClass: 'va-act-card' }
            ];
        }
    }

    async _loadOutletSummary(accountId) {
        if (!accountId) return;
        try {
            this.outletSummary = await getOutletSummaryApex({ accountId }) || {};
        } catch (e) { /* ignore */ }
    }

    _processActivities(activities) {
        return (activities || []).map(a => ({
            ...a,
            completed: false,
            cardClass: 'va-act-card'
        }));
    }

    // ═══════════════════════════════════════════════════
    // VISIT TIMER
    // ═══════════════════════════════════════════════════
    _startVisitTimer() {
        this._stopVisitTimer();
        this.visitDuration = 0;
        if (this.activeVisit && this.activeVisit.Check_In_Time__c) {
            const start = new Date(this.activeVisit.Check_In_Time__c);
            this.visitDuration = Math.floor((Date.now() - start.getTime()) / 1000);
        }
        this._timerInterval = setInterval(() => { this.visitDuration++; }, 1000);
    }

    _stopVisitTimer() {
        if (this._timerInterval) { clearInterval(this._timerInterval); this._timerInterval = null; }
    }

    get visitDurationDisplay() {
        const h = Math.floor(this.visitDuration / 3600);
        const m = Math.floor((this.visitDuration % 3600) / 60);
        const s = this.visitDuration % 60;
        return `${this._pad(h)}:${this._pad(m)}:${this._pad(s)}`;
    }

    get visitCheckInTime() {
        if (!this.activeVisit || !this.activeVisit.Check_In_Time__c) return '--';
        return this._fmtTime(this.activeVisit.Check_In_Time__c);
    }

    // ═══════════════════════════════════════════════════
    // ACTIVE VISIT SCREEN
    // ═══════════════════════════════════════════════════
    get activeOutletName() { return this.activeVisit ? (this.activeVisit.Account__r ? this.activeVisit.Account__r.Name : '') : ''; }
    get activeBeatNameDisplay() { return this.activeVisit ? (this.activeVisit.Beat__r ? this.activeVisit.Beat__r.Name : '') : ''; }
    get activeSequence() { return this.activeVisit ? this.activeVisit.Visit_Sequence__c : ''; }
    get activeIsAdHoc() { return this.activeVisit ? this.activeVisit.Is_Ad_Hoc__c : false; }
    get activeOrdersCount() { return this.activeVisitSummary.ordersCount || 0; }
    get activeOrderValue() { return INR.format(this.activeVisitSummary.totalOrderValue || 0); }
    get activeCollectionAmount() { return INR.format(this.activeVisitSummary.totalCollection || 0); }
    get activeReturnsCount() { return this.activeVisitSummary.returnsCount || 0; }
    get activeOrders() {
        return (this.activeVisitSummary.orders || []).map(o => ({
            ...o,
            amountFormatted: INR.format(o.Total_Net_Amount__c || 0)
        }));
    }
    get activeCollections() {
        return (this.activeVisitSummary.collections || []).map(c => ({
            ...c,
            amountFormatted: INR.format(c.Amount__c || 0)
        }));
    }
    get activeReturns() {
        return (this.activeVisitSummary.returns || []).map(r => ({
            ...r,
            amountFormatted: INR.format(r.Total_Return_Amount__c || 0)
        }));
    }
    get hasActiveOrders() { return this.activeOrders.length > 0; }
    get hasActiveCollections() { return this.activeCollections.length > 0; }
    get hasActiveReturns() { return this.activeReturns.length > 0; }

    // Outlet summary getters
    get outletLastVisit() { return this.outletSummary.lastVisitDate || 'N/A'; }
    get outletOutstanding() { return this.outletSummary.outstandingBalanceFormatted || INR.format(0); }
    get outletPendingOrders() { return this.outletSummary.pendingOrders || 0; }
    get outletType() { return this.outletSummary.outletType || '--'; }
    get outletChannel() { return this.outletSummary.channel || '--'; }
    get outletCreditLimit() { return this.outletSummary.creditLimit ? INR.format(this.outletSummary.creditLimit) : '--'; }
    get outletCity() { return this.outletSummary.city || '--'; }

    // Active visit tabs
    get isActivitiesVTab() { return this.activeVisitTab === 'activities'; }
    get isOrdersVTab() { return this.activeVisitTab === 'orders'; }
    get isCollectionsVTab() { return this.activeVisitTab === 'collections'; }
    get isReturnsVTab() { return this.activeVisitTab === 'returns'; }
    get isOutletVTab() { return this.activeVisitTab === 'outlet'; }
    get activitiesVTabCls() { return 'vm-tab' + (this.isActivitiesVTab ? ' vm-tab-active' : ''); }
    get ordersVTabCls() { return 'vm-tab' + (this.isOrdersVTab ? ' vm-tab-active' : ''); }
    get collectionsVTabCls() { return 'vm-tab' + (this.isCollectionsVTab ? ' vm-tab-active' : ''); }
    get returnsVTabCls() { return 'vm-tab' + (this.isReturnsVTab ? ' vm-tab-active' : ''); }
    get outletVTabCls() { return 'vm-tab' + (this.isOutletVTab ? ' vm-tab-active' : ''); }

    handleActiveVisitTab(e) { this.activeVisitTab = e.currentTarget.dataset.tab; }

    handleToggleActivity(e) {
        const id = e.currentTarget.dataset.id;
        this.visitActivities = this.visitActivities.map(a => {
            if (a.id === id) {
                const completed = !a.completed;
                return { ...a, completed, cardClass: completed ? 'va-act-card va-act-done' : 'va-act-card' };
            }
            return a;
        });
    }

    async handleRefreshVisitSummary() {
        if (!this.activeVisit) return;
        try {
            this.activeVisitSummary = await refreshVisitSummary({ visitId: this.activeVisit.Id }) || {};
        } catch (e) { /* ignore */ }
    }

    // NAVIGATION: Back to Visit Board from Active Visit
    handleBackToBoard() {
        if (this.activeVisit) {
            this._toast('Warning', 'Please check out the current visit first.', 'warning');
            return;
        }
        this.currentScreen = SCREEN.VISIT_BOARD;
    }

    // ═══════════════════════════════════════════════════
    // COMPLETED VISIT DETAIL
    // ═══════════════════════════════════════════════════
    async handleCompletedVisitClick(e) {
        const visitId = e.currentTarget.dataset.id;
        const visit = this.allVisits.find(v => v.Id === visitId);
        if (!visit) return;

        this.detailVisit = visit;
        this.detailVisitSummary = {};
        this.detailVisitTab = 'orders';
        this.currentScreen = SCREEN.VISIT_DETAIL;

        try {
            this.isProcessing = true;
            this.detailVisitSummary = await refreshVisitSummary({ visitId }) || {};
        } catch (err) {
            this._toast('Error', 'Failed to load visit details.', 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    handleBackToBoardFromDetail() {
        this.detailVisit = null;
        this.detailVisitSummary = {};
        this.currentScreen = SCREEN.VISIT_BOARD;
    }

    handleDetailTab(e) { this.detailVisitTab = e.currentTarget.dataset.tab; }

    // Detail visit getters
    get detailOutletName() { return this.detailVisit ? (this.detailVisit.Account__r ? this.detailVisit.Account__r.Name : '') : ''; }
    get detailBeatName() { return this.detailVisit ? (this.detailVisit.Beat__r ? this.detailVisit.Beat__r.Name : '') : ''; }
    get detailSequence() { return this.detailVisit ? this.detailVisit.Visit_Sequence__c : ''; }
    get detailIsAdHoc() { return this.detailVisit ? this.detailVisit.Is_Ad_Hoc__c : false; }
    get detailIsProductive() { return this.detailVisit ? this.detailVisit.Is_Productive__c : false; }
    get detailCheckInTime() {
        if (!this.detailVisit || !this.detailVisit.Check_In_Time__c) return '--';
        return this._fmtTime(this.detailVisit.Check_In_Time__c);
    }
    get detailCheckOutTime() {
        if (!this.detailVisit || !this.detailVisit.Check_Out_Time__c) return '--';
        return this._fmtTime(this.detailVisit.Check_Out_Time__c);
    }
    get detailDuration() {
        if (!this.detailVisit || !this.detailVisit.Duration_Minutes__c) return '--';
        const mins = this.detailVisit.Duration_Minutes__c;
        const h = Math.floor(mins / 60);
        const m = Math.round(mins % 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }
    get detailOrdersCount() { return this.detailVisitSummary.ordersCount || 0; }
    get detailOrderValue() { return INR.format(this.detailVisitSummary.totalOrderValue || 0); }
    get detailCollectionAmount() { return INR.format(this.detailVisitSummary.totalCollection || 0); }
    get detailReturnsCount() { return this.detailVisitSummary.returnsCount || 0; }
    get detailOrders() {
        return (this.detailVisitSummary.orders || []).map(o => ({
            ...o,
            amountFormatted: INR.format(o.Total_Net_Amount__c || 0)
        }));
    }
    get detailCollections() {
        return (this.detailVisitSummary.collections || []).map(c => ({
            ...c,
            amountFormatted: INR.format(c.Amount__c || 0)
        }));
    }
    get detailReturns() {
        return (this.detailVisitSummary.returns || []).map(r => ({
            ...r,
            amountFormatted: INR.format(r.Total_Return_Amount__c || 0)
        }));
    }
    get hasDetailOrders() { return this.detailOrders.length > 0; }
    get hasDetailCollections() { return this.detailCollections.length > 0; }
    get hasDetailReturns() { return this.detailReturns.length > 0; }

    // Detail tabs
    get isDetailOrdersTab() { return this.detailVisitTab === 'orders'; }
    get isDetailCollectionsTab() { return this.detailVisitTab === 'collections'; }
    get isDetailReturnsTab() { return this.detailVisitTab === 'returns'; }
    get detailOrdersTabCls() { return 'vm-tab' + (this.isDetailOrdersTab ? ' vm-tab-active' : ''); }
    get detailCollectionsTabCls() { return 'vm-tab' + (this.isDetailCollectionsTab ? ' vm-tab-active' : ''); }
    get detailReturnsTabCls() { return 'vm-tab' + (this.isDetailReturnsTab ? ' vm-tab-active' : ''); }

    // ═══════════════════════════════════════════════════
    // CHECKOUT
    // ═══════════════════════════════════════════════════
    get checkoutDisabled() {
        return this.isProcessing || (!this.isProductive && !this.nonProductiveReason) ||
            !this._checklistComplete;
    }

    get _checklistComplete() {
        if (this.checklistItems.length === 0) return true;
        return this.checklistItems.every(c => c.answer != null);
    }

    get nonProductiveReasonOptions() {
        return [
            { label: 'Shop Closed', value: 'Shop Closed' },
            { label: 'Owner Not Available', value: 'Owner Not Available' },
            { label: 'No Demand', value: 'No Demand' },
            { label: 'Credit Limit Exceeded', value: 'Credit Limit Exceeded' },
            { label: 'Stock Available', value: 'Stock Available' },
            { label: 'Other', value: 'Other' }
        ];
    }

    handleCheckoutClick() {
        this.checklistItems = [
            { id: 'stock', label: 'Was stock check completed?', answer: null, yesClass: 'vm-yn-btn', noClass: 'vm-yn-btn' },
            { id: 'display', label: 'Was product display verified?', answer: null, yesClass: 'vm-yn-btn', noClass: 'vm-yn-btn' },
            { id: 'feedback', label: 'Was retailer feedback captured?', answer: null, yesClass: 'vm-yn-btn', noClass: 'vm-yn-btn' },
            { id: 'scheme', label: 'Was scheme communication done?', answer: null, yesClass: 'vm-yn-btn', noClass: 'vm-yn-btn' }
        ];
        const hasOrders = this.activeOrdersCount > 0;
        const hasCollections = (this.activeVisitSummary.collectionsCount || 0) > 0;
        const hasReturns = (this.activeVisitSummary.returnsCount || 0) > 0;
        const hasAnyActivity = hasOrders || hasCollections || hasReturns;
        this.isProductive = hasAnyActivity;
        this.nonProductiveReason = '';
        this.visitNotes = '';
        this.showCheckoutModal = true;
    }

    handleCheckoutClose() { this.showCheckoutModal = false; }

    handleChecklistAnswer(e) {
        const id = e.currentTarget.dataset.id;
        const answer = e.currentTarget.dataset.answer;
        this.checklistItems = this.checklistItems.map(c => {
            if (c.id === id) {
                return {
                    ...c,
                    answer,
                    yesClass: answer === 'yes' ? 'vm-yn-btn vm-yn-yes-active' : 'vm-yn-btn',
                    noClass: answer === 'no' ? 'vm-yn-btn vm-yn-no-active' : 'vm-yn-btn'
                };
            }
            return c;
        });
    }

    handleProductiveChange(e) {
        this.isProductive = e.target.checked;
        if (this.isProductive) this.nonProductiveReason = '';
    }

    handleNonProductiveReasonChange(e) { this.nonProductiveReason = e.detail.value; }
    handleVisitNotesChange(e) { this.visitNotes = e.detail.value; }

    async handleCheckoutConfirm() {
        if (this.checkoutDisabled) return;
        this.isProcessing = true;
        try {
            const pos = await this._captureLocationAsync();
            const completedActs = this.checklistItems
                .filter(c => c.answer != null)
                .map(c => c.label.replace(/^Was\s+/i, '').replace(/\?$/, '') + ': ' + (c.answer === 'yes' ? 'Yes' : 'No'))
                .join(', ');

            const data = {
                visitId: this.activeVisit.Id,
                latitude: pos.latitude, longitude: pos.longitude, accuracy: pos.accuracy,
                isProductive: this.isProductive,
                nonProductiveReason: this.nonProductiveReason,
                notes: this.visitNotes,
                completedActivities: completedActs
            };

            await checkOutVisitApex({ visitJson: JSON.stringify(data) });
            this._toast('Success', 'Visit completed!', 'success');
            this._stopVisitTimer();
            this.showCheckoutModal = false;
            this.activeVisit = null;
            this.activeVisitSummary = {};
            this.activeVisitTab = 'activities';
            await this._refreshAllData();
            this.currentScreen = SCREEN.VISIT_BOARD;
        } catch (err) {
            this._toast('Error', 'Checkout failed: ' + this._err(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ═══════════════════════════════════════════════════
    // SKIP VISIT (mandatory reason)
    // ═══════════════════════════════════════════════════
    get skipReasonOptions() {
        return [
            { label: 'Shop Closed', value: 'Shop Closed' },
            { label: 'Owner Not Available', value: 'Owner Not Available' },
            { label: 'Road Blocked / Inaccessible', value: 'Road Blocked' },
            { label: 'No Demand', value: 'No Demand' },
            { label: 'Other', value: 'Other' }
        ];
    }
    get skipDisabled() { return !this.skipReason || this.isProcessing; }

    handleSkipClick(e) {
        e.stopPropagation();
        this.skipVisitId = e.currentTarget.dataset.id;
        this.skipReason = '';
        this.showSkipModal = true;
    }

    handleSkipReasonChange(e) { this.skipReason = e.detail.value; }
    handleSkipClose() { this.showSkipModal = false; this.skipVisitId = null; }

    async handleSkipConfirm() {
        if (!this.skipReason || !this.skipVisitId) return;
        this.isProcessing = true;
        this.showSkipModal = false;
        try {
            const isPlanned = String(this.skipVisitId).startsWith('planned_');
            if (isPlanned) {
                // Planned visits have synthetic IDs: planned_<accountId>_<index>
                const visit = this.allVisits.find(v => v.Id === this.skipVisitId);
                if (!visit) throw new Error('Visit not found.');
                await skipPlannedVisitApex({
                    accountId: visit.Account__c,
                    beatId: visit.Beat__c,
                    attendanceId: this.dayAttendance.Id,
                    skipReason: this.skipReason
                });
            } else {
                await skipVisitApex({ visitId: this.skipVisitId, skipReason: this.skipReason });
            }
            this._toast('Success', 'Visit skipped.', 'success');
            this.allVisits = this.allVisits.map(v =>
                v.Id === this.skipVisitId ? { ...v, Visit_Status__c: VISIT_STATUS.SKIPPED } : v
            );
            await this._refreshAllData();
        } catch (err) {
            this._toast('Error', 'Failed to skip: ' + this._err(err), 'error');
        } finally {
            this.isProcessing = false;
            this.skipVisitId = null;
        }
    }

    // ═══════════════════════════════════════════════════
    // SWITCH BEAT (mandatory reason)
    // ═══════════════════════════════════════════════════
    get switchBeatReasonOptions() {
        return [
            { label: 'Manager Instruction', value: 'Manager Instruction' },
            { label: 'Customer Emergency', value: 'Customer Emergency' },
            { label: 'Route Issue / Road Block', value: 'Route Issue' },
            { label: 'Beat Completed Early', value: 'Beat Completed Early' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get availableBeatsForSwitch() {
        return this.todaysBeats.filter(b => b.beatId !== this.activeBeatId).map(b => ({
            ...b,
            switchCardClass: b.beatId === this.switchBeatId ? 'vm-beat-card vm-beat-selected' : 'vm-beat-card'
        }));
    }

    get switchBeatDisabled() {
        return !this.switchBeatId || !this.switchBeatReason || this.isProcessing;
    }

    handleSwitchBeatClick() {
        if (this.activeVisits.length > 0) {
            this._toast('Warning', 'Complete the current active visit before switching beats.', 'warning');
            return;
        }
        this.switchBeatId = null;
        this.switchBeatReason = '';
        this.showSwitchBeatModal = true;
    }

    handleSwitchBeatSelect(e) {
        this.switchBeatId = e.currentTarget.dataset.beatId;
    }

    handleSwitchBeatReasonChange(e) { this.switchBeatReason = e.detail.value; }
    handleSwitchBeatClose() { this.showSwitchBeatModal = false; }

    async handleSwitchBeatConfirm() {
        if (this.switchBeatDisabled) return;
        this.isProcessing = true;
        this.showSwitchBeatModal = false;
        try {
            const result = await switchBeatApex({
                attendanceId: this.dayAttendance.Id,
                newBeatId: this.switchBeatId,
                reason: this.switchBeatReason
            });
            this.dayAttendance = result;
            this.activeBeatId = this.switchBeatId;

            await this._refreshAllData();
            this.boardTab = 'planned';
            const beatObj = this.todaysBeats.find(b => b.beatId === this.switchBeatId);
            this._toast('Success', 'Switched to ' + (beatObj ? beatObj.beatName : 'new beat'), 'success');
        } catch (err) {
            this._toast('Error', 'Failed to switch beat: ' + this._err(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ═══════════════════════════════════════════════════
    // AD-HOC VISIT
    // ═══════════════════════════════════════════════════
    get adHocReasonOptions() {
        return [
            { label: 'New Outlet', value: 'New Outlet' },
            { label: 'Manager Request', value: 'Manager Request' },
            { label: 'Customer Request', value: 'Customer Request' },
            { label: 'Nearby Outlet', value: 'Nearby Outlet' },
            { label: 'Other', value: 'Other' }
        ];
    }
    get adHocSubmitDisabled() { return !this.adHocSelectedAccount || this.isProcessing; }

    handleAdHocClick() {
        this.adHocSearchTerm = '';
        this.adHocSearchResults = [];
        this.adHocSelectedAccount = null;
        this.adHocReason = '';
        this.showAdHocDropdown = false;
        this.showAdHocModal = true;
    }

    handleAdHocSearch(e) {
        const term = e.detail.value || '';
        this.adHocSearchTerm = term;
        if (this._searchTimer) clearTimeout(this._searchTimer);
        if (term.length < 2) { this.adHocSearchResults = []; this.showAdHocDropdown = false; return; }
        this._searchTimer = setTimeout(() => this._doOutletSearch(term), 300);
    }

    async _doOutletSearch(term) {
        try {
            const results = await searchOutletsApex({ searchTerm: term });
            this.adHocSearchResults = (results || []).map(a => ({
                id: a.Id, name: a.Name,
                address: [a.BillingStreet, a.BillingCity].filter(Boolean).join(', ') || 'No address',
                code: a.Customer_Code__c || a.AccountNumber || ''
            }));
            this.showAdHocDropdown = this.adHocSearchResults.length > 0;
        } catch (err) {
            this._toast('Error', 'Search failed: ' + this._err(err), 'error');
        }
    }

    handleAdHocSelect(e) {
        const sel = this.adHocSearchResults.find(a => a.id === e.currentTarget.dataset.id);
        if (sel) {
            this.adHocSelectedAccount = sel;
            this.adHocSearchTerm = sel.name;
            this.showAdHocDropdown = false;
        }
    }

    handleAdHocReasonChange(e) { this.adHocReason = e.detail.value; }
    handleAdHocClose() { this.showAdHocModal = false; }

    async handleAdHocConfirm() {
        if (!this.adHocSelectedAccount) return;
        if (this.activeVisits.length > 0) {
            this._toast('Warning', 'Complete the current active visit first.', 'warning');
            return;
        }
        this.isProcessing = true;
        this.showAdHocModal = false;
        try {
            const pos = await this._captureLocationAsync();
            const data = {
                accountId: this.adHocSelectedAccount.id,
                dayAttendanceId: this.dayAttendance.Id,
                beatId: this.activeBeatId,
                latitude: pos.latitude, longitude: pos.longitude, accuracy: pos.accuracy,
                batteryLevel: this.batteryLevel,
                networkStatus: this.networkStatus,
                isPlanned: false,
                adHocReason: this.adHocReason || 'Ad-hoc visit'
            };

            const visit = await checkInVisitApex({ visitJson: JSON.stringify(data) });
            this._toast('Success', 'Ad-hoc visit started for ' + this.adHocSelectedAccount.name, 'success');
            this.activeVisit = visit;
            await this._loadActiveVisitData(visit.Id, this.adHocSelectedAccount.id);
            this._startVisitTimer();
            this.currentScreen = SCREEN.VISIT_ACTIVE;
            await this._refreshAllData();
        } catch (err) {
            this._toast('Error', 'Ad-hoc visit failed: ' + this._err(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ═══════════════════════════════════════════════════
    // DAY END
    // ═══════════════════════════════════════════════════
    handleEndDayClick() {
        if (this.activeVisits.length > 0) {
            this._toast('Warning', 'Complete all active visits before ending the day.', 'warning');
            return;
        }
        this.odometerEnd = null;
        this.endDayRemarks = '';
        this._endSelfieBase64 = null;
        this.endSelfiePreview = null;
        this.showEndDayModal = true;
    }

    handleEndDayClose() { this.showEndDayModal = false; }
    handleOdometerEndChange(e) { this.odometerEnd = e.detail.value ? Number(e.detail.value) : null; }
    handleEndRemarksChange(e) { this.endDayRemarks = e.detail.value; }


    handleEndSelfieCapture(e) {
        this._processPhoto(e, (base64, preview) => {
            this._endSelfieBase64 = base64;
            this.endSelfiePreview = preview;
        });
    }

    removeEndSelfie() { this._endSelfieBase64 = null; this.endSelfiePreview = null; }

    async handleEndDayConfirm() {
        this.isProcessing = true;
        try {
            const pos = await this._captureLocationAsync();
            const data = {
                attendanceId: this.dayAttendance.Id,
                endLatitude: pos.latitude,
                endLongitude: pos.longitude,
                endAccuracy: pos.accuracy,
                selfieBase64: this._endSelfieBase64 || '',
                remarks: this.endDayRemarks || '',
                odometerEnd: this.odometerEnd || 0
            };

            await endDayApex({ dayJson: JSON.stringify(data) });
            this._toast('Success', 'Day ended successfully!', 'success');
            this.showEndDayModal = false;
            this._stopAllIntervals();
            this.dayAttendance = null;
            this.dayStats = {};
            this.allVisits = [];
            this.activeBeatId = null;
            this.selectedBeatId = null;
            this.currentScreen = SCREEN.DAY_START;
        } catch (err) {
            this._toast('Error', 'Failed to end day: ' + this._err(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ═══════════════════════════════════════════════════
    // REFRESH & INTERVALS
    // ═══════════════════════════════════════════════════
    async _refreshAllData() {
        try {
            const data = await refreshDayData();
            if (data) {
                this.dayStats = data.dayStats || {};
                if (data.currentBeatId) {
                    this.activeBeatId = data.currentBeatId;
                }
                if (data.todaysVisits || data.plannedVisits) {
                    this._processVisits(data.todaysVisits || [], data.plannedVisits || []);
                }
                if (data.hasActiveVisit && data.activeVisit) {
                    this.activeVisit = data.activeVisit;
                    this.activeVisitSummary = data.activeVisitSummary || {};
                }
            }
        } catch (e) { /* ignore */ }
    }

    async handleBoardRefresh() {
        this.isProcessing = true;
        try {
            await this._refreshAllData();
            if (this.activeVisits.length > 0 && this.currentScreen === SCREEN.VISIT_BOARD) {
                const av = this.activeVisits[0];
                if (av && av.Id && !av.Id.startsWith('planned_')) {
                    this.activeVisit = av;
                    await this._loadActiveVisitData(av.Id, av.Account__c);
                    this._startVisitTimer();
                    this.currentScreen = SCREEN.VISIT_ACTIVE;
                }
            }
        } catch (e) { /* ignore */ }
        this.isProcessing = false;
    }

    _startStatsRefresh() {
        if (this._statsInterval) clearInterval(this._statsInterval);
        const interval = this.config.statsRefreshInterval || 60000;
        this._statsInterval = setInterval(() => this._refreshAllData(), interval);
    }

    _stopAllIntervals() {
        if (this._statsInterval) { clearInterval(this._statsInterval); this._statsInterval = null; }
        this._stopVisitTimer();
    }

    // ═══════════════════════════════════════════════════
    // PHOTO HELPER
    // ═══════════════════════════════════════════════════
    _processPhoto(event, callback) {
        const file = event.target.files[0];
        if (!file) return;
        if (file.size > 5 * 1024 * 1024) {
            this._toast('Error', 'Photo must be less than 5MB.', 'error');
            return;
        }
        const reader = new FileReader();
        reader.onload = () => {
            const base64 = reader.result.split(',')[1];
            callback(base64, reader.result);
        };
        reader.readAsDataURL(file);
    }

    // ═══════════════════════════════════════════════════
    // UTILITIES
    // ═══════════════════════════════════════════════════
    _fmtTime(dt) {
        if (!dt) return '--';
        try {
            return new Date(dt).toLocaleTimeString('en-IN', {
                hour: '2-digit', minute: '2-digit', hour12: true
            });
        } catch (e) { return '--'; }
    }

    _fmtDuration(mins) {
        if (!mins && mins !== 0) return '--';
        const h = Math.floor(mins / 60);
        const m = Math.round(mins % 60);
        return h > 0 ? `${h}h ${m}m` : `${m} min`;
    }

    _pad(n) { return n < 10 ? '0' + n : '' + n; }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _err(error) {
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'Unknown error';
    }
}
