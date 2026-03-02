// Script 11: Trade Schemes with Products and Slabs
// Run: sf apex run -f scripts/11_schemes.apex
// Prerequisite: 04_products.apex

// Fetch products
Map<String, Id> prodMap = new Map<String, Id>();
for (Product2 p : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode LIKE 'FF-%' AND IsActive = true]) {
    prodMap.put(p.ProductCode, p.Id);
}

// Fetch categories
Map<String, Id> catMap = new Map<String, Id>();
for (Product_Category__c pc : [SELECT Id, Category_Code__c FROM Product_Category__c WHERE Level__c = 'Sub-Category']) {
    catMap.put(pc.Category_Code__c, pc.Id);
}

// Create Schemes
List<Scheme__c> schemes = new List<Scheme__c>{
    new Scheme__c(
        Name = 'Summer Snacks Bonanza',
        Scheme_Code__c = 'SCH-2026-001',
        Scheme_Type__c = 'Buy X Get Y',
        Description__c = 'Buy 10 packs of any snack, get 2 free',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(3),
        Status__c = 'Active',
        Is_Active__c = true,
        Budget_Amount__c = 100000,
        Applicable_Channel__c = 'GT',
        Priority__c = 1
    ),
    new Scheme__c(
        Name = 'Beverages Flat 10% Off',
        Scheme_Code__c = 'SCH-2026-002',
        Scheme_Type__c = 'Flat Discount Percent',
        Description__c = '10% discount on all beverages for GT channel',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(2),
        Status__c = 'Active',
        Is_Active__c = true,
        Budget_Amount__c = 75000,
        Applicable_Channel__c = 'GT',
        Priority__c = 2
    ),
    new Scheme__c(
        Name = 'Personal Care Volume Discount',
        Scheme_Code__c = 'SCH-2026-003',
        Scheme_Type__c = 'Slab Based',
        Description__c = 'Volume-based slab discounts on personal care range',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(6),
        Status__c = 'Active',
        Is_Active__c = true,
        Budget_Amount__c = 200000,
        Applicable_Channel__c = 'GT',
        Priority__c = 3
    ),
    new Scheme__c(
        Name = 'Modern Trade Combo Offer',
        Scheme_Code__c = 'SCH-2026-004',
        Scheme_Type__c = 'Combo Offer',
        Description__c = 'Special combo pricing for Modern Trade outlets',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(1),
        Status__c = 'Draft',
        Is_Active__c = false,
        Budget_Amount__c = 50000,
        Applicable_Channel__c = 'MT',
        Priority__c = 4
    )
};
insert schemes;
System.debug('Inserted schemes: ' + schemes.size());

// Map schemes by code
Map<String, Id> schMap = new Map<String, Id>();
for (Scheme__c s : schemes) {
    schMap.put(s.Scheme_Code__c, s.Id);
}

// Scheme Products
List<Scheme_Product__c> schProducts = new List<Scheme_Product__c>{
    // Summer Snacks: snack products as buy, same as get
    new Scheme_Product__c(Scheme__c = schMap.get('SCH-2026-001'), Product__c = prodMap.get('FF-SNK-001'), Is_Buy_Product__c = true, Is_Get_Product__c = true, Min_Quantity__c = 10),
    new Scheme_Product__c(Scheme__c = schMap.get('SCH-2026-001'), Product__c = prodMap.get('FF-SNK-002'), Is_Buy_Product__c = true, Is_Get_Product__c = true, Min_Quantity__c = 10),
    // Beverages discount: juice and soda products
    new Scheme_Product__c(Scheme__c = schMap.get('SCH-2026-002'), Product__c = prodMap.get('FF-JUC-001'), Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 1),
    new Scheme_Product__c(Scheme__c = schMap.get('SCH-2026-002'), Product__c = prodMap.get('FF-JUC-002'), Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 1),
    new Scheme_Product__c(Scheme__c = schMap.get('SCH-2026-002'), Product__c = prodMap.get('FF-SOD-001'), Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 1),
    // Personal Care slab: all PC products
    new Scheme_Product__c(Scheme__c = schMap.get('SCH-2026-003'), Product__c = prodMap.get('FF-HAR-001'), Product_Category__c = catMap.get('SUB-HAIR'), Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 1),
    new Scheme_Product__c(Scheme__c = schMap.get('SCH-2026-003'), Product__c = prodMap.get('FF-SKN-001'), Product_Category__c = catMap.get('SUB-SKIN'), Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 1),
    new Scheme_Product__c(Scheme__c = schMap.get('SCH-2026-003'), Product__c = prodMap.get('FF-ORL-001'), Product_Category__c = catMap.get('SUB-ORAL'), Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 1)
};
insert schProducts;
System.debug('Inserted scheme products: ' + schProducts.size());

// Scheme Slabs (for slab-based scheme)
List<Scheme_Slab__c> slabs = new List<Scheme_Slab__c>{
    // Summer Snacks: buy 10 get 2 free
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-001'), Slab_Type__c = 'Quantity', Min_Value__c = 10, Max_Value__c = 49, Discount_Type__c = 'Free Product', Free_Quantity__c = 2),
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-001'), Slab_Type__c = 'Quantity', Min_Value__c = 50, Max_Value__c = 999, Discount_Type__c = 'Free Product', Free_Quantity__c = 12),
    // Beverages: flat 10%
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-002'), Slab_Type__c = 'Value', Min_Value__c = 0, Max_Value__c = 999999, Discount_Type__c = 'Percent', Discount_Value__c = 10),
    // Personal Care slabs
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-003'), Slab_Type__c = 'Value', Min_Value__c = 1000, Max_Value__c = 4999, Discount_Type__c = 'Percent', Discount_Value__c = 5),
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-003'), Slab_Type__c = 'Value', Min_Value__c = 5000, Max_Value__c = 14999, Discount_Type__c = 'Percent', Discount_Value__c = 8),
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-003'), Slab_Type__c = 'Value', Min_Value__c = 15000, Max_Value__c = 999999, Discount_Type__c = 'Percent', Discount_Value__c = 12),
    // Modern Trade combo
    new Scheme_Slab__c(Scheme__c = schMap.get('SCH-2026-004'), Slab_Type__c = 'Value', Min_Value__c = 5000, Max_Value__c = 999999, Discount_Type__c = 'Amount', Discount_Value__c = 500)
};
insert slabs;
System.debug('Inserted scheme slabs: ' + slabs.size());

System.debug('Schemes setup complete. Schemes: ' + schemes.size() + ', Products: ' + schProducts.size() + ', Slabs: ' + slabs.size());
