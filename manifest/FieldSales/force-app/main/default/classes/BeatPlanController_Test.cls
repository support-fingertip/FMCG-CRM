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

    // ── Beat CRUD Tests ──────────────────────────────────────────────

    @isTest
    static void testSaveBeatNew() {
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c LIMIT 1];

        Beat__c newBeat = new Beat__c(
            Name = 'Test New Beat',
            Beat_Code__c = 'BEAT-NEW01',
            Day_of_Week__c = 'Monday;Wednesday',
            Frequency__c = 'Weekly',
            Territory__c = territory.Id,
            Is_Active__c = true,
            Assigned_User__c = UserInfo.getUserId()
        );

        Test.startTest();
        Beat__c saved = BeatPlanController.saveBeat(newBeat);
        Test.stopTest();

        System.assertNotEquals(null, saved.Id, 'Saved beat should have an Id');
        System.assertEquals('Test New Beat', saved.Name);
    }

    @isTest
    static void testSaveBeatUpdate() {
        Beat__c existing = [SELECT Id, Name FROM Beat__c LIMIT 1];
        existing.Name = 'Updated Beat Name';

        Test.startTest();
        Beat__c saved = BeatPlanController.saveBeat(existing);
        Test.stopTest();

        System.assertEquals('Updated Beat Name', saved.Name);
    }

    @isTest
    static void testDeleteBeat() {
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c LIMIT 1];
        Beat__c beatToDelete = new Beat__c(
            Name = 'Delete Me',
            Beat_Code__c = 'BEAT-DEL01',
            Territory__c = territory.Id,
            Is_Active__c = true
        );
        insert beatToDelete;

        Test.startTest();
        BeatPlanController.deleteBeat(beatToDelete.Id);
        Test.stopTest();

        List<Beat__c> remaining = [SELECT Id FROM Beat__c WHERE Id = :beatToDelete.Id];
        System.assertEquals(0, remaining.size(), 'Beat should be deleted');
    }

    // ── Beat Outlet Management Tests ──────────────────────────────────

    @isTest
    static void testGetBeatOutlets() {
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Name = 'BPC Beat 0' LIMIT 1];

        Test.startTest();
        List<Beat_Outlet__c> outlets = BeatPlanController.getBeatOutlets(beat.Id);
        Test.stopTest();

        System.assert(outlets.size() > 0, 'Should return outlets for the beat');
    }

    @isTest
    static void testAddBeatOutlets() {
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Name = 'BPC Beat 0' LIMIT 1];

        // Create new accounts not already in this beat
        List<Account> newAccounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            newAccounts.add(new Account(Name = 'New Outlet ' + i, Type = 'Retailer'));
        }
        insert newAccounts;

        List<Id> newAccountIds = new List<Id>();
        for (Account a : newAccounts) {
            newAccountIds.add(a.Id);
        }

        Test.startTest();
        List<Beat_Outlet__c> result = BeatPlanController.addBeatOutlets(beat.Id, newAccountIds);
        Test.stopTest();

        System.assert(result.size() >= 3, 'Should have at least the 3 new outlets');
    }

    @isTest
    static void testAddBeatOutletsDuplicate() {
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Name = 'BPC Beat 0' LIMIT 1];
        // Get an account already added to this beat
        Beat_Outlet__c existingOutlet = [SELECT Account__c FROM Beat_Outlet__c WHERE Beat__c = :beat.Id LIMIT 1];

        Integer countBefore = [SELECT COUNT() FROM Beat_Outlet__c WHERE Beat__c = :beat.Id];

        Test.startTest();
        List<Beat_Outlet__c> result = BeatPlanController.addBeatOutlets(beat.Id, new List<Id>{ existingOutlet.Account__c });
        Test.stopTest();

        // Count should not increase because the account is already added
        System.assertEquals(countBefore, result.size(), 'Should not add duplicate outlet');
    }

    @isTest
    static void testRemoveBeatOutlet() {
        Beat_Outlet__c outlet = [SELECT Id FROM Beat_Outlet__c LIMIT 1];

        Test.startTest();
        BeatPlanController.removeBeatOutlet(outlet.Id);
        Test.stopTest();

        List<Beat_Outlet__c> remaining = [SELECT Id FROM Beat_Outlet__c WHERE Id = :outlet.Id];
        System.assertEquals(0, remaining.size(), 'Outlet should be removed');
    }

    // ── Calendar Day Persistence Tests ────────────────────────────────

    @isTest
    static void testAddBeatToCalendarDay() {
        Journey_Plan__c jp = [SELECT Id FROM Journey_Plan__c LIMIT 1];
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Name = 'BPC Beat 0' LIMIT 1];

        Test.startTest();
        Journey_Plan_Day__c result = BeatPlanController.addBeatToCalendarDay(
            jp.Id, beat.Id, 'Monday', 'Week 2', Date.today()
        );
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Plan day should be created');
        System.assertEquals('Monday', result.Day_of_Week__c);
        System.assertEquals(beat.Id, result.Beat__c);
    }

    @isTest
    static void testAddBeatToCalendarDayLockedPlan() {
        Journey_Plan__c jp = [SELECT Id FROM Journey_Plan__c LIMIT 1];
        jp.Status__c = 'Submitted';
        update jp;
        jp.Status__c = 'Approved';
        update jp;

        Beat__c beat = [SELECT Id FROM Beat__c LIMIT 1];

        Test.startTest();
        try {
            BeatPlanController.addBeatToCalendarDay(jp.Id, beat.Id, 'Monday', 'Week 1', Date.today());
            System.assert(false, 'Should throw exception for locked plan');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('submitted or approved'),
                'Error should mention plan is locked');
        }
        Test.stopTest();
    }

    @isTest
    static void testRemovePlanDay() {
        Journey_Plan_Day__c planDay = [SELECT Id FROM Journey_Plan_Day__c LIMIT 1];

        Test.startTest();
        BeatPlanController.removePlanDay(planDay.Id);
        Test.stopTest();

        List<Journey_Plan_Day__c> remaining = [SELECT Id FROM Journey_Plan_Day__c WHERE Id = :planDay.Id];
        System.assertEquals(0, remaining.size(), 'Plan day should be removed');
    }

    @isTest
    static void testRemovePlanDayLockedPlan() {
        Journey_Plan__c jp = [SELECT Id FROM Journey_Plan__c LIMIT 1];
        jp.Status__c = 'Submitted';
        update jp;
        jp.Status__c = 'Approved';
        update jp;

        Journey_Plan_Day__c planDay = [SELECT Id FROM Journey_Plan_Day__c WHERE Journey_Plan__c = :jp.Id LIMIT 1];

        Test.startTest();
        try {
            BeatPlanController.removePlanDay(planDay.Id);
            System.assert(false, 'Should throw exception for locked plan');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('submitted or approved'),
                'Error should mention plan is locked');
        }
        Test.stopTest();
    }

    // ── Generate Default Plan Test ────────────────────────────────────

    @isTest
    static void testGenerateDefaultPlan() {
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c LIMIT 1];

        // Use a future month so there's no existing plan for it
        Date futureDate = Date.today().addMonths(2);
        String monthName = new List<String>{
            'January','February','March','April','May','June',
            'July','August','September','October','November','December'
        }[futureDate.month() - 1];
        String yearStr = String.valueOf(futureDate.year());

        Test.startTest();
        Id planId = BeatPlanController.generateDefaultPlan(
            UserInfo.getUserId(), territory.Id, monthName, yearStr
        );
        Test.stopTest();

        System.assertNotEquals(null, planId, 'Should return a plan Id');
        Journey_Plan__c plan = [SELECT Id, Month__c, Year__c FROM Journey_Plan__c WHERE Id = :planId];
        System.assertEquals(monthName, plan.Month__c);
        System.assertEquals(yearStr, plan.Year__c);
    }
}