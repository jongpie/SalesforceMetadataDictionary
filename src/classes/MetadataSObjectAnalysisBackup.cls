public without sharing class MetadataSObjectAnalysisBackup implements Database.Batchable<SObject>, Database.AllowsCallouts {


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

        Map<String, Id> existingStaticResourcesByName = new Map<String, Id>();
        for(StaticResource staticResource : [SELECT Id, Name FROM StaticResource WHERE Name LIKE :STATIC_RESOURCE_PREFIX + '%']) {
            existingStaticResourcesByName.put(staticResource.Name, StaticResource.Id);
        }


        //List<StaticResourceTemplate> staticResourceTemplates = new List<StaticResourceTemplate>();
        List<MetadataSObject__c> cleanedSObjects = new List<MetadataSObject__c>();
        List<Map<String, Object>> cleanedSObjectDtos = new List<Map<String, Object>>();
        for(MetadataSObject__c metadataSObject : scope) {
            MetadataSObject__c cleanedSObject = metadataSObject.clone(false, true, false, false);
            Map<String, Object> cleanedSObjectDto = (Map<String, Object>)Json.deserializeUntyped(Json.serialize(cleanedSObject));

            List<MetadataField__c> cleanedFields = new List<MetadataField__c>();
            for(MetadataField__c metadataField : metadataSObject.MetadataFields__r) {
                MetadataField__c cleanedField = metadataField.clone(false, true, false, false);
                cleanedField.MetadataSObject__c = null;
                cleanedFields.add(cleanedField);
            }
            //cleanedSObject.MetadataFields__r = cleanedFields;
            //cleanedSObjectDto.put(FIELDS_CHILD_RELATIONSHIP_NAME, cleanedFields);
            //cleanedSObjectDto.put(FIELDS_CHILD_RELATIONSHIP_NAME, null);
            Map<String, Object> fields = (Map<String, Object>)cleanedSObjectDto.get(FIELDS_CHILD_RELATIONSHIP_NAME);
            fields.put('records', cleanedFields);

            List<MetadataRecordType__c> cleanedRecordTypes = new List<MetadataRecordType__c>();
            for(MetadataRecordType__c metadataRecordType : metadataSObject.MetadataRecordTypes__r) {
                MetadataRecordType__c cleanedRecordType = metadataRecordType.clone(false, true, false, false);
                cleanedRecordType.MetadataSObject__c = null;
                cleanedRecordTypes.add(cleanedRecordType);
            }
            //cleanedSObject.MetadataRecordTypes__r = cleanedRecordTypes;
            Map<String, Object> recordTypes = (Map<String, Object>)cleanedSObjectDto.get(RECORD_TYPES_CHILD_RELATIONSHIP_NAME);
            recordTypes.put('records', cleanedRecordTypes);

            cleanedSObjects.add(cleanedSObject);
            cleanedSObjectDtos.add(cleanedSObjectDto);
            // TODO make callout to Salesforce endpoint to create static resources. Endpoint only accepts 1 static resource at a time.
            //staticResourceTemplates.add(staticResource);
        }
        // TODO
        //Blob requestBlob = Blob.valueOf(Json.serializePretty(cleanedSObjects));
        Blob requestBlob = Blob.valueOf(Json.serialize(cleanedSObjectDtos));
        //Blob requestBlob = Blob.valueOf(Json.serializePretty(scope));
String finReq = EncodingUtil.base64Encode(requestBlob);
        
        StaticResourceTemplate staticResource = new StaticResourceTemplate();
        staticResource.Body         = finReq;//Json.serialize(scope);
        staticResource.CacheControl = 'Private';
        staticResource.ContentType  = 'application/json';//'application/json';
        staticResource.Description  = 'Metadata Dictionary contents';
        staticResource.Name         = STATIC_RESOURCE_PREFIX + '001';
        
        Id staticResourceId = existingStaticResourcesByName.get(staticResource.Name);
        this.createStaticResource(Json.serialize(staticResource), staticResourceId);
    }

    public void finish(Database.BatchableContext batchableContext) {
        
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
        Set<String> fields = new Set<String>();
        fields.addAll(sobjectType.getDescribe().fields.getMap().keySet());
        fields.removeAll(new List<String>{
            'lastreferenceddate',
            'lastvieweddate',
            'nebula__metadatasobject__c',
            'metadatasobject__c',
            'ownerid',
            'recordtypeid',
            'systemmodstamp'
        });
       /* fields.addAll(new List<String>{
            'createdby.email',
            'createdby.name',
            'lastmodifiedby.email',
            'lastmodifiedby.name',
            'recordtype.developername'
        });*/

        return new List<String>(fields);
    }

    private HttpResponse createStaticResource(String requestBody) {
        return this.createStaticResource(requestBody, null);
    }

    private HttpResponse createStaticResource(String requestBody, Id staticResourceId) {
System.debug('STATIC_RESOURCE_ENDPOINT=' + STATIC_RESOURCE_ENDPOINT);
System.debug('staticResourceId=' + staticResourceId);

        System.debug('requestBody=');
        System.debug(requestBody);

Blob requestBlob = Blob.valueOf('test');
String finReq = EncodingUtil.base64Encode(requestBlob);
        HttpRequest request = new HttpRequest();
        request.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        request.setHeader('Content-Type', 'application/json');
        
String calculatedEndpoint = STATIC_RESOURCE_ENDPOINT;
if(staticResourceId != null)  calculatedEndpoint += '/' + staticResourceId + '?_HttpMethod=PATCH';
System.debug('calculatedEndpoint=' + calculatedEndpoint);
        request.setEndpoint(calculatedEndpoint);
        //request.setBody('test');
        request.setBody(requestBody);
        //request.setBody(finReq);
        //request.setMethod(staticResourceId == null ? 'POST' : 'PATCH');
        request.setMethod('POST');
System.debug(request.getBody());
        HttpResponse response = new Http().send(request);
System.debug('response=');
        System.debug(response);
        
        System.assert(response.getStatusCode() < 300, 'Status code ' + response.getStatusCode() + ', Error: ' + response.getStatus());
        return response;
    }

}