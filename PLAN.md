# Must Sell & Focused Sell — Implementation Plan

## Current State

`Scheme_Product__c.Product_Classification__c` exists with values **Must Sell** and **Focused Sell**, and the `schemeManager` LWC lets admins set it when adding products to schemes. However, the classification is **completely ignored** everywhere else:

- **OrderEntryController** — `getApplicableSchemes()` doesn't return `Product_Classification__c`
- **SPM_SchemeEngine_Service** — doesn't reference classification at all
- **orderEntryForm LWC** — no UI for must-sell products
- **visitActivity LWC** — no compliance checking
- **OMS_OrderValidation_Service** — no must-sell enforcement

---

## Implementation Plan

### Phase 1: Surface Must-Sell Products in Order Entry

**Goal:** Show salespeople which products are must-sell so they know what to order.

#### Step 1.1 — Expose Must-Sell products from Apex

**File:** `OrderEntryController.cls`

- Add new method `getMustSellProducts(Id accountId, Date orderDate)`:
  - Query active schemes applicable to the account (reuse existing filtering logic from `getApplicableSchemes`)
  - Join to `Scheme_Products__r` where `Product_Classification__c = 'Must Sell'`
  - Return distinct product list with: Product Id, Name, SKU, Min_Quantity__c, Scheme name
- Update `getApplicableSchemes()` subquery on `Scheme_Products__r` to include `Product_Classification__c`

#### Step 1.2 — Display Must-Sell section in Order Entry UI

**File:** `orderEntryForm.js` / `orderEntryForm.html`

- Call `getMustSellProducts` on `connectedCallback` (alongside `loadSchemes`)
- Render a **"Must Sell Products"** section above the product search:
  - Show product name, SKU, required min quantity
  - "Add to Order" button per product (pre-fills quantity with `Min_Quantity__c`)
  - Visual indicator (checkmark) when product is already in the order
- Show a **"Focused Sell"** section below must-sell (collapsible, lower emphasis)
  - Same layout but styled as recommendations, not requirements

#### Step 1.3 — Add classification badges to line items

**File:** `orderEntryForm.html` / `orderEntryForm.css`

- When a line item matches a must-sell product, show a small badge ("Must Sell" / "Focused Sell") next to the product name in the cart
- Reuse the badge CSS classes already in `schemeManager.css` (`badge-must-sell`, `badge-focused-sell`)

---

### Phase 2: Soft Validation (Warning)

**Goal:** Warn salespeople when must-sell products are missing, without blocking the order.

#### Step 2.1 — Client-side warning on order submission

**File:** `orderEntryForm.js`

- Before calling `createSalesOrder`, compare `lineItems` against `mustSellProducts`
- If any must-sell product is missing, show a **confirmation modal**:
  - "The following must-sell products are not in this order: [Product A, Product B]. Continue anyway?"
  - User can choose "Add Products" (go back) or "Submit Anyway"
- Track the override: add a field `Must_Sell_Override__c` (Checkbox) on `Sales_Order__c` — set to `true` if user submitted despite missing must-sell products

#### Step 2.2 — New field on Sales_Order__c

**New field:** `Sales_Order__c.Must_Sell_Override__c`
- Type: Checkbox, default false
- Label: "Must Sell Override"
- Purpose: Audit trail — marks orders where salesperson acknowledged missing must-sell products

**New field:** `Sales_Order__c.Must_Sell_Compliance__c`
- Type: Percent (formula)
- Formula: Count of must-sell products ordered / Total must-sell products applicable
- Label: "Must Sell Compliance %"

---

### Phase 3: Visit-Level Compliance

**Goal:** Track must-sell compliance at the visit level.

#### Step 3.1 — New fields on Visit__c

**New field:** `Visit__c.Must_Sell_Compliance__c`
- Type: Percent, precision 5 scale 2
- Label: "Must Sell Compliance"
- Populated after order submission

**New field:** `Visit__c.Must_Sell_Products_Ordered__c`
- Type: Number
- Label: "Must Sell Products Ordered"

**New field:** `Visit__c.Must_Sell_Products_Required__c`
- Type: Number
- Label: "Must Sell Products Required"

#### Step 3.2 — Update visit completion summary

**File:** `OVE_Visit_Service.cls` → `checkOut()` method

- On visit completion, query orders for the visit
- Cross-reference order line items against must-sell products for the outlet
- Calculate and set `Must_Sell_Compliance__c`, `Must_Sell_Products_Ordered__c`, `Must_Sell_Products_Required__c`

#### Step 3.3 — Show compliance in visit activity UI

**File:** `visitActivity.html` / `visitActivity.js`

- In the checkout modal summary, add a "Must Sell Compliance" row showing X/Y products (e.g., "3/5 must-sell products ordered — 60%")
- Color code: green (100%), yellow (50-99%), red (<50%)

---

### Phase 4: Feature Toggle & Reporting

#### Step 4.1 — Feature toggle

**New metadata record:** `Feature_Toggle.SPM_Must_Sell_Enforcement.md-meta.xml`
- Feature_Code: `SPM-002`
- Label: "Must Sell Enforcement"
- Default: `true`
- Tier: `Base`

All must-sell logic gates behind `BPM_FeatureToggle_Util.isEnabled('SPM-002')`.

#### Step 4.2 — Reporting fields

Already handled by the formula field `Must_Sell_Compliance__c` on both `Sales_Order__c` and `Visit__c`. These are reportable out of the box via Salesforce reports:
- Must-sell compliance by salesperson
- Must-sell compliance by territory
- Must-sell compliance by outlet
- Orders with must-sell override

---

## Files to Create/Modify

| File | Action | Phase |
|---|---|---|
| `OrderEntryController.cls` | Add `getMustSellProducts()`, update `getApplicableSchemes()` | 1 |
| `orderEntryForm.js` | Add must-sell loading, display, and validation | 1, 2 |
| `orderEntryForm.html` | Add must-sell section, badges, warning modal | 1, 2 |
| `orderEntryForm.css` | Badge styles (reuse from schemeManager) | 1 |
| `Sales_Order__c/fields/Must_Sell_Override__c` | New checkbox field | 2 |
| `Sales_Order__c/fields/Must_Sell_Compliance__c` | New formula field | 2 |
| `Visit__c/fields/Must_Sell_Compliance__c` | New percent field | 3 |
| `Visit__c/fields/Must_Sell_Products_Ordered__c` | New number field | 3 |
| `Visit__c/fields/Must_Sell_Products_Required__c` | New number field | 3 |
| `OVE_Visit_Service.cls` | Calculate compliance on checkout | 3 |
| `visitActivity.html` / `visitActivity.js` | Show compliance in checkout | 3 |
| `Feature_Toggle.SPM_Must_Sell_Enforcement.md-meta.xml` | New feature toggle | 4 |

---

## Out of Scope (Future)

- **Hard blocking** — preventing order submission entirely if must-sell products are missing (requires business decision)
- **Manager notifications** — alerting managers when compliance drops below threshold
- **Scheme engine integration** — using classification to modify scheme benefit calculation (e.g., bonus discount for ordering all must-sell products)
- **Beat-level must-sell targets** — configuring different must-sell lists per beat or territory beyond what schemes already provide
