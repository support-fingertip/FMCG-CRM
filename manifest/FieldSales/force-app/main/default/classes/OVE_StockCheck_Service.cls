/**
 * @description Service class for Stock Check activity during outlet visits.
 *              Uses existing Distributor_Stock__c and Product_Extension__c objects.
 * @author  SFA Development Team
 * @date    2026
 */
public without sharing class OVE_StockCheck_Service {

    public static final String FEATURE_STOCK_CHECK = 'OVE-010';

    /**
     * Get distributor stock for an account (outlet)
     */
    public static List<Distributor_Stock__c> getDistributorStock(Id accountId) {
        if (!BPM_FeatureToggle_Util.isEnabled(FEATURE_STOCK_CHECK)) {
            return new List<Distributor_Stock__c>();
        }
        return [
            SELECT Id, Name, Product_Ext__c, Product_Ext__r.Name, Opening_Stock__c,
                   Received_Qty__c, Sold_Qty__c, Closing_Stock__c, Damaged_Qty__c,
                   Batch_No__c, Expiry_Date__c, Is_Current__c, Stock_Date__c
            FROM Distributor_Stock__c
            WHERE Account__c = :accountId
              AND Is_Current__c = true
            ORDER BY Product_Ext__r.Name
            LIMIT 200
        ];
    }

    /**
     * Search products for stock check
     */
    public static List<Product_Extension__c> getProductsForStockCheck(String searchTerm) {
        String searchKey = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        return [
            SELECT Id, Name, SKU_Code__c, Product_Category__c, Product_Category__r.Name,
                   Brand__c, Unit_of_Measure__c, MRP__c
            FROM Product_Extension__c
            WHERE Is_Active__c = true
              AND (Name LIKE :searchKey OR SKU_Code__c LIKE :searchKey OR Brand__c LIKE :searchKey)
            ORDER BY Name
            LIMIT 20
        ];
    }

    /**
     * Save stock entries linked to a visit
     */
    public static List<Distributor_Stock__c> saveStockEntries(String stockJson, Id visitId, Id accountId) {
        List<Object> rawEntries = (List<Object>) JSON.deserializeUntyped(stockJson);
        List<Distributor_Stock__c> stockRecords = new List<Distributor_Stock__c>();

        for (Object rawEntry : rawEntries) {
            Map<String, Object> entry = (Map<String, Object>) rawEntry;
            Distributor_Stock__c stock = new Distributor_Stock__c();
            if (entry.containsKey('id') && entry.get('id') != null) {
                stock.Id = (Id) entry.get('id');
            }
            stock.Account__c = accountId;
            stock.Visit__c = visitId;
            stock.Product_Ext__c = (Id) entry.get('productId');
            stock.Opening_Stock__c = toDecimal(entry.get('opening'));
            stock.Received_Qty__c = toDecimal(entry.get('received'));
            stock.Sold_Qty__c = toDecimal(entry.get('sold'));
            stock.Closing_Stock__c = toDecimal(entry.get('closing'));
            stock.Damaged_Qty__c = toDecimal(entry.get('damaged'));
            stock.Batch_No__c = entry.get('batch') != null ? String.valueOf(entry.get('batch')) : null;
            if (entry.containsKey('expiry') && entry.get('expiry') != null) {
                stock.Expiry_Date__c = Date.valueOf(String.valueOf(entry.get('expiry')));
            }
            stock.Stock_Date__c = Date.today();
            stock.Is_Current__c = true;
            stockRecords.add(stock);
        }

        upsert stockRecords;

        // Mark visit as stock check completed
        Visit__c visit = new Visit__c(Id = visitId, Stock_Check_Completed__c = true);
        update visit;

        return stockRecords;
    }

    /**
     * Get last stock check entries for pre-fill
     */
    public static List<Distributor_Stock__c> getLastStockCheck(Id accountId) {
        return [
            SELECT Id, Product_Ext__c, Product_Ext__r.Name, Opening_Stock__c,
                   Received_Qty__c, Sold_Qty__c, Closing_Stock__c, Damaged_Qty__c,
                   Batch_No__c, Expiry_Date__c, Stock_Date__c
            FROM Distributor_Stock__c
            WHERE Account__c = :accountId
              AND Is_Current__c = true
            ORDER BY Product_Ext__r.Name
            LIMIT 200
        ];
    }

    private static Decimal toDecimal(Object val) {
        if (val == null) return 0;
        if (val instanceof Decimal) return (Decimal) val;
        if (val instanceof Integer) return Decimal.valueOf((Integer) val);
        if (val instanceof Long) return Decimal.valueOf((Long) val);
        if (val instanceof Double) return Decimal.valueOf((Double) val);
        return Decimal.valueOf(String.valueOf(val));
    }
}