# End-to-End Test Guide: Orders → Targets → Achievements → Incentives

## Overview

This guide walks through the complete FMCG sales flow — from setting up products to calculating incentive payouts. Follow each step in order.

---

## Step 1: Prerequisites — Run Seed Scripts

Run these scripts in order via Developer Console (Execute Anonymous) or CLI:

```bash
sf apex run --file scripts/00_delete_all.apex          # Clean slate (optional)
sf apex run --file scripts/01_company_hierarchy.apex
sf apex run --file scripts/02_territory_master.apex
sf apex run --file scripts/03_product_category.apex
sf apex run --file scripts/04a_uom_master.apex         # UOM + global conversions
sf apex run --file scripts/04_products.apex
sf apex run --file scripts/04b_uom_conversions.apex    # Product-specific conversions (after products)
sf apex run --file scripts/05_batch_master.apex
sf apex run --file scripts/06_tax_configuration.apex
sf apex run --file scripts/07_price_list.apex
sf apex run --file scripts/08_warehouse.apex
sf apex run --file scripts/09_accounts.apex
sf apex run --file scripts/10_beats_and_outlets.apex
sf apex run --file scripts/11_schemes.apex
sf apex run --file scripts/11a_must_sell_config.apex    # Priority Sell configs
sf apex run --file scripts/13_employees.apex
sf apex run --file scripts/13_target_periods.apex
sf apex run --file scripts/14_target_criteria_and_actuals.apex
sf apex run --file scripts/13_incentive_slabs.apex
sf apex run --file scripts/15_test_team.apex
sf apex run --file scripts/16_leave_policies.apex
```

After running, verify record counts:
```apex
System.debug('Products: '   + [SELECT COUNT() FROM Product_Extension__c WHERE Is_Active__c = true]);   // 30
System.debug('Accounts: '   + [SELECT COUNT() FROM Account]);                                          // 20
System.debug('Territories: '+ [SELECT COUNT() FROM Territory_Master__c WHERE Is_Active__c = true]);     // 8
System.debug('Periods: '    + [SELECT COUNT() FROM Target_Period__c WHERE Is_Active__c = true]);        // 17
System.debug('Criteria: '   + [SELECT COUNT() FROM Target_Criteria__c WHERE Active__c = true]);         // 6
System.debug('UOMs: '       + [SELECT COUNT() FROM UOM__c WHERE Is_Active__c = true]);                  // 10
System.debug('UOM Conv: '   + [SELECT COUNT() FROM UOM_Conversion__c WHERE Is_Active__c = true]);       // 65+
System.debug('Must Sell: '  + [SELECT COUNT() FROM Must_Sell_Config__c WHERE Is_Active__c = true]);     // 30
System.debug('Schemes: '    + [SELECT COUNT() FROM Scheme__c WHERE Status__c = 'Active']);              // 7
System.debug('Slabs: '      + [SELECT COUNT() FROM Incentive_Slab__c WHERE Is_Active__c = true]);       // 40+
```

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

## Step 5: Create Sales Orders

### 5.1 Create a Visit
1. Go to **Visit Manager tab**
2. Start Day Attendance (check in)
3. Select an account/outlet
4. Check in to the visit

### 5.2 Create Order During Visit
1. From the visit, click **Create Order**
2. Select products from seed data:

| Product | SKU | UOM | Qty | Unit Price | Line Total |
|---|---|---|---|---|---|
| Crispy Masala Chips 150g | FF-SNK-001 | BOX | 2 | ₹21 × 48 | ₹2,016 |
| Classic Cream Biscuits 200g | FF-BIS-001 | PCS | 24 | ₹17.50 | ₹420 |
| Power Wash Detergent 1kg | FF-DET-001 | PCS | 12 | ₹95 | ₹1,140 |
| Fresh Mango Juice 1L | FF-JUC-001 | PCS | 6 | ₹55 | ₹330 |

3. Verify auto-calculations:
   - **Base Quantity**: BOX(2) × 48 = 96 PCS for Chips (product-specific conversion)
   - **Scheme Applied**: "Chips Buy 3 Get 1 Free" checks min qty 3 on Chips product
   - **Must-Sell Check**: Chips, Biscuits, Detergent are national must-sell → compliance tracked
   - **Tax**: GST auto-calculated (12% for Chips, 18% for Biscuits, 18% for Detergent)
   - **Total Net Amount**: Sum of all line totals after discount + tax

4. **Submit Order** → Status changes to "Submitted"
5. **Approve Order** (as manager) → Status = "Approved"

### 5.3 Create Multiple Orders
Create 5-10 orders across different accounts from seed data:

| Order | Account (from seed) | Salesperson (from test team) | Territory | Approx Total |
|---|---|---|---|---|
| ORD-001 | Lakshmi General Store | Rahul Kumar (TSE) | Delhi | ~₹15,000 |
| ORD-002 | Ganesh Provision Store | Anjali Reddy (TSE) | Delhi | ~₹22,000 |
| ORD-003 | Kumar Kirana | Karthik Nambiar (TSE) | Mumbai | ~₹18,000 |
| ORD-004 | Deepak Grocery | Meera Iyer (TSE) | Mumbai | ~₹31,000 |
| ORD-005 | Gupta Mart | Nikhil Rao (TSE) | Bangalore | ~₹12,500 |

---

## Step 6: Configure Target Criteria

### 6.1 Verify Target Criteria
Go to **Target Criteria Manager tab**. Ensure these exist:

| Criteria | Object | Operator | Field | Weight | Prerequisite |
|---|---|---|---|---|---|
| Revenue | Sales_Order__c | SUM | Total_Net_Amount__c | 60% | None |
| Collection | Collection__c | SUM | Amount__c | 10% | None |
| Volume | Sales_Order__c | COUNT | Id | — | None |
| Coverage | Visit__c | COUNT | Id | — | None |
| Focus Brand | Sales_Order__c | SUM | Total_Net_Amount__c | 15% | Revenue ≥ 90% |
| Outlet Expansion | Account | COUNT | Id | 15% | Revenue ≥ 90% |

### 6.2 Set Filters
- **Revenue**: Filter = `Status__c IN ('Approved', 'Delivered')`
- **Collection**: Filter = `Status__c = 'Confirmed'`
- **Coverage**: Filter = `Visit_Status__c = 'Completed' AND Is_Productive__c = true`

---

## Step 7: Set Targets via Target Allocation

### 7.1 Allocate Manager Targets
1. Go to **Target Allocation tab**
2. Select current period and the NSM user
3. Click **Add Target**
4. Set targets for each criteria:

| Criteria | NSM Target |
|---|---|
| Revenue | ₹30,00,000 |
| Collection | ₹20,00,000 |
| Volume | 500 orders |
| Coverage | 300 visits |
| Focus Brand | ₹5,00,000 |
| Outlet Expansion | 50 outlets |

### 7.2 Distribute to RSMs
1. Select NSM user → Click **Distribute**
2. Split targets across 2 RSMs:

| Criteria | RSM North | RSM South |
|---|---|---|
| Revenue | ₹15,00,000 | ₹15,00,000 |
| Collection | ₹10,00,000 | ₹10,00,000 |

### 7.3 Distribute RSM → ASMs → TSEs
Continue distributing down the hierarchy:
- RSM North → ASM Delhi (₹8,00,000) + ASM Mumbai (₹7,00,000)
- ASM Delhi → TSE Rahul (₹4,00,000) + TSE Anjali (₹4,00,000)

---

## Step 8: Run Achievement Calculation

### 8.1 Run Achievement Batch
In Developer Console:
```apex
// Run achievement calculation for all active criteria
Database.executeBatch(new TAM_Achievement_Batch(), 50);
```

### 8.2 Verify Achievements
Go to **Target Allocation tab** and select a TSE:
- Revenue target: ₹4,00,000
- Revenue actual: Sum of approved orders for that TSE
- Achievement %: auto-calculated

Or check in **KPI Dashboard** → My KPIs view.

### 8.3 How Achievement Calculation Works
```
1. TAM_Achievement_Batch queries all Target_Actual__c for active periods
2. For each criteria:
   a. Reads Object__c, Field__c, Operator__c, Date_Field__c, User_Field__c
   b. Builds dynamic SOQL: SELECT User_Field, SUM(Field) FROM Object WHERE date range AND filters
   c. Executes query, gets actual values per user
   d. Updates Target_Actual__c.Achievement_Value__c
3. TAM_Rollup_Service aggregates child achievements to parent (TSE→ASM→RSM→NSM)
```

---

## Step 9: Configure Incentive Slabs

### 9.1 Verify Slabs
Go to **Incentive Slab Manager tab**. The seed script creates slabs across all 4 FSCRM profiles:

#### Universal Slabs (fallback — no criteria/profile):
| Slab Name | Range | Payout Type | Value | Multiplier |
|---|---|---|---|---|
| Universal — Below Threshold | 0% – 89.99% | Fixed Amount | ₹0 | 0 |
| Universal — Base | 90% – 94.99% | Percentage | 3% | 1.0 |
| Universal — Standard | 95% – 99.99% | Percentage | 8% | 1.0 |
| Universal — Achiever | 100% – 109.99% | Percentage | 15% | 1.0 |
| Universal — Super Achiever | 110%+ | Percentage | 15% | 1.3 |

#### Revenue Slabs — Salary-Based by Profile:
| Profile | 90-95% | 95-100% | 100-110% | 110%+ |
|---|---|---|---|---|
| FSCRM_TSE | 4.5% | 10% | 17.75% | 20% |
| FSCRM_ASM | 3.75% | 8.25% | 14.5% | 17% |
| FSCRM_RSM | 3% | 7% | 12% | 15% |
| FSCRM_NSM | 2.5% | 5.5% | 10% | 12.5% |

#### Fixed Amount Slabs (Collection & Volume — same for all profiles):
| Criteria | 70-90% | 90-100% | 100%+ |
|---|---|---|---|
| Collection | ₹1,000 | ₹2,500 | ₹5,000 |
| Volume | — | ₹1,500 (80%+) | ₹3,000 (×1.5) |

#### Territory-Specific (Delhi premium):
| Slab | Profile | Territory | Range | Payout |
|---|---|---|---|---|
| Revenue Delhi TSE — 100-110% | FSCRM_TSE | Delhi | 100-110% | 20% salary |
| Revenue Delhi TSE — 110%+ | FSCRM_TSE | Delhi | 110%+ | 22.5% salary |

### 9.2 Slab Matching Priority
The incentive engine matches slabs in this order (most specific first):
```
1. Criteria + Profile + Territory  (e.g., Revenue + FSCRM_TSE + Delhi)
2. Criteria + Profile              (e.g., Revenue + FSCRM_TSE)
3. Criteria only                   (e.g., Collection — no profile)
4. Universal                       (fallback for all)
```

---

## Step 10: Calculate Incentives

### 10.1 Run Incentive Calculation
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

### 10.2 Calculation Example

**TSE Rahul Kumar** (Profile: FSCRM_TSE, Gross Salary: ₹30,000/month):

| Criteria | Weight | Target | Actual | % | Slab Matched | Payout Calculation |
|---|---|---|---|---|---|---|
| Revenue | 60% | ₹4,00,000 | ₹3,80,000 | 95% | Revenue TSE 95-100% (10%) | ₹30,000 × 10% × 1.0 × 60% = **₹1,800** |
| Focus Brand | 15% | ₹80,000 | ₹76,000 | 95% | Revenue TSE 95-100% (10%) | ₹30,000 × 10% × 1.0 × 15% = **₹450** |
| Outlet Expansion | 15% | 10 | 11 | 110% | Revenue TSE 110%+ (20%) | ₹30,000 × 20% × 1.0 × 15% = **₹900** |
| Collection | 10% | ₹2,80,000 | ₹2,50,000 | 89% | Below Threshold (₹0) | **₹0** |
| | | | | | **Total Monthly** | **₹3,150** |

**PBIS Payout Formula:** `Gross Salary × Slab% × Multiplier × KPI Weight`

**Prerequisite Check:**
- Revenue = 95% (≥ 90%) → Focus Brand and Outlet Expansion qualify ✓
- If Revenue was 85% → Focus Brand and Outlet Expansion would be ₹0 (prerequisite not met)

**Territory Premium Example** (if Rahul is in Delhi):
- Revenue at 105% → matches "Revenue Delhi TSE 100-110%" slab at 20% (vs standard 17.75%)
- Payout: ₹30,000 × 20% × 1.0 × 60% = ₹3,600 (vs ₹3,195 at standard rate)

### 10.3 Review in Dashboard
1. **Incentive Dashboard** → Shows all calculated incentives
2. Filter by: Period, Criteria, Profile, Territory
3. Click a row → See calculation breakdown (Target → Achievement % → Slab → Multiplier → Payout)
4. **Submit for Approval** → **Approve** → **Mark as Paid**

---

## Step 11: Verify in KPI Dashboard

### 11.1 Self View (as TSE)
Login as TSE user → **KPI Dashboard** → "My KPIs":
- KPI cards with progress rings per criteria
- Achievement % with color coding (green/amber/red)
- Total incentive earned

### 11.2 Team View (as ASM)
Login as ASM → **KPI Dashboard** → "Team":
- Aggregated stats across subordinates
- Per-user breakdown table with target, actual, %, incentive
- Performance trend chart (last 6 months)

### 11.3 Organization View (as NSM)
Login as NSM → **KPI Dashboard** → "Organization":
- Full hierarchy aggregation
- All users with their performance
- Total incentive pool

---

## Step 12: Achievement Dashboard

Go to **Achievement Dashboard tab**:
- Dynamic KPI cards (one per active criteria)
- Monthly trend chart (Chart.js bar chart — real data)
- KPI distribution doughnut chart
- Team performance table
- Top performers leaderboard (top 20 by achievement)

---

## Step 13: Generate Reports

### 13.1 Salesforce Reports
Create reports on:

**Order Performance Report:**
- Object: Sales_Order__c
- Columns: Order Date, Account, Salesperson, Total Net Amount, Status
- Filter: Status = Approved, Current Month
- Group By: Salesperson
- Summary: SUM(Total_Net_Amount__c)

**Target vs Achievement Report:**
- Object: Target_Actual__c
- Columns: User, Criteria, Target Value, Achievement Value, Achievement %
- Filter: Current Period, Active Criteria
- Group By: User → Criteria

**Incentive Payout Report:**
- Object: Incentive__c
- Columns: Salesperson, Criteria, Achievement %, Slab, Calculated Amount, Status
- Filter: Current Period
- Group By: Salesperson
- Summary: SUM(Calculated_Amount__c)

**Leave Balance Report:**
- Object: Leave_Balance__c
- Columns: Employee, Leave Type, Entitled, Accrued, Used, Pending, Available
- Filter: Current Year
- Group By: Employee

### 13.2 Dashboard Components
Create a Salesforce Dashboard with:
1. Revenue Target vs Actual (Bar Chart)
2. Top 10 Performers (Horizontal Bar)
3. Incentive Status Distribution (Donut)
4. Team Achievement Heat Map (Table)
5. Leave Balance Summary (Table)

---

## Appendix A: Data Flow Diagram

```
Products → Price List → Order Line Items
                              ↓
Schemes → Scheme Engine → Discounts applied
                              ↓
Must Sell → Compliance Check → Order validated
                              ↓
Visits → Orders → Sales_Order__c (Approved)
                              ↓
Target_Criteria__c → Achievement Batch → Target_Actual__c
                              ↓
Incentive_Slab__c → Incentive Calculation → Incentive__c
                              ↓
KPI Dashboard ← Incentive Dashboard → Approval → Payment
```

## Appendix B: Key Formulas

**Achievement %** = (Achievement_Value__c / Target_Value__c) × 100

**Incentive (Salary %)** = Gross Salary × (Slab Value / 100) × Multiplier × KPI Weight

**Incentive (Target %)** = Target Value × (Slab Value / 100) × Multiplier × KPI Weight

**Incentive (Fixed)** = Slab Value × Multiplier × KPI Weight

**Available Leave** = Accrued + Carry Forward − Used − Pending

**Annual Bonus** = Average of best 3 out of 4 quarterly incentives
