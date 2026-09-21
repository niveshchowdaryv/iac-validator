#!/usr/bin/env bash
# Local runner for the iac-validator policy gates.
# Mirrors .github/workflows/iac-validate.yml. No real AWS credentials are needed:
# the plan runs offline (-refresh=false) with dummy placeholder credentials.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/terraform"

FAILURES=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILURES=$((FAILURES + 1)); }
skip() { echo "SKIP: $1"; }
have() { command -v "$1" >/dev/null 2>&1; }

echo "### 1. terraform fmt"
terraform fmt -check -recursive . && pass "terraform fmt" || fail "terraform fmt"

echo "### 2. terraform init + validate"
terraform init -backend=false -input=false >/dev/null \
  && terraform validate && pass "terraform validate" || fail "terraform validate"

echo "### 3. Checkov (fail on HIGH and CRITICAL)"
if have checkov; then
  checkov -d . --framework terraform --check HIGH,CRITICAL --compact \
    && pass "checkov" || fail "checkov"
elif have docker; then
  docker run --rm -v "$PWD:/tf" bridgecrew/checkov:latest \
    -d /tf --framework terraform --check HIGH,CRITICAL --compact \
    && pass "checkov (docker)" || fail "checkov (docker)"
else
  skip "checkov — install with 'pip install checkov' or install docker"
fi

echo "### 4. terraform plan (offline, -refresh=false)"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-dummy}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-dummy}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
if terraform plan -refresh=false -input=false -out=plan.out >/dev/null \
  && terraform show -json plan.out >plan.json; then
  pass "terraform plan"
else
  fail "terraform plan"
fi

echo "### 5. Conftest (OPA/Rego policies)"
if [ -f plan.json ] && have conftest; then
  conftest test plan.json --policy ../policies \
    && pass "conftest" || fail "conftest"
elif [ -f plan.json ] && have docker; then
  docker run --rm -v "$PWD:/work" -v "$ROOT/policies:/policies" \
    openpolicyagent/conftest:latest test /work/plan.json --policy /policies \
    && pass "conftest (docker)" || fail "conftest (docker)"
elif [ -f plan.json ]; then
  skip "conftest — install from https://www.conftest.dev/install/ or install docker (plan.json kept at terraform/plan.json)"
fi

echo "### 6. Conftest negative test (examples/bad must be rejected)"
if [ -f plan.json ] && have conftest; then
  cd "$ROOT/examples/bad"
  terraform init -backend=false -input=false >/dev/null \
    && terraform plan -refresh=false -input=false -out=plan.out >/dev/null \
    && terraform show -json plan.out >plan.json \
    && ! conftest test plan.json --policy ../../policies >/dev/null \
    && pass "conftest rejects examples/bad" || fail "conftest negative test"
elif have docker; then
  skip "conftest negative test — install conftest for the full local run"
else
  skip "conftest negative test — install from https://www.conftest.dev/install/ or install docker"
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "Result: $FAILURES gate(s) FAILED."
  exit 1
fi
echo "Result: all gates passed."
