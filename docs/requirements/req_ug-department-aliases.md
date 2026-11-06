# UG department aliases

- Source: user-reported Auris admission API department mismatch in this conversation.
- Author: user; captured by Codex on 2026-11-02.
- Decision: treat `Undergraduate` and `Undergraduation` as equivalent UG department names.
- Approval: user replied `YES` to the proposed local Apex and regression-test change.
- Status: deployed to UAT (`0Afft000000PvazCAC`) and Production (`0Affv0000010y3dCAA`) on 2026-11-02; pending user validation in production.

## Requirement and implementation

The `/saveLeadRelatedData` endpoint must accept either UG name in an admission payload
and on the referenced Lead. Normalize the payload department for existing UG routing,
record-type lookup and form-metadata selection. Compare normalized names when validating
the Lead department. Registration duplicate lookup searches both UG department names.
The original payload field value remains available to the existing field-mapping logic;
this change does not perform a department data migration.

Keep exact `leadId` selection and registration-number ownership checks. Missing, invalid,
not-found or mismatched IDs retain their existing errors. Unrelated departments remain
distinct. Admission calls must not fall back to contact matching or create a Lead.

## Impact and dependencies

- Modified: `saveWebTo_YourProfileData` and `saveWebTo_YourProfileData_Test`.
- No components deleted; no org data changed; no deployment authorized.
- Dependencies: existing `Undergraduation` department record-type mapping, Auris form
  mappings, and Lead automation. No new custom metadata or package dependencies.
- API compatibility: accepts an additional equivalent name; response schema unchanged.
- Registration impact: existing Leads under either UG name are eligible for the same
  registration-number-first lookup. Existing candidate limit and tie-breaking remain.
- Risk: low. Effort estimate: under one hour.
- Stakeholders: Salesforce administrators and Auris integration maintainers; communicate
  the accepted names after deployment. No user retraining expected.
- Declarative assessment: selection and validation occur inside the existing Apex REST
  handler; implement this correction in that handler rather than adding record automation.

## Verification

Added regressions for both mixed-name directions, both alias names together, required
Lead ID under the alias, wrong registration rejection, unrelated department rejection,
and registration lookup of an existing alias Lead. Existing canonical-name tests remain.
Local whitespace/diff validation passed. Apex tests cannot execute against edited local
code without an org validation or deployment; neither has been performed for this change.

## Release

Before deployment, retrieve current target metadata, review the diff, perform validation
with specific test classes, and obtain separate deployment approval under AGENTS.md.
Rollback is redeployment of the retrieved pre-change Apex class and tests.

## Follow-up: Wonderchat / enquiry form source (2026-11-02)

- Cause: `AU_EnquiryForm` page puts the department label (`Form_Department_Config.UG` MasterLabel `Undergraduate`) into `Lead.Department__c`; on an email + phone match it updates the existing Lead with it.
- Decision (user): change only the metadata label to `Undergraduation`; no Apex change, no data clean-up of existing `Undergraduate` leads, no other logic change. Accepted that students see "Undergraduation" on the form.
- Status: deployed to UAT (`0Afft000000PwyTCAS`) and Production (`0Affv0000010ze1CAA`) on 2026-11-02; pending user validation in production.
