public without sharing class cdc_Campus_DriveHandler {

    public static void handleAfterInsert(List<Campus_Drive__c> campusDriveList) {
        recalculateAccountsFor(campusDriveList);
    }

    /**
     * Handles after-delete: Trigger.new is not available for delete events, so the
     * trigger passes Trigger.old here instead. Recalculation re-queries Campus_Drive__c
     * fresh from the database, so it naturally reflects the record(s) just removed.
     */
    public static void handleAfterDelete(List<Campus_Drive__c> campusDriveList) {
        recalculateAccountsFor(campusDriveList);
    }

    private static void recalculateAccountsFor(List<Campus_Drive__c> campusDriveList) {
        if (campusDriveList == null || campusDriveList.isEmpty()) return;

        Set<Id> accIds = new Set<Id>();
        for (Campus_Drive__c drive : campusDriveList) {
            if (drive.Account__c != null) accIds.add(drive.Account__c);
        }
        if (accIds.isEmpty()) return;

        List<Campus_Drive__c> allRelated = [
            SELECT Id, Account__c, Visited__c, Academic_Year__c
            FROM Campus_Drive__c
            WHERE Account__c IN :accIds
        ];

        Map<Id, List<Campus_Drive__c>> accDrivesMap = new Map<Id, List<Campus_Drive__c>>();
        for (Campus_Drive__c drive : allRelated) {
            if (!accDrivesMap.containsKey(drive.Account__c)) {
                accDrivesMap.put(drive.Account__c, new List<Campus_Drive__c>());
            }
            accDrivesMap.get(drive.Account__c).add(drive);
        }

        // Iterate every affected Account, not just accDrivesMap.keySet() — an Account
        // whose last Campus_Drive__c was just deleted has no rows left in the map at
        // all, and still needs its rollups reset back down to zero/blank.
        List<Account> toUpdate = new List<Account>();
        for (Id accId : accIds) {
            List<Campus_Drive__c> drives = accDrivesMap.containsKey(accId)
                ? accDrivesMap.get(accId)
                : new List<Campus_Drive__c>();
            Integer visitedCount = 0;
            Integer maxYear     = 0;
            for (Campus_Drive__c drive : drives) {
                if (drive.Visited__c == true) visitedCount++;
                if (String.isNotBlank(drive.Academic_Year__c) && drive.Academic_Year__c.isNumeric()) {
                    Integer yr = Integer.valueOf(drive.Academic_Year__c);
                    if (yr > maxYear) maxYear = yr;
                }
            }
            Account acc = new Account(Id = accId);
            acc.Total_Visit__c = visitedCount;
            acc.Status_According_to_Current_Year__c = visitedCount > 1 ? 'Repeat' : 'New';
            acc.Recent_Association__c = maxYear > 0 ? String.valueOf(maxYear) : null;
            toUpdate.add(acc);
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    public static void handleBeforeInsert(List<Campus_Drive__c> campusDriveList) {
        if (campusDriveList == null || campusDriveList.isEmpty()) return;

        Set<Id> accIds = new Set<Id>();
        for (Campus_Drive__c drive : campusDriveList) {
            if (drive.Account__c != null) accIds.add(drive.Account__c);
        }

        Map<Id, Account> accountsMap = new Map<Id, Account>();
        if (!accIds.isEmpty()) {
            accountsMap = new Map<Id, Account>([SELECT Id, Name FROM Account WHERE Id IN :accIds]);
        }

        for (Campus_Drive__c drive : campusDriveList) {
            String accountName = '';
            if (drive.Account__c != null && accountsMap.containsKey(drive.Account__c)) {
                accountName = accountsMap.get(drive.Account__c).Name;
            }
            if (String.isNotBlank(drive.Academic_Year__c) && String.isNotBlank(accountName)) {
                drive.Name = drive.Academic_Year__c + ' - ' + accountName;
            } else if (String.isNotBlank(drive.Academic_Year__c)) {
                drive.Name = drive.Academic_Year__c;
            } else if (String.isNotBlank(accountName)) {
                drive.Name = accountName;
            } else {
                drive.Name = 'Campus Drive';
            }
        }
    }
}