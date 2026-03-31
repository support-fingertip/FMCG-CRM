// ============================================================
// Script 07: Price Lists — Multi-dimensional pricing
// Prerequisite: 04_products.apex, 02_territory_master.apex, 09_accounts.apex
// Run: sf apex run --file scripts/07_price_list.apex
// ============================================================

delete [SELECT Id FROM Price_Change_Log__c];
delete [SELECT Id FROM Price_List__c];

List<Product_Extension__c> products = [
    SELECT Id, SKU_Code__c, Name, MRP__c, Unit_Price__c, Product_Category__c
    FROM Product_Extension__c WHERE Is_Active__c = true
];

Map<String, Id> terMap = new Map<String, Id>();
for (Territory_Master__c t : [SELECT Id, Territory_Code__c FROM Territory_Master__c WHERE Is_Active__c = true]) {
    terMap.put(t.Territory_Code__c, t.Id);
}

List<Account> keyAccounts = [SELECT Id, Name FROM Account WHERE Type = 'Distributor' AND Is_Active__c = true ORDER BY Name LIMIT 3];

Date stdFrom = Date.today().addMonths(-6);
Date stdTo = Date.today().addMonths(6);

// ═══════════════════════════════════════════════════════════
// 1. STANDARD PRICES — GT/MT/E-Commerce (with Effective_To so they don't block others)
// ═══════════════════════════════════════════════════════════

List<Price_List__c> stdPrices = new List<Price_List__c>();

for (Product_Extension__c p : products) {
    Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;

    stdPrices.add(new Price_List__c(
        Name = 'STD-GT-' + p.SKU_Code__c,
        Product_Ext__c = p.Id,
        Price_Type__c = 'Retailer Price',
        Unit_Price__c = (mrp * 0.70).setScale(2),
        Channel__c = 'GT',
        Effective_From__c = stdFrom,
        Effective_To__c = stdTo,
        Is_Active__c = true,
        Status__c = 'Approved'
    ));

    stdPrices.add(new Price_List__c(
        Name = 'STD-MT-' + p.SKU_Code__c,
        Product_Ext__c = p.Id,
        Price_Type__c = 'Distributor Price',
        Unit_Price__c = (mrp * 0.60).setScale(2),
        Channel__c = 'MT',
        Effective_From__c = stdFrom,
        Effective_To__c = stdTo,
        Is_Active__c = true,
        Status__c = 'Approved'
    ));

    stdPrices.add(new Price_List__c(
        Name = 'STD-ECOM-' + p.SKU_Code__c,
        Product_Ext__c = p.Id,
        Price_Type__c = 'MRP',
        Unit_Price__c = mrp,
        Channel__c = 'E-Commerce',
        Effective_From__c = stdFrom,
        Effective_To__c = stdTo,
        Is_Active__c = true,
        Status__c = 'Approved'
    ));
}

insert stdPrices;
System.debug('Standard prices: ' + stdPrices.size());

// ═══════════════════════════════════════════════════════════
// 2. TERRITORY-SPECIFIC PRICES (top 5 products, Delhi + Mumbai)
//    Composite key differs from standard because Territory is populated
// ═══════════════════════════════════════════════════════════

List<Price_List__c> terPrices = new List<Price_List__c>();
Id delhiTer = terMap.get('TER-DEL-001');
Id mumbaiTer = terMap.get('TER-MUM-001');

Integer tCount = 0;
for (Product_Extension__c p : products) {
    if (tCount >= 5) break;
    Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;

    if (delhiTer != null) {
        terPrices.add(new Price_List__c(
            Name = 'DEL-GT-' + p.SKU_Code__c,
            Product_Ext__c = p.Id,
            Price_Type__c = 'Retailer Price',
            Unit_Price__c = (mrp * 0.735).setScale(2),
            Channel__c = 'GT',
            Territory__c = delhiTer,
            Effective_From__c = stdFrom,
            Effective_To__c = stdTo,
            Is_Active__c = true,
            Status__c = 'Approved'
        ));
    }

    if (mumbaiTer != null) {
        terPrices.add(new Price_List__c(
            Name = 'MUM-GT-' + p.SKU_Code__c,
            Product_Ext__c = p.Id,
            Price_Type__c = 'Retailer Price',
            Unit_Price__c = (mrp * 0.679).setScale(2),
            Channel__c = 'GT',
            Territory__c = mumbaiTer,
            Effective_From__c = stdFrom,
            Effective_To__c = stdTo,
            Is_Active__c = true,
            Status__c = 'Approved'
        ));
    }
    tCount++;
}

if (!terPrices.isEmpty()) {
    insert terPrices;
    System.debug('Territory prices: ' + terPrices.size());
}

// ═══════════════════════════════════════════════════════════
// 3. CUSTOMER-SPECIFIC PRICES (key distributor, top 5 products)
// ═══════════════════════════════════════════════════════════

List<Price_List__c> custPrices = new List<Price_List__c>();

if (!keyAccounts.isEmpty()) {
    Account keyAcct = keyAccounts[0];
    Integer cCount = 0;
    for (Product_Extension__c p : products) {
        if (cCount >= 5) break;
        Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;

        custPrices.add(new Price_List__c(
            Name = 'KEY-' + keyAcct.Name.left(10) + '-' + p.SKU_Code__c,
            Product_Ext__c = p.Id,
            Customer__c = keyAcct.Id,
            Price_Type__c = 'Distributor Price',
            Unit_Price__c = (mrp * 0.55).setScale(2),
            Channel__c = 'MT',
            Effective_From__c = stdFrom,
            Effective_To__c = stdTo,
            Is_Active__c = true,
            Status__c = 'Approved'
        ));
        cCount++;
    }
}

if (!custPrices.isEmpty()) {
    insert custPrices;
    System.debug('Customer prices: ' + custPrices.size());
}

System.debug('');
System.debug('═══════════════════════════════════════════');
System.debug('Price List Setup Complete:');
System.debug('  Standard: ' + stdPrices.size() + ' (all products × 3 channels)');
System.debug('  Territory: ' + terPrices.size() + ' (5 products × Delhi + Mumbai)');
System.debug('  Customer: ' + custPrices.size() + ' (5 products × key account)');
System.debug('  Total: ' + (stdPrices.size() + terPrices.size() + custPrices.size()));
System.debug('═══════════════════════════════════════════');
