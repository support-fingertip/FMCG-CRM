/**
 * @description REST API for Distributor Stock operations (Mobile App).
 *              Covers:
 *                - Create Distributor Stock entries for inventory tracking
 *
 * @author  Praveen Kumar
 * @date    2026
 */
@RestResource(urlMapping='/mobile/distributor-stock/*')
global with sharing class API_DistributorStock_Rest {

    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        String path = req.requestURI;

        try {
            if (path.endsWith('/create')) {
                doCreateStock(req);
            } else {
                API_ResponseWrapper.sendError('Invalid endpoint.');
            }
        } catch (Exception e) {
            API_ResponseWrapper.sendServerError(e.getMessage());
        }
    }

    // ── Create Distributor Stock ──────────────────────────────────────────

    private static void doCreateStock(RestRequest req) {
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
            req.requestBody.toString()
        );

        // Validate userId
        String userId = (String) body.get('userId');
        if (String.isBlank(userId)) {
            API_ResponseWrapper.sendError('userId is required.');
            return;
        }

        Id sfUserId = resolveUserId(userId);
        if (sfUserId == null) {
            API_ResponseWrapper.sendError('User not found.');
            return;
        }

        // Validate accountId (accept both 'accountId' and 'accoutnId' for typo resilience)
        String accountId = (String) body.get('accountId');
        if (String.isBlank(accountId)) {
            accountId = (String) body.get('accoutnId');
        }
        if (String.isBlank(accountId)) {
            API_ResponseWrapper.sendError('accountId is required.');
            return;
        }

        List<Account> accounts = [SELECT Id FROM Account WHERE Name = :accountId LIMIT 1];
        if (accounts.isEmpty()) {
            API_ResponseWrapper.sendError('Account not found.');
            return;
        }
        Id resolvedAccountId = accounts[0].Id;

        // Validate visitId (optional)
        Id resolvedVisitId = null;
        String visitId = (String) body.get('visitId');
        if (String.isNotBlank(visitId)) {
            List<Visit__c> visits = [SELECT Id FROM Visit__c WHERE Id = :visitId OR Name = :visitId LIMIT 1];
            if (!visits.isEmpty()) {
                resolvedVisitId = visits[0].Id;
            }
        }

        // Validate products
        List<Object> products = (List<Object>) body.get('products');
        if (products == null || products.isEmpty()) {
            API_ResponseWrapper.sendError('At least one product is required.');
            return;
        }

        // Collect product names for bulk lookup
        Set<String> productNames = new Set<String>();
        for (Object prodObj : products) {
            Map<String, Object> prod = (Map<String, Object>) prodObj;
            String productName = (String) prod.get('productName');
            if (String.isNotBlank(productName)) {
                productNames.add(productName);
            }
        }

        // Bulk query Product_Extension__c by Name
        Map<String, Id> productNameToId = new Map<String, Id>();
        if (!productNames.isEmpty()) {
            List<Product_Extension__c> prodExts = [
                SELECT Id, Name FROM Product_Extension__c
                WHERE Name IN :productNames
            ];
            for (Product_Extension__c pe : prodExts) {
                productNameToId.put(pe.Name, pe.Id);
            }
        }

        // Build Distributor_Stock__c records
        List<Distributor_Stock__c> stockRecords = new List<Distributor_Stock__c>();
        for (Object prodObj : products) {
            Map<String, Object> prod = (Map<String, Object>) prodObj;
            String productName = (String) prod.get('productName');

            if (String.isBlank(productName)) {
                API_ResponseWrapper.sendError('productName is required for each product.');
                return;
            }

            if (!productNameToId.containsKey(productName)) {
                API_ResponseWrapper.sendError('Product not found: ' + productName);
                return;
            }

            Distributor_Stock__c stock = new Distributor_Stock__c();
            stock.Account__c = resolvedAccountId;
            stock.Product_Ext__c = productNameToId.get(productName);
            stock.Opening_Stock__c = toDecimal(prod.get('openingStock'));
            stock.Closing_Stock__c = toDecimal(prod.get('closingStock'));
            stock.Damaged_Qty__c = toDecimal(prod.get('damagedStock'));
            stock.Stock_Date__c = Date.today();
            stock.Is_Current__c = true;

            stockRecords.add(stock);
        }

        insert stockRecords;

        API_ResponseWrapper.sendSuccess('Distributor stock created successfully', new Map<String, Object>{
            'totalRecords' => stockRecords.size()
        });
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private static Id resolveUserId(String userId) {
        List<Employee__c> employees = [
            SELECT Id, User__c FROM Employee__c
            WHERE User__c = :userId OR Name = :userId
            LIMIT 1
        ];
        return employees.isEmpty() ? null : employees[0].User__c;
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
