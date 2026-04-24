/**
 * @description Apex controller for the collectionEntry LWC component.
 *              Delegates to CollectionController for core logic.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class CollectionEntryController {

    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> getOutstandingInvoices(Id accountId) {
        return CollectionController.getOutstandingInvoices(accountId);
    }

    @AuraEnabled
    public static Collection__c createCollection(String collectionJson) {
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(collectionJson);

        Id accountId = (Id) data.get('accountId');
        Decimal totalAmount = data.get('amount') != null ? Decimal.valueOf(String.valueOf(data.get('amount'))) : null;
        String paymentMode = (String) data.get('paymentMode');
        String remarks = (String) data.get('remarks');
        Id visitId = data.get('visitId') != null ? (Id) data.get('visitId') : null;

        List<Object> allocations = data.get('allocations') != null ? (List<Object>) data.get('allocations') : new List<Object>();

        // Filter to only non-zero allocations
        List<Map<String, Object>> activeAllocations = new List<Map<String, Object>>();
        for (Object a : allocations) {
            Map<String, Object> alloc = (Map<String, Object>) a;
            Decimal amt = alloc.get('allocatedAmount') != null
                ? Decimal.valueOf(String.valueOf(alloc.get('allocatedAmount'))) : 0;
            if (amt > 0 && alloc.get('invoiceId') != null) {
                activeAllocations.add(alloc);
            }
        }

        Collection__c firstCollection;

        if (!activeAllocations.isEmpty()) {
            // Create one Collection__c per allocation so each can be validated
            // against its invoice balance independently
            for (Integer i = 0; i < activeAllocations.size(); i++) {
                Map<String, Object> alloc = activeAllocations[i];
                Decimal allocAmount = Decimal.valueOf(String.valueOf(alloc.get('allocatedAmount')));
                Collection__c c = buildCollection(data, accountId, paymentMode, remarks, visitId);
                c.Amount__c = allocAmount;
                c.Invoice__c = (Id) alloc.get('invoiceId');
                Collection__c saved = CollectionController.createCollection(c);
                if (i == 0) firstCollection = saved;
            }
        } else {
            // On Account (no invoice allocation) — single collection with full amount
            Collection__c c = buildCollection(data, accountId, paymentMode, remarks, visitId);
            c.Amount__c = totalAmount;
            firstCollection = CollectionController.createCollection(c);
        }

        return firstCollection;
    }

    private static Collection__c buildCollection(Map<String, Object> data, Id accountId,
                                                   String paymentMode, String remarks, Id visitId) {
        Collection__c collection = new Collection__c();
        collection.Account__c = accountId;
        collection.Payment_Mode__c = paymentMode;
        collection.Notes__c = remarks;
        if (visitId != null) {
            collection.Visit__c = visitId;
        }
        if (data.get('chequeNumber') != null && String.isNotBlank((String) data.get('chequeNumber'))) {
            collection.Cheque_Number__c = (String) data.get('chequeNumber');
        }
        if (data.get('chequeDate') != null && String.isNotBlank(String.valueOf(data.get('chequeDate')))) {
            collection.Cheque_Date__c = Date.valueOf(String.valueOf(data.get('chequeDate')));
        }
        if (data.get('bankName') != null && String.isNotBlank((String) data.get('bankName'))) {
            collection.Bank_Name__c = (String) data.get('bankName');
        }
        if (data.get('upiReference') != null && String.isNotBlank((String) data.get('upiReference'))) {
            collection.UPI_Reference__c = (String) data.get('upiReference');
        }
        if (data.get('neftReference') != null && String.isNotBlank((String) data.get('neftReference'))) {
            collection.Transaction_Reference__c = (String) data.get('neftReference');
        }
        return collection;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getAgingSummary(Id accountId) {
        return CollectionController.getAgingSummary(accountId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Collection__c> getCollectionHistory(Id accountId) {
        return CollectionController.getCollectionHistory(accountId);
    }
}
