import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getOutletDetails from '@salesforce/apex/OutletThreeSixtyController.getOutletDetails';
import getRecentOrders from '@salesforce/apex/OutletThreeSixtyController.getRecentOrders';
import getOutstandingBalance from '@salesforce/apex/OutletThreeSixtyController.getOutstandingBalance';
import getVisitHistory from '@salesforce/apex/OutletThreeSixtyController.getVisitHistory';

const ACCOUNT_FIELDS = [
    'Account.Name',
    'Account.Outlet_Class__c',
    'Account.Channel__c',
    'Account.Type',
    'Account.GSTIN__c',
    'Account.BillingLatitude',
    'Account.BillingLongitude',
    'Account.BillingStreet',
    'Account.BillingCity'
];

export default class OutletThreeSixty extends NavigationMixin(LightningElement) {
    @api recordId;

    @track activeTab = 'orders';
    @track outletData = {
        name: '',
        outletClass: '',
        channel: '',
        type: '',
        gstin: '',
        mtdOrderValue: 0,
        mtdOrderValueFormatted: '0',
        outstanding: 0,
        outstandingFormatted: '0',
        avgOrderValue: 0,
        avgOrderValueFormatted: '0',
        visitFrequency: 'N/A',
        mtdCollectionFormatted: '0',
        overdueAmountFormatted: '0',
        classBadgeClass: 'class-badge class-b'
    };
    @track orders = [];
    @track collections = [];
    @track visits = [];
    @track schemes = [];
    @track stockItems = [];
    @track mapMarkers = null;

    isLoading = false;

    get hasOrders() { return this.orders && this.orders.length > 0; }
    get hasCollections() { return this.collections && this.collections.length > 0; }
    get hasVisits() { return this.visits && this.visits.length > 0; }
    get hasSchemes() { return this.schemes && this.schemes.length > 0; }
    get hasStock() { return this.stockItems && this.stockItems.length > 0; }

    @wire(getRecord, { recordId: '$recordId', fields: ACCOUNT_FIELDS })
    wiredAccount({ error, data }) {
        if (data) {
            const name = getFieldValue(data, 'Account.Name');
            const outletClass = getFieldValue(data, 'Account.Outlet_Class__c') || 'B';
            const channel = getFieldValue(data, 'Account.Channel__c') || 'General Trade';
            const type = getFieldValue(data, 'Account.Type') || 'Outlet';
            const gstin = getFieldValue(data, 'Account.GSTIN__c');
            const lat = getFieldValue(data, 'Account.BillingLatitude');
            const lng = getFieldValue(data, 'Account.BillingLongitude');
            const street = getFieldValue(data, 'Account.BillingStreet') || '';
            const city = getFieldValue(data, 'Account.BillingCity') || '';

            this.outletData = {
                ...this.outletData,
                name: name,
                outletClass: outletClass,
                channel: channel,
                type: type,
                gstin: gstin,
                classBadgeClass: this.getClassBadgeClass(outletClass)
            };

            if (lat && lng) {
                this.mapMarkers = [{
                    location: {
                        Latitude: lat,
                        Longitude: lng
                    },
                    title: name,
                    description: street + (city ? ', ' + city : '')
                }];
            }

            this.loadOutletDetails();
            this.loadTabData('orders');
        } else if (error) {
            this.showToast('Error', 'Failed to load account', 'error');
        }
    }

    async loadOutletDetails() {
        try {
            const result = await getOutletDetails({ accountId: this.recordId });
            if (result) {
                this.outletData = {
                    ...this.outletData,
                    mtdOrderValue: result.MTD_Order_Value__c || 0,
                    mtdOrderValueFormatted: this.formatCurrencyShort(result.MTD_Order_Value__c || 0),
                    outstanding: result.Outstanding_Balance__c || 0,
                    outstandingFormatted: this.formatCurrencyShort(result.Outstanding_Balance__c || 0),
                    avgOrderValue: result.Avg_Order_Value__c || 0,
                    avgOrderValueFormatted: this.formatCurrencyShort(result.Avg_Order_Value__c || 0),
                    visitFrequency: result.Visit_Frequency__c || 'Weekly',
                    mtdCollectionFormatted: this.formatCurrencyShort(result.MTD_Collection__c || 0),
                    overdueAmountFormatted: this.formatCurrencyShort(result.Overdue_Amount__c || 0)
                };
            }
        } catch (error) {
            console.error('Error loading outlet details:', error);
        }
    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
        this.loadTabData(this.activeTab);
    }

    async loadTabData(tabName) {
        this.isLoading = true;
        try {
            switch (tabName) {
                case 'orders':
                    await this.loadOrders();
                    break;
                case 'collections':
                    await this.loadCollections();
                    break;
                case 'visits':
                    await this.loadVisits();
                    break;
                case 'schemes':
                    await this.loadSchemes();
                    break;
                case 'stock':
                    await this.loadStock();
                    break;
                default:
                    break;
            }
        } catch (error) {
            console.error('Error loading tab data:', error);
        } finally {
            this.isLoading = false;
        }
    }

    async loadOrders() {
        try {
            const result = await getRecentOrders({ accountId: this.recordId });
            this.orders = (result || []).map(order => ({
                id: order.Id,
                orderNumber: order.Name || order.Order_Number__c,
                date: order.Order_Date__c,
                dateFormatted: this.formatDate(order.Order_Date__c || order.CreatedDate),
                itemCount: order.Line_Item_Count__c || 0,
                amount: order.Net_Amount__c || 0,
                amountFormatted: this.formatCurrency(order.Net_Amount__c || 0),
                status: order.Status__c || 'Confirmed',
                statusBadge: this.getStatusBadgeClass(order.Status__c)
            }));
        } catch (error) {
            console.error('Error loading orders:', error);
        }
    }

    async loadCollections() {
        try {
            const result = await getOutstandingBalance({ accountId: this.recordId });
            this.collections = (result || []).map(col => ({
                id: col.Id,
                receiptNumber: col.Name || col.Receipt_Number__c,
                date: col.Collection_Date__c,
                dateFormatted: this.formatDate(col.Collection_Date__c || col.CreatedDate),
                amount: col.Amount__c || 0,
                amountFormatted: this.formatCurrency(col.Amount__c || 0),
                mode: col.Payment_Mode__c || 'Cash',
                status: col.Status__c || 'Confirmed',
                statusBadge: this.getStatusBadgeClass(col.Status__c)
            }));
        } catch (error) {
            console.error('Error loading collections:', error);
        }
    }

    async loadVisits() {
        try {
            const result = await getVisitHistory({ accountId: this.recordId });
            this.visits = (result || []).map(visit => ({
                id: visit.Id,
                date: visit.Visit_Date__c,
                dateFormatted: this.formatDate(visit.Visit_Date__c || visit.CreatedDate),
                salesperson: visit.Salesperson_Name__c || visit.Owner?.Name || 'N/A',
                checkInTime: this.formatTime(visit.Check_In_Time__c),
                duration: this.formatDuration(visit.Duration_Minutes__c),
                isProductive: visit.Is_Productive__c !== false,
                activities: visit.Activities__c || 'Order'
            }));
        } catch (error) {
            console.error('Error loading visits:', error);
        }
    }

    async loadSchemes() {
        try {
            const result = await getApplicableSchemes({ accountId: this.recordId });
            this.schemes = (result || []).map(scheme => ({
                id: scheme.Id,
                name: scheme.Name,
                type: scheme.Type__c || 'Discount',
                description: scheme.Description__c || '',
                validFrom: this.formatDate(scheme.Valid_From__c),
                validTo: this.formatDate(scheme.Valid_To__c),
                typeBadgeStyle: this.getSchemeTypeBadgeStyle(scheme.Type__c)
            }));
        } catch (error) {
            console.error('Error loading schemes:', error);
        }
    }

    async loadStock() {
        // Stock data would come from a distributor stock custom object
        this.stockItems = [];
    }

    refreshData() {
        this.loadOutletDetails();
        this.loadTabData(this.activeTab);
    }

    navigateToRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    getClassBadgeClass(outletClass) {
        const classMap = {
            'A': 'class-badge class-a',
            'B': 'class-badge class-b',
            'C': 'class-badge class-c',
            'D': 'class-badge class-d'
        };
        return classMap[outletClass] || 'class-badge class-b';
    }

    getStatusBadgeClass(status) {
        const map = {
            'Confirmed': 'status-badge badge-confirmed',
            'Draft': 'status-badge badge-draft',
            'Pending': 'status-badge badge-pending',
            'Delivered': 'status-badge badge-delivered',
            'Cancelled': 'status-badge badge-cancelled',
            'Dispatched': 'status-badge badge-dispatched'
        };
        return map[status] || 'status-badge badge-confirmed';
    }

    getSchemeTypeBadgeStyle(type) {
        const colors = {
            'Percentage Discount': 'background-color: #e8f4fd; color: #0176d3',
            'Flat Discount': 'background-color: #e6f7e9; color: #2e844a',
            'Buy X Get Y Free': 'background-color: #fff8e1; color: #dd7a01',
            'Slab Discount': 'background-color: #f3e8ff; color: #9b59b6'
        };
        return colors[type] || 'background-color: #f3f3f3; color: #706e6b';
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: 'INR',
            minimumFractionDigits: 2
        }).format(value || 0);
    }

    formatCurrencyShort(value) {
        if (!value) return '0';
        if (value >= 100000) return (value / 100000).toFixed(1) + ' L';
        if (value >= 1000) return (value / 1000).toFixed(1) + ' K';
        return new Intl.NumberFormat('en-IN').format(Math.round(value));
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        return new Date(dateStr).toLocaleDateString('en-IN', {
            day: '2-digit', month: 'short', year: 'numeric'
        });
    }

    formatTime(timeStr) {
        if (!timeStr) return 'N/A';
        const date = new Date(timeStr);
        return date.toLocaleTimeString('en-IN', {
            hour: '2-digit', minute: '2-digit', hour12: true
        });
    }

    formatDuration(minutes) {
        if (!minutes) return 'N/A';
        if (minutes < 60) return minutes + ' min';
        const hrs = Math.floor(minutes / 60);
        const mins = minutes % 60;
        return hrs + 'h ' + mins + 'm';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}