trigger ExternalSystemField on ExternalSystemField__c(before insert) {
    for(ExternalSystemField__c externalSystemField : Trigger.new) {
        if(externalSystemField.Uuid__c != null) continue;

        externalSystemField.Uuid__c = new Uuid().getValue();
    }
}