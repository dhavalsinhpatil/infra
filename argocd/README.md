# ArgoCD

`appproject.yaml` scopes what this repo's Applications may touch.
`application-dev.yaml` and `application-prod.yaml` both deploy the same
`charts/employee-management` Helm chart from this repo's `main` branch,
to two different namespaces (`employee-management-dev` /
`employee-management-prod`) on the **same** EKS cluster — see
`infra/modules/eks` and `environments/dev` for why there's one cluster,
not two (cost: a second EKS control plane is another ~$0.10/hr
indefinitely, not a one-time charge).

## Install ArgoCD

```bash
kubectl create namespace argocd
# Server-side apply is required — client-side apply on the
# applicationsets.argoproj.io CRD exceeds the 262144-byte annotation
# limit kubectl enforces for client-side apply.
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side --force-conflicts
kubectl wait --for=condition=available --timeout=180s deployment/argocd-server -n argocd
```

## Register the apps

```bash
kubectl apply -f appproject.yaml
kubectl apply -f application-dev.yaml
kubectl apply -f application-prod.yaml
```

`syncPolicy.automated` has `selfHeal: true` and `prune: true` on both —
ArgoCD reverts manual `kubectl`/`helm` changes made directly against the
cluster and deletes resources removed from the chart, on every poll
(default ~3 min) or immediately via webhook if one is configured. Fully
automated sync on prod (no manual approval gate) matches what the
original project spec asked for; a more conservative real-world setup
would often leave prod on manual sync (`syncPolicy.automated` omitted,
approve each deploy in the UI/CLI) — worth calling out as a deliberate
tradeoff if this comes up in an interview.

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
- `values-dev.yaml` and `values-prod.yaml` both have `REPLACE_WITH_ECR_URL`
  placeholders for the image repository — these need the real ECR
  registry URL (from `environments/dev` Terraform output
  `ecr_repository_urls`) once images are actually pushed there, and
  `image.tag` needs to move off `latest` to a real immutable tag (git SHA
  or similar) once CI/CD is wired up.
- `values-prod.yaml` does **not** override `api.secrets` / `postgres.secrets`
  — it inherits the dev-only placeholders from `values.yaml`. Do not
  treat `application-prod.yaml` as safe to sync against a real prod
  workload until real secrets are wired through Secrets Manager or
  External Secrets Operator.
