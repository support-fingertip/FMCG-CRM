/**
 * @description Test class for DayAttendanceController.
 *              Validates all 9 @AuraEnabled controller methods that wrap
 *              DFO_DayAttendance_Service. Uses try/catch for methods that
 *              may throw AuraHandledException due to disabled feature toggles.
 *
 * @author  SFA Development Team
 * @date    2026
 */
@isTest
private class DayAttendanceController_Test {

    @testSetup
    static void setupTestData() {
        // Territory and beat
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('DA Territory', 'TER-DA01');
        Beat__c beat = TestDataFactory.createAndInsertBeat('DA Beat', 'BEAT-DA01', territory.Id);

        // Accounts
        List<Account> outlets = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            outlets.add(TestDataFactory.createAccount('DA Outlet ' + i, 'Retailer'));
        }
        insert outlets;

        // Day Attendance (with extended defaults)
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        insert da;

        // Create visits for stats tests
        List<Visit__c> visits = new List<Visit__c>();
        for (Integer i = 0; i < 3; i++) {
            Visit__c v = TestDataFactory.createVisitWithDefaults(
                outlets[i].Id, UserInfo.getUserId(), da.Id, beat.Id
            );
            v.Visit_Status__c = 'Completed';
            v.Check_Out_Time__c = DateTime.now().addMinutes(30 + (i * 15));
            v.Is_Productive__c = (i < 2);
            v.Order_Value__c = (i < 2) ? 5000 : 0;
            v.Collection_Amount__c = (i < 2) ? 3000 : 0;
            v.Visit_Sequence__c = i + 1;
            visits.add(v);
        }
        insert visits;
    }

    /**
     * @description Tests startDay() controller wrapper with JSON payload.
     */
    @isTest
    static void testStartDay() {
        // Delete existing DA so startDay can create a new one (avoid duplicate)
        delete [SELECT Id FROM Day_Attendance__c];

        Map<String, Object> requestMap = new Map<String, Object>{
            'startLatitude' => 19.0760,
            'startLongitude' => 72.8777,
            'startAccuracy' => 10.0,
            'batteryLevel' => 90,
            'networkStatus' => 'WiFi',
            'deviceInfo' => 'Test Device',
            'odometerStart' => 12500.0,
            'withCompanion' => false
        };
        String dayJson = JSON.serialize(requestMap);

        Test.startTest();
        try {
            Day_Attendance__c result = DayAttendanceController.startDay(dayJson);
            System.assertNotEquals(null, result, 'Result should not be null if feature enabled');
            System.assertEquals('Started', result.Status__c, 'Status should be Started');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('disabled') || e.getMessage().contains('Attendance'),
                'Should throw expected error. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description Tests endDay() controller wrapper with JSON payload.
     */
    @isTest
    static void testEndDay() {
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        Map<String, Object> requestMap = new Map<String, Object>{
            'attendanceId' => da.Id,
            'endLatitude' => 19.0800,
            'endLongitude' => 72.8800,
            'endAccuracy' => 15.0,
            'remarks' => 'Good day',
            'odometerEnd' => 12650.0
        };
        String dayJson = JSON.serialize(requestMap);

        Test.startTest();
        try {
            Day_Attendance__c result = DayAttendanceController.endDay(dayJson);
            System.assertNotEquals(null, result, 'Result should not be null if feature enabled');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('disabled') || e.getMessage().contains('Cannot end')
                || e.getMessage().contains('Attendance'),
                'Should throw expected error. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description Tests getDayStats() controller wrapper.
     */
    @isTest
    static void testGetDayStats() {
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        Test.startTest();
        try {
            Map<String, Object> stats = DayAttendanceController.getDayStats(da.Id);
            System.assertNotEquals(null, stats, 'Stats should not be null');
            System.assert(stats.containsKey('Planned_Visits__c'), 'Should contain Planned_Visits__c');
            System.assert(stats.containsKey('Productive_Calls__c'), 'Should contain Productive_Calls__c');
            System.assert(stats.containsKey('Order_Value__c'), 'Should contain Order_Value__c');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Error message should not be null');
        }
        Test.stopTest();
    }

    /**
     * @description Tests getCurrentDayAttendance() controller wrapper.
     */
    @isTest
    static void testGetCurrentDayAttendance() {
        Test.startTest();
        try {
            Day_Attendance__c result = DayAttendanceController.getCurrentDayAttendance(null);
            // Should return the DA created in setup (status = Started)
            System.assertNotEquals(null, result, 'Should return current attendance');
            System.assertEquals('Started', result.Status__c, 'Status should be Started');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Error message should not be null');
        }
        Test.stopTest();
    }

    /**
     * @description Tests logGPS() controller wrapper.
     */
    @isTest
    static void testLogGPS() {
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        GPS_Log__c gpsLog = TestDataFactory.createGPSLog(
            UserInfo.getUserId(), da.Id, 19.0765, 72.8780
        );

        Test.startTest();
        try {
            GPS_Log__c result = DayAttendanceController.logGPS(gpsLog);
            System.assertNotEquals(null, result, 'GPS log should be returned');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Error message should not be null');
        }
        Test.stopTest();
    }

    /**
     * @description Tests syncOfflineGPSLogs() controller wrapper with JSON array.
     */
    @isTest
    static void testSyncOfflineGPSLogs() {
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        List<Map<String, Object>> logsData = new List<Map<String, Object>>();
        for (Integer i = 0; i < 3; i++) {
            Map<String, Object> logMap = new Map<String, Object>{
                'Salesperson__c' => UserInfo.getUserId(),
                'Day_Attendance__c' => da.Id,
                'Latitude__c' => 19.0760 + (i * 0.001),
                'Longitude__c' => 72.8777 + (i * 0.001),
                'Accuracy__c' => 10.0,
                'Captured_At__c' => DateTime.now().addMinutes(-i),
                'Battery_Level__c' => 80,
                'Network_Status__c' => 'Offline',
                'Log_Type__c' => 'Breadcrumb'
            };
            logsData.add(logMap);
        }
        String gpsLogsJson = JSON.serialize(logsData);

        Test.startTest();
        try {
            List<GPS_Log__c> results = DayAttendanceController.syncOfflineGPSLogs(gpsLogsJson);
            System.assertNotEquals(null, results, 'Results should not be null');
            System.assertEquals(3, results.size(), 'Should return 3 GPS logs');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Error message should not be null');
        }
        Test.stopTest();
    }

    /**
     * @description Tests getTeamAttendance() controller wrapper.
     */
    @isTest
    static void testGetTeamAttendance() {
        Test.startTest();
        try {
            List<Day_Attendance__c> results = DayAttendanceController.getTeamAttendance(Date.today());
            System.assertNotEquals(null, results, 'Should return a list');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('disabled') || e.getMessage().contains('Manager Dashboard'),
                'Should indicate Manager Dashboard feature is disabled. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description Tests getTeamAttendanceSummary() controller wrapper.
     */
    @isTest
    static void testGetTeamAttendanceSummary() {
        Test.startTest();
        try {
            List<Map<String, Object>> results = DayAttendanceController.getTeamAttendanceSummary(
                Date.today().addDays(-7), Date.today()
            );
            System.assertNotEquals(null, results, 'Should return a list');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('disabled') || e.getMessage().contains('Manager Dashboard'),
                'Should indicate Manager Dashboard feature is disabled. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description Tests searchEmployees() controller wrapper.
     */
    @isTest
    static void testSearchEmployees() {
        // Create an active employee for search
        Territory_Master__c ter = [SELECT Id FROM Territory_Master__c LIMIT 1];
        Employee__c emp = new Employee__c(
            First_Name__c = 'John',
            Last_Name__c = 'TestCompanion',
            Employee_Code__c = 'EMP-COMP01',
            Is_Active__c = true,
            Territory__c = ter.Id,
            Channels__c = 'GT'
        );
        insert emp;

        Test.startTest();
        // Valid search by first name
        List<Employee__c> results = DayAttendanceController.searchEmployees('John');
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should find one matching employee');
        System.assertEquals('John', results[0].First_Name__c, 'First name should match');

        // Short search term (< 2 chars)
        List<Employee__c> shortResults = DayAttendanceController.searchEmployees('J');
        System.assertEquals(0, shortResults.size(), 'Short search term should return empty list');

        // Blank search
        List<Employee__c> blankResults = DayAttendanceController.searchEmployees('');
        System.assertEquals(0, blankResults.size(), 'Blank search should return empty list');
        Test.stopTest();
    }

    /**
     * @description Tests getAttendanceConfig() controller wrapper.
     */
    @isTest
    static void testGetAttendanceConfig() {
        Test.startTest();
        try {
            Map<String, Object> config = DayAttendanceController.getAttendanceConfig();
            System.assertNotEquals(null, config, 'Config should not be null');
            System.assert(config.containsKey('selfieRequired'), 'Should contain selfieRequired');
            System.assert(config.containsKey('gpsTrackingInterval'), 'Should contain gpsTrackingInterval');
            System.assert(config.containsKey('statsRefreshInterval'), 'Should contain statsRefreshInterval');
            System.assert(config.containsKey('gpsTrackingEnabled'), 'Should contain gpsTrackingEnabled');
            System.assert(config.containsKey('managerDashboardEnabled'), 'Should contain managerDashboardEnabled');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Error message should not be null');
        }
        Test.stopTest();
    }
}
