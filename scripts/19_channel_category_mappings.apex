// ============================================================
// Script 19: Channel & Category Mapping Data (Additive Only)
// Populates Channels__c on Products/Employees and creates
// Account_Category__c + Employee_Category__c junction records.
//
// SAFE TO RUN ON EXISTING DATA — does not delete or modify
// existing records. Skips records that already have values set.
//
// Run via: sf apex run --file scripts/19_channel_category_mappings.apex
// ============================================================

System.debug('═══════════════════════════════════════════');
System.debug('STARTING CHANNEL & CATEGORY MAPPING SEED');
System.debug('═══════════════════════════════════════════');

Integer created = 0;
Integer updated = 0;

// ═══════════════════════════════════════════════════════════
// PART 1: Populate Channels__c on Products
// All products get GT;MT;E-Commerce by default
// ═══════════════════════════════════════════════════════════

List<Product_Extension__c> prodsToUpdate = new List<Product_Extension__c>();
for (Product_Extension__c p : [SELECT Id, Channels__c FROM Product_Extension__c WHERE Is_Active__c = true]) {
    if (String.isBlank(p.Channels__c)) {
        p.Channels__c = 'GT;MT;E-Commerce';
        prodsToUpdate.add(p);
    }
}
if (!prodsToUpdate.isEmpty()) {
    update prodsToUpdate;
    updated += prodsToUpdate.size();
    System.debug('✓ Set Channels on ' + prodsToUpdate.size() + ' products (GT;MT;E-Commerce)');
} else {
    System.debug('· Products already have Channels set — skipped');
}

// ═══════════════════════════════════════════════════════════
// PART 2: Populate Channels__c on Employees
// All employees get GT;MT;E-Commerce by default
// ═══════════════════════════════════════════════════════════

List<Employee__c> empsToUpdate = new List<Employee__c>();
for (Employee__c e : [SELECT Id, Channels__c FROM Employee__c WHERE Is_Active__c = true]) {
    if (String.isBlank(e.Channels__c)) {
        e.Channels__c = 'GT;MT;E-Commerce';
        empsToUpdate.add(e);
    }
}
if (!empsToUpdate.isEmpty()) {
    update empsToUpdate;
    updated += empsToUpdate.size();
    System.debug('✓ Set Channels on ' + empsToUpdate.size() + ' employees (GT;MT;E-Commerce)');
} else {
    System.debug('· Employees already have Channels set — skipped');
}

// ═══════════════════════════════════════════════════════════
// PART 3: Create Account ↔ Category junction records
// Maps accounts to L1 categories based on Outlet_Type__c
// ═══════════════════════════════════════════════════════════

// Load L1 categories
Map<String, Id> catByName = new Map<String, Id>();
for (Product_Category__c cat : [
    SELECT Id, Name FROM Product_Category__c
    WHERE Level__c = 'Category' AND Is_Active__c = true
]) {
    catByName.put(cat.Name, cat.Id);
}

if (catByName.isEmpty()) {
    System.debug('✗ No L1 categories found — skipping Account Category mappings');
} else {
    // Define which categories each outlet type deals in
    Map<String, List<String>> outletCatMap = new Map<String, List<String>>{
        'Grocery'       => new List<String>{'Foods', 'Beverages'},
        'General Store' => new List<String>{'Foods', 'Beverages', 'Personal Care'},
        'Medical'       => new List<String>{'Personal Care'},
        'Hardware'      => new List<String>{'Home Care'},
        'Cosmetics'     => new List<String>{'Personal Care'},
        'Pan Shop'      => new List<String>{'Personal Care'}
    };
    List<String> allCatNames = new List<String>(catByName.keySet());

    // Check which mappings already exist to avoid duplicates
    Set<String> existingKeys = new Set<String>();
    for (Account_Category__c existing : [
        SELECT Account__c, Category__c FROM Account_Category__c WHERE Is_Active__c = true
    ]) {
        existingKeys.add(String.valueOf(existing.Account__c) + ':' + String.valueOf(existing.Category__c));
    }

    List<Account_Category__c> acctMappings = new List<Account_Category__c>();
    for (Account acct : [SELECT Id, Name, Outlet_Type__c, Type FROM Account WHERE Is_Active__c = true]) {
        // Determine categories for this account
        List<String> categories;
        if (acct.Outlet_Type__c != null && outletCatMap.containsKey(acct.Outlet_Type__c)) {
            categories = outletCatMap.get(acct.Outlet_Type__c);
        } else {
            // Distributors, Super Stockists, Modern Trade → all categories
            categories = allCatNames;
        }

        for (String catName : categories) {
            if (!catByName.containsKey(catName)) continue;
            Id catId = catByName.get(catName);
            String key = String.valueOf(acct.Id) + ':' + String.valueOf(catId);
            if (existingKeys.contains(key)) continue;

            acctMappings.add(new Account_Category__c(
                Account__c = acct.Id,
                Category__c = catId,
                Is_Active__c = true,
                Effective_From__c = Date.today()
            ));
            existingKeys.add(key);
        }
    }

    if (!acctMappings.isEmpty()) {
        insert acctMappings;
        created += acctMappings.size();
        System.debug('✓ Created ' + acctMappings.size() + ' Account–Category mappings');
    } else {
        System.debug('· Account–Category mappings already exist — skipped');
    }
}

// ═══════════════════════════════════════════════════════════
// PART 4: Create Employee ↔ Category junction records
// All employees get all 4 L1 categories (Primary)
// ═══════════════════════════════════════════════════════════

if (catByName.isEmpty()) {
    System.debug('✗ No L1 categories found — skipping Employee Category mappings');
} else {
    // Check existing to avoid duplicates
    Set<String> existingEmpKeys = new Set<String>();
    for (Employee_Category__c existing : [
        SELECT Employee__c, Category__c FROM Employee_Category__c WHERE Is_Active__c = true
    ]) {
        existingEmpKeys.add(String.valueOf(existing.Employee__c) + ':' + String.valueOf(existing.Category__c));
    }

    List<Employee_Category__c> empMappings = new List<Employee_Category__c>();
    for (Employee__c emp : [SELECT Id, Employee_Code__c FROM Employee__c WHERE Is_Active__c = true]) {
        for (String catName : catByName.keySet()) {
            Id catId = catByName.get(catName);
            String key = String.valueOf(emp.Id) + ':' + String.valueOf(catId);
            if (existingEmpKeys.contains(key)) continue;

            empMappings.add(new Employee_Category__c(
                Employee__c = emp.Id,
                Category__c = catId,
                Is_Active__c = true,
                Responsibility_Type__c = 'Primary',
                Effective_From__c = Date.today()
            ));
            existingEmpKeys.add(key);
        }
    }

    if (!empMappings.isEmpty()) {
        insert empMappings;
        created += empMappings.size();
        System.debug('✓ Created ' + empMappings.size() + ' Employee–Category mappings');
    } else {
        System.debug('· Employee–Category mappings already exist — skipped');
    }
}

// ═══════════════════════════════════════════════════════════
// SUMMARY
// ═══════════════════════════════════════════════════════════

System.debug('');
System.debug('═══════════════════════════════════════════');
System.debug('SEED COMPLETE');
System.debug('  Records updated: ' + updated);
System.debug('  Records created: ' + created);
System.debug('═══════════════════════════════════════════');
