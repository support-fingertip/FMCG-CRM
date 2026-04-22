// Seed: Assign all L1 categories to all active employees
// All employees get all 4 categories with Responsibility_Type = Primary
// Narrow per business needs post-seed.

List<Product_Category__c> l1Categories = [
    SELECT Id, Name FROM Product_Category__c
    WHERE Level__c = 'Category' AND Is_Active__c = true
    ORDER BY Sort_Order__c, Name
];

if (l1Categories.isEmpty()) {
    System.debug('No L1 categories found. Run 03_product_category.apex first.');
    return;
}

// Delete existing mappings to avoid duplicates
delete [SELECT Id FROM Employee_Category__c];

List<Employee_Category__c> mappings = new List<Employee_Category__c>();
for (Employee__c emp : [SELECT Id, Employee_Code__c FROM Employee__c WHERE Is_Active__c = true]) {
    for (Product_Category__c cat : l1Categories) {
        mappings.add(new Employee_Category__c(
            Employee__c = emp.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Responsibility_Type__c = 'Primary',
            Effective_From__c = Date.today()
        ));
    }
}

if (!mappings.isEmpty()) {
    insert mappings;
    System.debug('Created ' + mappings.size() + ' Employee-Category mappings (' +
                 [SELECT COUNT() FROM Employee__c WHERE Is_Active__c = true] + ' employees × ' +
                 l1Categories.size() + ' categories)');
} else {
    System.debug('No employees found to seed categories');
}
