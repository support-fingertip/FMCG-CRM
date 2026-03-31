// ============================================================
// Script 07: Price Lists — Multi-dimensional pricing
// Prerequisite: 04_products.apex, 02_territory_master.apex, 09_accounts.apex
// Run: sf apex run --file scripts/07_price_list.apex
//
// Creates:
//   1. Standard pricing (GT/MT/E-Commerce channels, all products)
//   2. Territory-specific pricing (Delhi, Mumbai get different rates)
//   3. Category-level pricing (Beverages category discount)
//   4. Customer-specific pricing (key account special prices)
//   5. Volume-based pricing (min qty discounts)
// ============================================================

delete [SELECT Id FROM Price_Change_Log__c];
delete [SELECT Id FROM Price_List__c];

// Load products
Map<String, Product_Extension__c> prodMap = new Map<String, Product_Extension__c>();
for (Product_Extension__c p : [SELECT Id, SKU_Code__c, Name, MRP__c, Unit_Price__c, Product_Category__c FROM Product_Extension__c WHERE Is_Active__c = true]) {
    prodMap.put(p.SKU_Code__c, p);
}

// Load territories
Map<String, Id> terMap = new Map<String, Id>();
for (Territory_Master__c t : [SELECT Id, Territory_Code__c, Name FROM Territory_Master__c WHERE Is_Active__c = true]) {
    terMap.put(t.Territory_Code__c, t.Id);
}

// Load categories
Map<String, Id> catMap = new Map<String, Id>();
for (Product_Category__c pc : [SELECT Id, Category_Code__c FROM Product_Category__c WHERE Is_Active__c = true]) {
    catMap.put(pc.Category_Code__c, pc.Id);
}

// Load key accounts (first 3 for customer-specific pricing)
List<Account> keyAccounts = [SELECT Id, Name FROM Account WHERE Type = 'Distributor' AND Is_Active__c = true ORDER BY Name LIMIT 3];

List<Price_List__c> prices = new List<Price_List__c>();
Date effectiveFrom = Date.today().addMonths(-6);

// ═══════════════════════════════════════════════════════════
// 1. STANDARD PRICES (all products × 3 channels)
// ═══════════════════════════════════════════════════════════

for (String sku : prodMap.keySet()) {
    Product_Extension__c p = prodMap.get(sku);
    Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;

    // GT Channel — Retailer Price (70% of MRP)
    prices.add(new Price_List__c(
        Name = 'STD-GT-' + sku,
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
        Name = 'STD-MT-' + sku,
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
        Name = 'STD-ECOM-' + sku,
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

System.debug('Standard prices: ' + prices.size());

// ═══════════════════════════════════════════════════════════
// 2. TERRITORY-SPECIFIC PRICES (Delhi gets 5% premium, Mumbai 3% discount)
// ═══════════════════════════════════════════════════════════

Id delhiTer = terMap.get('TER-DEL-001');
Id mumbaiTer = terMap.get('TER-MUM-001');

if (delhiTer != null) {
    for (String sku : prodMap.keySet()) {
        Product_Extension__c p = prodMap.get(sku);
        Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;

        prices.add(new Price_List__c(
            Name = 'DEL-GT-' + sku,
            Product_Ext__c = p.Id,
            Price_Type__c = 'Retailer Price',
            Unit_Price__c = (mrp * 0.735).setScale(2), // 5% premium over standard GT
            Channel__c = 'GT',
            Territory__c = delhiTer,
            Effective_From__c = effectiveFrom,
            Is_Active__c = true,
            Status__c = 'Approved',
            Priority__c = 60  // Higher priority (lower number) than standard
        ));
    }
}

if (mumbaiTer != null) {
    for (String sku : prodMap.keySet()) {
        Product_Extension__c p = prodMap.get(sku);
        Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;

        prices.add(new Price_List__c(
            Name = 'MUM-GT-' + sku,
            Product_Ext__c = p.Id,
            Price_Type__c = 'Retailer Price',
            Unit_Price__c = (mrp * 0.679).setScale(2), // 3% discount over standard GT
            Channel__c = 'GT',
            Territory__c = mumbaiTer,
            Effective_From__c = effectiveFrom,
            Is_Active__c = true,
            Status__c = 'Approved',
            Priority__c = 60
        ));
    }
}

System.debug('Territory prices added');

// ═══════════════════════════════════════════════════════════
// 3. CATEGORY-LEVEL PRICING (Beverages category 5% extra discount)
// ═══════════════════════════════════════════════════════════

Id beverageCat = catMap.get('CAT-BEV');
if (beverageCat != null) {
    prices.add(new Price_List__c(
        Name = 'CAT-BEV-GT-DISCOUNT',
        Category__c = beverageCat,
        Price_Type__c = 'Retailer Price',
        Unit_Price__c = 0, // Category-level — individual product prices override
        Channel__c = 'GT',
        Effective_From__c = effectiveFrom,
        Is_Active__c = true,
        Status__c = 'Approved',
        Priority__c = 60
    ));
}

// ═══════════════════════════════════════════════════════════
// 4. CUSTOMER-SPECIFIC PRICING (Key accounts get special rates)
// ═══════════════════════════════════════════════════════════

if (!keyAccounts.isEmpty()) {
    Account keyAccount = keyAccounts[0];

    // Top 5 products at 55% of MRP for key distributor
    Integer count = 0;
    for (String sku : prodMap.keySet()) {
        if (count >= 5) break;
        Product_Extension__c p = prodMap.get(sku);
        Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;

        prices.add(new Price_List__c(
            Name = 'KEY-' + keyAccount.Name.left(10) + '-' + sku,
            Product_Ext__c = p.Id,
            Customer__c = keyAccount.Id,
            Price_Type__c = 'Distributor Price',
            Unit_Price__c = (mrp * 0.55).setScale(2),
            Channel__c = 'MT',
            Effective_From__c = effectiveFrom,
            Is_Active__c = true,
            Status__c = 'Approved',
            Priority__c = 10  // Highest priority — customer-specific wins
        ));
        count++;
    }
}

System.debug('Customer-specific prices added');

// ═══════════════════════════════════════════════════════════
// 5. VOLUME-BASED PRICING (Min qty discounts)
// ═══════════════════════════════════════════════════════════

// For snack products: order 100+ PCS = extra 5% off
for (String sku : new List<String>{'FF-SNK-001', 'FF-SNK-002', 'FF-SNK-003'}) {
    if (!prodMap.containsKey(sku)) continue;
    Product_Extension__c p = prodMap.get(sku);
    Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;

    prices.add(new Price_List__c(
        Name = 'VOL-100-' + sku,
        Product_Ext__c = p.Id,
        Price_Type__c = 'Retailer Price',
        Unit_Price__c = (mrp * 0.665).setScale(2), // 5% extra discount on bulk
        Channel__c = 'GT',
        Min_Qty__c = 100,
        Effective_From__c = effectiveFrom,
        Is_Active__c = true,
        Status__c = 'Approved',
        Priority__c = 40  // Higher priority than territory but lower than customer
    ));
}

System.debug('Volume-based prices added');

// ═══════════════════════════════════════════════════════════
// INSERT ALL
// ═══════════════════════════════════════════════════════════

insert prices;

System.debug('');
System.debug('═══════════════════════════════════════════');
System.debug('Price List Setup Complete:');
System.debug('  Total Price Records: ' + prices.size());
System.debug('  Standard (all products × 3 channels): ' + (prodMap.size() * 3));
System.debug('  Territory-specific (Delhi + Mumbai): ' + (delhiTer != null ? prodMap.size() : 0) + ' + ' + (mumbaiTer != null ? prodMap.size() : 0));
System.debug('  Customer-specific: ' + Math.min(5, prodMap.size()));
System.debug('  Volume-based: 3');
System.debug('');
System.debug('Priority Resolution (lower number = higher priority):');
System.debug('  10 = Customer-specific');
System.debug('  40 = Volume-based (min qty)');
System.debug('  60 = Territory-specific / Category-level');
System.debug('  99 = Standard (default)');
System.debug('═══════════════════════════════════════════');
