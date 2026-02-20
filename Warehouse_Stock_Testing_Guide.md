# Warehouse Stock Module — Testing Document

## Overview

This document covers testing for the **Company Warehouse Stock (INV) module** built on the FMCG CRM/SFA platform. The module tracks real-time inventory at company warehouses and integrates with the Invoice, GRN, Return Order, and Stock Transfer flows.

---

## 1. Automated Test Classes

Run all tests with:
```bash
sf apex run test --test-level RunLocalTests --code-coverage
```

Or run individual test classes:
```bash
sf apex run test --class-names INV_WarehouseStock_Service_Test --code-coverage
```

---

### 1.1 INV_WarehouseStock_Service_Test.cls
**File:** `force-app/main/default/classes/INV_WarehouseStock_Service_Test.cls`
**Covers:** All 6 core service methods in `INV_WarehouseStock_Service.cls`

**Test Setup:**
- 1 Warehouse (Code: TW001, State: Maharashtra, Type: Central)
- 2 Products (TP001 with 100 on hand; TP002 with 50 on hand)
- 2 Warehouse_Stock__c records with min/max levels

| Test Method | Scenario | Expected Result |
|---|---|---|
| `testCheckAvailability` | Check available quantities for both products | Returns 100 and 50 respectively |
| `testReserveStock` | Reserve 20 units of TP001 | Qty_Reserved = 20, Stock_Transaction created (type: Reservation) |
| `testReleaseReservation` | Release 30 reserved units | Qty_Reserved returns to 0, Stock_Transaction created (type: Release_Reservation) |
| `testDeductStock` | Deduct 25 units from TP001 | Qty_On_Hand = 75, Stock_Transaction created (type: Outbound_Dispatch) |
| `testAddStock` | Add 30 units via GRN to TP001 | Qty_On_Hand = 80, Stock_Transaction created (type: Inbound_GRN) |
| `testAddStockReturnOrder` | Add stock with reference type Return_Order | Stock_Transaction type = Return_Inbound |
| `testAddStockTransfer` | Add stock with reference type Stock_Transfer | Stock_Transaction type = Transfer_In |
| `testAdjustDeduct` | Deduct 10 units via adjustment | Qty_On_Hand = 90, Stock_Transaction type = Adjustment_Deduct |
| `testAddStockCreatesNewRecord` | Add stock for a new batch/product combo | New Warehouse_Stock__c created with correct batch |
| `testStockLineItemConstructors` | Test StockLineItem inner class constructors | Both default and parameterised constructors work |
| `testDeductStockTransferType` | Deduct stock with Stock_Transfer reference | Stock_Transaction type = Transfer_Out |

---

### 1.2 INV_WarehouseStockController_Test.cls
**File:** `force-app/main/default/classes/INV_WarehouseStockController_Test.cls`
**Covers:** All `@AuraEnabled` methods in `INV_WarehouseStockController.cls`

**Test Setup:**
- 1 Warehouse (Code: TW001, Type: Central)
- 2 Products (PA001: 100 on hand, 10 reserved, 2 damaged; PB001: 0 on hand)
- 1 Stock_Transaction (Inbound_GRN for 100 units)

| Test Method | Scenario | Expected Result |
|---|---|---|
| `testGetWarehouseStockKPIs` | KPI summary filtered by warehouse | 2 total SKUs, 100 on hand, 10 reserved |
| `testGetWarehouseStockKPIsNoFilter` | KPI summary with null warehouse filter | Returns valid data across all warehouses |
| `testGetWarehouseStock` | List all stock, 25 per page, offset 0 | Returns 2 records |
| `testGetWarehouseStockWithSearch` | Search for 'Product A' | Returns 1 matching record |
| `testGetWarehouseStockFilters` | Filter by 'zero' and 'healthy' | Correct records returned for each filter |
| `testGetWarehouses` | Retrieve active warehouse list | Returns 1 warehouse |
| `testGetStockTransactions` | Retrieve transaction log for warehouse | Returns 1 transaction |
| `testGetStockTransactionsWithProduct` | Retrieve transactions filtered by product | Returns 1 transaction |
| `testGetLowStockAlerts` | Low/zero stock alerts | At least 1 alert (PB001 is zero stock) |
| `testCheckStockAvailability` | Real-time stock check for PA001 | 100 on hand, 10 reserved, 90 available |

---

### 1.3 INV_WarehouseStock_TriggerHandler_Test.cls
**File:** `force-app/main/default/classes/INV_WarehouseStock_TriggerHandler_Test.cls`
**Covers:** Trigger on `Warehouse_Stock__c` for defaults and uniqueness

**Test Setup:** 1 Warehouse (TW001), 1 Product (TP001)

| Test Method | Scenario | Expected Result |
|---|---|---|
| `testCreateStockWithDefaults` | Insert new stock record with no qty values | Qty_On_Hand = 0, Qty_Reserved = 0, Qty_Damaged = 0 |
| `testDuplicateWarehouseProductBatchFails` | Insert duplicate (same Warehouse + Product + Batch) | DmlException thrown |
| `testDifferentBatchesAllowed` | Insert 2 records same product, different batches | Both records created successfully |

---

### 1.4 INV_StockAdjustment_TriggerHandler_Test.cls
**File:** `force-app/main/default/classes/INV_StockAdjustment_TriggerHandler_Test.cls`
**Covers:** `INV_StockAdjustment_TriggerHandler.cls` (beforeInsert snapshot, afterUpdate approval)

**Test Setup:** 1 Warehouse (TW001), 1 Product (AP001), 1 Warehouse_Stock (80 on hand)

| Test Method | Scenario | Expected Result |
|---|---|---|
| `testSystemQtySnapshot` | Create adjustment record | System_Qty = 80 (snapshot of current stock) |
| `testPositiveAdjustmentOnApproval` | Approve +20 adjustment | Qty_On_Hand = 100 |
| `testNegativeAdjustmentOnApproval` | Approve -15 adjustment | Qty_On_Hand = 65 |
| `testRejectedAdjustmentNoStockChange` | Reject adjustment | Qty_On_Hand stays at 80 |

---

### 1.5 INV_StockTransfer_TriggerHandler_Test.cls
**File:** `force-app/main/default/classes/INV_StockTransfer_TriggerHandler_Test.cls`
**Covers:** `INV_StockTransfer_TriggerHandler.cls` (status validation, stock movements)

**Test Setup:** 2 Warehouses (SRC01, DST01), 1 Product (TRP01), Source Warehouse_Stock (200 on hand)

| Test Method | Scenario | Expected Result |
|---|---|---|
| `testValidStatusTransition` | Draft → Submitted | Status updates successfully |
| `testInvalidStatusTransition` | Draft → Received (skip steps) | DmlException: "Invalid status transition" |
| `testApprovedDeductsFromSource` | Approved transfer of 50 units | Source Qty_On_Hand = 150 (200 - 50) |
| `testCancelledTransfer` | Cancel a transfer | Status = Cancelled |

---

### 1.6 INV_StockTransferController_Test.cls
**File:** `force-app/main/default/classes/INV_StockTransferController_Test.cls`
**Covers:** `INV_StockTransferController.cls` CRUD and workflow methods

**Test Setup:** 2 Warehouses (SRC01, DST01), 1 Product (TRP01), Source Warehouse_Stock (200 on hand)

| Test Method | Scenario | Expected Result |
|---|---|---|
| `testCreateTransfer` | Create transfer with 1 line item (50 units) | Transfer created in Draft status, 1 line |
| `testGetTransfers` | List transfers for warehouse (status='all') | Returns 1 transfer |
| `testGetTransferDetail` | Get transfer header + line items | Returns 1 line with 30 requested qty |
| `testSubmitTransfer` | Submit Draft transfer | Status = Submitted |
| `testSubmitNonDraftFails` | Submit already-Submitted transfer | AuraHandledException with "draft" message |
| `testGetAvailableProducts` | Products available in source warehouse | Returns 1 product with available stock |
| `testGetAvailableProductsWithSearch` | Search for products by name | Returns matching product |
| `testReceiveTransfer` | Receive 38 of 40 approved units | Status = Received, Received_Qty = 38 |

---

### 1.7 INV_GRN_TriggerHandler_Test.cls
**File:** `force-app/main/default/classes/INV_GRN_TriggerHandler_Test.cls`
**Covers:** `INV_GRN_TriggerHandler.cls` — stock addition on GRN receipt

**Test Setup:** 1 Account, 1 Warehouse (GRN01), 1 Product (GP001), 1 Invoice (linked to warehouse, Status: Confirmed), 1 GRN (Pending), 1 GRN_Line (100 dispatched, 95 received, 3 short, 2 damaged)

| Test Method | Scenario | Expected Result |
|---|---|---|
| `testGRNReceivedAddsStock` | GRN status Pending → Received | Warehouse_Stock created with 93 units (95 received - 2 damaged) |
| `testGRNPartialAddsStock` | GRN status → Partial | Stock processed without errors |
| `testGRNPendingNoStockChange` | GRN stays Pending | No Warehouse_Stock__c record created |

---

## 2. Integration Test Scenarios (Manual)

### 2.1 Inbound Flow: GRN → Stock Addition

**Steps:**
1. Create a `Warehouse__c` record (e.g., Code: WH001, State: Maharashtra, Type: Central)
2. Create a `Sales_Order__c` with `Warehouse__c` set to WH001
3. Approve the Sales_Order → Invoice__c is auto-generated with `Warehouse__c = WH001`
4. Create a `GRN__c` linked to the Invoice
5. Add a `GRN_Line__c` (Dispatched_Qty: 100, Received_Qty: 90, Damaged_Qty: 5)
6. Change GRN Status → **Received**

**Verify:**
- `Warehouse_Stock__c` record created for WH001 + Product + Batch
- `Qty_On_Hand__c` = 85 (90 received - 5 damaged)
- `Stock_Transaction__c` created: type = `Inbound_GRN`, Direction = `In`, Quantity = 85

---

### 2.2 Outbound Flow: Invoice Confirmation → Dispatch

**Steps:**
1. Ensure Warehouse_Stock exists with Qty_On_Hand >= order quantity
2. Create and approve a `Sales_Order__c` with `Warehouse__c` linked
3. Invoice__c auto-generated; verify `Invoice__c.Warehouse__c` is populated
4. Change Invoice Status → **Confirmed**

**Verify after Confirmed:**
- `Warehouse_Stock__c.Qty_Reserved` increases by invoice line quantity
- `Qty_Available__c` decreases accordingly
- `Stock_Transaction__c` created: type = `Reservation`, Direction = `Out`

5. Change Invoice Status → **Dispatched**

**Verify after Dispatched:**
- `Warehouse_Stock__c.Qty_On_Hand` decreases by invoice line quantity
- `Warehouse_Stock__c.Qty_Reserved` decreases by invoice line quantity
- `Stock_Transaction__c` created: type = `Outbound_Dispatch`, Direction = `Out`

---

### 2.3 Invoice Cancellation → Reservation Released

**Steps:**
1. Confirm an Invoice (verify reservation per 2.2 above)
2. Change Invoice Status → **Cancelled**

**Verify:**
- `Qty_Reserved` decreases back to original value
- `Qty_On_Hand` unchanged
- `Stock_Transaction__c` created: type = `Release_Reservation`

---

### 2.4 Return Flow: Return Order Approved → Stock Added Back

**Steps:**
1. Dispatch an Invoice (stock deducted per 2.2)
2. Create a `Return_Order__c` linked to the Invoice with return quantities
3. Change Return_Order Status → **Approved**

**Verify:**
- `Warehouse_Stock__c.Qty_On_Hand` increases by returned quantity
- `Stock_Transaction__c` created: type = `Return_Inbound`, Direction = `In`
- Credit note `Ledger_Entry__c` also created (existing behaviour preserved)

---

### 2.5 Stock Transfer: Source → Destination

**Steps:**
1. Ensure source warehouse has stock (e.g., 200 units)
2. Create `Stock_Transfer__c` (Source: WH001, Destination: WH002, Status: Draft)
3. Add `Stock_Transfer_Line__c` (Product, Requested_Qty: 50)
4. Submit transfer (Draft → Submitted)
5. Approve transfer (Submitted → Approved)

**Verify after Approved:**
- Source `Qty_On_Hand` = 150
- `Stock_Transaction__c` created at source: type = `Transfer_Out`, Direction = `Out`

6. Move to In_Transit (Approved → In_Transit)
7. Receive transfer (In_Transit → Received) with Received_Qty

**Verify after Received:**
- Destination `Qty_On_Hand` increases by Received_Qty
- `Stock_Transaction__c` created at destination: type = `Transfer_In`, Direction = `In`

---

### 2.6 Stock Transfer Cancellation

**Steps:**
1. Approve a transfer (stock deducted from source per 2.5)
2. Cancel the transfer (Approved → Cancelled)

**Verify:**
- Source `Qty_On_Hand` restored to original value
- `Stock_Transaction__c` created to reverse the deduction

---

### 2.7 Stock Adjustment

**Steps:**
1. Open `Stock_Adjustment__c`, select Warehouse + Product
2. Verify `System_Qty__c` is auto-populated on save (snapshot of current stock)
3. Enter Adjustment_Qty: +20, Type: Correction_Add, Reason: "Reconciliation audit"
4. Submit, then Approve

**Verify after Approved:**
- `Warehouse_Stock__c.Qty_On_Hand` increased by 20
- `Stock_Transaction__c` created: type = `Adjustment_Add`, Direction = `In`

Repeat with negative Adjustment_Qty (e.g., -10, Type: Damage):
- `Qty_On_Hand` decreases by 10
- `Stock_Transaction__c` type = `Adjustment_Deduct`, Direction = `Out`

---

## 3. Negative / Validation Tests

| Scenario | Steps | Expected Error |
|---|---|---|
| Duplicate stock record | Insert 2 Warehouse_Stock__c with same Warehouse + Product + Batch | DmlException |
| Invalid transfer transition | Jump Draft → Received | "Invalid status transition" error |
| Submit non-draft transfer | Call submitTransfer() on Submitted record | AuraHandledException "must be in draft" |
| Transfer to same warehouse | Source = Destination on Stock_Transfer__c | Validation rule error: "Source and destination cannot be same" |
| Adjustment without reason | Save Stock_Adjustment__c with blank Reason | Validation rule error: "Reason is required" |
| Zero adjustment quantity | Save Stock_Adjustment__c with Adjustment_Qty = 0 | Validation rule error: "Quantity cannot be zero" |
| Negative stock | Attempt to deduct more than Qty_On_Hand | Service throws exception / stock cannot go below 0 |
| Requested_Qty = 0 on transfer line | Save Stock_Transfer_Line__c with 0 qty | Validation rule error: "Requested Qty must be positive" |

---

## 4. LWC Dashboard Manual Testing

### warehouseStockDashboard
1. Navigate to the **Warehouse Stock** tab
2. Select a warehouse from the dropdown
3. Verify **KPI Cards** show: Total SKUs, On Hand, Reserved, Available, Damaged, Low Stock count, Zero Stock count
4. **Tab: Current Stock**
   - Verify paginated stock list loads
   - Search for a product name — verify results filter
   - Switch filter to "Low Stock" — only items below min level shown
   - Switch filter to "Zero Stock" — only 0-on-hand items shown
5. **Tab: Transaction Log**
   - Verify audit trail loads on tab click
   - Entries show type, direction, quantity, reference, batch, running balance
6. **Tab: Low Stock Alerts**
   - Items below Min_Stock_Level__c shown
   - Severity badges correct (Low Stock vs Out of Stock)

### stockTransferForm
1. Navigate to the **Stock Transfers** tab or component
2. Create a new transfer — select Source/Destination warehouses
3. Search and add product lines; verify available stock is displayed
4. Submit the transfer; verify status changes to Submitted
5. Approve and receive; verify received quantities saved

### stockAdjustmentForm
1. Open the Stock Adjustment form
2. Select Warehouse + Product; verify System_Qty auto-populated
3. Choose adjustment type and enter quantity + reason
4. Submit and verify draft adjustment created
5. Approve and verify stock updated accordingly

---

## 5. Permission Set Verification

Verify the following user access:

**FSCRM_Stock_Manager:**
| Object | Create | Read | Edit | Delete | View All |
|---|---|---|---|---|---|
| Warehouse__c | Yes | Yes | Yes | No | Yes |
| Warehouse_Stock__c | No | Yes | No | No | Yes |
| Stock_Transaction__c | No | Yes | No | No | Yes |
| Stock_Transfer__c | Yes | Yes | Yes | No | Yes |
| Stock_Transfer_Line__c | Yes | Yes | Yes | No | Yes |
| Stock_Adjustment__c | Yes | Yes | Yes | No | Yes |

**FSCRM_Field_Rep_Products:** Read-only on Warehouse__c and Warehouse_Stock__c

---

## 6. Regression Testing

Run existing tests to confirm no regressions in OMS flows:
```bash
sf apex run test --class-names OMS_Invoice_TriggerHandler_Test,OMS_ReturnOrder_TriggerHandler_Test,OMS_InvoiceGeneration_Service_Test --code-coverage
```

Key regressions to verify:
- Invoice Confirmed → `Account.Credit_Utilized__c` still updates correctly (+ new stock reservation)
- Invoice Cancelled → Credit reversal still works (+ reservation released)
- Return Order Approved → Credit note `Ledger_Entry__c` still created (+ stock returned)
- Invoice generation from Sales Order → `Invoice__c.Warehouse__c` populated from order

---

## 7. Deployment Dry Run

Before deploying to a sandbox or production:
```bash
sf project deploy start --dry-run --source-dir force-app
```

To deploy:
```bash
sf project deploy start --source-dir force-app --test-level RunLocalTests
```

---

## 8. Key Files Reference

| Area | File Path |
|---|---|
| Core Service | `classes/INV_WarehouseStock_Service.cls` |
| Service Tests | `classes/INV_WarehouseStock_Service_Test.cls` |
| Dashboard Controller | `classes/INV_WarehouseStockController.cls` |
| Transfer Controller | `classes/INV_StockTransferController.cls` |
| GRN Handler | `classes/INV_GRN_TriggerHandler.cls` |
| Transfer Handler | `classes/INV_StockTransfer_TriggerHandler.cls` |
| Adjustment Handler | `classes/INV_StockAdjustment_TriggerHandler.cls` |
| Invoice Handler (modified) | `classes/OMS_Invoice_TriggerHandler.cls` |
| Return Order Handler (modified) | `classes/OMS_ReturnOrder_TriggerHandler.cls` |
| Warehouse Object | `objects/Warehouse__c/` |
| Warehouse Stock Object | `objects/Warehouse_Stock__c/` |
| Stock Transaction Object | `objects/Stock_Transaction__c/` |
| Stock Transfer Object | `objects/Stock_Transfer__c/` |
| Stock Adjustment Object | `objects/Stock_Adjustment__c/` |
| LWC Dashboard | `lwc/warehouseStockDashboard/` |
| LWC Transfer Form | `lwc/stockTransferForm/` |
| LWC Adjustment Form | `lwc/stockAdjustmentForm/` |
