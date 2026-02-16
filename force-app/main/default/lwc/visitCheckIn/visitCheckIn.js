import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import createVisit from '@salesforce/apex/VisitCheckInController.createVisit';
import completeVisit from '@salesforce/apex/VisitCheckInController.completeVisit';
import getOutletSummary from '@salesforce/apex/VisitCheckInController.getOutletSummary';

const ACCOUNT_FIELDS = [
    'Account.Name',
    'Account.BillingLatitude',
    'Account.BillingLongitude',
    'Account.BillingStreet',
    'Account.BillingCity',
    'Account.BillingState',
    'Account.Geofence_Radius__c'
];

const GEOFENCE_DEFAULT_RADIUS = 200; // meters

export default class VisitCheckIn extends LightningElement {
    @api recordId;

    @track visitRecord = {};
    @track location = { latitude: null, longitude: null, accuracy: null };
    @track isCheckedIn = false;
    @track visitDuration = 0;
    @track mapMarkers = null;
    @track outletSummary = {
        lastVisitDate: '--',
        pendingOrders: 0,
        outstandingBalanceFormatted: '0.00',
        activeSchemes: 0
    };
    @track visitActivities = [
        { id: 'order', label: 'Order', icon: 'standard:orders', completed: false, cardClass: 'activity-card' },
        { id: 'collection', label: 'Collection', icon: 'standard:currency', completed: false, cardClass: 'activity-card' },
        { id: 'merchandising', label: 'Merchandising', icon: 'standard:product_item', completed: false, cardClass: 'activity-card' },
        { id: 'survey', label: 'Survey', icon: 'standard:survey', completed: false, cardClass: 'activity-card' }
    ];

    photoPreview = null;
    photoData = null;
    isProcessing = false;
    checkInTime = null;
    visitId = null;
    timerInterval = null;
    outletLatitude = null;
    outletLongitude = null;
    geofenceRadius = GEOFENCE_DEFAULT_RADIUS;
    distanceToOutlet = null;
    nonProductiveReason = '';
    nonProductiveComments = '';
    showNonProductiveReason = false;

    get distanceDisplay() {
        if (this.distanceToOutlet === null) return 'Calculating...';
        if (this.distanceToOutlet < 1000) {
            return Math.round(this.distanceToOutlet) + ' m';
        }
        return (this.distanceToOutlet / 1000).toFixed(1) + ' km';
    }

    get distanceBadgeClass() {
        return this.isWithinGeofence ? 'status-badge badge-success' : 'status-badge badge-danger';
    }

    get isWithinGeofence() {
        if (this.distanceToOutlet === null) return false;
        return this.distanceToOutlet <= this.geofenceRadius;
    }

    get geofenceStatus() {
        return this.isWithinGeofence ? 'Within Range' : 'Out of Range';
    }

    get geofenceStatusClass() {
        return this.isWithinGeofence ? 'status-badge badge-success' : 'status-badge badge-danger';
    }

    get gpsAccuracy() {
        if (!this.location.accuracy) return 'N/A';
        return Math.round(this.location.accuracy) + ' m';
    }

    get visitDurationDisplay() {
        const hours = Math.floor(this.visitDuration / 3600);
        const minutes = Math.floor((this.visitDuration % 3600) / 60);
        const seconds = this.visitDuration % 60;
        return this.padZero(hours) + ':' + this.padZero(minutes) + ':' + this.padZero(seconds);
    }

    get checkInTimeDisplay() {
        if (!this.checkInTime) return '';
        return this.checkInTime.toLocaleTimeString('en-IN', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        });
    }

    get nonProductiveReasonOptions() {
        return [
            { label: 'Shop Closed', value: 'Shop Closed' },
            { label: 'Owner Not Available', value: 'Owner Not Available' },
            { label: 'Delivery Not Received', value: 'Delivery Not Received' },
            { label: 'No Demand', value: 'No Demand' },
            { label: 'Credit Limit Exceeded', value: 'Credit Limit Exceeded' },
            { label: 'Competition Activity', value: 'Competition Activity' },
            { label: 'Other', value: 'Other' }
        ];
    }

    @wire(getRecord, { recordId: '$recordId', fields: ACCOUNT_FIELDS })
    wiredAccount({ error, data }) {
        if (data) {
            this.outletLatitude = getFieldValue(data, 'Account.BillingLatitude');
            this.outletLongitude = getFieldValue(data, 'Account.BillingLongitude');
            this.geofenceRadius = getFieldValue(data, 'Account.Geofence_Radius__c') || GEOFENCE_DEFAULT_RADIUS;

            const accountName = getFieldValue(data, 'Account.Name');
            const street = getFieldValue(data, 'Account.BillingStreet') || '';
            const city = getFieldValue(data, 'Account.BillingCity') || '';

            this.getCurrentLocation();
            this.loadOutletSummary();

            if (this.outletLatitude && this.outletLongitude) {
                this.updateMapMarkers(accountName, street, city);
            }
        } else if (error) {
            this.showToast('Error', 'Failed to load outlet details', 'error');
        }
    }

    connectedCallback() {
        this.getCurrentLocation();
    }

    disconnectedCallback() {
        this.stopTimer();
    }

    getCurrentLocation() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.location = {
                        latitude: position.coords.latitude,
                        longitude: position.coords.longitude,
                        accuracy: position.coords.accuracy
                    };

                    if (this.outletLatitude && this.outletLongitude) {
                        this.distanceToOutlet = this.calculateDistance(
                            this.location.latitude, this.location.longitude,
                            this.outletLatitude, this.outletLongitude
                        );
                    }

                    this.updateMapMarkers();
                },
                (error) => {
                    console.error('Geolocation error:', error);
                    this.showToast('Warning', 'Unable to get location. Please enable GPS.', 'warning');
                },
                { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
            );
        } else {
            this.showToast('Error', 'Geolocation is not supported by this device', 'error');
        }
    }

    calculateDistance(lat1, lon1, lat2, lon2) {
        const R = 6371000; // Earth radius in meters
        const dLat = this.toRadians(lat2 - lat1);
        const dLon = this.toRadians(lon2 - lon1);
        const a =
            Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(this.toRadians(lat1)) * Math.cos(this.toRadians(lat2)) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    toRadians(degrees) {
        return degrees * (Math.PI / 180);
    }

    updateMapMarkers(accountName, street, city) {
        const markers = [];

        if (this.outletLatitude && this.outletLongitude) {
            markers.push({
                location: {
                    Latitude: this.outletLatitude,
                    Longitude: this.outletLongitude
                },
                title: accountName || 'Outlet Location',
                description: (street ? street + ', ' : '') + (city || ''),
                icon: 'standard:account',
                mapIcon: {
                    path: 'M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z',
                    fillColor: '#e74c3c',
                    fillOpacity: 1,
                    strokeWeight: 1,
                    scale: 1.5
                }
            });
        }

        if (this.location.latitude && this.location.longitude) {
            markers.push({
                location: {
                    Latitude: this.location.latitude,
                    Longitude: this.location.longitude
                },
                title: 'Your Location',
                description: 'Current GPS position',
                icon: 'standard:user',
                mapIcon: {
                    path: 'M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z',
                    fillColor: '#3498db',
                    fillOpacity: 1,
                    strokeWeight: 1,
                    scale: 1.5
                }
            });
        }

        if (markers.length > 0) {
            this.mapMarkers = markers;
        }
    }

    async loadOutletSummary() {
        if (!this.recordId) return;
        try {
            const result = await getOutletSummary({ accountId: this.recordId });
            if (result) {
                this.outletSummary = {
                    lastVisitDate: result.Last_Visit_Date__c
                        ? new Date(result.Last_Visit_Date__c).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
                        : 'No prior visit',
                    pendingOrders: result.Pending_Orders__c || 0,
                    outstandingBalanceFormatted: this.formatCurrency(result.Outstanding_Balance__c || 0),
                    activeSchemes: result.Active_Schemes__c || 0
                };
            }
        } catch (error) {
            console.error('Error loading outlet summary:', error);
        }
    }

    triggerPhotoCapture() {
        const fileInput = this.template.querySelector('input[type="file"]');
        if (fileInput) {
            fileInput.click();
        }
    }

    capturePhoto(event) {
        const file = event.target.files[0];
        if (!file) return;

        if (file.size > 5 * 1024 * 1024) {
            this.showToast('Error', 'Photo size must be less than 5MB', 'error');
            return;
        }

        const reader = new FileReader();
        reader.onload = () => {
            this.photoPreview = reader.result;
            this.photoData = reader.result.split(',')[1]; // base64 data
        };
        reader.readAsDataURL(file);
    }

    removePhoto() {
        this.photoPreview = null;
        this.photoData = null;
    }

    async handleCheckIn() {
        if (!this.location.latitude || !this.location.longitude) {
            this.showToast('Error', 'Location not available. Please enable GPS and try again.', 'error');
            this.getCurrentLocation();
            return;
        }

        if (!this.isWithinGeofence && this.outletLatitude) {
            this.showToast('Warning', 'You are outside the geo-fence radius. Please move closer to the outlet.', 'warning');
            return;
        }

        this.isProcessing = true;
        try {
            const visitData = {
                accountId: this.recordId,
                checkInLatitude: this.location.latitude,
                checkInLongitude: this.location.longitude,
                checkInAccuracy: this.location.accuracy,
                checkInPhoto: this.photoData,
                distanceToOutlet: this.distanceToOutlet
            };

            const result = await createVisit({ visitJson: JSON.stringify(visitData) });
            this.visitId = result.Id;
            this.isCheckedIn = true;
            this.checkInTime = new Date();
            this.startTimer();

            this.showToast('Success', 'Checked in successfully!', 'success');
        } catch (error) {
            this.showToast('Error', 'Check-in failed: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    async handleCheckOut() {
        this.isProcessing = true;
        try {
            this.getCurrentLocation();

            const completedActivities = this.visitActivities
                .filter(a => a.completed)
                .map(a => a.id);

            const visitData = {
                visitId: this.visitId,
                checkOutLatitude: this.location.latitude,
                checkOutLongitude: this.location.longitude,
                checkOutPhoto: this.photoData,
                duration: this.visitDuration,
                activities: completedActivities,
                isProductive: !this.showNonProductiveReason,
                nonProductiveReason: this.nonProductiveReason,
                nonProductiveComments: this.nonProductiveComments
            };

            await completeVisit({ visitJson: JSON.stringify(visitData) });
            this.stopTimer();
            this.isCheckedIn = false;

            this.showToast('Success',
                'Checked out successfully! Visit duration: ' + this.visitDurationDisplay,
                'success'
            );
        } catch (error) {
            this.showToast('Error', 'Check-out failed: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    handleMarkNonProductive() {
        this.showNonProductiveReason = !this.showNonProductiveReason;
    }

    handleNonProductiveReasonChange(event) {
        this.nonProductiveReason = event.detail.value;
    }

    handleNonProductiveCommentsChange(event) {
        this.nonProductiveComments = event.target.value;
    }

    toggleActivity(event) {
        const activityId = event.currentTarget.dataset.activityId;
        this.visitActivities = this.visitActivities.map(activity => {
            if (activity.id === activityId) {
                const completed = !activity.completed;
                return {
                    ...activity,
                    completed: completed,
                    cardClass: completed ? 'activity-card activity-completed' : 'activity-card'
                };
            }
            return activity;
        });
    }

    startTimer() {
        this.visitDuration = 0;
        this.timerInterval = setInterval(() => {
            this.visitDuration++;
        }, 1000);
    }

    stopTimer() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }
    }

    padZero(num) {
        return num < 10 ? '0' + num : '' + num;
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: 'INR',
            minimumFractionDigits: 2
        }).format(value || 0);
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