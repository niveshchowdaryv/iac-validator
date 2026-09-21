# examples/bad

Intentionally **non-compliant** Terraform config — the negative test for the
policy gates. CI plans this directory and asserts that `conftest` **fails** on
it, proving the policies actually catch violations:

- S3 bucket with a `public-read` ACL
- S3 bucket with no server-side encryption
- Security group allowing SSH (`22`) from `0.0.0.0/0`
- EC2 instance missing the required `Environment`/`Owner` tags

Expected conftest result: **4 denials** (see the expected-result list in the
top-level README). Never point this at a real account — it exists only to be
rejected by the gate.
