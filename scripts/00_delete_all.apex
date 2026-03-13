// Script 00: Delete All Sample Data - Clean slate for re-loading
// Run: sf apex run -f scripts/00_delete_all.apex
// WARNING: This deletes ALL records from custom objects. Use with caution!

// Delete in reverse dependency order to avoid relationship errors

// Child objects first
delete [SELECT Id FROM Journey_Plan_Day__c LIMIT 10000];
System.debug('Deleted Journey_Plan_Day__c');

delete [SELECT Id FROM Journey_Plan__c LIMIT 10000];
System.debug('Deleted Journey_Plan__c');

delete [SELECT Id FROM Leave_Request__c LIMIT 10000];
System.debug('Deleted Leave_Request__c');

delete [SELECT Id FROM Holiday__c LIMIT 10000];
System.debug('Deleted Holiday__c');

delete [SELECT Id FROM Employee__c LIMIT 10000];
System.debug('Deleted Employee__c');

delete [SELECT Id FROM Target_Line__c LIMIT 10000];
System.debug('Deleted Target_Line__c');

delete [SELECT Id FROM Target__c LIMIT 10000];
System.debug('Deleted Target__c');

delete [SELECT Id FROM Scheme_Mapping__c LIMIT 10000];
System.debug('Deleted Scheme_Mapping__c');

delete [SELECT Id FROM Scheme_Slab__c LIMIT 10000];
System.debug('Deleted Scheme_Slab__c');

delete [SELECT Id FROM Scheme_Product__c LIMIT 10000];
System.debug('Deleted Scheme_Product__c');

delete [SELECT Id FROM Scheme__c LIMIT 10000];
System.debug('Deleted Scheme__c');

delete [SELECT Id FROM Beat_Outlet__c LIMIT 10000];
System.debug('Deleted Beat_Outlet__c');

delete [SELECT Id FROM Beat__c LIMIT 10000];
System.debug('Deleted Beat__c');

delete [SELECT Id FROM Account WHERE Is_Active__c != null LIMIT 10000];
System.debug('Deleted Accounts');

delete [SELECT Id FROM Warehouse_Stock__c LIMIT 10000];
System.debug('Deleted Warehouse_Stock__c');

delete [SELECT Id FROM Warehouse__c LIMIT 10000];
System.debug('Deleted Warehouse__c');

delete [SELECT Id FROM Price_List__c LIMIT 10000];
System.debug('Deleted Price_List__c');

delete [SELECT Id FROM Tax_Configuration__c LIMIT 10000];
System.debug('Deleted Tax_Configuration__c');

delete [SELECT Id FROM Batch_Master__c LIMIT 10000];
System.debug('Deleted Batch_Master__c');

delete [SELECT Id FROM Product_Extension__c LIMIT 10000];
System.debug('Deleted Product_Extension__c');

delete [SELECT Id FROM Product2 WHERE ProductCode LIKE 'FF-%' LIMIT 10000];
System.debug('Deleted Product2');

delete [SELECT Id FROM Product_Category__c WHERE Parent_Category__c != null LIMIT 10000];
System.debug('Deleted Sub-Categories');

delete [SELECT Id FROM Product_Category__c LIMIT 10000];
System.debug('Deleted Categories');

delete [SELECT Id FROM Territory_Master__c LIMIT 10000];
System.debug('Deleted Territory_Master__c');

delete [SELECT Id FROM Company_Hierarchy__c WHERE Level__c = 'Region' LIMIT 10000];
delete [SELECT Id FROM Company_Hierarchy__c WHERE Level__c = 'Division' LIMIT 10000];
delete [SELECT Id FROM Company_Hierarchy__c WHERE Level__c = 'Parent Company' LIMIT 10000];
System.debug('Deleted Company_Hierarchy__c');

System.debug('All sample data deleted successfully!');
