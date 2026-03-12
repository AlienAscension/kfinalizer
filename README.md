# kfinalizer

A CLI tool to remove Kubernetes finalizers and force delete stuck namespaces.

> ⚠️ **Disclaimer**: This tool was 100% written by Claude (Anthropic's AI assistant). It comes with **NO WARRANTIES** or **GUARANTEES**. Use at your own risk. The authors are not responsible for any damage, data loss, or cluster issues that may result from using this tool.

## What It Does

`kfinalizer` helps you clean up stuck Kubernetes namespaces that won't delete due to finalizers. It:

-  **Detects** stuck resources in terminating namespaces
-  **Targets** only the resources that are actually stuck (not all 150+ Kubernetes resource types)
-  **Removes finalizers** from custom resources that are blocking namespace deletion
-  **Force deletes** namespaces when resources can't be patched (e.g., due to missing webhooks)
-  **Dry-run mode** lets you preview changes before applying them

## How It Works

1. **Reads namespace status** to identify which resources are stuck (from `NamespaceContentRemaining` condition)
2. **Patches each resource** to remove finalizers: `kubectl patch <resource> -p '{"metadata":{"finalizers":null}}'`
3. **Falls back to force delete** if patching fails (removes namespace finalizer directly via API)

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

#### Stuck OpenSearch namespace

```bash
kfinalizer -n opensearch --force
```

#### Stuck NATS namespace

```bash
kfinalizer -n nats -v
```

#### Target specific resources only

```bash
kfinalizer -n my-namespace \
  -r mycustomresource.example.com \
  -r anothercr.example.com
```

## Command-Line Options

```
OPTIONS:
    -n, --namespace <n>      Namespace to clean (required)
    -r, --resource <type>    Specific resource type (can be used multiple times)
    -a, --all                Process ALL resources (default: stuck resources only)
    -d, --dry-run            Preview changes without applying them
    -f, --force              Force delete namespace after removing finalizers
    -v, --verbose            Show detailed output
    -h, --help               Show help message
    -V, --version            Show version
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

## Why Patches Might Fail

Common reasons patches fail:

1. **Missing webhooks**: Admission webhooks are configured but the webhook service is gone
   - **Solution**: Use `--force` flag
   
2. **Insufficient permissions**: Your user/role can't patch the resources
   - **Solution**: Check `kubectl auth can-i patch <resource>`
   
3. **API server issues**: Resource definitions are corrupted or unavailable
   - **Solution**: Use `--force` to bypass and delete namespace directly

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

Very rare, but try manual cleanup:
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
- `jq` (for force delete functionality)
- Bash 4.0+
- Appropriate Kubernetes permissions

## Contributing

This tool was written by Claude, but contributions are welcome! 

- Report issues on GitHub
- Submit pull requests with improvements
- Share your use cases and feedback

## License

MIT License - See LICENSE file for details

## Credits

100% written by Claude (Anthropic AI Assistant) during a collaborative session to solve stuck Kubernetes namespaces.

**Remember**: Use at your own risk. No warranties or guarantees provided.

---

**Quick Commands Reference:**

```bash
# Preview changes
kfinalizer -n <namespace> --dry-run -v

# Remove finalizers
kfinalizer -n <namespace>

# Force delete (when webhooks are missing)
kfinalizer -n <namespace> --force

# Help
kfinalizer --help
```
