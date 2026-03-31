// Script 11: Trade Schemes - Full 4x6 Matrix with Products, Slabs, and Mappings
// Run: sf apex run -f scripts/11_schemes.apex
// Prerequisite: 04_products.apex, 03_product_category.apex

// Clean up existing scheme data (child objects first, then parent)
delete [SELECT Id FROM Scheme_Mapping__c LIMIT 10000];
delete [SELECT Id FROM Scheme_Slab__c LIMIT 10000];
delete [SELECT Id FROM Scheme_Product__c LIMIT 10000];
delete [SELECT Id FROM Scheme__c LIMIT 10000];
System.debug('Cleaned up existing scheme data');

// Fetch product extensions by SKU Code
Map<String, Id> peMap = new Map<String, Id>();
for (Product_Extension__c pe : [SELECT Id, SKU_Code__c FROM Product_Extension__c WHERE Is_Active__c = true AND SKU_Code__c LIKE 'FF-%']) {
    peMap.put(pe.SKU_Code__c, pe.Id);
}

// Fetch categories
Map<String, Id> catMap = new Map<String, Id>();
for (Product_Category__c pc : [SELECT Id, Category_Code__c FROM Product_Category__c WHERE Level__c = 'Sub-Category']) {
    catMap.put(pc.Category_Code__c, pc.Id);
}

// Fetch UOMs for Base_UOM__c
Map<String, Id> uomMap = new Map<String, Id>();
for (UOM__c u : [SELECT Id, UOM_Code__c FROM UOM__c WHERE Is_Active__c = true]) {
    uomMap.put(u.UOM_Code__c, u.Id);
}

// Product references for scheme materials
Id peChips150 = peMap.get('FF-SNK-001');    // Crispy Masala Chips 150g
Id peBiscuit200 = peMap.get('FF-BIS-001');  // Classic Cream Biscuits 200g
Id peNoodles70 = peMap.get('FF-NDL-001');   // Instant Noodles Masala 70g
Id peJuice1L = peMap.get('FF-JUC-001');     // Fresh Mango Juice 1L
Id peDetergent1kg = peMap.get('FF-DET-001');// Power Wash Detergent 1kg
Id peShampoo200 = peMap.get('FF-HAR-002');  // Anti-Dandruff Shampoo 200ml
Id peChips75 = peMap.get('FF-SNK-003');     // Classic Salted Chips 75g (free product)
Id peToffee200 = peMap.get('FF-CNF-001');   // Mango Toffees 200g (free product)

// ── Create Schemes (covering all 4 categories x representative types) ────

List<Scheme__c> schemes = new List<Scheme__c>{
    // ── Scenario 1: Free Products, Same Product (QTY) ────────────────
    new Scheme__c(
        Name = 'Chips Buy 3 Get 1 Free',
        Scheme_Code__c = 'SCH-2026-001',
        Scheme_Category__c = 'Free Products',
        Scheme_Type__c = 'Same Product (QTY)',
        Description__c = 'Buy 3 packs of Crispy Masala Chips 150g, get 1 Classic Salted Chips 75g free',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(3),
        Status__c = 'Active',
        Min_Quantity__c = 3,
        Free_Product_Ext__c = peChips75,
        Free_Quantity__c = 1,
        Product_Ext__c = peChips150,
        Product_Category__c = catMap.get('SUB-SNACK'),
        Budget_Amount__c = 100000,
        Applicable_Channel__c = 'GT',
        Channel__c = 'GT',
        Applicable_Outlet_Type__c = 'Grocery;General Store',
        Base_UOM__c = uomMap.get('PCS'),
        Max_Usage_Per_Customer__c = 5,
        Priority__c = 1
    ),

    // ── Scenario 2: Free Products, Same Product (VAL) ────────────────
    new Scheme__c(
        Name = 'Biscuits MOV Free Product',
        Scheme_Code__c = 'SCH-2026-002',
        Scheme_Category__c = 'Free Products',
        Scheme_Type__c = 'Same Product (VAL)',
        Description__c = 'Meet Rs.500 MOV on Classic Cream Biscuits, get 1 Mango Toffees free',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(3),
        Status__c = 'Active',
        MOV__c = 500,
        Free_Product_Ext__c = peToffee200,
        Free_Quantity__c = 1,
        Product_Ext__c = peBiscuit200,
        Product_Category__c = catMap.get('SUB-BISC'),
        Budget_Amount__c = 80000,
        Applicable_Channel__c = 'GT',
        Channel__c = 'GT',
        Applicable_Outlet_Type__c = 'Grocery;General Store',
        Base_UOM__c = uomMap.get('PCS'),
        Max_Usage_Per_Customer__c = 3,
        Priority__c = 2
    ),

    // ── Scenario 3: Discount in %, Assorted Product (QTY) ────────────
    new Scheme__c(
        Name = 'Snacks & Noodles 3% Off',
        Scheme_Code__c = 'SCH-2026-003',
        Scheme_Category__c = 'Discount in %',
        Scheme_Type__c = 'Assorted Product (QTY)',
        Description__c = '3% discount when buying assorted Chips + Noodles products',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(6),
        Status__c = 'Active',
        Discount_Percent__c = 3,
        Max_Discount_Cap__c = 500,
        Product_Category__c = catMap.get('SUB-SNACK'),
        Budget_Amount__c = 200000,
        Applicable_Channel__c = 'GT',
        Channel__c = 'GT',
        Base_UOM__c = uomMap.get('PCS'),
        Priority__c = 3
    ),

    // ── Scenario 4: Discount in Value, Invoice Qty Based ─────────────
    new Scheme__c(
        Name = 'Detergent Invoice Qty Discount',
        Scheme_Code__c = 'SCH-2026-004',
        Scheme_Category__c = 'Discount in Value',
        Scheme_Type__c = 'Invoice Qty Based',
        Description__c = 'Rs.200 price discount when invoice qty exceeds 10 KG of detergent',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(3),
        Status__c = 'Active',
        Invoice_Qty_Threshold__c = 10,
        Invoice_Qty_UOM__c = 'KG',
        Price_Discount__c = 200,
        Max_Discount_Cap__c = 200,
        Product_Category__c = catMap.get('SUB-DET'),
        Budget_Amount__c = 50000,
        Applicable_Channel__c = 'GT',
        Channel__c = 'GT',
        Base_UOM__c = uomMap.get('KG'),
        Priority__c = 4
    ),

    // ── Scenario 5: Reward Points, Invoice Val Based ─────────────────
    new Scheme__c(
        Name = 'Invoice Value Reward Points',
        Scheme_Code__c = 'SCH-2026-005',
        Scheme_Category__c = 'Reward Points',
        Scheme_Type__c = 'Invoice Val Based',
        Description__c = 'Earn 300 reward points on invoice value Rs.5,000+',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(6),
        Status__c = 'Active',
        Invoice_Val_Threshold__c = 5000,
        Reward_Points__c = 300,
        Budget_Amount__c = 150000,
        Applicable_Channel__c = 'GT',
        Channel__c = 'All',
        Applicable_Outlet_Type__c = 'Grocery;General Store;Medical;Hardware',
        Priority__c = 5,
        Is_Stackable__c = true
    ),

    // ── Scenario 6: Reward Points, Same Product (QTY) ────────────────
    new Scheme__c(
        Name = 'Juice Qty Reward Points',
        Scheme_Code__c = 'SCH-2026-006',
        Scheme_Category__c = 'Reward Points',
        Scheme_Type__c = 'Same Product (QTY)',
        Description__c = 'Earn 300 points buying 6+ packs of Fresh Mango Juice 1L',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(3),
        Status__c = 'Active',
        Min_Quantity__c = 6,
        Reward_Points__c = 300,
        Product_Ext__c = peJuice1L,
        Budget_Amount__c = 50000,
        Applicable_Channel__c = 'GT',
        Channel__c = 'GT',
        Base_UOM__c = uomMap.get('PCS'),
        Max_Usage_Per_Customer__c = 10,
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
        Max_Discount_Cap__c = 2000,
        Budget_Amount__c = 200000,
        Applicable_Channel__c = 'GT',
        Channel__c = 'GT',
        Base_UOM__c = uomMap.get('PCS'),
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
        Discount_Amount__c = 100,
        Max_Discount_Cap__c = 1000,
        Budget_Amount__c = 50000,
        Applicable_Channel__c = 'MT',
        Channel__c = 'MT',
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

// Scenario 1: Buy Chips 150g, get Chips 75g free
if (peChips150 != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-001'),
        Product_Ext__c = peChips150, Product_Category__c = catMap.get('SUB-SNACK'),
        Product_Classification__c = 'Must Sell',
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 3));
}
if (peChips75 != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-001'),
        Product_Ext__c = peChips75, Product_Category__c = catMap.get('SUB-SNACK'),
        Is_Buy_Product__c = false, Is_Get_Product__c = true, Min_Quantity__c = 0));
}

// Scenario 2: Buy Biscuits, get Toffees free
if (peBiscuit200 != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-002'),
        Product_Ext__c = peBiscuit200, Product_Category__c = catMap.get('SUB-BISC'),
        Product_Classification__c = 'Focused Sell',
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 20));
}
if (peToffee200 != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-002'),
        Product_Ext__c = peToffee200, Product_Category__c = catMap.get('SUB-CONF'),
        Is_Buy_Product__c = false, Is_Get_Product__c = true, Min_Quantity__c = 0));
}

// Scenario 3: Assorted Chips + Noodles
if (peChips150 != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-003'),
        Product_Ext__c = peChips150, Product_Category__c = catMap.get('SUB-SNACK'),
        Product_Classification__c = 'Must Sell',
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 3));
}
if (peNoodles70 != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-003'),
        Product_Ext__c = peNoodles70, Product_Category__c = catMap.get('SUB-NOODL'),
        Product_Classification__c = 'Must Sell',
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 4));
}

// Scenario 4: Invoice Qty - detergent
if (peDetergent1kg != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-004'),
        Product_Ext__c = peDetergent1kg, Product_Category__c = catMap.get('SUB-DET'),
        Product_Classification__c = 'Must Sell',
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 1));
}

// Scenario 5: Invoice Val - all products qualify (no specific product mapping needed)

// Scenario 6: Juice reward points
if (peJuice1L != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-006'),
        Product_Ext__c = peJuice1L, Product_Category__c = catMap.get('SUB-JUICE'),
        Product_Classification__c = 'Focused Sell',
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 6));
}

// Scenario 7: Personal care products for slab discount
if (peShampoo200 != null) {
    schProducts.add(new Scheme_Product__c(
        Scheme__c = schMap.get('SCH-2026-007'),
        Product_Ext__c = peShampoo200, Product_Category__c = catMap.get('SUB-HAIR'),
        Product_Classification__c = 'Focused Sell',
        Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 1));
}

if (!schProducts.isEmpty()) {
    insert schProducts;
    System.debug('Inserted scheme products: ' + schProducts.size());
}

// ── Scheme Slabs (for slab-based schemes) ────────────────────────────────

List<Scheme_Slab__c> slabs = new List<Scheme_Slab__c>{
    // Value-based slabs for Personal Care Volume Discount (SCH-2026-007)
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-007'),
        Slab_Type__c = 'Value', Min_Value__c = 1000, Max_Value__c = 4999,
        Discount_Type__c = 'Percent', Discount_Value__c = 5, Discount_Percent__c = 5, Is_Active__c = true),
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-007'),
        Slab_Type__c = 'Value', Min_Value__c = 5000, Max_Value__c = 14999,
        Discount_Type__c = 'Percent', Discount_Value__c = 8, Discount_Percent__c = 8, Is_Active__c = true),
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-007'),
        Slab_Type__c = 'Value', Min_Value__c = 15000, Max_Value__c = 999999,
        Discount_Type__c = 'Percent', Discount_Value__c = 12, Discount_Percent__c = 12, Is_Active__c = true),

    // Quantity-based slabs for Chips Buy 3 Get 1 Free (SCH-2026-001)
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-001'),
        Slab_Type__c = 'Quantity', Min_Quantity__c = 10, Max_Quantity__c = 49,
        Discount_Type__c = 'Free Product', Free_Quantity__c = 2,
        Free_Product_Ext__c = peChips75, Is_Active__c = true),
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-001'),
        Slab_Type__c = 'Quantity', Min_Quantity__c = 50, Max_Quantity__c = 999,
        Discount_Type__c = 'Free Product', Free_Quantity__c = 12,
        Free_Product_Ext__c = peChips75, Is_Active__c = true),

    // Quantity-based slabs for Invoice Val Reward Points (SCH-2026-005)
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-005'),
        Slab_Type__c = 'Value', Min_Value__c = 5000, Max_Value__c = 9999,
        Discount_Type__c = 'Reward Points', Reward_Points__c = 300, Is_Active__c = true),
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-005'),
        Slab_Type__c = 'Value', Min_Value__c = 10000, Max_Value__c = 999999,
        Discount_Type__c = 'Reward Points', Reward_Points__c = 750, Is_Active__c = true)
};
insert slabs;
System.debug('Inserted scheme slabs: ' + slabs.size());

// ── Scheme Mappings (territory-based targeting) ──────────────────────────

// Fetch territories for mapping
Map<String, Id> terrMap = new Map<String, Id>();
for (Territory_Master__c t : [SELECT Id, Territory_Code__c FROM Territory_Master__c WHERE Is_Active__c = true]) {
    if (t.Territory_Code__c != null) terrMap.put(t.Territory_Code__c, t.Id);
}

// Customer_Type__c now aligns with Account Record Types:
// Retailer, Distributor, Super Stockist, Modern Trade
List<Scheme_Mapping__c> mappings = new List<Scheme_Mapping__c>{
    new Scheme_Mapping__c(
        Scheme__c = schMap.get('SCH-2026-001'),
        Territory__c = terrMap.containsKey('TER-DEL-001') ? terrMap.get('TER-DEL-001') : null,
        Zone__c = 'North', Sub_Zone__c = 'North-1',
        Area__c = 'Delhi NCR', District__c = 'Central Delhi',
        Customer_Type__c = 'Retailer',
        Is_Active__c = true
    ),
    new Scheme_Mapping__c(
        Scheme__c = schMap.get('SCH-2026-001'),
        Territory__c = terrMap.containsKey('TER-MUM-001') ? terrMap.get('TER-MUM-001') : null,
        Zone__c = 'West', Sub_Zone__c = 'West-1',
        Area__c = 'Mumbai Metro', District__c = 'Mumbai City',
        Customer_Type__c = 'Retailer',
        Is_Active__c = true
    ),
    new Scheme_Mapping__c(
        Scheme__c = schMap.get('SCH-2026-005'),
        Territory__c = terrMap.containsKey('TER-CHN-001') ? terrMap.get('TER-CHN-001') : null,
        Zone__c = 'South', Sub_Zone__c = 'South-1',
        District__c = 'Chennai',
        Customer_Type__c = 'Retailer',
        Is_Active__c = true
    ),
    new Scheme_Mapping__c(
        Scheme__c = schMap.get('SCH-2026-005'),
        Territory__c = terrMap.containsKey('TER-KOL-001') ? terrMap.get('TER-KOL-001') : null,
        Zone__c = 'East', Sub_Zone__c = 'East-1',
        District__c = 'Kolkata',
        Customer_Type__c = 'Distributor',
        Is_Active__c = true
    ),
    new Scheme_Mapping__c(
        Scheme__c = schMap.get('SCH-2026-003'),
        Territory__c = terrMap.containsKey('TER-BLR-001') ? terrMap.get('TER-BLR-001') : null,
        Zone__c = 'South', Sub_Zone__c = 'South-2',
        Area__c = 'Bangalore Urban', District__c = 'Bangalore Urban',
        Is_Active__c = true
    ),
    // Additional mappings for broader coverage
    new Scheme_Mapping__c(
        Scheme__c = schMap.get('SCH-2026-004'),
        Territory__c = terrMap.containsKey('TER-DEL-001') ? terrMap.get('TER-DEL-001') : null,
        Zone__c = 'North', Sub_Zone__c = 'North-1',
        Customer_Type__c = 'Retailer',
        Is_Active__c = true
    ),
    new Scheme_Mapping__c(
        Scheme__c = schMap.get('SCH-2026-007'),
        Territory__c = terrMap.containsKey('TER-MUM-001') ? terrMap.get('TER-MUM-001') : null,
        Zone__c = 'West', Sub_Zone__c = 'West-1',
        Customer_Type__c = 'Retailer',
        Is_Active__c = true
    )
};
insert mappings;
System.debug('Inserted scheme mappings: ' + mappings.size());

System.debug('Schemes setup complete. Schemes: ' + schemes.size() +
    ', Products: ' + schProducts.size() + ', Slabs: ' + slabs.size() +
    ', Mappings: ' + mappings.size());
