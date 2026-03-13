// Script 05: Batch Master - 2 batches per product
// Run: sf apex run -f scripts/05_batch_master.apex
// Prerequisite: 04_products.apex

List<Product_Extension__c> products = [
    SELECT Id, SKU_Code__c, Name
    FROM Product_Extension__c
    WHERE SKU_Code__c LIKE 'FF-%' AND Is_Active__c = true
    ORDER BY SKU_Code__c
];

List<Batch_Master__c> batches = new List<Batch_Master__c>();
Integer batchNum = 1;

for (Product_Extension__c p : products) {
    // Batch 1: manufactured 6 months ago, 18 months shelf life
    batches.add(new Batch_Master__c(
        Name = p.SKU_Code__c + '-B' + String.valueOf(batchNum).leftPad(3, '0'),
        Product_Ext__c = p.Id,
        Batch_Number__c = 'BN-' + String.valueOf(batchNum).leftPad(4, '0'),
        Manufacturing_Date__c = Date.today().addMonths(-6),
        Expiry_Date__c = Date.today().addMonths(12),
        Quantity_Manufactured__c = 10000,
        Status__c = 'Active'
    ));
    batchNum++;

    // Batch 2: manufactured 1 month ago, 18 months shelf life
    batches.add(new Batch_Master__c(
        Name = p.SKU_Code__c + '-B' + String.valueOf(batchNum).leftPad(3, '0'),
        Product_Ext__c = p.Id,
        Batch_Number__c = 'BN-' + String.valueOf(batchNum).leftPad(4, '0'),
        Manufacturing_Date__c = Date.today().addMonths(-1),
        Expiry_Date__c = Date.today().addMonths(17),
        Quantity_Manufactured__c = 15000,
        Status__c = 'Active'
    ));
    batchNum++;
}

insert batches;
System.debug('Batch Master setup complete. Total batches: ' + batches.size());
