# kfinalizer - Quick Reference

## Common Commands

```bash
# Basic cleanup (auto-discovers stuck resources from namespace status)
kfinalizer -n <namespace>

# Preview changes first (recommended — server-side dry-run)
kfinalizer -n <namespace> --dry-run -v

# Force delete stuck namespace
kfinalizer -n <namespace> --force

# Strip orphan finalizers via raw API before force delete
kfinalizer -n <namespace> --force --delete-orphans

# Target a specific cluster
kfinalizer -n <namespace> -c prod-cluster

# Custom timeout for slow clusters
kfinalizer -n <namespace> --timeout 120s

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
5. **Multi-cluster safety**: always pass `-c <context>` (or check the printed context line) to avoid hitting the wrong cluster.
6. **Slow clusters**: raise the per-request timeout with `--timeout 120s`.

## How It Works

1. Reads stuck resources from namespace status (or uses your `-r` list, or `--all` for everything)
2. Filters to instances that actually have finalizers (via jq)
3. Patches each by name to remove finalizers: `{"metadata":{"finalizers":null}}`
4. Optionally force-deletes the namespace (warns about orphans; `--delete-orphans` strips them first)

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
