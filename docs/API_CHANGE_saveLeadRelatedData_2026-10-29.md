# API Change: Auris Lead API (`/saveLeadRelatedData`)

| | |
|---|---|
| **Effective** | Live in UAT and Production from 30-Oct-2026. |
| **Endpoint** | `POST /services/apexrest/saveLeadRelatedData` |
| **Production** | `https://ahmedabaduniversity2.my.salesforce.com/services/apexrest/saveLeadRelatedData` |
| **UAT** | `https://ahmedabaduniversity2--hlisuat.sandbox.my.salesforce.com/services/apexrest/saveLeadRelatedData` |
| **Owner** | Jitendra Varma (Salesforce) |

## Summary

| # | Change | Action needed from Auris |
|---|---|---|
| 1 | **UG Admission Form now requires `leadId`.** Send the Salesforce Lead Id returned by the Registration Form call. That exact Lead is updated. With `leadId`, `email`, `phone`, `mobile` and `admissionYear` become optional. | **Yes:** store `leadIds[0]` from the UG Registration response and send it as `leadId` on every UG Admission Form. Masters / PhD: no change. |
| 2 | **Phone numbers with `+` are saved as sent.** `+919876543210` stays `+919876543210`. | Send phone as `+<country code><number>`. |
| 3 | **Registration Form finds the existing Lead more reliably** (registration number first, then email + phone). | None. |

**Breaking change (UG only):** a UG Admission Form (`department = "Undergraduation"`) without a valid `leadId` is rejected. Nothing is saved. Masters and PhD Admission Forms work exactly as before.

---

## 1. Flow

```
1. Registration Form  ──►  Salesforce creates (or finds) the Lead
                      ◄──  {"leadIds":["00Q..."],"errors":[]}
                           ▲ store this Id against the student

2. Admission Form     ──►  same payload as before + "leadId": "00Q..."
                      ◄──  {"leadIds":["00Q..."],"errors":[]}   (same Id)
```

This applies to **Undergraduation only**. Masters and PhD keep their current flow: no `leadId`, and any `leadId` sent is ignored.

## 2. Registration Form: no change

`typeOfForm = "Auris_Registration_Form"`. Do **not** send `leadId`.

**Request**
```json
{
  "department": "Undergraduation",
  "typeOfForm": "Auris_Registration_Form",
  "leadStatus": "New Lead",
  "email": "student@example.com",
  "firstName": "Navinesh",
  "middleName": "",
  "lastName": "Kowshik",
  "leadSource": "website",
  "phone": "+447887139054",
  "admissionYear": "Admission Year - 2027",
  "cityTownVillage": "Bangalore",
  "stateUnionTerritoryProvince": "Karnataka",
  "country": "India",
  "registrationNumber": "UG2027-90000202",
  "registrationDate": "2026-10-28",
  "areas": "Business, Management, and Commerce;Economics;Sciences",
  "url": "https://undergraduateadmissions.ahduni.edu.in/index.php",
  "utm_source": "website",
  "utm_medium": "",
  "utm_campaign": "",
  "utm_content": "",
  "utm_term": ""
}
```

**Response (HTTP 200)**
```json
{"leadIds":["00Qfv00000cu83TEAQ"],"errors":[]}
```

**Store `leadIds[0]`. It is required for the Admission Form.**

How Salesforce matches an existing Lead on registration (first match wins):
1. Same `registrationNumber` + same department
2. Same `email` + same last 10 digits of `phone` + same department
3. No match, so a new Lead is created

Sending the same Registration Form twice updates the same Lead. It does not create a duplicate.

## 3. UG Admission Form: `leadId` now required

`department = "Undergraduation"` and `typeOfForm = "Auris_Admission_Form"`. Applies to **every** UG Admission Form payload, whatever the `leadStatus`.

**Fields**

| Key | Required | Notes |
|---|---|---|
| `leadId` | **Yes (new)** | Salesforce Lead Id from the Registration Form response (`leadIds[0]`). 15 or 18 characters. |
| `department` | Yes | `Undergraduation` |
| `typeOfForm` | Yes | `Auris_Admission_Form` |
| `registrationNumber` | Yes | Must match the Lead |
| `grpPrograms` | Yes | At least one group with `grptag` (unchanged) |
| `leadStatus` | Optional | Updated when sent |
| `email`, `phone`, `mobile`, `admissionYear` | **Optional** | Updated when sent. When left out, there's no error and the Lead keeps its current values. |

**Request**
```json
{
  "leadId": "00Qfv00000cu83TEAQ",
  "department": "Undergraduation",
  "typeOfForm": "Auris_Admission_Form",
  "leadStatus": "Application Initiated",
  "registrationNumber": "UG2027-90000202",
  "grpPrograms": [
    {
      "grptag": "UG_Lateral",
      "applicationNumber": "",
      "applicationDate": "",
      "programmes": []
    }
  ]
}
```
`email`, `phone`, `mobile` and `admissionYear` can still be sent; they are optional.

**Response (HTTP 200)**
```json
{"leadIds":["00Qfv00000cu83TEAQ"],"errors":[]}
```

**Rules**
- The Lead given by `leadId` is updated. Salesforce does **not** search by email or phone, and **never creates** a Lead from a UG Admission Form.
- `registrationNumber` must match the Lead's registration number.
- The Lead must be an Undergraduation Lead.
- Converted Leads are accepted, as before.

**Masters / PhD Admission Form:** no change. `leadId` is not needed and is ignored if sent.

## 4. Errors

Errors return **HTTP 500**. The payload is not saved.

```json
{
  "leadIds": [],
  "errors": [
    {
      "registrationNumber": "UG2027-90000202",
      "errorMessage": "Missing required field: leadId. Auris_Admission_Form must include the leadId of the Lead to update."
    }
  ]
}
```

**New `leadId` errors (UG Admission Form only)**

| Case | `errorMessage` | What to do |
|---|---|---|
| `leadId` missing, `""` or `null` | `Missing required field: leadId. Auris_Admission_Form must include the leadId of the Lead to update.` | Send the Id from the Registration response |
| Not a valid Salesforce Id | `Invalid leadId "<value>": not a valid Salesforce Id.` | Check the stored value |
| Valid Id, but not a Lead | `Invalid leadId "<value>": not a Lead Id.` | Lead Ids start with `00Q` |
| No Lead with this Id (deleted or wrong org) | `Invalid leadId "<value>": no Lead found with this Id.` | Check that UAT/Prod Ids aren't mixed up; contact Salesforce team |
| Lead belongs to another registration number | `leadId "<value>" belongs to Registration Number "<on lead>", but the payload has "<in payload>".` | Wrong student's Id; fix the mapping |
| Lead is not an Undergraduation Lead | `leadId "<value>" belongs to department "<on lead>", but the payload has "Undergraduation".` | Check the stored `leadId` |

**Existing errors (unchanged)**

| Case | `errorMessage` |
|---|---|
| `registrationNumber` missing | `Missing required field: registrationNumber` |
| `department` missing | `Missing required field: department` |
| Unknown department | `Invalid department or no record type mapping found` |
| UG Admission without `grpPrograms` | `grpPrograms is required and cannot be null.` |
| UG Admission with empty `grpPrograms` | `grpPrograms cannot be an empty list. At least one group is required.` |

**Batch requests:** when a JSON array is sent, each item is processed separately. Successful items are returned in `leadIds` and failed items in `errors`. The HTTP status is 500 if **any** item failed.

## 5. Phone format

Send `phone` (and `mobile`) **with `+` and the country code**.

| Sent | Saved in Salesforce |
|---|---|
| `+919876543210` | `+919876543210` |
| `+44 7887 139054` | `+447887139054` (spaces and dashes removed) |
| `9876543210` (no `+`, old format) | `919876543210` (country code added from `country`; still supported) |

## 6. Important for go-live

- **UG students who registered before this change.** Their Admission Form also needs `leadId`. If Auris did not store `leadIds` from earlier Registration responses, ask the Salesforce team for a registration number → lead Id list.
- **Don't mix environments.** UAT and Production Lead Ids are different. A UAT Id sent to Production returns `no Lead found`.
- **Error handling.** On an error, the data is **not** saved. Log `errors[].errorMessage` and retry after fixing. Do not retry the same payload without changes.

## 7. Testing

Test in UAT first. Production has been live since 30-Oct-2026.

UAT test leads (sandbox only):

| Lead Id | Registration Number | Department |
|---|---|---|
| `00Qft000002iXiHEAU` | `UG2027-90000550` | Undergraduation |
| `00Qft000002iXgfEAE` | `UG2027-90000545` | Undergraduation |
| `00Qft000002WW22EAG` | `MR-Ma6241702` | Masters |
