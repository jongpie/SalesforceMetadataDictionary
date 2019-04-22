trigger MetadataField on MetadataField__c(before insert) {
    for(MetadataField__c metadataField : Trigger.new) {
        if(Uuid.isValid(metadataField.Uuid__c)) continue;

        metadataField.Uuid__c = new Uuid().getValue();
    }
}