@isTest
private class API_Dashboard_Rest_Test {

    @TestSetup
    static void setup() {
        Employee__c emp = new Employee__c(
            First_Name__c = 'Test',
            Last_Name__c = 'User',
            Phone__c = '9876543210',
            Email__c = 'test@example.com',
            Employee_Code__c = 'CPC0023',
            User__c = UserInfo.getUserId(),
            Is_Active__c = true,
            Band__c = 'L1'
        );
        insert emp;

        Account acc = TestDataFactory.createAndInsertAccount('Happy Traders', 'Customer');

        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('West', 'WEST-001');
        Beat__c beat = TestDataFactory.createAndInsertBeat('Beat 1', 'B001', territory.Id);

        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        da.Total_Visits__c = 5;
        da.Productive_Calls__c = 3;
        da.Distance_Traveled_Km__c = 25;
        da.Total_Order_Value__c = 50000;
        da.Total_Orders__c = 4;
        insert da;

        Visit__c visit = TestDataFactory.createVisit(acc.Id, UserInfo.getUserId(), da.Id, beat.Id);
        visit.Visit_Status__c = 'Completed';
        visit.Is_Planned__c = true;
        visit.Is_Geo_Fenced__c = true;
        visit.Duration_Minutes__c = 30;
        visit.Check_In_Latitude__c = 25.5941;
        visit.Check_In_Longitude__c = 85.1376;
        insert visit;

        // Create a target for current month
        Date today = Date.today();
        List<String> monthNames = new List<String>{
            '', 'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };
        Target__c target = new Target__c(
            Salesperson__c = UserInfo.getUserId(),
            Target_Value__c = 400000,
            Achievement_Value__c = 150000,
            Achievement_Percent__c = 37.5,
            Month__c = monthNames[today.month()],
            Year__c = String.valueOf(today.year()),
            Status__c = 'Active',
            Period_Start__c = today.toStartOfMonth(),
            Period_End__c = Date.newInstance(today.year(), today.month(), Date.daysInMonth(today.year(), today.month()))
        );
        insert target;

        // Create expense items
        Expense__c expense = new Expense__c(
            Employee__c = emp.Id,
            Month__c = monthNames[today.month()],
            Status__c = 'Draft',
            Period_Start__c = today.toStartOfMonth(),
            Period_End__c = Date.newInstance(today.year(), today.month(), Date.daysInMonth(today.year(), today.month()))
        );
        insert expense;

        Expense_Item__c item = new Expense_Item__c(
            Expense__c = expense.Id,
            Expense_Type__c = 'Daily',
            Expense_Date__c = today,
            Claimed_Amount__c = 500,
            Approval_Status__c = 'Pending'
        );
        insert item;
    }

    @isTest
    static void testKpiDashboard() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/dashboard/kpi';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"userId":"' + UserInfo.getUserId() + '","summaryRange":"","expenseSummaryRange":""}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Dashboard_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String body = res.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(body);
        System.assertEquals(true, result.get('status'));

        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertNotEquals(null, data.get('targetSummary'));
        System.assertNotEquals(null, data.get('daySummary'));
        System.assertNotEquals(null, data.get('leaderboard'));
        System.assertNotEquals(null, data.get('productivity'));
        System.assertNotEquals(null, data.get('expenseTimeline'));
        System.assertNotEquals(null, data.get('todayVisits'));
    }

    @isTest
    static void testKpiDashboardMissingUserId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/dashboard/kpi';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Dashboard_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testInvalidEndpoint() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/dashboard/unknown';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Dashboard_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }
}
