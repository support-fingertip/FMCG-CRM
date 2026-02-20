/**
 * @description Trigger handler for GRN__c. When a GRN is received, adds stock
 *              to the company warehouse via INV_WarehouseStock_Service.
 * @author  SFA Development Team
 * @date    2024
 */
public class INV_GRN_TriggerHandler extends TriggerHandler {

    protected override void afterUpdate() {
        List<GRN__c> newRecords = (List<GRN__c>) Trigger.new;
        Map<Id, GRN__c> oldMap = (Map<Id, GRN__c>) Trigger.oldMap;

        List<GRN__c> receivedGRNs = new List<GRN__c>();
        for (GRN__c grn : newRecords) {
            GRN__c oldGrn = oldMap.get(grn.Id);
            if ((grn.Status__c == 'Received' || grn.Status__c == 'Partial') &&
                oldGrn.Status__c != 'Received' && oldGrn.Status__c != 'Partial') {
                receivedGRNs.add(grn);
            }
        }

        if (!receivedGRNs.isEmpty()) {
            addStockFromGRN(receivedGRNs);
        }
    }

    private void addStockFromGRN(List<GRN__c> receivedGRNs) {
        Set<Id> grnIds = new Set<Id>();
        Set<Id> invoiceIds = new Set<Id>();
        for (GRN__c grn : receivedGRNs) {
            grnIds.add(grn.Id);
            if (grn.Invoice__c != null) {
                invoiceIds.add(grn.Invoice__c);
            }
        }

        // Get warehouse from Invoice → Warehouse__c
        Map<Id, Id> invoiceToWarehouse = new Map<Id, Id>();
        if (!invoiceIds.isEmpty()) {
            for (Invoice__c inv : [
                SELECT Id, Warehouse__c FROM Invoice__c
                WHERE Id IN :invoiceIds AND Warehouse__c != null
            ]) {
                invoiceToWarehouse.put(inv.Id, inv.Warehouse__c);
            }
        }

        // Get GRN line items
        Map<Id, List<GRN_Line__c>> linesByGRN = new Map<Id, List<GRN_Line__c>>();
        for (GRN_Line__c line : [
            SELECT Id, GRN__c, Product__c, Received_Qty__c, Damaged_Qty__c, Batch_No__c
            FROM GRN_Line__c
            WHERE GRN__c IN :grnIds
        ]) {
            if (!linesByGRN.containsKey(line.GRN__c)) {
                linesByGRN.put(line.GRN__c, new List<GRN_Line__c>());
            }
            linesByGRN.get(line.GRN__c).add(line);
        }

        // Process each GRN
        for (GRN__c grn : receivedGRNs) {
            Id warehouseId = grn.Invoice__c != null ? invoiceToWarehouse.get(grn.Invoice__c) : null;
            if (warehouseId == null) {
                continue;
            }

            List<GRN_Line__c> lines = linesByGRN.get(grn.Id);
            if (lines == null || lines.isEmpty()) {
                continue;
            }

            List<INV_WarehouseStock_Service.StockLineItem> stockItems =
                new List<INV_WarehouseStock_Service.StockLineItem>();
            for (GRN_Line__c line : lines) {
                Decimal received = line.Received_Qty__c != null ? line.Received_Qty__c : 0;
                Decimal damaged = line.Damaged_Qty__c != null ? line.Damaged_Qty__c : 0;
                Decimal usable = received - damaged;
                if (usable > 0 && line.Product__c != null) {
                    stockItems.add(new INV_WarehouseStock_Service.StockLineItem(
                        line.Product__c, line.Batch_No__c, usable
                    ));
                }
            }

            if (!stockItems.isEmpty()) {
                INV_WarehouseStock_Service.addStock(warehouseId, stockItems, grn.Id, 'GRN');
            }
        }
    }
}
