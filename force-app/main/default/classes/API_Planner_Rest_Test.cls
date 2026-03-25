@isTest
private class API_Planner_Rest_Test {

    @TestSetup
    static void setup() {
        Employee__c emp = new Employee__c(
            First_Name__c = 'Test',
            Last_Name__c = 'User',
            Phone__c = '9876543210',
            Email__c = 'test@example.com',
            Employee_Code__c = 'CPC001',
            User__c = UserInfo.getUserId(),
            Is_Active__c = true
        );
        insert emp;

        Account acc1 = TestDataFactory.createAndInsertAccount('Happy Traders', 'Customer');
        Account acc2 = TestDataFactory.createAndInsertAccount('ABC Distributors', 'Customer');

        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('West', 'WEST-001');
        Beat__c beat = TestDataFactory.createAndInsertBeat('Beat 1', 'B001', territory.Id);

        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        insert da;

        // Create visits for today and tomorrow
        Visit__c visit1 = TestDataFactory.createVisit(acc1.Id, UserInfo.getUserId(), da.Id, beat.Id);
        visit1.Visit_Status__c = 'Pending';
        visit1.Visit_Date__c = Date.today();
        insert visit1;

        Visit__c visit2 = new Visit__c(
            Account__c = acc2.Id,
            Salesperson__c = UserInfo.getUserId(),
            Beat__c = beat.Id,
            Visit_Date__c = Date.today().addDays(1),
            Visit_Status__c = 'Pending',
            Is_Planned__c = true
        );
        insert visit2;
    }

    @isTest
    static void testPlannerList() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/planner/list';
        req.httpMethod = 'POST';

        Map<String, Object> body = new Map<String, Object>();
        body.put('userId', UserInfo.getUserId());
        body.put('fromDate', String.valueOf(Date.today()));
        body.put('toDate', String.valueOf(Date.today().addDays(7)));
        body.put('viewType', 'Day');
        body.put('pageSize', 0);
        body.put('search', '');
        req.requestBody = Blob.valueOf(JSON.serialize(body));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Planner_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String respBody = res.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(respBody);
        System.assertEquals(true, result.get('status'));

        List<Object> data = (List<Object>) result.get('data');
        System.assert(data.size() > 0, 'Should have at least one day entry');
    }

    @isTest
    static void testPlannerListWithSearch() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/planner/list';
        req.httpMethod = 'POST';

        Map<String, Object> body = new Map<String, Object>();
        body.put('userId', UserInfo.getUserId());
        body.put('fromDate', String.valueOf(Date.today()));
        body.put('toDate', String.valueOf(Date.today().addDays(7)));
        body.put('viewType', 'Day');
        body.put('pageSize', 10);
        body.put('search', 'Happy');
        req.requestBody = Blob.valueOf(JSON.serialize(body));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Planner_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }

    @isTest
    static void testPlannerListDefaultDates() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/planner/list';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"userId":"' + UserInfo.getUserId() + '"}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Planner_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }

    @isTest
    static void testPlannerListMissingUserId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/planner/list';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Planner_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testInvalidEndpoint() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/planner/unknown';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Planner_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }
}
