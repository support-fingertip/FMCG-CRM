// Script 03: Product Categories - 2-level tree
// Run: sf apex run -f scripts/03_product_category.apex

// Clean up (children first, then parents — self-referencing)
delete [SELECT Id FROM Product_Category__c WHERE Level__c = 'Sub-Category'];
delete [SELECT Id FROM Product_Category__c];
System.debug('Cleaned up Product_Category__c');

// Level 1 categories
List<Product_Category__c> l1 = new List<Product_Category__c>{
    new Product_Category__c(Name = 'Foods', Category_Code__c = 'CAT-FOOD', Level__c = 'Category', Sort_Order__c = 1, Is_Active__c = true, Description__c = 'Packaged and processed food products'),
    new Product_Category__c(Name = 'Beverages', Category_Code__c = 'CAT-BEV', Level__c = 'Category', Sort_Order__c = 2, Is_Active__c = true, Description__c = 'Drinking and refreshment beverages'),
    new Product_Category__c(Name = 'Personal Care', Category_Code__c = 'CAT-PC', Level__c = 'Category', Sort_Order__c = 3, Is_Active__c = true, Description__c = 'Personal hygiene and grooming products'),
    new Product_Category__c(Name = 'Home Care', Category_Code__c = 'CAT-HC', Level__c = 'Category', Sort_Order__c = 4, Is_Active__c = true, Description__c = 'Household cleaning and maintenance products')
};
insert l1;
System.debug('Inserted L1 categories: ' + l1.size());

Map<String, Id> catMap = new Map<String, Id>();
for (Product_Category__c c : l1) {
    catMap.put(c.Category_Code__c, c.Id);
}

// Level 2 sub-categories
List<Product_Category__c> l2 = new List<Product_Category__c>{
    // Foods sub-categories
    new Product_Category__c(Name = 'Snacks', Category_Code__c = 'SUB-SNACK', Level__c = 'Sub-Category', Parent_Category__c = catMap.get('CAT-FOOD'), Sort_Order__c = 1, Is_Active__c = true, Description__c = 'Namkeens, chips, and ready-to-eat snacks'),
    new Product_Category__c(Name = 'Biscuits', Category_Code__c = 'SUB-BISC', Level__c = 'Sub-Category', Parent_Category__c = catMap.get('CAT-FOOD'), Sort_Order__c = 2, Is_Active__c = true, Description__c = 'Cookies, crackers, and baked biscuits'),
    new Product_Category__c(Name = 'Noodles', Category_Code__c = 'SUB-NOODL', Level__c = 'Sub-Category', Parent_Category__c = catMap.get('CAT-FOOD'), Sort_Order__c = 3, Is_Active__c = true, Description__c = 'Instant and packaged noodles and pasta'),
    new Product_Category__c(Name = 'Dairy', Category_Code__c = 'SUB-DAIRY', Level__c = 'Sub-Category', Parent_Category__c = catMap.get('CAT-FOOD'), Sort_Order__c = 4, Is_Active__c = true, Description__c = 'Milk, cheese, yogurt, and dairy derivatives'),
    new Product_Category__c(Name = 'Confectionery', Category_Code__c = 'SUB-CONF', Level__c = 'Sub-Category', Parent_Category__c = catMap.get('CAT-FOOD'), Sort_Order__c = 5, Is_Active__c = true, Description__c = 'Chocolates, candies, and sugar confectionery'),
    // Beverages sub-categories
    new Product_Category__c(Name = 'Juices', Category_Code__c = 'SUB-JUICE', Level__c = 'Sub-Category', Parent_Category__c = catMap.get('CAT-BEV'), Sort_Order__c = 1, Is_Active__c = true, Description__c = 'Fruit juices, nectars, and juice drinks'),
    new Product_Category__c(Name = 'Soft Drinks', Category_Code__c = 'SUB-SODA', Level__c = 'Sub-Category', Parent_Category__c = catMap.get('CAT-BEV'), Sort_Order__c = 2, Is_Active__c = true, Description__c = 'Carbonated beverages and energy drinks'),
    new Product_Category__c(Name = 'Tea & Coffee', Category_Code__c = 'SUB-TEA', Level__c = 'Sub-Category', Parent_Category__c = catMap.get('CAT-BEV'), Sort_Order__c = 3, Is_Active__c = true, Description__c = 'Loose and packaged tea, instant and ground coffee'),
    // Personal Care sub-categories
    new Product_Category__c(Name = 'Hair Care', Category_Code__c = 'SUB-HAIR', Level__c = 'Sub-Category', Parent_Category__c = catMap.get('CAT-PC'), Sort_Order__c = 1, Is_Active__c = true, Description__c = 'Shampoos, conditioners, and hair oils'),
    new Product_Category__c(Name = 'Skin Care', Category_Code__c = 'SUB-SKIN', Level__c = 'Sub-Category', Parent_Category__c = catMap.get('CAT-PC'), Sort_Order__c = 2, Is_Active__c = true, Description__c = 'Moisturizers, face wash, and body lotions'),
    new Product_Category__c(Name = 'Oral Care', Category_Code__c = 'SUB-ORAL', Level__c = 'Sub-Category', Parent_Category__c = catMap.get('CAT-PC'), Sort_Order__c = 3, Is_Active__c = true, Description__c = 'Toothpaste, toothbrushes, and mouthwash'),
    // Home Care sub-categories
    new Product_Category__c(Name = 'Detergents', Category_Code__c = 'SUB-DET', Level__c = 'Sub-Category', Parent_Category__c = catMap.get('CAT-HC'), Sort_Order__c = 1, Is_Active__c = true, Description__c = 'Laundry powders, liquids, and fabric softeners'),
    new Product_Category__c(Name = 'Surface Cleaners', Category_Code__c = 'SUB-CLEAN', Level__c = 'Sub-Category', Parent_Category__c = catMap.get('CAT-HC'), Sort_Order__c = 2, Is_Active__c = true, Description__c = 'Floor cleaners, disinfectants, and glass cleaners')
};
insert l2;
System.debug('Inserted L2 sub-categories: ' + l2.size());

System.debug('Product Category setup complete. Total: ' + (l1.size() + l2.size()));
