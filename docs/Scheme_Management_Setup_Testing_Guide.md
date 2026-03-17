# Scheme Management — Setup, Configuration & Testing Guide

## Table of Contents

1. [Overview](#1-overview)
2. [The 4×6 Scheme Matrix](#2-the-4x6-scheme-matrix)
3. [Scheme Objects & Field Reference](#3-scheme-objects--field-reference)
4. [Step-by-Step Scheme Creation](#4-step-by-step-scheme-creation)
5. [How Schemes Work in Orders](#5-how-schemes-work-in-orders)
6. [Scheme Engine Evaluation Logic](#6-scheme-engine-evaluation-logic)
7. [Test Scenarios](#7-test-scenarios)
8. [Troubleshooting & FAQs](#8-troubleshooting--faqs)

---

## 1. Overview

The Scheme Management module (SPM) allows creating promotional schemes that automatically apply benefits (discounts, free products, reward points) when sales reps place orders. Schemes flow through three stages:

```
DEFINE (Scheme__c + Scheme_Product__c + Scheme_Slab__c + Scheme_Mapping__c)
   ↓
MATCH (LWC finds applicable schemes for the outlet during order entry)
   ↓
APPLY (Trigger handler calls SPM_SchemeEngine_Service on order save)
```

### Key Components

| Component | Purpose |
|-----------|---------|
| `schemeManager` LWC | Admin UI for creating/editing/managing schemes |
| `schemeViewer` LWC | Read-only display of active schemes with calculator |
| `orderEntryForm` LWC | Shows applicable schemes during order entry |
| `SchemeManagerController.cls` | Apex controller for scheme CRUD operations |
| `SchemeViewController.cls` | Apex controller for scheme display and calculation |
| `OrderEntryController.cls` | Apex controller for order entry (loads schemes for outlet) |
| `SPM_SchemeEngine_Service.cls` | Core engine that evaluates scheme eligibility |
| `OMS_OrderPricing_Service.cls` | Applies scheme discounts to order line items |
| `OMS_OrderLineItem_TriggerHandler.cls` | Trigger that invokes pricing + scheme + tax on save |
| `SPM_Scheme_Auto_Deactivation` (Flow) | Daily scheduled flow that expires past-due schemes |

### Status Workflow

```
Draft → Pending Approval → Active → Expired / Cancelled
```

- **Draft**: Initial creation state, not visible to sales reps
- **Pending Approval**: Submitted for approval
- **Active**: Live and applicable to orders
- **Expired**: Auto-set by daily flow when End_Date__c < TODAY()
- **Cancelled**: Manually deactivated

### Is_Active__c (Formula Field)

This is auto-calculated — do NOT set it manually:
```
AND(Status__c = 'Active', Start_Date__c <= TODAY(), End_Date__c >= TODAY())
```

---

## 2. The 4×6 Scheme Matrix

Every scheme is a combination of **one Scheme Category** (what benefit the customer gets) and **one Scheme Type** (what triggers the benefit).

### Scheme Categories (Benefit Types)

| Category | Description | Key Fields |
|----------|-------------|------------|
| **Free Products** | Customer receives free goods | `Free_Product_Ext__c`, `Free_Quantity__c` |
| **Discount in %** | Percentage discount on qualifying items | `Discount_Percent__c` |
| **Discount in Value** | Flat amount discount | `Discount_Amount__c` or `Price_Discount__c` |
| **Reward Points** | Loyalty points credited to customer | `Reward_Points__c` |

### Scheme Types (Trigger Conditions)

| Type | Trigger Logic | Key Fields |
|------|---------------|------------|
| **Same Product (QTY)** | Customer buys min quantity of the SAME product | `Min_Quantity__c` on Scheme_Product__c |
| **Same Product (VAL)** | Customer spends min value on the SAME product | `MOV__c` or `Min_Value__c` |
| **Assorted Product (QTY)** | Customer buys min quantity across MULTIPLE scheme products | `Min_Quantity__c` per product + header |
| **Assorted Product (VAL)** | Customer spends min value across MULTIPLE scheme products | `MOV__c` or `Min_Value__c` |
| **Invoice Qty Based** | Total invoice quantity meets threshold | `Invoice_Qty_Threshold__c` |
| **Invoice Val Based** | Total invoice value meets threshold | `Invoice_Val_Threshold__c` |

### Full Matrix with Examples

| | Same Product (QTY) | Same Product (VAL) | Assorted Product (QTY) | Assorted Product (VAL) | Invoice Qty Based | Invoice Val Based |
|---|---|---|---|---|---|---|
| **Free Products** | Buy 3 of X, get 1 Y free | Buy ₹500 of X, get 1 Y free | Buy 2 of X + 2 of Y, get Z free | Buy ₹1000 across X+Y, get Z free | Buy 50 total units, get Z free | Buy ₹5000 total, get Z free |
| **Discount in %** | Buy 5 of X, get 10% off | Buy ₹500 of X, get 10% off | Buy X+Y (min qty each), get 10% off | ₹1000 across X+Y, 10% off | 50 total units, 5% off invoice | ₹5000 total, 5% off invoice |
| **Discount in Value** | Buy 5 of X, get ₹50 off | Buy ₹500 of X, ₹50 off | Buy X+Y, ₹100 off | ₹1000 across X+Y, ₹100 off | 50 total units, ₹200 off | ₹5000 total, ₹200 off |
| **Reward Points** | Buy 5 of X, earn 100 pts | Buy ₹500 of X, 100 pts | Buy X+Y, earn 100 pts | ₹1000 across X+Y, 100 pts | 50 units, 500 pts | ₹5000 total, 500 pts |

---

## 3. Scheme Objects & Field Reference

### 3.1 Scheme__c (Master Record)

#### Core Identity Fields

| Field API Name | Type | Required | Description |
|----------------|------|----------|-------------|
| `Name` | Text | Yes | Display name (e.g. "Naga Maida Buy 3 Get 1 Free") |
| `Scheme_Code__c` | Text(50) | Yes | Unique identifier code (auto-generated via `generateSchemeCode()`) |
| `Description__c` | Long Text | No | Detailed description of the scheme |

#### Classification Fields

| Field API Name | Type | Required | Description |
|----------------|------|----------|-------------|
| `Scheme_Type__c` | Picklist | Yes | Trigger condition — one of the 6 types |
| `Scheme_Category__c` | Picklist | Yes | Benefit type — one of the 4 categories (default: Free Products) |

**Scheme_Type__c Picklist Values:**
- Same Product (QTY)
- Same Product (VAL)
- Assorted Product (QTY)
- Assorted Product (VAL)
- Invoice Qty Based
- Invoice Val Based

**Scheme_Category__c Picklist Values:**
- Free Products
- Discount in %
- Discount in Value
- Reward Points

#### Date & Status Fields

| Field API Name | Type | Required | Default | Description |
|----------------|------|----------|---------|-------------|
| `Start_Date__c` | Date | Yes | — | Scheme effective from |
| `End_Date__c` | Date | Yes | — | Scheme expires on |
| `Status__c` | Picklist | Yes | Draft | Workflow status |
| `Is_Active__c` | Formula | Auto | — | `AND(Status='Active', Start<=TODAY(), End>=TODAY())` |
| `Approval_Date__c` | DateTime | No | — | When approved |
| `Approved_By__c` | Lookup(User) | No | — | Who approved |

**Status__c Picklist Values:**
- Draft
- Pending Approval
- Active
- Expired
- Cancelled

#### Eligibility / Threshold Fields

| Field API Name | Type | Default | Use With Type |
|----------------|------|---------|---------------|
| `Min_Quantity__c` | Number | 0 | Same Product (QTY), Assorted (QTY), Invoice Qty |
| `Max_Quantity__c` | Number | 0 | Upper bound for qty-based triggers |
| `Min_Value__c` | Currency | 0 | Same Product (VAL), Assorted (VAL), Invoice Val |
| `Max_Value__c` | Currency | 0 | Upper bound for value-based triggers |
| `MOV__c` | Currency | — | Minimum Order Value (VAL-based types) |
| `Invoice_Qty_Threshold__c` | Number | — | Invoice Qty Based type |
| `Invoice_Qty_UOM__c` | Picklist | — | Unit of measure: PC, KG, LTR, CS |
| `Invoice_Val_Threshold__c` | Currency | — | Invoice Val Based type |

#### Benefit Fields

| Field API Name | Type | Default | Use With Category |
|----------------|------|---------|-------------------|
| `Discount_Percent__c` | Percent | — | Discount in % |
| `Discount_Amount__c` | Currency | 0 | Discount in Value |
| `Price_Discount__c` | Currency | — | Discount in Value (per-unit reduction) |
| `Free_Product_Ext__c` | Lookup(Product_Extension__c) | — | Free Products |
| `Free_Quantity__c` | Number | 0 | Free Products |
| `Reward_Points__c` | Number | 0 | Reward Points |
| `Max_Discount_Cap__c` | Currency | — | Any discount category (caps max discount) |

#### Product / Category Assignment

| Field API Name | Type | Description |
|----------------|------|-------------|
| `Product_Ext__c` | Lookup(Product_Extension__c) | Direct single-product scheme (alternative to Scheme_Product__c) |
| `Product_Category__c` | Lookup(Product_Category__c) | Category-level scheme (applies to all products in category) |

#### Channel & Outlet Targeting

| Field API Name | Type | Description |
|----------------|------|-------------|
| `Channel__c` | Picklist | Single channel: GT, MT, E-Commerce, All. Null = all channels |
| `Applicable_Channel__c` | Multi-Select Picklist | Multiple channels: GT, MT, E-Commerce, All |
| `Outlet_Type__c` | Text(50) | Outlet type text filter |
| `Applicable_Outlet_Type__c` | Multi-Select Picklist | Grocery, Medical, Hardware, General Store |
| `Region__c` | Text(100) | Region text filter |
| `Applicable_Region__c` | Lookup(Company_Hierarchy__c) | Region lookup |
| `Target_Channel__c` | Text(100) | Target channel text |

#### Priority & Stacking

| Field API Name | Type | Default | Description |
|----------------|------|---------|-------------|
| `Priority__c` | Number | 0 | Lower number = higher priority (evaluated first) |
| `Is_Stackable__c` | Checkbox | false | If false, blocks lower-priority schemes from applying |

#### Budget Management

| Field API Name | Type | Default | Description |
|----------------|------|---------|-------------|
| `Budget_Amount__c` | Currency | 0 | Total budget allocated for this scheme |
| `Budget_Used__c` | Currency | 0 | Budget consumed so far |
| `Budget_Remaining__c` | Formula | — | `Budget_Amount__c - Budget_Used__c` |

#### Other

| Field API Name | Type | Description |
|----------------|------|-------------|
| `Tier__c` | Picklist | Base, Pro, Enterprise (optional classification) |

---

### 3.2 Scheme_Product__c (Product Mapping)

Master-Detail child of Scheme__c. Maps which products qualify for the scheme.

| Field API Name | Type | Required | Default | Description |
|----------------|------|----------|---------|-------------|
| `Scheme__c` | Master-Detail | Yes | — | Parent scheme |
| `Product_Ext__c` | Lookup(Product_Extension__c) | No | — | The product |
| `Product_Category__c` | Lookup(Product_Category__c) | No | — | Product category (alternative to specific product) |
| `Min_Quantity__c` | Number | No | 0 | Minimum quantity of THIS product to qualify |
| `Is_Buy_Product__c` | Checkbox | No | false | Customer must BUY this product to trigger scheme |
| `Is_Get_Product__c` | Checkbox | No | false | Customer GETS this product free (for Free Products category) |
| `Product_Classification__c` | Picklist | No | — | Must Sell, Focused Sell (shows in order entry must-sell section) |

**Important Rules:**
- A product with `Is_Buy_Product__c = true` is what the customer must purchase
- A product with `Is_Get_Product__c = true` is what the customer receives free
- For "Free Products" category: you need at least one Buy product and one Get product
- For discount/points categories: you only need Buy products
- `Product_Classification__c` = "Must Sell" makes the product appear in the Must Sell section of the order screen
- `Product_Classification__c` = "Focused Sell" makes it appear in the Focused Sell section

---

### 3.3 Scheme_Slab__c (Tiered Benefits)

Master-Detail child of Scheme__c. Defines quantity/value tiers for progressive benefits.

| Field API Name | Type | Required | Default | Description |
|----------------|------|----------|---------|-------------|
| `Scheme__c` | Master-Detail | Yes | — | Parent scheme |
| `Slab_Type__c` | Picklist | Yes | Quantity | Quantity or Value |
| `Min_Quantity__c` | Number | No | — | Minimum quantity for this tier |
| `Max_Quantity__c` | Number | No | — | Maximum quantity for this tier |
| `Min_Value__c` | Number | Yes | 0 | Minimum value for this tier |
| `Max_Value__c` | Number | No | — | Maximum value for this tier |
| `Discount_Type__c` | Picklist | Yes | Percent | How benefit is calculated |
| `Discount_Percent__c` | Percent | No | — | % discount for this tier |
| `Discount_Amount__c` | Currency | No | 0 | Fixed discount for this tier |
| `Discount_Value__c` | Number | No | — | Alternative discount value |
| `Price_Discount__c` | Currency | No | — | Per-unit price reduction |
| `Free_Product_Ext__c` | Lookup(Product_Extension__c) | No | — | Free product for this tier |
| `Free_Quantity__c` | Number | No | 0 | Free quantity for this tier |
| `Reward_Points__c` | Number | No | 0 | Points for this tier |
| `Is_Active__c` | Checkbox | No | true | Enable/disable this slab |

**Discount_Type__c Picklist Values:**
- Percent
- Amount
- Free Product
- Price Discount
- Reward Points

**Slab Matching Logic:**
- Slabs are ordered by `Min_Quantity__c ASC, Min_Value__c ASC`
- First matching slab wins (no accumulation across slabs)
- If slab has both Min_Quantity and Min_Value, BOTH must be satisfied
- If only Min_Quantity is set, only quantity is checked
- If only Min_Value is set, only value is checked

---

### 3.4 Scheme_Mapping__c (Territory / Outlet Targeting)

Master-Detail child of Scheme__c. Controls geographic and outlet-level applicability.

| Field API Name | Type | Required | Default | Description |
|----------------|------|----------|---------|-------------|
| `Scheme__c` | Master-Detail | Yes | — | Parent scheme |
| `Territory__c` | Lookup(Territory_Master__c) | No | — | Sales territory |
| `Zone__c` | Text(100) | No | — | Geographic zone |
| `Sub_Zone__c` | Text(100) | No | — | Sub-zone/region |
| `District__c` | Text(100) | No | — | District |
| `Area__c` | Text(100) | No | — | Area |
| `Account__c` | Lookup(Account) | No | — | Specific outlet. Null = all outlets in territory |
| `Customer_Type__c` | Picklist | No | — | D2R, Wholesale, Modern Trade, Institutional |
| `Is_Active__c` | Checkbox | No | true | Enable/disable this mapping |

**Territory Restriction Logic:**
- If a scheme has **ANY** active Scheme_Mapping__c records → scheme is **territory-restricted**
- Only outlets that match a mapping record will see the scheme
- If a scheme has **NO** Scheme_Mapping__c records → scheme applies to **all outlets**
- `Account__c = null` in a mapping means "all outlets in this territory"
- `Account__c = specific outlet` means "only this outlet"

---

## 4. Step-by-Step Scheme Creation

### Step 1: Create Scheme__c Record

Set the core identity and classification:

| Field | Value |
|-------|-------|
| Name | e.g. "Naga Maida Buy 3 Get 1 Free" |
| Scheme_Code__c | Auto-generated or manual (e.g. "SCH-001") |
| Scheme_Category__c | Pick one: Free Products / Discount in % / Discount in Value / Reward Points |
| Scheme_Type__c | Pick one of the 6 types |
| Start_Date__c | Today or future date |
| End_Date__c | Expiry date |
| Status__c | Set to "Active" for testing (or follow Draft → Active workflow) |
| Priority__c | e.g. 1 (lower = higher priority) |
| Is_Stackable__c | true if can combine with other schemes |

### Step 2: Set Benefit Fields (Based on Category)

**If Category = "Free Products":**
- `Free_Product_Ext__c` → lookup to the free product record
- `Free_Quantity__c` → how many free units (e.g. 1)

**If Category = "Discount in %":**
- `Discount_Percent__c` → percentage (e.g. 10 for 10%)

**If Category = "Discount in Value":**
- `Discount_Amount__c` → flat amount (e.g. 50 for ₹50 off)
- OR `Price_Discount__c` → per-unit price reduction

**If Category = "Reward Points":**
- `Reward_Points__c` → points to award (e.g. 100)

**Optional for any category:**
- `Max_Discount_Cap__c` → maximum discount allowed (e.g. ₹500 cap)

### Step 3: Set Trigger Thresholds (Based on Type)

**Same Product (QTY):**
- Set `Min_Quantity__c` on scheme header as default
- OR set `Min_Quantity__c` on each Scheme_Product__c for per-product thresholds

**Same Product (VAL):**
- Set `MOV__c` (e.g. 500 for ₹500 minimum)
- OR set `Min_Value__c` as fallback

**Assorted Product (QTY):**
- Set `Min_Quantity__c` on each Scheme_Product__c (per product)
- Optionally set `Min_Quantity__c` on header for total aggregate threshold

**Assorted Product (VAL):**
- Set `MOV__c` or `Min_Value__c` for aggregate value threshold

**Invoice Qty Based:**
- Set `Invoice_Qty_Threshold__c` (e.g. 50 for 50 total units)
- Fallback: `Min_Quantity__c` on header

**Invoice Val Based:**
- Set `Invoice_Val_Threshold__c` (e.g. 5000 for ₹5000 total)
- Fallback: `Min_Value__c` on header

### Step 4: Create Scheme_Product__c Records

**This is the most critical step** — it determines which products the scheme applies to.

For each qualifying product, create a Scheme_Product__c record:

**Buy Products (what customer must purchase):**

| Field | Value |
|-------|-------|
| Scheme__c | Parent scheme |
| Product_Ext__c | The product |
| Is_Buy_Product__c | ✅ true |
| Is_Get_Product__c | ❌ false |
| Min_Quantity__c | Minimum qty of this product (for QTY-based types) |
| Product_Classification__c | "Must Sell" or "Focused Sell" (optional) |

**Get Products (what customer receives free — only for "Free Products" category):**

| Field | Value |
|-------|-------|
| Scheme__c | Parent scheme |
| Product_Ext__c | The free product |
| Is_Buy_Product__c | ❌ false |
| Is_Get_Product__c | ✅ true |
| Min_Quantity__c | Leave blank |

**Important:** If you don't create Scheme_Product__c records:
- The scheme will only match if `Product_Ext__c` or `Product_Category__c` is set on the scheme header
- Invoice-level schemes can work without products (they apply to the whole invoice)
- Without ANY product mapping, the scheme won't match specific products in the order screen

### Step 5 (Optional): Create Scheme_Slab__c Records

For tiered/slab-based benefits:

**Example: Progressive Discount**
| Slab | Min Qty | Max Qty | Discount Type | Discount % |
|------|---------|---------|---------------|------------|
| Slab 1 | 5 | 10 | Percent | 5% |
| Slab 2 | 11 | 20 | Percent | 10% |
| Slab 3 | 21 | — | Percent | 15% |

**Example: Tiered Free Products**
| Slab | Min Qty | Max Qty | Discount Type | Free Product | Free Qty |
|------|---------|---------|---------------|--------------|----------|
| Slab 1 | 10 | 19 | Free Product | Product X | 1 |
| Slab 2 | 20 | 49 | Free Product | Product X | 3 |
| Slab 3 | 50 | — | Free Product | Product X | 10 |

Set `Is_Active__c = true` on each slab.

### Step 6 (Optional): Create Scheme_Mapping__c Records

Only needed if you want to restrict the scheme to specific territories/outlets.

| Scenario | Account__c | Territory/Zone Fields |
|----------|------------|----------------------|
| All outlets in North zone | null | Zone__c = "North" |
| Specific outlet only | Outlet record | — |
| All D2R customers | null | Customer_Type__c = "D2R" |

**Remember:** If you create ANY mapping record, the scheme becomes territory-restricted. Outlets without a matching mapping won't see it.

### Step 7: Set Channel/Outlet Filters (Optional)

On the scheme header:
- `Channel__c` = "GT" → only General Trade outlets
- `Outlet_Type__c` = "Grocery" → only grocery stores
- Leave blank → applies to all channels/outlet types

### Step 8: Activate

Set `Status__c = "Active"` (and ensure dates include today).

---

## 5. How Schemes Work in Orders

### Order Entry Screen Flow

```
1. OUTLET SELECTION
   └─ Rep selects or visits an outlet
   └─ LWC calls: getApplicableSchemes(accountId)
   └─ LWC calls: getMustSellProducts(accountId, orderDate)

2. SCHEME DISPLAY
   └─ "Active Schemes & Offers" panel shows all applicable schemes
   └─ Schemes are color-coded by category:
       Green  = Free Products
       Blue   = Discount
       Yellow = Reward Points

3. MUST SELL SECTION
   └─ Products with Product_Classification__c = "Must Sell" appear in red section
   └─ Products with Product_Classification__c = "Focused Sell" in blue section
   └─ Progress bar tracks how many must-sell items are in the cart

4. PRODUCT SEARCH
   └─ Rep searches products by name/SKU
   └─ LWC calls findApplicableScheme() for each product result
   └─ Matching logic checks (in order):
       a. scheme.Product_Ext__c === product.Id (direct match)
       b. Scheme_Products__r contains product with Is_Buy_Product__c = true
       c. scheme.Product_Category__c === product category
       d. Invoice-level scheme (no product restriction)
   └─ Products with matching schemes show:
       • Blue left border on card
       • Scheme name and benefit description strip
       • Free qty badge (if applicable)

5. ADD TO CART
   └─ LWC calculates preview: discount, free qty, tax, total
   └─ These are PREVIEW values for the rep's reference

6. ORDER SUBMISSION
   └─ Must-sell compliance check (warns if missing)
   └─ LWC calls createSalesOrder(orderJson)

7. SERVER-SIDE PROCESSING (Trigger)
   └─ OMS_OrderLineItem_TriggerHandler.beforeInsert fires:
       a. calculateLineItemPricing() → resolves Unit_Price from Price_List__c
       b. applySchemes() → calls SPM_SchemeEngine_Service
       c. calculateTax() → CGST/SGST/IGST
   └─ Actual discounts are calculated server-side (may differ from preview)

8. ORDER TOTALS UPDATE
   └─ afterInsert trigger aggregates line items
   └─ Updates Sales_Order__c header with totals
```

### Fields Set on Order_Line_Item__c by Scheme Engine

| Field | Description |
|-------|-------------|
| `Scheme__c` | Lookup to the applied Scheme__c record |
| `Scheme_Applied__c` | Scheme ID (text reference) |
| `Scheme_Discount__c` | Discount amount from scheme |
| `Scheme_Category__c` | Category of applied scheme |
| `Free_Quantity__c` | Free goods quantity |
| `Reward_Points__c` | Points awarded |

### Fields Set on Sales_Order__c (Aggregated)

| Field | Description |
|-------|-------------|
| `Scheme_Discount__c` | Total scheme discount across all line items |
| `Total_Free_Quantity__c` | Total free goods quantity |
| `Total_Reward_Points__c` | Total reward points |
| `Must_Sell_Compliance__c` | % of must-sell products ordered |

---

## 6. Scheme Engine Evaluation Logic

### SPM_SchemeEngine_Service — How It Works

#### 1. Candidate Fetch (`fetchCandidateSchemes`)

The engine first queries all potentially applicable schemes:

```
WHERE Is_Active__c = true
  AND Start_Date__c <= orderDate
  AND (End_Date__c >= orderDate OR End_Date__c = null)
  AND (Channel__c = outlet.Channel OR Channel__c = null)
  AND (Outlet_Type__c = outlet.Type OR Outlet_Type__c = null)
  AND (Product match OR invoice-level)
  AND (Not territory-restricted OR mapped to this outlet)
ORDER BY Priority__c ASC NULLS LAST
```

#### 2. Stacking & Budget Check

For each candidate scheme (in priority order):
- If a previous non-stackable scheme already qualified → skip non-stackable schemes
- Check `Budget_Remaining__c > 0` (if budget is set)

#### 3. Type-Specific Evaluation

**Same Product (QTY):**
```
For each line item with product in scheme's buy-products:
    If item.Quantity >= product's Min_Quantity:
        Mark as qualifying
        Add to qualifying totals
If NO items qualify → no benefit
If slabs exist → evaluate slab with totals
Else → apply direct benefit from scheme header
```

**Same Product (VAL):**
```
For each line item with product in scheme's buy-products:
    If item.LineValue >= MOV threshold:
        Mark as qualifying
If NO items qualify → no benefit
```

**Assorted Product (QTY):**
```
Sum quantity across ALL buy-products in order
For each buy-product with Min_Quantity set:
    If product's ordered qty < its Min_Quantity → FAIL (no benefit)
If total aggregate qty < scheme header Min_Quantity → FAIL
Otherwise → qualify
```

**Assorted Product (VAL):**
```
Sum value across ALL buy-products in order
If total value < MOV threshold → FAIL
Otherwise → qualify
```

**Invoice Qty Based:**
```
Sum quantity across all line items (or scheme products if specified)
If total qty < Invoice_Qty_Threshold → FAIL
```

**Invoice Val Based:**
```
Sum value across all line items (or scheme products if specified)
If total value < Invoice_Val_Threshold → FAIL
```

#### 4. Benefit Application

Once qualified, benefits are applied based on `Scheme_Category__c`:

| Category | Calculation |
|----------|-------------|
| Free Products | Sets `freeProductId`, `freeQty` from scheme/slab |
| Discount in % | `discountAmount = totalValue × (Discount_Percent__c / 100)` |
| Discount in Value | `discountAmount = Discount_Amount__c` or `Price_Discount__c` |
| Reward Points | `rewardPoints = Reward_Points__c` from scheme/slab |

#### 5. Discount Distribution

For multi-line discounts, the total discount is distributed proportionally:
```
For each qualifying line item:
    proportion = lineValue / totalQualifyingValue
    lineDiscount = totalDiscount × proportion
```

#### 6. Discount Cap

If `Max_Discount_Cap__c` is set and `discountAmount > cap`:
```
discountAmount = Max_Discount_Cap__c
```

---

## 7. Test Scenarios

### Test 1: Same Product (QTY) + Free Products

**Setup:**
| Record | Field | Value |
|--------|-------|-------|
| Scheme__c | Name | "Naga Maida Buy 3 Get 1 Free" |
| | Scheme_Category__c | Free Products |
| | Scheme_Type__c | Same Product (QTY) |
| | Free_Product_Ext__c | Naga Maida 200g |
| | Free_Quantity__c | 1 |
| | Status__c | Active |
| | Start_Date__c | Today |
| | End_Date__c | Future date |
| | Priority__c | 1 |
| Scheme_Product__c #1 | Product_Ext__c | Naga Maida 1KG |
| | Is_Buy_Product__c | true |
| | Min_Quantity__c | 3 |
| Scheme_Product__c #2 | Product_Ext__c | Naga Maida 200g |
| | Is_Get_Product__c | true |

**Test Cases:**
- ✅ Order 3 of Naga Maida 1KG → should get 1 Naga Maida 200g free
- ✅ Order 6 of Naga Maida 1KG → should get 2 Naga Maida 200g free (if Buy X Get Y logic)
- ❌ Order 2 of Naga Maida 1KG → no free product (below min qty)
- ❌ Order 5 of Crispy Chips → no scheme shown (wrong product)
- ❌ Order 5 of Fresh Mango Juice → no scheme shown (wrong product)

### Test 2: Same Product (QTY) + Discount in %

**Setup:**
| Record | Field | Value |
|--------|-------|-------|
| Scheme__c | Name | "Mango Juice 10% Off on 5+" |
| | Scheme_Category__c | Discount in % |
| | Scheme_Type__c | Same Product (QTY) |
| | Discount_Percent__c | 10 |
| | Status__c | Active |
| Scheme_Product__c | Product_Ext__c | Fresh Mango Juice 1L |
| | Is_Buy_Product__c | true |
| | Min_Quantity__c | 5 |

**Test Cases:**
- ✅ Order 5 Mango Juice at ₹100 each → 10% off ₹500 = ₹50 discount
- ❌ Order 4 Mango Juice → no discount (below threshold)
- ❌ Order 5 Crispy Chips → no discount (wrong product)

### Test 3: Same Product (VAL) + Discount in Value

**Setup:**
| Record | Field | Value |
|--------|-------|-------|
| Scheme__c | Name | "₹50 off on ₹500+ Chips Order" |
| | Scheme_Category__c | Discount in Value |
| | Scheme_Type__c | Same Product (VAL) |
| | Discount_Amount__c | 50 |
| | MOV__c | 500 |
| | Status__c | Active |
| Scheme_Product__c | Product_Ext__c | Crispy Masala Chips 150g |
| | Is_Buy_Product__c | true |

**Test Cases:**
- ✅ Order 10 Chips at ₹60 each (₹600) → ₹50 off
- ❌ Order 5 Chips at ₹60 each (₹300) → no discount (below ₹500 MOV)

### Test 4: Assorted Product (QTY) + Discount in %

**Setup:**
| Record | Field | Value |
|--------|-------|-------|
| Scheme__c | Name | "Buy Combo Pack 15% Off" |
| | Scheme_Category__c | Discount in % |
| | Scheme_Type__c | Assorted Product (QTY) |
| | Discount_Percent__c | 15 |
| | Min_Quantity__c | 10 (total across products) |
| | Status__c | Active |
| Scheme_Product__c #1 | Product_Ext__c | Product A |
| | Is_Buy_Product__c | true |
| | Min_Quantity__c | 3 (must buy at least 3 of A) |
| Scheme_Product__c #2 | Product_Ext__c | Product B |
| | Is_Buy_Product__c | true |
| | Min_Quantity__c | 3 (must buy at least 3 of B) |

**Test Cases:**
- ✅ Order 5 of A + 5 of B (total 10, each ≥ 3) → 15% off
- ❌ Order 2 of A + 8 of B (total 10, but A < 3) → no discount
- ❌ Order 4 of A + 4 of B (total 8, below header min 10) → no discount

### Test 5: Invoice Val Based + Discount in Value

**Setup:**
| Record | Field | Value |
|--------|-------|-------|
| Scheme__c | Name | "₹200 off on ₹5000+ Invoice" |
| | Scheme_Category__c | Discount in Value |
| | Scheme_Type__c | Invoice Val Based |
| | Discount_Amount__c | 200 |
| | Invoice_Val_Threshold__c | 5000 |
| | Status__c | Active |
| (No Scheme_Product__c records needed) | | |

**Test Cases:**
- ✅ Order total ₹5500 → ₹200 off (distributed proportionally across line items)
- ❌ Order total ₹4800 → no discount

### Test 6: Slab-Based Scheme

**Setup:**
| Record | Field | Value |
|--------|-------|-------|
| Scheme__c | Name | "Tiered Discount on Noodles" |
| | Scheme_Category__c | Discount in % |
| | Scheme_Type__c | Same Product (QTY) |
| | Status__c | Active |
| Scheme_Product__c | Product_Ext__c | Instant Noodles |
| | Is_Buy_Product__c | true |
| Scheme_Slab__c #1 | Min_Quantity__c | 5 |
| | Max_Quantity__c | 10 |
| | Discount_Type__c | Percent |
| | Discount_Percent__c | 5 |
| Scheme_Slab__c #2 | Min_Quantity__c | 11 |
| | Max_Quantity__c | 20 |
| | Discount_Type__c | Percent |
| | Discount_Percent__c | 10 |
| Scheme_Slab__c #3 | Min_Quantity__c | 21 |
| | Max_Quantity__c | (blank) |
| | Discount_Type__c | Percent |
| | Discount_Percent__c | 15 |

**Test Cases:**
- ✅ Order 7 Noodles → 5% off (Slab 1)
- ✅ Order 15 Noodles → 10% off (Slab 2)
- ✅ Order 25 Noodles → 15% off (Slab 3)
- ❌ Order 3 Noodles → no discount (below Slab 1 minimum)

### Test 7: Stacking Rules

**Setup:**
- Scheme A: Priority 1, Is_Stackable = false, 10% off on Product X (min qty 5)
- Scheme B: Priority 2, Is_Stackable = true, 5% off on Product X (min qty 3)
- Scheme C: Priority 3, Is_Stackable = true, ₹20 off on Product X (min qty 2)

**Test Cases:**
- Order 5 of Product X:
  - ✅ Scheme A applies (10% off) — non-stackable, highest priority
  - ❌ Scheme B blocked (A is non-stackable)
  - ❌ Scheme C blocked (A is non-stackable)

- Change Scheme A to Is_Stackable = true:
  - ✅ Scheme A applies (10% off)
  - ✅ Scheme B applies (5% off) — stacks
  - ✅ Scheme C applies (₹20 off) — stacks

### Test 8: Budget Check

**Setup:**
- Scheme with Budget_Amount__c = 1000, Budget_Used__c = 950
- Discount = ₹200 per order

**Test Cases:**
- ✅ First qualifying order → ₹200 discount (budget remaining = 50, but scheme still has budget > 0 at evaluation time)
- Budget check uses: `Budget_Used__c < Budget_Amount__c` to determine eligibility

### Test 9: Must Sell Compliance

**Setup:**
- Scheme_Product__c records with Product_Classification__c = "Must Sell"

**Test Cases:**
- ✅ All must-sell products in cart → order submits normally
- ⚠️ Missing must-sell products → warning modal with options:
  - "Add Products" → returns to order screen
  - "Submit Anyway" → submits with must-sell compliance < 100%
- Check `Sales_Order__c.Must_Sell_Compliance__c` = (ordered / total) × 100

### Test 10: Territory Mapping

**Setup:**
- Create Scheme_Mapping__c for Scheme with Account__c = Outlet A

**Test Cases:**
- ✅ Order from Outlet A → scheme appears
- ❌ Order from Outlet B → scheme NOT visible (territory-restricted)
- Remove all Scheme_Mapping__c records → scheme visible to ALL outlets

---

## 8. Troubleshooting & FAQs

### Q: Scheme is showing on wrong products

**Cause:** Missing or incorrect `Scheme_Product__c` records.

**Fix:** Ensure every scheme has `Scheme_Product__c` records with:
- `Product_Ext__c` pointing to the correct product
- `Is_Buy_Product__c = true` for qualifying products
- Do NOT leave `Product_Ext__c` blank on the scheme header unless it's a category-level or invoice-level scheme

**How matching works (priority order):**
1. Direct match: `scheme.Product_Ext__c === product.Id`
2. Scheme_Products__r: product exists in the scheme's product list with `Is_Buy_Product__c = true`
3. Category match: `scheme.Product_Category__c === product's category`
4. Invoice-level: scheme has no product/category restriction AND type is Invoice Qty/Val Based

If a scheme has Scheme_Products__r records but the product is NOT in that list → **no match** (does not fall through to category/invoice check).

### Q: Scheme is not appearing at all

**Check:**
1. `Status__c` = "Active"
2. `Start_Date__c` <= today AND `End_Date__c` >= today
3. No channel/outlet type filter excluding the outlet
4. No territory mapping excluding the outlet
5. Budget not exhausted (if budget is set)
6. Feature toggle `SPM-001` is enabled (for scheme viewer)
7. Feature toggle `SPM-002` is enabled (for must-sell products)

### Q: Discount amount on order differs from what LWC showed

**Expected behavior.** The LWC shows a PREVIEW calculation. The actual discount is computed server-side by `SPM_SchemeEngine_Service` via the trigger when the order is saved. The server-side calculation uses:
- Actual Price_List__c prices (not the LWC's approximation)
- Full slab evaluation
- Budget checks
- Stacking rules
- Discount caps

### Q: Free quantity not showing

**Check:**
- Scheme Category must be "Free Products"
- `Free_Product_Ext__c` and `Free_Quantity__c` must be set (on scheme header or slab)
- For slabs: `Discount_Type__c` must be "Free Product"
- Quantity threshold must be met

### Q: Multiple schemes applying when only one should

**Fix:** Set `Is_Stackable__c = false` on the primary scheme. Only one non-stackable scheme can win. Set appropriate `Priority__c` values (lower = higher priority).

### Q: Scheme works in order entry but not applying server-side discount

**Check:**
- `OMS_OrderLineItem_TriggerHandler` is active
- Trigger is deployed and not bypassed
- `OMS_OrderPricing_Service.applySchemes()` is being called
- No exceptions in debug logs during trigger execution

---

*Document generated for FMCG-CRM Scheme Management Module. For support, contact the SFA Development Team.*
