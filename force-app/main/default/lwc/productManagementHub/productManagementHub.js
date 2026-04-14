import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import getDashboardStats from '@salesforce/apex/ProductManagementController.getDashboardStats';
import getProducts from '@salesforce/apex/ProductManagementController.getProducts';
import saveProduct from '@salesforce/apex/ProductManagementController.saveProduct';
import deleteProduct from '@salesforce/apex/ProductManagementController.deleteProduct';
import getCategories from '@salesforce/apex/ProductManagementController.getCategories';
import saveCategory from '@salesforce/apex/ProductManagementController.saveCategory';
import deleteCategory from '@salesforce/apex/ProductManagementController.deleteCategory';
import getPriceLists from '@salesforce/apex/ProductManagementController.getPriceLists';
import savePriceList from '@salesforce/apex/ProductManagementController.savePriceList';
import deletePriceList from '@salesforce/apex/ProductManagementController.deletePriceList';
import getPricebookPriorities from '@salesforce/apex/ProductManagementController.getPricebookPriorities';
import getBatches from '@salesforce/apex/ProductManagementController.getBatches';
import saveBatch from '@salesforce/apex/ProductManagementController.saveBatch';
import deleteBatch from '@salesforce/apex/ProductManagementController.deleteBatch';
import getMustSellConfigs from '@salesforce/apex/ProductManagementController.getMustSellConfigs';
import saveMustSellConfig from '@salesforce/apex/ProductManagementController.saveMustSellConfig';
import deleteMustSellConfig from '@salesforce/apex/ProductManagementController.deleteMustSellConfig';
import getPriceChangeLogs from '@salesforce/apex/ProductManagementController.getPriceChangeLogs';
import getUOMs from '@salesforce/apex/ProductManagementController.getUOMs';
import saveUOM from '@salesforce/apex/ProductManagementController.saveUOM';
import deleteUOMApex from '@salesforce/apex/ProductManagementController.deleteUOM';
import getUOMConversions from '@salesforce/apex/ProductManagementController.getUOMConversions';
import saveUOMConversion from '@salesforce/apex/ProductManagementController.saveUOMConversion';
import deleteUOMConversionApex from '@salesforce/apex/ProductManagementController.deleteUOMConversion';
import getActiveUOMsForLookup from '@salesforce/apex/ProductManagementController.getActiveUOMsForLookup';
import searchProductsForLookup from '@salesforce/apex/ProductManagementController.searchProductsForLookup';
import searchTerritoriesForLookup from '@salesforce/apex/ProductManagementController.searchTerritoriesForLookup';
import searchCategoriesForLookup from '@salesforce/apex/ProductManagementController.searchCategoriesForLookup';
import searchCustomersForLookup from '@salesforce/apex/ProductManagementController.searchCustomersForLookup';

const PAGE_SIZE = 25;

const PRIORITY_LABELS = {
    1: '1st - Customer',
    2: '2nd - Cat+Terr+Chan',
    3: '3rd - Terr+Chan',
    4: '4th - Cat+Terr',
    5: '5th - Territory',
    6: '6th - Channel',
    7: '7th - Category',
    8: '8th - Base Price'
};

export default class ProductManagementHub extends NavigationMixin(LightningElement) {

    // ── Navigation State ───────────────────────────────────────────────
    @track activeSection = 'dashboard';
    isLoading = false;
    isSaving = false;

    // ── Dashboard ──────────────────────────────────────────────────────
    @track stats = {};

    // ── Products ───────────────────────────────────────────────────────
    @track products = [];
    @track productSearchTerm = '';
    @track productActiveOnly = true;
    @track productCategoryFilter = '';
    @track productPage = 1;
    @track productTotalPages = 1;
    @track productTotalCount = 0;
    @track showProductModal = false;
    @track editProduct = {};
    @track isNewProduct = false;

    // ── Categories ─────────────────────────────────────────────────────
    @track categories = [];
    @track showCategoryModal = false;
    @track editCategory = {};
    @track isNewCategory = false;
    @track parentCategoryOptions = [];

    // ── Price Lists ────────────────────────────────────────────────────
    @track priceLists = [];
    @track priceListProductFilter = '';
    @track priceListChannelFilter = '';
    @track priceListPriorityFilter = '';
    @track priceListActiveOnly = true;
    @track priceListPage = 1;
    @track priceListTotalPages = 1;
    @track priceListTotalCount = 0;
    @track showPriceListModal = false;
    @track editPriceList = {};
    @track isNewPriceList = false;
    @track pricebookPriorities = [];

    // ── Batches ────────────────────────────────────────────────────────
    @track batches = [];
    @track batchProductFilter = '';
    @track batchStatusFilter = '';
    @track showBatchModal = false;
    @track editBatch = {};
    @track isNewBatch = false;

    // ── Must-Sell Configs ──────────────────────────────────────────────
    @track mustSellConfigs = [];
    @track mustSellActiveOnly = true;
    @track showMustSellModal = false;
    @track editMustSell = {};
    @track isNewMustSell = false;

    // ── Price Change Logs ──────────────────────────────────────────────
    @track priceChangeLogs = [];
    @track priceLogProductFilter = '';

    // ── UOM Master ───────────────────────────────────────────────────────
    @track uomList = [];
    @track showUOMModal = false;
    @track editUOM = {};
    @track isNewUOM = false;

    // ── UOM Conversions ──────────────────────────────────────────────────
    @track uomConversions = [];
    @track uomConvProductFilter = '';
    @track showUOMConvModal = false;
    @track editUOMConv = {};
    @track isNewUOMConv = false;
    @track uomLookupOptions = [];

    // ── UOM Lookup (for product Base_UOM and conversion modal) ───────────
    @track uomLookupResults = [];
    @track showUOMLookup = false;
    @track selectedUOMName = '';
    @track uomLookupSearchTerm = '';
    _uomLookupTimeout;

    // ── Product Lookup ─────────────────────────────────────────────────
    @track productLookupResults = [];
    @track showProductLookup = false;
    @track selectedProductName = '';
    @track productLookupSearchTerm = '';
    _lookupTimeout;

    // ── Territory Lookup ────────────────────────────────────────────────
    @track territoryLookupResults = [];
    @track showTerritoryLookup = false;
    @track selectedTerritoryName = '';
    @track territoryLookupSearchTerm = '';
    _territoryLookupTimeout;

    // ── Category Lookup (for Price List) ────────────────────────────────
    @track categoryLookupResults = [];
    @track showCategoryLookup = false;
    @track selectedCategoryName = '';
    @track categoryLookupSearchTerm = '';
    _categoryLookupTimeout;

    // ── Customer Lookup (for Price List) ────────────────────────────────
    @track customerLookupResults = [];
    @track showCustomerLookup = false;
    @track selectedCustomerName = '';
    @track customerLookupSearchTerm = '';
    _customerLookupTimeout;

    // ── Computed Getters ───────────────────────────────────────────────

    get showDashboard() { return this.activeSection === 'dashboard'; }
    get showProducts() { return this.activeSection === 'products'; }
    get showCategories() { return this.activeSection === 'categories'; }
    get showPriceLists() { return this.activeSection === 'priceLists'; }
    get showBatches() { return this.activeSection === 'batches'; }
    get showMustSell() { return this.activeSection === 'mustSell'; }
    get showPriceChangeLogs() { return this.activeSection === 'priceChangeLogs'; }
    get showPricebookConfig() { return this.activeSection === 'pricebookConfig'; }
    get showUOMMaster() { return this.activeSection === 'uomMaster'; }
    get showUOMConversions() { return this.activeSection === 'uomConversions'; }

    get dashboardNavClass() { return 'sidebar-item' + (this.activeSection === 'dashboard' ? ' active' : ''); }
    get productsNavClass() { return 'sidebar-item' + (this.activeSection === 'products' ? ' active' : ''); }
    get categoriesNavClass() { return 'sidebar-item' + (this.activeSection === 'categories' ? ' active' : ''); }
    get priceListsNavClass() { return 'sidebar-item' + (this.activeSection === 'priceLists' ? ' active' : ''); }
    get batchesNavClass() { return 'sidebar-item' + (this.activeSection === 'batches' ? ' active' : ''); }
    get mustSellNavClass() { return 'sidebar-item' + (this.activeSection === 'mustSell' ? ' active' : ''); }
    get priceChangeLogsNavClass() { return 'sidebar-item' + (this.activeSection === 'priceChangeLogs' ? ' active' : ''); }
    get pricebookConfigNavClass() { return 'sidebar-item' + (this.activeSection === 'pricebookConfig' ? ' active' : ''); }
    get uomMasterNavClass() { return 'sidebar-item' + (this.activeSection === 'uomMaster' ? ' active' : ''); }
    get uomConversionsNavClass() { return 'sidebar-item' + (this.activeSection === 'uomConversions' ? ' active' : ''); }

    get sectionTitle() {
        const titles = {
            dashboard: 'Dashboard',
            products: 'Products',
            categories: 'Product Categories',
            priceLists: 'Price Lists',
            batches: 'Batch Master',
            mustSell: 'Priority Sell Configuration',
            priceChangeLogs: 'Price Change Logs',
            pricebookConfig: 'Pricebook Priority Configuration',
            uomMaster: 'Unit of Measure (UOM) Master',
            uomConversions: 'UOM Conversions'
        };
        return titles[this.activeSection] || 'Product Management';
    }

    get productModalTitle() { return this.isNewProduct ? 'New Product' : 'Edit Product'; }
    get categoryModalTitle() { return this.isNewCategory ? 'New Category' : 'Edit Category'; }
    get priceListModalTitle() { return this.isNewPriceList ? 'New Price List Entry' : 'Edit Price List Entry'; }
    get batchModalTitle() { return this.isNewBatch ? 'New Batch' : 'Edit Batch'; }
    get mustSellModalTitle() { return this.isNewMustSell ? 'New Priority Sell Config' : 'Edit Priority Sell Config'; }
    get uomModalTitle() { return this.isNewUOM ? 'New UOM' : 'Edit UOM'; }
    get uomConvModalTitle() { return this.isNewUOMConv ? 'New Conversion Rule' : 'Edit Conversion Rule'; }

    get hasProducts() { return this.products.length > 0; }
    get hasCategories() { return this.categories.length > 0; }
    get hasPriceLists() { return this.priceLists.length > 0; }
    get hasBatches() { return this.batches.length > 0; }
    get hasMustSellConfigs() { return this.mustSellConfigs.length > 0; }
    get hasPriceChangeLogs() { return this.priceChangeLogs.length > 0; }
    get hasPricebookPriorities() { return this.pricebookPriorities.length > 0; }
    get hasUOMs() { return this.uomList.length > 0; }
    get hasUOMConversions() { return this.uomConversions.length > 0; }
    get hasSelectedUOM() { return !!this.selectedUOMName; }

    get productPageInfo() {
        return `Page ${this.productPage} of ${this.productTotalPages} (${this.productTotalCount} records)`;
    }
    get priceListPageInfo() {
        return `Page ${this.priceListPage} of ${this.priceListTotalPages} (${this.priceListTotalCount} records)`;
    }
    get isFirstProductPage() { return this.productPage <= 1; }
    get isLastProductPage() { return this.productPage >= this.productTotalPages; }
    get isFirstPriceListPage() { return this.priceListPage <= 1; }
    get isLastPriceListPage() { return this.priceListPage >= this.priceListTotalPages; }

    get categoryLevelOptions() {
        return [
            { label: 'Category', value: 'Category' },
            { label: 'Sub-Category', value: 'Sub-Category' },
            { label: 'Brand', value: 'Brand' }
        ];
    }
    get channelOptions() {
        return [
            { label: 'GT', value: 'GT' },
            { label: 'MT', value: 'MT' },
            { label: 'E-Commerce', value: 'E-Commerce' }
        ];
    }
    get priceTypeOptions() {
        return [
            { label: 'MRP', value: 'MRP' },
            { label: 'Distributor Price', value: 'Distributor Price' },
            { label: 'Retailer Price', value: 'Retailer Price' },
            { label: 'Special Price', value: 'Special Price' }
        ];
    }
    get batchStatusOptions() {
        return [
            { label: 'Active', value: 'Active' },
            { label: 'Recalled', value: 'Recalled' },
            { label: 'Expired', value: 'Expired' }
        ];
    }
    get weightUnitOptions() {
        return [
            { label: 'g', value: 'g' },
            { label: 'kg', value: 'kg' },
            { label: 'ml', value: 'ml' },
            { label: 'l', value: 'l' },
            { label: 'oz', value: 'oz' },
            { label: 'lb', value: 'lb' }
        ];
    }
    get classificationOptions() {
        return [
            { label: 'Must Sell', value: 'Must Sell' },
            { label: 'Focused Sell', value: 'Focused Sell' }
        ];
    }
    get customerTypeOptions() {
        return [
            { label: 'Retailer', value: 'Retailer' },
            { label: 'Distributor', value: 'Distributor' },
            { label: 'Super Stockist', value: 'Super Stockist' },
            { label: 'Modern Trade', value: 'Modern Trade' }
        ];
    }
    get outletTypeOptions() {
        return [
            { label: 'Grocery', value: 'Grocery' },
            { label: 'Medical', value: 'Medical' },
            { label: 'Hardware', value: 'Hardware' },
            { label: 'General Store', value: 'General Store' },
            { label: 'Cosmetics', value: 'Cosmetics' },
            { label: 'Pan Shop', value: 'Pan Shop' }
        ];
    }
    get uomTypeOptions() {
        return [
            { label: 'Count', value: 'Count' },
            { label: 'Weight', value: 'Weight' },
            { label: 'Volume', value: 'Volume' },
            { label: 'Length', value: 'Length' },
            { label: 'Packaging', value: 'Packaging' }
        ];
    }
    get batchStatusFilterOptions() {
        return [
            { label: 'All', value: '' },
            { label: 'Active', value: 'Active' },
            { label: 'Recalled', value: 'Recalled' },
            { label: 'Expired', value: 'Expired' }
        ];
    }
    get channelFilterOptions() {
        return [
            { label: 'All Channels', value: '' },
            { label: 'GT', value: 'GT' },
            { label: 'MT', value: 'MT' },
            { label: 'E-Commerce', value: 'E-Commerce' }
        ];
    }
    get priorityFilterOptions() {
        return [
            { label: 'All Priorities', value: '' },
            { label: '1st - Customer', value: '1' },
            { label: '2nd - Cat+Terr+Chan', value: '2' },
            { label: '3rd - Terr+Chan', value: '3' },
            { label: '4th - Cat+Terr', value: '4' },
            { label: '5th - Territory', value: '5' },
            { label: '6th - Channel', value: '6' },
            { label: '7th - Category', value: '7' },
            { label: '8th - Base Price', value: '8' }
        ];
    }

    // ── Lifecycle ──────────────────────────────────────────────────────

    connectedCallback() {
        this.loadDashboard();
    }

    // ── Navigation ─────────────────────────────────────────────────────

    handleSectionChange(event) {
        const section = event.currentTarget.dataset.section;
        this.activeSection = section;
        this.loadSectionData(section);
    }

    async loadSectionData(section) {
        this.isLoading = true;
        try {
            switch (section) {
                case 'dashboard': await this.loadDashboard(); break;
                case 'products': await this.loadProducts(); break;
                case 'categories': await this.loadCategories(); break;
                case 'priceLists': await this.loadPriceLists(); break;
                case 'batches': await this.loadBatches(); break;
                case 'mustSell': await this.loadMustSellConfigs(); break;
                case 'priceChangeLogs': await this.loadPriceChangeLogs(); break;
                case 'pricebookConfig': await this.loadPricebookPriorities(); break;
                case 'uomMaster': await this.loadUOMs(); break;
                case 'uomConversions': await this.loadUOMConversions(); break;
                default: break;
            }
        } catch (error) {
            this.showError('Error loading data', this.reduceErrors(error));
        } finally {
            this.isLoading = false;
        }
    }

    // ── Dashboard ──────────────────────────────────────────────────────

    async loadDashboard() {
        this.isLoading = true;
        try {
            this.stats = await getDashboardStats();
        } catch (error) {
            this.showError('Error loading dashboard', this.reduceErrors(error));
        } finally {
            this.isLoading = false;
        }
    }

    handleStatClick(event) {
        const section = event.currentTarget.dataset.section;
        if (section) {
            this.activeSection = section;
            this.loadSectionData(section);
        }
    }

    // ── Products ───────────────────────────────────────────────────────

    async loadProducts() {
        try {
            const result = await getProducts({
                searchTerm: this.productSearchTerm,
                categoryId: this.productCategoryFilter,
                activeOnly: this.productActiveOnly,
                pageNumber: this.productPage,
                pageSize: PAGE_SIZE
            });
            this.products = result.products.map(p => ({
                ...p,
                categoryName: p.Product_Category__r ? p.Product_Category__r.Name : '',
                baseUOMName: p.Base_UOM__r ? p.Base_UOM__r.Name : '',
                baseUOMCode: p.Base_UOM__r ? p.Base_UOM__r.UOM_Code__c : ''
            }));
            this.productTotalPages = result.totalPages;
            this.productTotalCount = result.totalCount;
        } catch (error) {
            this.showError('Error loading products', this.reduceErrors(error));
        }
    }

    handleProductSearch(event) {
        this.productSearchTerm = event.target.value;
        clearTimeout(this._searchTimeout);
        this._searchTimeout = setTimeout(() => {
            this.productPage = 1;
            this.loadProducts();
        }, 300);
    }

    handleProductActiveFilter(event) {
        this.productActiveOnly = event.target.checked;
        this.productPage = 1;
        this.loadProducts();
    }

    handleProductPrevPage() {
        if (this.productPage > 1) {
            this.productPage--;
            this.loadProducts();
        }
    }

    handleProductNextPage() {
        if (this.productPage < this.productTotalPages) {
            this.productPage++;
            this.loadProducts();
        }
    }

    handleNewProduct() {
        this.isNewProduct = true;
        this.editProduct = {
            Is_Active__c: true
        };
        this.selectedUOMName = '';
        this.showProductModal = true;
    }

    handleEditProduct(event) {
        const productId = event.currentTarget.dataset.id;
        const product = this.products.find(p => p.Id === productId);
        if (product) {
            this.isNewProduct = false;
            this.editProduct = JSON.parse(JSON.stringify(product));
            this.selectedUOMName = product.baseUOMName || '';
            this.showProductModal = true;
        }
    }

    handleProductFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.editProduct = { ...this.editProduct, [field]: value };
    }

    async handleSaveProduct() {
        this.isSaving = true;
        try {
            const productToSave = { ...this.editProduct };
            // Remove relationship fields
            delete productToSave.Product_Category__r;
            delete productToSave.Base_UOM__r;
            delete productToSave.baseUOMName;
            delete productToSave.categoryName;
            await saveProduct({ product: productToSave });
            this.showProductModal = false;
            this.showSuccess(this.isNewProduct ? 'Product created' : 'Product updated');
            await this.loadProducts();
        } catch (error) {
            this.showError('Error saving product', this.reduceErrors(error));
        } finally {
            this.isSaving = false;
        }
    }

    async handleDeleteProduct(event) {
        const productId = event.currentTarget.dataset.id;
        const product = this.products.find(p => p.Id === productId);
        if (!confirm(`Delete product "${product.Name}"? This cannot be undone.`)) return;
        try {
            await deleteProduct({ productId });
            this.showSuccess('Product deleted');
            await this.loadProducts();
        } catch (error) {
            this.showError('Error deleting product', this.reduceErrors(error));
        }
    }

    handleCloseProductModal() {
        this.showProductModal = false;
    }

    // ── Categories ─────────────────────────────────────────────────────

    async loadCategories() {
        try {
            const rawCategories = await getCategories();
            this.categories = rawCategories.map(c => ({
                ...c,
                parentCategoryName: c.Parent_Category__r ? c.Parent_Category__r.Name : ''
            }));
            this.parentCategoryOptions = [
                { label: '-- None --', value: '' },
                ...this.categories
                    .filter(c => c.Level__c === 'Category')
                    .map(c => ({ label: c.Name, value: c.Id }))
            ];
        } catch (error) {
            this.showError('Error loading categories', this.reduceErrors(error));
        }
    }

    handleNewCategory() {
        this.isNewCategory = true;
        this.editCategory = { Is_Active__c: true, Level__c: 'Category', Sort_Order__c: 0 };
        this.showCategoryModal = true;
    }

    handleEditCategory(event) {
        const catId = event.currentTarget.dataset.id;
        const cat = this.categories.find(c => c.Id === catId);
        if (cat) {
            this.isNewCategory = false;
            this.editCategory = JSON.parse(JSON.stringify(cat));
            this.showCategoryModal = true;
        }
    }

    handleCategoryFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.editCategory = { ...this.editCategory, [field]: value };
    }

    async handleSaveCategory() {
        this.isSaving = true;
        try {
            const catToSave = { ...this.editCategory };
            delete catToSave.Parent_Category__r;
            if (catToSave.Parent_Category__c === '') {
                catToSave.Parent_Category__c = null;
            }
            await saveCategory({ category: catToSave });
            this.showCategoryModal = false;
            this.showSuccess(this.isNewCategory ? 'Category created' : 'Category updated');
            await this.loadCategories();
        } catch (error) {
            this.showError('Error saving category', this.reduceErrors(error));
        } finally {
            this.isSaving = false;
        }
    }

    async handleDeleteCategory(event) {
        const catId = event.currentTarget.dataset.id;
        const cat = this.categories.find(c => c.Id === catId);
        if (!confirm(`Delete category "${cat.Name}"?`)) return;
        try {
            await deleteCategory({ categoryId: catId });
            this.showSuccess('Category deleted');
            await this.loadCategories();
        } catch (error) {
            this.showError('Error deleting category', this.reduceErrors(error));
        }
    }

    handleCloseCategoryModal() {
        this.showCategoryModal = false;
    }

    // ── Price Lists ────────────────────────────────────────────────────

    async loadPriceLists() {
        try {
            const result = await getPriceLists({
                productId: this.priceListProductFilter || null,
                channel: this.priceListChannelFilter || null,
                region: null,
                categoryId: null,
                territoryId: null,
                customerId: null,
                priorityFilter: this.priceListPriorityFilter || null,
                activeOnly: this.priceListActiveOnly,
                pageNumber: this.priceListPage,
                pageSize: PAGE_SIZE
            });
            this.priceLists = result.priceLists.map(pl => ({
                ...pl,
                productName: pl.Product_Ext__r ? pl.Product_Ext__r.Name : '',
                productSku: pl.Product_Ext__r ? pl.Product_Ext__r.SKU_Code__c : '',
                customerName: pl.Customer__r ? pl.Customer__r.Name : '',
                categoryName: pl.Category__r ? pl.Category__r.Name : '',
                territoryName: pl.Territory__r ? pl.Territory__r.Name : '',
                priorityLabel: PRIORITY_LABELS[pl.Priority__c] || (pl.Priority__c != null ? 'P' + pl.Priority__c : '')
            }));
            this.priceListTotalPages = result.totalPages;
            this.priceListTotalCount = result.totalCount;
        } catch (error) {
            this.showError('Error loading price lists', this.reduceErrors(error));
        }
    }

    handlePriceListChannelFilter(event) {
        this.priceListChannelFilter = event.target.value;
        this.priceListPage = 1;
        this.loadPriceLists();
    }

    handlePriceListPriorityFilter(event) {
        this.priceListPriorityFilter = event.target.value;
        this.priceListPage = 1;
        this.loadPriceLists();
    }

    handlePriceListActiveFilter(event) {
        this.priceListActiveOnly = event.target.checked;
        this.priceListPage = 1;
        this.loadPriceLists();
    }

    handlePriceListPrevPage() {
        if (this.priceListPage > 1) {
            this.priceListPage--;
            this.loadPriceLists();
        }
    }

    handlePriceListNextPage() {
        if (this.priceListPage < this.priceListTotalPages) {
            this.priceListPage++;
            this.loadPriceLists();
        }
    }

    handleNewPriceList() {
        this.isNewPriceList = true;
        this.editPriceList = {
            Is_Active__c: true,
            Name: '',
            Min_Qty__c: 1
        };
        this.resetProductLookup();
        this.resetCategoryLookup();
        this.resetCustomerLookup();
        this.resetTerritoryLookup();
        this.showPriceListModal = true;
    }

    handleEditPriceList(event) {
        const plId = event.currentTarget.dataset.id;
        const pl = this.priceLists.find(p => p.Id === plId);
        if (pl) {
            this.isNewPriceList = false;
            this.editPriceList = JSON.parse(JSON.stringify(pl));
            this.selectedProductName = pl.productName || '';
            this.selectedCustomerName = pl.customerName || '';
            this.selectedCategoryName = pl.categoryName || '';
            this.selectedTerritoryName = pl.territoryName || '';
            this.showPriceListModal = true;
        }
    }

    handlePriceListFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.editPriceList = { ...this.editPriceList, [field]: value };
    }

    async handleSavePriceList() {
        this.isSaving = true;
        try {
            const plToSave = { ...this.editPriceList };
            delete plToSave.Product_Ext__r;
            delete plToSave.Customer__r;
            delete plToSave.Category__r;
            delete plToSave.Territory__r;
            // Remove computed fields
            delete plToSave.productName;
            delete plToSave.productSku;
            delete plToSave.customerName;
            delete plToSave.categoryName;
            delete plToSave.territoryName;
            delete plToSave.priorityLabel;
            await savePriceList({ priceList: plToSave });
            this.showPriceListModal = false;
            this.showSuccess(this.isNewPriceList ? 'Price list entry created' : 'Price list entry updated');
            await this.loadPriceLists();
        } catch (error) {
            this.showError('Error saving price list', this.reduceErrors(error));
        } finally {
            this.isSaving = false;
        }
    }

    async handleDeletePriceList(event) {
        const plId = event.currentTarget.dataset.id;
        if (!confirm('Delete this price list entry?')) return;
        try {
            await deletePriceList({ priceListId: plId });
            this.showSuccess('Price list entry deleted');
            await this.loadPriceLists();
        } catch (error) {
            this.showError('Error deleting price list', this.reduceErrors(error));
        }
    }

    handleClosePriceListModal() {
        this.showPriceListModal = false;
    }

    // ── Pricebook Priority Configuration ────────────────────────────────

    async loadPricebookPriorities() {
        try {
            const rawPriorities = await getPricebookPriorities();
            this.pricebookPriorities = rawPriorities.map(p => ({
                ...p,
                dimensionLabel: this.buildDimensionLabel(p)
            }));
        } catch (error) {
            this.showError('Error loading pricebook priorities', this.reduceErrors(error));
        }
    }

    buildDimensionLabel(priority) {
        const parts = [];
        if (priority.Has_Customer__c) parts.push('Customer');
        if (priority.Has_Category__c) parts.push('Category');
        if (priority.Has_Territory__c) parts.push('Territory');
        if (priority.Has_Channel__c) parts.push('Channel');
        return parts.length > 0 ? parts.join(' + ') : 'Base Price (No Dimensions)';
    }

    // ── Batches ────────────────────────────────────────────────────────

    async loadBatches() {
        try {
            const rawBatches = await getBatches({
                productId: this.batchProductFilter || null,
                status: this.batchStatusFilter || null
            });
            this.batches = rawBatches.map(b => ({
                ...b,
                productName: b.Product_Ext__r ? b.Product_Ext__r.Name : ''
            }));
        } catch (error) {
            this.showError('Error loading batches', this.reduceErrors(error));
        }
    }

    handleBatchStatusFilter(event) {
        this.batchStatusFilter = event.target.value;
        this.loadBatches();
    }

    handleNewBatch() {
        this.isNewBatch = true;
        this.editBatch = { Status__c: 'Active' };
        this.resetProductLookup();
        this.showBatchModal = true;
    }

    handleEditBatch(event) {
        const bId = event.currentTarget.dataset.id;
        const batch = this.batches.find(b => b.Id === bId);
        if (batch) {
            this.isNewBatch = false;
            this.editBatch = JSON.parse(JSON.stringify(batch));
            this.selectedProductName = batch.productName || '';
            this.showBatchModal = true;
        }
    }

    handleBatchFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.editBatch = { ...this.editBatch, [field]: value };
    }

    async handleSaveBatch() {
        this.isSaving = true;
        try {
            const bToSave = { ...this.editBatch };
            delete bToSave.Product_Ext__r;
            await saveBatch({ batch: bToSave });
            this.showBatchModal = false;
            this.showSuccess(this.isNewBatch ? 'Batch created' : 'Batch updated');
            await this.loadBatches();
        } catch (error) {
            this.showError('Error saving batch', this.reduceErrors(error));
        } finally {
            this.isSaving = false;
        }
    }

    async handleDeleteBatch(event) {
        const bId = event.currentTarget.dataset.id;
        if (!confirm('Delete this batch?')) return;
        try {
            await deleteBatch({ batchId: bId });
            this.showSuccess('Batch deleted');
            await this.loadBatches();
        } catch (error) {
            this.showError('Error deleting batch', this.reduceErrors(error));
        }
    }

    handleCloseBatchModal() {
        this.showBatchModal = false;
    }

    // ── Must-Sell Configs ──────────────────────────────────────────────

    async loadMustSellConfigs() {
        try {
            const rawConfigs = await getMustSellConfigs({
                activeOnly: this.mustSellActiveOnly
            });
            this.mustSellConfigs = rawConfigs.map(ms => ({
                ...ms,
                productName: ms.Product_Ext__r ? ms.Product_Ext__r.Name : '',
                productSku: ms.Product_Ext__r ? ms.Product_Ext__r.SKU_Code__c : '',
                territoryName: ms.Territory__r ? ms.Territory__r.Name : ''
            }));
        } catch (error) {
            this.showError('Error loading priority sell configs', this.reduceErrors(error));
        }
    }

    handleMustSellActiveFilter(event) {
        this.mustSellActiveOnly = event.target.checked;
        this.loadMustSellConfigs();
    }

    handleNewMustSell() {
        this.isNewMustSell = true;
        this.editMustSell = {
            Is_Active__c: true,
            Classification__c: 'Must Sell'
        };
        this.resetProductLookup();
        this.resetTerritoryLookup();
        this.showMustSellModal = true;
    }

    handleEditMustSell(event) {
        const msId = event.currentTarget.dataset.id;
        const ms = this.mustSellConfigs.find(m => m.Id === msId);
        if (ms) {
            this.isNewMustSell = false;
            this.editMustSell = JSON.parse(JSON.stringify(ms));
            this.selectedProductName = ms.productName || '';
            this.selectedTerritoryName = ms.territoryName || '';
            this.showMustSellModal = true;
        }
    }

    handleMustSellFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        const updated = { ...this.editMustSell, [field]: value };

        // Enforce mutual exclusivity: Territory vs Channel vs Customer Type
        if (field === 'Channel__c' && value) {
            updated.Territory__c = null;
            updated.Customer_Type__c = '';
            this.resetTerritoryLookup();
        } else if (field === 'Customer_Type__c' && value) {
            updated.Territory__c = null;
            updated.Channel__c = '';
            this.resetTerritoryLookup();
        }

        this.editMustSell = updated;
    }

    async handleSaveMustSell() {
        this.isSaving = true;
        try {
            const msToSave = { ...this.editMustSell };
            delete msToSave.Product_Ext__r;
            delete msToSave.Territory__r;
            await saveMustSellConfig({ config: msToSave });
            this.showMustSellModal = false;
            this.showSuccess(this.isNewMustSell ? 'Must-sell config created' : 'Must-sell config updated');
            await this.loadMustSellConfigs();
        } catch (error) {
            this.showError('Error saving priority sell config', this.reduceErrors(error));
        } finally {
            this.isSaving = false;
        }
    }

    async handleDeleteMustSell(event) {
        const msId = event.currentTarget.dataset.id;
        if (!confirm('Delete this priority sell config?')) return;
        try {
            await deleteMustSellConfig({ configId: msId });
            this.showSuccess('Must-sell config deleted');
            await this.loadMustSellConfigs();
        } catch (error) {
            this.showError('Error deleting priority sell config', this.reduceErrors(error));
        }
    }

    handleCloseMustSellModal() {
        this.showMustSellModal = false;
        this.resetTerritoryLookup();
    }

    // ── Price Change Logs ──────────────────────────────────────────────

    async loadPriceChangeLogs() {
        try {
            const rawLogs = await getPriceChangeLogs({
                productId: this.priceLogProductFilter || null
            });
            this.priceChangeLogs = rawLogs.map(log => ({
                ...log,
                productName: log.Product_Ext__r ? log.Product_Ext__r.Name : '',
                productSku: log.Product_Ext__r ? log.Product_Ext__r.SKU_Code__c : '',
                customerName: log.Customer__r ? log.Customer__r.Name : '',
                categoryName: log.Category__r ? log.Category__r.Name : '',
                territoryName: log.Territory__r ? log.Territory__r.Name : '',
                priorityLabel: PRIORITY_LABELS[log.Priority__c] || ''
            }));
        } catch (error) {
            this.showError('Error loading price change logs', this.reduceErrors(error));
        }
    }

    // ── Product Lookup (for modal fields) ──────────────────────────────

    get hasSelectedProduct() {
        return !!this.selectedProductName;
    }

    get hasSelectedTerritory() {
        return !!this.selectedTerritoryName;
    }

    get hasSelectedCategory() {
        return !!this.selectedCategoryName;
    }

    get hasSelectedCustomer() {
        return !!this.selectedCustomerName;
    }

    get isTerritoryDisabled() {
        return !!this.editMustSell.Channel__c || !!this.editMustSell.Customer_Type__c;
    }

    get isChannelDisabled() {
        return !!this.editMustSell.Territory__c || !!this.editMustSell.Customer_Type__c;
    }

    get isCustomerTypeDisabled() {
        return !!this.editMustSell.Territory__c || !!this.editMustSell.Channel__c;
    }

    resetProductLookup() {
        this.selectedProductName = '';
        this.productLookupSearchTerm = '';
        this.productLookupResults = [];
        this.showProductLookup = false;
    }

    handleProductLookupSearch(event) {
        const searchTerm = event.target.value;
        this.productLookupSearchTerm = searchTerm;
        clearTimeout(this._lookupTimeout);
        if (searchTerm.length < 2) {
            this.productLookupResults = [];
            this.showProductLookup = false;
            return;
        }
        this._lookupTimeout = setTimeout(async () => {
            try {
                this.productLookupResults = await searchProductsForLookup({ searchTerm });
                this.showProductLookup = this.productLookupResults.length > 0;
            } catch (error) {
                this.productLookupResults = [];
                this.showProductLookup = false;
            }
        }, 300);
    }

    handleSelectLookupProduct(event) {
        const productId = event.currentTarget.dataset.id;
        const productName = event.currentTarget.dataset.name;
        const targetObject = event.currentTarget.dataset.target;

        if (targetObject === 'priceList') {
            this.editPriceList = { ...this.editPriceList, Product_Ext__c: productId };
        } else if (targetObject === 'batch') {
            this.editBatch = { ...this.editBatch, Product_Ext__c: productId };
        } else if (targetObject === 'mustSell') {
            this.editMustSell = { ...this.editMustSell, Product_Ext__c: productId };
        } else if (targetObject === 'uomConv') {
            this.editUOMConv = { ...this.editUOMConv, Product__c: productId };
        }

        this.selectedProductName = productName;
        this.productLookupSearchTerm = '';
        this.showProductLookup = false;
        this.productLookupResults = [];
    }

    handleClearProductSelection(event) {
        const targetObject = event.currentTarget.dataset.target;

        if (targetObject === 'priceList') {
            this.editPriceList = { ...this.editPriceList, Product_Ext__c: null };
        } else if (targetObject === 'batch') {
            this.editBatch = { ...this.editBatch, Product_Ext__c: null };
        } else if (targetObject === 'mustSell') {
            this.editMustSell = { ...this.editMustSell, Product_Ext__c: null };
        } else if (targetObject === 'uomConv') {
            this.editUOMConv = { ...this.editUOMConv, Product__c: null };
        }

        this.resetProductLookup();
    }

    // ── Territory Lookup (for Must-Sell and Price List modals) ──────────

    resetTerritoryLookup() {
        this.selectedTerritoryName = '';
        this.territoryLookupSearchTerm = '';
        this.territoryLookupResults = [];
        this.showTerritoryLookup = false;
    }

    handleTerritoryLookupSearch(event) {
        const searchTerm = event.target.value;
        this.territoryLookupSearchTerm = searchTerm;
        clearTimeout(this._territoryLookupTimeout);
        if (searchTerm.length < 2) {
            this.territoryLookupResults = [];
            this.showTerritoryLookup = false;
            return;
        }
        this._territoryLookupTimeout = setTimeout(async () => {
            try {
                this.territoryLookupResults = await searchTerritoriesForLookup({ searchTerm });
                this.showTerritoryLookup = this.territoryLookupResults.length > 0;
            } catch (error) {
                this.territoryLookupResults = [];
                this.showTerritoryLookup = false;
            }
        }, 300);
    }

    handleSelectLookupTerritory(event) {
        const territoryId = event.currentTarget.dataset.id;
        const territoryName = event.currentTarget.dataset.name;
        const targetObject = event.currentTarget.dataset.target;

        if (targetObject === 'priceList') {
            this.editPriceList = { ...this.editPriceList, Territory__c: territoryId };
        } else {
            // Must-sell: Enforce mutual exclusivity
            this.editMustSell = {
                ...this.editMustSell,
                Territory__c: territoryId,
                Channel__c: '',
                Customer_Type__c: ''
            };
        }

        this.selectedTerritoryName = territoryName;
        this.territoryLookupSearchTerm = '';
        this.showTerritoryLookup = false;
        this.territoryLookupResults = [];
    }

    handleClearTerritorySelection(event) {
        const targetObject = event.currentTarget ? event.currentTarget.dataset.target : '';

        if (targetObject === 'priceList') {
            this.editPriceList = { ...this.editPriceList, Territory__c: null };
        } else {
            this.editMustSell = { ...this.editMustSell, Territory__c: null };
        }

        this.resetTerritoryLookup();
    }

    // ── Category Lookup (for Price List modal) ──────────────────────────

    resetCategoryLookup() {
        this.selectedCategoryName = '';
        this.categoryLookupSearchTerm = '';
        this.categoryLookupResults = [];
        this.showCategoryLookup = false;
    }

    handleCategoryLookupSearch(event) {
        const searchTerm = event.target.value;
        this.categoryLookupSearchTerm = searchTerm;
        clearTimeout(this._categoryLookupTimeout);
        if (searchTerm.length < 2) {
            this.categoryLookupResults = [];
            this.showCategoryLookup = false;
            return;
        }
        this._categoryLookupTimeout = setTimeout(async () => {
            try {
                this.categoryLookupResults = await searchCategoriesForLookup({ searchTerm });
                this.showCategoryLookup = this.categoryLookupResults.length > 0;
            } catch (error) {
                this.categoryLookupResults = [];
                this.showCategoryLookup = false;
            }
        }, 300);
    }

    handleSelectLookupCategory(event) {
        const categoryId = event.currentTarget.dataset.id;
        const categoryName = event.currentTarget.dataset.name;

        this.editPriceList = { ...this.editPriceList, Category__c: categoryId };
        this.selectedCategoryName = categoryName;
        this.categoryLookupSearchTerm = '';
        this.showCategoryLookup = false;
        this.categoryLookupResults = [];
    }

    handleClearCategorySelection() {
        this.editPriceList = { ...this.editPriceList, Category__c: null };
        this.resetCategoryLookup();
    }

    // ── Customer Lookup (for Price List modal) ──────────────────────────

    resetCustomerLookup() {
        this.selectedCustomerName = '';
        this.customerLookupSearchTerm = '';
        this.customerLookupResults = [];
        this.showCustomerLookup = false;
    }

    handleCustomerLookupSearch(event) {
        const searchTerm = event.target.value;
        this.customerLookupSearchTerm = searchTerm;
        clearTimeout(this._customerLookupTimeout);
        if (searchTerm.length < 2) {
            this.customerLookupResults = [];
            this.showCustomerLookup = false;
            return;
        }
        this._customerLookupTimeout = setTimeout(async () => {
            try {
                this.customerLookupResults = await searchCustomersForLookup({ searchTerm });
                this.showCustomerLookup = this.customerLookupResults.length > 0;
            } catch (error) {
                this.customerLookupResults = [];
                this.showCustomerLookup = false;
            }
        }, 300);
    }

    handleSelectLookupCustomer(event) {
        const customerId = event.currentTarget.dataset.id;
        const customerName = event.currentTarget.dataset.name;

        this.editPriceList = { ...this.editPriceList, Customer__c: customerId };
        this.selectedCustomerName = customerName;
        this.customerLookupSearchTerm = '';
        this.showCustomerLookup = false;
        this.customerLookupResults = [];
    }

    handleClearCustomerSelection() {
        this.editPriceList = { ...this.editPriceList, Customer__c: null };
        this.resetCustomerLookup();
    }

    // ── UOM Master ────────────────────────────────────────────────────

    async loadUOMs() {
        try {
            this.uomList = await getUOMs();
        } catch (error) {
            this.showError('Error loading UOMs', this.reduceErrors(error));
        }
    }

    handleNewUOM() {
        this.isNewUOM = true;
        this.editUOM = { Is_Active__c: true, UOM_Type__c: 'Count' };
        this.showUOMModal = true;
    }

    handleEditUOM(event) {
        const uomId = event.currentTarget.dataset.id;
        const uom = this.uomList.find(u => u.Id === uomId);
        if (uom) {
            this.isNewUOM = false;
            this.editUOM = JSON.parse(JSON.stringify(uom));
            this.showUOMModal = true;
        }
    }

    handleUOMFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.editUOM = { ...this.editUOM, [field]: value };
    }

    async handleSaveUOM() {
        this.isSaving = true;
        try {
            await saveUOM({ uom: this.editUOM });
            this.showUOMModal = false;
            this.showSuccess(this.isNewUOM ? 'UOM created' : 'UOM updated');
            await this.loadUOMs();
        } catch (error) {
            this.showError('Error saving UOM', this.reduceErrors(error));
        } finally {
            this.isSaving = false;
        }
    }

    async handleDeleteUOM(event) {
        const uomId = event.currentTarget.dataset.id;
        const uom = this.uomList.find(u => u.Id === uomId);
        if (!confirm(`Delete UOM "${uom.Name}"? This cannot be undone.`)) return;
        try {
            await deleteUOMApex({ uomId });
            this.showSuccess('UOM deleted');
            await this.loadUOMs();
        } catch (error) {
            this.showError('Error deleting UOM', this.reduceErrors(error));
        }
    }

    handleCloseUOMModal() {
        this.showUOMModal = false;
    }

    // ── UOM Conversions ──────────────────────────────────────────────

    async loadUOMConversions() {
        try {
            const rawConversions = await getUOMConversions({
                productId: this.uomConvProductFilter || null
            });
            this.uomConversions = rawConversions.map(c => ({
                ...c,
                fromUOMName: c.From_UOM__r ? `${c.From_UOM__r.Name} (${c.From_UOM__r.UOM_Code__c})` : '',
                toUOMName: c.To_UOM__r ? `${c.To_UOM__r.Name} (${c.To_UOM__r.UOM_Code__c})` : '',
                productName: c.Product__r ? c.Product__r.Name : 'Global'
            }));
            // Also load UOM options for the conversion modal dropdowns
            const activeUOMs = await getActiveUOMsForLookup();
            this.uomLookupOptions = activeUOMs.map(u => ({
                label: `${u.Name} (${u.UOM_Code__c})`,
                value: u.Id
            }));
        } catch (error) {
            this.showError('Error loading UOM conversions', this.reduceErrors(error));
        }
    }

    handleNewUOMConv() {
        this.isNewUOMConv = true;
        this.editUOMConv = { Is_Active__c: true };
        this.resetProductLookup();
        this.showUOMConvModal = true;
    }

    handleEditUOMConv(event) {
        const convId = event.currentTarget.dataset.id;
        const conv = this.uomConversions.find(c => c.Id === convId);
        if (conv) {
            this.isNewUOMConv = false;
            this.editUOMConv = JSON.parse(JSON.stringify(conv));
            this.selectedProductName = conv.productName !== 'Global' ? conv.productName : '';
            this.showUOMConvModal = true;
        }
    }

    handleUOMConvFieldChange(event) {
        const field = event.target.dataset.field;
        let value;
        if (event.target.type === 'checkbox') {
            value = event.target.checked;
        } else if (event.target.type === 'number') {
            value = event.target.value !== '' ? parseFloat(event.target.value) : null;
        } else {
            value = event.target.value;
        }
        this.editUOMConv = { ...this.editUOMConv, [field]: value };
    }

    async handleSaveUOMConv() {
        if (!this.editUOMConv.From_UOM__c || !this.editUOMConv.To_UOM__c || !this.editUOMConv.Conversion_Factor__c) {
            this.showError('Validation Error', 'From UOM, To UOM, and Conversion Factor are required.');
            return;
        }
        this.isSaving = true;
        try {
            const convToSave = { ...this.editUOMConv };
            delete convToSave.From_UOM__r;
            delete convToSave.To_UOM__r;
            delete convToSave.Product__r;
            delete convToSave.fromUOMName;
            delete convToSave.toUOMName;
            delete convToSave.productName;
            await saveUOMConversion({ conversion: convToSave });
            this.showUOMConvModal = false;
            this.showSuccess(this.isNewUOMConv ? 'Conversion rule created' : 'Conversion rule updated');
            await this.loadUOMConversions();
        } catch (error) {
            this.showError('Error saving conversion', this.reduceErrors(error));
        } finally {
            this.isSaving = false;
        }
    }

    async handleDeleteUOMConv(event) {
        const convId = event.currentTarget.dataset.id;
        if (!confirm('Delete this conversion rule?')) return;
        try {
            await deleteUOMConversionApex({ conversionId: convId });
            this.showSuccess('Conversion rule deleted');
            await this.loadUOMConversions();
        } catch (error) {
            this.showError('Error deleting conversion', this.reduceErrors(error));
        }
    }

    handleCloseUOMConvModal() {
        this.showUOMConvModal = false;
    }

    // ── UOM Lookup (for product Base_UOM field) ─────────────────────

    resetUOMLookup() {
        this.selectedUOMName = '';
        this.uomLookupSearchTerm = '';
        this.uomLookupResults = [];
        this.showUOMLookup = false;
    }

    handleUOMLookupSearch(event) {
        const searchTerm = event.target.value;
        this.uomLookupSearchTerm = searchTerm;
        clearTimeout(this._uomLookupTimeout);
        if (searchTerm.length < 1) {
            this.uomLookupResults = [];
            this.showUOMLookup = false;
            return;
        }
        this._uomLookupTimeout = setTimeout(async () => {
            try {
                const allUOMs = await getActiveUOMsForLookup();
                const lowerSearch = searchTerm.toLowerCase();
                this.uomLookupResults = allUOMs.filter(u =>
                    u.Name.toLowerCase().includes(lowerSearch) ||
                    u.UOM_Code__c.toLowerCase().includes(lowerSearch)
                ).slice(0, 10);
                this.showUOMLookup = this.uomLookupResults.length > 0;
            } catch (error) {
                this.uomLookupResults = [];
                this.showUOMLookup = false;
            }
        }, 200);
    }

    handleSelectUOM(event) {
        const uomId = event.currentTarget.dataset.id;
        const uomName = event.currentTarget.dataset.name;
        this.editProduct = { ...this.editProduct, Base_UOM__c: uomId };
        this.selectedUOMName = uomName;
        this.uomLookupSearchTerm = '';
        this.showUOMLookup = false;
        this.uomLookupResults = [];
    }

    handleClearUOMSelection() {
        this.editProduct = { ...this.editProduct, Base_UOM__c: null };
        this.resetUOMLookup();
    }

    // ── Utility ────────────────────────────────────────────────────────

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message,
            variant: 'success'
        }));
    }

    showError(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message: message || 'An unexpected error occurred',
            variant: 'error'
        }));
    }

    reduceErrors(error) {
        if (!error) return 'Unknown error';
        if (typeof error === 'string') return error;

        // Array of errors (e.g. multiple wire errors)
        if (Array.isArray(error)) {
            return error.map(e => this.reduceErrors(e)).filter(Boolean).join(', ');
        }

        // Standard AuraHandledException shape
        if (error.body && typeof error.body.message === 'string' && error.body.message.trim()) {
            return error.body.message;
        }

        // DML exception composite shape:
        //   body = [{ errors: [{ message, statusCode }], pageErrors: [], ... }]
        if (error.body && Array.isArray(error.body)) {
            const messages = [];
            error.body.forEach(entry => {
                if (entry && Array.isArray(entry.errors)) {
                    entry.errors.forEach(e => { if (e && e.message) messages.push(e.message); });
                }
                if (entry && Array.isArray(entry.pageErrors)) {
                    entry.pageErrors.forEach(e => { if (e && e.message) messages.push(e.message); });
                }
                if (entry && typeof entry.message === 'string') {
                    messages.push(entry.message);
                }
            });
            if (messages.length) return messages.join(', ');
        }

        // pageErrors / fieldErrors directly on body
        if (error.body && Array.isArray(error.body.pageErrors) && error.body.pageErrors.length) {
            return error.body.pageErrors.map(e => e.message).filter(Boolean).join(', ');
        }
        if (error.body && error.body.fieldErrors) {
            const fieldMessages = [];
            Object.keys(error.body.fieldErrors).forEach(field => {
                const entries = error.body.fieldErrors[field] || [];
                entries.forEach(e => { if (e && e.message) fieldMessages.push(e.message); });
            });
            if (fieldMessages.length) return fieldMessages.join(', ');
        }

        // AuraHandledException output wrapper
        if (error.body && error.body.output && Array.isArray(error.body.output.errors)
            && error.body.output.errors.length) {
            return error.body.output.errors.map(e => e.message).filter(Boolean).join(', ');
        }

        if (typeof error.message === 'string' && error.message.trim()) return error.message;
        if (typeof error.statusText === 'string' && error.statusText.trim()) return error.statusText;

        return 'Save failed. Please review the form and try again.';
    }
}
