public class MetadataSObjectAnalyzer implements Database.Batchable<Schema.SObjectType> {

    private static final String ASSET_DEVELOPER_NAME                  = 'Asset';
    private static final String PLATFORM_FEATURE_ASSET_DEVELOPER_NAME = 'PlatformFeatureAsset';

    private static final Set<Schema.SObjectType> IGNORED_SOBJECT_TYPES = new Set<Schema.SObjectType>{
        // Custom objects used by this app
        Schema.ExternalSystem__c.SObjectType, Schema.ExternalSystem__ChangeEvent.SObjectType, Schema.ExternalSystem__History.SObjectType,
        Schema.ExternalSystemInterface__c.SObjectType, Schema.ExternalSystemInterface__ChangeEvent.SObjectType, Schema.ExternalSystemInterface__History.SObjectType,
        Schema.ExternalSystemField__c.SObjectType, Schema.ExternalSystemField__ChangeEvent.SObjectType, Schema.ExternalSystemField__History.SObjectType,
        Schema.MetadataField__c.SObjectType, Schema.MetadataField__ChangeEvent.SObjectType, Schema.MetadataField__History.SObjectType,
        Schema.MetadataRecordType__c.SObjectType, Schema.MetadataRecordType__ChangeEvent.SObjectType, Schema.MetadataRecordType__History.SObjectType,
        Schema.MetadataSObject__c.SObjectType, Schema.MetadataSObject__ChangeEvent.SObjectType, Schema.MetadataSObject__History.SObjectType,
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

        List<MetadataSObject__c> metadataSObjects                = new List<MetadataSObject__c>();
        List<MetadataSObject__c> metadataPlatformFeatureSObjects = new List<MetadataSObject__c>();
        List<MetadataField__c> metadataFields                    = new List<MetadataField__c>();
        List<MetadataRecordType__c> metadataRecordTypes          = new List<MetadataRecordType__c>();

        for(SObjectType sobjectType : scope) {
            Schema.DescribeSObjectResult sobjectDescribe = sobjectType.getDescribe();

            MetadataSObject__c existingMetadataSObject = existingSObjectTypesByApiName.get(sobjectDescribe.getName());

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
                RecordTypeId       = this.getRecordTypeId(Schema.MetadataSObject__c.SObjectType, ASSET_DEVELOPER_NAME)
            );

            // Link to parent object -- TODO, improve this/move to private method
            metadataSObject.recalculateFormulas();
            //List<String> testFeatureObjects = new List<String>{'AccountFeed', 'AccountHistory'};
            if(metadataSObject.IsPlatformFeatureObject__c == false) {//} && testFeatureObjects.contains(metadataSObject.Name)) {
                metadataSObjects.add(metadataSObject);
            } else {
                String primarySObjectDeveloperName = this.getPrimarySObjectDeveloperName(metadataSObject, sobjectType);

                metadataSObject.PrimaryMetadataSObject__r = new MetadataSObject__c(DeveloperName__c = primarySObjectDeveloperName);
                metadataSObject.RecordTypeId              = this.getRecordTypeId(Schema.MetadataSObject__c.SObjectType, PLATFORM_FEATURE_ASSET_DEVELOPER_NAME);
                metadataPlatformFeatureSObjects.add(metadataSObject);
            }

            // TODO move to private method
            metadataSObject.SystemHashCode__c = System.hashCode(metadataSObject);
            if(existingMetadataSObject != null && existingMetadataSObject.SystemHashCode__c != metadataSObject.SystemHashCode__c) {
                metadataSObject.LastMetadataChangeDate__c = System.now();
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
                    RecordTypeId       = this.getRecordTypeId(Schema.MetadataRecordType__c.SObjectType, ASSET_DEVELOPER_NAME)
                ));
            }

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
                    RecordTypeId            = this.getRecordTypeId(Schema.MetadataField__c.SObjectType, ASSET_DEVELOPER_NAME),
                    ReferenceTo__c          = this.getReferenceToValueString(fieldDescribe),
                    RelationshipName__c     = fieldDescribe.getRelationshipName(),
                    Scale__c                = fieldDescribe.getScale(),
                    Type__c                 = fieldDescribe.getType().name()
                ));
            }
        }
        upsert metadataSObjects DeveloperName__c;
        upsert metadataPlatformFeatureSObjects DeveloperName__c;
        upsert metadataRecordTypes DeveloperName__c;
        upsert metadataFields DeveloperName__c;
    }

    public void finish(Database.BatchableContext batchableContext) {}

    private Map<String, MetadataSObject__c> getExistingSObjectTypesByApiName() {
        Map<String, MetadataSObject__c> existingSObjectTypesByApiName = new Map<String, MetadataSObject__c>();
        for(MetadataSObject__c metadataSObject : [SELECT Id, Name, DeveloperName__c, SystemHashCode__c, IsInScope__c FROM MetadataSObject__c]) {
            existingSObjectTypesByApiName.put(metadataSObject.DeveloperName__c, metadataSObject);
        }
        return existingSObjectTypesByApiName;
    }

    private Id getRecordTypeId(Schema.SObjectType sobjectType, String recordTypeDeveloperName) {
        return sobjectType.getDescribe().getRecordTypeInfosByDeveloperName().get(recordTypeDeveloperName).getRecordTypeId();
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


    private String getPrimarySObjectDeveloperName(MetadataSObject__c metadataSObject, Schema.SObjectType sobjectType) {
        String parentSObjectDeveloperName = sobjectType.getDescribe().getName();

        // TODO make this less awful
        if(parentSObjectDeveloperName.endsWith('__ChangeEvent')) parentSObjectDeveloperName = parentSObjectDeveloperName.replace('__ChangeEvent', '__c');
        if(parentSObjectDeveloperName.endsWith('__Feed')) parentSObjectDeveloperName = parentSObjectDeveloperName.replace('__Feed', '__c');
        if(parentSObjectDeveloperName.endsWith('__History')) parentSObjectDeveloperName = parentSObjectDeveloperName.replace('__History', '__c');

        if(parentSObjectDeveloperName.endsWith('ChangeEvent')) parentSObjectDeveloperName = parentSObjectDeveloperName.replace('ChangeEvent', '');
        if(parentSObjectDeveloperName.endsWith('Feed')) parentSObjectDeveloperName = parentSObjectDeveloperName.replace('Feed', '');
        if(parentSObjectDeveloperName.endsWith('History')) parentSObjectDeveloperName = parentSObjectDeveloperName.replace('History', '');

        return parentSObjectDeveloperName;
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