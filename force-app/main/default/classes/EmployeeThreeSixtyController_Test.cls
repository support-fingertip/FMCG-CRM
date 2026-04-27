/**
 * @description Test class for EmployeeThreeSixtyController.
 *              Validates getEmployeeDetails, getEmployeeKPIs, getAttendanceHistory,
 *              getLeaveHistory, getAssignedBeats, getPerformanceTrend,
 *              getRecentActivity, getDirectReports, getMyEmployeeId,
 *              and getHolidaysForMonth.
 * @author  SFA Development Team
 * @date    2024
 */
@IsTest
private class EmployeeThreeSixtyController_Test {

    @TestSetup
    static void setupTestData() {
        Id currentUserId = UserInfo.getUserId();

        // Territory
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory(
            'E360 Territory', 'TER-E360');

        // Employee (linked to current user)
        Employee__c manager = new Employee__c(
            First_Name__c = 'Test',
            Last_Name__c = 'Manager',
            Employee_Code__c = 'EMP-MGR-001',
            Department__c = 'Sales',
            Designation__c = 'Area Sales Manager',
            Phone__c = '9876543210',
            Email__c = 'manager@test.com',
            User__c = currentUserId,
            Territory__c = territory.Id,
            Is_Active__c = true,
            Date_of_Joining__c = Date.newInstance(2020, 1, 1),
            Week_Off_Days__c = 'Sunday'
        );
        insert manager;

        // Direct report employee (no linked user - we'll test with null user)
        Employee__c report = new Employee__c(
            First_Name__c = 'Direct',
            Last_Name__c = 'Report',
            Employee_Code__c = 'EMP-REP-001',
            Department__c = 'Sales',
            Designation__c = 'Sales Executive',
            Phone__c = '9876543211',
            Email__c = 'report@test.com',
            Reporting_Manager__c = manager.Id,
            Territory__c = territory.Id,
            Is_Active__c = true,
            Date_of_Joining__c = Date.newInstance(2022, 6, 1),
            User__c = currentUserId
        );
        insert report;

        // Beats assigned to user
        Beat__c beat = TestDataFactory.createBeat('E360 Beat', 'BEAT-E360', territory.Id);
        beat.Assigned_User__c = currentUserId;
        beat.Total_Outlets__c = 25;
        beat.Day_of_Week__c = 'Monday';
        insert beat;

        // Day Attendance records for current month
        Date today = Date.today();
        List<Day_Attendance__c> attendances = new List<Day_Attendance__c>();
        for (Integer i = 0; i < 5; i++) {
            Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(currentUserId);
            da.Attendance_Date__c = today.addDays(-i);
            da.Status__c = 'Completed';
            da.Total_Orders__c = 3;
            da.Total_Order_Value__c = 5000;
            da.Total_Collection__c = 4000;
            da.Total_Visits__c = 8;
            da.Productive_Calls__c = 5;
            da.Hours_Worked__c = 8.5;
            attendances.add(da);
        }
        insert attendances;

        // Holiday
        Holiday__c holiday = new Holiday__c(
            Name = 'Test Holiday',
            Holiday_Date__c = Date.newInstance(today.year(), today.month(), 15),
            Type__c = 'National',
            Is_Active__c = true
        );
        insert holiday;
    }

    // ── Helper accessors ─────────────────────────────────────────────────────

    private static Employee__c getManagerEmployee() {
        return [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-MGR-001' LIMIT 1];
    }

    // ── getEmployeeDetails: valid employee ──────────────────────────────────

    @IsTest
    static void testGetEmployeeDetailsValid() {
        Employee__c emp = getManagerEmployee();

        Test.startTest();
        Employee__c detail = EmployeeThreeSixtyController.getEmployeeDetails(emp.Id);
        Test.stopTest();

        System.assertEquals('Test', detail.First_Name__c, 'First name should match');
        System.assertEquals('Manager', detail.Last_Name__c, 'Last name should match');
        System.assertNotEquals(null, detail.Territory__c, 'Territory should be populated');
    }

    // ── getEmployeeDetails: invalid ID throws ───────────────────────────────

    @IsTest
    static void testGetEmployeeDetailsInvalid() {
        Id fakeId = Employee__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.startTest();
        try {
            EmployeeThreeSixtyController.getEmployeeDetails(fakeId);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Employee not found'),
                'Error should mention employee not found');
        }
        Test.stopTest();
    }

    // ── getEmployeeKPIs: returns comprehensive KPIs ─────────────────────────

    @IsTest
    static void testGetEmployeeKPIs() {
        Employee__c emp = getManagerEmployee();

        Test.startTest();
        Map<String, Object> kpis = EmployeeThreeSixtyController.getEmployeeKPIs(emp.Id);
        Test.stopTest();

        System.assert(kpis.containsKey('mtdAttendanceCount'), 'Should have mtdAttendanceCount');
        System.assert(kpis.containsKey('mtdTotalWorkingDays'), 'Should have mtdTotalWorkingDays');
        System.assert(kpis.containsKey('attendancePercentage'), 'Should have attendancePercentage');
        System.assert(kpis.containsKey('mtdOrderCount'), 'Should have mtdOrderCount');
        System.assert(kpis.containsKey('mtdOrderValue'), 'Should have mtdOrderValue');
        System.assert(kpis.containsKey('mtdCollectionTotal'), 'Should have mtdCollectionTotal');
        System.assert(kpis.containsKey('mtdVisitCount'), 'Should have mtdVisitCount');
        System.assert(kpis.containsKey('totalBeatsAssigned'), 'Should have totalBeatsAssigned');
        System.assert(kpis.containsKey('totalOutletsCovered'), 'Should have totalOutletsCovered');
        System.assert(kpis.containsKey('avgHoursWorked'), 'Should have avgHoursWorked');
        System.assert(kpis.containsKey('totalLeaveBalance'), 'Should have totalLeaveBalance');

        // Verify attendance-related KPIs have values
        Integer attCount = (Integer) kpis.get('mtdAttendanceCount');
        System.assert(attCount > 0, 'Attendance count should be positive');

        Decimal orderValue = (Decimal) kpis.get('mtdOrderValue');
        System.assert(orderValue > 0, 'Order value should be positive');
    }

    // ── getEmployeeKPIs: invalid employee throws ────────────────────────────

    @IsTest
    static void testGetEmployeeKPIsInvalid() {
        Id fakeId = Employee__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.startTest();
        try {
            EmployeeThreeSixtyController.getEmployeeKPIs(fakeId);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Employee not found'),
                'Error should mention employee not found');
        }
        Test.stopTest();
    }

    // ── getAttendanceHistory: returns records for current month ──────────────

    @IsTest
    static void testGetAttendanceHistory() {
        Employee__c emp = getManagerEmployee();
        Date today = Date.today();

        Test.startTest();
        List<Day_Attendance__c> records = EmployeeThreeSixtyController.getAttendanceHistory(
            emp.Id, today.year(), today.month());
        Test.stopTest();

        System.assert(!records.isEmpty(), 'Should return attendance records for current month');
        for (Day_Attendance__c da : records) {
            System.assertEquals(today.month(), da.Attendance_Date__c.month(),
                'All records should be in the requested month');
        }
    }

    // ── getLeaveHistory: returns leave requests for the year ────────────────

    @IsTest
    static void testGetLeaveHistory() {
        Employee__c emp = getManagerEmployee();

        Test.startTest();
        List<Leave_Request__c> leaves = EmployeeThreeSixtyController.getLeaveHistory(
            emp.Id, Date.today().year());
        Test.stopTest();

        // May be empty since we did not create leave requests - just verify no error
        System.assertNotEquals(null, leaves, 'Result should not be null');
    }

    // ── getAssignedBeats: returns beats for employee ────────────────────────

    @IsTest
    static void testGetAssignedBeats() {
        Employee__c emp = getManagerEmployee();

        Test.startTest();
        List<Beat__c> beats = EmployeeThreeSixtyController.getAssignedBeats(emp.Id);
        Test.stopTest();

        System.assert(!beats.isEmpty(), 'Should return at least one beat');
        System.assertEquals('E360 Beat', beats[0].Name, 'Beat name should match');
    }

    // ── getAssignedBeats: employee not found throws ─────────────────────────

    @IsTest
    static void testGetAssignedBeatsInvalid() {
        Id fakeId = Employee__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.startTest();
        try {
            EmployeeThreeSixtyController.getAssignedBeats(fakeId);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Employee not found'),
                'Error should mention employee not found');
        }
        Test.stopTest();
    }

    // ── getPerformanceTrend: returns monthly aggregates ─────────────────────

    @IsTest
    static void testGetPerformanceTrend() {
        Employee__c emp = getManagerEmployee();

        Test.startTest();
        List<Map<String, Object>> trend = EmployeeThreeSixtyController.getPerformanceTrend(emp.Id, 6);
        Test.stopTest();

        System.assert(!trend.isEmpty(), 'Performance trend should have data');
        Map<String, Object> row = trend[0];
        System.assert(row.containsKey('month'), 'Row should have month');
        System.assert(row.containsKey('orderCount'), 'Row should have orderCount');
        System.assert(row.containsKey('orderValue'), 'Row should have orderValue');
    }

    // ── getPerformanceTrend: null months defaults to 6 ──────────────────────

    @IsTest
    static void testGetPerformanceTrendDefaultMonths() {
        Employee__c emp = getManagerEmployee();

        Test.startTest();
        List<Map<String, Object>> trend = EmployeeThreeSixtyController.getPerformanceTrend(emp.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, trend, 'Result should not be null');
    }

    // ── getPerformanceTrend: capped at 24 months ────────────────────────────

    @IsTest
    static void testGetPerformanceTrendMaxMonths() {
        Employee__c emp = getManagerEmployee();

        Test.startTest();
        List<Map<String, Object>> trend = EmployeeThreeSixtyController.getPerformanceTrend(emp.Id, 100);
        Test.stopTest();

        System.assertNotEquals(null, trend, 'Result should not be null even with excessive months');
    }

    // ── getRecentActivity: returns recent attendance records ─────────────────

    @IsTest
    static void testGetRecentActivity() {
        Employee__c emp = getManagerEmployee();

        Test.startTest();
        List<Day_Attendance__c> activity = EmployeeThreeSixtyController.getRecentActivity(emp.Id, 10);
        Test.stopTest();

        System.assert(!activity.isEmpty(), 'Should return recent activity records');
        System.assert(activity.size() <= 10, 'Should not exceed requested limit');
    }

    // ── getRecentActivity: null limit defaults to 15 ────────────────────────

    @IsTest
    static void testGetRecentActivityDefaultLimit() {
        Employee__c emp = getManagerEmployee();

        Test.startTest();
        List<Day_Attendance__c> activity = EmployeeThreeSixtyController.getRecentActivity(emp.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, activity, 'Result should not be null');
    }

    // ── getRecentActivity: limit capped at 100 ─────────────────────────────

    @IsTest
    static void testGetRecentActivityMaxLimit() {
        Employee__c emp = getManagerEmployee();

        Test.startTest();
        List<Day_Attendance__c> activity = EmployeeThreeSixtyController.getRecentActivity(emp.Id, 500);
        Test.stopTest();

        System.assert(activity.size() <= 100, 'Should not exceed 100 records');
    }

    // ── getDirectReports: returns subordinates with KPIs ────────────────────

    @IsTest
    static void testGetDirectReports() {
        Employee__c mgr = getManagerEmployee();

        Test.startTest();
        List<Map<String, Object>> reports = EmployeeThreeSixtyController.getDirectReports(mgr.Id);
        Test.stopTest();

        System.assert(!reports.isEmpty(), 'Manager should have at least one direct report');
        Map<String, Object> firstReport = reports[0];
        System.assert(firstReport.containsKey('name'), 'Report should have name');
        System.assert(firstReport.containsKey('employeeCode'), 'Report should have employeeCode');
        System.assert(firstReport.containsKey('mtdAttendanceDays'), 'Report should have mtdAttendanceDays');
        System.assert(firstReport.containsKey('mtdOrderValue'), 'Report should have mtdOrderValue');
    }

    // ── getDirectReports: employee with no reports returns empty ─────────────

    @IsTest
    static void testGetDirectReportsNone() {
        Employee__c report = [SELECT Id FROM Employee__c WHERE Employee_Code__c = 'EMP-REP-001' LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> results = EmployeeThreeSixtyController.getDirectReports(report.Id);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Employee with no reports should return empty list');
    }

    // ── getMyEmployeeId: returns current user's employee Id ─────────────────

    @IsTest
    static void testGetMyEmployeeId() {
        Test.startTest();
        Id empId = EmployeeThreeSixtyController.getMyEmployeeId();
        Test.stopTest();

        System.assertNotEquals(null, empId, 'Should return an Employee Id for current user');

        Employee__c emp = [SELECT Employee_Code__c FROM Employee__c WHERE Id = :empId];
        System.assert(emp.Employee_Code__c != null, 'Returned employee should have a code');
    }

    // ── getHolidaysForMonth: returns holidays ───────────────────────────────

    @IsTest
    static void testGetHolidaysForMonth() {
        Employee__c emp = getManagerEmployee();
        Date today = Date.today();

        Test.startTest();
        List<Holiday__c> holidays = EmployeeThreeSixtyController.getHolidaysForMonth(
            emp.Id, today.year(), today.month());
        Test.stopTest();

        System.assertNotEquals(null, holidays, 'Result should not be null');
    }

    // ── getHolidaysForMonth: null employee returns non-territory holidays ────

    @IsTest
    static void testGetHolidaysForMonthNoEmployee() {
        Date today = Date.today();

        Test.startTest();
        List<Holiday__c> holidays = EmployeeThreeSixtyController.getHolidaysForMonth(
            null, today.year(), today.month());
        Test.stopTest();

        System.assertNotEquals(null, holidays, 'Result should not be null');
    }
}
