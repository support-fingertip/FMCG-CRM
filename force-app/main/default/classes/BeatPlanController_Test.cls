/**
 * @description Test class for BeatPlanController.
 *              Validates all AuraEnabled controller methods for the
 *              beatPlanCalendar LWC component.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
private class BeatPlanController_Test {

    @testSetup
    static void setupTestData() {
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('BPC Territory', 'TER-BPC01');

        List<Beat__c> beats = new List<Beat__c>();
        List<String> dayNames = new List<String>{'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'};
        for (Integer i = 0; i < 5; i++) {
            Beat__c beat = TestDataFactory.createBeat('BPC Beat ' + i, 'BEAT-BPC' + i, territory.Id);
            beat.Day_of_Week__c = dayNames[i];
            beat.Assigned_User__c = UserInfo.getUserId();
            beats.add(beat);
        }
        insert beats;

        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            accounts.add(TestDataFactory.createAccount('BPC Outlet ' + i, 'Retailer'));
        }
        insert accounts;

        // Create beat outlets
        List<Beat_Outlet__c> outlets = new List<Beat_Outlet__c>();
        for (Integer i = 0; i < 10; i++) {
            outlets.add(TestDataFactory.createBeatOutlet(beats[Math.mod(i, 5)].Id, accounts[i].Id));
        }
        insert outlets;

        // Create journey plan
        String currentMonth = DateTime.now().format('MMMM');
        String currentYear = String.valueOf(Date.today().year());
        Journey_Plan__c jp = TestDataFactory.createJourneyPlan(UserInfo.getUserId(), currentMonth, currentYear);
        jp.Territory__c = territory.Id;
        insert jp;

        List<Journey_Plan_Day__c> jpDays = new List<Journey_Plan_Day__c>();
        for (Integer i = 0; i < 5; i++) {
            jpDays.add(TestDataFactory.createJourneyPlanDay(jp.Id, beats[i].Id, dayNames[i], 1));
        }
        insert jpDays;

        // Create day attendance and visits for compliance
        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        insert da;

        List<Visit__c> visits = new List<Visit__c>();
        for (Integer i = 0; i < 3; i++) {
            Visit__c v = TestDataFactory.createVisit(accounts[i].Id, UserInfo.getUserId(), da.Id, beats[i].Id);
            v.Visit_Status__c = 'Completed';
            v.Check_Out_Time__c = DateTime.now().addMinutes(30);
            visits.add(v);
        }
        insert visits;
    }

    @isTest
    static void testGetJourneyPlanById() {
        Journey_Plan__c jp = [SELECT Id FROM Journey_Plan__c LIMIT 1];

        Test.startTest();
        BeatPlanController.JourneyPlanResult result = BeatPlanController.getJourneyPlanById(jp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.journeyPlan, 'Journey plan should not be null');
        System.assertEquals(5, result.planDays.size(), 'Should have 5 plan days');
    }

    @isTest
    static void testGetJourneyPlanByIdNotFound() {
        Test.startTest();
        // Use a fake but valid-format ID
        Id fakeId = Journey_Plan__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';
        BeatPlanController.JourneyPlanResult result = BeatPlanController.getJourneyPlanById(fakeId);
        Test.stopTest();

        System.assertEquals(null, result.journeyPlan, 'Should return null for non-existent plan');
        System.assertEquals(0, result.planDays.size(), 'Should return empty plan days');
    }

    @isTest
    static void testGetJourneyPlan() {
        String currentMonth = DateTime.now().format('MMMM');
        String currentYear = String.valueOf(Date.today().year());

        Test.startTest();
        BeatPlanController.JourneyPlanResult result = BeatPlanController.getJourneyPlan(
            UserInfo.getUserId(), currentMonth, currentYear
        );
        Test.stopTest();

        System.assertNotEquals(null, result.journeyPlan, 'Should find the journey plan');
        System.assertEquals(currentMonth, result.journeyPlan.Month__c);
    }

    @isTest
    static void testGetJourneyPlanNotFound() {
        Test.startTest();
        BeatPlanController.JourneyPlanResult result = BeatPlanController.getJourneyPlan(
            UserInfo.getUserId(), 'January', '2099'
        );
        Test.stopTest();

        System.assertEquals(null, result.journeyPlan, 'Should return null when no plan found');
    }

    @isTest
    static void testGetBeatsForTerritory() {
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c LIMIT 1];

        Test.startTest();
        List<Beat__c> beats = BeatPlanController.getBeatsForTerritory(territory.Id);
        Test.stopTest();

        System.assertEquals(5, beats.size(), 'Should return 5 active beats for the territory');
    }

    @isTest
    static void testGetBeatsForUser() {
        Test.startTest();
        List<Beat__c> beats = BeatPlanController.getBeatsForUser(UserInfo.getUserId());
        Test.stopTest();

        System.assert(beats.size() > 0, 'Should return beats for the user');
    }

    @isTest
    static void testSubmitForApprovalAlreadyApproved() {
        Journey_Plan__c jp = [SELECT Id FROM Journey_Plan__c LIMIT 1];
        jp.Status__c = 'Submitted';
        update jp;
        jp.Status__c = 'Approved';
        update jp;

        Test.startTest();
        try {
            BeatPlanController.submitForApproval(jp.Id);
            System.assert(false, 'Should throw exception for already approved plan');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('already been approved'),
                'Error should mention plan is already approved');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveJourneyPlanDays() {
        Journey_Plan__c jp = [SELECT Id FROM Journey_Plan__c LIMIT 1];
        Beat__c beat = [SELECT Id FROM Beat__c LIMIT 1];

        List<Journey_Plan_Day__c> newDays = new List<Journey_Plan_Day__c>();
        newDays.add(new Journey_Plan_Day__c(
            Journey_Plan__c = jp.Id,
            Beat__c = beat.Id,
            Day_of_Week__c = 'Saturday',
            Week_Number__c = '2',
            Planned_Outlets__c = 3
        ));

        Test.startTest();
        List<Journey_Plan_Day__c> saved = BeatPlanController.saveJourneyPlanDays(newDays);
        Test.stopTest();

        System.assertEquals(1, saved.size(), 'Should save one day');
        System.assertNotEquals(null, saved[0].Id, 'Saved day should have an Id');
    }

    @isTest
    static void testSaveJourneyPlanDaysLocked() {
        Journey_Plan__c jp = [SELECT Id FROM Journey_Plan__c LIMIT 1];
        jp.Status__c = 'Submitted';
        update jp;
        jp.Status__c = 'Approved';
        update jp;

        Beat__c beat = [SELECT Id FROM Beat__c LIMIT 1];
        List<Journey_Plan_Day__c> newDays = new List<Journey_Plan_Day__c>();
        newDays.add(new Journey_Plan_Day__c(
            Journey_Plan__c = jp.Id,
            Beat__c = beat.Id,
            Day_of_Week__c = 'Saturday',
            Planned_Outlets__c = 3
        ));

        Test.startTest();
        try {
            BeatPlanController.saveJourneyPlanDays(newDays);
            System.assert(false, 'Should throw exception for locked plan');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('submitted or approved'),
                'Error should mention plan is locked');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveJourneyPlanDaysEmpty() {
        Test.startTest();
        try {
            BeatPlanController.saveJourneyPlanDays(new List<Journey_Plan_Day__c>());
            System.assert(false, 'Should throw exception for empty list');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('No journey plan day'),
                'Error should mention no entries provided');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetPlanCompliance() {
        Journey_Plan__c jp = [SELECT Id FROM Journey_Plan__c LIMIT 1];

        Test.startTest();
        Decimal compliance = BeatPlanController.getPlanCompliance(jp.Id);
        Test.stopTest();

        System.assert(compliance >= 0 && compliance <= 100,
            'Compliance should be between 0 and 100');
    }
}
