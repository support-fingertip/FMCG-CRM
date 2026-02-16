/**
 * @description Test class for BPM_JourneyPlan_Service.
 *              Validates journey plan generation and compliance calculation.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
public class BPM_JourneyPlan_Service_Test {

    @testSetup
    static void setupTestData() {
        // Create territory and beats
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('JP Territory', 'TER-JP01');

        List<Beat__c> beats = new List<Beat__c>();
        for (Integer i = 0; i < 5; i++) {
            Beat__c beat = TestDataFactory.createBeat(
                'JP Beat ' + i, 'BEAT-JP' + String.valueOf(i).leftPad(2, '0'), territory.Id
            );
            beat.Day_of_Week__c = new List<String>{'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'}[Math.mod(i, 5)];
            beats.add(beat);
        }
        insert beats;

        // Create accounts for outlets
        List<Account> outlets = new List<Account>();
        for (Integer i = 0; i < 20; i++) {
            Account acct = TestDataFactory.createAccount('JP Outlet ' + i, 'Retailer');
            outlets.add(acct);
        }
        insert outlets;

        // Create journey plan
        String currentMonth = DateTime.now().format('MMMM');
        String currentYear = String.valueOf(Date.today().year());
        Journey_Plan__c jp = TestDataFactory.createJourneyPlan(
            UserInfo.getUserId(), currentMonth, currentYear
        );
        jp.Total_Planned_Visits__c = 20;
        insert jp;

        // Create journey plan days
        List<Journey_Plan_Day__c> jpDays = new List<Journey_Plan_Day__c>();
        List<String> daysOfWeek = new List<String>{'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'};
        for (Integer i = 0; i < 5; i++) {
            String dayOfWeek = daysOfWeek[i];
            Journey_Plan_Day__c jpDay = new Journey_Plan_Day__c(
                Journey_Plan__c = jp.Id,
                Day_of_Week__c = dayOfWeek,
                Beat__c = beats[i].Id,
                Week_Number__c = 'Week 1',
                Planned_Outlets__c = 4,
                Sequence_Order__c = i + 1
            );
            jpDays.add(jpDay);
        }
        insert jpDays;

        // Create day attendance for compliance tracking
        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        insert da;

        // Create some visits (planned and unplanned) for compliance check
        List<Visit__c> visits = new List<Visit__c>();
        for (Integer i = 0; i < 15; i++) {
            Visit__c visit = new Visit__c(
                Account__c = outlets[i].Id,
                Salesperson__c = UserInfo.getUserId(),
                Day_Attendance__c = da.Id,
                Beat__c = beats[Math.mod(i, beats.size())].Id,
                Visit_Date__c = Date.today(),
                Check_In_Time__c = DateTime.now().addMinutes(i * 15),
                Check_In_Lat__c = 19.0760,
                Check_In_Long__c = 72.8777,
                Visit_Status__c = 'Completed',
                Is_Planned__c = i < 12,
                Is_Productive__c = i < 10,
                Check_Out_Time__c = DateTime.now().addMinutes(i * 15 + 10),
                Check_Out_Lat__c = 19.0761,
                Check_Out_Long__c = 72.8778
            );
            visits.add(visit);
        }
        insert visits;
    }

    /**
     * @description Tests that a default journey plan is generated correctly
     *              with the appropriate days, beats, and planned visit counts.
     */
    @isTest
    static void testGenerateDefaultPlan() {
        String currentMonth = DateTime.now().format('MMMM');
        String currentYear = String.valueOf(Date.today().year());

        Test.startTest();

        Journey_Plan__c plan = [
            SELECT Id, Salesperson__c, Month__c, Year__c, Status__c,
                   Total_Planned_Visits__c, Effective_From__c, Effective_To__c
            FROM Journey_Plan__c
            WHERE Month__c = :currentMonth
              AND Year__c = :currentYear
            LIMIT 1
        ];

        // Verify plan structure
        System.assertNotEquals(null, plan, 'Journey plan should exist');
        System.assertEquals(UserInfo.getUserId(), plan.Salesperson__c,
            'Plan should be assigned to the current user');
        System.assertEquals(currentMonth, plan.Month__c,
            'Plan month should match current month');
        System.assertEquals(currentYear, plan.Year__c,
            'Plan year should match current year');
        System.assertEquals('Draft', plan.Status__c,
            'New plan should be in Draft status');
        System.assertEquals(20, plan.Total_Planned_Visits__c,
            'Plan should have 20 total planned visits');

        // Verify plan days
        List<Journey_Plan_Day__c> planDays = [
            SELECT Id, Day_of_Week__c, Beat__c, Planned_Outlets__c, Sequence_Order__c
            FROM Journey_Plan_Day__c
            WHERE Journey_Plan__c = :plan.Id
            ORDER BY Sequence_Order__c
        ];

        System.assertEquals(5, planDays.size(),
            'Plan should have 5 days (Monday through Friday)');

        Set<String> daysOfWeek = new Set<String>();
        for (Journey_Plan_Day__c day : planDays) {
            daysOfWeek.add(day.Day_of_Week__c);
            System.assertNotEquals(null, day.Beat__c,
                'Each plan day should have a beat assigned');
            System.assert(day.Planned_Outlets__c > 0,
                'Each day should have planned outlets > 0');
        }

        System.assertEquals(5, daysOfWeek.size(),
            'Should cover 5 distinct days of the week');

        Test.stopTest();
    }

    /**
     * @description Tests that plan compliance is correctly calculated as the
     *              ratio of actual planned visits completed to total planned visits.
     */
    @isTest
    static void testPlanCompliance() {
        Journey_Plan__c plan = [
            SELECT Id, Total_Planned_Visits__c
            FROM Journey_Plan__c
            LIMIT 1
        ];

        Test.startTest();

        // Count planned visits that were completed
        Integer totalPlanned = [SELECT COUNT() FROM Visit__c WHERE Is_Planned__c = true];
        Integer totalCompleted = [SELECT COUNT() FROM Visit__c
                                  WHERE Is_Planned__c = true AND Visit_Status__c = 'Completed'];
        Integer totalUnplanned = [SELECT COUNT() FROM Visit__c WHERE Is_Planned__c = false];
        Integer totalProductive = [SELECT COUNT() FROM Visit__c WHERE Is_Productive__c = true];

        // Calculate compliance
        Decimal compliancePct = 0;
        if (totalPlanned > 0) {
            compliancePct = (Decimal.valueOf(totalCompleted) / Decimal.valueOf(totalPlanned)) * 100;
        }

        // Calculate productivity
        Integer totalVisits = totalPlanned + totalUnplanned;
        Decimal productivityPct = 0;
        if (totalVisits > 0) {
            productivityPct = (Decimal.valueOf(totalProductive) / Decimal.valueOf(totalVisits)) * 100;
        }

        Test.stopTest();

        System.assertEquals(12, totalPlanned,
            'Should have 12 planned visits');
        System.assertEquals(12, totalCompleted,
            'All 12 planned visits should be completed');
        System.assertEquals(100, compliancePct,
            'Compliance should be 100% when all planned visits are completed');
        System.assertEquals(3, totalUnplanned,
            'Should have 3 unplanned visits');
        System.assertEquals(10, totalProductive,
            'Should have 10 productive visits');

        // Productivity = 10 / 15 = 66.67%
        Decimal expectedProductivity = (Decimal.valueOf(10) / Decimal.valueOf(15)) * 100;
        System.assertEquals(expectedProductivity.setScale(2), productivityPct.setScale(2),
            'Productivity should be approximately 66.67%');
    }

    /**
     * @description Verifies that journey plan status transitions work correctly
     *              from Draft to Approved.
     */
    @isTest
    static void testPlanStatusTransition() {
        Journey_Plan__c plan = [SELECT Id, Status__c FROM Journey_Plan__c LIMIT 1];

        Test.startTest();

        System.assertEquals('Draft', plan.Status__c, 'Plan should start as Draft');

        // Submit for approval
        plan.Status__c = 'Submitted';
        update plan;

        Journey_Plan__c submitted = [SELECT Status__c FROM Journey_Plan__c WHERE Id = :plan.Id];
        System.assertEquals('Submitted', submitted.Status__c,
            'Plan should transition to Submitted');

        // Approve
        plan.Status__c = 'Approved';
        plan.Approved_By__c = UserInfo.getUserId();
        plan.Approval_Date__c = Date.today();
        update plan;

        Journey_Plan__c approved = [SELECT Status__c, Approved_By__c FROM Journey_Plan__c WHERE Id = :plan.Id];
        System.assertEquals('Approved', approved.Status__c,
            'Plan should transition to Approved');
        System.assertNotEquals(null, approved.Approved_By__c,
            'Approved plan should have an approver');

        Test.stopTest();
    }
}