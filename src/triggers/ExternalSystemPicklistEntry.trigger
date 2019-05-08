/*****************************************************************************************************************
* This file is part of the Metadata Dictionary project for Salesforce, released under the MIT License.           *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
trigger ExternalSystemPicklistEntry on ExternalSystemPicklistEntry__c(before insert) {
    for(ExternalSystemPicklistEntry__c externalSystemPicklistEntry : Trigger.new) {
        if(Uuid.isValid(externalSystemPicklistEntry.Uuid__c)) continue;

        externalSystemPicklistEntry.Uuid__c = new Uuid().getValue();
    }
}