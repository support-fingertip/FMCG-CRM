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
        Pincode_List__c = '110001,110005,110011,110020',
        Geo_Fence_Lat__c = 28.6139,
        Geo_Fence_Long__c = 77.2090,
        Geo_Fence_Radius__c = 25,
        Is_Active__c = true
    ),
    new Territory_Master__c(
        Name = 'Mumbai Metro',
        Territory_Code__c = 'TER-MUM-001',
        Region__c = regionMap.get('WEST'),
        State__c = 'Maharashtra',
        City__c = 'Mumbai',
        Pincode_List__c = '400001,400050,400070,400101',
        Geo_Fence_Lat__c = 19.0760,
        Geo_Fence_Long__c = 72.8777,
        Geo_Fence_Radius__c = 25,
        Is_Active__c = true
    ),
    new Territory_Master__c(
        Name = 'Bengaluru Urban',
        Territory_Code__c = 'TER-BLR-001',
        Region__c = regionMap.get('SOUTH'),
        State__c = 'Karnataka',
        City__c = 'Bengaluru',
        Pincode_List__c = '560001,560034,560068,560095',
        Geo_Fence_Lat__c = 12.9716,
        Geo_Fence_Long__c = 77.5946,
        Geo_Fence_Radius__c = 25,
        Is_Active__c = true
    ),
    new Territory_Master__c(
        Name = 'Chennai City',
        Territory_Code__c = 'TER-CHN-001',
        Region__c = regionMap.get('SOUTH'),
        State__c = 'Tamil Nadu',
        City__c = 'Chennai',
        Pincode_List__c = '600001,600018,600040,600083',
        Geo_Fence_Lat__c = 13.0827,
        Geo_Fence_Long__c = 80.2707,
        Geo_Fence_Radius__c = 25,
        Is_Active__c = true
    ),
    new Territory_Master__c(
        Name = 'Kolkata Metro',
        Territory_Code__c = 'TER-KOL-001',
        Region__c = regionMap.get('EAST'),
        State__c = 'West Bengal',
        City__c = 'Kolkata',
        Pincode_List__c = '700001,700019,700054,700091',
        Geo_Fence_Lat__c = 22.5726,
        Geo_Fence_Long__c = 88.3639,
        Geo_Fence_Radius__c = 25,
        Is_Active__c = true
    ),
    new Territory_Master__c(
        Name = 'Hyderabad City',
        Territory_Code__c = 'TER-HYD-001',
        Region__c = regionMap.get('SOUTH'),
        State__c = 'Telangana',
        City__c = 'Hyderabad',
        Pincode_List__c = '500001,500028,500072,500081',
        Geo_Fence_Lat__c = 17.3850,
        Geo_Fence_Long__c = 78.4867,
        Geo_Fence_Radius__c = 25,
        Is_Active__c = true
    ),
    new Territory_Master__c(
        Name = 'Pune Metro',
        Territory_Code__c = 'TER-PUN-001',
        Region__c = regionMap.get('WEST'),
        State__c = 'Maharashtra',
        City__c = 'Pune',
        Pincode_List__c = '411001,411014,411033,411057',
        Geo_Fence_Lat__c = 18.5204,
        Geo_Fence_Long__c = 73.8567,
        Geo_Fence_Radius__c = 25,
        Is_Active__c = true
    ),
    new Territory_Master__c(
        Name = 'Ahmedabad City',
        Territory_Code__c = 'TER-AHM-001',
        Region__c = regionMap.get('WEST'),
        State__c = 'Gujarat',
        City__c = 'Ahmedabad',
        Pincode_List__c = '380001,380009,380054,380061',
        Geo_Fence_Lat__c = 23.0225,
        Geo_Fence_Long__c = 72.5714,
        Geo_Fence_Radius__c = 25,
        Is_Active__c = true
    )
};

insert territories;
System.debug('Territory Master setup complete. Total records: ' + territories.size());
