# kfinalizer

A CLI tool to remove Kubernetes finalizers and force delete stuck namespaces.

> ⚠️ **Disclaimer**: This tool comes with **NO WARRANTIES** or **GUARANTEES**. Use at your own risk. The authors are not responsible for any damage, data loss, or cluster issues that may result from using this tool.

## What It Does

`kfinalizer` helps you clean up stuck Kubernetes namespaces that won't delete due to finalizers. It:

-  **Detects** stuck resources in terminating namespaces
-  **Targets** only the resources that are actually stuck (not all 150+ Kubernetes resource types)
-  **Removes finalizers** from custom resources that are blocking namespace deletion
-  **Force deletes** namespaces when resources can't be patched (e.g., due to missing webhooks)
-  **Dry-run mode** lets you preview changes before applying them

## How It Works

1. **Reads namespace status** to identify which resources are stuck (from `NamespaceContentRemaining` condition) — including built-in resources like `persistentvolumeclaims`, not just CRDs
2. **Patches only the instances that actually have finalizers** (filtered via jq), by name: `kubectl patch <resource> <name> -p '{"metadata":{"finalizers":null}}' --type=merge`
3. **Falls back to force delete** if patching fails (removes namespace finalizer directly via API). Before force-deleting, warns about resources that would be orphaned in etcd; use `--delete-orphans` to strip their finalizers via the raw `/finalize` API first.

## Installation

### Quick Install

```bash
# Download the script
curl -O https://raw.githubusercontent.com/AlienAscension/kfinalizer/main/kfinalizer
chmod +x kfinalizer

# Move to your PATH
sudo mv kfinalizer /usr/local/bin/
```

### Install to User Directory

```bash
# Clone the repo
git clone https://github.com/AlienAscension/kfinalizer.git
cd kfinalizer

# Install using Make
make install

# Or use the install script
./install.sh
```

This installs to `~/.local/bin/kfinalizer`. Make sure `~/.local/bin` is in your PATH:

```bash
export PATH="$PATH:~/.local/bin"
```

## Tutorial

### Basic Usage

#### 1. Check what's stuck in your namespace

```bash
kubectl describe namespace <stuck-namespace>
```

Look for the `NamespaceContentRemaining` condition to see which resources are blocking deletion.

#### 2. Preview changes (dry-run)

**Always start with a dry-run to see what will be changed:**

```bash
kfinalizer -n <namespace> --dry-run -v
```

Example output:
```
⚠ DRY RUN MODE - No changes will be made
ℹ Namespace: longhorn-system
⚠ Namespace is Terminating - checking what's stuck...
ℹ Stuck resources found:
  - backuptargets.longhorn.io has 1 resource
  - engines.longhorn.io has 1 resource
  - volumes.longhorn.io has 1 resource
ℹ Finalizers: longhorn.io in 12 resource instances
ℹ Target: Stuck resources from namespace status
```

#### 3. Remove finalizers

```bash
kfinalizer -n <namespace>
```

The tool will attempt to patch each stuck resource to remove its finalizers.

#### 4. Force delete if needed

If patching fails (common when webhooks are missing), use force delete:

```bash
kfinalizer -n <namespace> --force
```

This bypasses the stuck resources and removes the namespace finalizer directly.

### Common Scenarios

#### Stuck Longhorn namespace

```bash
# Dry-run first
kfinalizer -n longhorn-system --dry-run -v

# Apply changes
kfinalizer -n longhorn-system

# If webhooks are blocking, force delete
kfinalizer -n longhorn-system --force
```

#### Target specific resources only

```bash
kfinalizer -n my-namespace \
  -r mycustomresource.example.com \
  -r anothercr.example.com
```

#### Target a specific cluster

```bash
# Use a specific context (safer for multi-cluster admins)
kfinalizer -n my-namespace -c prod-cluster

# Or a specific kubeconfig file
kfinalizer -n my-namespace --kubeconfig ~/.kube/prod.conf

# Both together
kfinalizer -n my-namespace -c prod-cluster --kubeconfig ~/.kube/prod.conf
```

The active context is printed before any action, so you always know which cluster you're hitting.

## Command-Line Options

```
OPTIONS:
    -n, --namespace <n>      Namespace to clean (required)
    -r, --resource <type>    Specific resource type (can be used multiple times)
    -a, --all                Process ALL resources (default: stuck resources only)
    -d, --dry-run            Preview changes (server-side dry-run — exercises admission webhooks)
    -f, --force              Force delete namespace after removing finalizers
    --delete-orphans         Strip finalizers on stuck resources via raw /finalize API before force-deleting
    -c, --context <name>     Target a specific kube context
    --kubeconfig <path>     Use a specific kubeconfig file
    --timeout <sec>          Per-request kubectl timeout (default: 30s)
    -v, --verbose            Show detailed output
    -h, --help               Show help message
    -V, --version            Show version
```

ENVIRONMENT VARIABLES:
    KFINALIZER_NAMESPACE        Default namespace if -n not specified
    KFINALIZER_DRY_RUN          Set to 'true' to enable dry-run mode
    KFINALIZER_CONTEXT          Default kube context
    KFINALIZER_KUBECONFIG       Default kubeconfig path
    KFINALIZER_TIMEOUT          Per-request kubectl timeout (default: 30s)
    KFINALIZER_DELETE_ORPHANS   Set to 'true' to enable --delete-orphans
```

## Real-World Example

### Problem: Longhorn namespace stuck for 21 days

```bash
$ kubectl get ns
NAME              STATUS        AGE
longhorn-system   Terminating   21d

$ kubectl describe ns longhorn-system
...
NamespaceContentRemaining: Some resources are remaining: 
  backuptargets.longhorn.io has 1 resource instances
  engines.longhorn.io has 1 resource instances
  volumes.longhorn.io has 1 resource instances
NamespaceFinalizersRemaining: longhorn.io in 12 resource instances
```

### Solution

```bash
$ kfinalizer -n longhorn-system --dry-run -v
⚠ DRY RUN MODE - No changes will be made
ℹ Stuck resources found:
  - backuptargets.longhorn.io has 1 resource
  - engines.longhorn.io has 1 resource
  - volumes.longhorn.io has 1 resource
ℹ Finalizers: longhorn.io in 12 resource instances
ℹ Target: Stuck resources from namespace status

$ kfinalizer -n longhorn-system --force
ℹ Processing 1 instance(s) of backuptargets.longhorn.io
⚠ Failed to patch backuptarget.longhorn.io/default
ℹ Force deleting namespace 'longhorn-system'...
✓ Namespace force deleted

$ kubectl get ns
NAME              STATUS   AGE
longhorn-system   (deleted)
```

**Result**: Namespace deleted successfully after 21 days of being stuck! ✅

**Note**: v1.1 also detects built-in resources (e.g. `persistentvolumeclaims`) that carry finalizers like `kubernetes.io/pvc-protection` — these were silently missed in v1.0.

## Why Patches Might Fail

Common reasons patches fail:

1. **Missing webhooks**: Admission webhooks are configured but the webhook service is gone
   - **Solution**: Use `--force` flag
   
2. **Insufficient permissions**: Your user/role can't patch the resources
   - **Solution**: Check `kubectl auth can-i patch <resource>`
   
3. **API server issues**: Resource definitions are corrupted or unavailable
   - **Solution**: Use `--force` to bypass and delete namespace directly

4. **Hung webhooks**: An admission webhook is unreachable and the patch call hangs.
   - **Solution**: The tool now applies a 30-second timeout to every kubectl call by default. Raise it with `--timeout 120s` if your cluster is slow.

## Safety & Best Practices

### ⚠️ Important Warnings

- **Removing finalizers bypasses cleanup logic**: Resources may leave orphaned data
- **Always dry-run first**: Use `-d` to preview changes
- **Understand what finalizers do**: Know why they exist before removing them
- **Have backups**: Especially for storage operators like Longhorn

### ✅ Safe Usage

```bash
# 1. Always start with dry-run
kfinalizer -n my-namespace --dry-run -v

# 2. Review what will be changed
# Look at the "Stuck resources found" section

# 3. Apply changes
kfinalizer -n my-namespace -v

# 4. Use force only when needed
kfinalizer -n my-namespace --force
```

## Troubleshooting

### "Failed to patch" errors

This is normal when webhooks are missing. Use `--force`:
```bash
kfinalizer -n <namespace> --force
```

### Permission denied

Check your permissions:
```bash
kubectl auth can-i patch <resource-type> -n <namespace>
```

### Namespace still stuck after force delete

If `--force` reports resources that would be orphaned, strip their finalizers first with the supported path:

```bash
kfinalizer -n <namespace> --force --delete-orphans
```

This removes finalizers from stuck resources via the raw `/finalize` API (bypassing admission webhooks) before force-deleting the namespace.

If that still doesn't work, very rare, try manual cleanup:
```bash
kubectl get namespace <namespace> -o json | \
  jq '.spec.finalizers = []' | \
  kubectl replace --raw /api/v1/namespaces/<namespace>/finalize -f -
```

### Tool only checks configmaps, events, pods

You have an old version. Reinstall:
```bash
make install
```

The latest version only checks **stuck resources** (from namespace status), not all 150+ resource types.

## Requirements

- `kubectl` (configured and working)
- `jq` (required for finalizer filtering and force delete)
- Bash 4.0+
- Appropriate Kubernetes permissions

## Contributing

Contributions are welcome! 

- Report issues on GitHub
- Submit pull requests with improvements
- Share your use cases and feedback

## Credits

The initial v1.0 implementation was written by Claude (Anthropic AI Assistant) during a collaborative session to solve stuck Kubernetes namespaces.

The v1.1 release was designed, implemented, and reviewed by open-source AI models:
- **Orchestrator**: `glm-5.2` (opencode-go)
- **Coder**: `deepseek-v4-pro`
- **Reviewer**: `qwen3.7-max`

All work was coordinated through [opencode](https://opencode.ai) using the [superpowers](https://github.com/obra/superpowers) skill suite.

**Remember**: Use at your own risk. No warranties or guarantees provided.

---

**Quick Commands Reference:**

```bash
# Preview changes (server-side dry-run, exercises webhooks)
kfinalizer -n <namespace> --dry-run -v

# Remove finalizers
kfinalizer -n <namespace>

# Force delete (when webhooks are missing)
kfinalizer -n <namespace> --force

# Strip orphan finalizers via raw API, then force delete
kfinalizer -n <namespace> --force --delete-orphans

# Target a specific cluster
kfinalizer -n <namespace> -c prod-cluster

# Custom timeout for slow clusters
kfinalizer -n <namespace> --timeout 120s

# Help
kfinalizer --help
```
