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
            SELECT Id, Name, Product__c, Product__r.Name, Opening_Stock__c,
                   Received_Qty__c, Sold_Qty__c, Closing_Stock__c, Damaged_Qty__c,
                   Batch_No__c, Expiry_Date__c, Is_Current__c, Stock_Date__c
            FROM Distributor_Stock__c
            WHERE Account__c = :accountId
              AND Is_Current__c = true
            ORDER BY Product__r.Name
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
        List<Map<String, Object>> entries = (List<Map<String, Object>>) JSON.deserializeUntyped(stockJson);
        List<Distributor_Stock__c> stockRecords = new List<Distributor_Stock__c>();

        for (Map<String, Object> entry : entries) {
            Distributor_Stock__c stock = new Distributor_Stock__c();
            if (entry.containsKey('id') && entry.get('id') != null) {
                stock.Id = (Id) entry.get('id');
            }
            stock.Account__c = accountId;
            stock.Visit__c = visitId;
            stock.Product__c = (Id) entry.get('productId');
            stock.Opening_Stock__c = entry.containsKey('opening') ? ((Decimal) entry.get('opening')) : 0;
            stock.Received_Qty__c = entry.containsKey('received') ? ((Decimal) entry.get('received')) : 0;
            stock.Sold_Qty__c = entry.containsKey('sold') ? ((Decimal) entry.get('sold')) : 0;
            stock.Closing_Stock__c = entry.containsKey('closing') ? ((Decimal) entry.get('closing')) : 0;
            stock.Damaged_Qty__c = entry.containsKey('damaged') ? ((Decimal) entry.get('damaged')) : 0;
            stock.Batch_No__c = (String) entry.get('batch');
            if (entry.containsKey('expiry') && entry.get('expiry') != null) {
                stock.Expiry_Date__c = Date.valueOf((String) entry.get('expiry'));
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
            SELECT Id, Product__c, Product__r.Name, Opening_Stock__c,
                   Received_Qty__c, Sold_Qty__c, Closing_Stock__c, Damaged_Qty__c,
                   Batch_No__c, Expiry_Date__c, Stock_Date__c
            FROM Distributor_Stock__c
            WHERE Account__c = :accountId
              AND Is_Current__c = true
            ORDER BY Product__r.Name
            LIMIT 200
        ];
    }
}
