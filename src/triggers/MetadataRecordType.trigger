/*****************************************************************************************************************
* This file is part of the Nebula Logger project, released under the MIT License.                                *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
trigger MetadataRecordType on MetadataRecordType__c(before insert) {
    for(MetadataRecordType__c metadataRecordType : Trigger.new) {
        if(Uuid.isValid(metadataRecordType.Uuid__c)) continue;

        metadataRecordType.Uuid__c = new Uuid().getValue();
    }
}