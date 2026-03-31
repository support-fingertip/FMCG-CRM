import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getHomePageData from '@salesforce/apex/HomePageController.getHomePageData';

const TABS = {
    DASHBOARD: 'dashboard',
    FIELD_OPS: 'field_ops',
    SALES: 'sales',
    INVENTORY: 'inventory',
    HR: 'hr',
    ADMIN: 'admin'
};

export default class HomePage extends NavigationMixin(LightningElement) {

    @track activeTab = TABS.DASHBOARD;
    @track isLoading = true;
    @track data = {};
    @track currentTime = '';

    _clockInterval;

    // ── Lifecycle ──

    connectedCallback() {
        this.loadData();
        this.updateClock();
        this._clockInterval = setInterval(() => this.updateClock(), 60000);
    }

    disconnectedCallback() {
        if (this._clockInterval) clearInterval(this._clockInterval);
    }

    // ── Data Loading ──

    loadData() {
        this.isLoading = true;
        getHomePageData()
            .then(result => {
                this.data = result;
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Failed to load dashboard data', 'error');
                console.error('HomePage load error:', error);
            });
    }

    updateClock() {
        const now = new Date();
        const options = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
        this.currentTime = now.toLocaleDateString('en-IN', options);
    }

    // ── Tab Management ──

    get tabItems() {
        return [
            { key: TABS.DASHBOARD, label: 'Dashboard', icon: 'standard:home' },
            { key: TABS.FIELD_OPS, label: 'Field Ops', icon: 'standard:visit' },
            { key: TABS.SALES, label: 'Sales', icon: 'standard:opportunity' },
            { key: TABS.INVENTORY, label: 'Inventory', icon: 'standard:product' },
            { key: TABS.HR, label: 'HR & Expense', icon: 'standard:people' },
            { key: TABS.ADMIN, label: 'Admin', icon: 'standard:settings' }
        ].map(t => ({
            ...t,
            cssClass: 'hp-tab-item' + (t.key === this.activeTab ? ' hp-tab-active' : '')
        }));
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    // ── Tab Visibility ──

    get isDashboard() { return this.activeTab === TABS.DASHBOARD; }
    get isFieldOps() { return this.activeTab === TABS.FIELD_OPS; }
    get isSales() { return this.activeTab === TABS.SALES; }
    get isInventory() { return this.activeTab === TABS.INVENTORY; }
    get isHr() { return this.activeTab === TABS.HR; }
    get isAdmin() { return this.activeTab === TABS.ADMIN; }

    // ── Dashboard Stat Cards ──

    get visitProgress() {
        if (!this.data || !this.data.todayVisitCount) return 0;
        return Math.round((this.data.completedVisitCount / this.data.todayVisitCount) * 100);
    }

    get visitProgressStyle() {
        return `width: ${this.visitProgress}%`;
    }

    get attendanceBadgeClass() {
        return this.data.isDayStarted ? 'hp-badge hp-badge-success' : 'hp-badge hp-badge-warning';
    }

    // ── Navigation Helpers (open in new tab) ──

    navigateTo(event) {
        const tabName = event.currentTarget.dataset.target;
        if (!tabName) return;

        this[NavigationMixin.GenerateUrl]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: tabName
            }
        }).then(url => {
            window.open(url, '_blank');
        });
    }

    navigateToObject(event) {
        const objectName = event.currentTarget.dataset.object;
        if (!objectName) return;

        this[NavigationMixin.GenerateUrl]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: objectName,
                actionName: 'list'
            },
            state: {
                filterName: 'Recent'
            }
        }).then(url => {
            window.open(url, '_blank');
        });
    }

    handleRefresh() {
        this.loadData();
        this.showToast('Refreshed', 'Dashboard data updated', 'success');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
