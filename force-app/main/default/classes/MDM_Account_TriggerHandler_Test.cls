/**
 * @description Test class for MDM_Account_TriggerHandler.
 *              Tests default field population, beat outlet count rollups,
 *              visit frequency auto-assignment, and credit utilization methods.
 *
 * @author  SFA Development Team
 * @date    2024
 */
@IsTest
private class MDM_Account_TriggerHandler_Test {

    @TestSetup
    static void setupTestData() {
        // Create Territory
        Territory_Master__c territory = new Territory_Master__c(
            Name = 'Test Territory',
            Territory_Code__c = 'TER-001',
            State__c = 'Maharashtra',
            City__c = 'Mumbai',
            Is_Active__c = true
        );
        insert territory;

        // Create Beat
        Beat__c beat = new Beat__c(
            Name = 'Test Beat 1',
            Beat_Code__c = 'BT-001',
            Territory__c = territory.Id,
            Frequency__c = 'Weekly',
            Is_Active__c = true,
            Total_Outlets__c = 0
        );
        insert beat;

        // Create a second Beat for transfer tests
        Beat__c beat2 = new Beat__c(
            Name = 'Test Beat 2',
            Beat_Code__c = 'BT-002',
            Territory__c = territory.Id,
            Frequency__c = 'Weekly',
            Is_Active__c = true,
            Total_Outlets__c = 0
        );
        insert beat2;
    }

    // ── Before Insert Tests ──────────────────────────────────────────────

    @IsTest
    static void testBeforeInsert_DefaultsSetForClassA() {
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Beat_Code__c = 'BT-001' LIMIT 1];

        Test.startTest();
        Account acc = new Account(
            Name = 'Test Retailer A',
            Outlet_Class__c = 'A',
            Beat__c = beat.Id
        );
        insert acc;
        Test.stopTest();

        Account result = [SELECT Is_Active__c, Visit_Frequency__c, Credit_Utilized__c
                         FROM Account WHERE Id = :acc.Id];
        System.assertEquals(true, result.Is_Active__c, 'Is_Active should default to true');
        System.assertEquals('Weekly', result.Visit_Frequency__c, 'Class A should get Weekly frequency');
        System.assertEquals(0, result.Credit_Utilized__c, 'Credit_Utilized should default to 0');
    }

    @IsTest
    static void testBeforeInsert_DefaultsSetForClassB() {
        Test.startTest();
        Account acc = new Account(
            Name = 'Test Retailer B',
            Outlet_Class__c = 'B'
        );
        insert acc;
        Test.stopTest();

        Account result = [SELECT Visit_Frequency__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Bi-Weekly', result.Visit_Frequency__c, 'Class B should get Bi-Weekly frequency');
    }

    @IsTest
    static void testBeforeInsert_DefaultsSetForClassC() {
        Test.startTest();
        Account acc = new Account(
            Name = 'Test Retailer C',
            Outlet_Class__c = 'C'
        );
        insert acc;
        Test.stopTest();

        Account result = [SELECT Visit_Frequency__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Monthly', result.Visit_Frequency__c, 'Class C should get Monthly frequency');
    }

    @IsTest
    static void testBeforeInsert_ExplicitFrequencyNotOverridden() {
        Test.startTest();
        Account acc = new Account(
            Name = 'Test Retailer Explicit',
            Outlet_Class__c = 'A',
            Visit_Frequency__c = 'Monthly' // Explicitly set, should not be overridden
        );
        insert acc;
        Test.stopTest();

        Account result = [SELECT Visit_Frequency__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Monthly', result.Visit_Frequency__c, 'Explicit frequency should not be overridden');
    }

    // ── After Insert Tests (Beat Count) ──────────────────────────────────

    @IsTest
    static void testAfterInsert_BeatOutletCountIncremented() {
        Beat__c beat = [SELECT Id, Total_Outlets__c FROM Beat__c WHERE Beat_Code__c = 'BT-001' LIMIT 1];
        System.assertEquals(0, beat.Total_Outlets__c, 'Beat should start with 0 outlets');

        Test.startTest();
        Account acc1 = new Account(Name = 'Outlet 1', Beat__c = beat.Id, Is_Active__c = true);
        Account acc2 = new Account(Name = 'Outlet 2', Beat__c = beat.Id, Is_Active__c = true);
        insert new List<Account>{ acc1, acc2 };
        Test.stopTest();

        beat = [SELECT Total_Outlets__c FROM Beat__c WHERE Id = :beat.Id];
        System.assertEquals(2, beat.Total_Outlets__c, 'Beat should have 2 outlets after insert');
    }

    @IsTest
    static void testAfterInsert_InactiveAccountNotCounted() {
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Beat_Code__c = 'BT-001' LIMIT 1];

        Test.startTest();
        Account acc = new Account(Name = 'Inactive Outlet', Beat__c = beat.Id, Is_Active__c = false);
        insert acc;
        Test.stopTest();

        beat = [SELECT Total_Outlets__c FROM Beat__c WHERE Id = :beat.Id];
        System.assertEquals(0, beat.Total_Outlets__c, 'Inactive account should not be counted');
    }

    // ── After Update Tests (Beat Transfer) ───────────────────────────────

    @IsTest
    static void testAfterUpdate_BeatTransferUpdatesCount() {
        Beat__c beat1 = [SELECT Id FROM Beat__c WHERE Beat_Code__c = 'BT-001' LIMIT 1];
        Beat__c beat2 = [SELECT Id FROM Beat__c WHERE Beat_Code__c = 'BT-002' LIMIT 1];

        Account acc = new Account(Name = 'Transfer Outlet', Beat__c = beat1.Id, Is_Active__c = true);
        insert acc;

        // Verify initial state
        beat1 = [SELECT Total_Outlets__c FROM Beat__c WHERE Id = :beat1.Id];
        System.assertEquals(1, beat1.Total_Outlets__c, 'Beat1 should have 1 outlet');

        Test.startTest();
        acc.Beat__c = beat2.Id;
        update acc;
        Test.stopTest();

        beat1 = [SELECT Total_Outlets__c FROM Beat__c WHERE Id = :beat1.Id];
        beat2 = [SELECT Total_Outlets__c FROM Beat__c WHERE Id = :beat2.Id];
        System.assertEquals(0, beat1.Total_Outlets__c, 'Beat1 should have 0 outlets after transfer');
        System.assertEquals(1, beat2.Total_Outlets__c, 'Beat2 should have 1 outlet after transfer');
    }

    // ── Before Update Tests (Class Change) ───────────────────────────────

    @IsTest
    static void testBeforeUpdate_FrequencyUpdatedOnClassChange() {
        Account acc = new Account(
            Name = 'Class Change Outlet',
            Outlet_Class__c = 'A'
        );
        insert acc;

        Account insertedAcc = [SELECT Visit_Frequency__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Weekly', insertedAcc.Visit_Frequency__c, 'Should start as Weekly for Class A');

        Test.startTest();
        acc.Outlet_Class__c = 'C';
        update acc;
        Test.stopTest();

        Account result = [SELECT Visit_Frequency__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Monthly', result.Visit_Frequency__c, 'Frequency should update to Monthly for Class C');
    }

    // ── Static Method Tests ──────────────────────────────────────────────

    @IsTest
    static void testGetDefaultVisitFrequency() {
        System.assertEquals('Weekly', MDM_Account_TriggerHandler.getDefaultVisitFrequency('A'));
        System.assertEquals('Bi-Weekly', MDM_Account_TriggerHandler.getDefaultVisitFrequency('B'));
        System.assertEquals('Monthly', MDM_Account_TriggerHandler.getDefaultVisitFrequency('C'));
        System.assertEquals('Monthly', MDM_Account_TriggerHandler.getDefaultVisitFrequency('D'));
        System.assertEquals('Monthly', MDM_Account_TriggerHandler.getDefaultVisitFrequency(null));
    }

    @IsTest
    static void testRecalculateCreditUtilization_NoInvoices() {
        Account acc = new Account(Name = 'Credit Test Outlet', Credit_Limit__c = 50000);
        insert acc;

        Test.startTest();
        MDM_Account_TriggerHandler.recalculateCreditUtilization(new Set<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Credit_Utilized__c, Outstanding_Balance__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(0, result.Credit_Utilized__c, 'Credit utilized should be 0 with no invoices');
        System.assertEquals(0, result.Outstanding_Balance__c, 'Outstanding should be 0 with no invoices');
    }

    @IsTest
    static void testRecalculateCreditUtilization_EmptySet() {
        Test.startTest();
        MDM_Account_TriggerHandler.recalculateCreditUtilization(new Set<Id>());
        MDM_Account_TriggerHandler.recalculateCreditUtilization(null);
        Test.stopTest();
        // Should not throw any exceptions
    }

    @IsTest
    static void testUpdateLastOrderInfo_NoOrders() {
        Account acc = new Account(Name = 'Order Test Outlet');
        insert acc;

        Test.startTest();
        MDM_Account_TriggerHandler.updateLastOrderInfo(new Set<Id>{ acc.Id });
        Test.stopTest();
        // Should not throw; no orders means no update
    }

    @IsTest
    static void testUpdateLastVisitDate_NoVisits() {
        Account acc = new Account(Name = 'Visit Test Outlet');
        insert acc;

        Test.startTest();
        MDM_Account_TriggerHandler.updateLastVisitDate(new Set<Id>{ acc.Id });
        Test.stopTest();
        // Should not throw; no visits means no update
    }

    // ── Bulk Test ────────────────────────────────────────────────────────

    @IsTest
    static void testBulkInsert_200Accounts() {
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Beat_Code__c = 'BT-001' LIMIT 1];

        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(
                Name = 'Bulk Outlet ' + i,
                Outlet_Class__c = 'B',
                Beat__c = beat.Id,
                Is_Active__c = true
            ));
        }

        Test.startTest();
        insert accounts;
        Test.stopTest();

        beat = [SELECT Total_Outlets__c FROM Beat__c WHERE Id = :beat.Id];
        System.assertEquals(200, beat.Total_Outlets__c, 'Beat should have 200 outlets after bulk insert');
    }
}
