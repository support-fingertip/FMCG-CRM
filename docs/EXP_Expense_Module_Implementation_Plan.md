# Expense Management Module (EXP) — Revised Implementation Plan

## Context

Building an Expense Management module for the FMCG Field Sales CRM. The previous implementation created files using old naming (`Expense_Report__c`, `Expense_Line__c`, `Expense_Eligibility__mdt`). The user has requested these changes:

1. **Rename**: `Expense_Report__c` → `Expense__c` ("Expense"), `Expense_Line__c` → `Expense_Item__c` ("Expense Item")
2. **Expense Eligibility as Custom Object**: `Expense_Eligibility__mdt` → `Expense_Eligibility__c` (allows admin CRUD via standard UI — more dynamic)
3. **Responsive UI**: Desktop + mobile compatible, following existing SLDS patterns (visitManager, dayStartEnd)
4. **User-friendly**: Easy to create and read expenses with intuitive navigation

## What Needs to Change

### Files to DELETE (previously created with old naming)
```
# Old objects
objects/Expense_Report__c/   (entire directory — 21 files)
objects/Expense_Line__c/     (entire directory — 20 files)
objects/Expense_Eligibility__mdt/  (entire directory — 14 files)

# Old custom metadata records (60 eligibility seed records — no longer needed as custom object)
customMetadata/Expense_Eligibility.Band_*.md-meta.xml  (60 files)

# Old Apex classes (will be rewritten with new object names)
classes/EXP_Expense_Service.cls + .cls-meta.xml
classes/ExpenseController.cls + .cls-meta.xml
classes/EXP_ExpenseLine_TriggerHandler.cls + .cls-meta.xml
```

### Files to CREATE (new naming)

#### Custom Objects & Fields
```
objects/Employee__c/fields/Band__c.field-meta.xml                 (KEEP — already exists)

objects/Expense_Eligibility__c/Expense_Eligibility__c.object-meta.xml  (Custom Object, not metadata)
objects/Expense_Eligibility__c/fields/Band__c.field-meta.xml
objects/Expense_Eligibility__c/fields/Expense_Type__c.field-meta.xml
objects/Expense_Eligibility__c/fields/Expense_Category__c.field-meta.xml
objects/Expense_Eligibility__c/fields/Rate_Type__c.field-meta.xml
objects/Expense_Eligibility__c/fields/Rate_Amount__c.field-meta.xml
objects/Expense_Eligibility__c/fields/Max_Per_Day__c.field-meta.xml
objects/Expense_Eligibility__c/fields/Max_Per_Month__c.field-meta.xml
objects/Expense_Eligibility__c/fields/Min_Distance_KM__c.field-meta.xml
objects/Expense_Eligibility__c/fields/Receipt_Required__c.field-meta.xml
objects/Expense_Eligibility__c/fields/Receipt_Threshold__c.field-meta.xml
objects/Expense_Eligibility__c/fields/Is_Active__c.field-meta.xml
objects/Expense_Eligibility__c/fields/Sort_Order__c.field-meta.xml
objects/Expense_Eligibility__c/fields/Description__c.field-meta.xml

objects/Expense__c/Expense__c.object-meta.xml
objects/Expense__c/fields/Employee__c.field-meta.xml
objects/Expense__c/fields/User__c.field-meta.xml
objects/Expense__c/fields/Month__c.field-meta.xml
objects/Expense__c/fields/Year__c.field-meta.xml
objects/Expense__c/fields/Period_Start__c.field-meta.xml
objects/Expense__c/fields/Period_End__c.field-meta.xml
objects/Expense__c/fields/Status__c.field-meta.xml
objects/Expense__c/fields/Total_Claimed__c.field-meta.xml          (Roll-Up Summary)
objects/Expense__c/fields/Total_Approved__c.field-meta.xml         (Roll-Up Summary)
objects/Expense__c/fields/Total_Eligible__c.field-meta.xml         (Roll-Up Summary)
objects/Expense__c/fields/Working_Days__c.field-meta.xml
objects/Expense__c/fields/Total_Distance_KM__c.field-meta.xml
objects/Expense__c/fields/Submitted_Date__c.field-meta.xml
objects/Expense__c/fields/Manager_Approved_Date__c.field-meta.xml
objects/Expense__c/fields/Manager_Approver__c.field-meta.xml
objects/Expense__c/fields/Manager_Remarks__c.field-meta.xml
objects/Expense__c/fields/Finance_Approved_Date__c.field-meta.xml
objects/Expense__c/fields/Finance_Approver__c.field-meta.xml
objects/Expense__c/fields/Finance_Remarks__c.field-meta.xml
objects/Expense__c/fields/Rejection_Reason__c.field-meta.xml

objects/Expense_Item__c/Expense_Item__c.object-meta.xml
objects/Expense_Item__c/fields/Expense__c.field-meta.xml           (Master-Detail → Expense__c)
objects/Expense_Item__c/fields/Day_Attendance__c.field-meta.xml
objects/Expense_Item__c/fields/Expense_Date__c.field-meta.xml
objects/Expense_Item__c/fields/Expense_Type__c.field-meta.xml
objects/Expense_Item__c/fields/Expense_Category__c.field-meta.xml
objects/Expense_Item__c/fields/GPS_Distance_KM__c.field-meta.xml
objects/Expense_Item__c/fields/Manual_Distance_KM__c.field-meta.xml
objects/Expense_Item__c/fields/Distance_Override_Reason__c.field-meta.xml
objects/Expense_Item__c/fields/Applied_Distance_KM__c.field-meta.xml  (Formula)
objects/Expense_Item__c/fields/Eligible_Amount__c.field-meta.xml
objects/Expense_Item__c/fields/Claimed_Amount__c.field-meta.xml
objects/Expense_Item__c/fields/Approved_Amount__c.field-meta.xml
objects/Expense_Item__c/fields/Receipt_URL__c.field-meta.xml
objects/Expense_Item__c/fields/Receipt_Required__c.field-meta.xml
objects/Expense_Item__c/fields/Has_Receipt__c.field-meta.xml       (Formula)
objects/Expense_Item__c/fields/Notes__c.field-meta.xml
objects/Expense_Item__c/fields/Rate_Type__c.field-meta.xml
objects/Expense_Item__c/fields/Rate_Amount__c.field-meta.xml
objects/Expense_Item__c/fields/Is_Eligible__c.field-meta.xml
```

#### Custom Metadata (Feature Toggles + App Config only — KEEP existing)
```
customMetadata/Feature_Toggle.EXP_Expense_Module.md-meta.xml     (KEEP)
customMetadata/Feature_Toggle.EXP_Auto_Calculate.md-meta.xml     (KEEP)
customMetadata/Feature_Toggle.EXP_Finance_Approval.md-meta.xml   (KEEP)
customMetadata/App_Config.EXP_ALLOW_FUTURE_DATES.md-meta.xml     (KEEP)
customMetadata/App_Config.EXP_MAX_OVERRIDE_PERCENT.md-meta.xml   (KEEP)
customMetadata/App_Config.EXP_REPORT_LOCK_DAY.md-meta.xml        (KEEP)
customMetadata/App_Config.EXP_FINANCE_ROLE.md-meta.xml            (KEEP)
```

#### Apex Classes (rewritten with new object names)
```
classes/EXP_Expense_Service.cls + .cls-meta.xml          (rewrite: Expense__c, Expense_Item__c, Expense_Eligibility__c)
classes/EXP_Expense_Service_Test.cls + .cls-meta.xml
classes/ExpenseController.cls + .cls-meta.xml            (rewrite references)
classes/ExpenseController_Test.cls + .cls-meta.xml
classes/EXP_ExpenseItem_TriggerHandler.cls + .cls-meta.xml    (renamed from ExpenseLine)
classes/EXP_ExpenseItem_TriggerHandler_Test.cls + .cls-meta.xml
classes/EXP_Expense_TriggerHandler.cls + .cls-meta.xml        (renamed from ExpenseReport)
classes/EXP_Expense_TriggerHandler_Test.cls + .cls-meta.xml
```

#### Triggers
```
triggers/Expense_Trigger.trigger + .trigger-meta.xml         (on Expense__c)
triggers/Expense_Item_Trigger.trigger + .trigger-meta.xml    (on Expense_Item__c)
```

#### LWC — `expenseManager` (responsive, mobile-first)
```
lwc/expenseManager/expenseManager.js
lwc/expenseManager/expenseManager.html
lwc/expenseManager/expenseManager.css
lwc/expenseManager/expenseManager.js-meta.xml
```

#### Tabs
```
tabs/Expense_Manager.tab-meta.xml      (LWC tab)
tabs/Expense__c.tab-meta.xml           (object tab)
```

#### Updates to existing files
```
applications/Field_Sales_CRM.app-meta.xml   (add tab references)
profiles/Admin.profile-meta.xml             (add classAccesses + tabVisibilities)
```

---

## Key Data Model Changes

### Expense_Eligibility__c (Custom Object — replaces __mdt)
- **Sharing**: Private (admin-managed, read via `without sharing` service)
- **Name**: Auto Number `ELIG-{0000}`
- Same fields as before but as a custom object — admins manage via standard Salesforce UI or a dedicated admin LWC
- Query changes in service: `[SELECT ... FROM Expense_Eligibility__c WHERE ...]` instead of `Expense_Eligibility__mdt.getAll()`
- No seed metadata records needed — admins create records as data

### Expense__c (was Expense_Report__c)
- **Label**: "Expense" / **Plural**: "Expenses"
- **Name**: Auto Number `EXP-{0000}`
- Roll-up summaries now reference `Expense_Item__c`

### Expense_Item__c (was Expense_Line__c)
- **Label**: "Expense Item" / **Plural**: "Expense Items"
- **Name**: Auto Number `EXPI-{00000}`
- Master-Detail to `Expense__c` (field API: `Expense__c`)

---

## Apex Code Changes Summary

### EXP_Expense_Service.cls
All references updated:
- `Expense_Report__c` → `Expense__c`
- `Expense_Line__c` → `Expense_Item__c`
- `Expense_Eligibility__mdt` → `Expense_Eligibility__c`
- `Expense_Report__c` field on line → `Expense__c`
- Eligibility query: SOQL query instead of `.getAll()` pattern
- Cache: use transaction-scoped SOQL cache (query once, store in static map)

### ExpenseController.cls
- Same thin wrapper pattern, updated object references

### EXP_ExpenseItem_TriggerHandler.cls (was EXP_ExpenseLine_TriggerHandler)
- Same logic, updated to `Expense_Item__c` references

### EXP_Expense_TriggerHandler.cls (was EXP_ExpenseReport_TriggerHandler)
- Status transition validation on `Expense__c`
- beforeUpdate: validate transitions using `EXP_Expense_Service.isValidTransition()`

---

## LWC: `expenseManager` — Responsive Design

### Design Principles (from existing codebase patterns)
- **CSS Variables**: Reuse project color palette (`:host` variables from visitManager/dayStartEnd)
- **Breakpoints**: `768px` (tablet), `480px` (mobile) — matching existing patterns
- **Container**: `max-width: 960px`, `margin: 0 auto`, adaptive padding
- **Modals**: Full-screen on mobile (`max-width: 100%`, `border-radius: 0`)
- **Tables**: `slds-scrollable_x` wrapper for horizontal scroll on mobile
- **Buttons**: Stack vertically on mobile
- **Grid**: CSS Grid with `auto-fill, minmax()` for responsive stat cards

### UI Screens

**Screen 1: Monthly Overview (Default)**
- Month/Year selector (combobox)
- Status badge + summary stat cards (Total Eligible, Claimed, Approved, Working Days, Distance)
- Calendar grid showing days of month — each cell shows attendance status + expense total
- Greyed-out cells for non-attendance days
- Tap/click a date → opens Screen 2
- Submit / action buttons in footer

**Screen 2: Day Expense Entry (Modal / Slide Panel)**
- Date header with attendance info (check-in time, GPS distance)
- Card-based layout per expense type (not table rows — better for mobile):
  - Expense type name + rate info badge
  - GPS Distance (read-only) + Manual Override input + Override Reason
  - Eligible Amount (auto-calculated, read-only)
  - Claimed Amount input
  - Receipt upload button (conditionally shown)
  - Notes field
- Save + Cancel buttons
- On mobile: full-screen modal, inputs stack vertically

**Screen 3: Summary View (Tab/Toggle)**
- Summary table: expense types as rows, with Eligible / Claimed / Approved columns
- Per-day breakdown expandable
- Monthly totals row

**Screen 4: Manager Approval View (conditional on role)**
- List of pending team expense reports
- Click → drill into report details
- Approve / Reject buttons with remarks field

---

## Status Transition Metadata
Add `Status_Transition__mdt` records for `Expense__c`:

| Object | From | To | Required Role |
|--------|------|-----|--------------|
| Expense__c | Draft | Submitted | Owner |
| Expense__c | Submitted | Manager Approved | Reporting Manager |
| Expense__c | Submitted | Rejected | Reporting Manager |
| Expense__c | Manager Approved | Finance Approved | Finance Role |
| Expense__c | Manager Approved | Rejected | Finance Role |
| Expense__c | Rejected | Draft | Owner |
| Expense__c | Finance Approved | Paid | Finance Role |

---

## Implementation Order

| Phase | Step | Description |
|-------|------|-------------|
| 0 | 0.1 | Delete old files (Expense_Report__c, Expense_Line__c, Expense_Eligibility__mdt objects + 60 seed records + old Apex classes) |
| 1 | 1.1 | Keep `Band__c` field on Employee__c (already exists) |
| 1 | 1.2 | Create `Expense_Eligibility__c` custom object + all fields |
| 1 | 1.3 | Create `Expense__c` object + all fields |
| 1 | 1.4 | Create `Expense_Item__c` object + all fields (Master-Detail to Expense__c) |
| 1 | 1.5 | Keep existing Feature_Toggle + App_Config metadata records |
| 2 | 2.1 | Rewrite `EXP_Expense_Service.cls` with new object names |
| 2 | 2.2 | Rewrite `ExpenseController.cls` with new references |
| 2 | 2.3 | Create `EXP_ExpenseItem_TriggerHandler.cls` (renamed) |
| 2 | 2.4 | Create `EXP_Expense_TriggerHandler.cls` (status transitions) |
| 2 | 2.5 | Create triggers: `Expense_Trigger.trigger`, `Expense_Item_Trigger.trigger` |
| 2 | 2.6 | Create all test classes |
| 3 | 3.1 | Create `expenseManager` LWC (responsive, card-based day entry, calendar view) |
| 3 | 3.2 | Create tabs + update app + update Admin profile |
| 4 | 4.1 | Add Status_Transition__mdt records for Expense__c |
| 4 | 4.2 | Commit and push |

---

## Verification
- All Apex classes compile (no broken references to old object names)
- LWC renders on desktop and mobile viewports
- Feature toggle checks work (`BPM_FeatureToggle_Util.isEnabled`)
- Eligibility query from custom object returns correct rules per band
- Calendar shows only attendance days as active
- Day expense entry auto-calculates eligible amounts
- Status transitions are validated
- Roll-up summaries on Expense__c aggregate from Expense_Item__c
