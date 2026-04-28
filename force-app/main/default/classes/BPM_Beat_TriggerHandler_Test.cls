/**
 * @description Test class for BPM_Beat_TriggerHandler.
 *              Validates beat defaults, code uniqueness, deprecated field sync,
 *              and deactivation protection.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
private class BPM_Beat_TriggerHandler_Test {

    @testSetup
    static void setupTestData() {
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('Beat Test Territory', 'TER-BT01');

        Beat__c beat = TestDataFactory.createBeat('Existing Beat', 'BEAT-EXIST01', territory.Id);
        beat.Day_of_Week__c = 'Monday;Wednesday';
        beat.Frequency__c = 'Weekly';
        insert beat;
    }

    @isTest
    static void testDefaultValues() {
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c LIMIT 1];

        Test.startTest();
        Beat__c beat = new Beat__c(
            Name = 'New Beat',
            Beat_Code__c = 'BEAT-NEW01',
            Territory__c = territory.Id,
            Day_of_Week__c = 'Monday'
        );
        insert beat;
        Test.stopTest();

        Beat__c inserted = [SELECT Is_Active__c FROM Beat__c WHERE Id = :beat.Id];
        System.assertEquals(true, inserted.Is_Active__c, 'Is_Active__c should default to true');
    }

    @isTest
    static void testDeprecatedFieldSync() {
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c LIMIT 1];

        Test.startTest();
        Beat__c beat = new Beat__c(
            Name = 'Sync Beat',
            Beat_Code__c = 'BEAT-SYNC01',
            Territory__c = territory.Id,
            Day_of_Week__c = 'Tuesday;Thursday',
            Frequency__c = 'Bi-Weekly'
        );
        insert beat;
        Test.stopTest();

        Beat__c inserted = [SELECT Beat_Day__c, Beat_Frequency__c FROM Beat__c WHERE Id = :beat.Id];
        System.assertEquals('Tuesday;Thursday', inserted.Beat_Day__c,
            'Beat_Day__c should be synced from Day_of_Week__c');
        System.assertEquals('Bi-Weekly', inserted.Beat_Frequency__c,
            'Beat_Frequency__c should be synced from Frequency__c');
    }

    @isTest
    static void testBeatCodeUniqueness() {
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c LIMIT 1];

        Test.startTest();
        try {
            Beat__c duplicate = new Beat__c(
                Name = 'Duplicate Beat',
                Beat_Code__c = 'BEAT-EXIST01',
                Territory__c = territory.Id
            );
            insert duplicate;
            System.assert(false, 'Should have thrown an exception for duplicate Beat_Code__c');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('already in use'),
                'Error should mention beat code is already in use');
        }
        Test.stopTest();
    }

    @isTest
    static void testBeatCodeUniquenessInBatch() {
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c LIMIT 1];

        Test.startTest();
        try {
            List<Beat__c> beats = new List<Beat__c>();
            beats.add(new Beat__c(
                Name = 'Batch Beat 1',
                Beat_Code__c = 'BEAT-BATCH01',
                Territory__c = territory.Id,
                Day_of_Week__c = 'Monday'
            ));
            beats.add(new Beat__c(
                Name = 'Batch Beat 2',
                Beat_Code__c = 'BEAT-BATCH01',
                Territory__c = territory.Id,
                Day_of_Week__c = 'Monday'
            ));
            insert beats;
            System.assert(false, 'Should have thrown an exception for duplicate codes in batch');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Duplicate'),
                'Error should mention duplicate Beat Code');
        }
        Test.stopTest();
    }

    @isTest
    static void testDeactivationAutoRemovesFuturePlans() {
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Beat_Code__c = 'BEAT-EXIST01' LIMIT 1];

        // Create a journey plan and day in the future
        Journey_Plan__c jp = TestDataFactory.createJourneyPlan(UserInfo.getUserId(), 'December', '2030');
        insert jp;

        Journey_Plan_Day__c jpd = new Journey_Plan_Day__c(
            Journey_Plan__c = jp.Id,
            Beat__c = beat.Id,
            Day_of_Week__c = 'Monday',
            Plan_Date__c = Date.newInstance(2030, 12, 1),
            Planned_Outlets__c = 5
        );
        insert jpd;

        System.assertEquals(1, [SELECT COUNT() FROM Journey_Plan_Day__c WHERE Beat__c = :beat.Id AND Plan_Date__c >= TODAY],
            'Should have 1 future plan day before deactivation');

        Test.startTest();
        beat.Is_Active__c = false;
        update beat;
        Test.stopTest();

        Beat__c updated = [SELECT Is_Active__c FROM Beat__c WHERE Id = :beat.Id];
        System.assertEquals(false, updated.Is_Active__c, 'Beat should be deactivated');

        Integer futureDays = [SELECT COUNT() FROM Journey_Plan_Day__c WHERE Beat__c = :beat.Id AND Plan_Date__c >= TODAY];
        System.assertEquals(0, futureDays, 'Future plan days should be auto-deleted on deactivation');
    }

    @isTest
    static void testUpdateBeatCodeSync() {
        Beat__c beat = [SELECT Id, Day_of_Week__c FROM Beat__c WHERE Beat_Code__c = 'BEAT-EXIST01' LIMIT 1];

        Test.startTest();
        beat.Day_of_Week__c = 'Friday;Saturday';
        beat.Frequency__c = 'Monthly';
        update beat;
        Test.stopTest();

        Beat__c updated = [SELECT Beat_Day__c, Beat_Frequency__c FROM Beat__c WHERE Id = :beat.Id];
        System.assertEquals('Friday;Saturday', updated.Beat_Day__c,
            'Beat_Day__c should be updated on Beat update');
        System.assertEquals('Monthly', updated.Beat_Frequency__c,
            'Beat_Frequency__c should be updated on Beat update');
    }
}
