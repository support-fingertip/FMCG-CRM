/**
 * @description Controller for the Product Catalog LWC component.
 *              Provides product search, category browsing, and pricing data.
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class MDM_ProductCatalogController {

    /**
     * @description Retrieves products with their extensions, filtered by search and category.
     * @param searchTerm Optional search string to filter by product name or code.
     * @param categoryId Optional Product_Category__c Id to filter by category.
     * @param isActiveOnly If true, only return active products.
     * @param limitCount Maximum number of records to return.
     * @param offset Offset for pagination.
     * @return List of ProductWrapper objects.
     */
    @AuraEnabled(cacheable=true)
    public static ProductCatalogResult getProducts(
        String searchTerm,
        Id categoryId,
        Boolean isActiveOnly,
        Integer limitCount,
        Integer offset
    ) {
        limitCount = limitCount != null ? Math.min(limitCount, 100) : 50;
        offset = offset != null ? offset : 0;

        // Build dynamic query
        String query = 'SELECT Id, Name, ProductCode, Family, IsActive, Description, ' +
                       '(SELECT Id, Product_Category__c, Product_Category__r.Name, ' +
                       'Barcode_EAN__c, Barcode_UPC__c, HSN_SAC_Code__c, Weight__c, ' +
                       'Weight_Unit__c, Case_Size__c, Min_Order_Qty__c, Is_Active__c ' +
                       'FROM Product_Extensions__r LIMIT 1) ' +
                       'FROM Product2';

        List<String> conditions = new List<String>();

        if (String.isNotBlank(searchTerm)) {
            String searchWild = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            conditions.add('(Name LIKE :searchWild OR ProductCode LIKE :searchWild)');
        }

        if (isActiveOnly != null && isActiveOnly) {
            conditions.add('IsActive = true');
        }

        if (categoryId != null) {
            // Get all category IDs in the hierarchy below this category
            Set<Id> categoryIds = getCategoryHierarchyIds(categoryId);
            conditions.add('Id IN (SELECT Product__c FROM Product_Extension__c WHERE Product_Category__c IN :categoryIds)');
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        // Count query for pagination
        String countQuery = query.replace(
            'SELECT Id, Name, ProductCode, Family, IsActive, Description, ' +
            '(SELECT Id, Product_Category__c, Product_Category__r.Name, ' +
            'Barcode_EAN__c, Barcode_UPC__c, HSN_SAC_Code__c, Weight__c, ' +
            'Weight_Unit__c, Case_Size__c, Min_Order_Qty__c, Is_Active__c ' +
            'FROM Product_Extensions__r LIMIT 1)',
            'SELECT COUNT()'
        );

        query += ' ORDER BY Name ASC LIMIT :limitCount OFFSET :offset';

        List<Product2> products = Database.query(query);
        Integer totalCount = Database.countQuery(countQuery);

        // Build result
        ProductCatalogResult result = new ProductCatalogResult();
        result.totalCount = totalCount;
        result.products = new List<ProductWrapper>();

        for (Product2 p : products) {
            ProductWrapper pw = new ProductWrapper();
            pw.productId = p.Id;
            pw.name = p.Name;
            pw.productCode = p.ProductCode;
            pw.family = p.Family;
            pw.isActive = p.IsActive;
            pw.description = p.Description;

            if (p.Product_Extensions__r != null && !p.Product_Extensions__r.isEmpty()) {
                Product_Extension__c ext = p.Product_Extensions__r[0];
                pw.categoryName = ext.Product_Category__r != null ? ext.Product_Category__r.Name : null;
                pw.categoryId = ext.Product_Category__c;
                pw.barcodeEAN = ext.Barcode_EAN__c;
                pw.barcodeUPC = ext.Barcode_UPC__c;
                pw.hsnCode = ext.HSN_SAC_Code__c;
                pw.weight = ext.Weight__c;
                pw.weightUnit = ext.Weight_Unit__c;
                pw.caseSize = ext.Case_Size__c;
                pw.minOrderQty = ext.Min_Order_Qty__c;
                pw.extIsActive = ext.Is_Active__c;
            }

            result.products.add(pw);
        }

        return result;
    }

    /**
     * @description Retrieves the category hierarchy tree.
     * @return List of CategoryNode objects representing the tree structure.
     */
    @AuraEnabled(cacheable=true)
    public static List<CategoryNode> getCategoryTree() {
        List<Product_Category__c> allCategories = [
            SELECT Id, Name, Category_Code__c, Level__c, Parent_Category__c, Sort_Order__c, Is_Active__c
            FROM Product_Category__c
            WHERE Is_Active__c = true
            ORDER BY Sort_Order__c ASC, Name ASC
        ];

        // Build tree structure
        Map<Id, CategoryNode> nodeMap = new Map<Id, CategoryNode>();
        List<CategoryNode> rootNodes = new List<CategoryNode>();

        for (Product_Category__c cat : allCategories) {
            CategoryNode node = new CategoryNode();
            node.id = cat.Id;
            node.name = cat.Name;
            node.code = cat.Category_Code__c;
            node.level = cat.Level__c;
            node.parentId = cat.Parent_Category__c;
            node.sortOrder = cat.Sort_Order__c != null ? (Integer) cat.Sort_Order__c : 0;
            node.children = new List<CategoryNode>();
            nodeMap.put(cat.Id, node);
        }

        for (CategoryNode node : nodeMap.values()) {
            if (node.parentId != null && nodeMap.containsKey(node.parentId)) {
                nodeMap.get(node.parentId).children.add(node);
            } else {
                rootNodes.add(node);
            }
        }

        return rootNodes;
    }

    /**
     * @description Retrieves active price list entries for a given product.
     * @param productId The Product2 Id.
     * @return List of Price_List__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Price_List__c> getProductPricing(Id productId) {
        return [
            SELECT Id, Name, Unit_Price__c, Price_Type__c, Channel__c,
                   Region__c, Region__r.Name, Effective_From__c, Effective_To__c,
                   Min_Qty__c, Is_Active__c
            FROM Price_List__c
            WHERE Product__c = :productId
              AND Is_Active__c = true
              AND (Effective_To__c = null OR Effective_To__c >= TODAY)
              AND Effective_From__c <= TODAY
            ORDER BY Price_Type__c ASC, Channel__c ASC
        ];
    }

    /**
     * @description Retrieves product details including extension, pricing, and stock counts.
     * @param productId The Product2 Id.
     * @return ProductDetailWrapper with full product info.
     */
    @AuraEnabled(cacheable=true)
    public static ProductDetailWrapper getProductDetail(Id productId) {
        Product2 product = [
            SELECT Id, Name, ProductCode, Family, IsActive, Description,
                   (SELECT Id, Product_Category__c, Product_Category__r.Name,
                    Barcode_EAN__c, Barcode_UPC__c, HSN_SAC_Code__c, Weight__c,
                    Weight_Unit__c, Case_Size__c, Min_Order_Qty__c, Is_Active__c
                    FROM Product_Extensions__r LIMIT 1)
            FROM Product2
            WHERE Id = :productId
        ];

        ProductDetailWrapper detail = new ProductDetailWrapper();
        detail.productId = product.Id;
        detail.name = product.Name;
        detail.productCode = product.ProductCode;
        detail.family = product.Family;
        detail.isActive = product.IsActive;
        detail.description = product.Description;

        if (product.Product_Extensions__r != null && !product.Product_Extensions__r.isEmpty()) {
            Product_Extension__c ext = product.Product_Extensions__r[0];
            detail.categoryName = ext.Product_Category__r != null ? ext.Product_Category__r.Name : null;
            detail.barcodeEAN = ext.Barcode_EAN__c;
            detail.barcodeUPC = ext.Barcode_UPC__c;
            detail.hsnCode = ext.HSN_SAC_Code__c;
            detail.weight = ext.Weight__c;
            detail.weightUnit = ext.Weight_Unit__c;
            detail.caseSize = ext.Case_Size__c;
            detail.minOrderQty = ext.Min_Order_Qty__c;
        }

        // Get pricing
        detail.priceLists = getProductPricing(productId);

        // Get active batch count
        detail.activeBatchCount = [
            SELECT COUNT() FROM Batch_Master__c
            WHERE Product__c = :productId AND Status__c = 'Active'
        ];

        // Get total distributor stock (current entries)
        AggregateResult[] stockAgg = [
            SELECT SUM(Closing_Stock__c) totalStock
            FROM Distributor_Stock__c
            WHERE Product__c = :productId AND Is_Current__c = true
        ];
        detail.totalDistributorStock = stockAgg[0].get('totalStock') != null ?
            (Decimal) stockAgg[0].get('totalStock') : 0;

        return detail;
    }

    // ── Private Helpers ───────────────────────────────────────────────────────

    /**
     * @description Collects all category IDs in the hierarchy below and including a given category.
     */
    private static Set<Id> getCategoryHierarchyIds(Id categoryId) {
        Set<Id> ids = new Set<Id>{ categoryId };
        Set<Id> parentIds = new Set<Id>{ categoryId };

        // Walk down the hierarchy (max 3 levels: Category -> Sub-Category -> Brand)
        for (Integer i = 0; i < 3; i++) {
            List<Product_Category__c> children = [
                SELECT Id FROM Product_Category__c
                WHERE Parent_Category__c IN :parentIds AND Is_Active__c = true
            ];
            if (children.isEmpty()) break;
            parentIds.clear();
            for (Product_Category__c child : children) {
                ids.add(child.Id);
                parentIds.add(child.Id);
            }
        }

        return ids;
    }

    // ── Wrapper Classes ───────────────────────────────────────────────────────

    public class ProductCatalogResult {
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public List<ProductWrapper> products;
    }

    public class ProductWrapper {
        @AuraEnabled public Id productId;
        @AuraEnabled public String name;
        @AuraEnabled public String productCode;
        @AuraEnabled public String family;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String description;
        @AuraEnabled public String categoryName;
        @AuraEnabled public Id categoryId;
        @AuraEnabled public String barcodeEAN;
        @AuraEnabled public String barcodeUPC;
        @AuraEnabled public String hsnCode;
        @AuraEnabled public Decimal weight;
        @AuraEnabled public String weightUnit;
        @AuraEnabled public Decimal caseSize;
        @AuraEnabled public Decimal minOrderQty;
        @AuraEnabled public Boolean extIsActive;
    }

    public class ProductDetailWrapper {
        @AuraEnabled public Id productId;
        @AuraEnabled public String name;
        @AuraEnabled public String productCode;
        @AuraEnabled public String family;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String description;
        @AuraEnabled public String categoryName;
        @AuraEnabled public String barcodeEAN;
        @AuraEnabled public String barcodeUPC;
        @AuraEnabled public String hsnCode;
        @AuraEnabled public Decimal weight;
        @AuraEnabled public String weightUnit;
        @AuraEnabled public Decimal caseSize;
        @AuraEnabled public Decimal minOrderQty;
        @AuraEnabled public List<Price_List__c> priceLists;
        @AuraEnabled public Integer activeBatchCount;
        @AuraEnabled public Decimal totalDistributorStock;
    }

    public class CategoryNode {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String code;
        @AuraEnabled public String level;
        @AuraEnabled public Id parentId;
        @AuraEnabled public Integer sortOrder;
        @AuraEnabled public List<CategoryNode> children;
    }
}