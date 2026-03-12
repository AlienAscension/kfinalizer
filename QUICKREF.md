# kfinalizer - Quick Reference

## Common Commands

```bash
# Basic cleanup (auto-discovers all resources)
kfinalizer -n <namespace>

# Preview changes first (recommended)
kfinalizer -n <namespace> --dry-run -v

# Force delete stuck namespace
kfinalizer -n <namespace> --force

# Target specific resources only
kfinalizer -n <namespace> -r <resource-type>
```

## Operator-Specific Examples

### Longhorn Storage
```bash
kfinalizer -n longhorn-system -v
# If stuck: kfinalizer -n longhorn-system -f
```

### OpenSearch
```bash
kfinalizer -n opensearch
```

### NATS
```bash
kfinalizer -n nats -r accounts.jetstream.nats.io -r streams.jetstream.nats.io
```

### Cert-Manager
```bash
kfinalizer -n cert-manager
```

### Argo CD
```bash
kfinalizer -n argocd -f
```

## Troubleshooting

### No output showing?
- Add `-v` flag for verbose output
- The tool now properly shows progress for each resource

### Namespace still stuck?
```bash
# 1. Try with force
kfinalizer -n <namespace> --force

# 2. Check what's remaining
kubectl describe ns <namespace>

# 3. Target specific resources that are stuck
kubectl get <resource-type> -n <namespace>
kfinalizer -n <namespace> -r <resource-type>
```

### "Cannot patch" errors?
```bash
# Check permissions
kubectl auth can-i patch <resource> -n <namespace>

# May need cluster-admin temporarily
```

## Tips

1. **Always dry-run first**: `--dry-run -v`
2. **Use verbose for debugging**: `-v`
3. **Force only when needed**: `-f`
4. **Target specific resources** if you know which are stuck

## How It Works

1. Discovers all namespaced resources (or uses your `-r` list)
2. Finds instances of each resource in the namespace
3. Patches each to remove finalizers: `{"metadata":{"finalizers":null}}`
4. Optionally force-deletes the namespace

## Safety Notes

⚠️ **Removing finalizers bypasses cleanup**
- Finalizers exist to ensure proper cleanup
- Only remove them if you understand the implications
- Resources may leave behind orphaned data

✅ **Safe practices**
- Use `--dry-run` first
- Use `-v` to see what's being changed
- Know what the finalizers do before removing
- Have backups if dealing with storage operators
