/*****************************************************************************************************************
* This file is part of the Nebula Logger project, released under the MIT License.                                *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
trigger MetadataSObject on MetadataSObject__c(before insert) {
    for(MetadataSObject__c metadataSObject : Trigger.new) {
        if(Uuid.isValid(metadataSObject.Uuid__c)) continue;

        metadataSObject.Uuid__c = new Uuid().getValue();
    }
}