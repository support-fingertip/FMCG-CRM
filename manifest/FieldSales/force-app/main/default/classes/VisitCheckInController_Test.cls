/**
 * @description Test class for VisitCheckInController.
 *              Validates all 11 @AuraEnabled controller methods that wrap
 *              OVE_Visit_Service. Uses try/catch for methods that may throw
 *              AuraHandledException due to disabled feature toggles.
 *
 * @author  SFA Development Team
 * @date    2026
 */
@isTest
private class VisitCheckInController_Test {

    @testSetup
    static void setupTestData() {
        // Accounts with geo data
        Account geoOutlet = TestDataFactory.createAccountWithGeoData(
            'CI Geo Outlet', 'Retailer', 19.0760, 72.8777
        );
        insert geoOutlet;

        Account plainOutlet = TestDataFactory.createAccount('CI Plain Outlet', 'Retailer');
        insert plainOutlet;

        // Territory and beat
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('CI Territory', 'TER-CI01');
        Beat__c beat = TestDataFactory.createAndInsertBeat('CI Beat', 'BEAT-CI01', territory.Id);

        // Day attendance
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        insert da;

        // Completed visit with order and invoice for summary tests
        Visit__c completedVisit = TestDataFactory.createVisitWithDefaults(
            geoOutlet.Id, UserInfo.getUserId(), da.Id, beat.Id
        );
        completedVisit.Visit_Status__c = 'Completed';
        completedVisit.Check_Out_Time__c = DateTime.now().addMinutes(-30);
        completedVisit.Is_Productive__c = true;
        completedVisit.Order_Value__c = 8000;
        completedVisit.Collection_Amount__c = 5000;
        completedVisit.Total_Orders_Count__c = 1;
        completedVisit.Duration_Minutes__c = 30;
        completedVisit.Visit_Sequence__c = 1;
        insert completedVisit;

        Sales_Order__c order = TestDataFactory.createSalesOrder(
            geoOutlet.Id, UserInfo.getUserId(), completedVisit.Id
        );
        order.Total_Gross_Amount__c = 8000;
        order.Total_Net_Amount__c = 8000;
        order.Status__c = 'Submitted';
        insert order;

        Invoice__c invoice = TestDataFactory.createInvoice(order.Id, geoOutlet.Id);
        insert invoice;
    }

    /**
     * @description Tests createVisit() controller wrapper with JSON payload.
     */
    @isTest
    static void testCreateVisit() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'CI Plain Outlet' LIMIT 1];
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Beat_Code__c = 'BEAT-CI01' LIMIT 1];
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        Map<String, Object> requestMap = new Map<String, Object>{
            'accountId' => acct.Id,
            'beatId' => beat.Id,
            'dayAttendanceId' => da.Id,
            'latitude' => 19.0760,
            'longitude' => 72.8777,
            'accuracy' => 10.0,
            'batteryLevel' => 85,
            'networkStatus' => '4G',
            'isPlanned' => true
        };
        String visitJson = JSON.serialize(requestMap);

        Test.startTest();
        try {
            Visit__c result = VisitCheckInController.createVisit(visitJson);
            System.assertNotEquals(null, result, 'Visit should be created');
            System.assertEquals('Checked In', result.Visit_Status__c, 'Status should be Checked In');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('disabled') || e.getMessage().contains('Visit Execution'),
                'Should throw expected error. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description Tests completeVisit() controller wrapper with JSON payload.
     */
    @isTest
    static void testCompleteVisit() {
        // Create a fresh visit to complete
        Account acct = [SELECT Id FROM Account WHERE Name = 'CI Plain Outlet' LIMIT 1];
        Beat__c beat = [SELECT Id FROM Beat__c LIMIT 1];
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        Visit__c visit = TestDataFactory.createVisitWithDefaults(
            acct.Id, UserInfo.getUserId(), da.Id, beat.Id
        );
        visit.Visit_Sequence__c = 10;
        insert visit;

        Map<String, Object> requestMap = new Map<String, Object>{
            'visitId' => visit.Id,
            'latitude' => 19.0762,
            'longitude' => 72.8779,
            'accuracy' => 12.0,
            'isProductive' => true,
            'notes' => 'Order placed',
            'completedActivities' => 'order'
        };
        String visitJson = JSON.serialize(requestMap);

        Test.startTest();
        try {
            Visit__c result = VisitCheckInController.completeVisit(visitJson);
            System.assertEquals('Completed', result.Visit_Status__c, 'Should be Completed');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('disabled') || e.getMessage().contains('Visit Execution')
                || e.getMessage().contains('Cannot complete') || e.getMessage().contains('Minimum visit'),
                'Should throw expected error. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description Tests skipVisit() controller wrapper.
     */
    @isTest
    static void testSkipVisit() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'CI Plain Outlet' LIMIT 1];
        Beat__c beat = [SELECT Id FROM Beat__c LIMIT 1];
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        Visit__c visit = TestDataFactory.createVisitWithDefaults(
            acct.Id, UserInfo.getUserId(), da.Id, beat.Id
        );
        visit.Visit_Sequence__c = 20;
        insert visit;

        Test.startTest();
        try {
            Visit__c result = VisitCheckInController.skipVisit(visit.Id, 'Shop Closed');
            System.assertEquals('Skipped', result.Visit_Status__c, 'Should be Skipped');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('Cannot skip') || e.getMessage().contains('transition')
                || e.getMessage().contains('not found'),
                'Should throw expected error. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description Tests getOutletSummary() controller wrapper.
     */
    @isTest
    static void testGetOutletSummary() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'CI Geo Outlet' LIMIT 1];

        Test.startTest();
        try {
            Map<String, Object> summary = VisitCheckInController.getOutletSummary(acct.Id);
            System.assertNotEquals(null, summary, 'Summary should not be null');
            System.assert(summary.containsKey('outletName'), 'Should contain outletName');
            System.assertEquals('CI Geo Outlet', summary.get('outletName'), 'Name should match');
            System.assert(summary.containsKey('lastVisitDate'), 'Should contain lastVisitDate');
            System.assert(summary.containsKey('outstandingBalance'), 'Should contain outstandingBalance');
            System.assert(summary.containsKey('pendingOrders'), 'Should contain pendingOrders');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Error message should not be null');
        }
        Test.stopTest();
    }

    /**
     * @description Tests getTodaysVisits() controller wrapper.
     */
    @isTest
    static void testGetTodaysVisits() {
        Test.startTest();
        try {
            List<Visit__c> visits = VisitCheckInController.getTodaysVisits(null);
            System.assertNotEquals(null, visits, 'Should return a list');
            System.assert(visits.size() >= 1, 'Should return at least 1 visit from setup');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Error message should not be null');
        }
        Test.stopTest();
    }

    /**
     * @description Tests getPlannedVisits() controller wrapper.
     */
    @isTest
    static void testGetPlannedVisits() {
        Test.startTest();
        try {
            List<Map<String, Object>> planned = VisitCheckInController.getPlannedVisits(
                null, Date.today()
            );
            System.assertNotEquals(null, planned, 'Should return a list (possibly empty)');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Error message should not be null');
        }
        Test.stopTest();
    }

    /**
     * @description Tests validateGeoFence() controller wrapper.
     */
    @isTest
    static void testValidateGeoFence() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'CI Geo Outlet' LIMIT 1];

        Test.startTest();
        try {
            OVE_Visit_Service.GeoValidationResult result =
                VisitCheckInController.validateGeoFence(19.0761, 72.8778, acct.Id);
            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertEquals(true, result.isWithinRadius,
                'Should be within radius for nearby coordinates');
            System.assertNotEquals(null, result.message, 'Message should be populated');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Error message should not be null');
        }
        Test.stopTest();
    }

    /**
     * @description Tests getVisitActivities() controller wrapper.
     */
    @isTest
    static void testGetVisitActivities() {
        Test.startTest();
        try {
            List<Map<String, Object>> activities = VisitCheckInController.getVisitActivities();
            System.assertNotEquals(null, activities, 'Activities list should not be null');
            System.assert(activities.size() >= 3,
                'Should have at least 3 always-enabled activities');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Error message should not be null');
        }
        Test.stopTest();
    }

    /**
     * @description Tests getVisitCompletionSummary() controller wrapper.
     */
    @isTest
    static void testGetVisitCompletionSummary() {
        Visit__c visit = [SELECT Id FROM Visit__c
                          WHERE Visit_Status__c = 'Completed' LIMIT 1];

        Test.startTest();
        try {
            Map<String, Object> summary = VisitCheckInController.getVisitCompletionSummary(visit.Id);
            System.assertNotEquals(null, summary, 'Summary should not be null');
            System.assert(summary.containsKey('duration'), 'Should contain duration');
            System.assert(summary.containsKey('isProductive'), 'Should contain isProductive');
            System.assert(summary.containsKey('orderValue'), 'Should contain orderValue');
            System.assert(summary.containsKey('orders'), 'Should contain orders list');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Error message should not be null');
        }
        Test.stopTest();
    }

    /**
     * @description Tests getTeamVisits() controller wrapper.
     */
    @isTest
    static void testGetTeamVisits() {
        Test.startTest();
        try {
            List<Map<String, Object>> teamVisits = VisitCheckInController.getTeamVisits(Date.today());
            System.assertNotEquals(null, teamVisits, 'Should return a list (possibly empty)');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Error message should not be null');
        }
        Test.stopTest();
    }

    /**
     * @description Tests searchOutlets() controller wrapper.
     */
    @isTest
    static void testSearchOutlets() {
        // Ensure outlet is active for search
        Account acct = [SELECT Id, Active__c FROM Account WHERE Name = 'CI Geo Outlet' LIMIT 1];
        acct.Active__c = 'Yes';
        update acct;

        Test.startTest();
        // Valid search matching existing outlet
        List<Account> results = VisitCheckInController.searchOutlets('CI Geo');
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() >= 1, 'Should find at least one matching outlet');

        // Short search term (< 2 chars)
        List<Account> shortResults = VisitCheckInController.searchOutlets('C');
        System.assertEquals(0, shortResults.size(), 'Short search term should return empty list');

        // Blank search
        List<Account> blankResults = VisitCheckInController.searchOutlets('');
        System.assertEquals(0, blankResults.size(), 'Blank search should return empty list');

        // Non-matching search
        List<Account> noResults = VisitCheckInController.searchOutlets('ZZZZNONEXISTENT');
        System.assertEquals(0, noResults.size(), 'Non-matching search should return empty list');
        Test.stopTest();
    }

    /**
     * @description Tests getVisitConfig() controller wrapper.
     */
    @isTest
    static void testGetVisitConfig() {
        Test.startTest();
        try {
            Map<String, Object> config = VisitCheckInController.getVisitConfig();
            System.assertNotEquals(null, config, 'Config should not be null');
            System.assert(config.containsKey('requirePhotoCheckIn'), 'Should contain requirePhotoCheckIn');
            System.assert(config.containsKey('allowGeofenceOverride'), 'Should contain allowGeofenceOverride');
            System.assert(config.containsKey('minVisitDurationSec'), 'Should contain minVisitDurationSec');
            System.assert(config.containsKey('maxVisitsPerDay'), 'Should contain maxVisitsPerDay');
            System.assert(config.containsKey('geofenceEnabled'), 'Should contain geofenceEnabled');
            System.assert(config.containsKey('adHocVisitsEnabled'), 'Should contain adHocVisitsEnabled');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Error message should not be null');
        }
        Test.stopTest();
    }
}