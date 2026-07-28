# k8s

Kubernetes manifests for the Employee Management Portal, structured for
Kustomize (`base/`) so Helm/environment overlays can build on top later.

## Local cluster (kind)

```bash
kind create cluster --config kind-cluster.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=120s
```

`kind-cluster.yaml` is single control-plane, no worker node. This is
deliberate: the ingress-nginx kind manifest does not force scheduling
onto a specific node, so with a worker node present the controller can
land there while the `extraPortMappings` only forward from the
control-plane container — the Ingress silently returns nothing on the
mapped host port. Single-node avoids the whole class of bug.

## Build and load images

Kind runs its own containerd, separate from the host Docker image cache —
images built with `docker build` must be explicitly loaded in.

```bash
# from employee-management-api/
docker build -t employee-management-api:local .

# from employee-management-ui/ — VITE_API_BASE_URL must be a relative
# path since the browser reaches both UI and API through the same
# Ingress host
docker build -t employee-management-ui:local --build-arg VITE_API_BASE_URL=/api .

kind load docker-image employee-management-api:local employee-management-ui:local --name employee-management
```

## Deploy

```bash
kubectl apply -k base/
```

## Verify

```bash
kubectl get pods -n employee-management

curl -H "Host: employee-management.local" http://localhost:18080/
curl -H "Host: employee-management.local" http://localhost:18080/actuator/health
```

(`18080` is the host port mapped in `kind-cluster.yaml`, not 80 — chosen
to avoid colliding with the backend repo's `docker-compose.yml` which
already uses 8080.)

## Notes

- `postgres/secret.yaml` and `api/secret.yaml` contain literal dev-only
  placeholder credentials, clearly marked. Never reuse these values
  outside a local cluster — see the warning comment in each file.
- The HPA (`api/hpa.yaml`) requires the metrics-server addon to actually
  scale; kind does not ship one by default. Not yet installed here.
- Frontend image bakes `VITE_API_BASE_URL` in at build time (Vite env
  vars are compile-time). The Docker Compose setup uses an absolute
  `http://localhost:8080/api` because the browser talks to a different
  port than the Ingress; the Kubernetes image must use the relative
  `/api` path instead since both UI and API sit behind the same Ingress
  host. These are genuinely different images — don't reuse the Compose
  build for the k8s deploy.
