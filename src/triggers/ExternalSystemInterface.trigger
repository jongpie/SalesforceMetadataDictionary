/*****************************************************************************************************************
* This file is part of the Nebula Logger project, released under the MIT License.                                *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
trigger ExternalSystemInterface on ExternalSystemInterface__c(before insert) {
    for(ExternalSystemInterface__c externalSystemInterface : Trigger.new) {
        if(Uuid.isValid(externalSystemInterface.Uuid__c)) continue;

        externalSystemInterface.Uuid__c = new Uuid().getValue();
    }
}