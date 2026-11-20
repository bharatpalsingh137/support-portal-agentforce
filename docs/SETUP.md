# Setup guide

This guide takes you from an empty org to a working portal with an AI agent. Steps 1–3 are scripted. Steps 4–8 are point-and-click setup that can't (or shouldn't) be deployed as code.

## 0. Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`)
- Node.js 20+ (for the LWC Jest tests)
- VS Code with the Salesforce Extension Pack
- A **Dev Hub** org (any Developer Edition org with Dev Hub turned on: Setup → Dev Hub)
- For the Agentforce parts: an **Agentforce-enabled Developer Edition org** (free from Salesforce Developers)

> **Scratch org or Developer Edition?** Scratch orgs are great for CI and for the core project. Agentforce and Prompt Builder are easiest in an Agentforce-enabled Developer Edition org. In that case, skip `org create scratch` and use `sf org login web --alias support-portal` instead.

## 1. Deploy the metadata

```bash
sf project deploy start --source-dir force-app --target-org support-portal
```

`standardValueSets/CaseStatus` replaces the Case Status picklist with: New, Working, Waiting on Customer, Escalated, Closed. In an org that already uses other statuses, add *Waiting on Customer* and *Escalated* by hand and delete that file instead.

## 2. Permissions

```bash
sf org assign permset --name Support_Agent --target-org support-portal
```

Add the custom fields (Product Category, Source Channel, Resolution, Waiting Since, AI Summary) to the Case page layout, and add the **Case Detail Timeline** component to the Case record page if you like.

## 3. Demo data and scheduled job

```bash
sf apex run --file scripts/apex/sample-data.apex --target-org support-portal
sf apex run --file scripts/apex/schedule-jobs.apex --target-org support-portal
```

To test the batch right away, run this in Anonymous Apex:

```apex
Database.executeBatch(new CaseAutoCloseBatch(0), 200);
```

## 4. Experience Cloud site

1. **Setup → Digital Experiences → Settings**: turn on Digital Experiences and pick a domain.
2. **All Sites → New → Customer Service** template (Aura). Name it *Support Portal*.
   LMS and these components work in Aura sites. The components also target LWR pages.
3. In **Experience Builder**:
   - Create a page called **Support** and drag in **Case Create Wizard**, **My Cases** and **Case Detail Timeline** (two-column layout: wizard and list on the left, timeline on the right).
   - On the Case record detail page, add **Case Detail Timeline**. Its Record Id property defaults to `{!recordId}`.
4. **Administration → Members**: add the *Customer Community User* profile (or a clone of it).
5. **Administration → Login & Registration**: optionally turn on self-registration and assign new users to the Account *Sunrise Retail Pvt Ltd*.
6. Assign the **Support_Portal_Customer** permission set to customer users. With the Experience Cloud license, you can include it in a permission set group.
7. **Publish** the site.

### Sharing so customers only see their own cases

- **Setup → Sharing Settings**: set external access for Case to **Private**.
- **Setup → Digital Experiences → Settings → Sharing Sets → New**:
  - Profiles: *Customer Community User*
  - Object: **Case**. Grant access where `User.Contact` = `Case.Contact`, Access: *Read/Write*
- `FAQ__c` is Public Read Only, both internal and external.

### Create a test customer user

Open the contact *Priya Sharma* → **Enable Customer User** → profile *Customer Community User*. Then assign `Support_Portal_Customer` and log in to the site with that user.

## 5. Service Cloud: queues and Omni-Channel (optional, good for demos)

1. **Queues → New**: *Billing Support*, *Technical Support* (object: Case).
2. **Case Assignment Rules**: route by `Product Category`.
3. **Omni-Channel Settings**: turn on Omni-Channel. Create a **Routing Configuration** and a **Service Channel** for Case, then link the queues.
4. Add the Omni-Channel utility to the Service Console app.

## 6. Entitlements and SLAs (optional)

1. **Entitlement Settings**: turn on Entitlement Management (the scratch org definition already includes the feature).
2. Create an **Entitlement Process** *Standard Support* with milestones *First Response* (4 hours) and *Resolution* (48 hours).
3. Create an Entitlement on the *Sunrise Retail* account that uses the process.

## 7. Agentforce service agent

1. **Setup → Einstein Setup**: turn on Einstein. **Setup → Agentforce Agents**: turn on Agentforce.
2. **New Agent** → *Agentforce Service Agent* template. Name it *Support Assistant*.
3. Assign the **Support_Agent** permission set to the agent's running user (Setup → Users → *EinsteinServiceAgent User*).
4. In **Agent Builder**, create a topic:

   **Topic name:** Case Management
   **Classification description:** Handles questions about support issues, creating support cases, checking case status and adding updates to existing cases.
   **Scope:** Your job is to help customers resolve product issues using the FAQ library, create support cases when needed, report case status and add customer updates to their cases.
   **Instructions** (add each one separately):
   - Always run "Search FAQs" first when a customer describes a problem. If an answer is found, share it and ask whether it solved the issue.
   - Only create a case if the FAQ answer didn't help or no FAQ was found. Before creating it, ask for the customer's email address.
   - Before sharing case status or adding a comment, you must have both the case number and the customer's email address. Never guess them.
   - After creating a case, always tell the customer the case number.
   - If an action returns success = false, give the customer the action's message and offer to try again.

5. **Add these actions** to the topic (Apex type → choose the class):
   - `Search FAQs` (AgentSearchFaqAction)
   - `Create Support Case` (AgentCreateCaseAction)
   - `Get Case Status` (AgentGetCaseStatusAction)
   - `Add Comment to Case` (AgentAddCaseCommentAction)

   For each input, tick **Require input**, and tick **Show in conversation** for the output `message`.
6. Test in the **Conversation Preview**:
   - "I was charged twice this month" → FAQ answer
   - "That didn't help, please open a ticket. My email is priya.sharma@example.com" → case created
   - "What's the status of case 1002? Email priya.sharma@example.com" → status
7. **Activate** the agent and add it to the Experience site with **Embedded Service Deployment → Messaging for In-App and Web**.

## 8. AI case summary (Prompt Builder, optional)

1. **Setup → Prompt Builder → New Prompt Template**
   - Type: **Field Generation**, Object: **Case**, Field: **AI Summary**
   - API Name: **Case_Summary**
   - Prompt:

     ```
     You are a support team lead. Summarise this support case for a colleague who is picking it up.
     Write at most 5 bullet points: the customer's problem, what has been tried, the current status,
     and the next step. Use plain language.

     Subject: {!$Input:Case.Subject}
     Description: {!$Input:Case.Description}
     Status: {!$Input:Case.Status}
     Priority: {!$Input:Case.Priority}
     Category: {!$Input:Case.Product_Category__c}
     Resolution: {!$Input:Case.Resolution__c}
     ```
2. Activate the template.
3. Deploy the Apex extension:

   ```bash
   sf project deploy start --source-dir agentforce-extension --target-org support-portal
   ```
4. Use `CaseSummaryService.summarizeCases` as a **Flow action** (for example, a screen flow quick action called "Summarise case"), or add "Summarize Case" as another agent action.

## 9. GitHub Actions CI

The workflow in `.github/workflows/ci.yml` runs three jobs:

| Job | What it does | Needs |
|---|---|---|
| `lwc-tests` | ESLint + Jest with coverage | nothing |
| `code-analyzer` | Salesforce Code Analyzer (PMD and others), HTML report as an artifact | nothing |
| `deploy-and-test` | Creates a scratch org, deploys, runs all Apex tests, deletes the org | `DEVHUB_SFDX_URL` secret |

To get the Dev Hub secret:

```bash
sf org display --target-org devhub --verbose --json
```

Copy the value of `sfdxAuthUrl` (it starts with `force://`) into **GitHub → Settings → Secrets and variables → Actions → New repository secret** with the name `DEVHUB_SFDX_URL`. Never commit this value.

## Troubleshooting

| Problem | Fix |
|---|---|
| Deploy fails on `CaseStatus` | Your org has cases using a status not in the file. Add it to the file or remove the file and add the statuses manually. |
| Portal user sees "Case not found" | Check the sharing set and that the user has `Support_Portal_Customer`. |
| Agent says it can't find the case | The email must match `Contact.Email` on the case, and the agent user needs `Support_Agent`. |
| `Application_Log__c` stays empty | Platform event triggers run as the Automated Process user. Check **Setup → Platform Events → Log Event → Subscriptions**. |
| FAQ suggestions never appear | New records take a few minutes to be indexed for SOSL search. |
