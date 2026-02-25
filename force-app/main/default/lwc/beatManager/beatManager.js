import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Id from '@salesforce/user/Id';

import getBeatsForUser from '@salesforce/apex/BeatPlanController.getBeatsForUser';
import saveBeat from '@salesforce/apex/BeatPlanController.saveBeat';
import deleteBeat from '@salesforce/apex/BeatPlanController.deleteBeat';
import getBeatOutlets from '@salesforce/apex/BeatPlanController.getBeatOutlets';
import addBeatOutlets from '@salesforce/apex/BeatPlanController.addBeatOutlets';
import removeBeatOutlet from '@salesforce/apex/BeatPlanController.removeBeatOutlet';
import getAccountsByTerritory from '@salesforce/apex/BeatPlanController.getAccountsByTerritory';
import cloneBeat from '@salesforce/apex/BeatPlanController.cloneBeat';
import reassignBeat from '@salesforce/apex/BeatPlanController.reassignBeat';

const DAY_OPTIONS = [
    { label: 'Monday', value: 'Monday' },
    { label: 'Tuesday', value: 'Tuesday' },
    { label: 'Wednesday', value: 'Wednesday' },
    { label: 'Thursday', value: 'Thursday' },
    { label: 'Friday', value: 'Friday' },
    { label: 'Saturday', value: 'Saturday' }
];

const FREQUENCY_OPTIONS = [
    { label: 'Daily', value: 'Daily' },
    { label: 'Weekly', value: 'Weekly' },
    { label: 'Bi-Weekly', value: 'Bi-Weekly' },
    { label: 'Monthly', value: 'Monthly' }
];

const PAGE_SIZE = 10;

export default class BeatManager extends LightningElement {
    currentUserId = Id;
    @track selectedExecutiveId = Id;
    @track beats = [];
    @track selectedBeat = null;
    @track beatOutlets = [];
    @track territoryAccounts = [];
    @track selectedAccountIds = [];
    isLoading = false;
    showBeatForm = false;
    accountSearchTerm = '';
    beatSearchTerm = '';

    // Clone modal state
    showCloneModal = false;
    @track cloneForm = { Name: '', Beat_Code__c: '', Assigned_User__c: null };

    // Reassign modal state
    showReassignModal = false;
    reassignUserId = null;

    // Pagination state
    accountPageNumber = 1;
    accountTotalPages = 1;
    accountTotalCount = 0;

    // Debounce timers
    _searchTimer;
    _beatSearchTimer;

    // Beat form fields
    @track beatForm = {
        Id: null,
        Name: '',
        Beat_Code__c: '',
        Day_of_Week__c: [],
        Frequency__c: 'Weekly',
        Territory__c: null,
        Pincode_Cluster__c: '',
        Description__c: '',
        Assigned_User__c: null,
        Sequence__c: null,
        Is_Active__c: true
    };

    dayOptions = DAY_OPTIONS;
    frequencyOptions = FREQUENCY_OPTIONS;

    get formTitle() {
        return this.beatForm.Id ? 'Edit Beat' : 'New Beat';
    }

    get filteredBeats() {
        if (!this.beatSearchTerm) {
            return this.beats;
        }
        const term = this.beatSearchTerm.toLowerCase();
        return this.beats.filter(beat =>
            (beat.Name && beat.Name.toLowerCase().includes(term)) ||
            (beat.Beat_Code__c && beat.Beat_Code__c.toLowerCase().includes(term)) ||
            (beat.territoryName && beat.territoryName.toLowerCase().includes(term))
        );
    }

    get filteredBeatsCount() {
        return this.filteredBeats.length;
    }

    get hasFilteredBeats() {
        return this.filteredBeats.length > 0;
    }

    get hasBeats() {
        return this.beats.length > 0;
    }

    get hasBeatSelected() {
        return this.selectedBeat != null;
    }

    get hasOutlets() {
        return this.beatOutlets.length > 0;
    }

    get hasTerritoryAccounts() {
        return this.territoryAccounts.length > 0;
    }

    get isEditDisabled() {
        return !this.selectedBeat;
    }

    get selectedBeatName() {
        return this.selectedBeat ? this.selectedBeat.Name : '';
    }

    get outletCountLabel() {
        return this.beatOutlets.length + ' Outlet' + (this.beatOutlets.length !== 1 ? 's' : '');
    }

    get accountListLabel() {
        if (this.accountTotalCount > 0) {
            return this.accountTotalCount + ' Account' + (this.accountTotalCount !== 1 ? 's' : '');
        }
        return '0 Accounts';
    }

    get selectedTerritoryName() {
        return this.selectedBeat && this.selectedBeat.territoryName
            ? this.selectedBeat.territoryName : '';
    }

    get hasSelectedAccounts() {
        return this.selectedAccountIds.length > 0;
    }

    get isAddDisabled() {
        return this.selectedAccountIds.length === 0;
    }

    get selectedCountLabel() {
        return this.selectedAccountIds.length + ' selected';
    }

    get isPrevDisabled() {
        return this.accountPageNumber <= 1;
    }

    get isNextDisabled() {
        return this.accountPageNumber >= this.accountTotalPages;
    }

    get paginationLabel() {
        return 'Page ' + this.accountPageNumber + ' of ' + this.accountTotalPages;
    }

    get showPagination() {
        return this.accountTotalPages > 1;
    }

    connectedCallback() {
        this.loadBeats();
    }

    async loadBeats() {
        this.isLoading = true;
        try {
            const result = await getBeatsForUser({ userId: this.selectedExecutiveId });
            this.beats = (result || []).map(beat => ({
                ...beat,
                daysDisplay: beat.Day_of_Week__c ? beat.Day_of_Week__c.replace(/;/g, ', ') : '-',
                outletCount: beat.Total_Outlets__c || 0,
                territoryName: beat.Territory__r ? beat.Territory__r.Name : '-',
                rowClass: this.selectedBeat && this.selectedBeat.Id === beat.Id
                    ? 'beat-row beat-row-selected' : 'beat-row'
            }));
        } catch (error) {
            this.showToast('Error', 'Failed to load beats: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleSelectBeat(event) {
        const beatId = event.currentTarget.dataset.id;
        const beat = this.beats.find(b => b.Id === beatId);
        if (beat) {
            this.selectedBeat = beat;
            this.beats = this.beats.map(b => ({
                ...b,
                rowClass: b.Id === beatId ? 'beat-row beat-row-selected' : 'beat-row'
            }));
            this.loadOutlets(beatId);
            // Reset and load territory accounts
            this.accountSearchTerm = '';
            this.accountPageNumber = 1;
            this.selectedAccountIds = [];
            this.loadTerritoryAccounts();
        }
    }

    async loadOutlets(beatId) {
        try {
            const result = await getBeatOutlets({ beatId: beatId });
            this.beatOutlets = (result || []).map(outlet => ({
                ...outlet,
                accountName: outlet.Account__r ? outlet.Account__r.Name : 'Unknown',
                statusLabel: outlet.Is_Active__c ? 'Active' : 'Inactive'
            }));
        } catch (error) {
            this.showToast('Error', 'Failed to load outlets: ' + this.reduceErrors(error), 'error');
        }
    }

    async loadTerritoryAccounts() {
        if (!this.selectedBeat) return;
        try {
            const territoryId = this.selectedBeat.Territory__c || null;
            const result = await getAccountsByTerritory({
                territoryId: territoryId,
                searchTerm: this.accountSearchTerm || '',
                pageSize: PAGE_SIZE,
                pageNumber: this.accountPageNumber
            });

            const existingIds = new Set(this.beatOutlets.map(o => o.Account__c));
            this.territoryAccounts = (result.accounts || []).map(acc => ({
                ...acc,
                cityState: [acc.BillingCity, acc.BillingState].filter(Boolean).join(', ') || '-',
                alreadyAdded: existingIds.has(acc.Id),
                isSelected: this.selectedAccountIds.includes(acc.Id),
                rowClass: existingIds.has(acc.Id)
                    ? 'account-row account-row-disabled'
                    : this.selectedAccountIds.includes(acc.Id)
                        ? 'account-row account-row-selected' : 'account-row'
            }));
            this.accountTotalCount = result.totalCount;
            this.accountTotalPages = result.totalPages || 1;
        } catch (error) {
            console.error('Error loading territory accounts:', error);
        }
    }

    // ── Beat CRUD ──────────────────────────────────────────────

    handleNewBeat() {
        this.beatForm = {
            Id: null,
            Name: '',
            Beat_Code__c: '',
            Day_of_Week__c: [],
            Frequency__c: 'Weekly',
            Territory__c: this.selectedBeat ? this.selectedBeat.Territory__c : null,
            Pincode_Cluster__c: '',
            Description__c: '',
            Assigned_User__c: this.currentUserId,
            Sequence__c: this.beats.length + 1,
            Is_Active__c: true
        };
        this.showBeatForm = true;
    }

    handleEditBeat() {
        if (!this.selectedBeat) return;
        this.beatForm = {
            Id: this.selectedBeat.Id,
            Name: this.selectedBeat.Name,
            Beat_Code__c: this.selectedBeat.Beat_Code__c || '',
            Day_of_Week__c: this.selectedBeat.Day_of_Week__c
                ? this.selectedBeat.Day_of_Week__c.split(';') : [],
            Frequency__c: this.selectedBeat.Frequency__c || 'Weekly',
            Territory__c: this.selectedBeat.Territory__c,
            Pincode_Cluster__c: this.selectedBeat.Pincode_Cluster__c || '',
            Description__c: this.selectedBeat.Description__c || '',
            Assigned_User__c: this.selectedBeat.Assigned_User__c,
            Sequence__c: this.selectedBeat.Sequence__c,
            Is_Active__c: this.selectedBeat.Is_Active__c !== false
        };
        this.showBeatForm = true;
    }

    handleBeatFormChange(event) {
        const field = event.target.dataset.field;
        if (field === 'Day_of_Week__c') {
            this.beatForm = { ...this.beatForm, [field]: event.detail.value };
        } else if (field === 'Territory__c' || field === 'Assigned_User__c') {
            this.beatForm = { ...this.beatForm, [field]: event.detail.value[0] || null };
        } else if (field === 'Is_Active__c') {
            this.beatForm = { ...this.beatForm, [field]: event.target.checked };
        } else {
            this.beatForm = { ...this.beatForm, [field]: event.target.value };
        }
    }

    handleCancelBeatForm() {
        this.showBeatForm = false;
    }

    async handleSaveBeat() {
        if (!this.beatForm.Name || !this.beatForm.Beat_Code__c) {
            this.showToast('Error', 'Beat Name and Beat Code are required.', 'error');
            return;
        }
        if (!this.beatForm.Assigned_User__c) {
            this.showToast('Error', 'Assigned User is required.', 'error');
            return;
        }
        if (!this.beatForm.Day_of_Week__c || this.beatForm.Day_of_Week__c.length === 0) {
            this.showToast('Error', 'Please select at least one day.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const beatRecord = {
                Name: this.beatForm.Name,
                Beat_Code__c: this.beatForm.Beat_Code__c,
                Day_of_Week__c: this.beatForm.Day_of_Week__c.join(';'),
                Frequency__c: this.beatForm.Frequency__c,
                Territory__c: this.beatForm.Territory__c,
                Pincode_Cluster__c: this.beatForm.Pincode_Cluster__c,
                Description__c: this.beatForm.Description__c,
                Assigned_User__c: this.beatForm.Assigned_User__c,
                Sequence__c: this.beatForm.Sequence__c,
                Is_Active__c: this.beatForm.Is_Active__c
            };
            if (this.beatForm.Id) {
                beatRecord.Id = this.beatForm.Id;
            }

            const savedBeat = await saveBeat({ beat: beatRecord });
            this.showBeatForm = false;
            this.showToast('Success', 'Beat saved successfully.', 'success');
            await this.loadBeats();
            this.selectedBeat = this.beats.find(b => b.Id === savedBeat.Id) || null;
            if (this.selectedBeat) {
                this.beats = this.beats.map(b => ({
                    ...b,
                    rowClass: b.Id === savedBeat.Id ? 'beat-row beat-row-selected' : 'beat-row'
                }));
                this.loadOutlets(savedBeat.Id);
                this.accountPageNumber = 1;
                this.loadTerritoryAccounts();
            }
        } catch (error) {
            this.showToast('Error', 'Failed to save beat: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleDeleteBeat() {
        if (!this.selectedBeat) return;
        this.isLoading = true;
        try {
            await deleteBeat({ beatId: this.selectedBeat.Id });
            this.showToast('Success', 'Beat deleted.', 'success');
            this.selectedBeat = null;
            this.beatOutlets = [];
            this.territoryAccounts = [];
            this.accountTotalCount = 0;
            this.accountTotalPages = 1;
            await this.loadBeats();
        } catch (error) {
            this.showToast('Error', 'Failed to delete beat: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Executive Picker ───────────────────────────────────────────

    handleExecutiveChange(event) {
        const val = event.detail.value;
        const newId = Array.isArray(val) ? (val[0] || null) : val;
        if (newId && newId !== this.selectedExecutiveId) {
            this.selectedExecutiveId = newId;
            this.selectedBeat = null;
            this.beatOutlets = [];
            this.territoryAccounts = [];
            this.beatSearchTerm = '';
            this.loadBeats();
        }
    }

    handleResetExecutive() {
        if (this.selectedExecutiveId !== this.currentUserId) {
            this.selectedExecutiveId = this.currentUserId;
            this.selectedBeat = null;
            this.beatOutlets = [];
            this.territoryAccounts = [];
            this.beatSearchTerm = '';
            this.loadBeats();
        }
    }

    // ── Beat Search ─────────────────────────────────────────────

    handleBeatSearchChange(event) {
        this.beatSearchTerm = event.target.value;
    }

    // ── Clone Beat ──────────────────────────────────────────────

    handleCloneBeat() {
        if (!this.selectedBeat) return;
        this.cloneForm = {
            Name: this.selectedBeat.Name + ' (Copy)',
            Beat_Code__c: this.selectedBeat.Beat_Code__c + '-COPY',
            Assigned_User__c: this.selectedBeat.Assigned_User__c || this.currentUserId
        };
        this.showCloneModal = true;
    }

    handleCloneFormChange(event) {
        const field = event.target.dataset.field;
        if (field === 'CloneName') {
            this.cloneForm = { ...this.cloneForm, Name: event.target.value };
        } else if (field === 'CloneCode') {
            this.cloneForm = { ...this.cloneForm, Beat_Code__c: event.target.value };
        } else if (field === 'CloneUser') {
            const val = event.detail.value;
            this.cloneForm = { ...this.cloneForm, Assigned_User__c: Array.isArray(val) ? (val[0] || null) : val };
        }
    }

    handleCancelClone() {
        this.showCloneModal = false;
    }

    async handleSaveClone() {
        if (!this.cloneForm.Name || !this.cloneForm.Beat_Code__c) {
            this.showToast('Error', 'Beat Name and Beat Code are required.', 'error');
            return;
        }
        if (!this.cloneForm.Assigned_User__c) {
            this.showToast('Error', 'Assigned User is required.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const cloned = await cloneBeat({
                sourceBeatId: this.selectedBeat.Id,
                newAssignedUserId: this.cloneForm.Assigned_User__c,
                newBeatName: this.cloneForm.Name,
                newBeatCode: this.cloneForm.Beat_Code__c
            });
            this.showCloneModal = false;
            this.showToast('Success', 'Beat cloned successfully.', 'success');
            await this.loadBeats();
            // Select the cloned beat
            this.selectedBeat = this.beats.find(b => b.Id === cloned.Id) || null;
            if (this.selectedBeat) {
                this.beats = this.beats.map(b => ({
                    ...b,
                    rowClass: b.Id === cloned.Id ? 'beat-row beat-row-selected' : 'beat-row'
                }));
                this.loadOutlets(cloned.Id);
                this.accountPageNumber = 1;
                this.loadTerritoryAccounts();
            }
        } catch (error) {
            this.showToast('Error', 'Failed to clone beat: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Reassign Beat ───────────────────────────────────────────

    handleReassignBeat() {
        if (!this.selectedBeat) return;
        this.reassignUserId = null;
        this.showReassignModal = true;
    }

    handleReassignUserChange(event) {
        const val = event.detail.value;
        this.reassignUserId = Array.isArray(val) ? (val[0] || null) : val;
    }

    handleCancelReassign() {
        this.showReassignModal = false;
    }

    async handleSaveReassign() {
        if (!this.reassignUserId) {
            this.showToast('Error', 'Please select a user to reassign to.', 'error');
            return;
        }
        if (this.reassignUserId === this.selectedBeat.Assigned_User__c) {
            this.showToast('Warning', 'The beat is already assigned to this user.', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            const result = await reassignBeat({
                beatId: this.selectedBeat.Id,
                newUserId: this.reassignUserId
            });
            this.showReassignModal = false;

            let msg = 'Beat reassigned successfully.';
            if (result.affectedPlanDays > 0) {
                msg += ' ' + result.affectedPlanDays + ' Journey Plan day(s) in Draft/Active plans reference this beat.';
            }
            this.showToast('Success', msg, 'success');

            await this.loadBeats();
            const beatId = this.selectedBeat.Id;
            this.selectedBeat = this.beats.find(b => b.Id === beatId) || null;
            if (this.selectedBeat) {
                this.beats = this.beats.map(b => ({
                    ...b,
                    rowClass: b.Id === beatId ? 'beat-row beat-row-selected' : 'beat-row'
                }));
            }
        } catch (error) {
            this.showToast('Error', 'Failed to reassign beat: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Account Search & Pagination ──────────────────────────────

    handleAccountSearchChange(event) {
        this.accountSearchTerm = event.target.value;
        clearTimeout(this._searchTimer);
        this._searchTimer = setTimeout(() => {
            this.accountPageNumber = 1;
            this.loadTerritoryAccounts();
        }, 300);
    }

    handlePrevPage() {
        if (this.accountPageNumber > 1) {
            this.accountPageNumber--;
            this.loadTerritoryAccounts();
        }
    }

    handleNextPage() {
        if (this.accountPageNumber < this.accountTotalPages) {
            this.accountPageNumber++;
            this.loadTerritoryAccounts();
        }
    }

    handleToggleAccount(event) {
        const accId = event.currentTarget.dataset.id;
        const account = this.territoryAccounts.find(a => a.Id === accId);
        if (account && account.alreadyAdded) return;

        const idx = this.selectedAccountIds.indexOf(accId);
        if (idx >= 0) {
            this.selectedAccountIds = this.selectedAccountIds.filter(id => id !== accId);
        } else {
            this.selectedAccountIds = [...this.selectedAccountIds, accId];
        }
        this.territoryAccounts = this.territoryAccounts.map(r => ({
            ...r,
            isSelected: this.selectedAccountIds.includes(r.Id),
            rowClass: r.alreadyAdded
                ? 'account-row account-row-disabled'
                : this.selectedAccountIds.includes(r.Id)
                    ? 'account-row account-row-selected' : 'account-row'
        }));
    }

    async handleAddOutlets() {
        if (!this.selectedBeat || this.selectedAccountIds.length === 0) return;
        this.isLoading = true;
        try {
            const result = await addBeatOutlets({
                beatId: this.selectedBeat.Id,
                accountIds: this.selectedAccountIds
            });
            this.beatOutlets = (result || []).map(outlet => ({
                ...outlet,
                accountName: outlet.Account__r ? outlet.Account__r.Name : 'Unknown',
                statusLabel: outlet.Is_Active__c ? 'Active' : 'Inactive'
            }));
            this.selectedAccountIds = [];
            this.showToast('Success', 'Outlets added to beat.', 'success');
            await this.loadBeats();
            this.loadTerritoryAccounts();
        } catch (error) {
            this.showToast('Error', 'Failed to add outlets: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleRemoveOutlet(event) {
        const outletId = event.currentTarget.dataset.id;
        this.isLoading = true;
        try {
            await removeBeatOutlet({ beatOutletId: outletId });
            this.beatOutlets = this.beatOutlets.filter(o => o.Id !== outletId);
            this.showToast('Success', 'Outlet removed.', 'success');
            await this.loadBeats();
            this.loadTerritoryAccounts();
        } catch (error) {
            this.showToast('Error', 'Failed to remove outlet: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Helpers ─────────────────────────────────────────────────

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
