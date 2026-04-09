# End-to-End Test Guide: Orders → Targets → Achievements → Incentives

## Overview

This guide walks through the complete FMCG sales flow — from setting up products to calculating incentive payouts. Follow each step in order.

---

## Step 1: Prerequisites — Run Seed Scripts

Run these scripts in order via Developer Console (Execute Anonymous) or CLI:

```bash
# ── Master Data (run in order) ──
sf apex run --file scripts/00_delete_all.apex          # Clean slate (optional)
sf apex run --file scripts/01_company_hierarchy.apex    # Company → Division → Region
sf apex run --file scripts/02_territory_master.apex     # 8 territories with geo-fencing
sf apex run --file scripts/03_product_category.apex     # 4 L1 + 13 L2 categories
sf apex run --file scripts/04a_uom_master.apex         # 10 UOMs + 5 global conversions
sf apex run --file scripts/04_products.apex            # 30 products across all categories
sf apex run --file scripts/04b_uom_conversions.apex    # 60 product-specific BOX/CSE conversions
sf apex run --file scripts/05_batch_master.apex        # 60 batches (2 per product, 2 near-expiry)
sf apex run --file scripts/06_tax_configuration.apex   # GST rates per product
sf apex run --file scripts/07_price_list.apex          # 8 priority levels (Base → Customer)
sf apex run --file scripts/08_warehouse.apex           # 5 warehouses (Central/Regional/Depot/C&F)

# ── Accounts & Outlets ──
sf apex run --file scripts/09_accounts.apex            # 20 accounts (3D + 2SS + 12R + 3MT)
sf apex run --file scripts/10_beats_and_outlets.apex   # 8 beats + outlet mappings
sf apex run --file scripts/11_schemes.apex             # 8 schemes + slabs + mappings
sf apex run --file scripts/11a_must_sell_config.apex   # 30 Priority Sell configs

# ── HR & Employees ──
sf apex run --file scripts/13_employees.apex           # 15 employees (NSM→RSM→ASM→SR hierarchy)
sf apex run --file scripts/14_holidays.apex            # 20 holidays (national/regional/company)
sf apex run --file scripts/15_leave_requests.apex      # 10 leave requests (all statuses)
sf apex run --file scripts/16_leave_policies.apex      # 8 leave policies + balances
sf apex run --file scripts/16_journey_plans.apex       # 3 journey plans + daily plan entries

# ── Targets & Incentives ──
sf apex run --file scripts/12_targets.apex             # Territory targets (Rev/Col/Vol/Brand/Outlet)
sf apex run --file scripts/13_target_periods.apex      # 17 periods (Annual→Quarterly→Monthly)
sf apex run --file scripts/14_target_criteria_and_actuals.apex  # 6 criteria + sample actuals
sf apex run --file scripts/13_incentive_slabs.apex     # 40+ slabs (4 profiles × multiple tiers)
sf apex run --file scripts/15_test_team.apex           # 15 test users with FSCRM profiles
sf apex run --file scripts/18_kpi_metrics.apex         # 15 KPI metrics for Dynamic KPI Dashboard

# ── Transactional Data (run last) ──
sf apex run --file scripts/seed_transactional_data.apex  # Attendance, visits, orders, collections
```

After running, verify record counts:
```apex
System.debug('Products: '     + [SELECT COUNT() FROM Product_Extension__c WHERE Is_Active__c = true]);    // 30
System.debug('Accounts: '     + [SELECT COUNT() FROM Account]);                                            // 20
System.debug('Territories: '  + [SELECT COUNT() FROM Territory_Master__c WHERE Is_Active__c = true]);      // 8
System.debug('Warehouses: '   + [SELECT COUNT() FROM Warehouse__c WHERE Is_Active__c = true]);             // 5
System.debug('Beats: '        + [SELECT COUNT() FROM Beat__c WHERE Is_Active__c = true]);                  // 8
System.debug('Batches: '      + [SELECT COUNT() FROM Batch_Master__c WHERE Status__c = 'Active']);         // 60
System.debug('Employees: '    + [SELECT COUNT() FROM Employee__c WHERE Is_Active__c = true]);              // 15
System.debug('Holidays: '     + [SELECT COUNT() FROM Holiday__c WHERE Is_Active__c = true]);               // 20
System.debug('Periods: '      + [SELECT COUNT() FROM Target_Period__c WHERE Is_Active__c = true]);         // 17
System.debug('Criteria: '     + [SELECT COUNT() FROM Target_Criteria__c WHERE Active__c = true]);          // 6
System.debug('UOMs: '         + [SELECT COUNT() FROM UOM__c WHERE Is_Active__c = true]);                   // 10
System.debug('UOM Conv: '     + [SELECT COUNT() FROM UOM_Conversion__c WHERE Is_Active__c = true]);        // 65+
System.debug('Must Sell: '    + [SELECT COUNT() FROM Must_Sell_Config__c WHERE Is_Active__c = true]);      // 30
System.debug('Schemes: '      + [SELECT COUNT() FROM Scheme__c WHERE Status__c = 'Active']);               // 7
System.debug('Slabs: '        + [SELECT COUNT() FROM Incentive_Slab__c WHERE Is_Active__c = true]);        // 40+
System.debug('Targets: '      + [SELECT COUNT() FROM Target__c WHERE Status__c = 'Active']);               // 40
System.debug('Journey Plans: '+ [SELECT COUNT() FROM Journey_Plan__c]);                                    // 3
System.debug('Leave Requests: '+ [SELECT COUNT() FROM Leave_Request__c]);                                  // 10
System.debug('Day Attendance: '+ [SELECT COUNT() FROM Day_Attendance__c]);                                 // 5
System.debug('Visits: '       + [SELECT COUNT() FROM Visit__c]);                                           // 17+
System.debug('Orders: '       + [SELECT COUNT() FROM Sales_Order__c]);                                     // 12+
System.debug('Collections: '  + [SELECT COUNT() FROM Collection__c]);                                      // 7
System.debug('KPI Metrics: ' + [SELECT COUNT() FROM KPI_Metric__c WHERE Is_Active__c = true]);              // 15
```

> **Note:** All scripts have cleanup code — they can be safely re-run anytime to reset data.

---

## Step 2: UOM Configuration

### 2.1 Verify UOM Master
Go to **UOM tab** and verify 10 UOMs exist:
| UOM Code | Name | Type | Is Base |
|---|---|---|---|
| PCS | Pieces | Count | Yes |
| BOX | Box | Count | No |
| CSE | Case | Count | No |
| DOZ | Dozen | Count | No |
| KG | Kilogram | Weight | Yes |
| GM | Gram | Weight | No |
| LTR | Litre | Volume | Yes |
| ML | Millilitre | Volume | No |
| PKT | Pack | Count | No |
| STP | Strip | Count | No |

### 2.2 Verify UOM Conversions
Go to **UOM Conversion Manager tab**. You should see:

**Global conversions** (no product — apply to all):
| From UOM | To UOM | Factor | Type |
|---|---|---|---|
| Box (BOX) | Pieces (PCS) | 12 | Global |
| Case (CSE) | Box (BOX) | 10 | Global |
| Dozen (DOZ) | Pieces (PCS) | 12 | Global |
| Kilogram (KG) | Gram (GM) | 1000 | Global |
| Litre (LTR) | Millilitre (ML) | 1000 | Global |

**Product-specific conversions** (created by `04b_uom_conversions.apex`):
| Product | From UOM | To UOM | Factor | Source |
|---|---|---|---|---|
| Crispy Masala Chips 150g | BOX | PCS | 48 | Case_Size__c = 48 |
| Classic Cream Biscuits 200g | BOX | PCS | 60 | Case_Size__c = 60 |
| Fresh Mango Juice 1L | BOX | PCS | 24 | Case_Size__c = 24 |
| Power Wash Detergent 1kg | BOX | PCS | 20 | Case_Size__c = 20 |
| All products | CSE | BOX | 10 | Standard |

Product-specific conversions override global ones. Each product gets 2 conversions (BOX→PCS using `Case_Size__c`, CSE→BOX at 10).

### 2.3 How UOM Works in Orders
When creating an order line:
- User selects **Order UOM** (e.g., BOX)
- System finds the matching UOM conversion (product-specific first, then global)
- Auto-calculates **Base Quantity** = Order Quantity × Conversion Factor
- Example: 2 BOX of Crispy Masala Chips → 2 × 48 = 96 PCS base quantity
- Pricing uses Base UOM price × Base Quantity
- Target achievement calculation uses **Base Quantity** for volume, **Total Amount** for revenue

---

## Step 3: Scheme Configuration

### 3.1 Verify Active Schemes
Go to **Scheme Manager tab**. You should see 7 active schemes:

| Code | Scheme | Category | Type | Key Config |
|---|---|---|---|---|
| SCH-2026-001 | Chips Buy 3 Get 1 Free | Free Products | Same Product (QTY) | Min Qty: 3, Free: Classic Salted Chips 75g |
| SCH-2026-002 | Biscuits MOV Free Product | Free Products | Same Product (VAL) | MOV: ₹500, Free: Mango Toffees |
| SCH-2026-003 | Snacks & Noodles 3% Off | Discount in % | Assorted Product (QTY) | 3% discount, Max Cap: ₹500 |
| SCH-2026-004 | Detergent Invoice Qty Discount | Discount in Value | Invoice Qty Based | 10 KG threshold, ₹200 discount |
| SCH-2026-005 | Invoice Value Reward Points | Reward Points | Invoice Val Based | ₹5,000 threshold, 300 points |
| SCH-2026-006 | Juice Qty Reward Points | Reward Points | Same Product (QTY) | Min 6 packs, 300 points |
| SCH-2026-007 | Personal Care Volume Discount | Discount in % | Same Product (QTY) | Slab-based: 5%/8%/12% |

### 3.2 Scheme Slabs
Check **Scheme Slabs** on the Personal Care and Chips schemes:
| Scheme | Slab Type | Range | Discount |
|---|---|---|---|
| Personal Care Volume Discount | Value | ₹1,000 – ₹4,999 | 5% |
| Personal Care Volume Discount | Value | ₹5,000 – ₹14,999 | 8% |
| Personal Care Volume Discount | Value | ₹15,000+ | 12% |
| Chips Buy 3 Get 1 Free | Quantity | 10 – 49 | 2 Free |
| Chips Buy 3 Get 1 Free | Quantity | 50 – 999 | 12 Free |
| Invoice Value Reward Points | Value | ₹5,000 – ₹9,999 | 300 points |
| Invoice Value Reward Points | Value | ₹10,000+ | 750 points |

### 3.3 How Schemes Apply to Orders
- Scheme engine auto-evaluates applicable schemes on order save
- Filters by: Channel (GT/MT), Outlet Type, Territory mapping, Customer Type
- Discounts applied to matching line items
- Scheme_Applied__c, Scheme_Discount__c populated on Order_Line_Item__c
- Budget tracked on Scheme__c (Budget_Used__c increments)

---

## Step 4: Must-Sell Configuration

### 4.1 Verify Must-Sell Configs
Go to **Priority Sell Config tab** (Must_Sell_Config__c):

**National Must Sell** (all territories, all channels):
| Product | Classification | Min Qty |
|---|---|---|
| Crispy Masala Chips 150g | Must Sell | 12 |
| Classic Cream Biscuits 200g | Must Sell | 12 |
| Instant Noodles Masala 70g | Must Sell | 24 |
| Fresh Mint Toothpaste 150g | Must Sell | 6 |
| Power Wash Detergent 1kg | Must Sell | 6 |

**Channel-specific** (GT / MT):
| Product | Channel | Classification | Min Qty |
|---|---|---|---|
| Tangy Tomato Chips 150g | GT | Must Sell | 12 |
| Cola Fizz 300ml | GT | Must Sell | 12 |
| Classic Salted Chips 75g | MT | Must Sell | 24 |
| Digestive Wheat Biscuits 250g | MT | Must Sell | 12 |

**Territory-specific** (Delhi, Mumbai, Bangalore, Chennai):
| Product | Territory | Outlet Type | Classification |
|---|---|---|---|
| Instant Coffee 50g | Delhi | Grocery | Must Sell |
| Hair Oil 200ml | Mumbai | — | Must Sell |
| Instant Coffee 50g | Bangalore | Grocery | Must Sell |
| Hair Oil 200ml | Chennai | — | Must Sell |

### 4.2 How Must-Sell Works
- During order creation, `getMustSellProducts()` returns applicable configs for the account
- Filters by: Territory, Channel, Outlet Type (matches Account.Outlet_Type__c)
- `Must_Sell_Compliance__c` on Sales_Order__c shows compliance %
- Visit's `Must_Sell_Products_Required__c` vs `Must_Sell_Products_Ordered__c`
- Non-compliant orders can be flagged or require `Must_Sell_Override__c`

---

## Step 5: Verify Master Data

### 5.1 Company Hierarchy
Go to **Company Hierarchy tab**:
```
FreshFields FMCG Ltd (HC-FFMCG) — Parent Company
├── Foods Division (HC-DIV-FOOD)
│   ├── North Region (HC-REG-NORTH)
│   ├── South Region (HC-REG-SOUTH)
│   ├── West Region (HC-REG-WEST)
│   └── East Region (HC-REG-EAST)
├── Personal Care Division (HC-DIV-PCARE)
└── Home Care Division (HC-DIV-HCARE)
```

### 5.2 Territory Coverage
| Territory | Code | State | City | Geo-Fence | Warehouses |
|---|---|---|---|---|---|
| Delhi NCR | TER-DEL-001 | Delhi | New Delhi | 28.61°N, 77.21°E, 25km | WH-DEL (Regional) |
| Mumbai Metro | TER-MUM-001 | Maharashtra | Mumbai | 19.08°N, 72.88°E, 25km | WH-MUM (Central) |
| Bengaluru Urban | TER-BLR-001 | Karnataka | Bengaluru | 12.97°N, 77.59°E, 25km | WH-BLR (Regional) |
| Chennai City | TER-CHN-001 | Tamil Nadu | Chennai | 13.08°N, 80.27°E, 25km | — |
| Kolkata Metro | TER-KOL-001 | West Bengal | Kolkata | 22.57°N, 88.36°E, 25km | WH-KOL (Depot) |
| Hyderabad City | TER-HYD-001 | Telangana | Hyderabad | 17.39°N, 78.49°E, 25km | — |
| Pune Metro | TER-PUN-001 | Maharashtra | Pune | 18.52°N, 73.86°E, 25km | — |
| Ahmedabad City | TER-AHM-001 | Gujarat | Ahmedabad | 23.02°N, 72.57°E, 25km | WH-AHM (C&F) |

### 5.3 Employee Hierarchy (13_employees.apex)

The Employee__c records form a hierarchy via the `Reporting_Manager__c` self-referencing lookup.
This hierarchy drives target rollup (TSE→ASM→RSM→NSM) and incentive calculations.

```
Rajesh Kapoor (NSM, Band 1, ₹1,20,000) — All India
├── Suresh Menon (RSM West, Band 2, ₹80,000) — Mumbai
│   ├── Amit Patel (ASM, Band 3, ₹50,000) — Mumbai
│   │   ├── Arjun Deshmukh (SR, Band 4, ₹30,000) — Mumbai
│   │   └── Meera Joshi (SR, Band 4, ₹30,000) — Pune
│   └── Deepa Nair (ASM, Band 3, ₹50,000) — Bangalore
│       ├── Karthik Iyer (SR, Band 4, ₹30,000) — Bangalore
│       └── Divya Reddy (SR, Band 4, ₹30,000) — Hyderabad
└── Priya Sharma (RSM North, Band 2, ₹80,000) — Delhi
    ├── Vikram Singh (ASM, Band 3, ₹50,000) — Delhi
    │   ├── Rahul Verma (SR, Band 4, ₹30,000) — Delhi
    │   └── Sneha Gupta (SR, Band 4, ₹30,000) — Delhi
    └── Kavitha Rajan (ASM, Band 3, ₹50,000) — Chennai
        ├── Pradeep Menon (SR, Band 4, ₹30,000) — Chennai
        └── Ankit Agarwal (SR, Band 4, ₹30,000) — Kolkata
```

**Full Employee Directory:**

| # | Name | Code | Designation | Band | Salary | Territory | Reports To |
|---|---|---|---|---|---|---|---|
| 1 | Rajesh Kapoor | EMP-001 | National Sales Manager | Band 1 | ₹1,20,000 | All India | — |
| 2 | Suresh Menon | EMP-002 | Regional Sales Manager | Band 2 | ₹80,000 | Mumbai | Rajesh Kapoor |
| 3 | Priya Sharma | EMP-003 | Regional Sales Manager | Band 2 | ₹80,000 | Delhi | Rajesh Kapoor |
| 4 | Amit Patel | EMP-004 | Area Sales Manager | Band 3 | ₹50,000 | Mumbai | Suresh Menon |
| 5 | Deepa Nair | EMP-005 | Area Sales Manager | Band 3 | ₹50,000 | Bangalore | Suresh Menon |
| 6 | Vikram Singh | EMP-006 | Area Sales Manager | Band 3 | ₹50,000 | Delhi | Priya Sharma |
| 7 | Kavitha Rajan | EMP-007 | Area Sales Manager | Band 3 | ₹50,000 | Chennai | Priya Sharma |
| 8 | Arjun Deshmukh | EMP-008 | Sales Representative | Band 4 | ₹30,000 | Mumbai | Amit Patel |
| 9 | Meera Joshi | EMP-009 | Sales Representative | Band 4 | ₹30,000 | Pune | Amit Patel |
| 10 | Karthik Iyer | EMP-010 | Sales Representative | Band 4 | ₹30,000 | Bangalore | Deepa Nair |
| 11 | Divya Reddy | EMP-011 | Sales Representative | Band 4 | ₹30,000 | Hyderabad | Deepa Nair |
| 12 | Rahul Verma | EMP-012 | Sales Representative | Band 4 | ₹30,000 | Delhi | Vikram Singh |
| 13 | Sneha Gupta | EMP-013 | Sales Representative | Band 4 | ₹30,000 | Delhi | Vikram Singh |
| 14 | Pradeep Menon | EMP-014 | Sales Representative | Band 4 | ₹30,000 | Chennai | Kavitha Rajan |
| 15 | Ankit Agarwal | EMP-015 | Sales Representative | Band 4 | ₹30,000 | Kolkata | Kavitha Rajan |

### 5.3a Verify Hierarchy in Employee Manager

1. Go to **HR & Expense** → **Employee Manager**
2. Select any employee (e.g., Suresh Menon)
3. Click the **Hierarchy** tab → see the full org tree with:
   - Color-coded levels (Blue=NSM, Green=RSM, Purple=ASM, Orange=SR)
   - Expand/collapse branches
   - Current employee highlighted
   - Click any node → navigates to that employee's detail
4. Click the **Team** tab → see flat direct reports only (e.g., Amit Patel, Deepa Nair)
5. Verify **Reports To** in the Details tab shows the correct manager

### 5.3b User ↔ Employee Mapping (15_test_team.apex)

The `15_test_team.apex` script creates 15 test **User** records with FSCRM permission set profiles.
These are separate from the Employee__c records above but can be linked via `Employee__c.User__c`.

| # | User Name | Username | Profile | Employee Code |
|---|---|---|---|---|
| 1 | Test NSM User | nsm@fmcg-test.com | FSCRM_NSM | TEST-001 |
| 2 | Test RSM West | rsm.west@fmcg-test.com | FSCRM_RSM | TEST-002 |
| 3 | Test RSM North | rsm.north@fmcg-test.com | FSCRM_RSM | TEST-003 |
| 4 | Test ASM Mumbai | asm.mumbai@fmcg-test.com | FSCRM_ASM | TEST-004 |
| 5 | Test ASM Bangalore | asm.blr@fmcg-test.com | FSCRM_ASM | TEST-005 |
| 6 | Test ASM Delhi | asm.delhi@fmcg-test.com | FSCRM_ASM | TEST-006 |
| 7 | Test ASM Chennai | asm.chennai@fmcg-test.com | FSCRM_ASM | TEST-007 |
| 8-15 | Test TSE [City] | tse.[city]@fmcg-test.com | FSCRM_TSE | TEST-008..015 |

**Profile → PBIS Incentive Mapping:**
- **FSCRM_TSE** → Revenue slabs: 4.5%/10%/17.75%/20% of salary
- **FSCRM_ASM** → Revenue slabs: 3.75%/8.25%/14.5%/17% of salary
- **FSCRM_RSM** → Revenue slabs: 3%/7%/12%/15% of salary
- **FSCRM_NSM** → Revenue slabs: 2.5%/5.5%/10%/12.5% of salary

> **Important:** Employee__c records (EMP-xxx) hold operational data (hierarchy, salary, territory).
> User records (TEST-xxx) control login, permissions, and dashboard access.
> Link them via `Employee__c.User__c` lookup to connect the two.

### 5.4 Beat Plan Coverage
| Beat | Territory | Days | TSE | Outlets |
|---|---|---|---|---|
| BT-DEL-001 | Delhi | Mon/Wed | Rahul Kumar | Lakshmi General Store, Ganesh Provision |
| BT-DEL-002 | Delhi | Tue/Thu | Anjali Reddy | — |
| BT-MUM-001 | Mumbai | Mon/Wed/Fri | Karthik Nambiar | Kumar Kirana, Deepak Grocery |
| BT-MUM-002 | Mumbai | Tue/Thu/Sat | Meera Iyer | — |
| BT-BLR-001 | Bangalore | Mon/Wed/Fri | Nikhil Rao | Gupta Mart, Sri Balaji Store |
| BT-BLR-002 | Bangalore | Tue/Thu/Sat | Pooja Desai | — |
| BT-CHN-001 | Chennai | Mon/Wed/Fri | Arjun Patel | Modern Needs Store, Daily Fresh Mart |
| BT-CHN-002 | Chennai | Tue/Thu/Sat | Divya Joshi | — |

### 5.5 Account Distribution
| Record Type | Count | Channel | Outlet Types |
|---|---|---|---|
| Distributor | 3 | GT | — |
| Super Stockist | 2 | GT | — |
| Retailer | 12 | GT | Grocery (7), General Store (3), Medical (1), Hardware (1) |
| Modern Trade | 3 | MT | — |

---

## Step 6: Verify Price List Priority Pricing

Before creating orders, verify the 8-level price list priority system is working correctly.

### 6.1 How Price Resolution Works
The system resolves prices in this priority order (lowest number = highest priority):

| Priority | Level | Price Rule | Example |
|---|---|---|---|
| 1 | Customer-wise | Specific distributor/account | Sharma Distributors → 50% of MRP |
| 2 | Category + Territory + Channel | 3-dimension match | Snacks + Delhi + GT → 58% of MRP |
| 3 | Territory + Channel | 2-dimension match | Delhi GT → 72%, Mumbai MT → 55% |
| 4 | Category + Territory | 2-dimension match | Snacks + Delhi → 62% of MRP |
| 5 | Territory-wise | Territory only | Delhi → 73.5%, Mumbai → 68% |
| 6 | Channel-wise | Channel only | MT → 60%, E-Commerce → 100% |
| 7 | Category-wise | Category only | Snacks → 65% of MRP |
| 8 | Base price | No dimensions (fallback) | All products → 70% of MRP |

### 6.2 Verify with Example Product
Take **Crispy Masala Chips 150g** (MRP ₹30, Unit_Price ₹21):

| Scenario | Account | Expected Price | Why |
|---|---|---|---|
| GT Retailer in Delhi | Lakshmi General Store | ₹17.40 (58%) | Priority 2: Snacks + Delhi + GT |
| MT Store in Mumbai | HyperBazaar Mumbai | ₹16.50 (55%) | Priority 3: Mumbai + MT |
| GT Retailer in Bangalore | Gupta Mart | ₹21.00 (70%) | Priority 8: Base price (no territory/channel rule) |
| Distributor (Delhi) | Sharma Distributors | ₹15.00 (50%) | Priority 1: Customer-wise |

**How to test:** Search for the product in Order Entry on each account — the displayed price should match the above.

> **Note:** Prices come from `Price_List__c` records. If no matching price list entry exists, the system falls back to `product.Unit_Price__c`, then `product.MRP__c`.

---

## Step 7: Create Sales Orders

### 7.1 Create a Visit
1. Go to **Visit Manager tab**
2. Click **Start Day** → Attendance record created with GPS, time
3. Select beat **BT-DEL-001** (Delhi) → Click **Confirm Beat**
4. On the Visit Board, find a planned outlet (e.g., **Lakshmi General Store**)
5. Click **Check In** → Visit starts with GPS capture
6. Alternatively, click **Ad-Hoc Visit** to visit an outlet outside the beat plan

### 7.2 Create Order 1 — GT Retailer in Delhi (Must-Sell + Scheme Test)
Account: **Lakshmi General Store** (GT, Delhi, Grocery, Class A)

From the active visit, click **Create Order** and add these products:

| # | Product | SKU | UOM | Qty | Base Qty | Unit Price | GST | Line Total |
|---|---|---|---|---|---|---|---|---|
| 1 | Crispy Masala Chips 150g | FF-SNK-001 | BOX | 2 | 96 PCS | ₹21.00 | 12% | ₹2,016.00 |
| 2 | Classic Cream Biscuits 200g | FF-BIS-001 | PCS | 24 | 24 PCS | ₹17.50 | 18% | ₹420.00 |
| 3 | Instant Noodles Masala 70g | FF-NDL-001 | PCS | 24 | 24 PCS | ₹9.80 | 18% | ₹235.20 |
| 4 | Fresh Mint Toothpaste 150g | FF-ORL-001 | PCS | 12 | 12 PCS | ₹45.50 | 28% | ₹546.00 |
| 5 | Power Wash Detergent 1kg | FF-DET-001 | PCS | 6 | 6 PCS | ₹94.50 | 18% | ₹567.00 |
| 6 | Fresh Mango Juice 1L | FF-JUC-001 | PCS | 6 | 6 PCS | ₹84.00 | 12% | ₹504.00 |

**Verify these auto-calculations:**

**UOM Conversion (Line 1):**
- Order UOM: BOX, Qty: 2
- Product-specific conversion: 1 BOX = 48 PCS (from `Case_Size__c = 48`)
- Base Quantity = 2 × 48 = **96 PCS**
- Line Total = 96 × ₹21.00 = ₹2,016.00
- Label shows "= 96 PCS" below the UOM dropdown

**Must-Sell Compliance:**
- National must-sell products in this order: Chips (✓ 96 ≥ 12), Biscuits (✓ 24 ≥ 12), Noodles (✓ 24 ≥ 24), Toothpaste (✓ 12 ≥ 6), Detergent (✓ 6 ≥ 6)
- All 5 national must-sell products included with min qty met → **100% compliance**

**Scheme Evaluation:**
- **SCH-2026-003** "Snacks & Noodles 3% Off": Chips + Noodles qualify → 3% off on ₹2,251.20 = **-₹67.54**
- **SCH-2026-001** "Chips Buy 3 Get 1 Free": Base qty 96 ≥ min 3 → slab 50-999 gives **12 free** Classic Salted Chips 75g
- **SCH-2026-006** "Juice Qty Reward Points": 6 packs of juice ≥ min 6 → **300 reward points**

**Tax Calculation:**
| Line | Taxable Amount | GST Rate | CGST | SGST | Tax |
|---|---|---|---|---|---|
| Chips | ₹2,016.00 | 12% | ₹120.96 | ₹120.96 | ₹241.92 |
| Biscuits | ₹420.00 | 18% | ₹37.80 | ₹37.80 | ₹75.60 |
| Noodles | ₹235.20 | 18% | ₹21.17 | ₹21.17 | ₹42.34 |
| Toothpaste | ₹546.00 | 28% | ₹76.44 | ₹76.44 | ₹152.88 |
| Detergent | ₹567.00 | 18% | ₹51.03 | ₹51.03 | ₹102.06 |
| Juice | ₹504.00 | 12% | ₹30.24 | ₹30.24 | ₹60.48 |
| **Total** | **₹4,288.20** | | | | **₹675.28** |

**Order Summary:**
- Gross Amount: ₹4,288.20
- Scheme Discount: -₹67.54
- Net Taxable: ₹4,220.66
- Total Tax: ~₹665 (recalculated on net)
- **Order Total: ~₹4,886**
- Free Qty: 12 PCS (Classic Salted Chips 75g)
- Reward Points: 300

**Submit Order** → Status = "Submitted" → **Approve** → Status = "Approved"

### 7.3 Create Order 2 — GT Retailer in Mumbai (UOM + Invoice Scheme Test)
Account: **Kumar Kirana** (GT, Mumbai, Grocery, Class A)

| # | Product | SKU | UOM | Qty | Base Qty | Unit Price | GST | Line Total |
|---|---|---|---|---|---|---|---|---|
| 1 | Power Wash Detergent 1kg | FF-DET-001 | BOX | 1 | 12 PCS | ₹94.50 | 18% | ₹1,134.00 |
| 2 | Power Wash Detergent 500g | FF-DET-003 | PCS | 12 | 12 PCS | ₹50.40 | 18% | ₹604.80 |
| 3 | Anti-Dandruff Shampoo 200ml | FF-HAR-002 | PCS | 12 | 12 PCS | ₹122.50 | 28% | ₹1,470.00 |
| 4 | Neem Face Wash 100ml | FF-SKN-001 | PCS | 12 | 12 PCS | ₹59.50 | 28% | ₹714.00 |

**Verify:**

**UOM Conversion (Line 1):**
- 1 BOX of Detergent 1kg → 1 × 12 (Case_Size = 12) = **12 PCS**
- Line Total = 12 × ₹94.50 = ₹1,134.00

**Scheme Evaluation:**
- **SCH-2026-004** "Detergent Invoice Qty Discount": Total detergent = 12 + 12 = 24 PCS ≥ 10 KG threshold → **₹200 discount**
- **SCH-2026-007** "Personal Care Volume Discount": Shampoo ₹1,470 + Face Wash ₹714 = ₹2,184 → slab ₹1,000-₹4,999 = **5% off** = -₹109.20

**Order Total: ~₹4,500** (after discounts + tax)

### 7.4 Create Order 3 — MT Store (Channel-Specific Pricing + Invoice Value Scheme)
Account: **HyperBazaar Mumbai** (MT, Mumbai, Class A)

| # | Product | SKU | UOM | Qty | Unit Price | GST | Line Total |
|---|---|---|---|---|---|---|---|
| 1 | Crispy Masala Chips 150g | FF-SNK-001 | CSE | 1 | ₹21.00 | 12% | ₹10,080.00 |
| 2 | Classic Cream Biscuits 200g | FF-BIS-001 | BOX | 2 | ₹17.50 | 18% | ₹2,100.00 |
| 3 | Fresh Mango Juice 1L | FF-JUC-001 | BOX | 2 | ₹84.00 | 12% | ₹2,016.00 |

**Verify:**

**UOM Conversions:**
- 1 CSE of Chips → 1 × 10 (CSE→BOX) × 48 (BOX→PCS) = **480 PCS** — ₹480 × ₹21 = ₹10,080
- 2 BOX of Biscuits → 2 × 60 = **120 PCS** — ₹120 × ₹17.50 = ₹2,100
- 2 BOX of Juice → 2 × 12 = **24 PCS** — ₹24 × ₹84 = ₹2,016

**Price List Note:** MT channel → Price List Priority 3 (Mumbai + MT) gives 55% of MRP.
Chips: 55% of ₹30 = ₹16.50/PCS. If this price list entry exists, the price column should show ₹16.50, not ₹21.00.

**Scheme Evaluation:**
- **SCH-2026-005** "Invoice Value Reward Points": Invoice total ~₹14,196 ≥ ₹10,000 → slab ₹10,000+ = **750 reward points**

### 7.5 Create Orders 4-8 (Spread Across Territories)
Create additional orders to build achievement data:

| Order | Account | Territory | Channel | Products Focus | Approx Total |
|---|---|---|---|---|---|
| ORD-004 | Ganesh Provision Store | Delhi | GT | Biscuits, Noodles, Tea | ~₹3,200 |
| ORD-005 | Deepak Grocery | Mumbai | GT | Detergent, Cleaners, Chips | ~₹5,800 |
| ORD-006 | Gupta Mart | Bangalore | GT | Juice, Soda, Confectionery | ~₹2,900 |
| ORD-007 | Modern Needs Store | Chennai | GT | Hair Care, Skin Care, Oral | ~₹4,100 |
| ORD-008 | SuperMart Central Delhi | Delhi | MT | Mixed (large qty) | ~₹18,000 |

> **Tip:** Each order should include at least 3 must-sell products to test compliance tracking.

### 7.6 Create Collections Against Orders
After orders are approved/delivered, record payments:

| Collection | Account | Amount | Mode | Receipt | Notes |
|---|---|---|---|---|---|
| COL-001 | Lakshmi General Store | ₹2,443 (50%) | Cash | RCP-2026-0001 | Partial payment |
| COL-002 | Kumar Kirana | ₹3,375 (75%) | Cheque | RCP-2026-0002 | Cheque #10000001, SBI, +7 days |
| COL-003 | HyperBazaar Mumbai | ₹16,000 (100%) | NEFT | RCP-2026-0003 | HDFC Bank transfer |
| COL-004 | Ganesh Provision Store | ₹1,600 (50%) | UPI | RCP-2026-0004 | UPI reference auto-generated |
| COL-005 | Deepak Grocery | ₹4,350 (75%) | Cash | RCP-2026-0005 | — |
| COL-006 | Gupta Mart | ₹2,900 (100%) | UPI | RCP-2026-0006 | — |
| COL-007 | (On-Account Advance) | ₹10,000 | Cash | RCP-2026-ADV-001 | Advance, not tied to order |

**Total Collected:** ~₹40,668

---

## Step 8: Configure Target Criteria

### 8.1 Verify Target Criteria
Go to **Target Criteria Manager tab** (created by `14_target_criteria_and_actuals.apex`). Ensure these 6 criteria exist:

| Criteria | Object | Operator | Field | Category | Weight | Prerequisite |
|---|---|---|---|---|---|---|
| Revenue | Sales_Order__c | SUM | Total_Net_Amount__c | Revenue | 60% | None |
| Collection | Collection__c | SUM | Amount__c | Collection | 10% | None |
| Volume | Sales_Order__c | COUNT | Id | Activity | 20% | None |
| Coverage | Visit__c | COUNT | Id | Coverage | — | Visit completed & productive |
| Focus Brand | Sales_Order__c | SUM | Total_Net_Amount__c | Revenue | 15% | Revenue ≥ 90% |
| Outlet Expansion | Account | COUNT | Id | Coverage | 15% | Revenue ≥ 90% |

### 8.2 Verify Filters
- **Revenue**: `Status__c IN ('Approved', 'Delivered')`
- **Collection**: `Status__c = 'Confirmed'`
- **Coverage**: `Visit_Status__c = 'Completed' AND Is_Productive__c = true`

### 8.3 How Prerequisite Works
Focus Brand and Outlet Expansion have **Revenue ≥ 90%** as prerequisite:
- If TSE achieves Revenue = 95% → Focus Brand and Outlet Expansion are calculated normally
- If TSE achieves Revenue = 85% → Focus Brand and Outlet Expansion payout = **₹0** (prerequisite not met)

---

## Step 9: Verify Targets (from 12_targets.apex)

### 9.1 Territory Revenue Targets (Current Month)
Go to **Target__c** records. The seed script creates 5 target types per territory:

| Territory | Code | Revenue | Collection (90%) | Volume | Productive Calls | New Outlets |
|---|---|---|---|---|---|---|
| Delhi NCR | TER-DEL-001 | ₹5,00,000 | ₹4,50,000 | 2,000 | 9,00,000 (annual) | 10 |
| Mumbai Metro | TER-MUM-001 | ₹7,50,000 | ₹6,75,000 | 3,000 | 13,50,000 (annual) | 10 |
| Bengaluru Urban | TER-BLR-001 | ₹4,00,000 | ₹3,60,000 | 1,600 | 7,20,000 (annual) | 10 |
| Chennai City | TER-CHN-001 | ₹3,50,000 | ₹3,15,000 | 1,400 | 6,30,000 (annual) | 10 |
| Kolkata Metro | TER-KOL-001 | ₹3,00,000 | ₹2,70,000 | 1,200 | 5,40,000 (annual) | 10 |
| Hyderabad City | TER-HYD-001 | ₹3,50,000 | ₹3,15,000 | 1,400 | 6,30,000 (annual) | 10 |
| Pune Metro | TER-PUN-001 | ₹2,50,000 | ₹2,25,000 | 1,000 | 4,50,000 (annual) | 10 |
| Ahmedabad City | TER-AHM-001 | ₹2,80,000 | ₹2,52,000 | 1,120 | 5,04,000 (annual) | 10 |

**KPI Weights:** Revenue 40%, Collection 30%, Volume 20%, Productive Calls 15%, New Outlets 10%

### 9.2 Target Line Breakdown (Revenue by Category)
Each revenue target is broken into 4 category target lines:

| Category | Code | Split % | Avg Price/Case | Delhi Target | Delhi Qty |
|---|---|---|---|---|---|
| Foods | CAT-FOOD | 40% | ₹320 | ₹2,00,000 | 625 cases |
| Beverages | CAT-BEV | 20% | ₹180 | ₹1,00,000 | 556 cases |
| Personal Care | CAT-PC | 25% | ₹450 | ₹1,25,000 | 278 cases |
| Home Care | CAT-HC | 15% | ₹280 | ₹75,000 | 268 cases |

### 9.3 Seed Achievement Values
The script pre-populates **35% achievement** for all targets to simulate a mid-month state:

| Target Type | Delhi Target | Pre-seeded Achievement | % |
|---|---|---|---|
| Revenue | ₹5,00,000 | ₹1,75,000 | 35% |
| Collection | ₹4,50,000 | ₹1,40,000 | 31% |
| Volume | 2,000 | 700 | 35% |
| New Outlets | 10 | 3 | 30% |

### 9.4 Allocate Targets via Target Allocation Tab
To distribute from NSM → RSM → ASM → TSE:

1. Go to **Target Allocation tab**
2. Select current period and NSM user (Rajesh Kapoor)
3. Set NSM targets:

| Criteria | NSM Target |
|---|---|
| Revenue | ₹31,80,000 (sum of all territories) |
| Collection | ₹28,62,000 |

4. Click **Distribute** to split across RSMs:

| Criteria | RSM West (Suresh Menon) | RSM North (Priya Sharma) |
|---|---|---|
| Revenue | ₹16,80,000 | ₹15,00,000 |
| Collection | ₹15,12,000 | ₹13,50,000 |

5. Continue distributing down:
- RSM West → ASM Mumbai (Amit Patel: ₹7,50,000) + ASM Bangalore (Deepa Nair: ₹7,50,000)
- RSM North → ASM Delhi (Vikram Singh: ₹5,00,000) + ASM Chennai (Kavitha Rajan: ₹3,50,000)
- ASM Delhi → TSE Rahul (₹2,50,000) + TSE Sneha (₹2,50,000)

---

## Step 10: Run Achievement Calculation

### 10.1 Run Achievement Batch
In Developer Console:
```apex
// Run achievement calculation for all active criteria
Database.executeBatch(new TAM_Achievement_Batch(), 50);
```

### 10.2 Verify Achievements
Go to **Target Allocation tab** and select TSE Rahul Verma:

Using the orders created in Step 7 (ORD-001 through ORD-008):

| Criteria | Target | Actual (from orders) | Achievement % |
|---|---|---|---|
| Revenue | ₹2,50,000 | ₹1,75,000 + new orders | Recalculated |
| Collection | ₹2,25,000 | ~₹40,668 from Step 7.6 | ~18% |
| Volume | 1,000 | 8 orders created | 0.8% |
| Coverage | — | 17+ visits (seed) + new | — |

> **Note:** The seed data pre-populates 35% achievement. Your manually created orders ADD to these values. After running the batch, totals will be higher.

Or check in **KPI Dashboard** → My KPIs view.

### 10.3 How Achievement Calculation Works
```
1. TAM_Achievement_Batch queries all Target_Actual__c for active periods
2. For each criteria:
   a. Reads Object__c, Field__c, Operator__c, Date_Field__c, User_Field__c
   b. Builds dynamic SOQL: SELECT User_Field, SUM(Field) FROM Object WHERE date range AND filters
   c. Executes query, gets actual values per user
   d. Updates Target_Actual__c.Achievement_Value__c
3. TAM_Rollup_Service aggregates child achievements to parent (TSE→ASM→RSM→NSM)
```

### 10.4 Sample Achievement Actuals (from 14_target_criteria_and_actuals.apex)
The seed script also creates sample Target_Actual__c records for the current period:

| Criteria | Target Value | Achievement Value | Achievement % |
|---|---|---|---|
| Revenue | ₹5,00,000 | ₹4,60,000 | 92% |
| Collection | ₹3,00,000 | ₹2,64,000 | 88% |
| Volume | 200 units | 210 units | 105% |
| Coverage | 150 visits | 112 visits | 75% |
| Focus Brand | ₹1,00,000 | ₹95,000 | 95% |
| Outlet Expansion | 20 outlets | 22 outlets | 110% |

---

## Step 11: Configure Incentive Slabs

### 11.1 Verify Slabs (from 13_incentive_slabs.apex)
Go to **Incentive Slab Manager tab**. The seed script creates **80+ slabs** across all 4 FSCRM profiles:

#### 1. Universal Slabs (fallback — no criteria/profile — 5 slabs):
| Slab Name | Range | Payout Type | Value | Multiplier |
|---|---|---|---|---|
| Universal — Below Threshold | 0% – 89.99% | Fixed Amount | ₹0 | 0 |
| Universal — Base | 90% – 94.99% | Percentage | 3% | 1.0 |
| Universal — Standard | 95% – 99.99% | Percentage | 8% | 1.0 |
| Universal — Achiever | 100% – 109.99% | Percentage | 15% | 1.0 |
| Universal — Super Achiever | 110%+ | Percentage | 15% | 1.3 |

#### 2. Revenue Slabs — Salary-Based by Profile (4 profiles × 5 ranges = 20 slabs):
| Profile | Below 90% | 90-95% | 95-100% | 100-110% | 110%+ |
|---|---|---|---|---|---|
| FSCRM_TSE (₹30,000) | 0% | 4.5% | 10% | 17.75% | 20% |
| FSCRM_ASM (₹50,000) | 0% | 3.75% | 8.25% | 14.5% | 17% |
| FSCRM_RSM (₹80,000) | 0% | 3% | 7% | 12% | 15% |
| FSCRM_NSM (₹1,20,000) | 0% | 2.5% | 5.5% | 10% | 12.5% |

#### 3. Collection Slabs (Fixed amounts — 4 slabs, all profiles):
| Range | Payout Type | Value | Multiplier |
|---|---|---|---|
| Below 70% | Fixed Amount | ₹0 | 0 |
| 70% – 89.99% | Fixed Amount | ₹1,000 | 1.0 |
| 90% – 99.99% | Fixed Amount | ₹2,500 | 1.0 |
| 100%+ | Fixed Amount | ₹5,000 | 1.0 |

#### 4. Volume Slabs (Fixed amounts with multiplier — 3 slabs):
| Range | Payout Type | Value | Multiplier |
|---|---|---|---|
| Below 80% | Fixed Amount | ₹0 | 0 |
| 80% – 99.99% | Fixed Amount | ₹1,500 | 1.0 |
| 100%+ | Fixed Amount | ₹3,000 | 1.5 |

#### 5. S&D Parameter Slabs (5 criteria × 2 profiles × 4 ranges = 40 slabs):
Criteria: Focus Brand, Outlet Expansion, S&D, Visibility, New Outlets

| Profile | Below 90% | 90-95% | 95-100% | 100%+ |
|---|---|---|---|---|
| FSCRM_TSE | 0% | 4.5% salary | 10% salary | 17.75% salary |
| FSCRM_ASM | 0% | 3.75% salary | 8.25% salary | 14.5% salary |

#### 6. Territory-Specific Slabs (Delhi premium — 2 slabs):
| Slab | Profile | Territory | Range | Payout |
|---|---|---|---|---|
| Revenue Delhi TSE — 100-110% | FSCRM_TSE | Delhi NCR | 100-110% | 20% salary |
| Revenue Delhi TSE — 110%+ | FSCRM_TSE | Delhi NCR | 110%+ | 22.5% salary |

### 11.2 Slab Matching Priority
The incentive engine matches slabs in this order (most specific first):
```
1. Criteria + Profile + Territory  (e.g., Revenue + FSCRM_TSE + Delhi)
2. Criteria + Profile              (e.g., Revenue + FSCRM_TSE)
3. Criteria only                   (e.g., Collection — no profile)
4. Universal                       (fallback for all)
```

**Example:** TSE Rahul Verma achieves Revenue = 105% in Delhi:
- Engine first checks: Revenue + FSCRM_TSE + Delhi → **Matches** "Revenue Delhi TSE 100-110%" at **20%**
- This overrides the standard Revenue + FSCRM_TSE slab which would give 17.75%
- Delhi premium = 20% vs 17.75% = **2.25% extra incentive**

---

## Step 12: Calculate Incentives

### 12.1 Run Incentive Calculation
Go to **Incentive Dashboard tab** → Select current period → Click **Run Calculation**

Or in Developer Console:
```apex
// Get current monthly period
Target_Period__c period = [
    SELECT Id FROM Target_Period__c
    WHERE Is_Default__c = true AND Is_Active__c = true LIMIT 1
];
Database.executeBatch(new TAM_IncentiveCalculation_Batch(period.Id), 50);
```

### 12.2 Worked Example — TSE Rahul Verma (Delhi)

**Profile:** FSCRM_TSE | **Gross Salary:** ₹30,000/month | **Territory:** Delhi NCR

Using the sample achievement actuals from the seed data:

| Criteria | Weight | Target | Actual | Ach% | Slab Matched | Payout Calculation |
|---|---|---|---|---|---|---|
| Revenue | 60% | ₹5,00,000 | ₹4,60,000 | 92% | Revenue TSE 90-95% (4.5%) | ₹30,000 × 4.5% × 1.0 × 60% = **₹810** |
| Collection | 10% | ₹3,00,000 | ₹2,64,000 | 88% | Collection 70-90% (₹1,000) | ₹1,000 × 1.0 × 10% = **₹100** |
| Volume | 20% | 200 | 210 | 105% | Volume 100%+ (₹3,000 × 1.5) | ₹4,500 × 20% = **₹900** |
| Focus Brand | 15% | ₹1,00,000 | ₹95,000 | 95% | Revenue TSE 95-100% (10%) | ₹30,000 × 10% × 1.0 × 15% = **₹450** |
| Outlet Expansion | 15% | 20 | 22 | 110% | TSE 100%+ (17.75%) | ₹30,000 × 17.75% × 1.0 × 15% = **₹799** |
| | | | | | **Total Monthly** | **₹3,059** |

**PBIS Payout Formula:** `Gross Salary × Slab% × Multiplier × KPI Weight`

**Prerequisite Check:**
- Revenue = 92% (≥ 90%) → Focus Brand and Outlet Expansion **qualify** ✓
- If Revenue was 85% → Focus Brand and Outlet Expansion payout = **₹0** (prerequisite not met)

### 12.3 Worked Example — TSE Rahul with Delhi Premium (105% Revenue)

If Revenue achievement is boosted to 105%:

| Criteria | Ach% | Standard Slab | Delhi Premium Slab | Payout |
|---|---|---|---|---|
| Revenue | 105% | TSE 100-110%: 17.75% | **Delhi TSE 100-110%: 20%** | ₹30,000 × 20% × 1.0 × 60% = **₹3,600** |

Standard payout would be: ₹30,000 × 17.75% × 1.0 × 60% = ₹3,195
Delhi premium payout: **₹3,600** (+₹405 extra)

### 12.4 Worked Example — ASM Vikram Singh (Delhi)

**Profile:** FSCRM_ASM | **Gross Salary:** ₹50,000/month

| Criteria | Weight | Target | Actual | Ach% | Slab | Payout |
|---|---|---|---|---|---|---|
| Revenue | 60% | ₹5,00,000 | ₹4,60,000 | 92% | ASM 90-95% (3.75%) | ₹50,000 × 3.75% × 60% = **₹1,125** |
| Collection | 10% | ₹4,50,000 | ₹4,05,000 | 90% | 90-100% (₹2,500) | ₹2,500 × 10% = **₹250** |
| Volume | 20% | 2,000 | 1,800 | 90% | 80-100% (₹1,500) | ₹1,500 × 20% = **₹300** |
| | | | | | **Total** | **₹1,675** |

### 12.5 Review in Dashboard
1. **Incentive Dashboard** → Shows all calculated incentives per employee
2. Filter by: Period, Criteria, Profile, Territory
3. Click a row → See full calculation breakdown:
   - Target Value → Achievement Value → Achievement %
   - Slab Matched (name, range, payout type)
   - Multiplier applied → Final Payout Amount
4. **Submit for Approval** → **Approve** → **Mark as Paid**

---

## Step 13: Verify in KPI Dashboard

### 13.1 Self View (as TSE — Rahul Verma)
Login as TSE user → **KPI Dashboard** → "My KPIs":

Expected view with seed + manual data:
| KPI Card | Target | Actual | % | Color |
|---|---|---|---|---|
| Revenue | ₹2,50,000 | ₹1,75,000+ | ~70%+ | Red/Amber |
| Collection | ₹2,25,000 | ~₹40,668 | ~18% | Red |
| Volume | 1,000 | 700+ | ~70%+ | Amber |
| New Outlets | 5 | 3 | 60% | Red |

- KPI cards with progress rings per criteria
- Achievement % with color coding (green ≥100%, amber 80-99%, red <80%)
- Total incentive earned at bottom

### 13.2 Team View (as ASM — Vikram Singh)
Login as ASM → **KPI Dashboard** → "Team":
- Aggregated stats across subordinates (Rahul Verma + Sneha Gupta)
- Per-user breakdown table with target, actual, %, incentive
- Performance trend chart (last 6 months)

### 13.3 Organization View (as NSM — Rajesh Kapoor)
Login as NSM → **KPI Dashboard** → "Organization":
- Full hierarchy aggregation (2 RSMs → 4 ASMs → 8 TSEs)
- All users with their performance
- Total incentive pool (sum of all calculated incentives)

---

## Step 14: Achievement Dashboard

Go to **Achievement Dashboard tab**:
- **Dynamic KPI cards**: One card per active criteria (Revenue, Collection, Volume, Coverage, Focus Brand, Outlet Expansion)
- **Monthly trend chart**: Chart.js bar chart showing actual vs target for last 6 months
- **KPI distribution doughnut**: Breakdown of achievement by criteria weight
- **Team performance table**: All team members with target, actual, %
- **Top performers leaderboard**: Top 20 by achievement %

---

## Step 15: Generate Reports

### 15.1 Order Performance Report
- **Object:** Sales_Order__c
- **Columns:** Order Date, Account, Salesperson, Total Net Amount, Status, Must_Sell_Compliance__c
- **Filter:** Status = 'Approved' OR 'Delivered', Current Month
- **Group By:** Salesperson → Territory
- **Summary:** SUM(Total_Net_Amount__c), COUNT(Id)
- **Expected:** 12+ seed orders + 8 manual orders = 20+ rows

### 15.2 Target vs Achievement Report
- **Object:** Target_Actual__c
- **Columns:** User, Criteria, Target Value, Achievement Value, Achievement %
- **Filter:** Current Period, Active Criteria
- **Group By:** User → Criteria
- **Expected:** 6 criteria × number of users with targets

### 15.3 Incentive Payout Report
- **Object:** Incentive__c
- **Columns:** Salesperson, Profile, Criteria, Achievement %, Slab Name, Calculated Amount, Status
- **Filter:** Current Period
- **Group By:** Salesperson
- **Summary:** SUM(Calculated_Amount__c)

**Expected sample output from Step 12 calculations:**
| Salesperson | Profile | Revenue Inc | Collection Inc | Volume Inc | Total |
|---|---|---|---|---|---|
| Rahul Verma | TSE | ₹810 | ₹100 | ₹900 | ₹3,059 |
| Vikram Singh | ASM | ₹1,125 | ₹250 | ₹300 | ₹1,675 |

### 15.4 Scheme Performance Report
- **Object:** Sales_Order__c + Order_Line_Item__c
- **Columns:** Scheme Name, Orders Applied, Total Discount Given, Free Qty Issued, Budget Used
- **Filter:** Current Month, Scheme_Applied__c != null
- **Group By:** Scheme__c

### 15.5 Must-Sell Compliance Report
- **Object:** Sales_Order__c
- **Columns:** Account, Salesperson, Must_Sell_Compliance__c, Total Items
- **Filter:** Current Month
- **Group By:** Salesperson
- **Summary:** AVG(Must_Sell_Compliance__c)

### 15.6 Collection Outstanding Report
- **Object:** Sales_Order__c + Collection__c
- **Columns:** Account, Order Total, Collected Amount, Outstanding
- **Filter:** Status = 'Delivered', Collection partial
- **Cross-reference:** Total order value vs total collected per account

### 15.7 Leave Balance Report
- **Object:** Leave_Balance__c
- **Columns:** Employee, Leave Type, Entitled, Accrued, Used, Pending, Available
- **Filter:** Current Year
- **Group By:** Employee

### 15.8 Dashboard Components
Create a Salesforce Dashboard with:
1. **Revenue Target vs Actual** (Bar Chart) — per territory
2. **Top 10 Performers** (Horizontal Bar) — by achievement %
3. **Incentive Status Distribution** (Donut) — Pending/Approved/Paid
4. **Team Achievement Heat Map** (Table) — color-coded by %
5. **Scheme ROI Summary** (Table) — discount given vs revenue generated
6. **Must-Sell Compliance Trend** (Line) — daily compliance %
7. **Collection Efficiency** (Gauge) — collected vs outstanding

---

## Step 16: Dynamic KPI Dashboard — Metric Registry (Sprint 1)

The Dynamic KPI Dashboard is driven by reusable **KPI Metric** definitions.
Each metric declares how to aggregate data from a source object. Admins can
create/edit metrics from the **KPI Metrics tab** without any code changes.

### 16.1 Verify the KPI Metric Object
Go to **Setup → Object Manager → KPI Metric** (or open the **KPI Metrics** tab
from the app launcher). Verify these 15 fields are present:

| Field | Type | Purpose |
|---|---|---|
| Metric Key | Text (unique) | Code identifier (e.g., `revenue_total`) |
| Label | Text | Display name on dashboard |
| Description | Long Text Area | What the metric measures |
| Source Object | Text | API name of source object |
| Aggregation | Picklist | SUM / COUNT / AVG / MIN / MAX |
| Aggregate Field | Text | Field to aggregate (optional for COUNT) |
| Date Field | Text | Field used for date range filtering |
| User Field | Text | Field holding owner User Id |
| Default Filter | Long Text Area | Always-applied SOQL WHERE snippet |
| Format | Picklist | Currency / Number / Percent / Duration |
| Icon | Text | SLDS icon name |
| Color | Text | Hex accent color |
| Category | Picklist | Sales / Visits / Collections / Outlets / Schemes / Inventory / Custom |
| Allow Forecast | Checkbox | Eligible for the forecast widget |
| Is Active | Checkbox | Hide from picker when off |
| Sort Order | Number | Display order within category |

### 16.2 Verify Seed Metrics (from 18_kpi_metrics.apex)
Open the **KPI Metrics** tab → **All KPI Metrics** list view. You should see 15 active records:

**Sales (5):**
| Metric Key | Label | Aggregation | Source | Format |
|---|---|---|---|---|
| `revenue_total` | Total Revenue | SUM of Total_Net_Amount__c | Sales_Order__c | Currency |
| `order_count` | Order Count | COUNT | Sales_Order__c | Number |
| `avg_order_value` | Average Order Value | AVG of Total_Net_Amount__c | Sales_Order__c | Currency |
| `discount_given` | Total Discount Given | SUM of Total_Discount__c | Sales_Order__c | Currency |
| `max_order_value` | Largest Single Order | MAX of Total_Net_Amount__c | Sales_Order__c | Currency |

**Visits (4):**
| Metric Key | Label | Aggregation | Source | Format |
|---|---|---|---|---|
| `visit_count` | Total Visits | COUNT | Visit__c | Number |
| `productive_visit_count` | Productive Visits | COUNT | Visit__c | Number |
| `avg_visit_duration` | Avg Visit Duration | AVG of Duration_Minutes__c | Visit__c | Duration |
| `skipped_visit_count` | Skipped Visits | COUNT | Visit__c | Number |

**Collections (3):**
| Metric Key | Label | Aggregation | Source | Format |
|---|---|---|---|---|
| `collection_total` | Total Collections | SUM of Amount__c | Collection__c | Currency |
| `collection_count` | Collection Transactions | COUNT | Collection__c | Number |
| `avg_collection` | Avg Collection Amount | AVG of Amount__c | Collection__c | Currency |

**Outlets (2):**
| Metric Key | Label | Aggregation | Source | Format |
|---|---|---|---|---|
| `new_outlets` | New Outlets Added | COUNT | Account | Number |
| `active_outlets` | Active Outlets | COUNT | Account | Number |

**Schemes (1):**
| Metric Key | Label | Aggregation | Source | Format |
|---|---|---|---|---|
| `scheme_discount` | Scheme Discount Given | SUM of Scheme_Discount__c | Sales_Order__c | Currency |

### 16.3 Create a Custom Metric (Admin Walkthrough)

Let's create a "Must-Sell Compliance Rate" metric from scratch:

1. Go to **KPI Metrics** tab → Click **New**
2. Fill in the form:
   - **KPI Metric Name**: `Must-Sell Compliance`
   - **Metric Key**: `must_sell_compliance`
   - **Label**: `Must-Sell Compliance %`
   - **Description**: `Average must-sell product compliance across all orders.`
   - **Source Object**: `Sales_Order__c`
   - **Aggregation**: `AVG`
   - **Aggregate Field**: `Must_Sell_Compliance__c`
   - **Date Field**: `Order_Date__c`
   - **User Field**: `Salesperson__c`
   - **Default Filter**: `Status__c IN ('Approved','Delivered')`
   - **Format**: `Percent`
   - **Icon**: `utility:check`
   - **Color**: `#2e844a`
   - **Category**: `Sales`
   - **Allow Forecast**: unchecked
   - **Is Active**: checked
   - **Sort Order**: `6`
3. Click **Save**

Once saved, this metric is **immediately available** to the Dynamic KPI Dashboard (Sprint 3+) via `DKD_MetricRegistry.getMetric('must_sell_compliance')`.

### 16.4 Test the Apex Registry (Developer Console)

```apex
// List all active metrics
List<KPI_Metric__c> all = DKD_MetricRegistry.getAllMetrics();
System.debug('Active metrics: ' + all.size());

// Fetch a specific metric by key
KPI_Metric__c rev = DKD_MetricRegistry.getMetric('revenue_total');
System.debug('Revenue metric: ' + rev.Label__c + ' (' + rev.Aggregation__c + ')');

// Get catalog for LWC picker
List<Map<String, Object>> catalog = DKD_MetricRegistry.getCatalog();
System.debug('Catalog entries: ' + catalog.size());

// Filter by category
List<Map<String, Object>> sales = DKD_MetricRegistry.getMetricsByCategory('Sales');
System.debug('Sales metrics: ' + sales.size());

// List distinct categories
System.debug('Categories: ' + DKD_MetricRegistry.getCategories());

// Validate a metric before saving (admin use)
KPI_Metric__c test = new KPI_Metric__c(
    Metric_Key__c = 'test',
    Label__c = 'Test',
    Source_Object__c = 'Sales_Order__c',
    Aggregation__c = 'SUM',
    Aggregate_Field__c = 'Total_Net_Amount__c',
    Date_Field__c = 'Order_Date__c'
);
List<String> errors = DKD_MetricRegistry.validateMetric(test);
System.debug('Validation errors: ' + errors);  // Should be empty
```

### 16.5 What's Next (Sprint 3+)
- **Sprint 3**: `dynamicKpiDashboard` LWC shell with filter panel
- **Sprint 4**: KPI card and chart widgets
- **Sprint 5**: Forecast engine and forecast widget
- **Sprint 6**: Saved dashboard views (Dashboard_View__c)

---

## Step 17: Dynamic KPI Dashboard — Query Engine (Sprint 2)

`DKD_QueryEngine_Service` takes any metric definition from Step 16 and returns
aggregated data based on filters, date range, grouping, and user scope. It is
the bridge between metric metadata and live dashboard values.

### 17.1 Public API

| Method | Returns | Purpose |
|---|---|---|
| `queryMetric(key, filtersJson, groupBy, dateFrom, dateTo, userScope)` | `List<Map<String,Object>>` | Single metric with optional grouping. Used for KPI cards and charts. |
| `queryMultipleMetrics(keys, filtersJson, dateFrom, dateTo, userScope)` | `Map<String,Decimal>` | Bulk query for KPI card grids (1 filter → N cards). |
| `queryTimeSeries(key, filtersJson, dateFrom, dateTo, interval, userScope)` | `List<Map<String,Object>>` | Time-bucketed series for trend charts and forecasts. |

**User Scopes:**
- `self` — Only the current user's records (default)
- `team` — Current user + all subordinates via User.ManagerId hierarchy
- `org` — No user filter (all records)

**Time Intervals (for `queryTimeSeries`):** `DAY`, `WEEK`, `MONTH`, `QUARTER`, `YEAR`

### 17.2 How the WHERE Clause is Built

For each query, the engine combines four filter sources into one SOQL WHERE clause:

```
WHERE
  (Date Field >= dateFrom AND Date Field <= dateTo)    ← Date range
  AND (Default Filter from KPI_Metric__c)               ← Metric-level filter
  AND (User-provided filters via TAM_FilterEngine)      ← Dashboard filter panel
  AND (User Scope clause via TAM_RoleHierarchy)         ← self/team/org
```

### 17.3 Test in Developer Console

First make sure you have orders in the current period (run `seed_transactional_data.apex` or create some).

```apex
// ── Test 1: Scalar KPI card value ──
List<Map<String, Object>> result = DKD_QueryEngine_Service.queryMetric(
    'revenue_total',
    null,                          // no additional filters
    null,                          // no grouping
    Date.today().toStartOfMonth(),
    Date.today(),
    'self'
);
System.debug('Revenue this month: ' + result[0].get('value'));

// ── Test 2: Multi-metric for KPI grid ──
Map<String, Decimal> kpis = DKD_QueryEngine_Service.queryMultipleMetrics(
    new List<String>{ 'revenue_total', 'order_count', 'avg_order_value' },
    null,
    Date.today().toStartOfMonth(),
    Date.today(),
    'self'
);
System.debug('Revenue: ' + kpis.get('revenue_total'));
System.debug('Orders:  ' + kpis.get('order_count'));
System.debug('AOV:     ' + kpis.get('avg_order_value'));

// ── Test 3: Grouped result (for bar chart) ──
List<Map<String, Object>> byStatus = DKD_QueryEngine_Service.queryMetric(
    'order_count',
    null,
    'Status__c',                   // group by status
    Date.today().addMonths(-3),
    Date.today(),
    'org'
);
for (Map<String, Object> row : byStatus) {
    System.debug(row.get('groupKey') + ': ' + row.get('value'));
}

// ── Test 4: Time series (for trend chart) ──
List<Map<String, Object>> trend = DKD_QueryEngine_Service.queryTimeSeries(
    'revenue_total',
    null,
    Date.today().addMonths(-6),
    Date.today(),
    'MONTH',
    'team'
);
for (Map<String, Object> row : trend) {
    System.debug(row.get('label') + ' (' + row.get('period') + '): ' + row.get('value'));
}

// ── Test 5: With additional filter (only high-value orders) ──
String filters = '{"filters":[{"id":1,"field":"Total_Net_Amount__c","operator":">","value":5000,"type":"Number"}]}';
List<Map<String, Object>> highValue = DKD_QueryEngine_Service.queryMetric(
    'revenue_total', filters, null,
    Date.today().addMonths(-1), Date.today(), 'self'
);
System.debug('High-value revenue: ' + highValue[0].get('value'));
```

### 17.4 Result Format Reference

**Scalar result (no `groupBy`):**
```json
[
  { "label": "Total Revenue", "value": 248500, "count": 42, "groupKey": null }
]
```

**Grouped result (with `groupBy`):**
```json
[
  { "label": "Approved",  "value": 180000, "count": 28, "groupKey": "Approved"  },
  { "label": "Delivered", "value": 68500,  "count": 14, "groupKey": "Delivered" }
]
```

**Time series:**
```json
[
  { "period": 1, "label": "Jan", "value": 45000, "count": 12 },
  { "period": 2, "label": "Feb", "value": 62000, "count": 15 },
  { "period": 3, "label": "Mar", "value": 78000, "count": 18 }
]
```

### 17.5 Error Handling

The engine throws `DKD_QueryEngine_Service.DKD_QueryException` for:
- Unknown metric key
- Unsupported aggregation
- SUM/AVG/MIN/MAX without an Aggregate Field
- Invalid field names (SOQL injection protection — only `[A-Za-z0-9_.]` allowed)
- Invalid time interval
- SOQL query failures (with underlying error and generated SOQL in the message)

`queryMultipleMetrics` is **fail-soft** — if one metric errors, it returns `0` for that key and continues with the rest. This keeps a bad metric from breaking the entire dashboard.

### 17.6 What's Next (Sprint 4+)
- **Sprint 4**: Chart.js-powered widgets (line/bar/pie/doughnut)
- **Sprint 5**: `DKD_Forecast_Service` for linear regression on time series
- **Sprint 6**: `Dashboard_View__c` for saving custom dashboard layouts

---

## Step 18: Dynamic KPI Dashboard — UI & Permissions (Sprint 3)

Sprint 3 delivers the first **visible** piece of the Dynamic KPI Dashboard: a
working LWC with filter panel, KPI cards, and a simple breakdown chart, wired
up to the query engine from Sprint 2 and available from the home page.

### 18.1 Component Structure

| File | Purpose |
|---|---|
| `lwc/dynamicKpiDashboard/dynamicKpiDashboard.js` | State, filter handling, Apex calls, KPI card builder |
| `lwc/dynamicKpiDashboard/dynamicKpiDashboard.html` | Header, filter panel, KPI grid, chart widget |
| `lwc/dynamicKpiDashboard/dynamicKpiDashboard.css` | Responsive layout with gradient header and card styling |
| `lwc/dynamicKpiDashboard/dynamicKpiDashboard.js-meta.xml` | Exposed for `lightning__Tab`, `lightning__AppPage`, `lightning__HomePage` |
| `classes/DKD_Dashboard_Controller.cls` | Init data, KPI values, metric data, time series, previous period |
| `tabs/Dynamic_KPI_Dashboard.tab-meta.xml` | Custom tab that hosts the LWC |

### 18.2 Features Delivered in Sprint 3

**Filter Panel:**
- **User Scope**: Self / My Team / Organization (auto-default to Team if manager)
- **Period presets**: Today / Yesterday / This Week / MTD / Last Month / QTD / YTD / Last 30 / Last 90 / Custom
- **Custom date range** with from/to date pickers (when preset = Custom)
- **Category filter**: Sales / Visits / Collections / Outlets / Schemes / Custom
- **Metric picker**: Click-to-toggle multi-select list, filtered by category
- **Apply / Reset** buttons

**KPI Card Grid:**
- One card per selected metric
- Shows current value (formatted by metric type: Currency/Number/Percent/Duration)
- **vs Previous Period** comparison with up/down/flat trend indicator and % change
- Color-coded left border using the metric's configured Color__c
- Icon from metric's Icon__c

**Breakdown Chart:**
- Horizontal bar chart showing selected metric grouped by `Status__c`
- Metric picker to switch the charted metric
- Bars scaled to max value for easy comparison

**Active Filter Chips:**
- Visual chips at the top showing Scope, Period, and Category in effect

**Responsive Layout:**
- 280px fixed filter panel + flex canvas on desktop
- Collapses to single column on mobile (<900px)
- KPI grid adapts from 4+ columns → 2 → 1

### 18.3 Access Points

The Dynamic KPI Dashboard is available from **three** entry points:

| Entry Point | Location | Visibility |
|---|---|---|
| 1. **App Tab** | `Field Sales CRM` → `Dynamic KPI Dashboard` tab | All FSCRM profiles |
| 2. **Home Page Quick Action** | Home Page → Dashboard tab → Quick Actions → "KPI Dashboard" card | All FSCRM profiles |
| 3. **Home Page Analytics Section** | Home Page → Dashboard tab → "Analytics & Insights" section | All FSCRM profiles |
| 4. **Home Page Admin Section** | Home Page → Admin tab → "Administration & Configuration" | Admins only |

**KPI Metrics Registry** (for admins to create/edit metric definitions):
- App Launcher → "KPI Metrics" tab
- Home Page → Admin tab → "KPI Metrics Registry" card

### 18.4 Permissions Matrix

Permissions applied via profile updates in Sprint 3:

| Profile | DKD Apex Classes | KPI_Metric__c | Dynamic_KPI_Dashboard tab | KPI_Metric__c tab |
|---|---|---|---|---|
| **FSCRM_TSE** | Enabled | Read | DefaultOn | DefaultOff |
| **FSCRM_ASM** | Enabled | Read/Create/Edit | DefaultOn | DefaultOn |
| **FSCRM_RSM** | Enabled | Read/Create/Edit | DefaultOn | DefaultOn |
| **FSCRM_NSM** | Enabled | Full CRUD + Modify All | DefaultOn | DefaultOn |
| **FSCRM_Admin** (perm set) | Enabled | Full CRUD + Modify All | Visible | Visible |

**Apex classes granted:**
- `DKD_MetricRegistry`
- `DKD_QueryEngine_Service`
- `DKD_Dashboard_Controller`

### 18.5 Walkthrough — First Time User

1. **Login as a TSE** (e.g., Rahul Verma / FSCRM_TSE)
2. Go to **App Launcher** → **Field Sales CRM** app
3. Click the **Dynamic KPI Dashboard** tab (or from Home → Quick Actions → "KPI Dashboard")
4. On first load, the dashboard auto-selects:
   - **User Scope**: Self (or Team if you have subordinates)
   - **Period**: Month to Date
   - **Metrics**: First 4 Sales category metrics (Total Revenue, Order Count, Avg Order Value, Discount Given)
5. **KPI Cards** appear showing current values with vs-previous-period comparisons
6. **Breakdown chart** appears below showing Revenue grouped by Order Status

### 18.6 Walkthrough — Changing Filters

1. Click **Filters** in the header (if panel is collapsed)
2. Change **User Scope** to `My Team` — the dashboard reloads with aggregated team data
3. Change **Period** to `Last 30 Days` — dates auto-populate
4. Change **Category** to `Visits` — metric list filters to only Visit metrics
5. Click a metric row (e.g., `Total Visits`) to toggle it on/off — the check icon highlights
6. Click **Apply Filters** — KPI cards refresh with the new selection
7. Click **Reset** to return to defaults

### 18.7 Walkthrough — Admin Creates a New Metric

1. **Login as NSM** (Rajesh Kapoor / FSCRM_NSM) or use the Admin permission set
2. Go to **Home Page → Admin tab → "KPI Metrics Registry"** card
3. Click **New**, fill in:
   - Name: `Outstanding Collections`
   - Metric Key: `outstanding_collections`
   - Label: `Outstanding Collections`
   - Source Object: `Sales_Order__c`
   - Aggregation: `SUM`
   - Aggregate Field: `Total_Net_Amount__c`
   - Date Field: `Order_Date__c`
   - User Field: `Salesperson__c`
   - Default Filter: `Status__c = 'Delivered' AND Total_Amount__c > Total_Collected__c`
   - Format: `Currency`
   - Icon: `utility:moneybag`
   - Color: `#dd7a01`
   - Category: `Collections`
   - Is Active: checked
4. **Save**
5. Go to the **Dynamic KPI Dashboard** tab
6. In the filter panel, change Category to **Collections**
7. Click on **Outstanding Collections** in the metric list
8. Click **Apply Filters**
9. The new KPI card appears — zero code deployment needed!

### 18.8 Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| "Failed to load dashboard: Method not callable" | Apex class permission missing | Enable DKD_* classes on the user's profile |
| Empty KPI cards | No data in selected period/scope | Widen the date range or switch to Org scope |
| "Metric not found" error | Metric is inactive or the key doesn't exist | Check KPI_Metric__c.Is_Active__c |
| Breakdown chart empty | Grouping field `Status__c` doesn't exist on the source object | Check that the metric's source object has a Status field |
| Tab not visible in app | Tab visibility `DefaultOff` or not in app's tabs list | Verify profile tabVisibilities and Field_Sales_CRM.app-meta.xml |

---

## Appendix A: Data Flow Diagram

```
Products → Price List (8-level priority) → Order Line Items
                                                ↓
UOM_Conversion__c → Base Quantity calculation    ↓
                                                ↓
Schemes → Scheme Engine → Discounts/Free Goods applied
                                                ↓
Must Sell Config → Compliance Check → Order validated
                                                ↓
Visits → Orders → Sales_Order__c (Submitted → Approved → Delivered)
                                                ↓
              ┌─────────────────────────────────┤
              ↓                                 ↓
Target_Criteria__c                    Collection__c (payments)
              ↓                                 ↓
TAM_Achievement_Batch → Target_Actual__c (per user per criteria)
              ↓
TAM_Rollup_Service → Aggregates TSE→ASM→RSM→NSM
              ↓
Incentive_Slab__c (priority: Criteria+Profile+Territory > Criteria+Profile > Universal)
              ↓
TAM_IncentiveCalculation_Batch → Incentive__c (per user per criteria)
              ↓
KPI Dashboard ← Incentive Dashboard → Submit → Approve → Mark as Paid
```

## Appendix B: Key Formulas

**Achievement %** = (Achievement_Value__c / Target_Value__c) × 100

**Incentive (Salary %)** = Gross Salary × (Slab Value / 100) × Multiplier × KPI Weight

**Incentive (Target %)** = Target Value × (Slab Value / 100) × Multiplier × KPI Weight

**Incentive (Fixed)** = Slab Value × Multiplier × KPI Weight

**Base Quantity** = Order Quantity × UOM Conversion Factor

**UOM Price** = Base UOM Price × Conversion Factor (displayed per selected UOM)

**Price Resolution** = First match in: Customer → Cat+Terr+Chan → Terr+Chan → Cat+Terr → Territory → Channel → Category → Base

**Available Leave** = Accrued + Carry Forward − Used − Pending

**Annual Bonus** = Average of best 3 out of 4 quarterly incentives

## Appendix C: Target Period Hierarchy (from 13_target_periods.apex)

```
FY 2025-2026 (Annual: Apr 1 – Mar 31, Cumulative)
├── Q1 FY2025 (Apr 1 – Jun 30, Cumulative)
│   ├── April (Monthly, Is_Default if current)
│   ├── May
│   └── June
├── Q2 FY2025 (Jul 1 – Sep 30)
│   ├── July
│   ├── August
│   └── September
├── Q3 FY2025 (Oct 1 – Dec 31)
│   ├── October
│   ├── November
│   └── December
└── Q4 FY2025 (Jan 1 – Mar 31)
    ├── January
    ├── February
    └── March
```

**17 periods total:** 1 Annual + 4 Quarterly + 12 Monthly
**Current month** has `Is_Default__c = true` (used by incentive batch)

## Appendix D: Complete Product Catalog (from 04_products.apex)

| # | Product | SKU | Category | MRP | Unit Price | GST | Case Size | Min Qty | Base UOM |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Crispy Masala Chips 150g | FF-SNK-001 | Snacks | ₹30 | ₹21.00 | 12% | 48 | 12 | PCS |
| 2 | Tangy Tomato Chips 150g | FF-SNK-002 | Snacks | ₹30 | ₹21.00 | 12% | 48 | 12 | PCS |
| 3 | Classic Salted Chips 75g | FF-SNK-003 | Snacks | ₹15 | ₹10.50 | 12% | 96 | 24 | PCS |
| 4 | Classic Cream Biscuits 200g | FF-BIS-001 | Biscuits | ₹25 | ₹17.50 | 18% | 60 | 12 | PCS |
| 5 | Digestive Wheat Biscuits 250g | FF-BIS-002 | Biscuits | ₹35 | ₹24.50 | 18% | 48 | 12 | PCS |
| 6 | Chocolate Cream Biscuits 150g | FF-BIS-003 | Biscuits | ₹20 | ₹14.00 | 18% | 72 | 12 | PCS |
| 7 | Instant Noodles Masala 70g | FF-NDL-001 | Noodles | ₹14 | ₹9.80 | 18% | 120 | 24 | PCS |
| 8 | Instant Noodles Chicken 70g | FF-NDL-002 | Noodles | ₹16 | ₹11.20 | 18% | 120 | 24 | PCS |
| 9 | Daily Fresh Milk 500ml | FF-DRY-001 | Dairy | ₹28 | ₹22.40 | 5% | 20 | 10 | PCS |
| 10 | Curd Cup 200g | FF-DRY-002 | Dairy | ₹20 | ₹16.00 | 5% | 24 | 12 | PCS |
| 11 | Mango Toffees 200g | FF-CNF-001 | Confectionery | ₹50 | ₹35.00 | 18% | 60 | 12 | PCS |
| 12 | Fruit Drops 100g | FF-CNF-002 | Confectionery | ₹30 | ₹21.00 | 18% | 80 | 24 | PCS |
| 13 | Fresh Mango Juice 1L | FF-JUC-001 | Juices | ₹120 | ₹84.00 | 12% | 12 | 6 | PCS |
| 14 | Mixed Fruit Juice 1L | FF-JUC-002 | Juices | ₹110 | ₹77.00 | 12% | 12 | 6 | PCS |
| 15 | Orange Juice 200ml | FF-JUC-003 | Juices | ₹25 | ₹17.50 | 12% | 36 | 12 | PCS |
| 16 | Cola Fizz 300ml | FF-SOD-001 | Soft Drinks | ₹20 | ₹14.00 | 12% | 24 | 24 | PCS |
| 17 | Lemon Soda 300ml | FF-SOD-002 | Soft Drinks | ₹20 | ₹14.00 | 12% | 24 | 24 | PCS |
| 18 | Premium Assam Tea 250g | FF-TEA-001 | Tea & Coffee | ₹180 | ₹126.00 | 5% | 24 | 6 | PCS |
| 19 | Instant Coffee 50g | FF-TEA-002 | Tea & Coffee | ₹120 | ₹84.00 | 5% | 36 | 6 | PCS |
| 20 | Coconut Hair Oil 200ml | FF-HAR-001 | Hair Care | ₹95 | ₹66.50 | 28% | 36 | 6 | PCS |
| 21 | Anti-Dandruff Shampoo 200ml | FF-HAR-002 | Hair Care | ₹175 | ₹122.50 | 28% | 24 | 6 | PCS |
| 22 | Neem Face Wash 100ml | FF-SKN-001 | Skin Care | ₹85 | ₹59.50 | 28% | 36 | 6 | PCS |
| 23 | Aloe Moisturizer 100ml | FF-SKN-002 | Skin Care | ₹120 | ₹84.00 | 28% | 36 | 6 | PCS |
| 24 | Fresh Mint Toothpaste 150g | FF-ORL-001 | Oral Care | ₹65 | ₹45.50 | 28% | 48 | 12 | PCS |
| 25 | Herbal Toothpaste 100g | FF-ORL-002 | Oral Care | ₹55 | ₹38.50 | 28% | 48 | 12 | PCS |
| 26 | Power Wash Detergent 1kg | FF-DET-001 | Detergents | ₹135 | ₹94.50 | 18% | 12 | 6 | PCS |
| 27 | Liquid Dish Wash 500ml | FF-DET-002 | Detergents | ₹89 | ₹62.30 | 18% | 24 | 6 | PCS |
| 28 | Power Wash Detergent 500g | FF-DET-003 | Detergents | ₹72 | ₹50.40 | 18% | 24 | 6 | PCS |
| 29 | Floor Cleaner Pine 500ml | FF-CLN-001 | Cleaners | ₹99 | ₹69.30 | 18% | 24 | 6 | PCS |
| 30 | Glass Cleaner 250ml | FF-CLN-002 | Cleaners | ₹65 | ₹45.50 | 18% | 36 | 6 | PCS |

## Appendix E: Account Directory (from 09_accounts.apex)

| # | Account Name | Type | Territory | Channel | Outlet Type | Class | Credit Limit |
|---|---|---|---|---|---|---|---|
| 1 | Sharma Distributors Pvt Ltd | Distributor | Delhi | GT | — | — | ₹5,00,000 |
| 2 | Patel Trading Company | Distributor | Mumbai | GT | — | — | ₹7,50,000 |
| 3 | Reddy & Sons Distribution | Distributor | Bangalore | GT | — | — | ₹4,00,000 |
| 4 | National FMCG Stockists | Super Stockist | Delhi | GT | — | — | ₹10,00,000 |
| 5 | Western Hub Stockists | Super Stockist | Mumbai | GT | — | — | ₹8,00,000 |
| 6 | Lakshmi General Store | Retailer | Delhi | GT | Grocery | A | ₹25,000 |
| 7 | Ganesh Provision Store | Retailer | Delhi | GT | General Store | B | ₹25,000 |
| 8 | Kumar Kirana | Retailer | Mumbai | GT | Grocery | A | ₹25,000 |
| 9 | Deepak Grocery | Retailer | Mumbai | GT | General Store | C | ₹25,000 |
| 10 | Gupta Mart | Retailer | Bangalore | GT | Grocery | B | ₹25,000 |
| 11 | Sri Balaji Store | Retailer | Bangalore | GT | General Store | A | ₹25,000 |
| 12 | Modern Needs Store | Retailer | Chennai | GT | Grocery | B | ₹25,000 |
| 13 | Daily Fresh Mart | Retailer | Chennai | GT | Medical | C | ₹25,000 |
| 14 | City Grocery Point | Retailer | Kolkata | GT | Grocery | A | ₹25,000 |
| 15 | Family Store Corner | Retailer | Hyderabad | GT | Hardware | B | ₹25,000 |
| 16 | Quick Shop Express | Retailer | Pune | GT | General Store | C | ₹25,000 |
| 17 | New India Provisions | Retailer | Ahmedabad | GT | Grocery | B | ₹25,000 |
| 18 | SuperMart Central Delhi | Modern Trade | Delhi | MT | — | A | ₹2,00,000 |
| 19 | HyperBazaar Mumbai | Modern Trade | Mumbai | MT | — | A | ₹3,00,000 |
| 20 | MegaStore Bengaluru | Modern Trade | Bangalore | MT | — | A | ₹2,50,000 |
