// ============================================================
// Script 11a: Priority Sell Configs (Must_Sell_Config__c)
// Prerequisite: 04_products.apex, 02_territory_master.apex
// Run: sf apex run --file scripts/11a_must_sell_config.apex
// ============================================================
// Creates Must Sell and Focused Sell configurations across
// territories, channels, and customer types.
// ============================================================

delete [SELECT Id FROM Must_Sell_Config__c];

// Fetch products by SKU
Map<String, Id> prodMap = new Map<String, Id>();
for (Product_Extension__c p : [SELECT Id, SKU_Code__c, Name FROM Product_Extension__c WHERE Is_Active__c = true]) {
    prodMap.put(p.SKU_Code__c, p.Id);
}
System.assert(!prodMap.isEmpty(), 'No products found. Run 04_products.apex first.');

// Fetch territories
Map<String, Id> terMap = new Map<String, Id>();
for (Territory_Master__c t : [SELECT Id, Territory_Code__c FROM Territory_Master__c WHERE Is_Active__c = true]) {
    terMap.put(t.Territory_Code__c, t.Id);
}

Date startDate = Date.today().addMonths(-1);
Date endDate = Date.today().addMonths(6);

List<Must_Sell_Config__c> configs = new List<Must_Sell_Config__c>();

// ═══════════════════════════════════════════════════════════
// NATIONAL MUST SELL — All territories, all channels
// Core products every outlet must stock
// ═══════════════════════════════════════════════════════════

// Snacks — flagship product (Must Sell, all channels)
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-SNK-001'),
    Classification__c = 'Must Sell',
    Min_Qty__c = 12,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// Biscuits — core range (Must Sell, all channels)
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-BIS-001'),
    Classification__c = 'Must Sell',
    Min_Qty__c = 12,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// Noodles — staple product (Must Sell, all channels)
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-NDL-001'),
    Classification__c = 'Must Sell',
    Min_Qty__c = 24,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// Toothpaste — personal care staple (Must Sell, all channels)
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-ORL-001'),
    Classification__c = 'Must Sell',
    Min_Qty__c = 6,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// Detergent — home care staple (Must Sell, all channels)
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-DET-001'),
    Classification__c = 'Must Sell',
    Min_Qty__c = 6,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// ═══════════════════════════════════════════════════════════
// NATIONAL FOCUSED SELL — Recommended across all territories
// Products to push but not mandatory
// ═══════════════════════════════════════════════════════════

// Premium Tea — focused sell nationally
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-TEA-001'),
    Classification__c = 'Focused Sell',
    Min_Qty__c = 6,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// Mango Juice — seasonal focused sell
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-JUC-001'),
    Classification__c = 'Focused Sell',
    Min_Qty__c = 6,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// Shampoo — focused sell
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-HAR-002'),
    Classification__c = 'Focused Sell',
    Min_Qty__c = 3,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// ═══════════════════════════════════════════════════════════
// GT CHANNEL — Must Sell for General Trade only
// ═══════════════════════════════════════════════════════════

// Tangy Chips — GT push product
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-SNK-002'),
    Classification__c = 'Must Sell',
    Channel__c = 'GT',
    Min_Qty__c = 12,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// Confectionery — GT counter display
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-CNF-001'),
    Classification__c = 'Focused Sell',
    Channel__c = 'GT',
    Min_Qty__c = 6,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// Cola — GT cooler must-have
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-SOD-001'),
    Classification__c = 'Must Sell',
    Channel__c = 'GT',
    Min_Qty__c = 12,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// ═══════════════════════════════════════════════════════════
// MT CHANNEL — Must Sell for Modern Trade
// ═══════════════════════════════════════════════════════════

// Full snack range for MT shelves
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-SNK-003'),
    Classification__c = 'Must Sell',
    Channel__c = 'MT',
    Min_Qty__c = 24,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// Premium biscuits for MT
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-BIS-002'),
    Classification__c = 'Must Sell',
    Channel__c = 'MT',
    Min_Qty__c = 12,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// Full juice range for MT
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-JUC-002'),
    Classification__c = 'Must Sell',
    Channel__c = 'MT',
    Min_Qty__c = 12,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// Face wash for MT personal care aisle
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-SKN-001'),
    Classification__c = 'Focused Sell',
    Channel__c = 'MT',
    Min_Qty__c = 6,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// ═══════════════════════════════════════════════════════════
// TERRITORY-SPECIFIC — Delhi (GT channel, Grocery outlets)
// ═══════════════════════════════════════════════════════════

if (terMap.containsKey('TER-DEL-001')) {
    // Instant Coffee — high demand in Delhi winters
    configs.add(new Must_Sell_Config__c(
        Product_Ext__c = prodMap.get('FF-TEA-002'),
        Classification__c = 'Must Sell',
        Territory__c = terMap.get('TER-DEL-001'),
        Channel__c = 'GT',
        Customer_Type__c = 'Grocery',
        Min_Qty__c = 6,
        Is_Active__c = true,
        Start_Date__c = startDate,
        End_Date__c = endDate
    ));

    // Chocolate Biscuits — Delhi focused sell
    configs.add(new Must_Sell_Config__c(
        Product_Ext__c = prodMap.get('FF-BIS-003'),
        Classification__c = 'Focused Sell',
        Territory__c = terMap.get('TER-DEL-001'),
        Channel__c = 'GT',
        Min_Qty__c = 6,
        Is_Active__c = true,
        Start_Date__c = startDate,
        End_Date__c = endDate
    ));
}

// ═══════════════════════════════════════════════════════════
// TERRITORY-SPECIFIC — Mumbai (GT channel)
// ═══════════════════════════════════════════════════════════

if (terMap.containsKey('TER-MUM-001')) {
    // Hair Oil — high demand in Mumbai
    configs.add(new Must_Sell_Config__c(
        Product_Ext__c = prodMap.get('FF-HAR-001'),
        Classification__c = 'Must Sell',
        Territory__c = terMap.get('TER-MUM-001'),
        Channel__c = 'GT',
        Min_Qty__c = 6,
        Is_Active__c = true,
        Start_Date__c = startDate,
        End_Date__c = endDate
    ));

    // Floor Cleaner — Mumbai push
    configs.add(new Must_Sell_Config__c(
        Product_Ext__c = prodMap.get('FF-CLN-001'),
        Classification__c = 'Focused Sell',
        Territory__c = terMap.get('TER-MUM-001'),
        Min_Qty__c = 3,
        Is_Active__c = true,
        Start_Date__c = startDate,
        End_Date__c = endDate
    ));
}

// ═══════════════════════════════════════════════════════════
// TERRITORY-SPECIFIC — Bangalore (GT channel, Grocery)
// ═══════════════════════════════════════════════════════════

if (terMap.containsKey('TER-BLR-001')) {
    // Instant Coffee — strong market in Bangalore
    configs.add(new Must_Sell_Config__c(
        Product_Ext__c = prodMap.get('FF-TEA-002'),
        Classification__c = 'Must Sell',
        Territory__c = terMap.get('TER-BLR-001'),
        Channel__c = 'GT',
        Customer_Type__c = 'Grocery',
        Min_Qty__c = 12,
        Is_Active__c = true,
        Start_Date__c = startDate,
        End_Date__c = endDate
    ));

    // Noodles variant — Bangalore focused sell
    configs.add(new Must_Sell_Config__c(
        Product_Ext__c = prodMap.get('FF-NDL-002'),
        Classification__c = 'Focused Sell',
        Territory__c = terMap.get('TER-BLR-001'),
        Channel__c = 'GT',
        Min_Qty__c = 12,
        Is_Active__c = true,
        Start_Date__c = startDate,
        End_Date__c = endDate
    ));
}

// ═══════════════════════════════════════════════════════════
// TERRITORY-SPECIFIC — Chennai (GT channel)
// ═══════════════════════════════════════════════════════════

if (terMap.containsKey('TER-CHN-001')) {
    // Hair Oil — strong demand in Chennai
    configs.add(new Must_Sell_Config__c(
        Product_Ext__c = prodMap.get('FF-HAR-001'),
        Classification__c = 'Must Sell',
        Territory__c = terMap.get('TER-CHN-001'),
        Channel__c = 'GT',
        Min_Qty__c = 6,
        Is_Active__c = true,
        Start_Date__c = startDate,
        End_Date__c = endDate
    ));

    // Herbal Toothpaste — Chennai market preference
    configs.add(new Must_Sell_Config__c(
        Product_Ext__c = prodMap.get('FF-ORL-002'),
        Classification__c = 'Focused Sell',
        Territory__c = terMap.get('TER-CHN-001'),
        Customer_Type__c = 'Grocery',
        Min_Qty__c = 6,
        Is_Active__c = true,
        Start_Date__c = startDate,
        End_Date__c = endDate
    ));
}

// ═══════════════════════════════════════════════════════════
// CUSTOMER TYPE SPECIFIC — Grocery outlets
// (Customer_Type__c matches Account.Outlet_Type__c picklist)
// ═══════════════════════════════════════════════════════════

// Dairy must-have for grocery outlets
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-DRY-001'),
    Classification__c = 'Must Sell',
    Customer_Type__c = 'Grocery',
    Min_Qty__c = 6,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// Face Wash — grocery personal care section
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-SKN-001'),
    Classification__c = 'Focused Sell',
    Customer_Type__c = 'Grocery',
    Min_Qty__c = 3,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// ═══════════════════════════════════════════════════════════
// CUSTOMER TYPE SPECIFIC — General Store outlets
// ═══════════════════════════════════════════════════════════

// Confectionery — counter display for general stores
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-CNF-002'),
    Classification__c = 'Must Sell',
    Customer_Type__c = 'General Store',
    Min_Qty__c = 6,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// Glass Cleaner — general store home care
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-CLN-002'),
    Classification__c = 'Focused Sell',
    Customer_Type__c = 'General Store',
    Min_Qty__c = 3,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// ═══════════════════════════════════════════════════════════
// E-COMMERCE CHANNEL — Focused sell for online
// ═══════════════════════════════════════════════════════════

// Detergent combo pack — e-commerce push
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-DET-003'),
    Classification__c = 'Focused Sell',
    Channel__c = 'E-Commerce',
    Min_Qty__c = 1,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

// Dish Wash — e-commerce bundle push
configs.add(new Must_Sell_Config__c(
    Product_Ext__c = prodMap.get('FF-DET-002'),
    Classification__c = 'Focused Sell',
    Channel__c = 'E-Commerce',
    Min_Qty__c = 1,
    Is_Active__c = true,
    Start_Date__c = startDate,
    End_Date__c = endDate
));

insert configs;

// Count by classification
Integer mustSellCount = 0;
Integer focusedSellCount = 0;
Integer nationalCount = 0;
Integer territoryCount = 0;
Integer channelCount = 0;
for (Must_Sell_Config__c c : configs) {
    if (c.Classification__c == 'Must Sell') mustSellCount++;
    else focusedSellCount++;
    if (c.Territory__c == null && c.Channel__c == null && c.Customer_Type__c == null) nationalCount++;
    if (c.Territory__c != null) territoryCount++;
    if (c.Channel__c != null) channelCount++;
}

System.debug('');
System.debug('═══════════════════════════════════════════');
System.debug('Priority Sell Config Complete: ' + configs.size() + ' records');
System.debug('  Must Sell:     ' + mustSellCount);
System.debug('  Focused Sell:  ' + focusedSellCount);
System.debug('  National:      ' + nationalCount);
System.debug('  Territory:     ' + territoryCount);
System.debug('  Channel:       ' + channelCount);
System.debug('═══════════════════════════════════════════');
