/*****************************************************************************************************************
* This file is part of the Metadata Dictionary project for Salesforce, released under the MIT License.           *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
public without sharing class ExternalSystemBackupService implements Database.AllowsCallouts, Database.Batchable<SObject> {

    private static final String STATIC_RESOURCE_PREFIX   = 'MetadataDictionary';
    private static final String STATIC_RESOURCE_ENDPOINT = System.Url.getSalesforceBaseUrl().toExternalForm() + '/services/data/v45.0/sobjects/StaticResource';

    private static final String FIELDS_CHILD_RELATIONSHIP_NAME       = getChildRelationshipName(Schema.ExternalSystem__c.SObjectType, Schema.ExternalSystemField__c.SObjectType, Schema.ExternalSystemField__c.ExternalSystem__c);
    private static final String RECORD_TYPES_CHILD_RELATIONSHIP_NAME = getChildRelationshipName(Schema.ExternalSystem__c.SObjectType, Schema.ExternalSystemInterface__c.SObjectType, Schema.ExternalSystemInterface__c.ExternalSystem__c);

    private class StaticResourceTemplate {
        private String Body         {get; set;}
        private String CacheControl {get; set;}
        private String ContentType  {get; set;}
        private String Description  {get; set;}
        private String Name         {get; set;}
    }

    public List<ExternalSystem__c> start(Database.BatchableContext batchableContext) {
        return Database.query(this.getQueryString());
    }

    public void execute(Database.BatchableContext batchableContext, List<ExternalSystem__c> scope) {
        System.debug('scope=' + scope);

        // Get any existing static resources so we can update them
        Map<String, Id> existingStaticResourceIdsByName = new Map<String, Id>();
        for(StaticResource staticResource : [SELECT Id, Name FROM StaticResource WHERE Name LIKE :STATIC_RESOURCE_PREFIX + '%']) {
            existingStaticResourceIdsByName.put(staticResource.Name, StaticResource.Id);
        }

        for(ExternalSystem__c externalSystem : scope) {
            ExternalSystem__c cleanedSObject = externalSystem.clone(false, true, false, false);
            Map<String, Object> cleanedSObjectDto = (Map<String, Object>)Json.deserializeUntyped(Json.serialize(cleanedSObject));

            // Cleanup the fields before serialization
            if(!externalSystem.ExternalSystemFields__r.isEmpty()) {
                List<ExternalSystemField__c> cleanedFields = new List<ExternalSystemField__c>();
                for(ExternalSystemField__c metadataField : externalSystem.ExternalSystemFields__r) {
                    ExternalSystemField__c cleanedField = metadataField.clone(false, true, false, false);
                    cleanedField.ExternalSystem__c = null;

                    Map<String, Object> cleanedFieldDto = (Map<String, Object>)Json.deserializeUntyped(Json.serialize(cleanedField));
                    cleanedFieldDto = this.removeUnusedAttributes(cleanedFieldDto);

                    cleanedField = (Schema.ExternalSystemField__c)Json.deserialize(Json.serialize(cleanedFieldDto), ExternalSystemField__c.class);

                    cleanedFields.add(cleanedField);
                }
                Map<String, Object> fields = (Map<String, Object>)cleanedSObjectDto.get(FIELDS_CHILD_RELATIONSHIP_NAME);
                fields.put('records', cleanedFields);
            }

            // Cleanup the record types before serialization
            if(!externalSystem.ExternalSystemInterfaces__r.isEmpty()) {
                List<ExternalSystemInterface__c> cleanedExternalSystemInterfaces = new List<ExternalSystemInterface__c>();
                for(ExternalSystemInterface__c externalSystemInterface : externalSystem.ExternalSystemInterfaces__r) {
                    ExternalSystemInterface__c cleanedExternalSystemInterface = externalSystemInterface.clone(false, true, false, false);
                    cleanedExternalSystemInterface.ExternalSystem__c = null;

                    Map<String, Object> cleanedExternalSystemInterfaceDto = (Map<String, Object>)Json.deserializeUntyped(Json.serialize(cleanedExternalSystemInterface));
                    cleanedExternalSystemInterfaceDto = this.removeUnusedAttributes(cleanedExternalSystemInterfaceDto);

                    cleanedExternalSystemInterface = (Schema.ExternalSystemInterface__c)Json.deserialize(Json.serialize(cleanedExternalSystemInterfaceDto), ExternalSystemInterface__c.class);

                    cleanedExternalSystemInterfaces.add(cleanedExternalSystemInterface);
                }
                Map<String, Object> recordTypes = (Map<String, Object>)cleanedSObjectDto.get(RECORD_TYPES_CHILD_RELATIONSHIP_NAME);
                recordTypes.put('records', cleanedExternalSystemInterfaces);
            }

            cleanedSObjectDto = this.removeUnusedAttributes(cleanedSObjectDto);

            Blob requestBlob = Blob.valueOf(Json.serializePretty(cleanedSObjectDto));

            StaticResourceTemplate staticResource = new StaticResourceTemplate();
            staticResource.Body         = EncodingUtil.base64Encode(requestBlob);//finReq;//Json.serialize(scope);
            staticResource.CacheControl = 'Private';
            staticResource.ContentType  = 'application/json';
            staticResource.Description  = 'Metadata Dictionary - External System - ' + externalSystem.Name;
            staticResource.Name         = STATIC_RESOURCE_PREFIX + '_' + externalSystem.Uuid__c.replace('-', '_');

            Id staticResourceId = existingStaticResourceIdsByName.get(staticResource.Name);
            this.createStaticResource(Json.serialize(staticResource), staticResourceId);
        }
    }

    public void finish(Database.BatchableContext batchableContext) {

    }

    private String getQueryString() {
        String query = '';

        List<String> externalSystemFieldsToQuery    = this.getFieldsToQuery(Schema.ExternalSystem__c.SObjectType);
        List<String> externalSystemFieldFieldsToQuery      = this.getFieldsToQuery(Schema.ExternalSystemField__c.SObjectType);
        List<String> externalSystemInterfaceFieldsToQuery = this.getFieldsToQuery(Schema.ExternalSystemInterface__c.SObjectType);

        query = 'SELECT ' + String.join(externalSystemFieldsToQuery, ', ')
                + ', (SELECT ' + String.join(externalSystemFieldFieldsToQuery, ', ') + ' FROM ' + FIELDS_CHILD_RELATIONSHIP_NAME + ')'
                + ', (SELECT ' + String.join(externalSystemInterfaceFieldsToQuery, ', ') + ' FROM ' + RECORD_TYPES_CHILD_RELATIONSHIP_NAME + ')'
                + ' FROM ' + Schema.ExternalSystem__c.SObjectType;
        System.debug('query=' + query);
        return query;
    }

    private List<String> getFieldsToQuery(Schema.SObjectType sobjectType) {
        Map<String, Schema.SObjectField> allFieldsByApiName = sobjectType.getDescribe().fields.getMap();

        List<String> fields = new List<String>();
        for(Schema.SObjectField field : allFieldsByApiName.values()) {
            //Skip any system fields
            if(!field.getDescribe().isPermissionable() && !field.getDescribe().isNameField()) continue;

            fields.add(field.getDescribe().getName().toLowerCase());
        }

        if(allFieldsByApiName.containsKey('recordtypeid')) {
            fields.add('recordtype.developername');
        }
        /*fields.addAll(new List<String>{
            'RecordType.DeveloperName'.toLowerCase()
        });*/

  /*      if(sobjectType == Schema.ExternalSystem__c.SObjectType) {
            fields.add('PrimaryMetadataSObject__r.Uuid__c'.toLowerCase());
        }*/

        return fields;
    }

    private static String getChildRelationshipName(Schema.SObjectType parentSObjectType, Schema.SObjectType childSObjectType, Schema.SObjectField lookupField) {
        String relationshipName;
        for(Schema.ChildRelationship cr : Schema.ExternalSystem__c.SObjectType.getDescribe().getChildRelationships()) {
            if(cr.getChildSObject() != childSObjectType) continue;
            if(cr.getField() != lookupField) continue;

            relationshipName = cr.getRelationshipName();
        }
        return relationshipName;
    }

    private Map<String, Object> removeUnusedAttributes(Map<String, Object> cleanedSObjectDto) {
        // TODO use this to remove extra details from audit fields, record type, etc
        cleanedSObjectDto.remove('attributes');
        cleanedSObjectDto.remove(Schema.ExternalSystemField__c.ExternalSystem__c.getDescribe().getName());
        cleanedSObjectDto.remove(Schema.ExternalSystemInterface__c.ExternalSystem__c.getDescribe().getName());
        //cleanedSObjectDto.remove(Schema.ExternalSystem__c.PrimaryExternalSystem__c.getDescribe().getName());
        cleanedSObjectDto.remove('RecordTypeId');

        /*String primarySObjectRelationshipName = Schema.ExternalSystem__c.PrimaryExternalSystem__c.getDescribe().getRelationshipName();
        if(cleanedSObjectDto.containsKey(primarySObjectRelationshipName)) {
            Map<String, Object> primarySObjectDto = (Map<String, Object>)cleanedSObjectDto.get(primarySObjectRelationshipName);
            primarySObjectDto.remove('attributes');
            primarySObjectDto.remove('Id');

            cleanedSObjectDto.put(primarySObjectRelationshipName, primarySObjectDto);
        }*/

/*        if(cleanedSObjectDto.containsKey(Schema.ExternalSystemField.ExternalSystem__c.getDescribe().getRelationshipName()) || cleanedSObjectDto.containsKey(Schema.ExternalSystemInterface__c.ExternalSystem__c.getDescribe().getRelationshipName())) {
            Map<String, Object> recordTypeDto = (Map<String, Object>)cleanedSObjectDto.get('RecordType');
            recordTypeDto.remove('attributes');
            recordTypeDto.remove('Id');

            cleanedSObjectDto.put('RecordType', recordTypeDto);
        }*/

        if(cleanedSObjectDto.containsKey('RecordType')) {
            Map<String, Object> recordTypeDto = (Map<String, Object>)cleanedSObjectDto.get('RecordType');
            recordTypeDto.remove('attributes');
            recordTypeDto.remove('Id');

            cleanedSObjectDto.put('RecordType', recordTypeDto);
        }

        return cleanedSObjectDto;
    }

    private HttpResponse createStaticResource(String requestBody) {
        return this.createStaticResource(requestBody, null);
    }

    private HttpResponse createStaticResource(String requestBody, Id staticResourceId) {
        String calculatedEndpoint = STATIC_RESOURCE_ENDPOINT;
        if(staticResourceId != null)  calculatedEndpoint += '/' + staticResourceId + '?_HttpMethod=PATCH';
        System.debug('calculatedEndpoint=' + calculatedEndpoint);
        System.debug('requestBody=' + requestBody);

        HttpRequest request = new HttpRequest();
        request.setEndpoint(calculatedEndpoint);
        request.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        request.setHeader('Content-Type', 'application/json');
        request.setBody(requestBody);
        request.setMethod('POST');

        // Execute the callout & verify the response
        HttpResponse response = new Http().send(request);
        System.assert(response.getStatusCode() < 300, 'Status code ' + response.getStatusCode() + ', Error: ' + response.getStatus());

        return response;
    }

}