// Script 11: Trade Schemes - Full 4x6 Matrix with Products, Slabs, and Mappings
// Run: sf apex run -f scripts/11_schemes.apex
// Prerequisite: 04_products.apex

// Fetch products
Map<String, Id> prodMap = new Map<String, Id>();
for (Product2 p : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode LIKE 'FF-%' AND IsActive = true]) {
    prodMap.put(p.ProductCode, p.Id);
}

// Fetch product extensions
Map<String, Id> prodExtMap = new Map<String, Id>();
for (Product_Extension__c pe : [SELECT Id, Name FROM Product_Extension__c LIMIT 200]) {
    prodExtMap.put(pe.Name, pe.Id);
}

// Fetch categories
Map<String, Id> catMap = new Map<String, Id>();
for (Product_Category__c pc : [SELECT Id, Category_Code__c FROM Product_Category__c WHERE Level__c = 'Sub-Category']) {
    catMap.put(pc.Category_Code__c, pc.Id);
}

// Get first 6 product extension Ids for scheme materials
List<Id> peIds = new List<Id>(prodExtMap.values());
Id peMaida1kg = peIds.size() > 0 ? peIds[0] : null;
Id peMaida500g = peIds.size() > 1 ? peIds[1] : null;
Id peAtta200g = peIds.size() > 2 ? peIds[2] : null;
Id peAtta1kg = peIds.size() > 3 ? peIds[3] : null;
Id peSooji500g = peIds.size() > 4 ? peIds[4] : null;
Id peSnack1 = peIds.size() > 5 ? peIds[5] : null;

// ── Create Schemes (covering all 4 categories x representative types) ────

List<Scheme__c> schemes = new List<Scheme__c>{
    // ── Scenario 1: Free Products, Same Product (QTY) ────────────────
    new Scheme__c(
        Name = 'Naga Maida Buy 3 Get 1 Free',
        Scheme_Code__c = 'SCH-2026-001',
        Scheme_Category__c = 'Free Products',
        Scheme_Type__c = 'Same Product (QTY)',
        Description__c = 'Buy 3 packs of Naga Maida 1KG, get 1 Naga Maida 200g free',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(3),
        Status__c = 'Active',
        Min_Quantity__c = 3,
        Free_Product_Ext__c = peAtta200g,
        Free_Quantity__c = 1,
        Product_Ext__c = peMaida1kg,
        Budget_Amount__c = 100000,
        Applicable_Channel__c = 'GT',
        Priority__c = 1
    ),

    // ── Scenario 2: Free Products, Same Product (VAL) ────────────────
    new Scheme__c(
        Name = 'Naga Maida MOV Free Product',
        Scheme_Code__c = 'SCH-2026-002',
        Scheme_Category__c = 'Free Products',
        Scheme_Type__c = 'Same Product (VAL)',
        Description__c = 'Meet Rs.1500 MOV on Naga Maida 1KG, get 1 Maida 200g free',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(3),
        Status__c = 'Active',
        MOV__c = 1500,
        Free_Product_Ext__c = peAtta200g,
        Free_Quantity__c = 1,
        Product_Ext__c = peMaida1kg,
        Budget_Amount__c = 80000,
        Applicable_Channel__c = 'GT',
        Priority__c = 2
    ),

    // ── Scenario 3: Discount in %, Assorted Product (QTY) ────────────
    new Scheme__c(
        Name = 'Assorted Products 3% Off',
        Scheme_Code__c = 'SCH-2026-003',
        Scheme_Category__c = 'Discount in %',
        Scheme_Type__c = 'Assorted Product (QTY)',
        Description__c = '3% discount when buying assorted Maida + Sooji products',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(6),
        Status__c = 'Active',
        Discount_Percent__c = 3,
        Budget_Amount__c = 200000,
        Applicable_Channel__c = 'GT',
        Priority__c = 3
    ),

    // ── Scenario 4: Discount in Value, Invoice Qty Based ─────────────
    new Scheme__c(
        Name = 'Invoice Qty Price Discount',
        Scheme_Code__c = 'SCH-2026-004',
        Scheme_Category__c = 'Discount in Value',
        Scheme_Type__c = 'Invoice Qty Based',
        Description__c = 'Rs.200 price discount when invoice qty exceeds 10 KG',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(3),
        Status__c = 'Active',
        Invoice_Qty_Threshold__c = 10,
        Invoice_Qty_UOM__c = 'KG',
        Price_Discount__c = 200,
        Budget_Amount__c = 50000,
        Applicable_Channel__c = 'GT',
        Priority__c = 4
    ),

    // ── Scenario 5: Reward Points, Invoice Val Based ─────────────────
    new Scheme__c(
        Name = 'Invoice Value Reward Points',
        Scheme_Code__c = 'SCH-2026-005',
        Scheme_Category__c = 'Reward Points',
        Scheme_Type__c = 'Invoice Val Based',
        Description__c = 'Earn 300 reward points on invoice value Rs.11,000+',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(6),
        Status__c = 'Active',
        Invoice_Val_Threshold__c = 11000,
        Reward_Points__c = 300,
        Budget_Amount__c = 150000,
        Applicable_Channel__c = 'GT',
        Priority__c = 5,
        Is_Stackable__c = true
    ),

    // ── Scenario 6: Reward Points, Same Product (QTY) ────────────────
    new Scheme__c(
        Name = 'Maida Qty Reward Points',
        Scheme_Code__c = 'SCH-2026-006',
        Scheme_Category__c = 'Reward Points',
        Scheme_Type__c = 'Same Product (QTY)',
        Description__c = 'Earn 300 points buying 3+ packs of Naga Maida 1KG',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(3),
        Status__c = 'Active',
        Min_Quantity__c = 3,
        Reward_Points__c = 300,
        Product_Ext__c = peMaida1kg,
        Budget_Amount__c = 50000,
        Applicable_Channel__c = 'GT',
        Priority__c = 6,
        Is_Stackable__c = true
    ),

    // ── Scenario 7: Slab-based Discount in %, Same Product (QTY) ─────
    new Scheme__c(
        Name = 'Personal Care Volume Discount',
        Scheme_Code__c = 'SCH-2026-007',
        Scheme_Category__c = 'Discount in %',
        Scheme_Type__c = 'Same Product (QTY)',
        Description__c = 'Volume-based slab discounts on personal care range',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(6),
        Status__c = 'Active',
        Budget_Amount__c = 200000,
        Applicable_Channel__c = 'GT',
        Priority__c = 7
    ),

    // ── Modern Trade Draft (not active) ──────────────────────────────
    new Scheme__c(
        Name = 'Modern Trade Combo Offer',
        Scheme_Code__c = 'SCH-2026-008',
        Scheme_Category__c = 'Discount in Value',
        Scheme_Type__c = 'Assorted Product (VAL)',
        Description__c = 'Special combo pricing for Modern Trade outlets',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(1),
        Status__c = 'Draft',
        Budget_Amount__c = 50000,
        Applicable_Channel__c = 'MT',
        Priority__c = 8
    )
};
insert schemes;
System.debug('Inserted schemes: ' + schemes.size());

// Map schemes by code
Map<String, Id> schMap = new Map<String, Id>();
for (Scheme__c s : schemes) {
    schMap.put(s.Scheme_Code__c, s.Id);
}

// ── Scheme Products ──────────────────────────────────────────────────────

List<Scheme_Product__c> schProducts = new List<Scheme_Product__c>();

// Scenario 1: Same Product QTY - buy Maida 1KG
if (peMaida1kg != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-001'),
        Product_Ext__c = peMaida1kg,
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 3));
}
if (peMaida500g != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-001'),
        Product_Ext__c = peMaida500g,
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 4));
}
// Free product
if (peAtta200g != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-001'),
        Product_Ext__c = peAtta200g,
        Is_Buy_Product__c = false, Is_Get_Product__c = true, Min_Quantity__c = 0));
}

// Scenario 3: Assorted Product QTY - Maida + Sooji
if (peMaida1kg != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-003'),
        Product_Ext__c = peMaida1kg,
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 3));
}
if (peSooji500g != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-003'),
        Product_Ext__c = peSooji500g,
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 4));
}

// Scenario 4: Invoice Qty - scheme materials
if (peMaida1kg != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-004'),
        Product_Ext__c = peMaida1kg,
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 1));
}
if (peSooji500g != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-004'),
        Product_Ext__c = peSooji500g,
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 1));
}

// Scenario 5: Invoice Val - scheme materials
if (peMaida1kg != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-005'),
        Product_Ext__c = peMaida1kg,
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 1));
}
if (peSooji500g != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-005'),
        Product_Ext__c = peSooji500g,
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 1));
}

if (!schProducts.isEmpty()) {
    insert schProducts;
    System.debug('Inserted scheme products: ' + schProducts.size());
}

// ── Scheme Slabs (for slab-based scheme SCH-2026-007) ────────────────────

List<Scheme_Slab__c> slabs = new List<Scheme_Slab__c>{
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-007'),
        Slab_Type__c = 'Value', Min_Value__c = 1000, Max_Value__c = 4999,
        Discount_Type__c = 'Percent', Discount_Value__c = 5, Is_Active__c = true),
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-007'),
        Slab_Type__c = 'Value', Min_Value__c = 5000, Max_Value__c = 14999,
        Discount_Type__c = 'Percent', Discount_Value__c = 8, Is_Active__c = true),
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-007'),
        Slab_Type__c = 'Value', Min_Value__c = 15000, Max_Value__c = 999999,
        Discount_Type__c = 'Percent', Discount_Value__c = 12, Is_Active__c = true),

    // Slab for free product scheme (buy 10-49 get 2 free, buy 50+ get 12 free)
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-001'),
        Slab_Type__c = 'Quantity', Min_Quantity__c = 10, Max_Quantity__c = 49,
        Discount_Type__c = 'Free Product', Free_Quantity__c = 2, Is_Active__c = true),
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-001'),
        Slab_Type__c = 'Quantity', Min_Quantity__c = 50, Max_Quantity__c = 999,
        Discount_Type__c = 'Free Product', Free_Quantity__c = 12, Is_Active__c = true)
};
insert slabs;
System.debug('Inserted scheme slabs: ' + slabs.size());

// ── Scheme Mappings (territory-based targeting) ──────────────────────────

List<Scheme_Mapping__c> mappings = new List<Scheme_Mapping__c>{
    new Scheme_Mapping__c(
        Scheme__c = schMap.get('SCH-2026-001'),
        Zone__c = 'TN North',
        Sub_Zone__c = 'Madurai',
        District__c = 'Madurai',
        Area__c = 'Chennai North',
        Customer_Type__c = 'D2R',
        Is_Active__c = true
    ),
    new Scheme_Mapping__c(
        Scheme__c = schMap.get('SCH-2026-005'),
        Zone__c = 'TN North',
        Customer_Type__c = 'D2R',
        Is_Active__c = true
    )
};
insert mappings;
System.debug('Inserted scheme mappings: ' + mappings.size());

System.debug('Schemes setup complete. Schemes: ' + schemes.size() +
    ', Products: ' + schProducts.size() + ', Slabs: ' + slabs.size() +
    ', Mappings: ' + mappings.size());
