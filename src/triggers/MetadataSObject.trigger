trigger MetadataSObject on MetadataSObject__c(before insert) {
    for(MetadataSObject__c metadataSObject : Trigger.new) {
        if(Uuid.isValid(metadataSObject.Uuid__c)) continue;

        metadataSObject.Uuid__c = new Uuid().getValue();
    }
}