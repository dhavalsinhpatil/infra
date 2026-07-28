# Interview Guide — Terraform / EKS / Helm / ArgoCD
**Environment:** AWS account 452383571229, region us-east-1, cluster `empmgmt-dev-eks`

Scope note: this guide only covers what is genuinely built and running in this
account right now — Terraform modules, remote state, EKS, Helm, and a basic
single-cluster ArgoCD setup. It does NOT cover ApplicationSets, Secrets Manager,
SAST/DAST, Lambda, API Gateway, or the rest of the candidate's claimed matrix —
those need to be asked about verbally, this environment gives you nothing to
point at for them.

---

## 1. Terraform — Remote State & Locking

**Where to look:** AWS Console → S3 → bucket `employee-mgmt-tfstate-452383571229`.
Also DynamoDB → table `employee-management-terraform-locks` (though note: newer
Terraform versions prefer S3-native locking over DynamoDB — see below).

**Ask:** *"Here's our state bucket. If two people ran `terraform apply` on this
at the same second, what stops them from corrupting state? Walk me through it."*

**What a real answer sounds like:** State locking — Terraform acquires a lock
(traditionally via a DynamoDB table using conditional writes on a `LockID` key,
or now via S3's native object-lock/conditional-write locking in newer Terraform
versions) before any write, and the second `apply` blocks or errors out until
the first releases it. They should mention `terraform force-unlock` as the
escape hatch when a lock gets stuck (e.g., after a killed process), and that
using it carelessly can cause real corruption.

**Red flag:** if they don't know the difference between state *storage* (S3)
and state *locking* (separate mechanism), or think Terraform "just handles
concurrency" with no idea how.

**Follow-up we can actually back up ourselves:** *"We had a bootstrapping
problem — the S3 bucket that holds state doesn't exist yet before the first
apply. How would you solve that?"* Our answer: a separate `bootstrap/` root
module using local state (not remote) to create the bucket + lock table once,
then every other environment points its backend at that bucket. If they don't
land on "you need a chicken-and-egg workaround," that's a real gap — this
is a genuinely common real-world problem, not a trick question.

---

## 2. Terraform — Modules & Provider Versions

**Where to look:** Any file in `infra/modules/vpc`, `modules/eks`, or just
describe the setup verbally — no console step needed here.

**Ask:** *"You pin a provider version like `~> 5.0` in a module. Six months
later `terraform init` starts failing, or worse, silently installs something
you didn't expect. What happened, and how do you prevent it?"*

**What happened to us, for real:** we pinned `~> 5.0` for the AWS provider
from memory/documentation, but by the time we ran `terraform init`, AWS's
provider had moved to major version 6.x — `5.0` was no longer the latest in
that line and irrelevant to what's actually shipped. A real answer should
mention: `.terraform.lock.hcl` (committed to git) is what actually pins exact
versions across a team, not just the `~>` constraint in code; check the
Terraform Registry before assuming a version range is current; a major version
bump can carry breaking changes (they should know AWS provider 5→6 had
scheme/attribute renames in places).

**Red flag:** if they say "I just always use the latest" with no lock-file
discipline, or don't know `.terraform.lock.hcl` should be committed.

---

## 3. EKS — Networking

**Where to look:** AWS Console → VPC → your VPCs → `empmgmt-dev-vpc`.
Then Subnets — show them 2 public + 2 private subnets. Then point out: **no
NAT Gateway exists** (check VPC → NAT Gateways, it'll be empty).

**Ask:** *"Our EKS worker nodes are sitting in the public subnets, not the
private ones. Why might we have done that, and what's the tradeoff?"*

**What a real answer sounds like:** Private subnets need a NAT Gateway (or
NAT instance) to reach the internet for image pulls / EKS API calls — without
one, a private-subnet node is unreachable and won't even join the cluster.
NAT Gateway costs ~$0.045/hr plus data processing charges — real money,
running continuously. Putting nodes in public subnets with public IPs avoids
that cost but is a real security tradeoff (a misconfigured security group is
more exposed). A senior person should be able to articulate *both* sides
without you prompting — cost vs. security posture — and mention that
Security Groups are still the actual enforcement layer either way, a public
IP alone doesn't mean "open."

**Red flag:** if they assume private-subnet-always is correct with no
awareness of the NAT cost tradeoff, or don't know why a private-subnet node
would fail to join a cluster in the first place.

---

## 4. EKS — Storage / CSI Drivers

**Where to look:** `kubectl get storageclass` — show `gp2 (default)`.
Then: `kubectl get pods -n kube-system | grep ebs` — show the EBS CSI
controller pods running.

**Ask:** *"We deployed a StatefulSet with a PersistentVolumeClaim onto a
fresh EKS cluster, and the pod sat in `Pending` forever. What's the most
likely cause, and how would you debug it?"*

**What happened to us, for real:** exactly this. EKS does **not** ship the
EBS CSI driver by default — a fresh cluster has no way to actually provision
an EBS volume for a PVC, even though a `gp2` StorageClass exists (leftover
from the older in-tree provisioner, which is deprecated). A real answer:
`kubectl describe pvc <name>` to see the event ("no persistent volumes
available... no storage class is set" or similar), realize the CSI driver
addon isn't installed, install `aws-ebs-csi-driver` as an EKS addon — which
itself requires an IAM role trusted via the cluster's OIDC provider (IRSA).

**Red flag:** if they don't know to start with `kubectl describe pvc` /
`kubectl get events`, or have never heard of IRSA (IAM Roles for Service
Accounts) and can't explain why a pod needs a role tied to a Kubernetes
service account rather than just using the node's own IAM role.

**Bonus real detail:** we also had to manually patch `gp2` to be the default
StorageClass (`storageclass.kubernetes.io/is-default-class: "true"`) — ask
if they know that annotation exists and why a StorageClass needs it at all
if there's only one.

---

## 5. EKS — Container Architecture Mismatch

**Where to look:** no console needed — describe the scenario.

**Ask:** *"You build a Docker image on your MacBook, push it to ECR, deploy
it to EKS, and the pod immediately crashes or won't schedule. The image built
fine locally. What's your first suspicion?"*

**What happened to us, for real:** Apple Silicon Macs build `arm64` images
by default. EKS worker nodes (standard `t3` instance types) are `amd64`. The
image either fails to schedule at all, or crash-loops with an exec format
error. Real fix: `docker buildx build --platform linux/amd64 ...` explicitly.
A real answer should get to "CPU architecture mismatch" within one or two
follow-up questions, ideally naming `buildx` or multi-arch builds by name.

**Red flag:** if they've never heard of this — it's an extremely common
real-world gotcha for anyone who's actually built and pushed images from an
Apple Silicon machine to a cloud amd64 cluster in the last few years.

---

## 6. Helm

**Where to look:** show them `charts/employee-management/values.yaml`,
`values-dev.yaml`. Point out the base + overlay pattern.

**Ask:** *"We have one chart, one `values.yaml`, and separate
`values-dev.yaml` / `values-prod.yaml` files layered on top. Why not just
duplicate the whole chart per environment?"*

**What a real answer sounds like:** DRY — one source of truth for the
resource templates (Deployments, Services, etc.), environment differences
are *only* the values that actually differ (replica count, image tag,
ingress host, resource limits). Duplicating the whole chart means every
template change has to be made N times and drifts over time. They should
also be able to explain `helm upgrade`, and ideally mention `helm rollback`
and what actually happens under the hood (Helm keeps release history/revisions
in the cluster as Secrets by default).

**Follow-up:** *"If `helm upgrade` only changes a few resources, does it
touch the ones that didn't change?"* Real answer: no — Helm diffs and only
applies what changed, though naive users sometimes assume `upgrade` wipes
and recreates everything.

---

## 7. ArgoCD — Basics (this environment is single-cluster; be honest about that scope)

**Where to look:** ArgoCD UI (port-forward to `localhost:18081`, or however
you're accessing it that day) — show the `employee-management-dev`
Application, its sync status, health status, resource tree.

**Ask:** *"Sync policy here has `selfHeal: true` and `prune: true`. Show me:
if I `kubectl scale` this Deployment up manually right now, what happens?"*
(Actually do it live if the cluster's still up — it's a great live
demonstration, we proved this ourselves: manual replica change gets reverted
within seconds.)

**What a real answer sounds like:** ArgoCD continuously compares live cluster
state to the Git-declared desired state. `selfHeal: true` means any drift
(including a competent engineer manually "fixing" something under pressure)
gets reverted automatically — which is a feature until it isn't, e.g. during
an active incident where someone needs to hotfix something in the cluster
directly. `prune: true` means resources removed from the Helm chart in Git
get deleted from the cluster automatically too — dangerous if someone removes
a resource from a values file by mistake.

**Real, harder follow-up (their claimed skill, not something we built —
ask verbally):** *"Would you run `selfHeal: true` on production, unconditionally?
Why or why not?"* A senior answer should raise: incident response friction
(you can't quickly patch prod without it fighting you), and that many real
orgs deliberately leave prod on manual sync with an approval gate instead of
full automation — the "right" answer isn't a flat yes, it's a tradeoff
discussion. If they answer with unconditional enthusiasm and no caveats,
that's a flag for someone who's used ArgoCD's happy path but not lived through
an incident with it.

**Honest gap to disclose to the candidate:** this environment does not have
ApplicationSets, Git Generator, or Matrix Generator configured — if their
claimed strength is there, this environment won't let you verify it visually.
Ask them to whiteboard or verbally walk through: *"Explain when you'd reach
for an ApplicationSet with a Git Generator vs. just hand-writing multiple
Application manifests like we did here."* Real answer: Git Generator dynamically
creates an Application per directory/file matching a path pattern in a repo —
useful when you have many similar apps/environments and don't want to hand-
maintain an Application YAML per one (which is exactly what we did manually
here, for only 2 environments — a real "at scale" answer should recognize
that hand-writing doesn't scale past a handful).

---

## Suggested flow for the call

1. Open AWS Console, VPC page — quick tour, ask Q3 (networking tradeoff)
2. `kubectl get storageclass` + `kubectl get pods -n kube-system` — ask Q4 (CSI)
3. Ask Q5 (arch mismatch) verbally, no need to reproduce it live
4. Show `values.yaml` / `values-dev.yaml` in an editor — ask Q6 (Helm)
5. Open ArgoCD UI, do the live `kubectl scale` self-heal demo — ask Q7
6. Close with the verbal-only ApplicationSet question, and be upfront that
   the rest of their matrix (Secrets Manager, SAST/DAST, Lambda, etc.) isn't
   covered by this environment and needs a separate conversation
