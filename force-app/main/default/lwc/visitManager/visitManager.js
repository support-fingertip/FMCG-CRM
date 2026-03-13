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
import getVisitActivitiesApex from '@salesforce/apex/VisitManagerController.getVisitActivities';

// ── VISIT ACTIVITY IMPORTS ──
import getDistributorStock from '@salesforce/apex/OVE_StockCheckController.getDistributorStock';
import getProductsForStockCheck from '@salesforce/apex/OVE_StockCheckController.getProductsForStockCheck';
import saveStockEntries from '@salesforce/apex/OVE_StockCheckController.saveStockEntries';
import getCompetitorEntriesForVisit from '@salesforce/apex/OVE_CompetitorActivityController.getCompetitorEntriesForVisit';
import getCompetitorMaster from '@salesforce/apex/OVE_CompetitorActivityController.getCompetitorMaster';
import saveCompetitorEntry from '@salesforce/apex/OVE_CompetitorActivityController.saveCompetitorEntry';
import deleteCompetitorEntry from '@salesforce/apex/OVE_CompetitorActivityController.deleteCompetitorEntry';
import getMerchandisingForVisit from '@salesforce/apex/OVE_MerchandisingController.getMerchandisingForVisit';
import saveMerchandising from '@salesforce/apex/OVE_MerchandisingController.saveMerchandising';
import getApplicableSurveys from '@salesforce/apex/OVE_SurveyController.getApplicableSurveys';
import getSurveyWithQuestions from '@salesforce/apex/OVE_SurveyController.getSurveyWithQuestions';
import submitSurveyResponse from '@salesforce/apex/OVE_SurveyController.submitSurveyResponse';
import getSurveyResponsesForVisit from '@salesforce/apex/OVE_SurveyController.getSurveyResponsesForVisit';
import uploadSurveyPhoto from '@salesforce/apex/OVE_SurveyController.uploadSurveyPhoto';
import getActiveSchemes from '@salesforce/apex/OVE_SchemeInfoController.getActiveSchemes';
import getTicketsForVisit from '@salesforce/apex/OVE_TicketController.getTicketsForVisit';
import createTicket from '@salesforce/apex/OVE_TicketController.createTicket';

// ── SCREEN STATES ──
const SCREEN = {
    LOADING: 'loading',
    DAY_START: 'day_start',
    BEAT_SELECT: 'beat_select',
    VISIT_BOARD: 'visit_board',
    VISIT_ACTIVE: 'visit_active',
    VISIT_ACTIVITY: 'visit_activity',
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
    @track dutyType = 'HQ';
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
    @track detailSurveyResponses = [];

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

    // ── VISIT ACTIVITY (inline forms) ──
    @track activeActivityId = null;
    // Stock Check
    @track stockCheckLines = [];
    @track stockProductSearch = '';
    @track stockProductResults = [];
    @track stockIsLoading = false;
    // Competitor
    @track competitorEntries = [];
    @track competitorCompanies = [];
    @track competitorFilteredCompanies = [];
    @track competitorShowSuggestions = false;
    @track competitorForm = { competitorCompany: '', competitorSKU: '', competitorPrice: null, ownProductId: null, ownProductName: '', notes: '' };
    @track competitorIsLoading = false;
    @track competitorProductSearch = '';
    @track competitorProductResults = [];
    @track competitorShowProductSearch = false;
    // Merchandising
    @track merchandisingRecord = { ownShelfShare: null, competitorShelfShare: null, planogramCompliant: false, posmPresent: false, posmCondition: '', notes: '' };
    @track merchandisingIsLoading = false;
    // Survey
    @track applicableSurveys = [];
    @track selectedSurvey = null;
    @track surveyQuestions = [];
    @track surveyAnswers = {};
    @track surveyIsLoading = false;
    // Scheme
    @track activeSchemesList = [];
    @track schemeIsLoading = false;
    // Ticket
    @track visitTickets = [];
    @track ticketForm = { category: '', priority: 'Medium', subject: '', description: '' };
    @track ticketIsLoading = false;

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
    get isVisitActivityScreen() { return this.currentScreen === SCREEN.VISIT_ACTIVITY; }
    get isVisitDetailScreen() { return this.currentScreen === SCREEN.VISIT_DETAIL; }

    // ── Activity type getters ──
    get isStockCheckActivity() { return this.activeActivityId === 'stock_check'; }
    get isCompetitorActivity() { return this.activeActivityId === 'competitor'; }
    get isMerchandisingActivity() { return this.activeActivityId === 'merchandising'; }
    get isSurveyActivity() { return this.activeActivityId === 'survey'; }
    get isSchemeActivity() { return this.activeActivityId === 'scheme'; }
    get isTicketActivity() { return this.activeActivityId === 'ticket'; }
    get isOrderActivity() { return this.activeActivityId === 'order'; }
    get isCollectionActivity() { return this.activeActivityId === 'collection'; }
    get isReturnsActivity() { return this.activeActivityId === 'returns'; }
    get activeActivityTitle() {
        const titles = {
            stock_check: 'Distributor Stock', competitor: 'Competitor Activity', merchandising: 'Merchandising Audit',
            survey: 'Survey / Feedback', scheme: 'Scheme Info', ticket: 'Ticket / Complaint',
            order: 'Order Entry', collection: 'Collection', returns: 'Returns'
        };
        return titles[this.activeActivityId] || 'Activity';
    }
    get activeAccountId() { return this.activeVisit ? this.activeVisit.Account__c : null; }
    get activeVisitId() { return this.activeVisit ? this.activeVisit.Id : null; }

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

    get dutyTypeOptions() {
        return [
            { label: 'HQ', value: 'HQ' },
            { label: 'EX-HQ', value: 'EX-HQ' },
            { label: 'OS', value: 'OS' }
        ];
    }

    handleDutyTypeChange(e) { this.dutyType = e.detail.value; }

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
                dutyType: this.dutyType || 'HQ',
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
        const rawId = e.currentTarget.dataset.id || null;
        const existingVisitId = (rawId && rawId.startsWith('planned_')) ? null : rawId;

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
            const visitId = this.activeVisitId || null;
            const activities = await getVisitActivitiesApex({ visitId });
            if (activities && activities.length > 0) {
                this.visitActivities = this._processActivities(activities);
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

    handleActivityClick(e) {
        const id = e.currentTarget.dataset.id;
        this.activeActivityId = id;
        this.currentScreen = SCREEN.VISIT_ACTIVITY;
        this._loadActivityData(id);
    }

    handleActivityBack() {
        this.activeActivityId = null;
        this.currentScreen = SCREEN.VISIT_ACTIVE;
        this.handleRefreshVisitSummary();
        this._loadActivitiesData();
    }

    handleActivityFormSuccess() {
        this._toast('Success', 'Activity completed successfully.', 'success');
        this.handleActivityBack();
    }

    async _loadActivityData(activityId) {
        try {
            switch (activityId) {
                case 'stock_check': await this._loadStockCheckData(); break;
                case 'competitor': await this._loadCompetitorData(); break;
                case 'merchandising': await this._loadMerchandisingData(); break;
                case 'survey': await this._loadSurveyData(); break;
                case 'scheme': await this._loadSchemeData(); break;
                case 'ticket': await this._loadTicketData(); break;
                default: break;
            }
        } catch (err) {
            console.error('Error loading activity data:', err);
        }
    }

    // ── Stock Check ──
    async _loadStockCheckData() {
        this.stockIsLoading = true;
        this.stockProductSearch = '';
        this.stockProductResults = [];
        try {
            const stock = await getDistributorStock({ accountId: this.activeAccountId });
            this.stockCheckLines = (stock || []).map((s, idx) => ({
                ...s, lineKey: s.Id || ('new-' + idx),
                productName: s.Product_Ext__r ? s.Product_Ext__r.Name : '',
                opening: s.Opening_Stock__c || 0, received: s.Received_Qty__c || 0,
                sold: s.Sold_Qty__c || 0, closing: s.Closing_Stock__c || 0,
                damaged: s.Damaged_Qty__c || 0, batch: s.Batch_No__c || '',
                expiry: s.Expiry_Date__c || null
            }));
        } catch (e) { this.stockCheckLines = []; }
        this.stockIsLoading = false;
    }

    handleStockProductSearch(e) {
        const term = e.target.value;
        this.stockProductSearch = term;
        clearTimeout(this._stockSearchTimer);
        if (term.length < 2) { this.stockProductResults = []; return; }
        this._stockSearchTimer = setTimeout(async () => {
            try {
                const results = await getProductsForStockCheck({ searchTerm: term });
                this.stockProductResults = results || [];
            } catch (err) { this.stockProductResults = []; }
        }, 300);
    }

    handleStockProductAdd(e) {
        const productId = e.currentTarget.dataset.id;
        const product = this.stockProductResults.find(p => p.Id === productId);
        if (!product) return;
        if (this.stockCheckLines.some(l => l.Product_Ext__c === productId)) {
            this._toast('Info', 'Product already added.', 'info'); return;
        }
        this.stockCheckLines = [...this.stockCheckLines, {
            lineKey: 'new-' + Date.now(), Product_Ext__c: productId,
            productName: product.Name, opening: 0, received: 0,
            sold: 0, closing: 0, damaged: 0, batch: '', expiry: null
        }];
        this.stockProductResults = [];
        this.stockProductSearch = '';
    }

    handleStockQuantityChange(e) {
        const field = e.target.dataset.field;
        const key = e.target.dataset.key;
        const numericFields = ['opening', 'received', 'sold', 'damaged'];
        const val = numericFields.includes(field) ? (parseFloat(e.target.value) || 0) : e.target.value;
        this.stockCheckLines = this.stockCheckLines.map(l => {
            if (l.lineKey === key) {
                const updated = { ...l, [field]: val };
                updated.closing = (updated.opening || 0) + (updated.received || 0) - (updated.sold || 0) - (updated.damaged || 0);
                return updated;
            }
            return l;
        });
    }

    handleStockLineRemove(e) {
        const key = e.currentTarget.dataset.key;
        this.stockCheckLines = this.stockCheckLines.filter(l => l.lineKey !== key);
    }

    async handleStockCheckSave() {
        if (this.stockCheckLines.length === 0) {
            this._toast('Warning', 'Please add at least one product.', 'warning'); return;
        }
        this.stockIsLoading = true;
        try {
            const entries = this.stockCheckLines.map(l => ({
                id: l.Id || null, productId: l.Product_Ext__c,
                opening: l.opening, received: l.received, sold: l.sold,
                closing: l.closing, damaged: l.damaged,
                batch: l.batch, expiry: l.expiry
            }));
            await saveStockEntries({
                stockJson: JSON.stringify(entries),
                visitId: this.activeVisitId, accountId: this.activeAccountId
            });
            this._toast('Success', 'Distributor stock saved.', 'success');
            this.handleActivityBack();
        } catch (err) {
            this._toast('Error', this._err(err), 'error');
        }
        this.stockIsLoading = false;
    }

    // ── Competitor Activity ──
    async _loadCompetitorData() {
        this.competitorIsLoading = true;
        try {
            const [entries, companies] = await Promise.all([
                getCompetitorEntriesForVisit({ visitId: this.activeVisitId }),
                getCompetitorMaster()
            ]);
            this.competitorEntries = entries || [];
            this.competitorCompanies = (companies || []).map(c => ({ label: c, value: c }));
        } catch (e) { this.competitorEntries = []; this.competitorCompanies = []; }
        this.competitorIsLoading = false;
        this.competitorForm = { competitorCompany: '', competitorSKU: '', competitorPrice: null, ownProductId: null, ownProductName: '', notes: '' };
        this.competitorProductSearch = '';
        this.competitorProductResults = [];
        this.competitorShowProductSearch = false;
    }

    handleCompetitorFormChange(e) {
        const field = e.target.dataset.field;
        const val = e.target.value;
        this.competitorForm = { ...this.competitorForm, [field]: val };
        if (field === 'competitorCompany') {
            if (val && val.length > 0 && this.competitorCompanies.length > 0) {
                const search = val.toLowerCase();
                this.competitorFilteredCompanies = this.competitorCompanies.filter(c => c.label.toLowerCase().includes(search));
                this.competitorShowSuggestions = this.competitorFilteredCompanies.length > 0;
            } else {
                this.competitorShowSuggestions = false;
                this.competitorFilteredCompanies = [];
            }
        }
    }

    handleCompetitorCompanyFocus() {
        if (this.competitorCompanies.length > 0) {
            this.competitorFilteredCompanies = this.competitorCompanies;
            this.competitorShowSuggestions = true;
        }
    }

    handleCompetitorCompanyBlur() {
        // Delay to allow click on suggestion
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.competitorShowSuggestions = false; }, 250);
    }

    handleCompetitorSuggestionClick(e) {
        const company = e.currentTarget.dataset.value;
        this.competitorForm = { ...this.competitorForm, competitorCompany: company };
        this.competitorShowSuggestions = false;
    }

    async handleCompetitorProductSearchChange(e) {
        const term = e.target.value;
        this.competitorProductSearch = term;
        if (term && term.length >= 2) {
            try {
                const results = await getProductsForStockCheck({ searchTerm: term });
                this.competitorProductResults = results || [];
                this.competitorShowProductSearch = this.competitorProductResults.length > 0;
            } catch (err) {
                this.competitorProductResults = [];
                this.competitorShowProductSearch = false;
            }
        } else {
            this.competitorProductResults = [];
            this.competitorShowProductSearch = false;
        }
    }

    handleCompetitorProductSelect(e) {
        const productId = e.currentTarget.dataset.id;
        const productName = e.currentTarget.dataset.name;
        this.competitorForm = { ...this.competitorForm, ownProductId: productId, ownProductName: productName };
        this.competitorProductSearch = '';
        this.competitorProductResults = [];
        this.competitorShowProductSearch = false;
    }

    handleCompetitorProductClear() {
        this.competitorForm = { ...this.competitorForm, ownProductId: null, ownProductName: '' };
        this.competitorProductSearch = '';
    }

    async handleCompetitorSave() {
        if (!this.competitorForm.competitorCompany) {
            this._toast('Warning', 'Please enter competitor company.', 'warning'); return;
        }
        this.competitorIsLoading = true;
        try {
            const entryData = {
                visitId: this.activeVisitId, accountId: this.activeAccountId,
                competitorCompany: this.competitorForm.competitorCompany,
                competitorSKU: this.competitorForm.competitorSKU,
                competitorPrice: this.competitorForm.competitorPrice ? parseFloat(this.competitorForm.competitorPrice) : null,
                ownProductId: this.competitorForm.ownProductId,
                notes: this.competitorForm.notes
            };
            await saveCompetitorEntry({ entryJson: JSON.stringify(entryData) });
            this._toast('Success', 'Competitor entry saved.', 'success');
            await this._loadCompetitorData();
        } catch (err) {
            this._toast('Error', this._err(err), 'error');
        }
        this.competitorIsLoading = false;
    }

    async handleCompetitorDelete(e) {
        const entryId = e.currentTarget.dataset.id;
        this.competitorIsLoading = true;
        try {
            await deleteCompetitorEntry({ entryId });
            this._toast('Success', 'Entry removed.', 'success');
            await this._loadCompetitorData();
        } catch (err) { this._toast('Error', this._err(err), 'error'); }
        this.competitorIsLoading = false;
    }

    // ── Merchandising Audit ──
    async _loadMerchandisingData() {
        this.merchandisingIsLoading = true;
        try {
            const merch = await getMerchandisingForVisit({ visitId: this.activeVisitId });
            if (merch) {
                this.merchandisingRecord = {
                    id: merch.Id,
                    ownShelfShare: merch.Own_Shelf_Share__c, competitorShelfShare: merch.Competitor_Shelf_Share__c,
                    planogramCompliant: merch.Planogram_Compliant__c || false,
                    posmPresent: merch.POSM_Present__c || false, posmCondition: merch.POSM_Condition__c || '',
                    notes: merch.Notes__c || ''
                };
            } else {
                this.merchandisingRecord = { ownShelfShare: null, competitorShelfShare: null, planogramCompliant: false, posmPresent: false, posmCondition: '', notes: '' };
            }
        } catch (e) {
            this.merchandisingRecord = { ownShelfShare: null, competitorShelfShare: null, planogramCompliant: false, posmPresent: false, posmCondition: '', notes: '' };
        }
        this.merchandisingIsLoading = false;
    }

    handleMerchandisingChange(e) {
        const field = e.target.dataset.field;
        let value = e.target.type === 'toggle' || e.target.type === 'checkbox' ? e.target.checked : e.target.value;
        this.merchandisingRecord = { ...this.merchandisingRecord, [field]: value };
    }

    async handleMerchandisingSave() {
        this.merchandisingIsLoading = true;
        try {
            const data = {
                id: this.merchandisingRecord.id || null,
                visitId: this.activeVisitId, accountId: this.activeAccountId,
                ownShelfShare: this.merchandisingRecord.ownShelfShare ? parseFloat(this.merchandisingRecord.ownShelfShare) : null,
                competitorShelfShare: this.merchandisingRecord.competitorShelfShare ? parseFloat(this.merchandisingRecord.competitorShelfShare) : null,
                planogramCompliant: this.merchandisingRecord.planogramCompliant,
                posmPresent: this.merchandisingRecord.posmPresent,
                posmCondition: this.merchandisingRecord.posmCondition,
                notes: this.merchandisingRecord.notes
            };
            await saveMerchandising({ merchandisingJson: JSON.stringify(data) });
            this._toast('Success', 'Merchandising audit saved.', 'success');
            this.handleActivityBack();
        } catch (err) {
            this._toast('Error', this._err(err), 'error');
        }
        this.merchandisingIsLoading = false;
    }

    // ── Survey / Feedback ──
    async _loadSurveyData() {
        this.surveyIsLoading = true;
        this.selectedSurvey = null;
        this.surveyQuestions = [];
        this.surveyAnswers = {};
        try {
            const surveys = await getApplicableSurveys({ accountId: this.activeAccountId });
            this.applicableSurveys = (surveys || []).map(s => ({ label: s.Name, value: s.Id, ...s }));
            if (this.applicableSurveys.length === 1) {
                await this._selectSurvey(this.applicableSurveys[0].Id);
            }
        } catch (e) { this.applicableSurveys = []; }
        this.surveyIsLoading = false;
    }

    async handleSurveySelect(e) {
        const surveyId = e.detail.value;
        await this._selectSurvey(surveyId);
    }

    async _selectSurvey(surveyId) {
        this.surveyIsLoading = true;
        try {
            const result = await getSurveyWithQuestions({ surveyId });
            this.selectedSurvey = result.survey;
            this.surveyQuestions = (result.questions || []).map(q => ({
                ...q,
                isText: q.Question_Type__c === 'Text',
                isNumber: q.Question_Type__c === 'Number',
                isRating: q.Question_Type__c === 'Rating',
                isSingleChoice: q.Question_Type__c === 'Single Choice',
                isMultipleChoice: q.Question_Type__c === 'Multiple Choice',
                isPhoto: q.Question_Type__c === 'Photo',
                isDate: q.Question_Type__c === 'Date',
                options: this._parseOptions(q.Options__c),
                selectedValue: '',
                selectedValues: [],
                ratingOptions: [1, 2, 3, 4, 5].map(n => ({ value: n, label: '' + n, cls: 'vm-star' }))
            }));
            this.surveyAnswers = {};
        } catch (e) { this.surveyQuestions = []; }
        this.surveyIsLoading = false;
    }

    handleAnswerChange(e) {
        const qId = e.target.dataset.questionId || e.currentTarget.dataset.questionId;
        const type = e.target.dataset.type || e.currentTarget.dataset.type;
        let value = e.target.value;
        if (type === 'rating') value = parseInt(e.currentTarget.dataset.value, 10);
        if (type === 'Multiple Choice') value = e.detail.value;
        this.surveyAnswers = { ...this.surveyAnswers, [qId]: { type, value } };
        if (type === 'rating' || type === 'Single Choice' || type === 'Multiple Choice') {
            this.surveyQuestions = this.surveyQuestions.map(q => {
                if (q.Id !== qId) return q;
                const updated = { ...q };
                if (type === 'rating') {
                    updated.ratingOptions = q.ratingOptions.map(r => ({
                        ...r, cls: r.value <= value ? 'vm-star vm-star-filled' : 'vm-star'
                    }));
                } else if (type === 'Single Choice') {
                    updated.selectedValue = value;
                } else if (type === 'Multiple Choice') {
                    updated.selectedValues = value;
                }
                return updated;
            });
        }
    }

    handleSurveyPhotoUpload(e) {
        const qId = e.target.dataset.questionId;
        this._processPhoto(e, async (base64, preview) => {
            // Show uploading state and preview
            this.surveyQuestions = this.surveyQuestions.map(q =>
                q.Id === qId ? { ...q, photoUploading: true, photoPreview: preview } : q
            );
            try {
                const fileName = 'SurveyPhoto_' + qId + '_' + Date.now();
                const photoURL = await uploadSurveyPhoto({ base64Data: base64, fileName });
                this.surveyAnswers = { ...this.surveyAnswers, [qId]: { type: 'Photo', value: photoURL } };
                this.surveyQuestions = this.surveyQuestions.map(q =>
                    q.Id === qId ? { ...q, photoUploading: false } : q
                );
            } catch (err) {
                this._toast('Error', 'Failed to upload photo.', 'error');
                this.surveyQuestions = this.surveyQuestions.map(q =>
                    q.Id === qId ? { ...q, photoUploading: false, photoPreview: null } : q
                );
            }
        });
    }

    async handleSurveySubmit() {
        // Validate required questions
        const unanswered = this.surveyQuestions
            .filter(q => q.Is_Required__c)
            .filter(q => {
                const ans = this.surveyAnswers[q.Id];
                if (!ans) return true;
                const v = ans.value;
                if (v == null || v === '') return true;
                if (Array.isArray(v) && v.length === 0) return true;
                return false;
            });
        if (unanswered.length > 0) {
            this._toast('Required', 'Please answer all mandatory questions marked with *.', 'error');
            return;
        }

        this.surveyIsLoading = true;
        try {
            const answers = Object.entries(this.surveyAnswers).map(([qId, ans]) => ({
                questionId: qId,
                answerText: (ans.type === 'Text' || ans.type === 'Date') ? ans.value : null,
                answerChoice: (ans.type === 'Single Choice' || ans.type === 'Multiple Choice') ? (Array.isArray(ans.value) ? ans.value.join(';') : ans.value) : null,
                answerNumber: ans.type === 'Number' ? parseFloat(ans.value) : null,
                ratingValue: ans.type === 'rating' ? ans.value : null,
                photoURL: ans.type === 'Photo' ? ans.value : null
            }));
            const responseData = {
                visitId: this.activeVisitId, accountId: this.activeAccountId,
                surveyId: this.selectedSurvey.Id, answers
            };
            await submitSurveyResponse({ responseJson: JSON.stringify(responseData) });
            this._toast('Success', 'Survey submitted.', 'success');
            this.handleActivityBack();
        } catch (err) {
            this._toast('Error', this._err(err), 'error');
        }
        this.surveyIsLoading = false;
    }

    get surveyOptions() {
        return this.applicableSurveys.map(s => ({ label: s.label, value: s.value }));
    }

    get hasSurveyQuestions() { return this.surveyQuestions.length > 0; }
    get hasMultipleSurveys() { return this.applicableSurveys.length > 1; }

    _parseOptions(optionsRaw) {
        if (!optionsRaw) return [];
        const trimmed = optionsRaw.trim();
        // Support JSON array format: ["A","B"] or [{"label":"A","value":"a"}]
        if (trimmed.startsWith('[')) {
            try {
                const parsed = JSON.parse(trimmed);
                return parsed.map(item =>
                    typeof item === 'string'
                        ? { label: item, value: item }
                        : { label: item.label || item.value, value: item.value || item.label }
                ).filter(o => o.value);
            } catch (e) { /* fall through to semicolon split */ }
        }
        // Semicolon-separated format: "Yes;No;Partially"
        return trimmed.split(';').map(o => o.trim()).filter(o => o).map(o => ({ label: o, value: o }));
    }

    // ── Scheme Info ──
    async _loadSchemeData() {
        this.schemeIsLoading = true;
        try {
            this.activeSchemesList = await getActiveSchemes({ accountId: this.activeAccountId }) || [];
        } catch (e) { this.activeSchemesList = []; }
        this.schemeIsLoading = false;
    }

    get hasActiveSchemes() { return this.activeSchemesList.length > 0; }

    // ── Ticket / Complaint ──
    async _loadTicketData() {
        this.ticketIsLoading = true;
        try {
            this.visitTickets = await getTicketsForVisit({ visitId: this.activeVisitId }) || [];
        } catch (e) { this.visitTickets = []; }
        this.ticketIsLoading = false;
        this.ticketForm = { category: '', priority: 'Medium', subject: '', description: '' };
    }

    handleTicketFormChange(e) {
        const field = e.target.dataset.field;
        this.ticketForm = { ...this.ticketForm, [field]: e.target.value };
    }

    async handleTicketSave() {
        if (!this.ticketForm.subject) {
            this._toast('Warning', 'Please enter a subject.', 'warning'); return;
        }
        this.ticketIsLoading = true;
        try {
            const data = {
                visitId: this.activeVisitId, accountId: this.activeAccountId,
                category: this.ticketForm.category, priority: this.ticketForm.priority,
                subject: this.ticketForm.subject, description: this.ticketForm.description
            };
            await createTicket({ ticketJson: JSON.stringify(data) });
            this._toast('Success', 'Ticket created.', 'success');
            await this._loadTicketData();
        } catch (err) {
            this._toast('Error', this._err(err), 'error');
        }
        this.ticketIsLoading = false;
    }

    get hasVisitTickets() { return this.visitTickets.length > 0; }

    get ticketCategoryOptions() {
        return [
            { label: 'Product Quality', value: 'Product Quality' },
            { label: 'Delivery Issue', value: 'Delivery Issue' },
            { label: 'Pricing Dispute', value: 'Pricing Dispute' },
            { label: 'Service Request', value: 'Service Request' },
            { label: 'Scheme Claim', value: 'Scheme Claim' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get ticketPriorityOptions() {
        return [
            { label: 'Low', value: 'Low' },
            { label: 'Medium', value: 'Medium' },
            { label: 'High', value: 'High' },
            { label: 'Critical', value: 'Critical' }
        ];
    }

    get posmConditionOptions() {
        return [
            { label: 'Good', value: 'Good' },
            { label: 'Average', value: 'Average' },
            { label: 'Poor', value: 'Poor' },
            { label: 'Damaged', value: 'Damaged' },
            { label: 'Missing', value: 'Missing' }
        ];
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
        this.detailSurveyResponses = [];
        this.detailVisitTab = 'orders';
        this.currentScreen = SCREEN.VISIT_DETAIL;

        try {
            this.isProcessing = true;
            const [summary, surveyResp] = await Promise.all([
                refreshVisitSummary({ visitId }),
                getSurveyResponsesForVisit({ visitId }).catch(() => [])
            ]);
            this.detailVisitSummary = summary || {};
            this.detailSurveyResponses = (surveyResp || []).map(r => ({
                ...r,
                responseDateFmt: r.responseDate ? new Date(r.responseDate).toLocaleDateString() : '',
                answers: (r.answers || []).map(a => ({
                    ...a,
                    ratingStars: a.isRating ? this._buildRatingStars(a.ratingValue) : []
                }))
            }));
        } catch (err) {
            this._toast('Error', 'Failed to load visit details.', 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    handleBackToBoardFromDetail() {
        this.detailVisit = null;
        this.detailVisitSummary = {};
        this.detailSurveyResponses = [];
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
    get hasDetailSurveyResponses() { return this.detailSurveyResponses.length > 0; }

    // Detail tabs
    get isDetailOrdersTab() { return this.detailVisitTab === 'orders'; }
    get isDetailCollectionsTab() { return this.detailVisitTab === 'collections'; }
    get isDetailReturnsTab() { return this.detailVisitTab === 'returns'; }
    get isDetailSurveysTab() { return this.detailVisitTab === 'surveys'; }
    get detailOrdersTabCls() { return 'vm-tab' + (this.isDetailOrdersTab ? ' vm-tab-active' : ''); }
    get detailCollectionsTabCls() { return 'vm-tab' + (this.isDetailCollectionsTab ? ' vm-tab-active' : ''); }
    get detailReturnsTabCls() { return 'vm-tab' + (this.isDetailReturnsTab ? ' vm-tab-active' : ''); }
    get detailSurveysTabCls() { return 'vm-tab' + (this.isDetailSurveysTab ? ' vm-tab-active' : ''); }

    _buildRatingStars(value) {
        const v = value ? parseInt(value, 10) : 0;
        return [1, 2, 3, 4, 5].map(n => ({
            value: n,
            cls: n <= v ? 'vm-star vm-star-filled' : 'vm-star'
        }));
    }

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
            { id: 'stock', label: 'Was distributor stock captured?', answer: null, yesClass: 'vm-yn-btn', noClass: 'vm-yn-btn' },
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
