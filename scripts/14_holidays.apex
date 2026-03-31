// Script 14: Holiday Calendar - 2026 Indian holidays
// Run: sf apex run -f scripts/14_holidays.apex

// Clean up existing holidays
delete [SELECT Id FROM Holiday__c];
System.debug('Cleaned up Holiday__c');

// Fetch territory IDs for regional holiday assignment
Map<String, Id> terMap = new Map<String, Id>();
for (Territory_Master__c t : [SELECT Id, Territory_Code__c FROM Territory_Master__c WHERE Is_Active__c = true]) {
    terMap.put(t.Territory_Code__c, t.Id);
}

List<Holiday__c> holidays = new List<Holiday__c>{
    new Holiday__c(Name = 'Republic Day', Holiday_Date__c = Date.newInstance(2026, 1, 26), Type__c = 'National Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Republic Day of India'),
    new Holiday__c(Name = 'Holi', Holiday_Date__c = Date.newInstance(2026, 3, 17), Type__c = 'National Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Festival of Colors'),
    new Holiday__c(Name = 'Good Friday', Holiday_Date__c = Date.newInstance(2026, 4, 3), Type__c = 'National Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Good Friday'),
    new Holiday__c(Name = 'Eid ul-Fitr', Holiday_Date__c = Date.newInstance(2026, 3, 31), Type__c = 'National Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'End of Ramadan'),
    new Holiday__c(Name = 'May Day', Holiday_Date__c = Date.newInstance(2026, 5, 1), Type__c = 'National Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'International Workers Day'),
    new Holiday__c(Name = 'Independence Day', Holiday_Date__c = Date.newInstance(2026, 8, 15), Type__c = 'National Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'India Independence Day'),
    new Holiday__c(Name = 'Gandhi Jayanti', Holiday_Date__c = Date.newInstance(2026, 10, 2), Type__c = 'National Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Mahatma Gandhi Birthday'),
    new Holiday__c(Name = 'Dussehra', Holiday_Date__c = Date.newInstance(2026, 10, 20), Type__c = 'National Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Victory of Good over Evil'),
    new Holiday__c(Name = 'Diwali', Holiday_Date__c = Date.newInstance(2026, 11, 8), Type__c = 'National Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Festival of Lights'),
    new Holiday__c(Name = 'Christmas', Holiday_Date__c = Date.newInstance(2026, 12, 25), Type__c = 'National Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Christmas Day'),

    // Regional Holidays - Territory__c assigned per applicable region
    new Holiday__c(Name = 'Pongal', Holiday_Date__c = Date.newInstance(2026, 1, 14), Type__c = 'Regional Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Tamil harvest festival',
        Territory__c = terMap.get('TER-CHN-001')),
    new Holiday__c(Name = 'Ganesh Chaturthi', Holiday_Date__c = Date.newInstance(2026, 8, 26), Type__c = 'Regional Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Lord Ganesha birthday',
        Territory__c = terMap.get('TER-MUM-001')),
    new Holiday__c(Name = 'Onam', Holiday_Date__c = Date.newInstance(2026, 9, 3), Type__c = 'Regional Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Kerala harvest festival',
        Territory__c = terMap.get('TER-BLR-001')),
    new Holiday__c(Name = 'Durga Puja', Holiday_Date__c = Date.newInstance(2026, 10, 17), Type__c = 'Regional Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Worship of Goddess Durga',
        Territory__c = terMap.get('TER-KOL-001')),
    new Holiday__c(Name = 'Chhath Puja', Holiday_Date__c = Date.newInstance(2026, 11, 10), Type__c = 'Regional Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Sun God worship festival',
        Territory__c = terMap.get('TER-KOL-001')),

    // Company Holidays
    new Holiday__c(Name = 'Company Foundation Day', Holiday_Date__c = Date.newInstance(2026, 6, 15), Type__c = 'Company Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'FreshFields FMCG founding anniversary'),
    new Holiday__c(Name = 'Annual Day', Holiday_Date__c = Date.newInstance(2026, 12, 31), Type__c = 'Company Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Year-end celebration and awards'),

    // Optional Holidays
    new Holiday__c(Name = 'Mahavir Jayanti', Holiday_Date__c = Date.newInstance(2026, 4, 6), Type__c = 'Optional Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Jain festival'),
    new Holiday__c(Name = 'Buddha Purnima', Holiday_Date__c = Date.newInstance(2026, 5, 12), Type__c = 'Optional Holiday', Year__c = 2026, Is_Active__c = true, Description__c = 'Birth of Gautama Buddha')
};

insert holidays;
System.debug('Holiday setup complete. Total: ' + holidays.size());
