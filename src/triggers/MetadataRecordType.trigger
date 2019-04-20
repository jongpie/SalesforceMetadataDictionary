trigger MetadataRecordType on MetadataRecordType__c(before insert) {
    for(MetadataRecordType__c metadataRecordType : Trigger.new) {
        if(metadataRecordType.Uuid__c != null) continue;

        metadataRecordType.Uuid__c = new Uuid().getValue();
    }
}