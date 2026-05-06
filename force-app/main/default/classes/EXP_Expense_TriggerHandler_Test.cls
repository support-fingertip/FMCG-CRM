@isTest
public class EXP_Expense_TriggerHandler_Test {

    @TestSetup
    static void setupTestData() {
        Employee__c emp = new Employee__c(
            First_Name__c = 'Report',
            Last_Name__c = 'TriggerTest',
            Employee_Code__c = 'EMP-RPT01',
            Is_Active__c = true,
            User__c = UserInfo.getUserId(),
            Band__c = 'Band 1',
            Territory__c = TestDataFactory.createAndInsertTerritory('EXP Trig Ter', 'TER-EXPRPT01').Id,
            Channels__c = 'GT'
        );
        insert emp;
    }

    @isTest
    static void testValidStatusTransition() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        Date monthStart = Date.newInstance(Date.today().year(), Date.today().month(), 1);

        Expense__c expense = new Expense__c(
            Employee__c = emp.Id,
            User__c = UserInfo.getUserId(),
            Month__c = 'January',
            Year__c = Date.today().year(),
            Period_Start__c = monthStart,
            Period_End__c = monthStart.addMonths(1).addDays(-1),
            Status__c = 'Draft'
        );
        insert expense;

        Test.startTest();
        // Feature toggle is off in test context, so trigger handler won't validate
        // But the update should succeed
        expense.Status__c = 'Submitted';
        update expense;
        Test.stopTest();

        Expense__c updated = [SELECT Status__c FROM Expense__c WHERE Id = :expense.Id];
        System.assertEquals('Submitted', updated.Status__c);
    }

    @isTest
    static void testMultipleTransitions() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        Date monthStart = Date.newInstance(Date.today().year(), Date.today().month(), 1);

        Expense__c expense = new Expense__c(
            Employee__c = emp.Id,
            User__c = UserInfo.getUserId(),
            Month__c = 'February',
            Year__c = Date.today().year(),
            Period_Start__c = monthStart,
            Period_End__c = monthStart.addMonths(1).addDays(-1),
            Status__c = 'Draft'
        );
        insert expense;

        Test.startTest();
        expense.Status__c = 'Submitted';
        update expense;

        expense.Status__c = 'Manager Approved';
        update expense;

        expense.Status__c = 'Finance Approved';
        update expense;

        expense.Status__c = 'Paid';
        update expense;
        Test.stopTest();

        Expense__c final1 = [SELECT Status__c FROM Expense__c WHERE Id = :expense.Id];
        System.assertEquals('Paid', final1.Status__c);
    }
}