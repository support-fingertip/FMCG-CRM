// ============================================================
// Script 07: Price Lists — Standard channel pricing for all products
// Prerequisite: 04_products.apex
// Run: sf apex run --file scripts/07_price_list.apex
// ============================================================

delete [SELECT Id FROM Price_Change_Log__c];
delete [SELECT Id FROM Price_List__c];

List<Product_Extension__c> products = [
    SELECT Id, SKU_Code__c, Name, MRP__c, Unit_Price__c
    FROM Product_Extension__c
    WHERE Is_Active__c = true
];

List<Price_List__c> prices = new List<Price_List__c>();
Date effectiveFrom = Date.today().addMonths(-6);

for (Product_Extension__c p : products) {
    Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;

    // GT Channel — Retailer Price (70% of MRP)
    prices.add(new Price_List__c(
        Name = 'STD-GT-' + p.SKU_Code__c,
        Product_Ext__c = p.Id,
        Price_Type__c = 'Retailer Price',
        Unit_Price__c = (mrp * 0.70).setScale(2),
        Channel__c = 'GT',
        Effective_From__c = effectiveFrom,
        Is_Active__c = true,
        Status__c = 'Approved',
        Priority__c = 99
    ));

    // MT Channel — Distributor Price (60% of MRP)
    prices.add(new Price_List__c(
        Name = 'STD-MT-' + p.SKU_Code__c,
        Product_Ext__c = p.Id,
        Price_Type__c = 'Distributor Price',
        Unit_Price__c = (mrp * 0.60).setScale(2),
        Channel__c = 'MT',
        Effective_From__c = effectiveFrom,
        Is_Active__c = true,
        Status__c = 'Approved',
        Priority__c = 99
    ));

    // E-Commerce — MRP
    prices.add(new Price_List__c(
        Name = 'STD-ECOM-' + p.SKU_Code__c,
        Product_Ext__c = p.Id,
        Price_Type__c = 'MRP',
        Unit_Price__c = mrp,
        Channel__c = 'E-Commerce',
        Effective_From__c = effectiveFrom,
        Is_Active__c = true,
        Status__c = 'Approved',
        Priority__c = 99
    ));
}

insert prices;

System.debug('═══════════════════════════════════════════');
System.debug('Price List Setup Complete:');
System.debug('  Products: ' + products.size());
System.debug('  Price Records: ' + prices.size() + ' (' + products.size() + ' × 3 channels)');
System.debug('  Channels: GT (70% MRP), MT (60% MRP), E-Commerce (100% MRP)');
System.debug('═══════════════════════════════════════════');
