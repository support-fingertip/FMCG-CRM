@isTest
public class ExpenseController_Test {

    @TestSetup
    static void setupTestData() {
        Employee__c emp = new Employee__c(
            First_Name__c = 'Controller',
            Last_Name__c = 'Test',
            Employee_Code__c = 'EMP-CTRL01',
            Is_Active__c = true,
            User__c = UserInfo.getUserId(),
            Band__c = 'Band 2'
        );
        insert emp;

        List<Day_Attendance__c> attendances = new List<Day_Attendance__c>();
        Date monthStart = Date.newInstance(Date.today().year(), Date.today().month(), 1);
        for (Integer i = 0; i < 3; i++) {
            attendances.add(new Day_Attendance__c(
                User__c = UserInfo.getUserId(),
                Attendance_Date__c = monthStart.addDays(i),
                Start_Time__c = Datetime.newInstance(monthStart.addDays(i), Time.newInstance(9, 0, 0, 0)),
                Distance_Traveled_Km__c = 20
            ));
        }
        insert attendances;

        Expense_Eligibility__c rule = new Expense_Eligibility__c(
            Band__c = 'Band 2', Expense_Type__c = 'Daily Allowance', Expense_Category__c = 'Travel',
            Rate_Type__c = 'Per Day', Rate_Amount__c = 500, Max_Per_Day__c = 500,
            Max_Per_Month__c = 15000, Is_Active__c = true, Sort_Order__c = 1
        );
        insert rule;
    }

    @isTest
    static void testGetOrCreateReport() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];

        Test.startTest();
        Expense__c report = ExpenseController.getOrCreateReport(monthName, today.year());
        Test.stopTest();

        System.assertNotEquals(null, report, 'Report should be returned');
        System.assertEquals('Draft', report.Status__c, 'Status should be Draft');
    }

    @isTest
    static void testGetEligibleDates() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];

        Test.startTest();
        List<Map<String, Object>> dates = ExpenseController.getEligibleDates(monthName, today.year());
        Test.stopTest();

        System.assertEquals(3, dates.size(), 'Should have 3 eligible dates');
    }

    @isTest
    static void testGetEligibilityRules() {
        Test.startTest();
        List<Expense_Eligibility__c> rules = ExpenseController.getEligibilityRules();
        Test.stopTest();

        System.assertEquals(1, rules.size(), 'Should have 1 rule for Band 2');
    }

    @isTest
    static void testGetExpenseItemsForDate() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);

        Expense__c report = ExpenseController.getOrCreateReport(monthName, today.year());

        Test.startTest();
        List<Expense_Item__c> items = ExpenseController.getExpenseItemsForDate(report.Id, monthStart);
        Test.stopTest();

        System.assertNotEquals(null, items, 'Should not be null');
    }

    @isTest
    static void testSaveExpenseItems() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);

        Expense__c report = ExpenseController.getOrCreateReport(monthName, today.year());

        List<Expense_Item__c> items = new List<Expense_Item__c>();
        items.add(new Expense_Item__c(
            Expense_Date__c = monthStart,
            Expense_Type__c = 'Daily Allowance',
            Expense_Category__c = 'Travel',
            GPS_Distance_KM__c = 20,
            Claimed_Amount__c = 500,
            Eligible_Amount__c = 500
        ));
        String itemsJson = JSON.serialize(items);

        Test.startTest();
        List<Expense_Item__c> saved = ExpenseController.saveExpenseItems(report.Id, itemsJson);
        Test.stopTest();

        System.assertEquals(1, saved.size(), 'Should save 1 item');
    }

    @isTest
    static void testDeleteExpenseItems() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);

        Expense__c report = ExpenseController.getOrCreateReport(monthName, today.year());
        Expense_Item__c item = new Expense_Item__c(
            Expense__c = report.Id,
            Expense_Date__c = monthStart,
            Expense_Type__c = 'Daily Allowance',
            Claimed_Amount__c = 500,
            Eligible_Amount__c = 500
        );
        insert item;

        Test.startTest();
        ExpenseController.deleteExpenseItems(new List<Id>{ item.Id });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Expense_Item__c WHERE Id = :item.Id], 'Should be deleted');
    }

    @isTest
    static void testApprovalWorkflow() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);

        Expense__c report = ExpenseController.getOrCreateReport(monthName, today.year());
        Expense_Item__c item = new Expense_Item__c(
            Expense__c = report.Id,
            Expense_Date__c = monthStart,
            Expense_Type__c = 'Daily Allowance',
            Claimed_Amount__c = 500,
            Eligible_Amount__c = 500
        );
        insert item;

        Test.startTest();
        Expense__c submitted = ExpenseController.submitReport(report.Id);
        System.assertEquals('Submitted', submitted.Status__c);

        Expense__c approved = ExpenseController.approveReport(report.Id, 'OK', 'manager');
        System.assertEquals('Manager Approved', approved.Status__c);

        Expense__c finApproved = ExpenseController.approveReport(report.Id, 'OK', 'finance');
        System.assertEquals('Finance Approved', finApproved.Status__c);

        Expense__c paid = ExpenseController.markAsPaid(report.Id);
        System.assertEquals('Paid', paid.Status__c);
        Test.stopTest();
    }

    @isTest
    static void testRejectReport() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];

        Expense__c report = ExpenseController.getOrCreateReport(monthName, today.year());
        report.Status__c = 'Submitted';
        update report;

        Test.startTest();
        Expense__c rejected = ExpenseController.rejectReport(report.Id, 'Incomplete', 'manager');
        System.assertEquals('Rejected', rejected.Status__c);
        Test.stopTest();
    }

    @isTest
    static void testGetReportSummary() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];

        Expense__c report = ExpenseController.getOrCreateReport(monthName, today.year());

        Test.startTest();
        Map<String, Object> summary = ExpenseController.getReportSummary(report.Id);
        Test.stopTest();

        System.assertNotEquals(null, summary);
    }

    @isTest
    static void testGetMonthlyOverview() {
        Test.startTest();
        List<Map<String, Object>> overview = ExpenseController.getMonthlyOverview(Date.today().year());
        Test.stopTest();

        System.assertEquals(12, overview.size());
    }

    @isTest
    static void testGetExpenseConfig() {
        Test.startTest();
        Map<String, Object> config = ExpenseController.getExpenseConfig();
        Test.stopTest();

        System.assertNotEquals(null, config);
        System.assert(config.containsKey('expenseEnabled'));
        System.assert(config.containsKey('autoCalcEnabled'));
    }

    @isTest
    static void testGetTeamExpenseReports() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];

        Test.startTest();
        List<Expense__c> teamReports = ExpenseController.getTeamExpenseReports(monthName, today.year());
        Test.stopTest();

        System.assertNotEquals(null, teamReports);
    }

    @isTest
    static void testGetSubmitSummary() {
        Date today = Date.today();
        List<String> months = new List<String>{'', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'};
        String monthName = months[today.month()];
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);

        Expense__c report = ExpenseController.getOrCreateReport(monthName, today.year());

        Expense_Item__c item = new Expense_Item__c(
            Expense__c = report.Id,
            Expense_Date__c = monthStart,
            Expense_Type__c = 'Daily Allowance',
            Expense_Category__c = 'Travel',
            Claimed_Amount__c = 500,
            Eligible_Amount__c = 500
        );
        insert item;

        Test.startTest();
        Map<String, Object> summary = ExpenseController.getSubmitSummary(report.Id);
        Test.stopTest();

        System.assertNotEquals(null, summary, 'Summary should not be null');
        System.assertEquals(1, (Integer) summary.get('totalItems'), 'Should have 1 item');
        System.assertEquals(500, (Decimal) summary.get('totalClaimed'), 'Total claimed should match');
    }
}