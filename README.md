# iac-validator

**What:** a policy-as-code gate for Terraform. Every pull request that touches
infrastructure is automatically checked twice — once by [Checkov](https://www.checkov.io/)
(industry-standard static analysis) and once by custom [OPA/Rego](https://www.openpolicyagent.org/)
policies evaluated with [conftest](https://www.conftest.dev/) against the real
`terraform plan` JSON. Non-compliant plans fail the build before they can merge.

**Why:** misconfigured cloud infrastructure — public storage buckets, unencrypted
data, SSH open to the world, untagged resources — is one of the top causes of
breaches and surprise cloud bills. Cloud consultancies sell exactly this:
preventing misconfigurations from ever reaching production. This project
demonstrates that skill end to end: Terraform, CI gating, and policy-as-code.

## Architecture

```
┌──────────────┐   git push / PR    ┌────────────────────────────┐
│  terraform/  │ ─────────────────▶ │  GitHub Actions            │
│  main.tf     │                    │  .github/workflows/        │
│  (S3, EC2,   │                    │  iac-validate.yml          │
│   SecGroup)  │                    │                            │
└──────────────┘                    │  1. terraform fmt -check   │
                                    │  2. terraform init/validate│
┌──────────────┐   plan.json        │  3. Checkov (fail HIGH+)   │   ┌──────────────┐
│  policies/   │ ◀───────────────── │  4. terraform plan ─┐      │   │  artifacts   │
│  s3.rego     │   conftest test    │  5. plan → JSON   │      │──▶│  plan.json   │
│  ec2.rego    │   denies fail      │  6. conftest test ◀─┘      │   │  checkov     │
│  tags.rego   │   the build        └────────────────────────────┘   │  .sarif      │
└──────────────┘                                                    └──────────────┘
```

Sample infra: one S3 bucket, one EC2 instance, one security group — with
**intentional misconfigurations** (marked `# INTENTIONAL` in `main.tf`) so the
policies have real violations to catch: a public-read bucket ACL, a bucket with
no server-side encryption, an untagged EC2 instance, and SSH open to `0.0.0.0/0`.

## Quickstart

Prerequisites: `terraform >= 1.5`. For the policy gates you need
[checkov](https://www.checkov.io/) (`pip install checkov`) and
[conftest](https://www.conftest.dev/install/) — or just `docker`, the script
falls back to container images automatically.

```bash
git clone <your-repo-url> iac-validator
cd iac-validator
./scripts/run-local.sh
```

**Expected result on weekend 1:** gates **FAIL** — that's the demo. You should
see 4 policy violations:

- `S3 bucket 'aws_s3_bucket.app_data' uses ACL 'public-read' — public bucket ACLs are denied`
- `S3 bucket 'aws_s3_bucket.app_data' has no server-side encryption configured — SSE is required`
- `Security group 'aws_security_group.app' allows port 22 from 0.0.0.0/0 — restrict SSH to known CIDRs`
- `aws_instance 'aws_instance.app' is missing required tag(s): Environment, Owner`

plus the matching Checkov HIGH/CRITICAL findings. No real AWS credentials are
used anywhere — the plan runs offline (`-refresh=false`) with dummy
placeholders. Nothing is ever applied to a real account.

## 2-weekend build roadmap

**Weekend 1 — red pipeline (this scaffold).**
- [x] Sample Terraform (S3 + EC2 + security group) with intentional misconfigs
- [x] Checkov gate in CI, failing on HIGH and above
- [x] Custom OPA/Rego policies (S3, EC2, tags) evaluated by conftest on plan JSON
- [x] Local runner script mirroring CI
- [ ] Push to GitHub, watch the workflow fail on the 4 violations, tune policy messages

**Weekend 2 — green pipeline + cost gate.**
- [ ] Fix the infra: private ACL + `aws_s3_bucket_public_access_block`, add
      `aws_s3_bucket_server_side_encryption_configuration`, tag the EC2 instance,
      restrict SSH ingress to a known CIDR — gates go green
- [ ] Add an [infracost](https://www.infracost.io/) step that comments the
      estimated monthly cost delta on every PR (cost-estimation gate)
- [ ] Add 3+ more policies: EBS encryption by default, S3 versioning enabled,
      deny hardcoded secrets in user-data, require IMDSv2 on EC2
- [ ] Convert the intentional misconfigs into a `examples/bad/` vs
      `examples/good/` pair to demo both outcomes in interviews

## Suggested resume bullets

- Built an IaC policy-as-code gate (Terraform + Checkov + OPA/Conftest) that
  blocks non-compliant AWS plans in CI — caught [N] misconfigurations
  (public S3 ACLs, unencrypted buckets, open SSH ingress) across [M] pull
  requests before merge.
- Enforced [N] custom Rego policies (mandatory SSE, Environment/Owner tag
  compliance, restricted SSH ingress) as required CI checks on Terraform plans,
  cutting manual infrastructure review time by [X]%.

---
*Independent side project — not affiliated with any employer. Built to
demonstrate cloud infrastructure testing and policy-as-code skills.*
