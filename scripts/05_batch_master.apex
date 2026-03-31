// Script 05: Batch Master - 2 batches per product
// Run: sf apex run -f scripts/05_batch_master.apex
// Prerequisite: 04_products.apex

// Clean up existing batches
delete [SELECT Id FROM Batch_Master__c];
System.debug('Cleaned up Batch_Master__c');

List<Product_Extension__c> products = [
    SELECT Id, SKU_Code__c, Name, Shelf_Life_Days__c
    FROM Product_Extension__c
    WHERE SKU_Code__c LIKE 'FF-%' AND Is_Active__c = true
    ORDER BY SKU_Code__c
];

List<Batch_Master__c> batches = new List<Batch_Master__c>();
Integer batchNum = 1;

// Track near-expiry batch count — mark first 2 Batch 1 records as near-expiry
// (expiry within 30 days, manufactured shelf_life_days - 30 days ago)
Integer nearExpiryCount = 0;

for (Product_Extension__c p : products) {
    Integer shelfDays = (p.Shelf_Life_Days__c != null) ? Integer.valueOf(p.Shelf_Life_Days__c) : 365;

    // Near-expiry logic: first 2 products get a batch expiring in ~20 days
    Boolean makeNearExpiry = (nearExpiryCount < 2);

    // Batch 1: manufactured (shelfDays - 20) days ago, expiring in ~20 days
    //          For non-near-expiry: manufactured 6 months ago, expiring at full shelf life from mfg date
    Date mfgDate1;
    Date expDate1;
    if (makeNearExpiry) {
        // Near-expiry: manufactured long ago, expiring in ~20 days (formula auto-flags)
        mfgDate1 = Date.today().addDays(-(shelfDays - 20));
        expDate1 = Date.today().addDays(20);
        nearExpiryCount++;
    } else {
        mfgDate1 = Date.today().addMonths(-6);
        expDate1 = mfgDate1.addDays(shelfDays);
    }

    batches.add(new Batch_Master__c(
        Name = p.SKU_Code__c + '-B' + String.valueOf(batchNum).leftPad(3, '0'),
        Product_Ext__c = p.Id,
        Batch_Number__c = 'BN-' + String.valueOf(batchNum).leftPad(4, '0'),
        Manufacturing_Date__c = mfgDate1,
        Expiry_Date__c = expDate1,
        Quantity_Manufactured__c = 10000,
        Shelf_Life_Days__c = shelfDays,
        Status__c = 'Active'
    ));
    batchNum++;

    // Batch 2: manufactured 1 month ago, full shelf life from mfg date
    Date mfgDate2 = Date.today().addMonths(-1);
    Date expDate2 = mfgDate2.addDays(shelfDays);
    batches.add(new Batch_Master__c(
        Name = p.SKU_Code__c + '-B' + String.valueOf(batchNum).leftPad(3, '0'),
        Product_Ext__c = p.Id,
        Batch_Number__c = 'BN-' + String.valueOf(batchNum).leftPad(4, '0'),
        Manufacturing_Date__c = mfgDate2,
        Expiry_Date__c = expDate2,
        Quantity_Manufactured__c = 15000,
        Shelf_Life_Days__c = shelfDays,
        Status__c = 'Active'
    ));
    batchNum++;
}

insert batches;
System.debug('Batch Master setup complete. Total batches: ' + batches.size());
