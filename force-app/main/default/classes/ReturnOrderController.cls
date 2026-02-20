/**
 * @description Controller for the Return Order LWC component.
 *              Manages sales returns including invoice lookup, line item retrieval
 *              with available return quantities, and return order creation with validation.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class ReturnOrderController {

    // ── Get Account Invoices ────────────────────────────────────────────────────

    /**
     * @description Retrieves delivered/dispatched invoices for an account that are
     *              eligible for returns.
     * @param accountId The Account (outlet) Id.
     * @return List of Invoice__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> getAccountInvoices(Id accountId) {
        return [
            SELECT Id, Name, Invoice_Date__c, Total_Amount__c, Net_Amount__c,
                   Tax_Amount__c, Balance_Due__c, Status__c,
                   Sales_Order__c, Sales_Order__r.Name,
                   Delivery_Date__c, GSTIN__c
            FROM Invoice__c
            WHERE Account__c = :accountId
            AND Status__c IN ('Delivered', 'Dispatched', 'Partially Returned')
            ORDER BY Invoice_Date__c DESC
            LIMIT 50
        ];
    }

    // ── Get Invoice Lines ───────────────────────────────────────────────────────

    /**
     * @description Retrieves line items for a given invoice, including quantities
     *              already returned so that the LWC can display available return quantity.
     * @param invoiceId The Invoice__c record Id.
     * @return List of maps containing invoice line data and already-returned quantities.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getInvoiceLines(Id invoiceId) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        // Get invoice lines
        List<Invoice_Line__c> lines = [
            SELECT Id, Product__c, Product__r.Name, Product__r.ProductCode,
                   Quantity__c, Unit_Price__c, Discount__c, Tax_Amount__c,
                   Line_Total__c, HSN_SAC_Code__c, Batch_No__c,
                   CGST__c, SGST__c, IGST__c
            FROM Invoice_Line__c
            WHERE Invoice__c = :invoiceId
            ORDER BY CreatedDate
        ];

        if (lines.isEmpty()) {
            return results;
        }

        // Collect invoice line Ids to query existing returns
        Set<Id> invoiceLineIds = new Set<Id>();
        for (Invoice_Line__c line : lines) {
            invoiceLineIds.add(line.Id);
        }

        // Get already-returned quantities grouped by invoice line
        Map<Id, Decimal> returnedQtyMap = new Map<Id, Decimal>();
        List<AggregateResult> returnAgg = [
            SELECT Invoice_Line__c lineId, SUM(Return_Quantity__c) totalReturned
            FROM Return_Line__c
            WHERE Invoice_Line__c IN :invoiceLineIds
            AND Return_Order__r.Status__c NOT IN ('Cancelled', 'Rejected')
            GROUP BY Invoice_Line__c
        ];
        for (AggregateResult ar : returnAgg) {
            Id lineId = (Id)ar.get('lineId');
            Decimal totalReturned = (Decimal)ar.get('totalReturned');
            returnedQtyMap.put(lineId, totalReturned != null ? totalReturned : 0);
        }

        // Build result maps
        for (Invoice_Line__c line : lines) {
            Map<String, Object> lineMap = new Map<String, Object>();
            lineMap.put('invoiceLineId', line.Id);
            lineMap.put('productId', line.Product__c);
            lineMap.put('productName', line.Product__r.Name);
            lineMap.put('productCode', line.Product__r.ProductCode);
            lineMap.put('invoicedQty', line.Quantity__c);
            lineMap.put('unitPrice', line.Unit_Price__c);
            lineMap.put('discount', line.Discount__c);
            lineMap.put('taxAmount', line.Tax_Amount__c);
            lineMap.put('lineTotal', line.Line_Total__c);
            lineMap.put('hsnCode', line.HSN_SAC_Code__c);
            lineMap.put('batchNo', line.Batch_No__c);

            Decimal alreadyReturned = returnedQtyMap.containsKey(line.Id)
                ? returnedQtyMap.get(line.Id)
                : 0;
            Decimal invoicedQty = line.Quantity__c != null ? line.Quantity__c : 0;
            Decimal availableForReturn = invoicedQty - alreadyReturned;

            lineMap.put('alreadyReturned', alreadyReturned);
            lineMap.put('availableForReturn', availableForReturn > 0 ? availableForReturn : 0);

            results.add(lineMap);
        }

        return results;
    }

    // ── Create Return Order ─────────────────────────────────────────────────────

    /**
     * @description Creates a Return Order with its line items after validating
     *              that return quantities do not exceed available quantities.
     *              Uses savepoint for transactional integrity.
     * @param returnOrder The Return_Order__c header record.
     * @param returnLines List of Return_Line__c records.
     * @return The inserted Return_Order__c record with Id.
     */
    @AuraEnabled
    public static Return_Order__c createReturnOrder(Return_Order__c returnOrder, List<Return_Line__c> returnLines) {
        Savepoint sp = Database.setSavepoint();
        try {
            // Validate inputs
            if (returnLines == null || returnLines.isEmpty()) {
                throw new AuraHandledException('At least one return line item is required.');
            }

            // Validate return quantities against available quantities
            Set<Id> invoiceLineIds = new Set<Id>();
            for (Return_Line__c rl : returnLines) {
                if (rl.Invoice_Line__c != null) {
                    invoiceLineIds.add(rl.Invoice_Line__c);
                }
            }

            // Get invoiced quantities
            Map<Id, Decimal> invoicedQtyMap = new Map<Id, Decimal>();
            if (!invoiceLineIds.isEmpty()) {
                List<Invoice_Line__c> invoiceLines = [
                    SELECT Id, Quantity__c
                    FROM Invoice_Line__c
                    WHERE Id IN :invoiceLineIds
                ];
                for (Invoice_Line__c il : invoiceLines) {
                    invoicedQtyMap.put(il.Id, il.Quantity__c != null ? il.Quantity__c : 0);
                }
            }

            // Get already-returned quantities
            Map<Id, Decimal> returnedQtyMap = new Map<Id, Decimal>();
            if (!invoiceLineIds.isEmpty()) {
                List<AggregateResult> returnAgg = [
                    SELECT Invoice_Line__c lineId, SUM(Return_Quantity__c) totalReturned
                    FROM Return_Line__c
                    WHERE Invoice_Line__c IN :invoiceLineIds
                    AND Return_Order__r.Status__c NOT IN ('Cancelled', 'Rejected')
                    GROUP BY Invoice_Line__c
                ];
                for (AggregateResult ar : returnAgg) {
                    Id lineId = (Id)ar.get('lineId');
                    Decimal totalReturned = (Decimal)ar.get('totalReturned');
                    returnedQtyMap.put(lineId, totalReturned != null ? totalReturned : 0);
                }
            }

            // Validate each return line
            for (Return_Line__c rl : returnLines) {
                if (rl.Return_Quantity__c == null || rl.Return_Quantity__c <= 0) {
                    throw new AuraHandledException('Return quantity must be greater than zero.');
                }

                if (rl.Invoice_Line__c != null) {
                    Decimal invoicedQty = invoicedQtyMap.containsKey(rl.Invoice_Line__c)
                        ? invoicedQtyMap.get(rl.Invoice_Line__c) : 0;
                    Decimal alreadyReturned = returnedQtyMap.containsKey(rl.Invoice_Line__c)
                        ? returnedQtyMap.get(rl.Invoice_Line__c) : 0;
                    Decimal available = invoicedQty - alreadyReturned;

                    if (rl.Return_Quantity__c > available) {
                        throw new AuraHandledException(
                            'Return quantity (' + String.valueOf(rl.Return_Quantity__c) +
                            ') exceeds available quantity (' + String.valueOf(available) +
                            ') for invoice line ' + rl.Invoice_Line__c + '.'
                        );
                    }
                }

                if (String.isBlank(rl.Return_Reason__c)) {
                    throw new AuraHandledException('Return reason is required for all line items.');
                }
            }

            // Set defaults on the return order
            if (returnOrder.Return_Date__c == null) {
                returnOrder.Return_Date__c = Date.today();
            }
            if (returnOrder.Status__c == null) {
                returnOrder.Status__c = 'Draft';
            }

            insert returnOrder;

            // Associate lines with the return order
            Decimal totalReturnValue = 0;
            for (Return_Line__c rl : returnLines) {
                rl.Return_Order__c = returnOrder.Id;
                // Calculate line value if unit price is available
                if (rl.Unit_Price__c != null && rl.Return_Quantity__c != null) {
                    rl.Line_Total__c = rl.Unit_Price__c * rl.Return_Quantity__c;
                    totalReturnValue += rl.Line_Total__c;
                }
            }
            insert returnLines;

            // Update return order total
            returnOrder.Total_Return_Value__c = totalReturnValue;
            returnOrder.Total_Items__c = returnLines.size();
            update returnOrder;

            return [
                SELECT Id, Name, Return_Date__c, Status__c, Account__c, Account__r.Name,
                       Invoice__c, Invoice__r.Name, Total_Return_Value__c, Total_Items__c,
                       Return_Reason__c
                FROM Return_Order__c
                WHERE Id = :returnOrder.Id
                LIMIT 1
            ];
        } catch (AuraHandledException ahe) {
            Database.rollback(sp);
            throw ahe;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }
}
