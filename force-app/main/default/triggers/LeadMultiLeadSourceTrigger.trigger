trigger LeadMultiLeadSourceTrigger on Lead (before insert, before update) {
    // Get all valid values from the multi-select picklist
    Set<String> validMultiSelectValues = new Set<String>();
    for(Schema.PicklistEntry ple : Lead.Multi_Select_Lead_Source__c.getDescribe().getPicklistValues()) {
        validMultiSelectValues.add(ple.getValue());
    }
    
    // Create a map of common typos to correct values
    Map<String, String> typoCorrectionMap = new Map<String, String>();
    for(String validValue : validMultiSelectValues) {
        String lowerValid = validValue.toLowerCase();
        
        // Add the correct value
        typoCorrectionMap.put(lowerValid, validValue);
        
        // Add common variations
        typoCorrectionMap.put(lowerValid.replace('_', ' '), validValue);
        typoCorrectionMap.put(lowerValid.replace('_', ''), validValue);
        
        // For Meta_Ads specifically, add more variations
        if (lowerValid.contains('meta') && lowerValid.contains('ads')) {
            typoCorrectionMap.put('meta ads', validValue);
            typoCorrectionMap.put('meta dds', validValue);
            typoCorrectionMap.put('meta das', validValue);  // Your actual typo!
            typoCorrectionMap.put('meta ad', validValue);
            typoCorrectionMap.put('metads', validValue);
            typoCorrectionMap.put('meta-ads', validValue);
        }
    }
    
    // Process each lead
    for (Lead newLead : Trigger.new) {
        Set<String> allValues = new Set<String>();
        
        // 1. Get existing values for updates
        if (Trigger.isUpdate) {
            Lead oldLead = Trigger.oldMap.get(newLead.Id);
            if (oldLead != null && String.isNotBlank(oldLead.Multi_Select_Lead_Source__c)) {
                for(String val : oldLead.Multi_Select_Lead_Source__c.split(';')) {
                    val = val.trim();
                    if (validMultiSelectValues.contains(val)) {
                        allValues.add(val);
                    }
                }
            }
        }
        
        // 2. Process current Multi_Select_Lead_Source__c
        if (String.isNotBlank(newLead.Multi_Select_Lead_Source__c)) {
            for(String val : newLead.Multi_Select_Lead_Source__c.split(';')) {
                val = val.trim();
                String correctedVal = typoCorrectionMap.get(val.toLowerCase());
                
                if (correctedVal != null && validMultiSelectValues.contains(correctedVal)) {
                    allValues.add(correctedVal);
                } else if (validMultiSelectValues.contains(val)) {
                    allValues.add(val);
                }
            }
        }
        
        // 3. Process LeadSource - THIS IS KEY FOR DATA IMPORT
        if (String.isNotBlank(newLead.LeadSource)) {
            String leadSourceVal = newLead.LeadSource.trim();
            String correctedVal = typoCorrectionMap.get(leadSourceVal.toLowerCase());
            
            if (correctedVal != null && validMultiSelectValues.contains(correctedVal)) {
                allValues.add(correctedVal);
            } else if (validMultiSelectValues.contains(leadSourceVal)) {
                allValues.add(leadSourceVal);
            }
            // If no match, try to find the closest match
            else if (leadSourceVal.toLowerCase().contains('meta')) {
                // Look for any Meta-related value in the picklist
                for(String validValue : validMultiSelectValues) {
                    if (validValue.toLowerCase().contains('meta')) {
                        allValues.add(validValue);
                        break;
                    }
                }
            }
        }
        
        // 4. Update the fields
        if (!allValues.isEmpty()) {
            newLead.Multi_Select_Lead_Source__c = String.join(new List<String>(allValues), ';');
        } else {
            newLead.Multi_Select_Lead_Source__c = null;
        }

        // 5. Update LeadScore - ONLY if LeadSource is not blank
        if (String.isBlank(newLead.LeadSource)) {
            newLead.LeadScore__c = null;
        } else {
            newLead.LeadScore__c = allValues.size();
        }        
        
    }
}


/*
trigger LeadMultiLeadSourceTrigger on Lead (before insert, before update) {
    // First, get the allowed values for the multi-select picklist
    Schema.DescribeFieldResult multiSelectFieldDescribe = Lead.Multi_Select_Lead_Source__c.getDescribe();
    List<Schema.PicklistEntry> multiSelectPicklistValues = multiSelectFieldDescribe.getPicklistValues();
    Set<String> allowedMultiSelectValues = new Set<String>();
    
    // Create a map of normalized (lowercase) values to actual picklist values
    Map<String, String> normalizedToActualValue = new Map<String, String>();
    
    for (Schema.PicklistEntry ple : multiSelectPicklistValues) {
        allowedMultiSelectValues.add(ple.getValue());
        normalizedToActualValue.put(ple.getValue().toLowerCase(), ple.getValue());
    }
    
    Map<Id, Lead> oldMap = Trigger.isUpdate ? Trigger.oldMap : new Map<Id, Lead>();

    for (Lead newLead : Trigger.new) {
        // STEP 1: Build final list
        List<String> finalValues = new List<String>();
        
        // Add existing values from old record
        if (Trigger.isUpdate) {
            Lead oldRec = oldMap.get(newLead.Id);
            if (oldRec != null && String.isNotBlank(oldRec.Multi_Select_Lead_Source__c)) {
                for (String val : oldRec.Multi_Select_Lead_Source__c.split(';')) {
                    val = val.trim();
                    if (!finalValues.contains(val) && allowedMultiSelectValues.contains(val)) {
                        finalValues.add(val);
                    }
                }
            }
        }
        
        // STEP 2: Process current Multi_Select_Lead_Source__c
        if (String.isNotBlank(newLead.Multi_Select_Lead_Source__c)) {
            for (String val : newLead.Multi_Select_Lead_Source__c.split(';')) {
                val = val.trim();
                String normalizedVal = val.toLowerCase();
                
                // Check if the exact value exists in picklist
                if (allowedMultiSelectValues.contains(val)) {
                    if (!finalValues.contains(val)) {
                        finalValues.add(val);
                    }
                }
                // Check if a normalized version exists
                else if (normalizedToActualValue.containsKey(normalizedVal)) {
                    String actualValue = normalizedToActualValue.get(normalizedVal);
                    if (!finalValues.contains(actualValue)) {
                        finalValues.add(actualValue);
                    }
                }
                // Try to fix common typos
                else if (normalizedVal.contains('meta') && (normalizedVal.contains('ads') || normalizedVal.contains('dds'))) {
                    // Try to find a matching meta ads value
                    String metaAdsValue = null;
                    
                    // Look for any allowed value that contains 'meta' and 'ads'
                    for (String allowedValue : allowedMultiSelectValues) {
                        String allowedLower = allowedValue.toLowerCase();
                        if (allowedLower.contains('meta') && 
                            (allowedLower.contains('ads') || allowedLower.contains('ad'))) {
                            metaAdsValue = allowedValue;
                            break;
                        }
                    }
                    
                    if (metaAdsValue != null && !finalValues.contains(metaAdsValue)) {
                        finalValues.add(metaAdsValue);
                    }
                }
            }
        }
        
        // STEP 3: Process LeadSource - Map to corresponding multi-select value
        if (String.isNotBlank(newLead.LeadSource)) {
            String leadSourceVal = newLead.LeadSource.trim();
            String normalizedLeadSource = leadSourceVal.toLowerCase();
            
            // First, check if LeadSource directly matches a multi-select value
            if (allowedMultiSelectValues.contains(leadSourceVal)) {
                if (!finalValues.contains(leadSourceVal)) {
                    finalValues.add(leadSourceVal);
                }
            }
            // Check if normalized version matches
            else if (normalizedToActualValue.containsKey(normalizedLeadSource)) {
                String actualValue = normalizedToActualValue.get(normalizedLeadSource);
                if (!finalValues.contains(actualValue)) {
                    finalValues.add(actualValue);
                }
            }
            // Try to map common LeadSource values to multi-select values
            else {
                // Common mapping logic - you may need to customize this based on your org
                String mappedValue = null;
                
                if (normalizedLeadSource.contains('meta') && 
                    (normalizedLeadSource.contains('ads') || normalizedLeadSource.contains('dds'))) {
                    // Look for any Meta Ads related value in multi-select picklist
                    for (String allowedValue : allowedMultiSelectValues) {
                        String allowedLower = allowedValue.toLowerCase();
                        if (allowedLower.contains('meta') && 
                            (allowedLower.contains('ads') || allowedLower.contains('ad'))) {
                            mappedValue = allowedValue;
                            break;
                        }
                    }
                }
                // Add more mappings as needed for other LeadSource values
                
                if (mappedValue != null && !finalValues.contains(mappedValue)) {
                    finalValues.add(mappedValue);
                }
            }
        }
        
        // STEP 4: Update the multi-select field
        if (!finalValues.isEmpty()) {
            newLead.Multi_Select_Lead_Source__c = String.join(finalValues, ';');
        } else {
            newLead.Multi_Select_Lead_Source__c = null;
        }
        
        // STEP 5: Update LeadScore
        newLead.LeadScore__c = finalValues.size();
    }
}
*/