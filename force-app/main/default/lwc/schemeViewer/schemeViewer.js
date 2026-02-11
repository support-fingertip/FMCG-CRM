import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getActiveSchemes from '@salesforce/apex/SchemeViewerController.getActiveSchemes';
import getSchemeDetails from '@salesforce/apex/SchemeViewerController.getSchemeDetails';
import calculateSchemeDiscount from '@salesforce/apex/SchemeViewerController.calculateSchemeDiscount';

const SCHEME_TYPE_COLORS = {
    'Percentage Discount': { bg: '#e8f4fd', color: '#0176d3', short: '%' },
    'Flat Discount': { bg: '#e6f7e9', color: '#2e844a', short: 'F' },
    'Buy X Get Y Free': { bg: '#fff8e1', color: '#dd7a01', short: 'B+F' },
    'Slab Discount': { bg: '#f3e8ff', color: '#9b59b6', short: 'SL' },
    'Volume Discount': { bg: '#fff3e0', color: '#e67e22', short: 'VD' },
    'Combo Offer': { bg: '#fce4e4', color: '#ea001e', short: 'CO' }
};

export default class SchemeViewer extends LightningElement {
    @api accountId;

    @track activeSchemes = [];
    @track selectedScheme = null;
    @track calculatorResult = null;

    filterSchemeType = '';
    filterCategory = '';
    filterChannel = '';
    calculatorQty = 0;
    calculatorValue = 0;
    isLoading = false;

    get schemeTypeOptions() {
        return [
            { label: 'All Types', value: '' },
            { label: 'Percentage Discount', value: 'Percentage Discount' },
            { label: 'Flat Discount', value: 'Flat Discount' },
            { label: 'Buy X Get Y Free', value: 'Buy X Get Y Free' },
            { label: 'Slab Discount', value: 'Slab Discount' },
            { label: 'Volume Discount', value: 'Volume Discount' },
            { label: 'Combo Offer', value: 'Combo Offer' }
        ];
    }

    get categoryOptions() {
        return [
            { label: 'All Categories', value: '' },
            { label: 'Beverages', value: 'Beverages' },
            { label: 'Snacks', value: 'Snacks' },
            { label: 'Personal Care', value: 'Personal Care' },
            { label: 'Home Care', value: 'Home Care' },
            { label: 'Dairy', value: 'Dairy' },
            { label: 'Confectionery', value: 'Confectionery' }
        ];
    }

    get channelOptions() {
        return [
            { label: 'All Channels', value: '' },
            { label: 'General Trade', value: 'General Trade' },
            { label: 'Modern Trade', value: 'Modern Trade' },
            { label: 'E-Commerce', value: 'E-Commerce' },
            { label: 'Wholesale', value: 'Wholesale' },
            { label: 'Institutional', value: 'Institutional' }
        ];
    }

    get filteredSchemes() {
        return this.activeSchemes.filter(scheme => {
            const typeMatch = !this.filterSchemeType || scheme.type === this.filterSchemeType;
            const categoryMatch = !this.filterCategory || scheme.category === this.filterCategory;
            const channelMatch = !this.filterChannel || scheme.channel === this.filterChannel;
            return typeMatch && categoryMatch && channelMatch;
        });
    }

    get hasSchemes() {
        return this.filteredSchemes && this.filteredSchemes.length > 0;
    }

    connectedCallback() {
        this.loadSchemes();
    }

    async loadSchemes() {
        this.isLoading = true;
        try {
            const result = await getActiveSchemes({ accountId: this.accountId });
            this.activeSchemes = (result || []).map(scheme => {
                const typeConfig = SCHEME_TYPE_COLORS[scheme.Type__c] ||
                    { bg: '#f3f3f3', color: '#706e6b', short: '?' };
                const isSelected = this.selectedScheme && this.selectedScheme.id === scheme.Id;

                return {
                    id: scheme.Id,
                    name: scheme.Name,
                    type: scheme.Type__c || 'Percentage Discount',
                    typeShort: typeConfig.short,
                    typeBadgeStyle: 'background-color: ' + typeConfig.bg + '; color: ' + typeConfig.color,
                    description: scheme.Description__c || '',
                    validFrom: this.formatDate(scheme.Valid_From__c),
                    validTo: this.formatDate(scheme.Valid_To__c),
                    category: scheme.Category__c || 'All',
                    channel: scheme.Channel__c || 'All',
                    terms: scheme.Terms__c || '',
                    discountPercent: scheme.Discount_Percent__c || 0,
                    discountAmount: scheme.Discount_Amount__c || 0,
                    buyQty: scheme.Buy_Qty__c || 0,
                    freeQty: scheme.Free_Qty__c || 0,
                    minOrderValue: scheme.Min_Order_Value__c || 0,
                    products: scheme.Scheme_Products__r
                        ? scheme.Scheme_Products__r.map(sp => ({
                            id: sp.Product__c || sp.Id,
                            name: sp.Product__r?.Name || sp.Product_Name__c || 'Product',
                            sku: sp.Product__r?.SKU__c || sp.SKU__c || ''
                        }))
                        : null,
                    productBadges: scheme.Scheme_Products__r
                        ? scheme.Scheme_Products__r.slice(0, 3).map(sp =>
                            sp.Product__r?.Name || sp.Product_Name__c || 'Product')
                        : [],
                    hasSlabs: scheme.Scheme_Slabs__r && scheme.Scheme_Slabs__r.length > 0,
                    slabs: scheme.Scheme_Slabs__r
                        ? scheme.Scheme_Slabs__r.map((slab, idx) => ({
                            id: slab.Id || 'slab_' + idx,
                            minQty: slab.Min_Qty__c || 0,
                            maxQty: slab.Max_Qty__c || 'Unlimited',
                            discountPercent: slab.Discount_Percent__c || 0,
                            freeQty: slab.Free_Qty__c || 0
                        }))
                        : [],
                    cardClass: 'scheme-card' + (isSelected ? ' scheme-card-selected' : '')
                };
            });
        } catch (error) {
            this.showToast('Error', 'Failed to load schemes: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSchemeSelect(event) {
        const schemeId = event.currentTarget.dataset.schemeId;
        const scheme = this.activeSchemes.find(s => s.id === schemeId);
        if (!scheme) return;

        // Update selection styling
        this.activeSchemes = this.activeSchemes.map(s => ({
            ...s,
            cardClass: s.id === schemeId ? 'scheme-card scheme-card-selected' : 'scheme-card'
        }));

        try {
            const details = await getSchemeDetails({ schemeId: schemeId });
            if (details) {
                this.selectedScheme = {
                    ...scheme,
                    description: details.Description__c || scheme.description,
                    terms: details.Terms__c || scheme.terms
                };
            } else {
                this.selectedScheme = scheme;
            }
        } catch (error) {
            this.selectedScheme = scheme;
        }

        this.calculatorResult = null;
        this.calculatorQty = 0;
        this.calculatorValue = 0;
    }

    handleSchemeTypeFilter(event) {
        this.filterSchemeType = event.detail.value;
    }

    handleCategoryFilter(event) {
        this.filterCategory = event.detail.value;
    }

    handleChannelFilter(event) {
        this.filterChannel = event.detail.value;
    }

    handleClearFilters() {
        this.filterSchemeType = '';
        this.filterCategory = '';
        this.filterChannel = '';
    }

    handleCalculatorQtyChange(event) {
        this.calculatorQty = parseInt(event.detail.value, 10) || 0;
    }

    handleCalculatorValueChange(event) {
        this.calculatorValue = parseFloat(event.detail.value) || 0;
    }

    async handleCalculate() {
        if (!this.selectedScheme) {
            this.showToast('Warning', 'Please select a scheme first', 'warning');
            return;
        }

        if (this.calculatorQty <= 0 && this.calculatorValue <= 0) {
            this.showToast('Warning', 'Please enter quantity or order value', 'warning');
            return;
        }

        try {
            const result = await calculateSchemeDiscount({
                schemeId: this.selectedScheme.id,
                quantity: this.calculatorQty,
                orderValue: this.calculatorValue
            });

            if (result) {
                this.calculatorResult = {
                    grossAmount: result.Gross_Amount__c || this.calculatorValue,
                    grossAmountFormatted: this.formatCurrency(result.Gross_Amount__c || this.calculatorValue),
                    discount: result.Discount_Amount__c || 0,
                    discountFormatted: this.formatCurrency(result.Discount_Amount__c || 0),
                    freeQty: result.Free_Qty__c || 0,
                    netAmount: result.Net_Amount__c || 0,
                    netAmountFormatted: this.formatCurrency(result.Net_Amount__c || 0),
                    effectiveDiscountPercent: result.Effective_Discount_Percent__c || 0
                };
            } else {
                // Calculate locally if Apex doesn't return
                this.calculateLocally();
            }
        } catch (error) {
            // Fallback to local calculation
            this.calculateLocally();
        }
    }

    calculateLocally() {
        const scheme = this.selectedScheme;
        if (!scheme) return;

        let grossAmount = this.calculatorValue;
        let discount = 0;
        let freeQty = 0;

        switch (scheme.type) {
            case 'Percentage Discount':
                discount = grossAmount * (scheme.discountPercent / 100);
                break;
            case 'Flat Discount':
                discount = Math.min(scheme.discountAmount, grossAmount);
                break;
            case 'Buy X Get Y Free':
                if (scheme.buyQty > 0 && this.calculatorQty > 0) {
                    freeQty = Math.floor(this.calculatorQty / scheme.buyQty) * scheme.freeQty;
                }
                break;
            case 'Slab Discount':
                if (scheme.slabs && scheme.slabs.length > 0) {
                    const applicableSlab = scheme.slabs.find(slab => {
                        const maxQty = slab.maxQty === 'Unlimited' ? Infinity : slab.maxQty;
                        return this.calculatorQty >= slab.minQty && this.calculatorQty <= maxQty;
                    });
                    if (applicableSlab) {
                        discount = grossAmount * (applicableSlab.discountPercent / 100);
                        freeQty = applicableSlab.freeQty || 0;
                    }
                }
                break;
            default:
                break;
        }

        const netAmount = grossAmount - discount;
        const effectivePercent = grossAmount > 0 ? Math.round((discount / grossAmount) * 100 * 100) / 100 : 0;

        this.calculatorResult = {
            grossAmount: grossAmount,
            grossAmountFormatted: this.formatCurrency(grossAmount),
            discount: discount,
            discountFormatted: this.formatCurrency(discount),
            freeQty: freeQty,
            netAmount: netAmount,
            netAmountFormatted: this.formatCurrency(netAmount),
            effectiveDiscountPercent: effectivePercent
        };
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: 'INR',
            minimumFractionDigits: 2
        }).format(value || 0);
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        return new Date(dateStr).toLocaleDateString('en-IN', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
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
