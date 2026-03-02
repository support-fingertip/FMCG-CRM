// Script 04: Products (Product2 + Product_Extension__c)
// Run: sf apex run -f scripts/04_products.apex
// Prerequisite: 03_product_category.apex

// Fetch sub-categories by code
Map<String, Id> catMap = new Map<String, Id>();
for (Product_Category__c pc : [SELECT Id, Category_Code__c FROM Product_Category__c WHERE Level__c = 'Sub-Category']) {
    catMap.put(pc.Category_Code__c, pc.Id);
}

// Create Product2 records
List<Product2> products = new List<Product2>{
    new Product2(Name = 'Crispy Masala Chips 150g', ProductCode = 'FF-SNK-001', Family = 'Foods', IsActive = true, Description = 'Classic masala flavored potato chips'),
    new Product2(Name = 'Tangy Tomato Chips 150g', ProductCode = 'FF-SNK-002', Family = 'Foods', IsActive = true, Description = 'Tangy tomato flavored chips'),
    new Product2(Name = 'Classic Cream Biscuits 200g', ProductCode = 'FF-BIS-001', Family = 'Foods', IsActive = true, Description = 'Vanilla cream filled biscuits'),
    new Product2(Name = 'Digestive Wheat Biscuits 250g', ProductCode = 'FF-BIS-002', Family = 'Foods', IsActive = true, Description = 'High-fiber wheat biscuits'),
    new Product2(Name = 'Instant Noodles Masala 70g', ProductCode = 'FF-NDL-001', Family = 'Foods', IsActive = true, Description = 'Quick-cook masala noodles'),
    new Product2(Name = 'Daily Fresh Milk 500ml', ProductCode = 'FF-DRY-001', Family = 'Foods', IsActive = true, Description = 'Pasteurized toned milk'),
    new Product2(Name = 'Curd Cup 200g', ProductCode = 'FF-DRY-002', Family = 'Foods', IsActive = true, Description = 'Fresh set curd'),
    new Product2(Name = 'Mango Toffees 200g', ProductCode = 'FF-CNF-001', Family = 'Foods', IsActive = true, Description = 'Mango flavored chewy toffees'),
    new Product2(Name = 'Fresh Mango Juice 1L', ProductCode = 'FF-JUC-001', Family = 'Beverages', IsActive = true, Description = 'Real mango juice from Alphonso mangoes'),
    new Product2(Name = 'Mixed Fruit Juice 1L', ProductCode = 'FF-JUC-002', Family = 'Beverages', IsActive = true, Description = 'Mixed tropical fruit juice'),
    new Product2(Name = 'Cola Fizz 300ml', ProductCode = 'FF-SOD-001', Family = 'Beverages', IsActive = true, Description = 'Carbonated cola drink'),
    new Product2(Name = 'Premium Assam Tea 250g', ProductCode = 'FF-TEA-001', Family = 'Beverages', IsActive = true, Description = 'Premium CTC Assam tea leaves'),
    new Product2(Name = 'Coconut Hair Oil 200ml', ProductCode = 'FF-HAR-001', Family = 'Personal Care', IsActive = true, Description = 'Pure coconut hair oil'),
    new Product2(Name = 'Anti-Dandruff Shampoo 200ml', ProductCode = 'FF-HAR-002', Family = 'Personal Care', IsActive = true, Description = 'Anti-dandruff shampoo with zinc'),
    new Product2(Name = 'Neem Face Wash 100ml', ProductCode = 'FF-SKN-001', Family = 'Personal Care', IsActive = true, Description = 'Neem purifying face wash'),
    new Product2(Name = 'Aloe Moisturizer 100ml', ProductCode = 'FF-SKN-002', Family = 'Personal Care', IsActive = true, Description = 'Aloe vera moisturizing lotion'),
    new Product2(Name = 'Fresh Mint Toothpaste 150g', ProductCode = 'FF-ORL-001', Family = 'Personal Care', IsActive = true, Description = 'Mint flavored fluoride toothpaste'),
    new Product2(Name = 'Power Wash Detergent 1kg', ProductCode = 'FF-DET-001', Family = 'Home Care', IsActive = true, Description = 'Active wash detergent powder'),
    new Product2(Name = 'Liquid Dish Wash 500ml', ProductCode = 'FF-DET-002', Family = 'Home Care', IsActive = true, Description = 'Lemon dish washing liquid'),
    new Product2(Name = 'Floor Cleaner Pine 500ml', ProductCode = 'FF-CLN-001', Family = 'Home Care', IsActive = true, Description = 'Pine fragrance floor cleaner')
};
insert products;
System.debug('Inserted products: ' + products.size());

// Map products by ProductCode
Map<String, Id> prodMap = new Map<String, Id>();
for (Product2 p : products) {
    prodMap.put(p.ProductCode, p.Id);
}

// Product extensions with HSN codes and sub-category mapping
List<Product_Extension__c> extensions = new List<Product_Extension__c>{
    new Product_Extension__c(Product__c = prodMap.get('FF-SNK-001'), Product_Category__c = catMap.get('SUB-SNACK'), HSN_SAC_Code__c = '20052000', Weight__c = 150, Weight_Unit__c = 'g', Case_Size__c = 48, Min_Order_Qty__c = 12, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-SNK-002'), Product_Category__c = catMap.get('SUB-SNACK'), HSN_SAC_Code__c = '20052000', Weight__c = 150, Weight_Unit__c = 'g', Case_Size__c = 48, Min_Order_Qty__c = 12, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-BIS-001'), Product_Category__c = catMap.get('SUB-BISC'), HSN_SAC_Code__c = '19053200', Weight__c = 200, Weight_Unit__c = 'g', Case_Size__c = 60, Min_Order_Qty__c = 12, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-BIS-002'), Product_Category__c = catMap.get('SUB-BISC'), HSN_SAC_Code__c = '19053200', Weight__c = 250, Weight_Unit__c = 'g', Case_Size__c = 48, Min_Order_Qty__c = 12, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-NDL-001'), Product_Category__c = catMap.get('SUB-NOODL'), HSN_SAC_Code__c = '19023010', Weight__c = 70, Weight_Unit__c = 'g', Case_Size__c = 120, Min_Order_Qty__c = 24, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-DRY-001'), Product_Category__c = catMap.get('SUB-DAIRY'), HSN_SAC_Code__c = '04011000', Weight__c = 500, Weight_Unit__c = 'ml', Case_Size__c = 20, Min_Order_Qty__c = 10, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-DRY-002'), Product_Category__c = catMap.get('SUB-DAIRY'), HSN_SAC_Code__c = '04031000', Weight__c = 200, Weight_Unit__c = 'g', Case_Size__c = 24, Min_Order_Qty__c = 12, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-CNF-001'), Product_Category__c = catMap.get('SUB-CONF'), HSN_SAC_Code__c = '17049090', Weight__c = 200, Weight_Unit__c = 'g', Case_Size__c = 60, Min_Order_Qty__c = 12, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-JUC-001'), Product_Category__c = catMap.get('SUB-JUICE'), HSN_SAC_Code__c = '20098990', Weight__c = 1000, Weight_Unit__c = 'ml', Case_Size__c = 12, Min_Order_Qty__c = 6, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-JUC-002'), Product_Category__c = catMap.get('SUB-JUICE'), HSN_SAC_Code__c = '20098990', Weight__c = 1000, Weight_Unit__c = 'ml', Case_Size__c = 12, Min_Order_Qty__c = 6, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-SOD-001'), Product_Category__c = catMap.get('SUB-SODA'), HSN_SAC_Code__c = '22021010', Weight__c = 300, Weight_Unit__c = 'ml', Case_Size__c = 24, Min_Order_Qty__c = 24, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-TEA-001'), Product_Category__c = catMap.get('SUB-TEA'), HSN_SAC_Code__c = '09021000', Weight__c = 250, Weight_Unit__c = 'g', Case_Size__c = 24, Min_Order_Qty__c = 6, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-HAR-001'), Product_Category__c = catMap.get('SUB-HAIR'), HSN_SAC_Code__c = '33051000', Weight__c = 200, Weight_Unit__c = 'ml', Case_Size__c = 36, Min_Order_Qty__c = 6, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-HAR-002'), Product_Category__c = catMap.get('SUB-HAIR'), HSN_SAC_Code__c = '33051000', Weight__c = 200, Weight_Unit__c = 'ml', Case_Size__c = 24, Min_Order_Qty__c = 6, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-SKN-001'), Product_Category__c = catMap.get('SUB-SKIN'), HSN_SAC_Code__c = '33049990', Weight__c = 100, Weight_Unit__c = 'ml', Case_Size__c = 36, Min_Order_Qty__c = 6, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-SKN-002'), Product_Category__c = catMap.get('SUB-SKIN'), HSN_SAC_Code__c = '33049990', Weight__c = 100, Weight_Unit__c = 'ml', Case_Size__c = 36, Min_Order_Qty__c = 6, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-ORL-001'), Product_Category__c = catMap.get('SUB-ORAL'), HSN_SAC_Code__c = '33061000', Weight__c = 150, Weight_Unit__c = 'g', Case_Size__c = 48, Min_Order_Qty__c = 12, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-DET-001'), Product_Category__c = catMap.get('SUB-DET'), HSN_SAC_Code__c = '34022090', Weight__c = 1000, Weight_Unit__c = 'g', Case_Size__c = 12, Min_Order_Qty__c = 6, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-DET-002'), Product_Category__c = catMap.get('SUB-DET'), HSN_SAC_Code__c = '34022090', Weight__c = 500, Weight_Unit__c = 'ml', Case_Size__c = 24, Min_Order_Qty__c = 6, Is_Active__c = true),
    new Product_Extension__c(Product__c = prodMap.get('FF-CLN-001'), Product_Category__c = catMap.get('SUB-CLEAN'), HSN_SAC_Code__c = '34022090', Weight__c = 500, Weight_Unit__c = 'ml', Case_Size__c = 24, Min_Order_Qty__c = 6, Is_Active__c = true)
};
insert extensions;
System.debug('Inserted product extensions: ' + extensions.size());

System.debug('Products setup complete. Total: ' + (products.size() + extensions.size()));
