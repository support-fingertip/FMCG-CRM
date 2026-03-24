trigger Must_Sell_Config_Trigger on Must_Sell_Config__c (before insert, before update) {
    SPM_MustSellConfig_TriggerHandler handler = new SPM_MustSellConfig_TriggerHandler();

    if (Trigger.isBefore && Trigger.isInsert) {
        handler.onBeforeInsert(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        handler.onBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}
