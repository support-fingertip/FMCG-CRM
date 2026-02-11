/**
 * @description Controller for the Outlet 360-degree View LWC component.
 *              Provides a comprehensive view of an outlet (Account) including details,
 *              recent orders, outstanding balances, visit history, and MTD KPIs.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class OutletThreeSixtyController {

    // ── Get Outlet Details ──────────────────────────────────────────────────────

    /**
     * @description Retrieves full Account details including standard and custom fields
     *              relevant to the FMCG outlet profile.
     * @param accountId The Account (outlet) Id.
     * @return The Account record with all relevant fields.
     */
    @AuraEnabled(cacheable=true)
    public static Account getOutletDetails(Id accountId) {
        List<Account> accounts = [
            SELECT Id, Name, AccountNumber, Type, Industry, Phone, Fax,
                   Website, Description, OwnerId, Owner.Name,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   ShippingLatitude, ShippingLongitude,
                   CreatedDate, LastModifiedDate
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            throw new AuraHandledException('Outlet not found.');
        }
        return accounts[0];
    }

    // ── Get Recent Orders ───────────────────────────────────────────────────────

    /**
     * @description Retrieves recent sales orders for an outlet.
     * @param accountId  The Account (outlet) Id.
     * @param limitCount Maximum number of orders to return.
     * @return List of Sales_Order__c records with line item summaries.
     */
    @AuraEnabled(cacheable=true)
    public static List<Sales_Order__c> getRecentOrders(Id accountId, Integer limitCount) {
        Integer queryLimit = (limitCount != null && limitCount > 0) ? limitCount : 10;
        // Cap at 100 to prevent excessive queries
        if (queryLimit > 100) {
            queryLimit = 100;
        }

        return Database.query(
            'SELECT Id, Name, Order_Date__c, Status__c, Order_Type__c, ' +
            'Total_Gross_Amount__c, Total_Discount__c, Total_Tax__c, Total_Net_Amount__c, ' +
            'Total_Items__c, Salesperson__c, Salesperson__r.Name, ' +
            'Delivery_Date__c, Channel__c, Notes__c, ' +
            '(SELECT Id, Product__c, Product__r.Name, Product__r.ProductCode, ' +
            '        Quantity__c, Unit_Price__c, Discount_Amount__c, Tax_Amount__c, Line_Total__c ' +
            ' FROM Order_Line_Items__r ORDER BY CreatedDate LIMIT 200) ' +
            'FROM Sales_Order__c ' +
            'WHERE Account__c = :accountId ' +
            'ORDER BY Order_Date__c DESC ' +
            'LIMIT :queryLimit'
        );
    }

    // ── Get Outstanding Balance ─────────────────────────────────────────────────

    /**
     * @description Calculates the total outstanding balance across all unpaid invoices
     *              for a given outlet.
     * @param accountId The Account (outlet) Id.
     * @return The total outstanding Decimal amount.
     */
    @AuraEnabled(cacheable=true)
    public static Decimal getOutstandingBalance(Id accountId) {
        AggregateResult[] results = [
            SELECT SUM(Balance_Due__c) totalBalance
            FROM Invoice__c
            WHERE Account__c = :accountId
            AND Balance_Due__c > 0
            AND Status__c NOT IN ('Cancelled', 'Fully Paid')
        ];
        if (results.isEmpty()) {
            return 0;
        }
        Decimal balance = (Decimal)results[0].get('totalBalance');
        return balance != null ? balance : 0;
    }

    // ── Get Visit History ───────────────────────────────────────────────────────

    /**
     * @description Retrieves recent visit records for an outlet.
     * @param accountId  The Account (outlet) Id.
     * @param limitCount Maximum number of visits to return.
     * @return List of Visit__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Visit__c> getVisitHistory(Id accountId, Integer limitCount) {
        Integer queryLimit = (limitCount != null && limitCount > 0) ? limitCount : 20;
        if (queryLimit > 100) {
            queryLimit = 100;
        }

        return Database.query(
            'SELECT Id, Name, Visit_Date__c, Salesperson__c, Salesperson__r.Name, ' +
            'Check_In_Time__c, Check_Out_Time__c, Duration_Minutes__c, ' +
            'Visit_Status__c, Is_Productive__c, Is_Planned__c, ' +
            'Order_Value__c, Collection_Amount__c, Notes__c, ' +
            'Non_Productive_Reason__c, Visit_Sequence__c ' +
            'FROM Visit__c ' +
            'WHERE Account__c = :accountId ' +
            'ORDER BY Visit_Date__c DESC, Check_In_Time__c DESC ' +
            'LIMIT :queryLimit'
        );
    }

    // ── Get Outlet KPIs ─────────────────────────────────────────────────────────

    /**
     * @description Calculates MTD (Month-To-Date) key performance indicators for an outlet,
     *              including order values, visit frequency, collection amounts, and averages.
     * @param accountId The Account (outlet) Id.
     * @return Map of KPI metric names to their computed values.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getOutletKPIs(Id accountId) {
        Map<String, Object> kpis = new Map<String, Object>();

        Date today = Date.today();
        Date mtdStart = today.toStartOfMonth();

        // MTD Order Value
        AggregateResult[] orderAgg = [
            SELECT COUNT(Id) orderCount, SUM(Total_Net_Amount__c) totalValue
            FROM Sales_Order__c
            WHERE Account__c = :accountId
            AND Order_Date__c >= :mtdStart
            AND Order_Date__c <= :today
            AND Status__c NOT IN ('Cancelled', 'Rejected')
        ];

        Integer mtdOrderCount = 0;
        Decimal mtdOrderValue = 0;
        if (!orderAgg.isEmpty()) {
            mtdOrderCount = (Integer)orderAgg[0].get('orderCount');
            Decimal ov = (Decimal)orderAgg[0].get('totalValue');
            mtdOrderValue = ov != null ? ov : 0;
        }
        kpis.put('mtdOrderCount', mtdOrderCount);
        kpis.put('mtdOrderValue', mtdOrderValue);

        // MTD Visit Count
        AggregateResult[] visitAgg = [
            SELECT COUNT(Id) visitCount
            FROM Visit__c
            WHERE Account__c = :accountId
            AND Visit_Date__c >= :mtdStart
            AND Visit_Date__c <= :today
            AND Visit_Status__c = 'Completed'
        ];
        Integer mtdVisitCount = visitAgg.isEmpty() ? 0 : (Integer)visitAgg[0].get('visitCount');
        kpis.put('mtdVisitCount', mtdVisitCount);

        // MTD Collection
        AggregateResult[] collAgg = [
            SELECT SUM(Amount__c) totalCollection
            FROM Collection__c
            WHERE Account__c = :accountId
            AND Collection_Date__c >= :mtdStart
            AND Collection_Date__c <= :today
            AND Status__c != 'Cancelled'
        ];
        Decimal mtdCollection = 0;
        if (!collAgg.isEmpty()) {
            Decimal cv = (Decimal)collAgg[0].get('totalCollection');
            mtdCollection = cv != null ? cv : 0;
        }
        kpis.put('mtdCollection', mtdCollection);

        // Outstanding balance
        Decimal outstanding = getOutstandingBalance(accountId);
        kpis.put('outstandingBalance', outstanding);

        // Average order value (last 3 months)
        Date threeMonthsAgo = today.addMonths(-3);
        AggregateResult[] avgAgg = [
            SELECT AVG(Total_Net_Amount__c) avgOrderValue, COUNT(Id) totalOrders
            FROM Sales_Order__c
            WHERE Account__c = :accountId
            AND Order_Date__c >= :threeMonthsAgo
            AND Order_Date__c <= :today
            AND Status__c NOT IN ('Cancelled', 'Rejected')
        ];
        if (!avgAgg.isEmpty()) {
            Decimal avgVal = (Decimal)avgAgg[0].get('avgOrderValue');
            kpis.put('avgOrderValue', avgVal != null ? avgVal.setScale(2, RoundingMode.HALF_UP) : 0);
            kpis.put('totalOrders3M', (Integer)avgAgg[0].get('totalOrders'));
        } else {
            kpis.put('avgOrderValue', 0);
            kpis.put('totalOrders3M', 0);
        }

        // Average visit frequency (visits per month over last 3 months)
        AggregateResult[] visitFreqAgg = [
            SELECT COUNT(Id) totalVisits
            FROM Visit__c
            WHERE Account__c = :accountId
            AND Visit_Date__c >= :threeMonthsAgo
            AND Visit_Date__c <= :today
            AND Visit_Status__c = 'Completed'
        ];
        Integer totalVisits3M = visitFreqAgg.isEmpty() ? 0 : (Integer)visitFreqAgg[0].get('totalVisits');
        kpis.put('avgVisitsPerMonth', totalVisits3M > 0
            ? (Decimal.valueOf(totalVisits3M) / 3).setScale(1, RoundingMode.HALF_UP)
            : 0);

        // Last order date
        List<Sales_Order__c> lastOrder = [
            SELECT Order_Date__c
            FROM Sales_Order__c
            WHERE Account__c = :accountId
            AND Status__c NOT IN ('Cancelled', 'Rejected')
            ORDER BY Order_Date__c DESC
            LIMIT 1
        ];
        kpis.put('lastOrderDate', lastOrder.isEmpty() ? null : lastOrder[0].Order_Date__c);

        // Last visit date
        List<Visit__c> lastVisit = [
            SELECT Visit_Date__c
            FROM Visit__c
            WHERE Account__c = :accountId
            AND Visit_Status__c = 'Completed'
            ORDER BY Visit_Date__c DESC
            LIMIT 1
        ];
        kpis.put('lastVisitDate', lastVisit.isEmpty() ? null : lastVisit[0].Visit_Date__c);

        return kpis;
    }
}
