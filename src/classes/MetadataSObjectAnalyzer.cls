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
            String sobjectDeveloperName = sobjectType.getDescribe().getName().toLowerCase();

            if(this.getIgnoredSObjectDeveloperNames().contains(sobjectDeveloperName)) continue;
            else sobjectTypesToProcess.add(sobjectType);
        }
        return sobjectTypesToProcess;
    }

    public void execute(Database.BatchableContext batchableContext, List<Schema.SObjectType> scope) {
        Map<String, MetadataSObject__c> existingSObjectTypesByDeveloperName = this.getExistingSObjectTypesByDeveloperName();

        List<MetadataSObject__c> metadataSObjects                = new List<MetadataSObject__c>();
        List<MetadataSObject__c> metadataPlatformFeatureSObjects = new List<MetadataSObject__c>();
        List<MetadataRecordType__c> metadataRecordTypes          = new List<MetadataRecordType__c>();
        List<MetadataField__c> metadataFields                    = new List<MetadataField__c>();
        List<MetadataPicklistEntry__c> metadataPicklistEntries   = new List<MetadataPicklistEntry__c>();

        for(SObjectType sobjectType : scope) {
            Schema.DescribeSObjectResult sobjectDescribe = sobjectType.getDescribe();

            MetadataSObject__c existingMetadataSObject = existingSObjectTypesByDeveloperName.get(sobjectDescribe.getName());

            // Skip if this SObject Type has already been flagged with status = 'Not Used'
            if(existingMetadataSObject != null && existingMetadataSObject.IsInScope__c == false) continue;

            // Convert the sobject
            MetadataSObject__c metadataSObject = this.convert(sobjectDescribe);

            if(metadataSObject.IsPlatformFeatureObject__c) metadataPlatformFeatureSObjects.add(metadataSObject);
            else metadataSObjects.add(metadataSObject);

            // TODO move to trigger or process builder/eliminate the query if possible
            if(existingMetadataSObject != null && existingMetadataSObject.SystemHashCode__c != metadataSObject.SystemHashCode__c) {
                metadataSObject.LastMetadataChangeDate__c = System.now();
            }

            // Convert any record types
            for(Schema.RecordTypeInfo recordTypeInfo : sobjectDescribe.getRecordTypeInfosByDeveloperName().values()) {
                if(recordTypeInfo.isMaster()) continue; // TODO for now, don't log master record types. Might change later

                MetadataRecordType__c convertedRecordType = this.convert(sobjectDescribe, recordTypeInfo);
                metadataRecordTypes.add(convertedRecordType);
            }

            // Convert any fields
            for(SObjectField field : sobjectDescribe.fields.getMap().values()) {
                MetadataField__c convertedField = this.convert(sobjectDescribe, field.getDescribe());
                metadataFields.add(convertedField);

                for(Schema.PicklistEntry picklistEntry : field.getDescribe().getPicklistValues()) {
                    MetadataPicklistEntry__c convertedPicklistEntry = this.convert(sobjectDescribe, field.getDescribe(), picklistEntry);
                    metadataPicklistEntries.add(convertedPicklistEntry);
                }
            }
        }

        upsert metadataSObjects DeveloperName__c;
        upsert metadataPlatformFeatureSObjects DeveloperName__c;
        upsert metadataRecordTypes DeveloperName__c;
        upsert metadataFields DeveloperName__c;
        upsert metadataPicklistEntries DeveloperName__c;
    }

    public void finish(Database.BatchableContext batchableContext) {}

    private Set<String> getIgnoredSObjectDeveloperNames() {
        // These need to be tracked as strings instead of SObjectType because the objects may not exist in all orgs, but if they do exist, we want to ignore them
        Set<String> ignoredSObjectDeveloperNames = new Set<String>{
            'ActionLinkGroupTemplate', 'ActionLinkTemplate', 'AggregateResult', 'ApexClass', 'ApexComponent', 'ApexEmailNotification', 'ApexLog',
            'ApexPage', 'ApexPageInfo', 'ApexTestQueueItem', 'ApexTestResult', 'ApexTestResultLimits', 'ApexTestRunResult', 'ApexTestSuite',
            'ApexTrigger', 'AppDefinition', 'AppMenuItem', 'Approval', 'AppTabMember', 'AsyncApexJob', 'AuraDefinition', 'AuraDefinitionBundle',
            'AuraDefinitionBundleInfo', 'AuraDefinitionInfo', 'AuthConfig', 'AuthConfigProviders', 'AuthProvider', 'AuthSession',
            'BackgroundOperation', 'BackgroundOperationResult', 'BatchApexErrorEvent', 'BrandingSet', 'BrandingSetProperty', 'BrandTemplate',
            'BusinessProcess', 'ChatterActivity', 'ChatterConversation', 'ChatterConversationMember', 'ChatterExtension',
            'ChatterExtensionConfig', 'ChatterMessage', 'ClientBrowser', 'CollaborationGroup', 'CollaborationGroupFeed', 'CollaborationGroupMember',
            'CollaborationGroupMemberRequest', 'CollaborationGroupRecord', 'CollaborationInvitation', 'ColorDefinition', 'ConferenceNumber',
            'CorsWhitelistEntry', 'CronJobDetail', 'CronTrigger', 'CspTrustedSite', 'CustomBrand', 'CustomBrandAsset', 'CustomHelpMenuItem',
            'CustomHelpMenuSection', 'CustomHttpHeader', 'CustomObjectUserLicenseMetrics', 'CustomPermission', 'CustomPermissionDependency',
            'Dashboard', 'DashboardComponent', 'DashboardComponentFeed', 'DashboardFeed', 'DataAssessmentFieldMetric', 'DataAssessmentMetric',
            'DataAssessmentValueMetric', 'DataIntegrationRecordPurchasePermission', 'DataStatistics', 'DataType', 'Domain', 'DomainSite',
            'EmailDomainFilter', 'EmailDomainKey', 'EmailRelay', 'EmailServicesAddress', 'EmailServicesFunction', 'EmbeddedServiceDetail',
            'EmbeddedServiceLabel', 'EventBusSubscriber', 'EventLogFile', 'ExternalDataSource', 'ExternalDataUserAuth', 'ExternalEvent',
            'ExternalEventMapping', 'FeedComment', 'FeedItem', 'FeedLike', 'FeedPollChoice', 'FeedPollVote', 'FeedRevision', 'FeedSignal',
            'FeedTrackedChange', 'FieldDefinition', 'FieldPermissions', 'FileSearchActivity', 'FlexQueueItem', 'FlowInterview',
            'FlowRecordRelation', 'FlowStageRelation', 'ForecastingAdjustment', 'ForecastingDisplayedFamily', 'ForecastingFact',
            'ForecastingItem', 'ForecastingOwnerAdjustment', 'ForecastingQuota', 'ForecastingShare', 'ForecastingType',
            'ForecastingUserPreference', 'ForecastShare', 'GrantedByLicense', 'IconDefinition', 'IdpEventLog', 'IframeWhiteListUrl',
            'InstalledMobileApp', 'LightningExperienceTheme', 'ListEmail', 'ListEmailChangeEvent', 'ListEmailIndividualRecipient',
            'ListEmailRecipientSource', 'ListEmailShare', 'ListView', 'ListViewChart', 'ListViewChartInstance', 'LoginGeo', 'LoginHistory',
            'LoginIp', 'Macro', 'MacroHistory', 'MacroInstruction', 'MacroShare', 'NamedCredential', 'NavigationLinkSet', 'NavigationMenuItem',
            'OauthToken', 'ObjectPermissions', 'OnboardingMetrics', 'OrgDeleteRequest', 'OrgLifecycleNotification', 'PackageLicense',
            'PermissionSet', 'PermissionSetAssignment', 'PermissionSetLicense', 'PermissionSetLicenseAssign', 'PermissionSetTabSetting',
            'PicklistValueInfo', 'PlatformAction', 'PlatformCachePartition', 'PlatformCachePartitionType', 'PresenceConfigDeclineReason',
            'PresenceDeclineReason', 'PresenceUserConfig', 'PresenceUserConfigProfile', 'PresenceUserConfigUser', 'ProcessDefinition',
            'ProcessInstance', 'ProcessInstanceHistory', 'ProcessInstanceNode', 'ProcessInstanceStep', 'ProcessInstanceWorkItem',
            'ProcessNode', 'Publisher', 'PushTopic', 'QueueRoutingConfig', 'RecentlyViewed', 'RecordVisibility', 'RelationshipDomain',
            'RelationshipInfo', 'SamlSsoConfig', 'Scontrol', 'SearchActivity', 'SearchLayout', 'SearchPromotionRule', 'SessionPermSetActivation',
            'SetupAuditTrail', 'SetupEntityAccess', 'Site', 'SiteDetail', 'SiteIframeWhiteListUrl', 'TabDefinition', 'TenantSecret',
            'TenantUsageEntitlement', 'TestSuiteMembership', 'ThirdPartyAccountLink', 'TransactionSecurityPolicy', 'TwoFactorInfo',
            'TwoFactorMethodsInfo', 'TwoFactorTempCode', 'VerificationHistory', 'VisibilityChangeNotification', 'VisualforceAccessMetrics',
            'WaveAutoInstallRequest', 'WaveCompatibilityCheckItem', 'WebLink'
        };
        List<Schema.SObjectType> appSObjectTypes = new List<Schema.SObjectType>{
            Schema.ExternalSystem__c.SObjectType, Schema.ExternalSystemField__c.SObjectType,
            Schema.ExternalSystemPackage__c.SObjectType, Schema.ExternalSystemPicklistEntry__c.SObjectType,
            Schema.MetadataField__c.SObjectType, Schema.MetadataPicklistEntry__c.SObjectType,
            Schema.MetadataRecordType__c.SObjectType, Schema.MetadataSObject__c.SObjectType
        };
        List<String> suffixes = new List<String>{'ChangeEvent', 'Feed', 'History', 'Share'};
        for(Schema.SObjectType appSObjectType : appSObjectTypes) {
            String baseSObjectDeveloperName = appSObjectType.getDescribe().getName();
            ignoredSObjectDeveloperNames.add(baseSObjectDeveloperName);

            for(String suffix : suffixes) {
                ignoredSObjectDeveloperNames.add(baseSObjectDeveloperName.replace('__c', '__' + suffix));
            }
        }

        // Convert everything to lowercase to make sure all comparisons are accurate
        Set<String> ignoredSObjectDeveloperNamesInLowercase = new Set<String>();
        for(String ignoredSObjectDeveloperName : ignoredSObjectDeveloperNames) {
            ignoredSObjectDeveloperNamesInLowercase.add(ignoredSObjectDeveloperName.toLowerCase());
        }

        return ignoredSObjectDeveloperNamesInLowercase;
    }

    private Map<String, MetadataSObject__c> getExistingSObjectTypesByDeveloperName() {
        Map<String, MetadataSObject__c> existingSObjectTypesByDeveloperName = new Map<String, MetadataSObject__c>();
        for(MetadataSObject__c metadataSObject : [SELECT Id, Name, DeveloperName__c, SystemHashCode__c, IsInScope__c FROM MetadataSObject__c]) {
            existingSObjectTypesByDeveloperName.put(metadataSObject.DeveloperName__c, metadataSObject);
        }
        return existingSObjectTypesByDeveloperName;
    }

    private MetadataSObject__c convert(Schema.DescribeSObjectResult sobjectDescribe) {
        MetadataSObject__c metadataSObject = new MetadataSObject__c(
            DeveloperName__c   = sobjectDescribe.getName(),
            IsCustom__c        = sobjectDescribe.isCustom(),
            IsCustomSetting__c = sobjectDescribe.isCustomSetting(),
            Label__c           = sobjectDescribe.getLabel(),
            LabelLanguage__c   = UserInfo.getLanguage(),
            LabelPlural__c     = sobjectDescribe.getLabelPlural(),
            Name               = sobjectDescribe.getName(),
            Namespace__c       = this.getNamespace(sobjectDescribe),
            RecordTypeId       = this.getRecordTypeId(Schema.MetadataSObject__c.SObjectType, ASSET_DEVELOPER_NAME)
        );
        metadataSObject.recalculateFormulas();

        if(metadataSObject.IsPlatformFeatureObject__c) {
            metadataSObject.RecordTypeId = this.getRecordTypeId(Schema.MetadataSObject__c.SObjectType, PLATFORM_FEATURE_ASSET_DEVELOPER_NAME);

            String primarySObjectDeveloperName = this.getPrimarySObjectDeveloperName(sobjectDescribe);
            if(primarySObjectDeveloperName != null) {
                metadataSObject.PrimaryMetadataSObject__r = new MetadataSObject__c(DeveloperName__c = primarySObjectDeveloperName);
            }
        }

        // Last step: calculate a hash code once all other fields have been set
        metadataSObject.SystemHashCode__c = System.hashCode(metadataSObject);

        return metadataSObject;
    }

    private MetadataRecordType__c convert(Schema.DescribeSObjectResult sobjectDescribe, Schema.RecordTypeInfo recordTypeInfo) {
        MetadataRecordType__c metadataRecordType = new MetadataRecordType__c(
            DeveloperName__c   = sobjectDescribe.getName() + '.' + recordTypeInfo.getDeveloperName(),
            IsActive__c        = recordTypeInfo.isActive(),
            IsMaster__c        = recordTypeInfo.isMaster(),
            MetadataSObject__r = new MetadataSObject__c(DeveloperName__c = sobjectDescribe.getName()),
            Name               = recordTypeInfo.getDeveloperName(),
            Namespace__c       = this.getNamespace(recordTypeInfo),
            RecordTypeId       = this.getRecordTypeId(Schema.MetadataRecordType__c.SObjectType, ASSET_DEVELOPER_NAME)
        );

        return metadataRecordType;
    }

    private MetadataField__c convert(Schema.DescribeSObjectResult sobjectDescribe, Schema.DescribeFieldResult fieldDescribe) {
        MetadataField__c metadataField = new MetadataField__c(
            DefaultValue__c         = String.valueOf(fieldDescribe.getDefaultValue()),
            DefaultValueFormula__c  = fieldDescribe.getDefaultValueFormula(),
            DeveloperName__c        = sobjectDescribe.getName() + '.' + fieldDescribe.getName(),
            Digits__c               = fieldDescribe.getDigits(),
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
            MetadataSObject__r      = new MetadataSObject__c(DeveloperName__c = sobjectDescribe.getName()),
            Name                    = fieldDescribe.getName(),
            Namespace__c            = this.getNamespace(fieldDescribe),
            Precision__c            = fieldDescribe.getPrecision(),
            RecordTypeId            = this.getRecordTypeId(Schema.MetadataField__c.SObjectType, ASSET_DEVELOPER_NAME),
            ReferenceTo__c          = this.getReferenceToValueString(fieldDescribe),
            RelationshipName__c     = fieldDescribe.getRelationshipName(),
            Scale__c                = fieldDescribe.getScale(),
            Type__c                 = fieldDescribe.getType().name()
        );

        return metadataField;
    }

    private MetadataPicklistEntry__c convert(Schema.DescribeSObjectResult sobjectDescribe, Schema.DescribeFieldResult fieldDescribe, Schema.PicklistEntry picklistEntry) {
        String fieldDeveloperName = sobjectDescribe.getName() + '.' + fieldDescribe.getName();
        String picklistEntryDeveloperName = fieldDeveloperName + '.' + picklistEntry.getValue();

        MetadataPicklistEntry__c metadataPicklistEntry = new MetadataPicklistEntry__c(
            DeveloperName__c  = picklistEntryDeveloperName,
            IsActive__c       = picklistEntry.IsActive(),
            IsDefaultValue__c = picklistEntry.isDefaultValue(),
            Label__c          = picklistEntry.getLabel(),
            MetadataField__r  = new MetadataField__c(DeveloperName__c = fieldDeveloperName),
            Name              = picklistEntry.getValue(),
            RecordTypeId      = this.getRecordTypeId(Schema.MetadataPicklistEntry__c.SObjectType, ASSET_DEVELOPER_NAME)
        );

        return metadataPicklistEntry;
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

    private String getPrimarySObjectDeveloperName(Schema.DescribeSObjectResult sobjectDescribe) {
        String customSeparator = '__';

        List<String> platformFeatureSObjectSuffixes = new List<String>{'ChangeEvent', 'Feed', 'History', 'Share'};

        String primarySObjectDeveloperName;
        for(String platformFeatureSObjectSuffix : platformFeatureSObjectSuffixes) {
            String currentSObjectDeveloperName = sobjectDescribe.getName();

            Boolean primaryIsCustom;
            if(currentSObjectDeveloperName.endsWith(customSeparator + platformFeatureSObjectSuffix)) primaryIsCustom = true;
            else if(currentSObjectDeveloperName.endsWith(platformFeatureSObjectSuffix)) primaryIsCustom = false;
            else continue;

            String primarySObjectSuffix = primaryIsCustom ? '__c' : '';
            String separator = primaryIsCustom ? customSeparator : '';

            primarySObjectDeveloperName = currentSObjectDeveloperName.replace(separator + platformFeatureSObjectSuffix, primarySObjectSuffix);
            break;
        }

        // ActivityHistory is a platform feature without a primary sobject
        if(sobjectDescribe.getSObjectType() == Schema.ActivityHistory.SObjectType) primarySObjectDeveloperName = null;
        // OpportunityFieldHistory doesn't follow Salesforce's standard naming convention since OpportunityHistory also exists
        if(sobjectDescribe.getSObjectType() == Schema.OpportunityFieldHistory.SObjectType) primarySObjectDeveloperName = Schema.Opportunity.SObjectType.getDescribe().getName();
System.debug('primarySObjectDeveloperName=' + primarySObjectDeveloperName);
        return primarySObjectDeveloperName;
    }

    private String getReferenceToValueString(Schema.DescribeFieldResult fieldDescribe) {
        List<String> values = new List<String>();
        for(Schema.SObjectType sobjectType : fieldDescribe.getReferenceTo()) {
            values.add(sobjectType.getDescribe().getName());
        }
        return String.join(values, '\n');
    }

}
