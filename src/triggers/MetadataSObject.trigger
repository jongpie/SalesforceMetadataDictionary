trigger MetadataSObject on MetadataSObject__c(before insert) {
    for(MetadataSObject__c metadataSObject : Trigger.new) {
        if(metadataSObject.Uuid__c != null) continue;

        metadataSObject.Uuid__c = new Uuid().getValue();
    }
}