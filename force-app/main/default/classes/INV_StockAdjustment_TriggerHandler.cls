/**
 * @description Trigger handler for Stock_Adjustment__c. Snapshots current
 *              system quantity on creation and applies stock changes upon approval.
 * @author  SFA Development Team
 * @date    2024
 */
public class INV_StockAdjustment_TriggerHandler extends TriggerHandler {

    protected override void beforeInsert() {
        List<Stock_Adjustment__c> newRecords = (List<Stock_Adjustment__c>) Trigger.new;
        snapshotSystemQty(newRecords);
    }

    protected override void afterUpdate() {
        List<Stock_Adjustment__c> newRecords = (List<Stock_Adjustment__c>) Trigger.new;
        Map<Id, Stock_Adjustment__c> oldMap = (Map<Id, Stock_Adjustment__c>) Trigger.oldMap;

        List<Stock_Adjustment__c> approved = new List<Stock_Adjustment__c>();
        for (Stock_Adjustment__c rec : newRecords) {
            Stock_Adjustment__c oldRec = oldMap.get(rec.Id);
            if (rec.Status__c == 'Approved' && oldRec.Status__c != 'Approved') {
                approved.add(rec);
            }
        }

        if (!approved.isEmpty()) {
            applyAdjustments(approved);
        }
    }

    private void snapshotSystemQty(List<Stock_Adjustment__c> records) {
        Set<Id> warehouseIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        for (Stock_Adjustment__c rec : records) {
            warehouseIds.add(rec.Warehouse__c);
            productIds.add(rec.Product__c);
        }

        Map<String, Decimal> stockMap = new Map<String, Decimal>();
        for (Warehouse_Stock__c stock : [
            SELECT Warehouse__c, Product__c, Batch_Number__c, Qty_On_Hand__c
            FROM Warehouse_Stock__c
            WHERE Warehouse__c IN :warehouseIds AND Product__c IN :productIds
        ]) {
            String key = String.valueOf(stock.Warehouse__c) + '|' +
                         String.valueOf(stock.Product__c) + '|' +
                         (String.isNotBlank(stock.Batch_Number__c) ? stock.Batch_Number__c : '');
            Decimal onHand = stock.Qty_On_Hand__c != null ? stock.Qty_On_Hand__c : 0;
            stockMap.put(key, onHand);
        }

        for (Stock_Adjustment__c rec : records) {
            String key = String.valueOf(rec.Warehouse__c) + '|' +
                         String.valueOf(rec.Product__c) + '|' +
                         (String.isNotBlank(rec.Batch_Number__c) ? rec.Batch_Number__c : '');
            rec.System_Qty__c = stockMap.containsKey(key) ? stockMap.get(key) : 0;
        }
    }

    private void applyAdjustments(List<Stock_Adjustment__c> approvedAdj) {
        for (Stock_Adjustment__c adj : approvedAdj) {
            Decimal qty = adj.Adjustment_Qty__c != null ? adj.Adjustment_Qty__c : 0;
            if (qty == 0 || adj.Product__c == null || adj.Warehouse__c == null) continue;

            List<INV_WarehouseStock_Service.StockLineItem> items =
                new List<INV_WarehouseStock_Service.StockLineItem>();
            items.add(new INV_WarehouseStock_Service.StockLineItem(
                adj.Product__c, adj.Batch_Number__c, Math.abs(qty)
            ));

            if (qty > 0) {
                INV_WarehouseStock_Service.addStock(
                    adj.Warehouse__c, items, adj.Id, 'Stock_Adjustment'
                );
            } else {
                INV_WarehouseStock_Service.adjustDeduct(
                    adj.Warehouse__c, items, adj.Id
                );
            }
        }
    }
}
