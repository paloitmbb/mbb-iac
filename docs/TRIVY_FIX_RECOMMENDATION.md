# Trivy Step Failure Fix Recommendation

## Issue Summary

The Trivy security scan step is failing in the `terraform-ci.yml` workflow. The root cause is in the `mbb-tf-actions` repository's `security-scan-trivy` action.

## Temporary Workaround

While the upstream fix is being applied, you can disable Trivy scanning:

1. **Via workflow_dispatch**: Run the workflow manually and set `enable-trivy` to `false`
2. **Via code change**: Set `enable-trivy: false` in the workflow file (not recommended for production)

## Error Analysis

### Error Logs

```
aquasecurity/trivy info found version: 0.68.1 for v0.68.1/Linux/64bit
##[error]Process completed with exit code 1.
...
##[error]Path does not exist: trivy-results.sarif.
...
❌ Trivy: Failed
##[warning]Trivy SARIF file not generated - scan may have errored
```

### Root Cause

1. The `aquasecurity/trivy-action@v0.33.1` internally uses `aquasecurity/setup-trivy@v0.2.4` to install the Trivy binary
2. The Trivy installation script sometimes fails with exit code 1 (network issues, rate limiting, etc.)
3. When installation fails, no `trivy-results.sarif` file is generated
4. The subsequent SARIF upload step fails because the file doesn't exist
5. The outcome step fails because both the scan failed AND the SARIF file is missing

## Recommended Fix

The fix should be applied in the `mbb-tf-actions` repository in the file:
`actions/security-scan-trivy/action.yml`

### Current Code (Problematic)

```yaml
runs:
  using: 'composite'
  steps:
    - name: Run Security - Scan Trivy
      id: scan
      if: inputs.enabled == 'true'
      continue-on-error: ${{ inputs.continue-on-error == 'true' }}
      uses: aquasecurity/trivy-action@22438a435773de8c97dc0958cc0b823c45b064ac  # v0.33.1
      with:
        scan-type: 'config'
        scan-ref: ${{ inputs.working-directory }}
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: ${{ inputs.severity }}

    - name: Upload Trivy SARIF
      if: inputs.enabled == 'true' && always()
      continue-on-error: true
      uses: github/codeql-action/upload-sarif@7434149006143a4d75b82a2f411ef15b03ccc2d7  # v4.32.2
      with:
        sarif_file: trivy-results.sarif
        category: trivy-${{ inputs.environment }}
        wait-for-processing: true

    - name: Set outcome
      id: result
      if: always()
      shell: bash
      run: |
        if [ "${{ inputs.enabled }}" != "true" ]; then
          echo "outcome=skipped" >> $GITHUB_OUTPUT
          echo "⏭️ Trivy: Skipped (disabled)"
        elif [ "${{ steps.scan.outcome }}" == "success" ] && [ -f "trivy-results.sarif" ]; then
          echo "outcome=success" >> $GITHUB_OUTPUT
          echo "✅ Trivy: Passed"
        else
          echo "outcome=failure" >> $GITHUB_OUTPUT
          echo "❌ Trivy: Failed"
          if [ ! -f "trivy-results.sarif" ]; then
            echo "::warning::Trivy SARIF file not generated - scan may have errored"
          fi
          exit 1
        fi
```

### Recommended Fix

```yaml
runs:
  using: 'composite'
  steps:
    - name: Run Security - Scan Trivy
      id: scan
      if: inputs.enabled == 'true'
      continue-on-error: true  # Always continue to allow proper outcome handling
      uses: aquasecurity/trivy-action@22438a435773de8c97dc0958cc0b823c45b064ac  # v0.33.1
      with:
        scan-type: 'config'
        scan-ref: ${{ inputs.working-directory }}
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: ${{ inputs.severity }}

    - name: Ensure SARIF file exists
      if: inputs.enabled == 'true' && always()
      shell: bash
      run: |
        if [ ! -f "trivy-results.sarif" ]; then
          echo "::warning::Trivy scan failed or did not produce output, creating empty SARIF"
          cat > trivy-results.sarif << 'EOF'
        {
          "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
          "version": "2.1.0",
          "runs": [
            {
              "tool": {
                "driver": {
                  "name": "Trivy",
                  "informationUri": "https://github.com/aquasecurity/trivy",
                  "version": "unknown",
                  "rules": []
                }
              },
              "results": [],
              "invocations": [
                {
                  "executionSuccessful": false,
                  "toolExecutionNotifications": [
                    {
                      "message": {
                        "text": "Trivy scan failed to execute or produce results. Check workflow logs for details."
                      },
                      "level": "error"
                    }
                  ]
                }
              ]
            }
          ]
        }
        EOF
        fi

    - name: Upload Trivy SARIF
      if: inputs.enabled == 'true' && always()
      continue-on-error: true
      uses: github/codeql-action/upload-sarif@7434149006143a4d75b82a2f411ef15b03ccc2d7  # v4.32.2
      with:
        sarif_file: trivy-results.sarif
        category: trivy-${{ inputs.environment }}
        wait-for-processing: true

    - name: Set outcome
      id: result
      if: always()
      shell: bash
      run: |
        if [ "${{ inputs.enabled }}" != "true" ]; then
          echo "outcome=skipped" >> $GITHUB_OUTPUT
          echo "⏭️ Trivy: Skipped (disabled)"
        elif [ "${{ steps.scan.outcome }}" == "success" ]; then
          echo "outcome=success" >> $GITHUB_OUTPUT
          echo "✅ Trivy: Passed"
        else
          echo "outcome=failure" >> $GITHUB_OUTPUT
          echo "❌ Trivy: Failed (scan outcome: ${{ steps.scan.outcome }})"
          # Exit with appropriate code based on continue-on-error setting
          if [ "${{ inputs.continue-on-error }}" != "true" ]; then
            exit 1
          fi
        fi
```

### Key Changes

1. **Always continue-on-error for scan step**: Changed to always use `continue-on-error: true` in the scan step to allow proper outcome handling
2. **Ensure SARIF file exists**: Added a new step that creates a valid empty SARIF file when the scan fails, preventing the upload-sarif step from failing due to missing file
3. **Improved outcome handling**: The outcome step now respects the `continue-on-error` input parameter to decide whether to exit with failure

## Alternative Fix (Simpler)

If a minimal change is preferred:

```yaml
    - name: Ensure SARIF file exists
      if: inputs.enabled == 'true' && always()
      shell: bash
      run: |
        if [ ! -f "trivy-results.sarif" ]; then
          echo '{"version":"2.1.0","runs":[{"tool":{"driver":{"name":"Trivy"}},"results":[]}]}' > trivy-results.sarif
        fi
```

Add this step between the "Run Security - Scan Trivy" and "Upload Trivy SARIF" steps.

## Impact

- The Trivy step will no longer fail due to missing SARIF file
- The outcome will correctly reflect whether the scan succeeded or failed
- The workflow will continue as expected based on the `continue-on-error` setting
- SARIF upload will always succeed (either with real results or empty placeholder)

## Action Required

This fix needs to be applied to the `mbb-tf-actions` repository:
- **Repository**: `paloitmbb/mbb-tf-actions`
- **File**: `actions/security-scan-trivy/action.yml`

### How to Apply the Fix

**Option 1: Replace the entire file**
Copy the contents of `docs/security-scan-trivy-fixed-action.yml` to `mbb-tf-actions/actions/security-scan-trivy/action.yml`

**Option 2: Apply the patch**
Use the patch file `docs/trivy-fix.patch` to apply the changes

After the fix is merged to main, the `mbb-iac` workflows will automatically pick up the fix since they reference `@main`.
