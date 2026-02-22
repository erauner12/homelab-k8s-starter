# OpenClaw Helpers

Focused helpers for OpenClaw operations in this starter repo.

## Scripts

- `openclaw/scripts/access.sh`
  - Prints OpenClaw URL and gateway token from Kubernetes.
  - Supports tokenized URL output with `--tokenized-url-only`.

- `openclaw/scripts/approve-latest-pairing.sh`
  - Approves the latest pending OpenClaw device pairing request.
  - Useful when UI shows `pairing required`.

## Examples

```bash
# URL only
./openclaw/scripts/access.sh --url-only

# Direct login URL with token fragment
./openclaw/scripts/access.sh --tokenized-url-only

# Approve newest pending device request
./openclaw/scripts/approve-latest-pairing.sh
```

By default these scripts auto-use:
`terraform/rackspace-spot/kubeconfig-starter-cloud.yaml`

You can override cluster target with:

```bash
KUBECONFIG=/path/to/kubeconfig ./openclaw/scripts/access.sh
# or
./openclaw/scripts/access.sh --context <context-name>
```
