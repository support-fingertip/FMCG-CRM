// Script 02: Territory Master - 8 key FMCG territories
// Run: sf apex run -f scripts/02_territory_master.apex
// Prerequisite: 01_company_hierarchy.apex

// Clean up existing territories
delete [SELECT Id FROM Territory_Master__c];
System.debug('Cleaned up Territory_Master__c');

// Fetch region hierarchy records (Region__c is a Lookup to Company_Hierarchy__c)
Map<String, Id> regionMap = new Map<String, Id>();
for (Company_Hierarchy__c ch : [SELECT Id, Code__c FROM Company_Hierarchy__c WHERE Level__c = 'Region']) {
    regionMap.put(ch.Code__c, ch.Id);
}
System.assert(!regionMap.isEmpty(), 'No regions found. Run 01_company_hierarchy.apex first.');

List<Territory_Master__c> territories = new List<Territory_Master__c>{
    new Territory_Master__c(
        Name = 'Delhi NCR',
        Territory_Code__c = 'TER-DEL-001',
        Region__c = regionMap.get('NORTH'),
        State__c = 'Delhi',
        City__c = 'New Delhi',
        Is_Active__c = true
    ),
    new Territory_Master__c(
        Name = 'Mumbai Metro',
        Territory_Code__c = 'TER-MUM-001',
        Region__c = regionMap.get('WEST'),
        State__c = 'Maharashtra',
        City__c = 'Mumbai',
        Is_Active__c = true
    ),
    new Territory_Master__c(
        Name = 'Bengaluru Urban',
        Territory_Code__c = 'TER-BLR-001',
        Region__c = regionMap.get('SOUTH'),
        State__c = 'Karnataka',
        City__c = 'Bengaluru',
        Is_Active__c = true
    ),
    new Territory_Master__c(
        Name = 'Chennai City',
        Territory_Code__c = 'TER-CHN-001',
        Region__c = regionMap.get('SOUTH'),
        State__c = 'Tamil Nadu',
        City__c = 'Chennai',
        Is_Active__c = true
    ),
    new Territory_Master__c(
        Name = 'Kolkata Metro',
        Territory_Code__c = 'TER-KOL-001',
        Region__c = regionMap.get('EAST'),
        State__c = 'West Bengal',
        City__c = 'Kolkata',
        Is_Active__c = true
    ),
    new Territory_Master__c(
        Name = 'Hyderabad City',
        Territory_Code__c = 'TER-HYD-001',
        Region__c = regionMap.get('SOUTH'),
        State__c = 'Telangana',
        City__c = 'Hyderabad',
        Is_Active__c = true
    ),
    new Territory_Master__c(
        Name = 'Pune Metro',
        Territory_Code__c = 'TER-PUN-001',
        Region__c = regionMap.get('WEST'),
        State__c = 'Maharashtra',
        City__c = 'Pune',
        Is_Active__c = true
    ),
    new Territory_Master__c(
        Name = 'Ahmedabad City',
        Territory_Code__c = 'TER-AHM-001',
        Region__c = regionMap.get('WEST'),
        State__c = 'Gujarat',
        City__c = 'Ahmedabad',
        Is_Active__c = true
    )
};

insert territories;
System.debug('Territory Master setup complete. Total records: ' + territories.size());
