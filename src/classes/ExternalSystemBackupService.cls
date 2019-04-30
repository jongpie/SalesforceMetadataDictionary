/*****************************************************************************************************************
* This file is part of the Metadata Dictionary project for Salesforce, released under the MIT License.           *
* See LICENSE file or go to https://github.com/jongpie/SalesforceMetadataDictionary for full license details.    *
*****************************************************************************************************************/
public without sharing class ExternalSystemBackupService implements Database.AllowsCallouts, Database.Batchable<SObject> {

    private static final String STATIC_RESOURCE_PREFIX   = 'MetadataDictionary';
    private static final String STATIC_RESOURCE_ENDPOINT = System.Url.getSalesforceBaseUrl().toExternalForm() + '/services/data/v45.0/sobjects/StaticResource';

    private static final String PACKAGES_CHILD_RELATIONSHIP_NAME = getChildRelationshipName(Schema.ExternalSystem__c.SObjectType, Schema.ExternalSystemPackage__c.SObjectType, Schema.ExternalSystemPackage__c.ExternalSystem__c);
    private static final String FIELDS_CHILD_RELATIONSHIP_NAME   = getChildRelationshipName(Schema.ExternalSystemPackage__c.SObjectType, Schema.ExternalSystemField__c.SObjectType, Schema.ExternalSystemField__c.ExternalSystemPackage__c);

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
        Map<Id, List<ExternalSystemPackage__c>> externalSystemPackagesBySystemId = this.queryChildRecords(scope, Schema.ExternalSystemPackage__c.SObjectType, Schema.ExternalSystemPackage__c.ExternalSystem__c);
        List<ExternalSystemPackage__c> externalSystemPackages = new List<ExternalSystemPackage__c>();
        for(List<ExternalSystemPackage__c> packages : externalSystemPackagesBySystemId.values()) {
            externalSystemPackages.addAll(packages);
        }
        //TODO populate list of packages
        Map<Id, List<ExternalSystemField__c>> externalSystemFieldsByPackageId    = this.queryChildRecords(externalSystemPackages, Schema.ExternalSystemField__c.SObjectType, Schema.ExternalSystemField__c.ExternalSystemPackage__c);

        // Get any existing static resources so we can update them
        Map<String, Id> existingStaticResourceIdsByName = new Map<String, Id>();
        for(StaticResource staticResource : [SELECT Id, Name FROM StaticResource WHERE Name LIKE :STATIC_RESOURCE_PREFIX + '%']) {
            existingStaticResourceIdsByName.put(staticResource.Name, StaticResource.Id);
        }

        for(ExternalSystem__c externalSystem : scope) {
            ExternalSystem__c cleanedExternalSystem = externalSystem.clone(false, true, false, false);
            Map<String, Object> cleanedExternalSystemDto = (Map<String, Object>)Json.deserializeUntyped(Json.serialize(cleanedExternalSystem));//(Map<String, Object>)Json.deserializeUntyped(Json.serialize(cleanedExternalSystem));

            // Cleanup the fields before serialization
            //if(!externalSystem.ExternalSystemFields__r.isEmpty()) {
            //    List<ExternalSystemField__c> cleanedFields = new List<ExternalSystemField__c>();
            //    //for(ExternalSystemField__c metadataField : externalSystem.ExternalSystemFields__r) {
            //    //    ExternalSystemField__c cleanedField = metadataField.clone(false, true, false, false);
            //    //    cleanedField.ExternalSystemPackage__c = null;

            //    //    Map<String, Object> cleanedFieldDto = (Map<String, Object>)Json.deserializeUntyped(Json.serialize(cleanedField));
            //    //    cleanedFieldDto = this.removeUnusedAttributes(cleanedFieldDto);

            //    //    cleanedField = (Schema.ExternalSystemField__c)Json.deserialize(Json.serialize(cleanedFieldDto), ExternalSystemField__c.class);

            //    //    cleanedFields.add(cleanedField);
            //    //}
            //    Map<String, Object> fields = (Map<String, Object>)cleanedExternalSystemDto.get(FIELDS_CHILD_RELATIONSHIP_NAME);
            //    fields.put('records', cleanedFields);
            //}

            // Cleanup the record types before serialization
            //if(!externalSystem.ExternalSystemPackages__r.isEmpty()) {
            if(externalSystemPackagesBySystemId.containsKey(externalSystem.Id)) {
                List<ExternalSystemPackage__c> cleanedExternalSystemPackages = new List<ExternalSystemPackage__c>();

                for(ExternalSystemPackage__c externalSystemPackage : externalSystemPackagesBySystemId.get(externalSystem.Id)) {
                    ExternalSystemPackage__c cleanedExternalSystemPackage = externalSystemPackage.clone(false, true, false, false);
                    cleanedExternalSystemPackage.ExternalSystem__c = null;

                    Map<String, Object> cleanedExternalSystemPackageDto = (Map<String, Object>)Json.deserializeUntyped(Json.serialize(cleanedExternalSystemPackage));

                    if(externalSystemFieldsByPackageId.containsKey(externalSystemPackage.Id)) {
                        List<ExternalSystemField__c> cleanedExternalSystemFields = new List<ExternalSystemField__c>();

                        for(ExternalSystemField__c externalSystemField : externalSystemFieldsByPackageId.get(externalSystemPackage.Id)) {
                            //System.assert(false, 'aw yiss again');
                            ExternalSystemField__c cleanedExternalSystemField = externalSystemField.clone(false, true, false, false);
                            cleanedExternalSystemField.ExternalSystemPackage__c = null;

                            Map<String, Object> cleanedExternalSystemFieldDto = (Map<String, Object>)Json.deserializeUntyped(Json.serialize(cleanedExternalSystemField));

                            cleanedExternalSystemFieldDto = this.removeUnusedAttributes(cleanedExternalSystemFieldDto);

                            cleanedExternalSystemField = (Schema.ExternalSystemField__c)Json.deserialize(Json.serialize(cleanedExternalSystemFieldDto), ExternalSystemField__c.class);

                            cleanedExternalSystemFields.add(cleanedExternalSystemField);
                        }

                        Map<String, Object> fieldsDto = new Map<String, Object>();
                        fieldsDto.put('records', cleanedExternalSystemFields);
                        fieldsDto.put('totalSize', cleanedExternalSystemFields.size());
                        fieldsDto.put('done', true);
                        fieldsDto = this.removeUnusedAttributes(fieldsDto);
System.debug('FIELDS_CHILD_RELATIONSHIP_NAME=' + FIELDS_CHILD_RELATIONSHIP_NAME);
                        cleanedExternalSystemPackageDto.put(FIELDS_CHILD_RELATIONSHIP_NAME, fieldsDto);
System.debug('cleanedExternalSystemPackageDto=');
System.debug(cleanedExternalSystemPackageDto);
                    }


                    cleanedExternalSystemPackageDto = this.removeUnusedAttributes(cleanedExternalSystemPackageDto);

                    cleanedExternalSystemPackage = (Schema.ExternalSystemPackage__c)Json.deserialize(Json.serialize(cleanedExternalSystemPackageDto), ExternalSystemPackage__c.class);

                    cleanedExternalSystemPackages.add(cleanedExternalSystemPackage);
                }

                Map<String, Object> packagesDto = new Map<String, Object>();
                packagesDto.put('records', cleanedExternalSystemPackages);
                packagesDto.put('totalSize', cleanedExternalSystemPackages.size());
                packagesDto.put('done', true);
                packagesDto = this.removeUnusedAttributes(packagesDto);

                cleanedExternalSystemDto.put(PACKAGES_CHILD_RELATIONSHIP_NAME, packagesDto);
            }

            cleanedExternalSystemDto = this.removeUnusedAttributes(cleanedExternalSystemDto);

            Blob requestBlob = Blob.valueOf(Json.serializePretty(cleanedExternalSystemDto));

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

    public void finish(Database.BatchableContext batchableContext) {}

    private String getQueryString() {
        String query = '';

        List<String> externalSystemFieldsToQuery    = this.getFieldsToQuery(Schema.ExternalSystem__c.SObjectType);
        //List<String> externalSystemFieldFieldsToQuery      = this.getFieldsToQuery(Schema.ExternalSystemField__c.SObjectType);
        //List<String> externalSystemPackageFieldsToQuery = this.getFieldsToQuery(Schema.ExternalSystemPackage__c.SObjectType);

        query = 'SELECT ' + String.join(externalSystemFieldsToQuery, ', ')
                //+ ', (SELECT ' + String.join(externalSystemFieldFieldsToQuery, ', ') + ' FROM ' + FIELDS_CHILD_RELATIONSHIP_NAME + ')'
                //+ ', (SELECT ' + String.join(externalSystemPackageFieldsToQuery, ', ') + ' FROM ' + RECORD_TYPES_CHILD_RELATIONSHIP_NAME + ')'
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

        fields.add('Id');

        if(allFieldsByApiName.containsKey('recordtypeid')) {
            fields.add('recordtype.developername');
        }
        /*fields.addAll(new List<String>{
            'RecordType.DeveloperName'.toLowerCase()
        });*/

        if(sobjectType == Schema.ExternalSystemPackage__c.SObjectType) {
            fields.add(Schema.ExternalSystemPackage__c.ExternalSystem__c.getDescribe().getRelationshipName() + '.' + Schema.ExternalSystem__c.Uuid__c);
        }

        if(sobjectType == Schema.ExternalSystemField__c.SObjectType) {
            fields.add(Schema.ExternalSystemField__c.ExternalSystemPackage__c.getDescribe().getRelationshipName() + '.' + Schema.ExternalSystemPackage__c.Uuid__c);
            fields.add(Schema.ExternalSystemField__c.MappedField__c.getDescribe().getRelationshipName() + '.' + Schema.MetadataField__c.Uuid__c);
            fields.add(Schema.ExternalSystemField__c.MappedSObject__c.getDescribe().getRelationshipName() + '.' + Schema.MetadataSObject__c.Uuid__c);
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
        // TODO use this to remove extra details from audit fields, record type, etc
        cleanedSObjectDto.remove('attributes');
        cleanedSObjectDto.remove(Schema.ExternalSystemField__c.ExternalSystemPackage__c.getDescribe().getName());
        cleanedSObjectDto.remove(Schema.ExternalSystemField__c.MappedField__c.getDescribe().getName());
        cleanedSObjectDto.remove(Schema.ExternalSystemField__c.MappedSObject__c.getDescribe().getName());
        cleanedSObjectDto.remove(Schema.ExternalSystemPackage__c.ExternalSystem__c.getDescribe().getName());
        //cleanedSObjectDto.remove(Schema.ExternalSystem__c.PrimaryExternalSystem__c.getDescribe().getName());
        cleanedSObjectDto.remove('RecordTypeId');

        String packageRelationshipName = Schema.ExternalSystemField__c.ExternalSystemPackage__c.getDescribe().getRelationshipName();
        if(cleanedSObjectDto.containsKey(packageRelationshipName)) {
            Map<String, Object> mappedSObjectDto = (Map<String, Object>)cleanedSObjectDto.get(packageRelationshipName);
            mappedSObjectDto.remove('attributes');
            mappedSObjectDto.remove('Id');

            cleanedSObjectDto.put(packageRelationshipName, mappedSObjectDto);
        }

        String systemRelationshipName = Schema.ExternalSystemPackage__c.ExternalSystem__c.getDescribe().getRelationshipName();
        if(cleanedSObjectDto.containsKey(systemRelationshipName)) {
            Map<String, Object> mappedSObjectDto = (Map<String, Object>)cleanedSObjectDto.get(systemRelationshipName);
            mappedSObjectDto.remove('attributes');
            mappedSObjectDto.remove('Id');

            cleanedSObjectDto.put(systemRelationshipName, mappedSObjectDto);
        }

        String mappedSObjectRelationshipName = Schema.ExternalSystemField__c.MappedSObject__c.getDescribe().getRelationshipName();
        if(cleanedSObjectDto.containsKey(mappedSObjectRelationshipName)) {
            Map<String, Object> mappedSObjectDto = (Map<String, Object>)cleanedSObjectDto.get(mappedSObjectRelationshipName);
            mappedSObjectDto.remove('attributes');
            mappedSObjectDto.remove('Id');

            cleanedSObjectDto.put(mappedSObjectRelationshipName, mappedSObjectDto);
        }

        String mappedFieldRelationshipName = Schema.ExternalSystemField__c.MappedField__c.getDescribe().getRelationshipName();
        if(cleanedSObjectDto.containsKey(mappedFieldRelationshipName)) {
            Map<String, Object> mappedFieldDto = (Map<String, Object>)cleanedSObjectDto.get(mappedFieldRelationshipName);
            mappedFieldDto.remove('attributes');
            mappedFieldDto.remove('Id');

            cleanedSObjectDto.put(mappedFieldRelationshipName, mappedFieldDto);
        }

/*        if(cleanedSObjectDto.containsKey(Schema.ExternalSystemField.ExternalSystem__c.getDescribe().getRelationshipName()) || cleanedSObjectDto.containsKey(Schema.ExternalSystemPackage__c.ExternalSystem__c.getDescribe().getRelationshipName())) {
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