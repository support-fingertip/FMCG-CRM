# FMCG Field Sales CRM - Cross-Module Gap Analysis

**Date:** 2026-03-26 | **Branch:** main (post-merge of all fixes)
**Scope:** 13 modules, 69 custom objects, ~200 Apex classes, 25 triggers, 30+ LWC, 77 test classes

---

## EXECUTIVE SUMMARY

The CRM implementation is **substantially complete** across all 13 requested modules. Core objects, fields, triggers, handlers, service classes, LWC components, layouts, permissions, and approval processes are all in place. The architecture follows best practices (TriggerHandler framework, service layer pattern, feature toggles, custom metadata-driven configuration).

However, **12 cross-module integration gaps** remain that affect the connection *between* modules. Most individual modules work well in isolation; the gaps are in how they interact.

---

## MODULE-BY-MODULE STATUS

| # | Module | Objects | Fields | VRs | Triggers | Services | LWC | Layout | FlexiPage | Perms | Status |
|---|--------|---------|--------|-----|----------|----------|-----|--------|-----------|-------|--------|
| 1 | Account | Account (std) | 30 | 4 | 1 | - | outletThreeSixty | 8 | Yes | Yes | COMPLETE |
| 2 | Beats | Beat__c, Beat_Outlet__c | 16 | 5 | 2 | - | beatManager | 2 | Yes | Yes | COMPLETE |
| 3 | Journey Plans | Journey_Plan__c, Journey_Plan_Day__c | 28 | 5 | 2 | BPM_JourneyPlan_Service | beatPlanCalendar, visitPlanBoard | 2 | Yes | Yes | COMPLETE |
| 4 | Day Attendance | Day_Attendance__c, GPS_Log__c | 47+ | 0 | 1 | DFO_DayAttendance_Service | dayStartEnd, teamAttendanceDashboard | 1 | Yes | Yes | COMPLETE |
| 5 | Visits | Visit__c | 62 | 3 | 1 | OVE_Visit_Service, OVE_GeoValidation_Service | visitManager, visitActivity | 1 | Yes | Yes | COMPLETE |
| 6 | Products | Product_Extension__c, Product_Category__c | 25+ | 4+2 | 1 | MDM_ProductCatalogController | productCatalog | 1 | Yes | Yes | COMPLETE |
| 7 | Pricebooks | Price_List__c, Price_Change_Log__c | 14+ | 3 | 1 | OMS_OrderPricing_Service | (via orderEntryForm) | 1 | No | Yes | COMPLETE |
| 8 | Must Sell/Focused Sell | Must_Sell_Config__c | 9 | 4 | 1 | (in OrderEntryController) | (via orderEntryForm) | 1 | No | Yes | **HAS GAPS** |
| 9 | UOM | UOM__c, UOM_Conversion__c | 12 | 3 | 2 | UOM_Conversion_Service | uomConversionManager | 2 | No | Yes | COMPLETE |
| 10 | Warehouse Stock | Warehouse__c, Warehouse_Stock__c, Stock_Transaction__c | 20+ | 4 | 2 | INV_WarehouseStock_Service | stockDashboard, warehouseStockDashboard | 2 | No | Yes | **HAS GAPS** |
| 11 | Batch Master | Batch_Master__c | 9 | 3 | 1 | - | (via stockDashboard) | 1 | No | Yes | **HAS GAPS** |
| 12 | Schemes | Scheme__c, Scheme_Product__c, Scheme_Slab__c, Scheme_Mapping__c | 60+ | 2 | 4 | SPM_SchemeEngine_Service | schemeManager, schemeViewer | 4+ | Yes | Yes | COMPLETE |
| 13 | Orders | Sales_Order__c, Order_Line_Item__c | 72 | 0 | 2 | OMS_OrderPricing_Service, OMS_OrderValidation_Service, OMS_StockAvailability_Service | orderEntryForm | 2 | Yes | Yes | **HAS GAPS** |

---

## CROSS-MODULE GAPS

### GAP-01: Must-Sell Enforcement is Advisory Only, Not Blocking

**Severity:** HIGH
**Modules:** Must_Sell_Config (8) ↔ Orders (13)

**Current state:**
- `Must_Sell_Config__c` object fully configured with 9 fields, 4 validation rules, trigger handler
- `OrderEntryController.getMustSellProducts()` correctly queries active configs, filters by territory/channel/outlet type, and returns must-sell products to the LWC
- `Sales_Order__c` has `Must_Sell_Compliance__c` (Percent) and `Must_Sell_Override__c` (Checkbox) fields
- Feature toggle `SPM-002` (SPM_Must_Sell_Enforcement) is enabled

**What's missing:**
- `OMS_OrderValidation_Service.cls` has NO `validateMustSellCompliance()` method
- No trigger logic blocks order submission when must-sell products are absent or below min quantity
- `Must_Sell_Compliance__c` is never auto-calculated (stored as-is from frontend)
- Focused Sell products shown in LWC but have no differentiated enforcement from Must Sell

**Impact:** Field reps can submit orders without any must-sell products. Compliance tracking relies entirely on manual frontend entry.

**Fix:** Add `validateMustSellCompliance()` to `OMS_OrderValidation_Service`; call from `OMS_SalesOrder_TriggerHandler.beforeUpdate()` when status → Submitted.

---

### GAP-02: Scheme Engine Does Not Use UOM-Converted Base Quantity

**Severity:** HIGH
**Modules:** Schemes (12) ↔ UOM (9) ↔ Orders (13)

**Current state:**
- `UOM_Conversion_Service` correctly converts quantities and populates `Base_Quantity__c` on `Order_Line_Item__c`
- `OMS_OrderPricing_Service` uses `Base_Quantity__c` for pricing when available

**What's missing:**
- `SPM_SchemeEngine_Service.cls` has zero references to `Base_Quantity__c`
- Scheme slab evaluation uses raw `Quantity__c` regardless of UOM
- Same order placed in Cases (qty=1) vs Pieces (qty=12) may trigger different scheme tiers

**Impact:** Inconsistent scheme application depending on the UOM chosen at order entry.

**Fix:** Update `SPM_SchemeEngine_Service` to use `Base_Quantity__c` (falling back to `Quantity__c`) for all slab evaluations.

---

### GAP-03: Warehouse_Stock__c.Batch_Number__c is Text, Not Lookup

**Severity:** HIGH
**Modules:** Warehouse Stock (10) ↔ Batch Master (11)

**Current state:**
- `Batch_Master__c` object exists with proper fields (Batch_Number, Expiry_Date, Product, Status)
- `Order_Line_Item__c.Batch_Master__c` is a proper Lookup to `Batch_Master__c`
- But `Warehouse_Stock__c.Batch_Number__c` is a **Text(100)** field, NOT a Lookup

**What's missing:**
- No referential integrity between warehouse stock and batch master records
- `INV_WarehouseStock_Service` uses Batch_Number as a string key, not an Id reference
- Cannot query "which warehouse stock records belong to this batch" via relationship
- Stock operations cannot validate batch status (Active/Expired/Recalled) before transactions

**Impact:** Batch-level stock tracking has no relational integrity. Expired batches could be counted as available.

**Fix:** Add a `Batch_Master__c` Lookup field on `Warehouse_Stock__c` (alongside or replacing `Batch_Number__c`).

---

### GAP-04: Stock Availability Check Ignores Batch Expiry

**Severity:** HIGH
**Modules:** Orders (13) ↔ Warehouse Stock (10) ↔ Batch Master (11)

**Current state:**
- `OMS_StockAvailability_Service.validateStockAvailability()` queries `Warehouse_Stock__c` by Warehouse + Product
- `OMS_Invoice_TriggerHandler` correctly calls `reserveStock()` on Invoice Confirmed, `deductStock()` on Dispatched, `releaseReservation()` on Cancelled

**What's missing:**
- `OMS_StockAvailability_Service` has zero references to `Expiry` or `expired`
- Expired batch stock is counted as available
- No FEFO (First Expiry First Out) allocation logic anywhere

**Impact:** Orders can be fulfilled with expired stock. Critical for pharma and food FMCG products.

**Fix:** Add expiry date filter to stock availability queries; implement FEFO allocation in `INV_WarehouseStock_Service`.

---

### GAP-05: Invoice Generation Does Not Copy Batch Information

**Severity:** MEDIUM
**Modules:** Orders (13) ↔ Batch Master (11)

**Current state:**
- `Order_Line_Item__c.Batch_Master__c` (Lookup) exists
- `OMS_InvoiceGeneration_Service` creates `Invoice_Line__c` from order line items

**What's missing:**
- Invoice generation service does not copy `Batch_Master__c` to invoice lines
- `Invoice_Line__c` has `Batch_No__c` (Text) but it's not populated from order line item's batch

**Impact:** Invoices lack batch traceability. Stock operations at invoice level use `Batch_No__c` which is empty.

**Fix:** Update `OMS_InvoiceGeneration_Service` to populate `Invoice_Line__c.Batch_No__c` from `Order_Line_Item__c.Batch_Master__r.Batch_Number__c`.

---

### GAP-06: Price_Type__c and Min_Qty__c Not Used in Price Resolution

**Severity:** MEDIUM
**Modules:** Pricebooks (7) ↔ Orders (13)

**Current state:**
- `Price_List__c` has `Price_Type__c` picklist (Base Price, Special Offer, Bulk Discount, Scheme Price, Regional)
- `Price_List__c` has `Min_Qty__c` for quantity-based price breaks

**What's missing:**
- `OMS_OrderPricing_Service` has zero references to `Price_Type__c` - all active prices are treated equally
- `OMS_OrderPricing_Service` has zero references to `Min_Qty__c` - quantity-based pricing tiers not implemented
- No distinction between base price and special offer in the 8-tier priority resolution

**Impact:** Bulk pricing discounts don't apply automatically. Special offer prices not differentiated from base prices.

**Fix:** Add `Price_Type__c` filtering (prefer Base Price for standard resolution) and `Min_Qty__c` threshold matching in `OMS_OrderPricing_Service.resolvePriceByPriority()`.

---

### GAP-07: Product_Extension Min_Order_Qty Not Enforced at Order Level

**Severity:** MEDIUM
**Modules:** Products (6) ↔ Orders (13)

**Current state:**
- `Product_Extension__c.Min_Order_Qty__c` exists with validation rule ensuring positive value
- `OrderEntryController.searchProducts()` returns Min_Order_Qty to the LWC

**What's missing:**
- `OMS_OrderLineItem_TriggerHandler` has zero references to `Min_Order_Qty` or `MOQ`
- No backend validation that order quantity >= product's minimum order quantity

**Impact:** Orders can be placed below minimum order quantity. Frontend may show warning but backend doesn't enforce.

**Fix:** Add MOQ validation in `OMS_OrderLineItem_TriggerHandler.beforeInsert/beforeUpdate()`.

---

### GAP-08: Visit Must-Sell Metrics Not Auto-Calculated from Orders

**Severity:** MEDIUM
**Modules:** Visits (5) ↔ Must Sell (8) ↔ Orders (13)

**Current state:**
- `Visit__c` has fields: `Must_Sell_Products_Required__c` (Number), `Must_Sell_Products_Ordered__c` (Number), `Must_Sell_Compliance__c` (Percent)
- `OVE_Visit_TriggerHandler` calculates productive calls and updates Day_Attendance

**What's missing:**
- `Must_Sell_Products_Ordered__c` is a manual number field - not auto-calculated from Order_Line_Item__c
- No trigger on Sales_Order/Order_Line_Item updates Visit's must-sell compliance
- `Must_Sell_Compliance__c` on Visit not calculated from actual order line items vs config

**Impact:** Must-sell compliance at visit level is unreliable - depends on manual entry.

**Fix:** Add logic in `OMS_SalesOrder_TriggerHandler.afterInsert/afterUpdate()` to calculate visit-level must-sell metrics from order line items.

---

### GAP-09: Beat_Outlet Composite Uniqueness Not Enforced

**Severity:** LOW
**Modules:** Beats (2)

**Current state:**
- `Beat_Outlet__c` links `Beat__c` to `Account` with validation rules requiring both fields

**What's missing:**
- No uniqueness constraint on (Beat__c, Account__c) composite key
- Same account can be added to the same beat multiple times
- `BPM_BeatOutlet_TriggerHandler` doesn't check for duplicates

**Impact:** Duplicate beat-outlet assignments inflate Total_Outlets count and journey plan visit counts.

**Fix:** Add duplicate detection in `BPM_BeatOutlet_TriggerHandler.beforeInsert()`.

---

### GAP-10: Deprecated Fields Not Cleaned Up

**Severity:** LOW
**Modules:** Account (1), Beats (2), Journey Plans (3), Day Attendance (4)

**Current state:**
Several deprecated fields exist with sync logic in triggers:
- `Account.Active__c` (redundant with `Is_Active__c`)
- `Beat__c.Beat_Day__c` (synced from `Day_of_Week__c`)
- `Beat__c.Beat_Frequency__c` (synced from `Frequency__c`)
- `Journey_Plan__c.Salesperson__c` (synced from `User__c`)
- `Day_Attendance__c.Salesperson__c` (synced from `User__c`)
- `Day_Attendance__c.Total_Orders_Value__c` / `Total_Collections__c` / `Total_Distance__c` (synced copies)

**Impact:** Confusion about which field is authoritative. Extra trigger processing for field sync.

---

### GAP-11: Scheme Slab Overlap Validation Missing

**Severity:** LOW
**Modules:** Schemes (12)

**Current state:**
- `Scheme_Slab__c` has `Min_Value__c`, `Max_Value__c`, `Min_Quantity__c`, `Max_Quantity__c`
- `SPM_SchemeSlab_TriggerHandler` exists but doesn't validate overlapping ranges

**What's missing:**
- No validation preventing slabs [1-10] and [5-15] on the same scheme
- Overlapping slabs could cause unpredictable scheme evaluation results

**Fix:** Add slab overlap detection in `SPM_SchemeSlab_TriggerHandler.beforeInsert/beforeUpdate()`.

---

### GAP-12: Account Territory Not Mandatory for Field Operations

**Severity:** LOW
**Modules:** Account (1) ↔ Journey Plans (3) ↔ Must Sell (8) ↔ Schemes (12)

**Current state:**
- `Account.Territory__c` is optional (no validation rule requiring it)
- Journey Plan generation, Must Sell filtering, and Scheme evaluation all use territory for filtering

**What's missing:**
- Accounts without territory won't appear in territory-filtered must-sell configs
- Scheme territory-based mapping may not apply to accounts missing territory

**Fix:** Add validation rule requiring Territory when record type is Retailer or Modern_Trade.

---

## WHAT'S WORKING WELL (No Gaps)

These cross-module integrations are **fully functional**:

1. **Account → Beat → Journey Plan → Day Attendance → Visit** flow: Complete chain with proper lookups, rollup calculations, and status transitions
2. **Visit check-in/out with geo-fence validation**: OVE_GeoValidation_Service properly validates coordinates against Account.Geofence_Radius
3. **Visit completion → Day Attendance summary**: Trigger rollup of visits, productive calls, orders, collections to Day_Attendance
4. **Order → Invoice generation**: OMS_SalesOrder_TriggerHandler triggers OMS_InvoiceGeneration_Service on approval
5. **Invoice → Stock reserve/deduct/release**: OMS_Invoice_TriggerHandler correctly calls INV_WarehouseStock_Service on status transitions
6. **Invoice → Credit utilization**: Account credit limits updated via invoice trigger
7. **Order → Scheme application**: SPM_SchemeEngine_Service evaluates schemes with stacking, budget tracking, and slab support
8. **Order → Tax calculation**: MDM_TaxEngine_Service calculates GST (CGST/SGST/IGST) based on state
9. **UOM conversion in orders**: OrderEntryController uses UOM_Conversion_Service for quantity conversion
10. **Price resolution with 8-tier priority**: OMS_OrderPricing_Service resolves customer/territory/channel/category pricing
11. **Feature toggle system**: All modules respect Feature_Toggle__mdt for runtime enable/disable
12. **Status transition validation**: All objects use Status_Transition__mdt for valid state changes
13. **Approval workflows**: Journey Plans, Sales Orders, Schemes, Expenses all have approval processes
14. **Permission sets**: 10 permission sets covering all personas with appropriate CRUD access
15. **Profile coverage**: 48 profiles updated with field-level security for all custom objects

---

## RECOMMENDED FIX PRIORITY

| Priority | Gap | Effort | Impact |
|----------|-----|--------|--------|
| P1 | GAP-01: Must-Sell enforcement | Medium | High - core feature not enforcing |
| P1 | GAP-04: Stock availability ignores expiry | Medium | High - expired stock fulfillment risk |
| P2 | GAP-02: Scheme engine UOM mismatch | Low | High - inconsistent scheme application |
| P2 | GAP-03: Warehouse_Stock batch text field | Low | Medium - no referential integrity |
| P2 | GAP-05: Invoice missing batch info | Low | Medium - batch traceability gap |
| P3 | GAP-06: Price_Type/Min_Qty not used | Medium | Medium - bulk pricing not working |
| P3 | GAP-07: MOQ not enforced | Low | Medium - below-minimum orders possible |
| P3 | GAP-08: Visit must-sell auto-calc | Medium | Medium - manual compliance tracking |
| P4 | GAP-09: Beat_Outlet uniqueness | Low | Low - duplicate assignments |
| P4 | GAP-11: Scheme slab overlap | Low | Low - edge case |
| P4 | GAP-12: Account territory validation | Low | Low - filtering gaps |
| P5 | GAP-10: Deprecated field cleanup | Low | Low - code hygiene |
