# Team Management Workflow - Implementation Summary

**Date:** 23 February 2026
**Status:** ✅ Implementation Complete
**Plan Reference:** [03-TEAM_MANAGEMENT_WORKFLOW_PLAN.md](./03-TEAM_MANAGEMENT_WORKFLOW_PLAN.md)

---

## Overview

The issue-driven team management workflow has been fully implemented. Organization members can now submit team management requests through GitHub Issues, which are automatically validated and executed upon DevSecOps team approval.

---

## Files Created

| File                                         | Purpose                                          |
| -------------------------------------------- | ------------------------------------------------ |
| `.github/ISSUE_TEMPLATE/team-management.yml` | Issue form template for team management requests |
| `.github/workflows/team-management.yml`      | GitHub Actions workflow — validation + execution |

---

## Workflow Summary

### Trigger

- **Event:** `issues.opened`
- **Filter:** Issue title must start with `[TEAM REQUEST]`

### Architecture

```
User Opens Issue [TEAM REQUEST]
         │
         ▼
Job 1: validate-request
  ├── Parse issue form fields
  ├── Validate request type, team name format
  ├── Check team existence (API)
  ├── Check user/org membership (maintainer requests)
  ├── Check repository existence (access requests)
  ├── Post validation summary comment to issue
  └── Add labels: validation-passed / validation-failed
         │ (only if validation passes)
         ▼
  Approval Gate: team-management-approval environment
  (required reviewers: paloitmbb-devsecops)
         │
         ▼
Job 2: execute-request
  ├── Execute GitHub API call based on request type
  ├── Post execution summary comment to issue
  └── Close issue (completed) or label (execution-failed)
```

### Supported Request Types

| #   | Request Type                       | API Operation                                                        |
| --- | ---------------------------------- | -------------------------------------------------------------------- |
| 1   | Request team maintainer role       | `PUT /orgs/{org}/teams/{team}/memberships/{user}` (role: maintainer) |
| 2   | Remove team maintainer role        | `PUT /orgs/{org}/teams/{team}/memberships/{user}` (role: member)     |
| 3   | Give team access to a repository   | `PUT /orgs/{org}/teams/{team}/repos/{owner}/{repo}`                  |
| 4   | Remove team access to a repository | `DELETE /orgs/{org}/teams/{team}/repos/{owner}/{repo}`               |
| 5   | Create new team                    | `POST /orgs/{org}/teams` + maintainer assignment                     |

---

## Validation Rules

### Common (all request types)

| Check               | Description                       |
| ------------------- | --------------------------------- |
| Request type valid  | Must be one of five defined types |
| Team name not empty | Must be provided                  |
| Team name format    | Must match `^[a-zA-Z0-9._-]+$`    |

### Per Request Type

| Request Type             | Additional Checks                                      |
| ------------------------ | ------------------------------------------------------ |
| Maintainer role requests | Team exists; User exists on GitHub; User is org member |
| Team access requests     | Team exists; Repository exists in org                  |
| Create new team          | Team must **NOT** exist (prevents duplicates)          |

---

## GitHub Configuration Required

The following GitHub Environment must be manually configured before the workflow runs:

### `team-management-approval` Environment

| Setting                | Value                      |
| ---------------------- | -------------------------- |
| **Name**               | `team-management-approval` |
| **Required reviewers** | `paloitmbb-devsecops` team |
| **Wait timer**         | None                       |

**Setup path:** Repository → Settings → Environments → New environment

### Required Secret

| Secret             | Usage                                                                                                                                          |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `ORG_GITHUB_TOKEN` | GitHub token with `admin:org`, `repo`, and `read:org` scopes for team management API calls. Already configured for the repo-creation workflow. |

### Issue Labels Required

The following labels must exist in the repository:

| Label               | Created by      |
| ------------------- | --------------- |
| `team-request`      | Manually create |
| `pending-review`    | Manually create |
| `validation-passed` | Manually create |
| `validation-failed` | Manually create |
| `completed`         | Manually create |
| `execution-failed`  | Manually create |

---

## Key Design Decisions

### 1. Direct API Execution (No Terraform)

Team membership and maintainer roles are stateless operations applied directly via GitHub API. This provides faster execution and avoids Terraform state complexity for ephemeral membership changes.

### 2. Approval Gate

All five request types require DevSecOps approval via the `team-management-approval` environment, ensuring consistent oversight for all team changes.

### 3. Default Team Maintainer

For maintainer role requests where the `Team Maintainer` field is blank, the workflow defaults to the issue requestor's username. This reduces friction for self-service maintainer assignments.

### 4. Consistent Patterns

The workflow follows the same structural patterns as the existing `repo-request.yml`:

- `actions/github-script@v7` for all API and scripting steps
- GitHub job summaries alongside issue comments
- Environment-based approval gate
- Conventional commit messages following project guidelines

---

## Testing Checklist

| #   | Test Case                                        | Expected Outcome                                    |
| --- | ------------------------------------------------ | --------------------------------------------------- |
| 1   | Request maintainer role (valid team, valid user) | ✅ Maintainer role assigned                         |
| 2   | Request maintainer role (blank maintainer field) | ✅ Uses requestor's username                        |
| 3   | Request maintainer role (nonexistent user)       | ❌ Validation fails, issue closed                   |
| 4   | Request maintainer role (nonexistent team)       | ❌ Validation fails, issue closed                   |
| 5   | Remove maintainer role (valid)                   | ✅ Demoted to member                                |
| 6   | Give team access (valid team, valid repo)        | ✅ Access granted                                   |
| 7   | Give team access (nonexistent repo)              | ❌ Validation fails, issue closed                   |
| 8   | Remove team access (valid)                       | ✅ Access removed                                   |
| 9   | Create new team (unique name)                    | ✅ Team created, requestor = maintainer, no PR created |
| 10  | Create new team (existing name)                  | ❌ Validation fails, issue closed                      |
| 11  | Approval denied                                  | ⏹️ Workflow stops, no action taken                  |
| 12  | Non-`[TEAM REQUEST]` issue                       | ⏹️ Workflow does not trigger                        |

---

## Post-Implementation Steps

1. **Create `team-management-approval` environment** in repository settings with `paloitmbb-devsecops` as required reviewer
2. **Create issue labels** listed above in the repository
3. **Verify `ORG_GITHUB_TOKEN`** has `admin:org` scope (already required by repo-creation workflow)
4. **End-to-end test** each of the five request types in a non-production context

---

## References

- [Plan Document](./03-TEAM_MANAGEMENT_WORKFLOW_PLAN.md)
- [Repository Workflow Implementation Summary](./02-IMPLEMENTATION_SUMMARY.md)
- [Issue Template](../../.github/ISSUE_TEMPLATE/team-management.yml)
- [Workflow File](../../.github/workflows/team-management.yml)
