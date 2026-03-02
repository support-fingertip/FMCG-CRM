# QA Test Plan - Beat & Journey Plan Module (FMCG CRM / SFA)

**Application:** Field Sales CRM
**Module:** Beat Plan & Route Management (MOD-02)
**Version:** 1.0
**API Version:** 59.0
**Date:** 2026-02-24
**Total Test Cases:** 120

---

## Table of Contents

1. [Test Data Requirements](#1-test-data-requirements)
2. [Beat Creation & Default Values (TC-BPM-001 to TC-BPM-006)](#2-beat-creation--default-values)
3. [Beat Validation Rules (TC-BPM-007 to TC-BPM-014)](#3-beat-validation-rules)
4. [Beat Code Uniqueness (TC-BPM-015 to TC-BPM-019)](#4-beat-code-uniqueness)
5. [Beat Deprecated Field Sync (TC-BPM-020 to TC-BPM-023)](#5-beat-deprecated-field-sync)
6. [Beat Deactivation Protection (TC-BPM-024 to TC-BPM-028)](#6-beat-deactivation-protection)
7. [Beat Outlet Management (TC-BPM-029 to TC-BPM-037)](#7-beat-outlet-management)
8. [Beat Outlet Count Rollup (TC-BPM-038 to TC-BPM-043)](#8-beat-outlet-count-rollup)
9. [Beat List Views (TC-BPM-044 to TC-BPM-046)](#9-beat-list-views)
10. [Journey Plan Creation & Defaults (TC-BPM-047 to TC-BPM-053)](#10-journey-plan-creation--defaults)
11. [Journey Plan Validation Rules (TC-BPM-054 to TC-BPM-059)](#11-journey-plan-validation-rules)
12. [Journey Plan Effective Date Calculation (TC-BPM-060 to TC-BPM-064)](#12-journey-plan-effective-date-calculation)
13. [Journey Plan Status Transitions (TC-BPM-065 to TC-BPM-076)](#13-journey-plan-status-transitions)
14. [Journey Plan Approval Workflow (TC-BPM-077 to TC-BPM-082)](#14-journey-plan-approval-workflow)
15. [Journey Plan Day Management (TC-BPM-083 to TC-BPM-089)](#15-journey-plan-day-management)
16. [Journey Plan Day Rollup to Parent (TC-BPM-090 to TC-BPM-094)](#16-journey-plan-day-rollup-to-parent)
17. [Auto-Generate Default Plan (TC-BPM-095 to TC-BPM-105)](#17-auto-generate-default-plan)
18. [Beat Plan Calendar - LWC Component (TC-BPM-106 to TC-BPM-115)](#18-beat-plan-calendar---lwc-component)
19. [Plan Compliance Calculation (TC-BPM-116 to TC-BPM-118)](#19-plan-compliance-calculation)
20. [Integration & Cross-Module Tests (TC-BPM-119 to TC-BPM-120)](#20-integration--cross-module-tests)
21. [Test Summary](#21-test-summary)

---

## 1. Test Data Requirements

Before executing the test cases, prepare the following test data in your Salesforce org:

| # | Data Type | Details | Quantity |
|---|-----------|---------|----------|
| 1 | **Territory Master records** | Territory-North (TER-001), Territory-South (TER-002) | 2 |
| 2 | **User records (Sales Reps)** | Rep-A (assigned to Territory-North), Rep-B (assigned to Territory-South) | 2 |
| 3 | **Beat records** | Beat-MON (Monday), Beat-TUE (Tuesday), Beat-WED (Wednesday) in Territory-North, all active, each with Day_of_Week__c and Frequency__c set | 3 |
| 4 | **Beat record (multi-day)** | Beat-MULTI with Day_of_Week__c = "Monday;Wednesday;Friday", Frequency__c = Weekly | 1 |
| 5 | **Beat record (inactive)** | Beat-INACTIVE with Is_Active__c = false in Territory-North | 1 |
| 6 | **Retailer Account records** | Outlet-01 through Outlet-20 (Retailer type) | 20 |
| 7 | **Beat Outlet records** | 4 active outlets per beat (Beat-MON, Beat-TUE, Beat-WED), 4 outlets on Beat-MULTI | 16 |
| 8 | **Journey Plan (Draft)** | For Rep-A, Territory-North, current month, Status = Draft | 1 |
| 9 | **Journey Plan (Approved)** | For Rep-A, Territory-North, previous month, Status = Approved | 1 |
| 10 | **Journey Plan Day records** | 5 plan day records under the Draft journey plan | 5 |
| 11 | **Visit records** | Mix of Completed and In-Progress visits linked to beats and plan days | 10 |
| 12 | **Day Attendance record** | For Rep-A, today's date | 1 |

### Key Object Relationships

```
Territory_Master__c
  └── Beat__c (Territory__c lookup)
        └── Beat_Outlet__c (Beat__c lookup + Account__c lookup)

Journey_Plan__c (Salesperson__c → User, Territory__c → Territory_Master__c)
  └── Journey_Plan_Day__c (Journey_Plan__c master-detail, Beat__c lookup)

Visit__c (Beat__c lookup, Journey_Plan_Day__c lookup)
```

### Field Reference - Beat__c

| Field API Name | Type | Required | Notes |
|----------------|------|----------|-------|
| Beat_Code__c | Text(50) | Yes (Unique, External ID) | Case-insensitive uniqueness |
| Day_of_Week__c | Multi-Select Picklist | Required when active | Monday through Saturday |
| Frequency__c | Picklist | No | Daily, Weekly (default), Bi-Weekly, Monthly |
| Territory__c | Lookup(Territory_Master__c) | Required when active | |
| Assigned_User__c | Lookup(User) | No | |
| Is_Active__c | Checkbox | No | Default: true |
| Sequence__c | Number | No | Display order |
| Total_Outlets__c | Number | No | Auto-calculated rollup (default: 0) |
| Beat_Day__c | Multi-Select Picklist | No | DEPRECATED - auto-synced from Day_of_Week__c |
| Beat_Frequency__c | Picklist | No | DEPRECATED - auto-synced from Frequency__c |

### Field Reference - Journey_Plan__c

| Field API Name | Type | Required | Notes |
|----------------|------|----------|-------|
| Name | Text | Auto-set | "{Month} {Year} - {User} - {Territory}" |
| Salesperson__c | Lookup(User) | Yes | |
| Territory__c | Lookup(Territory_Master__c) | No | |
| Month__c | Picklist | Yes | January through December |
| Year__c | Text(4) | Yes | e.g. "2026" |
| Status__c | Picklist | No | Draft (default), Submitted, Approved, Rejected, Active, Cancelled |
| Plan_Date__c | Date | No | Auto-set to today |
| Effective_From__c | Date | No | Auto-calculated: 1st of month |
| Effective_To__c | Date | No | Auto-calculated: last day of month |
| Total_Planned_Days__c | Number | No | Auto-rollup from child days |
| Total_Planned_Visits__c | Number | No | Auto-rollup SUM of Planned_Outlets__c |
| Approval_Date__c | Date | No | Auto-set on approval |
| Approved_By__c | Lookup(User) | No | Auto-set on approval |
| User__c | Lookup(User) | No | DEPRECATED - auto-synced from Salesperson__c |

### Field Reference - Journey_Plan_Day__c

| Field API Name | Type | Required | Notes |
|----------------|------|----------|-------|
| Journey_Plan__c | Master-Detail | Yes | Parent plan |
| Beat__c | Lookup(Beat__c) | Yes | |
| Day_of_Week__c | Picklist | Yes | Monday through Saturday |
| Week_Number__c | Picklist | Yes | Week 1, Week 2, Week 3, Week 4 |
| Plan_Date__c | Date | No | Specific calendar date |
| Planned_Outlets__c | Number | No | Default: 0 |
| Visited_Outlets__c | Number | No | Default: 0 |
| Status__c | Picklist | No | Planned (default), Completed, Cancelled |
| Beat_Name__c | Text(80) | No | Auto-populated from Beat__r.Name |
| Sequence_Order__c | Number | No | |
| Sequence__c | Number | No | |
| Notes__c | TextArea | No | |

---

## 2. Beat Creation & Default Values

### TC-BPM-001: Create Beat with All Required Fields

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-001 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Territory-North (TER-001) exists; user has Beat create permission |
| **Steps** | 1. Navigate to Beat__c tab<br>2. Click **New**<br>3. Enter Beat Code = "BEAT-TEST-001"<br>4. Enter Name = "Test Beat Monday"<br>5. Select Day_of_Week__c = **Monday**<br>6. Select Frequency__c = **Weekly**<br>7. Set Territory__c = **Territory-North**<br>8. Click **Save** |
| **Expected Result** | - Record saves successfully<br>- `Is_Active__c` = **true** (auto-defaulted by trigger)<br>- `Total_Outlets__c` = **0** (no outlets yet)<br>- `Beat_Day__c` = **Monday** (synced from Day_of_Week__c)<br>- `Beat_Frequency__c` = **Weekly** (synced from Frequency__c) |
| **Status** | |

---

### TC-BPM-002: Create Beat - Verify Is_Active__c Defaults to True

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-002 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Territory exists |
| **Steps** | 1. Create a new Beat__c record via Data Loader or API<br>2. Set Beat_Code__c = "BEAT-TEST-002", Name = "Default Active Beat"<br>3. Set Day_of_Week__c = "Tuesday", Territory__c = Territory-North<br>4. Do NOT explicitly set Is_Active__c<br>5. Save the record |
| **Expected Result** | - `Is_Active__c` = **true** (auto-set by `setDefaults` in trigger handler) |
| **Status** | |

---

### TC-BPM-003: Create Beat with Multiple Days (Multi-Select Picklist)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-003 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Territory exists |
| **Steps** | 1. Create a new Beat__c record<br>2. Set Beat_Code__c = "BEAT-MULTI-001"<br>3. Select Day_of_Week__c = **Monday; Wednesday; Friday**<br>4. Set Frequency__c = "Weekly", Territory__c = Territory-North<br>5. Save the record |
| **Expected Result** | - Record saves with `Day_of_Week__c` = "Monday;Wednesday;Friday"<br>- `Beat_Day__c` = "Monday;Wednesday;Friday" (synced)<br>- Beat can be used for plan generation on all three days |
| **Status** | |

---

### TC-BPM-004: Create Beat with Frequency = Daily

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-004 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Territory exists |
| **Steps** | 1. Create a new Beat__c record<br>2. Set Beat_Code__c = "BEAT-DAILY-001"<br>3. Select Day_of_Week__c = **Monday; Tuesday; Wednesday; Thursday; Friday; Saturday**<br>4. Set Frequency__c = **Daily**<br>5. Set Territory__c = Territory-North<br>6. Save the record |
| **Expected Result** | - Record saves successfully<br>- `Beat_Frequency__c` = **Daily** (synced)<br>- This beat will generate plan days for every weekday when plan is auto-generated |
| **Status** | |

---

### TC-BPM-005: Create Beat with Frequency = Bi-Weekly

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-005 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Territory exists |
| **Steps** | 1. Create a new Beat__c record<br>2. Set Beat_Code__c = "BEAT-BIWEEK-001"<br>3. Select Day_of_Week__c = **Thursday**<br>4. Set Frequency__c = **Bi-Weekly**<br>5. Save the record |
| **Expected Result** | - Record saves successfully<br>- When used in plan generation, this beat will only create plan days for Thursdays falling on days 1-14 of the month |
| **Status** | |

---

### TC-BPM-006: Create Beat with Frequency = Monthly

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-006 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Territory exists |
| **Steps** | 1. Create a new Beat__c record<br>2. Set Beat_Code__c = "BEAT-MONTHLY-001"<br>3. Select Day_of_Week__c = **Friday**<br>4. Set Frequency__c = **Monthly**<br>5. Save the record |
| **Expected Result** | - Record saves successfully<br>- When used in plan generation, this beat will only create a plan day for the first Friday of the month (days 1-7) |
| **Status** | |

---

## 3. Beat Validation Rules

### TC-BPM-007: Beat Code Required - Save Without Beat Code

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-007 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | User has Beat create permission |
| **Steps** | 1. Create a new Beat__c record<br>2. Leave Beat_Code__c **blank**<br>3. Fill in Name, Day_of_Week__c, Territory__c<br>4. Click **Save** |
| **Expected Result** | - Save is **blocked**<br>- Error message: **"Beat Code is required."** |
| **Status** | |

---

### TC-BPM-008: Active Beat Requires Day of Week

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-008 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | User has Beat create permission |
| **Steps** | 1. Create a new Beat__c record<br>2. Set Beat_Code__c = "BEAT-NODAY-001"<br>3. Set Is_Active__c = **true**<br>4. Leave Day_of_Week__c **blank**<br>5. Set Territory__c = Territory-North<br>6. Click **Save** |
| **Expected Result** | - Save is **blocked**<br>- Error message: **"Active beats must have at least one day of week assigned."** |
| **Status** | |

---

### TC-BPM-009: Active Beat Requires Territory

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-009 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | User has Beat create permission |
| **Steps** | 1. Create a new Beat__c record<br>2. Set Beat_Code__c = "BEAT-NOTER-001"<br>3. Set Is_Active__c = **true**<br>4. Set Day_of_Week__c = **Monday**<br>5. Leave Territory__c **blank**<br>6. Click **Save** |
| **Expected Result** | - Save is **blocked**<br>- Error message: **"Active beats must be assigned to a territory."** |
| **Status** | |

---

### TC-BPM-010: Inactive Beat - Day of Week Not Required

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-010 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | User has Beat create permission |
| **Steps** | 1. Create a new Beat__c record<br>2. Set Beat_Code__c = "BEAT-INACT-001"<br>3. Set Is_Active__c = **false**<br>4. Leave Day_of_Week__c **blank**<br>5. Leave Territory__c **blank**<br>6. Click **Save** |
| **Expected Result** | - Record saves **successfully**<br>- Validation rules for Day_of_Week__c and Territory__c only apply when Is_Active__c = true |
| **Status** | |

---

### TC-BPM-011: Update Active Beat - Remove Day of Week

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-011 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | Active Beat exists with Day_of_Week__c = Monday |
| **Steps** | 1. Open an existing active Beat record<br>2. Clear the Day_of_Week__c field (remove all selected values)<br>3. Keep Is_Active__c = **true**<br>4. Click **Save** |
| **Expected Result** | - Save is **blocked**<br>- Error message: **"Active beats must have at least one day of week assigned."** |
| **Status** | |

---

### TC-BPM-012: Update Active Beat - Remove Territory

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-012 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | Active Beat exists with Territory__c set |
| **Steps** | 1. Open an existing active Beat record<br>2. Clear the Territory__c field<br>3. Keep Is_Active__c = **true**<br>4. Click **Save** |
| **Expected Result** | - Save is **blocked**<br>- Error message: **"Active beats must be assigned to a territory."** |
| **Status** | |

---

### TC-BPM-013: Deactivate Beat - Allows Blank Day and Territory

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-013 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Active Beat exists with no future journey plan assignments |
| **Steps** | 1. Open an existing active Beat record<br>2. Set Is_Active__c = **false**<br>3. Clear Day_of_Week__c and Territory__c<br>4. Click **Save** |
| **Expected Result** | - Record saves successfully (validation rules do not apply to inactive beats) |
| **Status** | |

---

### TC-BPM-014: Beat Outlet Validation - Account Required

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-014 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | Beat record exists |
| **Steps** | 1. Create a Beat_Outlet__c record<br>2. Set Beat__c = an existing beat<br>3. Leave Account__c **blank**<br>4. Save |
| **Expected Result** | - Save is **blocked**<br>- Error message: **"Account (Outlet) is required for a Beat Outlet record."** |
| **Status** | |

---

## 4. Beat Code Uniqueness

### TC-BPM-015: Duplicate Beat Code on Create

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-015 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | Beat with Beat_Code__c = "BEAT-MON" already exists |
| **Steps** | 1. Create a new Beat__c record<br>2. Set Beat_Code__c = **"BEAT-MON"** (exact duplicate)<br>3. Fill in other required fields<br>4. Click **Save** |
| **Expected Result** | - Save is **blocked**<br>- Error on Beat_Code__c field indicating duplicate code already exists |
| **Status** | |

---

### TC-BPM-016: Duplicate Beat Code - Case Insensitive

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-016 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | Beat with Beat_Code__c = "BEAT-MON" exists |
| **Steps** | 1. Create a new Beat__c record<br>2. Set Beat_Code__c = **"beat-mon"** (lowercase version)<br>3. Fill in other required fields<br>4. Click **Save** |
| **Expected Result** | - Save is **blocked**<br>- Uniqueness check is **case-insensitive** |
| **Status** | |

---

### TC-BPM-017: Duplicate Beat Code Within Batch Insert

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-017 |
| **Priority** | Medium |
| **Type** | Negative |
| **Precondition** | Data Loader or API access available |
| **Steps** | 1. Prepare a CSV/API payload with 3 Beat records<br>2. Set all three to Beat_Code__c = **"BEAT-BATCH-DUP"**<br>3. Insert all 3 records in a single batch |
| **Expected Result** | - At least 2 of the 3 records fail with a duplicate error<br>- Trigger handler checks within-batch duplicates |
| **Status** | |

---

### TC-BPM-018: Update Beat Code to Existing Code

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-018 |
| **Priority** | Medium |
| **Type** | Negative |
| **Precondition** | Two beats exist: BEAT-AAA and BEAT-BBB |
| **Steps** | 1. Open Beat with code "BEAT-BBB"<br>2. Change Beat_Code__c to **"BEAT-AAA"**<br>3. Click **Save** |
| **Expected Result** | - Save is **blocked**<br>- Error on Beat_Code__c field indicating duplicate |
| **Status** | |

---

### TC-BPM-019: Update Beat Code - Same Record (No False Positive)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-019 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Beat with Beat_Code__c = "BEAT-AAA" exists |
| **Steps** | 1. Open the Beat with code "BEAT-AAA"<br>2. Change the Name field only (do not change Beat_Code__c)<br>3. Click **Save** |
| **Expected Result** | - Record saves successfully<br>- Updating the same record does not trigger false duplicate error (handler excludes current record IDs) |
| **Status** | |

---

## 5. Beat Deprecated Field Sync

### TC-BPM-020: Day_of_Week__c Syncs to Beat_Day__c on Insert

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-020 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | None |
| **Steps** | 1. Create a Beat__c record<br>2. Set Day_of_Week__c = **"Monday;Wednesday"**<br>3. Do NOT set Beat_Day__c<br>4. Save the record<br>5. Query the record and check Beat_Day__c |
| **Expected Result** | - `Beat_Day__c` = **"Monday;Wednesday"** (auto-synced from Day_of_Week__c) |
| **Status** | |

---

### TC-BPM-021: Frequency__c Syncs to Beat_Frequency__c on Insert

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-021 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | None |
| **Steps** | 1. Create a Beat__c record<br>2. Set Frequency__c = **"Bi-Weekly"**<br>3. Do NOT set Beat_Frequency__c<br>4. Save the record<br>5. Query the record and check Beat_Frequency__c |
| **Expected Result** | - `Beat_Frequency__c` = **"Bi-Weekly"** (auto-synced from Frequency__c) |
| **Status** | |

---

### TC-BPM-022: Day_of_Week__c Change Syncs to Beat_Day__c on Update

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-022 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Beat exists with Day_of_Week__c = "Monday" |
| **Steps** | 1. Open the Beat record<br>2. Change Day_of_Week__c to **"Tuesday;Thursday"**<br>3. Save the record<br>4. Query the record and check Beat_Day__c |
| **Expected Result** | - `Beat_Day__c` = **"Tuesday;Thursday"** (synced on update) |
| **Status** | |

---

### TC-BPM-023: Frequency__c Change Syncs to Beat_Frequency__c on Update

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-023 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Beat exists with Frequency__c = "Weekly" |
| **Steps** | 1. Open the Beat record<br>2. Change Frequency__c to **"Monthly"**<br>3. Save the record<br>4. Query the record and check Beat_Frequency__c |
| **Expected Result** | - `Beat_Frequency__c` = **"Monthly"** (synced on update) |
| **Status** | |

---

## 6. Beat Deactivation Protection

### TC-BPM-024: Deactivate Beat with Future Journey Plan Assignments

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-024 |
| **Priority** | Critical |
| **Type** | Negative |
| **Precondition** | Beat "Beat-MON" has Journey_Plan_Day__c records with Plan_Date__c >= today |
| **Steps** | 1. Open Beat "Beat-MON"<br>2. Change Is_Active__c from **true** to **false**<br>3. Click **Save** |
| **Expected Result** | - Save is **blocked**<br>- Error message: **"Cannot deactivate this beat because it has future journey plan assignments..."** |
| **Status** | |

---

### TC-BPM-025: Deactivate Beat with Only Past Journey Plan Assignments

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-025 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Beat has Journey_Plan_Day__c records with Plan_Date__c all in the past (before today) |
| **Steps** | 1. Open the Beat record<br>2. Change Is_Active__c from **true** to **false**<br>3. Click **Save** |
| **Expected Result** | - Record saves **successfully**<br>- Only future plan dates block deactivation |
| **Status** | |

---

### TC-BPM-026: Deactivate Beat with No Journey Plan Assignments

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-026 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Beat has no related Journey_Plan_Day__c records |
| **Steps** | 1. Open the Beat record<br>2. Change Is_Active__c from **true** to **false**<br>3. Click **Save** |
| **Expected Result** | - Record saves **successfully** |
| **Status** | |

---

### TC-BPM-027: Reactivate Inactive Beat

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-027 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Inactive Beat exists with Day_of_Week__c and Territory__c populated |
| **Steps** | 1. Open the inactive Beat record<br>2. Change Is_Active__c from **false** to **true**<br>3. Ensure Day_of_Week__c and Territory__c are populated<br>4. Click **Save** |
| **Expected Result** | - Record saves **successfully**<br>- Beat is now active and available for plan generation |
| **Status** | |

---

### TC-BPM-028: Reactivate Beat Without Day_of_Week__c

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-028 |
| **Priority** | Medium |
| **Type** | Negative |
| **Precondition** | Inactive Beat exists with Day_of_Week__c blank |
| **Steps** | 1. Open the inactive Beat record<br>2. Change Is_Active__c from **false** to **true**<br>3. Leave Day_of_Week__c **blank**<br>4. Click **Save** |
| **Expected Result** | - Save is **blocked**<br>- Error: **"Active beats must have at least one day of week assigned."** |
| **Status** | |

---

## 7. Beat Outlet Management

### TC-BPM-029: Add Outlet to Beat via Controller

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-029 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Beat "Beat-MON" exists; Outlet-01 account exists; no existing Beat_Outlet__c linking them |
| **Steps** | 1. Open Beat Plan Calendar component or use API<br>2. Call `addBeatOutlets` with beatId = Beat-MON and accountIds = [Outlet-01]<br>3. Verify response |
| **Expected Result** | - Beat_Outlet__c record created with:<br>&nbsp;&nbsp;- Beat__c = Beat-MON<br>&nbsp;&nbsp;- Account__c = Outlet-01<br>&nbsp;&nbsp;- Is_Active__c = true<br>&nbsp;&nbsp;- Visit_Sequence__c = auto-incremented (next available) |
| **Status** | |

---

### TC-BPM-030: Add Multiple Outlets to Beat at Once

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-030 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Beat-TUE exists with 0 outlets; Outlet-05, Outlet-06, Outlet-07 exist |
| **Steps** | 1. Call `addBeatOutlets` with beatId = Beat-TUE and accountIds = [Outlet-05, Outlet-06, Outlet-07] |
| **Expected Result** | - 3 Beat_Outlet__c records created<br>- Visit_Sequence__c = 1, 2, 3 respectively<br>- Beat-TUE.Total_Outlets__c updates to **3** (via rollup trigger) |
| **Status** | |

---

### TC-BPM-031: Add Duplicate Outlet to Beat (Already Exists)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-031 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Beat-MON already has Outlet-01 as a Beat_Outlet__c |
| **Steps** | 1. Call `addBeatOutlets` with beatId = Beat-MON and accountIds = [Outlet-01] |
| **Expected Result** | - No duplicate record created<br>- Controller filters out already-existing Account IDs<br>- Returns existing outlet list unchanged |
| **Status** | |

---

### TC-BPM-032: Remove Outlet from Beat

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-032 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Beat-MON has Beat_Outlet__c record for Outlet-01 |
| **Steps** | 1. Get the Beat_Outlet__c Id for Outlet-01 under Beat-MON<br>2. Call `removeBeatOutlet` with that Id |
| **Expected Result** | - Beat_Outlet__c record is **deleted**<br>- Beat-MON.Total_Outlets__c **decremented** by 1 (via rollup trigger) |
| **Status** | |

---

### TC-BPM-033: Get Beat Outlets - Sorted by Visit Sequence

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-033 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Beat-MON has 4 outlets with Visit_Sequence__c = 1, 2, 3, 4 |
| **Steps** | 1. Call `getBeatOutlets` with beatId = Beat-MON<br>2. Verify the returned list |
| **Expected Result** | - Returns 4 records ordered by Visit_Sequence__c ascending<br>- Each record includes: Id, Beat__c, Account__c, Account__r.Name, Is_Active__c, Visit_Sequence__c |
| **Status** | |

---

### TC-BPM-034: Deactivate Beat Outlet (Set Is_Active__c = false)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-034 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Beat-MON has 4 active outlets |
| **Steps** | 1. Open a Beat_Outlet__c record under Beat-MON<br>2. Change Is_Active__c to **false**<br>3. Save the record |
| **Expected Result** | - Record saves successfully<br>- Beat-MON.Total_Outlets__c = **3** (rollup counts only active outlets) |
| **Status** | |

---

### TC-BPM-035: Search Accounts for Beat Outlet Assignment

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-035 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Accounts "Outlet-01" through "Outlet-20" exist |
| **Steps** | 1. Call `searchAccounts` with searchTerm = "Outlet" |
| **Expected Result** | - Returns up to 50 accounts matching name pattern<br>- Each result has: Id, Name, Type, BillingCity, BillingState |
| **Status** | |

---

### TC-BPM-036: Search Accounts - Minimum 2 Characters

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-036 |
| **Priority** | Low |
| **Type** | Negative |
| **Precondition** | None |
| **Steps** | 1. Call `searchAccounts` with searchTerm = "O" (1 character) |
| **Expected Result** | - Returns **empty list** (minimum 2 characters required) |
| **Status** | |

---

### TC-BPM-037: Beat Outlet Validation - Beat Required

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-037 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | Account exists |
| **Steps** | 1. Create a Beat_Outlet__c record<br>2. Set Account__c = a valid account<br>3. Leave Beat__c **blank**<br>4. Save |
| **Expected Result** | - Save is **blocked**<br>- Error message: **"Beat is required for a Beat Outlet record."** |
| **Status** | |

---

## 8. Beat Outlet Count Rollup

### TC-BPM-038: Rollup After Insert - Total Outlets Increases

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-038 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Beat-WED has Total_Outlets__c = 4 |
| **Steps** | 1. Create a new Beat_Outlet__c record<br>2. Set Beat__c = Beat-WED, Account__c = a new account, Is_Active__c = true<br>3. Save the record<br>4. Re-query Beat-WED |
| **Expected Result** | - Beat-WED.Total_Outlets__c = **5** |
| **Status** | |

---

### TC-BPM-039: Rollup After Delete - Total Outlets Decreases

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-039 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Beat-WED has Total_Outlets__c = 5 (from previous test) |
| **Steps** | 1. Delete the Beat_Outlet__c record added in TC-BPM-038<br>2. Re-query Beat-WED |
| **Expected Result** | - Beat-WED.Total_Outlets__c = **4** |
| **Status** | |

---

### TC-BPM-040: Rollup After Deactivation - Only Active Outlets Counted

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-040 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Beat-WED has 4 active outlets |
| **Steps** | 1. Open one Beat_Outlet__c under Beat-WED<br>2. Set Is_Active__c = **false**<br>3. Save<br>4. Re-query Beat-WED |
| **Expected Result** | - Beat-WED.Total_Outlets__c = **3** (only active outlets counted) |
| **Status** | |

---

### TC-BPM-041: Rollup After Reactivation

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-041 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Beat-WED has 3 active outlets and 1 inactive outlet |
| **Steps** | 1. Open the inactive Beat_Outlet__c under Beat-WED<br>2. Set Is_Active__c = **true**<br>3. Save<br>4. Re-query Beat-WED |
| **Expected Result** | - Beat-WED.Total_Outlets__c = **4** |
| **Status** | |

---

### TC-BPM-042: Rollup After Moving Outlet to Different Beat

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-042 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Beat-MON has 4 outlets; Beat-TUE has 3 outlets |
| **Steps** | 1. Open a Beat_Outlet__c record under Beat-MON<br>2. Change Beat__c from Beat-MON to **Beat-TUE**<br>3. Save<br>4. Re-query both beats |
| **Expected Result** | - Beat-MON.Total_Outlets__c = **3** (decreased by 1)<br>- Beat-TUE.Total_Outlets__c = **4** (increased by 1)<br>- Rollup recalculates for both old and new parent beats |
| **Status** | |

---

### TC-BPM-043: Rollup - Beat with Zero Outlets

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-043 |
| **Priority** | Low |
| **Type** | Boundary |
| **Precondition** | Beat exists with exactly 1 active outlet |
| **Steps** | 1. Delete the only active Beat_Outlet__c record under the beat<br>2. Re-query the beat |
| **Expected Result** | - Beat.Total_Outlets__c = **0** |
| **Status** | |

---

## 9. Beat List Views

### TC-BPM-044: Active Beats List View

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-044 |
| **Priority** | Low |
| **Type** | UI |
| **Precondition** | Mix of active and inactive Beat records exist |
| **Steps** | 1. Navigate to Beat__c tab<br>2. Select the **Active Beats** list view |
| **Expected Result** | - Only beats with Is_Active__c = true are shown |
| **Status** | |

---

### TC-BPM-045: All Beats List View

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-045 |
| **Priority** | Low |
| **Type** | UI |
| **Precondition** | Mix of active and inactive Beat records exist |
| **Steps** | 1. Navigate to Beat__c tab<br>2. Select the **All Beats** list view |
| **Expected Result** | - All Beat records are shown regardless of Is_Active__c status |
| **Status** | |

---

### TC-BPM-046: My Beats List View

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-046 |
| **Priority** | Low |
| **Type** | UI |
| **Precondition** | Beats exist with different Assigned_User__c values |
| **Steps** | 1. Navigate to Beat__c tab<br>2. Select the **My Beats** list view |
| **Expected Result** | - Only beats assigned to the current user (Assigned_User__c = current user) are shown |
| **Status** | |

---

## 10. Journey Plan Creation & Defaults

### TC-BPM-047: Create Journey Plan - Verify Auto-Defaults

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-047 |
| **Priority** | Critical |
| **Type** | Functional |
| **Precondition** | Territory-North and Rep-A exist |
| **Steps** | 1. Create a new Journey_Plan__c record<br>2. Set Salesperson__c = **Rep-A**<br>3. Set Territory__c = **Territory-North**<br>4. Set Month__c = **March**<br>5. Set Year__c = **2026**<br>6. Click **Save** |
| **Expected Result** | - Record saves successfully<br>- `Status__c` = **Draft** (auto-default)<br>- `Plan_Date__c` = **today's date** (auto-default)<br>- `Total_Planned_Visits__c` = **0** (auto-default)<br>- `Total_Planned_Days__c` = **0** (auto-default)<br>- `Effective_From__c` = **2026-03-01** (auto-calculated)<br>- `Effective_To__c` = **2026-03-31** (auto-calculated)<br>- `User__c` = Rep-A's Id (synced from Salesperson__c) |
| **Status** | |

---

### TC-BPM-048: Journey Plan Name Format

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-048 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Territory-North and Rep-A exist |
| **Steps** | 1. Generate a journey plan via the "Generate Plan" button in the calendar<br>2. Check the Name field of the created Journey_Plan__c record |
| **Expected Result** | - Name follows format: **"{Month} {Year} - {User Name} - {Territory Name}"**<br>- Example: **"March 2026 - Rep-A - Territory-North"** |
| **Status** | |

---

### TC-BPM-049: Journey Plan - Salesperson__c Syncs to User__c (Deprecated)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-049 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | None |
| **Steps** | 1. Create a Journey_Plan__c with Salesperson__c = Rep-A<br>2. Do NOT set User__c<br>3. Save and query the record |
| **Expected Result** | - `User__c` = Rep-A's Id (auto-synced from Salesperson__c by trigger handler) |
| **Status** | |

---

### TC-BPM-050: Journey Plan - Effective Dates Auto-Calculated by Flow

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-050 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | None |
| **Steps** | 1. Create a Journey_Plan__c with Month__c = "February", Year__c = "2026"<br>2. Leave Effective_From__c and Effective_To__c **blank**<br>3. Save and query the record |
| **Expected Result** | - `Effective_From__c` = **2026-02-01**<br>- `Effective_To__c` = **2026-02-28** (non-leap year) |
| **Status** | |

---

### TC-BPM-051: Journey Plan - Effective Dates for Leap Year

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-051 |
| **Priority** | Medium |
| **Type** | Boundary |
| **Precondition** | None |
| **Steps** | 1. Create a Journey_Plan__c with Month__c = "February", Year__c = "2028"<br>2. Leave Effective_From__c and Effective_To__c blank<br>3. Save and query the record |
| **Expected Result** | - `Effective_From__c` = **2028-02-01**<br>- `Effective_To__c` = **2028-02-29** (leap year) |
| **Status** | |

---

### TC-BPM-052: Journey Plan - Effective Dates for December (Year Boundary)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-052 |
| **Priority** | Medium |
| **Type** | Boundary |
| **Precondition** | None |
| **Steps** | 1. Create a Journey_Plan__c with Month__c = "December", Year__c = "2026"<br>2. Leave Effective_From__c and Effective_To__c blank<br>3. Save and query the record |
| **Expected Result** | - `Effective_From__c` = **2026-12-01**<br>- `Effective_To__c` = **2026-12-31** |
| **Status** | |

---

### TC-BPM-053: Journey Plan - Pre-set Effective Dates Not Overwritten

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-053 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | None |
| **Steps** | 1. Create a Journey_Plan__c with Month__c = "March", Year__c = "2026"<br>2. Explicitly set Effective_From__c = **2026-03-05**<br>3. Set Effective_To__c = **2026-03-25**<br>4. Save and query the record |
| **Expected Result** | - `Effective_From__c` = **2026-03-05** (NOT overwritten, already set)<br>- `Effective_To__c` = **2026-03-25** (NOT overwritten)<br>- Flow only auto-calculates when Effective_From__c IS NULL |
| **Status** | |

---

## 11. Journey Plan Validation Rules

### TC-BPM-054: Salesperson Required

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-054 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | None |
| **Steps** | 1. Create a Journey_Plan__c<br>2. Leave Salesperson__c **blank**<br>3. Set Month__c = "March", Year__c = "2026"<br>4. Save |
| **Expected Result** | - Save is **blocked**<br>- Error message: **"Salesperson is required for a Journey Plan."** |
| **Status** | |

---

### TC-BPM-055: Effective_To Must Be After Effective_From

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-055 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | None |
| **Steps** | 1. Create a Journey_Plan__c<br>2. Set Effective_From__c = **2026-03-31**<br>3. Set Effective_To__c = **2026-03-01** (before From date)<br>4. Save |
| **Expected Result** | - Save is **blocked**<br>- Error message: **"Effective To date must be on or after Effective From date."** |
| **Status** | |

---

### TC-BPM-056: Effective_To Same as Effective_From (Single Day Plan)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-056 |
| **Priority** | Low |
| **Type** | Boundary |
| **Precondition** | None |
| **Steps** | 1. Create a Journey_Plan__c<br>2. Set Effective_From__c = **2026-03-15**<br>3. Set Effective_To__c = **2026-03-15**<br>4. Save |
| **Expected Result** | - Record saves **successfully** (same date is valid per rule: Effective_To__c < Effective_From__c) |
| **Status** | |

---

### TC-BPM-057: No Edit After Approval - Modify Total Planned Visits

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-057 |
| **Priority** | Critical |
| **Type** | Negative |
| **Precondition** | Journey Plan exists with Status = "Approved" |
| **Steps** | 1. Open the Approved Journey Plan<br>2. Change Total_Planned_Visits__c to a different value<br>3. Save |
| **Expected Result** | - Save is **blocked**<br>- Error message: **"Cannot modify an approved or active Journey Plan. Please create a new plan or request revision."** |
| **Status** | |

---

### TC-BPM-058: No Edit After Active Status

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-058 |
| **Priority** | Critical |
| **Type** | Negative |
| **Precondition** | Journey Plan exists with Status = "Active" |
| **Steps** | 1. Open the Active Journey Plan<br>2. Attempt to modify Total_Planned_Visits__c<br>3. Save |
| **Expected Result** | - Save is **blocked**<br>- Error message: **"Cannot modify an approved or active Journey Plan..."** |
| **Status** | |

---

### TC-BPM-059: Draft Plan - Total Planned Visits Can Be Modified

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-059 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Journey Plan exists with Status = "Draft" |
| **Steps** | 1. Open the Draft Journey Plan<br>2. Change Total_Planned_Visits__c<br>3. Save |
| **Expected Result** | - Record saves **successfully** (validation only blocks Approved/Active plans) |
| **Status** | |

---

## 12. Journey Plan Effective Date Calculation

### TC-BPM-060: January Effective Dates

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-060 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | None |
| **Steps** | 1. Create Journey_Plan__c with Month__c = "January", Year__c = "2026"<br>2. Leave Effective dates blank<br>3. Save and query |
| **Expected Result** | - Effective_From__c = **2026-01-01**<br>- Effective_To__c = **2026-01-31** |
| **Status** | |

---

### TC-BPM-061: June Effective Dates (30-Day Month)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-061 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | None |
| **Steps** | 1. Create Journey_Plan__c with Month__c = "June", Year__c = "2026"<br>2. Leave Effective dates blank<br>3. Save and query |
| **Expected Result** | - Effective_From__c = **2026-06-01**<br>- Effective_To__c = **2026-06-30** |
| **Status** | |

---

### TC-BPM-062: Trigger Also Calculates Effective Dates

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-062 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | None |
| **Steps** | 1. Via API, create Journey_Plan__c with Month__c = "April", Year__c = "2026"<br>2. Leave Effective_From__c and Effective_To__c null<br>3. Query the record |
| **Expected Result** | - Both the Flow (BPM_JourneyPlan_Effective_Dates) and the Trigger handler (calculateEffectiveDates) calculate the dates<br>- Effective_From__c = **2026-04-01**<br>- Effective_To__c = **2026-04-30** |
| **Status** | |

---

### TC-BPM-063: Effective Dates - Month Provided as Number

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-063 |
| **Priority** | Low |
| **Type** | Boundary |
| **Precondition** | None |
| **Steps** | 1. Via the auto-generate plan flow, pass month = "7" (number format)<br>2. Verify the plan's effective dates |
| **Expected Result** | - Month parsed correctly as July<br>- Effective_From__c = **2026-07-01**<br>- Effective_To__c = **2026-07-31** |
| **Status** | |

---

### TC-BPM-064: Effective Dates - Invalid Month

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-064 |
| **Priority** | Low |
| **Type** | Negative |
| **Precondition** | None |
| **Steps** | 1. Call generateDefaultPlan via API with month = "InvalidMonth"<br>2. Observe the response |
| **Expected Result** | - Exception thrown: **"Invalid month value: InvalidMonth"** |
| **Status** | |

---

## 13. Journey Plan Status Transitions

### Valid Transition Map

| From Status | Valid Transitions To |
|-------------|---------------------|
| Draft | Submitted, Cancelled |
| Submitted | Approved, Rejected, Cancelled |
| Approved | Active, Cancelled |
| Rejected | Draft, Cancelled |
| Active | Cancelled |
| Cancelled | _(none - terminal state)_ |

---

### TC-BPM-065: Draft to Submitted

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-065 |
| **Priority** | Critical |
| **Type** | Functional |
| **Precondition** | Journey Plan with Status = "Draft" |
| **Steps** | 1. Update Status__c from **Draft** to **Submitted**<br>2. Save |
| **Expected Result** | - Record saves successfully<br>- Status = **Submitted** |
| **Status** | |

---

### TC-BPM-066: Submitted to Approved

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-066 |
| **Priority** | Critical |
| **Type** | Functional |
| **Precondition** | Journey Plan with Status = "Submitted" |
| **Steps** | 1. Update Status__c from **Submitted** to **Approved**<br>2. Save<br>3. Query Approval_Date__c and Approved_By__c |
| **Expected Result** | - Record saves successfully<br>- `Approval_Date__c` = **today's date** (auto-set by trigger handler)<br>- `Approved_By__c` = **current user's Id** (auto-set by trigger handler) |
| **Status** | |

---

### TC-BPM-067: Submitted to Rejected

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-067 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Journey Plan with Status = "Submitted" |
| **Steps** | 1. Update Status__c from **Submitted** to **Rejected**<br>2. Save |
| **Expected Result** | - Record saves successfully<br>- Status = **Rejected** |
| **Status** | |

---

### TC-BPM-068: Rejected Back to Draft

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-068 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Journey Plan with Status = "Rejected" |
| **Steps** | 1. Update Status__c from **Rejected** to **Draft**<br>2. Save |
| **Expected Result** | - Record saves successfully<br>- Status = **Draft** (plan can be re-edited and re-submitted) |
| **Status** | |

---

### TC-BPM-069: Approved to Active

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-069 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Journey Plan with Status = "Approved" |
| **Steps** | 1. Update Status__c from **Approved** to **Active**<br>2. Save |
| **Expected Result** | - Record saves successfully<br>- Status = **Active** |
| **Status** | |

---

### TC-BPM-070: Active to Cancelled

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-070 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Journey Plan with Status = "Active" |
| **Steps** | 1. Update Status__c from **Active** to **Cancelled**<br>2. Save |
| **Expected Result** | - Record saves successfully<br>- Status = **Cancelled** (terminal state) |
| **Status** | |

---

### TC-BPM-071: Invalid Transition - Draft to Approved (Skip Submitted)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-071 |
| **Priority** | Critical |
| **Type** | Negative |
| **Precondition** | Journey Plan with Status = "Draft" |
| **Steps** | 1. Update Status__c from **Draft** directly to **Approved**<br>2. Save |
| **Expected Result** | - Save is **blocked**<br>- Error on Status__c field indicating invalid status transition |
| **Status** | |

---

### TC-BPM-072: Invalid Transition - Draft to Active

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-072 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | Journey Plan with Status = "Draft" |
| **Steps** | 1. Update Status__c from **Draft** to **Active**<br>2. Save |
| **Expected Result** | - Save is **blocked** (Draft can only go to Submitted or Cancelled) |
| **Status** | |

---

### TC-BPM-073: Invalid Transition - Draft to Rejected

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-073 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | Journey Plan with Status = "Draft" |
| **Steps** | 1. Update Status__c from **Draft** to **Rejected**<br>2. Save |
| **Expected Result** | - Save is **blocked** (Draft cannot go directly to Rejected) |
| **Status** | |

---

### TC-BPM-074: Invalid Transition - Cancelled to Draft (Terminal State)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-074 |
| **Priority** | Critical |
| **Type** | Negative |
| **Precondition** | Journey Plan with Status = "Cancelled" |
| **Steps** | 1. Update Status__c from **Cancelled** to **Draft**<br>2. Save |
| **Expected Result** | - Save is **blocked**<br>- Cancelled is a terminal state with no valid outgoing transitions |
| **Status** | |

---

### TC-BPM-075: Invalid Transition - Approved to Draft

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-075 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | Journey Plan with Status = "Approved" |
| **Steps** | 1. Update Status__c from **Approved** to **Draft**<br>2. Save |
| **Expected Result** | - Save is **blocked** (Approved can only go to Active or Cancelled) |
| **Status** | |

---

### TC-BPM-076: Invalid Transition - Rejected to Approved

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-076 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | Journey Plan with Status = "Rejected" |
| **Steps** | 1. Update Status__c from **Rejected** to **Approved**<br>2. Save |
| **Expected Result** | - Save is **blocked** (Rejected can only go to Draft or Cancelled) |
| **Status** | |

---

## 14. Journey Plan Approval Workflow

### TC-BPM-077: Submit for Approval via Calendar Component

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-077 |
| **Priority** | Critical |
| **Type** | Functional |
| **Precondition** | Journey Plan in **Draft** status with plan days; Approval Process configured |
| **Steps** | 1. Open the Beat Plan Calendar component<br>2. Verify "Submit for Approval" button is **enabled**<br>3. Click **Submit for Approval**<br>4. Confirm the action |
| **Expected Result** | - Status changes to **Submitted**<br>- Success toast: "Journey Plan submitted for approval."<br>- "Submit for Approval" button becomes **disabled**<br>- Calendar refreshes showing updated status badge |
| **Status** | |

---

### TC-BPM-078: Submit Already Submitted Plan

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-078 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | Journey Plan with Status = "Submitted" |
| **Steps** | 1. Call `submitForApproval` via API with the plan Id |
| **Expected Result** | - Error: **"This journey plan has already been submitted for approval."** |
| **Status** | |

---

### TC-BPM-079: Submit Already Approved Plan

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-079 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | Journey Plan with Status = "Approved" |
| **Steps** | 1. Call `submitForApproval` via API with the plan Id |
| **Expected Result** | - Error: **"This journey plan has already been approved."** |
| **Status** | |

---

### TC-BPM-080: Approval Sets Approval_Date__c and Approved_By__c

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-080 |
| **Priority** | Critical |
| **Type** | Functional |
| **Precondition** | Journey Plan with Status = "Submitted" |
| **Steps** | 1. Change Status__c to **Approved** (via approval process or direct update)<br>2. Save<br>3. Query Approval_Date__c and Approved_By__c |
| **Expected Result** | - `Approval_Date__c` = **today's date**<br>- `Approved_By__c` = **current user's Id**<br>- Both auto-set by handleApproval method in trigger handler |
| **Status** | |

---

### TC-BPM-081: Submit for Approval Button Disabled for Non-Draft

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-081 |
| **Priority** | Medium |
| **Type** | UI |
| **Precondition** | Journey Plans in Submitted, Approved, and Active statuses |
| **Steps** | 1. Open each Journey Plan in the calendar component<br>2. Check the "Submit for Approval" button state |
| **Expected Result** | - Button is **disabled** for Submitted, Approved, and Active plans<br>- Button is **enabled** only for Draft and Rejected plans |
| **Status** | |

---

### TC-BPM-082: Re-Submit After Rejection

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-082 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Journey Plan with Status = "Rejected" |
| **Steps** | 1. Open the Rejected plan in the calendar<br>2. Optionally modify beat assignments (plan is editable in Rejected status)<br>3. Change Status to "Draft" first, then click **Submit for Approval** |
| **Expected Result** | - Plan transitions from Rejected → Draft → Submitted<br>- Approval process is re-initiated |
| **Status** | |

---

## 15. Journey Plan Day Management

### TC-BPM-083: Add Beat to Calendar Day

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-083 |
| **Priority** | Critical |
| **Type** | Functional |
| **Precondition** | Draft Journey Plan exists; Beat-MON available; calendar shows a Monday with no beats |
| **Steps** | 1. Open the Beat Plan Calendar<br>2. Click on a **Monday** cell in the calendar<br>3. In the day detail panel, find Beat-MON in the **Available Beats** section<br>4. Click Beat-MON to assign it |
| **Expected Result** | - New Journey_Plan_Day__c record created with:<br>&nbsp;&nbsp;- Journey_Plan__c = current plan<br>&nbsp;&nbsp;- Beat__c = Beat-MON<br>&nbsp;&nbsp;- Day_of_Week__c = "Monday"<br>&nbsp;&nbsp;- Week_Number__c = appropriate week ("Week 1" through "Week 4")<br>&nbsp;&nbsp;- Plan_Date__c = the selected date<br>&nbsp;&nbsp;- Planned_Outlets__c = count of active Beat_Outlet__c for Beat-MON<br>&nbsp;&nbsp;- Status__c = "Planned"<br>&nbsp;&nbsp;- Sequence_Order__c = auto-incremented<br>- Calendar refreshes showing the beat chip on that day<br>- Success toast: "Beat-MON assigned successfully."<br>- Parent plan Total_Planned_Days__c and Total_Planned_Visits__c updated |
| **Status** | |

---

### TC-BPM-084: Remove Beat from Calendar Day

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-084 |
| **Priority** | Critical |
| **Type** | Functional |
| **Precondition** | Draft Journey Plan with Beat-MON assigned to a Monday |
| **Steps** | 1. Open the Beat Plan Calendar<br>2. Click on the Monday that has Beat-MON<br>3. In the day detail panel, click the **X** button on Beat-MON |
| **Expected Result** | - Journey_Plan_Day__c record is **deleted**<br>- Calendar refreshes with the beat removed from that day<br>- Success toast: "Beat removed from day."<br>- Parent plan rollups updated (Total_Planned_Days__c decreased, Total_Planned_Visits__c decreased) |
| **Status** | |

---

### TC-BPM-085: Cannot Add Beat to Submitted/Approved Plan

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-085 |
| **Priority** | Critical |
| **Type** | Negative |
| **Precondition** | Journey Plan with Status = "Submitted" or "Approved" |
| **Steps** | 1. Open the plan in the calendar<br>2. Click on a day<br>3. Attempt to assign a beat |
| **Expected Result** | - Available beats section is **not shown** (isPlanEditable = false)<br>- If called via API: Error **"Cannot modify a plan that is submitted or approved."** |
| **Status** | |

---

### TC-BPM-086: Cannot Remove Beat from Submitted/Approved Plan

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-086 |
| **Priority** | Critical |
| **Type** | Negative |
| **Precondition** | Journey Plan with Status = "Submitted" or "Approved" |
| **Steps** | 1. Open the plan in the calendar<br>2. Click on a day with beats<br>3. Attempt to remove a beat |
| **Expected Result** | - Remove button is **not shown** (isPlanEditable = false)<br>- If called via API: Error **"Cannot modify a plan that is submitted or approved."** |
| **Status** | |

---

### TC-BPM-087: Plan Day Defaults - Beat_Name__c Auto-Populated

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-087 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Beat-MON exists with Name = "Beat Monday North" |
| **Steps** | 1. Create a Journey_Plan_Day__c record with Beat__c = Beat-MON<br>2. Do NOT set Beat_Name__c<br>3. Save and query the record |
| **Expected Result** | - `Beat_Name__c` = **"Beat Monday North"** (auto-populated from Beat__r.Name by trigger handler) |
| **Status** | |

---

### TC-BPM-088: Plan Day Defaults - Status and Counts

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-088 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Journey Plan exists in Draft status |
| **Steps** | 1. Create a Journey_Plan_Day__c record<br>2. Do NOT set Status__c, Planned_Outlets__c, or Visited_Outlets__c<br>3. Save and query |
| **Expected Result** | - `Status__c` = **"Planned"** (default)<br>- `Planned_Outlets__c` = **0** (default)<br>- `Visited_Outlets__c` = **0** (default) |
| **Status** | |

---

### TC-BPM-089: Plan Day Validation - Planned Outlets Non-Negative

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-089 |
| **Priority** | Medium |
| **Type** | Negative |
| **Precondition** | Journey Plan Day exists |
| **Steps** | 1. Update Journey_Plan_Day__c record<br>2. Set Planned_Outlets__c = **-5**<br>3. Save |
| **Expected Result** | - Save is **blocked**<br>- Error message: **"Planned Outlets cannot be negative."** |
| **Status** | |

---

## 16. Journey Plan Day Rollup to Parent

### TC-BPM-090: Insert Plan Days - Parent Totals Update

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-090 |
| **Priority** | Critical |
| **Type** | Functional |
| **Precondition** | Journey Plan in Draft with 0 plan days |
| **Steps** | 1. Create 3 Journey_Plan_Day__c records under the plan with Planned_Outlets__c = 4, 5, 6<br>2. Re-query the parent Journey_Plan__c |
| **Expected Result** | - `Total_Planned_Days__c` = **3**<br>- `Total_Planned_Visits__c` = **15** (4 + 5 + 6) |
| **Status** | |

---

### TC-BPM-091: Delete Plan Day - Parent Totals Decrease

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-091 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Journey Plan has 3 plan days with Total_Planned_Days__c = 3, Total_Planned_Visits__c = 15 |
| **Steps** | 1. Delete one Journey_Plan_Day__c (which had Planned_Outlets__c = 6)<br>2. Re-query the parent Journey_Plan__c |
| **Expected Result** | - `Total_Planned_Days__c` = **2**<br>- `Total_Planned_Visits__c` = **9** (4 + 5) |
| **Status** | |

---

### TC-BPM-092: Update Plan Day Outlets - Parent Total Visits Updates

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-092 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Journey Plan has plan days with Total_Planned_Visits__c = 9 |
| **Steps** | 1. Update one Journey_Plan_Day__c: change Planned_Outlets__c from 4 to **10**<br>2. Re-query the parent Journey_Plan__c |
| **Expected Result** | - `Total_Planned_Visits__c` = **15** (10 + 5) |
| **Status** | |

---

### TC-BPM-093: Bulk Insert Plan Days - Verify Rollup

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-093 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Journey Plan in Draft with 0 plan days |
| **Steps** | 1. Insert 20 Journey_Plan_Day__c records in a single DML batch, each with Planned_Outlets__c = 3<br>2. Re-query the parent Journey_Plan__c |
| **Expected Result** | - `Total_Planned_Days__c` = **20**<br>- `Total_Planned_Visits__c` = **60** (20 x 3) |
| **Status** | |

---

### TC-BPM-094: Delete All Plan Days - Totals Reset to Zero

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-094 |
| **Priority** | Medium |
| **Type** | Boundary |
| **Precondition** | Journey Plan has plan days |
| **Steps** | 1. Delete ALL Journey_Plan_Day__c records under the plan<br>2. Re-query the parent Journey_Plan__c |
| **Expected Result** | - `Total_Planned_Days__c` = **0**<br>- `Total_Planned_Visits__c` = **0** |
| **Status** | |

---

## 17. Auto-Generate Default Plan

### TC-BPM-095: Generate Plan with All 3 Beats (Mon/Tue/Wed)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-095 |
| **Priority** | Critical |
| **Type** | Functional |
| **Precondition** | Territory-North has 3 active beats: Beat-MON (Monday, Weekly), Beat-TUE (Tuesday, Weekly), Beat-WED (Wednesday, Weekly), each with 4 outlets. No existing plan for next month. |
| **Steps** | 1. Open the Beat Plan Calendar (not on a record page, standalone)<br>2. Navigate to **next month** using the arrow<br>3. Verify "No plan" empty state is shown<br>4. Click **Generate Plan** button |
| **Expected Result** | - Journey_Plan__c created with:<br>&nbsp;&nbsp;- Name = "{Month} {Year} - {User Name} - Territory-North"<br>&nbsp;&nbsp;- Status = "Draft"<br>&nbsp;&nbsp;- Effective_From__c = 1st of month<br>&nbsp;&nbsp;- Effective_To__c = last day of month<br>- Journey_Plan_Day__c records created for:<br>&nbsp;&nbsp;- Every Monday in the month → Beat-MON (4 outlets each)<br>&nbsp;&nbsp;- Every Tuesday in the month → Beat-TUE (4 outlets each)<br>&nbsp;&nbsp;- Every Wednesday in the month → Beat-WED (4 outlets each)<br>- **All 3 beats used** across the month (not just 1)<br>- Sundays are excluded<br>- Total plan days = approximately 12-15 (depending on month)<br>- Calendar refreshes immediately showing color-coded beat chips on each day<br>- Success toast displayed |
| **Status** | |

---

### TC-BPM-096: Generate Plan - Multi-Day Beat Appears on Multiple Days

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-096 |
| **Priority** | Critical |
| **Type** | Functional |
| **Precondition** | Beat-MULTI has Day_of_Week__c = "Monday;Wednesday;Friday", Frequency = Weekly, 4 outlets |
| **Steps** | 1. Ensure Beat-MULTI is the only active beat in a test territory<br>2. Generate a plan for next month |
| **Expected Result** | - Plan days created for every Monday, Wednesday, AND Friday<br>- Same Beat-MULTI appears on all three day types<br>- Multi-select picklist values correctly split by semicolon and matched |
| **Status** | |

---

### TC-BPM-097: Generate Plan - Frequency = Bi-Weekly

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-097 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Beat with Day_of_Week__c = "Thursday", Frequency__c = "Bi-Weekly", 4 outlets |
| **Steps** | 1. Generate a plan for a month<br>2. Count the number of plan days for this beat |
| **Expected Result** | - Plan days created only for Thursdays falling on **days 1-14** of the month<br>- Typically **2 plan days** (first two Thursdays)<br>- Thursdays after the 14th are **excluded** |
| **Status** | |

---

### TC-BPM-098: Generate Plan - Frequency = Monthly

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-098 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Beat with Day_of_Week__c = "Friday", Frequency__c = "Monthly", 4 outlets |
| **Steps** | 1. Generate a plan for a month<br>2. Count the number of plan days for this beat |
| **Expected Result** | - Plan day created only for the Friday falling on **days 1-7** of the month<br>- Typically **1 plan day** (first Friday only)<br>- All other Fridays are excluded |
| **Status** | |

---

### TC-BPM-099: Generate Plan - Sundays Excluded

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-099 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Plan generated for a full month |
| **Steps** | 1. Generate a plan<br>2. Query all Journey_Plan_Day__c records<br>3. Check Day_of_Week__c values |
| **Expected Result** | - No plan day has Day_of_Week__c = "Sunday"<br>- All plan days are Monday through Saturday only |
| **Status** | |

---

### TC-BPM-100: Generate Plan - Duplicate Prevention

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-100 |
| **Priority** | Critical |
| **Type** | Negative |
| **Precondition** | A non-cancelled Journey Plan already exists for Rep-A, Territory-North, current month/year |
| **Steps** | 1. Attempt to generate a plan for the same user, territory, month, year |
| **Expected Result** | - Error: **"A journey plan already exists for this user, territory, month, and year."**<br>- No duplicate plan created |
| **Status** | |

---

### TC-BPM-101: Generate Plan - No Active Beats in Territory

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-101 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | Territory-South has no active beats |
| **Steps** | 1. Attempt to generate a plan for Rep-B in Territory-South |
| **Expected Result** | - Error: **"No active beat assignments found for this user in the specified territory."** |
| **Status** | |

---

### TC-BPM-102: Generate Plan - Missing Parameters

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-102 |
| **Priority** | High |
| **Type** | Negative |
| **Precondition** | None |
| **Steps** | 1. Call `generateDefaultPlan` with userId = null, territoryId = null, month = null, year = null |
| **Expected Result** | - Error: **"All parameters (userId, territoryId, month, year) are required."** |
| **Status** | |

---

### TC-BPM-103: Generate Plan - No Territory Warning in Calendar

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-103 |
| **Priority** | Medium |
| **Type** | UI |
| **Precondition** | User has no beats and no territory association |
| **Steps** | 1. Open Beat Plan Calendar as a user with no territory<br>2. Click **Generate Plan** |
| **Expected Result** | - Warning toast: **"No territory found. Ensure beats are assigned to a territory."**<br>- Plan generation is not attempted |
| **Status** | |

---

### TC-BPM-104: Generate Plan - Planned Outlets Count Matches Active Beat Outlets

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-104 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Beat-MON has 4 active outlets and 1 inactive outlet |
| **Steps** | 1. Generate a plan<br>2. Query the Journey_Plan_Day__c records for Beat-MON |
| **Expected Result** | - Each plan day for Beat-MON has Planned_Outlets__c = **4** (only active outlets counted)<br>- The 1 inactive outlet is excluded from the count |
| **Status** | |

---

### TC-BPM-105: Generate Plan - Week Number Assignment

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-105 |
| **Priority** | Medium |
| **Type** | Functional |
| **Precondition** | Plan generated for a month |
| **Steps** | 1. Query all Journey_Plan_Day__c records<br>2. Check Week_Number__c against Plan_Date__c |
| **Expected Result** | - Days 1-7 → **Week 1**<br>- Days 8-14 → **Week 2**<br>- Days 15-21 → **Week 3**<br>- Days 22-31 → **Week 4** |
| **Status** | |

---

## 18. Beat Plan Calendar - LWC Component

### TC-BPM-106: Calendar Loads in Month View by Default

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-106 |
| **Priority** | High |
| **Type** | UI |
| **Precondition** | User has an existing journey plan for the current month |
| **Steps** | 1. Navigate to a page with the Beat Plan Calendar component<br>2. Observe the initial view |
| **Expected Result** | - Calendar displays in **month view** by default<br>- Current month and year shown in the header (e.g., "February 2026")<br>- 7-column grid with Sun-Sat headers<br>- Today's date is **highlighted** (distinct styling)<br>- Sundays have distinct **weekend styling**<br>- Beat chips displayed on days with assignments<br>- Each beat chip is **color-coded** and shows beat name + outlet count<br>- Summary statistics panel shows: Total Planned Visits, Coverage %, Assigned Beats, Total Outlets, Avg Visits/Day<br>- Status badge shows current plan status (e.g., "Draft") |
| **Status** | |

---

### TC-BPM-107: Switch to Week View and Back

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-107 |
| **Priority** | Medium |
| **Type** | UI |
| **Precondition** | Calendar is open in month view |
| **Steps** | 1. Click the **Week** view toggle button<br>2. Verify week view displays correctly<br>3. Click the **Month** view toggle button<br>4. Verify month view restores |
| **Expected Result** | - **Week view:** Shows 7-day row (Sun-Sat) for the current week with date labels, beat chips, and visit counts<br>- Week button has **brand** styling (selected), Month button has **neutral** styling<br>- **Month view:** Full calendar grid restored<br>- Month button has **brand** styling, Week button has **neutral** styling |
| **Status** | |

---

### TC-BPM-108: Navigate Previous / Next Month

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-108 |
| **Priority** | High |
| **Type** | UI |
| **Precondition** | Calendar is in month view, current month has a plan |
| **Steps** | 1. Click the **Next (>)** arrow button<br>2. Verify the calendar loads the next month<br>3. Click the **Previous (<)** arrow button twice<br>4. Verify the calendar navigates correctly |
| **Expected Result** | - Calendar header updates to show correct month/year<br>- Plan data loads for the navigated month (via `loadCalendar`)<br>- If no plan exists for that month, "No plan" state is shown with Generate Plan button<br>- If plan exists, beat assignments are displayed on the calendar |
| **Status** | |

---

### TC-BPM-109: Navigate to Today Button

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-109 |
| **Priority** | Medium |
| **Type** | UI |
| **Precondition** | Calendar is navigated to a different month |
| **Steps** | 1. Navigate to a month 3 months in the future<br>2. Click the **Today** button |
| **Expected Result** | - Calendar jumps back to the **current month**<br>- Today's date is highlighted<br>- Plan data reloads for the current month |
| **Status** | |

---

### TC-BPM-110: Select Day and View Detail Panel

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-110 |
| **Priority** | High |
| **Type** | UI |
| **Precondition** | Calendar is loaded with a plan that has beat assignments |
| **Steps** | 1. Click on a **day cell** that has beat chips<br>2. Observe the detail panel that appears |
| **Expected Result** | - Day detail panel opens showing:<br>&nbsp;&nbsp;- Full date display (e.g., "Monday, 02 March 2026")<br>&nbsp;&nbsp;- **Assigned Beats** section listing all beats on that day with color chips and outlet counts<br>&nbsp;&nbsp;- Remove (X) button on each beat (if plan is editable)<br>&nbsp;&nbsp;- **Available Beats** section showing beats not yet assigned to this day (if plan is editable)<br>&nbsp;&nbsp;- Total visits count for the day |
| **Status** | |

---

### TC-BPM-111: Calendar Refreshes After Plan Generation (No Manual Refresh)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-111 |
| **Priority** | Critical |
| **Type** | UI |
| **Precondition** | No plan exists for next month; beats are set up in the territory |
| **Steps** | 1. Navigate to next month in the calendar<br>2. Verify "No plan" empty state<br>3. Click **Generate Plan**<br>4. Wait for success toast<br>5. Observe the calendar **without manually refreshing the page** |
| **Expected Result** | - Calendar immediately shows the generated plan data<br>- Beat chips appear on the correct days<br>- Summary statistics panel updates with correct numbers<br>- Status badge shows "Draft"<br>- No manual page refresh needed (getJourneyPlan is NOT cacheable) |
| **Status** | |

---

### TC-BPM-112: Summary Statistics Panel Accuracy

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-112 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Plan generated with 3 beats (Mon/Tue/Wed), 4 outlets each, for a month with 4 full weeks |
| **Steps** | 1. Open the calendar and view the Summary Statistics panel<br>2. Calculate expected values manually |
| **Expected Result** | - **Total Planned Visits:** Sum of all Planned_Outlets__c across all plan days (e.g., ~48 for 12 days x 4 outlets)<br>- **Coverage %:** (days with assignments / total working days in month) x 100<br>- **Assigned Beats:** **3** (unique beats)<br>- **Total Outlets:** Sum of unique beat Total_Outlets__c values<br>- **Avg Visits/Day:** Total Planned Visits / unique dates with assignments |
| **Status** | |

---

### TC-BPM-113: Status Badge Styling

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-113 |
| **Priority** | Low |
| **Type** | UI |
| **Precondition** | Journey Plans in various statuses |
| **Steps** | 1. Open plans in different statuses and observe the status badge |
| **Expected Result** | - **Draft** → Draft badge style<br>- **Submitted** → Pending badge style<br>- **Pending Approval** → Pending badge style<br>- **Approved** → Approved badge style (green)<br>- **Active** → Active badge style<br>- **Rejected** → Rejected badge style (red) |
| **Status** | |

---

### TC-BPM-114: Calendar on Journey Plan Record Page

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-114 |
| **Priority** | High |
| **Type** | UI |
| **Precondition** | Journey_Plan__c record exists; calendar component placed on the record page layout |
| **Steps** | 1. Navigate to a Journey_Plan__c record page<br>2. Observe the calendar component |
| **Expected Result** | - Calendar loads using `getJourneyPlanById` (record context via recordId)<br>- Month/Year locked to the plan's Month__c/Year__c values<br>- Salesperson and Territory resolved from the plan record<br>- Beat assignments displayed for the plan's month<br>- Status badge matches the plan's Status__c |
| **Status** | |

---

### TC-BPM-115: Empty Calendar - No Plan State

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-115 |
| **Priority** | Medium |
| **Type** | UI |
| **Precondition** | No journey plan exists for the selected month/user |
| **Steps** | 1. Navigate to a month with no plan in the calendar |
| **Expected Result** | - "No plan" empty state is displayed<br>- **Generate Plan** button is visible and clickable<br>- Summary stats show all zeros<br>- Calendar grid is either empty or not shown |
| **Status** | |

---

## 19. Plan Compliance Calculation

### TC-BPM-116: Compliance Percentage - Partial Visits

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-116 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | Journey Plan with 5 plan days (each with 4 Planned_Outlets__c). 3 days fully visited (Visited_Outlets__c = 4), 2 days with 0 visits. |
| **Steps** | 1. Call `BPM_JourneyPlan_Service.getPlanCompliance(planId)` |
| **Expected Result** | - Compliance = (12 visited / 20 planned) x 100 = **60.00%** |
| **Status** | |

---

### TC-BPM-117: Compliance - No Plan Days (Returns 0)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-117 |
| **Priority** | Medium |
| **Type** | Boundary |
| **Precondition** | Journey Plan exists with no Journey_Plan_Day__c records |
| **Steps** | 1. Call `getPlanCompliance(planId)` |
| **Expected Result** | - Returns **0** |
| **Status** | |

---

### TC-BPM-118: Compliance - Null Plan ID (Returns 0)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-118 |
| **Priority** | Low |
| **Type** | Boundary |
| **Precondition** | None |
| **Steps** | 1. Call `getPlanCompliance(null)` |
| **Expected Result** | - Returns **0** (no exception thrown) |
| **Status** | |

---

## 20. Integration & Cross-Module Tests

### TC-BPM-119: End-to-End - Full Plan Lifecycle

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-119 |
| **Priority** | Critical |
| **Type** | Integration / End-to-End |
| **Precondition** | Territory with 3 beats (each with 4 outlets), a sales rep user, approval process configured |
| **Steps** | 1. **Setup:** Verify Territory-North has 3 active beats with Day_of_Week__c and outlets<br>2. **Generate:** Open Calendar as Rep-A → navigate to a future month → click **Generate Plan**<br>3. **Verify Plan Header:** Check Name = "{Month} {Year} - Rep-A - Territory-North", Status = Draft, Effective dates calculated<br>4. **Verify Plan Days:** Confirm plan days exist for Mon/Tue/Wed across the month (all 3 beats used), Sundays excluded, Planned_Outlets__c = 4 per day<br>5. **Modify Plan:** Click a Thursday → add a beat → verify it appears. Remove a beat from a Wednesday → verify removal<br>6. **Verify Rollups:** Check Total_Planned_Days__c and Total_Planned_Visits__c updated correctly after modifications<br>7. **Submit:** Click Submit for Approval → verify Status = Submitted, button disabled<br>8. **Approve:** Approve the plan via approval process → verify Approval_Date__c and Approved_By__c set<br>9. **Lock:** Attempt to add/remove beats on Approved plan → verify blocked<br>10. **Activate:** Change status to Active<br>11. **Compliance:** Record visits against the plan, check compliance calculation |
| **Expected Result** | - All steps complete without errors<br>- Data integrity maintained throughout lifecycle<br>- Rollups accurate at every stage<br>- Calendar UI updates in real-time at each step<br>- Status transitions follow valid state machine |
| **Status** | |

---

### TC-BPM-120: Cross-Module - Visit Linked to Journey Plan Day

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-BPM-120 |
| **Priority** | High |
| **Type** | Integration |
| **Precondition** | Active Journey Plan with plan days; Visit__c object has Beat__c and Journey_Plan_Day__c lookup fields |
| **Steps** | 1. Create a Visit__c record with:<br>&nbsp;&nbsp;- Salesperson__c = Rep-A<br>&nbsp;&nbsp;- Beat__c = a beat from the plan<br>&nbsp;&nbsp;- Journey_Plan_Day__c = the matching plan day<br>&nbsp;&nbsp;- Visit_Date__c = within the plan's effective date range<br>&nbsp;&nbsp;- Visit_Status__c = "Completed"<br>2. Call `BeatPlanController.getPlanCompliance(planId)` |
| **Expected Result** | - Visit counted in compliance calculation<br>- Compliance percentage reflects the completed visit<br>- Cross-module linking via Beat__c and Journey_Plan_Day__c works correctly |
| **Status** | |

---

## 21. Test Summary

### Test Case Distribution

| Section | Test Cases | Priority Breakdown |
|---------|-----------|-------------------|
| Beat Creation & Defaults | TC-BPM-001 to TC-BPM-006 | 2 High, 4 Medium |
| Beat Validation Rules | TC-BPM-007 to TC-BPM-014 | 5 High, 3 Medium |
| Beat Code Uniqueness | TC-BPM-015 to TC-BPM-019 | 2 High, 3 Medium |
| Beat Deprecated Field Sync | TC-BPM-020 to TC-BPM-023 | 0 High, 4 Medium |
| Beat Deactivation Protection | TC-BPM-024 to TC-BPM-028 | 1 Critical, 2 High, 2 Medium |
| Beat Outlet Management | TC-BPM-029 to TC-BPM-037 | 3 High, 3 Medium, 3 Low |
| Beat Outlet Count Rollup | TC-BPM-038 to TC-BPM-043 | 2 High, 2 Medium, 2 Low |
| Beat List Views | TC-BPM-044 to TC-BPM-046 | 0 High, 0 Medium, 3 Low |
| Journey Plan Creation & Defaults | TC-BPM-047 to TC-BPM-053 | 1 Critical, 2 High, 4 Medium |
| Journey Plan Validation Rules | TC-BPM-054 to TC-BPM-059 | 2 Critical, 2 High, 2 Medium |
| Journey Plan Effective Dates | TC-BPM-060 to TC-BPM-064 | 0 Critical, 0 High, 4 Medium, 1 Low |
| Journey Plan Status Transitions | TC-BPM-065 to TC-BPM-076 | 3 Critical, 7 High, 2 Medium |
| Journey Plan Approval Workflow | TC-BPM-077 to TC-BPM-082 | 2 Critical, 3 High, 1 Medium |
| Journey Plan Day Management | TC-BPM-083 to TC-BPM-089 | 2 Critical, 0 High, 5 Medium |
| Journey Plan Day Rollup | TC-BPM-090 to TC-BPM-094 | 1 Critical, 2 High, 2 Medium |
| Auto-Generate Default Plan | TC-BPM-095 to TC-BPM-105 | 2 Critical, 5 High, 4 Medium |
| Beat Plan Calendar LWC | TC-BPM-106 to TC-BPM-115 | 1 Critical, 4 High, 3 Medium, 2 Low |
| Plan Compliance | TC-BPM-116 to TC-BPM-118 | 1 High, 1 Medium, 1 Low |
| Integration & Cross-Module | TC-BPM-119 to TC-BPM-120 | 1 Critical, 1 High |

### Priority Summary

| Priority | Count |
|----------|-------|
| Critical | 16 |
| High | 43 |
| Medium | 49 |
| Low | 12 |
| **Total** | **120** |

### Test Type Summary

| Type | Count |
|------|-------|
| Functional | 68 |
| Negative | 30 |
| UI | 10 |
| Boundary | 8 |
| Integration / End-to-End | 4 |
| **Total** | **120** |

### Recommended Execution Order

1. **Smoke Test (Critical only):** TC-BPM-024, 047, 054, 057, 065, 071, 074, 077, 080, 083, 085, 090, 095, 100, 111, 119 (16 tests)
2. **Core Regression (Critical + High):** All Critical + High priority tests (59 tests)
3. **Full Regression:** All 120 test cases

### Known Dependencies

| Dependency | Details |
|------------|---------|
| Approval Process | Must be configured for Journey_Plan__c object for TC-BPM-077 through TC-BPM-082 |
| Feature Toggles | BPM-001 (Beat triggers) and BPM-002 (Journey Plan triggers) must be enabled via BPM_FeatureToggle_Util |
| Territory Data | At least 2 Territory_Master__c records needed |
| User Accounts | At least 2 active users with appropriate permissions |

---

_Document generated on 2026-02-24. For questions or clarifications, contact the SFA Development Team._
