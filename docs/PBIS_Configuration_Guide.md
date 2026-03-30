# PBIS Configuration Guide
## Performance-Based Incentive Scheme — Setup & Configuration

This guide explains how to configure the incentive system for any FMCG company. The system is fully dynamic — no code changes needed. All configuration is done through the UI.

---

## Table of Contents
1. [Quick Start — Minimal Setup](#1-quick-start)
2. [Step 1: Define Target Criteria](#2-target-criteria)
3. [Step 2: Configure Incentive Slabs](#3-incentive-slabs)
4. [Step 3: Set Up Target Periods](#4-target-periods)
5. [Step 4: Employee Salary Setup](#5-employee-salary)
6. [Step 5: Allocate Targets](#6-allocate-targets)
7. [Step 6: Run Incentive Calculation](#7-run-calculation)
8. [Advanced: KPI Weightage](#8-kpi-weightage)
9. [Advanced: Eligibility Rules (Prerequisites)](#9-eligibility-rules)
10. [Advanced: Profile-Based Slab Rates](#10-profile-based-slabs)
11. [Advanced: Region/Territory-Specific Slabs](#11-region-slabs)
12. [Advanced: Cumulative Quarterly Calculation](#12-cumulative-quarterly)
13. [Advanced: Annual Bonus](#13-annual-bonus)
14. [Payout Type Reference](#14-payout-types)
15. [Slab Matching Priority](#15-slab-matching)
16. [Example Configurations](#16-examples)

---

## 1. Quick Start — Minimal Setup <a name="1-quick-start"></a>

For a basic incentive structure, you only need 4 steps:

1. **Create 1 Target Criteria** (e.g., "Revenue" on Sales_Order__c)
2. **Create 3-5 Incentive Slabs** (achievement % ranges with payout rules)
3. **Create a Target Period** (e.g., "March 2026" — Monthly)
4. **Allocate Targets** to users via Target Allocation screen

Then click "Run Calculation" on the Incentive Dashboard.

---

## 2. Step 1: Define Target Criteria <a name="2-target-criteria"></a>

**Where:** Target Criteria Manager tab

A Target Criteria defines **what to measure**. Each criteria maps to a Salesforce object and field.

| Field | What to Enter | Example |
|---|---|---|
| **Name** | KPI name (used in reports) | Revenue, Collection, Volume, Outlet Expansion |
| **Object** | Salesforce object to query | Sales_Order__c, Collection__c, Visit__c, Account |
| **Operator** | SUM or COUNT | SUM for values, COUNT for number of records |
| **SUM Field** | Field to aggregate (when SUM) | Total_Net_Amount__c, Amount__c |
| **Date Field** | Date field for period filtering | Order_Date__c, Collection_Date__c, CreatedDate |
| **User Field** | Lookup field that identifies the salesperson | Salesperson__c, OwnerId, User__c |
| **Category** | Grouping label | Revenue, Activity, Collection, Coverage |
| **Incentive Weight (%)** | *(Advanced)* How much this KPI contributes to total incentive | 60%, 15%, 10% |
| **Prerequisite Criteria** | *(Advanced)* Must achieve this KPI first | Revenue (for S&D criteria) |
| **Prerequisite Min %** | *(Advanced)* Minimum % required on prerequisite | 90 |
| **Filters** | Optional conditions to narrow records | Status = 'Approved', Type = 'Focus Brand' |

### Common FMCG Criteria Examples

| Criteria | Object | Operator | Field | Filters |
|---|---|---|---|---|
| Revenue | Sales_Order__c | SUM | Total_Net_Amount__c | Status IN (Approved, Delivered) |
| Collection | Collection__c | SUM | Amount__c | Status = Confirmed |
| Volume | Order_Line_Item__c | SUM | Base_Quantity__c | — |
| Productive Calls | Visit__c | COUNT | Id | Is_Productive__c = true |
| New Outlets | Account | COUNT | Id | Type = 'Retailer' |
| Focus Brand Sales | Order_Line_Item__c | SUM | Total_Amount__c | Product_Category = 'Focus Brand' |

---

## 3. Step 2: Configure Incentive Slabs <a name="3-incentive-slabs"></a>

**Where:** Incentive Slab Manager tab

Slabs define **how much incentive to pay** for each achievement level.

| Field | What to Enter | Example |
|---|---|---|
| **Slab Name** | Descriptive name | "Revenue — Standard Achiever" |
| **Min Achievement %** | Minimum % to qualify for this slab | 80 |
| **Max Achievement %** | Maximum % for this slab | 99.99 |
| **Payout Type** | How payout is calculated (see below) | Percentage, Fixed Amount, Salary Percentage |
| **Payout Value** | The amount or percentage | 3 (means 3%), 5000 (fixed), 15 (salary %) |
| **Multiplier** | Scaling factor (default 1.0) | 1.0, 1.5, 2.0 |
| **Target Criteria** | *(Optional)* Specific criteria this slab applies to | Revenue |
| **Profile Name** | *(Optional)* Salesforce profile this slab applies to | Custom: Field Sales Rep |
| **Territory** | *(Optional)* Region this slab applies to | Kerala |
| **Active** | Enable/disable this slab | Yes |
| **Effective From/To** | *(Optional)* Date range for slab validity | 01/04/2026 — 31/03/2027 |

### Payout Type Guide

| Payout Type | Formula | Best For |
|---|---|---|
| **Percentage** | `Target Value × (Payout Value / 100) × Multiplier` | When incentive should scale with target size |
| **Fixed Amount** | `Payout Value × Multiplier` | Flat bonuses regardless of target size |
| **Salary Percentage** | `Gross Salary × (Payout Value / 100) × Multiplier` | Standard FMCG PBIS (% of salary) |

### Example: Basic 5-Slab Structure

| Slab | Range | Payout Type | Value | Multiplier | Example (Target 5L) |
|---|---|---|---|---|---|
| Below Threshold | 0 — 89.99% | Fixed | 0 | 0x | 0 |
| Base | 90 — 94.99% | Percentage | 3% | 1x | 15,000 |
| Standard | 95 — 99.99% | Percentage | 8% | 1x | 40,000 |
| Achiever | 100 — 109.99% | Percentage | 15% | 1x | 75,000 |
| Super | 110%+ | Percentage | 15% | 1.3x | 97,500 |

---

## 4. Step 3: Set Up Target Periods <a name="4-target-periods"></a>

**Where:** Target Periods tab (standard Salesforce list)

| Field | What to Enter | Example |
|---|---|---|
| **Name** | Period label | "March 2026", "Q1 FY26-27", "FY 2026-27" |
| **Type** | Monthly, Quarterly, or Yearly | Monthly |
| **Start Date** | Period start | 01/03/2026 |
| **End Date** | Period end | 31/03/2026 |
| **Active** | Enable for target allocation | Yes |
| **Default** | Auto-selected in dropdowns | Yes (for current period) |
| **Cumulative** | *(Advanced)* Sum child period achievements | Yes (for quarterly) |
| **Parent Period** | *(Advanced)* Links monthly → quarterly → annual | Q1 FY26-27 |

### Period Hierarchy Example (FY 2026-27)
```
FY 2026-27 (Yearly, Cumulative=Yes)
├── Q1 FY26-27 (Quarterly, Cumulative=Yes, Parent=FY 2026-27)
│   ├── April 2026 (Monthly, Parent=Q1)
│   ├── May 2026 (Monthly, Parent=Q1)
│   └── June 2026 (Monthly, Parent=Q1)
├── Q2 FY26-27 (Quarterly, Cumulative=Yes, Parent=FY 2026-27)
│   ├── July 2026 (Monthly, Parent=Q2)
│   ├── August 2026 (Monthly, Parent=Q2)
│   └── September 2026 (Monthly, Parent=Q2)
├── Q3 FY26-27 ...
└── Q4 FY26-27 ...
```

---

## 5. Step 4: Employee Salary Setup <a name="5-employee-salary"></a>

**Where:** Employee records (Employee tab → edit record)

Only needed if using **Salary Percentage** payout type.

| Field | What to Enter |
|---|---|
| **Gross Salary** | Monthly gross salary in local currency |

The calculation engine automatically:
- Uses monthly salary for Monthly period slabs
- Multiplies by 3 for Quarterly period slabs
- Multiplies by 12 for Annual period slabs

---

## 6. Step 5: Allocate Targets <a name="6-allocate-targets"></a>

**Where:** Target Allocation tab

1. Select **Period** and **User**
2. Click **Add Target** to set target values per criteria
3. Click **Distribute** to split a manager's target across subordinates

---

## 7. Step 6: Run Incentive Calculation <a name="7-run-calculation"></a>

**Where:** Incentive Dashboard tab

1. Select the **Period** to calculate
2. Click **Run Calculation** button
3. Wait ~30 seconds for the batch to process
4. Refresh to see calculated incentive records
5. **Review** → **Submit for Approval** → **Approve** → **Mark as Paid**

The calculation runs automatically on the 1st of every month (for the previous month) if the scheduler is configured.

---

## 8. Advanced: KPI Weightage <a name="8-kpi-weightage"></a>

Set **Incentive Weight (%)** on each Target Criteria to define how the total incentive pool is split.

### Example: 4-KPI Split
| Criteria | Weight | Meaning |
|---|---|---|
| Revenue | 60% | 60% of total incentive depends on revenue target |
| S&D Parameter 1 | 15% | Focus brand sales |
| S&D Parameter 2 | 15% | Outlet expansion |
| Focus Brand | 10% | Specific brand achievement |
| **Total** | **100%** | |

### How It Works
```
Revenue incentive (from slab)     = 12,000  × 60% weight = 7,200
S&D Param 1 incentive (from slab) =  8,000  × 15% weight = 1,200
S&D Param 2 incentive (from slab) =  8,000  × 15% weight = 1,200
Focus Brand incentive (from slab)  =  5,000  × 10% weight =   500
                                                   Total  = 10,100
```

> **Note:** If weights are blank (not set), each criteria's incentive is calculated independently without weighting — full payout per criteria.

---

## 9. Advanced: Eligibility Rules (Prerequisites) <a name="9-eligibility-rules"></a>

Set **Prerequisite Criteria** and **Prerequisite Min %** on a Target Criteria to enforce dependencies.

### Example
| Criteria | Prerequisite | Min % | Meaning |
|---|---|---|---|
| S&D Parameter 1 | Revenue | 90% | Must achieve 90% revenue target to qualify for S&D incentive |
| S&D Parameter 2 | Revenue | 90% | Same prerequisite |
| Focus Brand | Revenue | 90% | Same prerequisite |
| Revenue | *(none)* | — | No prerequisite — always eligible |

### What Happens
- Salesperson A: Revenue = 95% → Qualifies for all S&D incentives
- Salesperson B: Revenue = 85% → Gets Revenue incentive only, S&D incentives skipped
- Salesperson C: Revenue = 105%, S&D1 = 80% → Gets Revenue + S&D1 at 80% slab

---

## 10. Advanced: Profile-Based Slab Rates <a name="10-profile-based-slabs"></a>

Set **Profile Name** on slabs to define different payout rates for different roles.

### Example: Same Criteria, Different Rates Per Profile

| Slab | Profile | Range | Payout |
|---|---|---|---|
| TSE — Standard | Custom: Field Sales Rep | 90-95% | 4.5% salary |
| ASM — Standard | Custom: Area Sales Manager | 90-95% | 3.75% salary |
| RSM — Standard | Custom: Regional Sales Manager | 90-95% | 3.5% salary |
| Universal — Standard | *(blank)* | 90-95% | 3% salary |

### How Matching Works
1. System checks: does a slab exist for this user's **exact profile**? → Use it
2. If no profile match: use the **universal slab** (blank profile)

> **Tip:** Create universal slabs as a safety net. Then add profile-specific slabs for roles that need different rates.

---

## 11. Advanced: Region/Territory-Specific Slabs <a name="11-region-slabs"></a>

Set **Territory** on slabs for region-specific incentive structures.

### Example: Kerala vs Karnataka
| Slab | Territory | Profile | Range | Payout |
|---|---|---|---|---|
| Kerala TSE Standard | Kerala | Field Sales Rep | 90-95% | 4.5% salary |
| Karnataka TSE Standard | Karnataka | Field Sales Rep | 90-95% | 3.75% salary |
| Universal TSE Standard | *(blank)* | Field Sales Rep | 90-95% | 3% salary |

---

## 12. Advanced: Cumulative Quarterly Calculation <a name="12-cumulative-quarterly"></a>

For FMCG companies where quarterly incentive is based on cumulative performance:

1. Create **Monthly periods** (Apr, May, Jun) with **Parent Period** = Q1
2. Create **Q1 period** with **Cumulative = Yes**
3. When the engine calculates Q1 incentive:
   - It sums achievements from Apr + May + Jun
   - It sums targets from Apr + May + Jun
   - Calculates cumulative achievement %
   - Matches to quarterly slabs

### Example
```
Monthly targets: Apr=3L, May=3L, Jun=4L → Cumulative target = 10L
Monthly actuals: Apr=2.8L, May=3.5L, Jun=4.2L → Cumulative actual = 10.5L
Cumulative achievement = 10.5L / 10L = 105% → Matches "Achiever" quarterly slab
```

---

## 13. Advanced: Annual Bonus <a name="13-annual-bonus"></a>

Annual bonus = **average of the best 3 out of 4 quarterly incentives**.

### How to Set Up
1. Create 4 Quarterly periods linked to 1 Annual period via **Parent Period**
2. Run incentive calculation for each quarter
3. At year-end, the system automatically:
   - Collects all 4 quarterly incentive amounts
   - Picks the top 3
   - Calculates the average
   - Creates an Incentive record with **Is Annual Bonus = Yes**

### Example
| Quarter | Incentive Earned |
|---|---|
| Q1 | 6,000 |
| Q2 | 7,000 |
| Q3 | 5,500 |
| Q4 | 8,000 |

Top 3 = 8,000 + 7,000 + 6,000 = 21,000
Annual Bonus = 21,000 / 3 = **7,000**

---

## 14. Payout Type Reference <a name="14-payout-types"></a>

| Type | Formula | When to Use |
|---|---|---|
| **Percentage** | `Target Value × Slab% × Multiplier` | Incentive scales with target size. Large targets = larger incentive. |
| **Fixed Amount** | `Slab Value × Multiplier` | Flat bonus regardless of target size. Good for activity-based KPIs. |
| **Salary Percentage** | `Gross Salary × Slab% × Multiplier` | Standard FMCG PBIS. Incentive based on employee's pay grade. For quarterly periods, salary is auto-multiplied by 3. |

---

## 15. Slab Matching Priority <a name="15-slab-matching"></a>

When multiple slabs could match, the system uses this priority order:

```
Priority 1: Criteria + Profile + Territory + % range  (most specific)
Priority 2: Criteria + Profile + any territory        (profile-specific)
Priority 3: Criteria + any profile + any territory    (criteria-specific)
Priority 4: Any criteria + any profile + any territory (universal fallback)
```

Within the same priority level, slabs are evaluated by **Sort Order** (ascending).

> **Best Practice:** Always create universal slabs as a safety net, then layer on specific slabs for profiles, territories, or criteria as needed.

---

## 16. Example Configurations <a name="16-examples"></a>

### Configuration A: Simple FMCG (Small Company)
- 2 criteria: Revenue (SUM), Productive Calls (COUNT)
- 4 universal slabs: 80-90%, 90-100%, 100-110%, 110%+
- Payout type: Percentage of target
- No weights, no prerequisites, no profile/territory differentiation

### Configuration B: Mid-Size FMCG (Like Elite PBIS)
- 4 criteria: Revenue (60%), S&D Param 1 (15%), S&D Param 2 (15%), Focus Brand (10%)
- 12 slabs: 3 per slab level × 4 criteria (or universal + criteria-specific)
- Payout type: Salary Percentage
- Profile-based rates: TSE, ASM, RSM
- Prerequisites: S&D requires 90% revenue achievement
- Monthly + Quarterly (cumulative) + Annual bonus

### Configuration C: Large FMCG (Multi-Region)
- 6 criteria with different weights per region
- 50+ slabs: per criteria × per profile × per territory
- Region-specific weightage (Kerala: 60/15/15/10, Karnataka: 60/10/10/10/10)
- Cumulative quarterly with annual bonus
- Bakery contribution threshold as eligibility rule

---

## Need Help?

- **Target Criteria Manager** — Create and manage what to measure
- **Incentive Slab Manager** — Configure payout rules
- **Target Allocation** — Set targets per user
- **Incentive Dashboard** — Calculate, review, approve, pay
