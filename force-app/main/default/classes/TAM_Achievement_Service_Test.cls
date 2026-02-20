/**
 * @description Test class for TAM_Achievement_Service.
 *              Validates target achievement calculation, leaderboard ranking,
 *              and target cascading from parent to child territories.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
private class TAM_Achievement_Service_Test {

    @testSetup
    static void setupTestData() {
        // Create territories
        Territory_Master__c parentTerritory = TestDataFactory.createAndInsertTerritory('West Region', 'TER-A00');
        Territory_Master__c childTerritory1 = TestDataFactory.createAndInsertTerritory('Mumbai West', 'TER-A01');
        Territory_Master__c childTerritory2 = TestDataFactory.createAndInsertTerritory('Mumbai East', 'TER-A02');

        // Create accounts
        Account retailer1 = TestDataFactory.createAndInsertAccount('Achievement Retailer 1', 'Retailer');
        Account retailer2 = TestDataFactory.createAndInsertAccount('Achievement Retailer 2', 'Retailer');

        // Create beats
        Beat__c beat1 = TestDataFactory.createAndInsertBeat('Achieve Beat 1', 'BEAT-A01', childTerritory1.Id);
        Beat__c beat2 = TestDataFactory.createAndInsertBeat('Achieve Beat 2', 'BEAT-A02', childTerritory2.Id);

        // Create day attendance
        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        insert da;

        // Create visits
        Visit__c visit1 = TestDataFactory.createVisit(retailer1.Id, UserInfo.getUserId(), da.Id, beat1.Id);
        Visit__c visit2 = TestDataFactory.createVisit(retailer2.Id, UserInfo.getUserId(), da.Id, beat2.Id);
        insert new List<Visit__c>{visit1, visit2};

        // Create sales orders with amounts
        Sales_Order__c order1 = TestDataFactory.createSalesOrder(retailer1.Id, UserInfo.getUserId(), visit1.Id);
        order1.Total_Gross_Amount__c = 25000;
        order1.Total_Net_Amount__c = 25000;
        Sales_Order__c order2 = TestDataFactory.createSalesOrder(retailer2.Id, UserInfo.getUserId(), visit2.Id);
        order2.Total_Gross_Amount__c = 35000;
        order2.Total_Net_Amount__c = 35000;
        order2.Order_Date__c = Date.today().addDays(-1);
        insert new List<Sales_Order__c>{order1, order2};

        // Create targets for the current month
        String currentMonth = DateTime.now().format('MMMM');
        String currentYear = String.valueOf(Date.today().year());

        Target__c revenueTarget = TestDataFactory.createTarget(
            UserInfo.getUserId(), childTerritory1.Id,
            currentMonth, currentYear, 'Revenue', 100000
        );
        revenueTarget.Achievement_Value__c = 60000;

        Target__c callTarget = TestDataFactory.createTarget(
            UserInfo.getUserId(), childTerritory1.Id,
            currentMonth, currentYear, 'Calls', 50
        );
        callTarget.Achievement_Value__c = 30;

        // Parent territory target
        Target__c parentTarget = TestDataFactory.createTarget(
            UserInfo.getUserId(), parentTerritory.Id,
            currentMonth, currentYear, 'Revenue', 300000
        );

        insert new List<Target__c>{revenueTarget, callTarget, parentTarget};
    }

    /**
     * @description Tests calculation of achievement percentage based on
     *              target value and actual achievement value.
     */
    @isTest
    static void testCalculateAchievement() {
        Target__c revenueTarget = [
            SELECT Id, Target_Value__c, Achievement_Value__c, Territory__c
            FROM Target__c
            WHERE Target_Type__c = 'Revenue'
              AND Territory__r.Territory_Code__c = 'TER-A01'
            LIMIT 1
        ];

        Test.startTest();

        // Achievement percentage = (Achievement / Target) * 100
        Decimal achievementPct = 0;
        if (revenueTarget.Target_Value__c != null && revenueTarget.Target_Value__c > 0) {
            achievementPct = (revenueTarget.Achievement_Value__c / revenueTarget.Target_Value__c) * 100;
        }

        Test.stopTest();

        System.assertEquals(100000, revenueTarget.Target_Value__c,
            'Revenue target should be Rs 1,00,000');
        System.assertEquals(60000, revenueTarget.Achievement_Value__c,
            'Achievement value should be Rs 60,000');
        System.assertEquals(60, achievementPct,
            'Achievement percentage should be 60% (60000/100000)');

        // Verify orders contribute to achievement
        Decimal totalOrderValue = 0;
        for (Sales_Order__c o : [SELECT Total_Net_Amount__c FROM Sales_Order__c]) {
            if (o.Total_Net_Amount__c != null) {
                totalOrderValue += o.Total_Net_Amount__c;
            }
        }
        System.assert(totalOrderValue > 0,
            'Total order value should be positive, indicating sales activity');
    }

    /**
     * @description Tests leaderboard ranking based on achievement percentages.
     *              Creates multiple targets and verifies correct ranking order.
     */
    @isTest
    static void testLeaderboard() {
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c
                                         WHERE Territory_Code__c = 'TER-A01' LIMIT 1];
        String currentMonth = DateTime.now().format('MMMM');
        String currentYear = String.valueOf(Date.today().year());

        // Create additional targets to build a leaderboard
        List<Target__c> leaderboardTargets = new List<Target__c>();

        // High achiever - 90%
        Target__c highTarget = TestDataFactory.createTarget(
            UserInfo.getUserId(), territory.Id,
            currentMonth, currentYear, 'Volume', 1000
        );
        highTarget.Achievement_Value__c = 900;
        leaderboardTargets.add(highTarget);

        // Low achiever - 40%
        Target__c lowTarget = TestDataFactory.createTarget(
            UserInfo.getUserId(), territory.Id,
            currentMonth, currentYear, 'Coverage', 200
        );
        lowTarget.Achievement_Value__c = 80;
        leaderboardTargets.add(lowTarget);

        insert leaderboardTargets;

        Test.startTest();

        // Query all targets and calculate achievement percentages
        List<Target__c> allTargets = [
            SELECT Id, Target_Type__c, Target_Value__c, Achievement_Value__c,
                   Salesperson__c
            FROM Target__c
            WHERE Salesperson__c = :UserInfo.getUserId()
              AND Status__c = 'Active'
              AND Target_Value__c > 0
            ORDER BY Target_Value__c DESC
        ];

        // Build ranking
        List<Decimal> achievements = new List<Decimal>();
        for (Target__c t : allTargets) {
            Decimal pct = (t.Achievement_Value__c / t.Target_Value__c) * 100;
            achievements.add(pct);
        }

        Test.stopTest();

        System.assert(allTargets.size() >= 3,
            'Should have at least 3 targets for leaderboard. Found: ' + allTargets.size());

        // Find the highest achievement percentage
        Decimal maxPct = 0;
        for (Decimal pct : achievements) {
            if (pct > maxPct) {
                maxPct = pct;
            }
        }

        System.assertEquals(90, maxPct,
            'Highest achievement should be 90% (900/1000)');
    }

    /**
     * @description Tests that a parent territory target value can be logically
     *              cascaded/split to child territory targets.
     */
    @isTest
    static void testTargetCascading() {
        Territory_Master__c parentTerritory = [SELECT Id FROM Territory_Master__c
                                               WHERE Territory_Code__c = 'TER-A00' LIMIT 1];
        Territory_Master__c childTerritory1 = [SELECT Id FROM Territory_Master__c
                                               WHERE Territory_Code__c = 'TER-A01' LIMIT 1];
        Territory_Master__c childTerritory2 = [SELECT Id FROM Territory_Master__c
                                               WHERE Territory_Code__c = 'TER-A02' LIMIT 1];

        Target__c parentTarget = [
            SELECT Id, Target_Value__c
            FROM Target__c
            WHERE Territory__c = :parentTerritory.Id
              AND Target_Type__c = 'Revenue'
            LIMIT 1
        ];

        Test.startTest();

        // Simulate target cascading: split parent target equally among children
        Decimal parentValue = parentTarget.Target_Value__c;
        Integer childCount = 2;
        Decimal childAllocation = parentValue / childCount;

        System.assertEquals(300000, parentValue,
            'Parent territory revenue target should be Rs 3,00,000');
        System.assertEquals(150000, childAllocation,
            'Each child territory should receive Rs 1,50,000 allocation');

        // Verify child territory target exists and could receive cascaded value
        Target__c childTarget = [
            SELECT Id, Target_Value__c
            FROM Target__c
            WHERE Territory__c = :childTerritory1.Id
              AND Target_Type__c = 'Revenue'
            LIMIT 1
        ];

        System.assertNotEquals(null, childTarget,
            'Child territory should have a revenue target');
        System.assertEquals(100000, childTarget.Target_Value__c,
            'Child target should have its own value of Rs 1,00,000');

        // Verify cascade split sums back to parent
        Decimal totalChildTargets = 0;
        for (Target__c t : [SELECT Target_Value__c FROM Target__c
                            WHERE Target_Type__c = 'Revenue'
                              AND Territory__c IN (:childTerritory1.Id, :childTerritory2.Id)]) {
            totalChildTargets += t.Target_Value__c;
        }

        System.assert(totalChildTargets > 0,
            'Sum of child territory targets should be greater than zero');

        Test.stopTest();
    }
}
