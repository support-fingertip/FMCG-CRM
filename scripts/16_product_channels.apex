// Seed: Assign default channels to products
// All active products get all 3 channels by default; narrow per business needs post-seed.

List<Product_Extension__c> products = [SELECT Id, Name, Channels__c FROM Product_Extension__c WHERE Is_Active__c = true];
List<Product_Extension__c> toUpdate = new List<Product_Extension__c>();

for (Product_Extension__c prod : products) {
    if (String.isBlank(prod.Channels__c)) {
        prod.Channels__c = 'GT;MT;E-Commerce';
        toUpdate.add(prod);
    }
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Updated ' + toUpdate.size() + ' products with default channels (GT;MT;E-Commerce)');
} else {
    System.debug('All products already have channels assigned');
}
