# QA Test Plan: Product Management Module (MDM-01)

**Module:** Master Data Management - Product Management
**Application:** FMCG CRM / SFA
**Version:** 1.0
**Date:** 2026-02-20

---

## 1. Module Overview

The Product Management module provides end-to-end product master data management for an FMCG field sales application. It covers product catalog browsing, category hierarchy, FMCG-specific product extensions (barcodes, weights, packaging), pricing with audit trail, batch/expiry tracking, and distributor stock management.

### Components Under Test

| Component | Type | File Path |
|-----------|------|-----------|
| Product Catalog | LWC | `lwc/productCatalog/` |
| MDM_ProductCatalogController | Apex Controller | `classes/MDM_ProductCatalogController.cls` |
| MDM_PriceList_Handler | Apex Trigger Handler | `classes/MDM_PriceList_Handler.cls` |
| INV_DistributorStock_TriggerHandler | Apex Trigger Handler | `classes/INV_DistributorStock_TriggerHandler.cls` |
| INV_StockDashboardController | Apex Controller | `classes/INV_StockDashboardController.cls` |
| Product_Extension__c | Custom Object | `objects/Product_Extension__c/` |
| Product_Category__c | Custom Object | `objects/Product_Category__c/` |
| Batch_Master__c | Custom Object | `objects/Batch_Master__c/` |
| Price_List__c | Custom Object | `objects/Price_List__c/` |
| Price_Change_Log__c | Custom Object | `objects/Price_Change_Log__c/` |
| Distributor_Stock__c | Custom Object | `objects/Distributor_Stock__c/` |
| FSCRM_Product_Manager | Permission Set | `permissionsets/FSCRM_Product_Manager.permissionset-meta.xml` |
| FSCRM_Field_Rep_Products | Permission Set | `permissionsets/FSCRM_Field_Rep_Products.permissionset-meta.xml` |

---

## 2. Pre-Requisites

- [ ] Admin user with System Administrator profile
- [ ] Test user with FSCRM_Product_Manager permission set assigned
- [ ] Test user with FSCRM_Field_Rep_Products permission set assigned (read-only)
- [ ] At least one Account record (distributor) exists
- [ ] Product Catalog tab is visible in the app navigation

---

## 3. Test Data Setup

Before executing tests, create the following seed data:

### 3.1 Product Categories (3-level hierarchy)

| Category Code | Name | Level | Parent |
|---------------|------|-------|--------|
| BEV | Beverages | Category | -- |
| BEV-JUICE | Juices | Sub-Category | Beverages |
| BEV-JUICE-BA | Brand A Juices | Brand | Juices |
| SNK | Snacks | Category | -- |
| SNK-CHIPS | Chips | Sub-Category | Snacks |

### 3.2 Products (Standard Product2)

| Product Name | Product Code | Family | Active |
|--------------|-------------|--------|--------|
| Orange Juice 500ml | OJ-500 | Beverages | Yes |
| Apple Juice 1L | AJ-1000 | Beverages | Yes |
| Mango Juice 250ml | MJ-250 | Beverages | Yes |
| Potato Chips 100g | PC-100 | Snacks | Yes |
| Corn Chips 150g | CC-150 | Snacks | Yes |
| Discontinued Drink | DD-001 | Beverages | No |

### 3.3 Product Extensions

| Product | EAN Barcode | Weight | Unit | Case Size | MOQ | Category |
|---------|-------------|--------|------|-----------|-----|----------|
| Orange Juice 500ml | 8901234567890 | 500 | ml | 24 | 5 | Brand A Juices |
| Apple Juice 1L | 8901234567906 | 1000 | ml | 12 | 3 | Juices |
| Potato Chips 100g | 89012345 | 100 | g | 48 | 10 | Chips |

### 3.4 Price Lists

| Product | Price Type | Channel | Unit Price | Effective From | Effective To |
|---------|-----------|---------|------------|----------------|-------------|
| Orange Juice 500ml | MRP | -- | 45.00 | 2026-01-01 | -- |
| Orange Juice 500ml | Distributor Price | GT | 38.00 | 2026-01-01 | -- |
| Apple Juice 1L | MRP | -- | 85.00 | 2026-01-01 | 2026-06-30 |

### 3.5 Batch Master

| Product | Batch Number | Mfg Date | Expiry Date | Status | Qty |
|---------|-------------|----------|-------------|--------|-----|
| Orange Juice 500ml | BATCH-OJ-001 | 2026-01-15 | 2026-07-15 | Active | 5000 |
| Orange Juice 500ml | BATCH-OJ-002 | 2026-02-01 | 2026-08-01 | Active | 3000 |

### 3.6 Distributor Stock

| Account | Product | Stock Date | Opening | Received | Sold | Damaged | Is Current |
|---------|---------|------------|---------|----------|------|---------|------------|
| Distributor A | Orange Juice 500ml | 2026-02-20 | 100 | 50 | 30 | 2 | Yes |

---

## 4. Test Cases

---

### 4.1 Product Category Management

#### TC-CAT-001: Create Top-Level Category
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Pre-condition** | Logged in as Product Manager user |
| **Steps** | 1. Navigate to Product Categories tab<br>2. Click New<br>3. Enter: Category Code = "DAI", Name = "Dairy", Level = "Category"<br>4. Leave Parent Category blank<br>5. Click Save |
| **Expected Result** | Record created successfully. No parent category allowed for "Category" level. |

#### TC-CAT-002: Create Sub-Category with Parent
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Click New on Product Categories<br>2. Enter: Code = "DAI-MLK", Name = "Milk", Level = "Sub-Category"<br>3. Set Parent Category = "Dairy"<br>4. Click Save |
| **Expected Result** | Record created successfully with parent relationship. |

#### TC-CAT-003: Sub-Category Without Parent (Negative)
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Click New on Product Categories<br>2. Enter: Code = "DAI-YOG", Name = "Yogurt", Level = "Sub-Category"<br>3. Leave Parent Category blank<br>4. Click Save |
| **Expected Result** | Validation error: Sub-Category and Brand levels must have a parent category. |

#### TC-CAT-004: Top-Level Category with Parent (Negative)
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Click New on Product Categories<br>2. Enter: Code = "NEW-CAT", Name = "New Cat", Level = "Category"<br>3. Set Parent Category = "Beverages"<br>4. Click Save |
| **Expected Result** | Validation error: Top-level Category entries cannot have a parent category. |

#### TC-CAT-005: Duplicate Category Code (Negative)
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Create a category with Code = "BEV" (already exists)<br>2. Click Save |
| **Expected Result** | Duplicate value error on Category_Code__c (unique external ID). |

#### TC-CAT-006: Brand Level with Parent
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Create category: Code = "SNK-CHIPS-LA", Name = "Lays", Level = "Brand", Parent = "Chips"<br>2. Save |
| **Expected Result** | Record created successfully. |

---

### 4.2 Product Extension Management

#### TC-EXT-001: Create Product Extension with All Fields
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Navigate to a Product record<br>2. Click New on Product Extensions related list<br>3. Fill all fields: Name, Product (auto-filled), Category, EAN = "8901234567890", UPC, HSN Code, Weight = 500, Unit = ml, Case Size = 24, MOQ = 5<br>4. Save |
| **Expected Result** | Extension record created with all fields populated. Visible in Product layout related list. |

#### TC-EXT-002: Invalid EAN Barcode - Wrong Length (Negative)
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Create Product Extension<br>2. Enter Barcode EAN = "12345" (5 digits)<br>3. Save |
| **Expected Result** | Validation error: EAN Barcode must be 8 or 13 digits. |

#### TC-EXT-003: Valid EAN Barcode - 8 Digits
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Create Product Extension with EAN = "89012345" (8 digits)<br>2. Save |
| **Expected Result** | Record saved successfully. |

#### TC-EXT-004: Valid EAN Barcode - 13 Digits
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Create Product Extension with EAN = "8901234567890" (13 digits)<br>2. Save |
| **Expected Result** | Record saved successfully. |

#### TC-EXT-005: Weight Without Unit (Negative)
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Create Product Extension<br>2. Enter Weight = 500, leave Weight Unit blank<br>3. Save |
| **Expected Result** | Validation error: Weight Unit is required when Weight is specified. |

#### TC-EXT-006: Case Size Zero or Negative (Negative)
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Create Product Extension with Case Size = 0<br>2. Save |
| **Expected Result** | Validation error: Case Size must be greater than zero. |

#### TC-EXT-007: Min Order Qty Zero or Negative (Negative)
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Create Product Extension with Min Order Qty = -1<br>2. Save |
| **Expected Result** | Validation error: Min Order Qty must be greater than zero. |

#### TC-EXT-008: Weight Unit Picklist Values
| Field | Value |
|-------|-------|
| **Priority** | Low |
| **Steps** | 1. Open Product Extension edit form<br>2. Click Weight Unit picklist |
| **Expected Result** | Available values: kg, g, l, ml, units. |

---

### 4.3 Price List Management

#### TC-PRC-001: Create Price List Entry
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Create new Price List record<br>2. Product = "Orange Juice 500ml", Price Type = "Retailer Price", Channel = "GT", Unit Price = 42.00, Effective From = 2026-03-01<br>3. Save |
| **Expected Result** | Record created successfully. |

#### TC-PRC-002: Unit Price Zero or Negative (Negative)
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Create Price List with Unit Price = 0<br>2. Save |
| **Expected Result** | Validation error: Unit Price must be greater than zero. |

#### TC-PRC-003: Effective To Before Effective From (Negative)
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Create Price List with Effective From = 2026-06-01, Effective To = 2026-05-01<br>2. Save |
| **Expected Result** | Validation error: Effective To date must be on or after the Effective From date. |

#### TC-PRC-004: Overlapping Date Ranges - Same Dimensions (Negative)
| Field | Value |
|-------|-------|
| **Priority** | Critical |
| **Pre-condition** | Existing price: OJ-500, MRP, no channel, 2026-01-01 to open-ended |
| **Steps** | 1. Create new Price List: Product = OJ-500, Price Type = MRP, Channel = blank, Effective From = 2026-06-01<br>2. Save |
| **Expected Result** | Error: Overlapping date range exists for this Product + Region + Channel combination. |

#### TC-PRC-005: Non-Overlapping Prices - Different Channel
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Create Price List: Product = OJ-500, Price Type = MRP, Channel = "MT", Effective From = 2026-01-01<br>2. Save |
| **Expected Result** | Record saved successfully (different channel = different dimension). |

#### TC-PRC-006: Open-Ended Pricing (No Effective To)
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Create Price List with Effective From = 2026-03-01 and Effective To = blank<br>2. Save |
| **Expected Result** | Record saved. Treated as indefinitely valid. |

#### TC-PRC-007: Price Change Audit Trail
| Field | Value |
|-------|-------|
| **Priority** | Critical |
| **Pre-condition** | Existing Price List record with Unit Price = 45.00 |
| **Steps** | 1. Edit existing Price List record<br>2. Change Unit Price from 45.00 to 50.00<br>3. Save<br>4. Check Price Change Log related records |
| **Expected Result** | A Price_Change_Log__c record is auto-created with: Old Price = 45.00, New Price = 50.00, Changed By = current user, Change Date = current datetime, Change Reason = "Price updated via Price List modification". |

#### TC-PRC-008: No Audit Log When Price Unchanged
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Edit existing Price List record<br>2. Change a non-price field (e.g., Min Qty)<br>3. Save<br>4. Check Price Change Log |
| **Expected Result** | No new Price_Change_Log__c record created (price didn't change). |

#### TC-PRC-009: Negative Min Qty (Negative)
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Create Price List with Min Qty = -5<br>2. Save |
| **Expected Result** | Validation error: Min Qty must be greater than or equal to zero. |

---

### 4.4 Batch Master Management

#### TC-BAT-001: Create Valid Batch
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Navigate to Batch Master<br>2. Create new: Batch Number = "BATCH-TEST-001", Product = OJ-500, Mfg Date = 2026-02-01, Expiry Date = 2026-08-01, Status = Active, Qty = 1000<br>3. Save |
| **Expected Result** | Record created. Shelf_Life_Remaining_Pct__c and Is_Near_Expiry__c auto-calculated. |

#### TC-BAT-002: Future Manufacturing Date (Negative)
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Create Batch with Manufacturing Date = 2026-12-01 (future)<br>2. Save |
| **Expected Result** | Validation error: Manufacturing Date cannot be a future date. |

#### TC-BAT-003: Expiry Before Manufacturing (Negative)
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Create Batch with Mfg Date = 2026-02-01, Expiry Date = 2026-01-01<br>2. Save |
| **Expected Result** | Validation error: Expiry Date must be after Manufacturing Date. |

#### TC-BAT-004: Zero Quantity Manufactured (Negative)
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Create Batch with Quantity Manufactured = 0<br>2. Save |
| **Expected Result** | Validation error: Quantity Manufactured must be greater than zero. |

#### TC-BAT-005: Shelf Life Remaining Calculation
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Create batch: Mfg Date = 2026-01-01, Expiry Date = 2026-07-01 (181 days shelf life)<br>2. View the Shelf Life Remaining % field |
| **Expected Result** | Shelf_Life_Remaining_Pct__c = MAX(0, (Expiry - TODAY) / (Expiry - Mfg)) as a percentage. Verify calculation is correct for today's date. |

#### TC-BAT-006: Near Expiry Flag
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Create batch with Expiry Date = TODAY + 15 days<br>2. View Is_Near_Expiry__c field |
| **Expected Result** | Is_Near_Expiry__c = true (within 30 days of expiry). |

#### TC-BAT-007: Not Near Expiry
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Create batch with Expiry Date = TODAY + 60 days<br>2. View Is_Near_Expiry__c field |
| **Expected Result** | Is_Near_Expiry__c = false (more than 30 days until expiry). |

#### TC-BAT-008: Duplicate Batch Number (Negative)
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Create batch with Batch Number = "BATCH-OJ-001" (already exists)<br>2. Save |
| **Expected Result** | Duplicate value error on Batch_Number__c (unique external ID). |

#### TC-BAT-009: Batch Status Values
| Field | Value |
|-------|-------|
| **Priority** | Low |
| **Steps** | 1. Open Batch Master edit form<br>2. Check Status picklist |
| **Expected Result** | Available values: Active, Recalled, Expired. Default = Active. |

---

### 4.5 Distributor Stock Management

#### TC-STK-001: Create Stock Entry - Auto Closing Stock
| Field | Value |
|-------|-------|
| **Priority** | Critical |
| **Steps** | 1. Create Distributor Stock: Account = Distributor A, Product = OJ-500, Stock Date = today, Opening = 100, Received = 50, Sold = 30, Damaged = 2, Is Current = true<br>2. Save<br>3. Check Closing Stock field |
| **Expected Result** | Closing_Stock__c auto-calculated = 100 + 50 - 30 - 2 = **118**. |

#### TC-STK-002: Is Current Constraint (One Per Account+Product)
| Field | Value |
|-------|-------|
| **Priority** | Critical |
| **Pre-condition** | Existing stock for Distributor A + OJ-500 with Is Current = true |
| **Steps** | 1. Create new stock entry: same Account + Product, Is Current = true<br>2. Save<br>3. Query previous stock record |
| **Expected Result** | New record saved with Is_Current__c = true. Previous record's Is_Current__c auto-set to false. |

#### TC-STK-003: Negative Quantities (Negative)
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Create stock entry with Opening Stock = -10<br>2. Save |
| **Expected Result** | Validation error: All quantity fields must be greater than or equal to zero. |

#### TC-STK-004: Sold Exceeds Available (Negative)
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Create stock entry: Opening = 50, Received = 20, Sold = 80, Damaged = 0<br>2. Save |
| **Expected Result** | Validation error: Sold Qty + Damaged Qty cannot exceed Opening Stock + Received Qty. (80 > 70) |

#### TC-STK-005: Sold + Damaged Exactly Equals Available
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Create stock entry: Opening = 50, Received = 20, Sold = 60, Damaged = 10<br>2. Save |
| **Expected Result** | Record saved. Closing Stock = 0 (50 + 20 - 60 - 10 = 0). |

#### TC-STK-006: Past Expiry Date (Negative)
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Create stock entry with Expiry Date = 2025-01-01 (past date)<br>2. Save |
| **Expected Result** | Validation error: Expiry Date must be today or in the future. |

#### TC-STK-007: Closing Stock Recalculation on Update
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Edit existing stock entry<br>2. Change Sold Qty from 30 to 50<br>3. Save |
| **Expected Result** | Closing Stock auto-recalculated with new Sold value. |

---

### 4.6 Product Catalog LWC Component

#### TC-LWC-001: Initial Load
| Field | Value |
|-------|-------|
| **Priority** | Critical |
| **Steps** | 1. Navigate to Product Catalog tab<br>2. Wait for page to load |
| **Expected Result** | Category tree displayed on left panel. Product grid shows first 12 products in card format. Pagination controls visible at bottom. |

#### TC-LWC-002: Search by Product Name
| Field | Value |
|-------|-------|
| **Priority** | Critical |
| **Steps** | 1. Type "Orange" in the search box<br>2. Wait 300ms for debounce |
| **Expected Result** | Only products matching "Orange" displayed. Result count updates. Pagination resets to page 1. |

#### TC-LWC-003: Search by Product Code
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Type "OJ-500" in the search box<br>2. Wait for results |
| **Expected Result** | Product with code OJ-500 displayed. |

#### TC-LWC-004: Active Only Filter
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Pre-condition** | At least one inactive product exists |
| **Steps** | 1. Check "Active Only" checkbox<br>2. Verify results<br>3. Uncheck "Active Only"<br>4. Verify results |
| **Expected Result** | When checked: only active products shown. When unchecked: all products shown (including inactive "Discontinued Drink"). |

#### TC-LWC-005: Category Tree Navigation
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Expand "Beverages" in category tree<br>2. Click on "Juices" |
| **Expected Result** | Products filtered to Juices category and all sub-categories. Category filter badge appears showing "Juices". |

#### TC-LWC-006: Clear Category Filter
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Select a category to filter<br>2. Click the clear/X button on category filter badge |
| **Expected Result** | Category filter removed. All products displayed. Filter badge disappears. |

#### TC-LWC-007: Category Toggle Deselect
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Select "Beverages" category<br>2. Click "Beverages" again |
| **Expected Result** | Category deselected. Products unfiltered. |

#### TC-LWC-008: Product Card Click - Detail Panel
| Field | Value |
|-------|-------|
| **Priority** | Critical |
| **Steps** | 1. Click on "Orange Juice 500ml" product card |
| **Expected Result** | Detail panel opens on the right showing:<br>- Product name, code, family, active status<br>- Extension info (barcode, weight, case size, MOQ)<br>- Pricing table with all active prices<br>- Active batch count<br>- Current stock summary |

#### TC-LWC-009: Product Detail - Pricing Table
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Pre-condition** | Product has active price list entries |
| **Steps** | 1. Click on a product with pricing<br>2. Review pricing section in detail panel |
| **Expected Result** | Table shows all active prices within current effective date range. Includes Price Type, Channel, Unit Price. |

#### TC-LWC-010: Product Detail - Close Panel
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Open a product detail panel<br>2. Click close/X button on the panel |
| **Expected Result** | Detail panel closes. Product grid returns to full width. |

#### TC-LWC-011: Product Detail - Toggle Deselect
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Click a product card to open detail<br>2. Click the same product card again |
| **Expected Result** | Detail panel closes. |

#### TC-LWC-012: Pagination - Page Navigation
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Pre-condition** | More than 12 products exist |
| **Steps** | 1. Note products on page 1<br>2. Click page 2 button<br>3. Verify different products are shown<br>4. Click Previous<br>5. Verify page 1 products restored |
| **Expected Result** | Correct 12 products per page. Page numbers update. "Showing X-Y of Z" range is accurate. |

#### TC-LWC-013: Pagination - Disabled States
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Go to page 1<br>2. Check Previous button state<br>3. Go to last page<br>4. Check Next button state |
| **Expected Result** | Previous disabled on first page. Next disabled on last page. |

#### TC-LWC-014: Combined Filters
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Select "Beverages" category<br>2. Check "Active Only"<br>3. Type "Juice" in search<br>4. Verify results |
| **Expected Result** | Only active Beverage products matching "Juice" are displayed. All three filters applied simultaneously. |

#### TC-LWC-015: Empty State - No Results
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Type "XYZNONEXISTENT" in search |
| **Expected Result** | Empty state message displayed (e.g., "No products found"). Pagination hidden. |

#### TC-LWC-016: Responsive Layout
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. View Product Catalog on desktop (full width)<br>2. Resize browser to tablet width<br>3. Resize to mobile width |
| **Expected Result** | Desktop: 3 product cards per row. Tablet: 2 per row. Mobile: 1 per row. |

#### TC-LWC-017: Search Debounce Behavior
| Field | Value |
|-------|-------|
| **Priority** | Low |
| **Steps** | 1. Rapidly type "Orange" character by character<br>2. Observe network calls (browser dev tools) |
| **Expected Result** | Only one Apex call made after 300ms pause in typing (not one per keystroke). |

---

### 4.7 Permission & Security Testing

#### TC-SEC-001: Field Rep - Read-Only Product Access
| Field | Value |
|-------|-------|
| **Priority** | Critical |
| **Pre-condition** | Logged in as user with only FSCRM_Field_Rep_Products |
| **Steps** | 1. Navigate to Products tab<br>2. Open a Product record<br>3. Attempt to edit any field |
| **Expected Result** | User can view products but cannot create, edit, or delete. Edit buttons not available. |

#### TC-SEC-002: Field Rep - Read-Only Extensions
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. As Field Rep user, view Product Extension records<br>2. Attempt to create new extension |
| **Expected Result** | Can view extensions. Cannot create or edit. New button not available on related list. |

#### TC-SEC-003: Field Rep - Read-Only Price Lists
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. As Field Rep user, view Price List records |
| **Expected Result** | Can view price lists. Cannot create, edit, or delete. |

#### TC-SEC-004: Product Manager - Full CRUD on Products
| Field | Value |
|-------|-------|
| **Priority** | Critical |
| **Steps** | 1. As Product Manager user, create a new Product2 record<br>2. Edit the product<br>3. Verify cannot delete |
| **Expected Result** | Can create and edit products. Delete not permitted (allowDelete=false). ViewAllRecords = true. |

#### TC-SEC-005: Product Manager - CRUD on Extensions
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. As Product Manager, create, edit Product Extension records |
| **Expected Result** | Full create/read/edit access. No delete. ViewAllRecords enabled. |

#### TC-SEC-006: Product Manager - Tab Visibility
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. As Product Manager user, check visible tabs |
| **Expected Result** | Product, Product Categories, and Batch Master tabs are visible. |

#### TC-SEC-007: Field Rep - Tab Visibility
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. As Field Rep user, check visible tabs |
| **Expected Result** | Product and Distributor Stock tabs are visible. |

---

### 4.8 Layout Verification

#### TC-LAY-001: Product2 Layout Structure
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Open any Product record<br>2. Verify layout sections and fields |
| **Expected Result** | Sections: Product Information (Name, Code, Family, IsActive), Description Information, System Information. Related lists: Product Extensions, Price Lists, Batch Master, Distributor Stock. |

#### TC-LAY-002: Product2 - Excluded Buttons
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Open a Product record<br>2. Check available action buttons |
| **Expected Result** | Submit, Change Record Type, and Share buttons are NOT present. Edit and Delete (if permitted) are available. |

#### TC-LAY-003: Product Extension Layout - All Fields Visible
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Open a Product Extension record<br>2. Verify all sections |
| **Expected Result** | Information section: Name, Product, Category, Active, EAN, UPC, HSN/SAC. Packaging & Ordering section: Weight, Weight Unit, Case Size, MOQ. System section: Created/Modified. |

#### TC-LAY-004: Product Extension - Excluded Buttons
| Field | Value |
|-------|-------|
| **Priority** | Low |
| **Steps** | 1. Open a Product Extension record<br>2. Check action buttons |
| **Expected Result** | Submit, Change Owner, and Share buttons are NOT present. |

#### TC-LAY-005: Product Category Layout
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Open a Product Category record |
| **Expected Result** | Information section with Category Code (required), Level (required), Name (required), Owner. System section with Created/Modified. |

#### TC-LAY-006: Price Change Log - Auto-Number Name
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Open a Price Change Log record |
| **Expected Result** | Name field shows auto-generated number (PCL-00001 format). Name field is read-only. |

---

### 4.9 Integration & End-to-End Tests

#### TC-E2E-001: Full Product Lifecycle
| Field | Value |
|-------|-------|
| **Priority** | Critical |
| **Steps** | 1. Create Product Category hierarchy (Category > Sub-Category > Brand)<br>2. Create Product2 record<br>3. Create Product Extension with category, barcodes, weight<br>4. Create Price List entries (MRP, Distributor Price)<br>5. Create Batch Master record<br>6. Create Distributor Stock entry<br>7. Open Product Catalog LWC<br>8. Search for the product<br>9. Click product card to see detail panel |
| **Expected Result** | Full lifecycle works. Detail panel shows all data: extensions, pricing, batch count, stock. |

#### TC-E2E-002: Price Update with Audit Trail
| Field | Value |
|-------|-------|
| **Priority** | Critical |
| **Steps** | 1. Note current price for a product<br>2. Update the Unit Price on Price List<br>3. Check Price Change Log records<br>4. Open Product Catalog and view pricing |
| **Expected Result** | Audit log created. Product Catalog shows updated price. |

#### TC-E2E-003: Stock Dashboard - Distributors with Stock
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Pre-condition** | Distributor stock records exist with Is_Current = true |
| **Steps** | 1. Verify INV_StockDashboardController.getDistributorsWithStock() returns accounts with current stock |
| **Expected Result** | Returns list of Account records that have at least one current Distributor_Stock__c entry. |

#### TC-E2E-004: Category Hierarchy in Catalog
| Field | Value |
|-------|-------|
| **Priority** | High |
| **Steps** | 1. Open Product Catalog<br>2. Expand category tree to all 3 levels<br>3. Select a Brand-level category<br>4. Verify only products in that brand are shown |
| **Expected Result** | Tree shows 3 levels. Filtering by Brand shows only products with extensions linked to that brand category. |

---

### 4.10 Edge Cases & Boundary Tests

#### TC-EDGE-001: Maximum Pagination Limit
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Ensure > 100 products exist<br>2. Browse through all pages in Product Catalog |
| **Expected Result** | Server returns max 100 records per query. Pagination handles correctly. |

#### TC-EDGE-002: Special Characters in Search
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Type `O'Range` or `test'; DELETE` in search box |
| **Expected Result** | Search handles special characters safely (SOQL injection prevention). No errors. Returns products matching the sanitized term or empty results. |

#### TC-EDGE-003: Category Hierarchy Max Depth
| Field | Value |
|-------|-------|
| **Priority** | Low |
| **Steps** | 1. Select a Category-level item in the tree<br>2. Verify all products in sub-categories and brands are included |
| **Expected Result** | Category hierarchy resolved up to 3 levels deep. Products at all nested levels included. |

#### TC-EDGE-004: All Quantities Zero in Stock
| Field | Value |
|-------|-------|
| **Priority** | Low |
| **Steps** | 1. Create stock entry: Opening = 0, Received = 0, Sold = 0, Damaged = 0<br>2. Save |
| **Expected Result** | Record saved. Closing Stock = 0. |

#### TC-EDGE-005: Concurrent Stock Is_Current Updates
| Field | Value |
|-------|-------|
| **Priority** | Medium |
| **Steps** | 1. Create two stock entries for same Account + Product in quick succession, both with Is Current = true |
| **Expected Result** | Only the latest entry has Is_Current = true. Previous entries unmarked. |

---

## 5. Defect Severity Guide

| Severity | Definition | Example |
|----------|-----------|---------|
| **Critical** | System crash, data loss, security breach | Price overlap not prevented, stock miscalculated |
| **High** | Major feature broken, no workaround | Search not working, category filter fails |
| **Medium** | Feature partially broken, workaround exists | Pagination shows wrong count, layout field missing |
| **Low** | Cosmetic, minor UX issue | Button alignment, label typo |

---

## 6. Test Environment Checklist

- [ ] Org has Product Management module deployed
- [ ] Permission sets assigned to test users
- [ ] Test data created per Section 3
- [ ] Browser: Chrome (latest), Firefox (latest), Safari (latest)
- [ ] Lightning Experience enabled
- [ ] Salesforce Mobile App tested (for responsive tests)

---

## 7. Sign-Off

| Role | Name | Date | Status |
|------|------|------|--------|
| QA Lead | | | |
| Dev Lead | | | |
| Product Owner | | | |
