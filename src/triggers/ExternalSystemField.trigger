/*****************************************************************************************************************
* This file is part of the Nebula Logger project, released under the MIT License.                                *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
trigger ExternalSystemField on ExternalSystemField__c(before insert) {
    for(ExternalSystemField__c externalSystemField : Trigger.new) {
        if(Uuid.isValid(externalSystemField.Uuid__c)) continue;

        externalSystemField.Uuid__c = new Uuid().getValue();
    }
}