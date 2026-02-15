#!/usr/bin/env bash
# =============================================================================
# MeetMind — Terraform Quality Gate
# Strict rules for IaC (mirrors CRIS_DEVELOPMENT_STANDARDS.md IaC section)
#
# Gates:
#   1. terraform fmt     — Canonical formatting
#   2. terraform validate — Syntax & type checking
#   3. tflint            — Best practices & AWS provider rules
#   4. trivy config      — Security misconfigurations (CRITICAL/HIGH)
#   5. checkov           — CIS benchmarks & compliance
#   6. Naming convention — Project prefix enforcement
#   7. Sensitive vars    — Secrets marked as sensitive
#   8. Tags              — Required tags on all resources
# =============================================================================
set -euo pipefail

# --- Config ---
INFRA_DIR="${1:-infra}"
PASS=0
FAIL=0
WARN=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

gate_pass() { ((PASS++)); echo -e "${GREEN}  ✅ PASS${NC} — $1"; }
gate_fail() { ((FAIL++)); echo -e "${RED}  ❌ FAIL${NC} — $1"; }
gate_warn() { ((WARN++)); echo -e "${YELLOW}  ⚠️  WARN${NC} — $1"; }
gate_skip() { echo -e "${BLUE}  ⏭️  SKIP${NC} — $1 (not installed)"; }

echo ""
echo "═══════════════════════════════════════════════════"
echo "  🏗️  MeetMind Terraform Quality Gate"
echo "  Directory: ${INFRA_DIR}"
echo "═══════════════════════════════════════════════════"
echo ""

# --- Gate 1: terraform fmt ---
echo -e "${BLUE}[1/8] Formatting (terraform fmt)${NC}"
if terraform -chdir="${INFRA_DIR}" fmt -check -recursive > /dev/null 2>&1; then
  gate_pass "All .tf files properly formatted"
else
  gate_fail "Files not formatted. Run: terraform -chdir=${INFRA_DIR} fmt -recursive"
fi

# --- Gate 2: terraform validate ---
echo -e "${BLUE}[2/8] Validation (terraform validate)${NC}"
# Init if needed (backend=false to skip S3)
if [ ! -d "${INFRA_DIR}/.terraform" ]; then
  terraform -chdir="${INFRA_DIR}" init -backend=false -input=false > /dev/null 2>&1
fi
VALIDATE_OUTPUT=$(terraform -chdir="${INFRA_DIR}" validate 2>&1)
if echo "${VALIDATE_OUTPUT}" | grep -q "Success"; then
  gate_pass "Configuration is valid"
else
  gate_fail "Validation errors: ${VALIDATE_OUTPUT}"
fi

# --- Gate 3: tflint ---
echo -e "${BLUE}[3/8] Linting (tflint)${NC}"
if command -v tflint > /dev/null 2>&1; then
  TFLINT_OUTPUT=$(cd "${INFRA_DIR}" && tflint --format compact 2>&1) || true
  if [ -z "${TFLINT_OUTPUT}" ]; then
    gate_pass "No linting issues"
  else
    ISSUE_COUNT=$(echo "${TFLINT_OUTPUT}" | wc -l | tr -d ' ')
    if echo "${TFLINT_OUTPUT}" | grep -qi "error"; then
      gate_fail "tflint found errors (${ISSUE_COUNT} issues)"
      echo "${TFLINT_OUTPUT}" | head -10
    else
      gate_warn "tflint found ${ISSUE_COUNT} warnings"
      echo "${TFLINT_OUTPUT}" | head -5
    fi
  fi
else
  gate_skip "tflint — install: brew install tflint"
fi

# --- Gate 4: trivy config scan ---
echo -e "${BLUE}[4/8] Security scan (trivy config)${NC}"
if command -v trivy > /dev/null 2>&1; then
  TRIVY_OUTPUT=$(trivy config "${INFRA_DIR}" --severity CRITICAL,HIGH --exit-code 0 --format table 2>&1) || true
  # Count unique finding IDs (e.g. AWS-0028, AWS-0104)
  ALL_IDS=$(echo "${TRIVY_OUTPUT}" | grep -oE 'AWS-[0-9]+' | sort -u)
  # Accepted risks (document in comments):
  # - AWS-0104: egress to 0.0.0.0/0 on specific ports (443/80/53) — required for OpenAI API, ECR, SSM
  UNACCEPTED_IDS=$(echo "${ALL_IDS}" | grep -v 'AWS-0104' | grep -v '^$' || true)
  ACCEPTED_COUNT=$(echo "${ALL_IDS}" | grep -c 'AWS-0104' 2>/dev/null || true)
  ACCEPTED_COUNT=$(echo "${ACCEPTED_COUNT}" | tr -d '[:space:]')
  ACCEPTED_COUNT=${ACCEPTED_COUNT:-0}

  if [ -z "${UNACCEPTED_IDS}" ]; then
    if [ "${ACCEPTED_COUNT}" -gt 0 ] 2>/dev/null; then
      gate_warn "Accepted risks: AWS-0104 (port-restricted egress to 0.0.0.0/0)"
    else
      gate_pass "No CRITICAL/HIGH security issues"
    fi
  else
    UNACCEPTED_COUNT=$(echo "${UNACCEPTED_IDS}" | wc -l | tr -d ' ')
    gate_fail "Found ${UNACCEPTED_COUNT} unaccepted security findings: ${UNACCEPTED_IDS}"
    echo "${TRIVY_OUTPUT}" | grep -A2 "$(echo "${UNACCEPTED_IDS}" | head -5 | tr '\n' '|' | sed 's/|$//')" | head -15
  fi
else
  gate_skip "trivy — install: brew install trivy"
fi

# --- Gate 5: checkov ---
echo -e "${BLUE}[5/8] Compliance scan (checkov)${NC}"
if command -v checkov > /dev/null 2>&1; then
  CHECKOV_OUTPUT=$(checkov -d "${INFRA_DIR}" --quiet --compact --framework terraform 2>&1) || true
  FAILED_CHECKS=$(echo "${CHECKOV_OUTPUT}" | grep -c "FAILED" 2>/dev/null || echo 0)
  PASSED_CHECKS=$(echo "${CHECKOV_OUTPUT}" | grep -c "PASSED" 2>/dev/null || echo 0)
  if [ "${FAILED_CHECKS}" -eq 0 ]; then
    gate_pass "All compliance checks passed (${PASSED_CHECKS} checks)"
  else
    gate_warn "checkov: ${FAILED_CHECKS} failed, ${PASSED_CHECKS} passed"
    echo "${CHECKOV_OUTPUT}" | grep "FAILED" | head -10
  fi
else
  gate_skip "checkov — install: pip install checkov"
fi

# --- Gate 6: Naming conventions ---
echo -e "${BLUE}[6/8] Naming conventions${NC}"
# All resources should use var.project_name prefix
RESOURCES_WITHOUT_PREFIX=$(grep -rn 'resource "aws_' "${INFRA_DIR}"/*.tf 2>/dev/null | \
  grep -v 'var.project_name' | \
  grep -v '#' | \
  grep -c 'name' 2>/dev/null || true)
RESOURCES_WITHOUT_PREFIX=${RESOURCES_WITHOUT_PREFIX:-0}
RESOURCES_WITHOUT_PREFIX=$(echo "${RESOURCES_WITHOUT_PREFIX}" | tr -d '[:space:]')
if [ "${RESOURCES_WITHOUT_PREFIX}" -eq 0 ] 2>/dev/null; then
  gate_pass "All resources use var.project_name prefix"
else
  gate_warn "${RESOURCES_WITHOUT_PREFIX} resources may not follow naming convention"
fi

# --- Gate 7: Sensitive variables ---
echo -e "${BLUE}[7/8] Sensitive variables${NC}"
# Check that secret-related variables are marked sensitive
SECRETS_CHECK=0
for SECRET_NAME in "api_key" "token" "password" "secret"; do
  TOTAL=$(grep -c "variable.*${SECRET_NAME}" "${INFRA_DIR}"/variables.tf 2>/dev/null || true)
  TOTAL=$(echo "${TOTAL}" | tr -d '[:space:]')
  TOTAL=${TOTAL:-0}
  if [ "${TOTAL}" -gt 0 ] 2>/dev/null; then
    MARKED=$(grep -A5 "variable.*${SECRET_NAME}" "${INFRA_DIR}"/variables.tf 2>/dev/null | \
      grep -c "sensitive.*=.*true" || true)
    MARKED=$(echo "${MARKED}" | tr -d '[:space:]')
    MARKED=${MARKED:-0}
    if [ "${MARKED}" -lt "${TOTAL}" ] 2>/dev/null; then
      ((SECRETS_CHECK++))
    fi
  fi
done
if [ "${SECRETS_CHECK}" -eq 0 ]; then
  gate_pass "All secret variables marked as sensitive"
else
  gate_fail "${SECRETS_CHECK} secret variables not marked sensitive"
fi

# --- Gate 8: Required tags ---
echo -e "${BLUE}[8/8] Required tags${NC}"
# Check that default_tags are set in provider block
if grep -q "default_tags" "${INFRA_DIR}"/main.tf 2>/dev/null; then
  REQUIRED_TAGS=("Project" "Environment" "ManagedBy")
  MISSING_TAGS=0
  for TAG in "${REQUIRED_TAGS[@]}"; do
    if ! grep -q "${TAG}" "${INFRA_DIR}"/main.tf 2>/dev/null; then
      ((MISSING_TAGS++))
      echo "    Missing tag: ${TAG}"
    fi
  done
  if [ "${MISSING_TAGS}" -eq 0 ]; then
    gate_pass "All required tags present (Project, Environment, ManagedBy)"
  else
    gate_fail "Missing ${MISSING_TAGS} required tags"
  fi
else
  gate_fail "No default_tags block in provider configuration"
fi

# --- Summary ---
echo ""
echo "═══════════════════════════════════════════════════"
TOTAL=$((PASS + FAIL + WARN))
echo -e "  Results: ${GREEN}${PASS} passed${NC} / ${YELLOW}${WARN} warnings${NC} / ${RED}${FAIL} failed${NC} (${TOTAL} total)"
echo "═══════════════════════════════════════════════════"
echo ""

if [ "${FAIL}" -gt 0 ]; then
  echo -e "${RED}❌ Quality gate FAILED — fix ${FAIL} issue(s) before deploying.${NC}"
  exit 1
else
  echo -e "${GREEN}✅ Quality gate PASSED!${NC}"
  exit 0
fi
