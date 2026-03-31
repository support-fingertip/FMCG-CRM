// ============================================================
// Script 07: Price Lists — All 8 priority levels
// Prerequisite: 04_products, 02_territory_master, 03_product_category, 09_accounts
// Priority is AUTO-CALCULATED by trigger based on populated dimensions
// Run: sf apex run --file scripts/07_price_list.apex
// ============================================================

delete [SELECT Id FROM Price_Change_Log__c];
delete [SELECT Id FROM Price_List__c];

// Load data
Map<String, Product_Extension__c> prodMap = new Map<String, Product_Extension__c>();
for (Product_Extension__c p : [SELECT Id, SKU_Code__c, MRP__c, Product_Category__c FROM Product_Extension__c WHERE Is_Active__c = true]) {
    prodMap.put(p.SKU_Code__c, p);
}

Map<String, Id> terMap = new Map<String, Id>();
for (Territory_Master__c t : [SELECT Id, Territory_Code__c FROM Territory_Master__c WHERE Is_Active__c = true]) {
    terMap.put(t.Territory_Code__c, t.Id);
}

Map<String, Id> catMap = new Map<String, Id>();
for (Product_Category__c pc : [SELECT Id, Category_Code__c FROM Product_Category__c WHERE Is_Active__c = true]) {
    catMap.put(pc.Category_Code__c, pc.Id);
}

List<Account> distAccounts = [SELECT Id, Name FROM Account WHERE Type = 'Distributor' AND Is_Active__c = true ORDER BY Name LIMIT 3];

Date fromDate = Date.today().addMonths(-6);
Date toDate = Date.today().addMonths(6);

// ═══════════════════════════════════════════════════════════
// 8th - BASE PRICE (no dimensions — lowest priority)
// ═══════════════════════════════════════════════════════════

List<Price_List__c> basePrices = new List<Price_List__c>();
for (Product_Extension__c p : prodMap.values()) {
    Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;
    basePrices.add(new Price_List__c(
        Name = 'BASE-' + p.SKU_Code__c,
        Product_Ext__c = p.Id,
        Price_Type__c = 'Retailer Price',
        Unit_Price__c = (mrp * 0.70).setScale(2),
        Effective_From__c = fromDate, Effective_To__c = toDate,
        Is_Active__c = true, Status__c = 'Approved'
    ));
}
insert basePrices;
System.debug('8th Base Prices: ' + basePrices.size());

// ═══════════════════════════════════════════════════════════
// 7th - CATEGORY WISE
// ═══════════════════════════════════════════════════════════

List<Price_List__c> catPrices = new List<Price_List__c>();
Id snackCat = catMap.get('SUB-SNACK');
Id biscuitCat = catMap.get('SUB-BISCUIT');
if (snackCat != null) {
    for (Product_Extension__c p : prodMap.values()) {
        if (p.Product_Category__c == snackCat) {
            Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;
            catPrices.add(new Price_List__c(
                Name = 'CAT-SNK-' + p.SKU_Code__c,
                Product_Ext__c = p.Id, Category__c = snackCat,
                Price_Type__c = 'Retailer Price',
                Unit_Price__c = (mrp * 0.65).setScale(2),
                Effective_From__c = fromDate, Effective_To__c = toDate,
                Is_Active__c = true, Status__c = 'Approved'
            ));
        }
    }
}
if (!catPrices.isEmpty()) { insert catPrices; System.debug('7th Category Prices: ' + catPrices.size()); }

// ═══════════════════════════════════════════════════════════
// 6th - CHANNEL WISE
// ═══════════════════════════════════════════════════════════

List<Price_List__c> chanPrices = new List<Price_List__c>();
for (Product_Extension__c p : prodMap.values()) {
    Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;
    chanPrices.add(new Price_List__c(
        Name = 'CHAN-MT-' + p.SKU_Code__c,
        Product_Ext__c = p.Id, Channel__c = 'MT',
        Price_Type__c = 'Distributor Price',
        Unit_Price__c = (mrp * 0.60).setScale(2),
        Effective_From__c = fromDate, Effective_To__c = toDate,
        Is_Active__c = true, Status__c = 'Approved'
    ));
    chanPrices.add(new Price_List__c(
        Name = 'CHAN-ECOM-' + p.SKU_Code__c,
        Product_Ext__c = p.Id, Channel__c = 'E-Commerce',
        Price_Type__c = 'MRP',
        Unit_Price__c = mrp,
        Effective_From__c = fromDate, Effective_To__c = toDate,
        Is_Active__c = true, Status__c = 'Approved'
    ));
}
insert chanPrices;
System.debug('6th Channel Prices: ' + chanPrices.size());

// ═══════════════════════════════════════════════════════════
// 5th - TERRITORY WISE (Delhi, Mumbai — 5 products each)
// ═══════════════════════════════════════════════════════════

List<Price_List__c> terrPrices = new List<Price_List__c>();
Id delhiId = terMap.get('TER-DEL-001');
Id mumbaiId = terMap.get('TER-MUM-001');
Integer tc = 0;
for (Product_Extension__c p : prodMap.values()) {
    if (tc >= 5) break;
    Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;
    if (delhiId != null) {
        terrPrices.add(new Price_List__c(
            Name = 'TER-DEL-' + p.SKU_Code__c,
            Product_Ext__c = p.Id, Territory__c = delhiId,
            Price_Type__c = 'Retailer Price',
            Unit_Price__c = (mrp * 0.735).setScale(2),
            Effective_From__c = fromDate, Effective_To__c = toDate,
            Is_Active__c = true, Status__c = 'Approved'
        ));
    }
    if (mumbaiId != null) {
        terrPrices.add(new Price_List__c(
            Name = 'TER-MUM-' + p.SKU_Code__c,
            Product_Ext__c = p.Id, Territory__c = mumbaiId,
            Price_Type__c = 'Retailer Price',
            Unit_Price__c = (mrp * 0.68).setScale(2),
            Effective_From__c = fromDate, Effective_To__c = toDate,
            Is_Active__c = true, Status__c = 'Approved'
        ));
    }
    tc++;
}
if (!terrPrices.isEmpty()) { insert terrPrices; System.debug('5th Territory Prices: ' + terrPrices.size()); }

// ═══════════════════════════════════════════════════════════
// 4th - CATEGORY + TERRITORY (Snack category in Delhi)
// ═══════════════════════════════════════════════════════════

List<Price_List__c> catTerrPrices = new List<Price_List__c>();
if (snackCat != null && delhiId != null) {
    Integer ct = 0;
    for (Product_Extension__c p : prodMap.values()) {
        if (ct >= 3) break;
        if (p.Product_Category__c == snackCat) {
            Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;
            catTerrPrices.add(new Price_List__c(
                Name = 'CATTER-SNK-DEL-' + p.SKU_Code__c,
                Product_Ext__c = p.Id, Category__c = snackCat, Territory__c = delhiId,
                Price_Type__c = 'Retailer Price',
                Unit_Price__c = (mrp * 0.62).setScale(2),
                Effective_From__c = fromDate, Effective_To__c = toDate,
                Is_Active__c = true, Status__c = 'Approved'
            ));
            ct++;
        }
    }
}
if (!catTerrPrices.isEmpty()) { insert catTerrPrices; System.debug('4th Cat+Terr Prices: ' + catTerrPrices.size()); }

// ═══════════════════════════════════════════════════════════
// 3rd - TERRITORY + CHANNEL (Delhi GT, Mumbai MT)
// ═══════════════════════════════════════════════════════════

List<Price_List__c> terrChanPrices = new List<Price_List__c>();
Integer tcc = 0;
for (Product_Extension__c p : prodMap.values()) {
    if (tcc >= 3) break;
    Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;
    if (delhiId != null) {
        terrChanPrices.add(new Price_List__c(
            Name = 'TERCHAN-DEL-GT-' + p.SKU_Code__c,
            Product_Ext__c = p.Id, Territory__c = delhiId, Channel__c = 'GT',
            Price_Type__c = 'Retailer Price',
            Unit_Price__c = (mrp * 0.72).setScale(2),
            Effective_From__c = fromDate, Effective_To__c = toDate,
            Is_Active__c = true, Status__c = 'Approved'
        ));
    }
    if (mumbaiId != null) {
        terrChanPrices.add(new Price_List__c(
            Name = 'TERCHAN-MUM-MT-' + p.SKU_Code__c,
            Product_Ext__c = p.Id, Territory__c = mumbaiId, Channel__c = 'MT',
            Price_Type__c = 'Distributor Price',
            Unit_Price__c = (mrp * 0.55).setScale(2),
            Effective_From__c = fromDate, Effective_To__c = toDate,
            Is_Active__c = true, Status__c = 'Approved'
        ));
    }
    tcc++;
}
if (!terrChanPrices.isEmpty()) { insert terrChanPrices; System.debug('3rd Terr+Chan Prices: ' + terrChanPrices.size()); }

// ═══════════════════════════════════════════════════════════
// 2nd - CATEGORY + TERRITORY + CHANNEL (Snacks in Delhi GT)
// ═══════════════════════════════════════════════════════════

List<Price_List__c> catTerrChanPrices = new List<Price_List__c>();
if (snackCat != null && delhiId != null) {
    Integer ctc = 0;
    for (Product_Extension__c p : prodMap.values()) {
        if (ctc >= 2) break;
        if (p.Product_Category__c == snackCat) {
            Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;
            catTerrChanPrices.add(new Price_List__c(
                Name = 'CTC-SNK-DEL-GT-' + p.SKU_Code__c,
                Product_Ext__c = p.Id, Category__c = snackCat, Territory__c = delhiId, Channel__c = 'GT',
                Price_Type__c = 'Retailer Price',
                Unit_Price__c = (mrp * 0.58).setScale(2),
                Effective_From__c = fromDate, Effective_To__c = toDate,
                Is_Active__c = true, Status__c = 'Approved'
            ));
            ctc++;
        }
    }
}
if (!catTerrChanPrices.isEmpty()) { insert catTerrChanPrices; System.debug('2nd Cat+Terr+Chan Prices: ' + catTerrChanPrices.size()); }

// ═══════════════════════════════════════════════════════════
// 1st - CUSTOMER WISE (key distributor — highest priority)
// ═══════════════════════════════════════════════════════════

List<Price_List__c> custPrices = new List<Price_List__c>();
if (!distAccounts.isEmpty()) {
    Account keyAcct = distAccounts[0];
    Integer cc = 0;
    for (Product_Extension__c p : prodMap.values()) {
        if (cc >= 5) break;
        Decimal mrp = p.MRP__c != null ? p.MRP__c : 100;
        custPrices.add(new Price_List__c(
            Name = 'CUST-' + keyAcct.Name.left(8) + '-' + p.SKU_Code__c,
            Product_Ext__c = p.Id, Customer__c = keyAcct.Id,
            Price_Type__c = 'Distributor Price',
            Unit_Price__c = (mrp * 0.50).setScale(2),
            Effective_From__c = fromDate, Effective_To__c = toDate,
            Is_Active__c = true, Status__c = 'Approved'
        ));
        cc++;
    }
}
if (!custPrices.isEmpty()) { insert custPrices; System.debug('1st Customer Prices: ' + custPrices.size()); }

// ═══════════════════════════════════════════════════════════

Integer total = basePrices.size() + catPrices.size() + chanPrices.size() + terrPrices.size() +
    catTerrPrices.size() + terrChanPrices.size() + catTerrChanPrices.size() + custPrices.size();

System.debug('');
System.debug('═══════════════════════════════════════════');
System.debug('Price List Setup Complete: ' + total + ' records');
System.debug('  1st Customer:        ' + custPrices.size());
System.debug('  2nd Cat+Terr+Chan:   ' + catTerrChanPrices.size());
System.debug('  3rd Terr+Chan:       ' + terrChanPrices.size());
System.debug('  4th Cat+Terr:        ' + catTerrPrices.size());
System.debug('  5th Territory:       ' + terrPrices.size());
System.debug('  6th Channel:         ' + chanPrices.size());
System.debug('  7th Category:        ' + catPrices.size());
System.debug('  8th Base:            ' + basePrices.size());
System.debug('═══════════════════════════════════════════');
