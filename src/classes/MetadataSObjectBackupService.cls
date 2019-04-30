/*****************************************************************************************************************
* This file is part of the Metadata Dictionary project for Salesforce, released under the MIT License.           *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
public without sharing class MetadataSObjectBackupService implements Database.AllowsCallouts, Database.Batchable<SObject> {

    private static final String STATIC_RESOURCE_PREFIX   = 'MetadataDictionary';
    private static final String STATIC_RESOURCE_ENDPOINT = System.Url.getSalesforceBaseUrl().toExternalForm() + '/services/data/v45.0/sobjects/StaticResource';

    private static final String FIELDS_CHILD_RELATIONSHIP_NAME       = getChildRelationshipName(Schema.MetadataSObject__c.SObjectType, Schema.MetadataField__c.SObjectType, Schema.MetadataField__c.MetadataSObject__c);
    private static final String RECORD_TYPES_CHILD_RELATIONSHIP_NAME = getChildRelationshipName(Schema.MetadataSObject__c.SObjectType, Schema.MetadataRecordType__c.SObjectType, Schema.MetadataRecordType__c.MetadataSObject__c);

    private class StaticResourceTemplate {
        private String Body         {get; set;}
        private String CacheControl {get; set;}
        private String ContentType  {get; set;}
        private String Description  {get; set;}
        private String Name         {get; set;}
    }

    public List<MetadataSObject__c> start(Database.BatchableContext batchableContext) {
        return Database.query(this.getMetadataSObjectQueryString());
    }

    public void execute(Database.BatchableContext batchableContext, List<MetadataSObject__c> scope) {
        Map<Id, List<MetadataField__c>> metadataFieldsByMetadataSObjectId           = this.queryChildRecords(scope, Schema.MetadataField__c.SObjectType, Schema.MetadataField__c.MetadataSObject__c);
        Map<Id, List<MetadataRecordType__c>> metadataRecordTypesByMetadataSObjectId = this.queryChildRecords(scope, Schema.MetadataRecordType__c.SObjectType, Schema.MetadataRecordType__c.MetadataSObject__c);

        // Get any existing static resources so we can update them
        Map<String, Id> existingStaticResourceIdsByName = new Map<String, Id>();
        for(StaticResource staticResource : [SELECT Id, Name FROM StaticResource WHERE Name LIKE :STATIC_RESOURCE_PREFIX + '%']) {
            existingStaticResourceIdsByName.put(staticResource.Name, StaticResource.Id);
        }

        for(MetadataSObject__c metadataSObject : scope) {
            MetadataSObject__c cleanedSObject = metadataSObject.clone(false, true, false, false);
            Map<String, Object> cleanedSObjectDto = (Map<String, Object>)Json.deserializeUntyped(Json.serialize(cleanedSObject));

            // Cleanup the fields before serialization
            if(metadataFieldsByMetadataSObjectId.containsKey(metadataSObject.Id)) {
                List<MetadataField__c> cleanedFields = new List<MetadataField__c>();
                for(MetadataField__c metadataField : metadataFieldsByMetadataSObjectId.get(metadataSObject.Id)) {
                    MetadataField__c cleanedField = metadataField.clone(false, true, false, false);
                    cleanedField.MetadataSObject__c = null;

                    Map<String, Object> cleanedFieldDto = (Map<String, Object>)Json.deserializeUntyped(Json.serialize(cleanedField));
                    cleanedFieldDto = this.removeUnusedAttributes(cleanedFieldDto);

                    cleanedField = (Schema.MetadataField__c)Json.deserialize(Json.serialize(cleanedFieldDto), MetadataField__c.class);

                    cleanedFields.add(cleanedField);
                }

                Map<String, Object> fieldsDto = new Map<String, Object>();
                fieldsDto.put('records', cleanedFields);
                fieldsDto.put('totalSize', cleanedFields.size());
                fieldsDto.put('done', true);
                fieldsDto = this.removeUnusedAttributes(fieldsDto);

                cleanedSObjectDto.put(FIELDS_CHILD_RELATIONSHIP_NAME, fieldsDto);
            }

            // Cleanup the record types before serialization
            if(metadataRecordTypesByMetadataSObjectId.containsKey(metadataSObject.Id)) {
                List<MetadataRecordType__c> cleanedRecordTypes = new List<MetadataRecordType__c>();
                for(MetadataRecordType__c metadataRecordType : metadataRecordTypesByMetadataSObjectId.get(metadataSObject.Id)) {
                    MetadataRecordType__c cleanedRecordType = metadataRecordType.clone(false, true, false, false);
                    cleanedRecordType.MetadataSObject__c = null;

                    Map<String, Object> cleanedRecordTypeDto = (Map<String, Object>)Json.deserializeUntyped(Json.serialize(cleanedRecordType));
                    cleanedRecordTypeDto = this.removeUnusedAttributes(cleanedRecordTypeDto);

                    cleanedRecordType = (Schema.MetadataRecordType__c)Json.deserialize(Json.serialize(cleanedRecordTypeDto), MetadataRecordType__c.class);

                    cleanedRecordTypes.add(cleanedRecordType);
                }
                Map<String, Object> recordTypesDto = new Map<String, Object>();
                recordTypesDto.put('records', cleanedRecordTypes);
                recordTypesDto.put('totalSize', cleanedRecordTypes.size());
                recordTypesDto.put('done', true);
                recordTypesDto = this.removeUnusedAttributes(recordTypesDto);

                cleanedSObjectDto.put(RECORD_TYPES_CHILD_RELATIONSHIP_NAME, recordTypesDto);
            }

            cleanedSObjectDto = this.removeUnusedAttributes(cleanedSObjectDto);

            Blob requestBlob = Blob.valueOf(Json.serializePretty(cleanedSObjectDto));

            StaticResourceTemplate staticResource = new StaticResourceTemplate();
            staticResource.Body         = EncodingUtil.base64Encode(requestBlob);//finReq;//Json.serialize(scope);
            staticResource.CacheControl = 'Private';
            staticResource.ContentType  = 'application/json';
            staticResource.Description  = 'Metadata Dictionary - SObject - ' + metadataSObject.Name;
            staticResource.Name         = STATIC_RESOURCE_PREFIX + '_' + metadataSObject.Uuid__c.replace('-', '_');

            Id staticResourceId = existingStaticResourceIdsByName.get(staticResource.Name);
            this.createStaticResource(Json.serialize(staticResource), staticResourceId);
        }
    }

    public void finish(Database.BatchableContext batchableContext) {}

    private String getMetadataSObjectQueryString() {
        List<String> fieldsToQuery = this.getFieldsToQuery(Schema.MetadataSObject__c.SObjectType);

        return 'SELECT ' + String.join(fieldsToQuery, ', ') + ' FROM ' + Schema.MetadataSObject__c.SObjectType;
    }

    private List<String> getFieldsToQuery(Schema.SObjectType sobjectType) {
        Map<String, Schema.SObjectField> allFieldsByApiName = sobjectType.getDescribe().fields.getMap();

        List<String> fields = new List<String>();
        for(Schema.SObjectField field : allFieldsByApiName.values()) {
            //Skip any system fields
            if(!field.getDescribe().isPermissionable() && !field.getDescribe().isNameField()) continue;

            fields.add(field.getDescribe().getName().toLowerCase());
        }

        fields.add('Id');

        if(allFieldsByApiName.containsKey('recordtypeid')) {
            fields.add('recordtype.developername');
        }

        if(sobjectType == Schema.MetadataSObject__c.SObjectType) {
            fields.add('PrimaryMetadataSObject__r.Uuid__c'.toLowerCase());
        }

        if(sobjectType == Schema.MetadataField__c.SObjectType) {
            fields.add(Schema.MetadataField__c.MetadataSObject__c.getDescribe().getRelationshipName() + '.' + Schema.MetadataSObject__c.Uuid__c.getDescribe().getName());
        }

        if(sobjectType == Schema.MetadataRecordType__c.SObjectType) {
            fields.add(Schema.MetadataRecordType__c.MetadataSObject__c.getDescribe().getRelationshipName() + '.' + Schema.MetadataSObject__c.Uuid__c.getDescribe().getName());
        }

        return fields;
    }

    private Map<Id, List<SObject>> queryChildRecords(List<SObject> parentRecords, Schema.SObjectType childObject, Schema.SObjectField referenceField) {
        String referenceFieldDeveloperName = referenceField.getDescribe().getName();

        String query = 'SELECT ' + String.join(this.getFieldsToQuery(childObject), ', ')
            + ' FROM ' + childObject
            + ' WHERE ' + referenceFieldDeveloperName + ' IN :parentRecords';

        Map<Id, List<SObject>> childRecordsByParentId = new Map<Id, List<SObject>>();
        for(SObject record : Database.query(query)) {
            String parentId = (String)record.get(referenceFieldDeveloperName);

            if(!childRecordsByParentId.containsKey(parentId)) childRecordsByParentId.put(parentId, new List<SObject>());

            List<SObject> childRecords = childRecordsByParentId.get(parentId);
            childRecords.add(record);

            childRecordsByParentId.put(parentId, childRecords);
        }

        return childRecordsByParentId;
    }

    private static String getChildRelationshipName(Schema.SObjectType parentSObjectType, Schema.SObjectType childSObjectType, Schema.SObjectField lookupField) {
        String relationshipName;
        for(Schema.ChildRelationship cr : parentSObjectType.getDescribe().getChildRelationships()) {
            if(cr.getChildSObject() != childSObjectType) continue;
            if(cr.getField() != lookupField) continue;

            relationshipName = cr.getRelationshipName();
        }
        return relationshipName;
    }

    private Map<String, Object> removeUnusedAttributes(Map<String, Object> cleanedSObjectDto) {
        // TODO need to cleanup/improve
        cleanedSObjectDto.remove('attributes');
        cleanedSObjectDto.remove(Schema.MetadataField__c.MetadataSObject__c.getDescribe().getName());
        cleanedSObjectDto.remove(Schema.MetadataRecordType__c.MetadataSObject__c.getDescribe().getName());
        cleanedSObjectDto.remove(Schema.MetadataSObject__c.PrimaryMetadataSObject__c.getDescribe().getName());
        cleanedSObjectDto.remove('Id');
        cleanedSObjectDto.remove('RecordTypeId');

        String primarySObjectRelationshipName = Schema.MetadataSObject__c.PrimaryMetadataSObject__c.getDescribe().getRelationshipName();
        if(cleanedSObjectDto.containsKey(primarySObjectRelationshipName)) {
            Map<String, Object> primarySObjectDto = (Map<String, Object>)cleanedSObjectDto.get(primarySObjectRelationshipName);
            primarySObjectDto.remove('attributes');
            primarySObjectDto.remove('Id');

            cleanedSObjectDto.put(primarySObjectRelationshipName, primarySObjectDto);
        }

        String metadataSObjectRelationshipNameForField = Schema.MetadataField__c.MetadataSObject__c.getDescribe().getRelationshipName();
        if(cleanedSObjectDto.containsKey(metadataSObjectRelationshipNameForField)) {
            Map<String, Object> parentMetadataSObjectDto = (Map<String, Object>)cleanedSObjectDto.get(metadataSObjectRelationshipNameForField);
            parentMetadataSObjectDto.remove('attributes');
            parentMetadataSObjectDto.remove('Id');

            cleanedSObjectDto.put(metadataSObjectRelationshipNameForField, parentMetadataSObjectDto);
        }

        String metadataSObjectRelationshipNameForRecordType = Schema.MetadataRecordType__c.MetadataSObject__c.getDescribe().getRelationshipName();
        if(cleanedSObjectDto.containsKey(metadataSObjectRelationshipNameForRecordType)) {
            Map<String, Object> parentMetadataSObjectDto = (Map<String, Object>)cleanedSObjectDto.get(metadataSObjectRelationshipNameForRecordType);
            parentMetadataSObjectDto.remove('attributes');
            parentMetadataSObjectDto.remove('Id');

            cleanedSObjectDto.put(metadataSObjectRelationshipNameForRecordType, parentMetadataSObjectDto);
        }

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