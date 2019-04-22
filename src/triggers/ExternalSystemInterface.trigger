trigger ExternalSystemInterface on ExternalSystemInterface__c(before insert) {
    for(ExternalSystemInterface__c externalSystemInterface : Trigger.new) {
        if(Uuid.isValid(externalSystemInterface.Uuid__c)) continue;

        externalSystemInterface.Uuid__c = new Uuid().getValue();
    }
}