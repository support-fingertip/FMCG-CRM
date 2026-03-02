import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Id from '@salesforce/user/Id';

import createVisit from '@salesforce/apex/VisitCheckInController.createVisit';
import completeVisit from '@salesforce/apex/VisitCheckInController.completeVisit';
import skipVisit from '@salesforce/apex/VisitCheckInController.skipVisit';
import getOutletSummary from '@salesforce/apex/VisitCheckInController.getOutletSummary';
import getTodaysVisits from '@salesforce/apex/VisitCheckInController.getTodaysVisits';
import getPlannedVisits from '@salesforce/apex/VisitCheckInController.getPlannedVisits';
import validateGeoFence from '@salesforce/apex/VisitCheckInController.validateGeoFence';
import getVisitActivities from '@salesforce/apex/VisitCheckInController.getVisitActivities';
import getVisitCompletionSummary from '@salesforce/apex/VisitCheckInController.getVisitCompletionSummary';
import getVisitConfig from '@salesforce/apex/VisitCheckInController.getVisitConfig';

const ACCOUNT_FIELDS = [
    'Account.Name',
    'Account.BillingLatitude',
    'Account.BillingLongitude',
    'Account.BillingStreet',
    'Account.BillingCity',
    'Account.BillingState',
    'Account.Geofence_Radius__c'
];

const GEOFENCE_DEFAULT_RADIUS = 200;
const PHOTO_MAX_SIZE_BYTES = 5 * 1024 * 1024;
const INR_FORMATTER = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    minimumFractionDigits: 2
});

export default class VisitCheckIn extends LightningElement {
    @api recordId;

    currentUserId = Id;

    // ---------- Reactive state ----------
    @track location = { latitude: null, longitude: null, accuracy: null };
    @track mapMarkers = null;
    @track outletSummary = {
        lastVisitDate: '--',
        pendingOrders: 0,
        outstandingBalanceFormatted: INR_FORMATTER.format(0),
        activeSchemes: 0
    };
    @track visitActivities = [];
    @track completionSummary = {
        ordersCount: 0,
        ordersValueFormatted: INR_FORMATTER.format(0),
        collectionsCount: 0,
        collectionsValueFormatted: INR_FORMATTER.format(0)
    };

    // ---------- Visit state ----------
    isCheckedIn = false;
    isVisitCompleted = false;
    isProcessing = false;
    visitId = null;
    checkInTime = null;
    @track visitDuration = 0;
    timerInterval = null;

    // ---------- Photo ----------
    photoPreview = null;
    photoData = null;

    // ---------- Location / Geofence ----------
    outletLatitude = null;
    outletLongitude = null;
    outletName = '';
    outletStreet = '';
    outletCity = '';
    geofenceRadius = GEOFENCE_DEFAULT_RADIUS;
    distanceToOutlet = null;
    geoValidation = null; // server-side GeoValidationResult
    geofenceOverrideReason = '';

    // ---------- Non-productive ----------
    showNonProductiveReason = false;
    nonProductiveReason = '';
    nonProductiveComments = '';

    // ---------- Skip visit ----------
    showSkipReason = false;
    skipReason = '';

    // ---------- Visit notes ----------
    visitNotes = '';

    // ---------- Completion summary ----------
    showCompletionSummary = false;

    // ---------- Offline ----------
    isOffline = false;
    _onlineHandler;
    _offlineHandler;

    // ---------- Device info ----------
    batteryLevel = null;
    networkStatus = 'unknown';

    // ---------- Config flags ----------
    configRequirePhotoCheckIn = false;
    configAllowGeofenceOverride = false;
    configMinVisitDurationSec = 0;
    configMaxVisitsPerDay = 50;
    configGeofenceEnabled = true;
    configAdHocVisitsEnabled = true;

    // ================================================================
    //  GETTERS
    // ================================================================

    get distanceDisplay() {
        if (this.distanceToOutlet === null) return 'Calculating...';
        if (this.distanceToOutlet < 1000) {
            return Math.round(this.distanceToOutlet) + ' m';
        }
        return (this.distanceToOutlet / 1000).toFixed(1) + ' km';
    }

    get distanceBadgeClass() {
        return this.isWithinGeofence
            ? 'status-badge badge-success'
            : 'status-badge badge-danger';
    }

    get isWithinGeofence() {
        if (this.geoValidation) return this.geoValidation.isWithinRange;
        if (this.distanceToOutlet === null) return false;
        return this.distanceToOutlet <= this.geofenceRadius;
    }

    get geofenceStatus() {
        if (!this.configGeofenceEnabled) return 'Disabled';
        return this.isWithinGeofence ? 'Within Range' : 'Out of Range';
    }

    get geofenceStatusClass() {
        if (!this.configGeofenceEnabled) return 'status-badge badge-neutral';
        return this.isWithinGeofence
            ? 'status-badge badge-success'
            : 'status-badge badge-danger';
    }

    get gpsAccuracy() {
        if (!this.location.accuracy) return 'N/A';
        return Math.round(this.location.accuracy) + ' m';
    }

    get allowedRadiusDisplay() {
        if (this.geoValidation && this.geoValidation.allowedRadius) {
            return this.geoValidation.allowedRadius + ' m';
        }
        return this.geofenceRadius + ' m';
    }

    get showGeofenceWarning() {
        return this.configGeofenceEnabled
            && !this.isWithinGeofence
            && this.distanceToOutlet !== null
            && !this.showGeofenceOverride;
    }

    get showGeofenceOverride() {
        return this.configGeofenceEnabled
            && !this.isWithinGeofence
            && this.distanceToOutlet !== null
            && this.geoValidation
            && this.geoValidation.canOverride
            && this.configAllowGeofenceOverride;
    }

    get visitDurationDisplay() {
        const hours = Math.floor(this.visitDuration / 3600);
        const minutes = Math.floor((this.visitDuration % 3600) / 60);
        const seconds = this.visitDuration % 60;
        return this._padZero(hours) + ':' + this._padZero(minutes) + ':' + this._padZero(seconds);
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

    get skipReasonOptions() {
        return [
            { label: 'Shop Closed', value: 'Shop Closed' },
            { label: 'Owner Not Available', value: 'Owner Not Available' },
            { label: 'Route Changed', value: 'Route Changed' },
            { label: 'Time Constraint', value: 'Time Constraint' },
            { label: 'Weather/Emergency', value: 'Weather/Emergency' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get nonProductiveButtonLabel() {
        return this.showNonProductiveReason ? 'Cancel Non-Productive' : 'Mark Non-Productive';
    }

    get checkInDisabled() {
        if (this.isProcessing) return true;
        if (this.configRequirePhotoCheckIn && !this.photoData) return true;
        if (!this.location.latitude || !this.location.longitude) return true;
        if (this.configGeofenceEnabled && !this.isWithinGeofence) {
            if (!this.showGeofenceOverride) return true;
            if (this.showGeofenceOverride && !this.geofenceOverrideReason) return true;
        }
        return false;
    }

    get checkOutDisabled() {
        if (this.isProcessing) return true;
        if (this.configMinVisitDurationSec > 0 && this.visitDuration < this.configMinVisitDurationSec) return true;
        if (this.showNonProductiveReason && !this.nonProductiveReason) return true;
        return false;
    }

    get skipConfirmDisabled() {
        return this.isProcessing || !this.skipReason;
    }

    // ================================================================
    //  WIRE: Account record
    // ================================================================

    @wire(getRecord, { recordId: '$recordId', fields: ACCOUNT_FIELDS })
    wiredAccount({ error, data }) {
        if (data) {
            this.outletLatitude = getFieldValue(data, 'Account.BillingLatitude');
            this.outletLongitude = getFieldValue(data, 'Account.BillingLongitude');
            this.geofenceRadius = getFieldValue(data, 'Account.Geofence_Radius__c') || GEOFENCE_DEFAULT_RADIUS;
            this.outletName = getFieldValue(data, 'Account.Name') || '';
            this.outletStreet = getFieldValue(data, 'Account.BillingStreet') || '';
            this.outletCity = getFieldValue(data, 'Account.BillingCity') || '';

            this._captureCurrentLocation();
            this._loadOutletSummary();
            this._updateMapMarkers();
        } else if (error) {
            this._showToast('Error', 'Failed to load outlet details', 'error');
        }
    }

    // ================================================================
    //  LIFECYCLE
    // ================================================================

    connectedCallback() {
        this._captureCurrentLocation();
        this._loadConfig();
        this._loadActivities();
        this._captureDeviceInfo();
        this._registerConnectivityListeners();
    }

    disconnectedCallback() {
        this._stopTimer();
        this._unregisterConnectivityListeners();
    }

    // ================================================================
    //  CONFIG
    // ================================================================

    async _loadConfig() {
        try {
            const config = await getVisitConfig();
            if (config) {
                this.configRequirePhotoCheckIn = config.requirePhotoCheckIn === true;
                this.configAllowGeofenceOverride = config.allowGeofenceOverride === true;
                this.configMinVisitDurationSec = config.minVisitDurationSec || 0;
                this.configMaxVisitsPerDay = config.maxVisitsPerDay || 50;
                this.configGeofenceEnabled = config.geofenceEnabled !== false;
                this.configAdHocVisitsEnabled = config.adHocVisitsEnabled !== false;
            }
        } catch (err) {
            console.error('Error loading visit config:', err);
        }
    }

    // ================================================================
    //  ACTIVITIES
    // ================================================================

    async _loadActivities() {
        try {
            const result = await getVisitActivities();
            if (result && result.length > 0) {
                this.visitActivities = result.map(a => ({
                    id: a.id,
                    label: a.label,
                    icon: a.icon,
                    type: a.type,
                    completed: false,
                    cardClass: 'activity-card'
                }));
            }
        } catch (err) {
            console.error('Error loading visit activities:', err);
            // Fallback defaults
            this.visitActivities = [
                { id: 'order', label: 'Order', icon: 'standard:orders', type: 'order', completed: false, cardClass: 'activity-card' },
                { id: 'collection', label: 'Collection', icon: 'standard:currency', type: 'collection', completed: false, cardClass: 'activity-card' },
                { id: 'merchandising', label: 'Merchandising', icon: 'standard:product_item', type: 'merchandising', completed: false, cardClass: 'activity-card' },
                { id: 'survey', label: 'Survey', icon: 'standard:survey', type: 'survey', completed: false, cardClass: 'activity-card' }
            ];
        }
    }

    // ================================================================
    //  OUTLET SUMMARY
    // ================================================================

    async _loadOutletSummary() {
        if (!this.recordId) return;
        try {
            const result = await getOutletSummary({ accountId: this.recordId });
            if (result) {
                this.outletSummary = {
                    lastVisitDate: result.lastVisitDate
                        ? new Date(result.lastVisitDate).toLocaleDateString('en-IN', {
                              day: '2-digit',
                              month: 'short',
                              year: 'numeric'
                          })
                        : 'No prior visit',
                    pendingOrders: result.pendingOrders || 0,
                    outstandingBalanceFormatted: INR_FORMATTER.format(result.outstandingBalance || 0),
                    activeSchemes: result.activeSchemes || 0
                };
            }
        } catch (err) {
            console.error('Error loading outlet summary:', err);
        }
    }

    // ================================================================
    //  GEOLOCATION
    // ================================================================

    _captureCurrentLocation() {
        if (!navigator.geolocation) {
            this._showToast('Error', 'Geolocation is not supported by this device', 'error');
            return;
        }
        navigator.geolocation.getCurrentPosition(
            (position) => {
                this.location = {
                    latitude: position.coords.latitude,
                    longitude: position.coords.longitude,
                    accuracy: position.coords.accuracy
                };
                if (this.outletLatitude && this.outletLongitude) {
                    this.distanceToOutlet = this._calculateDistance(
                        this.location.latitude, this.location.longitude,
                        this.outletLatitude, this.outletLongitude
                    );
                    this._validateGeoFenceServer();
                }
                this._updateMapMarkers();
            },
            (err) => {
                console.error('Geolocation error:', err);
                this._showToast('Warning', 'Unable to get location. Please enable GPS.', 'warning');
            },
            { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
        );
    }

    async _validateGeoFenceServer() {
        if (!this.configGeofenceEnabled) return;
        if (!this.location.latitude || !this.location.longitude || !this.recordId) return;
        try {
            const result = await validateGeoFence({
                latitude: this.location.latitude,
                longitude: this.location.longitude,
                accountId: this.recordId
            });
            if (result) {
                this.geoValidation = result;
                this.distanceToOutlet = result.distance;
                if (result.allowedRadius) {
                    this.geofenceRadius = result.allowedRadius;
                }
            }
        } catch (err) {
            console.error('Geofence validation error:', err);
        }
    }

    _calculateDistance(lat1, lon1, lat2, lon2) {
        const R = 6371000;
        const dLat = this._toRadians(lat2 - lat1);
        const dLon = this._toRadians(lon2 - lon1);
        const a =
            Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(this._toRadians(lat1)) * Math.cos(this._toRadians(lat2)) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    _toRadians(degrees) {
        return degrees * (Math.PI / 180);
    }

    // ================================================================
    //  MAP
    // ================================================================

    _updateMapMarkers() {
        const markers = [];

        if (this.outletLatitude && this.outletLongitude) {
            markers.push({
                location: {
                    Latitude: this.outletLatitude,
                    Longitude: this.outletLongitude
                },
                title: this.outletName || 'Outlet Location',
                description: [this.outletStreet, this.outletCity].filter(Boolean).join(', '),
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

    // ================================================================
    //  DEVICE INFO (battery, network)
    // ================================================================

    async _captureDeviceInfo() {
        // Battery level
        try {
            if (navigator.getBattery) {
                const battery = await navigator.getBattery();
                this.batteryLevel = Math.round(battery.level * 100);
            }
        } catch (err) {
            console.error('Battery API error:', err);
            this.batteryLevel = null;
        }

        // Network status
        this.networkStatus = navigator.onLine ? 'online' : 'offline';
        if (navigator.connection) {
            this.networkStatus = navigator.connection.effectiveType || this.networkStatus;
        }
    }

    // ================================================================
    //  CONNECTIVITY
    // ================================================================

    _registerConnectivityListeners() {
        this.isOffline = !navigator.onLine;
        this._onlineHandler = () => { this.isOffline = false; };
        this._offlineHandler = () => { this.isOffline = true; };
        window.addEventListener('online', this._onlineHandler);
        window.addEventListener('offline', this._offlineHandler);
    }

    _unregisterConnectivityListeners() {
        if (this._onlineHandler) {
            window.removeEventListener('online', this._onlineHandler);
        }
        if (this._offlineHandler) {
            window.removeEventListener('offline', this._offlineHandler);
        }
    }

    // ================================================================
    //  PHOTO HANDLERS
    // ================================================================

    triggerPhotoCapture() {
        const fileInput = this.template.querySelector('input[data-id="photoInput"]');
        if (fileInput) {
            fileInput.click();
        }
    }

    handlePhotoCaptured(event) {
        const file = event.target.files[0];
        if (!file) return;

        if (file.size > PHOTO_MAX_SIZE_BYTES) {
            this._showToast('Error', 'Photo size must be less than 5 MB', 'error');
            return;
        }

        const reader = new FileReader();
        reader.onload = () => {
            this.photoPreview = reader.result;
            this.photoData = reader.result.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    handleRemovePhoto() {
        this.photoPreview = null;
        this.photoData = null;
        const fileInput = this.template.querySelector('input[data-id="photoInput"]');
        if (fileInput) {
            fileInput.value = '';
        }
    }

    // ================================================================
    //  CHECK-IN
    // ================================================================

    async handleCheckIn() {
        if (!this.location.latitude || !this.location.longitude) {
            this._showToast('Error', 'Location not available. Please enable GPS and try again.', 'error');
            this._captureCurrentLocation();
            return;
        }

        if (this.configRequirePhotoCheckIn && !this.photoData) {
            this._showToast('Warning', 'A photo is required for check-in. Please capture a photo.', 'warning');
            return;
        }

        // Geofence enforcement
        if (this.configGeofenceEnabled && !this.isWithinGeofence) {
            if (this.showGeofenceOverride && this.geofenceOverrideReason) {
                // Allow override - proceed
            } else {
                this._showToast('Warning', 'You are outside the geo-fence radius. Move closer or provide an override reason.', 'warning');
                return;
            }
        }

        await this._captureDeviceInfo();

        this.isProcessing = true;
        try {
            const visitData = {
                accountId: this.recordId,
                checkInLatitude: this.location.latitude,
                checkInLongitude: this.location.longitude,
                checkInAccuracy: this.location.accuracy,
                checkInPhoto: this.photoData,
                distanceToOutlet: this.distanceToOutlet,
                batteryLevel: this.batteryLevel,
                networkStatus: this.networkStatus
            };

            if (this.geofenceOverrideReason) {
                visitData.geofenceOverrideReason = this.geofenceOverrideReason;
            }

            const result = await createVisit({ visitJson: JSON.stringify(visitData) });
            this.visitId = result.Id;
            this.isCheckedIn = true;
            this.checkInTime = new Date();
            this._startTimer();

            // Reset photo for checkout
            this.photoPreview = null;
            this.photoData = null;

            this._showToast('Success', 'Checked in successfully!', 'success');
        } catch (err) {
            this._showToast('Error', 'Check-in failed: ' + this._reduceErrors(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ================================================================
    //  CHECK-OUT
    // ================================================================

    async handleCheckOut() {
        if (this.showNonProductiveReason && !this.nonProductiveReason) {
            this._showToast('Warning', 'Please select a non-productive reason before checking out.', 'warning');
            return;
        }

        if (this.configMinVisitDurationSec > 0 && this.visitDuration < this.configMinVisitDurationSec) {
            const remaining = this.configMinVisitDurationSec - this.visitDuration;
            const mins = Math.ceil(remaining / 60);
            this._showToast('Warning', `Minimum visit duration not met. Please wait ${mins} more minute(s).`, 'warning');
            return;
        }

        // Refresh location for checkout
        this._captureCurrentLocation();

        this.isProcessing = true;
        try {
            const completedActivities = this.visitActivities
                .filter(a => a.completed)
                .map(a => a.id);

            const visitData = {
                visitId: this.visitId,
                checkOutLatitude: this.location.latitude,
                checkOutLongitude: this.location.longitude,
                checkOutAccuracy: this.location.accuracy,
                checkOutPhoto: this.photoData,
                activities: completedActivities,
                isProductive: !this.showNonProductiveReason,
                nonProductiveReason: this.nonProductiveReason,
                notes: this.visitNotes
            };

            await completeVisit({ visitJson: JSON.stringify(visitData) });

            // Load completion summary
            await this._loadCompletionSummary();

            this._stopTimer();
            this.isCheckedIn = false;
            this.isVisitCompleted = true;

            this._showToast('Success',
                'Checked out successfully! Duration: ' + this.visitDurationDisplay,
                'success'
            );
        } catch (err) {
            this._showToast('Error', 'Check-out failed: ' + this._reduceErrors(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ================================================================
    //  COMPLETION SUMMARY
    // ================================================================

    async _loadCompletionSummary() {
        if (!this.visitId) return;
        try {
            const result = await getVisitCompletionSummary({ visitId: this.visitId });
            if (result) {
                this.completionSummary = {
                    ordersCount: result.ordersCount || 0,
                    ordersValueFormatted: INR_FORMATTER.format(result.ordersValue || 0),
                    collectionsCount: result.collectionsCount || 0,
                    collectionsValueFormatted: INR_FORMATTER.format(result.collectionsValue || 0)
                };
                this.showCompletionSummary = true;
            }
        } catch (err) {
            console.error('Error loading completion summary:', err);
        }
    }

    // ================================================================
    //  SKIP VISIT
    // ================================================================

    handleToggleSkip() {
        this.showSkipReason = !this.showSkipReason;
        if (!this.showSkipReason) {
            this.skipReason = '';
        }
    }

    handleSkipReasonChange(event) {
        this.skipReason = event.detail.value;
    }

    async handleConfirmSkip() {
        if (!this.skipReason) {
            this._showToast('Warning', 'Please select a skip reason.', 'warning');
            return;
        }

        this.isProcessing = true;
        try {
            await skipVisit({ visitId: this.recordId, skipReason: this.skipReason });
            this.isVisitCompleted = true;
            this.showSkipReason = false;
            this._showToast('Success', 'Visit skipped successfully.', 'success');
        } catch (err) {
            this._showToast('Error', 'Skip failed: ' + this._reduceErrors(err), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // ================================================================
    //  NON-PRODUCTIVE
    // ================================================================

    handleMarkNonProductive() {
        this.showNonProductiveReason = !this.showNonProductiveReason;
        if (!this.showNonProductiveReason) {
            this.nonProductiveReason = '';
            this.nonProductiveComments = '';
        }
    }

    handleNonProductiveReasonChange(event) {
        this.nonProductiveReason = event.detail.value;
    }

    handleNonProductiveCommentsChange(event) {
        this.nonProductiveComments = event.target.value;
    }

    // ================================================================
    //  ACTIVITIES
    // ================================================================

    handleToggleActivity(event) {
        const activityId = event.currentTarget.dataset.activityId;
        this.visitActivities = this.visitActivities.map(activity => {
            if (activity.id === activityId) {
                const completed = !activity.completed;
                return {
                    ...activity,
                    completed,
                    cardClass: completed ? 'activity-card activity-completed' : 'activity-card'
                };
            }
            return activity;
        });
    }

    // ================================================================
    //  NOTES
    // ================================================================

    handleVisitNotesChange(event) {
        this.visitNotes = event.target.value;
    }

    // ================================================================
    //  GEOFENCE OVERRIDE
    // ================================================================

    handleGeofenceOverrideReasonChange(event) {
        this.geofenceOverrideReason = event.target.value;
    }

    // ================================================================
    //  TIMER
    // ================================================================

    _startTimer() {
        this.visitDuration = 0;
        this.timerInterval = setInterval(() => {
            this.visitDuration++;
        }, 1000);
    }

    _stopTimer() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }
    }

    // ================================================================
    //  UTILITIES
    // ================================================================

    _padZero(num) {
        return num < 10 ? '0' + num : '' + num;
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error.body) {
            if (error.body.message) return error.body.message;
            if (error.body.fieldErrors) {
                return Object.values(error.body.fieldErrors)
                    .flat()
                    .map(e => e.message)
                    .join(', ');
            }
        }
        if (error.message) return error.message;
        return 'Unknown error';
    }
}
