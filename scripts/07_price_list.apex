// Script 07: Price List - One active price per product per channel
// Run: sf apex run -f scripts/07_price_list.apex
// Prerequisite: 04_products.apex
// Note: Validation prevents overlapping date ranges for same Product+Region+Channel

List<Product_Extension__c> products = [
    SELECT Id, SKU_Code__c, MRP__c, Unit_Price__c
    FROM Product_Extension__c
    WHERE SKU_Code__c LIKE 'FF-%' AND Is_Active__c = true
];

List<Price_List__c> prices = new List<Price_List__c>();

for (Product_Extension__c p : products) {
    Decimal mrp = p.MRP__c != null ? p.MRP__c : 100.00;

    // GT channel - Retailer Price (primary selling channel)
    prices.add(new Price_List__c(
        Product_Ext__c = p.Id,
        Price_Type__c = 'Retailer Price',
        Unit_Price__c = (mrp * 0.85).setScale(2),
        Channel__c = 'GT',
        Effective_From__c = Date.today().addMonths(-6),
        Is_Active__c = true
    ));

    // MT channel - Distributor Price
    prices.add(new Price_List__c(
        Product_Ext__c = p.Id,
        Price_Type__c = 'Distributor Price',
        Unit_Price__c = (mrp * 0.70).setScale(2),
        Channel__c = 'MT',
        Effective_From__c = Date.today().addMonths(-6),
        Is_Active__c = true
    ));

    // E-Commerce channel - MRP
    prices.add(new Price_List__c(
        Product_Ext__c = p.Id,
        Price_Type__c = 'MRP',
        Unit_Price__c = mrp,
        Channel__c = 'E-Commerce',
        Effective_From__c = Date.today().addMonths(-6),
        Is_Active__c = true
    ));
}

insert prices;
System.debug('Price List setup complete. Total records: ' + prices.size());
