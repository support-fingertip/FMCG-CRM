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
import getBatches from '@salesforce/apex/ProductManagementController.getBatches';
import saveBatch from '@salesforce/apex/ProductManagementController.saveBatch';
import deleteBatch from '@salesforce/apex/ProductManagementController.deleteBatch';
import getMustSellConfigs from '@salesforce/apex/ProductManagementController.getMustSellConfigs';
import saveMustSellConfig from '@salesforce/apex/ProductManagementController.saveMustSellConfig';
import deleteMustSellConfig from '@salesforce/apex/ProductManagementController.deleteMustSellConfig';
import getPriceChangeLogs from '@salesforce/apex/ProductManagementController.getPriceChangeLogs';
import searchProductsForLookup from '@salesforce/apex/ProductManagementController.searchProductsForLookup';

const PAGE_SIZE = 25;

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
    @track priceListActiveOnly = true;
    @track priceListPage = 1;
    @track priceListTotalPages = 1;
    @track priceListTotalCount = 0;
    @track showPriceListModal = false;
    @track editPriceList = {};
    @track isNewPriceList = false;

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

    // ── Product Lookup ─────────────────────────────────────────────────
    @track productLookupResults = [];
    @track showProductLookup = false;
    _lookupTimeout;

    // ── Computed Getters ───────────────────────────────────────────────

    get showDashboard() { return this.activeSection === 'dashboard'; }
    get showProducts() { return this.activeSection === 'products'; }
    get showCategories() { return this.activeSection === 'categories'; }
    get showPriceLists() { return this.activeSection === 'priceLists'; }
    get showBatches() { return this.activeSection === 'batches'; }
    get showMustSell() { return this.activeSection === 'mustSell'; }
    get showPriceChangeLogs() { return this.activeSection === 'priceChangeLogs'; }

    get dashboardNavClass() { return 'sidebar-item' + (this.activeSection === 'dashboard' ? ' active' : ''); }
    get productsNavClass() { return 'sidebar-item' + (this.activeSection === 'products' ? ' active' : ''); }
    get categoriesNavClass() { return 'sidebar-item' + (this.activeSection === 'categories' ? ' active' : ''); }
    get priceListsNavClass() { return 'sidebar-item' + (this.activeSection === 'priceLists' ? ' active' : ''); }
    get batchesNavClass() { return 'sidebar-item' + (this.activeSection === 'batches' ? ' active' : ''); }
    get mustSellNavClass() { return 'sidebar-item' + (this.activeSection === 'mustSell' ? ' active' : ''); }
    get priceChangeLogsNavClass() { return 'sidebar-item' + (this.activeSection === 'priceChangeLogs' ? ' active' : ''); }

    get sectionTitle() {
        const titles = {
            dashboard: 'Dashboard',
            products: 'Products',
            categories: 'Product Categories',
            priceLists: 'Price Lists',
            batches: 'Batch Master',
            mustSell: 'Must-Sell Configuration',
            priceChangeLogs: 'Price Change Logs'
        };
        return titles[this.activeSection] || 'Product Management';
    }

    get productModalTitle() { return this.isNewProduct ? 'New Product' : 'Edit Product'; }
    get categoryModalTitle() { return this.isNewCategory ? 'New Category' : 'Edit Category'; }
    get priceListModalTitle() { return this.isNewPriceList ? 'New Price List Entry' : 'Edit Price List Entry'; }
    get batchModalTitle() { return this.isNewBatch ? 'New Batch' : 'Edit Batch'; }
    get mustSellModalTitle() { return this.isNewMustSell ? 'New Must-Sell Config' : 'Edit Must-Sell Config'; }

    get hasProducts() { return this.products.length > 0; }
    get hasCategories() { return this.categories.length > 0; }
    get hasPriceLists() { return this.priceLists.length > 0; }
    get hasBatches() { return this.batches.length > 0; }
    get hasMustSellConfigs() { return this.mustSellConfigs.length > 0; }
    get hasPriceChangeLogs() { return this.priceChangeLogs.length > 0; }

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
    get uomOptions() {
        return [
            { label: 'Piece', value: 'Piece' },
            { label: 'Box', value: 'Box' },
            { label: 'Case', value: 'Case' },
            { label: 'Kg', value: 'Kg' },
            { label: 'Litre', value: 'Litre' },
            { label: 'Dozen', value: 'Dozen' },
            { label: 'Pack', value: 'Pack' }
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
                categoryName: p.Product_Category__r ? p.Product_Category__r.Name : ''
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
            Is_Active__c: true,
            Unit_of_Measure__c: 'Piece'
        };
        this.showProductModal = true;
    }

    handleEditProduct(event) {
        const productId = event.currentTarget.dataset.id;
        const product = this.products.find(p => p.Id === productId);
        if (product) {
            this.isNewProduct = false;
            this.editProduct = JSON.parse(JSON.stringify(product));
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
                activeOnly: this.priceListActiveOnly,
                pageNumber: this.priceListPage,
                pageSize: PAGE_SIZE
            });
            this.priceLists = result.priceLists.map(pl => ({
                ...pl,
                productName: pl.Product_Ext__r ? pl.Product_Ext__r.Name : '',
                productSku: pl.Product_Ext__r ? pl.Product_Ext__r.SKU_Code__c : ''
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
            Price_Type__c: 'MRP',
            Min_Qty__c: 1
        };
        this.showPriceListModal = true;
    }

    handleEditPriceList(event) {
        const plId = event.currentTarget.dataset.id;
        const pl = this.priceLists.find(p => p.Id === plId);
        if (pl) {
            this.isNewPriceList = false;
            this.editPriceList = JSON.parse(JSON.stringify(pl));
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
        this.showBatchModal = true;
    }

    handleEditBatch(event) {
        const bId = event.currentTarget.dataset.id;
        const batch = this.batches.find(b => b.Id === bId);
        if (batch) {
            this.isNewBatch = false;
            this.editBatch = JSON.parse(JSON.stringify(batch));
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
            this.showError('Error loading must-sell configs', this.reduceErrors(error));
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
        this.showMustSellModal = true;
    }

    handleEditMustSell(event) {
        const msId = event.currentTarget.dataset.id;
        const ms = this.mustSellConfigs.find(m => m.Id === msId);
        if (ms) {
            this.isNewMustSell = false;
            this.editMustSell = JSON.parse(JSON.stringify(ms));
            this.showMustSellModal = true;
        }
    }

    handleMustSellFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.editMustSell = { ...this.editMustSell, [field]: value };
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
            this.showError('Error saving must-sell config', this.reduceErrors(error));
        } finally {
            this.isSaving = false;
        }
    }

    async handleDeleteMustSell(event) {
        const msId = event.currentTarget.dataset.id;
        if (!confirm('Delete this must-sell config?')) return;
        try {
            await deleteMustSellConfig({ configId: msId });
            this.showSuccess('Must-sell config deleted');
            await this.loadMustSellConfigs();
        } catch (error) {
            this.showError('Error deleting must-sell config', this.reduceErrors(error));
        }
    }

    handleCloseMustSellModal() {
        this.showMustSellModal = false;
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
                productSku: log.Product_Ext__r ? log.Product_Ext__r.SKU_Code__c : ''
            }));
        } catch (error) {
            this.showError('Error loading price change logs', this.reduceErrors(error));
        }
    }

    // ── Product Lookup (for modal fields) ──────────────────────────────

    handleProductLookupSearch(event) {
        const searchTerm = event.target.value;
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
        }

        this.showProductLookup = false;
        this.productLookupResults = [];
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
        if (typeof error === 'string') return error;
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        if (Array.isArray(error?.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        return JSON.stringify(error);
    }
}
