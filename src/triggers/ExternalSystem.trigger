trigger ExternalSystem on ExternalSystem__c(before insert) {
    for(ExternalSystem__c externalSystem : Trigger.new) {
        if(externalSystem.Uuid__c != null) continue;

        externalSystem.Uuid__c = new Uuid().getValue();
    }
}