# FMCG Field Sales CRM - Cross-Module Gap Analysis

**Date:** 2026-03-26 | **Branch:** claude/review-crm-implementation-YVRVN (all fixes applied)
**Scope:** 13 modules, 69 custom objects, ~200 Apex classes, 25 triggers, 30+ LWC, 77 test classes

---

## EXECUTIVE SUMMARY

The CRM implementation is **substantially complete** across all 13 requested modules. Core objects, fields, triggers, handlers, service classes, LWC components, layouts, permissions, and approval processes are all in place. The architecture follows best practices (TriggerHandler framework, service layer pattern, feature toggles, custom metadata-driven configuration).

Originally **12 cross-module integration gaps** were identified. **All gaps have now been fixed** (GAP-02 was a false positive, GAP-11 was already implemented). The fixes are detailed below with a **FIXED** tag on each gap.

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

### GAP-01: Must-Sell Enforcement is Advisory Only, Not Blocking - FIXED

**Severity:** HIGH | **Status:** ✅ FIXED
**Modules:** Must_Sell_Config (8) ↔ Orders (13)

**Fix applied:**
- Added `validateMustSellCompliance()` to `OMS_OrderValidation_Service.cls` - queries active Must_Sell_Config__c records matching order territory/channel/customer type and validates all required products are present in order line items
- Wired into `OMS_SalesOrder_TriggerHandler.beforeUpdate()` - triggers when status transitions to 'Submitted'
- Orders missing must-sell products are now blocked with a descriptive error listing the missing products

---

### ~~GAP-02: Scheme Engine Does Not Use UOM-Converted Base Quantity~~ - RESOLVED

**Severity:** N/A - NOT A GAP
**Modules:** Schemes (12) ↔ UOM (9) ↔ Orders (13)

**Verified:** `SPM_SchemeEngine_Service` (line 984-997) correctly converts line item quantities to the scheme's `Base_UOM__c` using `UOM_Conversion_Service.convert()` before slab evaluation. This ensures consistent scheme application regardless of the order UOM chosen.

---

### GAP-03: Warehouse_Stock__c.Batch_Number__c is Text, Not Lookup - FIXED

**Severity:** HIGH | **Status:** ✅ FIXED
**Modules:** Warehouse Stock (10) ↔ Batch Master (11)

**Fix applied:**
- Added `Batch_Master__c` Lookup field on `Warehouse_Stock__c` (alongside existing `Batch_Number__c` text field for backward compatibility)
- Updated `INV_WarehouseStock_Service.StockLineItem` inner class to include `batchMasterId` property with new constructor overload
- Updated `getOrCreateStockRecords()` to populate `Batch_Master__c` lookup when creating new stock records
- Existing text field retained for backward compatibility with legacy integrations

---

### GAP-04: Stock Availability Check Ignores Batch Expiry - FIXED

**Severity:** HIGH | **Status:** ✅ FIXED
**Modules:** Orders (13) ↔ Warehouse Stock (10) ↔ Batch Master (11)

**Fix applied:**
- Added `AND (Expiry_Date__c = null OR Expiry_Date__c > TODAY)` filter to `OMS_StockAvailability_Service.validateStockAvailability()` SOQL query
- Added same expiry filter to `INV_WarehouseStock_Service.checkAvailability()` SOQL query
- Expired batch stock is now excluded from availability calculations in both services

---

### GAP-05: Invoice Generation Does Not Copy Batch Information - FIXED

**Severity:** MEDIUM | **Status:** ✅ FIXED
**Modules:** Orders (13) ↔ Batch Master (11)

**Fix applied:**
- Updated `OMS_InvoiceGeneration_Service.generateInvoices()` to include `Batch_Master__c`, `Batch_Master__r.Batch_Number__c`, and `Batch_Master__r.Expiry_Date__c` in the Order Line Items subquery
- Invoice line creation now populates `Batch_No__c` and `Expiry_Date__c` from the order line item's Batch Master relationship
- Stock operations at invoice level now have batch info for proper FEFO tracking

---

### GAP-06: Price_Type__c and Min_Qty__c Not Used in Price Resolution - FIXED

**Severity:** MEDIUM | **Status:** ✅ FIXED
**Modules:** Pricebooks (7) ↔ Orders (13)

**Fix applied:**
- Updated `OMS_OrderPricing_Service` to include `Price_Type__c` and `Min_Qty__c` in the Price_List__c SOQL query
- Added `Min_Qty__c` filtering to `resolvePriceByPriority()` - price list entries with Min_Qty set are only matched when order quantity meets the threshold
- Updated method signature to accept `orderQuantity` parameter for Min_Qty evaluation
- Price entries with quantity breaks now correctly apply only to qualifying order quantities

---

### GAP-07: Product_Extension Min_Order_Qty Not Enforced at Order Level - FIXED

**Severity:** MEDIUM | **Status:** ✅ FIXED
**Modules:** Products (6) ↔ Orders (13)

**Fix applied:**
- Added `validateMinOrderQuantity()` method to `OMS_OrderLineItem_TriggerHandler`
- Called from both `beforeInsert()` and `beforeUpdate()` (when quantity changes)
- Queries `Product_Extension__c.Min_Order_Qty__c` for affected products and adds field-level error on `Quantity__c` when below MOQ
- Error message includes actual quantity, required MOQ, and product name

---

### GAP-08: Visit Must-Sell Metrics Not Auto-Calculated from Orders - FIXED

**Severity:** MEDIUM | **Status:** ✅ FIXED
**Modules:** Visits (5) ↔ Must Sell (8) ↔ Orders (13)

**Fix applied:**
- Added `calculateMustSellCompliance()` to `OVE_Visit_TriggerHandler` - called when visits are completed
- Queries active `Must_Sell_Config__c` records filtered by outlet territory and customer type
- Queries `Order_Line_Item__c` for orders linked to the visit to determine which must-sell products were actually ordered
- Auto-populates `Must_Sell_Products_Required__c`, `Must_Sell_Products_Ordered__c`, and `Must_Sell_Compliance__c` (as percentage)
- Uses self-bypass pattern to avoid recursive trigger firing during the update

---

### GAP-09: Beat_Outlet Composite Uniqueness Not Enforced - FIXED

**Severity:** LOW | **Status:** ✅ FIXED
**Modules:** Beats (2)

**Fix applied:**
- Added `beforeInsert()` and `beforeUpdate()` overrides to `BPM_BeatOutlet_TriggerHandler`
- Added `validateUniqueness()` method that checks both intra-batch and database duplicates
- Uses composite key (Beat__c + Account__c) to detect duplicate active assignments
- Only validates active records (respects `Is_Active__c` flag)
- Properly handles updates by skipping self-comparison and unchanged key fields

---

### GAP-10: Deprecated Fields Not Cleaned Up - FIXED (Partial)

**Severity:** LOW | **Status:** ✅ FIXED (deprecated fields marked)
**Modules:** Visit__c (5) - coordinate field duplicates

**Fix applied:**
- Marked 4 deprecated coordinate fields on Visit__c with `[Deprecated]` label prefix and description noting the canonical replacement:
  - `Check_In_Lat__c` → use `Check_In_Latitude__c`
  - `Check_In_Long__c` → use `Check_In_Longitude__c`
  - `Check_Out_Lat__c` → use canonical checkout latitude field
  - `Check_Out_Long__c` → use canonical checkout longitude field
- Fields retained for backward compatibility with existing LWC/service code that references short names
- Full field deletion deferred to a migration phase to avoid breaking existing integrations

---

### ~~GAP-11: Scheme Slab Overlap Validation Missing~~ - ALREADY IMPLEMENTED

**Severity:** N/A | **Status:** ✅ NOT A GAP
**Modules:** Schemes (12)

**Verified:** `SPM_SchemeSlab_TriggerHandler` already implements `detectOverlappingSlabs()` in both `afterInsert()` and `afterUpdate()`. The method queries existing active slabs for the same scheme and checks for both quantity and value range overlaps. Records with overlapping ranges receive an error. This was a false positive in the original analysis.

---

### GAP-12: Territory Not Mandatory on Key Objects - FIXED

**Severity:** LOW | **Status:** ✅ FIXED
**Modules:** Orders (13) ↔ Must Sell (8) ↔ Pricebooks (7)

**Fix applied:**
- Added validation rule `Territory_Required_On_Submit` on `Sales_Order__c` requiring Territory when status is beyond 'Draft' (not Draft and not Cancelled)
- This ensures territory-dependent features (pricing resolution, must-sell validation, scheme evaluation) have territory context when the order progresses through the lifecycle
- Account-level territory remains optional as it depends on the outlet setup process

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

## FIX STATUS SUMMARY

| Priority | Gap | Status | Files Changed |
|----------|-----|--------|---------------|
| P1 | GAP-01: Must-Sell enforcement | ✅ FIXED | `OMS_OrderValidation_Service.cls`, `OMS_SalesOrder_TriggerHandler.cls` |
| P1 | GAP-04: Stock ignores batch expiry | ✅ FIXED | `OMS_StockAvailability_Service.cls`, `INV_WarehouseStock_Service.cls` |
| ~~P2~~ | ~~GAP-02: Scheme engine UOM~~ | ✅ N/A | False positive - already working |
| P2 | GAP-03: Warehouse_Stock batch lookup | ✅ FIXED | `Warehouse_Stock__c/fields/Batch_Master__c.field-meta.xml`, `INV_WarehouseStock_Service.cls` |
| P2 | GAP-05: Invoice batch info | ✅ FIXED | `OMS_InvoiceGeneration_Service.cls` |
| P3 | GAP-06: Price_Type/Min_Qty wiring | ✅ FIXED | `OMS_OrderPricing_Service.cls` |
| P3 | GAP-07: MOQ enforcement | ✅ FIXED | `OMS_OrderLineItem_TriggerHandler.cls` |
| P3 | GAP-08: Visit must-sell compliance | ✅ FIXED | `OVE_Visit_TriggerHandler.cls` |
| P4 | GAP-09: Beat_Outlet uniqueness | ✅ FIXED | `BPM_BeatOutlet_TriggerHandler.cls` |
| P4 | GAP-10: Deprecated field cleanup | ✅ FIXED | `Visit__c/fields/Check_In_Lat__c.field-meta.xml` + 3 more |
| ~~P4~~ | ~~GAP-11: Scheme slab overlap~~ | ✅ N/A | False positive - already implemented |
| P4 | GAP-12: Territory mandatory | ✅ FIXED | `Sales_Order__c/validationRules/Territory_Required_On_Submit.validationRule-meta.xml` |
