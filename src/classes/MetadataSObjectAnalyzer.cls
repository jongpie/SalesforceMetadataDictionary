/*****************************************************************************************************************
* This file is part of the Metadata Dictionary project for Salesforce, released under the MIT License.           *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
public class MetadataSObjectAnalyzer implements Database.Batchable<Schema.SObjectType> {

    private static final String ASSET_DEVELOPER_NAME                  = 'Asset';
    private static final String PLATFORM_FEATURE_ASSET_DEVELOPER_NAME = 'PlatformFeatureAsset';

    private static final Set<Schema.SObjectType> IGNORED_SOBJECT_TYPES = new Set<Schema.SObjectType>{
        // Custom objects used by this app
        Schema.ExternalSystem__c.SObjectType, Schema.ExternalSystem__ChangeEvent.SObjectType, Schema.ExternalSystem__Feed.SObjectType,Schema.ExternalSystem__History.SObjectType,
        Schema.ExternalSystemInterface__c.SObjectType, Schema.ExternalSystemInterface__ChangeEvent.SObjectType, Schema.ExternalSystemInterface__Feed.SObjectType,Schema.ExternalSystemInterface__History.SObjectType,
        Schema.ExternalSystemField__c.SObjectType, Schema.ExternalSystemField__ChangeEvent.SObjectType, Schema.ExternalSystemField__Feed.SObjectType,Schema.ExternalSystemField__History.SObjectType,
        Schema.MetadataField__c.SObjectType, Schema.MetadataField__ChangeEvent.SObjectType, Schema.MetadataField__Feed.SObjectType,Schema.MetadataField__History.SObjectType,
        Schema.MetadataRecordType__c.SObjectType, Schema.MetadataRecordType__ChangeEvent.SObjectType, Schema.MetadataRecordType__Feed.SObjectType,Schema.MetadataRecordType__History.SObjectType,
        Schema.MetadataSObject__c.SObjectType, Schema.MetadataSObject__ChangeEvent.SObjectType, Schema.MetadataSObject__Feed.SObjectType,Schema.MetadataSObject__History.SObjectType,
        // Standard objects that aren't currently helpful to document
        Schema.ApexClass.SObjectType, Schema.ApexComponent.SObjectType, Schema.ApexEmailNotification.SObjectType,
        Schema.ApexLog.SObjectType, Schema.ApexPage.SObjectType, Schema.ApexPageInfo.SObjectType,
        Schema.ApexTestQueueItem.SObjectType, Schema.ApexTestResult.SObjectType, Schema.ApexTestResultLimits.SObjectType,
        Schema.ApexTestRunResult.SObjectType, Schema.ApexTestSuite.SObjectType, Schema.ApexTrigger.SObjectType,
        Schema.AuraDefinition.SObjectType, Schema.AuraDefinitionBundle.SObjectType,
        Schema.AuraDefinitionBundleInfo.SObjectType, Schema.AuraDefinitionInfo.SObjectType,
        Schema.BatchApexErrorEvent.SObjectType,


        Schema.Aggregateresult.SObjectType,
        Schema.AppDefinition.SObjectType,
        Schema.AppMenuItem.SObjectType,
        Schema.AppTabMember.SObjectType,
        Schema.AsyncApexJob.SObjectType,
        Schema.AuthConfig.SObjectType,
        Schema.AuthProvider.SObjectType,
        Schema.AuthConfigProviders.SObjectType,
        Schema.AuthSession.SObjectType,
        Schema.BackgroundOperation.SObjectType,
        //Schema.BackgroundOperationResult.SObjectType,
        Schema.BrandingSet.SObjectType,
        Schema.BrandingSetProperty.SObjectType,
        Schema.BrandTemplate.SObjectType,
        Schema.BusinessProcess.SObjectType,
        Schema.ClientBrowser.SObjectType,
        Schema.ColorDefinition.SObjectType,
        //Schema.ConferenceNumber.SObjectType,
        Schema.CorsWhitelistEntry.SObjectType,
        Schema.CronJobDetail.SObjectType,
        Schema.CronTrigger.SObjectType,
        Schema.CspTrustedSite.SObjectType,
        Schema.CustomBrand.SObjectType,
        Schema.CustomBrandAsset.SObjectType,
        Schema.CustomObjectUserLicenseMetrics.SObjectType,
        Schema.Dashboard.SObjectType,
        Schema.DashboardComponent.SObjectType,
        Schema.DashboardComponentFeed.SObjectType,
        Schema.DashboardFeed.SObjectType,
        Schema.DataAssessmentFieldMetric.SObjectType,
        Schema.DataAssessmentMetric.SObjectType,
        Schema.DataAssessmentValueMetric.SObjectType,
        Schema.DataStatistics.SObjectType,
        Schema.DataType.SObjectType,
        Schema.Domain.SObjectType,
        Schema.DomainSite.SObjectType,
        Schema.IconDefinition.SObjectType,
        Schema.FlexQueueItem.SObjectType,
        Schema.FlowRecordRelation.SObjectType,
        Schema.FlowStageRelation.SObjectType,
    /*Schema.ForecastingAdjustment.SObjectType,
    Schema.ForecastingDisplayedFamily.SObjectType,
    Schema.ForecastingFact.SObjectType,
    Schema.ForecastingItem.SObjectType,
    Schema.ForecastingOwnerAdjustment.SObjectType,
    Schema.ForecastingQuota.SObjectType,
    Schema.ForecastingShare.SObjectType,
    Schema.ForecastingType.SObjectType,
    Schema.ForecastingUserPreference.SObjectType,*/
    Schema.ForecastShare.SObjectType,
        Schema.IdpEventLog.SObjectType,
        Schema.InstalledMobileApp.SObjectType,
        Schema.LightningExperienceTheme.SObjectType,
        Schema.ListEmail.SObjectType,
        Schema.ListEmailChangeEvent.SObjectType,
        Schema.ListEmailRecipientSource.SObjectType,
        Schema.ListEmailShare.SObjectType,
        //Schema.ListView.SObjectType,
        //Schema.ListViewChart.SObjectType,
        Schema.ListViewChartInstance.SObjectType,
        Schema.LoginGeo.SObjectType,
        Schema.LoginHistory.SObjectType,
        Schema.LoginIp.SObjectType,
        Schema.Macro.SObjectType,
        Schema.MacroHistory.SObjectType,
        Schema.MacroInstruction.SObjectType,
        Schema.MacroShare.SObjectType,
        Schema.NamedCredential.SObjectType,
        //Schema.NavigationLinkSet.SObjectType,
        //Schema.NavigationMenuItem.SObjectType
        Schema.OauthToken.SObjectType,
        Schema.OnboardingMetrics.SObjectType,
        Schema.PackageLicense.SObjectType,
        Schema.PermissionSetTabSetting.SObjectType,
        Schema.PlatformAction.SObjectType,
        Schema.PlatformCachePartition.SObjectType,
        Schema.PlatformCachePartitionType.SObjectType,
        //Schema.PresenceConfigDeclineReason.SObjectType,
        //Schema.PresenceDeclineReason.SObjectType,
        Schema.ProcessInstance.SObjectType,
        Schema.ProcessInstanceHistory.SObjectType,
        Schema.ProcessInstanceNode.SObjectType,
        Schema.ProcessInstanceStep.SObjectType,
        Schema.ProcessInstanceWorkItem.SObjectType,
        Schema.ProcessNode.SObjectType,
        Schema.Publisher.SObjectType,
        Schema.PushTopic.SObjectType
    };

    public Iterable<Schema.SObjectType> start(Database.BatchableContext batchableContext) {
        List<Schema.SObjectType> sobjectTypesToProcess = new List<Schema.SObjectType>();
        for(Schema.SObjectType sobjectType : Schema.getGlobalDescribe().values()) {
            String sobjectApiName = sobjectType.getDescribe().getName();

            if(this.getIgnoredSObjectApiNames().contains(sobjectApiName)) continue;
            //if(IGNORED_SOBJECT_TYPES.contains(sobjectType)) continue;
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

    private Set<String> getIgnoredSObjectApiNames() {
        Set<String> ignoredSObjectApiNames = new Set<String>{
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
            String baseSObjectApiName = appSObjectType.getDescribe().getName();
            ignoredSObjectApiNames.add(baseSObjectApiName);

            for(String suffix : suffixes) {
                ignoredSObjectApiNames.add(baseSObjectApiName.replace('__c', suffix));
            }
        }

        return ignoredSObjectApiNames;
    }

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
            .replace('__Share', '')       // Share object
            .indexOf('__');               // Now we can determine if there is a namespace

        return localNameIndex < 0 ? null : fullApiName.substring(0, localNameIndex);
    }


    private String getPrimarySObjectDeveloperName(MetadataSObject__c metadataSObject, Schema.SObjectType sobjectType) {
        String parentSObjectDeveloperName = sobjectType.getDescribe().getName();

        // TODO make this less awful
        if(parentSObjectDeveloperName.endsWith('__ChangeEvent')) parentSObjectDeveloperName = parentSObjectDeveloperName.replace('__ChangeEvent', '__c');
        if(parentSObjectDeveloperName.endsWith('__Feed')) parentSObjectDeveloperName = parentSObjectDeveloperName.replace('__Feed', '__c');
        if(parentSObjectDeveloperName.endsWith('__History')) parentSObjectDeveloperName = parentSObjectDeveloperName.replace('__History', '__c');
        if(parentSObjectDeveloperName.endsWith('__Share')) parentSObjectDeveloperName = parentSObjectDeveloperName.replace('__Share', '__c');

        if(parentSObjectDeveloperName.endsWith('ChangeEvent')) parentSObjectDeveloperName = parentSObjectDeveloperName.replace('ChangeEvent', '');
        if(parentSObjectDeveloperName.endsWith('Feed')) parentSObjectDeveloperName = parentSObjectDeveloperName.replace('Feed', '');
        if(parentSObjectDeveloperName.endsWith('History')) parentSObjectDeveloperName = parentSObjectDeveloperName.replace('History', '');
        if(parentSObjectDeveloperName.endsWith('Share')) parentSObjectDeveloperName = parentSObjectDeveloperName.replace('Share', '');

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