/*****************************************************************************************************************
* This file is part of the Metadata Dictionary project for Salesforce, released under the MIT License.           *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
trigger ExternalSystem on ExternalSystem__c(before insert) {
    for(ExternalSystem__c externalSystem : Trigger.new) {
        if(Uuid.isValid(externalSystem.Uuid__c)) continue;

        externalSystem.Uuid__c = new Uuid().getValue();
    }
}