/**
 * @description Controller for the Scheme View LWC component.
 *              Manages trade promotion schemes - filtering, detail retrieval,
 *              slab-based discount calculation for FMCG channel promotions.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class SchemeViewController {

    // ── Get Active Schemes ──────────────────────────────────────────────────────

    /**
     * @description Retrieves active schemes filtered by type, product category, and channel.
     *              All filters are optional; omitted filters are ignored.
     * @param schemeType  The scheme type (e.g. 'Quantity Discount', 'Buy X Get Y', 'Flat Discount').
     * @param categoryId  The Product_Category__c Id to filter scheme products.
     * @param channel     The sales channel (e.g. 'General Trade', 'Modern Trade').
     * @return List of active Scheme__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Scheme__c> getActiveSchemes(String schemeType, String categoryId, String channel) {
        Date today = Date.today();
        String query = 'SELECT Id, Name, Scheme_Code__c, Scheme_Type__c, Description__c, ' +
                       'Start_Date__c, End_Date__c, Status__c, Channel__c, ' +
                       'Max_Discount_Cap__c, Priority__c, ' +
                       '(SELECT Id, Slab_Type__c, Min_Value__c, Max_Value__c, ' +
                       '        Discount_Type__c, Discount_Value__c, Free_Product__c, Free_Quantity__c ' +
                       ' FROM Scheme_Slabs__r ORDER BY Min_Value__c), ' +
                       '(SELECT Id, Product__c, Product__r.Name, Product__r.ProductCode, ' +
                       '        Is_Buy_Product__c, Is_Get_Product__c, Min_Quantity__c ' +
                       ' FROM Scheme_Products__r ORDER BY Product__r.Name) ' +
                       'FROM Scheme__c ' +
                       'WHERE Status__c = \'Active\' ' +
                       'AND Start_Date__c <= :today ' +
                       'AND End_Date__c >= :today';

        if (String.isNotBlank(schemeType)) {
            query += ' AND Scheme_Type__c = :schemeType';
        }
        if (String.isNotBlank(channel)) {
            query += ' AND (Channel__c = :channel OR Channel__c = \'All\')';
        }
        if (String.isNotBlank(categoryId)) {
            query += ' AND Id IN (SELECT Scheme__c FROM Scheme_Product__c ' +
                     'WHERE Product__c IN (SELECT Product__c FROM Product_Extension__c WHERE Product_Category__c = :categoryId))';
        }

        query += ' ORDER BY Priority__c, Name LIMIT 100';

        return Database.query(query);
    }

    // ── Get Scheme Details ──────────────────────────────────────────────────────

    /**
     * @description Retrieves full details of a single scheme including all slabs and products.
     * @param schemeId The Scheme__c record Id.
     * @return The Scheme__c record with child Scheme_Slab__c and Scheme_Product__c records.
     */
    @AuraEnabled(cacheable=true)
    public static Scheme__c getSchemeDetails(Id schemeId) {
        List<Scheme__c> schemes = [
            SELECT Id, Name, Scheme_Code__c, Scheme_Type__c, Description__c,
                   Start_Date__c, End_Date__c, Status__c, Channel__c,
                   Max_Discount_Cap__c, Priority__c,
                   (SELECT Id, Slab_Type__c, Min_Value__c, Max_Value__c,
                           Discount_Type__c, Discount_Value__c,
                           Free_Product__c, Free_Product__r.Name, Free_Quantity__c
                    FROM Scheme_Slabs__r ORDER BY Min_Value__c),
                   (SELECT Id, Product__c, Product__r.Name, Product__r.ProductCode,
                           Is_Buy_Product__c, Is_Get_Product__c, Min_Quantity__c
                    FROM Scheme_Products__r ORDER BY Product__r.Name)
            FROM Scheme__c
            WHERE Id = :schemeId
            LIMIT 1
        ];
        if (schemes.isEmpty()) {
            throw new AuraHandledException('Scheme not found.');
        }
        return schemes[0];
    }

    // ── Calculate Scheme Discount ───────────────────────────────────────────────

    /**
     * @description Calculates the applicable discount for a given scheme based on
     *              the order quantity and value. Evaluates slab conditions to
     *              determine the correct discount tier.
     * @param schemeId The Scheme__c record Id.
     * @param quantity The order quantity (units or cases).
     * @param value    The order value (amount).
     * @return Map containing discountAmount, discountPercent, freeProduct, freeQuantity,
     *         appliedSlabId, and discountType.
     */
    @AuraEnabled
    public static Map<String, Object> calculateSchemeDiscount(Id schemeId, Decimal quantity, Decimal value) {
        try {
            Map<String, Object> result = new Map<String, Object>();
            result.put('discountAmount', 0);
            result.put('discountPercent', 0);
            result.put('freeProduct', null);
            result.put('freeQuantity', 0);
            result.put('appliedSlabId', null);
            result.put('discountType', null);

            Scheme__c scheme = [
                SELECT Id, Name, Scheme_Type__c, Max_Discount_Cap__c,
                       (SELECT Id, Slab_Type__c, Min_Value__c, Max_Value__c,
                               Discount_Type__c, Discount_Value__c,
                               Free_Product__c, Free_Product__r.Name, Free_Quantity__c
                        FROM Scheme_Slabs__r ORDER BY Min_Value__c DESC)
                FROM Scheme__c
                WHERE Id = :schemeId
                LIMIT 1
            ];

            if (scheme.Scheme_Slabs__r == null || scheme.Scheme_Slabs__r.isEmpty()) {
                return result;
            }

            // Find the applicable slab (highest qualifying tier)
            Scheme_Slab__c appliedSlab = null;
            for (Scheme_Slab__c slab : scheme.Scheme_Slabs__r) {
                Decimal compareValue;
                if (slab.Slab_Type__c == 'Quantity') {
                    compareValue = quantity != null ? quantity : 0;
                } else {
                    // Value-based slab
                    compareValue = value != null ? value : 0;
                }

                Boolean meetsMin = slab.Min_Value__c == null || compareValue >= slab.Min_Value__c;
                Boolean meetsMax = slab.Max_Value__c == null || compareValue <= slab.Max_Value__c;

                if (meetsMin && meetsMax) {
                    appliedSlab = slab;
                    break; // Slabs sorted DESC; first match is highest qualifying tier
                }
                // Also check if value exceeds max of this slab (for open-ended top slabs)
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

            // Calculate discount based on type
            Decimal discountAmount = 0;
            Decimal discountPercent = 0;

            if (appliedSlab.Discount_Type__c == 'Percentage') {
                discountPercent = appliedSlab.Discount_Value__c != null ? appliedSlab.Discount_Value__c : 0;
                Decimal baseValue = value != null ? value : 0;
                discountAmount = (baseValue * discountPercent / 100).setScale(2, RoundingMode.HALF_UP);
            } else if (appliedSlab.Discount_Type__c == 'Flat') {
                discountAmount = appliedSlab.Discount_Value__c != null ? appliedSlab.Discount_Value__c : 0;
                if (value != null && value > 0) {
                    discountPercent = (discountAmount / value * 100).setScale(2, RoundingMode.HALF_UP);
                }
            } else if (appliedSlab.Discount_Type__c == 'Free Product') {
                result.put('freeProduct', appliedSlab.Free_Product__c);
                result.put('freeProductName', appliedSlab.Free_Product__r != null
                    ? appliedSlab.Free_Product__r.Name : '');
                result.put('freeQuantity', appliedSlab.Free_Quantity__c != null
                    ? appliedSlab.Free_Quantity__c : 0);
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

            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
