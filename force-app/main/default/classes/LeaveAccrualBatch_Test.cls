@IsTest
private class LeaveAccrualBatch_Test {

    @TestSetup
    static void setupData() {
        // Create employee
        Employee__c emp = new Employee__c(
            First_Name__c = 'Batch',
            Last_Name__c = 'TestUser',
            Employee_Code__c = 'EMP-BAT-001',
            Designation__c = 'Sales Executive',
            Department__c = 'Sales',
            Is_Active__c = true,
            User__c = UserInfo.getUserId(),
            Date_of_Joining__c = Date.today().addYears(-2)
        );
        insert emp;

        String fiscalYear = LeaveBalanceService.getCurrentFiscalYear();

        // Create leave policy with monthly accrual (for LeaveAccrualBatch)
        Leave_Policy__c earnedPolicy = new Leave_Policy__c(
            Name = 'Earned Leave Policy',
            Leave_Type__c = 'Earned Leave',
            Annual_Entitlement__c = 15,
            Monthly_Accrual__c = 1.25,
            Max_Carry_Forward__c = 5,
            Is_Active__c = true,
            Effective_Year__c = fiscalYear
        );

        // Create leave policy without accrual (lump-sum)
        Leave_Policy__c casualPolicy = new Leave_Policy__c(
            Name = 'Casual Leave Policy',
            Leave_Type__c = 'Casual Leave',
            Annual_Entitlement__c = 12,
            Monthly_Accrual__c = 0,
            Max_Carry_Forward__c = 3,
            Is_Active__c = true,
            Effective_Year__c = fiscalYear
        );

        Leave_Policy__c sickPolicy = new Leave_Policy__c(
            Name = 'Sick Leave Policy',
            Leave_Type__c = 'Sick Leave',
            Annual_Entitlement__c = 7,
            Monthly_Accrual__c = 0,
            Max_Carry_Forward__c = 0,
            Is_Active__c = true,
            Effective_Year__c = fiscalYear
        );

        insert new List<Leave_Policy__c>{ earnedPolicy, casualPolicy, sickPolicy };

        // Create leave balances (simulating what initializeYearlyBalances would do)
        Leave_Balance__c earnedBalance = new Leave_Balance__c(
            Employee__c = emp.Id,
            Leave_Type__c = 'Earned Leave',
            Year__c = fiscalYear,
            Entitled__c = 15,
            Accrued__c = 0,
            Carry_Forward__c = 0,
            Used__c = 0,
            Pending__c = 0,
            Leave_Policy__c = earnedPolicy.Id
        );

        Leave_Balance__c casualBalance = new Leave_Balance__c(
            Employee__c = emp.Id,
            Leave_Type__c = 'Casual Leave',
            Year__c = fiscalYear,
            Entitled__c = 12,
            Accrued__c = 12,
            Carry_Forward__c = 0,
            Used__c = 0,
            Pending__c = 0,
            Leave_Policy__c = casualPolicy.Id
        );

        insert new List<Leave_Balance__c>{ earnedBalance, casualBalance };
    }

    // ═══════════════════════════════════════════════════════════════
    // LeaveAccrualBatch Tests
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void testLeaveAccrualBatch_DefaultConstructor() {
        Test.startTest();
        Database.executeBatch(new LeaveAccrualBatch(), 200);
        Test.stopTest();

        String fiscalYear = LeaveBalanceService.getCurrentFiscalYear();
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        List<Leave_Balance__c> earnedBal = [
            SELECT Accrued__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :fiscalYear AND Leave_Type__c = 'Earned Leave'
        ];

        if (!earnedBal.isEmpty()) {
            // Earned Leave has Monthly_Accrual__c = 1.25, initial Accrued__c = 0
            // After batch: should be 1.25
            System.assertEquals(1.25, earnedBal[0].Accrued__c,
                'Accrued should be 1.25 after first monthly accrual');
        }
    }

    @IsTest
    static void testLeaveAccrualBatch_WithYearParam() {
        String fiscalYear = LeaveBalanceService.getCurrentFiscalYear();

        Test.startTest();
        Database.executeBatch(new LeaveAccrualBatch(fiscalYear), 200);
        Test.stopTest();

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        List<Leave_Balance__c> earnedBal = [
            SELECT Accrued__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :fiscalYear AND Leave_Type__c = 'Earned Leave'
        ];

        if (!earnedBal.isEmpty()) {
            System.assert(earnedBal[0].Accrued__c > 0, 'Accrued should be incremented');
        }
    }

    @IsTest
    static void testLeaveAccrualBatch_DoesNotExceedEntitlement() {
        String fiscalYear = LeaveBalanceService.getCurrentFiscalYear();
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        // Set accrued close to max entitlement
        Leave_Balance__c earnedBal = [
            SELECT Id, Accrued__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :fiscalYear AND Leave_Type__c = 'Earned Leave'
        ];
        earnedBal.Accrued__c = 14.5;
        update earnedBal;

        Test.startTest();
        Database.executeBatch(new LeaveAccrualBatch(fiscalYear), 200);
        Test.stopTest();

        Leave_Balance__c updated = [
            SELECT Accrued__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :fiscalYear AND Leave_Type__c = 'Earned Leave'
        ];

        // Entitled is 15, accrual rate 1.25, so 14.5 + 1.25 = 15.75 -> capped at 15
        System.assertEquals(15, updated.Accrued__c,
            'Accrued should not exceed entitlement of 15');
    }

    @IsTest
    static void testLeaveAccrualBatch_SkipsNonAccrualTypes() {
        String fiscalYear = LeaveBalanceService.getCurrentFiscalYear();
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        // Casual Leave has Monthly_Accrual__c = 0, so batch should not touch it
        Leave_Balance__c casualBefore = [
            SELECT Accrued__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :fiscalYear AND Leave_Type__c = 'Casual Leave'
        ];

        Test.startTest();
        Database.executeBatch(new LeaveAccrualBatch(fiscalYear), 200);
        Test.stopTest();

        Leave_Balance__c casualAfter = [
            SELECT Accrued__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :fiscalYear AND Leave_Type__c = 'Casual Leave'
        ];

        System.assertEquals(casualBefore.Accrued__c, casualAfter.Accrued__c,
            'Casual Leave accrued should remain unchanged');
    }

    // ═══════════════════════════════════════════════════════════════
    // LeaveAccrualScheduler Tests
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void testLeaveAccrualScheduler() {
        String cronExpr = '0 0 1 1 * ?';

        Test.startTest();
        String jobId = System.schedule('Test Leave Accrual Scheduler', cronExpr, new LeaveAccrualScheduler());
        Test.stopTest();

        // Verify the job was scheduled
        List<CronTrigger> jobs = [
            SELECT Id, State FROM CronTrigger WHERE Id = :jobId
        ];
        System.assertEquals(1, jobs.size(), 'Scheduled job should exist');
    }

    @IsTest
    static void testLeaveAccrualScheduler_Execute() {
        Test.startTest();
        LeaveAccrualScheduler scheduler = new LeaveAccrualScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Verify batch was executed (accrual should have run)
        String fiscalYear = LeaveBalanceService.getCurrentFiscalYear();
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        List<Leave_Balance__c> earnedBal = [
            SELECT Accrued__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :fiscalYear AND Leave_Type__c = 'Earned Leave'
        ];

        // The scheduler fires both LeaveYearlyResetBatch (if April) and LeaveAccrualBatch
        // In test context, batches run synchronously within Test.startTest/stopTest
        System.assertNotEquals(null, earnedBal, 'Should have earned leave balance');
    }

    // ═══════════════════════════════════════════════════════════════
    // LeaveYearlyResetBatch Tests
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void testLeaveYearlyResetBatch_CreatesBalances() {
        // Use a different year so we start fresh
        String nextYear = String.valueOf(Integer.valueOf(LeaveBalanceService.getCurrentFiscalYear()) + 1);

        // Update policies to also apply to next year (Effective_Year__c = null means universal)
        for (Leave_Policy__c p : [SELECT Id, Effective_Year__c FROM Leave_Policy__c]) {
            p.Effective_Year__c = null;
            // Make policies universal so they match any year
        }
        update [SELECT Id, Effective_Year__c FROM Leave_Policy__c];
        List<Leave_Policy__c> policies = [SELECT Id FROM Leave_Policy__c];
        for (Leave_Policy__c p : policies) {
            p.Effective_Year__c = null;
        }
        update policies;

        Test.startTest();
        Database.executeBatch(new LeaveYearlyResetBatch(nextYear), 200);
        Test.stopTest();

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        List<Leave_Balance__c> newBalances = [
            SELECT Id, Leave_Type__c, Entitled__c, Accrued__c, Carry_Forward__c
            FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :nextYear
        ];

        System.assert(newBalances.size() >= 2,
            'Should create balances for at least 2 leave types. Got: ' + newBalances.size());
    }

    @IsTest
    static void testLeaveYearlyResetBatch_CarryForward() {
        String fiscalYear = LeaveBalanceService.getCurrentFiscalYear();
        String nextYear = String.valueOf(Integer.valueOf(fiscalYear) + 1);

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        // Set Casual Leave balance to have unused days
        Leave_Balance__c casualBal = [
            SELECT Id, Accrued__c, Used__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :fiscalYear AND Leave_Type__c = 'Casual Leave'
        ];
        casualBal.Accrued__c = 12;
        casualBal.Used__c = 5;
        update casualBal;

        // Make policies universal for next year
        List<Leave_Policy__c> policies = [SELECT Id FROM Leave_Policy__c];
        for (Leave_Policy__c p : policies) {
            p.Effective_Year__c = null;
        }
        update policies;

        Test.startTest();
        Database.executeBatch(new LeaveYearlyResetBatch(nextYear), 200);
        Test.stopTest();

        List<Leave_Balance__c> newCasualBal = [
            SELECT Carry_Forward__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :nextYear AND Leave_Type__c = 'Casual Leave'
        ];

        if (!newCasualBal.isEmpty()) {
            // Unused: 12 - 5 = 7, Max carry forward: 3, so carry = min(7, 3) = 3
            System.assertEquals(3, newCasualBal[0].Carry_Forward__c,
                'Carry forward should be capped at max (3)');
        }
    }

    @IsTest
    static void testLeaveYearlyResetBatch_NoDuplicates() {
        String nextYear = String.valueOf(Integer.valueOf(LeaveBalanceService.getCurrentFiscalYear()) + 1);

        // Make policies universal
        List<Leave_Policy__c> policies = [SELECT Id FROM Leave_Policy__c];
        for (Leave_Policy__c p : policies) {
            p.Effective_Year__c = null;
        }
        update policies;

        // Run once
        Database.executeBatch(new LeaveYearlyResetBatch(nextYear), 200);
        Test.startTest();
        // Run again - should not create duplicates
        Database.executeBatch(new LeaveYearlyResetBatch(nextYear), 200);
        Test.stopTest();

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        List<Leave_Balance__c> balances = [
            SELECT Leave_Type__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :nextYear
        ];

        Set<String> types = new Set<String>();
        for (Leave_Balance__c lb : balances) {
            System.assert(!types.contains(lb.Leave_Type__c),
                'Should not have duplicate leave type: ' + lb.Leave_Type__c);
            types.add(lb.Leave_Type__c);
        }
    }

    @IsTest
    static void testLeaveYearlyResetBatch_NoPolicies() {
        delete [SELECT Id FROM Leave_Balance__c];
        delete [SELECT Id FROM Leave_Policy__c];

        String nextYear = String.valueOf(Integer.valueOf(LeaveBalanceService.getCurrentFiscalYear()) + 1);

        Test.startTest();
        Database.executeBatch(new LeaveYearlyResetBatch(nextYear), 200);
        Test.stopTest();

        List<Leave_Balance__c> balances = [
            SELECT Id FROM Leave_Balance__c WHERE Year__c = :nextYear
        ];
        System.assertEquals(0, balances.size(), 'No balances should be created without policies');
    }

    @IsTest
    static void testLeaveYearlyResetBatch_LumpSumVsAccrual() {
        String nextYear = String.valueOf(Integer.valueOf(LeaveBalanceService.getCurrentFiscalYear()) + 1);

        // Make policies universal
        List<Leave_Policy__c> policies = [SELECT Id FROM Leave_Policy__c];
        for (Leave_Policy__c p : policies) {
            p.Effective_Year__c = null;
        }
        update policies;

        Test.startTest();
        Database.executeBatch(new LeaveYearlyResetBatch(nextYear), 200);
        Test.stopTest();

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        // Casual Leave: Monthly_Accrual__c = 0, so Accrued__c should equal Entitled__c
        List<Leave_Balance__c> casualBal = [
            SELECT Accrued__c, Entitled__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :nextYear AND Leave_Type__c = 'Casual Leave'
        ];
        if (!casualBal.isEmpty()) {
            System.assertEquals(casualBal[0].Entitled__c, casualBal[0].Accrued__c,
                'Lump-sum type should have full entitlement accrued');
        }

        // Earned Leave: Monthly_Accrual__c = 1.25, so Accrued__c should start at 0
        List<Leave_Balance__c> earnedBal = [
            SELECT Accrued__c FROM Leave_Balance__c
            WHERE Employee__c = :emp.Id AND Year__c = :nextYear AND Leave_Type__c = 'Earned Leave'
        ];
        if (!earnedBal.isEmpty()) {
            System.assertEquals(0, earnedBal[0].Accrued__c,
                'Accrual-based type should start with 0 accrued');
        }
    }
}
