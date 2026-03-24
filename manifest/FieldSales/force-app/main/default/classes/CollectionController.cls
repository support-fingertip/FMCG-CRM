/**
 * @description Controller for the Collection LWC component.
 *              Manages payment collection against invoices, aging analysis,
 *              ledger entry creation, and collection history for FMCG field sales.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class CollectionController {

    // ── Get Outstanding Invoices ────────────────────────────────────────────────

    /**
     * @description Retrieves all unpaid invoices for an outlet with outstanding balance.
     * @param accountId The Account (outlet) Id.
     * @return List of Invoice__c records with balance due.
     */
    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> getOutstandingInvoices(Id accountId) {
        return [
            SELECT Id, Name, Invoice_Date__c, Due_Date__c, Total_Amount__c,
                   Tax_Amount__c, Net_Amount__c, Balance_Due__c, Status__c,
                   Sales_Order__c, Sales_Order__r.Name
            FROM Invoice__c
            WHERE Account__c = :accountId
            AND Balance_Due__c > 0
            AND Status__c NOT IN ('Cancelled', 'Fully Paid')
            ORDER BY Due_Date__c ASC
        ];
    }

    // ── Create Collection ───────────────────────────────────────────────────────

    /**
     * @description Creates a collection record, updates the linked invoice balance,
     *              and creates a corresponding ledger entry. Uses savepoint for
     *              transactional integrity.
     * @param collection The Collection__c record with payment details.
     * @return The inserted Collection__c record.
     */
    @AuraEnabled
    public static Collection__c createCollection(Collection__c collection) {
        Savepoint sp = Database.setSavepoint();
        try {
            // Validate collection amount
            if (collection.Amount__c == null || collection.Amount__c <= 0) {
                throw new AuraHandledException('Collection amount must be greater than zero.');
            }

            // Set defaults
            if (collection.Collection_Date__c == null) {
                collection.Collection_Date__c = Date.today();
            }
            if (collection.Status__c == null) {
                collection.Status__c = 'Collected';
            }

            // If collecting against a specific invoice, validate balance
            if (collection.Invoice__c != null) {
                Invoice__c invoice = [
                    SELECT Id, Balance_Due__c, Status__c
                    FROM Invoice__c
                    WHERE Id = :collection.Invoice__c
                    LIMIT 1
                ];

                if (collection.Amount__c > invoice.Balance_Due__c) {
                    throw new AuraHandledException(
                        'Collection amount (' + String.valueOf(collection.Amount__c) +
                        ') exceeds invoice balance (' + String.valueOf(invoice.Balance_Due__c) + ').'
                    );
                }

                // Update invoice balance
                invoice.Balance_Due__c = invoice.Balance_Due__c - collection.Amount__c;
                if (invoice.Balance_Due__c == 0) {
                    invoice.Status__c = 'Fully Paid';
                }
                update invoice;
            }

            insert collection;

            // Create ledger entry for the collection
            Ledger_Entry__c ledger = new Ledger_Entry__c();
            ledger.Account__c = collection.Account__c;
            ledger.Collection__c = collection.Id;
            ledger.Entry_Date__c = collection.Collection_Date__c;
            ledger.Entry_Type__c = 'Collection';
            ledger.Credit_Amount__c = collection.Amount__c;
            ledger.Debit_Amount__c = 0;
            ledger.Reference_Number__c = collection.Receipt_Number__c;
            if (collection.Invoice__c != null) {
                ledger.Invoice__c = collection.Invoice__c;
            }
            ledger.Notes__c = 'Collection via ' + (collection.Payment_Mode__c != null
                ? collection.Payment_Mode__c
                : 'Cash');
            insert ledger;

            // Update running balance on the ledger
            updateRunningBalance(collection.Account__c);

            return [
                SELECT Id, Name, Amount__c, Collection_Date__c, Payment_Mode__c,
                       Status__c, Account__c, Account__r.Name, Invoice__c, Invoice__r.Name,
                       Receipt_Number__c
                FROM Collection__c
                WHERE Id = :collection.Id
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

    // ── Get Aging Summary ───────────────────────────────────────────────────────

    /**
     * @description Calculates aging buckets (0-30, 31-60, 61-90, 90+) for outstanding
     *              invoices of an account.
     * @param accountId The Account (outlet) Id.
     * @return Map with aging bucket keys and their corresponding outstanding amounts.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getAgingSummary(Id accountId) {
        Map<String, Decimal> aging = new Map<String, Decimal>{
            'current' => 0,    // 0-30 days
            'days31_60' => 0,  // 31-60 days
            'days61_90' => 0,  // 61-90 days
            'days90Plus' => 0, // 90+ days
            'total' => 0
        };

        Date today = Date.today();
        List<Invoice__c> invoices = [
            SELECT Id, Invoice_Date__c, Due_Date__c, Balance_Due__c
            FROM Invoice__c
            WHERE Account__c = :accountId
            AND Balance_Due__c > 0
            AND Status__c NOT IN ('Cancelled', 'Fully Paid')
        ];

        for (Invoice__c inv : invoices) {
            Date referenceDate = inv.Due_Date__c != null ? inv.Due_Date__c : inv.Invoice_Date__c;
            Integer daysOutstanding = referenceDate.daysBetween(today);
            Decimal balance = inv.Balance_Due__c != null ? inv.Balance_Due__c : 0;

            if (daysOutstanding <= 30) {
                aging.put('current', aging.get('current') + balance);
            } else if (daysOutstanding <= 60) {
                aging.put('days31_60', aging.get('days31_60') + balance);
            } else if (daysOutstanding <= 90) {
                aging.put('days61_90', aging.get('days61_90') + balance);
            } else {
                aging.put('days90Plus', aging.get('days90Plus') + balance);
            }
            aging.put('total', aging.get('total') + balance);
        }

        return aging;
    }

    // ── Get Collection History ──────────────────────────────────────────────────

    /**
     * @description Retrieves recent collection records for a given account.
     * @param accountId The Account (outlet) Id.
     * @return List of recent Collection__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Collection__c> getCollectionHistory(Id accountId) {
        return [
            SELECT Id, Name, Collection_Date__c, Amount__c, Payment_Mode__c,
                   Status__c, Invoice__c, Invoice__r.Name, Receipt_Number__c,
                   Cheque_Number__c, Cheque_Date__c, Bank_Name__c,
                   UPI_Reference__c, Transaction_Reference__c, Notes__c,
                   Salesperson__c, Salesperson__r.Name
            FROM Collection__c
            WHERE Account__c = :accountId
            ORDER BY Collection_Date__c DESC
            LIMIT 50
        ];
    }

    // ── Private Helper: Update Running Balance ──────────────────────────────────

    /**
     * @description Recalculates running balance for all ledger entries of an account
     *              in chronological order.
     */
    private static void updateRunningBalance(Id accountId) {
        List<Ledger_Entry__c> ledgerEntries = [
            SELECT Id, Debit_Amount__c, Credit_Amount__c, Running_Balance__c
            FROM Ledger_Entry__c
            WHERE Account__c = :accountId
            ORDER BY Entry_Date__c ASC, CreatedDate ASC
        ];

        Decimal runningBalance = 0;
        List<Ledger_Entry__c> toUpdate = new List<Ledger_Entry__c>();

        for (Ledger_Entry__c entry : ledgerEntries) {
            Decimal debit = entry.Debit_Amount__c != null ? entry.Debit_Amount__c : 0;
            Decimal credit = entry.Credit_Amount__c != null ? entry.Credit_Amount__c : 0;
            runningBalance = runningBalance + debit - credit;

            if (entry.Running_Balance__c != runningBalance) {
                entry.Running_Balance__c = runningBalance;
                toUpdate.add(entry);
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}