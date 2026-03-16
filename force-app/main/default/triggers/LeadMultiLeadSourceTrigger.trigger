trigger LeadMultiLeadSourceTrigger on Lead (before insert, before update) {

    Map<Id, Lead> oldMap = Trigger.isUpdate ? Trigger.oldMap : new Map<Id, Lead>();

    for (Lead newLead : Trigger.new) {

        if (String.isBlank(newLead.LeadSource))
            continue;

        List<String> finalList = new List<String>();

        // 1️⃣ Load OLD values first (NO CHANGE)
        if (Trigger.isUpdate) {
            Lead oldRec = oldMap.get(newLead.Id);
            if (oldRec != null && String.isNotBlank(oldRec.Multi_Select_Lead_Source__c)) {
                finalList.addAll(oldRec.Multi_Select_Lead_Source__c.split(';'));
            }
        }

        // 2️⃣ Handle LeadSource - ONLY FIX FOR META_ADS
        String leadSourceValue = newLead.LeadSource;
        
        // MINIMAL CHANGE: Only convert Meta Ads variations to Meta_Ads
        // This preserves ALL other values exactly as they are
        if (leadSourceValue == 'Meta Ads' || 
            leadSourceValue.equalsIgnoreCase('meta_ads') || 
            leadSourceValue.equalsIgnoreCase('meta ads')) {
            leadSourceValue = 'Meta_Ads'; // Convert to correct API name
        }
        
        // Remove if already present (using corrected value)
        Integer idx = finalList.indexOf(leadSourceValue);
        if (idx != -1) {
            finalList.remove(idx);
        }

        // 3️⃣ Add NEW multi-select values (NO CHANGE except Meta_Ads fix)
        if (String.isNotBlank(newLead.Multi_Select_Lead_Source__c)) {
            for (String s : newLead.Multi_Select_Lead_Source__c.split(';')) {
                // MINIMAL CHANGE: Only fix Meta Ads in multi-select input
                String valueToAdd = s;
                if (valueToAdd == 'Meta Ads' || 
                    valueToAdd.equalsIgnoreCase('meta_ads') || 
                    valueToAdd.equalsIgnoreCase('meta ads')) {
                    valueToAdd = 'Meta_Ads'; // Convert to correct API name
                }
                
                if (!finalList.contains(valueToAdd)) {
                    finalList.add(valueToAdd);
                }
            }
        }

        // 4️⃣ Add LeadSource at END (using corrected value)
        if (!finalList.contains(leadSourceValue)) {
            finalList.add(leadSourceValue);
        }

        // 5️⃣ Update fields (NO CHANGE)
        newLead.Multi_Select_Lead_Source__c = String.join(finalList, ';');
        newLead.LeadScore__c = finalList.size();
    }
}

//working for all except meta ads
// trigger LeadMultiLeadSourceTrigger on Lead (before insert, before update) {

//     Map<Id, Lead> oldMap = Trigger.isUpdate ? Trigger.oldMap : new Map<Id, Lead>();

//     for (Lead newLead : Trigger.new) {

//         if (String.isBlank(newLead.LeadSource))
//             continue;

//         List<String> finalList = new List<String>();

//         // 1️⃣ Load OLD values first
//         if (Trigger.isUpdate) {
//             Lead oldRec = oldMap.get(newLead.Id);
//             if (oldRec != null && String.isNotBlank(oldRec.Multi_Select_Lead_Source__c)) {
//                 finalList.addAll(oldRec.Multi_Select_Lead_Source__c.split(';'));
//             }
//         }

//         // 2️⃣ Remove LeadSource if already present (to push to last)
//         Integer idx = finalList.indexOf(newLead.LeadSource);
//         if (idx != -1) {
//             finalList.remove(idx);
//         }

//         // 3️⃣ Add NEW multi-select values (remove duplicates)
//         if (String.isNotBlank(newLead.Multi_Select_Lead_Source__c)) {
//             for (String s : newLead.Multi_Select_Lead_Source__c.split(';')) {
//                 if (!finalList.contains(s)) {
//                     finalList.add(s);
//                 }
//             }
//         }

//         // 4️⃣ Add LeadSource at END
//         if (!finalList.contains(newLead.LeadSource)) {
//             finalList.add(newLead.LeadSource);
//         }

//         // 5️⃣ Update fields
//         newLead.Multi_Select_Lead_Source__c = String.join(finalList, ';');
//         newLead.LeadScore__c = finalList.size();
//     }
// }




// trigger LeadMultiLeadSourceTrigger on Lead (before insert, before update) {
//     // Helper Set to prevent duplicates
//     Map<Id, Set<String>> multiLeadSourcesMap = new Map<Id, Set<String>>();
    
//     for (Lead lead : Trigger.new) {
//         // Ensure Lead Source is not null
//         if (!String.isEmpty(lead.LeadSource)) {
//             // Initialize Multi-Lead Source Set
//             Set<String> multiLeadSourceSet = new Set<String>();
            
//             // Add existing Multi-Lead Source values to the set
//             if (!String.isEmpty(lead.Multi_Select_Lead_Source__c)) {
//                 List<String> existingValues = lead.Multi_Select_Lead_Source__c.split(';');
//                 multiLeadSourceSet.addAll(existingValues);
//             }
            
//             // Add the current Lead Source value
//             multiLeadSourceSet.add(lead.LeadSource);

//             // Convert set back to a semi-colon-separated string
//             String updatedMultiLeadSource = String.join(new List<String>(multiLeadSourceSet), ';');
//             lead.Multi_Select_Lead_Source__c = updatedMultiLeadSource;

//             // Store the set for calculating the Lead Score
//             multiLeadSourcesMap.put(lead.Id, multiLeadSourceSet);

//             // Update Lead Score based on the number of unique values
//             lead.LeadScore__c = multiLeadSourceSet.size();
//         }
//     }
// }