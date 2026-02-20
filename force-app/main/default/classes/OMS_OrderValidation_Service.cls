/**
 * @description Service class providing bulk-safe validation methods for Sales Orders.
 *              All methods add errors directly to the SObject records, following the
 *              Salesforce trigger-pattern convention.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public without sharing class OMS_OrderValidation_Service {

    /**
     * @description Validates that each sales order's total amount does not exceed
     *              the associated account's available credit limit. Available credit
     *              is calculated as Credit_Limit__c minus Credit_Utilized__c.
     *
     * @param orders The list of Sales_Order__c records to validate.
     */
    public static void validateCreditLimit(List<Sales_Order__c> orders) {
        // Collect account IDs
        Set<Id> accountIds = new Set<Id>();
        for (Sales_Order__c order : orders) {
            if (order.Account__c != null) {
                accountIds.add(order.Account__c);
            }
        }

        if (accountIds.isEmpty()) {
            return;
        }

        // Query account credit details
        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, Name, Credit_Limit__c, Credit_Utilized__c
            FROM Account
            WHERE Id IN :accountIds
        ]);

        for (Sales_Order__c order : orders) {
            if (order.Account__c == null || order.Total_Amount__c == null) {
                continue;
            }

            Account acct = accountMap.get(order.Account__c);
            if (acct == null) {
                continue;
            }

            Decimal creditLimit = acct.Credit_Limit__c != null ? acct.Credit_Limit__c : 0;
            Decimal creditUtilized = acct.Credit_Utilized__c != null ? acct.Credit_Utilized__c : 0;
            Decimal availableCredit = creditLimit - creditUtilized;

            if (order.Total_Amount__c > availableCredit) {
                order.addError(
                    'Order amount (' + order.Total_Amount__c.setScale(2) +
                    ') exceeds available credit limit (' + availableCredit.setScale(2) +
                    ') for account ' + acct.Name + '. ' +
                    'Credit Limit: ' + creditLimit.setScale(2) +
                    ', Credit Utilized: ' + creditUtilized.setScale(2) + '.'
                );
            }
        }
    }

    /**
     * @description Validates that each sales order meets the minimum order value
     *              threshold. The threshold is sourced from the SFA_Settings__c
     *              custom setting or defaults to a sensible value.
     *
     * @param orders The list of Sales_Order__c records to validate.
     */
    public static void validateMinOrderValue(List<Sales_Order__c> orders) {
        // Retrieve the configurable minimum order value
        Decimal minOrderValue = getMinOrderValue();

        for (Sales_Order__c order : orders) {
            if (order.Total_Amount__c != null && order.Total_Amount__c < minOrderValue &&
                order.Total_Amount__c > 0) {
                order.addError(
                    'Order total amount (' + order.Total_Amount__c.setScale(2) +
                    ') is below the minimum order value of ' +
                    minOrderValue.setScale(2) + '.'
                );
            }
        }
    }

    /**
     * @description Checks for duplicate orders based on the same account, order date,
     *              and similar total amount within a configurable time window. Prevents
     *              accidental double-entry by field sales reps.
     *
     * @param orders The list of Sales_Order__c records to check.
     */
    public static void checkDuplicateOrders(List<Sales_Order__c> orders) {
        Set<Id> accountIds = new Set<Id>();
        Set<Date> orderDates = new Set<Date>();

        for (Sales_Order__c order : orders) {
            if (order.Account__c != null) {
                accountIds.add(order.Account__c);
            }
            if (order.Order_Date__c != null) {
                orderDates.add(order.Order_Date__c);
            }
        }

        if (accountIds.isEmpty() || orderDates.isEmpty()) {
            return;
        }

        // Query recent orders for the same accounts on the same dates
        Map<String, Sales_Order__c> existingOrders = new Map<String, Sales_Order__c>();
        for (Sales_Order__c existing : [
            SELECT Id, Account__c, Order_Date__c, Total_Amount__c, Sales_Rep__c
            FROM Sales_Order__c
            WHERE Account__c IN :accountIds
              AND Order_Date__c IN :orderDates
              AND Order_Status__c NOT IN ('Cancelled', 'Rejected')
            ORDER BY CreatedDate DESC
        ]) {
            String key = buildDuplicateKey(
                existing.Account__c,
                existing.Order_Date__c,
                existing.Sales_Rep__c
            );
            existingOrders.put(key, existing);
        }

        // Check within the incoming batch as well
        Map<String, Sales_Order__c> batchKeys = new Map<String, Sales_Order__c>();

        for (Sales_Order__c order : orders) {
            if (order.Account__c == null || order.Order_Date__c == null) {
                continue;
            }

            String key = buildDuplicateKey(
                order.Account__c,
                order.Order_Date__c,
                order.Sales_Rep__c
            );

            // Check against existing orders in the database
            if (existingOrders.containsKey(key)) {
                Sales_Order__c existing = existingOrders.get(key);
                // Only flag if amounts are similar (within 1% tolerance)
                if (order.Total_Amount__c != null && existing.Total_Amount__c != null) {
                    Decimal difference = Math.abs(order.Total_Amount__c - existing.Total_Amount__c);
                    Decimal tolerance = existing.Total_Amount__c * 0.01;
                    if (difference <= tolerance) {
                        order.addError(
                            'Potential duplicate order detected. An order with similar ' +
                            'details already exists (Order ID: ' + existing.Id +
                            ') for the same account, date, and sales rep.'
                        );
                        continue;
                    }
                }
            }

            // Check within the batch
            if (batchKeys.containsKey(key)) {
                order.addError(
                    'Duplicate order found within the same batch for account ' +
                    order.Account__c + ' on ' + String.valueOf(order.Order_Date__c) + '.'
                );
            } else {
                batchKeys.put(key, order);
            }
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * @description Builds a composite key for duplicate detection.
     * @param accountId The Account ID.
     * @param orderDate The order date.
     * @param salesRepId The Sales Rep user ID.
     * @return A pipe-delimited key string.
     */
    private static String buildDuplicateKey(Id accountId, Date orderDate, Id salesRepId) {
        return String.valueOf(accountId) + '|' +
               String.valueOf(orderDate) + '|' +
               String.valueOf(salesRepId);
    }

    /**
     * @description Retrieves the configurable minimum order value from custom settings.
     *              Falls back to a default if the setting does not exist.
     * @return The minimum order value.
     */
    private static Decimal getMinOrderValue() {
        try {
            List<App_Config__mdt> configs = [
                SELECT Config_Value__c FROM App_Config__mdt
                WHERE DeveloperName = 'Min_Order_Value' LIMIT 1
            ];
            if (!configs.isEmpty() && configs[0].Config_Value__c != null) {
                return Decimal.valueOf(configs[0].Config_Value__c);
            }
        } catch (Exception e) {
            // Custom metadata may not exist; fall back to default
        }
        return 0; // Default: no minimum
    }
}
