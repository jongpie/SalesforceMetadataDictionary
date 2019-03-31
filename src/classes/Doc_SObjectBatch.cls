public class Doc_SObjectBatch implements Database.Batchable<Schema.SObjectType> {

    private static final Set<Schema.SObjectType> IGNORED_SOBJECT_TYPES = new Set<Schema.SObjectType>{
        Schema.ApexClass.SObjectType, Schema.ApexComponent.SObjectType, Schema.ApexEmailNotification.SObjectType,
        Schema.ApexLog.SObjectType, Schema.ApexPage.SObjectType, Schema.ApexPageInfo.SObjectType,
        Schema.ApexTestQueueItem.SObjectType, Schema.ApexTestResult.SObjectType, Schema.ApexTestResultLimits.SObjectType,
        Schema.ApexTestRunResult.SObjectType, Schema.ApexTestSuite.SObjectType, Schema.ApexTrigger.SObjectType,
        Schema.AuraDefinition.SObjectType, Schema.AuraDefinitionBundle.SObjectType,
        Schema.AuraDefinitionBundleInfo.SObjectType, Schema.AuraDefinitionInfo.SObjectType,
        Schema.BatchApexErrorEvent.SObjectType
    };

    public Iterable<Schema.SObjectType> start(Database.BatchableContext batchableContext) {
        List<Schema.SObjectType> sobjectTypesToProcess = new List<Schema.SObjectType>();
        for(Schema.SObjectType sobjectType : Schema.getGlobalDescribe().values()) {
            if(IGNORED_SOBJECT_TYPES.contains(sobjectType)) continue;
            else sobjectTypesToProcess.add(sobjectType);
        }
        return sobjectTypesToProcess;
    }

    public void execute(Database.BatchableContext batchableContext, List<Schema.SObjectType> scope) {
        Map<String, Doc_SObject__c> existingSObjectTypesByApiName = this.getExistingSObjectTypesByApiName();

        this.analyze(scope, existingSObjectTypesByApiName);
    }

    public void finish(Database.BatchableContext batchableContext) {}

    private Map<String, Doc_SObject__c> getExistingSObjectTypesByApiName() {
        Map<String, Doc_SObject__c> existingSObjectTypesByApiName = new Map<String, Doc_SObject__c>();
        for(Doc_SObject__c docSObject : [SELECT Id, Name, DeveloperName__c, SystemHashCode__c, InScope__c FROM Doc_SObject__c]) {
            existingSObjectTypesByApiName.put(docSObject.DeveloperName__c, docSObject);
        }
        return existingSObjectTypesByApiName;
    }

    private void analyze(List<Schema.SObjectType> sobjectTypes, Map<String, Doc_SObject__c> getExistingSObjectTypesByApiName) {
        List<Doc_SObject__c> doc_SObjects       = new List<Doc_SObject__c>();
        List<Doc_Field__c> doc_Fields           = new List<Doc_Field__c>();
        List<Doc_RecordType__c> doc_RecordTypes = new List<Doc_RecordType__c>();

        for(SObjectType sobjectType : sobjectTypes) {
            Schema.DescribeSObjectResult sobjectDescribe = sobjectType.getDescribe();

            Doc_SObject__c existingDocSObject = getExistingSObjectTypesByApiName.get(sobjectDescribe.getName());

            // Skip if this SObject Type has already been flagged with status = 'Not Used'
            if(existingDocSObject != null && existingDocSObject.InScope__c == false) continue;

            Doc_SObject__c docSObject = new Doc_SObject__c(
                DeveloperName__c   = sobjectDescribe.getName(),
                IsCustom__c        = sobjectDescribe.isCustom(),
                IsCustomSetting__c = sobjectDescribe.isCustomSetting(),
                Label__c           = sobjectDescribe.getLabel(),
                LabelPlural__c     = sobjectDescribe.getLabelPlural(),
                LabelLanguage__c   = UserInfo.getLanguage(),
                Name               = sobjectDescribe.getName(),
                Namespace__c       = this.getNamespace(sobjectDescribe),
                RecordTypeId       = this.getAssetRecordTypeId(Schema.Doc_SObject__c.SObjectType)
            );

            // Link to parent object -- TODO, improve this/move to private method
            docSObject.recalculateFormulas();
            List<String> testFeatureObjects = new List<String>{'AccountFeed', 'AccountHistory'};
            if(docSObject.IsPlatformFeatureObject__c && testFeatureObjects.contains(docSObject.Name)) {
                docSObject.ParentSObject__r = new Doc_SObject__c(DeveloperName__c = 'Account');
            }

            // TODO move to private method
            docSObject.SystemHashCode__c = System.hashCode(docSObject);
            if(existingDocSObject != null && existingDocSObject.SystemHashCode__c != docSObject.SystemHashCode__c) {
                docSObject.LastMetadataChangeDate__c = System.now();
            }

            doc_SObjects.add(docSObject);

            for(SObjectField field : sobjectDescribe.fields.getMap().values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                doc_Fields.add(new Doc_Field__c(
                    DefaultValue__c         = String.valueOf(fieldDescribe.getDefaultValue()),
                    Digits__c               = fieldDescribe.getDigits(),
                    Doc_SObject__r          = new Doc_SObject__c(DeveloperName__c = sobjectDescribe.getName()),
                    DeveloperName__c        = sobjectDescribe.getName() + '.' + fieldDescribe.getName(),
                    InlineHelpText__c       = fieldDescribe.getInlineHelpText(),
                    IsCustom__c             = fieldDescribe.isCustom(),
                    IsNillable__c           = fieldDescribe.isNillable(),
                    IsPermissionable__c     = fieldDescribe.isPermissionable(),
                    IsRestrictedDelete__c   = fieldDescribe.isRestrictedDelete(),
                    IsRestrictedPicklist__c = fieldDescribe.isRestrictedPicklist(),
                    IsUnique__c             = fieldDescribe.isUnique(),
                    Label__c                = fieldDescribe.getLabel(),
                    Length__c               = fieldDescribe.getLength(),
                    Name                    = fieldDescribe.getName(),
                    Namespace__c            = this.getNamespace(fieldDescribe),
                    PicklistValues__c       = this.getPicklistValueString(field),
                    Precision__c            = fieldDescribe.getPrecision(),
                    RecordTypeId            = this.getAssetRecordTypeId(Schema.Doc_Field__c.SObjectType),
                    ReferenceTo__c          = this.getReferenceToValueString(fieldDescribe),
                    RelationshipName__c     = fieldDescribe.getRelationshipName(),
                    Scale__c                = fieldDescribe.getScale(),
                    Type__c                 = fieldDescribe.getType().name()
                ));
            }

            for(Schema.RecordTypeInfo recordTypeInfo : sobjectDescribe.getRecordTypeInfosByDeveloperName().values()) {
                if(recordTypeInfo.isMaster()) continue; // TODO for now, don't log master record types. Might change later

                doc_RecordTypes.add(new Doc_RecordType__c(
                    Doc_SObject__r   = new Doc_SObject__c(DeveloperName__c = sobjectType.getDescribe().getName()),
                    DeveloperName__c = sobjectType.getDescribe().getName() + '.' + recordTypeInfo.getDeveloperName(),
                    IsActive__c      = recordTypeInfo.isActive(),
                    IsMaster__c      = recordTypeInfo.isMaster(),
                    Name             = recordTypeInfo.getDeveloperName(),
                    Namespace__c     = this.getNamespace(recordTypeInfo),
                    RecordTypeId     = this.getAssetRecordTypeId(Schema.Doc_RecordType__c.SObjectType)
                ));
            }
        }
        upsert doc_SObjects DeveloperName__c;
        upsert doc_Fields DeveloperName__c;
        upsert doc_RecordTypes DeveloperName__c;
    }

    private Id getAssetRecordTypeId(Schema.SObjectType sobjectType) {
        return sobjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Asset').getRecordTypeId();
    }

    private String getNamespace(Schema.DescribeSObjectResult sobjectDescribe) {
        return this.getNameSpace(sobjectDescribe.getName());
    }

    private String getNamespace(Schema.DescribeFieldResult fieldDescribe) {
        return this.getNameSpace(fieldDescribe.getName());
    }

    private String getNameSpace(Schema.RecordTypeInfo recordTypeInfo) {
        return this.getNamespace(recordTypeInfo.getDeveloperName());
    }

    private String getNamespace(String fullApiName) {
        Integer localNameIndex = fullApiName
            .replace('__c', '')           // Custom objects & custom settings
            .replace('__e', '')           // Custom platform events
            .replace('__mdt', '')         // Custom metadata types
            .replace('__ChangeEvent', '') // Standard platform events
            .replace('__Feed', '')        // Chatter feed
            .replace('__History', '')     // History object
            .indexOf('__');               // Now we can determine if there is a namespace

        return localNameIndex < 0 ? null : fullApiName.substring(0, localNameIndex);
    }

    private String getReferenceToValueString(Schema.DescribeFieldResult fieldDescribe) {
        List<String> values = new List<String>();
        for(Schema.SObjectType sobjectType : fieldDescribe.getReferenceTo()) {
            values.add(sobjectType.getDescribe().getName());
        }
        return String.join(values, '\n');
    }

    private String getPicklistValueString(Schema.SObjectField field) {
        String valueString = String.join(this.getPicklistValues(field), '\n');
        if(valueString.length() > field.getDescribe().getLength()) return 'Too many values';
        return valueString;
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