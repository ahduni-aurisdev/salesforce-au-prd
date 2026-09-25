trigger cdc_Campus_Drive on Campus_Drive__c (before insert, after insert, after update, before update, before delete, after delete) {
    if (Trigger.isAfter) {
        if (Trigger.isDelete) {
            // Trigger.new is not populated for delete events — use Trigger.old instead.
            cdc_Campus_DriveHandler.handleAfterDelete(Trigger.old);
        } else {
            cdc_Campus_DriveHandler.handleAfterInsert(Trigger.new);
        }
    }
    if (Trigger.isBefore) {
        cdc_Campus_DriveHandler.handleBeforeInsert(Trigger.new);
    }
}