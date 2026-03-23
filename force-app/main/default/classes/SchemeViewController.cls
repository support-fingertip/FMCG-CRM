/**
 * @description Controller for the Scheme View LWC component.
 *              Manages trade promotion schemes - filtering, detail retrieval,
 *              discount/benefit calculation, and order-level scheme application
 *              for the FMCG scheme engine (4x6 matrix).
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class SchemeViewController {

    // ── Get Active Schemes ──────────────────────────────────────────────────

    /**
     * @description Retrieves active schemes filtered by category, type, and channel.
     * @param schemeCategory The scheme category (Free Products, Discount in %, etc.).
     * @param schemeType     The scheme type (Same Product (QTY), Invoice Val Based, etc.).
     * @param channel        The sales channel.
     * @return List of active Scheme__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Scheme__c> getActiveSchemes(String schemeCategory, String schemeType, String channel) {
        Date today = Date.today();
        String query = 'SELECT Id, Name, Scheme_Code__c, Scheme_Category__c, Scheme_Type__c, ' +
                       'Description__c, Start_Date__c, End_Date__c, Status__c, Channel__c, ' +
                       'Discount_Percent__c, Discount_Amount__c, Price_Discount__c, ' +
                       'Reward_Points__c, MOV__c, ' +
                       'Free_Product_Ext__c, Free_Product_Ext__r.Name, Free_Quantity__c, ' +
                       'Min_Quantity__c, Max_Quantity__c, Min_Value__c, Max_Value__c, ' +
                       'Invoice_Qty_Threshold__c, Invoice_Qty_UOM__c, Invoice_Val_Threshold__c, ' +
                       'Max_Discount_Cap__c, Priority__c, Is_Stackable__c, ' +
                       'Budget_Amount__c, Budget_Remaining__c, ' +
                       '(SELECT Id, Slab_Type__c, Min_Value__c, Max_Value__c, ' +
                       '        Min_Quantity__c, Max_Quantity__c, ' +
                       '        Discount_Type__c, Discount_Value__c, Discount_Percent__c, Discount_Amount__c, ' +
                       '        Price_Discount__c, Reward_Points__c, ' +
                       '        Free_Product_Ext__c, Free_Product_Ext__r.Name, Free_Quantity__c ' +
                       ' FROM Scheme_Slabs__r WHERE Is_Active__c = true ORDER BY Min_Value__c), ' +
                       '(SELECT Id, Product_Ext__c, Product_Ext__r.Name, Product_Ext__r.SKU_Code__c, ' +
                       '        Is_Buy_Product__c, Is_Get_Product__c, Min_Quantity__c, Product_Classification__c ' +
                       ' FROM Scheme_Products__r ORDER BY Product_Ext__r.Name) ' +
                       'FROM Scheme__c ' +
                       'WHERE Status__c = \'Active\' ' +
                       'AND Is_Active__c = true ' +
                       'AND Start_Date__c <= :today ' +
                       'AND (End_Date__c >= :today OR End_Date__c = null)';

        if (String.isNotBlank(schemeCategory)) {
            query += ' AND Scheme_Category__c = :schemeCategory';
        }
        if (String.isNotBlank(schemeType)) {
            query += ' AND Scheme_Type__c = :schemeType';
        }
        if (String.isNotBlank(channel)) {
            query += ' AND (Channel__c = :channel OR Channel__c = null)';
        }

        query += ' ORDER BY Priority__c ASC NULLS LAST, Name LIMIT 100';

        return Database.query(query);
    }

    // ── Get Scheme Details ──────────────────────────────────────────────────

    /**
     * @description Retrieves full details of a single scheme including slabs, products, and mappings.
     * @param schemeId The Scheme__c record Id.
     * @return The Scheme__c record with child records.
     */
    @AuraEnabled(cacheable=true)
    public static Scheme__c getSchemeDetails(Id schemeId) {
        List<Scheme__c> schemes = [
            SELECT Id, Name, Scheme_Code__c, Scheme_Category__c, Scheme_Type__c,
                   Description__c, Start_Date__c, End_Date__c, Status__c, Channel__c,
                   Discount_Percent__c, Discount_Amount__c, Price_Discount__c,
                   Reward_Points__c, MOV__c,
                   Free_Product_Ext__c, Free_Product_Ext__r.Name, Free_Quantity__c,
                   Min_Quantity__c, Max_Quantity__c, Min_Value__c, Max_Value__c,
                   Invoice_Qty_Threshold__c, Invoice_Qty_UOM__c, Invoice_Val_Threshold__c,
                   Base_UOM__c, Base_UOM__r.Name, Base_UOM__r.UOM_Code__c,
                   Max_Discount_Cap__c, Priority__c, Is_Stackable__c,
                   Budget_Amount__c, Budget_Used__c, Budget_Remaining__c,
                   Applicable_Channel__c, Applicable_Outlet_Type__c, Applicable_Region__c,
                   (SELECT Id, Slab_Type__c, Min_Value__c, Max_Value__c,
                           Min_Quantity__c, Max_Quantity__c,
                           Discount_Type__c, Discount_Value__c, Discount_Percent__c, Discount_Amount__c,
                           Price_Discount__c, Reward_Points__c,
                           Free_Product_Ext__c, Free_Product_Ext__r.Name, Free_Quantity__c
                    FROM Scheme_Slabs__r WHERE Is_Active__c = true ORDER BY Min_Value__c),
                   (SELECT Id, Product_Ext__c, Product_Ext__r.Name, Product_Ext__r.SKU_Code__c,
                           Is_Buy_Product__c, Is_Get_Product__c, Min_Quantity__c, Product_Classification__c
                    FROM Scheme_Products__r ORDER BY Product_Ext__r.Name),
                   (SELECT Id, Territory__c, Territory__r.Name,
                           Zone__c, Sub_Zone__c, District__c, Area__c,
                           Account__c, Account__r.Name, Customer_Type__c
                    FROM Scheme_Mappings__r WHERE Is_Active__c = true)
            FROM Scheme__c
            WHERE Id = :schemeId
            LIMIT 1
        ];
        if (schemes.isEmpty()) {
            throw new AuraHandledException('Scheme not found.');
        }
        return schemes[0];
    }

    // ── Calculate Scheme Discount ───────────────────────────────────────────

    /**
     * @description Calculates the applicable benefit for a given scheme based on
     *              the order quantity and value using slab evaluation.
     * @param schemeId The Scheme__c record Id.
     * @param quantity The order quantity.
     * @param value    The order value.
     * @return Map containing benefit details.
     */
    @AuraEnabled
    public static Map<String, Object> calculateSchemeDiscount(Id schemeId, Decimal quantity, Decimal value) {
        try {
            Map<String, Object> result = new Map<String, Object>();
            result.put('discountAmount', 0);
            result.put('discountPercent', 0);
            result.put('priceDiscount', 0);
            result.put('freeProduct', null);
            result.put('freeProductName', '');
            result.put('freeQuantity', 0);
            result.put('rewardPoints', 0);
            result.put('appliedSlabId', null);
            result.put('discountType', null);
            result.put('schemeCategory', null);

            Scheme__c scheme = [
                SELECT Id, Name, Scheme_Category__c, Scheme_Type__c, Max_Discount_Cap__c,
                       Discount_Percent__c, Discount_Amount__c, Price_Discount__c,
                       Reward_Points__c, Free_Product_Ext__c, Free_Product_Ext__r.Name,
                       Free_Quantity__c, MOV__c,
                       (SELECT Id, Slab_Type__c, Min_Value__c, Max_Value__c,
                               Min_Quantity__c, Max_Quantity__c,
                               Discount_Type__c, Discount_Value__c, Discount_Percent__c,
                               Discount_Amount__c, Price_Discount__c, Reward_Points__c,
                               Free_Product_Ext__c, Free_Product_Ext__r.Name, Free_Quantity__c
                        FROM Scheme_Slabs__r WHERE Is_Active__c = true ORDER BY Min_Value__c DESC)
                FROM Scheme__c
                WHERE Id = :schemeId
                LIMIT 1
            ];

            result.put('schemeCategory', scheme.Scheme_Category__c);

            // If scheme has slabs, evaluate against them
            if (scheme.Scheme_Slabs__r != null && !scheme.Scheme_Slabs__r.isEmpty()) {
                Scheme_Slab__c appliedSlab = null;

                for (Scheme_Slab__c slab : scheme.Scheme_Slabs__r) {
                    Decimal compareValue;
                    if (slab.Slab_Type__c == 'Quantity') {
                        compareValue = quantity != null ? quantity : 0;
                    } else {
                        compareValue = value != null ? value : 0;
                    }

                    Boolean meetsMin = slab.Min_Value__c == null || compareValue >= slab.Min_Value__c;
                    Boolean meetsMax = slab.Max_Value__c == null || compareValue <= slab.Max_Value__c;

                    if (meetsMin && meetsMax) {
                        appliedSlab = slab;
                        break;
                    }
                    if (meetsMin && slab.Max_Value__c == null) {
                        appliedSlab = slab;
                        break;
                    }
                }

                if (appliedSlab == null) {
                    return result;
                }

                result.put('appliedSlabId', appliedSlab.Id);
                result.put('discountType', appliedSlab.Discount_Type__c);

                Decimal discountAmount = 0;
                Decimal discountPercent = 0;

                if (appliedSlab.Discount_Type__c == 'Percent') {
                    discountPercent = appliedSlab.Discount_Value__c != null ? appliedSlab.Discount_Value__c
                        : (appliedSlab.Discount_Percent__c != null ? appliedSlab.Discount_Percent__c : 0);
                    Decimal baseValue = value != null ? value : 0;
                    discountAmount = (baseValue * discountPercent / 100).setScale(2, RoundingMode.HALF_UP);
                } else if (appliedSlab.Discount_Type__c == 'Amount') {
                    discountAmount = appliedSlab.Discount_Value__c != null ? appliedSlab.Discount_Value__c
                        : (appliedSlab.Discount_Amount__c != null ? appliedSlab.Discount_Amount__c : 0);
                    if (value != null && value > 0) {
                        discountPercent = (discountAmount / value * 100).setScale(2, RoundingMode.HALF_UP);
                    }
                } else if (appliedSlab.Discount_Type__c == 'Free Product') {
                    result.put('freeProduct', appliedSlab.Free_Product_Ext__c);
                    result.put('freeProductName', appliedSlab.Free_Product_Ext__r != null
                        ? appliedSlab.Free_Product_Ext__r.Name : '');
                    result.put('freeQuantity', appliedSlab.Free_Quantity__c != null
                        ? appliedSlab.Free_Quantity__c : 0);
                } else if (appliedSlab.Discount_Type__c == 'Price Discount') {
                    Decimal priceDisc = appliedSlab.Price_Discount__c != null ? appliedSlab.Price_Discount__c : 0;
                    result.put('priceDiscount', priceDisc);
                    discountAmount = priceDisc;
                } else if (appliedSlab.Discount_Type__c == 'Reward Points') {
                    result.put('rewardPoints', appliedSlab.Reward_Points__c != null
                        ? appliedSlab.Reward_Points__c : 0);
                }

                // Apply discount cap
                if (scheme.Max_Discount_Cap__c != null && discountAmount > scheme.Max_Discount_Cap__c) {
                    discountAmount = scheme.Max_Discount_Cap__c;
                    if (value != null && value > 0) {
                        discountPercent = (discountAmount / value * 100).setScale(2, RoundingMode.HALF_UP);
                    }
                }

                result.put('discountAmount', discountAmount);
                result.put('discountPercent', discountPercent);

            } else {
                // No slabs - use scheme-level fields directly
                String category = scheme.Scheme_Category__c;

                if (category == 'Free Products') {
                    result.put('freeProduct', scheme.Free_Product_Ext__c);
                    result.put('freeProductName', scheme.Free_Product_Ext__r != null
                        ? scheme.Free_Product_Ext__r.Name : '');
                    result.put('freeQuantity', scheme.Free_Quantity__c != null
                        ? scheme.Free_Quantity__c : 0);
                    result.put('discountType', 'Free Product');
                } else if (category == 'Discount in %') {
                    Decimal pct = scheme.Discount_Percent__c != null ? scheme.Discount_Percent__c : 0;
                    Decimal baseValue = value != null ? value : 0;
                    result.put('discountPercent', pct);
                    result.put('discountAmount', (baseValue * pct / 100).setScale(2, RoundingMode.HALF_UP));
                    result.put('discountType', 'Percent');
                } else if (category == 'Discount in Value') {
                    Decimal priceDisc = scheme.Price_Discount__c != null ? scheme.Price_Discount__c
                        : (scheme.Discount_Amount__c != null ? scheme.Discount_Amount__c : 0);
                    result.put('priceDiscount', priceDisc);
                    result.put('discountAmount', priceDisc);
                    result.put('discountType', 'Price Discount');
                } else if (category == 'Reward Points') {
                    result.put('rewardPoints', scheme.Reward_Points__c != null
                        ? scheme.Reward_Points__c : 0);
                    result.put('discountType', 'Reward Points');
                }
            }

            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Apply Schemes to Order ──────────────────────────────────────────────

    /**
     * @description Applies all applicable schemes to a sales order.
     * @param orderId   The Sales_Order__c Id.
     * @param accountId The outlet Account Id.
     * @return Map with scheme application results.
     */
    @AuraEnabled
    public static Map<String, Object> applySchemeToOrder(Id orderId, Id accountId) {
        try {
            return SPM_SchemeEngine_Service.applySchemeToOrder(orderId, accountId, Date.today());
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
