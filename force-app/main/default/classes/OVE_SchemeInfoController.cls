/**
 * @description Controller for the Scheme Info display during outlet visits.
 *              Read-only controller that retrieves active schemes applicable
 *              to an outlet based on date range and active status.
 *
 * @author  SFA Development Team
 * @date    2026
 */
public with sharing class OVE_SchemeInfoController {

    // ── Feature Codes ───────────────────────────────────────────────────────
    public static final String FEATURE_SCHEME_INFO = 'SPM-001';

    /**
     * @description Retrieves active schemes valid for today, optionally
     *              filtered by the outlet's type and channel.
     * @param accountId The outlet Account Id.
     * @return List of active Scheme__c records with key info fields.
     */
    @AuraEnabled(cacheable=true)
    public static List<Scheme__c> getActiveSchemes(Id accountId) {
        try {
            if (!BPM_FeatureToggle_Util.isEnabled(FEATURE_SCHEME_INFO)) {
                throw new AuraHandledException('Scheme Info feature is currently disabled.');
            }

            Date today = Date.today();

            // Determine outlet type and channel for filtering
            String outletType = null;
            String channel = null;
            if (accountId != null) {
                List<Account> accounts = [
                    SELECT Id, Type, Channel__c
                    FROM Account WHERE Id = :accountId LIMIT 1
                ];
                if (!accounts.isEmpty()) {
                    outletType = accounts[0].Type;
                    channel = accounts[0].Channel__c;
                }
            }

            String query = 'SELECT Id, Name, Scheme_Code__c, Scheme_Type__c, Description__c, ' +
                           'Start_Date__c, End_Date__c, Status__c, Channel__c, ' +
                           'Discount_Percent__c, Discount_Amount__c, Max_Discount_Cap__c, ' +
                           'Min_Quantity__c, Max_Quantity__c, Min_Value__c, Max_Value__c, ' +
                           'Free_Product__c, Free_Quantity__c, ' +
                           'Product_Ext__c, Product_Category__c, ' +
                           'Applicable_Outlet_Type__c, Applicable_Channel__c, Applicable_Region__c, ' +
                           'Priority__c, Is_Stackable__c, Budget_Amount__c, Budget_Remaining__c ' +
                           'FROM Scheme__c ' +
                           'WHERE Is_Active__c = true ' +
                           'AND (Start_Date__c = null OR Start_Date__c <= :today) ' +
                           'AND (End_Date__c = null OR End_Date__c >= :today)';

            if (String.isNotBlank(outletType)) {
                query += ' AND (Applicable_Outlet_Type__c = null OR Applicable_Outlet_Type__c = :outletType)';
            }
            if (String.isNotBlank(channel)) {
                query += ' AND (Applicable_Channel__c = null OR Applicable_Channel__c = :channel)';
            }

            query += ' ORDER BY Priority__c ASC NULLS LAST, Name ASC LIMIT 100';

            return Database.query(query);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
