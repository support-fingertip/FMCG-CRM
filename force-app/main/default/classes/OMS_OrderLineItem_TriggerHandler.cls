/**
 * @description Trigger handler for Order_Line_Item__c. Invokes pricing, scheme,
 *              and tax calculation services, and maintains order header totals.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public class OMS_OrderLineItem_TriggerHandler extends TriggerHandler {

    // ── Before Insert ─────────────────────────────────────────────────────────

    /**
     * @description Calculates unit pricing, applies schemes, and computes tax
     *              for new line items.
     */
    protected override void beforeInsert() {
        List<Order_Line_Item__c> newRecords = (List<Order_Line_Item__c>) Trigger.new;
        OMS_OrderPricing_Service.calculateLineItemPricing(newRecords);
        OMS_OrderPricing_Service.applySchemes(newRecords);
        OMS_OrderPricing_Service.calculateTax(newRecords);
    }

    // ── Before Update ─────────────────────────────────────────────────────────

    /**
     * @description Recalculates pricing when quantity, product, or discount changes.
     */
    protected override void beforeUpdate() {
        List<Order_Line_Item__c> newRecords = (List<Order_Line_Item__c>) Trigger.new;
        Map<Id, Order_Line_Item__c> oldMap = (Map<Id, Order_Line_Item__c>) Trigger.oldMap;

        List<Order_Line_Item__c> pricingChanged = new List<Order_Line_Item__c>();
        for (Order_Line_Item__c rec : newRecords) {
            Order_Line_Item__c oldRec = oldMap.get(rec.Id);
            if (rec.Quantity__c != oldRec.Quantity__c ||
                rec.Product__c != oldRec.Product__c ||
                rec.Discount_Percent__c != oldRec.Discount_Percent__c ||
                rec.Unit_Price__c != oldRec.Unit_Price__c) {
                pricingChanged.add(rec);
            }
        }

        if (!pricingChanged.isEmpty()) {
            OMS_OrderPricing_Service.calculateLineItemPricing(pricingChanged);
            OMS_OrderPricing_Service.applySchemes(pricingChanged);
            OMS_OrderPricing_Service.calculateTax(pricingChanged);
        }
    }

    // ── After Insert ──────────────────────────────────────────────────────────

    /**
     * @description Updates parent Sales_Order__c header totals after line items
     *              are inserted.
     */
    protected override void afterInsert() {
        List<Order_Line_Item__c> newRecords = (List<Order_Line_Item__c>) Trigger.new;
        updateOrderTotals(newRecords);
    }

    // ── After Update ──────────────────────────────────────────────────────────

    /**
     * @description Updates parent Sales_Order__c header totals after line items
     *              are modified.
     */
    protected override void afterUpdate() {
        List<Order_Line_Item__c> newRecords = (List<Order_Line_Item__c>) Trigger.new;
        updateOrderTotals(newRecords);
    }

    // ── After Delete ──────────────────────────────────────────────────────────

    /**
     * @description Updates parent Sales_Order__c header totals after line items
     *              are deleted.
     */
    protected override void afterDelete() {
        List<Order_Line_Item__c> oldRecords = (List<Order_Line_Item__c>) Trigger.old;
        updateOrderTotals(oldRecords);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * @description Recalculates and updates the parent Sales_Order__c header totals
     *              (subtotal, tax, discount, net amount) from line item aggregates.
     * @param lineItems The line items whose parent orders need total recalculation.
     */
    private void updateOrderTotals(List<Order_Line_Item__c> lineItems) {
        Set<Id> orderIds = new Set<Id>();
        for (Order_Line_Item__c item : lineItems) {
            if (item.Sales_Order__c != null) {
                orderIds.add(item.Sales_Order__c);
            }
        }

        if (orderIds.isEmpty()) {
            return;
        }

        // Aggregate line item totals per order
        Map<Id, Sales_Order__c> ordersToUpdate = new Map<Id, Sales_Order__c>();
        for (AggregateResult ar : [
            SELECT Sales_Order__c orderId,
                   SUM(Line_Amount__c) sumLineAmount,
                   SUM(Discount_Amount__c) sumDiscount,
                   SUM(Scheme_Discount__c) sumSchemeDiscount,
                   SUM(Tax_Amount__c) sumTax,
                   SUM(Total_Amount__c) sumTotal,
                   SUM(Net_Amount__c) sumNet
            FROM Order_Line_Item__c
            WHERE Sales_Order__c IN :orderIds
            GROUP BY Sales_Order__c
        ]) {
            Id orderId = (Id) ar.get('orderId');
            Decimal lineAmount = ar.get('sumLineAmount') != null
                ? (Decimal) ar.get('sumLineAmount') : 0;
            Decimal discount = ar.get('sumDiscount') != null
                ? (Decimal) ar.get('sumDiscount') : 0;
            Decimal schemeDiscount = ar.get('sumSchemeDiscount') != null
                ? (Decimal) ar.get('sumSchemeDiscount') : 0;
            Decimal tax = ar.get('sumTax') != null
                ? (Decimal) ar.get('sumTax') : 0;
            Decimal total = ar.get('sumTotal') != null
                ? (Decimal) ar.get('sumTotal') : 0;
            Decimal net = ar.get('sumNet') != null
                ? (Decimal) ar.get('sumNet') : 0;

            ordersToUpdate.put(orderId, new Sales_Order__c(
                Id = orderId,
                Total_Amount__c    = lineAmount,
                Discount_Amount__c = discount + schemeDiscount,
                Total_Tax__c       = tax,
                Net_Amount__c      = total
            ));
        }

        // Handle orders with no remaining line items (all deleted)
        for (Id orderId : orderIds) {
            if (!ordersToUpdate.containsKey(orderId)) {
                ordersToUpdate.put(orderId, new Sales_Order__c(
                    Id = orderId,
                    Total_Amount__c    = 0,
                    Discount_Amount__c = 0,
                    Total_Tax__c       = 0,
                    Net_Amount__c      = 0
                ));
            }
        }

        if (!ordersToUpdate.isEmpty()) {
            TriggerHandler.bypass('OMS_SalesOrder_TriggerHandler');
            update ordersToUpdate.values();
            TriggerHandler.clearBypass('OMS_SalesOrder_TriggerHandler');
        }
    }
}