# Order Entry & Schemes - Detailed Test Guide

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Scheme Types & Categories](#2-scheme-types--categories)
3. [How Schemes Are Applied to Products](#3-how-schemes-are-applied-to-products)
4. [Scheme Matching Hierarchy](#4-scheme-matching-hierarchy)
5. [Calculation Logic](#5-calculation-logic)
6. [UI Visibility - What Users See](#6-ui-visibility---what-users-see)
7. [Test Scenarios by Scheme Type](#7-test-scenarios-by-scheme-type)
8. [Must-Sell & Focused-Sell Products](#8-must-sell--focused-sell-products)
9. [Order Submission Flow](#9-order-submission-flow)
10. [Edge Cases & Negative Tests](#10-edge-cases--negative-tests)

---

## 1. System Overview

The Order Entry module allows field sales reps to create Sales Orders for retail outlets (Accounts). The system automatically detects and applies active promotional schemes to products, calculating discounts, free quantities, and reward points.

### Key Objects

| Object | Purpose |
|--------|---------|
| `Sales_Order__c` | Order header with totals, account, visit reference |
| `Order_Line_Item__c` | Individual product lines with qty, price, scheme info |
| `Scheme__c` | Promotional scheme definitions |
| `Scheme_Slab__c` | Tiered benefit slabs within a scheme |
| `Scheme_Product__c` | Product-to-scheme mappings (buy/get products) |
| `Product_Extension__c` | Product catalog with pricing |
| `Price_List__c` | Channel/region-specific pricing |

### Entry Points

- **From Visit page**: Navigate to Order Entry from an active visit (Visit ID and Account ID passed automatically)
- **From Account page**: Open Order Entry directly on an account record
- **Standalone**: Select an account/outlet manually before placing the order

---

## 2. Scheme Types & Categories

### 2.1 Scheme Types (`Scheme_Type__c`)

These define **what qualifies** a product/order for the scheme:

| Scheme Type | Qualifier | Example |
|-------------|-----------|---------|
| **Same Product (QTY)** | Quantity of a single product purchased | Buy 10 units of Product A |
| **Same Product (VAL)** | Value of a single product purchased | Purchase Rs.500 worth of Product A |
| **Assorted Product (QTY)** | Combined quantity across multiple products | Buy any 12 items from Snacks category |
| **Assorted Product (VAL)** | Combined value across multiple products | Purchase Rs.1000 worth of Beverages |
| **Invoice Qty Based** | Total invoice quantity threshold | Order 50+ total items |
| **Invoice Val Based** | Total invoice value threshold | Order worth Rs.5000+ |

### 2.2 Scheme Categories (`Scheme_Category__c`)

These define **what benefit** the customer receives:

| Category | Benefit | Fields Used |
|----------|---------|-------------|
| **Free Products** | Free quantity of same/different product | `Free_Quantity__c`, `Free_Product_Ext__c` |
| **Discount in %** | Percentage discount on line amount | `Discount_Percent__c` |
| **Discount in Value** | Flat amount discount | `Discount_Amount__c` |
| **Reward Points** | Loyalty points credited | `Reward_Points__c` |

### 2.3 Scheme Status Lifecycle

```
Draft --> Pending Approval --> Active --> Expired
                                  \--> Cancelled
```

Only **Active** schemes within valid date range (`Start_Date__c` <= today <= `End_Date__c`) are applied.

---

## 3. How Schemes Are Applied to Products

### Step-by-Step Flow

```
1. User opens Order Entry for an Account
       |
2. System loads all Active schemes (valid date range)
       |
3. System loads Must-Sell / Focused-Sell products
       |
4. User searches for a product (by name or SKU)
       |
5. For EACH product in search results:
   a. System runs findApplicableScheme() -- matches scheme to product
   b. If scheme found:
      - Calculates free quantity (if Free Products scheme)
      - Builds benefit description text (e.g. "10% off | Min qty: 5")
      - Highlights product card with scheme badge
       |
6. User sets quantity and adds product to cart
       |
7. System creates line item with:
   - grossAmount = quantity x unitPrice
   - discountAmount = calculated from scheme rules
   - taxableAmount = grossAmount - discountAmount
   - taxAmount = taxableAmount x (GST_Rate / 100)
   - totalAmount = taxableAmount + taxAmount
   - freeQty = calculated from scheme (if applicable)
       |
8. User can modify quantity in cart --> recalculation triggers
       |
9. Order summary updates in real-time
       |
10. User submits order --> Must-Sell validation runs
```

---

## 4. Scheme Matching Hierarchy

When the system looks for an applicable scheme for a product, it follows this priority order:

### Priority 1: Direct Product Match
- Scheme header has `Product_Ext__c` = the product's ID
- This is the most specific match

### Priority 2: Scheme Products (Child Records)
- `Scheme_Products__r` child records exist on the scheme
- One of them has `Product_Ext__c` = the product's ID AND `Is_Buy_Product__c` = true
- If the scheme has product mappings but this product is NOT in them, it is **excluded**

### Priority 3: Category-Level Match
- Scheme has `Product_Category__c` set
- Product belongs to that category
- No specific product mappings exist on the scheme

### Priority 4: Invoice-Level Schemes
- Scheme type is "Invoice Qty Based" or "Invoice Val Based"
- No `Product_Ext__c` or `Product_Category__c` set on scheme
- Applies to the entire order, not individual products

**Important**: The system returns the **first matching scheme** (ordered by `Priority__c` field). Higher priority schemes are checked first.

---

## 5. Calculation Logic

### 5.1 Line Item Calculation

```
grossAmount     = quantity x unitPrice
discountAmount  = calculated based on scheme category (see below)
taxableAmount   = grossAmount - discountAmount
taxAmount       = taxableAmount x (taxRate / 100)
totalAmount     = taxableAmount + taxAmount
```

### 5.2 Discount Calculation by Scheme Category

| Category | Calculation |
|----------|-------------|
| **Discount in %** | `grossAmount x (Discount_Percent__c / 100)` |
| **Discount in Value** | `min(Discount_Amount__c, grossAmount)` -- cannot exceed line amount |
| **Free Products** | No monetary discount; `freeQty` calculated separately |
| **Reward Points** | No monetary discount; points tracked separately |

### 5.3 Free Quantity Calculation

For "Free Products" schemes:
```
freeQty = floor(quantity / Buy_Qty) x Free_Quantity__c
```

Example: Buy 3 Get 1 Free, customer orders 10 units:
- `floor(10 / 3) x 1 = 3` free units

### 5.4 Slab-Based Discount

For schemes with `Scheme_Slabs__r` (tiered benefits):

1. System finds the slab where: `quantity >= Min_Quantity__c AND quantity <= Max_Quantity__c`
2. Applies the slab's discount type:
   - **Percent**: `grossAmount x (slab.Discount_Percent__c / 100)`
   - **Amount**: Flat `slab.Discount_Amount__c`
   - **Free Product**: Awards `slab.Free_Quantity__c` of `slab.Free_Product_Ext__c`
   - **Reward Points**: Awards `slab.Reward_Points__c`

### 5.5 Order Summary Calculation

```
Total Gross Amount  = SUM of all line items' grossAmount
Total Discount      = SUM of all line items' discountAmount
Taxable Amount      = Total Gross Amount - Total Discount
Total Tax (GST)     = SUM of all line items' taxAmount
Net Amount          = Taxable Amount + Total Tax
Total Items         = COUNT of line items
Total Quantity      = SUM of all line items' quantity
```

### 5.6 Price Resolution

Unit price is resolved in this order:
1. **Channel-specific price** from `Price_List__c` (matching product + channel)
2. **Region-specific price** from `Price_List__c` (matching product + region)
3. **Default/National price** from `Price_List__c` (product only, no region/channel)
4. **Product Unit Price** (`Product_Extension__c.Unit_Price__c`)
5. **MRP** (`Product_Extension__c.MRP__c`) as final fallback

---

## 6. UI Visibility - What Users See

### 6.1 Active Schemes & Offers Panel

**Location**: Top of Order Entry page, below the header
**Display**: Collapsible panel with badge showing count (e.g., "7")

Each scheme card shows:
- **Icon**: Package icon (Free Products), Percent icon (Discounts), Ribbon icon (Reward Points)
- **Scheme Name**: e.g., "Buy 5 Get 1 Free - Chips"
- **Benefit Text**: e.g., "10% off | Min qty: 5" or "Get 2 Coca Cola free | Min order: Rs.500"
- **Category Badge**: Color-coded badge (green for Free Products, blue for Discounts, gold for Reward Points)

### 6.2 Product Search Results

When a scheme applies to a product:
- **Scheme Strip**: Below product name showing scheme name and benefit description
- **Product Card Highlight**: Card gets a distinct styling (`oef-product-card-scheme` class)
- **Free Qty Badge**: Shows "+N FREE" badge when free quantity applies

### 6.3 Cart / Line Items Table

| Column | What it Shows |
|--------|---------------|
| # | Line number |
| Product | Name, SKU, Must-Sell/Focused-Sell badge |
| Rate | Unit price (Rs.) |
| Qty | Editable quantity input |
| Free | "+N" green pill if free qty applies |
| Scheme | Scheme name pill |
| Discount | "-Rs.XX.XX" discount amount |
| Tax | Tax amount |
| Total | Line total after discount + tax |
| Action | Delete button |

### 6.4 Order Summary Section

**Left Side**:
- **Savings Card** (green): Total discount amount (shown only if discount > 0)
- **Free Items Card**: Count of total free items from schemes
- **Items Stats**: Total line items count and total quantity

**Right Side (Financial Breakdown)**:
```
Gross Amount          Rs. X,XXX.XX
Discount             -Rs.   XXX.XX
                     ──────────────
Taxable Amount        Rs. X,XXX.XX
GST                   Rs.   XXX.XX
                     ══════════════
Net Amount            Rs. X,XXX.XX
```

### 6.5 Must-Sell Warning Modal

When submitting an order with missing must-sell products:
- Modal popup listing all missing must-sell products with name and SKU
- Two buttons:
  - **"Add Products"**: Returns to order to add missing products
  - **"Submit Anyway"**: Submits with override flag (records compliance %)

---

## 7. Test Scenarios by Scheme Type

### 7.1 Free Products Scheme

#### Test Data Setup
| Field | Value |
|-------|-------|
| Scheme Name | Buy 3 Get 1 Free - Chips |
| Scheme_Type__c | Same Product (QTY) |
| Scheme_Category__c | Free Products |
| Status__c | Active |
| Start_Date__c | Today or earlier |
| End_Date__c | Today or later |
| Product_Ext__c | (Link to Chips product) |
| Free_Quantity__c | 1 |
| Min_Quantity__c | 3 |

#### Test Steps

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Order Entry for an account | Page loads with "Active Schemes & Offers" panel |
| 2 | Expand Active Schemes panel | Scheme "Buy 3 Get 1 Free - Chips" visible with Package icon and "Free Products" badge |
| 3 | Search for "Chips" | Chips product appears with scheme strip: "Buy 3 Get 1 Free - Chips -- Get 1 free" |
| 4 | Set quantity = 3, click Add to Order | Line item added: Qty=3, Free="+1", Scheme="Buy 3 Get 1 Free - Chips" |
| 5 | Change quantity to 6 in cart | Free qty updates to "+2" (floor(6/3) x 1) |
| 6 | Change quantity to 2 in cart | Free qty disappears (below minimum of 3) |
| 7 | Change quantity to 9 in cart | Free qty shows "+3" (floor(9/3) x 1) |
| 8 | Verify order summary | Free Items card shows total free count |

#### Free Product with Different Get Product

| Field | Value |
|-------|-------|
| Scheme Name | Buy 5 Coke Get 1 Glass Free |
| Free_Product_Ext__c | (Link to Glass product) |
| Free_Quantity__c | 1 |
| Min_Quantity__c | 5 |

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Search for "Coke" | Scheme strip shows: "Get 1 Glass free" |
| 2 | Add 5 Coke to order | Free="+1" shown, scheme name displayed |
| 3 | Add 10 Coke to order | Free="+2" shown |

---

### 7.2 Discount in % Scheme

#### Test Data Setup
| Field | Value |
|-------|-------|
| Scheme Name | 10% Off on Beverages |
| Scheme_Type__c | Same Product (QTY) |
| Scheme_Category__c | Discount in % |
| Status__c | Active |
| Product_Category__c | (Link to Beverages category) |
| Discount_Percent__c | 10 |
| Min_Quantity__c | 5 |

#### Test Steps

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Order Entry | Scheme visible in panel with Percent icon and "Discount in %" badge |
| 2 | Search for a Beverages product | Scheme strip: "10% Off on Beverages -- 10% off \| Min qty: 5" |
| 3 | Add product (Unit Price Rs.100), Qty = 5 | grossAmount = Rs.500, discountAmount = Rs.50 (10%), taxableAmount = Rs.450 |
| 4 | Verify tax calculation | taxAmount = Rs.450 x (GST_Rate/100). If GST=18%, tax = Rs.81 |
| 5 | Verify total | totalAmount = Rs.450 + Rs.81 = Rs.531 |
| 6 | Verify discount column in cart | Shows "-Rs.50.00" |
| 7 | Change qty to 10 | grossAmount=Rs.1000, discount=Rs.100, taxable=Rs.900 |
| 8 | Verify order summary | Savings card shows "Rs.100.00" Total Savings |

#### Calculation Verification Table

| Qty | Rate | Gross | Discount (10%) | Taxable | GST (18%) | Total |
|-----|------|-------|-----------------|---------|-----------|-------|
| 5 | 100 | 500 | 50 | 450 | 81 | 531 |
| 10 | 100 | 1000 | 100 | 900 | 162 | 1062 |
| 20 | 50 | 1000 | 100 | 900 | 162 | 1062 |

---

### 7.3 Discount in Value Scheme

#### Test Data Setup
| Field | Value |
|-------|-------|
| Scheme Name | Rs.50 Off on Shampoo |
| Scheme_Type__c | Same Product (VAL) |
| Scheme_Category__c | Discount in Value |
| Status__c | Active |
| Product_Ext__c | (Link to Shampoo product) |
| Discount_Amount__c | 50 |
| Min_Value__c | 200 |

#### Test Steps

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Search for "Shampoo" | Scheme strip: "Rs.50 Off on Shampoo -- Rs.50.00 off \| Min order: Rs.200.00" |
| 2 | Add Shampoo (Price Rs.100), Qty=3 | grossAmount=Rs.300, discount=Rs.50 (flat), taxable=Rs.250 |
| 3 | Verify discount does not exceed line | If grossAmount < 50, discount = grossAmount (capped) |
| 4 | Add Shampoo Qty=1, Price=Rs.30 | discount = min(50, 30) = Rs.30 (capped to line amount) |
| 5 | Verify cart discount column | Shows "-Rs.50.00" (or capped amount) |

#### Calculation Verification Table

| Qty | Rate | Gross | Discount (Rs.50 flat, capped) | Taxable | GST (18%) | Total |
|-----|------|-------|-------------------------------|---------|-----------|-------|
| 3 | 100 | 300 | 50 | 250 | 45 | 295 |
| 1 | 30 | 30 | 30 (capped) | 0 | 0 | 0 |
| 5 | 100 | 500 | 50 | 450 | 81 | 531 |

---

### 7.4 Reward Points Scheme

#### Test Data Setup
| Field | Value |
|-------|-------|
| Scheme Name | Earn 100 Points on Dairy |
| Scheme_Type__c | Same Product (QTY) |
| Scheme_Category__c | Reward Points |
| Status__c | Active |
| Product_Category__c | (Link to Dairy category) |
| Reward_Points__c | 100 |
| Min_Quantity__c | 3 |

#### Test Steps

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Search for a Dairy product | Scheme strip: "Earn 100 Points on Dairy -- 100 reward points \| Min qty: 3" |
| 2 | Add product, Qty = 5 | Scheme name shown in cart, NO monetary discount applied |
| 3 | Verify gross = total (before tax) | discountAmount = Rs.0 (reward points don't reduce price) |
| 4 | Verify scheme shows in Scheme column | Pill shows "Earn 100 Points on Dairy" |
| 5 | Verify panel shows Ribbon icon | Reward Points scheme has ribbon icon |

---

### 7.5 Slab-Based Scheme

#### Test Data Setup

**Scheme Header:**
| Field | Value |
|-------|-------|
| Scheme Name | Tiered Discount on Snacks |
| Scheme_Type__c | Same Product (QTY) |
| Scheme_Category__c | Discount in % |
| Status__c | Active |
| Product_Category__c | (Link to Snacks category) |

**Scheme Slabs (Child Records):**

| Slab | Min_Quantity | Max_Quantity | Slab_Type | Discount_Type | Discount_Percent |
|------|-------------|-------------|-----------|---------------|------------------|
| Slab 1 | 5 | 10 | Quantity | Percent | 5% |
| Slab 2 | 11 | 20 | Quantity | Percent | 10% |
| Slab 3 | 21 | 50 | Quantity | Percent | 15% |

#### Test Steps

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Add Snacks product, Qty = 5 | 5% discount applied (Slab 1) |
| 2 | Change qty to 11 | 10% discount applied (Slab 2) |
| 3 | Change qty to 25 | 15% discount applied (Slab 3) |
| 4 | Change qty to 3 | No discount (below all slabs) |
| 5 | Change qty to 55 | No slab matches (above all slabs) -- verify behavior |

#### Calculation Verification Table (Unit Price = Rs.50)

| Qty | Slab | Rate | Gross | Discount % | Discount Amt | Taxable | GST (18%) | Total |
|-----|------|------|-------|------------|--------------|---------|-----------|-------|
| 5 | 1 | 50 | 250 | 5% | 12.50 | 237.50 | 42.75 | 280.25 |
| 11 | 2 | 50 | 550 | 10% | 55 | 495 | 89.10 | 584.10 |
| 25 | 3 | 50 | 1250 | 15% | 187.50 | 1062.50 | 191.25 | 1253.75 |
| 3 | None | 50 | 150 | 0% | 0 | 150 | 27 | 177 |

---

### 7.6 Assorted Product (QTY) Scheme

#### Test Data Setup

**Scheme Header:**
| Field | Value |
|-------|-------|
| Scheme Name | Buy Any 10 Snacks Get 2 Free |
| Scheme_Type__c | Assorted Product (QTY) |
| Scheme_Category__c | Free Products |
| Free_Quantity__c | 2 |
| Min_Quantity__c | 10 |

**Scheme Products (Child Records):**

| Product | Is_Buy_Product | Is_Get_Product |
|---------|----------------|----------------|
| Chips Classic | true | false |
| Chips Masala | true | false |
| Nachos | true | false |
| Chips Classic | false | true |

#### Test Steps

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Search "Chips Classic" | Scheme strip visible (matched via Scheme_Products with Is_Buy_Product) |
| 2 | Search "Nachos" | Scheme strip visible |
| 3 | Search "Biscuit" (not in scheme products) | No scheme applied |
| 4 | Add Chips Classic Qty=5, Nachos Qty=5 | Both show scheme name, combined qty=10 meets threshold |
| 5 | Verify free qty calculation | Free qty shown on applicable lines |

---

### 7.7 Invoice-Level Scheme (Qty Based)

#### Test Data Setup
| Field | Value |
|-------|-------|
| Scheme Name | Order 50+ Items Get 5% Off |
| Scheme_Type__c | Invoice Qty Based |
| Scheme_Category__c | Discount in % |
| Discount_Percent__c | 5 |
| Invoice_Qty_Threshold__c | 50 |
| Product_Ext__c | (blank - applies to all) |
| Product_Category__c | (blank - applies to all) |

#### Test Steps

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Search any product | Scheme strip visible (invoice-level applies to all products) |
| 2 | Add various products totaling < 50 qty | Discount may show on individual lines but threshold not met |
| 3 | Add products totaling >= 50 qty | 5% discount applied across applicable lines |
| 4 | Verify order summary | Total discount reflects 5% of gross |

---

### 7.8 Invoice-Level Scheme (Value Based)

#### Test Data Setup
| Field | Value |
|-------|-------|
| Scheme Name | Spend Rs.5000 Get Rs.200 Off |
| Scheme_Type__c | Invoice Val Based |
| Scheme_Category__c | Discount in Value |
| Discount_Amount__c | 200 |
| Invoice_Val_Threshold__c | 5000 |
| MOV__c | 5000 |

#### Test Steps

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Search any product | Scheme strip: "Rs.200 off \| Min order: Rs.5,000" |
| 2 | Add products totaling Rs.4000 | Discount not fully applied (below MOV) |
| 3 | Add more products to cross Rs.5000 | Rs.200 discount applied |
| 4 | Verify in order summary | Savings card shows Rs.200 |

---

## 8. Must-Sell & Focused-Sell Products

### 8.1 Overview

Must-Sell and Focused-Sell products are defined in `Scheme_Product__c` records with `Product_Classification__c` set to "Must Sell" or "Focused Sell". These are loaded via the `getMustSellProducts()` Apex method (feature-toggled by `SPM-002`).

### 8.2 Test Data Setup

Create Scheme_Product__c records:
| Product | Classification | Min_Quantity |
|---------|---------------|--------------|
| Product A | Must Sell | 2 |
| Product B | Must Sell | 1 |
| Product C | Focused Sell | 3 |

### 8.3 Test Steps

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Order Entry | Must-Sell section visible (if feature SPM-002 enabled) |
| 2 | Add products but skip Product A and B | Must-sell products tracked as missing |
| 3 | Click "Submit Order" | **Must-Sell Warning Modal** appears |
| 4 | Verify modal content | Lists "Product A" and "Product B" as missing with SKU |
| 5 | Click "Add Products" | Modal closes, returns to order for editing |
| 6 | Add Product A (Qty=2) and Product B (Qty=1) | Products added to cart with "Must Sell" badge |
| 7 | Click "Submit Order" | No warning -- order submits successfully |
| 8 | Verify Sales_Order__c record | Must_Sell_Compliance__c = 100%, Must_Sell_Override__c = false |

### 8.4 Submit Anyway (Override) Test

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create order WITHOUT must-sell products | Must-Sell Warning appears |
| 2 | Click "Submit Anyway" | Order submits with override |
| 3 | Verify Sales_Order__c record | Must_Sell_Override__c = true, Must_Sell_Compliance__c < 100% |

### 8.5 Product Classification Badge

| Classification | Badge Display | Location |
|---------------|--------------|----------|
| Must Sell | "Must Sell" badge on product card | Cart table, Product column |
| Focused Sell | "Focused Sell" badge on product card | Cart table, Product column |

---

## 9. Order Submission Flow

### 9.1 Complete Submission Steps

| Step | Action | System Behavior |
|------|--------|-----------------|
| 1 | User clicks "Submit Order" | `handleSubmitOrder()` called |
| 2 | Validation: Account selected? | Error toast if no account |
| 3 | Validation: Line items exist? | Error toast if cart empty |
| 4 | Validation: All quantities valid? | Error toast if any qty < 1 |
| 5 | Must-Sell check | Warning modal if products missing |
| 6 | Build order payload | JSON with order header + line items |
| 7 | Call Apex `createSalesOrder()` | Insert Sales_Order__c + Order_Line_Item__c records |
| 8 | Apex: Calculate totals | `updateOrderTotals()` aggregates line items |
| 9 | Success toast | "Order created successfully" |
| 10 | Navigation | Redirects to created order record |
| 11 | Form reset | Clears all line items, search, and summary |

### 9.2 Save Draft Flow

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click "Save Draft" | Order saved with Status = "Draft" |
| 2 | Verify Sales_Order__c | Status__c = "Draft" |
| 3 | Verify editable | Draft orders can be edited later |

### 9.3 Order Payload Structure

The system sends this data to Apex:

**Order Header:**
- Account__c (Account ID)
- Visit__c (Visit ID, if from visit)
- Status__c (Draft / Submitted)
- Notes__c (Remarks)
- Total_Gross_Amount__c
- Total_Discount__c
- Total_Tax__c
- Net_Amount__c

**Line Items (for each product):**
- Product_Ext__c
- Quantity__c
- Free_Quantity__c
- Unit_Price__c
- Line_Amount__c (gross)
- Discount_Amount__c
- Tax_Rate__c
- Tax_Amount__c
- Line_Total__c
- Scheme__c (Scheme ID reference)

---

## 10. Edge Cases & Negative Tests

### 10.1 Scheme Edge Cases

| # | Scenario | Expected Behavior |
|---|----------|-------------------|
| 1 | Expired scheme (End_Date < today) | Scheme NOT loaded, NOT applied |
| 2 | Future scheme (Start_Date > today) | Scheme NOT loaded, NOT applied |
| 3 | Scheme with Status = "Draft" | NOT loaded (only Active schemes loaded) |
| 4 | Scheme with Status = "Cancelled" | NOT loaded |
| 5 | Product matches multiple schemes | First scheme by Priority__c wins |
| 6 | Is_Stackable__c = true | Verify if multiple scheme discounts combine |
| 7 | Discount exceeds line amount (Discount in Value) | Discount capped at grossAmount |
| 8 | Max_Discount_Cap__c set | Discount should not exceed cap |
| 9 | Quantity below Min_Quantity__c | Scheme should not apply |
| 10 | Value below MOV__c | Scheme should not apply |
| 11 | Quantity above Max_Quantity__c | Verify behavior (may not apply) |

### 10.2 Product Search Edge Cases

| # | Scenario | Expected Behavior |
|---|----------|-------------------|
| 1 | Search with "All Categories" selected | categoryId is empty, searches all active products |
| 2 | Search with specific category | Filters by Product_Category__r.Name |
| 3 | Search with no account context | accountId is null, channel pricing skipped, fallback to default price |
| 4 | Empty search term with category | Should prompt "enter search term or select category" |
| 5 | No products match search | Empty results, no error |

### 10.3 Cart Edge Cases

| # | Scenario | Expected Behavior |
|---|----------|-------------------|
| 1 | Add same product twice | Quantities merge (not duplicate line) |
| 2 | Set quantity to 0 | Validation: minimum quantity is 1 |
| 3 | Delete all line items then submit | Error: "Please add at least one product" |
| 4 | Very large quantity (e.g., 99999) | Calculations handle large numbers correctly |
| 5 | Product with 0% GST | Tax = 0, total = taxable amount |
| 6 | Product with no MRP/Unit Price | Verify fallback pricing |

### 10.4 Order Submission Edge Cases

| # | Scenario | Expected Behavior |
|---|----------|-------------------|
| 1 | Submit without selecting account | Error toast: account/outlet required |
| 2 | Submit with empty cart | Error toast: add products |
| 3 | Submit with invalid quantities | Error toast: valid quantities required |
| 4 | Network failure during submit | Error toast with message, order NOT created |
| 5 | Duplicate submit (double-click) | Button disabled during submission (isSubmitting flag) |
| 6 | Submit from Visit context | Visit__c populated on Sales_Order__c |

---

## Appendix A: Field Reference Quick Card

### Sales_Order__c Key Fields
| Field | Type | Purpose |
|-------|------|---------|
| Account__c | Lookup | Customer account |
| Visit__c | Lookup | Source visit |
| Status__c | Picklist | Order lifecycle status |
| Total_Gross_Amount__c | Currency | Sum of line gross amounts |
| Total_Discount__c | Currency | Sum of all discounts |
| Total_Tax__c | Currency | Sum of all taxes |
| Net_Amount__c | Currency | Final payable amount |
| Must_Sell_Compliance__c | Percent | % of must-sell products included |
| Must_Sell_Override__c | Checkbox | Submitted despite missing must-sells |
| Channel__c | Picklist | Field App / Retailer Portal / WhatsApp / API |

### Order_Line_Item__c Key Fields
| Field | Type | Purpose |
|-------|------|---------|
| Product_Ext__c | Lookup | Product reference |
| Quantity__c | Number | Ordered quantity |
| Free_Quantity__c | Number | Free items from scheme |
| Unit_Price__c | Currency | Price per unit |
| Line_Amount__c | Currency | Gross amount (qty x price) |
| Discount_Amount__c | Currency | Discount on this line |
| Tax_Rate__c | Percent | GST rate |
| Tax_Amount__c | Currency | Tax on this line |
| Line_Total__c | Currency | Final line amount |
| Scheme__c | Lookup | Applied scheme reference |

---

## Appendix B: Scheme Configuration Checklist

Before testing, ensure:

- [ ] Scheme Status__c = "Active"
- [ ] Start_Date__c <= today
- [ ] End_Date__c >= today
- [ ] Scheme_Type__c is set
- [ ] Scheme_Category__c is set
- [ ] Product_Ext__c OR Product_Category__c is linked (or left blank for invoice-level)
- [ ] Relevant discount/free fields populated based on category
- [ ] Scheme Slabs created (if slab-based scheme)
- [ ] Scheme Products created (if assorted product scheme)
- [ ] Feature toggle SPM-002 enabled (for Must-Sell/Focused-Sell)
- [ ] Priority__c set correctly (lower number = higher priority)
