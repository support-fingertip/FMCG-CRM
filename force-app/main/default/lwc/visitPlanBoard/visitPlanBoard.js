import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getTodaysVisits from '@salesforce/apex/VisitCheckInController.getTodaysVisits';
import getPlannedVisits from '@salesforce/apex/VisitCheckInController.getPlannedVisits';
import skipVisit from '@salesforce/apex/VisitCheckInController.skipVisit';
import getVisitConfig from '@salesforce/apex/VisitCheckInController.getVisitConfig';
import createVisit from '@salesforce/apex/VisitCheckInController.createVisit';
import searchOutlets from '@salesforce/apex/VisitCheckInController.searchOutlets';
import getCurrentDayAttendance from '@salesforce/apex/DayAttendanceController.getCurrentDayAttendance';

import Id from '@salesforce/user/Id';

const VISIT_STATUS = {
    PLANNED: 'Planned',
    CHECKED_IN: 'Checked-In',
    IN_PROGRESS: 'In-Progress',
    COMPLETED: 'Completed',
    SKIPPED: 'Skipped'
};

const AUTO_REFRESH_INTERVAL = 60000; // 60 seconds
const ADDRESS_TRUNCATE_LENGTH = 40;

const INR_FORMATTER = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
});

const INR_FORMATTER_DECIMAL = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
});

export default class VisitPlanBoard extends NavigationMixin(LightningElement) {
    currentUserId = Id;

    @track visits = [];
    @track plannedOutlets = [];
    @track visitConfig = {};
    @track isLoading = true;
    @track isSkipModalOpen = false;
    @track selectedSkipReason = '';
    @track skipVisitId = null;

    // Ad-hoc visit state
    @track isAdHocModalOpen = false;
    @track adHocSearchTerm = '';
    @track adHocSearchResults = [];
    @track adHocSelectedAccount = null;
    @track adHocReason = '';
    @track showAdHocDropdown = false;
    @track dayAttendanceId = null;

    refreshInterval = null;
    hasLoadedOnce = false;
    _adHocSearchTimer = null;

    // ----- Skip Reason Options -----
    get skipReasonOptions() {
        return [
            { label: 'Shop Closed', value: 'Shop Closed' },
            { label: 'Owner Not Available', value: 'Owner Not Available' },
            { label: 'No Demand', value: 'No Demand' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get isSkipDisabled() {
        return !this.selectedSkipReason;
    }

    // ----- Lifecycle -----
    connectedCallback() {
        this.loadAllData();
        this.startAutoRefresh();
    }

    disconnectedCallback() {
        this.stopAutoRefresh();
    }

    // ----- Data Loading -----
    async loadAllData() {
        this.isLoading = true;
        try {
            const [visitsResult, configResult, dayAttendance] = await Promise.all([
                getTodaysVisits({ userId: this.currentUserId }),
                getVisitConfig(),
                getCurrentDayAttendance({ userId: this.currentUserId })
            ]);

            this.visits = this.processVisits(visitsResult || []);
            this.visitConfig = configResult || {};
            this.dayAttendanceId = dayAttendance ? dayAttendance.Id : null;
            this.hasLoadedOnce = true;
        } catch (error) {
            this.showToast('Error', 'Failed to load visits: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async refreshVisits() {
        try {
            const visitsResult = await getTodaysVisits({ userId: this.currentUserId });
            this.visits = this.processVisits(visitsResult || []);
        } catch (error) {
            console.error('Auto-refresh failed:', error);
        }
    }

    // ----- Data Processing -----
    processVisits(rawVisits) {
        return rawVisits.map(visit => {
            const accountName = visit.Account__r ? visit.Account__r.Name : 'Unknown Outlet';
            const street = visit.Account__r ? (visit.Account__r.BillingStreet || '') : '';
            const city = visit.Account__r ? (visit.Account__r.BillingCity || '') : '';
            const fullAddress = [street, city].filter(Boolean).join(', ');
            const truncatedAddress = fullAddress.length > ADDRESS_TRUNCATE_LENGTH
                ? fullAddress.substring(0, ADDRESS_TRUNCATE_LENGTH) + '...'
                : fullAddress || 'No address';

            return {
                ...visit,
                outletName: accountName,
                fullAddress: fullAddress,
                truncatedAddress: truncatedAddress,
                checkInTimeDisplay: this.formatTime(visit.Check_In_Time__c),
                checkOutTimeDisplay: this.formatTime(visit.Check_Out_Time__c),
                durationDisplay: this.formatDuration(visit.Duration_Minutes__c),
                orderValueFormatted: this.formatCurrency(visit.Order_Value__c),
                collectionFormatted: this.formatCurrency(visit.Collection_Amount__c)
            };
        });
    }

    // ----- Computed: Column Lists -----
    get plannedVisits() {
        return this.visits
            .filter(v => v.Visit_Status__c === VISIT_STATUS.PLANNED)
            .sort((a, b) => (a.Visit_Sequence__c || 0) - (b.Visit_Sequence__c || 0));
    }

    get activeVisits() {
        return this.visits
            .filter(v =>
                v.Visit_Status__c === VISIT_STATUS.CHECKED_IN ||
                v.Visit_Status__c === VISIT_STATUS.IN_PROGRESS
            )
            .sort((a, b) => (a.Visit_Sequence__c || 0) - (b.Visit_Sequence__c || 0));
    }

    get completedVisits() {
        return this.visits
            .filter(v => v.Visit_Status__c === VISIT_STATUS.COMPLETED)
            .sort((a, b) => (a.Visit_Sequence__c || 0) - (b.Visit_Sequence__c || 0));
    }

    get skippedVisits() {
        return this.visits
            .filter(v => v.Visit_Status__c === VISIT_STATUS.SKIPPED)
            .sort((a, b) => (a.Visit_Sequence__c || 0) - (b.Visit_Sequence__c || 0));
    }

    // ----- Computed: Stats -----
    get totalVisitCount() {
        return this.visits.length;
    }

    get completedCount() {
        return this.completedVisits.length;
    }

    get productivityPercent() {
        const completed = this.completedVisits;
        if (completed.length === 0) return 0;
        const productive = completed.filter(v => v.Is_Productive__c).length;
        return Math.round((productive / completed.length) * 100);
    }

    get totalTimeSpent() {
        const totalMinutes = this.completedVisits.reduce((sum, v) => {
            return sum + (v.Duration_Minutes__c || 0);
        }, 0);
        const hours = Math.floor(totalMinutes / 60);
        const minutes = Math.round(totalMinutes % 60);
        if (hours > 0) {
            return hours + 'h ' + minutes + 'm';
        }
        return minutes + 'm';
    }

    get totalOrdersValue() {
        return this.completedVisits.reduce((sum, v) => {
            return sum + (v.Order_Value__c || 0);
        }, 0);
    }

    get totalOrdersFormatted() {
        return INR_FORMATTER.format(this.totalOrdersValue);
    }

    get totalCollectionValue() {
        return this.completedVisits.reduce((sum, v) => {
            return sum + (v.Collection_Amount__c || 0);
        }, 0);
    }

    get totalCollectionFormatted() {
        return INR_FORMATTER.format(this.totalCollectionValue);
    }

    get hasNoVisits() {
        return this.hasLoadedOnce && this.visits.length === 0;
    }

    get isAdHocEnabled() {
        return this.visitConfig && this.visitConfig.adHocVisitsEnabled === true;
    }

    get isAdHocSubmitDisabled() {
        return !this.adHocSelectedAccount;
    }

    // ----- Formatting Helpers -----
    formatTime(dateTimeValue) {
        if (!dateTimeValue) return '--';
        try {
            const dt = new Date(dateTimeValue);
            return dt.toLocaleTimeString('en-IN', {
                hour: '2-digit',
                minute: '2-digit',
                hour12: true
            });
        } catch (e) {
            return '--';
        }
    }

    formatDuration(minutes) {
        if (!minutes && minutes !== 0) return '--';
        const hrs = Math.floor(minutes / 60);
        const mins = Math.round(minutes % 60);
        if (hrs > 0) {
            return hrs + 'h ' + mins + 'm';
        }
        return mins + ' min';
    }

    formatCurrency(value) {
        if (!value && value !== 0) return '';
        return INR_FORMATTER_DECIMAL.format(value);
    }

    // ----- Event Handlers: Card Click (Navigate to Account) -----
    handleCardClick(event) {
        // Prevent navigation when clicking skip button
        const clickedElement = event.target;
        if (clickedElement.closest('.skip-button')) {
            return;
        }

        const visitId = event.currentTarget.dataset.id;
        const visit = this.visits.find(v => v.Id === visitId);
        if (visit && visit.Account__c) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: visit.Account__c,
                    objectApiName: 'Account',
                    actionName: 'view'
                }
            });
        }
    }

    // ----- Event Handlers: Skip Visit -----
    handleSkipClick(event) {
        event.stopPropagation();
        this.skipVisitId = event.currentTarget.dataset.id;
        this.selectedSkipReason = '';
        this.isSkipModalOpen = true;
    }

    handleSkipReasonChange(event) {
        this.selectedSkipReason = event.detail.value;
    }

    handleSkipModalClose() {
        this.isSkipModalOpen = false;
        this.skipVisitId = null;
        this.selectedSkipReason = '';
    }

    async handleSkipConfirm() {
        if (!this.selectedSkipReason || !this.skipVisitId) {
            this.showToast('Warning', 'Please select a reason for skipping.', 'warning');
            return;
        }

        this.isLoading = true;
        this.isSkipModalOpen = false;

        try {
            await skipVisit({
                visitId: this.skipVisitId,
                skipReason: this.selectedSkipReason
            });

            this.showToast('Success', 'Visit has been skipped.', 'success');

            // Update local state immediately
            this.visits = this.visits.map(v => {
                if (v.Id === this.skipVisitId) {
                    return { ...v, Visit_Status__c: VISIT_STATUS.SKIPPED };
                }
                return v;
            });

            this.skipVisitId = null;
            this.selectedSkipReason = '';

            // Also refresh from server to get the latest data
            await this.refreshVisits();
        } catch (error) {
            this.showToast('Error', 'Failed to skip visit: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ----- Event Handlers: Refresh -----
    async handleRefresh() {
        this.isLoading = true;
        try {
            await this.refreshVisits();
            this.showToast('Success', 'Visit board refreshed.', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to refresh: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ----- Event Handlers: Ad-Hoc Visit -----
    handleAdHocClick() {
        this.adHocSearchTerm = '';
        this.adHocSearchResults = [];
        this.adHocSelectedAccount = null;
        this.adHocReason = '';
        this.showAdHocDropdown = false;
        this.isAdHocModalOpen = true;
    }

    handleAdHocModalClose() {
        this.isAdHocModalOpen = false;
        this.adHocSelectedAccount = null;
        this.adHocSearchTerm = '';
        this.adHocReason = '';
    }

    handleAdHocSearch(event) {
        const term = event.target.value;
        this.adHocSearchTerm = term;

        if (this._adHocSearchTimer) {
            clearTimeout(this._adHocSearchTimer);
        }

        if (!term || term.length < 2) {
            this.adHocSearchResults = [];
            this.showAdHocDropdown = false;
            return;
        }

        this._adHocSearchTimer = setTimeout(() => {
            this._doOutletSearch(term);
        }, 300);
    }

    async _doOutletSearch(term) {
        try {
            const results = await searchOutlets({ searchTerm: term });
            this.adHocSearchResults = (results || []).map(acct => ({
                id: acct.Id,
                name: acct.Name,
                address: [acct.BillingStreet, acct.BillingCity].filter(Boolean).join(', ') || 'No address'
            }));
            this.showAdHocDropdown = this.adHocSearchResults.length > 0;
        } catch (error) {
            console.error('VisitPlanBoard: Outlet search error', error);
            this.adHocSearchResults = [];
            this.showAdHocDropdown = false;
        }
    }

    handleAdHocOutletSelect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selected = this.adHocSearchResults.find(a => a.id === selectedId);
        if (selected) {
            this.adHocSelectedAccount = selected;
            this.adHocSearchTerm = selected.name;
            this.showAdHocDropdown = false;
        }
    }

    handleAdHocReasonChange(event) {
        this.adHocReason = event.detail.value;
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

    async handleAdHocConfirm() {
        if (!this.adHocSelectedAccount) {
            this.showToast('Warning', 'Please select an outlet.', 'warning');
            return;
        }

        this.isLoading = true;
        this.isAdHocModalOpen = false;

        try {
            const visitData = {
                accountId: this.adHocSelectedAccount.id,
                dayAttendanceId: this.dayAttendanceId,
                latitude: 0,
                longitude: 0,
                accuracy: 0,
                batteryLevel: 0,
                networkStatus: 'Online',
                isPlanned: false,
                adHocReason: this.adHocReason || 'Ad-hoc visit'
            };

            await createVisit({ visitJson: JSON.stringify(visitData) });
            this.showToast('Success', 'Ad-hoc visit created for ' + this.adHocSelectedAccount.name, 'success');

            this.adHocSelectedAccount = null;
            this.adHocSearchTerm = '';
            this.adHocReason = '';

            await this.refreshVisits();
        } catch (error) {
            this.showToast('Error', 'Failed to create ad-hoc visit: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ----- Auto Refresh -----
    startAutoRefresh() {
        this.stopAutoRefresh();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.refreshInterval = setInterval(() => {
            this.refreshVisits();
        }, AUTO_REFRESH_INTERVAL);
    }

    stopAutoRefresh() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
            this.refreshInterval = null;
        }
    }

    // ----- Utility -----
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        return 'Unknown error';
    }
}
