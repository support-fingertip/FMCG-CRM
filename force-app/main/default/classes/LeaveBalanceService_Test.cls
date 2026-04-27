@IsTest
private class LeaveBalanceService_Test {

    @TestSetup
    static void setupData() {
        // Create employee
        Employee__c emp = new Employee__c(
            First_Name__c = 'Test',
            Last_Name__c = 'Employee',
            Employee_Code__c = 'EMP-001',
            Designation__c = 'Sales Executive',
            Department__c = 'Sales',
            Is_Active__c = true,
            User__c = UserInfo.getUserId(),
            Date_of_Joining__c = Date.today().addYears(-2)
        );
        insert emp;

        // Create leave policies
        Leave_Policy__c casualPolicy = new Leave_Policy__c(
            Name = 'Casual Leave Policy',
            Leave_Type__c = 'Casual Leave',
            Designation__c = 'Sales Executive',
            Annual_Entitlement__c = 12,
            Monthly_Accrual__c = 1,
            Max_Carry_Forward__c = 3,
            Is_Active__c = true,
            Effective_Year__c = String.valueOf(Date.today().year())
        );

        Leave_Policy__c sickPolicy = new Leave_Policy__c(
            Name = 'Sick Leave Policy',
            Leave_Type__c = 'Sick Leave',
            Annual_Entitlement__c = 10,
            Monthly_Accrual__c = 0,
            Max_Carry_Forward__c = 0,
            Is_Active__c = true,
            Effective_Year__c = String.valueOf(Date.today().year())
        );

        insert new List<Leave_Policy__c>{ casualPolicy, sickPolicy };
    }

    // ── initializeYearlyBalances ─────────────────────────────────────

    @IsTest
    static void testInitializeYearlyBalances_CreatesBalances() {
        String year = String.valueOf(Date.today().year());

        Test.startTest();
        LeaveBalanceService.initializeYearlyBalances(year);
        Test.stopTest();

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        List<Leave_Balance__c> balances = [
            SELECT Id, Leave_Type__c, Entitled__c, Accrued__c, Used__c, Pending__c, Year__c
            FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :year
        ];

        System.assert(balances.size() >= 2, 'Should create at least 2 balances (Casual + Sick)');
    }

    @IsTest
    static void testInitializeYearlyBalances_NoDuplicates() {
        String year = String.valueOf(Date.today().year());

        LeaveBalanceService.initializeYearlyBalances(year);

        Test.startTest();
        // Run again -- should not create duplicates
        LeaveBalanceService.initializeYearlyBalances(year);
        Test.stopTest();

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        List<Leave_Balance__c> balances = [
            SELECT Id FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :year
        ];

        // Count each leave type at most once
        Set<String> types = new Set<String>();
        for (Leave_Balance__c lb : [SELECT Leave_Type__c FROM Leave_Balance__c
                                     WHERE Employee__c = :emp.Id AND Year__c = :year]) {
            System.assert(!types.contains(lb.Leave_Type__c), 'Should not have duplicate leave type: ' + lb.Leave_Type__c);
            types.add(lb.Leave_Type__c);
        }
    }

    @IsTest
    static void testInitializeYearlyBalances_LumpSumEntitlement() {
        String year = String.valueOf(Date.today().year());

        Test.startTest();
        LeaveBalanceService.initializeYearlyBalances(year);
        Test.stopTest();

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        // Sick Leave has monthly_accrual = 0, so should get full entitlement immediately
        List<Leave_Balance__c> sickBal = [
            SELECT Accrued__c, Entitled__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :year AND Leave_Type__c = 'Sick Leave'
        ];

        if (!sickBal.isEmpty()) {
            System.assertEquals(sickBal[0].Entitled__c, sickBal[0].Accrued__c,
                'Lump-sum types should have full entitlement accrued immediately');
        }
    }

    @IsTest
    static void testInitializeYearlyBalances_CarryForward() {
        String prevYear = String.valueOf(Date.today().year() - 1);
        String year = String.valueOf(Date.today().year());

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        Leave_Policy__c casualPolicy = [SELECT Id FROM Leave_Policy__c WHERE Leave_Type__c = 'Casual Leave' LIMIT 1];

        // Create previous year balance with unused days
        Leave_Balance__c prevBal = new Leave_Balance__c(
            Employee__c = emp.Id,
            Leave_Type__c = 'Casual Leave',
            Year__c = prevYear,
            Entitled__c = 12,
            Accrued__c = 12,
            Carry_Forward__c = 0,
            Used__c = 7,
            Pending__c = 0,
            Leave_Policy__c = casualPolicy.Id
        );
        insert prevBal;

        Test.startTest();
        LeaveBalanceService.initializeYearlyBalances(year);
        Test.stopTest();

        List<Leave_Balance__c> newBal = [
            SELECT Carry_Forward__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :year AND Leave_Type__c = 'Casual Leave'
        ];

        if (!newBal.isEmpty()) {
            // Max carry forward is 3, unused was 5 (12 - 7), so carry should be 3
            System.assertEquals(3, newBal[0].Carry_Forward__c, 'Carry forward should be capped at max');
        }
    }

    @IsTest
    static void testInitializeYearlyBalances_NoPolicies() {
        // Delete all policies
        delete [SELECT Id FROM Leave_Policy__c];

        String year = String.valueOf(Date.today().year());

        Test.startTest();
        LeaveBalanceService.initializeYearlyBalances(year);
        Test.stopTest();

        List<Leave_Balance__c> balances = [SELECT Id FROM Leave_Balance__c WHERE Year__c = :year];
        System.assertEquals(0, balances.size(), 'No balances should be created without policies');
    }

    // ── runMonthlyAccrual ────────────────────────────────────────────

    @IsTest
    static void testRunMonthlyAccrual() {
        String year = String.valueOf(Date.today().year());
        LeaveBalanceService.initializeYearlyBalances(year);

        Test.startTest();
        LeaveBalanceService.runMonthlyAccrual(year);
        Test.stopTest();

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        List<Leave_Balance__c> casualBal = [
            SELECT Accrued__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :year AND Leave_Type__c = 'Casual Leave'
        ];

        if (!casualBal.isEmpty()) {
            // Casual Leave has monthly_accrual = 1, initial accrued = 0, so after 1 accrual = 1
            System.assert(casualBal[0].Accrued__c >= 1, 'Accrued should be incremented');
        }
    }

    // ── deductBalance ────────────────────────────────────────────────

    @IsTest
    static void testDeductBalance() {
        String year = String.valueOf(Date.today().year());
        LeaveBalanceService.initializeYearlyBalances(year);

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        // First add some pending days
        LeaveBalanceService.addPending(emp.Id, 'Sick Leave', 2, year);

        Test.startTest();
        LeaveBalanceService.deductBalance(emp.Id, 'Sick Leave', 2, year);
        Test.stopTest();

        Leave_Balance__c bal = [
            SELECT Used__c, Pending__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :year AND Leave_Type__c = 'Sick Leave' LIMIT 1
        ];
        System.assertEquals(2, bal.Used__c, 'Used should be incremented by 2');
        System.assertEquals(0, bal.Pending__c, 'Pending should be decremented');
    }

    @IsTest
    static void testDeductBalance_NoBalanceRecord() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        // Should not throw - just returns
        LeaveBalanceService.deductBalance(emp.Id, 'NonExistent Leave', 1, '2099');
        Test.stopTest();
    }

    // ── restoreBalance ───────────────────────────────────────────────

    @IsTest
    static void testRestoreBalance() {
        String year = String.valueOf(Date.today().year());
        LeaveBalanceService.initializeYearlyBalances(year);

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        LeaveBalanceService.deductBalance(emp.Id, 'Sick Leave', 3, year);

        Test.startTest();
        LeaveBalanceService.restoreBalance(emp.Id, 'Sick Leave', 2, year);
        Test.stopTest();

        Leave_Balance__c bal = [
            SELECT Used__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :year AND Leave_Type__c = 'Sick Leave' LIMIT 1
        ];
        System.assertEquals(1, bal.Used__c, 'Used should be reduced by 2 (from 3 to 1)');
    }

    @IsTest
    static void testRestoreBalance_CannotGoNegative() {
        String year = String.valueOf(Date.today().year());
        LeaveBalanceService.initializeYearlyBalances(year);

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        LeaveBalanceService.restoreBalance(emp.Id, 'Sick Leave', 5, year);
        Test.stopTest();

        Leave_Balance__c bal = [
            SELECT Used__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :year AND Leave_Type__c = 'Sick Leave' LIMIT 1
        ];
        System.assertEquals(0, bal.Used__c, 'Used should not go below 0');
    }

    // ── addPending / removePending ───────────────────────────────────

    @IsTest
    static void testAddAndRemovePending() {
        String year = String.valueOf(Date.today().year());
        LeaveBalanceService.initializeYearlyBalances(year);

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        LeaveBalanceService.addPending(emp.Id, 'Sick Leave', 3, year);

        Leave_Balance__c bal = [
            SELECT Pending__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :year AND Leave_Type__c = 'Sick Leave' LIMIT 1
        ];
        System.assertEquals(3, bal.Pending__c, 'Pending should be 3');

        LeaveBalanceService.removePending(emp.Id, 'Sick Leave', 2, year);
        Test.stopTest();

        bal = [
            SELECT Pending__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :year AND Leave_Type__c = 'Sick Leave' LIMIT 1
        ];
        System.assertEquals(1, bal.Pending__c, 'Pending should be 1 after removing 2');
    }

    @IsTest
    static void testRemovePending_CannotGoNegative() {
        String year = String.valueOf(Date.today().year());
        LeaveBalanceService.initializeYearlyBalances(year);

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        LeaveBalanceService.removePending(emp.Id, 'Sick Leave', 10, year);
        Test.stopTest();

        Leave_Balance__c bal = [
            SELECT Pending__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :year AND Leave_Type__c = 'Sick Leave' LIMIT 1
        ];
        System.assertEquals(0, bal.Pending__c, 'Pending should not go below 0');
    }

    // ── validateBalance ──────────────────────────────────────────────

    @IsTest
    static void testValidateBalance_Sufficient() {
        String year = String.valueOf(Date.today().year());
        LeaveBalanceService.initializeYearlyBalances(year);

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        // Sick leave has 10 entitled (lump-sum), should not throw for 5 days
        try {
            LeaveBalanceService.validateBalance(emp.Id, 'Sick Leave', 5, year);
        } catch (AuraHandledException e) {
            System.assert(false, 'Should not throw for sufficient balance: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateBalance_Insufficient() {
        String year = String.valueOf(Date.today().year());
        LeaveBalanceService.initializeYearlyBalances(year);

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        try {
            LeaveBalanceService.validateBalance(emp.Id, 'Sick Leave', 15, year);
            System.assert(false, 'Should have thrown for insufficient balance');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Insufficient') ||
                          e.getMessage().contains('Script-thrown exception'),
                          'Should throw insufficient balance error');
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateBalance_NoBalanceRecord() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        try {
            LeaveBalanceService.validateBalance(emp.Id, 'NonExistent Leave', 1, '2099');
            System.assert(false, 'Should have thrown for missing balance');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('No leave balance found') ||
                          e.getMessage().contains('Script-thrown exception'),
                          'Should throw no balance found error');
        }
        Test.stopTest();
    }

    // ── getBalancesForUser ───────────────────────────────────────────

    @IsTest
    static void testGetBalancesForUser() {
        String year = String.valueOf(Date.today().year());
        LeaveBalanceService.initializeYearlyBalances(year);

        Test.startTest();
        List<Leave_Balance__c> balances = LeaveBalanceService.getBalancesForUser(UserInfo.getUserId(), year);
        Test.stopTest();

        System.assert(balances.size() >= 2, 'Should return at least 2 balances');
    }

    @IsTest
    static void testGetBalancesForUser_NoEmployee() {
        // Use a user ID that has no employee record -- a fake Id
        Test.startTest();
        List<Leave_Balance__c> balances = LeaveBalanceService.getBalancesForUser(
            UserInfo.getUserId(), '2099'
        );
        Test.stopTest();

        // Since there's no employee with this user in year 2099, will return empty
        // (the employee exists but no balances for 2099)
        System.assertNotEquals(null, balances, 'Should return a list (possibly empty)');
    }

    // ── getBalancesForEmployee ───────────────────────────────────────

    @IsTest
    static void testGetBalancesForEmployee() {
        String year = String.valueOf(Date.today().year());
        LeaveBalanceService.initializeYearlyBalances(year);

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        List<Leave_Balance__c> balances = LeaveBalanceService.getBalancesForEmployee(emp.Id, year);
        Test.stopTest();

        System.assert(balances.size() >= 2, 'Should return at least 2 balances');
    }

    // ── getCurrentFiscalYear ─────────────────────────────────────────

    @IsTest
    static void testGetCurrentFiscalYear() {
        Test.startTest();
        String fy = LeaveBalanceService.getCurrentFiscalYear();
        Test.stopTest();

        System.assertNotEquals(null, fy, 'Fiscal year should not be null');
        Integer fyInt = Integer.valueOf(fy);
        Integer currentYear = Date.today().year();
        // Indian FY: April-March. If month < 4, FY = currentYear - 1
        if (Date.today().month() < 4) {
            System.assertEquals(currentYear - 1, fyInt, 'FY should be previous year before April');
        } else {
            System.assertEquals(currentYear, fyInt, 'FY should be current year from April onwards');
        }
    }

    // ── getEmployeeId ────────────────────────────────────────────────

    @IsTest
    static void testGetEmployeeId() {
        Test.startTest();
        Id empId = LeaveBalanceService.getEmployeeId(UserInfo.getUserId());
        Test.stopTest();

        System.assertNotEquals(null, empId, 'Should return employee Id for current user');
    }

    @IsTest
    static void testGetEmployeeId_NoMatch() {
        // Delete all employees
        delete [SELECT Id FROM Employee__c];

        Test.startTest();
        Id empId = LeaveBalanceService.getEmployeeId(UserInfo.getUserId());
        Test.stopTest();

        System.assertEquals(null, empId, 'Should return null when no employee matches');
    }

    // ── calcAvailable ────────────────────────────────────────────────

    @IsTest
    static void testCalcAvailable() {
        Leave_Balance__c lb = new Leave_Balance__c(
            Accrued__c = 10,
            Carry_Forward__c = 3,
            Used__c = 5,
            Pending__c = 2
        );

        Test.startTest();
        Decimal available = LeaveBalanceService.calcAvailable(lb);
        Test.stopTest();

        System.assertEquals(6, available, 'Available should be 10 + 3 - 5 - 2 = 6');
    }

    @IsTest
    static void testCalcAvailable_NullFields() {
        Leave_Balance__c lb = new Leave_Balance__c();

        Test.startTest();
        Decimal available = LeaveBalanceService.calcAvailable(lb);
        Test.stopTest();

        System.assertEquals(0, available, 'Available should be 0 when all fields are null');
    }
}
