trigger MetadataField on MetadataField__c(before insert) {
    for(MetadataField__c metadataField : Trigger.new) {
        if(metadataField.Uuid__c != null) continue;

        metadataField.Uuid__c = new Uuid().getValue();
    }
}