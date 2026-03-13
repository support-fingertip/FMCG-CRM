import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import getSchemeStats from '@salesforce/apex/SchemeManagerController.getSchemeStats';
import getSchemes from '@salesforce/apex/SchemeManagerController.getSchemes';
import cloneScheme from '@salesforce/apex/SchemeManagerController.cloneScheme';
import updateSchemeStatus from '@salesforce/apex/SchemeManagerController.updateSchemeStatus';
import deleteScheme from '@salesforce/apex/SchemeManagerController.deleteScheme';
import getSchemeDetails from '@salesforce/apex/SchemeViewController.getSchemeDetails';
import calculateSchemeDiscount from '@salesforce/apex/SchemeViewController.calculateSchemeDiscount';

const STATUS_CONFIG = {
    'Draft':            { icon: 'utility:edit', class: 'status-draft', color: '#706e6b' },
    'Pending Approval': { icon: 'utility:clock', class: 'status-pending', color: '#dd7a01' },
    'Active':           { icon: 'utility:success', class: 'status-active', color: '#2e844a' },
    'Expired':          { icon: 'utility:warning', class: 'status-expired', color: '#ea001e' },
    'Cancelled':        { icon: 'utility:ban', class: 'status-cancelled', color: '#706e6b' }
};

const CATEGORY_COLORS = {
    'Free Products':      { bg: '#fff8e1', color: '#dd7a01', short: 'FP' },
    'Discount in %':      { bg: '#e8f4fd', color: '#0176d3', short: '%' },
    'Discount in Value':  { bg: '#e6f7e9', color: '#2e844a', short: 'Rs' },
    'Reward Points':      { bg: '#f3e8ff', color: '#9b59b6', short: 'RP' }
};

const STATUS_OPTIONS = [
    { label: 'All Statuses', value: '' },
    { label: 'Draft', value: 'Draft' },
    { label: 'Pending Approval', value: 'Pending Approval' },
    { label: 'Active', value: 'Active' },
    { label: 'Expired', value: 'Expired' },
    { label: 'Cancelled', value: 'Cancelled' }
];

const CATEGORY_OPTIONS = [
    { label: 'All Categories', value: '' },
    { label: 'Free Products', value: 'Free Products' },
    { label: 'Discount in %', value: 'Discount in %' },
    { label: 'Discount in Value', value: 'Discount in Value' },
    { label: 'Reward Points', value: 'Reward Points' }
];

const TYPE_OPTIONS = [
    { label: 'All Types', value: '' },
    { label: 'Same Product (QTY)', value: 'Same Product (QTY)' },
    { label: 'Same Product (VAL)', value: 'Same Product (VAL)' },
    { label: 'Assorted Product (QTY)', value: 'Assorted Product (QTY)' },
    { label: 'Assorted Product (VAL)', value: 'Assorted Product (VAL)' },
    { label: 'Invoice Qty Based', value: 'Invoice Qty Based' },
    { label: 'Invoice Val Based', value: 'Invoice Val Based' }
];

const CHANNEL_OPTIONS = [
    { label: 'All Channels', value: '' },
    { label: 'GT', value: 'GT' },
    { label: 'MT', value: 'MT' },
    { label: 'E-Commerce', value: 'E-Commerce' }
];

export default class SchemeManager extends NavigationMixin(LightningElement) {
    // Filter options
    statusOptions = STATUS_OPTIONS;
    categoryOptions = CATEGORY_OPTIONS;
    typeOptions = TYPE_OPTIONS;
    channelOptions = CHANNEL_OPTIONS;

    // Stats
    @track stats = {};

    // List state
    @track schemes = [];
    totalCount = 0;
    totalPages = 0;
    pageNumber = 1;
    pageSize = 25;

    // Filters
    filterStatus = '';
    filterCategory = '';
    filterType = '';
    filterChannel = '';
    searchTerm = '';
    sortField = 'CreatedDate';
    sortDirection = 'DESC';

    // UI state
    isLoading = false;
    currentView = 'list'; // list, detail
    @track selectedScheme = null;
    showDeleteConfirm = false;
    deleteTargetId = null;
    showStatusModal = false;
    statusTargetId = null;
    statusTargetName = '';
    newStatusValue = '';

    // Calculator
    calculatorQty = 0;
    calculatorValue = 0;
    @track calculatorResult = null;

    // Search debounce
    _searchTimer;

    // ── Lifecycle ────────────────────────────────────────────────────────

    connectedCallback() {
        this.loadStats();
        this.loadSchemes();
    }

    // ── Stats ────────────────────────────────────────────────────────────

    async loadStats() {
        try {
            this.stats = await getSchemeStats();
        } catch (e) {
            // non-blocking
        }
    }

    get statCards() {
        return [
            { key: 'active',  label: 'Active',           value: this.stats.activeSchemes || 0,   cls: 'stat-card stat-active' },
            { key: 'draft',   label: 'Draft',             value: this.stats.draftSchemes || 0,    cls: 'stat-card stat-draft' },
            { key: 'pending', label: 'Pending Approval',  value: this.stats.pendingApproval || 0, cls: 'stat-card stat-pending' },
            { key: 'expired', label: 'Expired',           value: this.stats.expiredSchemes || 0,  cls: 'stat-card stat-expired' },
            { key: 'total',   label: 'Total Schemes',     value: this.stats.totalSchemes || 0,    cls: 'stat-card stat-total' }
        ];
    }

    get totalBudgetFormatted() {
        return this.formatCurrency(this.stats.totalBudget || 0);
    }

    get totalBudgetUsedFormatted() {
        return this.formatCurrency(this.stats.totalBudgetUsed || 0);
    }

    get budgetUtilization() {
        const total = this.stats.totalBudget || 0;
        const used = this.stats.totalBudgetUsed || 0;
        if (total === 0) return 0;
        return Math.round((used / total) * 100);
    }

    get budgetBarStyle() {
        return 'width: ' + this.budgetUtilization + '%';
    }

    get detailBudgetBarStyle() {
        if (!this.selectedScheme) return 'width: 0%';
        return 'width: ' + this.selectedScheme.budgetPercent + '%';
    }

    // ── List Loading ─────────────────────────────────────────────────────

    async loadSchemes() {
        this.isLoading = true;
        try {
            const result = await getSchemes({
                status: this.filterStatus || null,
                category: this.filterCategory || null,
                schemeType: this.filterType || null,
                channel: this.filterChannel || null,
                searchTerm: this.searchTerm || null,
                pageSize: this.pageSize,
                pageNumber: this.pageNumber,
                sortField: this.sortField,
                sortDirection: this.sortDirection
            });

            this.schemes = (result.schemes || []).map(s => this.mapSchemeRow(s));
            this.totalCount = result.totalCount || 0;
            this.totalPages = result.totalPages || 0;
            this.pageNumber = result.pageNumber || 1;
        } catch (error) {
            this.showToast('Error', 'Failed to load schemes: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    mapSchemeRow(scheme) {
        const catConfig = CATEGORY_COLORS[scheme.Scheme_Category__c] || { bg: '#f3f3f3', color: '#706e6b', short: '?' };
        const statusConfig = STATUS_CONFIG[scheme.Status__c] || STATUS_CONFIG['Draft'];
        const isSelected = this.selectedScheme && this.selectedScheme.id === scheme.Id;

        const buyProducts = scheme.Scheme_Products__r
            ? scheme.Scheme_Products__r.filter(p => p.Is_Buy_Product__c)
            : [];
        const getProducts = scheme.Scheme_Products__r
            ? scheme.Scheme_Products__r.filter(p => p.Is_Get_Product__c)
            : [];

        return {
            id: scheme.Id,
            name: scheme.Name,
            code: scheme.Scheme_Code__c || '',
            category: scheme.Scheme_Category__c || '',
            schemeType: scheme.Scheme_Type__c || '',
            description: scheme.Description__c || '',
            status: scheme.Status__c || 'Draft',
            statusClass: 'status-badge ' + statusConfig.class,
            statusIcon: statusConfig.icon,
            categoryShort: catConfig.short,
            categoryBadgeStyle: 'background-color: ' + catConfig.bg + '; color: ' + catConfig.color,
            startDate: this.formatDate(scheme.Start_Date__c),
            endDate: this.formatDate(scheme.End_Date__c),
            startDateRaw: scheme.Start_Date__c,
            endDateRaw: scheme.End_Date__c,
            channel: scheme.Applicable_Channel__c || 'All',
            priority: scheme.Priority__c || '-',
            isStackable: scheme.Is_Stackable__c || false,
            budgetAmount: scheme.Budget_Amount__c,
            budgetUsed: scheme.Budget_Used__c,
            budgetRemaining: scheme.Budget_Remaining__c,
            budgetFormatted: this.formatCurrency(scheme.Budget_Amount__c || 0),
            benefitSummary: this.getBenefitSummary(scheme),
            triggerSummary: this.getTriggerSummary(scheme),
            buyProductCount: buyProducts.length,
            getProductCount: getProducts.length,
            productBadges: buyProducts.slice(0, 3).map(p => ({
                key: p.Id,
                name: p.Product_Ext__r ? p.Product_Ext__r.Name : 'Product',
                classification: p.Product_Classification__c || '',
                classificationClass: p.Product_Classification__c === 'Must Sell' ? 'badge-must-sell' :
                                     p.Product_Classification__c === 'Focused Sell' ? 'badge-focused-sell' : ''
            })),
            hasSlabs: scheme.Scheme_Slabs__r && scheme.Scheme_Slabs__r.length > 0,
            hasMappings: scheme.Scheme_Mappings__r && scheme.Scheme_Mappings__r.length > 0,
            cardClass: 'scheme-row' + (isSelected ? ' scheme-row-selected' : ''),
            createdDate: this.formatDate(scheme.CreatedDate),
            isDraft: scheme.Status__c === 'Draft',
            isActive: scheme.Status__c === 'Active',
            isPending: scheme.Status__c === 'Pending Approval',
            canEdit: scheme.Status__c === 'Draft' || scheme.Status__c === 'Active',
            canDelete: scheme.Status__c === 'Draft' || scheme.Status__c === 'Expired' || scheme.Status__c === 'Cancelled',
            canActivate: scheme.Status__c === 'Draft',
            canDeactivate: scheme.Status__c === 'Active',
            canSubmit: scheme.Status__c === 'Draft'
        };
    }

    getBenefitSummary(scheme) {
        const cat = scheme.Scheme_Category__c;
        if (cat === 'Free Products') {
            const name = scheme.Free_Product_Ext__r ? scheme.Free_Product_Ext__r.Name : 'product';
            return 'Get ' + (scheme.Free_Quantity__c || 0) + ' ' + name + ' free';
        } else if (cat === 'Discount in %') {
            return (scheme.Discount_Percent__c || 0) + '% discount';
        } else if (cat === 'Discount in Value') {
            return this.formatCurrency(scheme.Price_Discount__c || scheme.Discount_Amount__c || 0) + ' off';
        } else if (cat === 'Reward Points') {
            return (scheme.Reward_Points__c || 0) + ' reward points';
        }
        return '';
    }

    getTriggerSummary(scheme) {
        const type = scheme.Scheme_Type__c;
        if (type === 'Same Product (QTY)') return 'Min ' + (scheme.Min_Quantity__c || 0) + ' qty';
        if (type === 'Same Product (VAL)') return 'MOV ' + this.formatCurrency(scheme.MOV__c || 0);
        if (type === 'Assorted Product (QTY)') return 'Assorted (qty)';
        if (type === 'Assorted Product (VAL)') return 'Assorted (val)';
        if (type === 'Invoice Qty Based') return 'Inv qty ' + (scheme.Invoice_Qty_Threshold__c || 0);
        if (type === 'Invoice Val Based') return 'Inv val ' + this.formatCurrency(scheme.Invoice_Val_Threshold__c || 0);
        return type || '';
    }

    // ── View Management ──────────────────────────────────────────────────

    get isListView() { return this.currentView === 'list'; }
    get isDetailView() { return this.currentView === 'detail'; }
    get hasSchemes() { return this.schemes.length > 0; }
    get showPagination() { return this.totalPages > 1; }
    get isFirstPage() { return this.pageNumber <= 1; }
    get isLastPage() { return this.pageNumber >= this.totalPages; }

    get paginationInfo() {
        const start = ((this.pageNumber - 1) * this.pageSize) + 1;
        const end = Math.min(this.pageNumber * this.pageSize, this.totalCount);
        return start + '-' + end + ' of ' + this.totalCount;
    }

    get sortIconName() {
        return this.sortDirection === 'ASC' ? 'utility:arrowup' : 'utility:arrowdown';
    }

    get sortLabel() {
        const labels = {
            'CreatedDate': 'Created Date',
            'Name': 'Name',
            'Status__c': 'Status',
            'Start_Date__c': 'Start Date',
            'End_Date__c': 'End Date',
            'Priority__c': 'Priority'
        };
        return labels[this.sortField] || this.sortField;
    }

    get sortOptions() {
        return [
            { label: 'Created Date', value: 'CreatedDate' },
            { label: 'Name', value: 'Name' },
            { label: 'Status', value: 'Status__c' },
            { label: 'Start Date', value: 'Start_Date__c' },
            { label: 'End Date', value: 'End_Date__c' },
            { label: 'Priority', value: 'Priority__c' }
        ];
    }

    // ── Filter Handlers ──────────────────────────────────────────────────

    handleSearchInput(event) {
        const term = event.detail.value;
        clearTimeout(this._searchTimer);
        this._searchTimer = setTimeout(() => {
            this.searchTerm = term;
            this.pageNumber = 1;
            this.loadSchemes();
        }, 400);
    }

    handleStatusFilter(event) {
        this.filterStatus = event.detail.value;
        this.pageNumber = 1;
        this.loadSchemes();
    }

    handleCategoryFilter(event) {
        this.filterCategory = event.detail.value;
        this.pageNumber = 1;
        this.loadSchemes();
    }

    handleTypeFilter(event) {
        this.filterType = event.detail.value;
        this.pageNumber = 1;
        this.loadSchemes();
    }

    handleChannelFilter(event) {
        this.filterChannel = event.detail.value;
        this.pageNumber = 1;
        this.loadSchemes();
    }

    handleClearFilters() {
        this.filterStatus = '';
        this.filterCategory = '';
        this.filterType = '';
        this.filterChannel = '';
        this.searchTerm = '';
        this.pageNumber = 1;
        this.loadSchemes();
    }

    handleSortChange(event) {
        this.sortField = event.detail.value;
        this.pageNumber = 1;
        this.loadSchemes();
    }

    handleToggleSortDir() {
        this.sortDirection = this.sortDirection === 'ASC' ? 'DESC' : 'ASC';
        this.loadSchemes();
    }

    handleStatCardClick(event) {
        const key = event.currentTarget.dataset.key;
        const statusMap = {
            'active': 'Active',
            'draft': 'Draft',
            'pending': 'Pending Approval',
            'expired': 'Expired',
            'total': ''
        };
        this.filterStatus = statusMap[key] || '';
        this.pageNumber = 1;
        this.loadSchemes();
    }

    // ── Pagination ───────────────────────────────────────────────────────

    handlePrevPage() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.loadSchemes();
        }
    }

    handleNextPage() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.loadSchemes();
        }
    }

    // ── Scheme Actions ───────────────────────────────────────────────────

    handleNewScheme() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'Scheme_Definition' }
        });
    }

    handleSchemeClick(event) {
        const schemeId = event.currentTarget.dataset.id;
        this.openSchemeDetail(schemeId);
    }

    async openSchemeDetail(schemeId) {
        this.isLoading = true;
        try {
            const details = await getSchemeDetails({ schemeId });
            this.selectedScheme = this.mapSchemeDetail(details);
            this.currentView = 'detail';
            this.calculatorResult = null;
            this.calculatorQty = 0;
            this.calculatorValue = 0;
        } catch (error) {
            this.showToast('Error', 'Failed to load scheme: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    mapSchemeDetail(scheme) {
        const catConfig = CATEGORY_COLORS[scheme.Scheme_Category__c] || { bg: '#f3f3f3', color: '#706e6b', short: '?' };
        const statusConfig = STATUS_CONFIG[scheme.Status__c] || STATUS_CONFIG['Draft'];

        const buyProducts = (scheme.Scheme_Products__r || [])
            .filter(p => p.Is_Buy_Product__c)
            .map(p => ({
                id: p.Id,
                name: p.Product_Ext__r ? p.Product_Ext__r.Name : 'Product',
                sku: p.Product_Ext__r ? (p.Product_Ext__r.SKU_Code__c || '') : '',
                minQty: p.Min_Quantity__c || 0,
                classification: p.Product_Classification__c || '',
                classificationClass: p.Product_Classification__c === 'Must Sell' ? 'classification-must-sell' :
                                     p.Product_Classification__c === 'Focused Sell' ? 'classification-focused-sell' : '',
                isMustSell: p.Product_Classification__c === 'Must Sell',
                isFocusedSell: p.Product_Classification__c === 'Focused Sell'
            }));

        const getProducts = (scheme.Scheme_Products__r || [])
            .filter(p => p.Is_Get_Product__c)
            .map(p => ({
                id: p.Id,
                name: p.Product_Ext__r ? p.Product_Ext__r.Name : 'Product',
                sku: p.Product_Ext__r ? (p.Product_Ext__r.SKU_Code__c || '') : ''
            }));

        const slabs = (scheme.Scheme_Slabs__r || []).map((slab, idx) => ({
            id: slab.Id || 'slab_' + idx,
            slabType: slab.Slab_Type__c || 'Value',
            minValue: slab.Min_Value__c || 0,
            maxValue: slab.Max_Value__c != null ? slab.Max_Value__c : 'Unlimited',
            discountType: slab.Discount_Type__c || '',
            discountPercent: slab.Discount_Percent__c || slab.Discount_Value__c || 0,
            freeQty: slab.Free_Quantity__c || 0,
            freeProduct: slab.Free_Product_Ext__r ? slab.Free_Product_Ext__r.Name : '',
            priceDiscount: slab.Price_Discount__c || 0,
            rewardPoints: slab.Reward_Points__c || 0,
            benefitText: this.getSlabBenefitText(slab)
        }));

        const mappings = (scheme.Scheme_Mappings__r || []).map(m => ({
            id: m.Id,
            zone: m.Zone__c || '-',
            subZone: m.Sub_Zone__c || '-',
            district: m.District__c || '-',
            area: m.Area__c || '-',
            customerType: m.Customer_Type__c || '-',
            account: m.Account__r ? m.Account__r.Name : '-'
        }));

        return {
            id: scheme.Id,
            name: scheme.Name,
            code: scheme.Scheme_Code__c || '',
            category: scheme.Scheme_Category__c || '',
            schemeType: scheme.Scheme_Type__c || '',
            description: scheme.Description__c || '',
            status: scheme.Status__c || 'Draft',
            statusClass: 'status-badge-lg ' + statusConfig.class,
            statusIcon: statusConfig.icon,
            categoryShort: catConfig.short,
            categoryBadgeStyle: 'background-color: ' + catConfig.bg + '; color: ' + catConfig.color,
            startDate: this.formatDate(scheme.Start_Date__c),
            endDate: this.formatDate(scheme.End_Date__c),
            channel: scheme.Applicable_Channel__c || 'All',
            outletType: scheme.Applicable_Outlet_Type__c || 'All',
            region: scheme.Applicable_Region__c || 'All',
            priority: scheme.Priority__c || '-',
            isStackable: scheme.Is_Stackable__c || false,
            stackableLabel: scheme.Is_Stackable__c ? 'Yes' : 'No',
            budgetAmount: this.formatCurrency(scheme.Budget_Amount__c || 0),
            budgetUsed: this.formatCurrency(scheme.Budget_Used__c || 0),
            budgetRemaining: this.formatCurrency(scheme.Budget_Remaining__c || 0),
            hasBudget: (scheme.Budget_Amount__c || 0) > 0,
            budgetPercent: scheme.Budget_Amount__c > 0
                ? Math.round(((scheme.Budget_Used__c || 0) / scheme.Budget_Amount__c) * 100) : 0,
            benefitSummary: this.getBenefitSummary(scheme),
            triggerSummary: this.getTriggerSummary(scheme),
            discountPercent: scheme.Discount_Percent__c,
            discountAmount: scheme.Discount_Amount__c,
            priceDiscount: scheme.Price_Discount__c,
            rewardPoints: scheme.Reward_Points__c,
            mov: scheme.MOV__c,
            freeQty: scheme.Free_Quantity__c,
            freeProductName: scheme.Free_Product_Ext__r ? scheme.Free_Product_Ext__r.Name : '',
            minQty: scheme.Min_Quantity__c,
            maxQty: scheme.Max_Quantity__c,
            invoiceQtyThreshold: scheme.Invoice_Qty_Threshold__c,
            invoiceValThreshold: scheme.Invoice_Val_Threshold__c,
            maxDiscountCap: scheme.Max_Discount_Cap__c,
            buyProducts,
            getProducts,
            slabs,
            mappings,
            hasBuyProducts: buyProducts.length > 0,
            hasGetProducts: getProducts.length > 0,
            hasSlabs: slabs.length > 0,
            hasMappings: mappings.length > 0,
            hasMustSellProducts: buyProducts.some(p => p.isMustSell),
            hasFocusedSellProducts: buyProducts.some(p => p.isFocusedSell),
            isDraft: scheme.Status__c === 'Draft',
            isActive: scheme.Status__c === 'Active',
            canEdit: scheme.Status__c === 'Draft' || scheme.Status__c === 'Active',
            canDelete: scheme.Status__c !== 'Active',
            canActivate: scheme.Status__c === 'Draft',
            canDeactivate: scheme.Status__c === 'Active',
            canSubmit: scheme.Status__c === 'Draft'
        };
    }

    getSlabBenefitText(slab) {
        const dt = slab.Discount_Type__c;
        if (dt === 'Percent') return (slab.Discount_Value__c || slab.Discount_Percent__c || 0) + '%';
        if (dt === 'Amount') return this.formatCurrency(slab.Discount_Value__c || slab.Discount_Amount__c || 0);
        if (dt === 'Free Product') return (slab.Free_Quantity__c || 0) + ' free';
        if (dt === 'Price Discount') return this.formatCurrency(slab.Price_Discount__c || 0) + ' off';
        if (dt === 'Reward Points') return (slab.Reward_Points__c || 0) + ' pts';
        return '-';
    }

    handleBackToList() {
        this.currentView = 'list';
        this.selectedScheme = null;
        this.loadSchemes();
        this.loadStats();
    }

    // ── Edit Scheme ──────────────────────────────────────────────────────

    handleEditScheme(event) {
        const schemeId = event.currentTarget.dataset.id || (this.selectedScheme && this.selectedScheme.id);
        if (!schemeId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: schemeId,
                objectApiName: 'Scheme__c',
                actionName: 'edit'
            }
        });
    }

    handleEditSchemeWizard(event) {
        const schemeId = event.currentTarget.dataset.id || (this.selectedScheme && this.selectedScheme.id);
        if (!schemeId) return;
        // Navigate to the Scheme Definition tab with recordId parameter
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: {
                componentName: 'c__schemeDefinition'
            },
            state: {
                c__recordId: schemeId
            }
        });
    }

    handleViewRecord() {
        if (!this.selectedScheme) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.selectedScheme.id,
                objectApiName: 'Scheme__c',
                actionName: 'view'
            }
        });
    }

    // ── Clone Scheme ─────────────────────────────────────────────────────

    async handleCloneScheme(event) {
        const schemeId = event.currentTarget.dataset.id || (this.selectedScheme && this.selectedScheme.id);
        if (!schemeId) return;

        this.isLoading = true;
        try {
            const newId = await cloneScheme({ schemeId });
            this.showToast('Success', 'Scheme cloned successfully', 'success');
            this.openSchemeDetail(newId);
            this.loadStats();
        } catch (error) {
            this.showToast('Error', 'Clone failed: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Status Change ────────────────────────────────────────────────────

    handleStatusChange(event) {
        const schemeId = event.currentTarget.dataset.id || (this.selectedScheme && this.selectedScheme.id);
        const newStatus = event.currentTarget.dataset.status;
        if (!schemeId || !newStatus) return;

        this.statusTargetId = schemeId;
        this.newStatusValue = newStatus;
        const scheme = this.schemes.find(s => s.id === schemeId) || this.selectedScheme;
        this.statusTargetName = scheme ? scheme.name : '';
        this.showStatusModal = true;
    }

    async handleConfirmStatusChange() {
        this.showStatusModal = false;
        this.isLoading = true;
        try {
            await updateSchemeStatus({ schemeId: this.statusTargetId, newStatus: this.newStatusValue });
            this.showToast('Success', 'Status updated to ' + this.newStatusValue, 'success');

            if (this.isDetailView && this.selectedScheme) {
                await this.openSchemeDetail(this.statusTargetId);
            }
            this.loadSchemes();
            this.loadStats();
        } catch (error) {
            this.showToast('Error', 'Status change failed: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancelStatusChange() {
        this.showStatusModal = false;
    }

    get statusChangeMessage() {
        return 'Change status of "' + this.statusTargetName + '" to ' + this.newStatusValue + '?';
    }

    // ── Delete Scheme ────────────────────────────────────────────────────

    handleDeleteScheme(event) {
        const schemeId = event.currentTarget.dataset.id || (this.selectedScheme && this.selectedScheme.id);
        if (!schemeId) return;
        this.deleteTargetId = schemeId;
        this.showDeleteConfirm = true;
    }

    async handleConfirmDelete() {
        this.showDeleteConfirm = false;
        this.isLoading = true;
        try {
            await deleteScheme({ schemeId: this.deleteTargetId });
            this.showToast('Success', 'Scheme deleted', 'success');

            if (this.isDetailView) {
                this.currentView = 'list';
                this.selectedScheme = null;
            }
            this.loadSchemes();
            this.loadStats();
        } catch (error) {
            this.showToast('Error', 'Delete failed: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancelDelete() {
        this.showDeleteConfirm = false;
    }

    // ── Calculator ───────────────────────────────────────────────────────

    handleCalculatorQtyChange(event) {
        this.calculatorQty = parseInt(event.detail.value, 10) || 0;
    }

    handleCalculatorValueChange(event) {
        this.calculatorValue = parseFloat(event.detail.value) || 0;
    }

    async handleCalculate() {
        if (!this.selectedScheme) return;
        if (this.calculatorQty <= 0 && this.calculatorValue <= 0) {
            this.showToast('Warning', 'Enter quantity or value', 'warning');
            return;
        }

        try {
            const result = await calculateSchemeDiscount({
                schemeId: this.selectedScheme.id,
                quantity: this.calculatorQty,
                value: this.calculatorValue
            });

            if (result) {
                const grossAmount = this.calculatorValue || 0;
                const discountAmt = (result.discountAmount || 0) + (result.priceDiscount || 0);
                const netAmount = grossAmount - discountAmt;

                this.calculatorResult = {
                    grossAmountFormatted: this.formatCurrency(grossAmount),
                    discountFormatted: this.formatCurrency(discountAmt),
                    netAmountFormatted: this.formatCurrency(netAmount),
                    freeQty: result.freeQuantity || 0,
                    freeProductName: result.freeProductName || '',
                    rewardPoints: result.rewardPoints || 0,
                    effectiveDiscountPercent: grossAmount > 0
                        ? Math.round((discountAmt / grossAmount) * 100 * 100) / 100 : 0,
                    hasDiscount: discountAmt > 0,
                    hasFreeProduct: (result.freeQuantity || 0) > 0,
                    hasRewardPoints: (result.rewardPoints || 0) > 0
                };
            }
        } catch (error) {
            this.showToast('Error', 'Calculation failed: ' + this.reduceErrors(error), 'error');
        }
    }

    // ── Utilities ────────────────────────────────────────────────────────

    formatCurrency(value) {
        return new Intl.NumberFormat('en-IN', {
            style: 'currency', currency: 'INR', minimumFractionDigits: 0, maximumFractionDigits: 0
        }).format(value || 0);
    }

    formatDate(dateStr) {
        if (!dateStr) return '-';
        return new Date(dateStr).toLocaleDateString('en-IN', {
            day: '2-digit', month: 'short', year: 'numeric'
        });
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
