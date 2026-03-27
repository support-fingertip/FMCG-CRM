import { LightningElement, track, wire } from 'lwc';
import getAllObjects from '@salesforce/apex/TAM_TargetCriteria_Controller.getAllObjects';
import getAllCriteria from '@salesforce/apex/TAM_TargetCriteria_Controller.getAllCriteria';
import getFieldMetadata from '@salesforce/apex/TAM_FieldMetadata_Service.getFields';
import getCriteria from '@salesforce/apex/TAM_TargetCriteria_Controller.getCriteria';
import saveCriteria from '@salesforce/apex/TAM_TargetCriteria_Controller.saveCriteria';
import deleteCriteria from '@salesforce/apex/TAM_TargetCriteria_Controller.deleteCriteria';
import getLinkedTargetCount from '@salesforce/apex/TAM_TargetCriteria_Controller.getLinkedTargetCount';
import FilterLogicValidator from 'c/tamFilterLogicValidator';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TamCriteriaBuilder extends LightningElement {

    // ===== VIEW STATE =====
    currentView = 'list'; // 'list', 'detail', 'builder'

    // ===== LIST STATE =====
    @track criteriaList = [];

    // ===== DETAIL STATE =====
    @track selectedCriteria = {};

    // ===== DELETE STATE =====
    @track showDeleteConfirm = false;
    deleteTargetId = null;
    @track deleteTargetName = '';

    // ===== BUILDER STATE =====
    @track criteria = {};
    @track currentStep = 1;
    @track fieldsMetadata = [];
    @track numberFieldOptions = [];
    @track dateFieldOptions = [];
    @track userFieldOptions = [];

    allObjects = [];
    @track objectSearchText = '';
    @track showObjectDropdown = false;
    @track filteredObjects = [];

    @track filters = [];
    @track logicError = null;
    @track autoFilterLogic = true;
    @track isLoading = false;

    operatorOptions = [
        { label: 'SUM', value: 'SUM' },
        { label: 'COUNT', value: 'COUNT' }
    ];

    // ===== LIFECYCLE =====
    connectedCallback() {
        this.loadCriteriaList();
    }

    loadCriteriaList() {
        this.isLoading = true;
        getAllCriteria()
            .then(data => {
                this.criteriaList = (data || []).map(item => {
                    let filterCountDisplay = '0';
                    if (item.Filters__c) {
                        try {
                            const parsed = JSON.parse(item.Filters__c);
                            filterCountDisplay = String((parsed.filters || []).length);
                        } catch (e) { /* ignore */ }
                    }
                    return { ...item, filterCountDisplay };
                });
            })
            .catch(() => {
                this.showToast('Error', 'Failed to load criteria list', 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    @wire(getAllObjects)
    wiredObjects({ data }) {
        if (data) {
            this.allObjects = data.map(o => ({ label: o.label, api: o.api }));
        }
    }

    // ===== VIEW GETTERS =====
    get isListView() { return this.currentView === 'list'; }
    get isDetailView() { return this.currentView === 'detail'; }
    get isBuilderView() { return this.currentView === 'builder'; }
    get hasCriteria() { return this.criteriaList && this.criteriaList.length > 0; }

    get totalCount() { return this.criteriaList ? this.criteriaList.length : 0; }
    get activeCount() { return this.criteriaList ? this.criteriaList.filter(c => c.Active__c).length : 0; }
    get inactiveCount() { return this.totalCount - this.activeCount; }

    get builderTitle() { return this.criteria.Id ? 'Edit Criteria' : 'New Criteria'; }

    // ===== LIST ACTIONS =====
    handleNewCriteria() {
        this.resetForm();
        this.currentView = 'builder';
    }

    handleRowClick(event) {
        const id = event.currentTarget.dataset.id;
        this.openDetail(id);
    }

    handleEdit(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.openBuilder(id);
    }

    handleDelete(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        const item = this.criteriaList.find(c => c.Id === id);
        this.deleteTargetId = id;
        this.deleteTargetName = item ? item.Name : '';
        this._fetchLinkedCountAndShowConfirm();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    // ===== DETAIL VIEW =====
    openDetail(id) {
        this.isLoading = true;
        getCriteria({ criteriaId: id })
            .then(res => {
                this.selectedCriteria = { ...res };
                this.currentView = 'detail';
            })
            .catch(() => {
                this.showToast('Error', 'Failed to load criteria', 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    handleEditFromDetail() {
        this.openBuilder(this.selectedCriteria.Id);
    }

    handleDeleteFromDetail() {
        this.deleteTargetId = this.selectedCriteria.Id;
        this.deleteTargetName = this.selectedCriteria.Name;
        this._fetchLinkedCountAndShowConfirm();
    }

    // Fetch linked target count before showing delete confirmation
    _fetchLinkedCountAndShowConfirm() {
        this.isLoading = true;
        getLinkedTargetCount({ criteriaId: this.deleteTargetId })
            .then(count => {
                this._linkedTargetCount = count || 0;
                this.showDeleteConfirm = true;
            })
            .catch(() => {
                this._linkedTargetCount = 0;
                this.showDeleteConfirm = true;
            })
            .finally(() => { this.isLoading = false; });
    }

    _linkedTargetCount = 0;

    get deleteConfirmMessage() {
        if (this._linkedTargetCount > 0) {
            return `"${this.deleteTargetName}" is linked with ${this._linkedTargetCount} target actual record${this._linkedTargetCount > 1 ? 's' : ''}. Deleting this criteria will also delete all linked target records. Are you sure?`;
        }
        return `Are you sure you want to delete "${this.deleteTargetName}"? This cannot be undone.`;
    }

    get detailHasFilters() {
        return this.detailFilters.length > 0;
    }

    get detailFilterCount() {
        return this.detailFilters.length;
    }

    get detailFilters() {
        if (!this.selectedCriteria.Filters__c) return [];
        try {
            const parsed = JSON.parse(this.selectedCriteria.Filters__c);
            return parsed.filters || [];
        } catch (e) { return []; }
    }

    get detailQueryPreview() {
        const c = this.selectedCriteria;
        if (!c.Object__c) return '';
        const agg = c.Operator__c === 'COUNT'
            ? `COUNT(Id)`
            : `SUM(${c.Field__c || '?'})`;
        let q = `SELECT ${c.User_Field__c || '?'},\n       ${agg} val\nFROM ${c.Object__c}`;
        const wheres = [];
        if (c.Date_Field__c) wheres.push(`${c.Date_Field__c} >= :startDate`);
        if (c.Date_Field__c) wheres.push(`${c.Date_Field__c} <= :endDate`);
        if (c.User_Field__c) wheres.push(`${c.User_Field__c} IN :userIds`);
        if (wheres.length) q += `\nWHERE ${wheres.join('\n  AND ')}`;
        q += `\nGROUP BY ${c.User_Field__c || '?'}`;
        return q;
    }

    // ===== BUILDER =====
    openBuilder(id) {
        this.isLoading = true;
        this.resetForm();

        // Store parsed filters temporarily — set on child AFTER metadata loads
        let parsedFilters = [];

        getCriteria({ criteriaId: id })
            .then(res => {
                this.criteria = { ...res };
                if (!this.criteria.Operator__c) this.criteria.Operator__c = 'SUM';

                // Parse filters but DON'T assign to this.filters yet
                if (this.criteria.Filters__c) {
                    try {
                        const parsed = JSON.parse(this.criteria.Filters__c);
                        parsedFilters = parsed.filters || [];
                    } catch (e) { parsedFilters = []; }
                }

                if (this.criteria.Object__c) {
                    const selected = this.allObjects.find(o => o.api === this.criteria.Object__c);
                    this.objectSearchText = selected
                        ? `${selected.label} (${selected.api})`
                        : this.criteria.Object__c;
                    return this.loadFieldMetadata(this.criteria.Object__c);
                }
            })
            .then(() => {
                // Now fieldsMetadata is loaded — safe to set filters on child
                this.filters = parsedFilters;
                this.currentView = 'builder';
            })
            .catch(() => { this.showToast('Error', 'Failed to load criteria', 'error'); })
            .finally(() => { this.isLoading = false; });
    }

    handleBackToList() {
        this.currentView = 'list';
        this.loadCriteriaList();
    }

    // ===== DELETE =====
    handleCancelDelete() {
        this.showDeleteConfirm = false;
        this.deleteTargetId = null;
        this.deleteTargetName = '';
    }

    handleConfirmDelete() {
        this.isLoading = true;
        this.showDeleteConfirm = false;

        deleteCriteria({ criteriaId: this.deleteTargetId })
            .then(() => {
                this.showToast('Success', 'Criteria deleted', 'success');
                this.currentView = 'list';
                this.loadCriteriaList();
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message || 'Failed to delete', 'error');
            })
            .finally(() => {
                this.isLoading = false;
                this.deleteTargetId = null;
                this.deleteTargetName = '';
            });
    }

    // ===== STEP GETTERS =====
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }

    get step1Class() { return this.getStepClass(1); }
    get step2Class() { return this.getStepClass(2); }
    get step3Class() { return this.getStepClass(3); }
    get step4Class() { return this.getStepClass(4); }

    getStepClass(step) {
        let base = 'tcb-step';
        if (this.currentStep === step) base += ' active';
        else if (this.currentStep > step) base += ' completed';
        else base += ' disabled';
        return base;
    }

    get showPrevious() { return this.currentStep > 1; }
    get showNext() { return this.currentStep < 4; }
    get showSaveButtons() { return this.currentStep === 4; }

    get isNextDisabled() {
        if (this.currentStep === 1) return !this.criteria.Name || !this.criteria.Object__c;
        if (this.currentStep === 2) {
            if (!this.criteria.Operator__c) return true;
            if (this.criteria.Operator__c === 'SUM' && !this.criteria.Field__c) return true;
            if (!this.criteria.Date_Field__c) return true;
            if (!this.criteria.User_Field__c) return true;
            return false;
        }
        return false;
    }

    get isCount() { return this.criteria.Operator__c === 'COUNT'; }
    get filterCount() { return this.filters ? this.filters.length : 0; }
    get hasFilters() { return this.filterCount > 0; }

    get selectedObjectLabel() {
        if (!this.criteria.Object__c || !this.allObjects) return '';
        const found = this.allObjects.find(o => o.api === this.criteria.Object__c);
        return found ? found.label : this.criteria.Object__c;
    }

    get selectedFieldLabel() { return this.getFieldLabelByApi(this.criteria.Field__c); }
    get selectedDateFieldLabel() { return this.getFieldLabelByApi(this.criteria.Date_Field__c); }
    get selectedUserFieldLabel() { return this.getFieldLabelByApi(this.criteria.User_Field__c); }

    getFieldLabelByApi(apiName) {
        if (!apiName || !this.fieldsMetadata) return '';
        const f = this.fieldsMetadata.find(x => x.apiName === apiName);
        return f ? f.label : apiName;
    }

    // ===== OBJECT SEARCH =====
    handleObjectSearch(event) {
        const search = (event.target.value || '').toLowerCase();
        this.objectSearchText = event.target.value;
        if (!search) {
            this.showObjectDropdown = false;
            this.filteredObjects = [];
            return;
        }
        this.filteredObjects = this.allObjects.filter(obj =>
            obj.label.toLowerCase().includes(search)
        );
        this.showObjectDropdown = this.filteredObjects.length > 0;
    }

    selectObject(event) {
        const api = event.currentTarget.dataset.api;
        const label = event.currentTarget.dataset.label;
        this.criteria.Object__c = api;
        this.objectSearchText = `${label} (${api})`;
        this.showObjectDropdown = false;
        this.filters = [];
        this.isLoading = true;
        this.loadFieldMetadata(api).finally(() => { this.isLoading = false; });
    }

    // ===== FIELD METADATA =====
    loadFieldMetadata(objApiName) {
        return getFieldMetadata({ objectName: objApiName })
            .then(res => {
                this.fieldsMetadata = res || [];
                this.numberFieldOptions = this.fieldsMetadata
                    .filter(f => f.type === 'Number' || f.type === 'Currency' || f.type === 'Percent')
                    .map(f => ({ label: `${f.label} (${f.apiName})`, value: f.apiName }));
                this.dateFieldOptions = this.fieldsMetadata
                    .filter(f => f.type === 'Date' || f.type === 'DateTime')
                    .map(f => ({ label: f.label, value: f.apiName }));
                this.userFieldOptions = this.fieldsMetadata
                    .filter(f => f.isUserField)
                    .map(f => ({ label: `${f.label} (${f.apiName})`, value: f.apiName }));
            })
            .catch(e => {
                this.showToast('Error', e?.body?.message || 'Error loading fields', 'error');
            });
    }

    // ===== INPUT HANDLERS =====
    handleInput(e) {
        const field = e.target.dataset.field;
        this.criteria[field] = e.target.value;
        if (field === 'Filter_Logic__c') this.autoFilterLogic = false;
    }

    handleOperatorChange(e) {
        this.criteria.Operator__c = e.target.value;
        if (this.isCount) this.criteria.Field__c = null;
    }

    handleFilterChange(e) {
        this.filters = e.detail;
        if (this.autoFilterLogic) this.updateDefaultFilterLogic();
    }

    updateDefaultFilterLogic() {
        if (!this.filters || this.filters.length <= 1) {
            this.criteria.Filter_Logic__c = '';
            return;
        }
        this.criteria.Filter_Logic__c = this.filters.map(f => f.id).join(' AND ');
    }

    // ===== NAVIGATION =====
    handleNext() {
        if (this.currentStep === 3) {
            const filterIds = this.filters.map(f => f.id);
            if (this.criteria.Filter_Logic__c && filterIds.length > 0) {
                const result = FilterLogicValidator.validate(this.criteria.Filter_Logic__c, filterIds);
                if (!result.valid) { this.logicError = result.message; return; }
            }
            this.logicError = null;
        }
        if (this.currentStep < 4) this.currentStep++;
    }

    handlePrevious() {
        if (this.currentStep > 1) this.currentStep--;
    }

    // ===== SAVE =====
    handleSave() { this.doSave(false); }
    handleSaveAndNew() { this.doSave(true); }

    doSave(andNew) {
        this.isLoading = true;

        const filterJson = JSON.stringify({
            filters: (this.filters || []).map(f => ({
                id: f.id, field: f.field, operator: f.operator, value: f.value, type: f.type
            }))
        }, null, 2);

        const payload = {
            Id: this.criteria.Id,
            Name: this.criteria.Name,
            Object__c: this.criteria.Object__c,
            Operator__c: this.criteria.Operator__c,
            Field__c: this.criteria.Field__c,
            Date_Field__c: this.criteria.Date_Field__c,
            User_Field__c: this.criteria.User_Field__c,
            Filters__c: filterJson,
            Filter_Logic__c: this.criteria.Filter_Logic__c
        };

        saveCriteria({ criteria: payload })
            .then(result => {
                this.showToast('Success', 'Criteria saved successfully', 'success');
                if (andNew) {
                    this.resetForm();
                } else {
                    // Go to detail view of saved record
                    this.selectedCriteria = { ...result };
                    this.currentView = 'detail';
                    this.loadCriteriaList();
                }
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message || 'Error saving criteria', 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    // ===== RESET =====
    resetForm() {
        this.criteria = {
            Id: null, Name: '', Object__c: '', Operator__c: 'SUM',
            Field__c: '', Date_Field__c: '', User_Field__c: '', Filter_Logic__c: ''
        };
        this.objectSearchText = '';
        this.filters = [];
        this.fieldsMetadata = [];
        this.numberFieldOptions = [];
        this.dateFieldOptions = [];
        this.userFieldOptions = [];
        this.logicError = null;
        this.currentStep = 1;
        this.autoFilterLogic = true;
    }

    // ===== TOAST =====
    showToast(title, msg, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: msg, variant }));
    }
}
