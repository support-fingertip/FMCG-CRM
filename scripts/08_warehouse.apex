// Script 08: Warehouses + Warehouse Stock
// Run: sf apex run -f scripts/08_warehouse.apex
// Prerequisite: 01_company_hierarchy.apex, 04_products.apex, 05_batch_master.apex

// Clean up (delete stock children first, then warehouses)
delete [SELECT Id FROM Warehouse_Stock__c];
delete [SELECT Id FROM Warehouse__c];
System.debug('Cleaned up Warehouse__c and Warehouse_Stock__c');

Map<String, Id> hierMap = new Map<String, Id>();
for (Company_Hierarchy__c ch : [SELECT Id, Code__c FROM Company_Hierarchy__c WHERE Level__c = 'Region']) {
    hierMap.put(ch.Code__c, ch.Id);
}

// Warehouse codes: alphanumeric only (validation: ^[A-Za-z0-9]{3,20}$)
List<Warehouse__c> warehouses = new List<Warehouse__c>{
    new Warehouse__c(
        Name = 'Central Warehouse Mumbai',
        Warehouse_Code__c = 'WHMUM01',
        Warehouse_Type__c = 'Central',
        Address__c = 'Plot 45, MIDC Bhiwandi',
        City__c = 'Mumbai',
        State__c = 'Maharashtra',
        Pincode__c = '421302',
        Company_Hierarchy__c = hierMap.get('WEST'),
        Storage_Capacity__c = 50000,
        Is_Active__c = true
    ),
    new Warehouse__c(
        Name = 'Regional Warehouse Delhi',
        Warehouse_Code__c = 'WHDEL01',
        Warehouse_Type__c = 'Regional',
        Address__c = 'Sector 63, Noida',
        City__c = 'New Delhi',
        State__c = 'Delhi',
        Pincode__c = '201301',
        Company_Hierarchy__c = hierMap.get('NORTH'),
        Storage_Capacity__c = 30000,
        Is_Active__c = true
    ),
    new Warehouse__c(
        Name = 'Regional Warehouse Bengaluru',
        Warehouse_Code__c = 'WHBLR01',
        Warehouse_Type__c = 'Regional',
        Address__c = 'Peenya Industrial Area Phase 2',
        City__c = 'Bengaluru',
        State__c = 'Karnataka',
        Pincode__c = '560058',
        Company_Hierarchy__c = hierMap.get('SOUTH'),
        Storage_Capacity__c = 25000,
        Is_Active__c = true
    ),
    new Warehouse__c(
        Name = 'Depot Kolkata',
        Warehouse_Code__c = 'WHKOL01',
        Warehouse_Type__c = 'Depot',
        Address__c = 'Howrah Industrial Park',
        City__c = 'Kolkata',
        State__c = 'West Bengal',
        Pincode__c = '711101',
        Company_Hierarchy__c = hierMap.get('EAST'),
        Storage_Capacity__c = 15000,
        Is_Active__c = true
    ),
    new Warehouse__c(
        Name = 'C&F Ahmedabad',
        Warehouse_Code__c = 'WHAHM01',
        Warehouse_Type__c = 'C&F',
        Address__c = 'Sanand GIDC',
        City__c = 'Ahmedabad',
        State__c = 'Gujarat',
        Pincode__c = '382110',
        Company_Hierarchy__c = hierMap.get('WEST'),
        Storage_Capacity__c = 20000,
        Is_Active__c = true
    )
};

insert warehouses;
System.debug('Inserted warehouses: ' + warehouses.size());

// Map warehouses by code
Map<String, Id> whMap = new Map<String, Id>();
for (Warehouse__c w : warehouses) {
    whMap.put(w.Warehouse_Code__c, w.Id);
}

// ════════════════════════════════════════════════════════════
// WAREHOUSE STOCK — stock for products across warehouses
// ════════════════════════════════════════════════════════════

// Fetch products
List<Product_Extension__c> products = [
    SELECT Id, SKU_Code__c, Name, Reorder_Level__c, Reorder_Quantity__c
    FROM Product_Extension__c
    WHERE Is_Active__c = true AND SKU_Code__c LIKE 'FF-%'
    ORDER BY SKU_Code__c
];

// Fetch latest batch per product (for batch-level stock)
Map<Id, Batch_Master__c> latestBatchByProduct = new Map<Id, Batch_Master__c>();
for (Batch_Master__c b : [
    SELECT Id, Product_Ext__c, Batch_Number__c, Expiry_Date__c
    FROM Batch_Master__c
    WHERE Status__c = 'Active'
    ORDER BY Manufacturing_Date__c DESC
]) {
    if (!latestBatchByProduct.containsKey(b.Product_Ext__c)) {
        latestBatchByProduct.put(b.Product_Ext__c, b);
    }
}

List<Warehouse_Stock__c> stockRecords = new List<Warehouse_Stock__c>();

// Central warehouse (Mumbai) — all 30 products, high stock
for (Product_Extension__c p : products) {
    Decimal reorderLevel = (p.Reorder_Level__c != null) ? p.Reorder_Level__c : 500;
    Decimal reorderQty = (p.Reorder_Quantity__c != null) ? p.Reorder_Quantity__c : 2000;
    Batch_Master__c batch = latestBatchByProduct.get(p.Id);

    stockRecords.add(new Warehouse_Stock__c(
        Warehouse__c = whMap.get('WHMUM01'),
        Product_Ext__c = p.Id,
        Batch_Master__c = batch != null ? batch.Id : null,
        Batch_Number__c = batch != null ? batch.Batch_Number__c : null,
        Expiry_Date__c = batch != null ? batch.Expiry_Date__c : null,
        Qty_On_Hand__c = reorderQty * 2,
        Qty_Reserved__c = (reorderQty * 0.1).intValue(),
        Qty_Damaged__c = (Math.random() * 20).intValue(),
        Min_Stock_Level__c = reorderLevel,
        Max_Stock_Level__c = reorderQty * 3,
        Last_Transaction_Date__c = Date.today().addDays(-1)
    ));
}

// Regional warehouses — top 15 products each, moderate stock
List<String> regionalCodes = new List<String>{'WHDEL01', 'WHBLR01'};
Integer prodIdx = 0;
for (String whCode : regionalCodes) {
    for (Integer i = 0; i < Math.min(15, products.size()); i++) {
        Product_Extension__c p = products[i];
        Decimal reorderLevel = (p.Reorder_Level__c != null) ? p.Reorder_Level__c : 500;
        Decimal reorderQty = (p.Reorder_Quantity__c != null) ? p.Reorder_Quantity__c : 2000;
        Batch_Master__c batch = latestBatchByProduct.get(p.Id);

        stockRecords.add(new Warehouse_Stock__c(
            Warehouse__c = whMap.get(whCode),
            Product_Ext__c = p.Id,
            Batch_Master__c = batch != null ? batch.Id : null,
            Batch_Number__c = batch != null ? batch.Batch_Number__c : null,
            Expiry_Date__c = batch != null ? batch.Expiry_Date__c : null,
            Qty_On_Hand__c = reorderQty,
            Qty_Reserved__c = (reorderQty * 0.05).intValue(),
            Qty_Damaged__c = 0,
            Min_Stock_Level__c = reorderLevel,
            Max_Stock_Level__c = reorderQty * 2,
            Last_Transaction_Date__c = Date.today().addDays(-2)
        ));
    }
}

// Depot Kolkata — top 10 products, lower stock (some below reorder level)
for (Integer i = 0; i < Math.min(10, products.size()); i++) {
    Product_Extension__c p = products[i];
    Decimal reorderLevel = (p.Reorder_Level__c != null) ? p.Reorder_Level__c : 500;
    Batch_Master__c batch = latestBatchByProduct.get(p.Id);
    // First 3 products: low stock (below reorder level) to test low-stock alerts
    Decimal onHand = (i < 3) ? (reorderLevel * 0.3).intValue() : (reorderLevel * 2);

    stockRecords.add(new Warehouse_Stock__c(
        Warehouse__c = whMap.get('WHKOL01'),
        Product_Ext__c = p.Id,
        Batch_Master__c = batch != null ? batch.Id : null,
        Batch_Number__c = batch != null ? batch.Batch_Number__c : null,
        Expiry_Date__c = batch != null ? batch.Expiry_Date__c : null,
        Qty_On_Hand__c = onHand,
        Qty_Reserved__c = 0,
        Qty_Damaged__c = (i < 3) ? 5 : 0,
        Min_Stock_Level__c = reorderLevel,
        Max_Stock_Level__c = reorderLevel * 3,
        Last_Transaction_Date__c = Date.today().addDays(-5)
    ));
}

// C&F Ahmedabad — top 8 products, 2 with zero stock
for (Integer i = 0; i < Math.min(8, products.size()); i++) {
    Product_Extension__c p = products[i];
    Decimal reorderLevel = (p.Reorder_Level__c != null) ? p.Reorder_Level__c : 500;
    Batch_Master__c batch = latestBatchByProduct.get(p.Id);
    // Products 6-7: zero stock to test out-of-stock alerts
    Decimal onHand = (i >= 6) ? 0 : (reorderLevel * 1.5).intValue();

    stockRecords.add(new Warehouse_Stock__c(
        Warehouse__c = whMap.get('WHAHM01'),
        Product_Ext__c = p.Id,
        Batch_Master__c = batch != null ? batch.Id : null,
        Batch_Number__c = batch != null ? batch.Batch_Number__c : null,
        Expiry_Date__c = batch != null ? batch.Expiry_Date__c : null,
        Qty_On_Hand__c = onHand,
        Qty_Reserved__c = 0,
        Qty_Damaged__c = 0,
        Min_Stock_Level__c = reorderLevel,
        Max_Stock_Level__c = reorderLevel * 2,
        Last_Transaction_Date__c = Date.today().addDays(-3)
    ));
}

insert stockRecords;

// Summary
Integer lowStockCount = 0;
Integer zeroStockCount = 0;
for (Warehouse_Stock__c ws : stockRecords) {
    if (ws.Qty_On_Hand__c == 0) zeroStockCount++;
    else if (ws.Qty_On_Hand__c <= ws.Min_Stock_Level__c) lowStockCount++;
}

System.debug('');
System.debug('═══════════════════════════════════════════');
System.debug('Warehouse Setup Complete:');
System.debug('  Warehouses:     ' + warehouses.size());
System.debug('  Stock Records:  ' + stockRecords.size());
System.debug('  Low Stock:      ' + lowStockCount);
System.debug('  Zero Stock:     ' + zeroStockCount);
System.debug('');
System.debug('  WHMUM01 (Central):  30 products, full stock');
System.debug('  WHDEL01 (Regional): 15 products, moderate');
System.debug('  WHBLR01 (Regional): 15 products, moderate');
System.debug('  WHKOL01 (Depot):    10 products, 3 low stock');
System.debug('  WHAHM01 (C&F):      8 products, 2 zero stock');
System.debug('═══════════════════════════════════════════');
