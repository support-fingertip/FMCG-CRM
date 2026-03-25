# FMCG-CRM System Gap Analysis

**Date:** 2026-03-25
**Scope:** Complete system analysis across 13 modules covering fields, layouts, permissions, triggers, LWC, Apex classes, flows, and validation rules.

---

## CRITICAL GAPS (System-Breaking Issues)

### GAP-001: Dual Status Fields on Sales_Order__c (CRITICAL)

**Impact:** Order lifecycle is broken for LWC-created orders.

`Sales_Order__c` has **two separate status picklist fields** with different values:

| Field | Picklist Values | Used By |
|-------|----------------|---------|
| `Status__c` | Draft, Submitted, Approved, Rejected, Processing, Dispatched, Delivered, Cancelled | Layout, Approval Process, Auto-Approval Flow, Workflow field updates, `OrderEntryController.createSalesOrder()` |
| `Order_Status__c` | Draft, Submitted, Approved, Rejected, Cancelled | `OMS_SalesOrder_TriggerHandler` (state machine validation, defaults, after-update logic) |

**Root Cause:** `OrderEntryController.createSalesOrder()` at line 139 sets `order.Status__c` but the trigger handler at line 124 defaults and validates `Order_Status__c`. These are **different fields**.

**Consequences:**
- Orders created via LWC get `Status__c = 'Draft'` but `Order_Status__c` remains null (trigger defaults it to 'Draft' independently)
- The Auto-Approval Flow checks `Status__c = 'Submitted'` but trigger validates transitions on `Order_Status__c`
- Approval process entry criteria uses `Status__c = 'Submitted'`
- Workflow field updates set `Status__c`
- Trigger after-update checks `Order_Status__c` for invoice generation and credit release
- **Result:** Status changes via approval/flow update `Status__c` but trigger logic reads `Order_Status__c` - downstream actions (invoice generation, credit release) never fire

**Also missing from `Order_Status__c`:** Processing, Dispatched, Delivered values - but trigger defines transitions for them.

**Fix:** Consolidate to a single status field. Remove `Order_Status__c` and update the trigger handler to use `Status__c`, or vice versa.

---

### GAP-002: Stock Availability Check Uses Wrong UOM Quantity (CRITICAL)

**Impact:** Stock validation approves orders with insufficient stock or rejects orders with sufficient stock.

`OMS_StockAvailability_Service.validateStockAvailability()` at line 67 uses `li.Quantity__c` (order UOM quantity) to compare against `Warehouse_Stock__c.Qty_On_Hand__c` (base UOM quantity).

**Example:** If a rep orders 5 Cases (Quantity__c=5) and each Case = 12 Pieces, the actual demand is 60 Pieces. But the service compares 5 against the warehouse stock in Pieces, vastly understating demand.

**Fix:** Use `li.Base_Quantity__c` instead of `li.Quantity__c` for stock comparison, or convert warehouse stock to order UOM before comparing.

---

### GAP-003: Scheme Discount Applied to ALL Line Items (CRITICAL)

**Impact:** Scheme discounts are incorrectly distributed across all products in an order.

`OMS_OrderPricing_Service.applySchemeResults()` at lines 358-368 iterates ALL line items in the order and applies the scheme discount to each one, regardless of whether that line item's product qualifies for the scheme.

```apex
for (SPM_SchemeEngine_Service.SchemeResult scheme : schemes) {
    for (Order_Line_Item__c item : lineItems) {  // ALL items
        if (scheme.discountAmount != null && scheme.discountAmount > 0) {
            item.Scheme_Discount__c = currentDiscount + scheme.discountAmount;
```

**Fix:** Match `scheme.productId` or `scheme.lineItemId` against each `item.Product_Ext__c` before applying.

---

### GAP-004: SPM_MustSellConfig_TriggerHandler Does Not Extend TriggerHandler (CRITICAL)

**Impact:** Trigger bypass mechanism is broken for Must Sell Config, causing potential recursion or inability to bypass.

All other trigger handlers in the system extend the `TriggerHandler` base class, but `SPM_MustSellConfig_TriggerHandler` uses a standalone pattern with custom `onBeforeInsert`/`onBeforeUpdate` methods. The trigger directly calls handler methods instead of using `handler.run()`.

**Consequences:**
- `TriggerHandler.bypass('SPM_MustSellConfig_TriggerHandler')` has no effect
- No recursion protection
- Inconsistent architecture

**Fix:** Refactor to extend `TriggerHandler` and use `beforeInsert()`/`beforeUpdate()` overrides.

---

## HIGH-PRIORITY GAPS (Functional Issues)

### GAP-005: Duplicate/Redundant Fields on Day_Attendance__c

**Impact:** Data inconsistency between duplicate fields; unclear which field to populate.

| Pair 1 | Pair 2 | Purpose |
|--------|--------|---------|
| `Total_Collection__c` | `Total_Collections__c` | Collection amount |
| `Total_Order_Value__c` | `Total_Orders_Value__c` | Order value |
| `Start_Time__c` | `Day_Start_Time__c` | Day start |
| `End_Time__c` | `Day_End_Time__c` | Day end |
| `Total_Orders__c` | `Orders_Taken__c` | Order count |
| `Distance_Traveled_Km__c` | `Total_Distance__c` | Distance |

The trigger handler (`OVE_Visit_TriggerHandler.updateProductiveCallCounts()`) updates `Total_Order_Value__c`, `Total_Orders_Value__c`, `Total_Collection__c`, and `Total_Collections__c` - keeping both in sync. But `DFO_DayAttendance_Service` may only populate one of each pair.

**Fix:** Deprecate one field from each pair. Add formula fields or remove duplicates.

---

### GAP-006: Duplicate Geo Fields on Visit__c

**Impact:** Code inconsistently references different field pairs.

| New Fields | Legacy Fields |
|-----------|---------------|
| `Check_In_Latitude__c` | `Check_In_Lat__c` |
| `Check_In_Longitude__c` | `Check_In_Long__c` |
| `Check_Out_Lat__c` | (no duplicate) |
| `Check_Out_Long__c` | (no duplicate) |

Evidence from code:
- `OVE_Visit_TriggerHandler` uses `Check_In_Latitude__c` and `Check_In_Longitude__c` for geo-fence validation
- `OVE_Visit_Service.checkIn()` sets BOTH pairs: `Check_In_Latitude__c = request.latitude` AND `Check_In_Lat__c = request.latitude`
- `VisitManagerController` queries `Check_In_Lat__c`
- `TestDataFactory` sets `Check_In_Lat__c`

**Fix:** Consolidate to one pair. Make the other a formula or remove it.

---

### GAP-007: Duplicate Line Amount Fields on Order_Line_Item__c

**Impact:** `Line_Amount__c` and `Line_Total__c` serve the same purpose (both Currency 18,2, default 0).

- `OMS_OrderPricing_Service` calculates and sets `Line_Amount__c`
- `OrderEntryController.createSalesOrder()` sets `Line_Total__c` from the LWC payload (`grossAmount`)
- The aggregate query in `updateOrderTotals()` uses `Line_Amount__c`

**Result:** `Line_Total__c` contains the LWC-provided value but is never used in calculations. `Line_Amount__c` is the trigger-calculated value that overwrites during before-insert.

**Fix:** Remove `Line_Total__c` or make it a formula mirroring `Line_Amount__c`.

---

### GAP-008: Dual UOM Representation on Order_Line_Item__c

**Impact:** Confusion and potential data mismatch between picklist and lookup UOM fields.

- `UOM__c` - Lookup to UOM__c object (labeled "Base UOM" in layout context)
- `Order_UOM__c` - Lookup to UOM__c object (the UOM the order was placed in)
- `Base_UOM__c` - Lookup to UOM__c object (product's base UOM)
- Plus the old picklist pattern via `UOM_Conversion_Service.mapPicklistToCode()`

The `OrderEntryController` sets `li.UOM__c` as a picklist-style value (e.g., 'Pieces') and separately sets `li.Order_UOM__c` and `li.Base_UOM__c` as lookup IDs.

**Fix:** Clarify field purposes. `UOM__c` should be a lookup (not picklist text). Add field descriptions.

---

### GAP-009: No Validation Rules on Sales_Order__c

**Impact:** Critical validations exist only in trigger code, not at the metadata level.

`Sales_Order__c` has **zero validation rules**. All validation is performed in Apex (`OMS_OrderValidation_Service`, `OMS_SalesOrder_TriggerHandler`). This means:
- Data API inserts bypass UI validation
- Import tools skip order validation
- No declarative validation visible to admins

Missing declarative rules:
- Account is required
- Order Date is required
- Order Date not in future (if applicable)
- Status cannot be blank

**Fix:** Add key validation rules for required fields and basic constraints.

---

### GAP-010: No Validation Rules on Visit__c or Day_Attendance__c

**Impact:** Data integrity depends entirely on Apex triggers.

Neither `Visit__c` nor `Day_Attendance__c` have any validation rules defined. All validation is in triggers/services.

Missing rules for Visit__c:
- Account is required
- Visit Date is required
- Check-Out Time must be after Check-In Time

Missing rules for Day_Attendance__c:
- Salesperson is required
- Attendance Date is required
- End Time must be after Start Time

---

### GAP-011: Deprecated Fields Still Active on Beat__c

**Impact:** Data duplication and confusion.

`Beat__c` has deprecated fields that are still synced by the trigger:
- `Beat_Day__c` (deprecated) - synced from `Day_of_Week__c`
- `Beat_Frequency__c` (deprecated) - synced from `Frequency__c`

These appear in queries and may be referenced by external systems.

**Fix:** Remove deprecated fields after confirming no external references. Remove sync logic from trigger.

---

### GAP-012: Journey_Plan__c Deprecated User__c Field

**Impact:** Two user fields exist (`Salesperson__c` and `User__c`), both Lookup to User.

The trigger syncs `User__c` from `Salesperson__c` on every insert/update. Both fields appear in queries.

**Fix:** Remove `User__c` after confirming no external references.

---

## PERMISSION SET GAPS

### GAP-013: FSCRM_Field_Sales_Rep Missing Critical Object Permissions

The primary field sales rep permission set is missing object-level access for objects they need:

| Missing Object | Why Needed |
|---------------|------------|
| `Product_Extension__c` | Only has field-level permissions for 2 fields, no object CRUD |
| `Product_Category__c` | Needed for product browsing in order entry |
| `Warehouse__c` | Needed for warehouse selection in orders |
| `Warehouse_Stock__c` | Needed for stock availability checks |
| `Distributor_Stock__c` | Needed for stock check during visits |
| `Ticket__c` | Needed for logging tickets during visits |
| `Expense__c` / `Expense_Item__c` | Needed for expense submission |
| `Survey__c` / `Survey_Question__c` / `Survey_Answer__c` | Only `Survey_Response__c` is included |
| `Competitor__c` | Needed for competitor activity logging |
| `Price_List__c` | Read-only needed for price display |
| `GPS_Log__c` | Has create but missing from some queries |

**Note:** `Account` has object CRUD in FSR permission set but `Product_Extension__c` does not - yet `OrderEntryController.searchProducts()` queries it.

### GAP-014: Sales Manager Roles Missing Product/Price Visibility

| Permission Set | Missing Objects |
|---------------|----------------|
| `FSCRM_Area_Sales_Manager` | Product_Extension__c, Price_List__c, Warehouse_Stock__c |
| `FSCRM_Regional_Sales_Manager` | Product_Extension__c, Warehouse_Stock__c |
| `FSCRM_National_Sales_Manager` | Product_Extension__c, Price_List__c, Warehouse_Stock__c |

### GAP-015: FSCRM_Stock_Manager Missing Key Objects

Missing: `Account`, `Product_Extension__c`, `Product_Category__c`, `Visit__c`, `Day_Attendance__c`

Stock managers cannot view which accounts/visits generated stock demands.

---

## MISSING TEST CLASSES

### GAP-016: Controllers Without Test Coverage

The following controllers have no corresponding test class:

| Controller | Module |
|-----------|--------|
| `ReturnOrderController` | OMS |
| `ProductManagementController` | MDM |
| `ProductThreeSixtyController` | MDM |
| `SchemeViewController` | SPM |
| `VisitManagerController` | OVE |
| `EmployeeController` | HRM |
| `EmployeeThreeSixtyController` | HRM |
| `AdminConfigController` | Admin |
| `AchievementDashboardController` | TAM |
| `InvoicePDFController` | OMS |
| `LeaveRequestController` | DFO |
| `HolidayController` | DFO |
| `MDM_PriceList_Handler` | MDM |
| `OMS_OrderLineItem_TriggerHandler` | OMS |
| `MDM_CompanyHierarchy_Handler` | MDM |
| `OMS_InvoiceGeneration_Service` | OMS |
| `CollectionReceiptController` | OMS |
| `OVE_Collection_TriggerHandler` | OVE |

---

## DATA MODEL GAPS

### GAP-017: Missing Batch_Master__c Lookup on Warehouse_Stock__c

`Warehouse_Stock__c` has `Batch_Number__c` as a Text field, not a Lookup to `Batch_Master__c`. The trigger validates uniqueness using `Warehouse + Product + Batch_Number (text)`, but there's no referential integrity to `Batch_Master__c`.

**Impact:** Batch numbers can be entered that don't exist in `Batch_Master__c`. No cascade delete/update.

**Fix:** Add a Lookup field `Batch_Master__c` to `Warehouse_Stock__c` alongside or replacing the text field.

---

### GAP-018: Price_List__c Missing Status Field for Approval Workflow

The approval process references `Status__c = 'Pending Approval'` as entry criteria, but `Price_List__c` has no `Status__c` field defined in its field metadata. The workflow defines field updates for `Approve_Price_Change` and `Reject_Price_Change` that set `Status__c`.

**Fix:** Add `Status__c` picklist field to `Price_List__c` with values: Draft, Pending Approval, Approved, Rejected.

---

### GAP-019: Must_Sell_Config_Trigger Missing After/Delete Events

The trigger only fires on `before insert, before update`. Missing events:
- `after insert` / `after update` - for cascading updates
- `before delete` / `after delete` - for cleanup
- `after undelete`

All other triggers in the system register for all 7 events.

---

### GAP-020: UOM__c and UOM_Conversion__c Missing Validation Rules

Neither object has any validation rules:

**UOM__c needs:**
- `UOM_Code__c` is required and unique
- `UOM_Code__c` format validation (uppercase alphanumeric)

**UOM_Conversion__c needs:**
- `From_UOM__c` is required
- `To_UOM__c` is required
- `Conversion_Factor__c` must be positive
- `From_UOM__c` != `To_UOM__c` (cannot convert to same UOM)

---

### GAP-021: Batch_Master__c Missing Active/Inactive Status Management

`Batch_Master__c` has a `Status__c` field but the trigger handler only validates expiry dates and duplicate batch numbers. There's no:
- Validation preventing orders against expired batches
- Auto-deactivation flow for expired batches (only a notification flow `MDM_Batch_Expiry_Notification` exists)
- Prevention of stock operations on inactive batches

---

### GAP-022: Scheme__c Budget Tracking Not Connected to Orders

`Scheme__c` has `Budget_Amount__c`, `Budget_Used__c`, and `Budget_Remaining__c` (formula). But `OMS_OrderPricing_Service.applySchemes()` does not update `Budget_Used__c` when a scheme is applied to an order.

**Impact:** Budget tracking is never updated. `Budget_Remaining__c` always shows full budget.

**Fix:** After applying scheme discounts, update `Scheme__c.Budget_Used__c += discountAmount`.

---

### GAP-023: No Stock Reservation on Order Submission

When an order is submitted/approved, `Warehouse_Stock__c.Qty_Reserved__c` is never incremented. Stock availability is only checked at approval time but not reserved.

**Impact:** Two orders approved simultaneously could both pass stock validation but together exceed available stock.

**Fix:** Reserve stock (increment `Qty_Reserved__c`) on order submission/approval and release on cancellation.

---

## LAYOUT GAPS

### GAP-024: Sales_Order__c Layout Shows Both Status Fields

The layout includes both `Status__c` (in Information section, marked Required) and `Order_Status__c` (in Information section). Users see two status fields with potentially different values.

**Fix:** Remove one status field from layout (aligned with GAP-001 fix).

---

### GAP-025: Order_Line_Item__c Layout Shows Redundant Amount Fields

Layout shows both `Line_Total__c` (in Pricing section, Readonly) and `Line_Amount__c` (in Pricing section, Readonly). Both represent the same concept.

---

### GAP-026: Day_Attendance__c Layout Shows Both Time Field Pairs

Layout includes: `Start_Time__c`, `Day_Start_Time__c`, `End_Time__c`, `Day_End_Time__c` all in the same sections. Confusing for users.

---

## FLOW & AUTOMATION GAPS

### GAP-027: Auto-Approval Flow and Approval Process Conflict

`OMS_SalesOrder_AutoApproval.flow` triggers on `Status__c = 'Submitted'` and auto-approves orders <= 50,000. The `Sales_Order__c.Order_Approval` approval process also triggers on `Status__c = 'Submitted'` for orders > 50,000.

**Problem:** Both fire on the same status change. The flow may set `Status__c = 'Approved'` before the approval process evaluates, or vice versa, creating a race condition.

**Fix:** The flow should handle the routing: auto-approve small orders, submit large orders to approval process. Ensure they don't conflict.

---

### GAP-028: DFO_AutoDayEnd Flow Missing Implementation Details

The `DFO_AutoDayEnd` flow exists for auto-closing open day attendance records, but needs verification that it:
- Sets `Auto_Closed__c = true`
- Calculates day summary before closing
- Runs on a schedule (e.g., 10 PM daily)

---

### GAP-029: No Scheme Expiry Notification

`SPM_Scheme_Auto_Deactivation.flow` marks expired schemes as 'Expired', but there's no advance warning notification before a scheme expires (e.g., 7 days before End_Date).

---

## SUMMARY BY MODULE

| # | Module | Critical | High | Medium | Total |
|---|--------|----------|------|--------|-------|
| 1 | Account | 0 | 0 | 1 | 1 |
| 2 | Beats | 0 | 1 | 0 | 1 |
| 3 | Journey Plans | 0 | 1 | 0 | 1 |
| 4 | Day Attendance | 0 | 1 | 2 | 3 |
| 5 | Visits | 0 | 1 | 1 | 2 |
| 6 | Products | 0 | 0 | 1 | 1 |
| 7 | Pricebooks | 0 | 0 | 1 | 1 |
| 8 | Must Sell Config | 1 | 0 | 1 | 2 |
| 9 | UOM / Conversions | 0 | 0 | 1 | 1 |
| 10 | Warehouse Stock | 1 | 1 | 1 | 3 |
| 11 | Batch Master | 0 | 0 | 1 | 1 |
| 12 | Schemes | 1 | 1 | 1 | 3 |
| 13 | Orders / Line Items | 2 | 2 | 3 | 7 |
| - | Permissions | 0 | 3 | 0 | 3 |
| - | Test Coverage | 0 | 1 | 0 | 1 |
| **Total** | | **5** | **12** | **14** | **31** |

---

## RECOMMENDED FIX PRIORITY

### Phase 1 - Immediate (System-Breaking)
1. **GAP-001** - Consolidate Status__c / Order_Status__c on Sales_Order__c
2. **GAP-002** - Fix UOM quantity in stock availability check
3. **GAP-003** - Fix scheme discount application to target correct line items
4. **GAP-004** - Refactor MustSellConfig handler to extend TriggerHandler

### Phase 2 - High Priority (Functional)
5. **GAP-005/006/007** - Consolidate duplicate fields (Day_Attendance, Visit, Order Line Item)
6. **GAP-009/010** - Add validation rules on Sales_Order__c, Visit__c, Day_Attendance__c
7. **GAP-013/014/015** - Fix permission set gaps for Field Sales Rep and managers
8. **GAP-022** - Connect scheme budget tracking to orders
9. **GAP-023** - Implement stock reservation on order submission
10. **GAP-027** - Resolve auto-approval/approval process conflict

### Phase 3 - Medium Priority (Quality)
11. **GAP-008/011/012** - Clean up deprecated and dual-purpose fields
12. **GAP-016** - Add missing test classes
13. **GAP-017/018** - Fix data model gaps (Batch lookup, Price List status)
14. **GAP-019/020/021** - Add missing trigger events and validation rules
15. **GAP-024/025/026** - Clean up layouts
