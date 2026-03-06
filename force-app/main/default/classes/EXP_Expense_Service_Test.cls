@isTest
public class EXP_Expense_Service_Test {

    @TestSetup
    static void setupTestData() {
        // Create employee with band
        Employee__c emp = new Employee__c(
            First_Name__c = 'Test',
            Last_Name__c = 'Employee',
            Employee_Code__c = 'EMP-TEST01',
            Is_Active__c = true,
            User__c = UserInfo.getUserId(),
            Band__c = 'Band 1'
        );
        insert emp;

        // Create manager employee
        Employee__c mgr = new Employee__c(
            First_Name__c = 'Manager',
            Last_Name__c = 'Test',
            Employee_Code__c = 'EMP-MGR01',
            Is_Active__c = true,
            Band__c = 'Band 3'
        );
        insert mgr;
        emp.Reporting_Manager__c = mgr.Id;
        update emp;

        // Create day attendance records
        Date today = Date.today();
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);
        List<Day_Attendance__c> attendances = new List<Day_Attendance__c>();
        for (Integer i = 0; i < 5; i++) {
            attendances.add(new Day_Attendance__c(
                User__c = UserInfo.getUserId(),
                Attendance_Date__c = monthStart.addDays(i),
                Start_Time__c = Datetime.newInstance(monthStart.addDays(i), Time.newInstance(9, 0, 0, 0)),
                End_Time__c = Datetime.newInstance(monthStart.addDays(i), Time.newInstance(18, 0, 0, 0)),
                Distance_Traveled_Km__c = 25 + (i * 5)
            ));
        }
        insert attendances;

        // Create eligibility rules
        List<Expense_Eligibility__c> rules = new List<Expense_Eligibility__c>();
        rules.add(new Expense_Eligibility__c(
            Band__c = 'Band 1', Expense_Type__c = 'Daily Allowance', Expense_Category__c = 'Travel',
            Rate_Type__c = 'Per Day', Rate_Amount__c = 300, Max_Per_Day__c = 300,
            Max_Per_Month__c = 9000, Min_Distance_KM__c = 0, Is_Active__c = true, Sort_Order__c = 1
        ));
        rules.add(new Expense_Eligibility__c(
            Band__c = 'Band 1', Expense_Type__c = 'Travelling Allowance', Expense_Category__c = 'Travel',
            Rate_Type__c = 'Per KM', Rate_Amount__c = 5, Max_Per_Day__c = 500,
            Max_Per_Month__c = 15000, Min_Distance_KM__c = 10, Is_Active__c = true, Sort_Order__c = 2
        ));
        rules.add(new Expense_Eligibility__c(
            Band__c = 'Band 1', Expense_Type__c = 'Fuel', Expense_Category__c = 'Travel',
            Rate_Type__c = 'Actual', Rate_Amount__c = 0, Max_Per_Day__c = 800,
            Max_Per_Month__c = 12000, Receipt_Required__c = true, Is_Active__c = true, Sort_Order__c = 3
        ));
        rules.add(new Expense_Eligibility__c(
            Band__c = 'Band 1', Expense_Type__c = 'Food', Expense_Category__c = 'Miscellaneous',
            Rate_Type__c = 'Flat Monthly', Rate_Amount__c = 3000, Max_Per_Day__c = 200,
            Max_Per_Month__c = 3000, Is_Active__c = true, Sort_Order__c = 4
        ));
        insert rules;
    }

    @isTest
    static void testGetOrCreateReport() {
        Date today = Date.today();
        String monthName;
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        monthName = months[today.month()];

        Test.startTest();
        Expense__c report = EXP_Expense_Service.getOrCreateReport(UserInfo.getUserId(), monthName, today.year());
        Test.stopTest();

        System.assertNotEquals(null, report, 'Report should be created');
        System.assertEquals('Draft', report.Status__c, 'Status should be Draft');
        System.assertEquals(monthName, report.Month__c, 'Month should match');

        // Calling again should return same report
        Expense__c same = EXP_Expense_Service.getOrCreateReport(UserInfo.getUserId(), monthName, today.year());
        System.assertEquals(report.Id, same.Id, 'Should return existing report');
    }

    @isTest
    static void testGetEligibleDates() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];

        Test.startTest();
        List<Map<String, Object>> dates = EXP_Expense_Service.getEligibleDates(
            UserInfo.getUserId(), monthName, today.year()
        );
        Test.stopTest();

        System.assertEquals(5, dates.size(), 'Should have 5 eligible dates from test data');
    }

    @isTest
    static void testGetEligibilityRules() {
        Test.startTest();
        List<Expense_Eligibility__c> rules = EXP_Expense_Service.getEligibilityRules('Band 1');
        Test.stopTest();

        System.assertEquals(4, rules.size(), 'Should have 4 rules for Band 1');

        // Test caching — call again
        List<Expense_Eligibility__c> cached = EXP_Expense_Service.getEligibilityRules('Band 1');
        System.assertEquals(4, cached.size(), 'Cached result should match');
    }

    @isTest
    static void testGetEmployeeBand() {
        Test.startTest();
        String band = EXP_Expense_Service.getEmployeeBand(UserInfo.getUserId());
        Test.stopTest();

        System.assertEquals('Band 1', band, 'Band should be Band 1');
    }

    @isTest
    static void testCalculateEligibleAmount() {
        Expense_Item__c item = new Expense_Item__c(
            GPS_Distance_KM__c = 30,
            Claimed_Amount__c = 500
        );

        // Per Day
        Expense_Eligibility__c perDayRule = new Expense_Eligibility__c(
            Rate_Type__c = 'Per Day', Rate_Amount__c = 300, Max_Per_Day__c = 300,
            Is_Active__c = true, Min_Distance_KM__c = 0
        );
        Decimal perDayResult = EXP_Expense_Service.calculateEligibleAmount(item, perDayRule, 22);
        System.assertEquals(300, perDayResult, 'Per Day should return rate amount');

        // Per KM
        Expense_Eligibility__c perKmRule = new Expense_Eligibility__c(
            Rate_Type__c = 'Per KM', Rate_Amount__c = 5, Max_Per_Day__c = 500,
            Is_Active__c = true, Min_Distance_KM__c = 10
        );
        Decimal perKmResult = EXP_Expense_Service.calculateEligibleAmount(item, perKmRule, 22);
        System.assertEquals(150, perKmResult, 'Per KM should return distance * rate');

        // Per KM with cap
        Expense_Eligibility__c perKmCappedRule = new Expense_Eligibility__c(
            Rate_Type__c = 'Per KM', Rate_Amount__c = 20, Max_Per_Day__c = 500,
            Is_Active__c = true, Min_Distance_KM__c = 0
        );
        Decimal cappedResult = EXP_Expense_Service.calculateEligibleAmount(item, perKmCappedRule, 22);
        System.assertEquals(500, cappedResult, 'Should be capped at Max_Per_Day');

        // Actual
        Expense_Eligibility__c actualRule = new Expense_Eligibility__c(
            Rate_Type__c = 'Actual', Max_Per_Day__c = 800,
            Is_Active__c = true, Min_Distance_KM__c = 0
        );
        Decimal actualResult = EXP_Expense_Service.calculateEligibleAmount(item, actualRule, 22);
        System.assertEquals(500, actualResult, 'Actual should return claimed amount');

        // Flat Monthly
        Expense_Eligibility__c flatRule = new Expense_Eligibility__c(
            Rate_Type__c = 'Flat Monthly', Rate_Amount__c = 3000, Max_Per_Day__c = 200,
            Is_Active__c = true, Min_Distance_KM__c = 0
        );
        Decimal flatResult = EXP_Expense_Service.calculateEligibleAmount(item, flatRule, 22);
        Decimal expected = (Decimal)(3000.0 / 22).setScale(2, RoundingMode.HALF_UP);
        System.assertEquals(expected, flatResult, 'Flat Monthly should return rate/working days');

        // Min distance not met
        Expense_Eligibility__c minDistRule = new Expense_Eligibility__c(
            Rate_Type__c = 'Per KM', Rate_Amount__c = 5, Max_Per_Day__c = 500,
            Is_Active__c = true, Min_Distance_KM__c = 50
        );
        Decimal minDistResult = EXP_Expense_Service.calculateEligibleAmount(item, minDistRule, 22);
        System.assertEquals(0, minDistResult, 'Below min distance should return 0');

        // Null/inactive rule
        Decimal nullResult = EXP_Expense_Service.calculateEligibleAmount(item, null, 22);
        System.assertEquals(0, nullResult, 'Null rule should return 0');
    }

    @isTest
    static void testSaveAndGetExpenseItems() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);

        Expense__c report = EXP_Expense_Service.getOrCreateReport(UserInfo.getUserId(), monthName, today.year());

        List<Expense_Item__c> items = new List<Expense_Item__c>();
        items.add(new Expense_Item__c(
            Expense_Date__c = monthStart,
            Expense_Type__c = 'Daily Allowance',
            Expense_Category__c = 'Travel',
            GPS_Distance_KM__c = 25,
            Claimed_Amount__c = 300,
            Eligible_Amount__c = 300
        ));
        items.add(new Expense_Item__c(
            Expense_Date__c = monthStart,
            Expense_Type__c = 'Travelling Allowance',
            Expense_Category__c = 'Travel',
            GPS_Distance_KM__c = 25,
            Claimed_Amount__c = 125,
            Eligible_Amount__c = 125
        ));

        Test.startTest();
        List<Expense_Item__c> saved = EXP_Expense_Service.saveExpenseItems(report.Id, items);
        Test.stopTest();

        System.assertEquals(2, saved.size(), 'Should save 2 items');

        // Get items for date
        List<Expense_Item__c> retrieved = EXP_Expense_Service.getExpenseItemsForDate(report.Id, monthStart);
        System.assertEquals(2, retrieved.size(), 'Should retrieve 2 items for the date');
    }

    @isTest
    static void testSaveExpenseItemsValidation() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);

        Expense__c report = EXP_Expense_Service.getOrCreateReport(UserInfo.getUserId(), monthName, today.year());

        // Test distance override validation
        List<Expense_Item__c> items = new List<Expense_Item__c>();
        items.add(new Expense_Item__c(
            Expense_Date__c = monthStart,
            Expense_Type__c = 'Daily Allowance',
            Expense_Category__c = 'Travel',
            GPS_Distance_KM__c = 20,
            Manual_Distance_KM__c = 25,
            Eligible_Amount__c = 300,
            Claimed_Amount__c = 300
        ));

        Test.startTest();
        Boolean caught = false;
        try {
            // Missing override reason
            EXP_Expense_Service.saveExpenseItems(report.Id, items);
        } catch (AuraHandledException e) {
            caught = true;
        }
        System.assert(caught, 'Should throw error for missing override reason');
        Test.stopTest();
    }

    @isTest
    static void testDeleteExpenseItems() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);

        Expense__c report = EXP_Expense_Service.getOrCreateReport(UserInfo.getUserId(), monthName, today.year());

        Expense_Item__c item = new Expense_Item__c(
            Expense__c = report.Id,
            Expense_Date__c = monthStart,
            Expense_Type__c = 'Daily Allowance',
            Expense_Category__c = 'Travel',
            Claimed_Amount__c = 300,
            Eligible_Amount__c = 300
        );
        insert item;

        Test.startTest();
        EXP_Expense_Service.deleteExpenseItems(new List<Id>{ item.Id });
        Test.stopTest();

        List<Expense_Item__c> remaining = [SELECT Id FROM Expense_Item__c WHERE Id = :item.Id];
        System.assertEquals(0, remaining.size(), 'Item should be deleted');
    }

    @isTest
    static void testApprovalWorkflow() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);

        Expense__c report = EXP_Expense_Service.getOrCreateReport(UserInfo.getUserId(), monthName, today.year());

        // Add an item
        Expense_Item__c item = new Expense_Item__c(
            Expense__c = report.Id,
            Expense_Date__c = monthStart,
            Expense_Type__c = 'Daily Allowance',
            Expense_Category__c = 'Travel',
            Claimed_Amount__c = 300,
            Eligible_Amount__c = 300
        );
        insert item;

        Test.startTest();
        // Submit
        Expense__c submitted = EXP_Expense_Service.submitReport(report.Id);
        System.assertEquals('Submitted', submitted.Status__c, 'Should be Submitted');

        // Manager approve
        Expense__c approved = EXP_Expense_Service.approveReport(report.Id, 'Looks good', 'manager');
        System.assertEquals('Manager Approved', approved.Status__c, 'Should be Manager Approved');

        // Finance approve
        Expense__c finApproved = EXP_Expense_Service.approveReport(report.Id, 'Verified', 'finance');
        System.assertEquals('Finance Approved', finApproved.Status__c, 'Should be Finance Approved');

        // Mark paid
        Expense__c paid = EXP_Expense_Service.markAsPaid(report.Id);
        System.assertEquals('Paid', paid.Status__c, 'Should be Paid');
        Test.stopTest();
    }

    @isTest
    static void testRejectReport() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];

        Expense__c report = EXP_Expense_Service.getOrCreateReport(UserInfo.getUserId(), monthName, today.year());
        report.Status__c = 'Submitted';
        update report;

        Test.startTest();
        Expense__c rejected = EXP_Expense_Service.rejectReport(report.Id, 'Missing receipts', 'manager');
        System.assertEquals('Rejected', rejected.Status__c, 'Should be Rejected');
        Test.stopTest();
    }

    @isTest
    static void testGetReportSummary() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);

        Expense__c report = EXP_Expense_Service.getOrCreateReport(UserInfo.getUserId(), monthName, today.year());

        Expense_Item__c item = new Expense_Item__c(
            Expense__c = report.Id,
            Expense_Date__c = monthStart,
            Expense_Type__c = 'Daily Allowance',
            Expense_Category__c = 'Travel',
            Claimed_Amount__c = 300,
            Eligible_Amount__c = 300
        );
        insert item;

        Test.startTest();
        Map<String, Object> summary = EXP_Expense_Service.getReportSummary(report.Id);
        Test.stopTest();

        System.assertNotEquals(null, summary.get('expense'), 'Summary should include expense');
        System.assertNotEquals(null, summary.get('typeBreakdown'), 'Should include type breakdown');
        System.assertNotEquals(null, summary.get('dayBreakdown'), 'Should include day breakdown');
    }

    @isTest
    static void testGetMonthlyOverview() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];

        EXP_Expense_Service.getOrCreateReport(UserInfo.getUserId(), monthName, today.year());

        Test.startTest();
        List<Map<String, Object>> overview = EXP_Expense_Service.getMonthlyOverview(
            UserInfo.getUserId(), today.year()
        );
        Test.stopTest();

        System.assertEquals(12, overview.size(), 'Should return 12 months');
        Boolean foundReport = false;
        for (Map<String, Object> row : overview) {
            if (row.get('month') == monthName && (Boolean) row.get('hasReport')) {
                foundReport = true;
            }
        }
        System.assert(foundReport, 'Current month should have a report');
    }

    @isTest
    static void testIsValidTransition() {
        System.assert(EXP_Expense_Service.isValidTransition('Draft', 'Submitted'), 'Draft to Submitted should be valid');
        System.assert(EXP_Expense_Service.isValidTransition('Submitted', 'Manager Approved'), 'Submitted to Manager Approved should be valid');
        System.assert(EXP_Expense_Service.isValidTransition('Submitted', 'Rejected'), 'Submitted to Rejected should be valid');
        System.assert(!EXP_Expense_Service.isValidTransition('Draft', 'Manager Approved'), 'Draft to Manager Approved should be invalid');
        System.assert(!EXP_Expense_Service.isValidTransition('Paid', 'Draft'), 'Paid to Draft should be invalid');
    }

    @isTest
    static void testConfigHelpers() {
        Test.startTest();
        Boolean boolVal = EXP_Expense_Service.getConfigBoolean('ALLOW_FUTURE_DATES', false);
        Integer intVal = EXP_Expense_Service.getConfigInteger('MAX_OVERRIDE_PERCENT', 150);
        String strVal = EXP_Expense_Service.getAppConfig('NON_EXISTENT', 'default');
        Test.stopTest();

        System.assertNotEquals(null, boolVal, 'Boolean config should not be null');
        System.assertNotEquals(null, intVal, 'Integer config should not be null');
        System.assertEquals('default', strVal, 'Non-existent key should return default');
    }

    @isTest
    static void testClearCache() {
        EXP_Expense_Service.getEligibilityRules('Band 1');
        EXP_Expense_Service.getAppConfig('test', 'val');

        Test.startTest();
        EXP_Expense_Service.clearCache();
        Test.stopTest();

        // After clear, next call should re-query
        List<Expense_Eligibility__c> rules = EXP_Expense_Service.getEligibilityRules('Band 1');
        System.assertEquals(4, rules.size(), 'Should re-fetch after cache clear');
    }

    @isTest
    static void testGetTeamExpenseReports() {
        // The manager user doesn't have an employee linked, so this should throw
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];

        Test.startTest();
        // Current user IS the employee, not the manager — so team reports will be empty
        List<Expense__c> teamReports = EXP_Expense_Service.getTeamExpenseReports(
            UserInfo.getUserId(), monthName, today.year()
        );
        Test.stopTest();

        System.assertNotEquals(null, teamReports, 'Should not be null');
    }

    @isTest
    static void testPopulateEligibilityFields() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);

        Expense__c report = EXP_Expense_Service.getOrCreateReport(UserInfo.getUserId(), monthName, today.year());

        Day_Attendance__c att = [
            SELECT Id FROM Day_Attendance__c
            WHERE Attendance_Date__c = :monthStart LIMIT 1
        ];

        List<Expense_Item__c> items = new List<Expense_Item__c>();
        items.add(new Expense_Item__c(
            Expense__c = report.Id,
            Expense_Date__c = monthStart,
            Expense_Type__c = 'Daily Allowance',
            Day_Attendance__c = att.Id,
            Claimed_Amount__c = 300
        ));

        Test.startTest();
        EXP_Expense_Service.populateEligibilityFields(items, report.Id);
        Test.stopTest();

        System.assertEquals('Per Day', items[0].Rate_Type__c, 'Rate type should be populated');
        System.assertEquals(300, items[0].Rate_Amount__c, 'Rate amount should be populated');
        System.assert(items[0].Is_Eligible__c, 'Should be eligible');
        System.assert(items[0].Eligible_Amount__c > 0, 'Eligible amount should be > 0');
    }
}