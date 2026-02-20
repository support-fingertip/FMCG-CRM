/**
 * @description Trigger handler for Price_List__c. Ensures price list date ranges
 *              do not overlap for the same product + region + channel combination
 *              and maintains an audit trail of price changes.
 * @author  SFA Development Team
 * @date    2024
 */
public class MDM_PriceList_Handler extends TriggerHandler {

    // ── Before Insert ─────────────────────────────────────────────────────────

    /**
     * @description Validates that new price list entries do not have overlapping
     *              date ranges with existing entries for the same product, region,
     *              and channel.
     */
    protected override void beforeInsert() {
        List<Price_List__c> newRecords = (List<Price_List__c>) Trigger.new;
        validateDateRangeOverlap(newRecords, null);
    }

    // ── Before Update ─────────────────────────────────────────────────────────

    /**
     * @description Re-validates date ranges when effective dates or key
     *              dimensions change.
     */
    protected override void beforeUpdate() {
        List<Price_List__c> newRecords = (List<Price_List__c>) Trigger.new;
        Map<Id, Price_List__c> oldMap = (Map<Id, Price_List__c>) Trigger.oldMap;

        List<Price_List__c> changedRecords = new List<Price_List__c>();
        for (Price_List__c rec : newRecords) {
            Price_List__c oldRec = oldMap.get(rec.Id);
            if (rec.Effective_From__c != oldRec.Effective_From__c ||
                rec.Effective_To__c != oldRec.Effective_To__c ||
                rec.Product__c != oldRec.Product__c ||
                rec.Region__c != oldRec.Region__c ||
                rec.Channel__c != oldRec.Channel__c) {
                changedRecords.add(rec);
            }
        }

        if (!changedRecords.isEmpty()) {
            Set<Id> currentIds = new Set<Id>();
            for (Price_List__c rec : changedRecords) {
                currentIds.add(rec.Id);
            }
            validateDateRangeOverlap(changedRecords, currentIds);
        }
    }

    // ── After Update ──────────────────────────────────────────────────────────

    /**
     * @description Logs price changes into the Price_Change_Log__c object for
     *              audit and compliance tracking.
     */
    protected override void afterUpdate() {
        List<Price_List__c> newRecords = (List<Price_List__c>) Trigger.new;
        Map<Id, Price_List__c> oldMap = (Map<Id, Price_List__c>) Trigger.oldMap;
        logPriceChanges(newRecords, oldMap);
    }

    // ── Private helper methods ────────────────────────────────────────────────

    /**
     * @description Validates that no two price list entries overlap in their date
     *              ranges for the same product + region + channel combination.
     *              Checks both within the current batch and against existing DB records.
     * @param records   The records to validate.
     * @param excludeIds Set of Ids to exclude from the overlap query (for updates).
     */
    private void validateDateRangeOverlap(List<Price_List__c> records, Set<Id> excludeIds) {
        // Build composite keys and collect dimension values for query
        Set<Id> productIds = new Set<Id>();
        Set<String> regionValues = new Set<String>();
        Set<String> channelValues = new Set<String>();

        for (Price_List__c rec : records) {
            if (rec.Product__c != null) {
                productIds.add(rec.Product__c);
            }
            if (String.isNotBlank(rec.Region__c)) {
                regionValues.add(rec.Region__c);
            }
            if (String.isNotBlank(rec.Channel__c)) {
                channelValues.add(rec.Channel__c);
            }
        }

        if (productIds.isEmpty()) {
            return;
        }

        // Query existing price lists for the same dimension combinations
        String query = 'SELECT Id, Product__c, Region__c, Channel__c, ' +
                       'Effective_From__c, Effective_To__c ' +
                       'FROM Price_List__c ' +
                       'WHERE Product__c IN :productIds';

        if (!regionValues.isEmpty()) {
            query += ' AND Region__c IN :regionValues';
        }
        if (!channelValues.isEmpty()) {
            query += ' AND Channel__c IN :channelValues';
        }
        if (excludeIds != null && !excludeIds.isEmpty()) {
            query += ' AND Id NOT IN :excludeIds';
        }

        // Build a map of composite key -> list of existing date ranges
        Map<String, List<Price_List__c>> existingByKey = new Map<String, List<Price_List__c>>();
        for (Price_List__c existing : Database.query(query)) {
            String key = buildCompositeKey(
                existing.Product__c, existing.Region__c, existing.Channel__c
            );
            if (!existingByKey.containsKey(key)) {
                existingByKey.put(key, new List<Price_List__c>());
            }
            existingByKey.get(key).add(existing);
        }

        // Also check within the incoming batch for intra-batch overlaps
        Map<String, List<Price_List__c>> batchByKey = new Map<String, List<Price_List__c>>();
        for (Price_List__c rec : records) {
            String key = buildCompositeKey(rec.Product__c, rec.Region__c, rec.Channel__c);
            if (!batchByKey.containsKey(key)) {
                batchByKey.put(key, new List<Price_List__c>());
            }
            batchByKey.get(key).add(rec);
        }

        // Validate each record
        for (Price_List__c rec : records) {
            if (rec.Effective_From__c == null) {
                rec.addError('Effective From date is required.');
                continue;
            }

            String key = buildCompositeKey(rec.Product__c, rec.Region__c, rec.Channel__c);

            // Check against existing database records
            if (existingByKey.containsKey(key)) {
                for (Price_List__c existing : existingByKey.get(key)) {
                    if (datesOverlap(
                        rec.Effective_From__c, rec.Effective_To__c,
                        existing.Effective_From__c, existing.Effective_To__c
                    )) {
                        rec.addError(
                            'This price list overlaps with an existing entry (ID: ' +
                            existing.Id + ') for the same Product, Region, and Channel ' +
                            'combination. Effective dates must not overlap.'
                        );
                        break;
                    }
                }
            }

            // Check within the batch (skip self-comparison by reference)
            if (batchByKey.containsKey(key)) {
                for (Price_List__c batchRec : batchByKey.get(key)) {
                    if (batchRec === rec) {
                        continue;
                    }
                    if (datesOverlap(
                        rec.Effective_From__c, rec.Effective_To__c,
                        batchRec.Effective_From__c, batchRec.Effective_To__c
                    )) {
                        rec.addError(
                            'Multiple price list entries in this batch overlap for the ' +
                            'same Product, Region, and Channel combination.'
                        );
                        break;
                    }
                }
            }
        }
    }

    /**
     * @description Builds a composite key from the three dimension fields.
     * @param productId The Product__c lookup ID.
     * @param region    The Region__c value.
     * @param channel   The Channel__c value.
     * @return A pipe-delimited composite key string.
     */
    private String buildCompositeKey(Id productId, String region, String channel) {
        return String.valueOf(productId) + '|' +
               (String.isNotBlank(region) ? region : '') + '|' +
               (String.isNotBlank(channel) ? channel : '');
    }

    /**
     * @description Determines whether two date ranges overlap. Handles open-ended
     *              ranges (null end dates treated as indefinite future).
     * @param start1 First range start date.
     * @param end1   First range end date (null = indefinite).
     * @param start2 Second range start date.
     * @param end2   Second range end date (null = indefinite).
     * @return True if the ranges overlap.
     */
    private Boolean datesOverlap(Date start1, Date end1, Date start2, Date end2) {
        Date effectiveEnd1 = end1 != null ? end1 : Date.newInstance(9999, 12, 31);
        Date effectiveEnd2 = end2 != null ? end2 : Date.newInstance(9999, 12, 31);
        return start1 <= effectiveEnd2 && start2 <= effectiveEnd1;
    }

    /**
     * @description Creates Price_Change_Log__c records for any price changes
     *              detected during update operations.
     * @param newRecords The updated records.
     * @param oldMap     Map of old record values keyed by Id.
     */
    private void logPriceChanges(
        List<Price_List__c> newRecords,
        Map<Id, Price_List__c> oldMap
    ) {
        List<Price_Change_Log__c> logs = new List<Price_Change_Log__c>();

        for (Price_List__c rec : newRecords) {
            Price_List__c oldRec = oldMap.get(rec.Id);

            if (rec.Unit_Price__c != oldRec.Unit_Price__c) {
                logs.add(new Price_Change_Log__c(
                    Price_List__c   = rec.Id,
                    Product__c      = rec.Product__c,
                    Old_Price__c    = oldRec.Unit_Price__c,
                    New_Price__c    = rec.Unit_Price__c,
                    Changed_By__c   = UserInfo.getUserId(),
                    Change_Date__c  = Datetime.now(),
                    Region__c       = rec.Region__c,
                    Channel__c      = rec.Channel__c,
                    Change_Reason__c = 'Price updated via Price List modification'
                ));
            }
        }

        if (!logs.isEmpty()) {
            insert logs;
        }
    }
}
