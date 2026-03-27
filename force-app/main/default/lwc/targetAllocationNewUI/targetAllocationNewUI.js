import { LightningElement, track, wire, api } from 'lwc';
import getData from '@salesforce/apex/TargetAllocationNewUICtrl.getAllData';
import getTargetActuals from '@salesforce/apex/TargetAllocationNewUICtrl.getTargetActuals';
import getUserTargetActuals from '@salesforce/apex/TargetAllocationNewUICtrl.getUserTargets';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveTargets from '@salesforce/apex/TargetAllocationNewUICtrl.saveTargets';
import saveAdminTargetActuals from '@salesforce/apex/TargetAllocationNewUICtrl.saveAdminTargets';
import FORM_FACTOR from '@salesforce/client/formFactor';
import { CurrentPageReference } from 'lightning/navigation';

export default class TargetAllocationNewUI extends LightningElement {
    currentPageRef;
    periodId;
    executiveId;

    @wire(CurrentPageReference)
    wiredCurrentPageRef(result) {
        if (result) {
            this.currentPageRef = result;
            this.extractParams();
        }
    }

    extractParams() {
        if (this.currentPageRef && this.currentPageRef.state) {
            this.periodId = this.currentPageRef.state.c__periodId;
            this.executiveId = this.currentPageRef.state.c__ExecutiveId;
        }
    }

    isDisabled = false;
    selectedUser = '';
    selectedPeriod = '';
    selectedAdminPeriod = '';
    isLoading = false;
    isPopupLoading = false;
    isDesktop = false;
    isPhone = false;
    @track userOptions = [];
    @track userList = [];
    @track periodOptions = [];
    @track currentPeriodOptions = [];
    @track targetCriterias = [];
    @track targetList = [];
    @track curTargets = [];
    @track adminTargets = [];
    @track adminTargetItems = [];
    userTargetsCriteriasExisted = false;
    currentTargetExisted = false;
    openDistrbutionTable = false;
    @track subOrdinateUserList = [];
    @track uniqueTargetCriterias = [];
    @track targetCriteriasWithManagerMap = new Map();
    @track userColumns = [];
    @track targetCriteriaColumns = [];
    @track targetCriteriaArray = [];
    criteriaListSize = 0;
    subordinateUsersExisted = false;
    @track targetCriteriaMap = new Map();
    @track isDropdownOpen = true;
    containerClass;
    adminTarget = false;
    showAddTarget = false;
    showDistibuteTarget = false;
    initialTargetAssignmentProfile;
    @track parentToTotalTargetValueMap = new Map();
    @track parentwithtargetValueOfSubodinates = new Map();

    connectedCallback() {
        this.isDesktop = FORM_FACTOR === 'Large' ? true : false;
        this.isPhone = FORM_FACTOR === 'Small' ? true : false;
        if (FORM_FACTOR === 'Medium') {
            this.isDesktop = true;
        }
        this.containerClass = this.isDesktop ? 'slds-modal__container ' : 'mobilePopup';
        this.fetchAllData();
        this.disablePullToRefresh();
    }

    fetchAllData() {
        this.isLoading = true;
        getData({})
            .then((result) => {
                console.log("Fetched Data:", JSON.stringify(result));

                this.userOptions = this.populateOptions(result?.userList, 'Name', 'Id');
                this.userList = result?.userList || [];

                this.periodOptions = this.populateOptions(result?.periodsList, 'Name', 'Id');

                const currentDate = new Date();

                this.currentPeriodOptions = this.populateOptions(
                    result?.periodsList?.filter(period => new Date(period.End_Date__c) >= currentDate),
                    'Name',
                    'Id'
                );

                this.selectedUser = result?.currentUserId || '';
                this.selectedPeriod = result?.period || '';
                this.selectedAdminPeriod = result?.period || '';
                this.initialTargetAssignmentProfile = result?.initialTargetAssignmentProfile || '';

                this.targetList = result?.targetItems || [];
                this.setCurrentTarget();
                this.getProfileName();
                this.aggregateSubordinateTargets();
                this.isLoading = false;

                if (this.periodId != null && this.executiveId != null) {
                    this.selectedPeriod = this.periodId;
                    this.selectedUser = this.executiveId;
                    this.setTargetVsActualData();
                }
            })
            .catch((error) => {
                this.isLoading = false;
                console.error("Error fetching data:", error);

                this.showToast(
                    'Error',
                    `Error fetching targets: ${error.body?.message || JSON.stringify(error)}`,
                    'error'
                );
            });
    }

    setCurrentTarget() {
        this.curTargets = this.targetList.filter(item => item.User__c === this.selectedUser);

        this.uniqueTargetCriterias = this.curTargets.reduce((acc, t) => {
            if (t.Target_Criteria__c && !acc.some(item => item.Id === t.Target_Criteria__c)) {
                acc.push({ Id: t.Target_Criteria__c, Name: t.Target_Criteria__r?.Name || 'N/A' });
            }
            return acc;
        }, []);

        this.targetCriteriasWithManagerMap = new Map(
            this.curTargets.map(target => [target.Target_Criteria__c, target])
        );

        this.currentTargetExisted = this.curTargets.length > 0;
    }

    getTargetVsActualData(event) {
        this.selectedPeriod = event.target.value;
        this.selectedAdminPeriod = event.target.value;
        this.setTargetVsActualData();
    }

    setTargetVsActualData() {
        this.isLoading = true;
        getTargetActuals({
            period: this.selectedPeriod,
            userId: this.selectedUser
        })
            .then((result) => {
                this.targetList = result;
                this.setCurrentTarget();
                this.aggregateSubordinateTargets();
                this.isLoading = false;
            })
            .catch((error) => {
                this.isLoading = false;
                console.log('error' + JSON.stringify(error));
                this.showToast(
                    'Error',
                    'Error fetching targets: ' + (error.body ? error.body.message : JSON.stringify(error)),
                    'error'
                );
            });
    }

    getProfileName() {
        let selectedUserObj = this.userList.find(user => user.Id === this.selectedUser);

        if (selectedUserObj && selectedUserObj.Profile.Name === this.initialTargetAssignmentProfile) {
            this.showAddTarget = true;
        } else {
            this.showAddTarget = false;
        }
    }

    get comboboxContainerClass() {
        return this.showAddTarget ? 'combobox-container' : 'combobox-container-no-admin';
    }

    userChangeHandler(event) {
        this.selectedUser = event.target.value;
        this.setCurrentTarget();
        this.getProfileName();
    }

    openModal() {
        this.resetAll();
        this.openDistrbutionTable = true;
        this.subordinateUsersExisted = false;

        this.subOrdinateUserList = this.userList.filter(user => user.ManagerId === this.selectedUser);
        console.log('Users:', JSON.stringify(this.subOrdinateUserList));

        let targetListCopy = this.targetList.map(target => ({ ...target }));
        let targetMap = new Map();
        targetListCopy.forEach(target => {
            let extId = target.User__c + target.Target_Criteria__c;
            targetMap.set(extId, target);
        });

        let userTargetMap = new Map();

        for (let user of this.subOrdinateUserList) {
            let targetItems = [];
            for (let targetCriteria of this.uniqueTargetCriterias) {
                let extId = user.Id + targetCriteria.Id;
                if (!targetMap.has(extId)) {
                    let newTarget = this.addSubTargetItem(targetCriteria, user);
                    targetItems.push(newTarget);
                } else {
                    targetItems.push(targetMap.get(extId));
                }
            }
            userTargetMap.set(user.Id, { id: user.Id, name: user.Name, targets: targetItems });
        }

        this.targetCriteriaArray = Array.from(userTargetMap.values());
        console.log('Target Criteria Array:', JSON.stringify(this.targetCriteriaArray));

        this.targetCriteriaColumns = this.uniqueTargetCriterias.map(targetCriteria => ({
            Id: targetCriteria.Id,
            Name: targetCriteria.Name
        }));
        this.criteriaListSize = 1 + this.targetCriteriaColumns.length;
        this.subordinateUsersExisted = this.subOrdinateUserList.length > 0 &&
            this.targetCriteriaArray.some(item => item.targets && item.targets.length > 0);
    }

    addSubTargetItem(criteria, user) {
        let newTarget = {
            sobjectType: 'Target_Actual__c',
            Target_Criteria__r: {
                Id: criteria.Id,
                Name: criteria.Name
            },
            Target_Criteria__c: criteria.Id,
            Target_Value__c: '',
            Achievement_Value__c: 0,
            User__c: user.Id,
            UserName: user.Name,
            Parent_Target__c: this.targetCriteriasWithManagerMap.get(criteria.Id).Id
        };
        return newTarget;
    }

    handleInputChange(event) {
        const targetCriteriaId = event.target.dataset.targetcriteria;
        const executiveId = event.target.dataset.userid;
        let newValue = event.target.value ? Number(event.target.value) : '';
        const targetId = event.target.dataset.targetid;

        let parentTarget = this.targetCriteriasWithManagerMap.get(targetCriteriaId);
        if (!parentTarget) {
            console.error("Parent target not found");
            return;
        }
        let parentTargetValue = parentTarget.Target_Value__c || 0;

        let totalSubordinateValueOfCurrentTargetUser = this.parentwithtargetValueOfSubodinates.get(targetId) || 0;

        let totalSubordinateValue = 0;
        let lastEnteredTarget = null;

        for (let executive of this.targetCriteriaArray) {
            for (let targetItem of executive.targets) {
                if (targetItem.Target_Criteria__c === targetCriteriaId) {
                    if (targetItem.User__c === executiveId) {
                        lastEnteredTarget = targetItem;
                    } else {
                        totalSubordinateValue += Number(targetItem.Target_Value__c || 0);
                    }
                }
            }
        }

        let newTotal = totalSubordinateValue + newValue;

        if (newTotal > parentTargetValue) {
            let allowedValue = parentTargetValue - totalSubordinateValue;
            if (allowedValue < 0) allowedValue = 0;

            if (lastEnteredTarget) {
                lastEnteredTarget.Message = `Max value allowed: ${allowedValue}`
                lastEnteredTarget.Max_Value__c = allowedValue;
                lastEnteredTarget.Target_Value__c = newValue;
            }
        }
        else if (newValue < totalSubordinateValueOfCurrentTargetUser) {
            if (lastEnteredTarget) {
                lastEnteredTarget.Message = `Min value allowed: ${totalSubordinateValueOfCurrentTargetUser}`
                lastEnteredTarget.Min_Value__c = totalSubordinateValueOfCurrentTargetUser;
                lastEnteredTarget.Target_Value__c = newValue;
            }
        }
        else if (lastEnteredTarget) {
            lastEnteredTarget.Target_Value__c = newValue;
        }
    }

    saveData() {
        this.isLoading = true;
        const targetItems = this.targetCriteriaArray.map(targetCriteriaItem => targetCriteriaItem.targets).flat();
        const targetList = targetItems;

        const invalidTargets = targetList.filter(
            target => (target.Target_Value__c < target.Min_Value__c || target.Target_Value__c > target.Max_Value__c)
        );
        if (invalidTargets.length > 0) {
            this.isLoading = false;
            this.showToast('Error', 'Target distribution initiated. Please enter the targets in allowed range', 'error');
            return;
        }
        this.openDistrbutionTable = false;

        const selectedPeriod = this.selectedPeriod;

        console.log('TargetItems--->' + JSON.stringify(targetList));
        console.log('selectedPeriod--->' + selectedPeriod);

        saveTargets({ targetList: JSON.stringify(targetList), selctdperiod: selectedPeriod })
            .then(result => {
                this.targetList = result;
                this.resetAll();
                this.aggregateSubordinateTargets();
                this.isLoading = false;
                this.showToast('Success', 'Targets updated successfully.', 'success');
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'There was an issue saving the targets.', 'error');
            });
    }

    closeModal() {
        this.openDistrbutionTable = false;
        this.resetAll();
    }

    resetAll() {
        this.targetCriteriaArray = [];
        this.subOrdinateUserList = [];
        this.targetCriteriaColumns = [];
        this.targetCriteriaMap.clear();
    }

    openAdmintargetPopup() {
        this.adminTarget = true;
        this.getUserTargetActuals(this.selectedPeriod);
    }

    addTargetPeriodChangeHandler(event) {
        this.selectedAdminPeriod = event.target.value;
        this.getUserTargetActuals(this.selectedAdminPeriod);
    }

    getUserTargetActuals(period) {
        this.isPopupLoading = true;
        getUserTargetActuals({ period: period, userId: this.selectedUser })
            .then((result) => {
                console.log(JSON.stringify(result));
                this.adminTargetItems = result?.targetItems || [];
                this.targetCriterias = result?.targetCriterias || [];
                this.userTargetsCriteriasExisted = this.targetCriterias.length > 0 ? true : false;
                this.parentToTotalTargetValueMap = new Map(Object.entries(result?.parentToTotalTargetValueMap || {}));
                this.addAdminTarget();
                this.isPopupLoading = false;
            })
            .catch((error) => {
                this.isLoading = false;
                console.log('error' + JSON.stringify(error));
                this.showToast(
                    'Error',
                    'Error fetching targets: ' + (error.body ? error.body.message : JSON.stringify(error)),
                    'error'
                );
            });
    }

    addAdminTarget() {
        let targetListCopy = this.adminTargetItems.map(target => ({ ...target }));

        let adminTargets = targetListCopy.filter(target => target.User__c === this.selectedUser);

        let targetMap = new Map();
        adminTargets.forEach(target => targetMap.set(target.Target_Criteria__c, target));

        let targetItems = [];

        for (let targetCriteria of this.targetCriterias) {
            let extId = targetCriteria.Id;

            if (!targetMap.has(extId)) {
                let newTarget = this.addAdminTargetItem(targetCriteria, this.selectedUser);
                targetItems.push(newTarget);
            } else {
                targetItems.push(targetMap.get(extId));
            }
        }

        this.adminTargets = targetItems;

        console.log('Updated adminTargets:', this.adminTargets);
    }

    addAdminTargetItem(criteria, userId) {
        return {
            sobjectType: 'Target_Actual__c',
            Target_Criteria__r: {
                Id: criteria.Id,
                Name: criteria.Name,
            },
            Target_Criteria__c: criteria.Id,
            Target_Value__c: '',
            Achievement_Value__c: '',
            User__c: userId
        };
    }

    closeAdminTarget() {
        this.adminTarget = false;
    }

    handleTargetChange(event) {
        let targetCriteria = event.target.dataset.targetcriteria;
        let newValue = parseFloat(event.target.value) || '';
        let targetItemId = event.target.dataset.id;

        console.log('criteria:', targetCriteria, 'newValue:', newValue, 'targetItemId:', targetItemId);

        let totalValue = this.parentToTotalTargetValueMap?.get(targetItemId) || 0;
        console.log('totalValue:', totalValue);

        if (newValue < totalValue) {
            let targetItem = this.adminTargets.find(t => t.Id === targetItemId);
            if (targetItem) {
                targetItem.Min_Value__c = totalValue;
                targetItem.Message = `Min value allowed: ${totalValue}.`;
            }
        }

        this.adminTargets = this.adminTargets.map(t =>
            t.Target_Criteria__c === targetCriteria ? { ...t, Target_Value__c: newValue } : t
        );
    }

    saveAdminTarget() {
        const invalidTargets = this.adminTargets.filter(
            target => target.Target_Value__c < target.Min_Value__c
        );
        if (invalidTargets.length > 0) {
            this.isLoading = false;
            this.showToast('Error', `Target distribution initiated. Please enter the targets greater than minimum allowed value.`, 'error');
            return;
        }

        this.adminTarget = false;
        this.isLoading = true;
        let filteredAdminTargets = this.adminTargets.filter(target => target.Target_Value__c > 0);

        saveAdminTargetActuals({
            targetItems: filteredAdminTargets,
            selectedAdminPeriod: this.selectedAdminPeriod,
            selectedPeriod: this.selectedPeriod,
            userId: this.selectedUser
        })
            .then(result => {
                this.targetList = result;
                this.setCurrentTarget();
                this.resetAll();
                this.aggregateSubordinateTargets();
                this.isLoading = false;
                this.showToast('Success', 'Admin targets updated successfully', 'success');
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'There was an issue saving the targets.', 'error');
            });
    }

    aggregateSubordinateTargets() {
        this.parentwithtargetValueOfSubodinates = new Map();

        this.targetList.forEach(target => {
            if (target.Parent_Target__c) {
                let currentTotal = this.parentwithtargetValueOfSubodinates.get(target.Parent_Target__c) || 0;
                this.parentwithtargetValueOfSubodinates.set(target.Parent_Target__c, currentTotal + (target.Target_Value__c || 0));
            }
        });

        console.log('Aggregated Map:', this.parentwithtargetValueOfSubodinates);
    }

    populateOptions(dataList, labelField, valueField) {
        return dataList?.map(item => ({
            label: item[labelField],
            value: item[valueField]
        })) || [];
    }

    disablePullToRefresh() {
        const disableRefresh = new CustomEvent("updateScrollSettings", {
            detail: {
                isPullToRefreshEnabled: false
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(disableRefresh);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}