// Script 10: Beats and Beat-Outlet mappings
// Run: sf apex run -f scripts/10_beats_and_outlets.apex
// Prerequisite: 02_territory_master.apex, 09_accounts.apex

// Fetch territories
Map<String, Id> terMap = new Map<String, Id>();
for (Territory_Master__c t : [SELECT Id, Territory_Code__c FROM Territory_Master__c]) {
    terMap.put(t.Territory_Code__c, t.Id);
}

// Create beats - 6 beats for Delhi and Mumbai territories
List<Beat__c> beats = new List<Beat__c>{
    new Beat__c(Name = 'Delhi Central Beat', Beat_Code__c = 'BT-DEL-001', Territory__c = terMap.get('TER-DEL-001'), Day_of_Week__c = 'Monday;Wednesday', Frequency__c = 'Weekly', Is_Active__c = true),
    new Beat__c(Name = 'Delhi South Beat', Beat_Code__c = 'BT-DEL-002', Territory__c = terMap.get('TER-DEL-001'), Day_of_Week__c = 'Tuesday;Thursday', Frequency__c = 'Weekly', Is_Active__c = true),
    new Beat__c(Name = 'Mumbai Central Beat', Beat_Code__c = 'BT-MUM-001', Territory__c = terMap.get('TER-MUM-001'), Day_of_Week__c = 'Monday;Wednesday;Friday', Frequency__c = 'Weekly', Is_Active__c = true),
    new Beat__c(Name = 'Mumbai Suburban Beat', Beat_Code__c = 'BT-MUM-002', Territory__c = terMap.get('TER-MUM-001'), Day_of_Week__c = 'Tuesday;Thursday;Saturday', Frequency__c = 'Weekly', Is_Active__c = true),
    new Beat__c(Name = 'Bengaluru Main Beat', Beat_Code__c = 'BT-BLR-001', Territory__c = terMap.get('TER-BLR-001'), Day_of_Week__c = 'Monday;Wednesday;Friday', Frequency__c = 'Weekly', Is_Active__c = true),
    new Beat__c(Name = 'Chennai Central Beat', Beat_Code__c = 'BT-CHN-001', Territory__c = terMap.get('TER-CHN-001'), Day_of_Week__c = 'Tuesday;Thursday;Saturday', Frequency__c = 'Weekly', Is_Active__c = true)
};
insert beats;
System.debug('Inserted beats: ' + beats.size());

// Map beats by code
Map<String, Id> beatMap = new Map<String, Id>();
for (Beat__c b : beats) {
    beatMap.put(b.Beat_Code__c, b.Id);
}

// Fetch accounts by city for outlet mapping
Map<String, List<Account>> cityAccounts = new Map<String, List<Account>>();
for (Account a : [SELECT Id, Name, BillingCity FROM Account WHERE Is_Active__c = true AND RecordType.DeveloperName IN ('Retailer', 'Modern_Trade') ORDER BY Name]) {
    String city = a.BillingCity;
    if (!cityAccounts.containsKey(city)) {
        cityAccounts.put(city, new List<Account>());
    }
    cityAccounts.get(city).add(a);
}

// Create beat-outlet mappings
List<Beat_Outlet__c> beatOutlets = new List<Beat_Outlet__c>();
Integer seq;

// Delhi beats
if (cityAccounts.containsKey('New Delhi')) {
    List<Account> delhiAccts = cityAccounts.get('New Delhi');
    seq = 1;
    for (Integer i = 0; i < delhiAccts.size() && i < 3; i++) {
        beatOutlets.add(new Beat_Outlet__c(Beat__c = beatMap.get('BT-DEL-001'), Account__c = delhiAccts[i].Id, Visit_Sequence__c = seq++, Is_Active__c = true));
    }
    seq = 1;
    for (Integer i = 0; i < delhiAccts.size(); i++) {
        if (i >= 1) {
            beatOutlets.add(new Beat_Outlet__c(Beat__c = beatMap.get('BT-DEL-002'), Account__c = delhiAccts[i].Id, Visit_Sequence__c = seq++, Is_Active__c = true));
        }
    }
}

// Mumbai beats
if (cityAccounts.containsKey('Mumbai')) {
    List<Account> mumbaiAccts = cityAccounts.get('Mumbai');
    seq = 1;
    for (Integer i = 0; i < mumbaiAccts.size() && i < 3; i++) {
        beatOutlets.add(new Beat_Outlet__c(Beat__c = beatMap.get('BT-MUM-001'), Account__c = mumbaiAccts[i].Id, Visit_Sequence__c = seq++, Is_Active__c = true));
    }
    seq = 1;
    for (Integer i = 1; i < mumbaiAccts.size(); i++) {
        beatOutlets.add(new Beat_Outlet__c(Beat__c = beatMap.get('BT-MUM-002'), Account__c = mumbaiAccts[i].Id, Visit_Sequence__c = seq++, Is_Active__c = true));
    }
}

// Bengaluru beat
if (cityAccounts.containsKey('Bengaluru')) {
    List<Account> blrAccts = cityAccounts.get('Bengaluru');
    seq = 1;
    for (Account a : blrAccts) {
        beatOutlets.add(new Beat_Outlet__c(Beat__c = beatMap.get('BT-BLR-001'), Account__c = a.Id, Visit_Sequence__c = seq++, Is_Active__c = true));
    }
}

// Chennai beat
if (cityAccounts.containsKey('Chennai')) {
    List<Account> chnAccts = cityAccounts.get('Chennai');
    seq = 1;
    for (Account a : chnAccts) {
        beatOutlets.add(new Beat_Outlet__c(Beat__c = beatMap.get('BT-CHN-001'), Account__c = a.Id, Visit_Sequence__c = seq++, Is_Active__c = true));
    }
}

insert beatOutlets;
System.debug('Beats and Outlets setup complete. Beats: ' + beats.size() + ', Outlets: ' + beatOutlets.size());
