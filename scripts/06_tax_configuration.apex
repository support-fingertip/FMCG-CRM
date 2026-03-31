// Script 06: Tax Configuration - GST rates per product
// Run: sf apex run -f scripts/06_tax_configuration.apex
// Prerequisite: 04_products.apex

// Clean up existing tax configs
delete [SELECT Id FROM Tax_Configuration__c];
System.debug('Cleaned up Tax_Configuration__c');

// Map HSN prefix to GST rates [Total, CGST, SGST, IGST]
Map<String, Decimal[]> hsnRates = new Map<String, Decimal[]>{
    '04' => new Decimal[]{5.0, 2.5, 2.5, 5.0},   // Dairy
    '09' => new Decimal[]{5.0, 2.5, 2.5, 5.0},   // Tea/Coffee
    '17' => new Decimal[]{18.0, 9.0, 9.0, 18.0},  // Confectionery
    '19' => new Decimal[]{18.0, 9.0, 9.0, 18.0},  // Biscuits/Noodles
    '20' => new Decimal[]{12.0, 6.0, 6.0, 12.0},  // Prepared food/Snacks
    '22' => new Decimal[]{12.0, 6.0, 6.0, 12.0},  // Soft drinks
    '33' => new Decimal[]{28.0, 14.0, 14.0, 28.0}, // Cosmetics/Hair/Skin/Oral
    '34' => new Decimal[]{18.0, 9.0, 9.0, 18.0}   // Detergent/Cleaners
};

List<Product_Extension__c> exts = [
    SELECT Id, HSN_SAC_Code__c
    FROM Product_Extension__c
    WHERE Is_Active__c = true AND SKU_Code__c LIKE 'FF-%'
];

List<Tax_Configuration__c> taxConfigs = new List<Tax_Configuration__c>();

for (Product_Extension__c ext : exts) {
    String hsn2 = ext.HSN_SAC_Code__c != null ? ext.HSN_SAC_Code__c.substring(0, 2) : '18';
    Decimal[] rates = hsnRates.containsKey(hsn2) ? hsnRates.get(hsn2) : new Decimal[]{18.0, 9.0, 9.0, 18.0};

    taxConfigs.add(new Tax_Configuration__c(
        Product_Ext__c = ext.Id,
        Tax_Type__c = 'GST',
        Tax_Rate__c = rates[0],
        HSN_SAC_Code__c = ext.HSN_SAC_Code__c,
        CGST_Rate__c = rates[1],
        SGST_Rate__c = rates[2],
        IGST_Rate__c = rates[3],
        Effective_From__c = Date.newInstance(2017, 7, 1),
        Is_Active__c = true
    ));
}

insert taxConfigs;
System.debug('Tax Configuration setup complete. Total records: ' + taxConfigs.size());
