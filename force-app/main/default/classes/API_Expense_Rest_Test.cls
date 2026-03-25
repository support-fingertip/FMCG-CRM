@isTest
private class API_Expense_Rest_Test {

    @TestSetup
    static void setup() {
        Employee__c emp = new Employee__c(
            First_Name__c = 'Anil',
            Last_Name__c = 'Kumar',
            Phone__c = '9876543210',
            Email__c = 'anil@example.com',
            Employee_Code__c = 'CPC001',
            User__c = UserInfo.getUserId(),
            Is_Active__c = true,
            Band__c = 'L1'
        );
        insert emp;

        Date today = Date.today();
        List<String> monthNames = new List<String>{
            '', 'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };

        Expense__c expense = new Expense__c(
            Employee__c = emp.Id,
            Month__c = monthNames[today.month()],
            Status__c = 'Draft',
            Period_Start__c = today.toStartOfMonth(),
            Period_End__c = Date.newInstance(today.year(), today.month(), Date.daysInMonth(today.year(), today.month()))
        );
        insert expense;

        Expense_Item__c item1 = new Expense_Item__c(
            Expense__c = expense.Id,
            Expense_Type__c = 'Daily',
            Expense_Date__c = today,
            Claimed_Amount__c = 500,
            Approval_Status__c = 'Pending',
            Expense_Category__c = 'DA',
            Notes__c = 'Daily allowance'
        );
        Expense_Item__c item2 = new Expense_Item__c(
            Expense__c = expense.Id,
            Expense_Type__c = 'Travel',
            Expense_Date__c = today,
            Claimed_Amount__c = 555,
            Approval_Status__c = 'Pending',
            Notes__c = 'Travel expense'
        );
        insert new List<Expense_Item__c>{ item1, item2 };
    }

    @isTest
    static void testAddExpense() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/expense/add';
        req.httpMethod = 'POST';

        Map<String, Object> body = new Map<String, Object>();
        body.put('userId', UserInfo.getUserId());
        body.put('expenseType', 'Daily');
        body.put('expansedate', String.valueOf(Date.today()));
        body.put('description', 'Lunch allowance');
        body.put('amount', 300);
        req.requestBody = Blob.valueOf(JSON.serialize(body));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Expense_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String respBody = res.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(respBody);
        System.assertEquals(true, result.get('status'));

        // Verify item was created
        List<Expense_Item__c> items = [SELECT Id FROM Expense_Item__c WHERE Notes__c = 'Lunch allowance'];
        System.assertEquals(1, items.size());
    }

    @isTest
    static void testAddExpenseNewMonth() {
        // Test creating expense for a month that doesn't have a report yet
        Date futureMonth = Date.today().addMonths(1);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/expense/add';
        req.httpMethod = 'POST';

        Map<String, Object> body = new Map<String, Object>();
        body.put('userId', UserInfo.getUserId());
        body.put('expenseType', 'Travel');
        body.put('expenseDate', String.valueOf(futureMonth));
        body.put('description', 'Cab fare');
        body.put('amount', '250');
        req.requestBody = Blob.valueOf(JSON.serialize(body));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Expense_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }

    @isTest
    static void testExpenseList() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/expense/list';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"userId":"' + UserInfo.getUserId() + '","pageSize":0}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Expense_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String respBody = res.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(respBody);
        System.assertEquals('success', result.get('status'));
        System.assert((Decimal) result.get('totalExpenses') > 0);
    }

    @isTest
    static void testExpenseDetail() {
        Expense_Item__c item = [SELECT Id FROM Expense_Item__c WHERE Notes__c = 'Daily allowance' LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/expense/detail';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"userId":"' + UserInfo.getUserId() + '","expenseId":"' + item.Id + '"}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Expense_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String respBody = res.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(respBody);
        System.assertEquals('success', result.get('status'));

        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertEquals(500.0, data.get('amount'));
        System.assertEquals('Anil Kumar', data.get('salesperson'));
    }

    @isTest
    static void testExpenseDetailNotFound() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/expense/detail';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"userId":"' + UserInfo.getUserId() + '","expenseId":"a00000000000000AAA"}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Expense_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testAddExpenseMissingUserId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/expense/add';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Expense_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testInvalidEndpoint() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/expense/unknown';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Expense_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }
}
