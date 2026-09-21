# iac-validator

A policy-as-code gate for Terraform. Every pull request that touches
infrastructure gets checked twice — once by
[Checkov](https://www.checkov.io/) (static analysis) and once by custom
[OPA/Rego](https://www.openpolicyagent.org/) policies evaluated with
[conftest](https://www.conftest.dev/) against the real `terraform plan`
JSON. Non-compliant plans fail the build before they can merge.

The motivation is pretty simple: misconfigured cloud infrastructure —
public storage buckets, unencrypted data, SSH open to the world, untagged
resources — is one of the top causes of breaches and surprise cloud bills.
Catching that stuff in CI instead of in an incident review is the whole
point.

## How it's wired

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

The sample infra (`terraform/`) is one S3 bucket, one EC2 instance, one
security group — written to **pass** every gate: private bucket with SSE and
a public-access block, SSH restricted to a known admin CIDR, all resources
tagged with `Environment` and `Owner`.

To prove the gates actually bite, there's an intentionally misconfigured
copy at `examples/bad/` (public-read bucket ACL, no server-side encryption,
untagged EC2, SSH open to `0.0.0.0/0`). CI plans it and asserts it gets
**rejected** — a negative test, so a policy that silently stops working
gets caught too.

## Quickstart

You need `terraform >= 1.5`. For the policy gates you need
[checkov](https://www.checkov.io/) (`pip install checkov`) and
[conftest](https://www.conftest.dev/install/) — or just `docker`, because
the script falls back to container images automatically.

```bash
git clone <your-repo-url> iac-validator
cd iac-validator
./scripts/run-local.sh
```

**Expected result:** the gates **pass** on `terraform/`, and the
negative-test step confirms `examples/bad/` is **rejected** with 4 policy
violations:

- `S3 bucket 'aws_s3_bucket.app_data' uses ACL 'public-read' — public bucket ACLs are denied`
- `S3 bucket 'aws_s3_bucket.app_data' has no server-side encryption configured — SSE is required`
- `Security group 'aws_security_group.app' allows port 22 from 0.0.0.0/0 — restrict SSH to known CIDRs`
- `aws_instance 'aws_instance.app' is missing required tag(s): Environment, Owner`

No real AWS credentials are used anywhere — the plan runs offline
(`-refresh=false`) with dummy placeholders. Nothing ever touches a real
account.

## Notes

- The negative test is the part I'm most glad I added. When I first set this
  up, the sample infra intentionally violated its own policies, which meant
  the "green pipeline" story was nonsense — CI could never actually pass.
  Splitting good infra (`terraform/`) from known-bad infra (`examples/bad/`)
  fixed that, and the negative test guards the guards.
- `admin_cidr` defaults to `203.0.113.10/32` (documentation range), so
  nothing real is exposed by default. Override it with
  `-var="admin_cidr=<your-ip>/32"` for your own use.
- Rego policies live in `policies/`: `s3.rego` (no public ACLs, SSE
  required), `ec2.rego` (no open SSH), `tags.rego` (Environment + Owner
  required). Four deny rules total.

## Where I'd take this next

- [ ] Add an [infracost](https://www.infracost.io/) step that comments the
      estimated monthly cost delta on every PR.
- [ ] More policies: EBS encryption by default, S3 versioning enabled, deny
      hardcoded secrets in user-data, require IMDSv2 on EC2.
- [ ] A second example environment (e.g. a "staging" variant) to show the
      gates working across multiple configs.

## If you're reading this on my resume

Built an IaC policy-as-code gate (Terraform + Checkov + OPA/Conftest) that
blocks non-compliant AWS plans in CI. The sample infrastructure passes all
gates; a deliberately misconfigured example is asserted to be rejected by 4
custom Rego policies (SSE required, no public S3 ACLs, restricted SSH
ingress, mandatory Environment/Owner tags) — a negative test that catches
policies silently breaking.

---
*Independent side project, not affiliated with any employer.*
