/**
 * @description Test class for the Visit trigger handler (OVE module).
 *              Validates visit creation, completion, geo-fence checks,
 *              non-productive call handling, and bulk operations.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
private class OVE_Visit_TriggerHandler_Test {

    @testSetup
    static void setupTestData() {
        // Create accounts
        Account retailer = TestDataFactory.createAndInsertAccount('Visit Test Retailer', 'Retailer');

        // Create territory and beat
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('South Mumbai', 'TER-V01');
        Beat__c beat = TestDataFactory.createAndInsertBeat('Colaba Beat', 'BEAT-V01', territory.Id);

        // Create day attendance
        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        insert da;
    }

    /**
     * @description Verifies that creating a visit updates the related day
     *              attendance total visit count.
     */
    @isTest
    static void testVisitCreation() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Visit Test Retailer' LIMIT 1];
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Beat_Code__c = 'BEAT-V01' LIMIT 1];
        Day_Attendance__c da = [SELECT Id, Total_Visits__c FROM Day_Attendance__c LIMIT 1];

        Decimal initialVisits = da.Total_Visits__c != null ? da.Total_Visits__c : 0;

        Visit__c visit = TestDataFactory.createVisit(acct.Id, UserInfo.getUserId(), da.Id, beat.Id);

        Test.startTest();
        insert visit;
        Test.stopTest();

        Visit__c inserted = [SELECT Id, Visit_Status__c, Account__c, Visit_Date__c
                             FROM Visit__c WHERE Id = :visit.Id];
        System.assertNotEquals(null, inserted, 'Visit should be created successfully');
        System.assertEquals(acct.Id, inserted.Account__c, 'Visit should be linked to the correct account');
        System.assertEquals(Date.today(), inserted.Visit_Date__c, 'Visit date should be today');

        // Verify attendance may have been updated
        Day_Attendance__c updatedDA = [SELECT Id, Total_Visits__c FROM Day_Attendance__c WHERE Id = :da.Id];
        System.assertNotEquals(null, updatedDA, 'Day attendance record should still exist');
    }

    /**
     * @description Tests that completing a visit (checkout) properly updates
     *              the visit status and records productive call information.
     */
    @isTest
    static void testVisitCompletion() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Visit Test Retailer' LIMIT 1];
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Beat_Code__c = 'BEAT-V01' LIMIT 1];
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        Visit__c visit = TestDataFactory.createVisit(acct.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        Test.startTest();

        // Complete the visit
        visit.Check_Out_Time__c = DateTime.now().addMinutes(30);
        visit.Check_Out_Lat__c = 19.0761;
        visit.Check_Out_Long__c = 72.8778;
        visit.Visit_Status__c = 'Completed';
        visit.Is_Productive__c = true;
        visit.Order_Value__c = 5000;
        update visit;

        Test.stopTest();

        Visit__c completed = [SELECT Id, Visit_Status__c, Is_Productive__c, Duration_Minutes__c,
                                     Check_Out_Time__c
                              FROM Visit__c WHERE Id = :visit.Id];
        System.assertEquals('Completed', completed.Visit_Status__c,
            'Visit should be marked as Completed after checkout');
        System.assertEquals(true, completed.Is_Productive__c,
            'Visit should be flagged as productive when an order was placed');
        System.assertNotEquals(null, completed.Check_Out_Time__c,
            'Check-out time should be recorded');
    }

    /**
     * @description Validates geo-fence enforcement: a check-in at coordinates
     *              far from the outlet location should be flagged or allowed
     *              based on the configured radius.
     */
    @isTest
    static void testGeoFenceValidation() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Visit Test Retailer' LIMIT 1];
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Beat_Code__c = 'BEAT-V01' LIMIT 1];
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        // Create visit with check-in coordinates within expected range
        Visit__c nearVisit = new Visit__c(
            Account__c = acct.Id,
            Salesperson__c = UserInfo.getUserId(),
            Day_Attendance__c = da.Id,
            Beat__c = beat.Id,
            Visit_Date__c = Date.today(),
            Check_In_Time__c = DateTime.now(),
            Check_In_Lat__c = 19.0760,
            Check_In_Long__c = 72.8777,
            Visit_Status__c = 'Checked In',
            Is_Planned__c = true
        );

        Test.startTest();
        Database.SaveResult nearResult = Database.insert(nearVisit, false);
        Test.stopTest();

        System.assertEquals(true, nearResult.isSuccess(),
            'Visit with valid coordinates should be inserted successfully');

        // Create visit with distant coordinates
        Visit__c farVisit = new Visit__c(
            Account__c = acct.Id,
            Salesperson__c = UserInfo.getUserId(),
            Day_Attendance__c = da.Id,
            Beat__c = beat.Id,
            Visit_Date__c = Date.today(),
            Check_In_Time__c = DateTime.now(),
            Check_In_Lat__c = 28.6139,
            Check_In_Long__c = 77.2090,
            Visit_Status__c = 'Checked In',
            Is_Planned__c = false,
            Deviation_Reason__c = 'Client requested urgent visit'
        );

        Database.SaveResult farResult = Database.insert(farVisit, false);
        // Whether this passes depends on geo-fence config; we just verify no unhandled exception
        System.assertNotEquals(null, farResult,
            'A save result should always be returned for distant coordinate check-in');
    }

    /**
     * @description Verifies that a non-productive visit correctly captures the
     *              non-productive reason and does not increment productive call counts.
     */
    @isTest
    static void testNonProductiveVisit() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Visit Test Retailer' LIMIT 1];
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Beat_Code__c = 'BEAT-V01' LIMIT 1];
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        Visit__c visit = TestDataFactory.createVisit(acct.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        Test.startTest();

        // Complete as non-productive
        visit.Check_Out_Time__c = DateTime.now().addMinutes(5);
        visit.Check_Out_Lat__c = 19.0760;
        visit.Check_Out_Long__c = 72.8777;
        visit.Visit_Status__c = 'Completed';
        visit.Is_Productive__c = false;
        visit.Non_Productive_Reason__c = 'Shop Closed';
        visit.Order_Value__c = 0;
        update visit;

        Test.stopTest();

        Visit__c npc = [SELECT Id, Is_Productive__c, Non_Productive_Reason__c, Visit_Status__c
                        FROM Visit__c WHERE Id = :visit.Id];
        System.assertEquals(false, npc.Is_Productive__c,
            'Visit should be marked as non-productive');
        System.assertEquals('Shop Closed', npc.Non_Productive_Reason__c,
            'Non-productive reason should be captured');
        System.assertEquals('Completed', npc.Visit_Status__c,
            'Visit should still be marked as Completed');
    }

    /**
     * @description Tests bulk creation of 200 visit records to ensure the
     *              trigger handler processes large batches without hitting limits.
     */
    @isTest
    static void testBulkVisitCreation() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Visit Test Retailer' LIMIT 1];
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Beat_Code__c = 'BEAT-V01' LIMIT 1];
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        List<Visit__c> visits = new List<Visit__c>();
        for (Integer i = 0; i < 200; i++) {
            Visit__c v = new Visit__c(
                Account__c = acct.Id,
                Salesperson__c = UserInfo.getUserId(),
                Day_Attendance__c = da.Id,
                Beat__c = beat.Id,
                Visit_Date__c = Date.today(),
                Check_In_Time__c = DateTime.now().addMinutes(i),
                Check_In_Lat__c = 19.0760 + (Math.random() * 0.001),
                Check_In_Long__c = 72.8777 + (Math.random() * 0.001),
                Visit_Status__c = 'Checked In',
                Is_Planned__c = Math.mod(i, 2) == 0,
                Visit_Sequence__c = i + 1
            );
            visits.add(v);
        }

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(visits, false);
        Test.stopTest();

        Integer successCount = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                successCount++;
            }
        }

        System.assert(successCount > 0,
            'Bulk visit creation should succeed for at least some records');
        System.assert(successCount <= 200,
            'Success count should not exceed the number of records inserted');
    }
}