# FMCG CRM / SFA - Complete Module Flow Guide

**Modules Covered:** Product Management, Pricing, Distributor Stock, Warehouse Stock
**Application:** FMCG CRM / SFA
**Date:** 2026-02-23

---

## Table of Contents

1. [Big Picture Overview](#1-big-picture-overview)
2. [Module 1: Product Management](#2-module-1-product-management)
3. [Module 2: Pricing & Price Book](#3-module-2-pricing--price-book)
4. [Module 3: Distributor Stock](#4-module-3-distributor-stock)
5. [Module 4: Warehouse Stock](#5-module-4-warehouse-stock)
6. [How All Modules Connect](#6-how-all-modules-connect)
7. [Complete End-to-End Flow](#7-complete-end-to-end-flow)

---

## 1. Big Picture Overview

This system manages the entire FMCG (Fast Moving Consumer Goods) supply chain from product definition through warehouse inventory to distributor delivery. Here is how the four modules fit together:

```
  MASTER DATA                    COMPANY WAREHOUSES              FIELD SALES
 ─────────────                  ──────────────────              ───────────

 ┌─────────────┐    ┌───────────────────────────────┐    ┌──────────────────┐
 │  Products   │    │     WAREHOUSE STOCK MODULE     │    │ DISTRIBUTOR STOCK │
 │  + Category │    │                                │    │     MODULE        │
 │  + Extension│───▶│  GRN ──▶ Warehouse Stock       │───▶│                  │
 │  + Batches  │    │         ├─ Transfers           │    │  Opening Stock   │
 └──────┬──────┘    │         ├─ Adjustments         │    │  + Received      │
        │           │         └─ Transactions (Audit)│    │  - Sold          │
 ┌──────▼──────┐    │                                │    │  - Damaged       │
 │  Price List │    │  Invoice ──▶ Reserve ──▶ Deduct │    │  = Closing Stock │
 │  + Channels │    │  Return  ──▶ Add back          │    │                  │
 │  + Regions  │    └───────────────────────────────┘    └──────────────────┘
 │  + Audit Log│
 └─────────────┘
```

**In simple terms:**
- **Product Management** = "What do we sell?" (products, categories, batches)
- **Pricing** = "At what price?" (multi-channel, multi-region pricing)
- **Warehouse Stock** = "How much do we have in our warehouses?" (real-time inventory)
- **Distributor Stock** = "How much does each distributor have?" (field-level tracking)

---

## 2. Module 1: Product Management

### 2.1 What It Does

Manages the product master data — the catalog of everything the company sells, organized by category hierarchy.

### 2.2 Objects & Relationships

```
Product_Category__c (Self-referencing hierarchy)
│
│  Category (e.g., "Beverages")
│  └── Sub-Category (e.g., "Juices")
│      └── Brand (e.g., "Brand A Juices")
│
▼
Product2 (Standard Salesforce Product)
│  ├── Name: "Orange Juice 500ml"
│  ├── ProductCode: "OJ-500"
│  ├── Family: "Beverages"
│  └── IsActive: true
│
├──▶ Product_Extension__c (1:1 FMCG-specific details)
│       ├── Barcode_EAN__c: "8901234567890"
│       ├── Weight__c: 500
│       ├── Weight_Unit__c: "ml"
│       ├── Case_Size__c: 24 (units per carton)
│       ├── Min_Order_Qty__c: 5
│       ├── HSN_SAC_Code__c: "2009" (tax code)
│       └── Product_Category__c → Brand A Juices
│
├──▶ Price_List__c (1:Many pricing entries)
│
├──▶ Batch_Master__c (1:Many batch/lot tracking)
│
└──▶ Distributor_Stock__c (1:Many stock entries)
```

### 2.3 Product Category Hierarchy (3 Levels)

| Level | Example | Parent Required? |
|-------|---------|-----------------|
| **Category** | Beverages, Snacks, Dairy | NO parent allowed |
| **Sub-Category** | Juices, Chips, Yogurt | YES — must have Category parent |
| **Brand** | Brand A Juices, Premium Chips | YES — must have Sub-Category parent |

**Validation Rules:**
- Top-level "Category" entries **cannot** have a parent
- "Sub-Category" and "Brand" entries **must** have a parent

**Key Fields:**
- `Category_Code__c` — Unique identifier (e.g., "BEV-JUICE-BA")
- `Sort_Order__c` — Controls display order in the catalog
- `Is_Active__c` — Only active categories shown in catalog

### 2.4 Product Extension (FMCG Details)

The standard Product2 object doesn't have FMCG-specific fields, so `Product_Extension__c` adds them:

| Field | What It Stores | Validation |
|-------|---------------|------------|
| Barcode EAN | 8 or 13 digit EAN code | Must be exactly 8 or 13 numeric digits |
| Weight + Unit | e.g., 500 ml or 1 kg | If weight > 0, unit is required |
| Case Size | Units per carton (e.g., 24) | Must be > 0 if specified |
| Min Order Qty | Minimum order quantity | Must be > 0 if specified |
| HSN/SAC Code | India tax classification | Free text, max 20 chars |

### 2.5 Batch Master (Expiry Tracking)

Tracks manufacturing batches for FEFO (First Expiry, First Out) picking.

| Field | Purpose | Rule |
|-------|---------|------|
| Batch_Number__c | Unique batch ID | Unique across system |
| Manufacturing_Date__c | When made | Cannot be future date |
| Expiry_Date__c | When expires | Must be after manufacturing date |
| Status__c | Active / Recalled / Expired | Picklist |
| **Is_Near_Expiry__c** | Auto-flag | **Formula:** TRUE if 0-30 days until expiry |
| **Shelf_Life_Remaining_Pct__c** | % life left | **Formula:** (Expiry - Today) / (Expiry - Mfg) |

**Example:**
```
Batch: BATCH-2026-001
Product: Orange Juice 500ml
Manufactured: 2026-01-01
Expires: 2026-07-01
Shelf Life Remaining: 71% (as of Feb 23)
Is Near Expiry: FALSE (128 days left)
```

### 2.6 Product Catalog LWC

The `productCatalog` component provides a browsable product catalog:

- **Left sidebar:** Category tree (collapsible 3-level hierarchy)
- **Main area:** Product card grid (12 per page)
- **Search:** By product name or code
- **Filter:** Active/All products
- **Detail panel:** Slides in showing full product details, active pricing, batch count, distributor stock total

---

## 3. Module 2: Pricing & Price Book

### 3.1 What It Does

Manages multi-dimensional pricing — different prices per product, region, channel, and date range. Every price change is audited.

### 3.2 Price List Object

Each `Price_List__c` record represents one price entry:

```
┌────────────────────────────────────────────────┐
│ Price List Entry                                │
│                                                 │
│ Product:    Orange Juice 500ml                  │
│ Region:     West India                          │
│ Channel:    GT (General Trade)                  │
│ Price Type: Distributor Price                   │
│ Unit Price: INR 45.00                           │
│ Min Qty:    10 (minimum order for this price)   │
│ Effective:  2026-01-01 → 2026-12-31            │
│ Active:     YES                                 │
└────────────────────────────────────────────────┘
```

### 3.3 Pricing Dimensions

| Dimension | Values | Purpose |
|-----------|--------|---------|
| **Price Type** | MRP, Distributor Price, Retailer Price, Special Price | Different price points |
| **Channel** | GT (General Trade), MT (Modern Trade), E-Commerce | Sales channel |
| **Region** | Linked to Company_Hierarchy__c | Geographic pricing |
| **Date Range** | Effective From → Effective To | Time-based pricing |
| **Min Qty** | Minimum quantity threshold | Volume discounts |

### 3.4 No Overlapping Prices (Key Rule)

The system prevents conflicting prices for the same combination:

```
ALLOWED:
  Product: OJ-500, Channel: GT, Region: West
    Entry 1: Jan 1 → Jun 30 @ INR 45
    Entry 2: Jul 1 → Dec 31 @ INR 48     (no overlap)

BLOCKED:
  Product: OJ-500, Channel: GT, Region: West
    Entry 1: Jan 1 → Jun 30 @ INR 45
    Entry 2: May 1 → Dec 31 @ INR 48     (overlaps May-Jun!)
    ERROR: "Overlapping price entry exists for this Product, Region, Channel, and date range."
```

**How it works (trigger logic):**
1. For each new/updated Price_List__c record
2. Build composite key: `ProductId | Region | Channel`
3. Query existing records with same key
4. Check if date ranges overlap (null end date = indefinite)
5. Block save if overlap found

### 3.5 Price Change Audit Log

Every time `Unit_Price__c` changes on a Price_List__c record, the system automatically creates a `Price_Change_Log__c`:

```
┌───────────────────────────────────────────┐
│ Price Change Log: PCL-00042               │
│                                           │
│ Price List: Orange Juice - GT - West      │
│ Old Price:  INR 45.00                     │
│ New Price:  INR 48.00                     │
│ Changed By: Rajesh Kumar                  │
│ Date:       2026-02-23 14:30              │
│ Reason:     Price updated via Price List  │
│             modification                  │
└───────────────────────────────────────────┘
```

**Important:** Price_List__c records **cannot be deleted** if they have Price_Change_Log__c records (Restrict Delete) — this protects the audit trail.

### 3.6 Pricing Validation Rules

| Rule | Condition | Error |
|------|-----------|-------|
| Unit Price Positive | Price <= 0 | "Unit Price must be greater than zero." |
| Date Range Valid | End date < Start date | "Effective To date must be on or after Effective From date." |
| Min Qty Valid | Min Qty < 0 | "Minimum Quantity cannot be negative." |

---

## 4. Module 3: Distributor Stock

### 4.1 What It Does

Tracks inventory at the **distributor level** — how much stock each distributor (customer/Account) has for each product. This is the "field sales" view of inventory.

### 4.2 How It Works (Daily Stock Snapshot)

Each `Distributor_Stock__c` record is a daily snapshot:

```
┌──────────────────────────────────────────────┐
│ Distributor Stock: DST-00125                  │
│                                               │
│ Distributor: ABC Distributors Pvt Ltd         │
│ Product:     Orange Juice 500ml               │
│ Stock Date:  2026-02-23                       │
│                                               │
│ Opening Stock:  100 units                     │
│ + Received:      50 units (from warehouse)    │
│ - Sold:          30 units (to retailers)      │
│ - Damaged:        5 units                     │
│ ────────────────────────────                  │
│ = Closing Stock: 115 units  (auto-calculated) │
│                                               │
│ Batch: BATCH-2026-001                         │
│ Expiry: 2026-07-01                            │
│ Is Current: YES (latest entry)                │
└──────────────────────────────────────────────┘
```

### 4.3 Closing Stock Auto-Calculation

The trigger automatically calculates on every insert and update:

```
Closing Stock = Opening Stock + Received Qty - Sold Qty - Damaged Qty
```

**Example progression:**

| Date | Opening | Received | Sold | Damaged | **Closing** |
|------|---------|----------|------|---------|-------------|
| Feb 20 | 100 | 50 | 30 | 5 | **115** |
| Feb 21 | 115 | 0 | 40 | 2 | **73** |
| Feb 22 | 73 | 80 | 25 | 0 | **128** |
| Feb 23 | 128 | 0 | 60 | 3 | **65** |

### 4.4 The "Is Current" Flag

**Problem:** Each Account + Product combination has many daily snapshots. How do we know which is the latest?

**Solution:** The `Is_Current__c` flag. Only ONE record per Account + Product can be current.

```
Account: ABC Distributors | Product: Orange Juice 500ml

DST-00120  Feb 20  Closing: 115  Is Current: FALSE
DST-00121  Feb 21  Closing: 73   Is Current: FALSE
DST-00122  Feb 22  Closing: 128  Is Current: FALSE
DST-00123  Feb 23  Closing: 65   Is Current: TRUE  ◄── Latest
```

**Automatic management by trigger:**
1. When a NEW record is created with `Is_Current = TRUE`
2. The trigger finds ALL other records with same Account + Product where `Is_Current = TRUE`
3. Sets them to `Is_Current = FALSE`
4. Result: Only the newest record is current

**Independence rules:**
- Different products are independent (Account A + Product 1 and Account A + Product 2 can both have current records)
- Different accounts are independent (Account A + Product 1 and Account B + Product 1 can both have current records)

### 4.5 Validation Rules

| Rule | What It Prevents | Error Message |
|------|-----------------|---------------|
| Non-negative quantities | Opening, Received, Sold, or Damaged < 0 | "Stock quantities cannot be negative." |
| Sold not exceeding available | Sold > (Opening + Received) | "Sold Quantity cannot exceed available stock." |
| Current stock expiry | Is Current = TRUE with past expiry date | "Current stock entries cannot have a past expiry date." |

### 4.6 Stock Dashboard LWC (`stockDashboard`)

Provides a distributor-level stock overview:

**KPI Cards (6):**
| KPI | What It Shows |
|-----|--------------|
| Total SKUs | Count of current stock entries |
| Closing Stock | Sum of all closing stock |
| Total Sold | Sum of sold quantities |
| Low Stock | Items with closing stock 1-10 |
| Zero Stock | Items with closing stock = 0 |
| Near Expiry | Batches expiring within 30 days |

**Three Tabs:**
1. **Current Stock** — Table of all current distributor stock with search/filter/pagination
2. **Near Expiry Batches** — Batches approaching expiry with shelf-life progress bars
3. **Stock Movement** — Historical stock trend for a selected Account + Product pair

---

## 5. Module 4: Warehouse Stock

### 5.1 What It Does

Manages real-time inventory at the **company warehouse level**. Tracks every unit from receipt (GRN) through storage, transfer, dispatch (Invoice), and return.

### 5.2 Core Concept: The Three Quantities

Every `Warehouse_Stock__c` record tracks inventory at the Warehouse + Product + Batch level:

```
┌─────────────────────────────────────────────────────┐
│  Warehouse Stock: WST-00042                          │
│  Warehouse: Mumbai Central (MUM001)                  │
│  Product: Orange Juice 500ml                         │
│  Batch: BATCH-2026-001                               │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │ Qty On Hand:  500 units  (physical inventory)  │  │
│  │                                                │  │
│  │ Qty Reserved: 80 units   (for confirmed orders)│  │
│  │                                                │  │
│  │ Qty Available: 420 units (On Hand - Reserved)  │  │
│  │               ▲ Formula, auto-calculated       │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  Qty Damaged: 5 units (tracked separately)           │
│  Min Stock Level: 100                                │
│  Max Stock Level: 1000                               │
│  Is Low Stock: FALSE (420 > 100)                     │
│  Is Zero Stock: FALSE (500 > 0)                      │
└─────────────────────────────────────────────────────┘
```

**Key insight:** `Qty_Available = Qty_On_Hand - Qty_Reserved`
- **On Hand** = total physical units in the warehouse
- **Reserved** = units already allocated to confirmed invoices (spoken for)
- **Available** = units free for new orders

### 5.3 Stock Alerts (Formula Fields)

| Alert | Formula | Meaning |
|-------|---------|---------|
| **Is Low Stock** | Available <= Min AND Available > 0 | Stock running low, needs replenishment |
| **Is Zero Stock** | On Hand = 0 | Completely out of stock |

### 5.4 The Five Stock Flows

All stock movements go through `INV_WarehouseStock_Service` — the central service class that updates quantities and creates audit trail records.

---

#### FLOW 1: Goods Receipt (GRN) — Stock Enters the Warehouse

```
Supplier Ships Goods
        │
        ▼
┌─────────────────┐
│ GRN Created      │  Status: Pending
│ (Goods Receipt)  │  GRN Lines: Product, Received Qty, Damaged Qty
└────────┬────────┘
         │
         │  Status changed to "Received" or "Partial"
         ▼
┌─────────────────────────────────────────────────────┐
│ INV_GRN_TriggerHandler fires                         │
│                                                      │
│ For each GRN Line:                                   │
│   Usable Qty = Received Qty - Damaged Qty            │
│                                                      │
│   Example: Received 100, Damaged 5 → Usable = 95    │
│                                                      │
│ Calls: INV_WarehouseStock_Service.addStock()         │
│   ├── Warehouse_Stock__c.Qty_On_Hand += 95           │
│   └── Stock_Transaction__c created:                  │
│       Type: Inbound_GRN | Direction: In | Qty: 95    │
└─────────────────────────────────────────────────────┘

Result: Warehouse now has 95 more units of this product
```

---

#### FLOW 2: Invoice Lifecycle — Reserve, Dispatch, or Cancel

```
Sales Order Approved → Invoice Auto-Generated
        │
        │  Invoice Status: Draft → Confirmed
        ▼
┌─────────────────────────────────────────────────────┐
│ STEP 1: RESERVATION (Invoice Confirmed)              │
│                                                      │
│ OMS_Invoice_TriggerHandler detects: Draft → Confirmed│
│                                                      │
│ For each Invoice Line (Product, Qty):                │
│   Calls: reserveStock(warehouse, items, invoiceId)   │
│   ├── Qty_Reserved += line_qty                       │
│   ├── Qty_On_Hand: NO CHANGE                         │
│   ├── Qty_Available = On Hand - Reserved (decreases) │
│   └── Transaction: Reservation | Direction: Out      │
│                                                      │
│ Example:                                             │
│   Before: On Hand=500, Reserved=0,   Available=500   │
│   After:  On Hand=500, Reserved=80,  Available=420   │
└────────────────────────┬────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
         ▼                               ▼
┌─────────────────┐             ┌─────────────────┐
│ STEP 2a: DISPATCH│             │ STEP 2b: CANCEL │
│ (Confirmed →     │             │ (Confirmed →    │
│  Dispatched)     │             │  Cancelled)     │
│                  │             │                 │
│ deductStock()    │             │ releaseStock()  │
│ On Hand -= 80    │             │ Reserved -= 80  │
│ Reserved -= 80   │             │ On Hand: same   │
│                  │             │ Available += 80 │
│ Transaction:     │             │                 │
│ Outbound_Dispatch│             │ Transaction:    │
│ Direction: Out   │             │ Release_Reserv. │
│                  │             │ Direction: In   │
│ Result:          │             │                 │
│ On Hand=420      │             │ Result:         │
│ Reserved=0       │             │ On Hand=500     │
│ Available=420    │             │ Reserved=0      │
└─────────────────┘             │ Available=500   │
                                └─────────────────┘
```

---

#### FLOW 3: Return Order — Stock Comes Back

```
Customer returns goods
        │
        ▼
┌─────────────────┐
│ Return Order     │  Linked to original Invoice
│ (Status: Draft)  │  Return Qty: 30 units
└────────┬────────┘
         │
         │  Validation: Return Qty <= Invoiced Qty - Already Returned
         │  Status changed to "Approved"
         ▼
┌─────────────────────────────────────────────────────┐
│ OMS_ReturnOrder_TriggerHandler fires                 │
│                                                      │
│ 1. Creates Credit Note (Ledger_Entry__c)             │
│ 2. Calls: addStock(warehouse, items, returnId,       │
│                     'Return_Order')                   │
│    ├── Qty_On_Hand += 30                             │
│    └── Transaction: Return_Inbound | Direction: In   │
└─────────────────────────────────────────────────────┘

Result: 30 units back in warehouse, credit note issued
```

---

#### FLOW 4: Inter-Warehouse Transfer

```
┌──────────────────────────────────────────────────────────────────┐
│                    STOCK TRANSFER LIFECYCLE                        │
│                                                                   │
│  Status:   Draft → Submitted → Approved → In Transit → Received  │
│                                    │                      │       │
│  Stock:    nothing   nothing    SOURCE      (in flight)  DEST    │
│                                 deducted                 added   │
│                                                                   │
│  Cancel from Approved or In Transit? → Source stock RESTORED      │
└──────────────────────────────────────────────────────────────────┘

Step-by-step:

1. CREATE (Draft)
   ├── Source: Mumbai Warehouse (MUM001)
   ├── Destination: Delhi Depot (DEL001)
   ├── Lines: Product OJ-500, Requested Qty: 100
   └── No stock movement yet

2. SUBMIT (Draft → Submitted)
   └── No stock movement, just approval request

3. APPROVE (Submitted → Approved)
   ├── SOURCE warehouse: Qty_On_Hand -= 100
   ├── Transaction at source: Transfer_Out | Direction: Out
   └── Stock physically leaves Mumbai

4. IN TRANSIT (Approved → In_Transit)
   └── Status tracking only, no additional stock movement

5. RECEIVE (In_Transit → Received)
   ├── DESTINATION warehouse: Qty_On_Hand += received_qty
   ├── Received Qty may differ from Approved (e.g., 95 of 100)
   ├── Short_Qty = Approved - Received = 5
   ├── Transaction at destination: Transfer_In | Direction: In
   └── Stock arrives at Delhi

6. CANCEL (from Approved or In_Transit)
   ├── SOURCE warehouse: Qty_On_Hand += approved_qty (reversed)
   └── Stock returns to Mumbai (rollback)
```

**State Machine — Valid Transitions:**

| From | Allowed Next States |
|------|-------------------|
| Draft | Submitted, Cancelled |
| Submitted | Approved, Rejected, Cancelled |
| Approved | In_Transit, Cancelled |
| In_Transit | Received, Cancelled |
| Received | (terminal — no further changes) |
| Cancelled | (terminal — no further changes) |

---

#### FLOW 5: Stock Adjustment (Inventory Reconciliation)

```
Physical count reveals discrepancy
        │
        ▼
┌─────────────────┐
│ Stock Adjustment │  Type: Physical_Count
│ (Status: Draft)  │  System shows: 500 units
│                  │  Physical count: 520 units
│                  │  Adjustment: +20
│                  │  Reason: "Found extra stock in back"
└────────┬────────┘
         │
         │  On creation: System_Qty__c = 500 (auto-snapshot)
         │  Status changed to "Approved"
         ▼
┌─────────────────────────────────────────────────────┐
│ INV_StockAdjustment_TriggerHandler fires             │
│                                                      │
│ If Adjustment_Qty > 0 (adding stock):                │
│   Calls: addStock() → Qty_On_Hand += 20              │
│   Transaction: Adjustment_Add | Direction: In        │
│                                                      │
│ If Adjustment_Qty < 0 (removing stock):              │
│   Calls: adjustDeduct() → Qty_On_Hand -= abs(qty)    │
│   Transaction: Adjustment_Deduct | Direction: Out    │
└─────────────────────────────────────────────────────┘

Adjustment Types:
  Physical_Count     - Reconciliation from physical audit
  Damage             - Write off damaged goods
  Expiry_Write_Off   - Write off expired goods
  Correction_Add     - Manual correction (add)
  Correction_Deduct  - Manual correction (remove)
```

---

### 5.5 The Audit Trail (Stock_Transaction__c)

**Every** stock movement creates an immutable transaction record:

| Transaction Type | When Created | Direction | What Changes |
|-----------------|-------------|-----------|-------------|
| Inbound_GRN | GRN received | In | On Hand increases |
| Reservation | Invoice confirmed | Out | Reserved increases |
| Release_Reservation | Invoice cancelled | In | Reserved decreases |
| Outbound_Dispatch | Invoice dispatched | Out | On Hand & Reserved decrease |
| Transfer_Out | Transfer approved | Out | Source On Hand decreases |
| Transfer_In | Transfer received | In | Dest On Hand increases |
| Adjustment_Add | Positive adjustment approved | In | On Hand increases |
| Adjustment_Deduct | Negative adjustment approved | Out | On Hand decreases |
| Return_Inbound | Return order approved | In | On Hand increases |

Each transaction records: Quantity, Running Balance, Reference Type, Reference ID, Timestamp, User.

### 5.6 Warehouse Stock Dashboard LWC (`warehouseStockDashboard`)

**KPI Cards (6):**
| KPI | Source |
|-----|--------|
| Total SKUs | Count of Warehouse_Stock records |
| On Hand | Sum of Qty_On_Hand |
| Reserved | Sum of Qty_Reserved |
| Available | Sum of Qty_Available |
| Low Stock | Count where Is_Low_Stock = TRUE |
| Zero Stock | Count where Is_Zero_Stock = TRUE |

**Three Tabs:**
1. **Current Stock** — All warehouse stock with search, filter (All/Low/Zero/Healthy), pagination
2. **Transaction Log** — Recent stock transactions in reverse chronological order
3. **Low Stock Alerts** — Items below minimum with severity badges and reorder quantities

---

## 6. How All Modules Connect

### 6.1 Relationship Map

```
                    Product_Category__c
                    (3-level hierarchy)
                           │
                           ▼
Product2 ──────────▶ Product_Extension__c
   │                 (FMCG attributes)
   │
   ├──▶ Price_List__c ──▶ Price_Change_Log__c (audit)
   │    (multi-dimensional pricing)
   │
   ├──▶ Batch_Master__c
   │    (expiry tracking)
   │
   ├──▶ Warehouse_Stock__c ◄──── Warehouse__c
   │    (company inventory)        (warehouse master)
   │         │
   │         ├── Stock_Transaction__c (audit trail)
   │         ├── Stock_Transfer__c + Lines (inter-warehouse)
   │         ├── Stock_Adjustment__c (reconciliation)
   │         └── GRN__c + Lines (goods receipt)
   │
   ├──▶ Distributor_Stock__c ◄── Account (distributor)
   │    (field inventory)
   │
   ├──▶ Invoice__c + Lines ──▶ triggers stock operations
   │    (order fulfillment)
   │
   └──▶ Return_Order__c ──▶ triggers stock return
        (customer returns)
```

### 6.2 Module Interaction Summary

| Action | Module A | Module B | What Happens |
|--------|----------|----------|-------------|
| New product created | Product Mgmt | All others | Product available for pricing, stock, orders |
| Price changed | Pricing | Audit | Price_Change_Log__c auto-created |
| GRN received | Warehouse Stock | — | Stock added to warehouse |
| Invoice confirmed | Order Mgmt | Warehouse Stock | Stock reserved in warehouse |
| Invoice dispatched | Order Mgmt | Warehouse Stock | Stock deducted from warehouse |
| Goods delivered | — | Distributor Stock | Distributor records received qty |
| Return approved | Order Mgmt | Warehouse Stock | Stock added back to warehouse |
| Transfer approved | Warehouse Stock | Warehouse Stock | Stock moves between warehouses |
| Batch near expiry | Product Mgmt | Dashboard | Alert shown on stock dashboards |

---

## 7. Complete End-to-End Flow

Here is the complete lifecycle of a product from creation to delivery:

```
STEP 1: PRODUCT SETUP
═══════════════════════
Admin creates:
  ├── Product_Category__c: Beverages > Juices > Brand A
  ├── Product2: "Orange Juice 500ml" (OJ-500)
  ├── Product_Extension__c: EAN=8901234567890, Weight=500ml, Case=24
  ├── Batch_Master__c: BATCH-2026-001, Mfg=Jan, Expiry=Jul
  └── Price_List__c: GT Channel, West Region, INR 45.00


STEP 2: GOODS RECEIPT AT WAREHOUSE
════════════════════════════════════
Supplier delivers to Mumbai warehouse:
  ├── GRN__c created: 1000 units expected
  ├── GRN_Line__c: Received=950, Damaged=50
  ├── GRN Status → "Received"
  └── Result: Warehouse_Stock__c.Qty_On_Hand = 900 (950-50)
      └── Stock_Transaction__c: Inbound_GRN, +900


STEP 3: SALES ORDER & INVOICE
═══════════════════════════════
Sales rep creates order for distributor:
  ├── Sales_Order__c: 200 units, Warehouse=Mumbai
  ├── Approved → Invoice__c auto-generated
  ├── Invoice Status → "Confirmed"
  │   └── Reservation: Qty_Reserved += 200 (Available: 700)
  ├── Invoice Status → "Dispatched"
  │   └── Deduction: Qty_On_Hand = 700, Reserved = 0
  └── Goods shipped to distributor


STEP 4: DISTRIBUTOR RECEIVES GOODS
════════════════════════════════════
Field rep records at distributor:
  └── Distributor_Stock__c:
      Opening=50, Received=200, Sold=0, Damaged=0
      Closing=250, Is_Current=TRUE


STEP 5: DAILY SALES TRACKING
═════════════════════════════
Each day, field rep updates:
  └── Distributor_Stock__c:
      Opening=250, Received=0, Sold=80, Damaged=2
      Closing=168, Is_Current=TRUE
      (Previous entry auto-marked Is_Current=FALSE)


STEP 6: INTER-WAREHOUSE TRANSFER
══════════════════════════════════
Stock needed at Delhi depot:
  ├── Stock_Transfer: Mumbai → Delhi, 100 units
  ├── Approved → Mumbai: Qty_On_Hand -= 100
  ├── Received → Delhi: Qty_On_Hand += 95 (5 short)
  └── Transactions logged at both warehouses


STEP 7: RETURN PROCESSING
══════════════════════════
Customer returns 30 damaged units:
  ├── Return_Order__c: 30 units (validated <= invoiced)
  ├── Approved → Warehouse: Qty_On_Hand += 30
  ├── Credit Note created
  └── Transaction: Return_Inbound, +30


STEP 8: STOCK ADJUSTMENT
═════════════════════════
Physical audit finds 20 extra units:
  ├── Stock_Adjustment__c: +20, Type=Physical_Count
  ├── System_Qty snapshot = current On Hand
  ├── Approved → Qty_On_Hand += 20
  └── Transaction: Adjustment_Add, +20


FINAL STATE:
════════════
Mumbai Warehouse: Qty_On_Hand reflects all movements
  All changes tracked in Stock_Transaction__c audit trail
  Dashboard shows real-time KPIs, low stock alerts
  Product catalog shows pricing, batch info, stock levels
```

---

## Quick Reference: Object Count Summary

| Module | Objects | Triggers | LWC Components |
|--------|---------|----------|----------------|
| Product Management | Product2, Product_Extension__c, Product_Category__c, Batch_Master__c | 0 (validation only) | productCatalog |
| Pricing | Price_List__c, Price_Change_Log__c | Price_List_Trigger | (in productCatalog) |
| Distributor Stock | Distributor_Stock__c | Distributor_Stock_Trigger | stockDashboard |
| Warehouse Stock | Warehouse__c, Warehouse_Stock__c, Stock_Transaction__c, Stock_Transfer__c, Stock_Transfer_Line__c, Stock_Adjustment__c, GRN__c, GRN_Line__c | 5 Triggers | warehouseStockDashboard, stockTransferForm, stockAdjustmentForm |
| **Total** | **16 objects** | **7 triggers** | **5 LWC components** |

---

## Quick Reference: Permission Sets

| Permission Set | Who Uses It | Access Level |
|---------------|------------|--------------|
| FSCRM_Product_Manager | Product admins | Full CRUD on products, pricing, batches |
| FSCRM_Field_Rep_Products | Field sales reps | Read-only on products, pricing, stock |
| FSCRM_Stock_Manager | Warehouse/stock managers | Full access to warehouse, GRN, transfers, adjustments |
