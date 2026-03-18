/**
 * @description Controller for the Order Entry LWC component.
 *              Handles product search, sales order creation with line items,
 *              scheme application, and order history retrieval for FMCG field sales.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class OrderEntryController {

    @AuraEnabled(cacheable=true)
    public static List<ProductSearchResult> searchProducts(String searchTerm, String categoryId, String accountId) {
        String query = 'SELECT Id, Name, SKU_Code__c, Is_Active__c, MRP__c, Unit_Price__c, GST_Rate__c ' +
                       'FROM Product_Extension__c WHERE Is_Active__c = true';
        String searchKey;
        if (String.isNotBlank(searchTerm)) {
            searchKey = '%' + String.escapeSingleQuotes(searchTerm) + '%';
            query += ' AND (Name LIKE :searchKey OR SKU_Code__c LIKE :searchKey)';
        }
        if (String.isNotBlank(categoryId)) {
            query += ' AND Product_Category__r.Name = :categoryId';
        }
        query += ' ORDER BY Name LIMIT 50';
        List<Product_Extension__c> products = Database.query(query);

        if (products.isEmpty()) {
            return new List<ProductSearchResult>();
        }

        // Look up account channel for price resolution
        String channel = '';
        if (String.isNotBlank(accountId)) {
            try {
                Id acctId = Id.valueOf(accountId);
                List<Account> accts = [SELECT Channel__c FROM Account WHERE Id = :acctId LIMIT 1];
                if (!accts.isEmpty() && String.isNotBlank(accts[0].Channel__c)) {
                    channel = accts[0].Channel__c;
                }
            } catch (StringException e) {
                // accountId is not a valid Salesforce Id — skip channel resolution
            }
        }

        // Fetch active price list entries for found products
        Set<Id> productIds = new Set<Id>();
        for (Product_Extension__c p : products) {
            productIds.add(p.Id);
        }

        Map<String, Price_List__c> priceListMap = new Map<String, Price_List__c>();
        for (Price_List__c pl : [
            SELECT Id, Product_Ext__c, Region__c, Channel__c, Unit_Price__c
            FROM Price_List__c
            WHERE Product_Ext__c IN :productIds
              AND Is_Active__c = true
              AND Effective_From__c <= TODAY
              AND (Effective_To__c >= TODAY OR Effective_To__c = null)
            ORDER BY Effective_From__c DESC
        ]) {
            String regionVal = pl.Region__c != null ? String.valueOf(pl.Region__c) : '';
            String channelVal = pl.Channel__c != null ? pl.Channel__c : '';
            String key = String.valueOf(pl.Product_Ext__c) + '|' + regionVal + '|' + channelVal;
            if (!priceListMap.containsKey(key)) {
                priceListMap.put(key, pl);
            }
        }

        // Build results with resolved prices
        List<ProductSearchResult> results = new List<ProductSearchResult>();
        for (Product_Extension__c p : products) {
            ProductSearchResult r = new ProductSearchResult();
            r.Id = p.Id;
            r.Name = p.Name;
            r.SKU_Code = p.SKU_Code__c;
            r.MRP = p.MRP__c;
            r.GST_Rate = p.GST_Rate__c;

            // Resolve price from price list: channel-specific > product-only > fallback to MRP
            Decimal resolvedPrice = resolvePrice(p.Id, '', channel, priceListMap);
            r.Unit_Price = resolvedPrice != null && resolvedPrice > 0
                ? resolvedPrice
                : (p.Unit_Price__c != null ? p.Unit_Price__c : p.MRP__c);

            results.add(r);
        }

        return results;
    }

    private static Decimal resolvePrice(Id productId, String region, String channel, Map<String, Price_List__c> priceListMap) {
        // Try product + region + channel
        String key = String.valueOf(productId) + '|' +
                     (String.isNotBlank(region) ? region : '') + '|' +
                     (String.isNotBlank(channel) ? channel : '');
        if (priceListMap.containsKey(key)) {
            return priceListMap.get(key).Unit_Price__c;
        }
        // Try product + region only
        key = String.valueOf(productId) + '|' +
              (String.isNotBlank(region) ? region : '') + '|';
        if (priceListMap.containsKey(key)) {
            return priceListMap.get(key).Unit_Price__c;
        }
        // Try product only (national/default)
        key = String.valueOf(productId) + '||';
        if (priceListMap.containsKey(key)) {
            return priceListMap.get(key).Unit_Price__c;
        }
        return 0;
    }

    @AuraEnabled
    public static Sales_Order__c createSalesOrder(String orderJson) {
        Savepoint sp = Database.setSavepoint();
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(orderJson);

            Sales_Order__c order = new Sales_Order__c();
            order.Account__c = (String) payload.get('accountId');
            if (payload.get('visitId') != null) {
                order.Visit__c = (String) payload.get('visitId');
            }
            order.Status__c = (String) payload.get('status');
            order.Notes__c = (String) payload.get('remarks');
            order.Order_Date__c = Date.today();
            order.Total_Gross_Amount__c = toDecimal(payload.get('grossAmount'));
            order.Total_Discount__c = toDecimal(payload.get('totalDiscount'));
            order.Total_Tax__c = toDecimal(payload.get('totalTax'));
            order.Total_Net_Amount__c = toDecimal(payload.get('netAmount'));
            if (payload.containsKey('mustSellOverride') && payload.get('mustSellOverride') == true) {
                order.Must_Sell_Override__c = true;
            }
            if (payload.containsKey('mustSellCompliance')) {
                order.Must_Sell_Compliance__c = toDecimal(payload.get('mustSellCompliance'));
            }

            insert order;

            List<Order_Line_Item__c> lineItems = new List<Order_Line_Item__c>();
            List<Object> items = (List<Object>) payload.get('lineItems');
            if (items != null) {
                for (Object itemObj : items) {
                    Map<String, Object> item = (Map<String, Object>) itemObj;
                    Order_Line_Item__c li = new Order_Line_Item__c();
                    li.Sales_Order__c = order.Id;
                    li.Product_Ext__c = (String) item.get('productId');
                    li.Quantity__c = toDecimal(item.get('quantity'));
                    li.Free_Quantity__c = toDecimal(item.get('freeQty'));
                    li.Unit_Price__c = toDecimal(item.get('rate'));
                    li.Line_Total__c = toDecimal(item.get('grossAmount'));
                    li.Discount_Amount__c = toDecimal(item.get('discountAmount'));
                    li.Tax_Rate__c = toDecimal(item.get('taxRate'));
                    li.Tax_Amount__c = toDecimal(item.get('taxAmount'));
                    li.Total_Amount__c = toDecimal(item.get('totalAmount'));
                    if (item.get('schemeId') != null) {
                        li.Scheme__c = (String) item.get('schemeId');
                    }
                    lineItems.add(li);
                }
            }

            if (!lineItems.isEmpty()) {
                insert lineItems;
            }

            // Recalculate totals
            updateOrderTotals(order.Id);
            return [SELECT Id, Name, Status__c, Total_Net_Amount__c FROM Sales_Order__c WHERE Id = :order.Id];
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Decimal toDecimal(Object value) {
        if (value == null) return null;
        if (value instanceof Decimal) return (Decimal) value;
        if (value instanceof Integer) return Decimal.valueOf((Integer) value);
        if (value instanceof Long) return Decimal.valueOf((Long) value);
        if (value instanceof Double) return Decimal.valueOf((Double) value);
        return Decimal.valueOf(String.valueOf(value));
    }

    @AuraEnabled(cacheable=true)
    public static Sales_Order__c getLastOrder(Id accountId) {
        List<Sales_Order__c> orders = [
            SELECT Id, Name, Order_Date__c, Total_Net_Amount__c, Status__c,
                   (SELECT Id, Product_Ext__c, Product_Ext__r.Name, Quantity__c, Unit_Price__c, Line_Total__c
                    FROM Order_Line_Items__r ORDER BY CreatedDate)
            FROM Sales_Order__c
            WHERE Account__c = :accountId
            ORDER BY Order_Date__c DESC
            LIMIT 1
        ];
        return orders.isEmpty() ? null : orders[0];
    }

    @AuraEnabled(cacheable=true)
    public static List<Scheme__c> getApplicableSchemes(Id accountId, Date orderDate) {
        Date effectiveDate = orderDate != null ? orderDate : Date.today();
        return [
            SELECT Id, Name, Scheme_Code__c, Scheme_Category__c, Scheme_Type__c, Description__c,
                   Start_Date__c, End_Date__c, Max_Discount_Cap__c,
                   Discount_Percent__c, Discount_Amount__c, Price_Discount__c,
                   Free_Product_Ext__c, Free_Product_Ext__r.Name, Free_Quantity__c,
                   Reward_Points__c, MOV__c, Min_Quantity__c, Max_Quantity__c,
                   Min_Value__c, Max_Value__c, Product_Ext__c, Product_Category__c,
                   Is_Stackable__c, Priority__c,
                   (SELECT Id, Slab_Type__c, Min_Value__c, Max_Value__c,
                           Discount_Type__c, Discount_Value__c, Discount_Percent__c,
                           Discount_Amount__c, Free_Product_Ext__c, Free_Quantity__c
                    FROM Scheme_Slabs__r ORDER BY Min_Value__c),
                   (SELECT Id, Product_Ext__c, Product_Ext__r.Name, Is_Buy_Product__c, Is_Get_Product__c,
                           Min_Quantity__c, Product_Classification__c
                    FROM Scheme_Products__r)
            FROM Scheme__c
            WHERE Status__c = 'Active'
            AND Start_Date__c <= :effectiveDate
            AND End_Date__c >= :effectiveDate
            ORDER BY Priority__c
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getMustSellProducts(Id accountId, Date orderDate) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();

        if (!BPM_FeatureToggle_Util.isEnabled('SPM-002')) {
            return result;
        }

        Date effectiveDate = orderDate != null ? orderDate : Date.today();

        // Fetch account attributes for filtering
        String accountChannel = '';
        String accountCustomerType = '';
        Id accountTerritoryId = null;

        if (accountId != null) {
            List<Account> accts = [
                SELECT Channel__c, Outlet_Type__c, Territory__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
            if (!accts.isEmpty()) {
                accountChannel = accts[0].Channel__c != null ? accts[0].Channel__c : '';
                accountCustomerType = accts[0].Outlet_Type__c != null ? accts[0].Outlet_Type__c : '';
                accountTerritoryId = accts[0].Territory__c;
            }
        }

        // Query Must_Sell_Config__c records that are active and within date range
        List<Must_Sell_Config__c> configs = [
            SELECT Id, Product_Ext__c, Product_Ext__r.Name, Product_Ext__r.SKU_Code__c,
                   Classification__c, Min_Qty__c,
                   Territory__c, Channel__c, Customer_Type__c
            FROM Must_Sell_Config__c
            WHERE Is_Active__c = true
              AND Start_Date__c <= :effectiveDate
              AND End_Date__c >= :effectiveDate
              AND Product_Ext__c != null
            ORDER BY Classification__c, Product_Ext__r.Name
        ];

        // Filter configs by account's territory, channel, and customer type
        Set<Id> seenProductIds = new Set<Id>();
        for (Must_Sell_Config__c cfg : configs) {
            // Territory filter: config applies if territory is blank (all) or matches account
            if (cfg.Territory__c != null && cfg.Territory__c != accountTerritoryId) {
                continue;
            }
            // Channel filter: config applies if channel is blank (all) or matches account
            if (String.isNotBlank(cfg.Channel__c) && cfg.Channel__c != accountChannel) {
                continue;
            }
            // Customer Type filter: config applies if customer type is blank (all) or matches account
            if (String.isNotBlank(cfg.Customer_Type__c) && cfg.Customer_Type__c != accountCustomerType) {
                continue;
            }

            // Deduplicate by product Id — first matching config wins
            if (seenProductIds.contains(cfg.Product_Ext__c)) {
                continue;
            }
            seenProductIds.add(cfg.Product_Ext__c);

            Map<String, Object> item = new Map<String, Object>();
            item.put('productId', cfg.Product_Ext__c);
            item.put('productName', cfg.Product_Ext__r.Name);
            item.put('sku', cfg.Product_Ext__r.SKU_Code__c);
            item.put('minQuantity', cfg.Min_Qty__c != null ? cfg.Min_Qty__c : 1);
            item.put('classification', cfg.Classification__c);
            item.put('configId', cfg.Id);
            result.add(item);
        }

        // Also include legacy scheme-based must-sell products (backward compatibility)
        List<Scheme__c> schemes = [
            SELECT Id, Name,
                   (SELECT Id, Product_Ext__c, Product_Ext__r.Name, Product_Ext__r.SKU_Code__c,
                           Min_Quantity__c, Product_Classification__c
                    FROM Scheme_Products__r
                    WHERE Product_Classification__c IN ('Must Sell', 'Focused Sell')
                      AND Product_Ext__c != null)
            FROM Scheme__c
            WHERE Status__c = 'Active'
            AND Start_Date__c <= :effectiveDate
            AND End_Date__c >= :effectiveDate
            ORDER BY Priority__c
        ];

        for (Scheme__c scheme : schemes) {
            if (scheme.Scheme_Products__r == null) continue;
            for (Scheme_Product__c sp : scheme.Scheme_Products__r) {
                if (seenProductIds.contains(sp.Product_Ext__c)) continue;
                seenProductIds.add(sp.Product_Ext__c);

                Map<String, Object> item = new Map<String, Object>();
                item.put('productId', sp.Product_Ext__c);
                item.put('productName', sp.Product_Ext__r.Name);
                item.put('sku', sp.Product_Ext__r.SKU_Code__c);
                item.put('minQuantity', sp.Min_Quantity__c != null ? sp.Min_Quantity__c : 1);
                item.put('schemeName', scheme.Name);
                item.put('schemeId', scheme.Id);
                item.put('classification', sp.Product_Classification__c);
                result.add(item);
            }
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductSearchResult> getTopSellingProducts(Id accountId) {
        // Get top selling products based on order frequency for this account's territory
        Set<Id> topProductIds = new Set<Id>();

        // First: top products ordered by this specific account
        for (AggregateResult ar : [
            SELECT Product_Ext__c prodId, COUNT(Id) cnt
            FROM Order_Line_Item__c
            WHERE Sales_Order__r.Account__c = :accountId
              AND Sales_Order__r.Status__c != 'Cancelled'
              AND Sales_Order__r.Order_Date__c >= :Date.today().addDays(-90)
            GROUP BY Product_Ext__c
            ORDER BY COUNT(Id) DESC
            LIMIT 10
        ]) {
            topProductIds.add((Id) ar.get('prodId'));
        }

        // If less than 10, supplement with territory-wide top sellers
        if (topProductIds.size() < 10) {
            Id territoryId = null;
            List<Account> accts = [SELECT Territory__c FROM Account WHERE Id = :accountId LIMIT 1];
            if (!accts.isEmpty()) {
                territoryId = accts[0].Territory__c;
            }
            if (territoryId != null) {
                for (AggregateResult ar : [
                    SELECT Product_Ext__c prodId, COUNT(Id) cnt
                    FROM Order_Line_Item__c
                    WHERE Sales_Order__r.Account__r.Territory__c = :territoryId
                      AND Sales_Order__r.Status__c != 'Cancelled'
                      AND Sales_Order__r.Order_Date__c >= :Date.today().addDays(-90)
                      AND Product_Ext__c NOT IN :topProductIds
                    GROUP BY Product_Ext__c
                    ORDER BY COUNT(Id) DESC
                    LIMIT :( 10 - topProductIds.size() )
                ]) {
                    topProductIds.add((Id) ar.get('prodId'));
                }
            }
        }

        if (topProductIds.isEmpty()) {
            return new List<ProductSearchResult>();
        }

        List<Product_Extension__c> products = [
            SELECT Id, Name, SKU_Code__c, MRP__c, Unit_Price__c, GST_Rate__c
            FROM Product_Extension__c
            WHERE Id IN :topProductIds AND Is_Active__c = true
        ];

        List<ProductSearchResult> results = new List<ProductSearchResult>();
        for (Product_Extension__c p : products) {
            ProductSearchResult r = new ProductSearchResult();
            r.Id = p.Id;
            r.Name = p.Name;
            r.SKU_Code = p.SKU_Code__c;
            r.MRP = p.MRP__c;
            r.Unit_Price = p.Unit_Price__c != null ? p.Unit_Price__c : p.MRP__c;
            r.GST_Rate = p.GST_Rate__c;
            results.add(r);
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Product_Extension__c> getProductExtensions(List<Id> productIds) {
        return [SELECT Id, HSN_SAC_Code__c, Barcode_UPC__c, Barcode_EAN__c,
                       Case_Size__c, Min_Order_Qty__c, Weight__c, Weight_Unit__c
                FROM Product_Extension__c WHERE Id IN :productIds];
    }

    public class ProductSearchResult {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String SKU_Code;
        @AuraEnabled public Decimal MRP;
        @AuraEnabled public Decimal Unit_Price;
        @AuraEnabled public Decimal GST_Rate;
    }

    private static void updateOrderTotals(Id orderId) {
        AggregateResult[] results = [
            SELECT SUM(Line_Total__c) totalAmount, SUM(Tax_Amount__c) totalTax,
                   SUM(Discount_Amount__c) totalDiscount, COUNT(Id) totalItems
            FROM Order_Line_Item__c WHERE Sales_Order__c = :orderId
        ];
        if (!results.isEmpty()) {
            Sales_Order__c order = new Sales_Order__c(Id = orderId);
            order.Total_Gross_Amount__c = (Decimal)results[0].get('totalAmount');
            order.Total_Tax__c = (Decimal)results[0].get('totalTax');
            order.Total_Discount__c = (Decimal)results[0].get('totalDiscount');
            order.Total_Items__c = (Integer)results[0].get('totalItems');
            Decimal gross = order.Total_Gross_Amount__c != null ? order.Total_Gross_Amount__c : 0;
            Decimal tax = order.Total_Tax__c != null ? order.Total_Tax__c : 0;
            Decimal disc = order.Total_Discount__c != null ? order.Total_Discount__c : 0;
            order.Total_Net_Amount__c = gross + tax - disc;
            update order;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getProductCategories() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Map<String, String> allOption = new Map<String, String>();
        allOption.put('label', 'All Categories');
        allOption.put('value', '');
        options.add(allOption);
        for (Product_Category__c cat : [
            SELECT Id, Name FROM Product_Category__c
            WHERE Is_Active__c = true
            ORDER BY Sort_Order__c NULLS LAST, Name
        ]) {
            Map<String, String> opt = new Map<String, String>();
            opt.put('label', cat.Name);
            opt.put('value', cat.Name);
            options.add(opt);
        }
        return options;
    }
}
