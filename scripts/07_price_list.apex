// Script 07: Price List - MRP, Distributor, and Retailer prices
// Run: sf apex run -f scripts/07_price_list.apex
// Prerequisite: 04_products.apex

// Base MRP prices by product code
Map<String, Decimal> mrpMap = new Map<String, Decimal>{
    'FF-SNK-001' => 30.00, 'FF-SNK-002' => 30.00,
    'FF-BIS-001' => 25.00, 'FF-BIS-002' => 35.00,
    'FF-NDL-001' => 14.00,
    'FF-DRY-001' => 28.00, 'FF-DRY-002' => 20.00,
    'FF-CNF-001' => 50.00,
    'FF-JUC-001' => 120.00, 'FF-JUC-002' => 110.00,
    'FF-SOD-001' => 20.00,
    'FF-TEA-001' => 180.00,
    'FF-HAR-001' => 95.00, 'FF-HAR-002' => 175.00,
    'FF-SKN-001' => 85.00, 'FF-SKN-002' => 120.00,
    'FF-ORL-001' => 65.00,
    'FF-DET-001' => 135.00, 'FF-DET-002' => 89.00,
    'FF-CLN-001' => 99.00
};

List<Product2> products = [SELECT Id, ProductCode FROM Product2 WHERE ProductCode LIKE 'FF-%' AND IsActive = true];

List<Price_List__c> prices = new List<Price_List__c>();

for (Product2 p : products) {
    Decimal mrp = mrpMap.containsKey(p.ProductCode) ? mrpMap.get(p.ProductCode) : 100.00;
    Decimal distPrice = mrp * 0.70;  // 30% margin for distributors
    Decimal retPrice = mrp * 0.85;   // 15% margin for retailers

    // MRP
    prices.add(new Price_List__c(
        Product__c = p.Id,
        Price_Type__c = 'MRP',
        Unit_Price__c = mrp,
        Channel__c = 'GT',
        Effective_From__c = Date.today().addMonths(-6),
        Is_Active__c = true
    ));

    // Distributor Price
    prices.add(new Price_List__c(
        Product__c = p.Id,
        Price_Type__c = 'Distributor Price',
        Unit_Price__c = distPrice.setScale(2),
        Channel__c = 'GT',
        Effective_From__c = Date.today().addMonths(-6),
        Is_Active__c = true
    ));

    // Retailer Price
    prices.add(new Price_List__c(
        Product__c = p.Id,
        Price_Type__c = 'Retailer Price',
        Unit_Price__c = retPrice.setScale(2),
        Channel__c = 'GT',
        Effective_From__c = Date.today().addMonths(-6),
        Is_Active__c = true
    ));
}

insert prices;
System.debug('Price List setup complete. Total records: ' + prices.size());
