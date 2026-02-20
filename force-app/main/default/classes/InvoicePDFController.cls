public with sharing class InvoicePDFController {
    public Invoice__c invoice { get; set; }
    public List<LineItemWrapper> lineItems { get; set; }
    public Decimal amountPaid { get; set; }
    public String amountInWords { get; set; }
    public Integer creditDays { get; set; }

    public InvoicePDFController(ApexPages.StandardController stdController) {
        invoice = (Invoice__c)stdController.getRecord();
        invoice = [SELECT Id, Name, Invoice_Date__c, Due_Date__c, Status__c,
                          Total_Amount__c, Tax_Amount__c, Net_Amount__c, Balance_Due__c,
                          GSTIN__c, E_Invoice_IRN__c, E_Way_Bill_No__c, Vehicle_No__c, Transporter__c,
                          Sales_Order__r.Name,
                          Account__r.Name, Account__r.BillingStreet, Account__r.BillingCity,
                          Account__r.BillingState, Account__r.BillingPostalCode,
                          Account__r.ShippingStreet, Account__r.ShippingCity,
                          Account__r.ShippingState, Account__r.ShippingPostalCode
                   FROM Invoice__c WHERE Id = :invoice.Id];

        List<Invoice_Line__c> lines = [SELECT Id, Product__r.Name, HSN_SAC_Code__c,
                                              Quantity__c, Unit_Price__c, Discount__c,
                                              CGST__c, SGST__c, IGST__c, Tax_Amount__c, Line_Total__c,
                                              Batch_No__c, Expiry_Date__c
                                       FROM Invoice_Line__c
                                       WHERE Invoice__c = :invoice.Id
                                       ORDER BY CreatedDate];

        lineItems = new List<LineItemWrapper>();
        Integer idx = 1;
        for (Invoice_Line__c line : lines) {
            lineItems.add(new LineItemWrapper(idx, line));
            idx++;
        }

        // Calculate amount paid
        AggregateResult[] payments = [SELECT SUM(Amount__c) totalPaid
                                      FROM Collection__c
                                      WHERE Invoice__c = :invoice.Id AND Status__c = 'Cleared'];
        amountPaid = payments.isEmpty() || payments[0].get('totalPaid') == null ? 0 : (Decimal)payments[0].get('totalPaid');

        // Amount in words
        amountInWords = numberToWords(invoice.Net_Amount__c != null ? invoice.Net_Amount__c.intValue() : 0);

        creditDays = 30; // Default, could come from config
    }

    public class LineItemWrapper {
        public Integer index { get; set; }
        public Invoice_Line__c line { get; set; }
        public LineItemWrapper(Integer idx, Invoice_Line__c l) {
            this.index = idx;
            this.line = l;
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
