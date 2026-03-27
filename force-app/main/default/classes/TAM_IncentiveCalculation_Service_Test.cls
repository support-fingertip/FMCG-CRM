@isTest
private class TAM_IncentiveCalculation_Service_Test {

    @testSetup
    static void setupTestData() {
        // Create target criteria
        Target_Criteria__c criteria = new Target_Criteria__c(
            Name = 'Revenue',
            Object__c = 'Account',
            Operator__c = 'COUNT',
            Date_Field__c = 'CreatedDate',
            User_Field__c = 'OwnerId',
            Active__c = true
        );
        insert criteria;

        // Create period
        Target_Period__c period = new Target_Period__c(
            Name = 'Test Period',
            Start_Date__c = Date.today().toStartOfMonth(),
            End_Date__c = Date.today().toStartOfMonth().addMonths(1).addDays(-1),
            Is_Active__c = true,
            Type__c = 'Monthly'
        );
        insert period;

        // Create target actual with 85% achievement
        Target_Actual__c actual = new Target_Actual__c(
            Target_Criteria__c = criteria.Id,
            Target_Period__c = period.Id,
            User__c = UserInfo.getUserId(),
            Target_Value__c = 100000,
            Achievement_Value__c = 85000
        );
        insert actual;

        // Create incentive slabs
        List<Incentive_Slab__c> slabs = new List<Incentive_Slab__c>();

        slabs.add(new Incentive_Slab__c(
            Name = 'Below Threshold',
            Min_Percent__c = 0, Max_Percent__c = 49.99,
            Payout_Type__c = 'Fixed Amount', Payout_Value__c = 0,
            Multiplier__c = 0, Is_Active__c = true, Sort_Order__c = 1
        ));
        slabs.add(new Incentive_Slab__c(
            Name = 'Standard',
            Min_Percent__c = 80, Max_Percent__c = 99.99,
            Payout_Type__c = 'Percentage', Payout_Value__c = 3,
            Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 3
        ));
        slabs.add(new Incentive_Slab__c(
            Name = 'Super Achiever',
            Min_Percent__c = 100, Max_Percent__c = 999,
            Payout_Type__c = 'Percentage', Payout_Value__c = 5,
            Multiplier__c = 2.0, Is_Active__c = true, Sort_Order__c = 5
        ));
        // Criteria-specific slab
        slabs.add(new Incentive_Slab__c(
            Name = 'Revenue Bonus',
            Target_Criteria__c = criteria.Id,
            Min_Percent__c = 80, Max_Percent__c = 99.99,
            Payout_Type__c = 'Fixed Amount', Payout_Value__c = 5000,
            Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 2
        ));

        insert slabs;
    }

    @isTest
    static void testCalculateForTargetActuals_StandardSlab() {
        Target_Period__c period = [SELECT Id FROM Target_Period__c LIMIT 1];
        List<Target_Actual__c> actuals = [
            SELECT Id, User__c, Target_Criteria__c, Target_Value__c, Achievement_Value__c
            FROM Target_Actual__c
        ];

        Test.startTest();
        List<Incentive__c> results = TAM_IncentiveCalculation_Service.calculateForTargetActuals(actuals, period.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should create one incentive');
        Incentive__c inc = results[0];
        System.assertEquals('Calculated', inc.Status__c, 'Status should be Calculated');
        System.assert(inc.Achievement_Percent__c > 0, 'Achievement % should be set');
        System.assert(inc.Calculated_Amount__c > 0, 'Payout should be > 0');
        System.assertNotEquals(null, inc.Incentive_Slab_Ref__c, 'Slab should be matched');

        // 85% achievement should match criteria-specific "Revenue Bonus" slab (Fixed 5000)
        Incentive_Slab__c matched = [SELECT Name FROM Incentive_Slab__c WHERE Id = :inc.Incentive_Slab_Ref__c];
        System.assertEquals('Revenue Bonus', matched.Name, 'Should match criteria-specific slab first');
        System.assertEquals(5000, inc.Calculated_Amount__c, 'Fixed payout should be 5000 * 1.0');
    }

    @isTest
    static void testCalculateForTargetActuals_NoTarget() {
        Target_Period__c period = [SELECT Id FROM Target_Period__c LIMIT 1];

        // Create actual with zero target
        Target_Actual__c zeroActual = new Target_Actual__c(
            Target_Criteria__c = [SELECT Id FROM Target_Criteria__c LIMIT 1].Id,
            Target_Period__c = period.Id,
            User__c = UserInfo.getUserId(),
            Target_Value__c = 0,
            Achievement_Value__c = 0
        );
        insert zeroActual;

        Test.startTest();
        List<Incentive__c> results = TAM_IncentiveCalculation_Service.calculateForTargetActuals(
            new List<Target_Actual__c>{ zeroActual }, period.Id
        );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'No incentive for zero target');
    }

    @isTest
    static void testCalculateForTargetActuals_EmptyList() {
        Target_Period__c period = [SELECT Id FROM Target_Period__c LIMIT 1];

        Test.startTest();
        List<Incentive__c> results = TAM_IncentiveCalculation_Service.calculateForTargetActuals(
            new List<Target_Actual__c>(), period.Id
        );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'No incentives for empty list');
    }

    @isTest
    static void testComputePayout_Percentage() {
        Incentive_Slab__c slab = new Incentive_Slab__c(
            Payout_Type__c = 'Percentage', Payout_Value__c = 3, Multiplier__c = 1.5
        );

        Decimal result = TAM_IncentiveCalculation_Service.computePayout(100000, 85, slab);
        // 100000 * (3/100) * 1.5 = 4500
        System.assertEquals(4500, result, 'Percentage payout should be 4500');
    }

    @isTest
    static void testComputePayout_FixedAmount() {
        Incentive_Slab__c slab = new Incentive_Slab__c(
            Payout_Type__c = 'Fixed Amount', Payout_Value__c = 2000, Multiplier__c = 2.0
        );

        Decimal result = TAM_IncentiveCalculation_Service.computePayout(100000, 120, slab);
        // 2000 * 2.0 = 4000
        System.assertEquals(4000, result, 'Fixed payout should be 4000');
    }

    @isTest
    static void testUpsertExistingIncentive() {
        Target_Period__c period = [SELECT Id FROM Target_Period__c LIMIT 1];
        List<Target_Actual__c> actuals = [
            SELECT Id, User__c, Target_Criteria__c, Target_Value__c, Achievement_Value__c
            FROM Target_Actual__c
        ];

        // Calculate first time
        TAM_IncentiveCalculation_Service.calculateForTargetActuals(actuals, period.Id);
        Integer countBefore = [SELECT COUNT() FROM Incentive__c];

        // Update achievement and recalculate
        actuals[0].Achievement_Value__c = 110000;
        update actuals;

        actuals = [
            SELECT Id, User__c, Target_Criteria__c, Target_Value__c, Achievement_Value__c
            FROM Target_Actual__c
        ];

        Test.startTest();
        TAM_IncentiveCalculation_Service.calculateForTargetActuals(actuals, period.Id);
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM Incentive__c];
        System.assertEquals(countBefore, countAfter, 'Should update existing, not create new');
    }
}
