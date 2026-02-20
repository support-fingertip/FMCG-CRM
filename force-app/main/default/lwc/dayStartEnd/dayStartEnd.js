import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import startDay from '@salesforce/apex/DayAttendanceController.startDay';
import endDay from '@salesforce/apex/DayAttendanceController.endDay';
import getDayStats from '@salesforce/apex/DayAttendanceController.getDayStats';
import getCurrentDayAttendance from '@salesforce/apex/DayAttendanceController.getCurrentDayAttendance';

export default class DayStartEnd extends LightningElement {
    @track dayRecord = {};
    @track isStarted = false;
    @track stats = {
        plannedVisits: 0,
        completedVisits: 0,
        productivePercent: 0,
        productiveCalls: 0,
        nonProductiveCalls: 0,
        ordersToday: 0,
        orderValue: 0,
        orderValueFormatted: '0',
        collectionTotal: 0,
        collectionTotalFormatted: '0',
        distanceCovered: '0.0'
    };

    isProcessing = false;
    showEndDayModal = false;
    dayDuration = 0;
    timerInterval = null;
    clockInterval = null;
    statsInterval = null;
    currentTime = new Date();
    location = { latitude: null, longitude: null };
    batteryLevel = 'N/A';
    networkStatus = 'Online';
    dayStartTime = null;

    startPhotoPreview = null;
    startPhotoData = null;
    endPhotoPreview = null;
    endPhotoData = null;
    endDayRemarks = '';

    get todayDateDisplay() {
        return new Date().toLocaleDateString('en-IN', {
            weekday: 'long',
            day: '2-digit',
            month: 'long',
            year: 'numeric'
        });
    }

    get currentTimeDisplay() {
        return this.currentTime.toLocaleTimeString('en-IN', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
            hour12: true
        });
    }

    get locationStatus() {
        if (this.location.latitude && this.location.longitude) {
            return 'Captured (' +
                this.location.latitude.toFixed(4) + ', ' +
                this.location.longitude.toFixed(4) + ')';
        }
        return 'Fetching...';
    }

    get dayStartTimeDisplay() {
        if (!this.dayStartTime) return '';
        return this.dayStartTime.toLocaleTimeString('en-IN', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        });
    }

    get dayDurationDisplay() {
        const hours = Math.floor(this.dayDuration / 3600);
        const minutes = Math.floor((this.dayDuration % 3600) / 60);
        const seconds = this.dayDuration % 60;
        return this.padZero(hours) + ':' + this.padZero(minutes) + ':' + this.padZero(seconds);
    }

    get progressBarStyle() {
        const pct = this.stats.plannedVisits > 0
            ? Math.round((this.stats.completedVisits / this.stats.plannedVisits) * 100)
            : 0;
        const color = pct >= 80 ? '#2e844a' : pct >= 50 ? '#dd7a01' : '#ea001e';
        return 'width: ' + Math.min(pct, 100) + '%; background-color: ' + color;
    }

    connectedCallback() {
        this.captureLocation();
        this.getBatteryInfo();
        this.checkNetworkStatus();
        this.checkCurrentDayAttendance();

        // Update clock every second
        this.clockInterval = setInterval(() => {
            this.currentTime = new Date();
        }, 1000);
    }

    disconnectedCallback() {
        if (this.timerInterval) clearInterval(this.timerInterval);
        if (this.clockInterval) clearInterval(this.clockInterval);
        if (this.statsInterval) clearInterval(this.statsInterval);
    }

    async checkCurrentDayAttendance() {
        try {
            const result = await getCurrentDayAttendance({});
            if (result && result.Id) {
                this.dayRecord = result;
                this.isStarted = true;
                this.dayStartTime = new Date(result.Start_Time__c || result.CreatedDate);

                // Calculate elapsed duration
                const now = new Date();
                this.dayDuration = Math.floor((now - this.dayStartTime) / 1000);
                this.startDayTimer();
                this.loadDayStats();
                this.startStatsPolling();
            }
        } catch (error) {
            console.error('Error checking attendance:', error);
        }
    }

    captureLocation() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.location = {
                        latitude: position.coords.latitude,
                        longitude: position.coords.longitude,
                        accuracy: position.coords.accuracy
                    };
                },
                (error) => {
                    console.error('Location error:', error);
                    this.showToast('Warning', 'Unable to get GPS location', 'warning');
                },
                { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
            );
        }
    }

    async getBatteryInfo() {
        try {
            if (navigator.getBattery) {
                const battery = await navigator.getBattery();
                this.batteryLevel = Math.round(battery.level * 100) + '%' +
                    (battery.charging ? ' (Charging)' : '');
                battery.addEventListener('levelchange', () => {
                    this.batteryLevel = Math.round(battery.level * 100) + '%' +
                        (battery.charging ? ' (Charging)' : '');
                });
            }
        } catch (error) {
            this.batteryLevel = 'N/A';
        }
    }

    checkNetworkStatus() {
        this.networkStatus = navigator.onLine ? 'Online' : 'Offline';
        window.addEventListener('online', () => { this.networkStatus = 'Online'; });
        window.addEventListener('offline', () => { this.networkStatus = 'Offline'; });
    }

    triggerStartPhotoCapture() {
        const fileInput = this.template.querySelector('.day-start-panel input[type="file"]');
        if (fileInput) fileInput.click();
    }

    handleStartPhotoCapture(event) {
        const file = event.target.files[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = () => {
            this.startPhotoPreview = reader.result;
            this.startPhotoData = reader.result.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    removeStartPhoto() {
        this.startPhotoPreview = null;
        this.startPhotoData = null;
    }

    triggerEndPhotoCapture() {
        const fileInput = this.template.querySelector('.slds-modal__content input[type="file"]');
        if (fileInput) fileInput.click();
    }

    handleEndPhotoCapture(event) {
        const file = event.target.files[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = () => {
            this.endPhotoPreview = reader.result;
            this.endPhotoData = reader.result.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    async handleStartDay() {
        if (!this.location.latitude || !this.location.longitude) {
            this.showToast('Warning', 'Please wait for location to be captured', 'warning');
            this.captureLocation();
            return;
        }

        this.isProcessing = true;
        try {
            const dayData = {
                startLatitude: this.location.latitude,
                startLongitude: this.location.longitude,
                startPhoto: this.startPhotoData,
                batteryLevel: this.batteryLevel,
                networkStatus: this.networkStatus
            };

            const result = await startDay({ dayJson: JSON.stringify(dayData) });
            this.dayRecord = result;
            this.isStarted = true;
            this.dayStartTime = new Date();
            this.dayDuration = 0;
            this.startDayTimer();
            this.loadDayStats();
            this.startStatsPolling();

            this.showToast('Success', 'Day started successfully! Have a productive day!', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to start day: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    handleEndDayClick() {
        this.showEndDayModal = true;
        this.loadDayStats(); // Refresh stats for the modal
    }

    closeEndDayModal() {
        this.showEndDayModal = false;
    }

    handleEndRemarksChange(event) {
        this.endDayRemarks = event.target.value;
    }

    async handleEndDay() {
        this.captureLocation();
        this.isProcessing = true;

        try {
            const endData = {
                dayId: this.dayRecord.Id,
                endLatitude: this.location.latitude,
                endLongitude: this.location.longitude,
                endPhoto: this.endPhotoData,
                duration: this.dayDuration,
                remarks: this.endDayRemarks,
                completedVisits: this.stats.completedVisits,
                productiveCalls: this.stats.productiveCalls,
                ordersBooked: this.stats.ordersToday,
                orderValue: this.stats.orderValue,
                collectionTotal: this.stats.collectionTotal,
                distanceCovered: parseFloat(this.stats.distanceCovered) || 0
            };

            await endDay({ dayJson: JSON.stringify(endData) });

            this.stopTimers();
            this.isStarted = false;
            this.showEndDayModal = false;
            this.dayRecord = {};

            this.showToast('Success', 'Day ended successfully! Great work today!', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to end day: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    async loadDayStats() {
        try {
            const result = await getDayStats({ dayId: this.dayRecord.Id });
            if (result) {
                this.calculateStats(result);
            }
        } catch (error) {
            console.error('Error loading day stats:', error);
        }
    }

    calculateStats(data) {
        const completed = data.Completed_Visits__c || 0;
        const planned = data.Planned_Visits__c || 0;
        const productive = data.Productive_Calls__c || 0;
        const nonProductive = data.Non_Productive_Calls__c || 0;
        const productivePercent = completed > 0 ? Math.round((productive / completed) * 100) : 0;

        this.stats = {
            plannedVisits: planned,
            completedVisits: completed,
            productivePercent: productivePercent,
            productiveCalls: productive,
            nonProductiveCalls: nonProductive,
            ordersToday: data.Orders_Today__c || 0,
            orderValue: data.Order_Value__c || 0,
            orderValueFormatted: this.formatCurrency(data.Order_Value__c || 0),
            collectionTotal: data.Collection_Total__c || 0,
            collectionTotalFormatted: this.formatCurrency(data.Collection_Total__c || 0),
            distanceCovered: (data.Distance_Covered__c || 0).toFixed(1)
        };
    }

    startDayTimer() {
        if (this.timerInterval) clearInterval(this.timerInterval);
        this.timerInterval = setInterval(() => {
            this.dayDuration++;
        }, 1000);
    }

    startStatsPolling() {
        if (this.statsInterval) clearInterval(this.statsInterval);
        this.statsInterval = setInterval(() => {
            this.loadDayStats();
        }, 60000); // Refresh stats every minute
    }

    stopTimers() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }
        if (this.statsInterval) {
            clearInterval(this.statsInterval);
            this.statsInterval = null;
        }
    }

    padZero(num) {
        return num < 10 ? '0' + num : '' + num;
    }

    formatCurrency(value) {
        if (!value) return '0';
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: 'INR',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(value);
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
