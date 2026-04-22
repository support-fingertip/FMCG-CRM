// ============================================================
// Script 20: Product Image URLs (Additive — safe to re-run)
// Assigns placeholder product images to all 30 seed products.
// Uses picsum.photos with fixed seed IDs for consistent images.
//
// Run via: sf apex run --file scripts/20_product_images.apex
// ============================================================

System.debug('═══════════════════════════════════════════');
System.debug('UPDATING PRODUCT IMAGES...');
System.debug('═══════════════════════════════════════════');

// Map SKU → image URL (200x200 product-style placeholders with fixed seeds)
Map<String, String> skuToImage = new Map<String, String>{
    // ── Foods: Snacks ──
    'FF-SNK-001' => 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=400&h=400&fit=crop',
    'FF-SNK-002' => 'https://images.unsplash.com/photo-1621447504864-d8686e12698c?w=400&h=400&fit=crop',
    'FF-SNK-003' => 'https://images.unsplash.com/photo-1613919113640-25732ec5e61f?w=400&h=400&fit=crop',

    // ── Foods: Biscuits ──
    'FF-BIS-001' => 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400&h=400&fit=crop',
    'FF-BIS-002' => 'https://images.unsplash.com/photo-1597733336794-12d05021d510?w=400&h=400&fit=crop',
    'FF-BIS-003' => 'https://images.unsplash.com/photo-1548365328-8c6db3220e4c?w=400&h=400&fit=crop',

    // ── Foods: Noodles ──
    'FF-NDL-001' => 'https://images.unsplash.com/photo-1612929633738-8fe44f7ec841?w=400&h=400&fit=crop',
    'FF-NDL-002' => 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400&h=400&fit=crop',

    // ── Foods: Dairy ──
    'FF-DRY-001' => 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=400&h=400&fit=crop',
    'FF-DRY-002' => 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400&h=400&fit=crop',

    // ── Foods: Confectionery ──
    'FF-CNF-001' => 'https://images.unsplash.com/photo-1582176604856-e824b4736522?w=400&h=400&fit=crop',
    'FF-CNF-002' => 'https://images.unsplash.com/photo-1581798269146-6b239f0e28c3?w=400&h=400&fit=crop',

    // ── Beverages: Juices ──
    'FF-JUC-001' => 'https://images.unsplash.com/photo-1546173159-315724a31696?w=400&h=400&fit=crop',
    'FF-JUC-002' => 'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&h=400&fit=crop',
    'FF-JUC-003' => 'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=400&h=400&fit=crop',

    // ── Beverages: Soft Drinks ──
    'FF-SOD-001' => 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=400&h=400&fit=crop',
    'FF-SOD-002' => 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=400&h=400&fit=crop',

    // ── Beverages: Tea & Coffee ──
    'FF-TEA-001' => 'https://images.unsplash.com/photo-1564890369478-c89ca6d9cde9?w=400&h=400&fit=crop',
    'FF-TEA-002' => 'https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=400&h=400&fit=crop',

    // ── Personal Care: Hair Care ──
    'FF-HAR-001' => 'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?w=400&h=400&fit=crop',
    'FF-HAR-002' => 'https://images.unsplash.com/photo-1631729371254-42c2892f0e6e?w=400&h=400&fit=crop',

    // ── Personal Care: Skin Care ──
    'FF-SKN-001' => 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=400&h=400&fit=crop',
    'FF-SKN-002' => 'https://images.unsplash.com/photo-1611930022073-b7a4ba5fcccd?w=400&h=400&fit=crop',

    // ── Personal Care: Oral Care ──
    'FF-ORL-001' => 'https://images.unsplash.com/photo-1559013616-3133700e7964?w=400&h=400&fit=crop',
    'FF-ORL-002' => 'https://images.unsplash.com/photo-1609840114035-3c981b782dfe?w=400&h=400&fit=crop',

    // ── Home Care: Detergents ──
    'FF-DET-001' => 'https://images.unsplash.com/photo-1582735689369-4fe89db7114c?w=400&h=400&fit=crop',
    'FF-DET-002' => 'https://images.unsplash.com/photo-1622398925373-3f91b1e275f5?w=400&h=400&fit=crop',
    'FF-DET-003' => 'https://images.unsplash.com/photo-1583947215259-38e31be8751f?w=400&h=400&fit=crop',

    // ── Home Care: Surface Cleaners ──
    'FF-CLN-001' => 'https://images.unsplash.com/photo-1585421514284-efb74c2b69ba?w=400&h=400&fit=crop',
    'FF-CLN-002' => 'https://images.unsplash.com/photo-1563453392212-326f5e854473?w=400&h=400&fit=crop'
};

// Also add images for the 22 ice cream products (Big brand)
Map<String, String> iceCreamImages = new Map<String, String>{
    'BIG-ICE-001' => 'https://images.unsplash.com/photo-1497034825429-c343d7c6a68f?w=400&h=400&fit=crop',
    'BIG-ICE-002' => 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&h=400&fit=crop',
    'BIG-ICE-003' => 'https://images.unsplash.com/photo-1570197571499-166b36435e9f?w=400&h=400&fit=crop',
    'BIG-ICE-004' => 'https://images.unsplash.com/photo-1633933358116-a27b902fad35?w=400&h=400&fit=crop',
    'BIG-ICE-005' => 'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?w=400&h=400&fit=crop',
    'BIG-ICE-006' => 'https://images.unsplash.com/photo-1560008581-09826d1de69e?w=400&h=400&fit=crop',
    'BIG-ICE-007' => 'https://images.unsplash.com/photo-1629385701021-fcd568a743e8?w=400&h=400&fit=crop',
    'BIG-ICE-008' => 'https://images.unsplash.com/photo-1580915411954-282cb1b0d780?w=400&h=400&fit=crop',
    'BIG-ICE-009' => 'https://images.unsplash.com/photo-1567206563064-6f60f40a2b57?w=400&h=400&fit=crop',
    'BIG-ICE-010' => 'https://images.unsplash.com/photo-1557142046-c704a3adf364?w=400&h=400&fit=crop',
    'BIG-ICE-011' => 'https://images.unsplash.com/photo-1576506295286-5cda18df43e7?w=400&h=400&fit=crop',
    'BIG-ICE-012' => 'https://images.unsplash.com/photo-1488900128323-21503983a07e?w=400&h=400&fit=crop',
    'BIG-ICE-013' => 'https://images.unsplash.com/photo-1579954115545-a95591f28bfc?w=400&h=400&fit=crop',
    'BIG-ICE-014' => 'https://images.unsplash.com/photo-1615478503562-ec2d8aa0a7d6?w=400&h=400&fit=crop',
    'BIG-ICE-015' => 'https://images.unsplash.com/photo-1632171927001-cf80403e8784?w=400&h=400&fit=crop',
    'BIG-ICE-016' => 'https://images.unsplash.com/photo-1505394033641-40c6ad1178d7?w=400&h=400&fit=crop',
    'BIG-ICE-017' => 'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=400&h=400&fit=crop',
    'BIG-ICE-018' => 'https://images.unsplash.com/photo-1587049016823-69ef9d68d9a4?w=400&h=400&fit=crop',
    'BIG-ICE-019' => 'https://images.unsplash.com/photo-1516559828984-fb3b99548b21?w=400&h=400&fit=crop',
    'BIG-ICE-020' => 'https://images.unsplash.com/photo-1590080875852-ba44e8eee0e7?w=400&h=400&fit=crop',
    'BIG-ICE-021' => 'https://images.unsplash.com/photo-1571506165871-ee72a35bc9d4?w=400&h=400&fit=crop',
    'BIG-ICE-022' => 'https://images.unsplash.com/photo-1535254973040-607b474cb50d?w=400&h=400&fit=crop'
};

skuToImage.putAll(iceCreamImages);

List<Product_Extension__c> toUpdate = new List<Product_Extension__c>();

for (Product_Extension__c p : [
    SELECT Id, SKU_Code__c, Product_Image_URL__c
    FROM Product_Extension__c
    WHERE SKU_Code__c IN :skuToImage.keySet()
]) {
    String imageUrl = skuToImage.get(p.SKU_Code__c);
    if (imageUrl != null && imageUrl != p.Product_Image_URL__c) {
        p.Product_Image_URL__c = imageUrl;
        toUpdate.add(p);
    }
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('✓ Updated images for ' + toUpdate.size() + ' products');
} else {
    System.debug('· All products already have images or no matching SKUs found');
}

// Summary
Integer total = [SELECT COUNT() FROM Product_Extension__c WHERE Product_Image_URL__c != null];
Integer allProducts = [SELECT COUNT() FROM Product_Extension__c];
System.debug('');
System.debug('═══════════════════════════════════════════');
System.debug('PRODUCT IMAGES COMPLETE');
System.debug('  Products with images: ' + total + ' / ' + allProducts);
System.debug('═══════════════════════════════════════════');
