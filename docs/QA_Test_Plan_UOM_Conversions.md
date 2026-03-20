# QA Test Plan: UOM & UOM Conversions

**Module:** Unit of Measure (UOM) Management & Conversions
**Version:** 1.0
**Date:** 2026-03-20
**Scope:** UOM Master CRUD, Conversion Rules, Quick Converter, Product Integration, Order Impact, Scheme Evaluation

---

## Table of Contents

1. [Pre-requisite: Master Test Data Setup](#1-pre-requisite-master-test-data-setup)
2. [Module 1: UOM Master CRUD](#2-module-1-uom-master-crud)
3. [Module 2: UOM Conversion Rules CRUD](#3-module-2-uom-conversion-rules-crud)
4. [Module 3: UOM Quantity Conversion (Quick Converter)](#4-module-3-uom-quantity-conversion-quick-converter)
5. [Module 4: Products with UOM Conversions](#5-module-4-products-with-uom-conversions)
6. [Module 5: Orders with UOM](#6-module-5-orders-with-uom)
7. [Module 6: Schemes with UOM](#7-module-6-schemes-with-uom)
8. [Module 7: End-to-End Flow](#8-module-7-end-to-end-flow)
9. [Known Gaps / Bugs to Document](#9-known-gaps--bugs-to-document)
10. [How to Use This Plan](#10-how-to-use-this-plan)

---

## 1. Pre-requisite: Master Test Data Setup

### A. UOM Master Records

| # | Name | UOM Code | UOM Type | Is Base Unit | Is Active |
|---|------|----------|----------|-------------|-----------|
| 1 | Piece | PCS | Count | Yes | Yes |
| 2 | Box | BOX | Packaging | No | Yes |
| 3 | Case | CS | Packaging | No | Yes |
| 4 | Kilogram | KG | Weight | Yes | Yes |
| 5 | Gram | GRM | Weight | No | Yes |
| 6 | Liter | LTR | Volume | Yes | Yes |
| 7 | Inactive Unit | INA | Count | No | **No** |

### B. Global UOM Conversions

| # | From UOM | To UOM | Conversion Factor | Auto-Calculated Inverse | Product | Active |
|---|----------|--------|-------------------|------------------------|---------|--------|
| G1 | Box (BOX) | Piece (PCS) | 12 | 0.083333 | — (global) | Yes |
| G2 | Case (CS) | Piece (PCS) | 24 | 0.041667 | — (global) | Yes |
| G3 | Kilogram (KG) | Gram (GRM) | 1000 | 0.001000 | — (global) | Yes |

### C. Products

| # | Product Name | SKU | Base UOM | Secondary UOM | Unit Price (INR) |
|---|-------------|-----|----------|--------------|------------------|
| P1 | Surf Excel 1kg | SE001 | Piece (PCS) | Box (BOX) | 250.00 |
| P2 | Tata Salt 1kg | TS001 | Piece (PCS) | Case (CS) | 28.00 |
| P3 | Fortune Oil 1L | FO001 | Piece (PCS) | Case (CS) | 180.00 |
| P4 | Amul Butter 500g | AB001 | Kilogram (KG) | — | 500.00 |

### D. Product-Specific UOM Conversions (Override Global)

| # | From UOM | To UOM | Conversion Factor | Product | Active |
|---|----------|--------|-------------------|---------|--------|
| PS1 | Case (CS) | Piece (PCS) | **48** | P1 - Surf Excel | Yes |
| PS2 | Box (BOX) | Piece (PCS) | **6** | P3 - Fortune Oil | Yes |

> **Important:** Global says 1 Case = 24 PCS, but for Surf Excel, 1 Case = 48 PCS.
> Global says 1 Box = 12 PCS, but for Fortune Oil, 1 Box = 6 PCS.

---

## 2. Module 1: UOM Master CRUD

| TC# | Test Case | Steps | Input Data | Expected Result | Status |
|-----|-----------|-------|------------|----------------|--------|
| 1.1 | Create new UOM | Navigate to UOM Manager > Click New UOM > Fill form > Save | Name: "Dozen", Code: "DZN", Type: Count, Active: Yes | UOM created successfully. Appears in active UOM list. | |
| 1.2 | Create UOM with duplicate code | Try creating another UOM with an existing code | Name: "Packets", Code: "PCS", Type: Count | Error: Duplicate UOM_Code__c. Record NOT saved. | |
| 1.3 | Edit existing UOM | Select "Box" > Edit > Update description > Save | Description: "Standard packaging box" | UOM updated. Description saved correctly. | |
| 1.4 | Deactivate a UOM | Edit "Gram" > Set Is_Active = false > Save | Is_Active__c: false | Gram no longer appears in active UOM dropdowns but still exists in All UOMs admin view. | |
| 1.5 | View active vs all UOMs | Compare active UOM list vs all UOM list | — | Active list excludes "Inactive Unit" and deactivated "Gram". All list shows every UOM. | |
| 1.6 | Create UOM with all types | Create UOMs of each type | Type: Count, Weight, Volume, Length, Packaging | All types accepted and saved correctly. | |

---

## 3. Module 2: UOM Conversion Rules CRUD

| TC# | Test Case | Steps | Input Data | Expected Result | Status |
|-----|-----------|-------|------------|----------------|--------|
| 2.1 | Create global conversion | UOM Manager > New Conversion > Fill form (no product) > Save | From: Liter, To: Piece, Factor: 1, Product: (blank) | Saved. Inverse auto-calculated = 1.000000. Listed as global conversion. | |
| 2.2 | Create product-specific conversion | New Conversion > Select product > Save | From: Case, To: Piece, Factor: 48, Product: Surf Excel | Saved. Inverse = 0.020833. Listed with product tag. | |
| 2.3 | Validation: Same From and To UOM | Set From and To to same UOM | From: Piece, To: Piece, Factor: 1 | Error: "From UOM and To UOM must be different." | |
| 2.4 | Validation: Negative factor | Enter negative conversion factor | From: Box, To: Piece, Factor: -5 | Error: "Conversion factor must be a positive number." | |
| 2.5 | Validation: Zero factor | Enter zero conversion factor | From: Box, To: Piece, Factor: 0 | Error: "Conversion factor must be a positive number." | |
| 2.6 | Edit conversion factor | Edit G1 (Box to Piece) > Change factor > Save | Factor: 10 | Saved. Inverse auto-recalculated to 0.100000. | |
| 2.7 | Delete conversion | Delete G3 (KG to GRM) | — | Conversion removed. No longer appears in conversion list. | |
| 2.8 | Verify inverse auto-calculation | Create conversion with factor 3 | From: Case, To: Box, Factor: 3 | Inverse = 0.333333 (auto-calculated as 1/3). | |

---

## 4. Module 3: UOM Quantity Conversion (Quick Converter)

### 3A. Direct Conversions (multiply by factor)

| TC# | Input Qty | From UOM | To UOM | Product | Expected Result | Calculation |
|-----|-----------|----------|--------|---------|----------------|-------------|
| 3.1 | 5 | Box | Piece | — (global) | **60** | 5 x 12 = 60 |
| 3.2 | 3 | Case | Piece | — (global) | **72** | 3 x 24 = 72 |
| 3.3 | 2 | KG | Gram | — (global) | **2000** | 2 x 1000 = 2000 |
| 3.4 | 0 | Box | Piece | — | **0** | Zero input returns 0 |
| 3.5 | 10 | Piece | Piece | — | **10** | Same UOM, no conversion needed |
| 3.6 | 1.5 | Box | Piece | — (global) | **18** | 1.5 x 12 = 18 |

### 3B. Reverse Conversions (divide by factor)

| TC# | Input Qty | From UOM | To UOM | Product | Expected Result | Calculation |
|-----|-----------|----------|--------|---------|----------------|-------------|
| 3.7 | 24 | Piece | Box | — (global) | **2** | 24 / 12 = 2 |
| 3.8 | 48 | Piece | Case | — (global) | **2** | 48 / 24 = 2 |
| 3.9 | 500 | Gram | KG | — (global) | **0.5** | 500 / 1000 = 0.5 |
| 3.10 | 7 | Piece | Box | — (global) | **0.583333** | 7 / 12 = 0.583333 |
| 3.11 | 1 | Piece | Case | — (global) | **0.041667** | 1 / 24 = 0.041667 |

### 3C. Product-Specific Conversions (override global)

| TC# | Input Qty | From UOM | To UOM | Product | Expected Result | Calculation | Why? |
|-----|-----------|----------|--------|---------|----------------|-------------|------|
| 3.12 | 2 | Case | Piece | Surf Excel (PS1) | **96** | 2 x 48 = 96 | Product-specific factor 48, NOT global 24 |
| 3.13 | 2 | Case | Piece | Tata Salt (no override) | **48** | 2 x 24 = 48 | Falls back to global factor 24 |
| 3.14 | 3 | Box | Piece | Fortune Oil (PS2) | **18** | 3 x 6 = 18 | Product-specific factor 6, NOT global 12 |
| 3.15 | 3 | Box | Piece | Surf Excel (no BOX override) | **36** | 3 x 12 = 36 | No product-specific BOX rule, falls back to global 12 |
| 3.16 | 96 | Piece | Case | Surf Excel (PS1) | **2** | 96 / 48 = 2 | Reverse of product-specific conversion |
| 3.17 | 18 | Piece | Box | Fortune Oil (PS2) | **3** | 18 / 6 = 3 | Reverse of product-specific conversion |

### 3D. Error Scenarios

| TC# | Input Qty | From UOM | To UOM | Product | Expected Result |
|-----|-----------|----------|--------|---------|----------------|
| 3.18 | 1 | Case | Box | — (no rule exists) | Error: "No conversion rule found between the selected units of measure." |
| 3.19 | 1 | KG | Piece | — (no rule exists) | Error: "No conversion rule found between the selected units of measure." |
| 3.20 | 1 | Liter | KG | — (cross-type, no rule) | Error: "No conversion rule found between the selected units of measure." |
| 3.21 | null | Box | Piece | — | **0** (null treated as zero) |

---

## 5. Module 4: Products with UOM Conversions

| TC# | Test Case | Product | Action | Expected Result | Status |
|-----|-----------|---------|--------|----------------|--------|
| 4.1 | View product conversions (with override) | Surf Excel (has PS1 override) | Call getProductConversions | Returns 2+ conversions: product-specific Case-to-Piece (48) AND global Box-to-Piece (12). Product-specific listed first. | |
| 4.2 | View product conversions (no override) | Tata Salt | Call getProductConversions | Returns only global conversions. All marked isProductSpecific = false. | |
| 4.3 | Product-specific takes priority | Surf Excel | Convert 1 Case to Piece | Returns **48** (product-specific), NOT 24 (global). | |
| 4.4 | Global fallback works | Tata Salt | Convert 1 Box to Piece | Returns **12** (global fallback since no product-specific BOX rule). | |
| 4.5 | Product with Base and Secondary UOM | Surf Excel | Verify product record | Base_UOM = Piece (PCS), Secondary_UOM = Box (BOX). Both lookups resolve correctly. | |
| 4.6 | Product without Secondary UOM | Amul Butter | Verify product record | Base_UOM = KG, Secondary_UOM = null. No error. | |

---

## 6. Module 5: Orders with UOM

### Test Orders

**Order O1 — Single UOM (Pieces only)**

| Line | Product | Qty | UOM | Unit Price | Line Amount |
|------|---------|-----|-----|-----------|-------------|
| 1 | Surf Excel | 10 | Pieces | 250.00 | 2,500.00 |
| 2 | Tata Salt | 20 | Pieces | 28.00 | 560.00 |
| **Total** | | **30 PCS** | | | **3,060.00** |

**Order O2 — Mixed UOM (Cases + Pieces)**

| Line | Product | Qty | UOM | Unit Price | Line Amount |
|------|---------|-----|-----|-----------|-------------|
| 1 | Surf Excel | 2 | Cases | 250.00 | 500.00 |
| 2 | Tata Salt | 10 | Pieces | 28.00 | 280.00 |
| **Total** | | **12 (raw sum)** | | | **780.00** |

**Order O3 — Boxes**

| Line | Product | Qty | UOM | Unit Price | Line Amount |
|------|---------|-----|-----|-----------|-------------|
| 1 | Fortune Oil | 5 | Boxes | 180.00 | 900.00 |
| **Total** | | **5 BOX** | | | **900.00** |

### Order Test Cases

| TC# | Test Case | Order | Steps | Expected Result | Status |
|-----|-----------|-------|-------|----------------|--------|
| 5.1 | Order with default UOM (Pieces) | O1 | Create order with all items in Pieces | Line amounts calculated correctly. UOM defaults to "Pieces" if not explicitly set. | |
| 5.2 | Order with mixed UOM | O2 | Create order with Cases and Pieces | Lines saved with respective UOMs. Line_Amount = raw Qty x Unit_Price. | |
| 5.3 | Verify UOM persists on line item | O2 | After save, query Order_Line_Item__c.UOM__c | Line 1 UOM = "Cases", Line 2 UOM = "Pieces". | |
| 5.4 | Invoice generation preserves UOM | O2 | Generate invoice from order | Invoice_Line__c.UOM__c should match Order_Line_Item UOM values. | |
| 5.5 | Order entry UOM field population | Any | Create order via UI, select non-default UOM | **Verify:** Is UOM__c field actually populated on Order_Line_Item? (See Known Gap #1) | |
| 5.6 | Line amount calculation with non-base UOM | O2 | Verify line amount for Cases line | **Current behavior:** Line_Amount = 2 x 250 = 500. **Note:** No UOM-based price conversion applied. (See Known Gap #3) | |

---

## 7. Module 6: Schemes with UOM

### Test Schemes

| Scheme | Name | Type | Threshold | Invoice Qty UOM | Discount Type | Discount Value | Applicable Products |
|--------|------|------|-----------|----------------|--------------|----------------|-------------------|
| S1 | Bulk Purchase 50PC | Invoice Qty Based | 50 | PC | Percentage | 5% on invoice | All products |
| S2 | KG Promo 10KG | Invoice Qty Based | 10 | KG | Free Product | 3 pcs Tata Salt | Amul Butter |
| S3 | Combo Deal 100PC | Invoice Qty Based | 100 | PC | Flat Amount | 500 off | Surf Excel, Tata Salt |

### Scheme Test Cases

| TC# | Test Case | Order Lines | Scheme | Expected Result | Notes | Status |
|-----|-----------|-------------|--------|----------------|-------|--------|
| 6.1 | Scheme qualifies — all Pieces | 30 PCS Surf + 25 PCS Tata Salt = 55 PCS total | S1 (threshold: 50 PC) | **QUALIFIES.** 55 >= 50. 5% discount applied. | Straightforward single UOM scenario. | |
| 6.2 | Scheme does NOT qualify — below threshold | 20 PCS Surf + 20 PCS Tata Salt = 40 PCS total | S1 (threshold: 50 PC) | **DOES NOT QUALIFY.** 40 < 50. No discount. | | |
| 6.3 | Mixed UOM — Cases + Pieces | 2 Cases Surf + 10 PCS Tata Salt | S1 (threshold: 50 PC) | **Current behavior:** Raw sum = 2 + 10 = 12. Does NOT qualify (12 < 50). | **Known Gap:** Ideally 2 Cases = 96 PCS (product-specific). Total should be 106 PCS which qualifies. But scheme engine sums raw quantities without UOM conversion. | |
| 6.4 | KG-based scheme — all in KG | 15 KG Amul Butter | S2 (threshold: 10 KG) | **QUALIFIES.** 15 >= 10. Free 3 pcs Tata Salt awarded. | | |
| 6.5 | KG-based scheme — mixed KG and Gram | 5 KG + 6000 Gram Amul Butter | S2 (threshold: 10 KG) | **Current behavior:** Raw sum = 5 + 6000 = 6005. Qualifies (incorrectly inflated). | **Known Gap:** Should convert 6000g to 6 KG first. Correct total = 11 KG, still qualifies but for the right reason. | |
| 6.6 | Product-filtered scheme — excluded product | 60 PCS Surf + 50 PCS Fortune Oil | S3 (threshold: 100 PC, products: Surf + Tata Salt) | **DOES NOT QUALIFY.** Only Surf counts (60 PCS). Fortune Oil excluded from S3. 60 < 100. | | |
| 6.7 | Product-filtered scheme — qualifies | 60 PCS Surf + 50 PCS Tata Salt | S3 (threshold: 100 PC) | **QUALIFIES.** 60 + 50 = 110 >= 100. Rs.500 flat discount applied. | | |
| 6.8 | Scheme with slabs and UOM | Multiple qty tiers | S1 with slabs | Verify correct slab is picked based on raw quantity sum. | | |

---

## 8. Module 7: End-to-End Flow

| TC# | Scenario | Steps | Expected Result | Status |
|-----|----------|-------|----------------|--------|
| 7.1 | Full order lifecycle with UOM | 1. Create UOMs (PCS, BOX, CS) 2. Create global conversions (BOX-PCS=12, CS-PCS=24) 3. Create product with Base_UOM=PCS, Secondary_UOM=BOX 4. Create order with 5 BOX of that product 5. Apply scheme 6. Generate invoice | All steps complete successfully. Invoice reflects correct UOM, quantity, and any scheme discount. | |
| 7.2 | Product-specific conversion in order | 1. Create product-specific conversion (CS-PCS=48 for Surf) 2. Order 3 CS of Surf 3. Verify conversion in Quick Converter 4. Check order line item | Quick Converter: 3 CS = 144 PCS for Surf. Order line saved with UOM=Cases, Qty=3. | |
| 7.3 | Deactivate conversion mid-flow | 1. Create conversion BOX-PCS=12 2. Use Quick Converter (works, returns result) 3. Deactivate conversion (Is_Active=false) 4. Try Quick Converter again | Step 2: Returns correct result. Step 4: Error "No conversion rule found." Inactive conversions are excluded. | |
| 7.4 | Delete product with conversions | 1. Create product-specific conversion for a product 2. Delete/deactivate the product 3. Check conversion record | Verify behavior: Does conversion become orphaned? Does it still appear in global list? | |
| 7.5 | Bulk conversion accuracy | 1. Convert 999999 PCS to Box (global) 2. Convert result back to PCS | Forward: 999999 / 12 = 83333.25 BOX. Reverse: 83333.25 x 12 = 999999 PCS. Round-trip accuracy maintained. | |

---

## 9. Known Gaps / Bugs to Document

| # | Gap Description | Impact | Severity | Reference |
|---|----------------|--------|----------|-----------|
| 1 | **OrderEntryController does not populate UOM__c** on Order_Line_Item during order creation. The `createSalesOrder` method does not map UOM from the input payload. | All order line items will have NULL or default "Pieces" UOM regardless of what user selects in the UI. | **High** | `OrderEntryController.cls` lines 144-158 |
| 2 | **Scheme engine ignores Invoice_Qty_UOM__c** — `evaluateInvoiceQty()` sums raw `Quantity__c` values without converting line item UOMs to the scheme's target UOM. | Mixed-UOM orders get incorrect scheme qualification. See TC 6.3 and 6.5 for examples. | **High** | `SPM_SchemeEngine_Service.cls` lines 716-758 |
| 3 | **Pricing ignores UOM** — `Line_Amount = Quantity x Unit_Price` without converting quantity to base UOM first. | Ordering 2 Cases at Rs.250/piece gives Rs.500 instead of the expected Rs.24,000 (2 x 48 x 250). | **High** | `OMS_OrderPricing_Service.cls` |
| 4 | **Order_Line_Item.UOM__c is a Picklist** (Pieces, Cases, Boxes, Kg, Liters) instead of a Lookup to UOM__c master. | Adding new UOM types requires a metadata deployment. Disconnected from UOM__c master records. | **Medium** | `Order_Line_Item__c/fields/UOM__c.field-meta.xml` |
| 5 | **Invoice_Line.UOM__c is a Text field** (20 chars) instead of a Lookup or Picklist. | No validation against UOM master. Free-text entry possible. | **Low** | `Invoice_Line__c/fields/UOM__c.field-meta.xml` |

---

## 10. How to Use This Plan

### For Developer Testing (Round 1)

1. **Set up test data** exactly as specified in Section 1 (Pre-requisite).
2. **Execute Modules 1-4** first — UOM CRUD, Conversion Rules, Quick Converter, and Product Integration. These are fully functional.
3. **Execute Modules 5-6** to document actual behavior vs expected, especially for known gaps.
4. **Document actual results** in the Status column for each test case.
5. **Note any deviations** from expected results.

### For QA Handoff

1. Share this entire document with the QA team.
2. QA should:
   - Set up test data exactly as specified in the Pre-requisite section.
   - Execute each TC# sequentially within each module.
   - Mark **Pass/Fail** with actual results in the Status column.
   - Flag any item from the "Known Gaps" table as a **Known Issue** (not a test failure) unless it has been fixed.
3. **Regression Testing:** After any gap is fixed, re-run the affected test cases to verify the fix.

### Priority for Fixing Gaps

| Priority | Gap # | Reason |
|----------|-------|--------|
| P0 | #1 | UOM field not being saved breaks all downstream UOM-dependent features |
| P0 | #3 | Pricing without UOM conversion leads to incorrect order amounts |
| P1 | #2 | Scheme evaluation with mixed UOMs gives wrong qualification results |
| P2 | #4 | Architectural improvement for maintainability |
| P3 | #5 | Minor data integrity improvement |

---

## Conversion Reference Card (Quick Lookup)

| From | To | Global Factor | Surf Excel Factor | Fortune Oil Factor |
|------|----|--------------|-------------------|-------------------|
| Box | Piece | 12 | 12 (global) | **6** (product-specific) |
| Case | Piece | 24 | **48** (product-specific) | 24 (global) |
| KG | Gram | 1000 | 1000 (global) | 1000 (global) |
| Piece | Box | 1/12 = 0.083333 | 0.083333 | **1/6 = 0.166667** |
| Piece | Case | 1/24 = 0.041667 | **1/48 = 0.020833** | 0.041667 |
| Gram | KG | 1/1000 = 0.001 | 0.001 | 0.001 |
