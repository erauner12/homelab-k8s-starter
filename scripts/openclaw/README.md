# OpenClaw Helpers

Focused helpers for OpenClaw operations in this starter repo.

## Scripts

- `scripts/openclaw/access.sh`
  - Prints OpenClaw URL and gateway token from Kubernetes.
  - Supports tokenized URL output with `--tokenized-url-only`.

- `scripts/openclaw/approve-latest-pairing.sh`
  - Approves the latest pending OpenClaw device pairing request.
  - Useful when UI shows `pairing required`.

## Examples

```bash
# URL only
./scripts/openclaw/access.sh --url-only

# Direct login URL with token fragment
./scripts/openclaw/access.sh --tokenized-url-only

# Approve newest pending device request
./scripts/openclaw/approve-latest-pairing.sh
```

By default these scripts auto-use:
`terraform/rackspace-spot/kubeconfig-starter-cloud.yaml`

You can override cluster target with:

```bash
KUBECONFIG=/path/to/kubeconfig ./scripts/openclaw/access.sh
# or
./scripts/openclaw/access.sh --context <context-name>
```
