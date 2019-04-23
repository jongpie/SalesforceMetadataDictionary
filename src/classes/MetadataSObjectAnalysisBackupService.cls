/*****************************************************************************************************************
* This file is part of the Metadata Dictionary project for Salesforce, released under the MIT License.           *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
public without sharing class MetadataSObjectAnalysisBackupService implements Database.AllowsCallouts, Database.Batchable<SObject> {


/*

For later importing...

StaticResource sr = [select id, body from StaticResource where name like 'MetadataDictionary001%'];
String statResBody = sr.body.toString();
System.debug(statResBody);
List<MetadataSObject__c> records = (List<MetadataSObject__c>)Json.deserialize(statResBody, List<MetadataSObject__c>.class);
System.debug(records);

*/
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
        return Database.query(this.getQueryString());
    }

    public void execute(Database.BatchableContext batchableContext, List<MetadataSObject__c> scope) {
        System.debug('scope=' + scope);

        // Get any existing static resources so we can update them
        Map<String, Id> existingStaticResourceIdsByName = new Map<String, Id>();
        for(StaticResource staticResource : [SELECT Id, Name FROM StaticResource WHERE Name LIKE :STATIC_RESOURCE_PREFIX + '%']) {
            existingStaticResourceIdsByName.put(staticResource.Name, StaticResource.Id);
        }

        for(MetadataSObject__c metadataSObject : scope) {
            MetadataSObject__c cleanedSObject = metadataSObject.clone(false, true, false, false);
            Map<String, Object> cleanedSObjectDto = (Map<String, Object>)Json.deserializeUntyped(Json.serialize(cleanedSObject));

            // Cleanup the fields before serialization
            if(!metadataSObject.MetadataFields__r.isEmpty()) {
                List<MetadataField__c> cleanedFields = new List<MetadataField__c>();
                for(MetadataField__c metadataField : metadataSObject.MetadataFields__r) {
                    MetadataField__c cleanedField = metadataField.clone(false, true, false, false);
                    cleanedField.MetadataSObject__c = null;
                    cleanedFields.add(cleanedField);
                }
                Map<String, Object> fields = (Map<String, Object>)cleanedSObjectDto.get(FIELDS_CHILD_RELATIONSHIP_NAME);
                fields.put('records', cleanedFields);
            }

            // Cleanup the record types before serialization
            if(!metadataSObject.MetadataRecordTypes__r.isEmpty()) {
                List<MetadataRecordType__c> cleanedRecordTypes = new List<MetadataRecordType__c>();
                for(MetadataRecordType__c metadataRecordType : metadataSObject.MetadataRecordTypes__r) {
                    MetadataRecordType__c cleanedRecordType = metadataRecordType.clone(false, true, false, false);
                    cleanedRecordType.MetadataSObject__c = null;
                    cleanedRecordTypes.add(cleanedRecordType);
                }
                Map<String, Object> recordTypes = (Map<String, Object>)cleanedSObjectDto.get(RECORD_TYPES_CHILD_RELATIONSHIP_NAME);
                recordTypes.put('records', cleanedRecordTypes);
            }

            Blob requestBlob = Blob.valueOf(Json.serialize(cleanedSObjectDto));

            StaticResourceTemplate staticResource = new StaticResourceTemplate();
            staticResource.Body         = EncodingUtil.base64Encode(requestBlob);//finReq;//Json.serialize(scope);
            staticResource.CacheControl = 'Private';
            staticResource.ContentType  = 'application/json';
            staticResource.Description  = 'Metadata Dictionary contents';
            staticResource.Name         = this.generateStaticResourceName(metadataSObject);

            Id staticResourceId = existingStaticResourceIdsByName.get(staticResource.Name);
            this.createStaticResource(Json.serialize(staticResource), staticResourceId);
        }
    }

    public void finish(Database.BatchableContext batchableContext) {

    }

    private String getQueryString() {
        String query = '';

        List<String> sobjectFieldsToQuery    = this.getFieldsToQuery(Schema.MetadataSObject__c.SObjectType);
        List<String> fieldFieldsToQuery      = this.getFieldsToQuery(Schema.MetadataField__c.SObjectType);
        List<String> recordTypeFieldsToQuery = this.getFieldsToQuery(Schema.MetadataRecordType__c.SObjectType);

        query = 'SELECT ' + String.join(sobjectFieldsToQuery, ', ')
                + ', (SELECT ' + String.join(fieldFieldsToQuery, ', ') + ' FROM ' + FIELDS_CHILD_RELATIONSHIP_NAME + ')' // TODO replace with field token instead of hardcoded string
                + ', (SELECT ' + String.join(recordTypeFieldsToQuery, ', ') + ' FROM ' + RECORD_TYPES_CHILD_RELATIONSHIP_NAME + ')' // TODO replace with field token instead of hardcoded string
                + ' FROM ' + Schema.MetadataSObject__c.SObjectType;
        System.debug('query=' + query);
        return query;
    }

    private List<String> getFieldsToQuery(Schema.SObjectType sobjectType) {
        List<String> fields = new List<String>();
        for(Schema.SObjectField field : sobjectType.getDescribe().fields.getMap().values()) {
            //Skip any system fields
            if(!field.getDescribe().isPermissionable() && !field.getDescribe().isNameField()) continue;

            fields.add(field.getDescribe().getName().toLowerCase());
        }
        fields.addAll(new List<String>{
            'recordtype.developername'
        });

        return fields;
    }

    private static String getChildRelationshipName(Schema.SObjectType parentSObjectType, Schema.SObjectType childSObjectType, Schema.SObjectField lookupField) {
        String relationshipName;
        for(Schema.ChildRelationship cr : Schema.MetadataSObject__c.SObjectType.getDescribe().getChildRelationships()) {
            if(cr.getChildSObject() != childSObjectType) continue;
            if(cr.getField() != lookupField) continue;

            relationshipName = cr.getRelationshipName();
        }
        return relationshipName;
    }

    private String generateStaticResourceName(MetadataSObject__c metadataSObject) {
        String cleanedSObjectName = metadataSObject.Name
            .replaceAll('[^a-zA-Z0-9_\\s+]', '')
            .trim()
            .replace(' ', '')
            .replace('__', '_');

        String staticResourceName = STATIC_RESOURCE_PREFIX + '_' + cleanedSObjectName;

        /*if(staticResource.Name.lastIndexOf('_') == (staticResource.Name.length() - 1)) {
            staticResource.Name = staticResource.Name.left(staticResource.Name.length());
        }*/
        return staticResourceName;
    }
    private Object removeUnusedAttributes(SObject record) {
        // TODO use this to remove extra details from audit fields, record type, etc
        return null;
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