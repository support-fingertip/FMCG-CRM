// Script 04: Products (Product_Extension__c) - Complete product master
// Run: sf apex run -f scripts/04_products.apex
// Prerequisite: 03_product_category.apex, UOM__c records must exist
// Creates 30 products across all categories with full field data

// Fetch sub-categories by code
Map<String, Id> catMap = new Map<String, Id>();
for (Product_Category__c pc : [SELECT Id, Category_Code__c FROM Product_Category__c WHERE Level__c = 'Sub-Category']) {
    catMap.put(pc.Category_Code__c, pc.Id);
}

// Fetch UOM records for Base_UOM__c and Secondary_UOM__c lookups
Map<String, Id> uomMap = new Map<String, Id>();
for (UOM__c u : [SELECT Id, UOM_Code__c FROM UOM__c WHERE Is_Active__c = true]) {
    uomMap.put(u.UOM_Code__c, u.Id);
}

// Default UOMs
Id pcsUom = uomMap.get('PCS');   // Pieces
Id boxUom = uomMap.get('BOX');   // Box
Id cseUom = uomMap.get('CSE');   // Case
Id kgUom = uomMap.get('KG');     // Kilogram
Id ltrUom = uomMap.get('LTR');   // Litre
Id dozUom = uomMap.get('DOZ');   // Dozen

if (pcsUom == null) {
    System.debug('WARNING: UOM records not found. Run UOM seed script first or create PCS/BOX/CSE/KG UOM records.');
}

List<Product_Extension__c> products = new List<Product_Extension__c>();

// ── FOODS: Snacks (3 SKUs) ─────────────────────────────────────────────
products.add(new Product_Extension__c(
    Name = 'Crispy Masala Chips 150g', SKU_Code__c = 'FF-SNK-001', Brand__c = 'FreshFields',
    Product_Category__c = catMap.get('SUB-SNACK'), HSN_SAC_Code__c = '20052000',
    Weight__c = 150, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Piece',
    MRP__c = 30, Unit_Price__c = 21, GST_Rate__c = 12,
    Case_Size__c = 48, Min_Order_Qty__c = 12, Shelf_Life_Days__c = 180,
    Reorder_Level__c = 500, Reorder_Quantity__c = 2000,
    Barcode_EAN__c = '8901234560011', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Tangy Tomato Chips 150g', SKU_Code__c = 'FF-SNK-002', Brand__c = 'FreshFields',
    Product_Category__c = catMap.get('SUB-SNACK'), HSN_SAC_Code__c = '20052000',
    Weight__c = 150, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Piece',
    MRP__c = 30, Unit_Price__c = 21, GST_Rate__c = 12,
    Case_Size__c = 48, Min_Order_Qty__c = 12, Shelf_Life_Days__c = 180,
    Reorder_Level__c = 500, Reorder_Quantity__c = 2000,
    Barcode_EAN__c = '8901234560028', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Classic Salted Chips 75g', SKU_Code__c = 'FF-SNK-003', Brand__c = 'FreshFields',
    Product_Category__c = catMap.get('SUB-SNACK'), HSN_SAC_Code__c = '20052000',
    Weight__c = 75, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Piece',
    MRP__c = 15, Unit_Price__c = 10.50, GST_Rate__c = 12,
    Case_Size__c = 96, Min_Order_Qty__c = 24, Shelf_Life_Days__c = 180,
    Reorder_Level__c = 1000, Reorder_Quantity__c = 4000,
    Barcode_EAN__c = '8901234560035', Is_Returnable__c = true, Is_Active__c = true
));

// ── FOODS: Biscuits (3 SKUs) ───────────────────────────────────────────
products.add(new Product_Extension__c(
    Name = 'Classic Cream Biscuits 200g', SKU_Code__c = 'FF-BIS-001', Brand__c = 'FreshFields',
    Product_Category__c = catMap.get('SUB-BISC'), HSN_SAC_Code__c = '19053200',
    Weight__c = 200, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Piece',
    MRP__c = 25, Unit_Price__c = 17.50, GST_Rate__c = 18,
    Case_Size__c = 60, Min_Order_Qty__c = 12, Shelf_Life_Days__c = 270,
    Reorder_Level__c = 400, Reorder_Quantity__c = 1500,
    Barcode_EAN__c = '8901234560042', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Digestive Wheat Biscuits 250g', SKU_Code__c = 'FF-BIS-002', Brand__c = 'FreshFields',
    Product_Category__c = catMap.get('SUB-BISC'), HSN_SAC_Code__c = '19053200',
    Weight__c = 250, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Piece',
    MRP__c = 35, Unit_Price__c = 24.50, GST_Rate__c = 18,
    Case_Size__c = 48, Min_Order_Qty__c = 12, Shelf_Life_Days__c = 270,
    Reorder_Level__c = 300, Reorder_Quantity__c = 1200,
    Barcode_EAN__c = '8901234560059', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Chocolate Cream Biscuits 150g', SKU_Code__c = 'FF-BIS-003', Brand__c = 'FreshFields',
    Product_Category__c = catMap.get('SUB-BISC'), HSN_SAC_Code__c = '19053200',
    Weight__c = 150, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Piece',
    MRP__c = 20, Unit_Price__c = 14, GST_Rate__c = 18,
    Case_Size__c = 72, Min_Order_Qty__c = 12, Shelf_Life_Days__c = 270,
    Reorder_Level__c = 600, Reorder_Quantity__c = 2400,
    Barcode_EAN__c = '8901234560066', Is_Returnable__c = true, Is_Active__c = true
));

// ── FOODS: Noodles (2 SKUs) ────────────────────────────────────────────
products.add(new Product_Extension__c(
    Name = 'Instant Noodles Masala 70g', SKU_Code__c = 'FF-NDL-001', Brand__c = 'FreshFields',
    Product_Category__c = catMap.get('SUB-NOODL'), HSN_SAC_Code__c = '19023010',
    Weight__c = 70, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Piece',
    MRP__c = 14, Unit_Price__c = 9.80, GST_Rate__c = 18,
    Case_Size__c = 120, Min_Order_Qty__c = 24, Shelf_Life_Days__c = 365,
    Reorder_Level__c = 1000, Reorder_Quantity__c = 5000,
    Barcode_EAN__c = '8901234560073', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Instant Noodles Chicken 70g', SKU_Code__c = 'FF-NDL-002', Brand__c = 'FreshFields',
    Product_Category__c = catMap.get('SUB-NOODL'), HSN_SAC_Code__c = '19023010',
    Weight__c = 70, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Piece',
    MRP__c = 16, Unit_Price__c = 11.20, GST_Rate__c = 18,
    Case_Size__c = 120, Min_Order_Qty__c = 24, Shelf_Life_Days__c = 365,
    Reorder_Level__c = 800, Reorder_Quantity__c = 3000,
    Barcode_EAN__c = '8901234560080', Is_Returnable__c = true, Is_Active__c = true
));

// ── FOODS: Dairy (2 SKUs) ──────────────────────────────────────────────
products.add(new Product_Extension__c(
    Name = 'Daily Fresh Milk 500ml', SKU_Code__c = 'FF-DRY-001', Brand__c = 'FreshFields Dairy',
    Product_Category__c = catMap.get('SUB-DAIRY'), HSN_SAC_Code__c = '04011000',
    Weight__c = 500, Weight_Unit__c = 'ml', Unit_of_Measure__c = 'Piece',
    MRP__c = 28, Unit_Price__c = 22.40, GST_Rate__c = 5,
    Case_Size__c = 20, Min_Order_Qty__c = 10, Shelf_Life_Days__c = 7,
    Reorder_Level__c = 200, Reorder_Quantity__c = 500,
    Barcode_EAN__c = '8901234560097', Is_Returnable__c = false, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Curd Cup 200g', SKU_Code__c = 'FF-DRY-002', Brand__c = 'FreshFields Dairy',
    Product_Category__c = catMap.get('SUB-DAIRY'), HSN_SAC_Code__c = '04031000',
    Weight__c = 200, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Piece',
    MRP__c = 20, Unit_Price__c = 16, GST_Rate__c = 5,
    Case_Size__c = 24, Min_Order_Qty__c = 12, Shelf_Life_Days__c = 14,
    Reorder_Level__c = 150, Reorder_Quantity__c = 400,
    Barcode_EAN__c = '8901234560103', Is_Returnable__c = false, Is_Active__c = true
));

// ── FOODS: Confectionery (2 SKUs) ──────────────────────────────────────
products.add(new Product_Extension__c(
    Name = 'Mango Toffees 200g', SKU_Code__c = 'FF-CNF-001', Brand__c = 'FreshFields',
    Product_Category__c = catMap.get('SUB-CONF'), HSN_SAC_Code__c = '17049090',
    Weight__c = 200, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Pack',
    MRP__c = 50, Unit_Price__c = 35, GST_Rate__c = 18,
    Case_Size__c = 60, Min_Order_Qty__c = 12, Shelf_Life_Days__c = 365,
    Reorder_Level__c = 300, Reorder_Quantity__c = 1200,
    Barcode_EAN__c = '8901234560110', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Fruit Drops 100g', SKU_Code__c = 'FF-CNF-002', Brand__c = 'FreshFields',
    Product_Category__c = catMap.get('SUB-CONF'), HSN_SAC_Code__c = '17049090',
    Weight__c = 100, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Pack',
    MRP__c = 30, Unit_Price__c = 21, GST_Rate__c = 18,
    Case_Size__c = 80, Min_Order_Qty__c = 24, Shelf_Life_Days__c = 365,
    Reorder_Level__c = 500, Reorder_Quantity__c = 2000,
    Barcode_EAN__c = '8901234560127', Is_Returnable__c = true, Is_Active__c = true
));

// ── BEVERAGES: Juices (3 SKUs) ─────────────────────────────────────────
products.add(new Product_Extension__c(
    Name = 'Fresh Mango Juice 1L', SKU_Code__c = 'FF-JUC-001', Brand__c = 'FreshFields Beverages',
    Product_Category__c = catMap.get('SUB-JUICE'), HSN_SAC_Code__c = '20098990',
    Weight__c = 1000, Weight_Unit__c = 'ml', Unit_of_Measure__c = 'Piece',
    MRP__c = 120, Unit_Price__c = 84, GST_Rate__c = 12,
    Case_Size__c = 12, Min_Order_Qty__c = 6, Shelf_Life_Days__c = 270,
    Reorder_Level__c = 200, Reorder_Quantity__c = 600,
    Barcode_EAN__c = '8901234560134', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Mixed Fruit Juice 1L', SKU_Code__c = 'FF-JUC-002', Brand__c = 'FreshFields Beverages',
    Product_Category__c = catMap.get('SUB-JUICE'), HSN_SAC_Code__c = '20098990',
    Weight__c = 1000, Weight_Unit__c = 'ml', Unit_of_Measure__c = 'Piece',
    MRP__c = 110, Unit_Price__c = 77, GST_Rate__c = 12,
    Case_Size__c = 12, Min_Order_Qty__c = 6, Shelf_Life_Days__c = 270,
    Reorder_Level__c = 200, Reorder_Quantity__c = 600,
    Barcode_EAN__c = '8901234560141', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Orange Juice 200ml', SKU_Code__c = 'FF-JUC-003', Brand__c = 'FreshFields Beverages',
    Product_Category__c = catMap.get('SUB-JUICE'), HSN_SAC_Code__c = '20098990',
    Weight__c = 200, Weight_Unit__c = 'ml', Unit_of_Measure__c = 'Piece',
    MRP__c = 25, Unit_Price__c = 17.50, GST_Rate__c = 12,
    Case_Size__c = 36, Min_Order_Qty__c = 12, Shelf_Life_Days__c = 180,
    Reorder_Level__c = 400, Reorder_Quantity__c = 1200,
    Barcode_EAN__c = '8901234560158', Is_Returnable__c = true, Is_Active__c = true
));

// ── BEVERAGES: Soft Drinks (2 SKUs) ────────────────────────────────────
products.add(new Product_Extension__c(
    Name = 'Cola Fizz 300ml', SKU_Code__c = 'FF-SOD-001', Brand__c = 'FreshFields Beverages',
    Product_Category__c = catMap.get('SUB-SODA'), HSN_SAC_Code__c = '22021010',
    Weight__c = 300, Weight_Unit__c = 'ml', Unit_of_Measure__c = 'Piece',
    MRP__c = 20, Unit_Price__c = 14, GST_Rate__c = 12,
    Case_Size__c = 24, Min_Order_Qty__c = 24, Shelf_Life_Days__c = 270,
    Reorder_Level__c = 500, Reorder_Quantity__c = 2000,
    Barcode_EAN__c = '8901234560165', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Lemon Soda 300ml', SKU_Code__c = 'FF-SOD-002', Brand__c = 'FreshFields Beverages',
    Product_Category__c = catMap.get('SUB-SODA'), HSN_SAC_Code__c = '22021010',
    Weight__c = 300, Weight_Unit__c = 'ml', Unit_of_Measure__c = 'Piece',
    MRP__c = 20, Unit_Price__c = 14, GST_Rate__c = 12,
    Case_Size__c = 24, Min_Order_Qty__c = 24, Shelf_Life_Days__c = 270,
    Reorder_Level__c = 500, Reorder_Quantity__c = 2000,
    Barcode_EAN__c = '8901234560172', Is_Returnable__c = true, Is_Active__c = true
));

// ── BEVERAGES: Tea & Coffee (2 SKUs) ───────────────────────────────────
products.add(new Product_Extension__c(
    Name = 'Premium Assam Tea 250g', SKU_Code__c = 'FF-TEA-001', Brand__c = 'FreshFields',
    Product_Category__c = catMap.get('SUB-TEA'), HSN_SAC_Code__c = '09021000',
    Weight__c = 250, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Pack',
    MRP__c = 180, Unit_Price__c = 126, GST_Rate__c = 5,
    Case_Size__c = 24, Min_Order_Qty__c = 6, Shelf_Life_Days__c = 545,
    Reorder_Level__c = 200, Reorder_Quantity__c = 600,
    Barcode_EAN__c = '8901234560189', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Instant Coffee 50g', SKU_Code__c = 'FF-TEA-002', Brand__c = 'FreshFields',
    Product_Category__c = catMap.get('SUB-TEA'), HSN_SAC_Code__c = '09021000',
    Weight__c = 50, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Piece',
    MRP__c = 120, Unit_Price__c = 84, GST_Rate__c = 5,
    Case_Size__c = 36, Min_Order_Qty__c = 6, Shelf_Life_Days__c = 545,
    Reorder_Level__c = 150, Reorder_Quantity__c = 500,
    Barcode_EAN__c = '8901234560196', Is_Returnable__c = true, Is_Active__c = true
));

// ── PERSONAL CARE: Hair Care (2 SKUs) ──────────────────────────────────
products.add(new Product_Extension__c(
    Name = 'Coconut Hair Oil 200ml', SKU_Code__c = 'FF-HAR-001', Brand__c = 'FreshFields Care',
    Product_Category__c = catMap.get('SUB-HAIR'), HSN_SAC_Code__c = '33051000',
    Weight__c = 200, Weight_Unit__c = 'ml', Unit_of_Measure__c = 'Piece',
    MRP__c = 95, Unit_Price__c = 66.50, GST_Rate__c = 28,
    Case_Size__c = 36, Min_Order_Qty__c = 6, Shelf_Life_Days__c = 730,
    Reorder_Level__c = 200, Reorder_Quantity__c = 600,
    Barcode_EAN__c = '8901234560202', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Anti-Dandruff Shampoo 200ml', SKU_Code__c = 'FF-HAR-002', Brand__c = 'FreshFields Care',
    Product_Category__c = catMap.get('SUB-HAIR'), HSN_SAC_Code__c = '33051000',
    Weight__c = 200, Weight_Unit__c = 'ml', Unit_of_Measure__c = 'Piece',
    MRP__c = 175, Unit_Price__c = 122.50, GST_Rate__c = 28,
    Case_Size__c = 24, Min_Order_Qty__c = 6, Shelf_Life_Days__c = 730,
    Reorder_Level__c = 150, Reorder_Quantity__c = 500,
    Barcode_EAN__c = '8901234560219', Is_Returnable__c = true, Is_Active__c = true
));

// ── PERSONAL CARE: Skin Care (2 SKUs) ──────────────────────────────────
products.add(new Product_Extension__c(
    Name = 'Neem Face Wash 100ml', SKU_Code__c = 'FF-SKN-001', Brand__c = 'FreshFields Care',
    Product_Category__c = catMap.get('SUB-SKIN'), HSN_SAC_Code__c = '33049990',
    Weight__c = 100, Weight_Unit__c = 'ml', Unit_of_Measure__c = 'Piece',
    MRP__c = 85, Unit_Price__c = 59.50, GST_Rate__c = 28,
    Case_Size__c = 36, Min_Order_Qty__c = 6, Shelf_Life_Days__c = 730,
    Reorder_Level__c = 150, Reorder_Quantity__c = 500,
    Barcode_EAN__c = '8901234560226', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Aloe Moisturizer 100ml', SKU_Code__c = 'FF-SKN-002', Brand__c = 'FreshFields Care',
    Product_Category__c = catMap.get('SUB-SKIN'), HSN_SAC_Code__c = '33049990',
    Weight__c = 100, Weight_Unit__c = 'ml', Unit_of_Measure__c = 'Piece',
    MRP__c = 120, Unit_Price__c = 84, GST_Rate__c = 28,
    Case_Size__c = 36, Min_Order_Qty__c = 6, Shelf_Life_Days__c = 730,
    Reorder_Level__c = 150, Reorder_Quantity__c = 500,
    Barcode_EAN__c = '8901234560233', Is_Returnable__c = true, Is_Active__c = true
));

// ── PERSONAL CARE: Oral Care (2 SKUs) ──────────────────────────────────
products.add(new Product_Extension__c(
    Name = 'Fresh Mint Toothpaste 150g', SKU_Code__c = 'FF-ORL-001', Brand__c = 'FreshFields Care',
    Product_Category__c = catMap.get('SUB-ORAL'), HSN_SAC_Code__c = '33061000',
    Weight__c = 150, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Piece',
    MRP__c = 65, Unit_Price__c = 45.50, GST_Rate__c = 28,
    Case_Size__c = 48, Min_Order_Qty__c = 12, Shelf_Life_Days__c = 730,
    Reorder_Level__c = 300, Reorder_Quantity__c = 1000,
    Barcode_EAN__c = '8901234560240', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Herbal Toothpaste 100g', SKU_Code__c = 'FF-ORL-002', Brand__c = 'FreshFields Care',
    Product_Category__c = catMap.get('SUB-ORAL'), HSN_SAC_Code__c = '33061000',
    Weight__c = 100, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Piece',
    MRP__c = 55, Unit_Price__c = 38.50, GST_Rate__c = 28,
    Case_Size__c = 48, Min_Order_Qty__c = 12, Shelf_Life_Days__c = 730,
    Reorder_Level__c = 300, Reorder_Quantity__c = 1000,
    Barcode_EAN__c = '8901234560257', Is_Returnable__c = true, Is_Active__c = true
));

// ── HOME CARE: Detergents (3 SKUs) ─────────────────────────────────────
products.add(new Product_Extension__c(
    Name = 'Power Wash Detergent 1kg', SKU_Code__c = 'FF-DET-001', Brand__c = 'FreshFields Home',
    Product_Category__c = catMap.get('SUB-DET'), HSN_SAC_Code__c = '34022090',
    Weight__c = 1000, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Pack',
    MRP__c = 135, Unit_Price__c = 94.50, GST_Rate__c = 18,
    Case_Size__c = 12, Min_Order_Qty__c = 6, Shelf_Life_Days__c = 730,
    Reorder_Level__c = 200, Reorder_Quantity__c = 600,
    Barcode_EAN__c = '8901234560264', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Liquid Dish Wash 500ml', SKU_Code__c = 'FF-DET-002', Brand__c = 'FreshFields Home',
    Product_Category__c = catMap.get('SUB-DET'), HSN_SAC_Code__c = '34022090',
    Weight__c = 500, Weight_Unit__c = 'ml', Unit_of_Measure__c = 'Piece',
    MRP__c = 89, Unit_Price__c = 62.30, GST_Rate__c = 18,
    Case_Size__c = 24, Min_Order_Qty__c = 6, Shelf_Life_Days__c = 730,
    Reorder_Level__c = 200, Reorder_Quantity__c = 600,
    Barcode_EAN__c = '8901234560271', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Power Wash Detergent 500g', SKU_Code__c = 'FF-DET-003', Brand__c = 'FreshFields Home',
    Product_Category__c = catMap.get('SUB-DET'), HSN_SAC_Code__c = '34022090',
    Weight__c = 500, Weight_Unit__c = 'g', Unit_of_Measure__c = 'Pack',
    MRP__c = 72, Unit_Price__c = 50.40, GST_Rate__c = 18,
    Case_Size__c = 24, Min_Order_Qty__c = 6, Shelf_Life_Days__c = 730,
    Reorder_Level__c = 300, Reorder_Quantity__c = 1000,
    Barcode_EAN__c = '8901234560288', Is_Returnable__c = true, Is_Active__c = true
));

// ── HOME CARE: Surface Cleaners (2 SKUs) ───────────────────────────────
products.add(new Product_Extension__c(
    Name = 'Floor Cleaner Pine 500ml', SKU_Code__c = 'FF-CLN-001', Brand__c = 'FreshFields Home',
    Product_Category__c = catMap.get('SUB-CLEAN'), HSN_SAC_Code__c = '34022090',
    Weight__c = 500, Weight_Unit__c = 'ml', Unit_of_Measure__c = 'Piece',
    MRP__c = 99, Unit_Price__c = 69.30, GST_Rate__c = 18,
    Case_Size__c = 24, Min_Order_Qty__c = 6, Shelf_Life_Days__c = 730,
    Reorder_Level__c = 200, Reorder_Quantity__c = 600,
    Barcode_EAN__c = '8901234560295', Is_Returnable__c = true, Is_Active__c = true
));
products.add(new Product_Extension__c(
    Name = 'Glass Cleaner 250ml', SKU_Code__c = 'FF-CLN-002', Brand__c = 'FreshFields Home',
    Product_Category__c = catMap.get('SUB-CLEAN'), HSN_SAC_Code__c = '34022090',
    Weight__c = 250, Weight_Unit__c = 'ml', Unit_of_Measure__c = 'Piece',
    MRP__c = 65, Unit_Price__c = 45.50, GST_Rate__c = 18,
    Case_Size__c = 36, Min_Order_Qty__c = 6, Shelf_Life_Days__c = 730,
    Reorder_Level__c = 200, Reorder_Quantity__c = 600,
    Barcode_EAN__c = '8901234560301', Is_Returnable__c = true, Is_Active__c = true
));

insert products;

// ── Set Base_UOM__c, Secondary_UOM__c, Ordering_UOMs__c on all products ──
if (pcsUom != null) {
    List<Product_Extension__c> toUpdate = new List<Product_Extension__c>();
    for (Product_Extension__c p : products) {
        Product_Extension__c upd = new Product_Extension__c(Id = p.Id);

        // Most FMCG products: Base = PCS, Secondary = BOX or CSE
        if (p.Unit_of_Measure__c == 'Piece' || p.Unit_of_Measure__c == 'Pieces') {
            upd.Base_UOM__c = pcsUom;
            upd.Secondary_UOM__c = boxUom;
            upd.Ordering_UOMs__c = 'PCS,BOX,CSE';
        } else if (p.Unit_of_Measure__c == 'Kg' || p.Unit_of_Measure__c == 'kg') {
            upd.Base_UOM__c = kgUom;
            upd.Secondary_UOM__c = boxUom;
            upd.Ordering_UOMs__c = 'KG,BOX';
        } else if (p.Unit_of_Measure__c == 'Litre' || p.Unit_of_Measure__c == 'litre') {
            upd.Base_UOM__c = ltrUom;
            upd.Secondary_UOM__c = boxUom;
            upd.Ordering_UOMs__c = 'LTR,BOX';
        } else {
            // Default to PCS
            upd.Base_UOM__c = pcsUom;
            upd.Secondary_UOM__c = boxUom;
            upd.Ordering_UOMs__c = 'PCS,BOX,CSE';
        }

        toUpdate.add(upd);
    }
    update toUpdate;
    System.debug('Updated Base_UOM__c on ' + toUpdate.size() + ' products');
}

System.debug('Products setup complete. Total Product Extensions: ' + products.size());
