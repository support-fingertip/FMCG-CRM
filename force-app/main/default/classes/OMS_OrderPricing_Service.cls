/**
 * @description Service class for calculating order line item pricing including
 *              base price lookup, scheme/discount application, and tax computation.
 *              Designed for bulk invocation from triggers and batch processes.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public without sharing class OMS_OrderPricing_Service {

    /**
     * @description Calculates pricing for order line items by looking up the
     *              applicable price list entry and computing the line total.
     *              Sets Unit_Price__c, Line_Amount__c on each line item.
     *
     * @param lineItems The list of Order_Line_Item__c records to price.
     */
    public static void calculateLineItemPricing(List<Order_Line_Item__c> lineItems) {
        if (lineItems == null || lineItems.isEmpty()) {
            return;
        }

        // Collect product IDs and sales order IDs for price resolution
        Set<Id> productIds = new Set<Id>();
        Set<Id> orderIds = new Set<Id>();

        for (Order_Line_Item__c item : lineItems) {
            if (item.Product__c != null) {
                productIds.add(item.Product__c);
            }
            if (item.Sales_Order__c != null) {
                orderIds.add(item.Sales_Order__c);
            }
        }

        if (productIds.isEmpty()) {
            return;
        }

        // Fetch order details to determine region and channel for price lookup
        Map<Id, Sales_Order__c> orderMap = new Map<Id, Sales_Order__c>();
        if (!orderIds.isEmpty()) {
            orderMap = new Map<Id, Sales_Order__c>([
                SELECT Id, Region__c, Channel__c, Account__c, Order_Date__c
                FROM Sales_Order__c
                WHERE Id IN :orderIds
            ]);
        }

        // Fetch active price list entries for the products
        Map<String, Price_List__c> priceListMap = new Map<String, Price_List__c>();
        for (Price_List__c pl : [
            SELECT Id, Product__c, Region__c, Channel__c,
                   Unit_Price__c, Effective_From__c, Effective_To__c
            FROM Price_List__c
            WHERE Product__c IN :productIds
              AND Is_Active__c = true
              AND Effective_From__c <= TODAY
              AND (Effective_To__c >= TODAY OR Effective_To__c = null)
            ORDER BY Effective_From__c DESC
        ]) {
            // Build composite key for lookup
            String key = String.valueOf(pl.Product__c) + '|' +
                         (String.isNotBlank(pl.Region__c) ? pl.Region__c : '') + '|' +
                         (String.isNotBlank(pl.Channel__c) ? pl.Channel__c : '');
            if (!priceListMap.containsKey(key)) {
                priceListMap.put(key, pl);
            }
        }

        // Calculate pricing for each line item
        for (Order_Line_Item__c item : lineItems) {
            if (item.Product__c == null) {
                continue;
            }

            Decimal quantity = item.Quantity__c != null ? item.Quantity__c : 0;
            Decimal unitPrice = item.Unit_Price__c;

            // Look up price if not manually set
            if (unitPrice == null || unitPrice == 0) {
                Sales_Order__c order = orderMap.get(item.Sales_Order__c);
                String region = (order != null) ? order.Region__c : '';
                String channel = (order != null) ? order.Channel__c : '';

                // Try specific region+channel first, then fall back
                unitPrice = resolvePrice(item.Product__c, region, channel, priceListMap);
                item.Unit_Price__c = unitPrice;
            }

            // Calculate line amount
            Decimal lineAmount = (unitPrice != null ? unitPrice : 0) * quantity;
            item.Line_Amount__c = lineAmount.setScale(2, RoundingMode.HALF_UP);

            // Calculate net amount (after line-level discount)
            Decimal discountPercent = item.Discount_Percent__c != null
                ? item.Discount_Percent__c : 0;
            Decimal discountAmount = (lineAmount * discountPercent / 100)
                .setScale(2, RoundingMode.HALF_UP);
            item.Discount_Amount__c = discountAmount;
            item.Net_Amount__c = (lineAmount - discountAmount).setScale(2, RoundingMode.HALF_UP);
        }
    }

    /**
     * @description Applies eligible promotional schemes to order line items.
     *              Uses the SPM_SchemeEngine_Service to evaluate schemes and
     *              applies discounts or free goods to qualifying items.
     *
     * @param lineItems The list of Order_Line_Item__c records to evaluate.
     */
    public static void applySchemes(List<Order_Line_Item__c> lineItems) {
        if (lineItems == null || lineItems.isEmpty()) {
            return;
        }

        // Collect order IDs for account lookup
        Set<Id> orderIds = new Set<Id>();
        for (Order_Line_Item__c item : lineItems) {
            if (item.Sales_Order__c != null) {
                orderIds.add(item.Sales_Order__c);
            }
        }

        if (orderIds.isEmpty()) {
            return;
        }

        // Fetch parent order details
        Map<Id, Sales_Order__c> orderMap = new Map<Id, Sales_Order__c>([
            SELECT Id, Account__c, Order_Date__c
            FROM Sales_Order__c
            WHERE Id IN :orderIds
        ]);

        // Group line items by order
        Map<Id, List<Order_Line_Item__c>> itemsByOrder = new Map<Id, List<Order_Line_Item__c>>();
        for (Order_Line_Item__c item : lineItems) {
            if (!itemsByOrder.containsKey(item.Sales_Order__c)) {
                itemsByOrder.put(item.Sales_Order__c, new List<Order_Line_Item__c>());
            }
            itemsByOrder.get(item.Sales_Order__c).add(item);
        }

        // Evaluate schemes per order
        for (Id orderId : itemsByOrder.keySet()) {
            Sales_Order__c order = orderMap.get(orderId);
            if (order == null || order.Account__c == null) {
                continue;
            }

            List<Order_Line_Item__c> orderItems = itemsByOrder.get(orderId);
            Date orderDate = order.Order_Date__c != null ? order.Order_Date__c : Date.today();

            List<SPM_SchemeEngine_Service.SchemeResult> schemes =
                SPM_SchemeEngine_Service.getApplicableSchemes(
                    order.Account__c, orderItems, orderDate
                );

            // Apply scheme results to line items
            applySchemeResults(orderItems, schemes);
        }
    }

    /**
     * @description Calculates tax for order line items using the MDM Tax Engine.
     *              Sets CGST__c, SGST__c, IGST__c, and Tax_Amount__c on each item.
     *
     * @param lineItems The list of Order_Line_Item__c records to tax.
     */
    public static void calculateTax(List<Order_Line_Item__c> lineItems) {
        if (lineItems == null || lineItems.isEmpty()) {
            return;
        }

        // Collect order IDs for state lookup
        Set<Id> orderIds = new Set<Id>();
        for (Order_Line_Item__c item : lineItems) {
            if (item.Sales_Order__c != null) {
                orderIds.add(item.Sales_Order__c);
            }
        }

        // Fetch order details with shipping state
        Map<Id, Sales_Order__c> orderMap = new Map<Id, Sales_Order__c>();
        if (!orderIds.isEmpty()) {
            orderMap = new Map<Id, Sales_Order__c>([
                SELECT Id, Shipping_State__c, Warehouse_State__c
                FROM Sales_Order__c
                WHERE Id IN :orderIds
            ]);
        }

        // Prepare bulk tax calculation inputs
        List<Id> productIds = new List<Id>();
        List<Decimal> taxableAmounts = new List<Decimal>();
        List<Order_Line_Item__c> taxableItems = new List<Order_Line_Item__c>();
        String fromState = '';
        String toState = '';

        for (Order_Line_Item__c item : lineItems) {
            if (item.Product__c == null) {
                continue;
            }

            Decimal taxableAmount = item.Net_Amount__c != null ? item.Net_Amount__c : 0;
            if (taxableAmount <= 0) {
                continue;
            }

            Sales_Order__c order = orderMap.get(item.Sales_Order__c);
            if (order != null) {
                fromState = String.isNotBlank(order.Warehouse_State__c)
                    ? order.Warehouse_State__c : '';
                toState = String.isNotBlank(order.Shipping_State__c)
                    ? order.Shipping_State__c : '';
            }

            productIds.add(item.Product__c);
            taxableAmounts.add(taxableAmount);
            taxableItems.add(item);
        }

        if (taxableItems.isEmpty()) {
            return;
        }

        // Bulk calculate tax
        List<MDM_TaxEngine_Service.TaxResult> taxResults =
            MDM_TaxEngine_Service.calculateTaxBulk(productIds, fromState, toState, taxableAmounts);

        // Apply tax results to line items
        for (Integer i = 0; i < taxableItems.size(); i++) {
            Order_Line_Item__c item = taxableItems[i];
            MDM_TaxEngine_Service.TaxResult taxResult = taxResults[i];

            item.CGST__c = taxResult.cgst;
            item.SGST__c = taxResult.sgst;
            item.IGST__c = taxResult.igst;
            item.Tax_Amount__c = taxResult.totalTax;
            item.Tax_Rate__c = taxResult.taxRate;
            item.Total_Amount__c = (item.Net_Amount__c != null ? item.Net_Amount__c : 0)
                + taxResult.totalTax;
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * @description Resolves the unit price by attempting progressively broader
     *              lookups: specific region+channel, then region-only, then
     *              product-only (national price).
     */
    private static Decimal resolvePrice(
        Id productId,
        String region,
        String channel,
        Map<String, Price_List__c> priceListMap
    ) {
        // Try exact match: product + region + channel
        String key = String.valueOf(productId) + '|' +
                     (String.isNotBlank(region) ? region : '') + '|' +
                     (String.isNotBlank(channel) ? channel : '');
        if (priceListMap.containsKey(key)) {
            return priceListMap.get(key).Unit_Price__c;
        }

        // Try region-only: product + region
        key = String.valueOf(productId) + '|' +
              (String.isNotBlank(region) ? region : '') + '|';
        if (priceListMap.containsKey(key)) {
            return priceListMap.get(key).Unit_Price__c;
        }

        // Try product-only (national/default price)
        key = String.valueOf(productId) + '||';
        if (priceListMap.containsKey(key)) {
            return priceListMap.get(key).Unit_Price__c;
        }

        return 0;
    }

    /**
     * @description Applies scheme results (discounts, free goods) to line items.
     */
    private static void applySchemeResults(
        List<Order_Line_Item__c> lineItems,
        List<SPM_SchemeEngine_Service.SchemeResult> schemes
    ) {
        if (schemes == null || schemes.isEmpty()) {
            return;
        }

        for (SPM_SchemeEngine_Service.SchemeResult scheme : schemes) {
            for (Order_Line_Item__c item : lineItems) {
                if (scheme.discountAmount != null && scheme.discountAmount > 0) {
                    Decimal currentDiscount = item.Scheme_Discount__c != null
                        ? item.Scheme_Discount__c : 0;
                    item.Scheme_Discount__c = currentDiscount + scheme.discountAmount;
                    item.Scheme__c = scheme.schemeId;
                }
            }
        }
    }
}