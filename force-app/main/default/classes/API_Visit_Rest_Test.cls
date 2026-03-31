@isTest
private class API_Visit_Rest_Test {

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

        Account acc = TestDataFactory.createAndInsertAccount('Happy Traders', 'Customer');

        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('West', 'WEST-001');
        Beat__c beat = TestDataFactory.createAndInsertBeat('Beat 1', 'B001', territory.Id);

        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        insert da;

        Visit__c visit = TestDataFactory.createVisit(acc.Id, UserInfo.getUserId(), da.Id, beat.Id);
        visit.Visit_Status__c = 'Pending';
        visit.Check_In_Latitude__c = 25.5941;
        visit.Check_In_Longitude__c = 85.1376;
        insert visit;
    }

    @isTest
    static void testVisitList() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/visit/list';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"userId":"' + UserInfo.getUserId() + '","schdduleDate":"","status":"","pageSize":0}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Visit_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String body = res.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(body);
        System.assertEquals(true, result.get('status'));
    }

    @isTest
    static void testVisitListWithFilters() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/visit/list';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"userId":"' + UserInfo.getUserId() + '","schdduleDate":"' +
            String.valueOf(Date.today()) + '","status":"Pending","pageSize":10}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Visit_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }

    @isTest
    static void testVisitDetail() {
        Visit__c visit = [SELECT Id FROM Visit__c LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/visit/detail';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"userId":"' + UserInfo.getUserId() + '","siteVisitId":"' + visit.Id + '"}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Visit_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String body = res.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(body);
        System.assertEquals(true, result.get('status'));

        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertEquals('Happy Traders', data.get('outletName'));
    }

    @isTest
    static void testVisitDetailNotFound() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/visit/detail';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"userId":"' + UserInfo.getUserId() + '","siteVisitId":"a00000000000000AAA"}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Visit_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testAddVisit() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/visit/add';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"userId":"' + UserInfo.getUserId() +
            '","accountId":"' + acc.Id +
            '","purpose":"Sales Call","Notes":"Follow up on order"}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Visit_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String body = res.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(body);
        System.assertEquals(true, result.get('status'));

        // Verify visit was created
        List<Visit__c> visits = [SELECT Id FROM Visit__c WHERE Is_Ad_Hoc__c = true];
        System.assertEquals(1, visits.size());
    }

    @isTest
    static void testAddVisitMissingFields() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/visit/add';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"userId":"' + UserInfo.getUserId() + '"}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Visit_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testVisitListMissingUserId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/visit/list';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Visit_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testInvalidEndpoint() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/visit/unknown';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Visit_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }
}
