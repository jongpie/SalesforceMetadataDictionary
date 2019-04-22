/*****************************************************************************************************************
* This file is part of the Metadata Dictionary project for Salesforce, released under the MIT License.           *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
trigger MetadataRecordType on MetadataRecordType__c(before insert) {
    for(MetadataRecordType__c metadataRecordType : Trigger.new) {
        if(Uuid.isValid(metadataRecordType.Uuid__c)) continue;

        metadataRecordType.Uuid__c = new Uuid().getValue();
    }
}