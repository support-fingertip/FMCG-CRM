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
        String query = 'SELECT Id, Name, SKU_Code__c, Is_Active__c, MRP__c, Unit_Price__c, GST_Rate__c, ' +
                       'Unit_of_Measure__c, Base_UOM__c, Base_UOM__r.UOM_Code__c, Base_UOM__r.Name, ' +
                       'Secondary_UOM__c, Secondary_UOM__r.UOM_Code__c, Secondary_UOM__r.Name, ' +
                       'Ordering_UOMs__c, Case_Size__c ' +
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
            r.UOM = p.Unit_of_Measure__c != null ? p.Unit_of_Measure__c : 'Piece';
            r.BaseUOMCode = (p.Base_UOM__c != null && p.Base_UOM__r.UOM_Code__c != null)
                ? p.Base_UOM__r.UOM_Code__c : 'PCS';
            r.BaseUOMId = p.Base_UOM__c;
            r.BaseUOMName = (p.Base_UOM__c != null && p.Base_UOM__r.Name != null)
                ? p.Base_UOM__r.Name : 'Piece';
            r.SecondaryUOMCode = (p.Secondary_UOM__c != null && p.Secondary_UOM__r.UOM_Code__c != null)
                ? p.Secondary_UOM__r.UOM_Code__c : null;
            r.SecondaryUOMId = p.Secondary_UOM__c;
            r.SecondaryUOMName = (p.Secondary_UOM__c != null && p.Secondary_UOM__r.Name != null)
                ? p.Secondary_UOM__r.Name : null;
            r.OrderingUOMs = p.Ordering_UOMs__c;
            r.CaseSize = p.Case_Size__c;

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

            // Set territory from account
            if (order.Account__c != null) {
                List<Account> accts = [SELECT Territory__c FROM Account WHERE Id = :order.Account__c LIMIT 1];
                if (!accts.isEmpty() && accts[0].Territory__c != null) {
                    order.Territory__c = accts[0].Territory__c;
                }
            }

            // Set warehouse if selected
            if (payload.get('warehouseId') != null) {
                order.Warehouse__c = (String) payload.get('warehouseId');
            }
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
                // Collect product Ids for bulk UOM resolution
                Set<Id> lineProductIds = new Set<Id>();
                for (Object itemObj : items) {
                    Map<String, Object> itm = (Map<String, Object>) itemObj;
                    if (itm.get('productId') != null) {
                        try {
                            lineProductIds.add(Id.valueOf((String) itm.get('productId')));
                        } catch (Exception ex) { /* skip invalid ids */ }
                    }
                }

                // Bulk-fetch product base UOM info
                Map<Id, Product_Extension__c> productUOMMap = new Map<Id, Product_Extension__c>();
                if (!lineProductIds.isEmpty()) {
                    for (Product_Extension__c pe : [
                        SELECT Id, Base_UOM__c, Base_UOM__r.UOM_Code__c
                        FROM Product_Extension__c
                        WHERE Id IN :lineProductIds
                    ]) {
                        productUOMMap.put(pe.Id, pe);
                    }
                }

                // Build conversion requests for bulk conversion
                List<UOM_Conversion_Service.ConversionRequest> convRequests = new List<UOM_Conversion_Service.ConversionRequest>();
                List<Map<String, Object>> itemMaps = new List<Map<String, Object>>();

                for (Object itemObj : items) {
                    Map<String, Object> item = (Map<String, Object>) itemObj;
                    itemMaps.add(item);

                    Id productId = item.get('productId') != null ? Id.valueOf((String) item.get('productId')) : null;
                    String uomCode = item.get('uomCode') != null ? (String) item.get('uomCode') : null;
                    String uomPicklist = item.get('uom') != null ? (String) item.get('uom') : 'Pieces';
                    Decimal qty = toDecimal(item.get('quantity'));

                    // Resolve the order UOM code
                    if (String.isBlank(uomCode)) {
                        uomCode = UOM_Conversion_Service.mapPicklistToCode(uomPicklist);
                    }

                    // Get base UOM code for the product
                    String baseUomCode = 'PCS';
                    if (productId != null && productUOMMap.containsKey(productId)) {
                        Product_Extension__c pe = productUOMMap.get(productId);
                        if (pe.Base_UOM__c != null && String.isNotBlank(pe.Base_UOM__r.UOM_Code__c)) {
                            baseUomCode = pe.Base_UOM__r.UOM_Code__c;
                        }
                    }

                    UOM_Conversion_Service.ConversionRequest cr = new UOM_Conversion_Service.ConversionRequest();
                    cr.productId = productId;
                    cr.fromUomCode = uomCode;
                    cr.toUomCode = baseUomCode;
                    cr.quantity = qty;
                    convRequests.add(cr);
                }

                // Bulk convert
                List<UOM_Conversion_Service.ConvertedResult> convResults = UOM_Conversion_Service.bulkConvert(convRequests);

                for (Integer i = 0; i < itemMaps.size(); i++) {
                    Map<String, Object> item = itemMaps[i];
                    UOM_Conversion_Service.ConvertedResult conv = convResults[i];

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

                    // Set UOM picklist (backward compatibility)
                    String uomPicklist = item.get('uom') != null ? (String) item.get('uom') : null;
                    String uomCode = item.get('uomCode') != null ? (String) item.get('uomCode') : null;
                    if (String.isNotBlank(uomPicklist)) {
                        li.UOM__c = uomPicklist;
                    } else if (String.isNotBlank(uomCode)) {
                        li.UOM__c = UOM_Conversion_Service.mapCodeToPicklist(uomCode);
                    } else {
                        li.UOM__c = 'Pieces';
                    }

                    // Set UOM lookup fields
                    if (String.isNotBlank(uomCode)) {
                        li.Order_UOM__c = UOM_Conversion_Service.getUOMIdByCode(uomCode);
                    } else {
                        li.Order_UOM__c = UOM_Conversion_Service.getUOMIdByCode(
                            UOM_Conversion_Service.mapPicklistToCode(li.UOM__c)
                        );
                    }

                    // Set base quantity and conversion factor
                    li.Base_Quantity__c = conv.convertedQuantity;
                    li.Conversion_Factor__c = conv.conversionFactor;
                    li.Base_UOM__c = conv.baseUomId;

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
            SELECT Id, Name, Order_Date__c, Total_Net_Amount__c, Status__c, Net_Amount__c,
                   (SELECT Id, Product_Ext__c, Product_Ext__r.Name, Product_Ext__r.SKU_Code__c,
                           Product_Ext__r.Base_UOM__c, Product_Ext__r.Base_UOM__r.UOM_Code__c,
                           Quantity__c, Base_Quantity__c, Unit_Price__c, Line_Total__c,
                           UOM__c, Order_UOM__c, Base_UOM__c, Conversion_Factor__c,
                           Free_Quantity__c, Discount_Amount__c, Tax_Rate__c, Tax_Amount__c, Total_Amount__c
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
                   Invoice_Qty_Threshold__c, Invoice_Qty_UOM__c, Invoice_Val_Threshold__c,
                   Is_Stackable__c, Priority__c,
                   (SELECT Id, Slab_Type__c, Min_Quantity__c, Max_Quantity__c,
                           Min_Value__c, Max_Value__c,
                           Discount_Type__c, Discount_Value__c, Discount_Percent__c,
                           Discount_Amount__c, Free_Product_Ext__c, Free_Quantity__c,
                           Price_Discount__c, Reward_Points__c
                    FROM Scheme_Slabs__r WHERE Is_Active__c = true ORDER BY Min_Quantity__c ASC, Min_Value__c ASC),
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
                   Product_Ext__r.Unit_of_Measure__c,
                   Product_Ext__r.Base_UOM__c, Product_Ext__r.Base_UOM__r.UOM_Code__c, Product_Ext__r.Base_UOM__r.Name,
                   Product_Ext__r.Secondary_UOM__c, Product_Ext__r.Secondary_UOM__r.UOM_Code__c, Product_Ext__r.Secondary_UOM__r.Name,
                   Product_Ext__r.Ordering_UOMs__c, Product_Ext__r.Case_Size__c,
                   Product_Ext__r.MRP__c, Product_Ext__r.Unit_Price__c, Product_Ext__r.GST_Rate__c,
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
            item.put('uom', cfg.Product_Ext__r.Unit_of_Measure__c != null ? cfg.Product_Ext__r.Unit_of_Measure__c : 'Piece');
            item.put('baseUOMCode', (cfg.Product_Ext__r.Base_UOM__c != null && cfg.Product_Ext__r.Base_UOM__r.UOM_Code__c != null) ? cfg.Product_Ext__r.Base_UOM__r.UOM_Code__c : 'PCS');
            item.put('baseUOMName', (cfg.Product_Ext__r.Base_UOM__c != null && cfg.Product_Ext__r.Base_UOM__r.Name != null) ? cfg.Product_Ext__r.Base_UOM__r.Name : 'Piece');
            item.put('secondaryUOMCode', (cfg.Product_Ext__r.Secondary_UOM__c != null && cfg.Product_Ext__r.Secondary_UOM__r.UOM_Code__c != null) ? cfg.Product_Ext__r.Secondary_UOM__r.UOM_Code__c : null);
            item.put('secondaryUOMName', (cfg.Product_Ext__r.Secondary_UOM__c != null && cfg.Product_Ext__r.Secondary_UOM__r.Name != null) ? cfg.Product_Ext__r.Secondary_UOM__r.Name : null);
            item.put('orderingUOMs', cfg.Product_Ext__r.Ordering_UOMs__c);
            item.put('caseSize', cfg.Product_Ext__r.Case_Size__c);
            item.put('mrp', cfg.Product_Ext__r.MRP__c);
            item.put('unitPrice', cfg.Product_Ext__r.Unit_Price__c);
            item.put('gstRate', cfg.Product_Ext__r.GST_Rate__c);
            result.add(item);
        }

        // Also include legacy scheme-based must-sell products (backward compatibility)
        List<Scheme__c> schemes = [
            SELECT Id, Name,
                   (SELECT Id, Product_Ext__c, Product_Ext__r.Name, Product_Ext__r.SKU_Code__c,
                           Product_Ext__r.Unit_of_Measure__c,
                           Product_Ext__r.Base_UOM__c, Product_Ext__r.Base_UOM__r.UOM_Code__c, Product_Ext__r.Base_UOM__r.Name,
                           Product_Ext__r.Secondary_UOM__c, Product_Ext__r.Secondary_UOM__r.UOM_Code__c, Product_Ext__r.Secondary_UOM__r.Name,
                           Product_Ext__r.Ordering_UOMs__c, Product_Ext__r.Case_Size__c,
                           Product_Ext__r.MRP__c, Product_Ext__r.Unit_Price__c, Product_Ext__r.GST_Rate__c,
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
                item.put('uom', sp.Product_Ext__r.Unit_of_Measure__c != null ? sp.Product_Ext__r.Unit_of_Measure__c : 'Piece');
                item.put('baseUOMCode', (sp.Product_Ext__r.Base_UOM__c != null && sp.Product_Ext__r.Base_UOM__r.UOM_Code__c != null) ? sp.Product_Ext__r.Base_UOM__r.UOM_Code__c : 'PCS');
                item.put('baseUOMName', (sp.Product_Ext__r.Base_UOM__c != null && sp.Product_Ext__r.Base_UOM__r.Name != null) ? sp.Product_Ext__r.Base_UOM__r.Name : 'Piece');
                item.put('secondaryUOMCode', (sp.Product_Ext__r.Secondary_UOM__c != null && sp.Product_Ext__r.Secondary_UOM__r.UOM_Code__c != null) ? sp.Product_Ext__r.Secondary_UOM__r.UOM_Code__c : null);
                item.put('secondaryUOMName', (sp.Product_Ext__r.Secondary_UOM__c != null && sp.Product_Ext__r.Secondary_UOM__r.Name != null) ? sp.Product_Ext__r.Secondary_UOM__r.Name : null);
                item.put('orderingUOMs', sp.Product_Ext__r.Ordering_UOMs__c);
                item.put('caseSize', sp.Product_Ext__r.Case_Size__c);
                item.put('mrp', sp.Product_Ext__r.MRP__c);
                item.put('unitPrice', sp.Product_Ext__r.Unit_Price__c);
                item.put('gstRate', sp.Product_Ext__r.GST_Rate__c);
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

        // Fallback: if no top sellers found, show recently added active products
        if (topProductIds.isEmpty()) {
            List<Product_Extension__c> fallbackProducts = [
                SELECT Id, Name, SKU_Code__c, MRP__c, Unit_Price__c, GST_Rate__c, Unit_of_Measure__c,
                       Base_UOM__c, Base_UOM__r.UOM_Code__c, Base_UOM__r.Name,
                       Secondary_UOM__c, Secondary_UOM__r.UOM_Code__c, Secondary_UOM__r.Name,
                       Ordering_UOMs__c, Case_Size__c
                FROM Product_Extension__c
                WHERE Is_Active__c = true
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
            List<ProductSearchResult> fallbackResults = new List<ProductSearchResult>();
            for (Product_Extension__c p : fallbackProducts) {
                fallbackResults.add(buildProductSearchResult(p));
            }
            return fallbackResults;
        }

        List<Product_Extension__c> products = [
            SELECT Id, Name, SKU_Code__c, MRP__c, Unit_Price__c, GST_Rate__c, Unit_of_Measure__c,
                   Base_UOM__c, Base_UOM__r.UOM_Code__c, Base_UOM__r.Name,
                   Secondary_UOM__c, Secondary_UOM__r.UOM_Code__c, Secondary_UOM__r.Name,
                   Ordering_UOMs__c, Case_Size__c
            FROM Product_Extension__c
            WHERE Id IN :topProductIds AND Is_Active__c = true
        ];

        List<ProductSearchResult> results = new List<ProductSearchResult>();
        for (Product_Extension__c p : products) {
            results.add(buildProductSearchResult(p));
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
        @AuraEnabled public String UOM;
        @AuraEnabled public String BaseUOMCode;
        @AuraEnabled public Id BaseUOMId;
        @AuraEnabled public String BaseUOMName;
        @AuraEnabled public String SecondaryUOMCode;
        @AuraEnabled public Id SecondaryUOMId;
        @AuraEnabled public String SecondaryUOMName;
        @AuraEnabled public String OrderingUOMs;
        @AuraEnabled public Decimal CaseSize;
    }

    /**
     * @description Returns the available UOM options for order line items.
     *              Maps product UOM values to Order_Line_Item__c.UOM__c picklist values.
     * @return List of label/value pairs for UOM combobox.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getOrderUOMOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        // Query all active UOMs from the UOM master table
        List<UOM__c> activeUOMs = [
            SELECT Id, UOM_Code__c, Name, Is_Base_Unit__c
            FROM UOM__c
            WHERE Is_Active__c = true
            ORDER BY Is_Base_Unit__c DESC, Name ASC
        ];
        if (!activeUOMs.isEmpty()) {
            for (UOM__c u : activeUOMs) {
                Map<String, String> opt = new Map<String, String>();
                opt.put('label', u.Name + ' (' + u.UOM_Code__c + ')');
                opt.put('value', u.UOM_Code__c);
                opt.put('uomId', u.Id);
                opt.put('isBase', String.valueOf(u.Is_Base_Unit__c));
                options.add(opt);
            }
        }
        // Fallback to hardcoded values if no UOM master records exist
        if (options.isEmpty()) {
            String[] uomValues = new String[]{ 'Pieces', 'Cases', 'Boxes', 'Kg', 'Liters' };
            for (String uom : uomValues) {
                Map<String, String> opt = new Map<String, String>();
                opt.put('label', uom);
                opt.put('value', uom);
                options.add(opt);
            }
        }
        return options;
    }

    /**
     * @description Returns allowed UOM options for a specific product, using
     *              the UOM master and product configuration.
     * @param productId The Product_Extension__c Id.
     * @return List of maps with label, value (UOM code), uomId, isBase keys.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getProductUOMOptions(Id productId) {
        return UOM_Conversion_Service.getProductUOMOptions(productId);
    }

    /**
     * @description Converts a quantity between UOMs for a product. Used by LWC
     *              to display the base quantity equivalent inline.
     * @param productId The Product_Extension__c Id.
     * @param fromUomCode Source UOM code (e.g., 'CS').
     * @param toUomCode Target UOM code (e.g., 'PC').
     * @param quantity The quantity to convert.
     * @return Map with convertedQuantity and conversionFactor.
     */
    @AuraEnabled
    public static Map<String, Decimal> convertQuantity(Id productId, String fromUomCode, String toUomCode, Decimal quantity) {
        Map<String, Decimal> result = new Map<String, Decimal>();
        Decimal factor = UOM_Conversion_Service.getConversionFactor(productId, fromUomCode, toUomCode);
        result.put('conversionFactor', factor);
        result.put('convertedQuantity', quantity != null ? quantity * factor : 0);
        // Flag: 1 = valid conversion found, 0 = defaulted to 1 (no rule)
        result.put('hasConversion', (fromUomCode == toUomCode || factor != 1) ? 1 : 0);
        return result;
    }

    /**
     * @description Maps a Product_Extension__c.Unit_of_Measure__c value to
     *              the corresponding Order_Line_Item__c.UOM__c picklist value.
     * @param productUOM The product's Unit_of_Measure__c value.
     * @return The matching Order_Line_Item__c.UOM__c picklist value.
     */
    public static String mapProductUOMToOrderUOM(String productUOM) {
        if (String.isBlank(productUOM)) return 'Pieces';
        Map<String, String> mapping = new Map<String, String>{
            'Piece' => 'Pieces',
            'Box' => 'Boxes',
            'Case' => 'Cases',
            'Kg' => 'Kg',
            'Litre' => 'Liters',
            'Dozen' => 'Pieces',
            'Pack' => 'Pieces'
        };
        return mapping.containsKey(productUOM) ? mapping.get(productUOM) : 'Pieces';
    }

    private static ProductSearchResult buildProductSearchResult(Product_Extension__c p) {
        ProductSearchResult r = new ProductSearchResult();
        r.Id = p.Id;
        r.Name = p.Name;
        r.SKU_Code = p.SKU_Code__c;
        r.MRP = p.MRP__c;
        r.Unit_Price = p.Unit_Price__c != null ? p.Unit_Price__c : p.MRP__c;
        r.GST_Rate = p.GST_Rate__c;
        r.UOM = p.Unit_of_Measure__c != null ? p.Unit_of_Measure__c : 'Piece';
        r.BaseUOMCode = (p.Base_UOM__c != null && p.Base_UOM__r.UOM_Code__c != null)
            ? p.Base_UOM__r.UOM_Code__c : 'PCS';
        r.BaseUOMId = p.Base_UOM__c;
        r.BaseUOMName = (p.Base_UOM__c != null && p.Base_UOM__r.Name != null)
            ? p.Base_UOM__r.Name : 'Piece';
        r.SecondaryUOMCode = (p.Secondary_UOM__c != null && p.Secondary_UOM__r.UOM_Code__c != null)
            ? p.Secondary_UOM__r.UOM_Code__c : null;
        r.SecondaryUOMId = p.Secondary_UOM__c;
        r.SecondaryUOMName = (p.Secondary_UOM__c != null && p.Secondary_UOM__r.Name != null)
            ? p.Secondary_UOM__r.Name : null;
        r.OrderingUOMs = p.Ordering_UOMs__c;
        r.CaseSize = p.Case_Size__c;
        return r;
    }

    private static void updateOrderTotals(Id orderId) {
        AggregateResult[] results = [
            SELECT SUM(Line_Total__c) totalAmount, SUM(Line_Amount__c) lineAmount,
                   SUM(Tax_Amount__c) totalTax,
                   SUM(Discount_Amount__c) totalDiscount,
                   SUM(Scheme_Discount__c) totalSchemeDiscount,
                   SUM(Total_Amount__c) totalNet,
                   SUM(Free_Quantity__c) totalFreeQty,
                   SUM(Reward_Points__c) totalRewardPts,
                   COUNT(Id) totalItems
            FROM Order_Line_Item__c WHERE Sales_Order__c = :orderId
        ];
        if (!results.isEmpty()) {
            Sales_Order__c order = new Sales_Order__c(Id = orderId);
            Decimal lineAmount = results[0].get('lineAmount') != null ? (Decimal)results[0].get('lineAmount') : 0;
            Decimal totalAmount = results[0].get('totalAmount') != null ? (Decimal)results[0].get('totalAmount') : 0;
            Decimal tax = results[0].get('totalTax') != null ? (Decimal)results[0].get('totalTax') : 0;
            Decimal disc = results[0].get('totalDiscount') != null ? (Decimal)results[0].get('totalDiscount') : 0;
            Decimal schemeDisc = results[0].get('totalSchemeDiscount') != null ? (Decimal)results[0].get('totalSchemeDiscount') : 0;
            Decimal totalNet = results[0].get('totalNet') != null ? (Decimal)results[0].get('totalNet') : 0;
            Decimal freeQty = results[0].get('totalFreeQty') != null ? (Decimal)results[0].get('totalFreeQty') : 0;
            Decimal rewardPts = results[0].get('totalRewardPts') != null ? (Decimal)results[0].get('totalRewardPts') : 0;

            // Align with trigger handler field mappings
            order.Total_Amount__c = lineAmount;
            order.Total_Gross_Amount__c = totalAmount > 0 ? totalAmount : lineAmount;
            order.Total_Tax__c = tax;
            order.Total_Discount__c = disc;
            order.Discount_Amount__c = disc + schemeDisc;
            order.Scheme_Discount__c = schemeDisc;
            order.Total_Net_Amount__c = totalNet > 0 ? totalNet : (lineAmount - disc - schemeDisc + tax);
            order.Net_Amount__c = totalNet > 0 ? totalNet : (lineAmount - disc - schemeDisc + tax);
            order.Total_Items__c = (Integer)results[0].get('totalItems');
            order.Total_Free_Quantity__c = freeQty;
            order.Total_Reward_Points__c = rewardPts.intValue();
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

    /**
     * @description Returns active warehouses for the warehouse selection dropdown.
     * @return List of warehouse options with Id and Name.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getWarehouses() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (Warehouse__c wh : [
            SELECT Id, Name, Warehouse_Code__c, Warehouse_Type__c, State__c, City__c
            FROM Warehouse__c
            WHERE Is_Active__c = true
            ORDER BY Name ASC
        ]) {
            Map<String, String> opt = new Map<String, String>();
            String label = wh.Name;
            if (String.isNotBlank(wh.Warehouse_Code__c)) {
                label += ' (' + wh.Warehouse_Code__c + ')';
            }
            if (String.isNotBlank(wh.City__c)) {
                label += ' - ' + wh.City__c;
            }
            opt.put('label', label);
            opt.put('value', wh.Id);
            opt.put('warehouseType', wh.Warehouse_Type__c != null ? wh.Warehouse_Type__c : '');
            opt.put('state', wh.State__c != null ? wh.State__c : '');
            options.add(opt);
        }
        return options;
    }

    /**
     * @description Checks stock availability for given products at a warehouse.
     *              Does NOT restrict order creation - only shows available quantities.
     * @param warehouseId The warehouse to check stock at.
     * @param productIds  List of product Ids to check.
     * @return Map of Product Id to available quantity (on hand minus reserved).
     */
    @AuraEnabled
    public static Map<Id, Decimal> checkStockAvailability(Id warehouseId, List<Id> productIds) {
        if (warehouseId == null || productIds == null || productIds.isEmpty()) {
            return new Map<Id, Decimal>();
        }
        return INV_WarehouseStock_Service.checkAvailability(warehouseId, productIds);
    }
}
