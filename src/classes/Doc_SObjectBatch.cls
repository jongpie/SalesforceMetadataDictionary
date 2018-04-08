public class Doc_SObjectBatch implements Database.Batchable<Schema.SObjectType> {

    public Iterable<SObjectType> start(Database.BatchableContext batchableContext) {
        return Schema.getGlobalDescribe().values();
    }

    public void execute(Database.BatchableContext batchableContext, List<Schema.SObjectType> scope) {
        this.analyze(scope);
    }

    public void finish(Database.BatchableContext batchableContext) {}

    private void analyze(List<Schema.SObjectType> sobjectTypes) {
        List<Doc_SObject__c> doc_SObjects       = new List<Doc_SObject__c>();
        List<Doc_Field__c> doc_Fields           = new List<Doc_Field__c>();
        List<Doc_RecordType__c> doc_RecordTypes = new List<Doc_RecordType__c>();

        for(SObjectType sobjectType : sobjectTypes) {
            Schema.DescribeSObjectResult sobjectDescribe = sobjectType.getDescribe();

            if(sobjectDescribe.getName() != 'Account' && !sobjectDescribe.isCustom()) continue;

            doc_SObjects.add(new Doc_SObject__c(
                ExtId__c           = sobjectDescribe.getName(),
                IsCustom__c        = sobjectDescribe.isCustom(),
                IsCustomSetting__c = sobjectDescribe.isCustomSetting(),
                Name               = sobjectDescribe.getName(),
                Namespace__c       = this.getNamespace(sobjectDescribe)
            ));

            for(SObjectField field : sobjectDescribe.fields.getMap().values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                
                doc_Fields.add(new Doc_Field__c(
                    ExtId__c          = sobjectDescribe.getName() + '.' + fieldDescribe.getName(),
                    Doc_SObject__r    = new Doc_SObject__c(ExtId__c = sobjectDescribe.getName()),
                    InlineHelpText__c = fieldDescribe.getInlineHelpText(),
                    IsCustom__c       = fieldDescribe.isCustom(),
                    Length__c         = fieldDescribe.getLength(),
                    Name              = fieldDescribe.getName(),
                    PicklistValues__c = String.join(this.getPicklistValues(field), '\n'),
                    Type__c           = fieldDescribe.getType().name()
                ));
            }

            for(Schema.RecordTypeInfo recordTypeInfo : sobjectDescribe.getRecordTypeInfosByDeveloperName().values()) {
                doc_RecordTypes.add(new Doc_RecordType__c(
                    Doc_SObject__r  = new Doc_SObject__c(ExtId__c = sobjectType.getDescribe().getName()),
                    ExtId__c        = sobjectType.getDescribe().getName() + '.' + recordTypeInfo.getDeveloperName(),
                    IsActive__c     = recordTypeInfo.isActive(),
                    IsMaster__c     = recordTypeInfo.isMaster(),
                    Name            = recordTypeInfo.getDeveloperName()
                ));
            }
        }
        upsert doc_SObjects ExtId__c;
        upsert doc_Fields ExtId__c;
        upsert doc_RecordTypes ExtId__c;
    }

    private String getNamespace(Schema.DescribeSObjectResult sobjectDescribe) {
        String fullApiName     = sobjectDescribe.getName();
        Integer localNameIndex = fullApiName.replace('__c', '').indexOf('__');

        return localNameIndex < 0 ? null : fullApiName.substring(0, localNameIndex);
    }

    private List<String> getPicklistValues(Schema.SObjectField field) {
        Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
        List<String> picklistValues = new List<String>();

        if(fieldDescribe.getPickListValues().isEmpty()) return picklistValues;

        for(Schema.PicklistEntry picklistEntry : fieldDescribe.getPickListValues()) {
            picklistValues.add(picklistEntry.getValue());
        }
        return picklistValues;
    }

}