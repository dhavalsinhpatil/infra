# ArgoCD

`appproject.yaml` and `application.yaml` wire ArgoCD to auto-deploy the
`charts/employee-management` Helm chart from this repo's `main` branch.

## Install ArgoCD (local kind cluster)

```bash
kubectl create namespace argocd
# Server-side apply is required — client-side apply on the
# applicationsets.argoproj.io CRD exceeds the 262144-byte annotation
# limit kubectl enforces for client-side apply.
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side --force-conflicts
kubectl wait --for=condition=available --timeout=180s deployment/argocd-server -n argocd
```

## Register the app

```bash
kubectl apply -f appproject.yaml
kubectl apply -f application.yaml
```

`syncPolicy.automated` has `selfHeal: true` and `prune: true` — ArgoCD
will revert manual `kubectl`/`helm` changes made directly against the
cluster and delete resources removed from the chart, on every poll (default
~3 min) or immediately via webhook if one is configured.

## Access the UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

Then open `https://localhost:8081`. Initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## Requirements

- **The source repo must be publicly reachable** (or ArgoCD needs a
  registered repository credential) — this app's `repoURL` points at
  `github.com/dhavalsinhpatil/infra`, which is public for exactly this
  reason. A private repo returns "authentication required: Repository
  not found" from the ArgoCD repo-server with no anonymous credential
  configured.
- The chart path (`charts/employee-management`) must exist on the
  `targetRevision` branch (`main`) — ArgoCD reads from Git, not from
  local uncommitted/unpushed changes.
