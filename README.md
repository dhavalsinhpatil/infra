# infra

Terraform for the Employee Management Portal's AWS infrastructure.

## Structure

```
bootstrap/         one-time setup: S3 state bucket + DynamoDB lock table
                    (run with local state, before anything else exists)
modules/
  vpc/              VPC, public/private subnets, IGW, optional NAT
  iam/              GitHub Actions OIDC role (CI push to ECR),
                    app runtime role (Secrets Manager read, CloudWatch logs)
  ecr/              container registries for the API and UI images
environments/
  dev/              root module wiring the above together for dev
  prod/             not yet built (see environments/prod/README.md)
```

More modules (S3/CloudFront for frontend hosting, Lambda, API Gateway,
SQS, SNS, Secrets Manager, CloudWatch dashboards/alarms) will be added as
later phases, once the app has a concrete need for each.

## First-time setup

1. **Bootstrap the state backend** (once per AWS account):
   ```bash
   cd bootstrap
   terraform init
   terraform apply -var="state_bucket_name=<globally-unique-name>"
   ```
   Note the `state_bucket_name` output.

2. **Point the environment at that backend** — edit
   `environments/dev/backend.tf`, replace `REPLACE_WITH_STATE_BUCKET_NAME`
   with the bucket name from step 1.

3. **Deploy the environment**:
   ```bash
   cd environments/dev
   terraform init
   terraform plan
   terraform apply
   ```

## AWS Free Tier notes

- NAT Gateway is disabled by default (`enable_nat_gateway = false` in
  `environments/dev/main.tf`) — it is **not** Free Tier eligible
  (~$32/month plus data processing charges). Private subnets exist for
  workloads that don't need outbound internet; add VPC endpoints instead
  of NAT where AWS service access is needed.
- ECR: no charge for the first 500MB-month of storage; lifecycle policy
  caps retained images per repo to control storage cost beyond that.
- See the main project's monitoring/deployment docs for a full
  Free-Tier-vs-cost breakdown per AWS service as later phases add them
  (e.g. EKS is explicitly out of Free Tier — kind/Minikube is the local
  alternative used for the Kubernetes phase of this project).

## Conventions

- Every root module (`environments/*`) has its own remote state key —
  never share state between environments.
- Modules take a `name_prefix` and `tags` variable for consistent naming;
  don't hardcode resource names inside modules.
- `.terraform.lock.hcl` is committed (pins provider versions); `.tfstate`,
  `.tfvars`, and `.terraform/` are not.
