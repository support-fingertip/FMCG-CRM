import { LightningElement, api, track, wire } from 'lwc';
import getAllObjects from '@salesforce/apex/TargetCriteriaController.getAllObjects';
import getFieldMetadata from '@salesforce/apex/FieldMetadataService.getFields';
import getCriteria from '@salesforce/apex/TargetCriteriaController.getCriteria';
import saveCriteria from '@salesforce/apex/TargetCriteriaController.saveCriteria';
import FilterLogicValidator from 'c/filterLogicValidator';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class TargetCriteriaBuilderNew extends NavigationMixin(LightningElement) {

    @api recordId;  // edit mode

    // Criteria backing object
    @track criteria = {
        Id: null,
        Name: '',
        Object__c: '',
        Operator__c: 'SUM',
        Field__c: '',
        Date_Field__c: '',
        User_Field__c: '',
        Filter_Logic__c: ''
    };

    // Step state
    @track currentStep = 1; // 1: General, 2: Mapping, 3: Filters, 4: Summary

    // Metadata / picklists
    @track fieldsMetadata = [];
    @track numberFieldOptions = [];
    @track dateFieldOptions = [];
    @track userFieldOptions = [];

    // Object search
    allObjects = [];
    @track objectSearchText = '';
    @track showObjectDropdown = false;
    @track filteredObjects = [];

    // Filters
    @track filters = [];
    @track logicError = null;

    @track autoFilterLogic = true;

    // UI state
    @track isLoading = false;

    operatorOptions = [
        { label: 'SUM', value: 'SUM' },
        { label: 'COUNT', value: 'COUNT' }
    ];

    // ===== LIFECYCLE =====
    connectedCallback() {
        this.isLoading = true;
        if (this.recordId) {
            this.loadExistingCriteria()
                .finally(() => { this.isLoading = false; });
        } else {
            this.isLoading = false;
        }
    }

    // Load existing record in edit mode
    loadExistingCriteria() {
        return getCriteria({ criteriaId: this.recordId })
            .then(res => {
                // copy all fields from server
                this.criteria = { ...res };

                // Ensure operator default
                if (!this.criteria.Operator__c) {
                    this.criteria.Operator__c = 'SUM';
                }

                // Parse Filters__c JSON
                if (this.criteria.Filters__c) {
                    try {
                        const parsed = JSON.parse(this.criteria.Filters__c);
                        this.filters = parsed.filters || [];
                    } catch (e) {
                        this.filters = [];
                    }
                }

                // Load metadata for selected object
                if (this.criteria.Object__c) {
                    this.loadFieldMetadata(this.criteria.Object__c);
                }
            });
    }

    // ===== WIRES =====
    @wire(getAllObjects)
    wiredObjects({ data, error }) {
        if (data) {
            this.allObjects = data.map(o => ({
                label: o.label,
                api: o.api
            }));

            // If we're editing and object is already selected, populate search text
            if (this.criteria.Object__c && !this.objectSearchText) {
                const selected = this.allObjects.find(
                    o => o.api === this.criteria.Object__c
                );
                if (selected) {
                    this.objectSearchText = `${selected.label} (${selected.api})`;
                } else {
                    this.objectSearchText = this.criteria.Object__c;
                }
            }
        } else if (error) {
            this.showToast('Error', 'Error loading object list', 'error');
        }
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
        if (this.currentStep === step) {
            base += ' active';
        } else if (this.currentStep > step) {
            base += ' completed';
        } else {
            base += ' disabled';
        }
        return base;
    }

    get showPrevious() {
        return this.currentStep > 1;
    }

    get showNext() {
        return this.currentStep < 4;
    }

    get showSaveButtons() {
        return this.currentStep === 4;
    }

    get currentStepLabel() {
        switch (this.currentStep) {
            case 1: return 'General Settings';
            case 2: return 'Field Mapping';
            case 3: return 'Filters & Logic';
            case 4: return 'Summary';
            default: return '';
        }
    }

    // Disable Next for obvious missing stuff on step 1 & 2
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
        // Step 3: validated on click
        return false;
    }

    // Quick helpers
    get isCount() {
        return this.criteria.Operator__c === 'COUNT';
    }

    get filterCount() {
        return this.filters ? this.filters.length : 0;
    }

    get hasFilters() {
        return this.filterCount > 0;
    }

    get hasNoFilters() {
        return !this.hasFilters;
    }

    get selectedObjectLabel() {
        if (!this.criteria.Object__c || !this.allObjects) return '';
        const found = this.allObjects.find(o => o.api === this.criteria.Object__c);
        return found ? found.label : this.criteria.Object__c;
    }

    get selectedFieldLabel() {
        return this.getFieldLabelByApi(this.criteria.Field__c);
    }

    get selectedDateFieldLabel() {
        return this.getFieldLabelByApi(this.criteria.Date_Field__c);
    }

    get selectedUserFieldLabel() {
        return this.getFieldLabelByApi(this.criteria.User_Field__c);
    }

    getFieldLabelByApi(apiName) {
        if (!apiName || !this.fieldsMetadata) return '';
        const f = this.fieldsMetadata.find(x => x.apiName === apiName);
        return f ? f.label : apiName;
    }

    get jsonFilters() {
        return JSON.stringify({
            filters: (this.filters || []).map(f => ({
                id: f.id,
                field: f.field,
                operator: f.operator,
                value: f.value,
                type: f.type
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

        // Set criteria value
        this.criteria.Object__c = api;

        // Show label + API in search box
        this.objectSearchText = `${label} (${api})`;

        // Hide dropdown
        this.showObjectDropdown = false;

        // Reset filters when object changes
        this.filters = [];

        // Load fields
        this.isLoading = true;
        this.loadFieldMetadata(api)
            .finally(() => { this.isLoading = false; });
    }

    // ===== FIELD METADATA =====
    loadFieldMetadata(objApiName) {
        return getFieldMetadata({ objectName: objApiName })
            .then(res => {
                this.fieldsMetadata = res || [];

                this.numberFieldOptions = this.fieldsMetadata
                    .filter(f =>
                        f.type === 'Number' ||
                        f.type === 'Currency' ||
                        f.type === 'Percent'
                    )
                    .map(f => ({
                        label: `${f.label} (${f.apiName})`,
                        value: f.apiName
                    }));

                this.dateFieldOptions = this.fieldsMetadata
                    .filter(f => f.type === 'Date' || f.type === 'DateTime')
                    .map(f => ({
                        label: f.label,
                        value: f.apiName
                    }));

                this.userFieldOptions = this.fieldsMetadata
                    .filter(f => f.isUserField)
                    .map(f => ({
                        label: `${f.label} (${f.apiName})`,
                        value: f.apiName
                    }));
            })
            .catch(e => {
                this.showToast(
                    'Error',
                    e.body && e.body.message ? e.body.message : 'Error loading field metadata',
                    'error'
                );
            });
    }

    // ===== GENERIC INPUT HANDLERS =====
    handleInput(e) {
        const field = e.target.dataset.field;
        this.criteria[field] = e.target.value;

        // If user types in Filter Logic, stop auto-updating
        if (field === 'Filter_Logic__c') {
            this.autoFilterLogic = false;
        }
    }

    handleCheckbox(e) {
        const field = e.target.dataset.field;
        this.criteria[field] = e.target.checked;
    }

    handleOperatorChange(e) {
        this.criteria.Operator__c = e.target.value;
        if (this.isCount) {
            this.criteria.Field__c = null;
        }
    }

    // ===== FILTER HANDLING =====
    handleFilterChange(e) {
        this.filters = e.detail;

        // If we're still in auto mode, keep Filter Logic in sync
        if (this.autoFilterLogic) {
            this.updateDefaultFilterLogic();
        }
    }

    updateDefaultFilterLogic() {
        // 0 or 1 filter -> NO logic string
        if (!this.filters || this.filters.length <= 1) {
            this.criteria.Filter_Logic__c = '';
            return;
        }

        // 2+ filters -> default to "id1 AND id2 AND id3 ..."
        const parts = this.filters.map(f => f.id);    // numeric ids
        this.criteria.Filter_Logic__c = parts.join(' AND ');
    }



    // ===== STEP NAVIGATION =====
    handleNext() {
        if (this.currentStep === 1) {
            if (!this.validateStep1()) return;
        } else if (this.currentStep === 2) {
            if (!this.validateStep2()) return;
        } else if (this.currentStep === 3) {
            if (!this.validateStep3()) return;
        }

        if (this.currentStep < 4) {
            this.currentStep += 1;
        }
    }

    handlePrevious() {
        if (this.currentStep > 1) {
            this.currentStep -= 1;
        }
    }

    // ===== VALIDATION =====
    validateStep1() {
        if (!this.criteria.Name || !this.criteria.Name.trim()) {
            this.showToast('Error', 'Criteria Name is required.', 'error');
            return false;
        }

        if (!this.criteria.Object__c) {
            this.showToast('Error', 'Object is required.', 'error');
            return false;
        }

        return true;
    }

    validateStep2() {
        if (!this.criteria.Operator__c) {
            this.showToast('Error', 'Operator is required.', 'error');
            return false;
        }

        if (this.criteria.Operator__c === 'SUM' && !this.criteria.Field__c) {
            this.showToast('Error', 'SUM Field is required.', 'error');
            return false;
        }

        if (!this.criteria.Date_Field__c) {
            this.showToast('Error', 'Date Field is required.', 'error');
            return false;
        }

        if (!this.criteria.User_Field__c) {
            this.showToast('Error', 'User Field is required.', 'error');
            return false;
        }

        return true;
    }

    validateFilters() {
        for (let i = 0; i < this.filters.length; i++) {
            const f = this.filters[i];
            const index = i + 1;

            if (!f.field) {
                this.showToast('Error', `Filter ${index}: Field is required.`, 'error');
                return false;
            }

            if (!f.operator) {
                this.showToast('Error', `Filter ${index}: Operator is required.`, 'error');
                return false;
            }

            if (f.operator === 'IN' || f.operator === 'NOT IN') {
                if (!f.value || (Array.isArray(f.value) && f.value.length === 0)) {
                    this.showToast('Error', `Filter ${index}: Select at least one value.`, 'error');
                    return false;
                }
            } else {
                if (
                    f.value === null ||
                    f.value === '' ||
                    (Array.isArray(f.value) && f.value.length === 0)
                ) {
                    this.showToast('Error', `Filter ${index}: Enter a value.`, 'error');
                    return false;
                }
            }
        }
        return true;
    }

    validateStep3() {
        // No filters -> nothing to validate
        if (!this.filters || this.filters.length === 0) {
            this.logicError = null;
            return true;
        }

        // 1. Every filter row must be complete
        if (!this.validateFilters()) {
            return false;
        }

        // 2. Auto mode keeps logic in sync with current filters
        if (this.autoFilterLogic) {
            this.updateDefaultFilterLogic();
        }

        const filterCount = this.filters.length;

        // 3. 1 filter -> no logic needed, always valid
        if (filterCount === 1) {
            this.logicError = null;
            return true;
        }

        // 4. For 2+ filters, logic is required
        const logic = (this.criteria.Filter_Logic__c || '').trim();
        if (!logic) {
            this.showToast(
                'Error',
                'Filter Logic is required when more than one filter is defined.',
                'error'
            );
            return false;
        }

        const filterIds = this.filters.map(f => Number(f.id));

        // 5. All filter IDs must be present at least once in logic
        const matches = logic.match(/\d+/g) || [];
        const usedIds = new Set(matches.map(m => Number(m)));

        const missingIds = filterIds.filter(id => !usedIds.has(id));
        if (missingIds.length > 0) {
            const msg =
                'Filter Logic must include all filters. Missing: ' +
                missingIds.join(', ');
            this.logicError = msg;
            this.showToast('Error', msg, 'error');
            return false;
        }

        // 6. Delegate syntax & AND/OR rules to FilterLogicValidator
        const result = FilterLogicValidator.validate(logic, filterIds);
        if (!result.valid) {
            this.logicError = result.message;
            this.showToast('Error', result.message, 'error');
            return false;
        }

        this.logicError = null;
        return true;
    }





    /*   validateStep3() {
          // No filters -> nothing to validate
          if (!this.filters || this.filters.length === 0) {
              this.logicError = null;
              return true;
          }
  
          // 1. Every filter row must be complete
          if (!this.validateFilters()) {
              return false;
          }
  
          // 2. Default AND logic when more than one filter and logic is empty
          if (this.filters.length > 1 && !this.criteria.Filter_Logic__c) {
              const parts = this.filters.map(f => f.id);
              this.criteria.Filter_Logic__c = parts.join(' AND ');
          }
  
          // 3. Validate logic syntax and references using FilterLogicValidator
          const filterIds = this.filters.map(f => f.id);
          const result = FilterLogicValidator.validate(
              this.criteria.Filter_Logic__c,
              filterIds
          );
  
          if (!result.valid) {
              this.logicError = result.message;
              this.showToast('Error', result.message, 'error');
              return false;
          }
  
          this.logicError = null;
          return true;
      } */

    validateAll() {
        return this.validateStep1() && this.validateStep2() && this.validateStep3();
    }

    // ===== SAVE ACTIONS =====
    handleSave() {
        if (!this.validateAll()) {
            return;
        }

        this.isLoading = true;
        this.saveCriteria(false);
    }

    handleSaveAndNew() {
        if (!this.validateAll()) {
            return;
        }

        this.isLoading = true;
        this.saveCriteria(true);
    }

    saveCriteria(isNew) {
        // Build Filters__c JSON
        const filterJson = JSON.stringify({
            filters: (this.filters || []).map(f => ({
                id: f.id,
                field: f.field,
                operator: f.operator,
                value: f.value,
                type: f.type
            }))
        }, null, 2);

        const payload = {
            Id: this.criteria.Id,
            Name: this.criteria.Name,
            btsi__Object__c: this.criteria.Object__c,
            btsi__Operator__c: this.criteria.Operator__c,
            btsi__Field__c: this.criteria.Field__c,
            btsi__Date_Field__c: this.criteria.Date_Field__c,
            btsi__User_Field__c: this.criteria.User_Field__c,
            btsi__Filters__c: filterJson,
            btsi__Filter_Logic__c: this.criteria.Filter_Logic__c
        };

        saveCriteria({ criteria: payload })
            .then(result => {
                this.showToast('Success', 'Criteria saved successfully', 'success');

                if (isNew) {
                    this.resetForm();
                    this.isLoading = false;
                } else {
                    const recordId = result && result.Id ? result.Id : this.criteria.Id;
                    this.navigateToRecord(recordId);
                }
            })
            .catch(error => {
                this.isLoading = false;
                const msg =
                    error && error.body && error.body.message
                        ? error.body.message
                        : 'Error saving criteria';
                this.showToast('Error', msg, 'error');
            });
    }

    // ===== NAVIGATION / RESET =====
    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'btsi__Target_Criteria__c',
                actionName: 'list'
            }
        });
    }

    resetForm() {
        this.criteria = {
            Id: null,
            Name: '',
            Object__c: '',
            Operator__c: 'SUM',
            Field__c: '',
            Date_Field__c: '',
            User_Field__c: '',
            Filter_Logic__c: ''
        };
        this.objectSearchText = '';
        this.filters = [];
        this.fieldsMetadata = [];
        this.numberFieldOptions = [];
        this.dateFieldOptions = [];
        this.userFieldOptions = [];
        this.logicError = null;
        this.currentStep = 1;
    }

    navigateToRecord(recordId) {
        this.isLoading = false;
        if (!recordId) {
            this.showToast('Error', 'Record Id missing after save.', 'error');
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    // ===== TOAST =====
    showToast(title, msg, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message: msg,
                variant
            })
        );
    }
}