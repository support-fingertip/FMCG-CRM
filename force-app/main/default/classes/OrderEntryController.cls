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
    public static List<Product2> searchProducts(String searchTerm, String categoryId) {
        String searchKey = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        String query = 'SELECT Id, Name, ProductCode, Description, IsActive, ' +
                       '(SELECT Id, UnitPrice, Pricebook2Id FROM PricebookEntries WHERE IsActive = true LIMIT 1) ' +
                       'FROM Product2 WHERE IsActive = true AND (Name LIKE :searchKey OR ProductCode LIKE :searchKey)';
        if (String.isNotBlank(categoryId)) {
            query += ' AND Id IN (SELECT Product__c FROM Product_Extension__c WHERE Product_Category__c = :categoryId)';
        }
        query += ' ORDER BY Name LIMIT 50';
        return Database.query(query);
    }

    @AuraEnabled
    public static Sales_Order__c createSalesOrder(Sales_Order__c order, List<Order_Line_Item__c> lineItems) {
        Savepoint sp = Database.setSavepoint();
        try {
            insert order;
            for (Order_Line_Item__c li : lineItems) {
                li.Sales_Order__c = order.Id;
            }
            insert lineItems;
            // Recalculate totals
            updateOrderTotals(order.Id);
            return [SELECT Id, Name, Status__c, Total_Net_Amount__c FROM Sales_Order__c WHERE Id = :order.Id];
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Sales_Order__c getLastOrder(Id accountId) {
        List<Sales_Order__c> orders = [
            SELECT Id, Name, Order_Date__c, Total_Net_Amount__c, Status__c,
                   (SELECT Id, Product__c, Product__r.Name, Quantity__c, Unit_Price__c, Line_Total__c
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
        return [
            SELECT Id, Name, Scheme_Code__c, Scheme_Type__c, Description__c,
                   Start_Date__c, End_Date__c, Max_Discount_Cap__c,
                   (SELECT Id, Slab_Type__c, Min_Value__c, Max_Value__c,
                           Discount_Type__c, Discount_Value__c, Free_Product__c, Free_Quantity__c
                    FROM Scheme_Slabs__r ORDER BY Min_Value__c),
                   (SELECT Id, Product__c, Product__r.Name, Is_Buy_Product__c, Is_Get_Product__c, Min_Quantity__c
                    FROM Scheme_Products__r)
            FROM Scheme__c
            WHERE Status__c = 'Active'
            AND Start_Date__c <= :orderDate
            AND End_Date__c >= :orderDate
            ORDER BY Priority__c
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Product_Extension__c> getProductExtensions(List<Id> productIds) {
        return [SELECT Id, Product__c, HSN_SAC_Code__c, Barcode_UPC__c, Barcode_EAN__c,
                       Case_Size__c, Min_Order_Qty__c, Weight__c, Weight_Unit__c
                FROM Product_Extension__c WHERE Product__c IN :productIds];
    }

    private static void updateOrderTotals(Id orderId) {
        AggregateResult[] results = [
            SELECT SUM(Line_Total__c) totalAmount, SUM(Tax_Amount__c) totalTax,
                   SUM(Discount_Amount__c) totalDiscount, COUNT(Id) totalItems
            FROM Order_Line_Item__c WHERE Sales_Order__c = :orderId
        ];
        if (!results.isEmpty()) {
            Sales_Order__c order = new Sales_Order__c(Id = orderId);
            order.Total_Gross_Amount__c = (Decimal)results[0].get('totalAmount');
            order.Total_Tax__c = (Decimal)results[0].get('totalTax');
            order.Total_Discount__c = (Decimal)results[0].get('totalDiscount');
            order.Total_Items__c = (Integer)results[0].get('totalItems');
            Decimal gross = order.Total_Gross_Amount__c != null ? order.Total_Gross_Amount__c : 0;
            Decimal tax = order.Total_Tax__c != null ? order.Total_Tax__c : 0;
            Decimal disc = order.Total_Discount__c != null ? order.Total_Discount__c : 0;
            order.Total_Net_Amount__c = gross + tax - disc;
            update order;
        }
    }
}