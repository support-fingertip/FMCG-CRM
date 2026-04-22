// Seed: Assign product categories to accounts based on Outlet_Type__c
// - Grocery → Foods, Beverages
// - Medical → Personal Care
// - Hardware → Home Care
// - General Store → Foods, Beverages, Personal Care
// - Cosmetics, Pan Shop → Personal Care
// - All others (distributors, supermarkets) → all 4 L1 categories

Map<String, Product_Category__c> catByName = new Map<String, Product_Category__c>();
for (Product_Category__c cat : [SELECT Id, Name, Level__c FROM Product_Category__c WHERE Level__c = 'Category' AND Is_Active__c = true]) {
    catByName.put(cat.Name, cat);
}

if (catByName.isEmpty()) {
    System.debug('No L1 categories found. Run 03_product_category.apex first.');
    return;
}

Map<String, List<String>> outletCategoryMap = new Map<String, List<String>>{
    'Grocery' => new List<String>{'Foods', 'Beverages'},
    'Medical' => new List<String>{'Personal Care'},
    'Hardware' => new List<String>{'Home Care'},
    'General Store' => new List<String>{'Foods', 'Beverages', 'Personal Care'},
    'Cosmetics' => new List<String>{'Personal Care'},
    'Pan Shop' => new List<String>{'Personal Care'}
};

List<String> allCategoryNames = new List<String>(catByName.keySet());

// Delete existing mappings to avoid duplicates
delete [SELECT Id FROM Account_Category__c];

List<Account_Category__c> mappings = new List<Account_Category__c>();
for (Account acct : [SELECT Id, Name, Outlet_Type__c FROM Account WHERE Is_Active__c = true]) {
    List<String> categories;
    if (acct.Outlet_Type__c != null && outletCategoryMap.containsKey(acct.Outlet_Type__c)) {
        categories = outletCategoryMap.get(acct.Outlet_Type__c);
    } else {
        categories = allCategoryNames;
    }

    for (String catName : categories) {
        if (catByName.containsKey(catName)) {
            mappings.add(new Account_Category__c(
                Account__c = acct.Id,
                Category__c = catByName.get(catName).Id,
                Is_Active__c = true,
                Effective_From__c = Date.today()
            ));
        }
    }
}

if (!mappings.isEmpty()) {
    insert mappings;
    System.debug('Created ' + mappings.size() + ' Account-Category mappings');
} else {
    System.debug('No accounts found to seed categories');
}
