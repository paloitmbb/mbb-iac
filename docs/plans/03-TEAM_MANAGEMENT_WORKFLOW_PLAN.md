# Team Management Workflow - Implementation Plan

**Created:** 22 February 2026
**Owner:** DevSecOps Team
**Status:** Planning

---

## Executive Summary

Implement a GitHub issue-driven automated workflow that allows organization members to manage teams through structured issue forms. The workflow supports five request types: requesting/removing team maintainer roles, granting/removing team access to repositories, and creating new teams. All requests go through validation and an approval gate before execution, with results reported back as issue comments.

---

## Architecture Overview

```
┌─────────────────────┐
│  User Creates       │
│  Team Request Issue  │
└────────┬────────────┘
         │
         ▼
┌─────────────────────────┐
│  Job 1: Validate        │
│  - Parse issue fields   │
│  - Validate team        │
│  - Validate user        │
│  - Validate repository  │
│  - Post validation      │
│    summary to issue     │
└────────┬────────────────┘
         │ (only if validation passes)
         ▼
┌─────────────────────────┐
│  Approval Gate          │
│  (paloitmbb-devsecops)  │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Job 2: Execute         │
│  - Execute request via  │
│    GitHub API            │
│  - Post execution       │
│    summary to issue     │
│  - Close issue          │
└─────────────────────────┘
```

### Key Differences from Repository Workflow

| Aspect        | Repository Workflow                   | Team Management Workflow               |
| ------------- | ------------------------------------- | -------------------------------------- |
| **Execution** | Creates PR → merges → Terraform apply | Direct GitHub API calls (no Terraform) |
| **Scope**     | Single request type (create repo)     | Five distinct request types            |
| **State**     | Updates YAML + Terraform state        | Stateless API operations               |
| **Trigger**   | `[REPO REQUEST]` prefix in title      | `[TEAM REQUEST]` prefix in title       |

**Rationale for API-based execution:** All team operations are executed directly via GitHub API. Teams are not managed via Terraform in this project, so no YAML file updates or PRs are needed for any request type.

---

## Request Types

| #   | Request Type                       | API Operation                                                        |
| --- | ---------------------------------- | -------------------------------------------------------------------- |
| 1   | Request team maintainer role       | `PUT /orgs/{org}/teams/{team}/memberships/{user}` (role: maintainer) |
| 2   | Remove team maintainer role        | `PUT /orgs/{org}/teams/{team}/memberships/{user}` (role: member)     |
| 3   | Give team access to a repository   | `PUT /orgs/{org}/teams/{team}/repos/{owner}/{repo}`                  |
| 4   | Remove team access to a repository | `DELETE /orgs/{org}/teams/{team}/repos/{owner}/{repo}`               |
| 5   | Create new team                    | `POST /orgs/{org}/teams` + maintainer assignment                     |

---

## Step 1: Issue Template

### 1.1 Issue Form Definition

**File:** `.github/ISSUE_TEMPLATE/team-management.yml`

```yaml
name: Team Management Request
description: Request team role changes, team access to repositories, or create a new team
title: "[TEAM REQUEST] "
labels: ["team-request", "pending-review"]
assignees:
  - devsecops-team

body:
  - type: markdown
    attributes:
      value: |
        ## Team Management Request Form
        Please fill out this form to submit a team management request.
        Your request will be validated and requires approval from the DevSecOps team.

        **Note:** Fields are context-dependent — see field descriptions for which apply to your request type.

  - type: dropdown
    id: request-type
    attributes:
      label: Request Type
      description: Select the type of team management request
      options:
        - Request team maintainer role
        - Remove team maintainer role
        - Give team access to a repository
        - Remove team access to a repository
        - Create new team
    validations:
      required: true

  - type: input
    id: team-name
    attributes:
      label: Team
      description: >
        Name (slug) of the team. For existing operations, this team must already exist.
        For "Create new team", this will be the new team name.
      placeholder: "mbb-web-portal-dev"
    validations:
      required: true

  - type: input
    id: team-maintainer
    attributes:
      label: Team Maintainer
      description: >
        GitHub username to assign/revoke maintainer role.
        Required for maintainer role requests. If left blank, the requestor's username will be used.
        Ignored for team access requests.
      placeholder: "github-username"
    validations:
      required: false

  - type: input
    id: repository
    attributes:
      label: Repository
      description: >
        Name of the repository to grant/remove team access.
        Required for team access requests. Ignored for maintainer role requests.
      placeholder: "mbb-web-portal"
    validations:
      required: false

  - type: dropdown
    id: permission
    attributes:
      label: Permission Level
      description: >
        Permission level for team access to repository (only applicable for "Give team access to a repository").
        Defaults to "push" if not specified.
      options:
        - pull
        - triage
        - push
        - maintain
        - admin
      default: 2
    validations:
      required: false

  - type: textarea
    id: justification
    attributes:
      label: Justification / Remark
      description: Provide a justification or additional comments for this request
      placeholder: |
        - Reason for request:
        - Additional context:
    validations:
      required: true

  - type: checkboxes
    id: terms
    attributes:
      label: Acknowledgment
      description: Please confirm you understand the following
      options:
        - label: I understand that this request requires DevSecOps team approval
          required: true
        - label: I confirm that I am a member of this GitHub organization
          required: true
```

### 1.2 Field Behavior Matrix

| Field                | Maintainer Role Requests     | Team Access Requests    | Create New Team                        |
| -------------------- | ---------------------------- | ----------------------- | -------------------------------------- |
| **Request Type**     | Required                     | Required                | Required                               |
| **Team**             | Required (must exist)        | Required (must exist)   | Required (must NOT exist)              |
| **Team Maintainer**  | Used (defaults to requestor) | Ignored                 | Ignored (requestor becomes maintainer) |
| **Repository**       | Ignored                      | Required (must exist)   | Ignored                                |
| **Permission Level** | Ignored                      | Used (defaults to push) | Ignored                                |
| **Justification**    | Required                     | Required                | Required                               |

---

## Step 2: Workflow Definition

### 2.1 Workflow File

**File:** `.github/workflows/team-management.yml`

```yaml
name: Issue Triggered Team Management Workflow

on:
  issues:
    types: [opened]

permissions:
  issues: write
  contents: write
  pull-requests: write

jobs:
  # ============================================================================
  # Job 1: Validate Team Request
  # ============================================================================
  validate-request:
    name: Validate Team Request
    runs-on: ubuntu-latest
    if: startsWith(github.event.issue.title, '[TEAM REQUEST]')
    outputs:
      request-type: ${{ steps.parse.outputs.request-type }}
      team-name: ${{ steps.parse.outputs.team-name }}
      team-maintainer: ${{ steps.parse.outputs.team-maintainer }}
      repository: ${{ steps.parse.outputs.repository }}
      permission: ${{ steps.parse.outputs.permission }}
      justification: ${{ steps.parse.outputs.justification }}
      validation-passed: ${{ steps.validate.outputs.validation-passed }}

    steps:
      # ... (detailed in Step 3 below)

  # ============================================================================
  # Job 2: Execute Team Request (Requires Approval)
  # ============================================================================
  execute-request:
    name: Execute Team Request
    runs-on: ubuntu-latest
    needs: validate-request
    if: needs.validate-request.outputs.validation-passed == 'true'
    environment: team-management-approval

    steps:
      # ... (detailed in Step 4 below)
```

### 2.2 Workflow Trigger

- **Trigger:** `issues.opened` event
- **Filter:** Issue title must start with `[TEAM REQUEST]`
- **Token:** Uses `secrets.ORG_GITHUB_TOKEN` for org-level API operations (same as repo-creation workflow)

### 2.3 Environment & Approval Gate

Create a new GitHub Environment for the approval gate:

- **Environment name:** `team-management-approval`
- **Required reviewers:** `paloitmbb-devsecops` team members
- **Wait timer:** None (immediate upon approval)

This follows the same pattern as `repo-creation-approval` used by the repository workflow.

---

## Step 3: Validation Job

### 3.1 Parse Issue Form

**Step:** `parse`

Extract fields from the issue body using field label matching (consistent with repo-creation workflow pattern):

```yaml
- name: Parse issue form
  id: parse
  uses: actions/github-script@v7
  with:
    script: |
      const issueBody = context.payload.issue.body;

      function extractField(body, fieldLabel) {
        const regex = new RegExp(`### ${fieldLabel}\\s*\\n\\s*([^\\n#]+)`, 'i');
        const match = body.match(regex);
        return match ? match[1].trim() : '';
      }

      const requestType = extractField(issueBody, 'Request Type');
      const teamName = extractField(issueBody, 'Team');
      let teamMaintainer = extractField(issueBody, 'Team Maintainer');
      const repository = extractField(issueBody, 'Repository');
      const permission = extractField(issueBody, 'Permission Level') || 'push';
      const justification = extractField(issueBody, 'Justification / Remark');

      // Default team maintainer to requestor for maintainer role requests
      const isMaintainerRequest = requestType.includes('maintainer');
      if (isMaintainerRequest && !teamMaintainer) {
        teamMaintainer = context.payload.issue.user.login;
      }

      core.setOutput('request-type', requestType);
      core.setOutput('team-name', teamName);
      core.setOutput('team-maintainer', teamMaintainer);
      core.setOutput('repository', repository);
      core.setOutput('permission', permission);
      core.setOutput('justification', justification);
```

### 3.2 Validation Logic

**Step:** `validate`

Validation rules per request type:

#### 3.2.1 Common Validations

| Check                  | Description                       | Applies To |
| ---------------------- | --------------------------------- | ---------- |
| Request type is valid  | Must be one of five defined types | All        |
| Team name is not empty | Must be provided                  | All        |
| Team name format       | Must match `^[a-zA-Z0-9._-]+$`    | All        |

#### 3.2.2 Request-Type-Specific Validations

| Request Type                           | Validations                                                                            |
| -------------------------------------- | -------------------------------------------------------------------------------------- |
| **Request team maintainer role**       | Team must exist; Username must exist in org                                            |
| **Remove team maintainer role**        | Team must exist; Username must exist in org; User must be a current member of the team |
| **Give team access to a repository**   | Team must exist; Repository must exist in org                                          |
| **Remove team access to a repository** | Team must exist; Repository must exist in org                                          |
| **Create new team**                    | Team must NOT exist (no name collision)                                                |

#### 3.2.3 Validation Implementation

```yaml
- name: Validate team request
  id: validate
  uses: actions/github-script@v7
  with:
    github-token: ${{ secrets.ORG_GITHUB_TOKEN }}
    script: |
      const org = context.repo.owner;
      const requestType = '${{ steps.parse.outputs.request-type }}';
      const teamName = '${{ steps.parse.outputs.team-name }}';
      const teamMaintainer = '${{ steps.parse.outputs.team-maintainer }}';
      const repository = '${{ steps.parse.outputs.repository }}';
      const errors = [];
      const validations = [];

      // --- Common Validations ---

      // Validate request type
      const validTypes = [
        'Request team maintainer role',
        'Remove team maintainer role',
        'Give team access to a repository',
        'Remove team access to a repository',
        'Create new team'
      ];
      if (!validTypes.includes(requestType)) {
        errors.push(`Invalid request type: "${requestType}"`);
      }

      // Validate team name format
      if (!teamName) {
        errors.push('Team name is required');
      } else if (!/^[a-zA-Z0-9._-]+$/.test(teamName)) {
        errors.push('Team name must contain only alphanumeric characters, hyphens, underscores, and periods');
      }

      // --- Team Existence Check ---
      let teamExists = false;
      if (teamName) {
        try {
          await github.rest.teams.getByName({ org, team_slug: teamName });
          teamExists = true;
          validations.push({ check: 'Team exists', result: '✅ Passed' });
        } catch (e) {
          if (e.status === 404) {
            teamExists = false;
            validations.push({ check: 'Team exists', result: '❌ Not found' });
          }
        }
      }

      // For "Create new team": team must NOT exist
      if (requestType === 'Create new team') {
        if (teamExists) {
          errors.push(`Team "${teamName}" already exists. Cannot create a duplicate.`);
        } else {
          validations.push({ check: 'Team does not exist', result: '✅ Passed' });
        }
      } else {
        // For all other requests: team MUST exist
        if (!teamExists) {
          errors.push(`Team "${teamName}" does not exist in the organization.`);
        }
      }

      // --- Username Validation (maintainer requests only) ---
      const isMaintainerRequest = requestType.includes('maintainer');
      if (isMaintainerRequest) {
        if (!teamMaintainer) {
          errors.push('Team maintainer username is required for maintainer role requests');
        } else {
          // Check if user exists
          try {
            await github.rest.users.getByUsername({ username: teamMaintainer });
            validations.push({ check: `User "${teamMaintainer}" exists`, result: '✅ Passed' });
          } catch (e) {
            errors.push(`User "${teamMaintainer}" does not exist on GitHub`);
          }

          // Check org membership
          try {
            await github.rest.orgs.checkMembershipForUser({ org, username: teamMaintainer });
            validations.push({ check: `User "${teamMaintainer}" is org member`, result: '✅ Passed' });
          } catch (e) {
            errors.push(`User "${teamMaintainer}" is not a member of the organization`);
          }
        }
      }

      // --- Repository Validation (team access requests only) ---
      const isAccessRequest = requestType.includes('access to a repository');
      if (isAccessRequest) {
        if (!repository) {
          errors.push('Repository name is required for team access requests');
        } else {
          try {
            await github.rest.repos.get({ owner: org, repo: repository });
            validations.push({ check: `Repository "${repository}" exists`, result: '✅ Passed' });
          } catch (e) {
            errors.push(`Repository "${repository}" does not exist in the organization`);
          }
        }
      }

      // --- Output Results ---
      const passed = errors.length === 0;
      core.setOutput('validation-passed', passed.toString());
      core.setOutput('errors', JSON.stringify(errors));
      core.setOutput('validations', JSON.stringify(validations));
```

### 3.3 Post Validation Summary to Issue

After validation, post a structured comment to the issue:

```yaml
- name: Post validation summary
  if: always()
  uses: actions/github-script@v7
  with:
    github-token: ${{ secrets.ORG_GITHUB_TOKEN }}
    script: |
      const passed = '${{ steps.validate.outputs.validation-passed }}' === 'true';
      const errors = JSON.parse('${{ steps.validate.outputs.errors }}');
      const validations = JSON.parse('${{ steps.validate.outputs.validations }}');

      let comment = passed
        ? '## ✅ Validation Passed\n\n'
        : '## ❌ Validation Failed\n\n';

      // Request summary table
      comment += '### 📋 Request Summary\n\n';
      comment += '| Field | Value |\n';
      comment += '|-------|-------|\n';
      comment += `| **Request Type** | ${{ steps.parse.outputs.request-type }} |\n`;
      comment += `| **Team** | \`${{ steps.parse.outputs.team-name }}\` |\n`;
      comment += `| **Team Maintainer** | ${{ steps.parse.outputs.team-maintainer || '_N/A_' }} |\n`;
      comment += `| **Repository** | ${{ steps.parse.outputs.repository || '_N/A_' }} |\n`;
      comment += `| **Permission** | ${{ steps.parse.outputs.permission || '_N/A_' }} |\n`;
      comment += `| **Requested By** | @${context.payload.issue.user.login} |\n\n`;

      // Validation results
      comment += '### 🔍 Validation Results\n\n';
      comment += '| Check | Result |\n';
      comment += '|-------|--------|\n';
      for (const v of validations) {
        comment += `| ${v.check} | ${v.result} |\n`;
      }
      comment += '\n';

      // Errors (if any)
      if (errors.length > 0) {
        comment += '### ⚠️ Errors\n\n';
        for (const e of errors) {
          comment += `- ❌ ${e}\n`;
        }
        comment += '\n';
      }

      // Next steps
      if (passed) {
        comment += '### 📝 Next Steps\n\n';
        comment += '- ⏳ Awaiting approval from **DevSecOps team**\n';
        comment += '- Once approved, the request will be executed automatically\n';
      } else {
        comment += '### 📝 Next Steps\n\n';
        comment += '- Please fix the validation errors and create a new request issue.\n';
      }

      await github.rest.issues.createComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: context.issue.number,
        body: comment,
      });

      // Add labels
      const labels = passed
        ? ['validation-passed']
        : ['validation-failed'];
      await github.rest.issues.addLabels({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: context.issue.number,
        labels,
      });

      // Close issue if validation failed
      if (!passed) {
        await github.rest.issues.update({
          owner: context.repo.owner,
          repo: context.repo.repo,
          issue_number: context.issue.number,
          state: 'closed',
          state_reason: 'not_planned',
        });
      }
```

---

## Step 4: Execute Job

### 4.1 Execution Logic

The execute job runs after approval. It dispatches to the appropriate API call based on request type.

```yaml
- name: Execute team request
  id: execute
  uses: actions/github-script@v7
  with:
    github-token: ${{ secrets.ORG_GITHUB_TOKEN }}
    script: |
      const org = context.repo.owner;
      const requestType = '${{ needs.validate-request.outputs.request-type }}';
      const teamName = '${{ needs.validate-request.outputs.team-name }}';
      const teamMaintainer = '${{ needs.validate-request.outputs.team-maintainer }}';
      const repository = '${{ needs.validate-request.outputs.repository }}';
      const permission = '${{ needs.validate-request.outputs.permission }}' || 'push';
      let result = {};

      switch (requestType) {

        // ── Request 1: Request team maintainer role ──
        case 'Request team maintainer role':
          await github.rest.teams.addOrUpdateMembershipForUserInOrg({
            org,
            team_slug: teamName,
            username: teamMaintainer,
            role: 'maintainer',
          });
          result = {
            action: 'Assigned maintainer role',
            details: `User \`${teamMaintainer}\` is now a **maintainer** of team \`${teamName}\``,
          };
          break;

        // ── Request 2: Remove team maintainer role ──
        case 'Remove team maintainer role':
          await github.rest.teams.addOrUpdateMembershipForUserInOrg({
            org,
            team_slug: teamName,
            username: teamMaintainer,
            role: 'member',
          });
          result = {
            action: 'Removed maintainer role',
            details: `User \`${teamMaintainer}\` has been demoted to **member** of team \`${teamName}\``,
          };
          break;

        // ── Request 3: Give team access to a repository ──
        case 'Give team access to a repository':
          await github.rest.teams.addOrUpdateRepoPermissionsInOrg({
            org,
            team_slug: teamName,
            owner: org,
            repo: repository,
            permission,
          });
          result = {
            action: 'Granted repository access',
            details: `Team \`${teamName}\` now has **${permission}** access to \`${repository}\``,
          };
          break;

        // ── Request 4: Remove team access to a repository ──
        case 'Remove team access to a repository':
          await github.rest.teams.removeRepoInOrg({
            org,
            team_slug: teamName,
            owner: org,
            repo: repository,
          });
          result = {
            action: 'Removed repository access',
            details: `Team \`${teamName}\` no longer has access to \`${repository}\``,
          };
          break;

        // ── Request 5: Create new team ──
        case 'Create new team':
          const newTeam = await github.rest.teams.create({
            org,
            name: teamName,
            privacy: 'closed',
          });

          // Assign requestor as team maintainer
          const requestor = context.payload.issue.user.login;
          await github.rest.teams.addOrUpdateMembershipForUserInOrg({
            org,
            team_slug: teamName,
            username: requestor,
            role: 'maintainer',
          });

          result = {
            action: 'Created new team',
            details: `Team \`${teamName}\` created. User \`@${requestor}\` assigned as **maintainer**.`,
          };
          break;
      }

      core.setOutput('action', result.action);
      core.setOutput('details', result.details);
```

### 4.2 Post Execution Summary to Issue

```yaml
- name: Post execution summary
  if: always()
  uses: actions/github-script@v7
  with:
    github-token: ${{ secrets.ORG_GITHUB_TOKEN }}
    script: |
      const success = '${{ steps.execute.outcome }}' === 'success';
      const action = '${{ steps.execute.outputs.action }}';
      const details = '${{ steps.execute.outputs.details }}';

      let comment = success
        ? '## ✅ Request Executed Successfully\n\n'
        : '## ❌ Request Execution Failed\n\n';

      comment += '### 📋 Execution Summary\n\n';
      comment += '| Field | Value |\n';
      comment += '|-------|-------|\n';
      comment += `| **Action** | ${action} |\n`;
      comment += `| **Details** | ${details} |\n`;
      comment += `| **Executed By** | Automated Workflow |\n`;
      comment += `| **Approved By** | DevSecOps Team |\n`;

      comment += '\n';

      if (!success) {
        const runUrl = `https://github.com/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`;
        comment += `### 🔧 Troubleshooting\n\n`;
        comment += `- [View Workflow Logs](${runUrl})\n`;
        comment += `- Contact DevSecOps team for assistance\n`;
      }

      await github.rest.issues.createComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: context.issue.number,
        body: comment,
      });

      // Close issue on success
      if (success) {
        await github.rest.issues.update({
          owner: context.repo.owner,
          repo: context.repo.repo,
          issue_number: context.issue.number,
          state: 'closed',
          state_reason: 'completed',
        });
        await github.rest.issues.addLabels({
          owner: context.repo.owner,
          repo: context.repo.repo,
          issue_number: context.issue.number,
          labels: ['completed'],
        });
      } else {
        await github.rest.issues.addLabels({
          owner: context.repo.owner,
          repo: context.repo.repo,
          issue_number: context.issue.number,
          labels: ['execution-failed'],
        });
      }
```

---

## Step 5: Job Summary

### 5.1 Validation Job Summary

Generate a GitHub Actions job summary for the validation job (visible in the Actions tab):

```yaml
- name: Generate validation job summary
  if: always()
  uses: actions/github-script@v7
  with:
    script: |
      const passed = '${{ steps.validate.outputs.validation-passed }}' === 'true';
      const requestType = '${{ steps.parse.outputs.request-type }}';
      const teamName = '${{ steps.parse.outputs.team-name }}';
      const issueNumber = context.issue.number;

      let summary = passed
        ? '# ✅ Team Request Validation Passed\n\n'
        : '# ❌ Team Request Validation Failed\n\n';

      summary += '| Field | Value |\n';
      summary += '|-------|-------|\n';
      summary += `| **Request Type** | ${requestType} |\n`;
      summary += `| **Team** | \`${teamName}\` |\n`;
      summary += `| **Issue** | #${issueNumber} |\n`;
      summary += `| **Requestor** | @${context.payload.issue.user.login} |\n`;
      summary += `| **Status** | ${passed ? '✅ Passed' : '❌ Failed'} |\n\n`;

      if (passed) {
        summary += '## Next Steps\n\n';
        summary += '- Awaiting DevSecOps team approval\n';
        summary += '- Request will be executed automatically upon approval\n';
      }

      await core.summary.addRaw(summary).write();
```

### 5.2 Execute Job Summary

Generate a GitHub Actions job summary for the execution job:

```yaml
- name: Generate execution job summary
  if: always()
  uses: actions/github-script@v7
  with:
    script: |
      const success = '${{ steps.execute.outcome }}' === 'success';
      const action = '${{ steps.execute.outputs.action }}';
      const details = '${{ steps.execute.outputs.details }}';
      const requestType = '${{ needs.validate-request.outputs.request-type }}';
      const teamName = '${{ needs.validate-request.outputs.team-name }}';
      const issueNumber = context.issue.number;

      let summary = success
        ? '# ✅ Team Request Executed Successfully\n\n'
        : '# ❌ Team Request Execution Failed\n\n';

      summary += '| Field | Value |\n';
      summary += '|-------|-------|\n';
      summary += `| **Request Type** | ${requestType} |\n`;
      summary += `| **Team** | \`${teamName}\` |\n`;
      summary += `| **Action** | ${action} |\n`;
      summary += `| **Details** | ${details} |\n`;
      summary += `| **Issue** | #${issueNumber} |\n\n`;

      await core.summary.addRaw(summary).write();
```

---

## Files to Create / Modify

### New Files

| File                                         | Purpose                               |
| -------------------------------------------- | ------------------------------------- |
| `.github/ISSUE_TEMPLATE/team-management.yml` | Issue form template for team requests |
| `.github/workflows/team-management.yml`      | Main workflow for team management     |

### Existing Files (No Modification Required)

None — all team operations are executed directly via GitHub API.

### GitHub Configuration

| Configuration                                                                                                           | Details                                        |
| ----------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| **Environment:** `team-management-approval`                                                                             | New GitHub Environment with required reviewers |
| **Required reviewers:** `paloitmbb-devsecops`                                                                           | Same approval team as repository workflow      |
| **Labels:** `team-request`, `pending-review`, `validation-passed`, `validation-failed`, `completed`, `execution-failed` | Issue labels for tracking                      |

---

## Security Considerations

1. **Token permissions:** `ORG_GITHUB_TOKEN` must have `admin:org` scope for team management API calls
2. **Approval gate:** All requests require DevSecOps team approval before execution
3. **Input validation:** All user-provided inputs are validated before execution
4. **Audit trail:** All actions are logged as issue comments for traceability
5. **Org membership:** Only organization members can create issues (enforced by repository access)
6. **No secret exposure:** No sensitive data is included in issue comments or job summaries

---

## Required Token Permissions

The `ORG_GITHUB_TOKEN` secret must have the following additional permissions for team management:

| Scope       | Permission   | Used For                                  |
| ----------- | ------------ | ----------------------------------------- |
| `admin:org` | Full control | Team creation, membership management      |
| `repo`      | Full control | Repository access management, PR creation |
| `read:org`  | Read access  | Team and membership validation            |

---

## Testing Plan

### Manual Testing Matrix

| #   | Test Case                                        | Expected Outcome                        |
| --- | ------------------------------------------------ | --------------------------------------- |
| 1   | Request maintainer role (valid team, valid user) | ✅ Maintainer role assigned             |
| 2   | Request maintainer role (blank maintainer field) | ✅ Uses requestor's username            |
| 3   | Request maintainer role (nonexistent user)       | ❌ Validation fails                     |
| 4   | Request maintainer role (nonexistent team)       | ❌ Validation fails                     |
| 5   | Remove maintainer role (valid)                   | ✅ Demoted to member                    |
| 6   | Give team access (valid team, valid repo)        | ✅ Access granted                       |
| 7   | Give team access (nonexistent repo)              | ❌ Validation fails                     |
| 8   | Remove team access (valid)                       | ✅ Access removed                       |
| 9   | Create new team (unique name)                    | ✅ Team created, requestor = maintainer |
| 10  | Create new team (existing name)                  | ❌ Validation fails                     |
| 11  | Approval denied                                  | ⏹️ Workflow stops, no action taken      |
| 12  | Non-`[TEAM REQUEST]` issue                       | ⏹️ Workflow does not trigger            |

---

## Implementation Sequence

| Phase       | Task                                                                 | Estimated Effort |
| ----------- | -------------------------------------------------------------------- | ---------------- |
| **Phase 1** | Create issue template (`.github/ISSUE_TEMPLATE/team-management.yml`) | 0.5 day          |
| **Phase 2** | Create workflow file with validation job                             | 1 day            |
| **Phase 3** | Add execution job with API calls                                     | 1 day            |
| **Phase 4** | Add issue comments and job summaries                                 | 0.5 day          |
| **Phase 5** | Configure `team-management-approval` environment                     | 0.5 day          |
| **Phase 6** | End-to-end testing with all request types                            | 1 day            |
| **Total**   |                                                                      | **4.5 days**     |

---

## References

- [Existing Repository Workflow](./02-AUTOMATED_REPO_WORKFLOW_PLAN.md)
- [Implementation Summary](./02-IMPLEMENTATION_SUMMARY.md)
- [GitHub Teams API](https://docs.github.com/en/rest/teams)
- [GitHub Team Membership API](https://docs.github.com/en/rest/teams/members)
- [GitHub Team Repository API](https://docs.github.com/en/rest/teams/teams#add-or-update-team-repository-permissions)
