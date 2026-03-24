public with sharing class SPM_MustSellConfig_TriggerHandler {

    public void onBeforeInsert(List<Must_Sell_Config__c> newRecords) {
        validateDateRanges(newRecords);
        checkDuplicateConfigs(newRecords, null);
    }

    public void onBeforeUpdate(List<Must_Sell_Config__c> newRecords, Map<Id, Must_Sell_Config__c> oldMap) {
        validateDateRanges(newRecords);
        checkDuplicateConfigs(newRecords, oldMap);
    }

    private void validateDateRanges(List<Must_Sell_Config__c> records) {
        for (Must_Sell_Config__c config : records) {
            if (config.Start_Date__c != null && config.End_Date__c != null
                && config.End_Date__c < config.Start_Date__c) {
                config.addError('End Date must be on or after Start Date.');
            }
        }
    }

    private void checkDuplicateConfigs(List<Must_Sell_Config__c> records, Map<Id, Must_Sell_Config__c> oldMap) {
        Set<Id> productIds = new Set<Id>();
        for (Must_Sell_Config__c config : records) {
            if (config.Product_Ext__c != null) {
                productIds.add(config.Product_Ext__c);
            }
        }

        if (productIds.isEmpty()) {
            return;
        }

        Map<Id, List<Must_Sell_Config__c>> existingByProduct = new Map<Id, List<Must_Sell_Config__c>>();
        for (Must_Sell_Config__c existing : [
            SELECT Id, Product_Ext__c, Territory__c, Channel__c,
                   Customer_Type__c, Start_Date__c, End_Date__c, Is_Active__c
            FROM Must_Sell_Config__c
            WHERE Product_Ext__c IN :productIds
              AND Is_Active__c = true
        ]) {
            if (!existingByProduct.containsKey(existing.Product_Ext__c)) {
                existingByProduct.put(existing.Product_Ext__c, new List<Must_Sell_Config__c>());
            }
            existingByProduct.get(existing.Product_Ext__c).add(existing);
        }

        for (Must_Sell_Config__c config : records) {
            if (config.Product_Ext__c == null || !config.Is_Active__c) {
                continue;
            }
            if (oldMap != null && oldMap.get(config.Id) != null) {
                Must_Sell_Config__c oldRec = oldMap.get(config.Id);
                if (oldRec.Product_Ext__c == config.Product_Ext__c
                    && oldRec.Territory__c == config.Territory__c
                    && oldRec.Channel__c == config.Channel__c
                    && oldRec.Customer_Type__c == config.Customer_Type__c) {
                    continue;
                }
            }

            List<Must_Sell_Config__c> existingList = existingByProduct.get(config.Product_Ext__c);
            if (existingList == null) {
                continue;
            }

            for (Must_Sell_Config__c existing : existingList) {
                if (existing.Id == config.Id) {
                    continue;
                }
                if (existing.Territory__c == config.Territory__c
                    && existing.Channel__c == config.Channel__c
                    && existing.Customer_Type__c == config.Customer_Type__c) {
                    Boolean datesOverlap = config.Start_Date__c != null
                        && config.End_Date__c != null
                        && existing.Start_Date__c != null
                        && existing.End_Date__c != null
                        && config.Start_Date__c <= existing.End_Date__c
                        && config.End_Date__c >= existing.Start_Date__c;
                    Boolean eitherOpenEnded = config.End_Date__c == null || existing.End_Date__c == null;

                    if (datesOverlap || eitherOpenEnded) {
                        config.addError('An active Priority Sell configuration already exists for this product, territory, channel, and customer type combination with overlapping dates.');
                    }
                }
            }
        }
    }
}
