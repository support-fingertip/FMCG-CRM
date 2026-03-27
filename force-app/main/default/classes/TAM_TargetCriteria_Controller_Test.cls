/**
 * @description Test class for TAM_TargetCriteria_Controller.
 *              Validates object/field metadata retrieval and criteria CRUD operations.
 */
@isTest
private class TAM_TargetCriteria_Controller_Test {

    @testSetup
    static void setupTestData() {
        // Create a Target Criteria for retrieval and update tests
        Target_Criteria__c criteria = new Target_Criteria__c(
            Name = 'Criteria Controller Test',
            Object__c = 'Account',
            Operator__c = 'COUNT',
            Field__c = 'Id',
            Date_Field__c = 'CreatedDate',
            User_Field__c = 'OwnerId',
            Active__c = true
        );
        insert criteria;
    }

    /**
     * @description getAllObjects should return a non-empty list where each item
     *              contains 'api' and 'label' keys.
     */
    @isTest
    static void testGetAllObjects() {
        Test.startTest();
        List<Map<String, String>> objects = TAM_TargetCriteria_Controller.getAllObjects();
        Test.stopTest();

        System.assertNotEquals(null, objects, 'Object list should not be null');
        System.assert(objects.size() > 0, 'Object list should not be empty');

        // Verify structure of each entry
        for (Map<String, String> item : objects) {
            System.assert(item.containsKey('api'),
                'Each item should have an api key');
            System.assert(item.containsKey('label'),
                'Each item should have a label key');
            System.assertNotEquals(null, item.get('api'),
                'api value should not be null');
            System.assertNotEquals(null, item.get('label'),
                'label value should not be null');
            break; // Only need to verify the first entry for structure
        }
    }

    /**
     * @description getFieldCategories for Account should return maps with
     *              numberFields, dateFields, userFields, and allFields.
     */
    @isTest
    static void testGetFieldCategories_Account() {
        Test.startTest();
        Map<String, List<String>> categories = TAM_TargetCriteria_Controller.getFieldCategories('Account');
        Test.stopTest();

        System.assertNotEquals(null, categories, 'Categories map should not be null');
        System.assert(categories.containsKey('numberFields'),
            'Should contain numberFields key');
        System.assert(categories.containsKey('dateFields'),
            'Should contain dateFields key');
        System.assert(categories.containsKey('userFields'),
            'Should contain userFields key');
        System.assert(categories.containsKey('allFields'),
            'Should contain allFields key');

        // Account always has date and user-lookup fields
        System.assert(categories.get('dateFields').size() > 0,
            'Account should have at least one date field');
        System.assert(categories.get('userFields').size() > 0,
            'Account should have at least one user-lookup field (OwnerId)');
        System.assert(categories.get('allFields').size() > 0,
            'Account should have many fields');
    }

    /**
     * @description getCriteria should retrieve a saved criteria record by Id.
     */
    @isTest
    static void testGetCriteria() {
        Target_Criteria__c existing = [SELECT Id FROM Target_Criteria__c LIMIT 1];

        Test.startTest();
        Target_Criteria__c result = TAM_TargetCriteria_Controller.getCriteria(existing.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Returned criteria should not be null');
        System.assertEquals(existing.Id, result.Id, 'Should return the correct record');
        System.assertEquals('Account', result.Object__c,
            'Object__c should match the inserted value');
        System.assertEquals('COUNT', result.Operator__c,
            'Operator__c should match the inserted value');
        System.assertEquals('CreatedDate', result.Date_Field__c,
            'Date_Field__c should match the inserted value');
        System.assertEquals('OwnerId', result.User_Field__c,
            'User_Field__c should match the inserted value');
    }

    /**
     * @description saveCriteria should insert a new Target_Criteria__c record.
     */
    @isTest
    static void testSaveCriteria_Insert() {
        Target_Criteria__c newCriteria = new Target_Criteria__c(
            Name = 'New Insert Criteria',
            Object__c = 'Contact',
            Operator__c = 'COUNT',
            Field__c = 'Id',
            Date_Field__c = 'CreatedDate',
            User_Field__c = 'OwnerId',
            Active__c = true
        );

        Test.startTest();
        Target_Criteria__c result = TAM_TargetCriteria_Controller.saveCriteria(newCriteria);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Returned criteria should not be null');
        System.assertNotEquals(null, result.Id, 'Saved criteria should have an Id');
        System.assertEquals('Contact', result.Object__c,
            'Object__c should be Contact');

        // Verify it was actually persisted
        Integer count = [SELECT COUNT() FROM Target_Criteria__c WHERE Name = 'New Insert Criteria'];
        System.assertEquals(1, count, 'New criteria should exist in the database');
    }

    /**
     * @description saveCriteria should update an existing Target_Criteria__c record.
     */
    @isTest
    static void testSaveCriteria_Update() {
        Target_Criteria__c existing = [SELECT Id, Name, Object__c, Operator__c, Field__c,
                                              Date_Field__c, User_Field__c
                                       FROM Target_Criteria__c LIMIT 1];

        // Modify the criteria
        existing.Name = 'Updated Criteria Name';
        existing.Operator__c = 'SUM';

        Test.startTest();
        Target_Criteria__c result = TAM_TargetCriteria_Controller.saveCriteria(existing);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Returned criteria should not be null');
        System.assertEquals(existing.Id, result.Id, 'Should be the same record');
        System.assertEquals('Updated Criteria Name', result.Name,
            'Name should be updated');
        System.assertEquals('SUM', result.Operator__c,
            'Operator__c should be updated to SUM');

        // Verify only one record with the original Id exists
        Target_Criteria__c verify = [SELECT Name, Operator__c FROM Target_Criteria__c WHERE Id = :existing.Id];
        System.assertEquals('Updated Criteria Name', verify.Name,
            'Database should reflect the updated name');
        System.assertEquals('SUM', verify.Operator__c,
            'Database should reflect the updated operator');
    }
}
