# QA Test Plan: GRN & Distributor Stock Module

**Module:** Inventory Management - Goods Receipt Notes & Distributor Stock
**Application:** FMCG CRM / SFA
**Version:** 1.0
**Date:** 2026-02-23
**Depends On:** Warehouse Stock Module (see `Warehouse_Stock_Testing_Guide.md`)

---

## 1. Module Overview

This document covers QA testing for two sub-modules not fully covered in the Warehouse Stock Testing Guide:

1. **GRN (Goods Receipt Note)** — Tracks receipt of dispatched goods against invoices at the warehouse, including line-level damaged/short quantity tracking.
2. **Distributor Stock** — Tracks distributor-level inventory snapshots (opening/closing stock, receipts, sales) for field sales management.

### Components Under Test

| Component | Type | Description |
|-----------|------|-------------|
| `GRN__c` | Custom Object | Parent record for goods receipt |
| `GRN_Line__c` | Custom Object | Line items with product-level receipt details |
| `INV_GRN_TriggerHandler` | Apex Trigger Handler | Auto-adds stock to warehouse on GRN receipt |
| `Distributor_Stock__c` | Custom Object | Distributor inventory snapshots |
| `INV_DistributorStock_TriggerHandler` | Apex Trigger Handler | Auto-calculates closing stock, manages "current" flag |
| `INV_StockDashboardController` | Apex Controller | Dashboard metrics and reporting |
| `stockDashboard` | LWC | Stock analytics and reporting dashboard |
| `FSCRM_Stock_Manager` | Permission Set | Access to GRN and Distributor Stock |

---

## 2. Prerequisites / Test Data Setup

### 2.1 Required Base Data

Ensure the following exist before starting (refer to Warehouse Stock Testing Guide for warehouse setup):

| # | Record | Details |
|---|--------|---------|
| 1 | Warehouse: MUM001 | Mumbai Central Warehouse, Active, Type: Central |
| 2 | Warehouse: DEL001 | Delhi Regional Depot, Active, Type: Regional |
| 3 | Product: WF001 | Wheat Flour 1kg |
| 4 | Product: RC005 | Rice 5kg |
| 5 | Product: SG002 | Sugar 2kg |
| 6 | Account (Distributor) | Any active Account record (e.g., "QA Distributor Pvt Ltd") |
| 7 | Invoice linked to MUM001 | Invoice with Warehouse__c = MUM001, Status: Confirmed or Dispatched |

### 2.2 User Profiles Required

| # | Profile / Permission Set | Purpose |
|---|--------------------------|---------|
| 1 | System Administrator | Full access for data setup |
| 2 | User with FSCRM_Stock_Manager | Test GRN and Distributor Stock CRUD |
| 3 | User with FSCRM_Field_Rep_Products | Read-only access verification |

---

## SECTION A: GRN Object & Field Validation Tests

---

### TC-GRN-A01: Create GRN — Happy Path

**Steps:**
1. Navigate to **GRN__c** tab → Click **New**
2. Enter:
   - Account: `QA Distributor Pvt Ltd`
   - Invoice: (select an existing Invoice linked to MUM001)
   - GRN Date: `Today`
   - Status: `Pending` (default)
   - Received By: `QA Tester`
3. Click **Save**

**Expected Result:**
- [ ] Record saved successfully
- [ ] Auto-number Name generated in format `GRN-XXXX`
- [ ] Status defaults to `Pending`
- [ ] Damaged Qty defaults to `0`
- [ ] Excess Qty defaults to `0`
- [ ] Short Qty defaults to `0`

---

### TC-GRN-A02: GRN Required Fields Validation

**Steps:**
1. Create GRN with blank Account → Save

**Expected Result:** Required field error for Account

2. Create GRN with blank GRN Date → Save

**Expected Result:** Required field error for GRN Date

3. Create GRN with blank Status → Save

**Expected Result:** Required field error for Status

---

### TC-GRN-A03: GRN Status Picklist Values

**Steps:**
1. Open any GRN record → Edit → Click Status dropdown

**Verify picklist values exist:**
- [ ] `Pending`
- [ ] `Received`
- [ ] `Partial`
- [ ] `Disputed`

---

### TC-GRN-A04: GRN — Delete Protection (Restrict Delete on Account)

**Steps:**
1. Create a GRN linked to an Account
2. Try to delete the Account

**Expected Result:** Delete blocked — `"Cannot delete Account because it has related GRN records"`

---

## SECTION B: GRN Line Item Tests

---

### TC-GRN-B01: Create GRN Line — Happy Path

**Steps:**
1. Open an existing GRN record (Status: Pending)
2. Navigate to the GRN Lines related list → Click **New**
3. Enter:
   - Product: `WF001 (Wheat Flour 1kg)`
   - Batch No: `BATCH-GRN-01`
   - Expiry Date: `2027-06-30`
   - Dispatched Qty: `100`
   - Received Qty: `95`
   - Damaged Qty: `3`
   - Short Qty: `2`
   - Notes: `"3 bags torn, 2 missing from shipment"`
4. Click **Save**

**Expected Result:**
- [ ] Record saved successfully
- [ ] GRN Line linked to parent GRN
- [ ] All quantities stored correctly

---

### TC-GRN-B02: GRN Line — Master-Detail Cascade Delete

**Steps:**
1. Create a GRN with 2 GRN Line items
2. Delete the parent GRN record

**Expected Result:**
- [ ] Parent GRN deleted
- [ ] Both child GRN Line records automatically deleted (cascade)

---

### TC-GRN-B03: GRN Line — Default Damaged Qty

**Steps:**
1. Create a GRN Line without entering Damaged Qty
2. Save

**Expected Result:**
- [ ] Damaged Qty defaults to `0`
- [ ] Short Qty defaults to `0`

---

### TC-GRN-B04: GRN Line — Multiple Products

**Steps:**
1. Open a GRN record
2. Add 3 GRN Lines with different products:

| Line | Product | Dispatched | Received | Damaged |
|------|---------|-----------|----------|---------|
| 1 | WF001 | 100 | 95 | 5 |
| 2 | RC005 | 200 | 200 | 0 |
| 3 | SG002 | 50 | 45 | 3 |

3. Save all lines

**Expected Result:** All 3 lines saved correctly under the parent GRN

---

### TC-GRN-B05: GRN Line — Expiry Date for FEFO Tracking

**Steps:**
1. Create GRN Line with:
   - Product: WF001
   - Batch No: `BATCH-FEFO-01`
   - Expiry Date: `2026-12-31`
2. Create another GRN Line with:
   - Product: WF001
   - Batch No: `BATCH-FEFO-02`
   - Expiry Date: `2026-06-30`
3. Save both

**Expected Result:**
- [ ] Both lines saved with different expiry dates
- [ ] When GRN is received, both batch entries should be created separately in Warehouse Stock

---

## SECTION C: GRN → Warehouse Stock Integration Tests

> **Note:** TC-B01 through TC-B03 in the Warehouse Stock Testing Guide cover the core GRN-to-stock flow. The tests below cover additional edge cases.

---

### TC-GRN-C01: GRN Received — Multi-Line Stock Addition

**Preconditions:**
- GRN with 3 lines (from TC-GRN-B04)
- Warehouse MUM001 linked via Invoice
- Note current stock levels for WF001, RC005, SG002

**Steps:**
1. Change GRN Status from `Pending` → `Received`
2. Click Save

**Verify for each product:**

| Product | Usable Qty (Received - Damaged) | On Hand Change | Transaction Created |
|---------|--------------------------------|----------------|---------------------|
| WF001 | 90 (95 - 5) | +90 | Yes, Inbound_GRN |
| RC005 | 200 (200 - 0) | +200 | Yes, Inbound_GRN |
| SG002 | 42 (45 - 3) | +42 | Yes, Inbound_GRN |

- [ ] 3 separate Stock_Transaction__c records created (one per line)
- [ ] Each transaction has Reference Type = `GRN` and Reference ID = GRN record ID
- [ ] Warehouse_Stock__c records created/updated for each product
- [ ] Last_Transaction_Date__c updated on each stock record

---

### TC-GRN-C02: GRN Received — New Product (No Existing Stock)

**Preconditions:**
- Warehouse MUM001 has NO existing stock for product SG002
- GRN Line: Product = SG002, Received = 50, Damaged = 2

**Steps:**
1. Change GRN Status → `Received`
2. Click Save

**Verify:**
- [ ] NEW `Warehouse_Stock__c` record auto-created for MUM001 + SG002
- [ ] Qty On Hand = **48** (50 - 2)
- [ ] Qty Reserved = **0**
- [ ] Qty Damaged = **0** (damaged from GRN does not go to stock damaged)
- [ ] Stock_Transaction__c created with Running Balance = 48

---

### TC-GRN-C03: GRN Received — Batch-Level Stock Creation

**Preconditions:**
- GRN Line 1: Product = WF001, Batch = `BATCH-X1`, Received = 50, Damaged = 0
- GRN Line 2: Product = WF001, Batch = `BATCH-X2`, Received = 30, Damaged = 0

**Steps:**
1. Change GRN Status → `Received`
2. Click Save

**Verify:**
- [ ] TWO separate Warehouse_Stock__c records created:
  - MUM001 + WF001 + BATCH-X1: On Hand = 50
  - MUM001 + WF001 + BATCH-X2: On Hand = 30
- [ ] Two Stock_Transaction__c records created (one per batch)

---

### TC-GRN-C04: GRN Partial → Stock Added (Same as Received)

**Steps:**
1. Create new GRN with line: Received = 100, Damaged = 10
2. Change GRN Status → `Partial`
3. Click Save

**Verify:**
- [ ] Stock increased by **90** (100 - 10) — same behavior as `Received`
- [ ] Stock_Transaction__c created with Transaction Type = `Inbound_GRN`

---

### TC-GRN-C05: GRN Disputed → No Stock Change

**Steps:**
1. Create new GRN with line items
2. Change GRN Status → `Disputed`
3. Click Save

**Verify:**
- [ ] NO Warehouse_Stock__c changes
- [ ] NO Stock_Transaction__c created
- [ ] GRN record saved with Status = `Disputed`

---

### TC-GRN-C06: GRN Received — All Damaged (Zero Usable)

**Preconditions:**
- GRN Line: Dispatched = 50, Received = 50, Damaged = 50

**Steps:**
1. Change GRN Status → `Received`
2. Click Save

**Verify:**
- [ ] Usable qty = **0** (50 - 50)
- [ ] Warehouse_Stock__c Qty On Hand increased by **0** (or no change if record exists)
- [ ] Stock_Transaction__c still created with Quantity = 0 OR no transaction created (verify actual behavior)

---

### TC-GRN-C07: GRN Without Invoice Link → Verify Warehouse Determination

**Preconditions:**
- GRN with Invoice__c = null (no invoice linked)

**Steps:**
1. Change GRN Status → `Received`
2. Click Save

**Verify:**
- [ ] Verify behavior — handler queries warehouse from Invoice; if no Invoice, no warehouse → no stock operation
- [ ] No errors thrown
- [ ] No Warehouse_Stock__c changes

---

### TC-GRN-C08: GRN Status Changed — Non-Status Field Edit (No Re-trigger)

**Preconditions:**
- GRN already in `Received` status (stock already added)

**Steps:**
1. Edit the GRN Notes field → Save
2. Edit the Received By field → Save

**Verify:**
- [ ] NO additional stock added (trigger only fires on status change)
- [ ] NO duplicate Stock_Transaction__c records

---

## SECTION D: Distributor Stock — Object & Field Validation Tests

---

### TC-DS-D01: Create Distributor Stock — Happy Path

**Steps:**
1. Navigate to **Distributor_Stock__c** tab → Click **New**
2. Enter:
   - Account: `QA Distributor Pvt Ltd`
   - Product: `WF001 (Wheat Flour 1kg)`
   - Batch No: `DIST-BATCH-01`
   - Stock Date: `Today`
   - Opening Stock: `100`
   - Received Qty: `50`
   - Sold Qty: `30`
   - Damaged Qty: `5`
   - Expiry Date: `2027-06-30`
   - Is Current: `TRUE`
3. Click **Save**

**Expected Result:**
- [ ] Record saved successfully
- [ ] Auto-number Name generated in format `DST-XXXXX`
- [ ] **Closing_Stock__c** auto-calculated = **115** (100 + 50 - 30 - 5)

---

### TC-DS-D02: Distributor Stock — Closing Stock Auto-Calculation

Test the formula: `Closing Stock = Opening Stock + Received Qty - Sold Qty - Damaged Qty`

| # | Opening | Received | Sold | Damaged | Expected Closing |
|---|---------|----------|------|---------|-----------------|
| 1 | 100 | 50 | 30 | 5 | **115** |
| 2 | 0 | 200 | 0 | 0 | **200** |
| 3 | 500 | 0 | 300 | 50 | **150** |
| 4 | 100 | 100 | 100 | 100 | **0** |
| 5 | 0 | 0 | 0 | 0 | **0** |

**Steps for each row:**
1. Create Distributor_Stock__c with the values above
2. Click Save
3. Verify Closing_Stock__c matches expected

---

### TC-DS-D03: Distributor Stock — Closing Stock Recalculation on Update

**Preconditions:** Record from TC-DS-D01 (Closing = 115)

**Steps:**
1. Edit the record: Change Sold Qty from `30` → `50`
2. Click Save

**Verify:**
- [ ] Closing_Stock__c recalculated = **95** (100 + 50 - 50 - 5)

3. Edit again: Change Received Qty from `50` → `80`
4. Click Save

**Verify:**
- [ ] Closing_Stock__c recalculated = **125** (100 + 80 - 50 - 5)

---

### TC-DS-D04: Distributor Stock — Quantities Non-Negative Validation

**Steps:**
1. Create Distributor_Stock__c with Opening Stock = `-10` → Save

**Expected Error:** `"Stock quantities cannot be negative."`

2. Set Opening Stock = `100`, Received Qty = `-5` → Save

**Expected Error:** `"Stock quantities cannot be negative."`

3. Set Received Qty = `0`, Sold Qty = `-20` → Save

**Expected Error:** `"Stock quantities cannot be negative."`

4. Set Sold Qty = `0`, Damaged Qty = `-3` → Save

**Expected Error:** `"Stock quantities cannot be negative."`

5. Set all to valid non-negative values → Save

**Expected Result:** Record saved successfully

---

### TC-DS-D05: Distributor Stock — Sold Qty Cannot Exceed Available

**Steps:**
1. Create Distributor_Stock__c with:
   - Opening Stock: `100`
   - Received Qty: `50`
   - Sold Qty: `200` (exceeds 100 + 50 = 150)
2. Click Save

**Expected Error:** `"Sold Quantity cannot exceed available stock (Opening Stock + Received Qty)."`
**Error displayed on:** Sold_Qty__c field

3. Change Sold Qty to `150` (exactly equals available)
4. Click Save

**Expected Result:** Record saved successfully (equal is allowed)

5. Change Sold Qty to `151`
6. Click Save

**Expected Error:** `"Sold Quantity cannot exceed available stock (Opening Stock + Received Qty)."`

---

### TC-DS-D06: Distributor Stock — Expiry Date Validation (Current Stock)

**Steps:**
1. Create Distributor_Stock__c with:
   - Is Current: `TRUE`
   - Expiry Date: `2025-01-01` (past date)
2. Click Save

**Expected Error:** `"Current stock entries cannot have a past expiry date. Mark as non-current or correct the expiry date."`
**Error displayed on:** Expiry_Date__c field

3. Change Is Current to `FALSE` (keep past expiry date)
4. Click Save

**Expected Result:** Record saved (non-current stock can have past expiry)

5. Change Is Current back to `TRUE`, Expiry Date to `2027-12-31` (future)
6. Click Save

**Expected Result:** Record saved (current stock with future expiry is valid)

7. Create with Is Current = `TRUE`, Expiry Date = blank
8. Click Save

**Expected Result:** Record saved (blank expiry date is allowed)

---

### TC-DS-D07: Distributor Stock — Required Fields

**Steps:**
1. Create Distributor_Stock__c with blank Account → Save

**Expected Result:** Required field error for Account

2. Create with blank Stock Date → Save

**Expected Result:** Required field error for Stock Date

---

### TC-DS-D08: Distributor Stock — Delete Protection on Account

**Steps:**
1. Create Distributor_Stock__c linked to an Account
2. Try to delete that Account

**Expected Result:** Delete blocked (Restrict Delete on Account lookup)

---

## SECTION E: Distributor Stock — "Is Current" Flag Management

---

### TC-DS-E01: New Current Stock — Previous Current Unmarked

**Preconditions:** No existing Distributor_Stock__c for Account "QA Dist" + Product WF001

**Steps:**
1. Create Distributor_Stock__c:
   - Account: QA Dist, Product: WF001, Stock Date: 2026-02-20, Is Current: `TRUE`
2. Save → Note record ID as `DST-00001`

**Verify:** Is Current = TRUE

3. Create another Distributor_Stock__c:
   - Account: QA Dist, Product: WF001, Stock Date: 2026-02-21, Is Current: `TRUE`
4. Save → Note record ID as `DST-00002`

**Verify:**
- [ ] `DST-00002` → Is Current = **TRUE**
- [ ] `DST-00001` → Is Current = **FALSE** (automatically unmarked by trigger)

---

### TC-DS-E02: Update to Current — Previous Current Unmarked

**Preconditions:**
- `DST-00002` is current (Is Current = TRUE)
- `DST-00001` is not current (Is Current = FALSE)

**Steps:**
1. Create a third record `DST-00003` with Is Current = `FALSE`
2. Edit `DST-00003`: Change Is Current from `FALSE` → `TRUE`
3. Save

**Verify:**
- [ ] `DST-00003` → Is Current = **TRUE**
- [ ] `DST-00002` → Is Current = **FALSE** (automatically unmarked)
- [ ] `DST-00001` → Is Current = **FALSE** (remains unchanged)

---

### TC-DS-E03: Current Flag — Different Products Are Independent

**Steps:**
1. Create: Account: QA Dist, Product: WF001, Is Current: `TRUE` → Save
2. Create: Account: QA Dist, Product: RC005, Is Current: `TRUE` → Save

**Verify:**
- [ ] WF001 record → Is Current = **TRUE** (unchanged — different product)
- [ ] RC005 record → Is Current = **TRUE**
- [ ] Only ONE current record per Account + Product combination

---

### TC-DS-E04: Current Flag — Different Accounts Are Independent

**Steps:**
1. Create: Account: Distributor A, Product: WF001, Is Current: `TRUE`
2. Create: Account: Distributor B, Product: WF001, Is Current: `TRUE`

**Verify:**
- [ ] Distributor A record → Is Current = **TRUE** (unchanged — different account)
- [ ] Distributor B record → Is Current = **TRUE**

---

### TC-DS-E05: Insert Non-Current — No Flag Changes

**Steps:**
1. Ensure one current record exists for QA Dist + WF001
2. Create new record with Is Current = `FALSE`

**Verify:**
- [ ] Existing current record → Is Current still = **TRUE** (not affected)
- [ ] New record → Is Current = **FALSE**

---

## SECTION F: Stock Dashboard Controller Tests

---

### TC-SD-F01: Stock Dashboard — Access Dashboard

**Steps:**
1. Navigate to the Stock Dashboard (stockDashboard LWC)
2. Verify the component loads without errors

**Expected Result:**
- [ ] Dashboard loads successfully
- [ ] No Apex errors or console errors
- [ ] Relevant stock metrics displayed

---

### TC-SD-F02: Stock Dashboard — Data Accuracy

**Steps:**
1. Note the following from raw data:
   - Total products with stock records
   - Sum of Qty On Hand across all warehouses
   - Count of low stock items
   - Count of zero stock items
2. Open Stock Dashboard
3. Compare displayed metrics against raw data

**Verify:**
- [ ] All dashboard metrics match the raw database values
- [ ] Metrics update when stock changes are made (after refresh)

---

### TC-SD-F03: Stock Dashboard — Empty State

**Steps:**
1. If possible, test with a warehouse that has no stock records
2. Open Dashboard filtered to that warehouse

**Verify:**
- [ ] Dashboard handles empty state gracefully
- [ ] Shows "0" or appropriate empty state message (no errors)

---

## SECTION G: Permission Set Tests

---

### TC-PERM-G01: FSCRM_Stock_Manager — GRN Permissions

Login as a user with **FSCRM_Stock_Manager** permission set.

| Action | Expected |
|--------|----------|
| View GRN list | YES — Can see all GRN records |
| Create new GRN | YES |
| Edit GRN (change Status) | YES |
| Delete GRN | NO — Access denied |
| View GRN Lines | YES |
| Create GRN Lines | YES |
| Edit GRN Lines | YES |
| Delete GRN Lines | NO |

---

### TC-PERM-G02: FSCRM_Stock_Manager — Distributor Stock Permissions

Login as a user with **FSCRM_Stock_Manager** permission set.

| Action | Expected |
|--------|----------|
| View Distributor Stock list | YES — Can see all records |
| Create new Distributor Stock | YES |
| Edit Distributor Stock | YES |
| Delete Distributor Stock | NO — Access denied |
| View All records | YES |

---

### TC-PERM-G03: FSCRM_Stock_Manager — Read-Only Objects

Login as a user with **FSCRM_Stock_Manager** permission set.

| Action | Expected |
|--------|----------|
| Edit Warehouse_Stock__c directly | NO — Read only |
| Create Warehouse_Stock__c directly | NO — Managed by service |
| Edit Stock_Transaction__c | NO — Read only (audit trail) |
| Create Stock_Transaction__c | NO — Managed by service |
| View Products (Product2) | YES — Read only |

---

### TC-PERM-G04: Field Rep — Read-Only Access

Login as a user with **FSCRM_Field_Rep_Products** permission set.

| Action | Expected |
|--------|----------|
| View Distributor Stock | YES |
| Create Distributor Stock | NO |
| Edit Distributor Stock | NO |
| View Warehouse Stock | YES |
| View Stock Transactions | NO (or limited based on config) |

---

## SECTION H: List View Tests

---

### TC-LV-H01: Distributor Stock — "All Stock Entries" List View

**Steps:**
1. Navigate to Distributor Stock tab
2. Select "All Stock Entries" list view

**Verify:**
- [ ] All Distributor_Stock__c records visible
- [ ] No filter applied

---

### TC-LV-H02: Distributor Stock — "Current Stock" List View

**Steps:**
1. Select "Current Stock" list view

**Verify:**
- [ ] Only records where `Is_Current__c = TRUE` are displayed
- [ ] No historical/non-current records shown

---

### TC-LV-H03: Distributor Stock — "Low Stock Items" List View

**Steps:**
1. Select "Low Stock Items" list view

**Verify:**
- [ ] Shows items with critically low closing stock
- [ ] Helps field reps identify distributors needing replenishment

---

## SECTION I: Edge Case & Negative Tests

---

### TC-EDGE-I01: GRN — Double Status Change (Pending → Received → Edit Again)

**Steps:**
1. Change GRN from Pending → Received (stock added)
2. Edit GRN and change a non-status field → Save

**Verify:**
- [ ] Stock NOT added again (trigger checks old vs new status)

---

### TC-EDGE-I02: Distributor Stock — Bulk Insert with Multiple Current Records

**Steps (via Data Loader or API):**
1. Insert 5 Distributor_Stock__c records in a single batch for the same Account + Product, all with Is Current = TRUE

**Verify:**
- [ ] Only the LAST processed record has Is Current = TRUE
- [ ] All others are set to FALSE by the trigger
- [ ] No errors during bulk insert

---

### TC-EDGE-I03: Distributor Stock — Closing Stock with Zero Values

**Steps:**
1. Create record with: Opening = 0, Received = 0, Sold = 0, Damaged = 0

**Verify:**
- [ ] Closing Stock = **0**
- [ ] Record saved without errors

---

### TC-EDGE-I04: GRN with Large Quantities

**Steps:**
1. Create GRN Line with Dispatched = 999999, Received = 999999, Damaged = 0
2. Receive the GRN

**Verify:**
- [ ] Stock increased by 999999
- [ ] No overflow or precision errors
- [ ] Stock_Transaction__c correctly records the large quantity

---

### TC-EDGE-I05: Distributor Stock — Same Day Multiple Entries

**Steps:**
1. Create record: Account A, WF001, Stock Date = Today, Is Current = TRUE
2. Create record: Account A, WF001, Stock Date = Today, Is Current = TRUE (different batch)

**Verify:**
- [ ] If same Account + Product, only one can be current
- [ ] If different batches, verify whether the uniqueness is at Account+Product or Account+Product+Batch level

---

## SECTION J: End-to-End Scenario — Full GRN-to-Distributor Lifecycle

---

### TC-E2E-J01: Complete GRN Lifecycle

**Scenario:** Receive goods at warehouse, then track at distributor level.

**Step 1: Create GRN**
1. Create GRN linked to Invoice (Warehouse: MUM001)
2. Add 2 GRN Lines:

| Product | Batch | Dispatched | Received | Damaged |
|---------|-------|-----------|----------|---------|
| WF001 | B-2026-A | 500 | 480 | 20 |
| RC005 | B-2026-B | 300 | 300 | 0 |

3. Save GRN (Status: Pending)

**Verify:** No stock changes yet

**Step 2: Receive GRN**
1. Change Status → `Received`
2. Save

**Verify:**
- [ ] MUM001 + WF001 + B-2026-A: Qty On Hand += **460** (480 - 20)
- [ ] MUM001 + RC005 + B-2026-B: Qty On Hand += **300** (300 - 0)
- [ ] 2 Stock_Transaction__c records created (Inbound_GRN, Direction: In)

**Step 3: Record Distributor Stock**
1. Create Distributor_Stock__c:
   - Account: QA Distributor
   - Product: WF001
   - Opening Stock: 50
   - Received Qty: 200 (from warehouse dispatch)
   - Sold Qty: 120
   - Damaged Qty: 5
   - Is Current: TRUE
   - Stock Date: Today
2. Save

**Verify:**
- [ ] Closing Stock = **125** (50 + 200 - 120 - 5)

**Step 4: Next Day Stock Update**
1. Create another Distributor_Stock__c:
   - Account: QA Distributor
   - Product: WF001
   - Opening Stock: 125 (previous closing)
   - Received Qty: 0
   - Sold Qty: 80
   - Damaged Qty: 2
   - Is Current: TRUE
   - Stock Date: Tomorrow
2. Save

**Verify:**
- [ ] New record: Closing Stock = **43** (125 + 0 - 80 - 2)
- [ ] Previous day's record: Is Current = **FALSE** (auto-unmarked)

---

## SECTION K: Automated Test Execution

---

### TC-AUTO-K01: Run All Related Apex Tests

Execute the following test classes and verify all tests pass:

```bash
sf apex run test --class-names "INV_GRN_TriggerHandler_Test,INV_DistributorStock_TriggerHandler_Test,INV_StockDashboardController_Test,INV_WarehouseStock_Service_Test" --result-format human --code-coverage
```

**Verify:**
- [ ] All tests pass (0 failures)
- [ ] Code coverage for each class:
  - `INV_GRN_TriggerHandler` ≥ 75%
  - `INV_DistributorStock_TriggerHandler` ≥ 75%
  - `INV_StockDashboardController` ≥ 75%
  - `INV_WarehouseStock_Service` ≥ 75%

---

### TC-AUTO-K02: Full Regression Test Run

```bash
sf apex run test --test-level RunLocalTests --code-coverage
```

**Verify:**
- [ ] All local tests pass
- [ ] No regressions in other modules (Invoice, Return Order, Sales Order)
- [ ] Overall org code coverage ≥ 75%

---

## Quick Reference: Validation Rules Summary

| Object | Rule | Condition | Error Message |
|--------|------|-----------|---------------|
| Distributor_Stock__c | Quantities_Non_Negative | Opening, Received, Sold, or Damaged < 0 | "Stock quantities cannot be negative." |
| Distributor_Stock__c | Sold_Qty_Not_Exceed_Available | Sold > (Opening + Received) | "Sold Quantity cannot exceed available stock (Opening Stock + Received Qty)." |
| Distributor_Stock__c | Expiry_Date_Future | Is Current = TRUE AND Expiry < TODAY | "Current stock entries cannot have a past expiry date. Mark as non-current or correct the expiry date." |

## Quick Reference: Trigger Behavior Summary

| Object | Event | Behavior |
|--------|-------|----------|
| GRN__c | After Update (Status → Received/Partial) | Adds usable qty (Received - Damaged) to Warehouse Stock per line |
| Distributor_Stock__c | Before Insert | Auto-calculates Closing Stock |
| Distributor_Stock__c | Before Update | Recalculates Closing Stock on qty changes |
| Distributor_Stock__c | After Insert (Is Current = TRUE) | Unmarks previous current for same Account+Product |
| Distributor_Stock__c | After Update (Is Current changed to TRUE) | Unmarks previous current for same Account+Product |
