# QA Test Plan: Beat Management, Journey Planner, Holiday Management, Employee Management & Leave Management

**Project:** FieldSalesCRM (FMCG SFA)
**Version:** 1.0
**Date:** 2026-03-02
**Prepared By:** Development Team
**Status:** Ready for Internal Testing → QA Handoff

---

## Table of Contents

1. [Test Environment Setup](#1-test-environment-setup)
2. [Module 1: Beat Management](#2-module-1-beat-management)
3. [Module 2: Journey Planner](#3-module-2-journey-planner)
4. [Module 3: Holiday Management](#4-module-3-holiday-management)
5. [Module 4: Employee Management](#5-module-4-employee-management)
6. [Module 5: Leave Management](#6-module-5-leave-management)
7. [Cross-Module Integration Tests](#7-cross-module-integration-tests)
8. [Regression & Edge Cases](#8-regression--edge-cases)

---

## 1. Test Environment Setup

### Prerequisites

| Item | Requirement |
|------|-------------|
| Salesforce Org | Scratch org or sandbox with `FSCRM` namespace |
| API Version | 59.0 |
| Users Required | 1 Admin, 1 Manager (RSM/ASM), 2 Sales Reps |
| Objects Deployed | Employee__c, Beat__c, Beat_Outlet__c, Journey_Plan__c, Journey_Plan_Day__c, Holiday__c, Leave_Request__c, Territory_Master__c, Day_Attendance__c, Visit__c |
| Feature Toggles | BPM-001 (Beat Definition) = ON, BPM-002 (Journey Plan) = ON |
| Apex Classes | All BPM_*, BeatPlanController, HolidayController, EmployeeController, LeaveRequestController, EmployeeThreeSixtyController |
| LWC Components | beatManager, beatPlanCalendar, holidayManager, employeeManager, leaveManager, leaveApproval, employeeThreeSixty |

### Sample Data Checklist

Before starting tests, ensure the following data exists:

- [ ] At least 2 Territory_Master__c records (e.g., "Mumbai", "Delhi")
- [ ] At least 4 Employee__c records with hierarchy (NSM → RSM → ASM → SR)
- [ ] Each Employee linked to a User record via `User__c`
- [ ] At least 6 Beat__c records across territories with different Day_of_Week__c and Frequency__c settings
- [ ] At least 10 Account records tagged with territories
- [ ] Beat_Outlet__c mappings (3-5 outlets per beat)
- [ ] Holiday__c records for current year (National + Territory-specific)
- [ ] Employee Week_Off_Days__c configured (e.g., "Sunday")
- [ ] Leave balances set on Employee records (CL=12, SL=7, EL=15, CO=0)

---

## 2. Module 1: Beat Management

### 2.1 Overview

**Objects:** `Beat__c`, `Beat_Outlet__c`
**Apex Classes:** `BeatPlanController`, `BPM_Beat_TriggerHandler`, `BPM_BeatOutlet_TriggerHandler`
**LWC Component:** `beatManager`
**Feature Toggle:** BPM-001

### 2.2 Test Cases: Beat CRUD

#### TC-BM-001: Create a New Beat

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Beat Manager LWC | Component loads; executive picker visible |
| 2 | Click "New Beat" button | Create Beat form/modal opens |
| 3 | Fill in: Name = "Test Beat Alpha", Beat Code = "BT-TST-001", Territory = select any, Day of Week = "Monday;Wednesday", Frequency = "Weekly", Assigned User = select a sales rep | All fields accept input |
| 4 | Click "Save" | Beat is saved. Toast success message. Beat appears in the list |
| 5 | Verify record in Salesforce | Beat__c record created. `Is_Active__c` = true (auto-default). `OwnerId` set to Assigned User |

#### TC-BM-002: Beat Code Uniqueness Validation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create a beat with Beat Code = "BT-TST-001" (already exists) | Error: "Beat Code 'BT-TST-001' is already in use. Please choose a unique code." |
| 2 | Try Beat Code = "bt-tst-001" (lowercase) | Same error (case-insensitive check) |
| 3 | Use a unique code "BT-TST-002" | Beat saves successfully |

#### TC-BM-003: Beat Validation Rules

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create beat without Beat_Code__c | Error: "Beat Code is required." |
| 2 | Create active beat without Day_of_Week__c | Error: Day is required when active |
| 3 | Create active beat without Territory__c | Error: Territory is required when active |

#### TC-BM-004: Edit an Existing Beat

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select a beat from the list | Beat details loaded in right panel |
| 2 | Click "Edit" | Edit form opens pre-populated |
| 3 | Change Frequency from "Weekly" to "Bi-Weekly" | Field updates |
| 4 | Save | Beat updated. Toast success. List refreshed |

#### TC-BM-005: Delete a Beat

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select a beat with no future Journey Plan Days | Beat selected |
| 2 | Click "Delete" | Confirmation prompt appears |
| 3 | Confirm | Beat deleted. Removed from list |

#### TC-BM-006: Deactivation Protection

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create a Journey Plan Day for a beat with Plan_Date__c in the future | Plan Day created |
| 2 | Try to deactivate that beat (set Is_Active__c = false) | Error: "Cannot deactivate this beat because it has future journey plan assignments. Please reassign or remove the beat from future plans first." |
| 3 | Remove the future Plan Day, then deactivate | Beat deactivated successfully |

### 2.3 Test Cases: Beat Outlet Management

#### TC-BM-007: Add Outlets to a Beat

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select a beat | Outlet list panel visible (may be empty) |
| 2 | Click "Add Outlets" | Account search/picker modal opens |
| 3 | Search for accounts by name | Results displayed with Name, Type, City, State |
| 4 | Select 3 accounts and confirm | Outlets added. Visit_Sequence__c auto-assigned (1, 2, 3). Total_Outlets__c updated on parent Beat |
| 5 | Try adding the same account again | Account skipped (duplicate prevention). No error, but no duplicate entry |

#### TC-BM-008: Remove an Outlet from a Beat

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select a beat with outlets | Outlet list displayed |
| 2 | Click remove/delete on an outlet | Outlet removed. Visit_Sequence__c of remaining outlets unchanged |
| 3 | Verify Beat__c.Total_Outlets__c | Count decremented by 1 (trigger recalculates) |

#### TC-BM-009: Reorder Outlets (Sequence Management)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select a beat with 3+ outlets | Outlets displayed with sequence numbers |
| 2 | Click "Move Up" on the 2nd outlet | 2nd and 1st outlets swap sequences |
| 3 | Click "Move Down" on the 1st outlet | 1st and 2nd outlets swap sequences |
| 4 | Save the order | Visit_Sequence__c values persisted. Refreshed list matches new order |
| 5 | Verify outlets from different beats cannot be mixed | Error: "All outlets must belong to the same beat." |

#### TC-BM-010: Territory-Filtered Account Search

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select a beat assigned to Territory "Mumbai" | Beat selected |
| 2 | Open Add Outlets modal | Accounts filtered by Mumbai territory |
| 3 | Use search within the filtered list | Combined territory + search filter works |
| 4 | Navigate pagination (if > 10 results) | Page 1, 2, etc. show correctly. Total count displayed |

### 2.4 Test Cases: Advanced Beat Operations

#### TC-BM-011: Clone a Beat

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select an existing beat with outlets | Beat details visible |
| 2 | Click "Clone Beat" | Clone modal opens |
| 3 | Leave defaults (Name appends " (Copy)", Code appends "-COPY") | Fields pre-filled |
| 4 | Optionally assign to a different user | User picker available |
| 5 | Save | New beat created with all outlet mappings cloned. Both beats have same outlets |
| 6 | Verify cloned beat has unique Id and Beat_Code__c | New record with "-COPY" suffix |

#### TC-BM-012: Reassign a Beat

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select a beat currently assigned to User A | Beat details show User A |
| 2 | Click "Reassign" | Reassign modal opens |
| 3 | Select User B | User picker works |
| 4 | Confirm | Beat.Assigned_User__c updated to User B. OwnerId updated. Toast shows number of affected Journey Plan Days |

#### TC-BM-013: Executive Picker

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Beat Manager as a Manager user | Executive picker dropdown visible |
| 2 | Select a Sales Rep from picker | Beats filtered to show only that rep's assigned beats |
| 3 | Switch to a different rep | Beat list refreshes for the new rep |
| 4 | As Admin user, open Beat Manager | All active beats visible (fallback behavior) |

### 2.5 Deprecated Field Sync Verification

#### TC-BM-014: Deprecated Field Synchronization

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create/update a beat with Day_of_Week__c = "Monday;Friday" | Beat_Day__c auto-set to "Monday;Friday" |
| 2 | Set Frequency__c = "Daily" | Beat_Frequency__c auto-set to "Daily" |

---

## 3. Module 2: Journey Planner

### 3.1 Overview

**Objects:** `Journey_Plan__c`, `Journey_Plan_Day__c`
**Apex Classes:** `BeatPlanController`, `BPM_JourneyPlan_Service`, `BPM_JourneyPlan_TriggerHandler`, `BPM_JourneyPlanDay_TriggerHandler`
**LWC Component:** `beatPlanCalendar`
**Feature Toggle:** BPM-002
**Status Flow:** Draft → Submitted → Approved → Active (or Rejected → Draft, any → Cancelled)

### 3.2 Test Cases: Journey Plan Generation

#### TC-JP-001: Generate Default Plan for Month

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Beat Plan Calendar LWC | Calendar view loads |
| 2 | Select a user, territory, month (e.g., March 2026), year | Dropdowns populated |
| 3 | Click "Generate Plan" | Modal opens with exclusion options |
| 4 | Enable: Exclude Holidays = Yes, Exclude Leaves = Yes, Exclude Week Offs = Yes | Checkboxes toggled |
| 5 | Confirm generation | Journey_Plan__c created with Status = "Draft". Plan Days generated for each working day matching beat day-of-week assignments |
| 6 | Verify calendar | Days show beat assignments with color coding. Holidays, leaves, and week-offs are blank |

#### TC-JP-002: Verify Plan Day Generation Logic

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | User has beats: Beat A (Monday, Weekly), Beat B (Tuesday;Thursday, Daily) | Beats configured |
| 2 | Generate plan for March 2026 | Journey Plan Days created |
| 3 | Verify: Every Monday has Beat A | Correct |
| 4 | Verify: Every Tuesday and Thursday has Beat B | Correct |
| 5 | Verify: Sundays (week off) have no plan days | Correct |
| 6 | Verify: Holiday dates have no plan days | Correct |
| 7 | Verify: Approved/Pending leave dates have no plan days | Correct |
| 8 | Verify each plan day has: Plan_Date__c, Day_of_Week__c, Week_Number__c, Beat__c, Planned_Outlets__c (= active outlet count) | All fields populated |

#### TC-JP-003: Frequency-Based Filtering

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create beat with Frequency = "Bi-Weekly" assigned to Monday | Beat saved |
| 2 | Generate plan for a full month | Plan Days created only for Mondays in days 1-14 (first two weeks) |
| 3 | Create beat with Frequency = "Monthly" | Plan Days created only for first week (days 1-7) |
| 4 | Create beat with Frequency = "Daily" or "Weekly" | Plan Days created for all applicable dates |

#### TC-JP-004: Prevent Duplicate Plan Generation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Generate a plan for User A, Territory X, March 2026 | Plan created |
| 2 | Attempt to generate another plan for same user/territory/month/year | Error: "A journey plan already exists for this user, territory, month, and year." |
| 3 | Cancel the existing plan, then regenerate | New plan created successfully |

#### TC-JP-005: Generate Plan for Custom Date Range

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Use "Generate Plan for Date Range" option | Date range picker visible |
| 2 | Set From Date = 2026-03-15, To Date = 2026-04-15 | Cross-month range accepted |
| 3 | Configure exclusion options | Checkboxes work |
| 4 | Generate | Single Journey_Plan__c with Effective_From__c = Mar 15, Effective_To__c = Apr 15. Plan Days span both months |
| 5 | Plan Name | Format: "March 2026 to April 2026 - {UserName} - {TerritoryName}" |

#### TC-JP-006: Overlapping Date Range Prevention

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Plan exists: Mar 15 to Apr 15 | Existing plan |
| 2 | Try generating: Apr 1 to Apr 30 (overlaps) | Error: "An overlapping journey plan already exists: {PlanName} (2026-03-15 to 2026-04-15)." |

### 3.3 Test Cases: Plan Day Management

#### TC-JP-007: Add Beat to Calendar Day

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open an existing Draft plan in calendar | Calendar with plan days visible |
| 2 | Click on an empty day cell | Day selection UI appears |
| 3 | Select a beat from available beats | Beat added to that day |
| 4 | Verify Journey_Plan_Day__c created | Plan_Date__c, Day_of_Week__c, Week_Number__c, Beat__c, Planned_Outlets__c all populated |
| 5 | Verify Sequence_Order__c | Auto-incremented from existing max |

#### TC-JP-008: Remove Plan Day

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click remove on an existing plan day | Plan day deleted |
| 2 | Verify Total_Planned_Days__c on parent plan | Decremented (trigger rollup) |
| 3 | Verify Total_Planned_Visits__c | Updated (sum of Planned_Outlets__c recalculated) |

#### TC-JP-009: Cannot Modify Submitted/Approved Plans

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Submit a plan for approval | Status = "Submitted" |
| 2 | Try to add a beat to a calendar day | Error: "Cannot modify a plan that is submitted or approved." |
| 3 | Try to remove a plan day | Error: "Cannot modify a plan that is submitted or approved." |
| 4 | Try to save journey plan days | Error: "Cannot modify days for a journey plan that is already submitted or approved." |

#### TC-JP-010: Remove Beat from Plan

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Draft plan has Beat A assigned to 5 days | Multiple plan days with Beat A |
| 2 | Call "Remove Beat from Plan" for Beat A | All 5 plan days with Beat A deleted |
| 3 | Plan days for other beats remain intact | Correct |

### 3.4 Test Cases: Regenerate Plan

#### TC-JP-011: Regenerate Plan

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open a Draft plan with existing plan days | Plan visible |
| 2 | Click "Regenerate" | Regenerate modal with exclusion options |
| 3 | Set new end date and exclusion preferences | Options configured |
| 4 | Confirm | All future plan days (from today) deleted and recreated. Past plan days preserved. Exclusion preferences saved on plan record |
| 5 | Verify only Draft or Rejected plans can be regenerated | Submitted/Approved/Active plans show error: "Only Draft or Rejected plans can be regenerated." |

### 3.5 Test Cases: Status Flow & Approval

#### TC-JP-012: Valid Status Transitions

| Transition | Expected |
|------------|----------|
| Draft → Submitted | Allowed |
| Draft → Cancelled | Allowed |
| Submitted → Approved | Allowed |
| Submitted → Rejected | Allowed |
| Submitted → Cancelled | Allowed |
| Approved → Active | Allowed |
| Approved → Cancelled | Allowed |
| Rejected → Draft | Allowed |
| Active → Cancelled | Allowed |
| Cancelled → (anything) | Blocked |

#### TC-JP-013: Invalid Status Transitions

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Try Draft → Approved directly | Error: "Invalid status transition from 'Draft' to 'Approved'. Allowed transitions: Submitted, Cancelled." |
| 2 | Try Draft → Active | Error with allowed transitions listed |
| 3 | Try Cancelled → Draft | Error (no transitions from Cancelled) |

#### TC-JP-014: Submit Plan for Approval

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open a Draft plan | Submit button enabled |
| 2 | Click "Submit for Approval" | Status changes to "Submitted". Salesforce Approval Process triggered |
| 3 | Try submitting again | Error: "This journey plan has already been submitted for approval." |
| 4 | Try submitting an Approved plan | Error: "This journey plan has already been approved." |

#### TC-JP-015: Approval Handling

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Approve a Submitted plan | Status = "Approved". Approval_Date__c = today. Approved_By__c = current user |
| 2 | Reject a Submitted plan | Status = "Rejected". Plan goes back to Draft eligibility |

### 3.6 Test Cases: Journey Plan Calendar UI

#### TC-JP-016: Calendar View

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Beat Plan Calendar | Month calendar grid displayed |
| 2 | Beats shown with color coding | Up to 15 different colors assigned to beats |
| 3 | Switch month/year | Calendar refreshes with correct data |
| 4 | Summary stats visible | Total Planned Visits, Beat Coverage %, Assigned Beats count, Outlet count |

#### TC-JP-017: Plan Compliance

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create plan with 10 plan days | Total_Planned_Days__c = 10 |
| 2 | Create 7 completed Visit__c records matching planned beats within the plan date range | Visits created |
| 3 | Check compliance | Compliance = 70% (7/10 * 100) |
| 4 | Verify compliance capped at 100% | If actual > planned, displays 100% |

### 3.7 Validation Rules

#### TC-JP-018: Journey Plan Validation Rules

| Rule | Test | Expected Result |
|------|------|-----------------|
| Effective_To_After_From | Set Effective_To__c < Effective_From__c | Error |
| No_Edit_After_Approval | Edit fields on Approved plan | Error |
| Salesperson_Required | Create plan without Salesperson__c | Error |
| Beat_Required (Plan Day) | Create plan day without Beat__c | Error |
| Planned_Outlets_Non_Negative | Set Planned_Outlets__c = -1 | Error |

### 3.8 Test Cases: Effective Date Calculation

#### TC-JP-019: Auto Effective Dates

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create plan with Month__c = "March", Year__c = "2026", no Effective_From/To | Trigger auto-calculates: Effective_From__c = 2026-03-01, Effective_To__c = 2026-03-31 |
| 2 | Create plan with explicit Effective_From/To dates | Dates preserved as-is |

---

## 4. Module 3: Holiday Management

### 4.1 Overview

**Object:** `Holiday__c`
**Apex Class:** `HolidayController`
**LWC Component:** `holidayManager`
**Fields:** Name, Holiday_Date__c, Type__c (National Holiday, Company Holiday, Regional Holiday, etc.), Description__c, Is_Active__c, Year__c, Territory__c

### 4.2 Test Cases: Holiday CRUD

#### TC-HM-001: Create a Holiday

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Holiday Manager LWC | Component loads with year selector |
| 2 | Click "New Holiday" | Holiday form opens |
| 3 | Fill: Name = "Republic Day", Date = 2026-01-26, Type = "National Holiday", Description = "National Holiday" | Fields accept input |
| 4 | Save | Holiday saved. Year__c auto-populated as 2026 from Holiday_Date__c |
| 5 | Verify in list | Holiday appears in 2026 list, ordered by date |

#### TC-HM-002: Year Auto-Population

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create holiday with date 2026-08-15 | Year__c = 2026 (auto-set) |
| 2 | Edit holiday, change date to 2027-01-01 | Year__c auto-updated to 2027 |

#### TC-HM-003: Holiday Date Required Validation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Try to save holiday without Holiday_Date__c | Error: "Holiday Date is required." |

#### TC-HM-004: Edit a Holiday

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select an existing holiday | Details visible |
| 2 | Change Type from "National Holiday" to "Company Holiday" | Field updates |
| 3 | Save | Updated successfully |

#### TC-HM-005: Delete a Holiday

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select a holiday | Holiday selected |
| 2 | Click Delete | Confirmation prompt |
| 3 | Confirm | Holiday deleted from list |

#### TC-HM-006: Delete with Null Id

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call deleteHoliday(null) via Apex | Error: "Holiday Id is required." |

### 4.3 Test Cases: Holiday Querying

#### TC-HM-007: Get Holidays by Year

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select Year = 2026 | All active holidays for 2026 displayed, ordered by date |
| 2 | Select Year = 2025 | Different set of holidays (or empty) |
| 3 | Try without year | Error: "Year is required." |

#### TC-HM-008: Filter by Type

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select Year = 2026, Type = "National Holiday" | Only national holidays shown |
| 2 | Select Type = "Company Holiday" | Only company holidays shown |
| 3 | Leave Type blank | All types shown |

#### TC-HM-009: Filter by Territory

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select Territory = "Mumbai" | Only holidays tagged to Mumbai territory |
| 2 | Leave Territory blank | All holidays regardless of territory |

#### TC-HM-010: Get All Holidays for Year (Admin View)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call getAllHolidaysForYear(2026, null) | Returns ALL holidays including inactive ones |
| 2 | Verify inactive holidays visible | Inactive holidays shown (admin management) |

#### TC-HM-011: Get Upcoming Holidays

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call getUpcomingHolidays(5) | Returns next 5 holidays from today |
| 2 | Call getUpcomingHolidays(null) | Defaults to 10 records |
| 3 | Verify ordering | Ascending by Holiday_Date__c |
| 4 | Only active holidays returned | Is_Active__c = true filter applied |

#### TC-HM-012: Get Holidays Between Dates

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call getHolidaysBetweenDates('2026-03-01', '2026-03-31') | Holidays in March 2026 |
| 2 | Call with startDate > endDate | Error: "Start date must be on or before end date." |
| 3 | Call with null dates | Error: "Both start date and end date are required." |

### 4.4 Test Cases: Bulk Operations

#### TC-HM-013: Bulk Create Holidays

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Prepare list of 5 Holiday records | Records ready |
| 2 | Call bulkCreateHolidays() | All 5 inserted. Year__c auto-set on each |
| 3 | One record has null Holiday_Date__c | Error: "Holiday Date is required for all records. Missing on: {name}" |
| 4 | Empty list | Error: "No holiday records provided." |

### 4.5 Test Cases: Picklist & Dropdown Support

#### TC-HM-014: Holiday Type Picklist

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call getHolidayTypeOptions() | Returns list of maps with 'label' and 'value' keys |
| 2 | Verify only active picklist values | Inactive values excluded |

#### TC-HM-015: Territory Dropdown

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call getTerritoryOptions() | Returns active Territory_Master__c records (Id, Name) |
| 2 | Verify ordering | Alphabetical by Name |

---

## 5. Module 4: Employee Management

### 5.1 Overview

**Object:** `Employee__c`
**Apex Classes:** `EmployeeController`, `EmployeeThreeSixtyController`
**LWC Components:** `employeeManager`, `employeeThreeSixty`
**Key Fields:** Employee_Code__c (unique external ID), First_Name__c, Last_Name__c, Email__c, Department__c, Designation__c, Territory__c, Reporting_Manager__c (self-lookup), User__c, Week_Off_Days__c, CL/SL/EL/CO_Balance__c

### 5.2 Test Cases: Employee CRUD

#### TC-EM-001: Create a New Employee

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Employee Manager LWC | Component loads with employee list |
| 2 | Click "New Employee" | Form modal opens |
| 3 | Fill required fields: First Name, Last Name, Employee Code, Email | Fields accept input |
| 4 | Set Department = "Sales", Designation = "Sales Representative" | Picklist values populated from schema |
| 5 | Select Territory, Reporting Manager, linked User | Lookup fields work |
| 6 | Configure Week Off Days = "Sunday" | Multi-select/text field works |
| 7 | Save | Employee created. Auto-number name generated (EMP-XXXX). Is_Active__c = true |

#### TC-EM-002: Employee Code Uniqueness

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create employee with Employee_Code__c = "EMP-SR-001" (already exists) | Error: Duplicate value on Employee_Code__c (External ID) |
| 2 | Use unique code "EMP-SR-099" | Employee saves successfully |

#### TC-EM-003: Edit an Employee

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select employee from list | Details load in right panel |
| 2 | Click "Edit" | Edit form with pre-populated values |
| 3 | Change Department from "Sales" to "Marketing" | Field updates |
| 4 | Change Reporting Manager | Lookup works |
| 5 | Save | Employee updated. List refreshed |

#### TC-EM-004: Deactivate an Employee

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select an active employee | Deactivate button enabled |
| 2 | Click "Deactivate" | Employee.Is_Active__c set to false |
| 3 | Try deactivating already inactive employee | Error: "This employee is already inactive." |
| 4 | Toggle "Active Only" filter off | Inactive employee now visible in list |

### 5.3 Test Cases: Search & Filter

#### TC-EM-005: Text Search

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Type "Rajesh" in search box | Employees with "Rajesh" in First/Last Name shown |
| 2 | Search by Employee Code "EMP-SR" | Matching codes shown |
| 3 | Search by Email "rajesh@" | Matching emails shown |
| 4 | Search with < 2 chars | No filtering applied (min 2 chars for account search) |

#### TC-EM-006: Department & Designation Filters

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select Department = "Sales" | Only Sales employees shown |
| 2 | Add Designation = "Area Sales Manager" | Further filtered to Sales ASMs |
| 3 | Clear both filters | All employees shown |

#### TC-EM-007: Active Only Toggle

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Default: Active Only = true | Only active employees in list |
| 2 | Toggle to false | Both active and inactive employees shown |
| 3 | Inactive employees visually distinguishable | Status badge/indicator shows "Inactive" |

### 5.4 Test Cases: Employee Lookups

#### TC-EM-008: Get Employee by User Id

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call getEmployeeByUserId(validUserId) | Returns matching Employee__c record |
| 2 | Call with User not linked to any employee | Returns null |
| 3 | Call with User linked to inactive employee | Returns null (filter: Is_Active__c = true) |

#### TC-EM-009: Get Direct Reports

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call getDirectReports(managerId) | Returns all active employees where Reporting_Manager__c = managerId |
| 2 | For manager with no reports | Returns empty list |
| 3 | Verify only active reports returned | Inactive employees excluded |
| 4 | Verify ordering | Alphabetical by First_Name__c |

### 5.5 Test Cases: Picklist Options

#### TC-EM-010: Department & Designation Picklists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call getDepartmentOptions() | Returns: Sales, Marketing, Operations, Finance, HR, IT, Supply Chain |
| 2 | Call getDesignationOptions() | Returns: Sales Representative, Senior Sales Representative, ASM, RSM, ZSM, NSM, Territory Manager, Key Account Manager |
| 3 | Verify only active picklist values | Inactive excluded |

### 5.6 Test Cases: Employee 360 View

#### TC-EM-011: Employee Details

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Employee 360 view for an employee | Full profile visible |
| 2 | Verify all fields: name, code, department, designation, territory, manager, zone, region, email, phone, DOJ | All displayed correctly |
| 3 | Verify leave balances: CL, SL, EL, CO | Balances shown from Employee record |

#### TC-EM-012: Employee KPIs

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View KPIs for an employee with attendance data | KPI cards visible |
| 2 | Verify MTD Attendance Count | Count of Day_Attendance__c records this month with Status IN ('Started', 'Completed') |
| 3 | Verify Attendance % | = Attendance Count / Working Days (Mon-Fri) * 100 |
| 4 | Verify MTD Order Count & Value | Aggregated from Day_Attendance__c |
| 5 | Verify MTD Collection Total | Aggregated from Day_Attendance__c |
| 6 | Verify MTD Visit Count & Productive Calls | Aggregated from Day_Attendance__c |
| 7 | Verify Total Beats Assigned | Count of Beat__c where Assigned_User__c = employee's user |
| 8 | Verify Total Outlets Covered | Sum of Beat__c.Total_Outlets__c for assigned beats |
| 9 | Verify Average Hours Worked | AVG(Day_Attendance__c.Hours_Worked__c) for MTD |

#### TC-EM-013: Attendance History

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select month & year in 360 view | Attendance calendar loads |
| 2 | Verify Day_Attendance__c records shown | Records for selected month displayed with: Date, Status, Start/End Time, Hours, Visits, Orders, Collections |
| 3 | Switch months | Data refreshes correctly |

#### TC-EM-014: Leave History

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View leave history for 2026 | Leave_Request__c records for 2026 shown |
| 2 | Verify columns: Type, Start/End Date, Days, Status, Reason, Approver | All fields displayed |
| 3 | Ordering | Most recent first (Start_Date__c DESC) |

#### TC-EM-015: Assigned Beats

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View assigned beats in 360 view | Active Beat__c records shown for employee |
| 2 | Verify fields: Name, Code, Day of Week, Frequency, Outlets, Territory | All displayed |
| 3 | Only active beats shown | Is_Active__c = true filter applied |

#### TC-EM-016: Performance Trend

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View performance trend (default 6 months) | Monthly data points visible |
| 2 | Verify: Month label, Order Count, Order Value, Collection, Visits, Productive Calls | All metrics aggregated per month |
| 3 | Max 24 months lookback | Setting months > 24 caps at 24 |

#### TC-EM-017: Direct Reports (Manager View)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View direct reports for a manager employee | Team list with KPI summaries |
| 2 | Verify per-report data: Name, Code, Designation, Territory, MTD Attendance, Orders, Collections, Visits | All shown |
| 3 | Only active reports shown | Inactive employees excluded |

---

## 6. Module 5: Leave Management

### 6.1 Overview

**Object:** `Leave_Request__c`
**Apex Class:** `LeaveRequestController`
**LWC Components:** `leaveManager`, `leaveApproval`
**Leave Types:** Casual Leave (CL=12), Sick Leave (SL=7), Earned Leave (EL=15), Compensatory Off (CO=0)
**Status Flow:** Submitted → Approved/Rejected, Approved → Cancelled (with balance restore), Submitted → Cancelled

### 6.2 Test Cases: Leave Application

#### TC-LM-001: Apply for Casual Leave (Full Day)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Leave Manager LWC | Component loads. Balance cards visible |
| 2 | Click "Apply for Leave" | Leave form opens |
| 3 | Select Leave Type = "Casual Leave" | Type selected |
| 4 | Set Start Date = 2026-03-10, End Date = 2026-03-12 | Dates selected (Tue-Thu) |
| 5 | Start Session = "Session 1", End Session = "Session 2" (full days) | Default sessions |
| 6 | Enter Reason = "Personal work" | Text entered |
| 7 | Submit | Leave_Request__c created. Number_of_Days__c = 3 (3 business days). Status = "Submitted". Approved_By__c = Reporting Manager's User Id |

#### TC-LM-002: Apply for Half-Day Leave

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Set Start Date = End Date = 2026-03-10 | Same day |
| 2 | Start Session = "Session 1", End Session = "Session 1" | Half day (morning only) |
| 3 | Submit | Number_of_Days__c = 0.5 |
| 4 | Same day: Start Session = "Session 2", End Session = "Session 2" | Number_of_Days__c = 0.5 |
| 5 | Same day: Start Session = "Session 1", End Session = "Session 2" | Number_of_Days__c = 1 (full day) |

#### TC-LM-003: Session Validation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Same date: Start Session = "Session 2", End Session = "Session 1" | Error: "Invalid session selection. To Session cannot be Session 1 when From Session is Session 2 on the same date." |

#### TC-LM-004: Date Validation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Set End Date before Start Date | Error: "End Date cannot be before Start Date." |
| 2 | Set Start Date = null | Error: "Start Date and End Date are required." |
| 3 | Select weekend-only range (Sat-Sun) | Error: "The selected date range does not contain any business days." |

#### TC-LM-005: Business Day Calculation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Apply: Mon Mar 9 to Fri Mar 13, 2026 | Number_of_Days__c = 5 (all business days) |
| 2 | Apply: Fri Mar 6 to Mon Mar 9, 2026 | Number_of_Days__c = 2 (Fri + Mon, skip Sat/Sun) |
| 3 | Apply: Mon Mar 9 to Fri Mar 13 with Session 2 start | Number_of_Days__c = 4.5 |
| 4 | Apply: Mon Mar 9 to Fri Mar 13 with Session 1 end | Number_of_Days__c = 4.5 |
| 5 | Apply: Mon Mar 9 to Fri Mar 13 with Session 2 start AND Session 1 end | Number_of_Days__c = 4.0 |

#### TC-LM-006: Leave Balance Validation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Employee has CL_Balance__c = 2 | Current balance |
| 2 | Apply for 3 days Casual Leave | Error: "Insufficient Casual Leave balance. Available: 2 days, Requested: 3 days." |
| 3 | Apply for 2 days Casual Leave | Leave submitted successfully |

#### TC-LM-007: Auto-Population of Approver

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Employee has Reporting_Manager__c with a linked User | Manager exists |
| 2 | Submit leave | Approved_By__c auto-set to reporting manager's User__c |
| 3 | Employee has no reporting manager | Approved_By__c = null (leave still created) |

### 6.3 Test Cases: Leave Approval

#### TC-LM-008: Approve a Leave Request

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login as Manager | Leave Approval component visible |
| 2 | View Pending Approvals tab | Submitted leaves from direct reports shown |
| 3 | Select a leave request | Details expanded: Employee Name, Type, Dates, Sessions, Days, Reason |
| 4 | Click "Approve" | Optionally add comments |
| 5 | Confirm | Status = "Approved". Approved_By__c = current manager. Approval_Date__c = now. Employee's leave balance deducted |
| 6 | Verify balance: CL was 12, 3 days approved | CL_Balance__c = 9 |

#### TC-LM-009: Reject a Leave Request

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select a pending leave request | Details visible |
| 2 | Click "Reject" | Comments field (mandatory for rejection context) |
| 3 | Enter comments and confirm | Status = "Rejected". Approved_By__c = current user. Approval_Date__c = now. Comments saved |
| 4 | Verify: NO balance deduction | Employee balance unchanged |

#### TC-LM-010: Approval Status Validations

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Try approving already approved leave | Error: "This leave request has already been approved." |
| 2 | Try approving cancelled leave | Error: "Cannot approve a cancelled leave request." |
| 3 | Try rejecting already rejected leave | Error: "This leave request has already been rejected." |
| 4 | Try rejecting cancelled leave | Error: "Cannot reject a cancelled leave request." |

### 6.4 Test Cases: Leave Cancellation

#### TC-LM-011: Cancel a Submitted Leave

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Employee has a "Submitted" leave request | Leave exists |
| 2 | Click "Cancel" on the leave | Status = "Cancelled" |
| 3 | Verify: NO balance change | Balance unchanged (was never deducted) |

#### TC-LM-012: Cancel an Approved Leave (Balance Restoration)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Employee has an "Approved" leave (3 CL days). CL_Balance = 9 | Post-approval state |
| 2 | Cancel the approved leave | Status = "Cancelled" |
| 3 | Verify CL_Balance__c = 12 | Balance restored (9 + 3 = 12) |

#### TC-LM-013: Cancel Already Cancelled Leave

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Try cancelling already cancelled leave | Error: "This leave request has already been cancelled." |

### 6.5 Test Cases: Leave Balance & Summary

#### TC-LM-014: Get Leave Balance

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call getLeaveBalance(userId) | Returns: {CL: 12, SL: 7, EL: 15, CO: 0} (or current values) |
| 2 | User not linked to any Employee | Returns default: {CL: 12, SL: 7, EL: 15, CO: 0} |
| 3 | Employee has null balance fields | Returns defaults per type |

#### TC-LM-015: Leave Summary

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call getLeavesSummary(userId, 2026) | Returns aggregated counts by type and status |
| 2 | Example: 3 CL Approved, 1 SL Rejected | Map: {"Casual Leave_Approved": 3, "Sick Leave_Rejected": 1} |

#### TC-LM-016: Upcoming Leaves

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call getUpcomingLeaves(userId, 5) | Returns next 5 leaves with Start_Date >= today and Status IN ('Approved', 'Pending', 'Submitted') |
| 2 | Ordering | Ascending by Start_Date__c |
| 3 | Null/zero limitCount | Defaults to 10 |

### 6.6 Test Cases: Manager & Team Views

#### TC-LM-017: Manager Detection

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call checkIsManager(userId) for a user with direct reports | Returns true |
| 2 | Call for a user with no direct reports (and not admin) | Returns false |
| 3 | Call for System Administrator (no direct reports) | Returns true (admin override) |

#### TC-LM-018: Pending Approvals for Manager

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login as Manager | Pending tab shows leaves where Approved_By__c = current user |
| 2 | Login as Admin | Pending tab shows ALL pending/submitted leaves org-wide |

#### TC-LM-019: Approval History

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Manager views approval history | Shows approved/rejected leaves by this manager (last 50) |
| 2 | Admin views approval history | Shows ALL approved/rejected leaves org-wide (last 50) |

#### TC-LM-020: Team Leave Requests

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Manager views team leave requests | Shows all leave requests from direct reports |
| 2 | Filter by status | Filtered results |
| 3 | Manager has no Employee record | Returns empty list |
| 4 | Manager has no direct reports | Returns empty list |

#### TC-LM-021: Team Leaves on Date

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call getTeamLeavesOnDate('2026-03-15', managerId) | Returns approved leaves for team members where Start_Date <= Mar 15 AND End_Date >= Mar 15 |
| 2 | Ordering | Alphabetical by Employee Name |

### 6.7 Test Cases: Leave Types

#### TC-LM-022: All Leave Types

| Leave Type | Balance Field | Default | Test |
|-----------|---------------|---------|------|
| Casual Leave | CL_Balance__c | 12 | Apply, approve, verify deduction from CL |
| Sick Leave | SL_Balance__c | 7 | Apply, approve, verify deduction from SL |
| Earned Leave | EL_Balance__c | 15 | Apply, approve, verify deduction from EL |
| Compensatory Off | CO_Balance__c | 0 | Apply fails with 0 balance unless CO is manually added |

---

## 7. Cross-Module Integration Tests

### 7.1 Journey Plan + Holiday Integration

#### TC-INT-001: Holidays Excluded from Journey Plan

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create Holiday: 2026-03-17 (Holi) as National Holiday | Holiday created |
| 2 | Generate Journey Plan for March 2026 with Exclude Holidays = Yes | Plan generated |
| 3 | Verify March 17 has no plan days | Holiday date skipped |
| 4 | Regenerate with Exclude Holidays = No | March 17 now has plan days |

#### TC-INT-002: Territory-Specific Holidays

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create holiday for Territory "Mumbai" only | Territory-specific holiday |
| 2 | Generate plan for Mumbai territory | Holiday excluded |
| 3 | Generate plan for Delhi territory | Same date NOT excluded (different territory) |

### 7.2 Journey Plan + Leave Integration

#### TC-INT-003: Leaves Excluded from Journey Plan

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create approved leave for Sales Rep: March 20-22 | Leave approved |
| 2 | Generate Journey Plan for March 2026 with Exclude Leaves = Yes | Plan generated |
| 3 | Verify March 20, 21, 22 have no plan days | Leave dates skipped |
| 4 | Pending leaves also excluded | Both Approved and Pending statuses checked |

#### TC-INT-004: Leave Cancellation & Plan Regeneration

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Employee has approved leave Mar 20-22, excluded from plan | Leave in system |
| 2 | Cancel the leave | Balance restored |
| 3 | Regenerate the plan | Mar 20-22 now have plan days (leave no longer exists) |

### 7.3 Journey Plan + Employee Week-Off Integration

#### TC-INT-005: Week-Off Days Excluded

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Employee has Week_Off_Days__c = "Sunday" | Configured |
| 2 | Generate plan with Exclude Week Offs = Yes | All Sundays skipped |
| 3 | Change Week_Off_Days__c = "Sunday;Saturday" and regenerate | Saturdays also skipped |
| 4 | Generate with Exclude Week Offs = No | Week-off days included in plan |

### 7.4 Beat + Journey Plan Integration

#### TC-INT-006: Beat Assignment Drives Plan Days

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Assign Beat A (Monday) and Beat B (Wednesday) to Sales Rep | Beats assigned |
| 2 | Generate Journey Plan | Mondays have Beat A, Wednesdays have Beat B |
| 3 | Planned_Outlets__c on each plan day = active outlet count of the beat | Outlet count matches |

#### TC-INT-007: Beat Deactivation Protection with Plans

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Beat X is assigned in a future Journey Plan Day | Future plan exists |
| 2 | Try deactivating Beat X | Error: Cannot deactivate with future plan assignments |
| 3 | Remove Beat X from all future plan days, then deactivate | Success |

#### TC-INT-008: Beat Reassignment Impact

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Reassign Beat from User A to User B | Beat reassigned |
| 2 | Verify affectedPlanDays count returned | Shows count of Draft/Active plan days referencing this beat |

### 7.5 Employee + Leave Balance Integration

#### TC-INT-009: Leave Balance Lifecycle

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Employee CL_Balance = 12 | Initial state |
| 2 | Submit 3-day CL leave | Balance still 12 (not deducted on submission) |
| 3 | Manager approves | Balance = 9 (deducted on approval) |
| 4 | Employee cancels approved leave | Balance = 12 (restored on cancellation) |
| 5 | Submit and reject | Balance = 12 (no deduction on rejection) |

### 7.6 Employee + Beat + 360 View Integration

#### TC-INT-010: Employee 360 Shows Correct Beat Data

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Assign 3 beats to an employee | Beats assigned |
| 2 | View Employee 360 KPIs | totalBeatsAssigned = 3, totalOutletsCovered = sum of all outlet counts |
| 3 | View Assigned Beats tab | All 3 beats listed with details |
| 4 | Deactivate one beat | 360 shows totalBeatsAssigned = 2 |

---

## 8. Regression & Edge Cases

### 8.1 Data Boundary Tests

| ID | Test | Expected |
|----|------|----------|
| TC-EDGE-001 | Create beat with max length Beat_Code__c (50 chars) | Saves successfully |
| TC-EDGE-002 | Generate plan for February (28/29 days) | Correct day count handling |
| TC-EDGE-003 | Generate plan where all days are holidays/leaves/week-offs | Plan created with 0 plan days |
| TC-EDGE-004 | Apply leave spanning year boundary (Dec 28 - Jan 5) | Business days calculated correctly across years |
| TC-EDGE-005 | Employee with all leave balances = 0 | All leave applications fail with balance error |
| TC-EDGE-006 | Beat with 0 outlets added to plan day | Planned_Outlets__c = 0 on plan day |
| TC-EDGE-007 | Journey Plan compliance when 0 plan days exist | Returns 0% (not divide-by-zero error) |
| TC-EDGE-008 | Search accounts with special characters (O'Brien) | No SQL injection; search works safely |

### 8.2 Concurrent & Bulk Tests

| ID | Test | Expected |
|----|------|----------|
| TC-EDGE-009 | Two users simultaneously generate plans for same user/territory/month | Only one succeeds; second gets duplicate error |
| TC-EDGE-010 | Bulk create 50 holidays at once | All 50 inserted with correct Year__c |
| TC-EDGE-011 | Beat with 200 outlets | Outlet list loads with pagination |
| TC-EDGE-012 | Manager with 50 direct reports | All leaves visible in pending queue |

### 8.3 Permission & Security Tests

| ID | Test | Expected |
|----|------|----------|
| TC-EDGE-013 | Non-manager tries to access Leave Approval component | Manager check returns false; approval actions hidden |
| TC-EDGE-014 | Admin can see all pending leaves org-wide | Admin bypasses manager filter |
| TC-EDGE-015 | User cannot modify Approved Journey Plan fields | Validation rule: No_Edit_After_Approval blocks changes |
| TC-EDGE-016 | Feature Toggle BPM-001 = OFF | Beat trigger logic skipped (no validations) |
| TC-EDGE-017 | Feature Toggle BPM-002 = OFF | Journey Plan trigger logic skipped |

### 8.4 Rollup & Aggregation Tests

| ID | Test | Expected |
|----|------|----------|
| TC-EDGE-018 | Add outlet → Beat.Total_Outlets__c increments | Trigger recalculates count |
| TC-EDGE-019 | Remove outlet → Beat.Total_Outlets__c decrements | Trigger recalculates count |
| TC-EDGE-020 | Deactivate outlet → Beat.Total_Outlets__c decrements | Only active outlets counted |
| TC-EDGE-021 | Add plan day → Journey_Plan__c.Total_Planned_Days__c increments | Trigger rollup |
| TC-EDGE-022 | Delete plan day → Journey_Plan__c.Total_Planned_Visits__c updates | SUM(Planned_Outlets__c) recalculated |

---

## Appendix A: Object Field Reference

### Beat__c Fields

| Field | API Name | Type | Required | Notes |
|-------|----------|------|----------|-------|
| Name | Name | Text | Yes | Beat Name |
| Beat Code | Beat_Code__c | Text(50) | Yes | Unique, External ID |
| Day of Week | Day_of_Week__c | Multi-Select Picklist | Yes (when active) | Mon-Sat |
| Frequency | Frequency__c | Picklist | No | Daily, Weekly, Bi-Weekly, Monthly |
| Territory | Territory__c | Lookup | Yes (when active) | Territory_Master__c |
| Assigned User | Assigned_User__c | Lookup(User) | No | Salesperson |
| Is Active | Is_Active__c | Checkbox | No | Default: true |
| Total Outlets | Total_Outlets__c | Number | No | Auto-calculated (trigger rollup) |
| Sequence | Sequence__c | Number | No | Display order |
| Pincode Cluster | Pincode_Cluster__c | Text | No | Geographic grouping |
| Description | Description__c | Text | No | Beat description |

### Journey_Plan__c Fields

| Field | API Name | Type | Required | Notes |
|-------|----------|------|----------|-------|
| Salesperson | Salesperson__c | Lookup(User) | Yes | Sales rep |
| Territory | Territory__c | Lookup | No | Territory_Master__c |
| Month | Month__c | Picklist | No | January-December |
| Year | Year__c | Text | No | e.g., "2026" |
| Status | Status__c | Picklist | No | Draft, Submitted, Approved, Rejected, Active, Cancelled |
| Effective From | Effective_From__c | Date | No | Auto-calculated from Month/Year |
| Effective To | Effective_To__c | Date | No | Auto-calculated |
| Total Planned Days | Total_Planned_Days__c | Number | No | Rollup count |
| Total Planned Visits | Total_Planned_Visits__c | Number | No | Rollup sum |
| Exclude Holidays | Exclude_Holidays__c | Checkbox | No | Plan generation preference |
| Exclude Leaves | Exclude_Leaves__c | Checkbox | No | Plan generation preference |
| Exclude Week Offs | Exclude_Week_Offs__c | Checkbox | No | Plan generation preference |
| Approval Date | Approval_Date__c | Date | No | Set on approval |
| Approved By | Approved_By__c | Lookup(User) | No | Set on approval |

### Holiday__c Fields

| Field | API Name | Type | Required | Notes |
|-------|----------|------|----------|-------|
| Name | Name | Text | Yes | Holiday name |
| Holiday Date | Holiday_Date__c | Date | Yes | The date |
| Type | Type__c | Picklist | No | National Holiday, Company Holiday, etc. |
| Year | Year__c | Number | No | Auto-derived from Holiday_Date__c |
| Territory | Territory__c | Lookup | No | Territory-specific holidays |
| Description | Description__c | Text | No | Details |
| Is Active | Is_Active__c | Checkbox | No | Active flag |

### Employee__c Fields

| Field | API Name | Type | Required | Notes |
|-------|----------|------|----------|-------|
| Employee Code | Employee_Code__c | Text(20) | Yes | Unique, External ID |
| First Name | First_Name__c | Text | Yes | |
| Last Name | Last_Name__c | Text | Yes | |
| Email | Email__c | Text | Yes | |
| Phone | Phone__c | Text | No | |
| Department | Department__c | Picklist | No | Sales, Marketing, etc. |
| Designation | Designation__c | Picklist | No | SR, ASM, RSM, etc. |
| Territory | Territory__c | Lookup | No | Territory_Master__c |
| Reporting Manager | Reporting_Manager__c | Lookup(Employee__c) | No | Self-referencing hierarchy |
| User | User__c | Lookup(User) | No | Linked Salesforce User |
| Is Active | Is_Active__c | Checkbox | No | Default: true |
| Week Off Days | Week_Off_Days__c | Text | No | Semicolon-separated (e.g., "Sunday") |
| CL Balance | CL_Balance__c | Number | No | Casual Leave balance |
| SL Balance | SL_Balance__c | Number | No | Sick Leave balance |
| EL Balance | EL_Balance__c | Number | No | Earned Leave balance |
| CO Balance | CO_Balance__c | Number | No | Compensatory Off balance |
| Zone | Zone__c | Text | No | |
| Region | Region__c | Text | No | |
| Date of Joining | Date_of_Joining__c | Date | No | |
| Profile Photo URL | Profile_Photo_URL__c | URL | No | |
| Address | Address__c | Text | No | |

### Leave_Request__c Fields

| Field | API Name | Type | Required | Notes |
|-------|----------|------|----------|-------|
| Employee | Employee__c | Lookup(User) | Yes | Applicant |
| Leave Type | Leave_Type__c | Picklist | Yes | CL, SL, EL, CO |
| Start Date | Start_Date__c | Date | Yes | |
| End Date | End_Date__c | Date | Yes | |
| Start Session | Start_Session__c | Picklist | No | Session 1, Session 2 |
| End Session | End_Session__c | Picklist | No | Session 1, Session 2 |
| Number of Days | Number_of_Days__c | Number | No | Auto-calculated |
| Reason | Reason__c | Text | No | Leave reason |
| Status | Status__c | Picklist | No | Pending, Submitted, Approved, Rejected, Cancelled |
| Approved By | Approved_By__c | Lookup(User) | No | Auto-set to reporting manager |
| Approval Date | Approval_Date__c | DateTime | No | Set on approve/reject |
| Comments | Comments__c | Text | No | Approval/rejection comments |

---

## Appendix B: Status Flow Diagrams

### Journey Plan Status Flow

```
                    ┌──────────┐
                    │  Draft   │
                    └────┬─────┘
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
        ┌──────────┐         ┌───────────┐
        │Submitted │         │ Cancelled │
        └────┬─────┘         └───────────┘
             │
    ┌────────┴────────┐
    ▼                 ▼
┌──────────┐   ┌──────────┐
│ Approved │   │ Rejected │──────► Draft
└────┬─────┘   └──────────┘
     │
     ▼
┌──────────┐
│  Active  │
└──────────┘
```

### Leave Request Status Flow

```
         ┌───────────┐
         │ Submitted │
         └─────┬─────┘
               │
     ┌─────────┴─────────┐
     ▼                   ▼
┌──────────┐       ┌──────────┐
│ Approved │       │ Rejected │
└────┬─────┘       └──────────┘
     │
     ▼
┌───────────┐
│ Cancelled │ (Balance Restored)
└───────────┘
```

---

## Appendix C: Test Execution Checklist

Use this checklist to track test execution:

### Beat Management
- [ ] TC-BM-001 through TC-BM-014 (14 test cases)

### Journey Planner
- [ ] TC-JP-001 through TC-JP-019 (19 test cases)

### Holiday Management
- [ ] TC-HM-001 through TC-HM-015 (15 test cases)

### Employee Management
- [ ] TC-EM-001 through TC-EM-017 (17 test cases)

### Leave Management
- [ ] TC-LM-001 through TC-LM-022 (22 test cases)

### Cross-Module Integration
- [ ] TC-INT-001 through TC-INT-010 (10 test cases)

### Edge Cases & Regression
- [ ] TC-EDGE-001 through TC-EDGE-022 (22 test cases)

**Total Test Cases: 119**

---

*End of Test Plan Document*
