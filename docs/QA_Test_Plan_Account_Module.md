# QA Test Plan - Account Module (FMCG CRM / SFA)

**Application:** Field Sales CRM
**Module:** Account Management
**Version:** 1.0
**API Version:** 59.0
**Date:** 2026-02-20
**Total Test Cases:** 78

---

## Table of Contents

1. [Test Data Requirements](#1-test-data-requirements)
2. [Account Creation & Default Values (TC-ACC-001 to TC-ACC-004)](#2-account-creation--default-values)
3. [Visit Frequency Auto-Assignment (TC-ACC-005 to TC-ACC-010)](#3-visit-frequency-auto-assignment)
4. [Validation Rules (TC-ACC-011 to TC-ACC-023)](#4-validation-rules)
5. [Beat Assignment & Outlet Count Rollup (TC-ACC-024 to TC-ACC-028)](#5-beat-assignment--outlet-count-rollup)
6. [Credit Utilization Tracking (TC-ACC-029 to TC-ACC-032)](#6-credit-utilization-tracking)
7. [Last Activity Auto-Tracking (TC-ACC-033 to TC-ACC-035)](#7-last-activity-auto-tracking)
8. [Outlet 360-Degree View - LWC Component (TC-ACC-036 to TC-ACC-047)](#8-outlet-360-degree-view---lwc-component)
9. [New Outlet Onboarding Flow (TC-ACC-048 to TC-ACC-051)](#9-new-outlet-onboarding-flow)
10. [List Views (TC-ACC-052 to TC-ACC-055)](#10-list-views)
11. [Page Layouts by Record Type (TC-ACC-056 to TC-ACC-057)](#11-page-layouts-by-record-type)
12. [Compact Layout (TC-ACC-058)](#12-compact-layout)
13. [Field-Level Picklist Values (TC-ACC-059 to TC-ACC-062)](#13-field-level-picklist-values)
14. [Boundary & Negative Testing (TC-ACC-063 to TC-ACC-067)](#14-boundary--negative-testing)
15. [Geo-Location & Check-In (TC-ACC-068 to TC-ACC-070)](#15-geo-location--check-in)
16. [Application Navigation (TC-ACC-071 to TC-ACC-072)](#16-application-navigation)
17. [Integration Tests - Cross Module (TC-ACC-073 to TC-ACC-075)](#17-integration-tests---cross-module)
18. [Data Integrity (TC-ACC-076 to TC-ACC-078)](#18-data-integrity)
19. [Test Summary](#19-test-summary)

---

## 1. Test Data Requirements

Before executing the test cases, prepare the following test data in your Salesforce org:

| # | Data Type | Details | Quantity |
|---|-----------|---------|----------|
| 1 | **Beat records** | Beat-001, Beat-002, Beat-003 with known Total_Outlets__c values | 3 |
| 2 | **Territory Master records** | Territory-North, Territory-South | 2 |
| 3 | **Retailer Account** | With Outlet Type, Outlet Class, Channel, Beat, Territory populated | 1 |
| 4 | **Distributor Account** | With GSTIN, PAN, Drug License, FSSAI License populated | 1 |
| 5 | **Modern Trade Account** | With Channel = MT | 1 |
| 6 | **Super Stockist Account** | Basic account with required fields | 1 |
| 7 | **Sales Orders** | Mix of Confirmed, Delivered, Cancelled, Rejected statuses per account | 3-5 per account |
| 8 | **Invoices** | Mix of Unpaid, Partially Paid, Fully Paid, Cancelled statuses | 3-5 per account |
| 9 | **Collections** | Mix of Cash, Cheque, UPI, On Account payment modes | 3-5 per account |
| 10 | **Visits** | Mix of Completed and In-Progress visits | 3-5 per account |
| 11 | **Schemes** | Active schemes with different types (Percentage, Flat, Buy X Get Y, Slab, Volume) matching test account's Channel/Outlet Type | 3+ |
| 12 | **Distributor Stock** | Varying quantity levels (Low <=10, Medium <=50, High >50) | 5+ |

### Record Types Available

| Record Type Developer Name | Label | Description |
|---------------------------|-------|-------------|
| Retailer | Retailer | Retail outlet / shop (traditional trade) |
| Distributor | Distributor | Distribution partner / C&F Agent |
| Modern_Trade | Modern Trade | Modern Trade key account (chain stores, supermarkets) |
| Super_Stockist | Super Stockist | Super Stockist / C&F Agent intermediary |

---

## 2. Account Creation & Default Values

### TC-ACC-001: Create Retailer Account - Verify Auto-Defaults

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-001 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | User has Account Create permission |
| **Steps** | 1. Navigate to Accounts tab<br>2. Click **New**<br>3. Select Record Type = **Retailer**<br>4. Enter Account Name = "Test Retail Shop"<br>5. Select Outlet Type = "Grocery"<br>6. Set Outlet Class = **A**<br>7. Click **Save** |
| **Expected Result** | - Record saves successfully<br>- `Is_Active__c` = **true** (auto-set by trigger)<br>- `Visit_Frequency__c` = **Weekly** (auto-set for Class A)<br>- `Credit_Utilized__c` = **0** (initialized by trigger)<br>- Record Type = Retailer |
| **Status** | |

---

### TC-ACC-002: Create Distributor Account - Verify Auto-Defaults

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-002 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | User has Account Create permission |
| **Steps** | 1. Navigate to Accounts tab<br>2. Click **New**<br>3. Select Record Type = **Distributor**<br>4. Enter Account Name = "Test Distributor"<br>5. Click **Save** |
| **Expected Result** | - Record saves successfully<br>- `Is_Active__c` = **true**<br>- `Credit_Utilized__c` = **0**<br>- No Outlet Type validation error (rule only applies to Retailer)<br>- Record Type = Distributor |
| **Status** | |

---

### TC-ACC-003: Create Modern Trade Account

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-003 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | User has Account Create permission |
| **Steps** | 1. Navigate to Accounts tab<br>2. Click **New**<br>3. Select Record Type = **Modern_Trade**<br>4. Enter Account Name = "Test Supermarket Chain"<br>5. Set Channel = **MT**<br>6. Click **Save** |
| **Expected Result** | - Record saves successfully<br>- `Is_Active__c` = **true**<br>- `Credit_Utilized__c` = **0**<br>- Record Type = Modern Trade |
| **Status** | |

---

### TC-ACC-004: Create Super Stockist Account

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-004 |
| **Priority** | High |
| **Type** | Functional |
| **Precondition** | User has Account Create permission |
| **Steps** | 1. Navigate to Accounts tab<br>2. Click **New**<br>3. Select Record Type = **Super_Stockist**<br>4. Enter Account Name = "Test Super Stockist"<br>5. Click **Save** |
| **Expected Result** | - Record saves successfully<br>- `Is_Active__c` = **true**<br>- `Credit_Utilized__c` = **0**<br>- Record Type = Super Stockist |
| **Status** | |

---

## 3. Visit Frequency Auto-Assignment

### TC-ACC-005: Outlet Class A Assigns Weekly Visit Frequency

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-005 |
| **Priority** | High |
| **Type** | Functional / Automation |
| **Precondition** | None |
| **Steps** | 1. Create new Account (Record Type = Retailer)<br>2. Set Outlet_Class__c = **A**<br>3. Leave Visit_Frequency__c blank<br>4. Save |
| **Expected Result** | `Visit_Frequency__c` = **Weekly** |
| **Status** | |

---

### TC-ACC-006: Outlet Class B Assigns Bi-Weekly Visit Frequency

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-006 |
| **Priority** | High |
| **Type** | Functional / Automation |
| **Precondition** | None |
| **Steps** | 1. Create new Account (Record Type = Retailer)<br>2. Set Outlet_Class__c = **B**<br>3. Leave Visit_Frequency__c blank<br>4. Save |
| **Expected Result** | `Visit_Frequency__c` = **Bi-Weekly** |
| **Status** | |

---

### TC-ACC-007: Outlet Class C Assigns Monthly Visit Frequency

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-007 |
| **Priority** | High |
| **Type** | Functional / Automation |
| **Precondition** | None |
| **Steps** | 1. Create new Account (Record Type = Retailer)<br>2. Set Outlet_Class__c = **C**<br>3. Leave Visit_Frequency__c blank<br>4. Save |
| **Expected Result** | `Visit_Frequency__c` = **Monthly** |
| **Status** | |

---

### TC-ACC-008: Outlet Class D Assigns Monthly Visit Frequency

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-008 |
| **Priority** | High |
| **Type** | Functional / Automation |
| **Precondition** | None |
| **Steps** | 1. Create new Account (Record Type = Retailer)<br>2. Set Outlet_Class__c = **D**<br>3. Leave Visit_Frequency__c blank<br>4. Save |
| **Expected Result** | `Visit_Frequency__c` = **Monthly** |
| **Status** | |

---

### TC-ACC-009: Changing Outlet Class Updates Visit Frequency (Default Was Applied)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-009 |
| **Priority** | High |
| **Type** | Functional / Automation |
| **Precondition** | Existing Retailer Account with Outlet Class = **A** and Visit Frequency = **Weekly** (auto-assigned default) |
| **Steps** | 1. Open the Account record<br>2. Click **Edit**<br>3. Change Outlet_Class__c from **A** to **C**<br>4. Click **Save** |
| **Expected Result** | `Visit_Frequency__c` changes from **Weekly** to **Monthly** (trigger re-derives because old value matched old class default) |
| **Status** | |

---

### TC-ACC-010: Changing Outlet Class Preserves Manual Visit Frequency Override

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-010 |
| **Priority** | High |
| **Type** | Functional / Automation |
| **Precondition** | Existing Retailer Account with Outlet Class = **A**. Manually change Visit_Frequency__c to **Monthly** (overriding the default "Weekly") and save. |
| **Steps** | 1. Open the Account record<br>2. Click **Edit**<br>3. Change Outlet_Class__c from **A** to **B**<br>4. Click **Save** |
| **Expected Result** | `Visit_Frequency__c` remains **Monthly** (manual override preserved because the old value "Monthly" did NOT match the old class A default of "Weekly") |
| **Status** | |

---

## 4. Validation Rules

### TC-ACC-011: GSTIN Validation - Valid 15-Character Format

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-011 |
| **Priority** | High |
| **Type** | Validation |
| **Precondition** | Account record open in edit mode |
| **Steps** | 1. Enter GSTIN__c = `27AABCU9603R1ZM`<br>2. Save |
| **Expected Result** | Record saves successfully. No validation error. |
| **Regex Pattern** | `[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}` |
| **Status** | |

---

### TC-ACC-012: GSTIN Validation - Invalid Format (All Letters)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-012 |
| **Priority** | High |
| **Type** | Validation / Negative |
| **Steps** | 1. Enter GSTIN__c = `ABCDEFGHIJKLMNO`<br>2. Save |
| **Expected Result** | Error on GSTIN__c field: **"Invalid GSTIN format. Expected format: 2 digits + 5 letters + 4 digits + 1 letter + 1 alphanumeric + Z + 1 alphanumeric"** |
| **Status** | |

---

### TC-ACC-013: GSTIN Validation - Invalid Format (Too Short)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-013 |
| **Priority** | Medium |
| **Type** | Validation / Negative |
| **Steps** | 1. Enter GSTIN__c = `27AAB`<br>2. Save |
| **Expected Result** | Validation error on GSTIN__c field |
| **Status** | |

---

### TC-ACC-014: GSTIN Validation - Blank Value (Should Pass)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-014 |
| **Priority** | Medium |
| **Type** | Validation / Positive |
| **Steps** | 1. Leave GSTIN__c **blank**<br>2. Save |
| **Expected Result** | Record saves successfully. GSTIN is optional. |
| **Status** | |

---

### TC-ACC-015: PAN Validation - Valid 10-Character Format

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-015 |
| **Priority** | High |
| **Type** | Validation |
| **Steps** | 1. Enter PAN__c = `ABCDE1234F`<br>2. Save |
| **Expected Result** | Record saves successfully. No validation error. |
| **Regex Pattern** | `[A-Z]{5}[0-9]{4}[A-Z]{1}` |
| **Status** | |

---

### TC-ACC-016: PAN Validation - Invalid Format (Numbers First)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-016 |
| **Priority** | High |
| **Type** | Validation / Negative |
| **Steps** | 1. Enter PAN__c = `12345ABCDE`<br>2. Save |
| **Expected Result** | Error on PAN__c field: **"Invalid PAN format. Expected format: 5 letters + 4 digits + 1 letter"** |
| **Status** | |

---

### TC-ACC-017: PAN Validation - Invalid Format (Lowercase Letters)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-017 |
| **Priority** | Medium |
| **Type** | Validation / Negative |
| **Steps** | 1. Enter PAN__c = `abcde1234f`<br>2. Save |
| **Expected Result** | Validation error on PAN__c field (regex requires uppercase `[A-Z]`) |
| **Status** | |

---

### TC-ACC-018: PAN Validation - Blank Value (Should Pass)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-018 |
| **Priority** | Medium |
| **Type** | Validation / Positive |
| **Steps** | 1. Leave PAN__c **blank**<br>2. Save |
| **Expected Result** | Record saves successfully. PAN is optional. |
| **Status** | |

---

### TC-ACC-019: Credit Limit - Negative Value Rejected

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-019 |
| **Priority** | High |
| **Type** | Validation / Negative |
| **Steps** | 1. Enter Credit_Limit__c = `-5000`<br>2. Save |
| **Expected Result** | Error on Credit_Limit__c field: **"Credit Limit cannot be negative. Please enter a value of 0 or greater."** |
| **Status** | |

---

### TC-ACC-020: Credit Limit - Zero Value Accepted

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-020 |
| **Priority** | Medium |
| **Type** | Validation / Boundary |
| **Steps** | 1. Enter Credit_Limit__c = `0`<br>2. Save |
| **Expected Result** | Record saves successfully |
| **Status** | |

---

### TC-ACC-021: Credit Limit - Positive Value Accepted

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-021 |
| **Priority** | Medium |
| **Type** | Validation / Positive |
| **Steps** | 1. Enter Credit_Limit__c = `50000`<br>2. Save |
| **Expected Result** | Record saves successfully |
| **Status** | |

---

### TC-ACC-022: Outlet Type Required for Retailer Record Type

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-022 |
| **Priority** | High |
| **Type** | Validation / Negative |
| **Precondition** | Record Type = Retailer |
| **Steps** | 1. Create new Account with Record Type = **Retailer**<br>2. Enter Account Name<br>3. Leave Outlet_Type__c **blank**<br>4. Save |
| **Expected Result** | Error on Outlet_Type__c field: **"Outlet Type is required for Retailer accounts. Please select an outlet type."** |
| **Status** | |

---

### TC-ACC-023: Outlet Type NOT Required for Non-Retailer Record Types

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-023 |
| **Priority** | High |
| **Type** | Validation / Positive |
| **Steps** | 1. Create new Account with Record Type = **Distributor**<br>2. Enter Account Name<br>3. Leave Outlet_Type__c **blank**<br>4. Save |
| **Expected Result** | Record saves successfully. Validation rule only fires for RecordType.DeveloperName = "Retailer". |
| **Status** | |

---

## 5. Beat Assignment & Outlet Count Rollup

### TC-ACC-024: Assign Beat - Total Outlets Count Increments

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-024 |
| **Priority** | High |
| **Type** | Functional / Automation |
| **Precondition** | Beat "Beat-001" exists with `Total_Outlets__c` = **5** |
| **Steps** | 1. Create a new Account<br>2. Set Beat__c = **Beat-001**<br>3. Save<br>4. Navigate to Beat-001 record |
| **Expected Result** | Beat-001.`Total_Outlets__c` = **6** (incremented by 1) |
| **Status** | |

---

### TC-ACC-025: Transfer Beat - Counts Update on Both Old and New Beats

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-025 |
| **Priority** | High |
| **Type** | Functional / Automation |
| **Precondition** | Account assigned to "Beat-001" (count=6). "Beat-002" exists (count=3). |
| **Steps** | 1. Open the Account record<br>2. Edit Beat__c from **Beat-001** to **Beat-002**<br>3. Save<br>4. Verify both Beat records |
| **Expected Result** | - Beat-001.`Total_Outlets__c` = **5** (decremented)<br>- Beat-002.`Total_Outlets__c` = **4** (incremented) |
| **Status** | |

---

### TC-ACC-026: Remove Beat Assignment - Count Decrements

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-026 |
| **Priority** | High |
| **Type** | Functional / Automation |
| **Precondition** | Account assigned to "Beat-001" (count=6) |
| **Steps** | 1. Open the Account record<br>2. Clear the Beat__c field (set to blank)<br>3. Save<br>4. Verify Beat-001 record |
| **Expected Result** | Beat-001.`Total_Outlets__c` = **5** (decremented by 1) |
| **Status** | |

---

### TC-ACC-027: Delete Account - Beat Count Decrements

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-027 |
| **Priority** | High |
| **Type** | Functional / Automation |
| **Precondition** | Account assigned to "Beat-001" (count=6) |
| **Steps** | 1. Delete the Account record<br>2. Verify Beat-001 record |
| **Expected Result** | Beat-001.`Total_Outlets__c` = **5** (decremented by 1) |
| **Status** | |

---

### TC-ACC-028: Inactive Account Excluded from Beat Count

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-028 |
| **Priority** | High |
| **Type** | Functional / Automation |
| **Precondition** | Account assigned to "Beat-001" with Is_Active__c = true (count includes this account) |
| **Steps** | 1. Open the Account record<br>2. Set Is_Active__c = **false**<br>3. Save<br>4. Verify Beat-001 record |
| **Expected Result** | Beat-001.`Total_Outlets__c` decrements (only counts active accounts where Is_Active__c = true) |
| **Status** | |

---

## 6. Credit Utilization Tracking

### TC-ACC-029: Credit Utilized Updates from Unpaid Invoices

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-029 |
| **Priority** | Critical |
| **Type** | Functional / Automation |
| **Precondition** | Account exists with Credit_Limit__c = 100,000 and no existing invoices |
| **Steps** | 1. Create Invoice-1 for this Account with Balance_Due__c = **25,000**<br>2. Create Invoice-2 for this Account with Balance_Due__c = **15,000**<br>3. Navigate to the Account record |
| **Expected Result** | - `Credit_Utilized__c` = **40,000**<br>- `Outstanding_Balance__c` = **40,000** |
| **Status** | |

---

### TC-ACC-030: Cancelled Invoice Excluded from Credit Utilization

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-030 |
| **Priority** | Critical |
| **Type** | Functional / Automation |
| **Precondition** | Account with 2 invoices (total Credit_Utilized = 40,000). Invoice-1 Balance_Due = 25,000. |
| **Steps** | 1. Open Invoice-1<br>2. Change status to **Cancelled**<br>3. Save<br>4. Navigate to Account record |
| **Expected Result** | `Credit_Utilized__c` = **15,000** (25,000 from cancelled invoice excluded) |
| **Status** | |

---

### TC-ACC-031: Fully Paid Invoice Excluded from Credit Utilization

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-031 |
| **Priority** | Critical |
| **Type** | Functional / Automation |
| **Precondition** | Account with unpaid Invoice (Balance_Due = 15,000) |
| **Steps** | 1. Record full payment against the Invoice<br>2. Invoice status changes to **Fully Paid**, Balance_Due = 0<br>3. Navigate to Account record |
| **Expected Result** | `Credit_Utilized__c` decreases by 15,000. Outstanding_Balance__c decreases accordingly. |
| **Status** | |

---

### TC-ACC-032: Credit Utilization Percentage Calculation

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-032 |
| **Priority** | High |
| **Type** | Functional / Calculation |
| **Precondition** | Account with Credit_Limit__c = 100,000 and Credit_Utilized__c = 85,000 |
| **Steps** | 1. Open Account record<br>2. View Outlet 360 component<br>3. Check Credit Utilization section |
| **Expected Result** | - Utilization percentage = **85%**<br>- Progress bar shown in **red** color (>80% threshold)<br>- Displays: Utilized 85,000 / Limit 100,000<br>- Available credit = 15,000 |
| **Status** | |

---

## 7. Last Activity Auto-Tracking

### TC-ACC-033: Last Order Date and Value Update on New Sales Order

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-033 |
| **Priority** | High |
| **Type** | Functional / Automation |
| **Precondition** | Account exists with no previous orders |
| **Steps** | 1. Create a new Sales Order for this Account<br>2. Set Order Date = **today**<br>3. Set Order Amount = **12,500**<br>4. Save the Sales Order<br>5. Navigate to the Account record |
| **Expected Result** | - `Last_Order_Date__c` = **today's date**<br>- `Last_Order_Value__c` = **12,500** |
| **Status** | |

---

### TC-ACC-034: Last Order Value Updates to Most Recent Order

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-034 |
| **Priority** | High |
| **Type** | Functional / Automation |
| **Precondition** | Account with existing order (Last_Order_Value = 5,000) |
| **Steps** | 1. Create a new Sales Order for this Account with amount = **8,000**<br>2. Save<br>3. Navigate to Account record |
| **Expected Result** | `Last_Order_Value__c` = **8,000** (reflects most recent order, not old 5,000) |
| **Status** | |

---

### TC-ACC-035: Last Visit Date Updates on Visit Completion

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-035 |
| **Priority** | High |
| **Type** | Functional / Automation |
| **Precondition** | Account exists. Visit record created for this Account. |
| **Steps** | 1. Open the Visit record<br>2. Mark Visit as **Completed**<br>3. Save<br>4. Navigate to Account record |
| **Expected Result** | `Last_Visit_Date__c` = Visit completion date |
| **Status** | |

---

## 8. Outlet 360-Degree View - LWC Component

### TC-ACC-036: 360 View - Header Information Display

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-036 |
| **Priority** | High |
| **Type** | UI / Display |
| **Precondition** | Navigate to a Retailer Account record page that has the `outletThreeSixty` LWC component |
| **Steps** | 1. Open the Account record page<br>2. Observe the header section of the 360 view component |
| **Expected Result** | Header displays all of the following:<br>- **Account Name** (prominent)<br>- **Outlet Class badge** (A/B/C/D)<br>- **Active/Inactive status** indicator<br>- **Channel** (GT/MT/E-Commerce)<br>- **Outlet Type** (Grocery/Medical/etc.)<br>- **Record Type** name<br>- **Owner Name**<br>- **Phone**<br>- **GSTIN** (if populated)<br>- **PAN** (if populated)<br>- **Beat** name (lookup)<br>- **Territory** name (lookup)<br>- **Address** with billing details |
| **Status** | |

---

### TC-ACC-037: 360 View - KPI Tiles Accuracy (6 Tiles)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-037 |
| **Priority** | Critical |
| **Type** | UI / Data Accuracy |
| **Precondition** | Account with known orders, collections, and visits in the current month. Manually calculate expected values. |
| **Steps** | 1. Open Account record page<br>2. Observe 6 KPI tiles in the 360 view |
| **Expected Result** | Tile 1: **MTD Orders** - Sum of current month order values + order count (excludes Cancelled/Rejected)<br>Tile 2: **Outstanding Balance** - Sum of unpaid invoice Balance_Due__c (highlighted if overdue invoices exist)<br>Tile 3: **MTD Collection** - Sum of current month collection amounts (excludes Cancelled)<br>Tile 4: **Average Order Value** - Average order value over last 3 months<br>Tile 5: **MTD Visit Count** - Count of completed visits this month<br>Tile 6: **Visit Frequency** - Weekly/Bi-Weekly/Monthly |
| **Verification** | Cross-check each tile value against source records using reports |
| **Status** | |

---

### TC-ACC-038: 360 View - Credit Utilization Progress Bar (Green)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-038 |
| **Priority** | High |
| **Type** | UI / Display |
| **Precondition** | Account with Credit_Limit__c = 100,000 and Credit_Utilized__c = 45,000 |
| **Steps** | 1. Open 360 view<br>2. Observe Credit Utilization section |
| **Expected Result** | - Progress bar at **45%**<br>- Bar color = **Green** (0-60% threshold)<br>- Shows "45,000 utilized" and "55,000 available"<br>- Limit displayed as 100,000 |
| **Status** | |

---

### TC-ACC-039: 360 View - Credit Utilization Bar Color Thresholds

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-039 |
| **Priority** | High |
| **Type** | UI / Display |
| **Steps** | Test with 3 different accounts:<br>a) Utilization = **50%** (50,000 / 100,000)<br>b) Utilization = **70%** (70,000 / 100,000)<br>c) Utilization = **85%** (85,000 / 100,000) |
| **Expected Result** | a) 50% → **Green** bar color<br>b) 70% → **Orange** bar color (60-80% range)<br>c) 85% → **Red** bar color (>80% range) |
| **Status** | |

---

### TC-ACC-040: 360 View - Orders Tab

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-040 |
| **Priority** | High |
| **Type** | UI / Data |
| **Precondition** | Account with 5+ Sales Orders of varying statuses |
| **Steps** | 1. Open 360 view<br>2. Click **Orders** tab |
| **Expected Result** | - Table columns: **Order #, Date, Items (count), Amount, Status**<br>- Maximum **20** records displayed<br>- Sorted by **date descending** (newest first)<br>- **Excludes** orders with status = Cancelled or Rejected<br>- Order # is **clickable** and navigates to the Sales Order record page<br>- Order line items count is accurate |
| **Status** | |

---

### TC-ACC-041: 360 View - Collections Tab

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-041 |
| **Priority** | High |
| **Type** | UI / Data |
| **Precondition** | Account with 5+ Collection records across different payment modes |
| **Steps** | 1. Open 360 view<br>2. Click **Collections** tab |
| **Expected Result** | **Summary Cards at top:**<br>- Total Outstanding amount<br>- MTD Collections total<br>- Overdue Amount<br><br>**Table columns:** Receipt #, Date, Amount, Payment Mode, Invoice (link), Status<br>- Payment modes shown: Cash, Cheque, UPI, On Account<br>- For **Cheque** payments: Cheque Number, Bank Name, Cheque Date displayed<br>- Excludes Cancelled collections |
| **Status** | |

---

### TC-ACC-042: 360 View - Visits Tab

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-042 |
| **Priority** | High |
| **Type** | UI / Data |
| **Precondition** | Account with 5+ Visit records (mix of Completed and In-Progress) |
| **Steps** | 1. Open 360 view<br>2. Click **Visits** tab |
| **Expected Result** | Table columns: **Date, Salesperson, Check-In Time, Duration, Productive (Yes/No), Order Value**<br>- Duration formatted as hours and minutes (e.g., "1h 30m")<br>- Productive column shows Yes or No<br>- Sorted by date descending |
| **Status** | |

---

### TC-ACC-043: 360 View - Schemes Tab

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-043 |
| **Priority** | High |
| **Type** | UI / Data |
| **Precondition** | Active schemes exist that match the Account's Channel and Outlet Type. Also create schemes that do NOT match (to verify filtering). |
| **Steps** | 1. Open 360 view<br>2. Click **Schemes** tab |
| **Expected Result** | - Displayed as **cards** (not table)<br>- Each card shows: Scheme Name, Type Badge, Code, Description, Date Range, Max Discount, Budget Remaining<br>- **Type badges** with distinct styling: Percentage Discount, Flat Discount, Buy X Get Y Free, Slab Discount, Volume Discount<br>- Only shows schemes where: status = Active, current date within start/end dates, Channel and Outlet Type match the account<br>- Non-matching schemes are **NOT** displayed |
| **Status** | |

---

### TC-ACC-044: 360 View - Stock Tab

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-044 |
| **Priority** | High |
| **Type** | UI / Data |
| **Precondition** | Distributor_Stock__c records exist for this Account with varying quantities |
| **Steps** | 1. Open 360 view<br>2. Click **Stock** tab |
| **Expected Result** | Table columns: **Product, SKU, Closing Qty, Sold, Batch, Expiry, Last Updated**<br><br>Closing Qty color coding:<br>- **Red** (Low): Quantity <= 10<br>- **Orange** (Medium): Quantity <= 50<br>- **Green** (High): Quantity > 50 |
| **Status** | |

---

### TC-ACC-045: 360 View - Timeline Tab

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-045 |
| **Priority** | High |
| **Type** | UI / Data |
| **Precondition** | Account with Orders, Visits, and Collections created on different dates |
| **Steps** | 1. Open 360 view<br>2. Click **Timeline** tab |
| **Expected Result** | - **Unified chronological feed** combining Orders, Visits, and Collections<br>- Each entry shows: **Icon** (type-specific), Activity Type, Title, Description, Date, Amount, Status Badge<br>- Maximum **30** entries displayed<br>- Sorted by **date descending** (newest first)<br>- All three activity types (Order, Visit, Collection) are interleaved correctly by date |
| **Status** | |

---

### TC-ACC-046: 360 View - Map Display with Geo-Coordinates

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-046 |
| **Priority** | Medium |
| **Type** | UI / Display |
| **Precondition** | Account with BillingLatitude and BillingLongitude populated (e.g., 19.0760, 72.8777 for Mumbai) and BillingStreet, BillingCity, BillingState populated |
| **Steps** | 1. Open 360 view<br>2. Observe header section for map |
| **Expected Result** | - Map displays with a **marker** at the correct coordinates<br>- Address text shown alongside/below the map |
| **Status** | |

---

### TC-ACC-047: 360 View - Inactive Account Visual Indicator

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-047 |
| **Priority** | Medium |
| **Type** | UI / Display |
| **Precondition** | Account with Is_Active__c = **false** |
| **Steps** | 1. Open Account record page<br>2. Observe 360 view header |
| **Expected Result** | Clear **visual indicator** (badge, color, or icon) showing the account is **Inactive** |
| **Status** | |

---

## 9. New Outlet Onboarding Flow

### TC-ACC-048: Complete New Outlet Onboarding Flow Successfully

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-048 |
| **Priority** | Critical |
| **Type** | Functional / End-to-End |
| **Precondition** | User has access to the "OVE_NewOutlet_Onboarding" screen flow |
| **Steps** | 1. Launch the **OVE_NewOutlet_Onboarding** flow<br>2. Enter Outlet Name = "QA Test Grocery"<br>3. Enter Phone = "9876543210"<br>4. Enter Address: Street = "MG Road", City = "Mumbai"<br>5. Select Outlet Type = **Grocery**<br>6. Select Outlet Class = **B**<br>7. Select Channel = **GT** (General Trade)<br>8. Click **Submit / Finish** |
| **Expected Result** | - New Account record created successfully<br>- All entered fields populated correctly<br>- `Is_Active__c` = **true** (trigger default)<br>- `Visit_Frequency__c` = **Bi-Weekly** (Class B trigger default)<br>- `Credit_Utilized__c` = **0** (trigger default)<br>- Record Type = appropriate type for flow |
| **Status** | |

---

### TC-ACC-049: Flow - Verify Outlet Type Screen Choices

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-049 |
| **Priority** | Medium |
| **Type** | UI / Display |
| **Steps** | 1. Launch the onboarding flow<br>2. Navigate to the Outlet Type selection screen<br>3. Inspect available choices |
| **Expected Result** | Exactly these options available:<br>- **Grocery**<br>- **Medical**<br>- **Hardware**<br>- **General Store** |
| **Status** | |

---

### TC-ACC-050: Flow - Verify Outlet Class Screen Choices with Labels

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-050 |
| **Priority** | Medium |
| **Type** | UI / Display |
| **Steps** | 1. Launch the onboarding flow<br>2. Navigate to the Outlet Class selection screen<br>3. Inspect available choices and their labels |
| **Expected Result** | Options with descriptive labels:<br>- **A** = Premium<br>- **B** = Standard<br>- **C** = Economy<br>- **D** = Small |
| **Status** | |

---

### TC-ACC-051: Flow - Verify Channel Screen Choices

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-051 |
| **Priority** | Medium |
| **Type** | UI / Display |
| **Steps** | 1. Launch the onboarding flow<br>2. Navigate to the Channel selection screen<br>3. Inspect available choices |
| **Expected Result** | Options:<br>- **GT** = General Trade<br>- **MT** = Modern Trade |
| **Status** | |

---

## 10. List Views

### TC-ACC-052: "My Accounts" List View - Shows Only Owned Records

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-052 |
| **Priority** | High |
| **Type** | Functional / UI |
| **Precondition** | Current user owns some accounts. Other users own other accounts. |
| **Steps** | 1. Navigate to **Accounts** tab<br>2. Select list view = **My Accounts** |
| **Expected Result** | - Shows **only** accounts owned by the current logged-in user<br>- Columns displayed: Name, Record Type, Outlet Type, Outlet Class, Channel, Beat, Outstanding Balance, Last Visit Date, Last Order Date, Is Active<br>- No accounts owned by other users appear |
| **Status** | |

---

### TC-ACC-053: "All Distributors" List View - Filters by Record Type

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-053 |
| **Priority** | High |
| **Type** | Functional / UI |
| **Precondition** | Mix of Distributor and non-Distributor accounts exist |
| **Steps** | 1. Navigate to **Accounts** tab<br>2. Select list view = **All Distributors** |
| **Expected Result** | - Shows **only** accounts with Record Type = **Distributor**<br>- Columns: Name, Channel, Territory, GSTIN, Credit Limit, Credit Utilized, Outstanding Balance, Phone, Is Active<br>- Retailer / Modern Trade / Super Stockist accounts do NOT appear |
| **Status** | |

---

### TC-ACC-054: "All Retailers" List View - Filters by Record Type

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-054 |
| **Priority** | High |
| **Type** | Functional / UI |
| **Precondition** | Mix of Retailer and non-Retailer accounts exist |
| **Steps** | 1. Navigate to **Accounts** tab<br>2. Select list view = **All Retailers** |
| **Expected Result** | - Shows **only** accounts with Record Type = **Retailer**<br>- Columns: Name, Outlet Type, Outlet Class, Channel, Beat, Territory, Phone, Outstanding Balance, Is Active, Last Visit Date<br>- Non-Retailer accounts do NOT appear |
| **Status** | |

---

### TC-ACC-055: "Inactive Accounts" List View - Filters by Active Status

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-055 |
| **Priority** | High |
| **Type** | Functional / UI |
| **Precondition** | Both active (Is_Active = true) and inactive (Is_Active = false) accounts exist |
| **Steps** | 1. Navigate to **Accounts** tab<br>2. Select list view = **Inactive Accounts** |
| **Expected Result** | - Shows **only** accounts where Is_Active__c = **false**<br>- Columns: Name, Record Type, Outlet Type, Outlet Class, Beat, Territory, Last Visit Date, Last Order Date, Phone<br>- Active accounts do NOT appear |
| **Status** | |

---

## 11. Page Layouts by Record Type

### TC-ACC-056: Retailer Page Layout - Field Visibility and Sections

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-056 |
| **Priority** | High |
| **Type** | UI / Layout |
| **Steps** | 1. Open a **Retailer** account record in **Edit** mode<br>2. Verify sections and fields visible |
| **Expected Result** | **Section 1 - Outlet Information (2 columns):**<br>- Name (Required)<br>- Owner_Name__c<br>- Outlet_Type__c<br>- Outlet_Class__c<br>- Channel__c<br>- OwnerId<br>- Phone<br>- RecordTypeId (Read-only)<br>- Is_Active__c<br>- AccountNumber<br><br>**Section 2 - Territory & Beat Assignment:**<br>- Beat__c<br>- Territory__c<br>- Visit_Frequency__c<br>- Region__c<br><br>**Section 3 - Address Information:**<br>- BillingAddress<br>- ShippingAddress |
| **Status** | |

---

### TC-ACC-057: Distributor Page Layout - Field Visibility and KYC Section

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-057 |
| **Priority** | High |
| **Type** | UI / Layout |
| **Steps** | 1. Open a **Distributor** account record in **Edit** mode<br>2. Verify sections and fields visible |
| **Expected Result** | **Section 1 - Distributor Information:**<br>- Name (Required)<br>- Owner_Name__c<br>- ParentId (Parent Account)<br>- Channel__c<br>- OwnerId<br>- Phone<br>- RecordTypeId (Read-only)<br>- Is_Active__c<br>- AccountNumber<br><br>**Section 2 - Territory Assignment:**<br>- Territory__c<br>- Region__c<br><br>**Section 3 - Address Information:**<br>- BillingAddress<br>- ShippingAddress<br><br>**Section 4 - KYC & Compliance:**<br>- GSTIN__c<br>- PAN__c<br>- Drug_License_No__c<br>- FSSAI_License_No__c |
| **Status** | |

---

## 12. Compact Layout

### TC-ACC-058: SFA Account Compact Layout in Highlights Panel

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-058 |
| **Priority** | Medium |
| **Type** | UI / Layout |
| **Steps** | 1. Open any Account record<br>2. Observe the **highlights panel** at the top of the record page (compact layout) |
| **Expected Result** | The compact layout (SFA Account Compact) displays these 7 fields:<br>1. **Name**<br>2. **Outlet_Class__c**<br>3. **Channel__c**<br>4. **Phone**<br>5. **Beat__c**<br>6. **Is_Active__c**<br>7. **Outstanding_Balance__c** |
| **Status** | |

---

## 13. Field-Level Picklist Values

### TC-ACC-059: Channel Picklist - Verify Available Values

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-059 |
| **Priority** | Medium |
| **Type** | Data / Configuration |
| **Steps** | 1. Open any Account in edit mode<br>2. Click on Channel__c dropdown |
| **Expected Result** | Available options: **GT** (General Trade), **MT** (Modern Trade), **E-Commerce** |
| **Status** | |

---

### TC-ACC-060: Outlet Type Picklist - Verify Available Values

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-060 |
| **Priority** | Medium |
| **Type** | Data / Configuration |
| **Steps** | 1. Open a Retailer Account in edit mode<br>2. Click on Outlet_Type__c dropdown |
| **Expected Result** | Available options: **Grocery, Medical, Hardware, General Store, Modern Trade** |
| **Status** | |

---

### TC-ACC-061: Outlet Class Picklist - Verify Restricted Values

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-061 |
| **Priority** | Medium |
| **Type** | Data / Configuration |
| **Steps** | 1. Open any Account in edit mode<br>2. Click on Outlet_Class__c dropdown |
| **Expected Result** | Available options (restricted picklist): **A, B, C, D** |
| **Status** | |

---

### TC-ACC-062: Visit Frequency Picklist - Verify Restricted Values

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-062 |
| **Priority** | Medium |
| **Type** | Data / Configuration |
| **Steps** | 1. Open any Account in edit mode<br>2. Click on Visit_Frequency__c dropdown |
| **Expected Result** | Available options (restricted picklist): **Weekly, Bi-Weekly, Monthly** |
| **Status** | |

---

## 14. Boundary & Negative Testing

### TC-ACC-063: Required Field - Account Name Blank

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-063 |
| **Priority** | High |
| **Type** | Negative / Boundary |
| **Steps** | 1. Click New Account<br>2. Select any Record Type<br>3. Leave **Name** field blank<br>4. Click Save |
| **Expected Result** | Standard Salesforce required field validation error: **"Required fields are missing: [Account Name]"** |
| **Status** | |

---

### TC-ACC-064: GSTIN - Valid Boundary (Exactly 15 Characters, Correct Pattern)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-064 |
| **Priority** | Medium |
| **Type** | Boundary |
| **Steps** | 1. Enter GSTIN__c = `07AAACP1234M1Z5`<br>2. Save |
| **Expected Result** | Record saves successfully (valid 15-char GSTIN matching regex) |
| **Status** | |

---

### TC-ACC-065: PAN - Valid Boundary (Exactly 10 Characters, Correct Pattern)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-065 |
| **Priority** | Medium |
| **Type** | Boundary |
| **Steps** | 1. Enter PAN__c = `ZZZZZ9999Z`<br>2. Save |
| **Expected Result** | Record saves successfully (valid 10-char PAN matching regex) |
| **Status** | |

---

### TC-ACC-066: Credit Limit - Very Large Positive Value

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-066 |
| **Priority** | Low |
| **Type** | Boundary |
| **Steps** | 1. Enter Credit_Limit__c = `99999999`<br>2. Save |
| **Expected Result** | Record saves successfully (no upper limit validation rule exists) |
| **Status** | |

---

### TC-ACC-067: Multiple Validation Errors Triggered Simultaneously

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-067 |
| **Priority** | Medium |
| **Type** | Negative / Multi-error |
| **Precondition** | Create/Edit Account with Record Type = Retailer |
| **Steps** | 1. Leave Outlet_Type__c **blank**<br>2. Enter GSTIN__c = `INVALIDGSTIN`<br>3. Enter PAN__c = `INVALIDPAN`<br>4. Enter Credit_Limit__c = `-1000`<br>5. Click Save |
| **Expected Result** | **Multiple** error messages displayed simultaneously:<br>- Outlet Type required for Retailer<br>- Invalid GSTIN format<br>- Invalid PAN format<br>- Credit Limit cannot be negative |
| **Status** | |

---

## 15. Geo-Location & Check-In

### TC-ACC-068: Geofence Radius Default Value

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-068 |
| **Priority** | Medium |
| **Type** | Functional / Default |
| **Steps** | 1. Create a new Account<br>2. Check the value of Geofence_Radius__c |
| **Expected Result** | `Geofence_Radius__c` = **0** (default value) |
| **Status** | |

---

### TC-ACC-069: Visit Check-In - Within Geofence Radius (Success)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-069 |
| **Priority** | High |
| **Type** | Functional / Geo-Location |
| **Precondition** | Account with:<br>- BillingLatitude = 19.0760<br>- BillingLongitude = 72.8777<br>- Geofence_Radius__c = **200** (meters) |
| **Steps** | 1. On mobile device (or simulated location), position within **200 meters** of the coordinates<br>2. Initiate Visit Check-In for this Account |
| **Expected Result** | Check-in succeeds. Visit record created with Check-In time and location. |
| **Status** | |

---

### TC-ACC-070: Visit Check-In - Outside Geofence Radius (Warning/Failure)

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-070 |
| **Priority** | High |
| **Type** | Functional / Geo-Location / Negative |
| **Precondition** | Same Account as TC-ACC-069 (Geofence_Radius = 200m) |
| **Steps** | 1. Position device **more than 200 meters** away from the account coordinates<br>2. Attempt Visit Check-In for this Account |
| **Expected Result** | Warning or error message indicating the user is **outside the geofence area**. Check-in may be blocked or flagged. |
| **Status** | |

---

## 16. Application Navigation

### TC-ACC-071: Account Tab Visible in Field Sales CRM App

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-071 |
| **Priority** | High |
| **Type** | UI / Navigation |
| **Steps** | 1. Open the **Field Sales CRM** Lightning app<br>2. Inspect the navigation bar at the top |
| **Expected Result** | **Account** tab (standard-Account) is visible in the app navigation and is clickable. Clicking it opens the Account list view. |
| **Status** | |

---

### TC-ACC-072: Account Records Accessible on Mobile Form Factor

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-072 |
| **Priority** | High |
| **Type** | UI / Mobile |
| **Precondition** | Field Sales CRM app is configured for both Large (desktop) and Small (mobile) form factors |
| **Steps** | 1. Open Salesforce Mobile App<br>2. Navigate to **Field Sales CRM** app<br>3. Tap on **Accounts** |
| **Expected Result** | - Account records are accessible on mobile<br>- List views load correctly<br>- Account detail page renders properly<br>- 360 view component renders (if added to mobile page) |
| **Status** | |

---

## 17. Integration Tests - Cross Module

### TC-ACC-073: End-to-End: Account -> Sales Order -> Invoice -> Credit Utilization

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-073 |
| **Priority** | Critical |
| **Type** | Integration / End-to-End |
| **Precondition** | Account with Credit_Limit__c = 50,000 and no existing invoices |
| **Steps** | 1. Create a **Sales Order** for the Account (Amount = 20,000)<br>2. Process the Sales Order to generate an **Invoice** with Balance_Due__c = 20,000<br>3. Navigate to the Account record<br>4. Verify Credit and Order fields |
| **Expected Result** | - `Credit_Utilized__c` = **20,000**<br>- `Outstanding_Balance__c` = **20,000**<br>- `Last_Order_Date__c` = Sales Order date<br>- `Last_Order_Value__c` = 20,000<br>- 360 view KPI tiles reflect updated values |
| **Status** | |

---

### TC-ACC-074: End-to-End: Account -> Visit -> Last Visit Date Update

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-074 |
| **Priority** | High |
| **Type** | Integration / End-to-End |
| **Precondition** | Account exists with Last_Visit_Date = null or an older date |
| **Steps** | 1. Create a **Visit** record for the Account<br>2. Mark the Visit as **Completed** with today's date<br>3. Navigate to the Account record |
| **Expected Result** | - `Last_Visit_Date__c` = today's date (visit completion date)<br>- 360 view Visits tab shows the new visit<br>- MTD Visit Count KPI increments |
| **Status** | |

---

### TC-ACC-075: End-to-End: Account -> Collection -> Outstanding Balance Reduces

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-075 |
| **Priority** | Critical |
| **Type** | Integration / End-to-End |
| **Precondition** | Account has Outstanding_Balance__c = 40,000 from unpaid invoices |
| **Steps** | 1. Create a **Collection** (payment receipt) of **15,000** against one of the unpaid invoices<br>2. Invoice Balance_Due reduces accordingly<br>3. Navigate to the Account record |
| **Expected Result** | - `Outstanding_Balance__c` decreases (approx. 25,000 remaining)<br>- `Credit_Utilized__c` decreases accordingly<br>- 360 view Collections tab shows the new receipt<br>- MTD Collection KPI tile updates |
| **Status** | |

---

## 18. Data Integrity

### TC-ACC-076: Delete Beat Record - Account Beat Field Set to Null

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-076 |
| **Priority** | High |
| **Type** | Data Integrity |
| **Precondition** | Beat "Beat-X" has 3 Accounts assigned to it |
| **Steps** | 1. Delete the **Beat-X** record<br>2. Open each of the 3 Account records that were assigned to Beat-X |
| **Expected Result** | All 3 Accounts: `Beat__c` = **null** (SetNull delete behavior configured on lookup) |
| **Status** | |

---

### TC-ACC-077: Delete Territory Record - Account Territory Field Set to Null

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-077 |
| **Priority** | High |
| **Type** | Data Integrity |
| **Precondition** | Territory "Territory-X" has 2 Accounts assigned |
| **Steps** | 1. Delete the **Territory-X** record<br>2. Open each Account that was assigned to Territory-X |
| **Expected Result** | All Accounts: `Territory__c` = **null** (SetNull delete behavior) |
| **Status** | |

---

### TC-ACC-078: Bulk Account Creation (50+ Records) - Trigger Handles Bulk

| Field | Value |
|-------|-------|
| **Test Case ID** | TC-ACC-078 |
| **Priority** | High |
| **Type** | Performance / Bulk |
| **Precondition** | Beat "Beat-Bulk" exists with known Total_Outlets__c. Prepare a CSV with 50+ Account records all assigned to Beat-Bulk. |
| **Steps** | 1. Use **Data Loader** or **Data Import Wizard**<br>2. Import 50+ Account records simultaneously, all assigned to Beat-Bulk<br>3. Verify Beat-Bulk record<br>4. Spot-check 5-10 imported Accounts |
| **Expected Result** | - All 50+ records created successfully (no governor limit errors)<br>- Each Account has: `Is_Active__c` = true, `Credit_Utilized__c` = 0, `Visit_Frequency__c` auto-assigned based on Outlet Class<br>- Beat-Bulk.`Total_Outlets__c` incremented by the correct count<br>- No trigger errors in debug logs |
| **Status** | |

---

## 19. Test Summary

| # | Category | Test Case IDs | Count | Priority Breakdown |
|---|----------|--------------|-------|-------------------|
| 1 | Account Creation & Defaults | TC-ACC-001 to TC-ACC-004 | **4** | 4 High |
| 2 | Visit Frequency Auto-Assignment | TC-ACC-005 to TC-ACC-010 | **6** | 6 High |
| 3 | Validation Rules | TC-ACC-011 to TC-ACC-023 | **13** | 7 High, 6 Medium |
| 4 | Beat Assignment & Outlet Count | TC-ACC-024 to TC-ACC-028 | **5** | 5 High |
| 5 | Credit Utilization Tracking | TC-ACC-029 to TC-ACC-032 | **4** | 2 Critical, 2 High |
| 6 | Last Activity Auto-Tracking | TC-ACC-033 to TC-ACC-035 | **3** | 3 High |
| 7 | Outlet 360 View (LWC) | TC-ACC-036 to TC-ACC-047 | **12** | 1 Critical, 9 High, 2 Medium |
| 8 | New Outlet Onboarding Flow | TC-ACC-048 to TC-ACC-051 | **4** | 1 Critical, 3 Medium |
| 9 | List Views | TC-ACC-052 to TC-ACC-055 | **4** | 4 High |
| 10 | Page Layouts | TC-ACC-056 to TC-ACC-057 | **2** | 2 High |
| 11 | Compact Layout | TC-ACC-058 | **1** | 1 Medium |
| 12 | Picklist Values | TC-ACC-059 to TC-ACC-062 | **4** | 4 Medium |
| 13 | Boundary & Negative Testing | TC-ACC-063 to TC-ACC-067 | **5** | 1 High, 3 Medium, 1 Low |
| 14 | Geo-Location & Check-In | TC-ACC-068 to TC-ACC-070 | **3** | 2 High, 1 Medium |
| 15 | Application Navigation | TC-ACC-071 to TC-ACC-072 | **2** | 2 High |
| 16 | Integration (Cross-Module) | TC-ACC-073 to TC-ACC-075 | **3** | 2 Critical, 1 High |
| 17 | Data Integrity | TC-ACC-076 to TC-ACC-078 | **3** | 3 High |
| | **TOTAL** | | **78** | **5 Critical, 52 High, 20 Medium, 1 Low** |

### Priority Definitions

| Priority | Definition | Testing Guidance |
|----------|-----------|-----------------|
| **Critical** | Core business functionality; defect blocks deployment | Must pass before UAT sign-off |
| **High** | Important functionality; defect impacts daily operations | Must pass before release |
| **Medium** | Standard functionality; defect has workaround available | Should pass before release |
| **Low** | Edge case; minimal business impact | Nice to have for release |

---

*End of QA Test Plan - Account Module*
