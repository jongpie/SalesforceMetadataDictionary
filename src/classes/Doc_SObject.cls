public class Doc_SObject {

    private List<SObjectType> sobjectTypes = new List<SObjectType>();
    
    public Doc_SObject() {
        this.sobjectTypes = Schema.getGlobalDescribe().values();
    }
    
    public void analyze() {
        List<Doc_SObject__c> doc_SObjects = new List<Doc_SObject__c>();
        List<Doc_Field__c> doc_Fields = new List<Doc_Field__c>();
        for(SObjectType sobjectType : this.sobjectTypes) {
            //if(!sobjectType.getDescribe().isCustom()) continue;

            doc_SObjects.add(new Doc_SObject__c(
                ExtId__c = sobjectType.getDescribe().getName(),
                IsCustom__c = sobjectType.getDescribe().isCustom(),
                Name     = sobjectType.getDescribe().getName(),
                Namespace__c = this.getNamespace(sobjectType)
            ));
            
            for(SObjectField field : sobjectType.getDescribe().fields.getMap().values()) {
                doc_Fields.add(new Doc_Field__c(
                    //IsCustom__c = field.getDescribe().isCustom(),
                	ExtId__c = sobjectType.getDescribe().getName() + '.' + field.getDescribe().getName(),
                    Doc_SObject__r = new Doc_SObject__c(ExtId__c = sobjectType.getDescribe().getName()),
                    Name = field.getDescribe().getName()
                ));
            }
        }
        upsert doc_SObjects ExtId__c;
        upsert doc_Fields ExtId__c;
    }
    
    private String getNamespace(Schema.SObjectType sobjectType) {
        String fullApiName = sobjectType.getDescribe().getName();
        Integer localNameIndex = fullApiName.replace('__c', '').indexOf('__');
        return localNameIndex < 0 ? null : fullApiName.substring(0, localNameIndex);
	}
    
}