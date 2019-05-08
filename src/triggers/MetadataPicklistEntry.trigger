/*****************************************************************************************************************
* This file is part of the Metadata Dictionary project for Salesforce, released under the MIT License.           *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
trigger MetadataPicklistEntry on MetadataPicklistEntry__c(before insert) {
    for(MetadataPicklistEntry__c metadataPicklistEntry : Trigger.new) {
        if(Uuid.isValid(metadataPicklistEntry.Uuid__c)) continue;

        metadataPicklistEntry.Uuid__c = new Uuid().getValue();
    }
}