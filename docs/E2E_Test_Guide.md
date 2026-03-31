# End-to-End Test Guide: Orders → Targets → Achievements → Incentives

## Overview

This guide walks through the complete FMCG sales flow — from setting up products to calculating incentive payouts. Follow each step in order.

---

## Step 1: Prerequisites — Run Seed Scripts

Run these scripts in order via Developer Console (Execute Anonymous) or CLI:

```bash
sf apex run --file scripts/01_company_hierarchy.apex
sf apex run --file scripts/02_territory_master.apex
sf apex run --file scripts/03_product_category.apex
sf apex run --file scripts/04_products.apex
sf apex run --file scripts/05_batch_master.apex
sf apex run --file scripts/06_tax_configuration.apex
sf apex run --file scripts/07_price_list.apex
sf apex run --file scripts/08_warehouse.apex
sf apex run --file scripts/09_accounts.apex
sf apex run --file scripts/10_beats_and_outlets.apex
sf apex run --file scripts/11_schemes.apex
sf apex run --file scripts/13_employees.apex
sf apex run --file scripts/13_target_periods.apex
sf apex run --file scripts/14_target_criteria_and_actuals.apex
sf apex run --file scripts/13_incentive_slabs.apex
sf apex run --file scripts/15_test_team.apex
sf apex run --file scripts/16_leave_policies.apex
```

After running, verify:
- Products: `SELECT COUNT() FROM Product_Extension__c WHERE Is_Active__c = true`
- Accounts: `SELECT COUNT() FROM Account`
- Territories: `SELECT COUNT() FROM Territory_Master__c WHERE Is_Active__c = true`
- Periods: `SELECT COUNT() FROM Target_Period__c WHERE Is_Active__c = true`
- Criteria: `SELECT COUNT() FROM Target_Criteria__c WHERE Active__c = true`

---

## Step 2: UOM Configuration

### 2.1 Verify UOM Master
Go to **UOM tab** and verify these exist:
| UOM Code | Name | Is Base |
|---|---|---|
| PCS | Pieces | Yes |
| BOX | Box | No |
| CSE | Case | No |
| KG | Kilogram | Yes |
| DOZ | Dozen | No |

### 2.2 Verify UOM Conversions
Go to **UOM Conversion Manager tab** and verify:
| Product | From UOM | To UOM | Factor |
|---|---|---|---|
| Biscuit Premium 200g | BOX | PCS | 12 |
| Biscuit Premium 200g | CSE | BOX | 10 |
| Rice Basmati 5kg | BOX | PCS | 6 |

### 2.3 How UOM Works in Orders
When creating an order line:
- User selects **Order UOM** (e.g., BOX)
- System auto-calculates **Base Quantity** = Quantity × Conversion Factor
- Pricing uses Base UOM price × Base Quantity
- Target achievement calculation uses **Base Quantity** for volume, **Total Amount** for revenue

---

## Step 3: Scheme Configuration

### 3.1 Verify Active Schemes
Go to **Scheme Manager tab**. You should see schemes like:

| Scheme | Type | Discount | Min Qty | Period |
|---|---|---|---|---|
| Buy 5 Get 1 Free | Same Product Qty | Free Product | 5 | Current month |
| 10% Off Beverages | Invoice Value | 10% Discount | ₹1000 min | Current month |
| Festive Bonanza | Assorted Value | 5% Discount | ₹5000 min | Current month |

### 3.2 Scheme Slabs
Each scheme can have tiered slabs:
| Scheme | Slab | Min Qty | Max Qty | Discount |
|---|---|---|---|---|
| Buy 5 Get 1 Free | Slab 1 | 5 | 10 | 1 Free |
| Buy 5 Get 1 Free | Slab 2 | 11 | 20 | 2 Free |
| Buy 5 Get 1 Free | Slab 3 | 21 | 999 | 5 Free |

### 3.3 How Schemes Apply to Orders
- Scheme engine auto-evaluates applicable schemes on order save
- Discounts applied to matching line items
- Scheme_Applied__c, Scheme_Discount__c populated on Order_Line_Item__c
- Budget tracked on Scheme__c (Budget_Used__c increments)

---

## Step 4: Must-Sell Configuration

### 4.1 Verify Must-Sell Configs
Go to **Must Sell Config tab**:
| Product | Territory | Min Qty | Active |
|---|---|---|---|
| Biscuit Premium 200g | Delhi NCR | 5 | Yes |
| Tea Classic 250g | All | 3 | Yes |
| Soap Fresh 100g | Mumbai Metro | 10 | Yes |

### 4.2 How Must-Sell Works
- During order creation, system checks if must-sell products are included
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
2. Select products:

| Product | UOM | Qty | Unit Price | Line Total |
|---|---|---|---|---|
| Biscuit Premium 200g | BOX | 10 | ₹120 | ₹1,200 |
| Tea Classic 250g | PCS | 20 | ₹85 | ₹1,700 |
| Soap Fresh 100g | CSE | 2 | ₹450 | ₹900 |
| Rice Basmati 5kg | PCS | 5 | ₹350 | ₹1,750 |

3. Verify auto-calculations:
   - **Base Quantity**: BOX(10) × 12 = 120 PCS for Biscuit
   - **Scheme Applied**: If "Buy 5 Get 1 Free" matches → Free Qty populated
   - **Discount**: Scheme discount auto-applied to line items
   - **Tax**: GST auto-calculated from product HSN/SAC code
   - **Total Net Amount**: Sum of all line totals after discount + tax

4. **Submit Order** → Status changes to "Submitted"
5. **Approve Order** (as manager) → Status = "Approved"

### 5.3 Create Multiple Orders
Create 5-10 orders across different accounts and users to generate meaningful target achievement data:

| Order | Account | Salesperson | Total Amount | Status |
|---|---|---|---|---|
| ORD-001 | ABC Store | Rahul Kumar | ₹15,500 | Approved |
| ORD-002 | XYZ Mart | Rahul Kumar | ₹22,000 | Approved |
| ORD-003 | PQR Shop | Anjali Reddy | ₹18,000 | Approved |
| ORD-004 | LMN Store | Karthik Nambiar | ₹31,000 | Approved |
| ORD-005 | DEF Outlet | Meera Iyer | ₹12,500 | Approved |

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

### 9.1 Create Slabs
Go to **Incentive Slab Manager tab** → Click **New Slab**

#### Universal Slabs (all criteria, all profiles):
| Slab Name | Range | Payout Type | Value | Multiplier |
|---|---|---|---|---|
| Below Threshold | 0% – 89.99% | Fixed Amount | 0 | 0 |
| Base Achiever | 90% – 94.99% | Salary Percentage | 4.5% | 1.0 |
| Standard | 95% – 99.99% | Salary Percentage | 10% | 1.0 |
| Achiever | 100% – 109.99% | Salary Percentage | 17.75% | 1.0 |
| Super Achiever | 110%+ | Salary Percentage | 20% | 1.0 |

#### Revenue-Specific (different rates by profile):
| Slab | Profile | Range | Payout | Value |
|---|---|---|---|---|
| Revenue TSE 90-95% | FSCRM_TSE | 90% – 94.99% | Salary % | 4.5% |
| Revenue TSE 100%+ | FSCRM_TSE | 100% – 109.99% | Salary % | 17.75% |
| Revenue ASM 90-95% | FSCRM_ASM | 90% – 94.99% | Salary % | 3.75% |
| Revenue ASM 100%+ | FSCRM_ASM | 100% – 109.99% | Salary % | 14.5% |

### 9.2 Slab Matching Priority
```
1. Criteria + Profile + Territory  (most specific)
2. Criteria + Profile              (profile-specific)
3. Criteria only                   (criteria-specific)
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

**TSE Rahul Kumar** (Salary: ₹30,000):
| Criteria | Target | Actual | % | Slab Matched | Payout |
|---|---|---|---|---|---|
| Revenue | ₹4,00,000 | ₹3,80,000 | 95% | Standard (10%) | ₹30,000 × 10% × 60% weight = ₹1,800 |
| Focus Brand | ₹80,000 | ₹76,000 | 95% | Standard (10%) | ₹30,000 × 10% × 15% weight = ₹450 |
| Outlet Expansion | 10 | 11 | 110% | Super (20%) | ₹30,000 × 20% × 15% weight = ₹900 |
| Collection | ₹2,80,000 | ₹2,50,000 | 89% | Below | ₹0 |
| **Total Monthly** | | | | | **₹3,150** |

**Prerequisite Check:**
- Revenue = 95% (≥ 90%) → Focus Brand and Outlet Expansion qualify ✓
- If Revenue was 85% → Focus Brand and Outlet Expansion would be ₹0

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
