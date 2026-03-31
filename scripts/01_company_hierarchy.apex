// Script 01: Company Hierarchy - 3 levels
// Run: sf apex run -f scripts/01_company_hierarchy.apex

// Clean up (nullify self-refs first, then delete)
List<Company_Hierarchy__c> chOld = [SELECT Id FROM Company_Hierarchy__c WHERE Parent_Hierarchy__c != null];
for (Company_Hierarchy__c c : chOld) c.Parent_Hierarchy__c = null;
if (!chOld.isEmpty()) update chOld;
delete [SELECT Id FROM Company_Hierarchy__c];
System.debug('Cleaned up Company_Hierarchy__c');

List<Company_Hierarchy__c> level1 = new List<Company_Hierarchy__c>{
    new Company_Hierarchy__c(
        Name = 'FreshFields FMCG Ltd',
        Code__c = 'FFMCG',
        Level__c = 'Parent Company',
        Is_Active__c = true,
        Description__c = 'Parent holding company for all FMCG operations'
    )
};
insert level1;
System.debug('Inserted Level 1: ' + level1.size());

List<Company_Hierarchy__c> level2 = new List<Company_Hierarchy__c>{
    new Company_Hierarchy__c(
        Name = 'Foods Division',
        Code__c = 'FOOD',
        Level__c = 'Division',
        Parent_Hierarchy__c = level1[0].Id,
        Is_Active__c = true,
        Description__c = 'Packaged foods and snacks'
    ),
    new Company_Hierarchy__c(
        Name = 'Personal Care Division',
        Code__c = 'PCARE',
        Level__c = 'Division',
        Parent_Hierarchy__c = level1[0].Id,
        Is_Active__c = true,
        Description__c = 'Personal care and hygiene products'
    ),
    new Company_Hierarchy__c(
        Name = 'Home Care Division',
        Code__c = 'HCARE',
        Level__c = 'Division',
        Parent_Hierarchy__c = level1[0].Id,
        Is_Active__c = true,
        Description__c = 'Home cleaning and maintenance'
    )
};
insert level2;
System.debug('Inserted Level 2: ' + level2.size());

List<Company_Hierarchy__c> level3 = new List<Company_Hierarchy__c>{
    new Company_Hierarchy__c(
        Name = 'North Region',
        Code__c = 'NORTH',
        Level__c = 'Region',
        Parent_Hierarchy__c = level2[0].Id,
        Is_Active__c = true,
        Description__c = 'North India operations'
    ),
    new Company_Hierarchy__c(
        Name = 'South Region',
        Code__c = 'SOUTH',
        Level__c = 'Region',
        Parent_Hierarchy__c = level2[0].Id,
        Is_Active__c = true,
        Description__c = 'South India operations'
    ),
    new Company_Hierarchy__c(
        Name = 'West Region',
        Code__c = 'WEST',
        Level__c = 'Region',
        Parent_Hierarchy__c = level2[0].Id,
        Is_Active__c = true,
        Description__c = 'West India operations'
    ),
    new Company_Hierarchy__c(
        Name = 'East Region',
        Code__c = 'EAST',
        Level__c = 'Region',
        Parent_Hierarchy__c = level2[0].Id,
        Is_Active__c = true,
        Description__c = 'East India operations'
    )
};
insert level3;
System.debug('Inserted Level 3: ' + level3.size());

System.debug('Company Hierarchy setup complete. Total records: ' + (level1.size() + level2.size() + level3.size()));
