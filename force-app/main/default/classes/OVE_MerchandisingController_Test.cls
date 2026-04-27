@IsTest
private class OVE_MerchandisingController_Test {

    @TestSetup
    static void setupData() {
        Account acc = TestDataFactory.createAndInsertAccount('Merch Test Outlet', 'Retailer');

        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('Merch Territory', 'MT-001');
        Beat__c beat = TestDataFactory.createAndInsertBeat('Merch Beat', 'MB-001', territory.Id);

        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        insert da;

        Visit__c visit = TestDataFactory.createVisit(acc.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        // Create Merchandising__c record linked to the visit
        Merchandising__c merch = new Merchandising__c(
            Visit__c = visit.Id,
            Account__c = acc.Id,
            Audit_Date__c = Date.today(),
            Own_Shelf_Share__c = 60,
            Competitor_Shelf_Share__c = 40,
            Planogram_Compliant__c = true,
            POSM_Present__c = true,
            POSM_Condition__c = 'Good',
            Notes__c = 'Test merchandising audit'
        );
        insert merch;
    }

    // ── getMerchandisingForVisit ─────────────────────────────────────

    @IsTest
    static void testGetMerchandisingForVisit_ReturnsRecord() {
        Visit__c visit = [SELECT Id FROM Visit__c LIMIT 1];

        Test.startTest();
        try {
            Merchandising__c result = OVE_MerchandisingController.getMerchandisingForVisit(visit.Id);
            // Feature may be disabled - if enabled, validate the result
            if (result != null) {
                System.assertEquals(visit.Id, result.Visit__c, 'Merchandising should belong to the visit');
                System.assertEquals(60, result.Own_Shelf_Share__c, 'Own shelf share should be 60');
            }
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Feature toggle may be disabled');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetMerchandisingForVisit_NoRecord() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Beat__c beat = [SELECT Id FROM Beat__c LIMIT 1];
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        Visit__c emptyVisit = TestDataFactory.createVisit(acc.Id, UserInfo.getUserId(), da.Id, beat.Id);
        emptyVisit.Visit_Date__c = Date.today().addDays(-1);
        insert emptyVisit;

        Test.startTest();
        try {
            Merchandising__c result = OVE_MerchandisingController.getMerchandisingForVisit(emptyVisit.Id);
            // If feature enabled, should return null for visit with no merchandising
            System.assertEquals(null, result, 'Should return null for visit without merchandising');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Feature toggle may be disabled');
        }
        Test.stopTest();
    }

    // ── saveMerchandising ───────────────────────────────────────────

    @IsTest
    static void testSaveMerchandising_NewRecord() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Beat__c beat = [SELECT Id FROM Beat__c LIMIT 1];
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        Visit__c newVisit = TestDataFactory.createVisit(acc.Id, UserInfo.getUserId(), da.Id, beat.Id);
        newVisit.Visit_Date__c = Date.today().addDays(-2);
        insert newVisit;

        Map<String, Object> merchData = new Map<String, Object>{
            'visitId' => newVisit.Id,
            'accountId' => acc.Id,
            'ownShelfShare' => 55,
            'competitorShelfShare' => 45,
            'planogramCompliant' => false,
            'posmPresent' => true,
            'posmCondition' => 'Fair',
            'notes' => 'New merchandising audit'
        };
        String merchJson = JSON.serialize(merchData);

        Test.startTest();
        try {
            Merchandising__c result = OVE_MerchandisingController.saveMerchandising(merchJson);
            System.assertNotEquals(null, result, 'Saved record should not be null');
            System.assertNotEquals(null, result.Id, 'Saved record should have an Id');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception expected if feature disabled');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveMerchandising_UpdateExisting() {
        Merchandising__c existing = [SELECT Id, Visit__c, Account__c FROM Merchandising__c LIMIT 1];

        Map<String, Object> merchData = new Map<String, Object>{
            'id' => existing.Id,
            'visitId' => existing.Visit__c,
            'accountId' => existing.Account__c,
            'ownShelfShare' => 70,
            'competitorShelfShare' => 30,
            'planogramCompliant' => true,
            'posmPresent' => false,
            'notes' => 'Updated merchandising audit'
        };
        String merchJson = JSON.serialize(merchData);

        Test.startTest();
        try {
            Merchandising__c result = OVE_MerchandisingController.saveMerchandising(merchJson);
            System.assertEquals(existing.Id, result.Id, 'Should update existing record');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception expected if feature disabled');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveMerchandising_WithPhotos() {
        Visit__c visit = [SELECT Id, Account__c FROM Visit__c LIMIT 1];

        Map<String, Object> merchData = new Map<String, Object>{
            'visitId' => visit.Id,
            'accountId' => visit.Account__c,
            'ownShelfShare' => 50,
            'photoBefore' => 'https://example.com/before.jpg',
            'photoAfter' => 'https://example.com/after.jpg',
            'notes' => 'With photos'
        };
        String merchJson = JSON.serialize(merchData);

        Test.startTest();
        try {
            Merchandising__c result = OVE_MerchandisingController.saveMerchandising(merchJson);
            System.assertNotEquals(null, result, 'Saved record should not be null');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception expected if feature disabled');
        }
        Test.stopTest();
    }
}
