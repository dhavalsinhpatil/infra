# employee-management Helm chart

Umbrella chart for the whole portal: Postgres (StatefulSet), API
(Deployment + HPA), UI (Deployment), Services, and Ingress.

## Install

```bash
helm install employee-management . -n employee-management --create-namespace
```

(Note: `namespace.yaml` is templated in this chart, so `--create-namespace`
is only needed if you also override `namespace` in values and expect Helm
to manage the target namespace metadata separately — the chart's own
Namespace object works standalone against the default install target.)

## Upgrade

```bash
helm upgrade employee-management . --set api.replicaCount=3
```

## Rollback

```bash
helm rollback employee-management <revision>
```

## Values

See `values.yaml` for the full list. Key ones:

| Key | Default | Notes |
|---|---|---|
| `api.image.tag` | `local` | Set to the real ECR tag for anything beyond kind |
| `ui.image.tag` | `local` | Same |
| `api.autoscaling.enabled` | `true` | Requires metrics-server in-cluster to actually scale |
| `ingress.host` | `employee-management.local` | Add to `/etc/hosts` pointing at the cluster, or pass `Host:` header for testing |
| `*.secrets.*` | dev-only placeholders | Never reuse outside a local cluster — see inline comments in `values.yaml` |

## Verified

Installed, upgraded (`replicaCount` override), and rolled back against a
local kind cluster — full login flow confirmed working through the
Ingress after install.
