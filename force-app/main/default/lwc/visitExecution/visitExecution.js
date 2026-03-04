import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Id from '@salesforce/user/Id';

// Controller methods
import getDayContext from '@salesforce/apex/VisitExecutionController.getDayContext';
import switchBeat from '@salesforce/apex/VisitExecutionController.switchBeat';
import checkInFromSequence from '@salesforce/apex/VisitExecutionController.checkInFromSequence';
import checkOutVisit from '@salesforce/apex/VisitExecutionController.checkOutVisit';
import markVisitMissed from '@salesforce/apex/VisitExecutionController.markVisitMissed';
import rescheduleVisit from '@salesforce/apex/VisitExecutionController.rescheduleVisit';
import createAdHocVisit from '@salesforce/apex/VisitExecutionController.createAdHocVisit';
import skipPlannedVisit from '@salesforce/apex/VisitExecutionController.skipPlannedVisit';
import searchOutlets from '@salesforce/apex/VisitExecutionController.searchOutlets';

// Day attendance methods
import startDay from '@salesforce/apex/DayAttendanceController.startDay';
import endDay from '@salesforce/apex/DayAttendanceController.endDay';

const STATUS = {
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

const REFRESH_INTERVAL = 60000;

export default class VisitExecution extends NavigationMixin(LightningElement) {
    currentUserId = Id;

    // ── Day state ────────────────────────────────────────────
    @track isDayStarted = false;
    @track isLoading = true;
    @track isProcessing = false;
    @track dayAttendance = null;

    // ── Beat state ───────────────────────────────────────────
    @track currentBeat = null;
    @track isBeatSwitched = false;
    @track beatSwitchReason = '';
    @track availableBeats = [];

    // ── Outlets / Visits ─────────────────────────────────────
    @track outlets = [];
    @track todaysVisits = [];
    @track activeVisitId = null;
    @track activeVisitDuration = 0;

    // ── Summary stats ────────────────────────────────────────
    @track totalPlanned = 0;
    @track completedCount = 0;
    @track missedCount = 0;
    @track skippedCount = 0;
    @track pendingCount = 0;
    @track adHocCount = 0;

    // ── Config ───────────────────────────────────────────────
    @track config = {};

    // ── Modal state ──────────────────────────────────────────
    // Beat switch modal
    @track showBeatSwitchModal = false;
    @track selectedSwitchBeatId = '';
    @track selectedSwitchReason = '';
    @track switchNotes = '';

    // Missed visit modal
    @track showMissedModal = false;
    @track missedOutlet = null;
    @track selectedMissedReason = '';
    @track missedNotes = '';
    @track rescheduleDate = '';

    // Reschedule modal
    @track showRescheduleModal = false;
    @track rescheduleVisitId = null;
    @track newRescheduleDate = '';

    // Skip modal
    @track showSkipModal = false;
    @track skipOutlet = null;
    @track selectedSkipReason = '';

    // Ad-hoc modal
    @track showAdHocModal = false;
    @track adHocSearchTerm = '';
    @track adHocSearchResults = [];
    @track adHocSelectedAccount = null;
    @track adHocReason = '';
    @track showAdHocDropdown = false;

    // Check-out modal
    @track showCheckOutModal = false;
    @track checkOutVisitId = null;
    @track checkOutNotes = '';
    @track isCheckOutProductive = true;
    @track nonProductiveReason = '';

    // End day modal
    @track showEndDayModal = false;
    @track endDayRemarks = '';

    // ── Location ─────────────────────────────────────────────
    locationLatitude = null;
    locationLongitude = null;
    locationAccuracy = null;

    // ── Timers ───────────────────────────────────────────────
    _refreshInterval = null;
    _visitTimerInterval = null;
    _visitTimerStart = null;
    _adHocSearchTimer = null;

    // ══════════════════════════════════════════════════════════
    //  GETTERS
    // ══════════════════════════════════════════════════════════

    get beatDisplayName() {
        return this.currentBeat ? this.currentBeat.Name : 'No Beat Assigned';
    }

    get beatOutletCount() {
        return this.currentBeat ? (this.currentBeat.Total_Outlets__c || 0) : 0;
    }

    get progressPercent() {
        if (this.totalPlanned === 0) return 0;
        const handled = this.completedCount + this.missedCount + this.skippedCount;
        return Math.min(Math.round((handled / this.totalPlanned) * 100), 100);
    }

    get progressBarStyle() {
        const pct = this.progressPercent;
        let color = '#ea001e';
        if (pct >= 80) color = '#2e844a';
        else if (pct >= 50) color = '#dd7a01';
        return 'width:' + pct + '%;background-color:' + color;
    }

    get totalOrderValue() {
        return this.todaysVisits.reduce((sum, v) => sum + (v.Order_Value__c || 0), 0);
    }

    get totalOrderValueFormatted() {
        return INR.format(this.totalOrderValue);
    }

    get totalCollection() {
        return this.todaysVisits.reduce((sum, v) => sum + (v.Collection_Amount__c || 0), 0);
    }

    get totalCollectionFormatted() {
        return INR.format(this.totalCollection);
    }

    get dayStartTimeDisplay() {
        if (!this.dayAttendance || !this.dayAttendance.Day_Start_Time__c) return '--';
        return new Date(this.dayAttendance.Day_Start_Time__c).toLocaleTimeString('en-IN', {
            hour: '2-digit', minute: '2-digit', hour12: true
        });
    }

    get activeVisitDurationDisplay() {
        const h = Math.floor(this.activeVisitDuration / 3600);
        const m = Math.floor((this.activeVisitDuration % 3600) / 60);
        const s = this.activeVisitDuration % 60;
        return this._pad(h) + ':' + this._pad(m) + ':' + this._pad(s);
    }

    get hasActiveVisit() {
        return this.activeVisitId != null;
    }

    get isAdHocEnabled() {
        return this.config.adHocVisitsEnabled !== false;
    }

    get isSequenceEnforced() {
        return this.config.sequenceEnforced !== false;
    }

    // ── Processed outlet list with computed properties ────────
    get processedOutlets() {
        return this.outlets.map((outlet, idx) => {
            const isPlanned = outlet.visitStatus === STATUS.PLANNED;
            const isCheckedIn = outlet.visitStatus === STATUS.CHECKED_IN || outlet.visitStatus === STATUS.IN_PROGRESS;
            const isCompleted = outlet.visitStatus === STATUS.COMPLETED;
            const isMissed = outlet.visitStatus === STATUS.MISSED;
            const isSkipped = outlet.visitStatus === STATUS.SKIPPED;
            const isHandled = isCompleted || isMissed || isSkipped;

            // Determine if this is the next actionable outlet
            let isNextInSequence = false;
            if (isPlanned && !this.hasActiveVisit) {
                // Check if all prior outlets are handled
                const allPriorHandled = this.outlets.slice(0, idx).every(o =>
                    o.visitStatus === STATUS.COMPLETED ||
                    o.visitStatus === STATUS.MISSED ||
                    o.visitStatus === STATUS.SKIPPED ||
                    o.visitStatus === STATUS.CHECKED_IN ||
                    o.visitStatus === STATUS.IN_PROGRESS
                );
                isNextInSequence = allPriorHandled;
            }

            // Determine card class
            let cardClass = 'outlet-card';
            if (isCompleted) cardClass = 'outlet-card-completed';
            else if (isMissed) cardClass = 'outlet-card-missed';
            else if (isSkipped) cardClass = 'outlet-card-skipped';
            else if (isCheckedIn) cardClass = 'outlet-card-active';

            return {
                ...outlet,
                key: outlet.beatOutletId || outlet.accountId + '_' + idx,
                cardClass,
                isPlanned,
                isCheckedIn,
                isCompleted,
                isMissed,
                isSkipped,
                isHandled,
                isNextInSequence,
                canCheckIn: isPlanned && (isNextInSequence || !this.isSequenceEnforced) && !this.hasActiveVisit,
                canMarkMissed: isPlanned && !this.hasActiveVisit,
                canSkip: isPlanned && !this.hasActiveVisit,
                canCheckOut: isCheckedIn,
                canReschedule: isMissed && !outlet.rescheduleDate,
                statusLabel: this._getStatusLabel(outlet.visitStatus),
                statusClass: 'status-badge status-' + (outlet.visitStatus || 'planned').toLowerCase().replace(/ /g, '-'),
                sequenceDisplay: '#' + (outlet.sequence || (idx + 1)),
                checkInTimeDisplay: outlet.checkInTime
                    ? new Date(outlet.checkInTime).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
                    : '--',
                checkOutTimeDisplay: outlet.checkOutTime
                    ? new Date(outlet.checkOutTime).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
                    : '--',
                durationDisplay: outlet.durationMinutes ? Math.round(outlet.durationMinutes) + ' min' : '--',
                orderValueDisplay: outlet.orderValue ? INR.format(outlet.orderValue) : '',
                rescheduleDateDisplay: outlet.rescheduleDate
                    ? new Date(outlet.rescheduleDate).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })
                    : ''
            };
        });
    }

    // ── Beat switch options ──────────────────────────────────
    get beatSwitchOptions() {
        return this.availableBeats
            .filter(b => !this.currentBeat || b.Id !== this.currentBeat.Id)
            .map(b => ({
                label: b.Name + (b.Beat_Code__c ? ' (' + b.Beat_Code__c + ')' : '') +
                       ' - ' + (b.Total_Outlets__c || 0) + ' outlets',
                value: b.Id
            }));
    }

    get switchReasonOptions() {
        return [
            { label: 'Road Block', value: 'Road Block' },
            { label: 'Weather Conditions', value: 'Weather Conditions' },
            { label: 'Manager Instructions', value: 'Manager Instructions' },
            { label: 'Market Emergency', value: 'Market Emergency' },
            { label: 'Vehicle Issue', value: 'Vehicle Issue' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get missedReasonOptions() {
        return [
            { label: 'Shop Closed', value: 'Shop Closed' },
            { label: 'Owner Not Available', value: 'Owner Not Available' },
            { label: 'Access Issue', value: 'Access Issue' },
            { label: 'Weather Conditions', value: 'Weather Conditions' },
            { label: 'Vehicle Breakdown', value: 'Vehicle Breakdown' },
            { label: 'Time Constraint', value: 'Time Constraint' },
            { label: 'Emergency', value: 'Emergency' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get skipReasonOptions() {
        return [
            { label: 'Shop Closed', value: 'Shop Closed' },
            { label: 'Owner Not Available', value: 'Owner Not Available' },
            { label: 'Route Changed', value: 'Route Changed' },
            { label: 'Time Constraint', value: 'Time Constraint' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get adHocReasonOptions() {
        return [
            { label: 'New Outlet', value: 'New Outlet' },
            { label: 'Manager Request', value: 'Manager Request' },
            { label: 'Customer Request', value: 'Customer Request' },
            { label: 'Nearby Outlet', value: 'Nearby Outlet' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get nonProductiveReasonOptions() {
        return [
            { label: 'Shop Closed', value: 'Shop Closed' },
            { label: 'Owner Not Available', value: 'Owner Not Available' },
            { label: 'No Demand', value: 'No Demand' },
            { label: 'Credit Limit Exceeded', value: 'Credit Limit Exceeded' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get isSwitchDisabled() {
        return this.isProcessing || !this.selectedSwitchBeatId || !this.selectedSwitchReason;
    }

    get isMissedDisabled() {
        return this.isProcessing || !this.selectedMissedReason;
    }

    get isSkipDisabled() {
        return this.isProcessing || !this.selectedSkipReason;
    }

    get isRescheduleDisabled() {
        return this.isProcessing || !this.newRescheduleDate;
    }

    get isAdHocSubmitDisabled() {
        return this.isProcessing || !this.adHocSelectedAccount;
    }

    get isCheckOutDisabled() {
        return this.isProcessing;
    }

    get showNonProductiveField() {
        return !this.isCheckOutProductive;
    }

    get isDayNotStarted() {
        return !this.isLoading && !this.isDayStarted;
    }

    get noOutlets() {
        return this.outlets.length === 0;
    }

    get todayDateDisplay() {
        return new Date().toLocaleDateString('en-IN', {
            weekday: 'long', day: '2-digit', month: 'long', year: 'numeric'
        });
    }

    // ══════════════════════════════════════════════════════════
    //  LIFECYCLE
    // ══════════════════════════════════════════════════════════

    connectedCallback() {
        this._captureLocation();
        this._loadDayContext();
        this._refreshInterval = setInterval(() => {
            this._loadDayContext();
        }, REFRESH_INTERVAL);
    }

    disconnectedCallback() {
        if (this._refreshInterval) clearInterval(this._refreshInterval);
        this._stopVisitTimer();
    }

    // ══════════════════════════════════════════════════════════
    //  DATA LOADING
    // ══════════════════════════════════════════════════════════

    async _loadDayContext() {
        try {
            const ctx = await getDayContext();
            this.isDayStarted = ctx.isDayStarted;
            this.dayAttendance = ctx.dayAttendance;
            this.currentBeat = ctx.currentBeat;
            this.isBeatSwitched = ctx.isBeatSwitched;
            this.beatSwitchReason = ctx.beatSwitchReason || '';
            this.outlets = ctx.outlets || [];
            this.todaysVisits = ctx.todaysVisits || [];
            this.availableBeats = ctx.availableBeats || [];
            this.totalPlanned = ctx.totalPlanned || 0;
            this.completedCount = ctx.completedCount || 0;
            this.missedCount = ctx.missedCount || 0;
            this.skippedCount = ctx.skippedCount || 0;
            this.pendingCount = ctx.pendingCount || 0;
            this.adHocCount = ctx.adHocCount || 0;
            this.config = ctx.config || {};

            // Check for active check-in
            const activeVisit = this.todaysVisits.find(
                v => v.Visit_Status__c === STATUS.CHECKED_IN || v.Visit_Status__c === STATUS.IN_PROGRESS
            );
            if (activeVisit) {
                this.activeVisitId = activeVisit.Id;
                if (!this._visitTimerInterval) {
                    this._visitTimerStart = new Date(activeVisit.Check_In_Time__c);
                    this._startVisitTimer();
                }
            } else {
                this.activeVisitId = null;
                this._stopVisitTimer();
            }
        } catch (error) {
            this._toast('Error', 'Failed to load day context: ' + this._err(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ══════════════════════════════════════════════════════════
    //  DAY START / END
    // ══════════════════════════════════════════════════════════

    async handleStartDay() {
        this._captureLocation();
        this.isProcessing = true;
        try {
            const dayData = {
                startLatitude: this.locationLatitude || 0,
                startLongitude: this.locationLongitude || 0,
                startAccuracy: this.locationAccuracy || 0,
                batteryLevel: 0,
                networkStatus: navigator.onLine ? 'Online' : 'Offline',
                deviceInfo: navigator.platform || ''
            };
            await startDay({ dayJson: JSON.stringify(dayData) });
            this._toast('Success', 'Day started! Have a productive day!', 'success');
            await this._loadDayContext();
        } catch (error) {
            this._toast('Error', 'Failed to start day: ' + this._err(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    handleEndDayClick() {
        this.endDayRemarks = '';
        this.showEndDayModal = true;
    }

    closeEndDayModal() {
        this.showEndDayModal = false;
    }

    handleEndRemarksChange(event) {
        this.endDayRemarks = event.target.value;
    }

    async handleEndDay() {
        this.isProcessing = true;
        this.showEndDayModal = false;
        try {
            const endData = {
                attendanceId: this.dayAttendance.Id,
                endLatitude: this.locationLatitude || 0,
                endLongitude: this.locationLongitude || 0,
                endAccuracy: this.locationAccuracy || 0,
                remarks: this.endDayRemarks
            };
            await endDay({ dayJson: JSON.stringify(endData) });
            this._toast('Success', 'Day ended! Great work today!', 'success');
            await this._loadDayContext();
        } catch (error) {
            this._toast('Error', 'Failed to end day: ' + this._err(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ══════════════════════════════════════════════════════════
    //  BEAT SWITCHING
    // ══════════════════════════════════════════════════════════

    handleSwitchBeatClick() {
        this.selectedSwitchBeatId = '';
        this.selectedSwitchReason = '';
        this.switchNotes = '';
        this.showBeatSwitchModal = true;
    }

    closeBeatSwitchModal() {
        this.showBeatSwitchModal = false;
    }

    handleSwitchBeatChange(event) {
        this.selectedSwitchBeatId = event.detail.value;
    }

    handleSwitchReasonChange(event) {
        this.selectedSwitchReason = event.detail.value;
    }

    handleSwitchNotesChange(event) {
        this.switchNotes = event.target.value;
    }

    async handleSwitchBeatConfirm() {
        this.isProcessing = true;
        this.showBeatSwitchModal = false;
        try {
            await switchBeat({
                newBeatId: this.selectedSwitchBeatId,
                switchReason: this.selectedSwitchReason,
                switchNotes: this.switchNotes
            });
            this._toast('Success', 'Beat switched successfully.', 'success');
            await this._loadDayContext();
        } catch (error) {
            this._toast('Error', 'Failed to switch beat: ' + this._err(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ══════════════════════════════════════════════════════════
    //  CHECK-IN (Sequential)
    // ══════════════════════════════════════════════════════════

    async handleCheckIn(event) {
        const accountId = event.currentTarget.dataset.accountId;
        const beatId = event.currentTarget.dataset.beatId;

        this._captureLocation();
        this.isProcessing = true;
        try {
            const visitData = {
                accountId: accountId,
                beatId: beatId,
                latitude: this.locationLatitude || 0,
                longitude: this.locationLongitude || 0,
                accuracy: this.locationAccuracy || 0,
                isPlanned: true,
                batteryLevel: 0,
                networkStatus: navigator.onLine ? 'Online' : 'Offline'
            };
            const result = await checkInFromSequence({ visitJson: JSON.stringify(visitData) });
            this.activeVisitId = result.Id;
            this._visitTimerStart = new Date();
            this._startVisitTimer();
            this._toast('Success', 'Checked in successfully!', 'success');
            await this._loadDayContext();
        } catch (error) {
            this._toast('Error', 'Check-in failed: ' + this._err(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ══════════════════════════════════════════════════════════
    //  CHECK-OUT
    // ══════════════════════════════════════════════════════════

    handleCheckOutClick(event) {
        this.checkOutVisitId = event.currentTarget.dataset.visitId || this.activeVisitId;
        this.checkOutNotes = '';
        this.isCheckOutProductive = true;
        this.nonProductiveReason = '';
        this.showCheckOutModal = true;
    }

    closeCheckOutModal() {
        this.showCheckOutModal = false;
    }

    handleCheckOutNotesChange(event) {
        this.checkOutNotes = event.target.value;
    }

    handleProductiveToggle(event) {
        this.isCheckOutProductive = event.target.checked;
    }

    handleNonProductiveReasonChange(event) {
        this.nonProductiveReason = event.detail.value;
    }

    async handleCheckOutConfirm() {
        this.isProcessing = true;
        this.showCheckOutModal = false;
        try {
            this._captureLocation();
            const visitData = {
                visitId: this.checkOutVisitId,
                latitude: this.locationLatitude || 0,
                longitude: this.locationLongitude || 0,
                accuracy: this.locationAccuracy || 0,
                isProductive: this.isCheckOutProductive,
                nonProductiveReason: !this.isCheckOutProductive ? this.nonProductiveReason : null,
                notes: this.checkOutNotes
            };
            await checkOutVisit({ visitJson: JSON.stringify(visitData) });
            this._stopVisitTimer();
            this.activeVisitId = null;
            this._toast('Success', 'Checked out successfully!', 'success');
            await this._loadDayContext();
        } catch (error) {
            this._toast('Error', 'Check-out failed: ' + this._err(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ══════════════════════════════════════════════════════════
    //  MISSED VISIT
    // ══════════════════════════════════════════════════════════

    handleMissedClick(event) {
        const accountId = event.currentTarget.dataset.accountId;
        const outlet = this.outlets.find(o => o.accountId === accountId);
        this.missedOutlet = outlet;
        this.selectedMissedReason = '';
        this.missedNotes = '';
        this.rescheduleDate = '';
        this.showMissedModal = true;
    }

    closeMissedModal() {
        this.showMissedModal = false;
        this.missedOutlet = null;
    }

    handleMissedReasonChange(event) {
        this.selectedMissedReason = event.detail.value;
    }

    handleMissedNotesChange(event) {
        this.missedNotes = event.target.value;
    }

    handleRescheduleDateChange(event) {
        this.rescheduleDate = event.target.value;
    }

    async handleMissedConfirm() {
        if (!this.missedOutlet) return;
        this.isProcessing = true;
        this.showMissedModal = false;
        try {
            await markVisitMissed({
                accountId: this.missedOutlet.accountId,
                beatId: this.missedOutlet.beatId,
                missedReason: this.selectedMissedReason,
                missedNotes: this.missedNotes,
                rescheduleDate: this.rescheduleDate || null
            });
            const msg = this.rescheduleDate
                ? 'Visit marked as missed and rescheduled.'
                : 'Visit marked as missed.';
            this._toast('Success', msg, 'success');
            await this._loadDayContext();
        } catch (error) {
            this._toast('Error', 'Failed to mark visit: ' + this._err(error), 'error');
        } finally {
            this.isProcessing = false;
            this.missedOutlet = null;
        }
    }

    // ══════════════════════════════════════════════════════════
    //  RESCHEDULE
    // ══════════════════════════════════════════════════════════

    handleRescheduleClick(event) {
        this.rescheduleVisitId = event.currentTarget.dataset.visitId;
        this.newRescheduleDate = '';
        this.showRescheduleModal = true;
    }

    closeRescheduleModal() {
        this.showRescheduleModal = false;
    }

    handleNewRescheduleDateChange(event) {
        this.newRescheduleDate = event.target.value;
    }

    async handleRescheduleConfirm() {
        this.isProcessing = true;
        this.showRescheduleModal = false;
        try {
            await rescheduleVisit({
                visitId: this.rescheduleVisitId,
                rescheduleDate: this.newRescheduleDate
            });
            this._toast('Success', 'Visit rescheduled successfully.', 'success');
            await this._loadDayContext();
        } catch (error) {
            this._toast('Error', 'Reschedule failed: ' + this._err(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ══════════════════════════════════════════════════════════
    //  SKIP VISIT
    // ══════════════════════════════════════════════════════════

    handleSkipClick(event) {
        const accountId = event.currentTarget.dataset.accountId;
        this.skipOutlet = this.outlets.find(o => o.accountId === accountId);
        this.selectedSkipReason = '';
        this.showSkipModal = true;
    }

    closeSkipModal() {
        this.showSkipModal = false;
        this.skipOutlet = null;
    }

    handleSkipReasonChange(event) {
        this.selectedSkipReason = event.detail.value;
    }

    async handleSkipConfirm() {
        if (!this.skipOutlet) return;
        this.isProcessing = true;
        this.showSkipModal = false;
        try {
            await skipPlannedVisit({
                visitId: this.skipOutlet.visitId || null,
                accountId: this.skipOutlet.accountId,
                beatId: this.skipOutlet.beatId,
                skipReason: this.selectedSkipReason
            });
            this._toast('Success', 'Visit skipped.', 'success');
            await this._loadDayContext();
        } catch (error) {
            this._toast('Error', 'Skip failed: ' + this._err(error), 'error');
        } finally {
            this.isProcessing = false;
            this.skipOutlet = null;
        }
    }

    // ══════════════════════════════════════════════════════════
    //  AD-HOC VISIT
    // ══════════════════════════════════════════════════════════

    handleAdHocClick() {
        this.adHocSearchTerm = '';
        this.adHocSearchResults = [];
        this.adHocSelectedAccount = null;
        this.adHocReason = '';
        this.showAdHocDropdown = false;
        this.showAdHocModal = true;
    }

    closeAdHocModal() {
        this.showAdHocModal = false;
    }

    handleAdHocSearch(event) {
        const term = event.target.value;
        this.adHocSearchTerm = term;
        if (this._adHocSearchTimer) clearTimeout(this._adHocSearchTimer);
        if (!term || term.length < 2) {
            this.adHocSearchResults = [];
            this.showAdHocDropdown = false;
            return;
        }
        this._adHocSearchTimer = setTimeout(() => this._doAdHocSearch(term), 300);
    }

    async _doAdHocSearch(term) {
        try {
            const results = await searchOutlets({ searchTerm: term });
            this.adHocSearchResults = (results || []).map(a => ({
                id: a.Id, name: a.Name,
                address: [a.BillingStreet, a.BillingCity].filter(Boolean).join(', ') || 'No address'
            }));
            this.showAdHocDropdown = this.adHocSearchResults.length > 0;
        } catch (error) {
            this.adHocSearchResults = [];
            this.showAdHocDropdown = false;
        }
    }

    handleAdHocOutletSelect(event) {
        const sel = this.adHocSearchResults.find(a => a.id === event.currentTarget.dataset.id);
        if (sel) {
            this.adHocSelectedAccount = sel;
            this.adHocSearchTerm = sel.name;
            this.showAdHocDropdown = false;
        }
    }

    handleAdHocReasonChange(event) {
        this.adHocReason = event.detail.value;
    }

    async handleAdHocConfirm() {
        if (!this.adHocSelectedAccount) return;
        this.isProcessing = true;
        this.showAdHocModal = false;
        try {
            await createAdHocVisit({
                accountId: this.adHocSelectedAccount.id,
                adHocReason: this.adHocReason || 'Ad-hoc visit'
            });
            this._toast('Success', 'Ad-hoc visit created for ' + this.adHocSelectedAccount.name, 'success');
            await this._loadDayContext();
        } catch (error) {
            this._toast('Error', 'Ad-hoc visit failed: ' + this._err(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ══════════════════════════════════════════════════════════
    //  NAVIGATION
    // ══════════════════════════════════════════════════════════

    handleOutletClick(event) {
        if (event.target.closest('button') || event.target.closest('lightning-button') ||
            event.target.closest('lightning-button-icon')) return;
        const accountId = event.currentTarget.dataset.accountId;
        if (accountId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: accountId, objectApiName: 'Account', actionName: 'view' }
            });
        }
    }

    handleRefresh() {
        this.isLoading = true;
        this._loadDayContext();
    }

    // ══════════════════════════════════════════════════════════
    //  HELPERS
    // ══════════════════════════════════════════════════════════

    _captureLocation() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                pos => {
                    this.locationLatitude = pos.coords.latitude;
                    this.locationLongitude = pos.coords.longitude;
                    this.locationAccuracy = pos.coords.accuracy;
                },
                () => {},
                { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
            );
        }
    }

    _startVisitTimer() {
        this._stopVisitTimer();
        this._visitTimerInterval = setInterval(() => {
            if (this._visitTimerStart) {
                this.activeVisitDuration = Math.floor((Date.now() - this._visitTimerStart.getTime()) / 1000);
            }
        }, 1000);
    }

    _stopVisitTimer() {
        if (this._visitTimerInterval) {
            clearInterval(this._visitTimerInterval);
            this._visitTimerInterval = null;
        }
        this.activeVisitDuration = 0;
        this._visitTimerStart = null;
    }

    _getStatusLabel(status) {
        const labels = {
            'Planned': 'Planned',
            'Checked In': 'Checked In',
            'In Progress': 'In Progress',
            'Completed': 'Completed',
            'Skipped': 'Skipped',
            'Missed': 'Missed'
        };
        return labels[status] || status || 'Planned';
    }

    _pad(n) {
        return n < 10 ? '0' + n : '' + n;
    }

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
