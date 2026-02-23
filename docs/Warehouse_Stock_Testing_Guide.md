# Warehouse Stock Module — QA Test Plan

## Overview

This document provides **detailed step-by-step QA testing instructions** for the Company Warehouse Stock (INV) module. It covers all 6 new custom objects, 7 Apex trigger handlers, 2 modified trigger handlers, 3 LWC components, and all integration flows.

**New Objects:** `Warehouse__c`, `Warehouse_Stock__c`, `Stock_Transaction__c`, `Stock_Transfer__c`, `Stock_Transfer_Line__c`, `Stock_Adjustment__c`

**Modified Objects:** `Sales_Order__c` (new `Warehouse__c` lookup), `Invoice__c` (new `Warehouse__c` lookup)

---

## Prerequisites / Test Data Setup

Before starting, create the following base test data:

### Step 1: Create Warehouses

| # | Name | Warehouse Code | State | Type | Is Active |
|---|------|----------------|-------|------|-----------|
| 1 | Mumbai Central Warehouse | MUM001 | Maharashtra | Central | TRUE |
| 2 | Delhi Regional Depot | DEL001 | Delhi | Regional | TRUE |
| 3 | Chennai Depot | CHN001 | Tamil Nadu | Depot | TRUE |
| 4 | Inactive Warehouse | INA001 | Karnataka | Depot | FALSE |

### Step 2: Ensure Products Exist

Use existing products or create:

| # | Product Name | Product Code |
|---|-------------|-------------|
| 1 | Wheat Flour 1kg | WF001 |
| 2 | Rice 5kg | RC005 |
| 3 | Sugar 2kg | SG002 |

### Step 3: Create Initial Warehouse Stock

| # | Warehouse | Product | Qty On Hand | Qty Reserved | Qty Damaged | Batch Number | Expiry Date | Min Stock Level | Max Stock Level |
|---|-----------|---------|-------------|-------------|-------------|-------------|-------------|----------------|----------------|
| 1 | MUM001 | WF001 | 500 | 0 | 0 | BATCH-A01 | 2026-12-31 | 100 | 1000 |
| 2 | MUM001 | RC005 | 200 | 0 | 0 | BATCH-B01 | 2026-09-30 | 50 | 500 |
| 3 | MUM001 | SG002 | 0 | 0 | 0 | BATCH-C01 | 2026-06-30 | 20 | 300 |
| 4 | DEL001 | WF001 | 300 | 0 | 0 | BATCH-A02 | 2026-11-30 | 80 | 800 |

---

## SECTION A: Object & Field Validation Tests

---

### TC-A01: Warehouse Creation — Happy Path

**Steps:**
1. Navigate to **Warehouse__c** tab → Click **New**
2. Enter:
   - Name: `Test Warehouse QA`
   - Warehouse Code: `QAW001`
   - State: `Maharashtra`
   - Warehouse Type: `Central`
   - Is Active: `TRUE`
3. Click **Save**

**Expected Result:**
- Record saved successfully
- Auto-number Name generated
- Is Active defaults to TRUE

---

### TC-A02: Warehouse Code Validation — Invalid Format

**Steps:**
1. Create Warehouse with Warehouse Code = `QA` (only 2 characters)
2. Click Save

**Expected Error:** `"Warehouse Code must be 3-20 alphanumeric characters."`

3. Change Warehouse Code to `QA@WAREHOUSE!` (special characters)
4. Click Save

**Expected Error:** `"Warehouse Code must be 3-20 alphanumeric characters."`

5. Change Warehouse Code to `QAW001` (valid 3-20 alphanumeric)
6. Click Save

**Expected Result:** Record saved successfully

---

### TC-A03: Warehouse Required Fields

**Steps:**
1. Create Warehouse with blank Warehouse Code → Save
2. Create Warehouse with blank State → Save
3. Create Warehouse with blank Warehouse Type → Save

**Expected Result:** Each should fail with required field errors

---

### TC-A04: Warehouse Stock — Quantity Non-Negative Validation

**Steps:**
1. Navigate to **Warehouse_Stock__c** → Click **New**
2. Select Warehouse: `MUM001`, Product: `WF001`
3. Enter Qty On Hand: `-5`
4. Click Save

**Expected Error:** `"Stock quantities cannot be negative."`

5. Set Qty On Hand: `100`, Qty Reserved: `-10`
6. Click Save

**Expected Error:** `"Stock quantities cannot be negative."`

7. Set Qty On Hand: `100`, Qty Reserved: `0`, Qty Damaged: `-3`
8. Click Save

**Expected Error:** `"Stock quantities cannot be negative."`

---

### TC-A05: Warehouse Stock — Reserved Cannot Exceed On Hand

**Steps:**
1. Create Warehouse_Stock__c with:
   - Qty On Hand: `50`
   - Qty Reserved: `100`
2. Click Save

**Expected Error:** `"Reserved quantity cannot exceed quantity on hand."`

3. Change Qty Reserved to `50` (equals On Hand)
4. Click Save

**Expected Result:** Record saved (equal values allowed)

---

### TC-A06: Warehouse Stock — Min/Max Stock Level Validation

**Steps:**
1. Create Warehouse_Stock__c with:
   - Min Stock Level: `100`
   - Max Stock Level: `50`
2. Click Save

**Expected Error:** `"Min Stock Level must be less than Max Stock Level."`

3. Set Min = `100`, Max = `100`
4. Click Save

**Expected Error:** `"Min Stock Level must be less than Max Stock Level."`

5. Set Min = `50`, Max = `100`
6. Click Save

**Expected Result:** Record saved successfully

---

### TC-A07: Warehouse Stock — Formula Fields Verification

**Steps:**
1. Open the Warehouse Stock record for MUM001/WF001 (Qty On Hand: 500, Qty Reserved: 0)

**Verify:**
- `Qty_Available__c` = **500** (500 - 0)
- `Is_Low_Stock__c` = **FALSE** (Available 500 > Min 100)
- `Is_Zero_Stock__c` = **FALSE** (On Hand 500 ≠ 0)

2. Edit: Set Qty Reserved = `420`

**Verify:**
- `Qty_Available__c` = **80** (500 - 420)
- `Is_Low_Stock__c` = **TRUE** (Available 80 ≤ Min 100 AND Available > 0)

3. Open the Warehouse Stock record for MUM001/SG002 (Qty On Hand: 0)

**Verify:**
- `Qty_Available__c` = **0**
- `Is_Low_Stock__c` = **FALSE** (Available not > 0)
- `Is_Zero_Stock__c` = **TRUE** (On Hand = 0)

---

### TC-A08: Warehouse Stock — Unique Constraint (Warehouse + Product + Batch)

**Steps:**
1. Create Warehouse_Stock__c:
   - Warehouse: MUM001, Product: WF001, Batch Number: `BATCH-DUP01`
2. Click Save → should succeed
3. Create another Warehouse_Stock__c with the **same** values:
   - Warehouse: MUM001, Product: WF001, Batch Number: `BATCH-DUP01`
4. Click Save

**Expected Error:** Duplicate record error (trigger-enforced unique constraint)

5. Create Warehouse_Stock__c with same Warehouse + Product but different Batch:
   - Warehouse: MUM001, Product: WF001, Batch Number: `BATCH-DUP02`
6. Click Save

**Expected Result:** Record saved (different batches allowed)

---

### TC-A09: Warehouse Stock — Default Values

**Steps:**
1. Create Warehouse_Stock__c with only required fields (Warehouse + Product)
2. Leave Qty On Hand, Qty Reserved, Qty Damaged blank
3. Click Save

**Expected Result:**
- Qty On Hand = **0**
- Qty Reserved = **0**
- Qty Damaged = **0**
- (Trigger sets defaults)

---

### TC-A10: Stock Transaction — Quantity Must Be Positive

**Steps:**
1. Create Stock_Transaction__c with Quantity = `0` → Save

**Expected Error:** `"Transaction quantity must be greater than zero."`

2. Change Quantity to `-50` → Save

**Expected Error:** `"Transaction quantity must be greater than zero."`

3. Change Quantity to `50` → Save

**Expected Result:** Record saved successfully

---

### TC-A11: Stock Transfer — Source Cannot Equal Destination

**Steps:**
1. Create Stock_Transfer__c:
   - Source Warehouse: MUM001
   - Destination Warehouse: MUM001
2. Click Save

**Expected Error:** `"Source and destination warehouses must be different."`

3. Change Destination to DEL001
4. Click Save

**Expected Result:** Record saved, Status defaults to `Draft`

---

### TC-A12: Stock Transfer Line — Requested Qty Must Be Positive

**Steps:**
1. Open Stock Transfer (Draft)
2. Add Stock_Transfer_Line__c with Requested Qty = `0`
3. Click Save

**Expected Error:** `"Requested quantity must be greater than zero."`

4. Change to Requested Qty = `50`
5. Click Save

**Expected Result:** Record saved; Short_Qty formula = 0 (approved/received blank)

---

### TC-A13: Stock Transfer Line — Short Qty Formula

**Steps:**
1. Open Stock_Transfer_Line with:
   - Approved Qty = `100`, Received Qty = `90`

**Verify:** Short Qty = **10**

2. Edit: Approved Qty = `50`, Received Qty = `50`

**Verify:** Short Qty = **0**

3. Edit: Approved Qty = blank, Received Qty = `50`

**Verify:** Short Qty = **0** (handles blanks)

---

### TC-A14: Stock Adjustment — Reason Required

**Steps:**
1. Create Stock_Adjustment__c with Reason blank → Save

**Expected Error:** `"A reason is required for all stock adjustments."`

2. Enter Reason: `"Physical count reconciliation"` → Save

**Expected Result:** Record saved

---

### TC-A15: Stock Adjustment — Qty Cannot Be Zero

**Steps:**
1. Create Stock_Adjustment__c with Adjustment Qty = `0` → Save

**Expected Error:** `"Adjustment quantity cannot be zero."`

2. Change Adjustment Qty to `20` → Save

**Expected Result:** Record saved

---

## SECTION B: Stock Flow Integration Tests

---

### TC-B01: GRN Received → Stock Added to Warehouse

**Preconditions:**
- Warehouse MUM001 exists
- Invoice linked to MUM001 warehouse exists (Status: Confirmed)
- GRN linked to the Invoice (Status: Pending)
- GRN Line: Dispatched Qty = 100, Received Qty = 95, Damaged Qty = 5

**Steps:**
1. Note the current Warehouse Stock for MUM001/Product (or confirm none exists)
2. Open the GRN record
3. Change Status from `Pending` → `Received`
4. Click Save

**Verify:**
- [ ] `Warehouse_Stock__c` record exists for MUM001 + Product
- [ ] `Qty_On_Hand__c` increased by **90** (95 received - 5 damaged)
- [ ] `Last_Transaction_Date__c` updated to current timestamp
- [ ] `Stock_Transaction__c` created with:
  - Transaction Type = `Inbound_GRN`
  - Direction = `In`
  - Quantity = `90`
  - Reference Type = `GRN`
  - Reference ID = GRN record ID
  - Running Balance = new Qty On Hand

---

### TC-B02: GRN Partial → Stock Added

**Preconditions:** Same as TC-B01 but with a new GRN

**Steps:**
1. Change GRN Status from `Pending` → `Partial`
2. Click Save

**Verify:**
- [ ] Stock is added same as TC-B01 (Partial also triggers stock addition)
- [ ] Stock_Transaction__c created with type `Inbound_GRN`

---

### TC-B03: GRN Stays Pending → No Stock Change

**Steps:**
1. Create a GRN with Status = `Pending`
2. Edit a non-status field and Save

**Verify:**
- [ ] No new Warehouse_Stock__c record created
- [ ] No Stock_Transaction__c created

---

### TC-B04: Invoice Confirmed → Stock Reserved

**Preconditions:**
- Warehouse MUM001 has Stock: WF001, Qty On Hand = 500, Qty Reserved = 0
- Sales Order exists with Warehouse__c = MUM001
- Invoice auto-generated from Sales Order with Warehouse__c = MUM001
- Invoice Line: Product = WF001, Qty = 80

**Steps:**
1. Note current stock: Qty On Hand = 500, Qty Reserved = 0
2. Change Invoice Status → `Confirmed`
3. Click Save

**Verify:**
- [ ] `Warehouse_Stock__c.Qty_Reserved__c` = **80** (0 + 80)
- [ ] `Qty_Available__c` = **420** (500 - 80)
- [ ] `Qty_On_Hand__c` = **500** (unchanged)
- [ ] `Stock_Transaction__c` created:
  - Transaction Type = `Reservation`
  - Direction = `Out`
  - Quantity = `80`
  - Reference Type = `Invoice`
  - Notes = `"Stock reserved for invoice"`
- [ ] `Account.Credit_Utilized__c` increased by Invoice Total_Amount

---

### TC-B05: Invoice Dispatched → Stock Deducted

**Preconditions:** Invoice from TC-B04 is Confirmed (stock reserved)

**Steps:**
1. Note current stock: Qty On Hand = 500, Qty Reserved = 80
2. Change Invoice Status → `Dispatched`
3. Click Save

**Verify:**
- [ ] `Warehouse_Stock__c.Qty_On_Hand__c` = **420** (500 - 80)
- [ ] `Warehouse_Stock__c.Qty_Reserved__c` = **0** (80 - 80)
- [ ] `Qty_Available__c` = **420** (420 - 0)
- [ ] `Stock_Transaction__c` created:
  - Transaction Type = `Outbound_Dispatch`
  - Direction = `Out`
  - Quantity = `80`
  - Reference Type = `Invoice`

---

### TC-B06: Invoice Cancelled (from Confirmed) → Reservation Released

**Preconditions:**
- Fresh Invoice confirmed with 60 units reserved (Qty Reserved = 60)

**Steps:**
1. Note stock: Qty On Hand = 420, Qty Reserved = 60
2. Change Invoice Status → `Cancelled`
3. Click Save

**Verify:**
- [ ] `Warehouse_Stock__c.Qty_Reserved__c` = **0** (60 - 60)
- [ ] `Warehouse_Stock__c.Qty_On_Hand__c` = **420** (unchanged)
- [ ] `Qty_Available__c` = **420** (420 - 0)
- [ ] `Stock_Transaction__c` created:
  - Transaction Type = `Release_Reservation`
  - Direction = `In`
  - Notes = `"Reservation released"`
- [ ] `Account.Credit_Utilized__c` decreased

---

### TC-B07: Invoice Cancelled (from Dispatched) → No Stock Reversal

**Preconditions:** Invoice already Dispatched (stock already deducted)

**Steps:**
1. Note stock levels
2. Change Invoice Status → `Cancelled`
3. Click Save

**Verify:**
- [ ] `Qty_On_Hand__c` = **unchanged** (no reversal for post-dispatch cancel)
- [ ] `Qty_Reserved__c` = **unchanged**
- [ ] `Account.Credit_Utilized__c` still decreases (credit reversal is separate from stock)

---

### TC-B08: Invoice Without Warehouse → No Stock Operations

**Preconditions:** Invoice with `Warehouse__c` = null

**Steps:**
1. Change Invoice Status → `Confirmed`
2. Click Save

**Verify:**
- [ ] No Stock_Transaction__c created
- [ ] No Warehouse_Stock__c changes
- [ ] Credit utilization still updates (separate logic)

---

### TC-B09: Return Order Approved → Stock Added Back

**Preconditions:**
- Invoice dispatched from Warehouse MUM001 (stock deducted)
- Current Stock: Qty On Hand = 420
- Return Order linked to the Invoice, Return Quantity = 30, Product = WF001

**Steps:**
1. Note stock: Qty On Hand = 420
2. Change Return Order Status → `Approved`
3. Click Save

**Verify:**
- [ ] `Warehouse_Stock__c.Qty_On_Hand__c` = **450** (420 + 30)
- [ ] `Stock_Transaction__c` created:
  - Transaction Type = `Return_Inbound`
  - Direction = `In`
  - Quantity = `30`
  - Reference Type = `Return_Order`
- [ ] `Ledger_Entry__c` created (credit note):
  - Entry Type = `Credit Note`
  - Status = `Posted`
- [ ] `Invoice__c.Balance_Due__c` decreased by return amount

---

### TC-B10: Return Order — Quantity Exceeds Available

**Preconditions:**
- Invoice with 100 units dispatched
- Previous return of 80 units already approved

**Steps:**
1. Create Return_Order__c with Return Quantity = `30` (80 + 30 = 110 > 100)
2. Click Save

**Expected Error:** `"Return quantity (30) exceeds available returnable quantity (20). Invoiced: 100, Already returned: 80."`

---

### TC-B11: Return Order — Zero/Negative Quantity

**Steps:**
1. Create Return_Order__c with Return Quantity = `0` → Save

**Expected Error:** `"Return quantity must be greater than zero."`

2. Change Return Quantity = `-5` → Save

**Expected Error:** `"Return quantity must be greater than zero."`

---

### TC-B12: Sales Order → Invoice Warehouse Propagation

**Steps:**
1. Create Sales_Order__c with `Warehouse__c` = MUM001
2. Approve Sales Order (triggers auto invoice generation)
3. Open the generated Invoice__c

**Verify:**
- [ ] `Invoice__c.Warehouse__c` = MUM001 (copied from Sales Order)

---

## SECTION C: Stock Transfer Integration Tests

---

### TC-C01: Create Stock Transfer (Happy Path)

**Steps:**
1. Create Stock_Transfer__c:
   - Source Warehouse: MUM001
   - Destination Warehouse: DEL001
   - Transfer Date: today
   - Notes: "QA Test Transfer"
2. Add Stock_Transfer_Line__c:
   - Product: WF001, Requested Qty: 50
3. Click Save

**Verify:**
- [ ] Transfer created with Status = `Draft`
- [ ] Transfer Name auto-generated (TRF-xxxxx)
- [ ] Line Name auto-generated (TRL-xxxx)
- [ ] Available_Stock__c shows snapshot of source stock at creation time

---

### TC-C02: Stock Transfer — Valid Status Transitions

Test each valid transition:

| # | From | To | Expected |
|---|------|----|----------|
| 1 | Draft | Submitted | Success |
| 2 | Submitted | Approved | Success |
| 3 | Approved | In_Transit | Success |
| 4 | In_Transit | Received | Success |
| 5 | Draft | Cancelled | Success |
| 6 | Submitted | Cancelled | Success |
| 7 | Approved | Cancelled | Success (reverses deduction) |
| 8 | In_Transit | Cancelled | Success (reverses deduction) |
| 9 | Submitted | Rejected | Success |

**Steps for each:** Change Status__c to the target value → Save → Verify success

---

### TC-C03: Stock Transfer — Invalid Status Transitions

Test each invalid transition:

| # | From | To | Expected Error |
|---|------|----|----------------|
| 1 | Draft | Received | `"Invalid status transition from 'Draft' to 'Received'."` |
| 2 | Draft | Approved | `"Invalid status transition from 'Draft' to 'Approved'."` |
| 3 | Draft | In_Transit | `"Invalid status transition from 'Draft' to 'In_Transit'."` |
| 4 | Received | Draft | `"Invalid status transition from 'Received' to 'Draft'."` |
| 5 | Cancelled | Draft | `"Invalid status transition from 'Cancelled' to 'Draft'."` |
| 6 | Received | Cancelled | `"Invalid status transition from 'Received' to 'Cancelled'."` |

---

### TC-C04: Stock Transfer Approved → Source Stock Deducted

**Preconditions:**
- Source (MUM001): WF001, Qty On Hand = 500
- Transfer Line: Product = WF001, Requested Qty = 50, Approved Qty = 50

**Steps:**
1. Change Transfer Status → `Approved`
2. Click Save

**Verify:**
- [ ] Source MUM001 Stock: Qty On Hand = **450** (500 - 50)
- [ ] Stock_Transaction__c at source:
  - Transaction Type = `Transfer_Out`
  - Direction = `Out`
  - Quantity = `50`
  - Reference Type = `Stock_Transfer`

---

### TC-C05: Stock Transfer Received → Destination Stock Added

**Preconditions:** Transfer from TC-C04 (Approved, source deducted)
- Destination (DEL001): WF001, Qty On Hand = 300

**Steps:**
1. Change Transfer Status → `Received`
2. Set Received_Qty = `48` on line item (partial receipt)
3. Click Save

**Verify:**
- [ ] Destination DEL001 Stock: Qty On Hand = **348** (300 + 48)
- [ ] Stock_Transaction__c at destination:
  - Transaction Type = `Transfer_In`
  - Direction = `In`
  - Quantity = `48`
  - Reference Type = `Stock_Transfer`
- [ ] Line Short_Qty = **2** (50 Approved - 48 Received)

---

### TC-C06: Stock Transfer Cancelled (from Approved) → Source Stock Restored

**Preconditions:**
- Transfer Approved; Source stock was deducted by 50 (now at 450)

**Steps:**
1. Change Transfer Status → `Cancelled`
2. Click Save

**Verify:**
- [ ] Source MUM001 Stock: Qty On Hand = **500** (450 + 50 restored)
- [ ] Stock_Transaction__c (reversal):
  - Direction = `In`
  - Quantity = `50`

---

### TC-C07: Stock Transfer Cancelled (from In_Transit) → Source Stock Restored

Same as TC-C06 but cancel from In_Transit status.

**Verify:** Same reversal behavior as TC-C06.

---

### TC-C08: Stock Transfer Cancelled (from Draft/Submitted) → No Stock Change

**Steps:**
1. Create transfer in Draft status
2. Cancel it

**Verify:**
- [ ] No Warehouse_Stock__c changes
- [ ] No Stock_Transaction__c created

---

## SECTION D: Stock Adjustment Integration Tests

---

### TC-D01: Stock Adjustment — System Qty Snapshot on Creation

**Preconditions:** MUM001/WF001 Stock: Qty On Hand = 500

**Steps:**
1. Create Stock_Adjustment__c:
   - Warehouse: MUM001
   - Product: WF001
   - Adjustment Type: `Physical_Count`
   - Adjustment Qty: `20`
   - Reason: "QA test - system qty snapshot"
   - Status: `Draft`
2. Click Save

**Verify:**
- [ ] `System_Qty__c` = **500** (auto-snapshot of current Qty On Hand)

---

### TC-D02: Positive Adjustment Approved → Stock Added

**Preconditions:** MUM001/WF001 Stock: Qty On Hand = 500

**Steps:**
1. Create Adjustment: Adjustment Qty = `+25`, Reason: "Found extra stock"
2. Save as Draft, then change Status → `Approved`
3. Click Save

**Verify:**
- [ ] `Warehouse_Stock__c.Qty_On_Hand__c` = **525** (500 + 25)
- [ ] `Stock_Transaction__c` created:
  - Transaction Type = `Adjustment_Add`
  - Direction = `In`
  - Quantity = `25`
  - Reference Type = `Stock_Adjustment`

---

### TC-D03: Negative Adjustment Approved → Stock Deducted

**Preconditions:** MUM001/WF001 Stock: Qty On Hand = 525

**Steps:**
1. Create Adjustment: Adjustment Qty = `-15`, Reason: "Damaged goods write-off"
2. Save as Draft, then change Status → `Approved`
3. Click Save

**Verify:**
- [ ] `Warehouse_Stock__c.Qty_On_Hand__c` = **510** (525 - 15)
- [ ] `Stock_Transaction__c` created:
  - Transaction Type = `Adjustment_Deduct`
  - Direction = `Out`
  - Quantity = `15`
  - Notes = `"Stock adjusted (deduct)"`

---

### TC-D04: Rejected Adjustment → No Stock Change

**Preconditions:** MUM001/WF001 Stock: Qty On Hand = 510

**Steps:**
1. Create Adjustment: Adjustment Qty = `+100`, Reason: "Test rejection"
2. Save as Draft, then change Status → `Rejected`
3. Click Save

**Verify:**
- [ ] `Warehouse_Stock__c.Qty_On_Hand__c` = **510** (unchanged)
- [ ] No Stock_Transaction__c created

---

### TC-D05: Adjustment All Types

Test each Adjustment Type:

| # | Type | Qty | Expected Transaction Type |
|---|------|-----|--------------------------|
| 1 | Physical_Count | +30 | Adjustment_Add |
| 2 | Damage | -10 | Adjustment_Deduct |
| 3 | Expiry_Write_Off | -20 | Adjustment_Deduct |
| 4 | Correction_Add | +15 | Adjustment_Add |
| 5 | Correction_Deduct | -5 | Adjustment_Deduct |

---

## SECTION E: LWC Component Tests

---

### TC-E01: Warehouse Stock Dashboard — KPI Cards

**Steps:**
1. Navigate to **Warehouse Stock** tab (warehouseStockDashboard LWC)
2. Select Warehouse: `Mumbai Central Warehouse` from dropdown

**Verify KPI Cards:**
- [ ] **Total SKUs** — Shows count of distinct products in stock
- [ ] **On Hand** — Sum of all Qty_On_Hand__c
- [ ] **Reserved** — Sum of all Qty_Reserved__c
- [ ] **Available** — Sum of all Qty_Available__c
- [ ] **Low Stock** — Count of items where Is_Low_Stock = TRUE (warning icon if > 0)
- [ ] **Zero Stock** — Count of items where Is_Zero_Stock = TRUE (error icon if > 0)

---

### TC-E02: Dashboard — Warehouse Dropdown

**Steps:**
1. Open dashboard
2. Click warehouse dropdown

**Verify:**
- [ ] "All Warehouses" option appears first
- [ ] Only **active** warehouses listed (Inactive Warehouse INA001 should NOT appear)
- [ ] Warehouses show name with code (e.g., "Mumbai Central Warehouse (MUM001)")

3. Select "All Warehouses"

**Verify:** KPIs aggregate across all warehouses

---

### TC-E03: Dashboard — Current Stock Tab

**Steps:**
1. Select warehouse MUM001
2. Verify **Current Stock** tab is active by default

**Verify Table Columns:**
- [ ] Stock # | Warehouse | Product | Code | On Hand | Reserved | Available | Damaged | Batch | Expiry | Last Txn

**Verify Color Coding:**
- [ ] **Green** (healthy): Available > Min Stock Level
- [ ] **Yellow/Warning**: Available ≤ Min Stock Level AND Available > 0
- [ ] **Red** (danger): On Hand = 0 OR Available ≤ 0

**Verify Pagination:**
- [ ] Page size = 25 records
- [ ] Shows "Page 1 of X (Y records)"
- [ ] Previous disabled on page 1
- [ ] Next disabled on last page

---

### TC-E04: Dashboard — Product Search

**Steps:**
1. Type `"Wheat"` in the search box
2. Wait 300ms (debounce)

**Verify:**
- [ ] Only products matching "Wheat" displayed
- [ ] Search works on product name and product code

3. Clear search

**Verify:** All products shown again

---

### TC-E05: Dashboard — Stock Filter Buttons

**Steps:**
1. Click **"Low Stock"** filter button

**Verify:** Only items where Is_Low_Stock = TRUE shown

2. Click **"Zero Stock"** filter button

**Verify:** Only items where Qty On Hand = 0 shown

3. Click **"Healthy"** filter button

**Verify:** Only items with healthy stock levels shown

4. Click **"All"** filter button

**Verify:** All items shown

---

### TC-E06: Dashboard — Transaction Log Tab

**Steps:**
1. Click **"Transaction Log"** tab

**Verify Table Columns:**
- [ ] Txn # | Date | Type | Product | Qty | Direction | Balance | Reference | By | Notes

**Verify Direction Styling:**
- [ ] `In` → Green badge with `+` prefix
- [ ] `Out` → Red badge with `-` prefix

**Verify:** Transactions appear in reverse chronological order

---

### TC-E07: Dashboard — Low Stock Alerts Tab

**Steps:**
1. Click **"Low Stock Alerts"** tab

**Verify:**
- [ ] Items below Min Stock Level displayed
- [ ] Severity column shows:
  - **"Out of Stock"** badge (red) for zero stock items
  - **"Low Stock"** badge (yellow/orange) for low stock items
- [ ] **Reorder Qty** column shows: Max Stock Level - Available

---

### TC-E08: Dashboard — Refresh Button

**Steps:**
1. Click the refresh icon button (top-right)
2. Verify all KPIs and table data reload from server

---

### TC-E09: Stock Transfer Form — Create Transfer

**Steps:**
1. Navigate to Stock Transfer component
2. Click **"New Transfer"** button
3. Select Source Warehouse: MUM001
4. Select Destination Warehouse: DEL001
5. Enter Transfer Date
6. Click **"Add Line Item"**
7. Select Product from dropdown (shows available qty)
8. Enter Quantity: `50`
9. Click **"Create Transfer"**

**Verify:**
- [ ] Toast: `"Stock transfer created successfully."`
- [ ] Transfer created in `Draft` status
- [ ] Line item saved with Requested Qty = 50

---

### TC-E10: Stock Transfer Form — Validation Errors

**Steps:**
1. Click "Create Transfer" without selecting warehouses

**Expected Error:** `"Please select both source and destination warehouses."`

2. Select same warehouse for source and destination

**Expected Error:** `"Source and destination warehouses must be different."`

3. Select different warehouses but no line items

**Expected Error:** `"Please add at least one line item with a product and quantity."`

---

### TC-E11: Stock Transfer Form — Submit for Approval

**Steps:**
1. Open a Draft transfer detail view
2. Verify **"Submit for Approval"** button is visible
3. Click **"Submit for Approval"**

**Verify:**
- [ ] Toast: `"Transfer submitted for approval."`
- [ ] Status changed to `Submitted`
- [ ] "Submit for Approval" button disappears

---

### TC-E12: Stock Transfer Form — Receive Transfer

**Steps:**
1. Open an Approved/In_Transit transfer detail view
2. Verify **"Receive Transfer"** button is visible
3. Click **"Receive Transfer"**
4. In the modal, enter Received Qty for each line item
5. Click **"Confirm Receipt"**

**Verify:**
- [ ] Toast: `"Transfer received successfully."`
- [ ] Status = `Received`
- [ ] Short Qty calculated correctly

---

### TC-E13: Stock Transfer Form — List View Filters

**Steps:**
1. Use status filter dropdown

**Verify Filter Options:**
- [ ] All Statuses, Draft, Submitted, Approved, In Transit, Received, Cancelled

2. Filter by Warehouse

**Verify:** Only transfers with source OR destination matching shown

---

### TC-E14: Stock Adjustment Form — Create Adjustment

**Steps:**
1. Open Stock Adjustment form
2. Select Warehouse: MUM001
3. Search and select Product: WF001
4. Optionally enter Batch Number
5. Click **"Check Stock"**

**Verify:**
- [ ] System stock displayed: `"Current System Stock: [X] units"`

6. Select Adjustment Type: `Physical_Count`

**Verify:**
- [ ] "Actual Physical Count" input appears
- [ ] Enter Actual Count = 520

**Verify Variance Display:**
- [ ] Variance = 520 - 500 = **+20** (green text)
- [ ] Projected Stock Summary shows:
  - System Qty: 500
  - Adjustment: +20
  - Projected Qty: 520

7. Enter Reason: "Physical count reconciliation"
8. Click **"Create Adjustment"**

**Verify:**
- [ ] Toast: `"Stock adjustment created successfully (ID: ADJ-XXXXX). Submit for approval to apply the adjustment."`

---

### TC-E15: Stock Adjustment Form — Negative Variance

**Steps:**
1. Check Stock for warehouse with 500 on hand
2. Select Adjustment Type: `Damage`
3. Enter Adjustment Quantity: `-10`

**Verify:**
- [ ] Adjustment shows as `-10` in red text
- [ ] Projected Qty = 490
- [ ] Helper text: "Positive = Add, Negative = Deduct"

---

### TC-E16: Stock Adjustment Form — Validation Errors

| # | Missing Field | Expected Error |
|---|--------------|----------------|
| 1 | No warehouse | `"Please select a warehouse."` |
| 2 | No product | `"Please select a product."` |
| 3 | No adjustment type | `"Please select an adjustment type."` |
| 4 | Adjustment qty = 0 | `"Adjustment quantity cannot be zero."` |
| 5 | No reason | `"Reason is required for all adjustments."` |

---

### TC-E17: Stock Adjustment Form — Reset Button

**Steps:**
1. Fill in all fields
2. Click **"Reset"** button

**Verify:** All fields cleared, form returns to initial state

---

## SECTION F: Permission Set Tests

---

### TC-F01: FSCRM_Stock_Manager Permissions

Login as a user with **FSCRM_Stock_Manager** permission set.

| Object | Create | Read | Edit | Delete | View All |
|--------|--------|------|------|--------|---------|
| Warehouse__c | YES | YES | YES | NO | YES |
| Warehouse_Stock__c | NO | YES | NO | NO | YES |
| Stock_Transaction__c | NO | YES | NO | NO | YES |
| Stock_Transfer__c | YES | YES | YES | NO | YES |
| Stock_Transfer_Line__c | YES | YES | YES | NO | YES |
| Stock_Adjustment__c | YES | YES | YES | NO | YES |

**Key Verification:**
- [ ] User CANNOT directly create/edit Warehouse_Stock__c (managed by service)
- [ ] User CANNOT delete any stock records
- [ ] User CAN create transfers and adjustments

---

### TC-F02: FSCRM_Field_Rep_Products Permissions

Login as a user with **FSCRM_Field_Rep_Products** permission set.

**Verify:**
- [ ] CAN read Warehouse__c records
- [ ] CAN read Warehouse_Stock__c records
- [ ] CANNOT create/edit/delete any stock records

---

## SECTION G: Regression Tests

---

### TC-G01: Invoice Flow — Credit Utilization Still Works

**Steps:**
1. Create Sales Order with Warehouse → Approve → Invoice generated
2. Confirm Invoice

**Verify:**
- [ ] Account.Credit_Utilized__c increased (existing behavior)
- [ ] Stock reservation also happened (new behavior)

3. Cancel Invoice

**Verify:**
- [ ] Account.Credit_Utilized__c decreased (existing behavior)
- [ ] Stock reservation released (new behavior)

---

### TC-G02: Return Order — Credit Note Still Created

**Steps:**
1. Approve Return Order linked to dispatched Invoice

**Verify:**
- [ ] Ledger_Entry__c credit note created (existing behavior)
- [ ] Invoice.Balance_Due__c decreased (existing behavior)
- [ ] Stock returned to warehouse (new behavior)

---

### TC-G03: Run All Automated Tests

```bash
sf apex run test --test-level RunLocalTests --code-coverage
```

**Verify:**
- [ ] All tests pass
- [ ] No test regressions in OMS_Invoice_TriggerHandler_Test
- [ ] No test regressions in OMS_ReturnOrder_TriggerHandler_Test
- [ ] No test regressions in OMS_InvoiceGeneration_Service_Test

---

## SECTION H: End-to-End Scenario

---

### TC-H01: Full Lifecycle Test

This tests the complete stock lifecycle across all flows.

**Step 1: Setup**
- Create Warehouse "QA-WH" (Code: QAE2E, State: Maharashtra, Type: Central)
- Create Product "QA Product" (Code: QAP001)

**Step 2: Inbound (GRN)**
1. Create Invoice linked to QA-WH
2. Create GRN with Line: Dispatched=1000, Received=950, Damaged=50
3. Change GRN Status → Received

**Verify:** Warehouse Stock created: Qty On Hand = **900**, Transaction logged

**Step 3: Outbound (Invoice)**
1. Create Sales Order with Warehouse = QA-WH, Qty = 200
2. Approve → Invoice auto-created
3. Confirm Invoice → Verify: Reserved = 200, Available = 700
4. Dispatch Invoice → Verify: On Hand = 700, Reserved = 0

**Step 4: Return**
1. Create Return Order: 50 units returned
2. Approve → Verify: On Hand = **750**

**Step 5: Transfer Out**
1. Create Transfer: QA-WH → DEL001, 100 units
2. Submit → Approve → Verify: QA-WH On Hand = **650**
3. Receive at DEL001 (Received 95) → Verify: DEL001 On Hand increased by 95

**Step 6: Adjustment**
1. Create Adjustment: +30 (Physical Count found extra)
2. Approve → Verify: QA-WH On Hand = **680**

**Step 7: Verify Final State**
- [ ] QA-WH On Hand = **680**
- [ ] All Stock_Transaction__c records exist (6 transactions minimum)
- [ ] Dashboard KPIs reflect correct totals
- [ ] Transaction Log shows complete audit trail in chronological order

**Calculation Trail:**
```
+900 (GRN)  → 900
-200 (Invoice Dispatch) → 700
+50  (Return) → 750
-100 (Transfer Out) → 650
+30  (Adjustment) → 680
```

---

## Stock Transaction Type Reference

| Operation | Transaction Type | Direction | Qty_On_Hand | Qty_Reserved |
|-----------|-----------------|-----------|-------------|-------------|
| GRN Received | Inbound_GRN | In | +qty | — |
| Invoice Confirmed | Reservation | Out | — | +qty |
| Invoice Dispatched | Outbound_Dispatch | Out | -qty | -qty |
| Invoice Cancelled (from Confirmed) | Release_Reservation | In | — | -qty |
| Return Approved | Return_Inbound | In | +qty | — |
| Transfer Approved (source) | Transfer_Out | Out | -qty | — |
| Transfer Received (destination) | Transfer_In | In | +qty | — |
| Adjustment (+ve) | Adjustment_Add | In | +qty | — |
| Adjustment (-ve) | Adjustment_Deduct | Out | -qty | — |
