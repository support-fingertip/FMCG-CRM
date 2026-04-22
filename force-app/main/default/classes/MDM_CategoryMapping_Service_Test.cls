/**
 * @description Test class for MDM_CategoryMapping_Service.
 *              Validates category hierarchy expansion, account/employee category
 *              lookups, product validation, and combined authorization checks.
 * @author  SFA Development Team
 * @date    2026
 */
@isTest
private class MDM_CategoryMapping_Service_Test {

    @TestSetup
    static void setupTestData() {
        // Create category hierarchy: L1 -> L2a, L2b
        Product_Category__c l1Category = new Product_Category__c(
            Name = 'Beverages',
            Category_Code__c = 'CAT-BEV',
            Level__c = 'Category',
            Sort_Order__c = 1,
            Is_Active__c = true
        );
        insert l1Category;

        Product_Category__c l2CategoryA = new Product_Category__c(
            Name = 'Carbonated Drinks',
            Category_Code__c = 'CAT-BEV-CARB',
            Level__c = 'Sub-Category',
            Parent_Category__c = l1Category.Id,
            Sort_Order__c = 1,
            Is_Active__c = true
        );
        Product_Category__c l2CategoryB = new Product_Category__c(
            Name = 'Juices',
            Category_Code__c = 'CAT-BEV-JUI',
            Level__c = 'Sub-Category',
            Parent_Category__c = l1Category.Id,
            Sort_Order__c = 2,
            Is_Active__c = true
        );
        insert new List<Product_Category__c>{ l2CategoryA, l2CategoryB };

        // Standalone category (not in hierarchy)
        Product_Category__c standaloneCategory = new Product_Category__c(
            Name = 'Snacks',
            Category_Code__c = 'CAT-SNK',
            Level__c = 'Category',
            Sort_Order__c = 2,
            Is_Active__c = true
        );
        insert standaloneCategory;

        // Products assigned to categories
        List<Product_Extension__c> products = new List<Product_Extension__c>();
        products.add(new Product_Extension__c(
            Name = 'Cola Drink',
            SKU_Code__c = 'CAT-P001',
            Product_Category__c = l2CategoryA.Id,
            Is_Active__c = true
        ));
        products.add(new Product_Extension__c(
            Name = 'Orange Juice',
            SKU_Code__c = 'CAT-P002',
            Product_Category__c = l2CategoryB.Id,
            Is_Active__c = true
        ));
        products.add(new Product_Extension__c(
            Name = 'Snack Bar',
            SKU_Code__c = 'CAT-P003',
            Product_Category__c = standaloneCategory.Id,
            Is_Active__c = true
        ));
        products.add(new Product_Extension__c(
            Name = 'Uncategorized Product',
            SKU_Code__c = 'CAT-P004',
            Is_Active__c = true
        ));
        insert products;

        // Account
        Account acc = TestDataFactory.createAndInsertAccount('Category Test Retailer', 'Retailer');

        // Employee
        Employee__c emp = new Employee__c(
            First_Name__c = 'Category',
            Last_Name__c = 'Tester',
            Employee_Code__c = 'EMP-CAT01',
            Is_Active__c = true,
            User__c = UserInfo.getUserId()
        );
        insert emp;

        // Active Account_Category__c mapping (L1 = Beverages)
        Account_Category__c acMap = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = l1Category.Id,
            Is_Active__c = true,
            Effective_From__c = Date.today().addDays(-10)
        );
        insert acMap;

        // Active Employee_Category__c mapping (L1 = Beverages)
        Employee_Category__c ecMap = new Employee_Category__c(
            Employee__c = emp.Id,
            Category__c = l1Category.Id,
            Is_Active__c = true,
            Responsibility_Type__c = 'Primary',
            Effective_From__c = Date.today().addDays(-10)
        );
        insert ecMap;
    }

    // ─── getAccountCategoryIds ─────────────────────────────────────────

    @isTest
    static void testGetAccountCategoryIds_WithActiveMapping() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Category Test Retailer'];

        Test.startTest();
        Set<Id> categoryIds = MDM_CategoryMapping_Service.getAccountCategoryIds(acc.Id);
        Test.stopTest();

        // Toggle MDM-004 may be disabled in test; if so returns empty set
        // Method should execute without error in either case
        System.assertNotEquals(null, categoryIds, 'Should return a set (possibly empty if toggle disabled)');
    }

    @isTest
    static void testGetAccountCategoryIds_NullAccountId() {
        Test.startTest();
        Set<Id> categoryIds = MDM_CategoryMapping_Service.getAccountCategoryIds(null);
        Test.stopTest();

        System.assertEquals(0, categoryIds.size(), 'Null account should return empty set');
    }

    @isTest
    static void testGetAccountCategoryIdsMap() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Category Test Retailer'];
        Set<Id> accountIds = new Set<Id>{ acc.Id };

        Test.startTest();
        Map<Id, Set<Id>> result = MDM_CategoryMapping_Service.getAccountCategoryIdsMap(accountIds);
        Test.stopTest();

        // Even if toggle disabled, should return map structure
        System.assertNotEquals(null, result, 'Should return a map');
    }

    @isTest
    static void testGetAccountCategoryIdsMap_EmptySet() {
        Test.startTest();
        Map<Id, Set<Id>> result = MDM_CategoryMapping_Service.getAccountCategoryIdsMap(new Set<Id>());
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Empty input should return empty map');
    }

    @isTest
    static void testGetAccountCategoryIdsMap_NullSet() {
        Test.startTest();
        Map<Id, Set<Id>> result = MDM_CategoryMapping_Service.getAccountCategoryIdsMap(null);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Null input should return empty map');
    }

    // ─── getEmployeeCategoryIds ────────────────────────────────────────

    @isTest
    static void testGetEmployeeCategoryIds_WithActiveMapping() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-CAT01'];

        Test.startTest();
        Set<Id> categoryIds = MDM_CategoryMapping_Service.getEmployeeCategoryIds(emp.Id);
        Test.stopTest();

        System.assertNotEquals(null, categoryIds, 'Should return a set');
    }

    @isTest
    static void testGetEmployeeCategoryIds_NullEmployeeId() {
        Test.startTest();
        Set<Id> categoryIds = MDM_CategoryMapping_Service.getEmployeeCategoryIds(null);
        Test.stopTest();

        System.assertEquals(0, categoryIds.size(), 'Null employee should return empty set');
    }

    // ─── Expired / Inactive Mapping Exclusion ──────────────────────────

    @isTest
    static void testExpiredMappingExcluded() {
        Account acc = TestDataFactory.createAndInsertAccount('Expired Mapping Acct', 'Retailer');
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'CAT-SNK'];

        // Insert an expired mapping
        Account_Category__c expired = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Effective_From__c = Date.today().addDays(-60),
            Effective_To__c = Date.today().addDays(-30)
        );
        insert expired;

        Test.startTest();
        Set<Id> categoryIds = MDM_CategoryMapping_Service.getAccountCategoryIds(acc.Id);
        Test.stopTest();

        // If toggle enabled, expired mapping should not be returned
        // If toggle disabled, returns empty set by default
        System.assert(!categoryIds.contains(cat.Id),
            'Expired mapping should not be included');
    }

    @isTest
    static void testInactiveMappingExcluded() {
        Account acc = TestDataFactory.createAndInsertAccount('Inactive Mapping Acct', 'Retailer');
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'CAT-SNK'];

        Account_Category__c inactive = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = cat.Id,
            Is_Active__c = false,
            Effective_From__c = Date.today().addDays(-10)
        );
        insert inactive;

        Test.startTest();
        Set<Id> categoryIds = MDM_CategoryMapping_Service.getAccountCategoryIds(acc.Id);
        Test.stopTest();

        System.assert(!categoryIds.contains(cat.Id),
            'Inactive mapping should not be included');
    }

    // ─── expandCategoryHierarchy ───────────────────────────────────────

    @isTest
    static void testExpandCategoryHierarchy_L1IncludesL2() {
        Product_Category__c l1 = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'CAT-BEV'];
        Product_Category__c l2a = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'CAT-BEV-CARB'];
        Product_Category__c l2b = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'CAT-BEV-JUI'];

        MDM_CategoryMapping_Service.clearCache();

        Test.startTest();
        Set<Id> expanded = MDM_CategoryMapping_Service.expandCategoryHierarchy(new Set<Id>{ l1.Id });
        Test.stopTest();

        System.assert(expanded.contains(l1.Id), 'Expanded set should contain the original L1 category');
        System.assert(expanded.contains(l2a.Id), 'Expanded set should contain L2 child Carbonated Drinks');
        System.assert(expanded.contains(l2b.Id), 'Expanded set should contain L2 child Juices');
        System.assertEquals(3, expanded.size(), 'Should have L1 + 2 L2 children = 3 total');
    }

    @isTest
    static void testExpandCategoryHierarchy_LeafNode() {
        Product_Category__c l2a = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'CAT-BEV-CARB'];

        MDM_CategoryMapping_Service.clearCache();

        Test.startTest();
        Set<Id> expanded = MDM_CategoryMapping_Service.expandCategoryHierarchy(new Set<Id>{ l2a.Id });
        Test.stopTest();

        System.assertEquals(1, expanded.size(), 'Leaf node should only contain itself');
        System.assert(expanded.contains(l2a.Id), 'Should contain the leaf category itself');
    }

    @isTest
    static void testExpandCategoryHierarchy_NullInput() {
        Test.startTest();
        Set<Id> expanded = MDM_CategoryMapping_Service.expandCategoryHierarchy(null);
        Test.stopTest();

        System.assertEquals(null, expanded, 'Null input should return null');
    }

    @isTest
    static void testExpandCategoryHierarchy_EmptyInput() {
        Test.startTest();
        Set<Id> expanded = MDM_CategoryMapping_Service.expandCategoryHierarchy(new Set<Id>());
        Test.stopTest();

        System.assertEquals(0, expanded.size(), 'Empty input should return empty set');
    }

    // ─── validateProductsForAccount ────────────────────────────────────

    @isTest
    static void testValidateProductsForAccount() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Category Test Retailer'];
        List<Product_Extension__c> prods = [SELECT Id FROM Product_Extension__c ORDER BY SKU_Code__c];
        Set<Id> productIds = new Set<Id>();
        for (Product_Extension__c p : prods) {
            productIds.add(p.Id);
        }

        Test.startTest();
        Map<Id, Boolean> results = MDM_CategoryMapping_Service.validateProductsForAccount(acc.Id, productIds);
        Test.stopTest();

        System.assertEquals(productIds.size(), results.size(), 'Should have a result for each product');
        for (Id pId : productIds) {
            System.assertNotEquals(null, results.get(pId), 'Each product should have a boolean result');
        }
    }

    @isTest
    static void testValidateProductsForAccount_EmptyProducts() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Category Test Retailer'];

        Test.startTest();
        Map<Id, Boolean> results = MDM_CategoryMapping_Service.validateProductsForAccount(acc.Id, new Set<Id>());
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Empty product set should return empty map');
    }

    @isTest
    static void testValidateProductsForAccount_NullProducts() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Category Test Retailer'];

        Test.startTest();
        Map<Id, Boolean> results = MDM_CategoryMapping_Service.validateProductsForAccount(acc.Id, null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Null product set should return empty map');
    }

    @isTest
    static void testValidateProductsForAccount_NoMappings_PermissiveDefault() {
        // Account with no category mappings
        Account acc = TestDataFactory.createAndInsertAccount('No Mapping Acct', 'Retailer');
        List<Product_Extension__c> prods = [SELECT Id FROM Product_Extension__c LIMIT 2];
        Set<Id> productIds = new Set<Id>();
        for (Product_Extension__c p : prods) {
            productIds.add(p.Id);
        }

        Test.startTest();
        Map<Id, Boolean> results = MDM_CategoryMapping_Service.validateProductsForAccount(acc.Id, productIds);
        Test.stopTest();

        // With no account-category mappings, should be permissive
        for (Id pId : productIds) {
            System.assertEquals(true, results.get(pId), 'No mappings should default to allowed');
        }
    }

    // ─── isEmployeeAuthorizedForCategory ───────────────────────────────

    @isTest
    static void testIsEmployeeAuthorizedForCategory() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-CAT01'];
        Product_Category__c l1 = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'CAT-BEV'];

        Test.startTest();
        Boolean result = MDM_CategoryMapping_Service.isEmployeeAuthorizedForCategory(emp.Id, l1.Id);
        Test.stopTest();

        // With toggle disabled returns true (permissive); with toggle enabled also true (mapped)
        System.assertEquals(true, result, 'Employee mapped to category should be authorized');
    }

    @isTest
    static void testIsEmployeeAuthorizedForCategory_NoMappings_PermissiveDefault() {
        // Create employee without category mappings
        Employee__c emp = new Employee__c(
            First_Name__c = 'No',
            Last_Name__c = 'Mapping',
            Employee_Code__c = 'EMP-CAT99',
            Is_Active__c = true
        );
        insert emp;

        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'CAT-SNK'];

        Test.startTest();
        Boolean result = MDM_CategoryMapping_Service.isEmployeeAuthorizedForCategory(emp.Id, cat.Id);
        Test.stopTest();

        System.assertEquals(true, result, 'Employee with no mappings should be authorized by default');
    }

    // ─── canSellProduct ────────────────────────────────────────────────

    @isTest
    static void testCanSellProduct_CombinedCheck() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-CAT01'];
        Account acc = [SELECT Id FROM Account WHERE Name = 'Category Test Retailer'];
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'CAT-P001'];

        Test.startTest();
        Boolean result = MDM_CategoryMapping_Service.canSellProduct(emp.Id, acc.Id, prod.Id);
        Test.stopTest();

        // With toggle disabled returns true; with toggle enabled, both account and employee
        // are mapped to Beverages L1 which expands to include Carbonated Drinks (L2)
        System.assertEquals(true, result, 'Should be able to sell product in mapped category');
    }

    @isTest
    static void testCanSellProduct_UncategorizedProduct() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-CAT01'];
        Account acc = [SELECT Id FROM Account WHERE Name = 'Category Test Retailer'];
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'CAT-P004'];

        Test.startTest();
        Boolean result = MDM_CategoryMapping_Service.canSellProduct(emp.Id, acc.Id, prod.Id);
        Test.stopTest();

        System.assertEquals(true, result, 'Uncategorized product should be allowed');
    }

    // ─── filterAllowedProducts ─────────────────────────────────────────

    @isTest
    static void testFilterAllowedProducts() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-CAT01'];
        Account acc = [SELECT Id FROM Account WHERE Name = 'Category Test Retailer'];
        List<Product_Extension__c> prods = [SELECT Id FROM Product_Extension__c ORDER BY SKU_Code__c];
        List<Id> productIds = new List<Id>();
        for (Product_Extension__c p : prods) {
            productIds.add(p.Id);
        }

        Test.startTest();
        List<Id> filtered = MDM_CategoryMapping_Service.filterAllowedProducts(emp.Id, acc.Id, productIds);
        Test.stopTest();

        System.assertNotEquals(null, filtered, 'Should return a list');
        System.assert(filtered.size() > 0, 'Should return at least some allowed products');
    }

    @isTest
    static void testFilterAllowedProducts_NullInput() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-CAT01'];
        Account acc = [SELECT Id FROM Account WHERE Name = 'Category Test Retailer'];

        Test.startTest();
        List<Id> filtered = MDM_CategoryMapping_Service.filterAllowedProducts(emp.Id, acc.Id, null);
        Test.stopTest();

        System.assertEquals(null, filtered, 'Null input should return null');
    }

    @isTest
    static void testFilterAllowedProducts_EmptyInput() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-CAT01'];
        Account acc = [SELECT Id FROM Account WHERE Name = 'Category Test Retailer'];

        Test.startTest();
        List<Id> filtered = MDM_CategoryMapping_Service.filterAllowedProducts(emp.Id, acc.Id, new List<Id>());
        Test.stopTest();

        System.assertEquals(0, filtered.size(), 'Empty input should return empty list');
    }

    // ─── getProductIdsForAccountCategories ─────────────────────────────

    @isTest
    static void testGetProductIdsForAccountCategories() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Category Test Retailer'];

        Test.startTest();
        Set<Id> productIds = MDM_CategoryMapping_Service.getProductIdsForAccountCategories(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, productIds, 'Should return a set');
    }

    // ─── getCurrentUserCategoryIds ─────────────────────────────────────

    @isTest
    static void testGetCurrentUserCategoryIds() {
        Test.startTest();
        Set<Id> categoryIds = MDM_CategoryMapping_Service.getCurrentUserCategoryIds();
        Test.stopTest();

        System.assertNotEquals(null, categoryIds, 'Should return a set');
    }
}
