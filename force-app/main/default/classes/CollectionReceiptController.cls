public with sharing class CollectionReceiptController {
    public Collection__c collection { get; set; }
    public String amountInWords { get; set; }
    public Decimal balanceDue { get; set; }

    public CollectionReceiptController(ApexPages.StandardController stdController) {
        collection = (Collection__c)stdController.getRecord();
        collection = [SELECT Id, Name, Receipt_Number__c, Collection_Date__c, Amount__c,
                             Payment_Mode__c, Status__c, Notes__c, Is_On_Account__c,
                             Cheque_Number__c, Cheque_Date__c, Bank_Name__c,
                             Transaction_Reference__c, UPI_Reference__c,
                             Account__r.Name, Account__r.BillingStreet,
                             Account__r.BillingCity, Account__r.BillingState,
                             Account__r.BillingPostalCode,
                             Invoice__r.Name, Invoice__r.Invoice_Date__c,
                             Invoice__r.Net_Amount__c, Invoice__r.Balance_Due__c,
                             Salesperson__r.Name
                      FROM Collection__c WHERE Id = :collection.Id];

        // Amount in words
        amountInWords = numberToWords(collection.Amount__c != null ? collection.Amount__c.intValue() : 0);

        // Calculate balance due after this payment
        if (collection.Invoice__c != null && collection.Invoice__r.Balance_Due__c != null) {
            balanceDue = collection.Invoice__r.Balance_Due__c;
        } else {
            balanceDue = 0;
        }
    }

    private static String numberToWords(Integer num) {
        if (num == 0) return 'Zero';
        String[] ones = new String[]{'', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
                                     'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
                                     'Seventeen', 'Eighteen', 'Nineteen'};
        String[] tens = new String[]{'', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'};

        if (num < 20) return ones[num];
        if (num < 100) return tens[num/10] + (Math.mod(num, 10) != 0 ? ' ' + ones[Math.mod(num, 10)] : '');
        if (num < 1000) return ones[num/100] + ' Hundred' + (Math.mod(num, 100) != 0 ? ' and ' + numberToWords(Math.mod(num, 100)) : '');
        if (num < 100000) return numberToWords(num/1000) + ' Thousand' + (Math.mod(num, 1000) != 0 ? ' ' + numberToWords(Math.mod(num, 1000)) : '');
        if (num < 10000000) return numberToWords(num/100000) + ' Lakh' + (Math.mod(num, 100000) != 0 ? ' ' + numberToWords(Math.mod(num, 100000)) : '');
        return numberToWords(num/10000000) + ' Crore' + (Math.mod(num, 10000000) != 0 ? ' ' + numberToWords(Math.mod(num, 10000000)) : '');
    }
}