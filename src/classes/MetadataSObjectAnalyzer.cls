public class MetadataSObjectAnalyzer implements Database.Batchable<Schema.SObjectType> {

    private static final String ASSET_DEVELOPER_NAME = 'Asset';

    private static final Set<Schema.SObjectType> IGNORED_SOBJECT_TYPES = new Set<Schema.SObjectType>{
        // Custom objects used by this app
        Schema.ExternalSystem__c.SObjectType, Schema.ExternalSystem__ChangeEvent.SObjectType,
        Schema.ExternalSystem__Feed.SObjectType, Schema.ExternalSystem__History.SObjectType,
        Schema.ExternalSystemField__c.SObjectType, Schema.ExternalSystemField__ChangeEvent.SObjectType,
        Schema.ExternalSystemField__Feed.SObjectType, Schema.ExternalSystemField__History.SObjectType,
        Schema.MetadataField__c.SObjectType, Schema.MetadataField__ChangeEvent.SObjectType,
        Schema.MetadataField__Feed.SObjectType, Schema.MetadataField__History.SObjectType,
        Schema.MetadataRecordType__c.SObjectType, Schema.MetadataRecordType__ChangeEvent.SObjectType,
        Schema.MetadataRecordType__Feed.SObjectType, Schema.MetadataRecordType__History.SObjectType,
        Schema.MetadataSObject__c.SObjectType, Schema.MetadataSObject__ChangeEvent.SObjectType,
        Schema.MetadataSObject__Feed.SObjectType, Schema.MetadataSObject__History.SObjectType,
        // Standard objects that aren't currently helpful to document
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
        Map<String, MetadataSObject__c> existingSObjectTypesByApiName = this.getExistingSObjectTypesByApiName();

        this.analyze(scope, existingSObjectTypesByApiName);
    }

    public void finish(Database.BatchableContext batchableContext) {}

    private Map<String, MetadataSObject__c> getExistingSObjectTypesByApiName() {
        Map<String, MetadataSObject__c> existingSObjectTypesByApiName = new Map<String, MetadataSObject__c>();
        for(MetadataSObject__c metadataSObject : [SELECT Id, Name, DeveloperName__c, SystemHashCode__c, IsInScope__c FROM MetadataSObject__c]) {
            existingSObjectTypesByApiName.put(metadataSObject.DeveloperName__c, metadataSObject);
        }
        return existingSObjectTypesByApiName;
    }

    private void analyze(List<Schema.SObjectType> sobjectTypes, Map<String, MetadataSObject__c> getExistingSObjectTypesByApiName) {
        List<MetadataSObject__c> metadataSObjects       = new List<MetadataSObject__c>();
        List<MetadataField__c> metadataFields           = new List<MetadataField__c>();
        List<MetadataRecordType__c> metadataRecordTypes = new List<MetadataRecordType__c>();

        for(SObjectType sobjectType : sobjectTypes) {
            Schema.DescribeSObjectResult sobjectDescribe = sobjectType.getDescribe();

            MetadataSObject__c existingMetadataSObject = getExistingSObjectTypesByApiName.get(sobjectDescribe.getName());

            // Skip if this SObject Type has already been flagged with status = 'Not Used'
            if(existingMetadataSObject != null && existingMetadataSObject.IsInScope__c == false) continue;

            MetadataSObject__c metadataSObject = new MetadataSObject__c(
                DeveloperName__c   = sobjectDescribe.getName(),
                IsCustom__c        = sobjectDescribe.isCustom(),
                IsCustomSetting__c = sobjectDescribe.isCustomSetting(),
                Label__c           = sobjectDescribe.getLabel(),
                LabelPlural__c     = sobjectDescribe.getLabelPlural(),
                LabelLanguage__c   = UserInfo.getLanguage(),
                Name               = sobjectDescribe.getName(),
                Namespace__c       = this.getNamespace(sobjectDescribe),
                RecordTypeId       = this.getAssetRecordTypeId(Schema.MetadataSObject__c.SObjectType)
            );

            // Link to parent object -- TODO, improve this/move to private method
            metadataSObject.recalculateFormulas();
            List<String> testFeatureObjects = new List<String>{'AccountFeed', 'AccountHistory'};
            if(metadataSObject.IsPlatformFeatureObject__c && testFeatureObjects.contains(metadataSObject.Name)) {
                metadataSObject.ParentSObject__r = new MetadataSObject__c(DeveloperName__c = 'Account');
            }

            // TODO move to private method
            metadataSObject.SystemHashCode__c = System.hashCode(metadataSObject);
            if(existingMetadataSObject != null && existingMetadataSObject.SystemHashCode__c != metadataSObject.SystemHashCode__c) {
                metadataSObject.LastMetadataChangeDate__c = System.now();
            }

            metadataSObjects.add(metadataSObject);

            for(SObjectField field : sobjectDescribe.fields.getMap().values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                metadataFields.add(new MetadataField__c(
                    DefaultValue__c         = String.valueOf(fieldDescribe.getDefaultValue()),
                    Digits__c               = fieldDescribe.getDigits(),
                    MetadataSObject__r      = new MetadataSObject__c(DeveloperName__c = sobjectDescribe.getName()),
                    DeveloperName__c        = sobjectDescribe.getName() + '.' + fieldDescribe.getName(),
                    InlineHelpText__c       = fieldDescribe.getInlineHelpText(),
                    IsCalculated__c         = fieldDescribe.isCalculated(),
                    IsCustom__c             = fieldDescribe.isCustom(),
                    IsExternalId__c         = fieldDescribe.IsExternalId(),
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
                    RecordTypeId            = this.getAssetRecordTypeId(Schema.MetadataField__c.SObjectType),
                    ReferenceTo__c          = this.getReferenceToValueString(fieldDescribe),
                    RelationshipName__c     = fieldDescribe.getRelationshipName(),
                    Scale__c                = fieldDescribe.getScale(),
                    Type__c                 = fieldDescribe.getType().name()
                ));
            }

            for(Schema.RecordTypeInfo recordTypeInfo : sobjectDescribe.getRecordTypeInfosByDeveloperName().values()) {
                if(recordTypeInfo.isMaster()) continue; // TODO for now, don't log master record types. Might change later

                metadataRecordTypes.add(new MetadataRecordType__c(
                    MetadataSObject__r = new MetadataSObject__c(DeveloperName__c = sobjectType.getDescribe().getName()),
                    DeveloperName__c   = sobjectType.getDescribe().getName() + '.' + recordTypeInfo.getDeveloperName(),
                    IsActive__c        = recordTypeInfo.isActive(),
                    IsMaster__c        = recordTypeInfo.isMaster(),
                    Name               = recordTypeInfo.getDeveloperName(),
                    Namespace__c       = this.getNamespace(recordTypeInfo),
                    RecordTypeId       = this.getAssetRecordTypeId(Schema.MetadataRecordType__c.SObjectType)
                ));
            }
        }
        upsert metadataSObjects DeveloperName__c;
        upsert metadataFields DeveloperName__c;
        upsert metadataRecordTypes DeveloperName__c;
    }

    private Id getAssetRecordTypeId(Schema.SObjectType sobjectType) {
        return sobjectType.getDescribe().getRecordTypeInfosByDeveloperName().get(ASSET_DEVELOPER_NAME).getRecordTypeId();
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