/*****************************************************************************************************************
* This file is part of the Metadata Dictionary project for Salesforce, released under the MIT License.           *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
public class MetadataSObjectAnalyzer implements Database.Batchable<Schema.SObjectType> {

    private static final String ASSET_DEVELOPER_NAME                  = 'Asset';
    private static final String PLATFORM_FEATURE_ASSET_DEVELOPER_NAME = 'PlatformFeatureAsset';

    public Iterable<Schema.SObjectType> start(Database.BatchableContext batchableContext) {
        List<Schema.SObjectType> sobjectTypesToProcess = new List<Schema.SObjectType>();
        for(Schema.SObjectType sobjectType : Schema.getGlobalDescribe().values()) {
            String sobjectDeveloperName = sobjectType.getDescribe().getName();

            if(this.getIgnoredSObjectDeveloperNames().contains(sobjectDeveloperName)) continue;
            else sobjectTypesToProcess.add(sobjectType);
        }
        return sobjectTypesToProcess;
    }

    public void execute(Database.BatchableContext batchableContext, List<Schema.SObjectType> scope) {
        Map<String, MetadataSObject__c> existingSObjectTypesByDeveloperName = this.getExistingSObjectTypesByDeveloperName();

        List<MetadataSObject__c> metadataSObjects                = new List<MetadataSObject__c>();
        List<MetadataSObject__c> metadataPlatformFeatureSObjects = new List<MetadataSObject__c>();
        List<MetadataField__c> metadataFields                    = new List<MetadataField__c>();
        List<MetadataRecordType__c> metadataRecordTypes          = new List<MetadataRecordType__c>();

        for(SObjectType sobjectType : scope) {
            Schema.DescribeSObjectResult sobjectDescribe = sobjectType.getDescribe();

            MetadataSObject__c existingMetadataSObject = existingSObjectTypesByDeveloperName.get(sobjectDescribe.getName());

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
                String primarySObjectDeveloperName = this.getPrimarySObjectDeveloperName(sobjectType);

                if(primarySObjectDeveloperName != null) {
                    metadataSObject.PrimaryMetadataSObject__r = new MetadataSObject__c(DeveloperName__c = primarySObjectDeveloperName);
                }
                metadataSObject.RecordTypeId = this.getRecordTypeId(Schema.MetadataSObject__c.SObjectType, PLATFORM_FEATURE_ASSET_DEVELOPER_NAME);
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

    private Set<String> getIgnoredSObjectDeveloperNames() {
        // These need to be tracked as strings instead of SObjectType because the objects may not exist in all orgs, but if they do exist, we want to ignore them
        Set<String> ignoredSObjectDeveloperNames = new Set<String>{
            'Aggregateresult', 'ApexClass', 'ApexComponent', 'ApexEmailNotification', 'ApexLog', 'ApexPage', 'ApexPageInfo', 'ApexTestQueueItem', 'ApexTestResult',
            'ApexTestResultLimits', 'ApexTestRunResult', 'ApexTestSuite', 'ApexTrigger', 'AppDefinition', 'AppMenuItem', 'AppTabMember', 'AsyncApexJob', 'AuraDefinition',
            'AuraDefinitionBundle', 'AuraDefinitionBundleInfo', 'AuraDefinitionInfo', 'AuthConfig', 'AuthConfigProviders', 'AuthProvider', 'AuthSession',
            'BackgroundOperation', 'BackgroundOperationResult', 'BatchApexErrorEvent', 'BrandingSet', 'BrandingSetProperty', 'BrandTemplate', 'BusinessProcess',
            'ClientBrowser', 'ColorDefinition', 'ConferenceNumber', 'CorsWhitelistEntry', 'CronJobDetail', 'CronTrigger', 'CspTrustedSite', 'CustomBrand',
            'CustomBrandAsset', 'CustomObjectUserLicenseMetrics', 'Dashboard', 'DashboardComponent', 'DashboardComponentFeed', 'DashboardFeed',
            'DataAssessmentFieldMetric', 'DataAssessmentMetric', 'DataAssessmentValueMetric', 'DataStatistics', 'DataType', 'Domain', 'DomainSite', 'FlexQueueItem',
            'FlowRecordRelation', 'FlowStageRelation', 'ForecastingAdjustment', 'ForecastingDisplayedFamily', 'ForecastingFact', 'ForecastingItem',
            'ForecastingOwnerAdjustment', 'ForecastingQuota', 'ForecastingShare', 'ForecastingType', 'ForecastingUserPreference', 'ForecastShare', 'IconDefinition',
            'IdpEventLog', 'InstalledMobileApp', 'LightningExperienceTheme', 'ListEmail', 'ListEmailChangeEvent', 'ListEmailRecipientSource', 'ListEmailShare', 'ListView',
            'ListViewChart', 'ListViewChartInstance', 'LoginGeo', 'LoginHistory', 'LoginIp', 'Macro', 'MacroHistory', 'MacroInstruction', 'MacroShare', 'NamedCredential',
            'NavigationLinkSet', 'NavigationMenuItem', 'OauthToken', 'OnboardingMetrics', 'PackageLicense', 'PermissionSetTabSetting', 'PlatformAction',
            'PlatformCachePartition', 'PlatformCachePartitionType', 'PresenceConfigDeclineReason', 'PresenceDeclineReason', 'ProcessInstance', 'ProcessInstanceHistory',
            'ProcessInstanceNode', 'ProcessInstanceStep', 'ProcessInstanceWorkItem', 'ProcessNode', 'Publisher', 'PushTopic',

            'VerificationHistory'
        };
        List<Schema.SObjectType> appSObjectTypes = new List<Schema.SObjectType>{
            Schema.ExternalSystem__c.SObjectType, Schema.ExternalSystemField__c.SObjectType, Schema.ExternalSystemInterface__c.SObjectType,
            Schema.MetadataField__c.SObjectType, Schema.MetadataRecordType__c.SObjectType, Schema.MetadataSObject__c.SObjectType
        };
        List<String> suffixes = new List<String>{'ChangeEvent', 'Feed', 'History', 'Share'};
        for(Schema.SObjectType appSObjectType : appSObjectTypes) {
            String baseSObjectDeveloperName = appSObjectType.getDescribe().getName();
            ignoredSObjectDeveloperNames.add(baseSObjectDeveloperName);

            for(String suffix : suffixes) {
                ignoredSObjectDeveloperNames.add(baseSObjectDeveloperName.replace('__c', suffix));
            }
        }

        return ignoredSObjectDeveloperNames;
    }

    private Map<String, MetadataSObject__c> getExistingSObjectTypesByDeveloperName() {
        Map<String, MetadataSObject__c> existingSObjectTypesByDeveloperName = new Map<String, MetadataSObject__c>();
        for(MetadataSObject__c metadataSObject : [SELECT Id, Name, DeveloperName__c, SystemHashCode__c, IsInScope__c FROM MetadataSObject__c]) {
            existingSObjectTypesByDeveloperName.put(metadataSObject.DeveloperName__c, metadataSObject);
        }
        return existingSObjectTypesByDeveloperName;
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

    private String getNamespace(String fullDeveloperName) {
        Integer localNameIndex = fullDeveloperName
            .replace('__c', '')           // Custom objects & custom settings
            .replace('__e', '')           // Custom platform events
            .replace('__mdt', '')         // Custom metadata types
            .replace('__ChangeEvent', '') // Standard platform events
            .replace('__Feed', '')        // Chatter feed
            .replace('__History', '')     // History object
            .replace('__Share', '')       // Share object
            .indexOf('__');               // Now we can determine if there is a namespace

        return localNameIndex < 0 ? null : fullDeveloperName.substring(0, localNameIndex);
    }

    private String getPrimarySObjectDeveloperName(Schema.SObjectType sobjectType) {
        String separator   = sobjectType.getDescribe().isCustom() ? '__' : '';
        String replacement = sobjectType.getDescribe().isCustom() ? '__c' : '';

        List<String> platformFeatureSObjectSuffixes = new List<String>{'ChangeEvent', 'Feed', 'History', 'Share'};

        String parentSObjectDeveloperName;
        for(String platformFeatureSObjectSuffix : platformFeatureSObjectSuffixes) {
            if(!sobjectType.getDescribe().getName().endsWith(separator + platformFeatureSObjectSuffix)) continue;

            String currentSObjectDeveloperName = sobjectType.getDescribe().getName();
            parentSObjectDeveloperName = currentSObjectDeveloperName.replace(separator + platformFeatureSObjectSuffix, separator + replacement);
        }

        // ActivityHistory is a platform feature without a parent sobject
        if(sobjectType == Schema.ActivityHistory.SObjectType) parentSObjectDeveloperName = null;
        // OpportunityFieldHistory doesn't follow Salesforce's standard naming convention since OpportunityHistory also exists
        if(sobjectType == Schema.OpportunityFieldHistory.SObjectType) parentSObjectDeveloperName = Schema.Opportunity.SObjectType.getDescribe().getName();

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