/**
 * @description Test class for MDM_EmployeeCategory_TriggerHandler.
 *              Validates duplicate prevention logic and auto-set Assigned_By behavior
 *              on Employee_Category__c records.
 * @author  SFA Development Team
 * @date    2026
 */
@isTest
private class MDM_EmployeeCategory_TriggerHandler_Test {

    @TestSetup
    static void setupTestData() {
        // Category hierarchy
        Product_Category__c l1 = new Product_Category__c(
            Name = 'Personal Care',
            Category_Code__c = 'ECT-PC',
            Level__c = 'Category',
            Sort_Order__c = 1,
            Is_Active__c = true
        );
        insert l1;

        Product_Category__c l2 = new Product_Category__c(
            Name = 'Shampoo',
            Category_Code__c = 'ECT-PC-SHP',
            Level__c = 'Sub-Category',
            Parent_Category__c = l1.Id,
            Sort_Order__c = 1,
            Is_Active__c = true
        );
        insert l2;

        // Employee
        Employee__c emp = new Employee__c(
            First_Name__c = 'EmpTrigger',
            Last_Name__c = 'Tester',
            Employee_Code__c = 'EMP-ECT01',
            Is_Active__c = true,
            User__c = UserInfo.getUserId()
        );
        insert emp;
    }

    // ─── Insert Valid Mapping ──────────────────────────────────────────

    @isTest
    static void testInsertValidMapping_Success() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-ECT01'];
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ECT-PC'];

        Test.startTest();
        Employee_Category__c ec = new Employee_Category__c(
            Employee__c = emp.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Responsibility_Type__c = 'Primary',
            Effective_From__c = Date.today()
        );
        insert ec;
        Test.stopTest();

        List<Employee_Category__c> inserted = [
            SELECT Id FROM Employee_Category__c WHERE Id = :ec.Id
        ];
        System.assertEquals(1, inserted.size(), 'Mapping should be inserted successfully');
    }

    // ─── Verify Assigned_By Auto-populated ─────────────────────────────

    @isTest
    static void testAssignedByAutoPopulated() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-ECT01'];
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ECT-PC'];

        Test.startTest();
        Employee_Category__c ec = new Employee_Category__c(
            Employee__c = emp.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Responsibility_Type__c = 'Primary',
            Effective_From__c = Date.today()
        );
        insert ec;
        Test.stopTest();

        Employee_Category__c inserted = [
            SELECT Assigned_By__c FROM Employee_Category__c WHERE Id = :ec.Id
        ];
        System.assertEquals(UserInfo.getUserId(), inserted.Assigned_By__c,
            'Assigned_By__c should be auto-populated with current user');
    }

    @isTest
    static void testAssignedByNotOverwritten_WhenProvided() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-ECT01'];
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ECT-PC'];

        Test.startTest();
        Employee_Category__c ec = new Employee_Category__c(
            Employee__c = emp.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Responsibility_Type__c = 'Primary',
            Effective_From__c = Date.today(),
            Assigned_By__c = UserInfo.getUserId()
        );
        insert ec;
        Test.stopTest();

        Employee_Category__c inserted = [
            SELECT Assigned_By__c FROM Employee_Category__c WHERE Id = :ec.Id
        ];
        System.assertEquals(UserInfo.getUserId(), inserted.Assigned_By__c,
            'Assigned_By__c should retain the explicitly provided value');
    }

    // ─── Duplicate Active Mapping (overlapping dates) ──────────────────

    @isTest
    static void testDuplicateActiveMapping_OverlappingDates_Error() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-ECT01'];
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ECT-PC'];

        // First mapping
        Employee_Category__c ec1 = new Employee_Category__c(
            Employee__c = emp.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Responsibility_Type__c = 'Primary',
            Effective_From__c = Date.today(),
            Effective_To__c = Date.today().addDays(30)
        );
        insert ec1;

        // Second mapping with overlapping dates
        Test.startTest();
        Employee_Category__c ec2 = new Employee_Category__c(
            Employee__c = emp.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Responsibility_Type__c = 'Primary',
            Effective_From__c = Date.today().addDays(15),
            Effective_To__c = Date.today().addDays(45)
        );
        Boolean errorThrown = false;
        try {
            insert ec2;
        } catch (DmlException e) {
            errorThrown = true;
            System.assert(e.getMessage().contains('active mapping already exists'),
                'Error message should mention duplicate active mapping');
        }
        Test.stopTest();

        System.assert(errorThrown, 'Should throw error for duplicate active mapping with overlapping dates');
    }

    // ─── Same Employee+Category but one is Inactive ────────────────────

    @isTest
    static void testSameCombo_OneInactive_Success() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-ECT01'];
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ECT-PC'];

        // Active mapping
        Employee_Category__c ec1 = new Employee_Category__c(
            Employee__c = emp.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Responsibility_Type__c = 'Primary',
            Effective_From__c = Date.today()
        );
        insert ec1;

        // Same combo but inactive - should succeed
        Test.startTest();
        Employee_Category__c ec2 = new Employee_Category__c(
            Employee__c = emp.Id,
            Category__c = cat.Id,
            Is_Active__c = false,
            Responsibility_Type__c = 'Primary',
            Effective_From__c = Date.today()
        );
        Boolean success = true;
        try {
            insert ec2;
        } catch (DmlException e) {
            success = false;
        }
        Test.stopTest();

        System.assert(success, 'Inactive mapping with same employee+category should be allowed');
    }

    // ─── Same Employee+Category with non-overlapping dates ─────────────

    @isTest
    static void testSameCombo_NonOverlappingDates_Success() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-ECT01'];
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ECT-PC'];

        // First mapping: past period
        Employee_Category__c ec1 = new Employee_Category__c(
            Employee__c = emp.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Responsibility_Type__c = 'Primary',
            Effective_From__c = Date.today().addDays(-60),
            Effective_To__c = Date.today().addDays(-31)
        );
        insert ec1;

        // Second mapping: future period (non-overlapping)
        Test.startTest();
        Employee_Category__c ec2 = new Employee_Category__c(
            Employee__c = emp.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Responsibility_Type__c = 'Primary',
            Effective_From__c = Date.today().addDays(31),
            Effective_To__c = Date.today().addDays(60)
        );
        Boolean success = true;
        try {
            insert ec2;
        } catch (DmlException e) {
            success = false;
        }
        Test.stopTest();

        System.assert(success, 'Non-overlapping date ranges should be allowed');
    }

    // ─── Different Category on same Employee ───────────────────────────

    @isTest
    static void testDifferentCategory_SameEmployee_Success() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-ECT01'];
        Product_Category__c cat1 = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ECT-PC'];
        Product_Category__c cat2 = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ECT-PC-SHP'];

        Employee_Category__c ec1 = new Employee_Category__c(
            Employee__c = emp.Id,
            Category__c = cat1.Id,
            Is_Active__c = true,
            Responsibility_Type__c = 'Primary',
            Effective_From__c = Date.today()
        );
        insert ec1;

        Test.startTest();
        Employee_Category__c ec2 = new Employee_Category__c(
            Employee__c = emp.Id,
            Category__c = cat2.Id,
            Is_Active__c = true,
            Responsibility_Type__c = 'Secondary',
            Effective_From__c = Date.today()
        );
        Boolean success = true;
        try {
            insert ec2;
        } catch (DmlException e) {
            success = false;
        }
        Test.stopTest();

        System.assert(success, 'Different category on same employee should be allowed');
    }

    // ─── TestDataFactory helper method ─────────────────────────────────

    @isTest
    static void testCreateEmployeeCategory_ViaFactory() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-ECT01'];
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ECT-PC-SHP'];

        Test.startTest();
        Employee_Category__c ec = TestDataFactory.createEmployeeCategory(emp.Id, cat.Id);
        Test.stopTest();

        System.assertNotEquals(null, ec.Id, 'Factory method should insert the record');
        Employee_Category__c queried = [
            SELECT Is_Active__c, Responsibility_Type__c, Effective_From__c, Assigned_By__c
            FROM Employee_Category__c WHERE Id = :ec.Id
        ];
        System.assertEquals(true, queried.Is_Active__c, 'Should be active');
        System.assertEquals('Primary', queried.Responsibility_Type__c, 'Responsibility should be Primary');
        System.assertEquals(Date.today(), queried.Effective_From__c, 'Effective from should be today');
        System.assertNotEquals(null, queried.Assigned_By__c, 'Assigned_By should be auto-set');
    }
}
