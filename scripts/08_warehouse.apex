// Script 08: Warehouses - 5 regional warehouses
// Run: sf apex run -f scripts/08_warehouse.apex
// Prerequisite: 01_company_hierarchy.apex

// Clean up (delete stock children first, then warehouses)
delete [SELECT Id FROM Warehouse_Stock__c];
delete [SELECT Id FROM Warehouse__c];
System.debug('Cleaned up Warehouse__c');

Map<String, Id> hierMap = new Map<String, Id>();
for (Company_Hierarchy__c ch : [SELECT Id, Code__c FROM Company_Hierarchy__c WHERE Level__c = 'Region']) {
    hierMap.put(ch.Code__c, ch.Id);
}

List<Warehouse__c> warehouses = new List<Warehouse__c>{
    new Warehouse__c(
        Name = 'Central Warehouse Mumbai',
        Warehouse_Code__c = 'WH-MUM',
        Warehouse_Type__c = 'Central',
        Address__c = 'Plot 45, MIDC Bhiwandi',
        City__c = 'Mumbai',
        State__c = 'Maharashtra',
        Pincode__c = '421302',
        Company_Hierarchy__c = hierMap.get('WEST'),
        Storage_Capacity__c = 50000,
        Is_Active__c = true
    ),
    new Warehouse__c(
        Name = 'Regional Warehouse Delhi',
        Warehouse_Code__c = 'WH-DEL',
        Warehouse_Type__c = 'Regional',
        Address__c = 'Sector 63, Noida',
        City__c = 'New Delhi',
        State__c = 'Delhi',
        Pincode__c = '201301',
        Company_Hierarchy__c = hierMap.get('NORTH'),
        Storage_Capacity__c = 30000,
        Is_Active__c = true
    ),
    new Warehouse__c(
        Name = 'Regional Warehouse Bengaluru',
        Warehouse_Code__c = 'WH-BLR',
        Warehouse_Type__c = 'Regional',
        Address__c = 'Peenya Industrial Area Phase 2',
        City__c = 'Bengaluru',
        State__c = 'Karnataka',
        Pincode__c = '560058',
        Company_Hierarchy__c = hierMap.get('SOUTH'),
        Storage_Capacity__c = 25000,
        Is_Active__c = true
    ),
    new Warehouse__c(
        Name = 'Depot Kolkata',
        Warehouse_Code__c = 'WH-KOL',
        Warehouse_Type__c = 'Depot',
        Address__c = 'Howrah Industrial Park',
        City__c = 'Kolkata',
        State__c = 'West Bengal',
        Pincode__c = '711101',
        Company_Hierarchy__c = hierMap.get('EAST'),
        Storage_Capacity__c = 15000,
        Is_Active__c = true
    ),
    new Warehouse__c(
        Name = 'C&F Ahmedabad',
        Warehouse_Code__c = 'WH-AHM',
        Warehouse_Type__c = 'C&F',
        Address__c = 'Sanand GIDC',
        City__c = 'Ahmedabad',
        State__c = 'Gujarat',
        Pincode__c = '382110',
        Company_Hierarchy__c = hierMap.get('WEST'),
        Storage_Capacity__c = 20000,
        Is_Active__c = true
    )
};

insert warehouses;
System.debug('Warehouse setup complete. Total records: ' + warehouses.size());
