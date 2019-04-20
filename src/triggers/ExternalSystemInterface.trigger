trigger ExternalSystemInterface on ExternalSystemInterface__c(before insert) {
    for(ExternalSystemInterface__c externalSystemInterface : Trigger.new) {
        if(externalSystemInterface.Uuid__c != null) continue;

        externalSystemInterface.Uuid__c = new Uuid().getValue();
    }
}