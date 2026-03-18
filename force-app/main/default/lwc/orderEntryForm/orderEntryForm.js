import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import searchProducts from '@salesforce/apex/OrderEntryController.searchProducts';
import createSalesOrder from '@salesforce/apex/OrderEntryController.createSalesOrder';
import getLastOrder from '@salesforce/apex/OrderEntryController.getLastOrder';
import getApplicableSchemes from '@salesforce/apex/OrderEntryController.getApplicableSchemes';
import getMustSellProducts from '@salesforce/apex/OrderEntryController.getMustSellProducts';
import getProductCategories from '@salesforce/apex/OrderEntryController.getProductCategories';
import getTopSellingProducts from '@salesforce/apex/OrderEntryController.getTopSellingProducts';

const ACCOUNT_FIELDS = [
    'Account.Name',
    'Account.Channel__c',
    'Account.Outlet_Class__c',
    'Account.Outlet_Type__c',
    'Account.Territory__c',
    'Account.BillingCity'
];

export default class OrderEntryForm extends NavigationMixin(LightningElement) {
    @api recordId;
    @api visitId;
    @api accountId;

    get isEmbedded() { return !!this.accountId; }

    @track lineItems = [];
    @track orderSummary = {
        grossAmount: 0,
        totalDiscount: 0,
        taxableAmount: 0,
        totalTax: 0,
        netAmount: 0,
        totalItems: 0,
        totalQuantity: 0,
        grossAmountFormatted: '₹0.00',
        totalDiscountFormatted: '₹0.00',
        taxableAmountFormatted: '₹0.00',
        totalTaxFormatted: '₹0.00',
        netAmountFormatted: '₹0.00'
    };
    @track productResults = [];
    @track lastOrderInfo;
    @track schemes = [];
    @track mustSellProducts = [];
    @track focusedSellProducts = [];
    @track showMustSellWarning = false;
    @track missingMustSellProducts = [];
    @track mustSellBelowMinQty = [];
    @track topSellingProducts = [];
    @track mustSellHighlightActive = false;
    showFocusedSell = false;
    showSchemesPanel = false;
    showTopSelling = true;

    searchTerm = '';
    selectedCategory = '';
    categoryOptionsData = [];
    selectedAccountId;
    accountName = '';
    accountChannel = '';
    accountClass = '';
    orderRemarks = '';
    isLoading = false;
    isSubmitting = false;
    lineIdCounter = 0;

    get effectiveAccountId() {
        return this.accountId || this.recordId || this.selectedAccountId;
    }

    get showProductResults() {
        return this.productResults && this.productResults.length > 0;
    }

    get hasLineItems() {
        return this.lineItems && this.lineItems.length > 0;
    }

    get lineItemCount() {
        return this.lineItems.length;
    }

    get hasMustSellProducts() {
        return this.mustSellProducts && this.mustSellProducts.length > 0;
    }

    get hasFocusedSellProducts() {
        return this.focusedSellProducts && this.focusedSellProducts.length > 0;
    }

    get hasMissingMustSell() {
        return this.missingMustSellProducts && this.missingMustSellProducts.length > 0;
    }

    get hasMustSellBelowMinQty() {
        return this.mustSellBelowMinQty && this.mustSellBelowMinQty.length > 0;
    }

    // --- Schemes panel getters ---
    get hasSchemes() {
        return this.schemes && this.schemes.length > 0;
    }

    get schemesCount() {
        return this.schemes ? this.schemes.length : 0;
    }

    get schemesPanelIcon() {
        return this.showSchemesPanel ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get focusedSellIcon() {
        return this.showFocusedSell ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get hasTopSellingProducts() {
        return this.topSellingProducts && this.topSellingProducts.length > 0;
    }

    get topSellingIcon() {
        return this.showTopSelling ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get schemesForDisplay() {
        if (!this.schemes) return [];
        return this.schemes.map(scheme => {
            const cat = scheme.Scheme_Category__c || '';
            let iconName = 'utility:discount';
            let cardClass = 'oef-scheme-card';
            let categoryBadgeClass = 'oef-scheme-cat-badge';

            if (cat === 'Free Products') {
                iconName = 'utility:package';
                cardClass += ' oef-scheme-card-free';
                categoryBadgeClass += ' oef-cat-free';
            } else if (cat === 'Discount in %' || cat === 'Discount in Value') {
                iconName = 'utility:percent';
                cardClass += ' oef-scheme-card-discount';
                categoryBadgeClass += ' oef-cat-discount';
            } else if (cat === 'Reward Points') {
                iconName = 'utility:ribbon';
                cardClass += ' oef-scheme-card-reward';
                categoryBadgeClass += ' oef-cat-reward';
            } else {
                cardClass += ' oef-scheme-card-default';
                categoryBadgeClass += ' oef-cat-default';
            }

            const benefitText = this.buildSchemeBenefitText(scheme);

            return {
                ...scheme,
                iconName,
                cardClass,
                categoryBadgeClass,
                benefitText
            };
        });
    }

    buildSchemeBenefitText(scheme) {
        const parts = [];
        if (scheme.Discount_Percent__c) {
            parts.push(scheme.Discount_Percent__c + '% off');
        }
        if (scheme.Discount_Amount__c) {
            parts.push(this.formatCurrency(scheme.Discount_Amount__c) + ' off');
        }
        if (scheme.Free_Quantity__c && scheme.Free_Product_Ext__r) {
            parts.push('Get ' + scheme.Free_Quantity__c + ' ' + scheme.Free_Product_Ext__r.Name + ' free');
        } else if (scheme.Free_Quantity__c) {
            parts.push('Get ' + scheme.Free_Quantity__c + ' free');
        }
        if (scheme.Reward_Points__c) {
            parts.push(scheme.Reward_Points__c + ' reward points');
        }
        if (scheme.MOV__c) {
            parts.push('Min order: ' + this.formatCurrency(scheme.MOV__c));
        }
        if (scheme.Min_Quantity__c) {
            parts.push('Min qty: ' + scheme.Min_Quantity__c);
        }
        if (parts.length === 0 && scheme.Description__c) {
            return scheme.Description__c;
        }
        return parts.join(' | ') || scheme.Description__c || scheme.Scheme_Type__c || '';
    }

    // --- Must Sell progress getters ---
    get mustSellOrderedCount() {
        return this.mustSellProducts ? this.mustSellProducts.filter(p => p.isInOrder).length : 0;
    }

    get mustSellTotalCount() {
        return this.mustSellProducts ? this.mustSellProducts.length : 0;
    }

    get mustSellBarStyle() {
        if (!this.mustSellTotalCount) return 'width: 0%';
        const pct = Math.round((this.mustSellOrderedCount / this.mustSellTotalCount) * 100);
        return 'width: ' + pct + '%';
    }

    // --- Summary getters ---
    get hasSchemeSavings() {
        return this.orderSummary.totalDiscount > 0;
    }

    get totalFreeQuantity() {
        if (!this.lineItems) return 0;
        return this.lineItems.reduce((sum, item) => sum + (item.freeQty || 0), 0);
    }

    get categoryOptions() {
        if (this.categoryOptionsData && this.categoryOptionsData.length > 0) {
            return this.categoryOptionsData;
        }
        return [{ label: 'All Categories', value: '' }];
    }

    @wire(getProductCategories)
    wiredCategories({ error, data }) {
        if (data) {
            this.categoryOptionsData = data;
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: ACCOUNT_FIELDS })
    wiredAccount({ error, data }) {
        if (data) {
            this.accountName = getFieldValue(data, 'Account.Name');
            this.accountChannel = getFieldValue(data, 'Account.Channel__c') || 'General Trade';
            this.accountClass = getFieldValue(data, 'Account.Outlet_Class__c') || 'B';
            this.selectedAccountId = this.recordId;
            this.loadLastOrder();
            this.loadSchemes();
            this.loadMustSellProducts();
            this.loadTopSellingProducts();
        } else if (error) {
            this.showToast('Error', 'Failed to load account details', 'error');
        }
    }

    connectedCallback() {
        if (!this.recordId && this.accountId) {
            this.selectedAccountId = this.accountId;
            this.loadLastOrder();
            this.loadSchemes();
            this.loadMustSellProducts();
            this.loadTopSellingProducts();
        }
    }

    handleAccountChange(event) {
        this.selectedAccountId = event.detail.recordId;
        if (this.selectedAccountId) {
            this.loadAccountDetails();
            this.loadLastOrder();
            this.loadSchemes();
            this.loadMustSellProducts();
            this.loadTopSellingProducts();
        }
    }

    loadAccountDetails() {
        if (this.selectedAccountId && !this.recordId) {
            this.accountName = 'Selected Outlet';
            this.accountChannel = 'General Trade';
            this.accountClass = 'B';
        }
    }

    async loadLastOrder() {
        if (!this.effectiveAccountId) return;
        try {
            const result = await getLastOrder({ accountId: this.effectiveAccountId });
            if (result) {
                this.lastOrderInfo = {
                    orderNumber: result.Name || result.Order_Number__c,
                    orderDate: this.formatDate(result.Order_Date__c || result.CreatedDate),
                    itemCount: result.Line_Item_Count__c || 0,
                    totalFormatted: this.formatCurrency(result.Net_Amount__c || 0),
                    id: result.Id,
                    lineItems: result.Order_Line_Items__r || []
                };
            }
        } catch (error) {
            console.error('Error loading last order:', error);
        }
    }

    async loadSchemes() {
        if (!this.effectiveAccountId) return;
        try {
            const result = await getApplicableSchemes({ accountId: this.effectiveAccountId });
            this.schemes = result || [];
        } catch (error) {
            console.error('Error loading schemes:', error);
        }
    }

    async loadMustSellProducts() {
        if (!this.effectiveAccountId) return;
        try {
            const result = await getMustSellProducts({
                accountId: this.effectiveAccountId,
                orderDate: null
            });
            const items = result || [];
            const orderedProductIds = new Set(this.lineItems.map(li => li.productId));

            this.mustSellProducts = items
                .filter(p => p.classification === 'Must Sell')
                .map(p => ({
                    ...p,
                    isInOrder: orderedProductIds.has(p.productId),
                    cardClass: orderedProductIds.has(p.productId)
                        ? 'oef-ms-card oef-ms-card-done' : 'oef-ms-card',
                    hasMinQty: p.minQuantity && p.minQuantity > 1,
                    minQtyLabel: p.minQuantity ? 'Min Qty: ' + p.minQuantity : ''
                }));

            this.focusedSellProducts = items
                .filter(p => p.classification === 'Focused Sell')
                .map(p => ({
                    ...p,
                    isInOrder: orderedProductIds.has(p.productId),
                    cardClass: orderedProductIds.has(p.productId)
                        ? 'oef-ms-card oef-fs-card oef-ms-card-done' : 'oef-ms-card oef-fs-card'
                }));

            // Auto-add must-sell products to cart with qty 0
            this.autoAddMustSellToCart();
        } catch (error) {
            console.error('Error loading must-sell products:', error);
        }
    }

    autoAddMustSellToCart() {
        if (!this.mustSellProducts || this.mustSellProducts.length === 0) return;
        const orderedProductIds = new Set(this.lineItems.map(li => li.productId));
        let added = false;

        this.mustSellProducts.forEach(product => {
            if (orderedProductIds.has(product.productId)) return;

            this.lineIdCounter++;
            const newItem = {
                id: 'LINE_' + this.lineIdCounter,
                productId: product.productId,
                productName: product.productName,
                sku: product.sku || 'N/A',
                rate: 0,
                rateFormatted: this.formatCurrency(0),
                quantity: 0,
                freeQty: 0,
                schemeName: product.schemeName || '',
                schemeId: product.schemeId || null,
                classification: 'Must Sell',
                classificationBadgeClass: this.getClassificationBadgeClass('Must Sell'),
                taxRate: 18,
                grossAmount: 0,
                discountAmount: 0,
                discountFormatted: this.formatCurrency(0),
                taxAmount: 0,
                taxFormatted: this.formatCurrency(0),
                totalAmount: 0,
                totalFormatted: this.formatCurrency(0),
                serialNumber: this.lineItems.length + 1,
                rowClass: 'oef-row-must-sell-pending',
                isMustSell: true,
                minQuantity: product.minQuantity || 1
            };
            this.lineItems = [...this.lineItems, newItem];
            added = true;
        });

        if (added) {
            this.calculateTotals();
            this.refreshMustSellStatus();
        }
    }

    async loadTopSellingProducts() {
        if (!this.effectiveAccountId) return;
        try {
            const results = await getTopSellingProducts({ accountId: this.effectiveAccountId });
            const orderedProductIds = new Set(this.lineItems.map(li => li.productId));
            this.topSellingProducts = (results || []).map(product => {
                const allSchemes = this.findAllApplicableSchemes(product);
                const scheme = allSchemes.length > 0 ? allSchemes[0] : null;
                const schemeStrips = allSchemes.map(s => ({
                    id: s.Id,
                    name: s.Name,
                    description: this.buildSchemeBenefitText(s)
                }));
                return {
                    id: product.Id,
                    name: product.Name,
                    sku: product.SKU_Code || 'N/A',
                    mrp: product.MRP || product.Unit_Price || 0,
                    mrpFormatted: this.formatCurrency(product.MRP || product.Unit_Price || 0),
                    unitPrice: product.Unit_Price || 0,
                    taxRate: product.GST_Rate || 18,
                    schemeName: scheme ? scheme.Name : '',
                    schemeId: scheme ? scheme.Id : null,
                    schemeStrips: schemeStrips,
                    hasSchemes: schemeStrips.length > 0,
                    isInOrder: orderedProductIds.has(product.Id),
                    cardClass: 'oef-top-sell-card' + (orderedProductIds.has(product.Id) ? ' oef-top-sell-done' : '')
                };
            });
        } catch (error) {
            console.error('Error loading top selling products:', error);
        }
    }

    toggleTopSelling() {
        this.showTopSelling = !this.showTopSelling;
    }

    handleAddTopSelling(event) {
        const productId = event.currentTarget.dataset.productId;
        const product = this.topSellingProducts.find(p => p.id === productId);
        if (!product) return;

        const existingIndex = this.lineItems.findIndex(item => item.productId === productId);
        if (existingIndex >= 0) {
            this.showToast('Info', product.name + ' is already in the order', 'info');
            return;
        }

        this.lineIdCounter++;
        const qty = 1;
        const scheme = product.schemeId ? this.schemes.find(s => s.Id === product.schemeId) : null;
        const freeQty = scheme ? this.calculateFreeQty(qty, scheme) : 0;
        const grossAmount = qty * product.unitPrice;
        const discountAmount = scheme ? this.calculateSchemeDiscount(grossAmount, qty, scheme) : 0;
        const taxableAmount = grossAmount - discountAmount;
        const taxAmount = taxableAmount * (product.taxRate / 100);
        const totalAmount = taxableAmount + taxAmount;

        const newItem = {
            id: 'LINE_' + this.lineIdCounter,
            productId: product.id,
            productName: product.name,
            sku: product.sku,
            rate: product.unitPrice,
            rateFormatted: this.formatCurrency(product.unitPrice),
            quantity: qty,
            freeQty: freeQty,
            schemeName: product.schemeName || '',
            schemeId: product.schemeId || null,
            classification: '',
            classificationBadgeClass: '',
            taxRate: product.taxRate,
            grossAmount: grossAmount,
            discountAmount: discountAmount,
            discountFormatted: this.formatCurrency(discountAmount),
            taxAmount: taxAmount,
            taxFormatted: this.formatCurrency(taxAmount),
            totalAmount: totalAmount,
            totalFormatted: this.formatCurrency(totalAmount),
            serialNumber: this.lineItems.length + 1,
            rowClass: ''
        };
        this.lineItems = [...this.lineItems, newItem];
        this.calculateTotals();
        this.refreshMustSellStatus();
        this.refreshTopSellingStatus();
        this.showToast('Success', product.name + ' added to order', 'success');
    }

    refreshTopSellingStatus() {
        const orderedProductIds = new Set(this.lineItems.map(li => li.productId));
        this.topSellingProducts = this.topSellingProducts.map(p => ({
            ...p,
            isInOrder: orderedProductIds.has(p.id),
            cardClass: 'oef-top-sell-card' + (orderedProductIds.has(p.id) ? ' oef-top-sell-done' : '')
        }));
    }

    refreshMustSellStatus() {
        const orderedProductIds = new Set(this.lineItems.map(li => li.productId));
        this.mustSellProducts = this.mustSellProducts.map(p => ({
            ...p,
            isInOrder: orderedProductIds.has(p.productId),
            cardClass: orderedProductIds.has(p.productId)
                ? 'oef-ms-card oef-ms-card-done' : 'oef-ms-card',
            hasMinQty: p.minQuantity && p.minQuantity > 1,
            minQtyLabel: p.minQuantity ? 'Min Qty: ' + p.minQuantity : ''
        }));
        this.focusedSellProducts = this.focusedSellProducts.map(p => ({
            ...p,
            isInOrder: orderedProductIds.has(p.productId),
            cardClass: orderedProductIds.has(p.productId)
                ? 'oef-ms-card oef-fs-card oef-ms-card-done' : 'oef-ms-card oef-fs-card'
        }));
    }

    toggleSchemesPanel() {
        this.showSchemesPanel = !this.showSchemesPanel;
    }

    toggleFocusedSell() {
        this.showFocusedSell = !this.showFocusedSell;
    }

    handleAddMustSell(event) {
        const productId = event.currentTarget.dataset.productId;
        const classification = event.currentTarget.dataset.classification;
        const source = classification === 'Must Sell' ? this.mustSellProducts : this.focusedSellProducts;
        const product = source.find(p => p.productId === productId);
        if (!product) return;

        const existingIndex = this.lineItems.findIndex(item => item.productId === productId);
        if (existingIndex >= 0) {
            // If already in cart with qty 0 (auto-added must-sell), update to min qty
            const existingItem = this.lineItems[existingIndex];
            if (existingItem.quantity === 0) {
                const qty = product.minQuantity || 1;
                this.lineItems = this.lineItems.map((item, idx) => {
                    if (idx === existingIndex) {
                        return this.recalculateLineItem({
                            ...item,
                            quantity: qty,
                            rowClass: classification === 'Must Sell' ? 'oef-row-must-sell-pending' : ''
                        });
                    }
                    return item;
                });
                this.calculateTotals();
                this.refreshMustSellStatus();
                this.showToast('Success', product.productName + ' quantity updated', 'success');
                return;
            }
            this.showToast('Info', product.productName + ' is already in the order', 'info');
            return;
        }

        this.lineIdCounter++;
        const qty = product.minQuantity || 1;
        const rate = 0;
        const newItem = {
            id: 'LINE_' + this.lineIdCounter,
            productId: product.productId,
            productName: product.productName,
            sku: product.sku || 'N/A',
            rate: rate,
            rateFormatted: this.formatCurrency(rate),
            quantity: qty,
            freeQty: 0,
            schemeName: product.schemeName || '',
            schemeId: product.schemeId || null,
            classification: classification,
            classificationBadgeClass: this.getClassificationBadgeClass(classification),
            taxRate: 18,
            grossAmount: qty * rate,
            discountAmount: 0,
            discountFormatted: this.formatCurrency(0),
            taxAmount: 0,
            taxFormatted: this.formatCurrency(0),
            totalAmount: 0,
            totalFormatted: this.formatCurrency(0),
            serialNumber: this.lineItems.length + 1,
            rowClass: classification === 'Must Sell' ? 'oef-row-must-sell-pending' : '',
            isMustSell: classification === 'Must Sell',
            minQuantity: product.minQuantity || 1
        };
        this.lineItems = [...this.lineItems, newItem];
        this.calculateTotals();
        this.refreshMustSellStatus();
        this.showToast('Success', product.productName + ' added to order', 'success');
    }

    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
        if (this.searchTerm.length >= 2) {
            this.debounceSearch();
        }
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.detail.value;
        this.handleProductSearch();
    }

    debounceSearch() {
        clearTimeout(this._searchTimeout);
        this._searchTimeout = setTimeout(() => {
            this.handleProductSearch();
        }, 300);
    }

    async handleProductSearch() {
        if (!this.searchTerm && !this.selectedCategory) {
            this.showToast('Info', 'Please enter a search term or select a category', 'info');
            return;
        }

        this.isLoading = true;
        try {
            const results = await searchProducts({
                searchTerm: this.searchTerm,
                categoryId: this.selectedCategory,
                accountId: this.effectiveAccountId
            });

            this.productResults = (results || []).map(product => {
                const allSchemes = this.findAllApplicableSchemes(product);
                const scheme = allSchemes.length > 0 ? allSchemes[0] : null;
                const qty = 0;
                const unitPrice = product.Unit_Price || 0;
                const mrp = product.MRP || unitPrice;
                const freeQty = scheme ? this.calculateFreeQty(qty, scheme) : 0;
                const lineTotal = qty * unitPrice;
                const schemeDescription = scheme ? this.buildSchemeBenefitText(scheme) : '';

                const schemeStrips = allSchemes.map(s => ({
                    id: s.Id,
                    name: s.Name,
                    description: this.buildSchemeBenefitText(s)
                }));

                // Check if product is Must Sell or Focused Sell
                const msMatch = this.mustSellProducts.find(p => p.productId === product.Id);
                const fsMatch = this.focusedSellProducts.find(p => p.productId === product.Id);
                const classification = msMatch ? 'Must Sell' : (fsMatch ? 'Focused Sell' : '');
                const classificationBadgeClass = this.getClassificationBadgeClass(classification);

                return {
                    id: product.Id,
                    name: product.Name,
                    sku: product.SKU_Code || 'N/A',
                    mrp: mrp,
                    mrpFormatted: this.formatCurrency(mrp),
                    unitPrice: unitPrice,
                    category: '',
                    taxRate: product.GST_Rate || 18,
                    quantity: qty,
                    freeQty: freeQty,
                    schemeName: scheme ? scheme.Name : '',
                    schemeId: scheme ? scheme.Id : null,
                    schemeDescription: schemeDescription,
                    schemeStrips: schemeStrips,
                    hasSchemes: schemeStrips.length > 0,
                    classification: classification,
                    classificationBadgeClass: classificationBadgeClass,
                    hasClassification: !!classification,
                    lineTotal: lineTotal,
                    lineTotalFormatted: this.formatCurrency(lineTotal),
                    cardClass: allSchemes.length > 0 ? 'oef-product-card oef-product-card-scheme' : 'oef-product-card'
                };
            });
        } catch (error) {
            this.showToast('Error', 'Failed to search products: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleProductQtyChange(event) {
        const productId = event.target.dataset.productId;
        const qty = parseInt(event.target.value, 10) || 0;

        this.productResults = this.productResults.map(product => {
            if (product.id === productId) {
                const scheme = this.findApplicableScheme(product);
                const freeQty = scheme ? this.calculateFreeQty(qty, scheme) : 0;
                const lineTotal = qty * product.unitPrice;
                return {
                    ...product,
                    quantity: qty,
                    freeQty: freeQty,
                    lineTotal: lineTotal,
                    lineTotalFormatted: this.formatCurrency(lineTotal)
                };
            }
            return product;
        });
    }

    addToOrder(event) {
        const productId = event.target.dataset.productId || event.currentTarget.dataset.productId;
        const product = this.productResults.find(p => p.id === productId);

        if (!product) return;

        const qty = product.quantity || 1;
        if (qty <= 0) {
            this.showToast('Warning', 'Please enter a valid quantity', 'warning');
            return;
        }

        const existingIndex = this.lineItems.findIndex(item => item.productId === productId);
        if (existingIndex >= 0) {
            this.lineItems = this.lineItems.map((item, idx) => {
                if (idx === existingIndex) {
                    const newQty = item.quantity + qty;
                    return this.recalculateLineItem({ ...item, quantity: newQty });
                }
                return item;
            });
        } else {
            this.lineIdCounter++;
            const scheme = this.findApplicableScheme(product);
            const freeQty = scheme ? this.calculateFreeQty(qty, scheme) : 0;
            const grossAmount = qty * product.unitPrice;
            const discountAmount = scheme ? this.calculateSchemeDiscount(grossAmount, qty, scheme) : 0;
            const taxableAmount = grossAmount - discountAmount;
            const taxAmount = taxableAmount * (product.taxRate / 100);
            const totalAmount = taxableAmount + taxAmount;

            const msMatch = this.mustSellProducts.find(p => p.productId === product.id);
            const fsMatch = this.focusedSellProducts.find(p => p.productId === product.id);
            const classification = msMatch ? 'Must Sell' : (fsMatch ? 'Focused Sell' : '');

            const newItem = {
                id: 'LINE_' + this.lineIdCounter,
                productId: product.id,
                productName: product.name,
                sku: product.sku,
                rate: product.unitPrice,
                rateFormatted: this.formatCurrency(product.unitPrice),
                quantity: qty,
                freeQty: freeQty,
                schemeName: scheme ? scheme.Name : '',
                schemeId: scheme ? scheme.Id : null,
                classification: classification,
                classificationBadgeClass: this.getClassificationBadgeClass(classification),
                taxRate: product.taxRate,
                grossAmount: grossAmount,
                discountAmount: discountAmount,
                discountFormatted: this.formatCurrency(discountAmount),
                taxAmount: taxAmount,
                taxFormatted: this.formatCurrency(taxAmount),
                totalAmount: totalAmount,
                totalFormatted: this.formatCurrency(totalAmount),
                serialNumber: this.lineItems.length + 1,
                rowClass: ''
            };
            this.lineItems = [...this.lineItems, newItem];
        }

        this.calculateTotals();
        this.refreshMustSellStatus();
        this.refreshTopSellingStatus();
        this.showToast('Success', product.name + ' added to order', 'success');
    }

    removeLineItem(event) {
        const lineId = event.target.dataset.lineId || event.currentTarget.dataset.lineId;
        this.lineItems = this.lineItems
            .filter(item => item.id !== lineId)
            .map((item, idx) => ({ ...item, serialNumber: idx + 1 }));
        this.calculateTotals();
        this.refreshMustSellStatus();
        this.refreshTopSellingStatus();
    }

    handleLineQtyChange(event) {
        const lineId = event.target.dataset.lineId;
        const newQty = parseInt(event.target.value, 10) || 0;

        const item = this.lineItems.find(i => i.id === lineId);
        if (!item) return;

        // For non-must-sell items, qty must be at least 1
        if (!item.isMustSell && newQty <= 0) {
            this.showToast('Warning', 'Quantity must be at least 1', 'warning');
            return;
        }

        this.lineItems = this.lineItems.map(li => {
            if (li.id === lineId) {
                const updated = this.recalculateLineItem({ ...li, quantity: newQty });
                // Clear red highlight when user enters valid qty
                if (li.isMustSell && newQty > 0) {
                    updated.rowClass = 'oef-row-must-sell-pending';
                }
                return updated;
            }
            return li;
        });

        this.calculateTotals();
        this.refreshMustSellStatus();
    }

    recalculateLineItem(item) {
        const scheme = this.schemes.find(s => s.Id === item.schemeId);
        const freeQty = scheme ? this.calculateFreeQty(item.quantity, scheme) : item.freeQty;
        const grossAmount = item.quantity * item.rate;
        const discountAmount = scheme ? this.calculateSchemeDiscount(grossAmount, item.quantity, scheme) : 0;
        const taxableAmount = grossAmount - discountAmount;
        const taxAmount = taxableAmount * (item.taxRate / 100);
        const totalAmount = taxableAmount + taxAmount;

        return {
            ...item,
            freeQty: freeQty,
            grossAmount: grossAmount,
            discountAmount: discountAmount,
            discountFormatted: this.formatCurrency(discountAmount),
            taxAmount: taxAmount,
            taxFormatted: this.formatCurrency(taxAmount),
            totalAmount: totalAmount,
            totalFormatted: this.formatCurrency(totalAmount)
        };
    }

    calculateTotals() {
        let grossAmount = 0;
        let totalDiscount = 0;
        let totalTax = 0;
        let totalQuantity = 0;

        this.lineItems.forEach(item => {
            grossAmount += item.grossAmount || 0;
            totalDiscount += item.discountAmount || 0;
            totalTax += item.taxAmount || 0;
            totalQuantity += item.quantity || 0;
        });

        const taxableAmount = grossAmount - totalDiscount;
        const netAmount = taxableAmount + totalTax;

        this.orderSummary = {
            grossAmount: grossAmount,
            totalDiscount: totalDiscount,
            taxableAmount: taxableAmount,
            totalTax: totalTax,
            netAmount: netAmount,
            totalItems: this.lineItems.length,
            totalQuantity: totalQuantity,
            grossAmountFormatted: this.formatCurrency(grossAmount),
            totalDiscountFormatted: this.formatCurrency(totalDiscount),
            taxableAmountFormatted: this.formatCurrency(taxableAmount),
            totalTaxFormatted: this.formatCurrency(totalTax),
            netAmountFormatted: this.formatCurrency(netAmount)
        };
    }

    findAllApplicableSchemes(product) {
        if (!this.schemes || this.schemes.length === 0) return [];
        const productId = product.id || product.Id;
        const productCategory = product.category || product.Category__c || product.Product_Category__c || '';

        const productSchemes = [];
        const categorySchemes = [];
        const invoiceSchemes = [];

        this.schemes.forEach(scheme => {
            // 1. Direct product match on scheme header
            if (scheme.Product_Ext__c && scheme.Product_Ext__c === productId) {
                productSchemes.push(scheme);
                return;
            }

            // 2. Check Scheme_Products__r child records for product-level mapping
            const schemeProducts = scheme.Scheme_Products__r;
            if (schemeProducts && schemeProducts.length > 0) {
                const hasProductInScheme = schemeProducts.some(
                    sp => sp.Product_Ext__c === productId && sp.Is_Buy_Product__c
                );
                if (hasProductInScheme) {
                    productSchemes.push(scheme);
                }
                return;
            }

            // 3. Category-level scheme (no specific products mapped)
            if (scheme.Product_Category__c && productCategory &&
                scheme.Product_Category__c === productCategory) {
                categorySchemes.push(scheme);
                return;
            }

            // 4. Invoice-level schemes (no product or category restriction)
            const invoiceTypes = ['Invoice Qty Based', 'Invoice Val Based'];
            if (!scheme.Product_Ext__c && !scheme.Product_Category__c &&
                invoiceTypes.includes(scheme.Scheme_Type__c)) {
                invoiceSchemes.push(scheme);
            }
        });

        return [...productSchemes, ...categorySchemes, ...invoiceSchemes];
    }

    findApplicableScheme(product) {
        const all = this.findAllApplicableSchemes(product);
        return all.length > 0 ? all[0] : null;
    }

    calculateFreeQty(qty, scheme) {
        if (!scheme) return 0;
        if (scheme.Scheme_Category__c === 'Free Products' && scheme.Min_Quantity__c && scheme.Free_Quantity__c) {
            return Math.floor(qty / scheme.Min_Quantity__c) * scheme.Free_Quantity__c;
        }
        return 0;
    }

    calculateSchemeDiscount(amount, qty, scheme) {
        if (!scheme || !scheme.Scheme_Category__c) return 0;
        if (scheme.Scheme_Category__c === 'Discount in %' && scheme.Discount_Percent__c) {
            return amount * (scheme.Discount_Percent__c / 100);
        }
        if (scheme.Scheme_Category__c === 'Discount in Value' && scheme.Discount_Amount__c) {
            return Math.min(scheme.Discount_Amount__c, amount);
        }
        if (scheme.Scheme_Slabs__r) {
            const applicableSlab = scheme.Scheme_Slabs__r.find(slab =>
                qty >= slab.Min_Value__c && (!slab.Max_Value__c || qty <= slab.Max_Value__c)
            );
            if (applicableSlab && applicableSlab.Discount_Percent__c) {
                return amount * (applicableSlab.Discount_Percent__c / 100);
            }
        }
        return 0;
    }

    async handleReorderLastOrder() {
        if (!this.lastOrderInfo || !this.lastOrderInfo.lineItems) return;

        this.isLoading = true;
        try {
            const lastItems = this.lastOrderInfo.lineItems;
            for (const lastItem of lastItems) {
                this.lineIdCounter++;
                const newItem = {
                    id: 'LINE_' + this.lineIdCounter,
                    productId: lastItem.Product_Ext__c,
                    productName: lastItem.Product_Name__c || lastItem.Product_Ext__r?.Name || 'Product',
                    sku: lastItem.SKU__c || 'N/A',
                    rate: lastItem.Unit_Price__c || 0,
                    rateFormatted: this.formatCurrency(lastItem.Unit_Price__c || 0),
                    quantity: lastItem.Quantity__c || 0,
                    freeQty: lastItem.Free_Qty__c || 0,
                    schemeName: '',
                    schemeId: null,
                    taxRate: lastItem.Tax_Rate__c || 18,
                    grossAmount: (lastItem.Quantity__c || 0) * (lastItem.Unit_Price__c || 0),
                    discountAmount: lastItem.Discount_Amount__c || 0,
                    discountFormatted: this.formatCurrency(lastItem.Discount_Amount__c || 0),
                    taxAmount: lastItem.Tax_Amount__c || 0,
                    taxFormatted: this.formatCurrency(lastItem.Tax_Amount__c || 0),
                    totalAmount: lastItem.Total_Amount__c || 0,
                    totalFormatted: this.formatCurrency(lastItem.Total_Amount__c || 0),
                    serialNumber: this.lineItems.length + 1,
                    rowClass: 'oef-reorder-row'
                };
                this.lineItems = [...this.lineItems, newItem];
            }
            this.calculateTotals();
            this.refreshMustSellStatus();
            this.showToast('Success', 'Last order items loaded for reorder', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to load last order', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleClearCart() {
        this.lineItems = [];
        this.calculateTotals();
        this.refreshMustSellStatus();
        this.refreshTopSellingStatus();
        this.mustSellHighlightActive = false;
        // Re-add must-sell products with qty 0
        this.autoAddMustSellToCart();
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleRemarksChange(event) {
        this.orderRemarks = event.target.value;
    }

    async handleSubmitOrder() {
        if (!this.validateOrder()) return;

        // Check must-sell products with qty 0 or below min - highlight red
        if (this.mustSellProducts && this.mustSellProducts.length > 0) {
            let hasViolation = false;

            this.lineItems = this.lineItems.map(item => {
                if (item.isMustSell && (!item.quantity || item.quantity <= 0)) {
                    hasViolation = true;
                    return { ...item, rowClass: 'oef-row-must-sell-error' };
                }
                // Check if must-sell below min qty
                const msProduct = this.mustSellProducts.find(p => p.productId === item.productId);
                if (msProduct && msProduct.minQuantity && item.quantity < msProduct.minQuantity) {
                    hasViolation = true;
                    return { ...item, rowClass: 'oef-row-must-sell-error' };
                }
                // Clear any previous highlight for non-violating rows
                if (item.rowClass === 'oef-row-must-sell-error') {
                    return { ...item, rowClass: item.isMustSell ? 'oef-row-must-sell-pending' : '' };
                }
                return item;
            });

            this.mustSellHighlightActive = hasViolation;

            if (hasViolation) {
                this.showToast('Warning', 'Please add quantity for all Must Sell products (highlighted in red) before submitting', 'warning');
                return;
            }
        }

        this._submitOrder(false);
    }

    handleMustSellWarningClose() {
        this.showMustSellWarning = false;
    }

    handleMustSellAddProducts() {
        this.showMustSellWarning = false;
    }

    get canOverrideMustSell() {
        // Cannot override if Must Sell products are missing or below min qty
        return this.missingMustSellProducts.length === 0 && this.mustSellBelowMinQty.length === 0;
    }

    handleMustSellSubmitAnyway() {
        if (!this.canOverrideMustSell) {
            this.showToast('Error', 'Cannot submit without all priority sell products meeting minimum quantity', 'error');
            return;
        }
        this.showMustSellWarning = false;
        this._submitOrder(true);
    }

    async _submitOrder(mustSellOverride) {
        this.isSubmitting = true;
        this.isLoading = true;

        try {
            const orderData = this.buildOrderPayload('Confirmed');
            orderData.mustSellOverride = mustSellOverride;
            if (mustSellOverride && this.mustSellProducts.length > 0) {
                const orderedProductIds = new Set(this.lineItems.map(li => li.productId));
                const ordered = this.mustSellProducts.filter(p => orderedProductIds.has(p.productId)).length;
                orderData.mustSellCompliance = (ordered / this.mustSellProducts.length) * 100;
            } else if (this.mustSellProducts.length > 0) {
                orderData.mustSellCompliance = 100;
            }
            const result = await createSalesOrder({ orderJson: JSON.stringify(orderData) });

            this.showToast('Success', 'Order submitted successfully! Order #: ' + (result.Name || result.Id), 'success');
            this.resetForm();

            this.dispatchEvent(new CustomEvent('success', {
                detail: { recordId: result.Id, orderNumber: result.Name, type: 'order' }
            }));

            if (result.Id && !this.accountId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result.Id,
                        objectApiName: 'Sales_Order__c',
                        actionName: 'view'
                    }
                });
            }
        } catch (error) {
            this.showToast('Error', 'Failed to submit order: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isSubmitting = false;
            this.isLoading = false;
        }
    }

    async handleSaveDraft() {
        if (this.lineItems.length === 0) {
            this.showToast('Warning', 'Add at least one product to save draft', 'warning');
            return;
        }
        this.isSubmitting = true;
        this.isLoading = true;

        try {
            const orderData = this.buildOrderPayload('Draft');
            const result = await createSalesOrder({ orderJson: JSON.stringify(orderData) });

            this.showToast('Success', 'Draft saved successfully!', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to save draft: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isSubmitting = false;
            this.isLoading = false;
        }
    }

    buildOrderPayload(status) {
        // Filter out must-sell items with qty 0 (placeholders only)
        const activeLineItems = this.lineItems.filter(item => item.quantity && item.quantity > 0);
        return {
            accountId: this.effectiveAccountId,
            visitId: this.visitId || this.recordId,
            status: status,
            remarks: this.orderRemarks,
            grossAmount: this.orderSummary.grossAmount,
            totalDiscount: this.orderSummary.totalDiscount,
            totalTax: this.orderSummary.totalTax,
            netAmount: this.orderSummary.netAmount,
            lineItems: activeLineItems.map(item => ({
                productId: item.productId,
                quantity: item.quantity,
                freeQty: item.freeQty,
                rate: item.rate,
                grossAmount: item.grossAmount,
                discountAmount: item.discountAmount,
                taxRate: item.taxRate,
                taxAmount: item.taxAmount,
                totalAmount: item.totalAmount,
                schemeId: item.schemeId
            }))
        };
    }

    validateOrder() {
        if (!this.effectiveAccountId) {
            this.showToast('Error', 'Please select an outlet', 'error');
            return false;
        }
        // Count non-must-sell items with valid qty
        const validItems = this.lineItems.filter(item => item.quantity && item.quantity > 0);
        if (validItems.length === 0) {
            this.showToast('Error', 'Add at least one product with quantity to the order', 'error');
            return false;
        }
        // Check non-must-sell items have valid qty
        const invalidNonMustSell = this.lineItems.filter(item => !item.isMustSell && (!item.quantity || item.quantity <= 0));
        if (invalidNonMustSell.length > 0) {
            this.showToast('Error', 'All non-priority line items must have a valid quantity', 'error');
            return false;
        }
        return true;
    }

    resetForm() {
        this.lineItems = [];
        this.productResults = [];
        this.searchTerm = '';
        this.selectedCategory = '';
        this.orderRemarks = '';
        this.calculateTotals();
    }

    getClassificationBadgeClass(classification) {
        if (classification === 'Must Sell') return 'oef-badge-must-sell';
        if (classification === 'Focused Sell') return 'oef-badge-focused-sell';
        return '';
    }

    formatCurrency(value) {
        if (value === null || value === undefined) return '₹0.00';
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: 'INR',
            minimumFractionDigits: 2
        }).format(value);
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        const date = new Date(dateStr);
        return date.toLocaleDateString('en-IN', {
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
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        return 'Unknown error';
    }
}
