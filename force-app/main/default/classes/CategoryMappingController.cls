public with sharing class CategoryMappingController {

    // ─── Dashboard Stats ────────────────────────────────────────────────

    @AuraEnabled
    public static Map<String, Object> getCategoryMappingStats() {
        Map<String, Object> stats = new Map<String, Object>();

        stats.put('totalAccounts', [SELECT COUNT() FROM Account WHERE Is_Active__c = true]);
        stats.put('accountsWithCategories', Database.countQuery(
            'SELECT COUNT() FROM Account WHERE Id IN (SELECT Account__c FROM Account_Category__c WHERE Is_Active__c = true) AND Is_Active__c = true'
        ));
        stats.put('totalEmployees', [SELECT COUNT() FROM Employee__c WHERE Is_Active__c = true]);
        stats.put('employeesWithCategories', Database.countQuery(
            'SELECT COUNT() FROM Employee__c WHERE Id IN (SELECT Employee__c FROM Employee_Category__c WHERE Is_Active__c = true) AND Is_Active__c = true'
        ));
        stats.put('totalCategories', [SELECT COUNT() FROM Product_Category__c WHERE Is_Active__c = true]);
        stats.put('activeAccountMappings', [SELECT COUNT() FROM Account_Category__c WHERE Is_Active__c = true]);
        stats.put('activeEmployeeMappings', [SELECT COUNT() FROM Employee_Category__c WHERE Is_Active__c = true]);

        return stats;
    }

    // ─── Account Category CRUD ──────────────────────────────────────────

    @AuraEnabled
    public static List<Account_Category__c> getAccountCategories(Id accountId) {
        return [
            SELECT Id, Name, Account__c, Account__r.Name, Category__c, Category__r.Name,
                   Category_Level__c, Is_Active__c, Effective_From__c, Effective_To__c,
                   Assigned_By__c, Assigned_By__r.Name, Notes__c
            FROM Account_Category__c
            WHERE Account__c = :accountId
            ORDER BY Category__r.Name
        ];
    }

    @AuraEnabled
    public static List<Account_Category__c> getCategoryAccounts(Id categoryId) {
        return [
            SELECT Id, Name, Account__c, Account__r.Name, Category__c, Category__r.Name,
                   Category_Level__c, Is_Active__c, Effective_From__c, Effective_To__c,
                   Assigned_By__c, Assigned_By__r.Name, Notes__c
            FROM Account_Category__c
            WHERE Category__c = :categoryId
            ORDER BY Account__r.Name
        ];
    }

    @AuraEnabled
    public static Account_Category__c saveAccountCategory(Account_Category__c mapping) {
        upsert mapping;
        return [
            SELECT Id, Name, Account__c, Account__r.Name, Category__c, Category__r.Name,
                   Category_Level__c, Is_Active__c, Effective_From__c, Effective_To__c,
                   Assigned_By__c, Assigned_By__r.Name, Notes__c
            FROM Account_Category__c
            WHERE Id = :mapping.Id
        ];
    }

    @AuraEnabled
    public static void deleteAccountCategory(Id mappingId) {
        delete [SELECT Id FROM Account_Category__c WHERE Id = :mappingId];
    }

    @AuraEnabled
    public static List<Account_Category__c> bulkAssignAccountCategories(
        List<Id> accountIds, List<Id> categoryIds, Date effectiveFrom, Date effectiveTo
    ) {
        List<Account_Category__c> mappings = new List<Account_Category__c>();
        for (Id acctId : accountIds) {
            for (Id catId : categoryIds) {
                mappings.add(new Account_Category__c(
                    Account__c = acctId,
                    Category__c = catId,
                    Effective_From__c = effectiveFrom,
                    Effective_To__c = effectiveTo,
                    Is_Active__c = true
                ));
            }
        }
        insert mappings;
        return mappings;
    }

    // ─── Employee Category CRUD ─────────────────────────────────────────

    @AuraEnabled
    public static List<Employee_Category__c> getEmployeeCategories(Id employeeId) {
        return [
            SELECT Id, Name, Employee__c, Employee__r.First_Name__c, Employee__r.Last_Name__c,
                   Employee__r.Employee_Code__c, Category__c, Category__r.Name,
                   Category_Level__c, Responsibility_Type__c, Is_Active__c,
                   Effective_From__c, Effective_To__c, Assigned_By__c, Assigned_By__r.Name, Notes__c
            FROM Employee_Category__c
            WHERE Employee__c = :employeeId
            ORDER BY Category__r.Name
        ];
    }

    @AuraEnabled
    public static List<Employee_Category__c> getCategoryEmployees(Id categoryId) {
        return [
            SELECT Id, Name, Employee__c, Employee__r.First_Name__c, Employee__r.Last_Name__c,
                   Employee__r.Employee_Code__c, Category__c, Category__r.Name,
                   Category_Level__c, Responsibility_Type__c, Is_Active__c,
                   Effective_From__c, Effective_To__c, Assigned_By__c, Assigned_By__r.Name, Notes__c
            FROM Employee_Category__c
            WHERE Category__c = :categoryId
            ORDER BY Employee__r.Last_Name__c
        ];
    }

    @AuraEnabled
    public static Employee_Category__c saveEmployeeCategory(Employee_Category__c mapping) {
        upsert mapping;
        return [
            SELECT Id, Name, Employee__c, Employee__r.First_Name__c, Employee__r.Last_Name__c,
                   Employee__r.Employee_Code__c, Category__c, Category__r.Name,
                   Category_Level__c, Responsibility_Type__c, Is_Active__c,
                   Effective_From__c, Effective_To__c, Assigned_By__c, Assigned_By__r.Name, Notes__c
            FROM Employee_Category__c
            WHERE Id = :mapping.Id
        ];
    }

    @AuraEnabled
    public static void deleteEmployeeCategory(Id mappingId) {
        delete [SELECT Id FROM Employee_Category__c WHERE Id = :mappingId];
    }

    @AuraEnabled
    public static List<Employee_Category__c> bulkAssignEmployeeCategories(
        List<Id> employeeIds, List<Id> categoryIds, String responsibilityType,
        Date effectiveFrom, Date effectiveTo
    ) {
        List<Employee_Category__c> mappings = new List<Employee_Category__c>();
        for (Id empId : employeeIds) {
            for (Id catId : categoryIds) {
                mappings.add(new Employee_Category__c(
                    Employee__c = empId,
                    Category__c = catId,
                    Responsibility_Type__c = String.isNotBlank(responsibilityType) ? responsibilityType : 'Primary',
                    Effective_From__c = effectiveFrom,
                    Effective_To__c = effectiveTo,
                    Is_Active__c = true
                ));
            }
        }
        insert mappings;
        return mappings;
    }

    // ─── Category Product View (read-only) ──────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Product_Extension__c> getCategoryProducts(Id categoryId, Boolean includeSubCategories) {
        Set<Id> catIds = new Set<Id>{ categoryId };
        if (includeSubCategories == true) {
            for (Product_Category__c child : [
                SELECT Id FROM Product_Category__c WHERE Parent_Category__c = :categoryId
            ]) {
                catIds.add(child.Id);
            }
        }
        return [
            SELECT Id, Name, SKU_Code__c, Brand__c, MRP__c, Unit_Price__c, Is_Active__c,
                   Product_Category__c, Product_Category__r.Name
            FROM Product_Extension__c
            WHERE Product_Category__c IN :catIds
            ORDER BY Name
        ];
    }

    // ─── Lookups ────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccountsForLookup(String searchTerm) {
        String key = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        return [
            SELECT Id, Name, Channel__c, Outlet_Type__c
            FROM Account
            WHERE Is_Active__c = true AND Name LIKE :key
            ORDER BY Name LIMIT 20
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Employee__c> searchEmployeesForLookup(String searchTerm) {
        String key = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        return [
            SELECT Id, First_Name__c, Last_Name__c, Employee_Code__c, Designation__c
            FROM Employee__c
            WHERE Is_Active__c = true AND (First_Name__c LIKE :key OR Last_Name__c LIKE :key OR Employee_Code__c LIKE :key)
            ORDER BY Last_Name__c LIMIT 20
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Product_Category__c> getCategoryTree() {
        return [
            SELECT Id, Name, Level__c, Parent_Category__c, Parent_Category__r.Name,
                   Category_Code__c, Is_Active__c, Sort_Order__c
            FROM Product_Category__c
            WHERE Is_Active__c = true
            ORDER BY Sort_Order__c, Name
        ];
    }
}
