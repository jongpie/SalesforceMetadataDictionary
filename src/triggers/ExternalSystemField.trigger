trigger ExternalSystemField on ExternalSystemField__c(before insert) {
    for(ExternalSystemField__c externalSystemField : Trigger.new) {
        if(Uuid.isValid(externalSystemField.Uuid__c)) continue;

        externalSystemField.Uuid__c = new Uuid().getValue();
    }
}