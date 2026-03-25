@isTest
private class API_UserProfile_Rest_Test {

    @TestSetup
    static void setup() {
        Employee__c emp = new Employee__c(
            First_Name__c = 'Rohan',
            Last_Name__c = 'Jani',
            Phone__c = '8160419555',
            Email__c = 'rohan@gmail.com',
            Employee_Code__c = 'CM-0001',
            User__c = UserInfo.getUserId(),
            Is_Active__c = true
        );
        insert emp;
    }

    @isTest
    static void testGetProfile() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/user/profile';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"userId":"' + UserInfo.getUserId() + '"}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_UserProfile_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String body = res.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(body);
        System.assertEquals(true, result.get('status'));
        System.assertEquals('User profile', result.get('message'));

        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertEquals('CM-0001', data.get('userId'));
        System.assertEquals('Rohan Jani', data.get('name'));
    }

    @isTest
    static void testGetProfileMissingUserId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/user/profile';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_UserProfile_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testGetProfileUserNotFound() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/user/profile';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"userId":"005000000000000AAA"}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_UserProfile_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testLoginOnHold() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/user/login';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"mobileNumber":"8160419222","password":"Test@123"}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_UserProfile_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testInvalidEndpoint() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/user/unknown';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_UserProfile_Rest.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }
}
