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

        Collection__c collection = new Collection__c();
        collection.Account__c = (Id) data.get('accountId');
        collection.Amount__c = data.get('amount') != null ? Decimal.valueOf(String.valueOf(data.get('amount'))) : null;
        collection.Payment_Mode__c = (String) data.get('paymentMode');
        collection.Notes__c = (String) data.get('remarks');

        if (data.get('visitId') != null) {
            collection.Visit__c = (Id) data.get('visitId');
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

        // Handle invoice allocation - use the first selected invoice
        List<Object> allocations = data.get('allocations') != null ? (List<Object>) data.get('allocations') : new List<Object>();
        if (!allocations.isEmpty()) {
            Map<String, Object> firstAllocation = (Map<String, Object>) allocations[0];
            collection.Invoice__c = (Id) firstAllocation.get('invoiceId');
        }

        return CollectionController.createCollection(collection);
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
