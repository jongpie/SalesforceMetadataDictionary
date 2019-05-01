/*****************************************************************************************************************
* This file is part of the Metadata Dictionary project for Salesforce, released under the MIT License.           *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
trigger ExternalSystemPackage on ExternalSystemPackage__c(before insert) {
    for(ExternalSystemPackage__c externalSystemPackage : Trigger.new) {
        if(Uuid.isValid(externalSystemPackage.Uuid__c)) continue;

        externalSystemPackage.Uuid__c = new Uuid().getValue();
    }
}