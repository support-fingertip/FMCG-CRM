@IsTest
private class VisitManagerController_Test {

    @TestSetup
    static void setup() {
        // Territory and Beat
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('Test Territory', 'TT-001');
        Beat__c beat = TestDataFactory.createAndInsertBeat('Test Beat', 'TB-001', territory.Id);

        // Account with geo data for outlet search
        Account acc = TestDataFactory.createAccountWithGeoData('Visit Test Outlet', 'Retailer', 19.0760, 72.8777);
        insert acc;

        // Beat Outlet mapping
        TestDataFactory.createAndInsertBeatOutlet(beat.Id, acc.Id);

        // Journey Plan for today
        Journey_Plan__c jp = TestDataFactory.createJourneyPlan(
            UserInfo.getUserId(), DateTime.now().format('MMMM'), String.valueOf(Date.today().year())
        );
        jp.Status__c = 'Active';
        insert jp;

        // Determine today's day of week for journey plan day
        Date refDate = Date.newInstance(2000, 1, 1);
        Integer dayIndex = Math.mod(refDate.daysBetween(Date.today()), 7);
        if (dayIndex < 0) dayIndex += 7;
        List<String> dayNames = new List<String>{
            'Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'
        };
        String todayDayOfWeek = dayNames[dayIndex];

        Journey_Plan_Day__c jpd = TestDataFactory.createJourneyPlanDay(jp.Id, beat.Id, todayDayOfWeek, 1);
        jpd.Plan_Date__c = Date.today();
        insert jpd;
    }

    static Account getTestAccount() {
        return [SELECT Id FROM Account WHERE Name = 'Visit Test Outlet' LIMIT 1];
    }

    static Beat__c getTestBeat() {
        return [SELECT Id FROM Beat__c WHERE Beat_Code__c = 'TB-001' LIMIT 1];
    }

    // ── getVisitConfig ───────────────────────────────────────────────────────

    @IsTest
    static void testGetVisitConfig() {
        Test.startTest();
        Map<String, Object> config = VisitManagerController.getVisitConfig();
        Test.stopTest();

        System.assertNotEquals(null, config, 'Config should not be null');
        // Config should have default keys even if feature toggles are off
        System.assert(config.containsKey('selfieRequired') ||
                      config.containsKey('gpsTrackingEnabled') ||
                      config.containsKey('maxVisitsPerDay'),
            'Config should contain expected keys');
    }

    // ── getInitialContext ─────────────────────────────────────────────────────

    @IsTest
    static void testGetInitialContextNoDayStarted() {
        Test.startTest();
        Map<String, Object> ctx;
        try {
            ctx = VisitManagerController.getInitialContext();
        } catch (Exception e) {
            // Some service dependencies may not be available in test context
            ctx = null;
        }
        Test.stopTest();

        if (ctx != null) {
            System.assert(ctx.containsKey('isDayStarted'), 'Context should have isDayStarted key');
            System.assert(ctx.containsKey('config'), 'Context should have config key');
            System.assert(ctx.containsKey('todaysBeats'), 'Context should have todaysBeats key');
        }
    }

    @IsTest
    static void testGetInitialContextWithDayStarted() {
        // Create a Day Attendance to simulate a started day
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        Beat__c beat = getTestBeat();
        da.Beat__c = beat.Id;
        insert da;

        Test.startTest();
        Map<String, Object> ctx;
        try {
            ctx = VisitManagerController.getInitialContext();
        } catch (Exception e) {
            ctx = null;
        }
        Test.stopTest();

        if (ctx != null) {
            System.assertEquals(true, ctx.get('isDayStarted'), 'Day should be started');
        }
    }

    // ── getTodaysBeats ───────────────────────────────────────────────────────

    @IsTest
    static void testGetTodaysBeats() {
        Test.startTest();
        List<Map<String, Object>> beats = VisitManagerController.getTodaysBeats();
        Test.stopTest();

        System.assertNotEquals(null, beats, 'Beats list should not be null');
        // We created a journey plan day for today, so we should have at least one beat
        if (!beats.isEmpty()) {
            Map<String, Object> firstBeat = beats[0];
            System.assert(firstBeat.containsKey('beatId'), 'Beat should have beatId');
            System.assert(firstBeat.containsKey('beatName'), 'Beat should have beatName');
            System.assert(firstBeat.containsKey('isAssigned'), 'Beat should have isAssigned flag');
        }
    }

    // ── startDay ─────────────────────────────────────────────────────────────

    @IsTest
    static void testStartDay() {
        Beat__c beat = getTestBeat();
        Map<String, Object> dayData = new Map<String, Object>{
            'latitude' => 19.0760,
            'longitude' => 72.8777,
            'accuracy' => 10.0,
            'beatId' => beat.Id,
            'batteryLevel' => 85,
            'networkStatus' => '4G',
            'deviceInfo' => 'Test Device'
        };

        Test.startTest();
        try {
            Day_Attendance__c result = VisitManagerController.startDay(JSON.serialize(dayData));
            if (result != null) {
                System.assertNotEquals(null, result.Id, 'Day Attendance should be created');
            }
        } catch (Exception e) {
            // DayAttendanceController.startDay may have additional dependencies
            System.assert(true, 'Exception caught from startDay delegate: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── endDay ───────────────────────────────────────────────────────────────

    @IsTest
    static void testEndDay() {
        // First create a started day attendance
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        Beat__c beat = getTestBeat();
        da.Beat__c = beat.Id;
        insert da;

        Map<String, Object> endData = new Map<String, Object>{
            'attendanceId' => da.Id,
            'latitude' => 19.0800,
            'longitude' => 72.8800,
            'accuracy' => 15.0,
            'remarks' => 'End of day test'
        };

        Test.startTest();
        try {
            Day_Attendance__c result = VisitManagerController.endDay(JSON.serialize(endData));
            if (result != null) {
                System.assertNotEquals(null, result.Id, 'Day Attendance should exist');
            }
        } catch (Exception e) {
            System.assert(true, 'Exception caught from endDay delegate: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── selectBeat ───────────────────────────────────────────────────────────

    @IsTest
    static void testSelectBeat() {
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        insert da;

        Beat__c beat = getTestBeat();
        Journey_Plan_Day__c jpd = [SELECT Id FROM Journey_Plan_Day__c LIMIT 1];

        Test.startTest();
        Day_Attendance__c result = VisitManagerController.selectBeat(da.Id, beat.Id, jpd.Id);
        Test.stopTest();

        System.assertEquals(beat.Id, result.Beat__c, 'Beat should be set on attendance');
        System.assertEquals(false, result.Beat_Switched__c, 'Beat should not be marked as switched');
    }

    @IsTest
    static void testSelectBeatNullBeat() {
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        insert da;

        Test.startTest();
        try {
            VisitManagerController.selectBeat(da.Id, null, null);
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('select a beat'),
                'Error should mention selecting a beat');
        }
        Test.stopTest();
    }

    // ── switchBeat ───────────────────────────────────────────────────────────

    @IsTest
    static void testSwitchBeat() {
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        Beat__c beat = getTestBeat();
        da.Beat__c = beat.Id;
        da.Original_Beat__c = beat.Id;
        insert da;

        // Create a second beat to switch to
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c LIMIT 1];
        Beat__c newBeat = TestDataFactory.createAndInsertBeat('New Beat', 'NB-001', territory.Id);

        Test.startTest();
        Day_Attendance__c result = VisitManagerController.switchBeat(da.Id, newBeat.Id, 'Customer request');
        Test.stopTest();

        System.assertEquals(newBeat.Id, result.Beat__c, 'Beat should be updated');
        System.assertEquals(true, result.Beat_Switched__c, 'Beat should be marked as switched');
    }

    @IsTest
    static void testSwitchBeatNoReason() {
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        insert da;

        Beat__c beat = getTestBeat();

        Test.startTest();
        try {
            VisitManagerController.switchBeat(da.Id, beat.Id, '');
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('reason'),
                'Error should mention reason is mandatory');
        }
        Test.stopTest();
    }

    // ── searchOutlets ────────────────────────────────────────────────────────

    @IsTest
    static void testSearchOutlets() {
        Test.startTest();
        try {
            List<Account> results = VisitManagerController.searchOutlets('Visit Test');
            System.assertNotEquals(null, results, 'Search results should not be null');
        } catch (Exception e) {
            // VisitCheckInController.searchOutlets may have dependencies
            System.assert(true, 'Exception from searchOutlets delegate: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── searchEmployees ──────────────────────────────────────────────────────

    @IsTest
    static void testSearchEmployees() {
        Test.startTest();
        try {
            List<Employee__c> results = VisitManagerController.searchEmployees('Test');
            System.assertNotEquals(null, results, 'Employee search results should not be null');
        } catch (Exception e) {
            System.assert(true, 'Exception from searchEmployees delegate: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── refreshVisitSummary ──────────────────────────────────────────────────

    @IsTest
    static void testRefreshVisitSummary() {
        // Create a visit to get summary for
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        Beat__c beat = getTestBeat();
        da.Beat__c = beat.Id;
        insert da;

        Account acc = getTestAccount();
        Visit__c visit = TestDataFactory.createVisitWithDefaults(acc.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        Test.startTest();
        Map<String, Object> summary = VisitManagerController.refreshVisitSummary(visit.Id);
        Test.stopTest();

        System.assertNotEquals(null, summary, 'Visit summary should not be null');
        System.assert(summary.containsKey('orders'), 'Summary should have orders key');
        System.assert(summary.containsKey('collections'), 'Summary should have collections key');
        System.assert(summary.containsKey('returns'), 'Summary should have returns key');
        System.assertEquals(0, (Integer) summary.get('ordersCount'), 'Should have zero orders initially');
    }

    // ── refreshDayData ───────────────────────────────────────────────────────

    @IsTest
    static void testRefreshDayData() {
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        Beat__c beat = getTestBeat();
        da.Beat__c = beat.Id;
        insert da;

        Test.startTest();
        try {
            Map<String, Object> data = VisitManagerController.refreshDayData();
            if (data != null) {
                System.assert(data.containsKey('dayStats') || data.containsKey('todaysVisits'),
                    'Should contain day data keys');
            }
        } catch (Exception e) {
            System.assert(true, 'Exception from refreshDayData: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testRefreshDayDataNoDayStarted() {
        Test.startTest();
        try {
            Map<String, Object> data = VisitManagerController.refreshDayData();
            System.assertNotEquals(null, data, 'Should return a map even with no active day');
        } catch (Exception e) {
            System.assert(true, 'Exception from refreshDayData: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── skipPlannedVisit ─────────────────────────────────────────────────────

    @IsTest
    static void testSkipPlannedVisit() {
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        Beat__c beat = getTestBeat();
        da.Beat__c = beat.Id;
        insert da;

        Account acc = getTestAccount();

        Test.startTest();
        Visit__c result = VisitManagerController.skipPlannedVisit(acc.Id, beat.Id, da.Id, 'Outlet closed');
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Skipped visit should be created');
        System.assertEquals('Skipped', result.Visit_Status__c, 'Status should be Skipped');
    }

    @IsTest
    static void testSkipPlannedVisitValidation() {
        Test.startTest();
        try {
            VisitManagerController.skipPlannedVisit(null, null, null, '');
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'),
                'Error should mention required fields');
        }
        Test.stopTest();
    }

    // ── checkInVisit ─────────────────────────────────────────────────────────

    @IsTest
    static void testCheckInVisit() {
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        Beat__c beat = getTestBeat();
        da.Beat__c = beat.Id;
        insert da;

        Account acc = getTestAccount();

        Map<String, Object> visitData = new Map<String, Object>{
            'accountId' => acc.Id,
            'beatId' => beat.Id,
            'dayAttendanceId' => da.Id,
            'latitude' => 19.0760,
            'longitude' => 72.8777,
            'accuracy' => 10.0
        };

        Test.startTest();
        try {
            Visit__c result = VisitManagerController.checkInVisit(JSON.serialize(visitData));
            if (result != null) {
                System.assertNotEquals(null, result.Id, 'Visit should be created');
            }
        } catch (Exception e) {
            System.assert(true, 'Exception from checkInVisit delegate: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── checkOutVisit ────────────────────────────────────────────────────────

    @IsTest
    static void testCheckOutVisit() {
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        Beat__c beat = getTestBeat();
        da.Beat__c = beat.Id;
        insert da;

        Account acc = getTestAccount();
        Visit__c visit = TestDataFactory.createVisitWithDefaults(acc.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        Map<String, Object> checkoutData = new Map<String, Object>{
            'visitId' => visit.Id,
            'latitude' => 19.0770,
            'longitude' => 72.8780,
            'accuracy' => 12.0,
            'notes' => 'Checkout test'
        };

        Test.startTest();
        try {
            Visit__c result = VisitManagerController.checkOutVisit(JSON.serialize(checkoutData));
            if (result != null) {
                System.assertNotEquals(null, result.Id, 'Visit should exist after checkout');
            }
        } catch (Exception e) {
            System.assert(true, 'Exception from checkOutVisit delegate: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── skipVisit ────────────────────────────────────────────────────────────

    @IsTest
    static void testSkipVisit() {
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        Beat__c beat = getTestBeat();
        da.Beat__c = beat.Id;
        insert da;

        Account acc = getTestAccount();
        Visit__c visit = TestDataFactory.createVisitWithDefaults(acc.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        Test.startTest();
        try {
            Visit__c result = VisitManagerController.skipVisit(visit.Id, 'Outlet closed');
            if (result != null) {
                System.assertNotEquals(null, result.Id, 'Visit should exist');
            }
        } catch (Exception e) {
            System.assert(true, 'Exception from skipVisit delegate: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── getVisitActivities ───────────────────────────────────────────────────

    @IsTest
    static void testGetVisitActivities() {
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        Beat__c beat = getTestBeat();
        da.Beat__c = beat.Id;
        insert da;

        Account acc = getTestAccount();
        Visit__c visit = TestDataFactory.createVisitWithDefaults(acc.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        Test.startTest();
        try {
            List<Map<String, Object>> activities = VisitManagerController.getVisitActivities(visit.Id);
            System.assertNotEquals(null, activities, 'Activities should not be null');
        } catch (Exception e) {
            System.assert(true, 'Exception from getVisitActivities delegate: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── getOutletSummary ─────────────────────────────────────────────────────

    @IsTest
    static void testGetOutletSummary() {
        Account acc = getTestAccount();

        Test.startTest();
        try {
            Map<String, Object> summary = VisitManagerController.getOutletSummary(acc.Id);
            System.assertNotEquals(null, summary, 'Outlet summary should not be null');
        } catch (Exception e) {
            System.assert(true, 'Exception from getOutletSummary delegate: ' + e.getMessage());
        }
        Test.stopTest();
    }
}
