/**
 * @description Service class for validating warehouse stock availability
 *              before order approval. Checks that sufficient stock exists
 *              for all line items in an order.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class OMS_StockAvailability_Service {

    /**
     * @description Validates that warehouse stock is available for the given orders.
     *              Adds errors to orders where stock is insufficient.
     * @param orderIds Set of Sales_Order__c Ids to validate.
     * @return Map of orderId to list of shortage messages (empty list = sufficient stock).
     */
    public static Map<Id, List<String>> validateStockAvailability(Set<Id> orderIds) {
        Map<Id, List<String>> shortages = new Map<Id, List<String>>();
        for (Id orderId : orderIds) {
            shortages.put(orderId, new List<String>());
        }

        // Get all line items for the orders
        List<Order_Line_Item__c> lineItems = [
            SELECT Id, Sales_Order__c, Product_Ext__c, Product_Ext__r.Name,
                   Quantity__c, Sales_Order__r.Warehouse__c
            FROM Order_Line_Item__c
            WHERE Sales_Order__c IN :orderIds
        ];

        if (lineItems.isEmpty()) return shortages;

        // Collect required products and warehouses
        Set<Id> productIds = new Set<Id>();
        Set<Id> warehouseIds = new Set<Id>();
        for (Order_Line_Item__c li : lineItems) {
            if (li.Product_Ext__c != null) productIds.add(li.Product_Ext__c);
            if (li.Sales_Order__r.Warehouse__c != null) warehouseIds.add(li.Sales_Order__r.Warehouse__c);
        }

        if (productIds.isEmpty() || warehouseIds.isEmpty()) return shortages;

        // Get current stock levels
        Map<String, Decimal> stockMap = new Map<String, Decimal>();
        for (Warehouse_Stock__c ws : [
            SELECT Product_Ext__c, Warehouse__c, Qty_On_Hand__c, Qty_Reserved__c
            FROM Warehouse_Stock__c
            WHERE Product_Ext__c IN :productIds
              AND Warehouse__c IN :warehouseIds
        ]) {
            String key = ws.Warehouse__c + '|' + ws.Product_Ext__c;
            Decimal available = (ws.Qty_On_Hand__c != null ? ws.Qty_On_Hand__c : 0)
                              - (ws.Qty_Reserved__c != null ? ws.Qty_Reserved__c : 0);
            stockMap.put(key, available);
        }

        // Aggregate demand per order per product per warehouse
        Map<String, Decimal> demandMap = new Map<String, Decimal>();
        Map<String, Id> demandToOrder = new Map<String, Id>();
        Map<String, String> demandToProduct = new Map<String, String>();

        for (Order_Line_Item__c li : lineItems) {
            if (li.Product_Ext__c == null || li.Sales_Order__r.Warehouse__c == null) continue;

            String key = li.Sales_Order__r.Warehouse__c + '|' + li.Product_Ext__c;
            Decimal current = demandMap.containsKey(key) ? demandMap.get(key) : 0;
            demandMap.put(key, current + (li.Quantity__c != null ? li.Quantity__c : 0));
            demandToOrder.put(key, li.Sales_Order__c);
            demandToProduct.put(key, li.Product_Ext__r.Name);
        }

        // Check availability
        for (String key : demandMap.keySet()) {
            Decimal demanded = demandMap.get(key);
            Decimal available = stockMap.containsKey(key) ? stockMap.get(key) : 0;

            if (demanded > available) {
                Id orderId = demandToOrder.get(key);
                String productName = demandToProduct.get(key);
                shortages.get(orderId).add(
                    productName + ': required ' + demanded + ', available ' + available
                );
            }
        }

        return shortages;
    }
}