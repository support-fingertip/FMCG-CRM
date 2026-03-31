// Script 09: Accounts - Distributors, Super Stockists, Retailers, Modern Trade
// Run: sf apex run -f scripts/09_accounts.apex
// Prerequisite: 02_territory_master.apex
//
// Account Type Hierarchy:
//   RecordType + Type field = Business Role (Distributor, Super Stockist, Retailer, Modern Trade)
//   Outlet_Type__c          = Store Format  (Grocery, Medical, Hardware, General Store) — Retailers only
//   Channel__c              = Sales Channel (GT, MT, E-Commerce)
//   Outlet_Class__c         = Revenue Class (A, B, C, D)

// Clean up existing accounts (delete ALL child objects first)
delete [SELECT Id FROM Order_Line_Item__c];
delete [SELECT Id FROM Collection__c];
delete [SELECT Id FROM Sales_Order__c];
delete [SELECT Id FROM Visit__c];
delete [SELECT Id FROM Day_Attendance__c];
delete [SELECT Id FROM GRN_Line__c];
delete [SELECT Id FROM GRN__c];
delete [SELECT Id FROM Invoice_Line__c];
delete [SELECT Id FROM Invoice__c];
delete [SELECT Id FROM Indent_Line__c];
delete [SELECT Id FROM Indent__c];
delete [SELECT Id FROM Return_Line__c];
delete [SELECT Id FROM Return_Order__c];
delete [SELECT Id FROM Claim_Line__c];
delete [SELECT Id FROM Claim__c];
delete [SELECT Id FROM Ledger_Entry__c];
delete [SELECT Id FROM Survey_Response__c];
delete [SELECT Id FROM Merchandising__c];
delete [SELECT Id FROM Competitor__c];
delete [SELECT Id FROM Distributor_Stock__c];
delete [SELECT Id FROM Drug_License__c];
delete [SELECT Id FROM Loyalty_Points__c];
delete [SELECT Id FROM Ticket__c];
delete [SELECT Id FROM Scorecard__c];
delete [SELECT Id FROM Channel_Partner__c];
delete [SELECT Id FROM Scheme_Mapping__c];
delete [SELECT Id FROM Beat_Outlet__c];
delete [SELECT Id FROM Account];
System.debug('Cleaned up Accounts and all child objects');

// Fetch Record Type IDs
Map<String, Id> rtMap = new Map<String, Id>();
for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Account' AND IsActive = true]) {
    rtMap.put(rt.DeveloperName, rt.Id);
}

// Fetch territories
Map<String, Id> terMap = new Map<String, Id>();
for (Territory_Master__c t : [SELECT Id, Territory_Code__c FROM Territory_Master__c]) {
    terMap.put(t.Territory_Code__c, t.Id);
}

List<Account> accounts = new List<Account>();

// ── 3 Distributors ──────────────────────────────────────────────────────
accounts.add(new Account(
    Name = 'Sharma Distributors Pvt Ltd', Type = 'Distributor',
    RecordTypeId = rtMap.get('Distributor'), Territory__c = terMap.get('TER-DEL-001'),
    Channel__c = 'GT', GSTIN__c = '07ABCDE1234F1ZK', Credit_Limit__c = 500000,
    Is_Active__c = true, BillingStreet = '12 Chandni Chowk',
    BillingCity = 'New Delhi', BillingState = 'Delhi', BillingPostalCode = '110006',
    Phone = '011-23456789'));

accounts.add(new Account(
    Name = 'Patel Trading Company', Type = 'Distributor',
    RecordTypeId = rtMap.get('Distributor'), Territory__c = terMap.get('TER-MUM-001'),
    Channel__c = 'GT', GSTIN__c = '27FGHIJ5678K1ZL', Credit_Limit__c = 750000,
    Is_Active__c = true, BillingStreet = '45 Crawford Market',
    BillingCity = 'Mumbai', BillingState = 'Maharashtra', BillingPostalCode = '400001',
    Phone = '022-34567890'));

accounts.add(new Account(
    Name = 'Reddy & Sons Distribution', Type = 'Distributor',
    RecordTypeId = rtMap.get('Distributor'), Territory__c = terMap.get('TER-BLR-001'),
    Channel__c = 'GT', GSTIN__c = '29KLMNO9012P1ZM', Credit_Limit__c = 400000,
    Is_Active__c = true, BillingStreet = '78 Commercial Street',
    BillingCity = 'Bengaluru', BillingState = 'Karnataka', BillingPostalCode = '560001',
    Phone = '080-45678901'));

// ── 2 Super Stockists ───────────────────────────────────────────────────
accounts.add(new Account(
    Name = 'National FMCG Stockists', Type = 'Super Stockist',
    RecordTypeId = rtMap.get('Super_Stockist'), Territory__c = terMap.get('TER-DEL-001'),
    Channel__c = 'GT', GSTIN__c = '07PQRST3456U1ZN', Credit_Limit__c = 1000000,
    Is_Active__c = true, BillingStreet = '5 Karol Bagh',
    BillingCity = 'New Delhi', BillingState = 'Delhi', BillingPostalCode = '110005',
    Phone = '011-56789012'));

accounts.add(new Account(
    Name = 'Western Hub Stockists', Type = 'Super Stockist',
    RecordTypeId = rtMap.get('Super_Stockist'), Territory__c = terMap.get('TER-MUM-001'),
    Channel__c = 'GT', GSTIN__c = '27UVWXY7890Z1ZO', Credit_Limit__c = 800000,
    Is_Active__c = true, BillingStreet = '23 Andheri East',
    BillingCity = 'Mumbai', BillingState = 'Maharashtra', BillingPostalCode = '400069',
    Phone = '022-67890123'));

// ── 12 Retailers (Outlet_Type__c = store format, varies by outlet) ──────
String[] retailerNames = new String[]{
    'Lakshmi General Store', 'Ganesh Provision Store', 'Kumar Kirana',
    'Deepak Grocery', 'Gupta Mart', 'Sri Balaji Store',
    'Modern Needs Store', 'Daily Fresh Mart', 'City Grocery Point',
    'Family Store Corner', 'Quick Shop Express', 'New India Provisions'
};
String[] retailerTerritories = new String[]{
    'TER-DEL-001', 'TER-DEL-001', 'TER-MUM-001',
    'TER-MUM-001', 'TER-BLR-001', 'TER-BLR-001',
    'TER-CHN-001', 'TER-CHN-001', 'TER-KOL-001',
    'TER-HYD-001', 'TER-PUN-001', 'TER-AHM-001'
};
String[] outletTypes = new String[]{
    'Grocery', 'General Store', 'Grocery',
    'General Store', 'Grocery', 'General Store',
    'Grocery', 'Medical', 'Grocery',
    'Hardware', 'General Store', 'Grocery'
};
String[] outletClasses = new String[]{
    'A', 'B', 'A', 'C', 'B', 'A', 'B', 'C', 'A', 'B', 'C', 'B'
};

for (Integer i = 0; i < retailerNames.size(); i++) {
    accounts.add(new Account(
        Name = retailerNames[i],
        Type = 'Retailer',
        RecordTypeId = rtMap.get('Retailer'),
        Territory__c = terMap.get(retailerTerritories[i]),
        Channel__c = 'GT',
        Outlet_Type__c = outletTypes[i],
        Outlet_Class__c = outletClasses[i],
        Credit_Limit__c = 25000,
        Is_Active__c = true,
        BillingCity = retailerTerritories[i].contains('DEL') ? 'New Delhi' :
                      retailerTerritories[i].contains('MUM') ? 'Mumbai' :
                      retailerTerritories[i].contains('BLR') ? 'Bengaluru' :
                      retailerTerritories[i].contains('CHN') ? 'Chennai' :
                      retailerTerritories[i].contains('KOL') ? 'Kolkata' :
                      retailerTerritories[i].contains('HYD') ? 'Hyderabad' :
                      retailerTerritories[i].contains('PUN') ? 'Pune' : 'Ahmedabad',
        BillingState = retailerTerritories[i].contains('DEL') ? 'Delhi' :
                       retailerTerritories[i].contains('MUM') ? 'Maharashtra' :
                       retailerTerritories[i].contains('BLR') ? 'Karnataka' :
                       retailerTerritories[i].contains('CHN') ? 'Tamil Nadu' :
                       retailerTerritories[i].contains('KOL') ? 'West Bengal' :
                       retailerTerritories[i].contains('HYD') ? 'Telangana' :
                       retailerTerritories[i].contains('PUN') ? 'Maharashtra' : 'Gujarat'
    ));
}

// ── 3 Modern Trade (no Outlet_Type — MT is a business role, not a store format) ─
accounts.add(new Account(
    Name = 'SuperMart Central Delhi', Type = 'Modern Trade',
    RecordTypeId = rtMap.get('Modern_Trade'), Territory__c = terMap.get('TER-DEL-001'),
    Channel__c = 'MT', Outlet_Class__c = 'A', Credit_Limit__c = 200000,
    Is_Active__c = true, BillingCity = 'New Delhi', BillingState = 'Delhi'));

accounts.add(new Account(
    Name = 'HyperBazaar Mumbai', Type = 'Modern Trade',
    RecordTypeId = rtMap.get('Modern_Trade'), Territory__c = terMap.get('TER-MUM-001'),
    Channel__c = 'MT', Outlet_Class__c = 'A', Credit_Limit__c = 300000,
    Is_Active__c = true, BillingCity = 'Mumbai', BillingState = 'Maharashtra'));

accounts.add(new Account(
    Name = 'MegaStore Bengaluru', Type = 'Modern Trade',
    RecordTypeId = rtMap.get('Modern_Trade'), Territory__c = terMap.get('TER-BLR-001'),
    Channel__c = 'MT', Outlet_Class__c = 'A', Credit_Limit__c = 250000,
    Is_Active__c = true, BillingCity = 'Bengaluru', BillingState = 'Karnataka'));

insert accounts;

// Summary
Integer distCount = 0, ssCount = 0, retCount = 0, mtCount = 0;
for (Account a : accounts) {
    if (a.Type == 'Distributor') distCount++;
    else if (a.Type == 'Super Stockist') ssCount++;
    else if (a.Type == 'Retailer') retCount++;
    else if (a.Type == 'Modern Trade') mtCount++;
}
System.debug('');
System.debug('═══════════════════════════════════════════');
System.debug('Account Setup Complete: ' + accounts.size() + ' records');
System.debug('  Distributors:    ' + distCount);
System.debug('  Super Stockists: ' + ssCount);
System.debug('  Retailers:       ' + retCount);
System.debug('  Modern Trade:    ' + mtCount);
System.debug('═══════════════════════════════════════════');
