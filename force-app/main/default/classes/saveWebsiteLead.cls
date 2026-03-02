/**
* @description
* ****************************************************************************************
* Create By        : Preksha Chauhan
* Company          : GetonCRM Solutions
* Create Date      : 06/25/2024
* Class Name       : saveWebsiteLead
* Description      : This class provides RESTful API endpoints for creating Lead records in Salesforce. 
*                    It handles parsing JSON request bodies, validating required fields, checking for 
*                    duplicate leads, retrieving record type IDs based on department, mapping fields from 
*                    JSON to Lead objects, and handling custom exceptions and error responses.
*********************************************************************************************
*/ 
@RestResource(urlMapping='/saveLead/*')
global with sharing class saveWebsiteLead {

   /**
    * @description
    **************************************************************************************** 
    * Method Name : saveLead
    * Created By  : Preksha Chauhan
    * Created Date: 06/25/2024
    * Modified Date: 06/26/2024
    * Description : This method handles the HTTP POST request to create a new Lead record.
    *               It parses the JSON request body, determines the department (Masters or UG),
    *               and calls the appropriate method for lead creation. It handles errors 
    *               gracefully by returning an appropriate error response if any issues occur 
    *               during processing.
    ****************************************************************************************
    */
    @HttpPost
    global static void saveLead() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String department;
        try {
            // Parse the JSON request body
            String requestBody = req.requestBody.toString();
            // 🔎 Debug entire raw JSON
        System.debug('### Incoming JSON Body: ' + requestBody);
            Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
             // 🔎 Debug keys and values one by one
        for (String key : params.keySet()) {
            System.debug('### Key: ' + key + ' | Value: ' + params.get(key));
        }

            // Get department and form type from params
             department = (String) params.get(StaticValuesUtil.DEPARTMENT_FIELD);
            Id leadId = createRecord(params);
            Map<String, String> responseBody = new Map<String, String>();
            responseBody.put('leadId', leadId);
            res.responseBody = Blob.valueOf(JSON.serialize(responseBody));

        } catch (Exception e) {
            system.debug('exception occured');
            Id recordTypeId = getRecordTypeIdByDepartment(department);
            if (recordTypeId == null) {
                createErrorResponse(400, 'Invalid department specified.');
            }
            else{
                createErrorResponse(500, 'Error creating lead: ' + e.getMessage());
            }
        }
    }

    /**
    * @description
    * @param params JSON parameters from request
    * @return Id of lead record 
    * Method Name : createRecord
    * Created By  : Preksha Chauhan
    * Created Date: 06/25/2024
    * Modified Date: 06/26/2024
    * Description : This method processes the lead creation specifically for the StaticValuesUtil.DEPARTMENT_MASTERS department.
    *               It validates the required fields, retrieves the appropriate RecordTypeId, checks 
    *               for duplicate leads, and maps the JSON fields to the Lead object. It inserts the 
    *               Lead record and returns the created Lead Id in the response if successful. If any 
    *               errors occur, it returns an appropriate error response.
    ****************************************************************************************
    */
    global static Id createRecord(Map<String, Object> params) {
        String department = (String) params.get(StaticValuesUtil.DEPARTMENT_FIELD);

            // Get department and form type from params
            String typeOfForm = (String) params.get(StaticValuesUtil.TYPE_OF_FORM_FIELD);
            if (department == null) {
                createErrorResponse(400, 'Department is required.');
            }
            if (typeOfForm == null) {
                createErrorResponse(400, 'Type of form is required.');
            }
            
            // Retrieve the RecordTypeId from custom metadata
            Id recordTypeId = getRecordTypeIdByDepartment(department);
            if (recordTypeId == null) {
                createErrorResponse(400, 'Invalid department specified.');
            }
            
        
            // Check for duplicate Lead based on phone, email, and program
            String phone = (String) params.get(StaticValuesUtil.FIELD_PHONE);
            
            String email = (String) params.get(StaticValuesUtil.FIELD_EMAIL);
            String programmeInterestedIn = (String) params.get(StaticValuesUtil.FIELD_PROGRAMME_INTERESTED); 
            system.debug('programmeInterestedIn102'+programmeInterestedIn);

        
            // Create the Lead record using LeadRecordParams instance
            LeadRecordParams leadParams = new LeadRecordParams(params, recordTypeId, department, typeOfForm);
            Lead lead = saveLeadFieldMappings(leadParams);
            system.debug('lead after field mappings'+ lead);
        
            // Check CRUD permissions before inserting
            if (!Schema.sObjectType.Lead.isCreateable()) {
                createErrorResponse(403, 'Current user does not have permission to create Lead records.');
            }
            Lead undergraduationLead = null;
            Lead masterLead = null;
            if(department.equalsIgnoreCase(StaticValuesUtil.DEPARTMENT_UNDERGRAD)){
                undergraduationLead  =  handleDuplicateLeadUnderGraduation(params,department,typeOfForm);
                system.debug('undergraduationLead=='+undergraduationLead);
                if (undergraduationLead!= null){    
                    lead= undergraduationLead;
                }
            }else{
                masterLead  =  handleDuplicateLeadDefault(params,department,typeOfForm);
                
                if (masterLead!= null){
                    lead = masterLead;
                    
                }

            }

            //commented this code by neha and added logic in upper else so master's duplicate lead logic will be dafault for 
            //all department except UG
            /*if(department.equalsIgnoreCase(StaticValuesUtil.DEPARTMENT_MASTERS)){
                masterLead  =  handleDuplicateLeadMasters(params,department,typeOfForm);
                
                if (masterLead!= null){
                    lead = masterLead;
                    
                }
            }*/
            System.debug('--- Entered createRecord ---');
            System.debug('Input Params: ' + JSON.serializePretty(params));
            System.debug('Department: ' + department + ', TypeOfForm: ' + typeOfForm);
            System.debug('RecordTypeId resolved: ' + recordTypeId);

            System.debug('Phone from params: ' + phone);
            System.debug('Email from params: ' + email);
            System.debug('ProgrammeInterestedIn: ' + programmeInterestedIn);


            System.debug('Lead after saveLeadFieldMappings: ' + JSON.serializePretty(lead));

            if (undergraduationLead != null) {
                System.debug('Duplicate UG Lead found: ' + JSON.serializePretty(undergraduationLead));
            }
            if (masterLead != null) {
                System.debug('Duplicate Master Lead found: ' + JSON.serializePretty(masterLead));
            }

            System.debug('Final Lead before insert/upsert: ' + JSON.serializePretty(lead));

            System.debug('Lead before insert: ' + JSON.serializePretty(lead));

            // Insert the Lead record
            upsert lead;
            return lead.Id;

        
    }
   
  

    /**
    * @description - Checking duplicate lead based on combination of Email+ Phone+ Preferred Program 
                     and if the matching lead is found and lead source of matching lead is not 'AURIS'
                     then updates the record with payload data and lead source gets added into
                     multiple lead source for all record type except UG
    * @param payloadMap payload
    * @param department master department
    * @param  typeOfForm from type
    * @return updated lead
    */
    public static Lead handleDuplicateLeadDefault(Map<String, Object> payloadMap,String department,String typeOfForm){
        String matchingphone=(String) payloadMap.get(StaticValuesUtil.FIELD_PHONE);

        Map<String, String> leadSourceGroupMapping = new Map<String, String>();
            // Retrieve field mappings from custom metadata
            List<WebFormFieldMapping__mdt> fieldMappings = [
                SELECT Department__c, JSON_Key__c, Label,
                TypeOfForm__c,LeadSourceGroup__c, Datatype__c
                FROM WebFormFieldMapping__mdt
                WHERE Department__c = :department 
                  AND TypeOfForm__c = :typeOfForm
            ];
            

            for (WebFormFieldMapping__mdt mapping : fieldMappings) {
                leadSourceGroupMapping.put(mapping.TypeOfForm__c, mapping.LeadSourceGroup__c);
            }

        if (matchingphone != null) {
            matchingphone = '%' + matchingphone + '%'; // Adding % for partial match
        }
        String matchingEmail = (String) payloadMap.get(StaticValuesUtil.FIELD_EMAIL); 
        String matchingDepartment = department;
        String matchingPreferedProgrm = (String) payloadMap.get(StaticValuesUtil.FIELD_PROGRAMME_INTERESTED);     
        List<Lead> matchingLead = [SELECT Id, Phone, Registration_Number__c, Email,LeadSource,Preferred_Programme__c,Multi_Select_Lead_Source__c,
                                  Name_of_University_College__c,Department__c,State, Country
                                  FROM Lead 
                                  WHERE Phone LIKE :matchingphone 
                                  AND Email = :matchingEmail AND Department__c = :matchingDepartment
                                  AND Preferred_Programme__c = :matchingPreferedProgrm
                                   LIMIT 1];
        Lead newLead =null;
        if(!matchingLead.isEmpty()){
            newLead = matchingLead[0];

            if(newLead.LeadSource == 'AURIS' ){
                newLead = matchingLead[0];

                //Get the current value of the multi-picklist field
                Set<String> picklistValues = new Set<String>();
                if (String.isNotBlank(newLead.Multi_Select_Lead_Source__c)) {
                    picklistValues.addAll(newLead.Multi_Select_Lead_Source__c.split(';'));
                }
                // Add the new value if it doesn't already exist
                String websiteLeadSource;

                
                if (leadSourceGroupMapping.containsKey(typeOfForm)) {
                    websiteLeadSource = leadSourceGroupMapping.get(typeOfForm);
                }
                picklistValues.add(websiteLeadSource);
                //Save the updated values back to the field
                newLead.Multi_Select_Lead_Source__c = String.join(new List<String>(picklistValues), ';');
              
            }
            else{
                newLead = handleFieldAssignmentOfDuplicates(fieldMappings,payloadMap,newLead,department,typeOfForm);

              
                
            }
            
            return newLead;
        }
        return newLead;
    }

    /** 
    * @description - Checking duplicate lead based on combination of Email+ Phone and if the matching
                     lead is found and matching lead's lead source is not 'AURIS' then
                     updates the record with payload data and lead source gets added into
                     multiple lead source for Undergraduation record type
                     * @param payloadMap payload
    * @param department UG department
    * @param  typeOfForm from type
    * @return updated lead
    **/
    public static Lead handleDuplicateLeadUnderGraduation(Map<String, Object> payloadMap,String department,String typeOfForm){
        String matchingphone=(String) payloadMap.get(StaticValuesUtil.FIELD_PHONE);
        
        Map<String, String> leadSourceGroupMapping = new Map<String, String>();
            // Retrieve field mappings from custom metadata
            List<WebFormFieldMapping__mdt> fieldMappings = [
                SELECT Department__c, JSON_Key__c, Label,
                TypeOfForm__c,LeadSourceGroup__c, Datatype__c
                FROM WebFormFieldMapping__mdt
                WHERE Department__c = :department 
                  AND TypeOfForm__c = :typeOfForm
            ];

            for (WebFormFieldMapping__mdt mapping : fieldMappings) {
                leadSourceGroupMapping.put(mapping.TypeOfForm__c, mapping.LeadSourceGroup__c);
            }



        if (matchingphone != null) {
            matchingphone = '%' + matchingphone + '%'; // Adding % for partial match
        }
        String matchingEmail = (String) payloadMap.get(StaticValuesUtil.FIELD_EMAIL);
        String matchingDepartment =department;
        List<Lead> matchingLead = [SELECT Id, Phone, Registration_Number__c, Email,LeadSource,Preferred_Programme__c,Multi_Select_Lead_Source__c,
                                  Name_of_University_College__c,Department__c,State,Country
                                  FROM Lead 
                                  WHERE Phone LIKE :matchingphone 
                                  AND Email = :matchingEmail AND Department__c=:matchingDepartment
                                   LIMIT 1];
        
        Lead newLead =null;
        if(!matchingLead.isEmpty()){
            newLead = matchingLead[0];

            if(newLead.LeadSource == 'AURIS' ){
                newLead = matchingLead[0];

                //Get the current value of the multi-picklist field
                Set<String> picklistValues = new Set<String>();
                if (String.isNotBlank(newLead.Multi_Select_Lead_Source__c)) {
                    picklistValues.addAll(newLead.Multi_Select_Lead_Source__c.split(';'));
                }
                // Add the new value if it doesn't already exist
                String websiteLeadSource;

                if (leadSourceGroupMapping.containsKey(typeOfForm)) {
                    websiteLeadSource = leadSourceGroupMapping.get(typeOfForm);
                }

                picklistValues.add(websiteLeadSource);
                //Save the updated values back to the field
                newLead.Multi_Select_Lead_Source__c = String.join(new List<String>(picklistValues), ';');

            }
            else{
           newLead = handleFieldAssignmentOfDuplicates(fieldMappings,payloadMap,newLead,department,typeOfForm);
             
                
            } 
            
            return newLead;
        }
        return newLead;
    }

    public static Lead handleFieldAssignmentOfDuplicates(List<WebFormFieldMapping__mdt> fieldMappings,Map<String,Object> payloadMap,Lead newLead,String department,String typeOfForm){
        Map<String, String> leadSourceGroupMapping = new Map<String, String>();

        for(WebFormFieldMapping__mdt mapping : fieldMappings){
            String jsonKey = mapping.JSON_Key__c;
            String leadField = mapping.Label;
            String type = mapping.Datatype__c;
            leadSourceGroupMapping.put(mapping.TypeOfForm__c, mapping.LeadSourceGroup__c);

            if (payloadMap.containsKey(jsonKey) && payloadMap.get(jsonKey) != null)  {
                Object val = payloadMap.get(jsonKey);
                Object typedVal;

                if (type == 'String') {
                    typedVal = String.valueOf(val);
                } else if (type == 'Date') {
                    typedVal = Date.valueOf(String.valueOf(val));
                } else if (type == 'Decimal') {
                    typedVal = Decimal.valueOf(String.valueOf(val));
                } else if (type == 'Boolean') {
                    typedVal = Boolean.valueOf(String.valueOf(val));
                } else {
                    typedVal = val;
                }
                
                newLead.put(leadField, typedVal);
            }
        }

                    newLead.Admission_Year__c = System.label.Admission_Year;
                    newLead.Department__c = department;
                    newLead.TypeOfForm__c = typeOfForm;
                    // if(newLead.Preferred_Programme__c!= null){
                    //     newLead.Programme_Interested_in__c = newLead.Preferred_Programme__c;
                    // }
                    // Assign LeadSourceGroup dynamically based on typeOfForm
                if (leadSourceGroupMapping.containsKey(typeOfForm)) {
                    newLead.LeadSource = leadSourceGroupMapping.get(typeOfForm);
                }
                if (String.isBlank((String)newLead.get('lastName'))) {
                    newLead.LastName = '.';
                }
                if (payloadMap.containsKey('lastName')) {
                    String lastName = (String) payloadMap.get('lastName');
                    newLead.LastName = (lastName != null && lastName.trim().length() > 0) ? lastName : '.';
                }

                // Logic for phone number formatting with country code
                // Done below changes for resolving issue of getting null in phone field value
                String country= null;
                Integer countryLength=0;
                if(payloadMap.containsKey('country') && payloadMap.get('country') != null && payloadMap.get('country')!=newLead.Country ){
                    country = (String) payloadMap.get('country');
                    countryLength = country.length();
                }
                
                
                if (payloadMap.containsKey('phone') && payloadMap.get('phone') != null ) {
                    if (payloadMap.containsKey('country') && payloadMap.get('country') != null && countryLength > 0 && payloadMap.get('country')!=newLead.Country ) {
                            
                        newLead.Phone = LeadPhoneUpdater.generatePhoneNumberWithCountryCode(country, (String) payloadMap.get('phone'));
                        newLead.Country = (String) payloadMap.get('country');
                        if(payloadMap.containsKey('state') && payloadMap.get('state') != null && payloadMap.get('state')!=newLead.State){
                            newLead.State =(String)payloadMap.get('state');
                        }

                    } 
                }

                //code to add leadsource in mutipicklist field
                Set<String> picklistValues = new Set<String>();
                if (String.isNotBlank(newLead.Multi_Select_Lead_Source__c)) {
                    picklistValues.addAll(newLead.Multi_Select_Lead_Source__c.split(';'));
                }
                // Add the new value if it doesn't already exist
                String websiteLeadSource;

                if (leadSourceGroupMapping.containsKey(typeOfForm)) {
                    websiteLeadSource = leadSourceGroupMapping.get(typeOfForm);
                }

                picklistValues.add(websiteLeadSource);
                // Save the updated values back to the field
                newLead.Multi_Select_Lead_Source__c = String.join(new List<String>(picklistValues), ';'); 

                return newLead;

    }

    /**
    * @description
    * @param department master department
    * @return updated lead
     * **************************************************************************************** 
    * Method Name : getRecordTypeIdByDepartment
    * Create By : Preksha Chauhan
    * Create Date : 06/25/2024
    * Description : This method retrieves the RecordTypeId for a given department using custom metadata. 
    *               It queries the Department_Record_Type_Mapping__mdt custom metadata type to get the 
    *               RecordTypeId based on the department. If any error occurs, it logs the error and returns null.
    ****************************************************************************************
    ***/
    public static Id getRecordTypeIdByDepartment(String department) {
        try {
            List<Department_Record_Type_Mapping__mdt> mappings = [
                SELECT Record_Type_Id__c
                FROM Department_Record_Type_Mapping__mdt
                WHERE Department__c = :department 
                LIMIT 1
            ];

            if (!mappings.isEmpty()) {
                system.debug('mapping is available');
                
                return mappings[0].Record_Type_Id__c;
            }
            else{
                system.debug('mapping is not available for department');
                createErrorResponse(400, 'Invalid department specified.');

            }
           
            return null;
        } catch (Exception e) {
            
            return null;
        }
    }


    /**Commented by Neha for dynamically add fields
    * @description
    * @param leadParams lead parameters
    * @return created lead
    */


    public static Lead saveLeadFieldMappings(LeadRecordParams leadParams) {
        try {
            Lead newLead = new Lead();
            //newLead.RecordTypeId = recordTypeId;
            Map<String, String> leadSourceGroupMapping = new Map<String, String>();

            // Retrieve field mappings from custom metadata
            List<WebFormFieldMapping__mdt> fieldMappings = [
                SELECT Department__c, JSON_Key__c, Label, Datatype__c,
                TypeOfForm__c,LeadSourceGroup__c
                FROM WebFormFieldMapping__mdt
                WHERE Department__c = :leadParams.department 
                  AND TypeOfForm__c = :leadParams.typeOfForm
            ];
            if(fieldMappings.isEmpty()){
                System.debug('***********Field mappings found: ' + fieldMappings.size());
            }
            system.debug('The fieldMappings are '+fieldMappings);
            // Iterate over field mappings and map JSON fields to Lead fields
            for (WebFormFieldMapping__mdt mapping : fieldMappings) {
                leadSourceGroupMapping.put(mapping.TypeOfForm__c, mapping.LeadSourceGroup__c);
                String jsonKey = mapping.JSON_Key__c;
                String leadField = mapping.Label;
                String type = mapping.Datatype__c;
    
                if (leadParams.params.containsKey(jsonKey) && leadParams.params.get(jsonKey) != null) {
                    Object val = leadParams.params.get(jsonKey);
                    Object typedVal;
    
                    if (type == 'String') {
                        typedVal = String.valueOf(val);
                    } else if (type == 'Date') {
                        typedVal = Date.valueOf(String.valueOf(val));
                    } else if (type == 'Decimal') {
                        typedVal = Decimal.valueOf(String.valueOf(val));
                    } else if (type == 'Boolean') {
                        typedVal = Boolean.valueOf(String.valueOf(val));
                    } else {
                        typedVal = val;
                    }
                    System.debug('Mapping JSON key ' + jsonKey + ' to Lead field ' + leadField + ' with value: ' + typedVal);
                    newLead.put(leadField, typedVal);
                }
                if(!leadParams.params.containsKey('admissionYear') || leadParams.params.get('admissionYear') == null){
                    newLead.Admission_Year__c = System.label.Admission_Year;
                }
                
                newLead.Department__c = leadParams.department;
                newLead.TypeOfForm__c = leadParams.typeOfForm;
                newLead.RecordTypeId = leadParams.recordTypeId;

                // if(newLead.Preferred_Programme__c!= null){
                //     newLead.Programme_Interested_in__c = newLead.Preferred_Programme__c;
                // }
                // Assign LeadSourceGroup dynamically based on typeOfForm
            if (leadSourceGroupMapping.containsKey(leadParams.typeOfForm)) {
                newLead.LeadSource = leadSourceGroupMapping.get(leadParams.typeOfForm);
            }
            // Assign to Multi_Select_Lead_Source__c if LeadSource is set
            if (newLead.LeadSource != null) {
                newLead.Multi_Select_Lead_Source__c = newLead.LeadSource;
            }
            if (String.isBlank((String)newLead.get('lastName'))) {
                newLead.LastName = '.';
            }
            if (leadParams.params.containsKey('lastName')) {
                String lastName = (String) leadParams.params.get('lastName');
                newLead.LastName = (lastName != null && lastName.trim().length() > 0) ? lastName : '.';
            }

            // Logic for phone number formatting with country code
            // Done below changes for resolving issue of getting null in phone field value
            String country= null;
            Integer countryLength=0;
            if(leadParams.params.containsKey('country') && leadParams.params.get('country') != null){
                country = (String) leadParams.params.get('country');
                countryLength = country.length();
                newLead.Country = country;
            }
            // else{
            //     newLead.Country = 'India';
            // }
            if (leadParams.params.containsKey('phone') && leadParams.params.get('phone') != null ) {
                if (leadParams.params.containsKey('country') && leadParams.params.get('country') != null && countryLength > 0) {
                        
                    newLead.Phone = LeadPhoneUpdater.generatePhoneNumberWithCountryCode(country, (String) leadParams.params.get('phone'));
                } else {
                    newLead.Phone = LeadPhoneUpdater.generatePhoneNumberWithCountryCode('IN', (String) leadParams.params.get('phone'));   
                }
            }
            // if (leadParams.params.containsKey(StaticValuesUtil.FIELD_PHD_SCHOOL_NAME) && leadParams.params.get(StaticValuesUtil.FIELD_PHD_SCHOOL_NAME) != null && leadParams.department == StaticValuesUtil.DEPARTMENT_PHD) {
            //     newLead.Programme_Interested_in__c  = (String) leadParams.params.get(StaticValuesUtil.FIELD_PHD_SCHOOL_NAME);
            // }
            
            }
            System.debug('--- Entered saveLeadFieldMappings ---');
            System.debug('Lead Params JSON: ' + JSON.serializePretty(leadParams.params));


            if (leadParams.params.containsKey('phone')) {
                System.debug('Raw phone param: ' + leadParams.params.get('phone'));
                System.debug('Final phone after formatting: ' + newLead.Phone);
            }

            if (leadParams.params.containsKey('email')) {
                System.debug('Raw email param: ' + leadParams.params.get('email'));
            }
            System.debug('Lead fields after mapping (partial): ' + 
                ' LastName=' + newLead.LastName +
                ', Email=' + newLead.Email +
                ', Phone=' + newLead.Phone +
                ', Department=' + newLead.Department__c +
                ', TypeOfForm=' + newLead.TypeOfForm__c);

            return newLead;
        }catch(Exception e){
            throw new CustomException('Error creating Lead record: ' + e.getMessage());

        }
    
    }


        
    
    /**
    * @description
    * Class Name : LeadRecordParams
    * Create By : Preksha Chauhan
    * Create Date : 06/26/2024
    * Description : This class encapsulates the parameters for creating a Lead record. 
    *               It contains the JSON parameters, RecordTypeId, department, and typeOfForm.
    ****************************************************************************************
    */
    public class LeadRecordParams {
        /**
        * @description
        */
        public Map<String, Object> params { get; set; }
         /**
        * @description
        */
        public Id recordTypeId { get; set; }
         /**
        * @description
        */
        public String department { get; set; }
         /**
        * @description
        */
        public String typeOfForm { get; set; }

         /**
        * @description
        * @param params lead parameters
        * @param recordTypeId record type Id of lead
        * @param department department of lead
        * @param typeOfForm of lead
        */
        public LeadRecordParams(Map<String, Object> params, Id recordTypeId, String department, String typeOfForm) {
            this.params = params;
            this.recordTypeId = recordTypeId;
            this.department = department;
            this.typeOfForm = typeOfForm;
        }
    }
    /**
    * @description
    * @param statusCode status code of Http request
    * @param message message of Http request
    * Method Name : createErrorResponse
    * Create By : Preksha Chauhan
    * Create Date : 06/25/2024
    * Description : This helper method creates an error response with the given status code and message. 
    *               It sets the response status code, content type, and serializes the error message to JSON. 
    *               If any error occurs, it logs the error and returns a generic error response.
    ****************************************************************************************
    ***/
    public static void createErrorResponse(Integer statusCode, String message) {
        try {
            RestResponse res = RestContext.response;
            res.statusCode = statusCode;

            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'status' => statusCode,
                'message' => message
            }));
        } catch (Exception e) {
            
            RestResponse res = RestContext.response;
            res.statusCode = statusCode;

            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'status' => 500,
                'message' => 'Error creating error response: ' + e.getMessage()
            }));
        }
    }

    /**
    * @description
     * **************************************************************************************** 
    * Method Name : CustomException
    * Create By : Preksha Chauhan
    * Create Date : 06/25/2024
    * Description : This class defines a custom exception to be used within the LeadRestService class. 
    *               It extends the base Exception class to provide custom error handling.
    ****************************************************************************************
    ***/
    public class CustomException extends Exception {}
}