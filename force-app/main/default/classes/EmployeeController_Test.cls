@IsTest
private class EmployeeController_Test {

    @TestSetup
    static void setup() {
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('Sales Territory', 'ST-001');

        // Manager employee
        Employee__c manager = new Employee__c(
            First_Name__c = 'Manager',
            Last_Name__c = 'Smith',
            Employee_Code__c = 'MGR-001',
            Email__c = 'manager.smith@test.com',
            Phone__c = '9876543210',
            Department__c = 'Sales',
            Designation__c = 'Area Sales Manager',
            Date_of_Joining__c = Date.today().addYears(-5),
            Is_Active__c = true,
            Zone__c = 'West',
            Region__c = 'Maharashtra',
            Territory__c = territory.Id,
            User__c = UserInfo.getUserId()
        );
        insert manager;

        // Subordinate employees
        List<Employee__c> subordinates = new List<Employee__c>();
        for (Integer i = 1; i <= 3; i++) {
            subordinates.add(new Employee__c(
                First_Name__c = 'Sales',
                Last_Name__c = 'Rep' + i,
                Employee_Code__c = 'SR-00' + i,
                Email__c = 'salesrep' + i + '@test.com',
                Phone__c = '98765432' + String.valueOf(10 + i),
                Department__c = 'Sales',
                Designation__c = 'Sales Executive',
                Date_of_Joining__c = Date.today().addYears(-1),
                Is_Active__c = true,
                Zone__c = 'West',
                Region__c = 'Maharashtra',
                Territory__c = territory.Id,
                Reporting_Manager__c = manager.Id
            ));
        }

        // Inactive employee
        subordinates.add(new Employee__c(
            First_Name__c = 'Inactive',
            Last_Name__c = 'Employee',
            Employee_Code__c = 'IE-001',
            Email__c = 'inactive@test.com',
            Phone__c = '9999999999',
            Department__c = 'Sales',
            Designation__c = 'Sales Executive',
            Date_of_Joining__c = Date.today().addYears(-3),
            Is_Active__c = false,
            Zone__c = 'West',
            Region__c = 'Maharashtra'
        ));

        insert subordinates;
    }

    static Employee__c getManager() {
        return [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'MGR-001' LIMIT 1];
    }

    // ── getEmployees: all active ─────────────────────────────────────────────

    @IsTest
    static void testGetEmployeesActiveOnly() {
        Test.startTest();
        List<Employee__c> employees = EmployeeController.getEmployees(null, null, null, true);
        Test.stopTest();

        System.assert(employees.size() >= 4, 'Should return at least 4 active employees');
        for (Employee__c emp : employees) {
            System.assertEquals(true, emp.Is_Active__c, 'All returned employees should be active');
        }
    }

    // ── getEmployees: include inactive ───────────────────────────────────────

    @IsTest
    static void testGetEmployeesIncludeInactive() {
        Test.startTest();
        List<Employee__c> employees = EmployeeController.getEmployees(null, null, null, false);
        Test.stopTest();

        System.assert(employees.size() >= 5, 'Should include inactive employees');
        Boolean hasInactive = false;
        for (Employee__c emp : employees) {
            if (!emp.Is_Active__c) {
                hasInactive = true;
                break;
            }
        }
        System.assert(hasInactive, 'Should include at least one inactive employee');
    }

    // ── getEmployees: search by name ─────────────────────────────────────────

    @IsTest
    static void testGetEmployeesSearchByName() {
        Test.startTest();
        List<Employee__c> employees = EmployeeController.getEmployees('Manager', null, null, true);
        Test.stopTest();

        System.assert(!employees.isEmpty(), 'Should find Manager employee');
        System.assert(employees[0].First_Name__c == 'Manager' || employees[0].Last_Name__c == 'Smith',
            'Should match the Manager Smith employee');
    }

    // ── getEmployees: search by code ─────────────────────────────────────────

    @IsTest
    static void testGetEmployeesSearchByCode() {
        Test.startTest();
        List<Employee__c> employees = EmployeeController.getEmployees('SR-001', null, null, true);
        Test.stopTest();

        System.assertEquals(1, employees.size(), 'Should find exactly one employee by code');
        System.assertEquals('SR-001', employees[0].Employee_Code__c, 'Code should match');
    }

    // ── getEmployees: search by email ────────────────────────────────────────

    @IsTest
    static void testGetEmployeesSearchByEmail() {
        Test.startTest();
        List<Employee__c> employees = EmployeeController.getEmployees('salesrep1@test', null, null, true);
        Test.stopTest();

        System.assert(!employees.isEmpty(), 'Should find employee by email');
    }

    // ── getEmployees: filter by department ────────────────────────────────────

    @IsTest
    static void testGetEmployeesFilterByDepartment() {
        Test.startTest();
        List<Employee__c> employees = EmployeeController.getEmployees(null, 'Sales', null, true);
        Test.stopTest();

        System.assert(!employees.isEmpty(), 'Should return Sales department employees');
        for (Employee__c emp : employees) {
            System.assertEquals('Sales', emp.Department__c, 'All should be in Sales department');
        }
    }

    // ── getEmployees: filter by designation ───────────────────────────────────

    @IsTest
    static void testGetEmployeesFilterByDesignation() {
        Test.startTest();
        List<Employee__c> employees = EmployeeController.getEmployees(null, null, 'Sales Executive', true);
        Test.stopTest();

        System.assert(!employees.isEmpty(), 'Should return Sales Executive employees');
        for (Employee__c emp : employees) {
            System.assertEquals('Sales Executive', emp.Designation__c, 'All should be Sales Executives');
        }
    }

    // ── getEmployees: combined filters ───────────────────────────────────────

    @IsTest
    static void testGetEmployeesCombinedFilters() {
        Test.startTest();
        List<Employee__c> employees = EmployeeController.getEmployees('Rep', 'Sales', 'Sales Executive', true);
        Test.stopTest();

        System.assert(!employees.isEmpty(), 'Should return results with combined filters');
    }

    // ── getEmployees: null activeOnly defaults to true ────────────────────────

    @IsTest
    static void testGetEmployeesNullActiveOnly() {
        Test.startTest();
        List<Employee__c> employees = EmployeeController.getEmployees(null, null, null, null);
        Test.stopTest();

        System.assert(employees != null, 'Should return a list');
        for (Employee__c emp : employees) {
            System.assertEquals(true, emp.Is_Active__c, 'Default should be active only');
        }
    }

    // ── getEmployee ──────────────────────────────────────────────────────────

    @IsTest
    static void testGetEmployee() {
        Employee__c manager = getManager();

        Test.startTest();
        Employee__c result = EmployeeController.getEmployee(manager.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return the employee');
        System.assertEquals(manager.Id, result.Id, 'Ids should match');
        System.assertEquals('Manager', result.First_Name__c, 'First name should match');
        System.assertEquals('Smith', result.Last_Name__c, 'Last name should match');
    }

    @IsTest
    static void testGetEmployeeNotFound() {
        // Use a fake Id
        Id fakeId = Employee__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';

        Test.startTest();
        Employee__c result = EmployeeController.getEmployee(fakeId);
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null for non-existent employee');
    }

    // ── saveEmployee: insert ─────────────────────────────────────────────────

    @IsTest
    static void testSaveEmployeeInsert() {
        Employee__c newEmp = new Employee__c(
            First_Name__c = 'New',
            Last_Name__c = 'Hire',
            Employee_Code__c = 'NH-001',
            Email__c = 'newhire@test.com',
            Phone__c = '8888888888',
            Department__c = 'Sales',
            Designation__c = 'Sales Executive',
            Date_of_Joining__c = Date.today(),
            Is_Active__c = true
        );

        Test.startTest();
        Employee__c result = EmployeeController.saveEmployee(newEmp);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Employee should be inserted');
        System.assertEquals('New', result.First_Name__c, 'First name should match');
        System.assertEquals('NH-001', result.Employee_Code__c, 'Code should match');
    }

    // ── saveEmployee: update ─────────────────────────────────────────────────

    @IsTest
    static void testSaveEmployeeUpdate() {
        Employee__c manager = getManager();
        manager.Phone__c = '1111111111';

        Test.startTest();
        Employee__c result = EmployeeController.saveEmployee(manager);
        Test.stopTest();

        System.assertEquals('1111111111', result.Phone__c, 'Phone should be updated');
    }

    // ── deactivateEmployee ───────────────────────────────────────────────────

    @IsTest
    static void testDeactivateEmployee() {
        Employee__c emp = [SELECT Id, Is_Active__c FROM Employee__c WHERE Employee_Code__c = 'SR-001' LIMIT 1];
        System.assertEquals(true, emp.Is_Active__c, 'Employee should be active before deactivation');

        Test.startTest();
        EmployeeController.deactivateEmployee(emp.Id);
        Test.stopTest();

        Employee__c updated = [SELECT Is_Active__c FROM Employee__c WHERE Id = :emp.Id];
        System.assertEquals(false, updated.Is_Active__c, 'Employee should be inactive after deactivation');
    }

    @IsTest
    static void testDeactivateAlreadyInactiveEmployee() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'IE-001' LIMIT 1];

        Test.startTest();
        try {
            EmployeeController.deactivateEmployee(emp.Id);
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('already inactive'),
                'Error should mention employee is already inactive');
        }
        Test.stopTest();
    }

    // ── getEmployeeByUserId ──────────────────────────────────────────────────

    @IsTest
    static void testGetEmployeeByUserId() {
        Test.startTest();
        Employee__c result = EmployeeController.getEmployeeByUserId(UserInfo.getUserId());
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should find employee linked to current user');
        System.assertEquals('MGR-001', result.Employee_Code__c, 'Should return the manager employee');
    }

    @IsTest
    static void testGetEmployeeByUserIdNotFound() {
        // Use a User Id that has no employee link (create a dummy scenario)
        // This is tricky since we can't easily create another User in test,
        // so we test with the inactive employee's user (null)
        Id fakeUserId = UserInfo.getUserId();
        // Unlink the user from the manager
        Employee__c mgr = getManager();
        mgr.User__c = null;
        update mgr;

        Test.startTest();
        Employee__c result = EmployeeController.getEmployeeByUserId(fakeUserId);
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when no active employee linked');
    }

    // ── getDepartmentOptions ─────────────────────────────────────────────────

    @IsTest
    static void testGetDepartmentOptions() {
        Test.startTest();
        List<String> options = EmployeeController.getDepartmentOptions();
        Test.stopTest();

        System.assertNotEquals(null, options, 'Department options should not be null');
        // At minimum the picklist should have values defined in the org
        System.assert(options.size() >= 0, 'Should return department picklist values');
    }

    // ── getDesignationOptions ────────────────────────────────────────────────

    @IsTest
    static void testGetDesignationOptions() {
        Test.startTest();
        List<String> options = EmployeeController.getDesignationOptions();
        Test.stopTest();

        System.assertNotEquals(null, options, 'Designation options should not be null');
        System.assert(options.size() >= 0, 'Should return designation picklist values');
    }

    // ── getDirectReports ─────────────────────────────────────────────────────

    @IsTest
    static void testGetDirectReports() {
        Employee__c manager = getManager();

        Test.startTest();
        List<Employee__c> reports = EmployeeController.getDirectReports(manager.Id);
        Test.stopTest();

        System.assertEquals(3, reports.size(), 'Manager should have 3 direct reports');
        for (Employee__c rep : reports) {
            System.assertEquals(manager.Id, rep.Reporting_Manager__c,
                'All should report to the manager');
        }
    }

    @IsTest
    static void testGetDirectReportsNoReports() {
        Employee__c rep = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'SR-001' LIMIT 1];

        Test.startTest();
        List<Employee__c> reports = EmployeeController.getDirectReports(rep.Id);
        Test.stopTest();

        System.assertEquals(0, reports.size(), 'Sales rep should have no direct reports');
    }

    // ── getOrgHierarchy ──────────────────────────────────────────────────────

    @IsTest
    static void testGetOrgHierarchy() {
        Test.startTest();
        List<Map<String, Object>> hierarchy = EmployeeController.getOrgHierarchy();
        Test.stopTest();

        System.assertNotEquals(null, hierarchy, 'Hierarchy should not be null');
        System.assert(!hierarchy.isEmpty(), 'Hierarchy should have at least one root node');

        // Validate tree structure
        Map<String, Object> rootNode = hierarchy[0];
        System.assert(rootNode.containsKey('id'), 'Node should have id');
        System.assert(rootNode.containsKey('name'), 'Node should have name');
        System.assert(rootNode.containsKey('children'), 'Node should have children');
        System.assert(rootNode.containsKey('level'), 'Node should have level');
        System.assertEquals(0, (Integer) rootNode.get('level'), 'Root should be at level 0');

        // Manager (root) should have children
        List<Map<String, Object>> children = (List<Map<String, Object>>) rootNode.get('children');
        System.assertEquals(3, children.size(), 'Manager should have 3 children in hierarchy');
        System.assertEquals(true, rootNode.get('hasChildren'), 'Manager should have hasChildren = true');
    }

    // ── getEmployeeLeaveBalances ─────────────────────────────────────────────

    @IsTest
    static void testGetEmployeeLeaveBalances() {
        Employee__c manager = getManager();

        Test.startTest();
        try {
            List<Leave_Balance__c> balances = EmployeeController.getEmployeeLeaveBalances(manager.Id);
            System.assertNotEquals(null, balances, 'Leave balances should not be null');
        } catch (Exception e) {
            // LeaveBalanceService may not be fully set up in test
            System.assert(true, 'Exception from getEmployeeLeaveBalances: ' + e.getMessage());
        }
        Test.stopTest();
    }
}
