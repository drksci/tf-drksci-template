// Terratest suite for the homelab-cicd Terraform configuration.
//
// Unit tests (TestValidate, TestPlan*) are fast and need no real hardware.
// Integration tests (TestDeploy*) are skipped unless RUN_INTEGRATION=true.
//
// Run unit tests:
//   go test -v -run TestValidate ./...
//   go test -v -run TestPlan ./...
//
// Run integration (GitHub Actions / real VM):
//   RUN_INTEGRATION=true go test -v -timeout 60m -run TestDeploy ./...

package test

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// repoRoot returns the absolute path to the repository root.
func repoRoot(t *testing.T) string {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	root, err := filepath.Abs(filepath.Join(filepath.Dir(file), "..", ".."))
	require.NoError(t, err)
	return root
}

func tfDir(t *testing.T) string {
	return filepath.Join(repoRoot(t), "environments", "lab")
}

// baseVars is the minimal set of variables needed for validate/plan.
// These override terraform.tfvars so tests are hermetic and match the
// variable defaults (not the operator's local deployment config).
func baseVars() map[string]interface{} {
	return map[string]interface{}{
		"primary_host":        "127.0.0.1",
		"primary_user":        "runner",
		"minio_root_password": "test-only",
		// Explicit runtime so tests don't pick up colima from local terraform.tfvars
		"runtime": "k3s",
		// Disable cloud integrations — no API tokens in unit tests
		"cloudflare_api_token": "",
		"tailscale_auth_key":   "",
		"gdrive_rclone_token":  "",
		"github_token":         "",
		// Override local tfvars defaults for hermeticity
		"enable_backup": false,
		"enable_velero": true,
	}
}

// ---------------------------------------------------------------------------
// Validate — HCL syntax + type checking (no provider calls)
// ---------------------------------------------------------------------------

func TestValidate(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    tfDir(t),
		TerraformBinary: "tofu",
		Vars:            baseVars(),
		// Skip backend init — we're only validating
		BackendConfig: map[string]interface{}{},
	}

	terraform.Init(t, opts)
	terraform.Validate(t, opts)
}

// ---------------------------------------------------------------------------
// Plan — verify resource graph without applying
// ---------------------------------------------------------------------------

func TestPlanDefaultConfig(t *testing.T) {
	opts := &terraform.Options{
		TerraformDir:    tfDir(t),
		TerraformBinary: "tofu",
		Vars:            baseVars(),
		PlanFilePath:    filepath.Join(t.TempDir(), "tfplan"),
	}

	terraform.Init(t, opts)
	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)

	// Core resources must be planned
	assert.NotEmpty(t, plan.ResourceChangesMap, "plan should contain resources")

	// k3s join token must be planned (random_password, namespaced under root module)
	_, hasToken := plan.ResourceChangesMap["module.homelab_cicd.random_password.k3s_token[0]"]
	assert.True(t, hasToken, "k3s join token resource should be in plan")
}

func TestPlanCloudflareDisabledByDefault(t *testing.T) {
	opts := &terraform.Options{
		TerraformDir:    tfDir(t),
		TerraformBinary: "tofu",
		Vars:            baseVars(), // no CF vars set → CF disabled
		PlanFilePath:    filepath.Join(t.TempDir(), "tfplan"),
	}

	terraform.Init(t, opts)
	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)

	// Cloudflare tunnel must NOT be in plan when api_token is empty
	_, hasCFTunnel := plan.ResourceChangesMap["module.homelab_cicd.cloudflare_zero_trust_tunnel_cloudflared.homelab[0]"]
	assert.False(t, hasCFTunnel, "CF tunnel should not be planned when api_token is empty")
}

func TestPlanCloudflareEnabled(t *testing.T) {
	vars := baseVars()
	// CF provider validates token: must be alphanumeric/hyphens/underscores, ≥40 chars
	vars["cloudflare_api_token"] = "test-only-token-aaaaabbbbbccccc11111222223333344444"
	vars["cloudflare_account_id"] = "test-account"
	vars["cloudflare_zone_id"] = "test-zone"
	vars["cloudflare_domain"] = "example.com"

	opts := &terraform.Options{
		TerraformDir:    tfDir(t),
		TerraformBinary: "tofu",
		Vars:            vars,
		PlanFilePath:    filepath.Join(t.TempDir(), "tfplan"),
	}

	terraform.Init(t, opts)
	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)

	// CF tunnel must appear in plan when all CF vars are set
	_, hasCFTunnel := plan.ResourceChangesMap["module.homelab_cicd.cloudflare_zero_trust_tunnel_cloudflared.homelab[0]"]
	assert.True(t, hasCFTunnel, "CF tunnel should be planned when api_token + account + zone are set")
}

func TestPlanBackupDisabledByDefault(t *testing.T) {
	opts := &terraform.Options{
		TerraformDir:    tfDir(t),
		TerraformBinary: "tofu",
		Vars:            baseVars(),
		PlanFilePath:    filepath.Join(t.TempDir(), "tfplan"),
	}

	terraform.Init(t, opts)
	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)

	// enable_backup defaults to false — Velero module should not appear
	for key := range plan.ResourceChangesMap {
		assert.NotContains(t, key, "module.backup", "backup module should not be planned by default")
	}
}

// ---------------------------------------------------------------------------
// Integration — full apply + assertions (skipped unless RUN_INTEGRATION=true)
// ---------------------------------------------------------------------------

func TestDeployMinimal(t *testing.T) {
	if os.Getenv("RUN_INTEGRATION") != "true" {
		t.Skip("set RUN_INTEGRATION=true to run integration tests")
	}

	// Integration test expects a real SSH target at PRIMARY_HOST
	host := os.Getenv("PRIMARY_HOST")
	require.NotEmpty(t, host, "PRIMARY_HOST env var required for integration tests")
	user := os.Getenv("PRIMARY_USER")
	if user == "" {
		user = "runner"
	}
	keyPath := os.Getenv("PRIMARY_KEY_PATH")
	if keyPath == "" {
		keyPath = "~/.ssh/test_key"
	}

	vars := baseVars()
	vars["primary_host"] = host
	vars["primary_user"] = user
	vars["primary_key_path"] = keyPath
	vars["primary_os"] = "linux"
	vars["runtime"] = "k3s"
	// Minimal feature set for fast integration test
	vars["enable_dagger"] = false
	vars["enable_docuum"] = false
	vars["enable_storage"] = false
	vars["enable_backup"] = false
	vars["enable_argocd"] = false
	vars["enable_homepage"] = false
	vars["enable_observability"] = false
	vars["enable_botkube"] = false
	vars["enable_github_runner"] = false
	vars["enable_gvisor"] = false

	opts := &terraform.Options{
		TerraformDir:    tfDir(t),
		TerraformBinary: "tofu",
		Vars:            vars,
	}

	defer terraform.Destroy(t, opts)
	terraform.InitAndApply(t, opts)

	// Verify kubeconfig was written as an output
	kubeconfig := terraform.Output(t, opts, "kubeconfig_path")
	assert.NotEmpty(t, kubeconfig, "kubeconfig_path output should be set after deploy")
}
