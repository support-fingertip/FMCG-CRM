@IsTest
private class LeavePolicyController_Test {

    @TestSetup
    static void setupData() {
        // Create leave policies
        Leave_Policy__c casualPolicy = new Leave_Policy__c(
            Name = 'Casual Leave Policy',
            Leave_Type__c = 'Casual Leave',
            Designation__c = 'Sales Executive',
            Annual_Entitlement__c = 12,
            Monthly_Accrual__c = 1,
            Max_Carry_Forward__c = 3,
            Encashable__c = false,
            Is_Active__c = true,
            Effective_Year__c = LeaveBalanceService.getCurrentFiscalYear()
        );

        Leave_Policy__c sickPolicy = new Leave_Policy__c(
            Name = 'Sick Leave Policy',
            Leave_Type__c = 'Sick Leave',
            Annual_Entitlement__c = 7,
            Monthly_Accrual__c = 0,
            Max_Carry_Forward__c = 0,
            Encashable__c = false,
            Is_Active__c = true,
            Effective_Year__c = LeaveBalanceService.getCurrentFiscalYear()
        );

        insert new List<Leave_Policy__c>{ casualPolicy, sickPolicy };

        // Create employee for balance initialization
        Employee__c emp = new Employee__c(
            First_Name__c = 'Test',
            Last_Name__c = 'Employee',
            Employee_Code__c = 'EMP-LP-001',
            Designation__c = 'Sales Executive',
            Department__c = 'Sales',
            Is_Active__c = true,
            User__c = UserInfo.getUserId(),
            Date_of_Joining__c = Date.today().addYears(-2)
        );
        insert emp;
    }

    // ── getAllPolicies ───────────────────────────────────────────────

    @IsTest
    static void testGetAllPolicies() {
        Test.startTest();
        List<Leave_Policy__c> policies = LeavePolicyController.getAllPolicies();
        Test.stopTest();

        System.assert(policies.size() >= 2, 'Should return at least 2 policies');
    }

    // ── getPolicy ───────────────────────────────────────────────────

    @IsTest
    static void testGetPolicy() {
        Leave_Policy__c policy = [SELECT Id FROM Leave_Policy__c WHERE Leave_Type__c = 'Casual Leave' LIMIT 1];

        Test.startTest();
        Leave_Policy__c result = LeavePolicyController.getPolicy(policy.Id);
        Test.stopTest();

        System.assertEquals(policy.Id, result.Id, 'Should return the correct policy');
        System.assertEquals('Casual Leave', result.Leave_Type__c, 'Should be Casual Leave');
    }

    // ── savePolicy (insert) ─────────────────────────────────────────

    @IsTest
    static void testSavePolicy_NewPolicy() {
        Leave_Policy__c newPolicy = new Leave_Policy__c(
            Name = 'Earned Leave Policy',
            Leave_Type__c = 'Earned Leave',
            Annual_Entitlement__c = 15,
            Monthly_Accrual__c = 1.25,
            Max_Carry_Forward__c = 5,
            Encashable__c = true,
            Is_Active__c = true,
            Effective_Year__c = LeaveBalanceService.getCurrentFiscalYear()
        );

        Test.startTest();
        Leave_Policy__c result = LeavePolicyController.savePolicy(newPolicy);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Should have an Id after save');
        System.assertEquals('Earned Leave', result.Leave_Type__c, 'Leave type should match');
    }

    // ── savePolicy (update) ─────────────────────────────────────────

    @IsTest
    static void testSavePolicy_UpdateExisting() {
        Leave_Policy__c policy = [SELECT Id, Annual_Entitlement__c FROM Leave_Policy__c
                                   WHERE Leave_Type__c = 'Casual Leave' LIMIT 1];
        policy.Annual_Entitlement__c = 15;

        Test.startTest();
        Leave_Policy__c result = LeavePolicyController.savePolicy(policy);
        Test.stopTest();

        System.assertEquals(15, result.Annual_Entitlement__c, 'Entitlement should be updated');
    }

    // ── deletePolicy ────────────────────────────────────────────────

    @IsTest
    static void testDeletePolicy() {
        Leave_Policy__c policy = [SELECT Id FROM Leave_Policy__c WHERE Leave_Type__c = 'Sick Leave' LIMIT 1];

        Test.startTest();
        LeavePolicyController.deletePolicy(policy.Id);
        Test.stopTest();

        List<Leave_Policy__c> remaining = [SELECT Id FROM Leave_Policy__c WHERE Id = :policy.Id];
        System.assertEquals(0, remaining.size(), 'Policy should be deleted');
    }

    // ── toggleActive ────────────────────────────────────────────────

    @IsTest
    static void testToggleActive_Deactivate() {
        Leave_Policy__c policy = [SELECT Id FROM Leave_Policy__c WHERE Leave_Type__c = 'Casual Leave' LIMIT 1];

        Test.startTest();
        LeavePolicyController.toggleActive(policy.Id, false);
        Test.stopTest();

        Leave_Policy__c updated = [SELECT Is_Active__c FROM Leave_Policy__c WHERE Id = :policy.Id];
        System.assertEquals(false, updated.Is_Active__c, 'Policy should be deactivated');
    }

    @IsTest
    static void testToggleActive_Activate() {
        Leave_Policy__c policy = [SELECT Id FROM Leave_Policy__c WHERE Leave_Type__c = 'Casual Leave' LIMIT 1];
        policy.Is_Active__c = false;
        update policy;

        Test.startTest();
        LeavePolicyController.toggleActive(policy.Id, true);
        Test.stopTest();

        Leave_Policy__c updated = [SELECT Is_Active__c FROM Leave_Policy__c WHERE Id = :policy.Id];
        System.assertEquals(true, updated.Is_Active__c, 'Policy should be activated');
    }

    // ── initializeBalances ──────────────────────────────────────────

    @IsTest
    static void testInitializeBalances() {
        String year = LeaveBalanceService.getCurrentFiscalYear();

        Test.startTest();
        String result = LeavePolicyController.initializeBalances(year);
        Test.stopTest();

        System.assert(result.contains('Initialized'), 'Should return initialization message');
        System.assert(result.contains(year), 'Should mention the year');
    }

    // ── runAccrual ──────────────────────────────────────────────────

    @IsTest
    static void testRunAccrual() {
        String year = LeaveBalanceService.getCurrentFiscalYear();
        // Initialize balances first
        LeaveBalanceService.initializeYearlyBalances(year);

        Test.startTest();
        String result = LeavePolicyController.runAccrual(year);
        Test.stopTest();

        System.assert(result.contains('accrual completed'), 'Should return accrual message');
    }

    // ── getBalanceSummary ───────────────────────────────────────────

    @IsTest
    static void testGetBalanceSummary() {
        String year = LeaveBalanceService.getCurrentFiscalYear();
        LeaveBalanceService.initializeYearlyBalances(year);

        Test.startTest();
        Map<String, Object> summary = LeavePolicyController.getBalanceSummary(year);
        Test.stopTest();

        System.assert(summary.containsKey('totalBalances'), 'Should contain totalBalances');
        System.assert(summary.containsKey('totalPolicies'), 'Should contain totalPolicies');
        System.assert(summary.containsKey('totalEmployees'), 'Should contain totalEmployees');
    }

    @IsTest
    static void testGetBalanceSummary_NoData() {
        Test.startTest();
        Map<String, Object> summary = LeavePolicyController.getBalanceSummary('2099');
        Test.stopTest();

        System.assertEquals(0, summary.get('totalBalances'), 'Should have zero balances for future year');
    }
}
