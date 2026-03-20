trigger UOM_Conversion_Trigger on UOM_Conversion__c (before insert, before update) {
    for (UOM_Conversion__c conv : Trigger.new) {
        if (conv.Conversion_Factor__c != null && conv.Conversion_Factor__c != 0) {
            conv.Inverse_Conversion_Factor__c = (1 / conv.Conversion_Factor__c).setScale(4, RoundingMode.HALF_UP);
        }
    }
}
