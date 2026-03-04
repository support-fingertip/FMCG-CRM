import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import completeVisit from '@salesforce/apex/VisitCheckInController.completeVisit';
import getVisitCompletionSummary from '@salesforce/apex/VisitCheckInController.getVisitCompletionSummary';
import getVisitActivities from '@salesforce/apex/VisitCheckInController.getVisitActivities';

// Visit fields
import VISIT_STATUS from '@salesforce/schema/Visit__c.Visit_Status__c';
import ACCOUNT_ID from '@salesforce/schema/Visit__c.Account__c';
import ACCOUNT_NAME from '@salesforce/schema/Visit__c.Account__r.Name';
import BEAT_NAME from '@salesforce/schema/Visit__c.Beat__r.Name';
import CHECK_IN_TIME from '@salesforce/schema/Visit__c.Check_In_Time__c';
import VISIT_SEQUENCE from '@salesforce/schema/Visit__c.Visit_Sequence__c';
import ORDER_VALUE from '@salesforce/schema/Visit__c.Order_Value__c';
import COLLECTION_AMOUNT from '@salesforce/schema/Visit__c.Collection_Amount__c';
import TOTAL_ORDERS_COUNT from '@salesforce/schema/Visit__c.Total_Orders_Count__c';
import IS_AD_HOC from '@salesforce/schema/Visit__c.Is_Ad_Hoc__c';

const VISIT_FIELDS = [
    VISIT_STATUS, ACCOUNT_ID, ACCOUNT_NAME, BEAT_NAME,
    CHECK_IN_TIME, VISIT_SEQUENCE, ORDER_VALUE,
    COLLECTION_AMOUNT, TOTAL_ORDERS_COUNT, IS_AD_HOC
];

const INR_FORMATTER = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
});

export default class VisitActivity extends NavigationMixin(LightningElement) {
    @api recordId;

    @track activeTab = 'activities';
    @track activities = [];
    @track orders = [];
    @track collections = [];
    @track isLoading = false;
    @track isCheckoutModalOpen = false;
    @track checkoutNotes = '';
    @track isProductive = true;
    @track nonProductiveReason = '';
    @track isProcessing = false;

    visitRecord = null;

    @wire(getRecord, { recordId: '$recordId', fields: VISIT_FIELDS })
    wiredVisit({ error, data }) {
        if (data) {
            this.visitRecord = data;
            this._loadSummary();
        } else if (error) {
            console.error('Error loading visit:', error);
        }
    }

    async _loadSummary() {
        try {
            const [summary, activityList] = await Promise.all([
                getVisitCompletionSummary({ visitId: this.recordId }),
                getVisitActivities()
            ]);

            if (summary) {
                this.orders = (summary.orders || []).map(o => ({
                    ...o,
                    amountFormatted: INR_FORMATTER.format(o.Total_Net_Amount__c || 0)
                }));
                this.collections = (summary.collections || []).map(c => ({
                    ...c,
                    amountFormatted: INR_FORMATTER.format(c.Amount__c || 0)
                }));
            }

            if (activityList) {
                this.activities = activityList.filter(a => a.enabled !== false);
            }
        } catch (err) {
            console.error('Error loading visit summary:', err);
        }
    }

    // ----- Getters for visit data -----
    get outletName() {
        return this.visitRecord ? getFieldValue(this.visitRecord, ACCOUNT_NAME) : '';
    }
    get accountId() {
        return this.visitRecord ? getFieldValue(this.visitRecord, ACCOUNT_ID) : null;
    }
    get beatName() {
        return this.visitRecord ? getFieldValue(this.visitRecord, BEAT_NAME) : '';
    }
    get visitStatus() {
        return this.visitRecord ? getFieldValue(this.visitRecord, VISIT_STATUS) : '';
    }
    get checkInTime() {
        const t = this.visitRecord ? getFieldValue(this.visitRecord, CHECK_IN_TIME) : null;
        if (!t) return '--';
        try {
            return new Date(t).toLocaleTimeString('en-IN', {
                hour: '2-digit', minute: '2-digit', hour12: true
            });
        } catch (e) { return '--'; }
    }
    get visitSequence() {
        return this.visitRecord ? getFieldValue(this.visitRecord, VISIT_SEQUENCE) : '';
    }
    get orderValue() {
        const v = this.visitRecord ? getFieldValue(this.visitRecord, ORDER_VALUE) : 0;
        return INR_FORMATTER.format(v || 0);
    }
    get collectionAmount() {
        const v = this.visitRecord ? getFieldValue(this.visitRecord, COLLECTION_AMOUNT) : 0;
        return INR_FORMATTER.format(v || 0);
    }
    get totalOrdersCount() {
        return this.visitRecord ? getFieldValue(this.visitRecord, TOTAL_ORDERS_COUNT) || 0 : 0;
    }
    get isAdHoc() {
        return this.visitRecord ? getFieldValue(this.visitRecord, IS_AD_HOC) : false;
    }
    get isActiveVisit() {
        return this.visitStatus === 'Checked In' || this.visitStatus === 'In Progress';
    }
    get isCompletedVisit() {
        return this.visitStatus === 'Completed';
    }
    get statusBadgeClass() {
        if (this.isActiveVisit) return 'status-badge status-active';
        if (this.isCompletedVisit) return 'status-badge status-completed';
        return 'status-badge status-other';
    }

    // ----- Tab management -----
    get isActivitiesTab() { return this.activeTab === 'activities'; }
    get isOrdersTab() { return this.activeTab === 'orders'; }
    get isCollectionsTab() { return this.activeTab === 'collections'; }
    get isReturnsTab() { return this.activeTab === 'returns'; }

    get activitiesTabClass() { return 'va-tab' + (this.isActivitiesTab ? ' va-tab-selected' : ''); }
    get ordersTabClass() { return 'va-tab' + (this.isOrdersTab ? ' va-tab-selected' : ''); }
    get collectionsTabClass() { return 'va-tab' + (this.isCollectionsTab ? ' va-tab-selected' : ''); }
    get returnsTabClass() { return 'va-tab' + (this.isReturnsTab ? ' va-tab-selected' : ''); }

    get hasOrders() { return this.orders.length > 0; }
    get hasCollections() { return this.collections.length > 0; }

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

    get isCheckoutDisabled() {
        return this.isProcessing || (!this.isProductive && !this.nonProductiveReason);
    }

    // ----- Tab click -----
    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    // ----- Activity Actions -----
    handleActivityClick(event) {
        const activityId = event.currentTarget.dataset.id;
        const activity = this.activities.find(a => a.id === activityId);
        if (!activity || !this.accountId) return;

        switch (activityId) {
            case 'order':
                this._navigateToTab('orders');
                break;
            case 'collection':
                this._navigateToTab('collections');
                break;
            case 'returns':
                this._navigateToTab('returns');
                break;
            default:
                // For other activities like Merchandising, Survey - navigate to account
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.accountId,
                        objectApiName: 'Account',
                        actionName: 'view'
                    }
                });
                break;
        }
    }

    _navigateToTab(tabName) {
        this.activeTab = tabName;
    }

    // ----- Navigation Actions -----
    handleNewOrder() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Sales_Order__c',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: 'Account__c=' + this.accountId + ',Visit__c=' + this.recordId
            }
        });
    }

    handleNewCollection() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Collection__c',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: 'Account__c=' + this.accountId + ',Visit__c=' + this.recordId
            }
        });
    }

    handleNewReturn() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Return_Order__c',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: 'Account__c=' + this.accountId + ',Visit__c=' + this.recordId
            }
        });
    }

    handleViewRecord(event) {
        const recId = event.currentTarget.dataset.id;
        const objApi = event.currentTarget.dataset.object;
        if (recId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recId,
                    objectApiName: objApi || 'Sales_Order__c',
                    actionName: 'view'
                }
            });
        }
    }

    // ----- Checkout -----
    handleCheckoutClick() {
        this.isCheckoutModalOpen = true;
        this.checkoutNotes = '';
        this.isProductive = true;
        this.nonProductiveReason = '';
    }

    handleCheckoutClose() {
        this.isCheckoutModalOpen = false;
    }

    handleProductiveChange(event) {
        this.isProductive = event.target.checked;
        if (this.isProductive) {
            this.nonProductiveReason = '';
        }
    }

    handleNonProductiveReasonChange(event) {
        this.nonProductiveReason = event.detail.value;
    }

    handleCheckoutNotesChange(event) {
        this.checkoutNotes = event.detail.value;
    }

    async handleCheckoutConfirm() {
        this.isProcessing = true;
        try {
            let position = { latitude: 0, longitude: 0, accuracy: 0 };
            if (navigator.geolocation) {
                position = await new Promise((resolve) => {
                    navigator.geolocation.getCurrentPosition(
                        (pos) => resolve({
                            latitude: pos.coords.latitude,
                            longitude: pos.coords.longitude,
                            accuracy: pos.coords.accuracy
                        }),
                        () => resolve({ latitude: 0, longitude: 0, accuracy: 0 }),
                        { enableHighAccuracy: true, timeout: 10000 }
                    );
                });
            }

            const checkoutData = {
                visitId: this.recordId,
                latitude: position.latitude,
                longitude: position.longitude,
                accuracy: position.accuracy,
                isProductive: this.isProductive,
                nonProductiveReason: this.nonProductiveReason,
                notes: this.checkoutNotes
            };

            await completeVisit({ visitJson: JSON.stringify(checkoutData) });
            this.showToast('Success', 'Visit completed successfully.', 'success');
            this.isCheckoutModalOpen = false;

            // Refresh the page
            // eslint-disable-next-line no-restricted-globals
            setTimeout(() => { location.reload(); }, 500);
        } catch (error) {
            const msg = error.body ? error.body.message : error.message || 'Unknown error';
            this.showToast('Error', 'Checkout failed: ' + msg, 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    handleGoBack() {
        window.history.back();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
