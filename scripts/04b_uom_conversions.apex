// ============================================================
// Script 04b: Product-Specific UOM Conversions
// Run AFTER: 04_products.apex (products must exist)
// Run via: sf apex run --file scripts/04b_uom_conversions.apex
//
// Creates product-specific BOX/CSE→PCS conversions based on
// each product's Case_Size__c field. Falls back to defaults
// if Case_Size__c is not set.
// ============================================================

// Delete existing product-specific conversions only (keep global)
delete [SELECT Id FROM UOM_Conversion__c WHERE Product__c != null];

Map<String, Id> uomMap = new Map<String, Id>();
for (UOM__c u : [SELECT Id, UOM_Code__c FROM UOM__c WHERE Is_Active__c = true]) {
    uomMap.put(u.UOM_Code__c, u.Id);
}

Id pcsUom = uomMap.get('PCS');
Id boxUom = uomMap.get('BOX');
Id cseUom = uomMap.get('CSE');
Id kgUom  = uomMap.get('KG');
Id ltrUom = uomMap.get('LTR');

if (pcsUom == null || boxUom == null) {
    System.debug('ERROR: PCS or BOX UOM not found. Run 04a_uom_master.apex first.');
    return;
}

// Fetch all active products with their case sizes
List<Product_Extension__c> products = [
    SELECT Id, Name, SKU_Code__c, Case_Size__c, Weight__c, Weight_Unit__c,
           Base_UOM__c, Base_UOM__r.UOM_Code__c
    FROM Product_Extension__c
    WHERE Is_Active__c = true
    ORDER BY SKU_Code__c
];

List<UOM_Conversion__c> conversions = new List<UOM_Conversion__c>();

for (Product_Extension__c p : products) {
    // BOX → PCS: Use Case_Size__c if available
    Decimal boxToPcs = (p.Case_Size__c != null && p.Case_Size__c > 0)
        ? p.Case_Size__c : 12; // default 12 PCS per BOX

    conversions.add(new UOM_Conversion__c(
        Product__c = p.Id,
        From_UOM__c = boxUom,
        To_UOM__c = pcsUom,
        Conversion_Factor__c = boxToPcs,
        Inverse_Conversion_Factor__c = (1 / boxToPcs).setScale(6, RoundingMode.HALF_UP),
        Is_Active__c = true
    ));

    // CSE → BOX: Standard 10 boxes per case for all products
    conversions.add(new UOM_Conversion__c(
        Product__c = p.Id,
        From_UOM__c = cseUom,
        To_UOM__c = boxUom,
        Conversion_Factor__c = 10,
        Inverse_Conversion_Factor__c = 0.1,
        Is_Active__c = true
    ));
}

insert conversions;

// Summary
System.debug('');
System.debug('═══════════════════════════════════════════');
System.debug('Product-Specific UOM Conversions Created: ' + conversions.size());
System.debug('  Products covered: ' + products.size());
System.debug('  Conversions per product: 2 (BOX→PCS, CSE→BOX)');
System.debug('');
System.debug('Sample conversions:');
Integer shown = 0;
for (Product_Extension__c p : products) {
    if (shown >= 5) break;
    Decimal cs = (p.Case_Size__c != null && p.Case_Size__c > 0) ? p.Case_Size__c : 12;
    System.debug('  ' + p.Name + ' (' + p.SKU_Code__c + '): 1 BOX = ' + cs.intValue() + ' PCS');
    shown++;
}
System.debug('═══════════════════════════════════════════');
