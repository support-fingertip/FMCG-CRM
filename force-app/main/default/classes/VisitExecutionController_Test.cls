@isTest
private class VisitExecutionController_Test {

    @TestSetup
    static void setupData() {
        // Territory
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('Test Territory', 'TT-001');

        // Beats
        Beat__c beat1 = TestDataFactory.createAndInsertBeat('Beat Alpha', 'BA-001', territory.Id);
        Beat__c beat2 = TestDataFactory.createAndInsertBeat('Beat Beta', 'BB-002', territory.Id);

        // Accounts (Outlets)
        Account acct1 = TestDataFactory.createAccountWithGeoData('Outlet A', 'Retailer', 19.0760, 72.8777);
        Account acct2 = TestDataFactory.createAccountWithGeoData('Outlet B', 'Retailer', 19.0770, 72.8787);
        Account acct3 = TestDataFactory.createAccountWithGeoData('Outlet C', 'Retailer', 19.0780, 72.8797);
        Account acct4 = TestDataFactory.createAccountWithGeoData('Outlet D', 'Retailer', 19.0790, 72.8807);
        insert new List<Account>{ acct1, acct2, acct3, acct4 };

        // Beat Outlets (with sequence)
        Beat_Outlet__c bo1 = TestDataFactory.createBeatOutlet(beat1.Id, acct1.Id);
        bo1.Visit_Sequence__c = 1;
        Beat_Outlet__c bo2 = TestDataFactory.createBeatOutlet(beat1.Id, acct2.Id);
        bo2.Visit_Sequence__c = 2;
        Beat_Outlet__c bo3 = TestDataFactory.createBeatOutlet(beat1.Id, acct3.Id);
        bo3.Visit_Sequence__c = 3;
        insert new List<Beat_Outlet__c>{ bo1, bo2, bo3 };

        // Beat outlets for beat 2
        Beat_Outlet__c bo4 = TestDataFactory.createBeatOutlet(beat2.Id, acct4.Id);
        bo4.Visit_Sequence__c = 1;
        insert bo4;

        // Journey Plan
        String monthName = DateTime.now().format('MMMM');
        String yearStr = String.valueOf(Date.today().year());
        Journey_Plan__c jp = TestDataFactory.createJourneyPlan(UserInfo.getUserId(), monthName, yearStr);
        jp.Status__c = 'Active';
        insert jp;

        String dayOfWeek = DateTime.newInstance(Date.today(), Time.newInstance(0,0,0,0)).format('EEEE');
        Journey_Plan_Day__c jpd = TestDataFactory.createJourneyPlanDay(jp.Id, beat1.Id, dayOfWeek, 1);
        insert jpd;

        // Day Attendance
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        da.Beat__c = beat1.Id;
        da.Journey_Plan_Day__c = jpd.Id;
        insert da;
    }

    // ── Helper: get test data ────────────────────────────────────────────

    static Day_Attendance__c getAttendance() {
        return [SELECT Id, Beat__c, Original_Beat__c, Beat_Switched__c,
                       Beat_Switch_Reason__c, User__c
                FROM Day_Attendance__c LIMIT 1];
    }

    static List<Beat__c> getBeats() {
        return [SELECT Id, Name FROM Beat__c ORDER BY Name];
    }

    static List<Account> getAccounts() {
        return [SELECT Id, Name FROM Account ORDER BY Name];
    }

    // ══════════════════════════════════════════════════════════════════════
    //  TEST: getDayContext
    // ══════════════════════════════════════════════════════════════════════

    @isTest
    static void testGetDayContext() {
        Test.startTest();
        VisitExecutionController.VisitDayContext ctx = VisitExecutionController.getDayContext();
        Test.stopTest();

        System.assertNotEquals(null, ctx, 'Context should not be null');
        System.assertEquals(true, ctx.isDayStarted, 'Day should be started');
        System.assertNotEquals(null, ctx.dayAttendance, 'Day attendance should exist');
        System.assertNotEquals(null, ctx.currentBeat, 'Current beat should be populated');
        System.assert(ctx.outlets.size() > 0, 'Should have beat outlets');
        System.assert(ctx.availableBeats.size() > 0, 'Should have available beats');
    }

    // ══════════════════════════════════════════════════════════════════════
    //  TEST: switchBeat
    // ══════════════════════════════════════════════════════════════════════

    @isTest
    static void testSwitchBeat_success() {
        Day_Attendance__c da = getAttendance();
        List<Beat__c> beats = getBeats();
        Id originalBeatId = da.Beat__c;
        Beat__c newBeat = null;
        for (Beat__c b : beats) {
            if (b.Id != originalBeatId) {
                newBeat = b;
                break;
            }
        }
        System.assertNotEquals(null, newBeat, 'Should have a different beat available');

        Test.startTest();
        VisitExecutionController.VisitDayContext ctx = VisitExecutionController.switchBeat(
            newBeat.Id, 'Road Block', 'Construction on main road'
        );
        Test.stopTest();

        System.assertNotEquals(null, ctx, 'Context should not be null after switch');
        System.assertEquals(true, ctx.isBeatSwitched, 'Beat should be marked as switched');

        Day_Attendance__c updated = getAttendance();
        System.assertEquals(newBeat.Id, updated.Beat__c, 'Beat should be updated');
        System.assertEquals(originalBeatId, updated.Original_Beat__c, 'Original beat should be stored');
        System.assertEquals(true, updated.Beat_Switched__c, 'Switched flag should be true');
    }

    @isTest
    static void testSwitchBeat_missingReason() {
        List<Beat__c> beats = getBeats();
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            VisitExecutionController.switchBeat(beats[0].Id, '', '');
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Should throw exception when reason is missing');
    }

    @isTest
    static void testSwitchBeat_missingBeatId() {
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            VisitExecutionController.switchBeat(null, 'Road Block', '');
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Should throw exception when beat is missing');
    }

    // ══════════════════════════════════════════════════════════════════════
    //  TEST: checkInFromSequence
    // ══════════════════════════════════════════════════════════════════════

    @isTest
    static void testCheckInFromSequence_firstOutlet() {
        List<Account> accounts = getAccounts();
        Day_Attendance__c da = getAttendance();
        Account firstOutlet = null;
        for (Account a : accounts) {
            if (a.Name == 'Outlet A') {
                firstOutlet = a;
                break;
            }
        }

        Map<String, Object> visitData = new Map<String, Object>{
            'accountId' => firstOutlet.Id,
            'beatId' => da.Beat__c,
            'latitude' => 19.0760,
            'longitude' => 72.8777,
            'accuracy' => 10.0,
            'isPlanned' => true,
            'batteryLevel' => 80,
            'networkStatus' => '4G'
        };

        Test.startTest();
        Visit__c result = VisitExecutionController.checkInFromSequence(
            JSON.serialize(visitData)
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Visit should be created');
        System.assertNotEquals(null, result.Id, 'Visit should have an Id');
    }

    // ══════════════════════════════════════════════════════════════════════
    //  TEST: markVisitMissed
    // ══════════════════════════════════════════════════════════════════════

    @isTest
    static void testMarkVisitMissed_withReschedule() {
        List<Account> accounts = getAccounts();
        Day_Attendance__c da = getAttendance();
        Account outlet = accounts[0];
        Date futureDate = Date.today().addDays(3);

        Test.startTest();
        Visit__c result = VisitExecutionController.markVisitMissed(
            outlet.Id, da.Beat__c, 'Shop Closed', 'Was locked', futureDate
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Missed visit should be created');
        System.assertEquals('Missed', result.Visit_Status__c, 'Status should be Missed');

        // Check rescheduled visit was created
        List<Visit__c> rescheduled = [
            SELECT Id, Visit_Date__c, Is_Rescheduled__c, Original_Visit__c
            FROM Visit__c
            WHERE Original_Visit__c = :result.Id
        ];
        System.assertEquals(1, rescheduled.size(), 'Should have one rescheduled visit');
        System.assertEquals(futureDate, rescheduled[0].Visit_Date__c, 'Reschedule date should match');
        System.assertEquals(true, rescheduled[0].Is_Rescheduled__c, 'Is_Rescheduled should be true');
    }

    @isTest
    static void testMarkVisitMissed_withoutReschedule() {
        List<Account> accounts = getAccounts();
        Day_Attendance__c da = getAttendance();

        Test.startTest();
        Visit__c result = VisitExecutionController.markVisitMissed(
            accounts[0].Id, da.Beat__c, 'Owner Not Available', 'Will try tomorrow', null
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Missed', result.Visit_Status__c);
        System.assertEquals('Owner Not Available', result.Missed_Reason__c);
    }

    @isTest
    static void testMarkVisitMissed_missingReason() {
        List<Account> accounts = getAccounts();
        Day_Attendance__c da = getAttendance();
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            VisitExecutionController.markVisitMissed(
                accounts[0].Id, da.Beat__c, '', '', null
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Should require a missed reason');
    }

    @isTest
    static void testMarkVisitMissed_pastRescheduleDate() {
        List<Account> accounts = getAccounts();
        Day_Attendance__c da = getAttendance();
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            VisitExecutionController.markVisitMissed(
                accounts[0].Id, da.Beat__c, 'Shop Closed', '',
                Date.today().addDays(-1)
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Should reject past reschedule date');
    }

    // ══════════════════════════════════════════════════════════════════════
    //  TEST: rescheduleVisit
    // ══════════════════════════════════════════════════════════════════════

    @isTest
    static void testRescheduleVisit_success() {
        List<Account> accounts = getAccounts();
        Day_Attendance__c da = getAttendance();

        // First create a missed visit
        Visit__c missedVisit = VisitExecutionController.markVisitMissed(
            accounts[0].Id, da.Beat__c, 'Shop Closed', '', null
        );

        Date newDate = Date.today().addDays(5);

        Test.startTest();
        Visit__c result = VisitExecutionController.rescheduleVisit(missedVisit.Id, newDate);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(newDate, result.Reschedule_Date__c);
    }

    @isTest
    static void testRescheduleVisit_pastDate() {
        List<Account> accounts = getAccounts();
        Day_Attendance__c da = getAttendance();

        Visit__c missedVisit = VisitExecutionController.markVisitMissed(
            accounts[0].Id, da.Beat__c, 'Shop Closed', '', null
        );

        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            VisitExecutionController.rescheduleVisit(missedVisit.Id, Date.today());
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Should reject non-future reschedule date');
    }

    // ══════════════════════════════════════════════════════════════════════
    //  TEST: skipPlannedVisit
    // ══════════════════════════════════════════════════════════════════════

    @isTest
    static void testSkipPlannedVisit_newRecord() {
        List<Account> accounts = getAccounts();
        Day_Attendance__c da = getAttendance();

        Test.startTest();
        Visit__c result = VisitExecutionController.skipPlannedVisit(
            null, accounts[0].Id, da.Beat__c, 'Shop Closed'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Skipped', result.Visit_Status__c);
    }

    @isTest
    static void testSkipPlannedVisit_missingReason() {
        List<Account> accounts = getAccounts();
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            VisitExecutionController.skipPlannedVisit(null, accounts[0].Id, null, '');
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Should require skip reason');
    }

    // ══════════════════════════════════════════════════════════════════════
    //  TEST: createAdHocVisit
    // ══════════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateAdHocVisit() {
        List<Account> accounts = getAccounts();
        // Use account D which is not in beat 1
        Account adHocAccount = null;
        for (Account a : accounts) {
            if (a.Name == 'Outlet D') {
                adHocAccount = a;
                break;
            }
        }

        Test.startTest();
        Visit__c result = VisitExecutionController.createAdHocVisit(
            adHocAccount.Id, 'Customer Request'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.Id);
    }

    @isTest
    static void testCreateAdHocVisit_missingAccount() {
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            VisitExecutionController.createAdHocVisit(null, 'test');
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Should require account');
    }

    // ══════════════════════════════════════════════════════════════════════
    //  TEST: searchOutlets
    // ══════════════════════════════════════════════════════════════════════

    @isTest
    static void testSearchOutlets() {
        Test.startTest();
        List<Account> results = VisitExecutionController.searchOutlets('Outlet');
        Test.stopTest();

        System.assert(results.size() > 0, 'Should find outlets');
    }

    @isTest
    static void testSearchOutlets_shortTerm() {
        Test.startTest();
        List<Account> results = VisitExecutionController.searchOutlets('O');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty for short search term');
    }

    // ══════════════════════════════════════════════════════════════════════
    //  TEST: DTO classes
    // ══════════════════════════════════════════════════════════════════════

    @isTest
    static void testDTOClasses() {
        VisitExecutionController.VisitDayContext ctx = new VisitExecutionController.VisitDayContext();
        System.assertNotEquals(null, ctx);

        VisitExecutionController.BeatOutletInfo info = new VisitExecutionController.BeatOutletInfo();
        info.beatOutletId = null;
        info.accountId = null;
        info.accountName = 'Test';
        info.sequence = 1;
        info.visitStatus = 'Planned';
        System.assertEquals('Test', info.accountName);
    }
}
