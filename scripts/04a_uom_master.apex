// ============================================================
// Script 04a: UOM Master + UOM Conversions
// Run BEFORE: 04_products.apex
// Run via: sf apex run --file scripts/04a_uom_master.apex
// ============================================================

delete [SELECT Id FROM UOM_Conversion__c];
delete [SELECT Id FROM UOM__c];

List<UOM__c> uoms = new List<UOM__c>();

uoms.add(new UOM__c(Name = 'Pieces', UOM_Code__c = 'PCS', UOM_Type__c = 'Count', Is_Base_Unit__c = true, Is_Active__c = true, Description__c = 'Individual pieces/units'));
uoms.add(new UOM__c(Name = 'Box', UOM_Code__c = 'BOX', UOM_Type__c = 'Count', Is_Base_Unit__c = false, Is_Active__c = true, Description__c = 'Box containing multiple pieces'));
uoms.add(new UOM__c(Name = 'Case', UOM_Code__c = 'CSE', UOM_Type__c = 'Count', Is_Base_Unit__c = false, Is_Active__c = true, Description__c = 'Case containing multiple boxes'));
uoms.add(new UOM__c(Name = 'Dozen', UOM_Code__c = 'DOZ', UOM_Type__c = 'Count', Is_Base_Unit__c = false, Is_Active__c = true, Description__c = '12 pieces'));
uoms.add(new UOM__c(Name = 'Kilogram', UOM_Code__c = 'KG', UOM_Type__c = 'Weight', Is_Base_Unit__c = true, Is_Active__c = true, Description__c = 'Weight in kilograms'));
uoms.add(new UOM__c(Name = 'Gram', UOM_Code__c = 'GM', UOM_Type__c = 'Weight', Is_Base_Unit__c = false, Is_Active__c = true, Description__c = 'Weight in grams'));
uoms.add(new UOM__c(Name = 'Litre', UOM_Code__c = 'LTR', UOM_Type__c = 'Volume', Is_Base_Unit__c = true, Is_Active__c = true, Description__c = 'Volume in litres'));
uoms.add(new UOM__c(Name = 'Millilitre', UOM_Code__c = 'ML', UOM_Type__c = 'Volume', Is_Base_Unit__c = false, Is_Active__c = true, Description__c = 'Volume in millilitres'));
uoms.add(new UOM__c(Name = 'Pack', UOM_Code__c = 'PKT', UOM_Type__c = 'Count', Is_Base_Unit__c = false, Is_Active__c = true, Description__c = 'Small pack/pouch'));
uoms.add(new UOM__c(Name = 'Strip', UOM_Code__c = 'STP', UOM_Type__c = 'Count', Is_Base_Unit__c = false, Is_Active__c = true, Description__c = 'Strip packaging'));

insert uoms;
System.debug('Created ' + uoms.size() + ' UOM records');

// ── UOM Conversions ──────────────────────────────────────
Map<String, Id> uomMap = new Map<String, Id>();
for (UOM__c u : uoms) uomMap.put(u.UOM_Code__c, u.Id);

// Get products for product-specific conversions
Map<String, Id> prodMap = new Map<String, Id>();
for (Product_Extension__c p : [SELECT Id, SKU_Code__c FROM Product_Extension__c WHERE Is_Active__c = true LIMIT 200]) {
    prodMap.put(p.SKU_Code__c, p.Id);
}

List<UOM_Conversion__c> conversions = new List<UOM_Conversion__c>();

// Generic conversions (no product — universal)
conversions.add(new UOM_Conversion__c(
From_UOM__c = uomMap.get('DOZ'), To_UOM__c = uomMap.get('PCS'),
    Conversion_Factor__c = 12, Inverse_Conversion_Factor__c = 0.0833, Is_Active__c = true
));
conversions.add(new UOM_Conversion__c(
From_UOM__c = uomMap.get('KG'), To_UOM__c = uomMap.get('GM'),
    Conversion_Factor__c = 1000, Inverse_Conversion_Factor__c = 0.001, Is_Active__c = true
));
conversions.add(new UOM_Conversion__c(
From_UOM__c = uomMap.get('LTR'), To_UOM__c = uomMap.get('ML'),
    Conversion_Factor__c = 1000, Inverse_Conversion_Factor__c = 0.001, Is_Active__c = true
));

// Product-specific conversions (BOX/CSE to PCS for key products)
// Snacks: 1 BOX = 48 PCS, 1 CSE = 10 BOX
if (prodMap.containsKey('FF-SNK-001')) {
    conversions.add(new UOM_Conversion__c(
    Product__c = prodMap.get('FF-SNK-001'),
        From_UOM__c = uomMap.get('BOX'), To_UOM__c = uomMap.get('PCS'),
        Conversion_Factor__c = 48, Inverse_Conversion_Factor__c = 0.0208, Is_Active__c = true
    ));
    conversions.add(new UOM_Conversion__c(
    Product__c = prodMap.get('FF-SNK-001'),
        From_UOM__c = uomMap.get('CSE'), To_UOM__c = uomMap.get('BOX'),
        Conversion_Factor__c = 10, Inverse_Conversion_Factor__c = 0.1, Is_Active__c = true
    ));
}

// Biscuits: 1 BOX = 24 PCS
if (prodMap.containsKey('FF-BIS-001')) {
    conversions.add(new UOM_Conversion__c(
    Product__c = prodMap.get('FF-BIS-001'),
        From_UOM__c = uomMap.get('BOX'), To_UOM__c = uomMap.get('PCS'),
        Conversion_Factor__c = 24, Inverse_Conversion_Factor__c = 0.0417, Is_Active__c = true
    ));
}

// Beverages: 1 BOX = 12 PCS
if (prodMap.containsKey('FF-TEA-001')) {
    conversions.add(new UOM_Conversion__c(
    Product__c = prodMap.get('FF-TEA-001'),
        From_UOM__c = uomMap.get('BOX'), To_UOM__c = uomMap.get('PCS'),
        Conversion_Factor__c = 12, Inverse_Conversion_Factor__c = 0.0833, Is_Active__c = true
    ));
}

// Generic BOX = 12 PCS (default for products without specific conversion)
conversions.add(new UOM_Conversion__c(
From_UOM__c = uomMap.get('BOX'), To_UOM__c = uomMap.get('PCS'),
    Conversion_Factor__c = 12, Inverse_Conversion_Factor__c = 0.0833, Is_Active__c = true
));
conversions.add(new UOM_Conversion__c(
From_UOM__c = uomMap.get('CSE'), To_UOM__c = uomMap.get('BOX'),
    Conversion_Factor__c = 10, Inverse_Conversion_Factor__c = 0.1, Is_Active__c = true
));

insert conversions;

System.debug('════════════════════════════════════════════');
System.debug('UOM Setup Complete:');
System.debug('  UOM Records: ' + uoms.size());
System.debug('  UOM Conversions: ' + conversions.size());
System.debug('════════════════════════════════════════════');
