trigger MetadataRecordType on MetadataRecordType__c(before insert) {
    for(MetadataRecordType__c metadataRecordType : Trigger.new) {
        if(Uuid.isValid(metadataRecordType.Uuid__c)) continue;

        metadataRecordType.Uuid__c = new Uuid().getValue();
    }
}