import { LightningElement, track, wire } from 'lwc';
import getAllObjects from '@salesforce/apex/TAM_TargetCriteria_Controller.getAllObjects';
import getAllCriteria from '@salesforce/apex/TAM_TargetCriteria_Controller.getAllCriteria';
import getFieldMetadata from '@salesforce/apex/TAM_FieldMetadata_Service.getFields';
import getCriteria from '@salesforce/apex/TAM_TargetCriteria_Controller.getCriteria';
import saveCriteria from '@salesforce/apex/TAM_TargetCriteria_Controller.saveCriteria';
import deleteCriteria from '@salesforce/apex/TAM_TargetCriteria_Controller.deleteCriteria';
import FilterLogicValidator from 'c/tamFilterLogicValidator';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TamCriteriaBuilder extends LightningElement {

    // ===== LIST VIEW STATE =====
    @track criteriaList = [];
    @track showModal = false;
    @track showDeleteConfirm = false;
    @track deleteTargetId = null;
    @track deleteTargetName = '';

    // ===== FORM STATE =====
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
                this.criteriaList = data || [];
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load criteria list', 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    // ===== WIRES =====
    @wire(getAllObjects)
    wiredObjects({ data, error }) {
        if (data) {
            this.allObjects = data.map(o => ({ label: o.label, api: o.api }));
        }
    }

    // ===== LIST VIEW GETTERS =====
    get hasCriteria() {
        return this.criteriaList && this.criteriaList.length > 0;
    }

    get modalTitle() {
        return this.criteria.Id ? 'Edit Criteria' : 'New Criteria';
    }

    // ===== LIST VIEW ACTIONS =====
    handleNewCriteria() {
        this.resetForm();
        this.showModal = true;
    }

    handleEdit(event) {
        const id = event.currentTarget.dataset.id;
        this.isLoading = true;
        this.resetForm();

        getCriteria({ criteriaId: id })
            .then(res => {
                this.criteria = { ...res };
                if (!this.criteria.Operator__c) this.criteria.Operator__c = 'SUM';

                if (this.criteria.Filters__c) {
                    try {
                        const parsed = JSON.parse(this.criteria.Filters__c);
                        this.filters = parsed.filters || [];
                    } catch (e) {
                        this.filters = [];
                    }
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
                this.showModal = true;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load criteria', 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    handleDelete(event) {
        const id = event.currentTarget.dataset.id;
        const item = this.criteriaList.find(c => c.Id === id);
        this.deleteTargetId = id;
        this.deleteTargetName = item ? item.Name : '';
        this.showDeleteConfirm = true;
    }

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
                this.loadCriteriaList();
            })
            .catch(error => {
                const msg = error?.body?.message || 'Failed to delete';
                this.showToast('Error', msg, 'error');
            })
            .finally(() => {
                this.isLoading = false;
                this.deleteTargetId = null;
                this.deleteTargetName = '';
            });
    }

    handleCloseModal() {
        this.showModal = false;
        this.resetForm();
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
        if (this.currentStep === 1) {
            return !this.criteria.Name || !this.criteria.Object__c;
        }
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

    get jsonFilters() {
        return JSON.stringify({
            filters: (this.filters || []).map(f => ({
                id: f.id, field: f.field, operator: f.operator, value: f.value, type: f.type
            }))
        }, null, 2);
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
        const ids = this.filters.map(f => f.id);
        this.criteria.Filter_Logic__c = ids.join(' AND ');
    }

    // ===== NAVIGATION =====
    handleNext() {
        if (this.currentStep === 3) {
            const filterIds = this.filters.map(f => f.id);
            if (this.criteria.Filter_Logic__c && filterIds.length > 0) {
                const result = FilterLogicValidator.validate(this.criteria.Filter_Logic__c, filterIds);
                if (!result.valid) {
                    this.logicError = result.message;
                    return;
                }
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
            .then(() => {
                this.showToast('Success', 'Criteria saved successfully', 'success');
                if (andNew) {
                    this.resetForm();
                } else {
                    this.showModal = false;
                    this.resetForm();
                }
                this.loadCriteriaList();
            })
            .catch(error => {
                const msg = error?.body?.message || 'Error saving criteria';
                this.showToast('Error', msg, 'error');
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
