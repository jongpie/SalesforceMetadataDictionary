trigger ExternalSystem on ExternalSystem__c(before insert) {
    for(ExternalSystem__c externalSystem : Trigger.new) {
        if(Uuid.isValid(externalSystem.Uuid__c)) continue;

        externalSystem.Uuid__c = new Uuid().getValue();
    }
}