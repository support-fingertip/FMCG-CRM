# UOM & UOM Conversions — Implementation Plan

## Current State Analysis

### What Exists Today

1. **Product_Extension__c** has:
   - `Unit_of_Measure__c` — Picklist (Piece, Box, Case, Kg, Litre, Dozen, Pack)
   - `Case_Size__c` — Number (pieces per case, but not linked to any conversion logic)
   - `Weight__c` / `Weight_Unit__c` — Product weight (kg, g, l, ml, units)

2. **Order_Line_Item__c** has:
   - `UOM__c` — Picklist (Pieces, Cases, Boxes, Kg, Liters) — inconsistent values with Product
   - `Quantity__c` — number, always in the UOM selected on the line item
   - No base-quantity field, no conversion factor stored

3. **Invoice_Line__c** has:
   - `UOM__c` — Plain Text(20), copied from order line as-is
   - No conversion tracking

4. **Scheme__c** has:
   - `Invoice_Qty_UOM__c` — Picklist (PC, KG, LTR, CS) — yet another inconsistent set of values

### Key Problems

| Problem | Impact |
|---|---|
| **No UOM master** — UOM values are hardcoded picklists with inconsistent naming across objects (Piece vs Pieces vs PC) | Unreliable data, impossible to query cross-object |
| **No conversion table** — `Case_Size__c` exists but there's no structured way to define "1 Case = 24 Pieces" per product | Sales reps can't order in Cases and have the system convert to base units |
| **No base quantity tracking** — Order lines store qty in whatever UOM was selected, making reporting/inventory inaccurate | Stock checks compare apples to oranges when UOMs differ |
| **Order entry ignores UOM** — `OrderEntryController` doesn't set `UOM__c` on line items at all | Line items default to null UOM |
| **No UOM selection in order entry UI** — `orderEntryForm` LWC has no UOM picker per line item | Reps can only order in the product's default UOM |

---

## Implementation Plan

### Phase 1: UOM Master Object & Global Value Set

**Goal:** Single source of truth for all UOM values across the org.

#### Step 1.1 — Create Global Value Set: `UOM_Values`

**New file:** `force-app/main/default/globalValueSets/UOM_Values.globalValueSet-meta.xml`

Values (standardized abbreviations):
- `PC` — Piece
- `BX` — Box
- `CS` — Case
- `KG` — Kilogram
- `G` — Gram
- `LTR` — Litre
- `ML` — Millilitre
- `DZ` — Dozen
- `PK` — Pack

#### Step 1.2 — Create `UOM__c` Custom Object (UOM Master)

**New object:** `force-app/main/default/objects/UOM__c/`

| Field | Type | Description |
|---|---|---|
| `Name` | Auto Number (UOM-{0000}) | Record name |
| `UOM_Code__c` | Text(10), Unique, Required | Short code: PC, CS, BX, KG, etc. |
| `UOM_Name__c` | Text(50), Required | Full name: Piece, Case, Box, Kilogram |
| `UOM_Type__c` | Picklist: Count, Weight, Volume | Category for grouping |
| `Is_Base_UOM__c` | Checkbox | Whether this is a base UOM (Piece for count, Kg for weight, Litre for volume) |
| `Is_Active__c` | Checkbox, default true | Soft delete |

#### Step 1.3 — Create `UOM_Conversion__c` Object (Conversion Rules)

**New object:** `force-app/main/default/objects/UOM_Conversion__c/`

| Field | Type | Description |
|---|---|---|
| `Name` | Auto Number (UOMC-{0000}) | Record name |
| `Product_Ext__c` | Lookup(Product_Extension__c), Optional | Product-specific conversion (null = global default) |
| `Product_Category__c` | Lookup(Product_Category__c), Optional | Category-level conversion |
| `From_UOM__c` | Lookup(UOM__c), Required | Source UOM |
| `To_UOM__c` | Lookup(UOM__c), Required | Target UOM |
| `Conversion_Factor__c` | Number(18,6), Required | Multiply From-qty by this to get To-qty |
| `Is_Active__c` | Checkbox, default true | Soft delete |

**Conversion logic priority:** Product-specific → Category-level → Global default

**Examples:**
| Product | From | To | Factor | Meaning |
|---|---|---|---|---|
| Coca Cola 250ml | CS | PC | 24 | 1 Case = 24 Pieces |
| Coca Cola 500ml | CS | PC | 12 | 1 Case = 12 Pieces |
| *(global)* | DZ | PC | 12 | 1 Dozen = 12 Pieces |
| *(global)* | KG | G | 1000 | 1 Kg = 1000 Grams |

---

### Phase 2: Product UOM Configuration

**Goal:** Each product defines its base UOM and allowed ordering UOMs.

#### Step 2.1 — New fields on Product_Extension__c

| Field | Type | Description |
|---|---|---|
| `Base_UOM__c` | Lookup(UOM__c) | The base/stock UOM (replaces picklist `Unit_of_Measure__c`) |
| `Ordering_UOMs__c` | Text(255) | Comma-separated UOM codes allowed for ordering (e.g., "PC,CS,BX") |

The existing `Unit_of_Measure__c` picklist and `Case_Size__c` fields remain for backward compatibility but are no longer the source of truth.

#### Step 2.2 — Data migration script

**New file:** `scripts/apex/migrate-uom-data.apex`

- Create UOM__c master records for all current picklist values
- Create default UOM_Conversion__c records (e.g., CS→PC using existing `Case_Size__c`, DZ→PC = 12)
- Populate `Base_UOM__c` on all Product_Extension__c records by mapping `Unit_of_Measure__c` picklist values to UOM__c lookup records
- Populate `Ordering_UOMs__c` with sensible defaults based on `UOM_Type__c`

---

### Phase 3: Conversion Service (Apex)

**Goal:** Central Apex utility for UOM conversions used by order entry, invoicing, stock, and schemes.

#### Step 3.1 — `UOM_Conversion_Service.cls`

**New file:** `force-app/main/default/classes/UOM_Conversion_Service.cls`

```
public with sharing class UOM_Conversion_Service {

    // Convert quantity from one UOM to another for a given product
    public static Decimal convert(Id productId, String fromUomCode, String toUomCode, Decimal quantity);

    // Get conversion factor (product-specific → category → global fallback)
    public static Decimal getConversionFactor(Id productId, String fromUomCode, String toUomCode);

    // Get allowed UOMs for a product (returns list of UOM records)
    public static List<UOM__c> getProductUOMs(Id productId);

    // Bulk convert: Map<lineItemId, ConvertedResult>
    public static Map<Id, ConvertedResult> bulkConvert(List<ConversionRequest> requests);

    // Inner classes
    public class ConversionRequest {
        public Id productId;
        public String fromUomCode;
        public String toUomCode;
        public Decimal quantity;
    }

    public class ConvertedResult {
        public Decimal convertedQuantity;
        public Decimal conversionFactor;
        public String baseUomCode;
    }
}
```

#### Step 3.2 — Test class

**New file:** `force-app/main/default/classes/UOM_Conversion_Service_Test.cls`

Test scenarios:
- Product-specific conversion (CS → PC for product with Case_Size = 24)
- Global fallback conversion (DZ → PC)
- Category-level conversion
- Reverse conversion (PC → CS)
- Missing conversion throws descriptive error
- Bulk conversion performance test

---

### Phase 4: Order Entry Integration

**Goal:** Sales reps can select UOM per line item; system stores both ordering qty and base qty.

#### Step 4.1 — New fields on Order_Line_Item__c

| Field | Type | Description |
|---|---|---|
| `Order_UOM__c` | Lookup(UOM__c) | The UOM the rep ordered in |
| `Base_Quantity__c` | Number(18,3) | Quantity converted to base UOM |
| `Base_UOM__c` | Lookup(UOM__c) | The product's base UOM (denormalized for reporting) |
| `Conversion_Factor__c` | Number(18,6) | Factor used at time of order (snapshot) |

Existing `Quantity__c` remains as the "ordering quantity" (what the rep entered).
Existing `UOM__c` picklist remains for backward compatibility.

#### Step 4.2 — Update `OrderEntryController.cls`

- `searchProducts()` / product queries: include `Base_UOM__c`, `Ordering_UOMs__c` from Product_Extension__c
- `createSalesOrder()`: for each line item, call `UOM_Conversion_Service.convert()` to compute `Base_Quantity__c` and store `Conversion_Factor__c`
- New method `getProductUOMs(Id productId)`: returns allowed UOMs for the combobox

#### Step 4.3 — Update `orderEntryForm` LWC

**Files:** `orderEntryForm.js`, `orderEntryForm.html`, `orderEntryForm.css`

- Add UOM combobox per line item row (populated from product's `Ordering_UOMs__c`)
- Default to product's `Base_UOM__c`
- On UOM change: recalculate line amount using conversion factor (e.g., if unit price is per Piece and rep orders in Cases, multiply price × case size)
- Show converted base quantity as helper text: "= 24 PC" below the quantity input
- Pass selected UOM to `createSalesOrder()`

---

### Phase 5: Invoice & Stock Integration

**Goal:** Propagate UOM data through the downstream flow.

#### Step 5.1 — New fields on Invoice_Line__c

| Field | Type | Description |
|---|---|---|
| `Order_UOM__c` | Lookup(UOM__c) | UOM from the order |
| `Base_Quantity__c` | Number(18,3) | Base quantity |
| `Base_UOM__c` | Lookup(UOM__c) | Base UOM |
| `Conversion_Factor__c` | Number(18,6) | Conversion factor |

#### Step 5.2 — Update `OMS_InvoiceGeneration_Service.cls`

- Copy UOM fields from Order_Line_Item__c to Invoice_Line__c during invoice generation

#### Step 5.3 — Update stock services

**Files:** `OVE_StockCheck_Service.cls`, Stock_Transaction__c queries

- When checking/updating stock, always work in base UOM
- Convert order quantities to base UOM before comparing with warehouse stock
- Display stock in base UOM but show equivalent in ordering UOM

---

### Phase 6: UOM Management UI

**Goal:** Admin interface to manage UOMs and conversion rules.

#### Step 6.1 — UOM Management LWC

**New component:** `force-app/main/default/lwc/uomManagement/`

Features:
- List/Create/Edit UOM master records
- List/Create/Edit conversion rules
- Filter conversions by product or category
- Bulk import conversions (CSV)
- Validation: prevent duplicate conversions, circular conversions

#### Step 6.2 — Product UOM Configuration in Product Management

**Update:** `productManagementHub` LWC

- Replace `Unit_of_Measure__c` picklist combobox with `Base_UOM__c` lookup
- Add multi-select for `Ordering_UOMs__c`
- Show conversion rules inline for the product (with add/edit capability)
- Show `Case_Size__c` as a quick-entry that auto-creates CS→PC conversion

---

### Phase 7: Scheme Engine UOM Alignment

**Goal:** Scheme quantity thresholds work correctly with UOM conversions.

#### Step 7.1 — Update `SPM_SchemeEngine_Service.cls`

- When evaluating quantity-based schemes, convert order line quantities to the scheme's expected UOM using `UOM_Conversion_Service`
- Replace hardcoded `Invoice_Qty_UOM__c` picklist references with UOM__c lookups

#### Step 7.2 — Update Scheme__c fields

| Field | Type | Description |
|---|---|---|
| `Invoice_Qty_UOM_Ref__c` | Lookup(UOM__c) | Replaces `Invoice_Qty_UOM__c` picklist |

---

## Files Summary

| File | Action | Phase |
|---|---|---|
| `globalValueSets/UOM_Values.globalValueSet-meta.xml` | Create | 1 |
| `objects/UOM__c/` (object + fields) | Create | 1 |
| `objects/UOM_Conversion__c/` (object + fields) | Create | 1 |
| `objects/Product_Extension__c/fields/Base_UOM__c` | Create | 2 |
| `objects/Product_Extension__c/fields/Ordering_UOMs__c` | Create | 2 |
| `scripts/apex/migrate-uom-data.apex` | Create | 2 |
| `classes/UOM_Conversion_Service.cls` | Create | 3 |
| `classes/UOM_Conversion_Service_Test.cls` | Create | 3 |
| `objects/Order_Line_Item__c/fields/Order_UOM__c` | Create | 4 |
| `objects/Order_Line_Item__c/fields/Base_Quantity__c` | Create | 4 |
| `objects/Order_Line_Item__c/fields/Base_UOM__c` | Create | 4 |
| `objects/Order_Line_Item__c/fields/Conversion_Factor__c` | Create | 4 |
| `classes/OrderEntryController.cls` | Modify | 4 |
| `lwc/orderEntryForm/` (js, html, css) | Modify | 4 |
| `objects/Invoice_Line__c/fields/Order_UOM__c` | Create | 5 |
| `objects/Invoice_Line__c/fields/Base_Quantity__c` | Create | 5 |
| `objects/Invoice_Line__c/fields/Base_UOM__c` | Create | 5 |
| `objects/Invoice_Line__c/fields/Conversion_Factor__c` | Create | 5 |
| `classes/OMS_InvoiceGeneration_Service.cls` | Modify | 5 |
| `classes/OVE_StockCheck_Service.cls` | Modify | 5 |
| `lwc/uomManagement/` | Create | 6 |
| `lwc/productManagementHub/` (js, html) | Modify | 6 |
| `classes/SPM_SchemeEngine_Service.cls` | Modify | 7 |
| `objects/Scheme__c/fields/Invoice_Qty_UOM_Ref__c` | Create | 7 |

---

## Feature Toggle

**New metadata record:** `Feature_Toggle.UOM_Conversions.md-meta.xml`
- Feature_Code: `MDM-002`
- Label: "UOM Conversions"
- Default: `true`
- Tier: `Base`

All new UOM conversion logic gates behind `BPM_FeatureToggle_Util.isEnabled('MDM-002')`. When disabled, the system falls back to existing behavior (picklist UOMs, no conversion).

---

## Out of Scope (Future)

- **UOM-based pricing** — different prices per UOM (e.g., case price vs piece price) beyond simple conversion math
- **Purchase order UOM** — inbound procurement UOM handling
- **UOM groups/families** — grouping UOMs into families for complex multi-dimensional conversions
- **Barcode-to-UOM mapping** — scanning a case barcode vs piece barcode to auto-select UOM
- **Minimum order quantity per UOM** — e.g., min 1 Case but min 12 Pieces
