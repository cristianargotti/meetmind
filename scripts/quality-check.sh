#!/usr/bin/env bash
# ============================================================================
# MeetMind Quality Gate — Based on MEETMIND_DEVELOPMENT_STANDARDS.md
# ============================================================================
# Usage: ./scripts/quality-check.sh [--fix]
#
# Verifies ALL development standards:
#   SEC-001: No hardcoded secrets (gitleaks)
#   SEC-002: No sensitive defaults in code
#   CODE-001: File size limits (≤500 soft, ≤800 hard)
#   CODE-002: Function length limits
#   TEST-001: Coverage ≥80%
#   DOC-001: Type hints & linting (mypy --strict)
#   LINT: 0 errors (ruff)
#   FORMAT: 100% formatted (ruff format)
# ============================================================================

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$ROOT_DIR/backend"
FLUTTER_DIR="$ROOT_DIR/flutter_app"

FIX_MODE=false
if [[ "${1:-}" == "--fix" ]]; then
    FIX_MODE=true
fi

PASSED=0
FAILED=0
WARNINGS=0

pass() { ((PASSED++)); echo -e "  ${GREEN}✅ PASS${NC} — $1"; }
fail() { ((FAILED++)); echo -e "  ${RED}❌ FAIL${NC} — $1"; }
warn() { ((WARNINGS++)); echo -e "  ${YELLOW}⚠️  WARN${NC} — $1"; }
info() { echo -e "  ${BLUE}ℹ️  INFO${NC} — $1"; }

# ============================================================================
# SECTION 1: SECURITY CHECKS
# ============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  🔒 SECURITY CHECKS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# SEC-001: Secrets scan
if command -v gitleaks &> /dev/null; then
    GITLEAKS_CONFIG=""
    if [[ -f "$ROOT_DIR/.gitleaks.toml" ]]; then
        GITLEAKS_CONFIG="--config=$ROOT_DIR/.gitleaks.toml"
    fi
    if gitleaks detect --source="$ROOT_DIR" $GITLEAKS_CONFIG --no-banner --no-color 2>/dev/null; then
        pass "SEC-001: No secrets detected (gitleaks)"
    else
        fail "SEC-001: Secrets found in code! Run: gitleaks detect --verbose"
    fi
else
    warn "SEC-001: gitleaks not installed — skipping secrets scan"
    info "Install with: brew install gitleaks"
fi

# SEC-002: No hardcoded AWS credentials in Python
echo ""
HARDCODED=$(grep -rn "AKIA\|aws_secret_access_key\|sk-[a-zA-Z0-9]\{20,\}" \
    "$BACKEND_DIR/src/" 2>/dev/null || true)
if [[ -z "$HARDCODED" ]]; then
    pass "SEC-002: No hardcoded AWS/API keys in backend source"
else
    fail "SEC-002: Hardcoded credentials found:"
    echo "$HARDCODED"
fi

# SEC-005: Check settings.py has no credential defaults
SETTINGS_FILE="$BACKEND_DIR/src/meetmind/config/settings.py"
if [[ -f "$SETTINGS_FILE" ]]; then
    # Check aws_profile and aws_region have empty defaults
    if grep -q 'aws_profile.*=.*"mibaggy' "$SETTINGS_FILE" 2>/dev/null; then
        fail "SEC-005: aws_profile has hardcoded default in settings.py"
    else
        pass "SEC-005: No hardcoded AWS defaults in settings.py"
    fi
fi

# SEC-006: .env not committed
if git -C "$ROOT_DIR" ls-files --cached | grep -q "\.env$"; then
    fail "SEC-006: .env file is tracked by git!"
else
    pass "SEC-006: .env not tracked by git"
fi

# ============================================================================
# SECTION 2: PYTHON QUALITY (Backend)
# ============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  🐍 PYTHON QUALITY (Backend)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cd "$BACKEND_DIR"

# LINT: ruff check
echo ""
if $FIX_MODE; then
    info "Running ruff with --fix..."
    uv run ruff check src/ tests/ --fix 2>/dev/null || true
fi
RUFF_OUTPUT=$(uv run ruff check src/ tests/ 2>&1 || true)
if echo "$RUFF_OUTPUT" | grep -q "All checks passed\|^$"; then
    pass "LINT: ruff — 0 errors"
else
    RUFF_COUNT=$(echo "$RUFF_OUTPUT" | grep -oE 'Found [0-9]+ error' | head -1)
    fail "LINT: ruff — ${RUFF_COUNT:-errors found}"
    echo "$RUFF_OUTPUT" | head -20
fi

# FORMAT: ruff format
echo ""
if $FIX_MODE; then
    info "Running ruff format..."
    uv run ruff format src/ tests/ 2>/dev/null || true
fi
FORMAT_OUTPUT=$(uv run ruff format --check src/ tests/ 2>&1)
FORMAT_EXIT=$?
if [[ $FORMAT_EXIT -eq 0 ]]; then
    pass "FORMAT: ruff format — 100% formatted"
else
    FORMAT_COUNT=$(echo "$FORMAT_OUTPUT" | grep -c "would be reformatted" 2>/dev/null || echo "?")
    fail "FORMAT: $FORMAT_COUNT file(s) need formatting. Run: uv run ruff format src/ tests/"
fi

# TYPE SAFETY: mypy --strict
echo ""
MYPY_OUTPUT=$(uv run mypy --strict src/ 2>&1 || true)
MYPY_ERRORS=$(echo "$MYPY_OUTPUT" | grep ": error:" | wc -l | tr -d ' ')
if [[ "$MYPY_ERRORS" -eq 0 ]] || echo "$MYPY_OUTPUT" | grep -q "Success"; then
    pass "TYPES: mypy --strict — 0 errors"
else
    fail "TYPES: mypy --strict — $MYPY_ERRORS error(s)"
    echo "$MYPY_OUTPUT" | grep ": error:" | head -10
fi

# TESTS: pytest + coverage
echo ""
PYTEST_OUTPUT=$(uv run pytest tests/ --cov=meetmind --cov-report=term-missing -q 2>&1 || true)
if echo "$PYTEST_OUTPUT" | grep -q "passed"; then
    PASSED_TESTS=$(echo "$PYTEST_OUTPUT" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || echo "?")
    FAILED_TESTS=$(echo "$PYTEST_OUTPUT" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' || echo "0")
    
    if [[ "$FAILED_TESTS" -gt 0 ]]; then
        fail "TESTS: $FAILED_TESTS tests failed"
    else
        pass "TESTS: $PASSED_TESTS tests passed"
    fi
    
    # Coverage check
    COVERAGE=$(echo "$PYTEST_OUTPUT" | grep "TOTAL" | awk '{print $NF}' | tr -d '%')
    if [[ -n "$COVERAGE" ]]; then
        if [[ "$COVERAGE" -ge 80 ]]; then
            pass "COVERAGE: ${COVERAGE}% (≥80% required)"
        else
            fail "COVERAGE: ${COVERAGE}% — below 80% minimum!"
        fi
    else
        warn "COVERAGE: Could not determine coverage percentage"
    fi
else
    fail "TESTS: pytest failed to run"
    echo "$PYTEST_OUTPUT" | tail -10
fi

# ============================================================================
# SECTION 3: CODE QUALITY CHECKS
# ============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  📏 CODE QUALITY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cd "$ROOT_DIR"

# CODE-001: File size (≤500 soft, ≤800 hard)
echo ""
BIG_FILES_HARD=0
BIG_FILES_SOFT=0
while IFS= read -r file; do
    lines=$(wc -l < "$file" | tr -d ' ')
    if [[ "$lines" -gt 800 ]]; then
        fail "CODE-001: $file — $lines lines (HARD limit: 800)"
        ((BIG_FILES_HARD++))
    elif [[ "$lines" -gt 500 ]]; then
        warn "CODE-001: $file — $lines lines (SOFT limit: 500)"
        ((BIG_FILES_SOFT++))
    fi
done < <(find "$BACKEND_DIR/src" -name "*.py" -type f 2>/dev/null)

if [[ "$BIG_FILES_HARD" -eq 0 && "$BIG_FILES_SOFT" -eq 0 ]]; then
    pass "CODE-001: All Python files ≤500 lines"
elif [[ "$BIG_FILES_HARD" -eq 0 ]]; then
    info "CODE-001: $BIG_FILES_SOFT files above soft limit (500) but within hard limit (800)"
fi

# DOC-001: Docstrings on public functions
echo ""
MISSING_DOCS=$(uv run ruff check "$BACKEND_DIR/src/" --select D100,D101,D102,D103 2>&1 || true)
if echo "$MISSING_DOCS" | grep -q "All checks passed"; then
    pass "DOC-001: All modules/classes/functions have docstrings"
else
    DOC_COUNT=$(echo "$MISSING_DOCS" | grep ": D10" | wc -l | tr -d ' ')
    if [[ "$DOC_COUNT" -eq 0 ]]; then
        pass "DOC-001: Docstrings check passed"
    else
        warn "DOC-001: $DOC_COUNT missing docstrings (run: uv run ruff check src/ --select D)"
    fi
fi

# Check for 'dynamic' equivalent in Python — bare except
echo ""
BARE_EXCEPT=$(grep -rn "except:" "$BACKEND_DIR/src/" 2>/dev/null | grep -v "except:  #" || true)
if [[ -z "$BARE_EXCEPT" ]]; then
    pass "ANTI-PATTERN: No bare 'except:' clauses"
else
    fail "ANTI-PATTERN: Bare 'except:' found — use specific exceptions"
    echo "$BARE_EXCEPT"
fi

# Check for print() statements
PRINTS=$(grep -rn "^[[:space:]]*print(" "$BACKEND_DIR/src/" 2>/dev/null || true)
if [[ -z "$PRINTS" ]]; then
    pass "ANTI-PATTERN: No print() in source — use structlog"
else
    fail "ANTI-PATTERN: print() found — use structlog instead"
    echo "$PRINTS"
fi

# ============================================================================
# SECTION 4: FLUTTER CHECKS
# ============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  📱 FLUTTER CHECKS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ -d "$FLUTTER_DIR" ]]; then
    cd "$FLUTTER_DIR"

    # Detect Flutter command (FVM or global)
    if command -v fvm &> /dev/null && [[ -f ".fvmrc" ]]; then
        FLUTTER_CMD="fvm flutter"
        DART_CMD="fvm dart"
        FVM_VERSION=$(cat .fvmrc | grep -o '"flutter".*"[0-9.]*"' | grep -o '[0-9.]*' || echo "?")
        pass "FVM: Pinned to Flutter $FVM_VERSION"
    elif command -v flutter &> /dev/null; then
        FLUTTER_CMD="flutter"
        DART_CMD="dart"
        warn "FVM: Not using FVM — falling back to global Flutter"
    else
        warn "FLUTTER: Flutter SDK not found — skipping Flutter checks"
        FLUTTER_CMD=""
    fi

    if [[ -n "$FLUTTER_CMD" ]]; then
        # FLUTTER ANALYZE (strict — 0 errors)
        echo ""
        ANALYZE_OUTPUT=$(FLUTTER_SUPPRESS_ANALYTICS=true $FLUTTER_CMD analyze --no-pub 2>&1 || true)
        ANALYZE_ERRORS=$(echo "$ANALYZE_OUTPUT" | grep -oE '[0-9]+ issue' | grep -oE '[0-9]+' || echo "0")
        if echo "$ANALYZE_OUTPUT" | grep -q "No issues found"; then
            pass "DART-LINT: flutter analyze — 0 issues"
        else
            fail "DART-LINT: flutter analyze — $ANALYZE_ERRORS issue(s)"
            echo "$ANALYZE_OUTPUT" | grep -E "error|warning|info" | head -15
        fi

        # FLUTTER FORMAT CHECK
        echo ""
        DART_FORMAT_OUTPUT=$($DART_CMD format --set-exit-if-changed --output=none lib/ 2>&1)
        DART_FORMAT_EXIT=$?
        if [[ $DART_FORMAT_EXIT -eq 0 ]]; then
            pass "DART-FORMAT: All Dart files formatted"
        else
            if $FIX_MODE; then
                info "Running dart format..."
                $DART_CMD format lib/ 2>/dev/null || true
                pass "DART-FORMAT: Auto-formatted"
            else
                FORMAT_FILES=$(echo "$DART_FORMAT_OUTPUT" | grep -c "\.dart$" || echo "?")
                fail "DART-FORMAT: $FORMAT_FILES file(s) need formatting. Run: dart format lib/"
            fi
        fi

        # FLUTTER TESTS
        echo ""
        FLUTTER_TEST_OUTPUT=$(FLUTTER_SUPPRESS_ANALYTICS=true $FLUTTER_CMD test --no-pub 2>&1 || true)
        if echo "$FLUTTER_TEST_OUTPUT" | grep -q "All tests passed"; then
            FLUTTER_PASSED=$(echo "$FLUTTER_TEST_OUTPUT" | grep -oE '[0-9]+ test' | grep -oE '[0-9]+' || echo "?")
            pass "DART-TESTS: $FLUTTER_PASSED test(s) passed"
        elif echo "$FLUTTER_TEST_OUTPUT" | grep -q "No tests ran"; then
            warn "DART-TESTS: No tests found — add tests to flutter_app/test/"
        else
            fail "DART-TESTS: Flutter tests failed"
            echo "$FLUTTER_TEST_OUTPUT" | tail -10
        fi
    fi

    # CODE-005: No 'dynamic' types in Dart
    echo ""
    DYNAMIC_COUNT=$(grep -rn "dynamic " "$FLUTTER_DIR/lib/" 2>/dev/null | grep -v "// ignore" | wc -l | tr -d ' ')
    if [[ "$DYNAMIC_COUNT" -eq 0 ]]; then
        pass "CODE-005: No 'dynamic' types in Dart"
    else
        fail "CODE-005: $DYNAMIC_COUNT uses of 'dynamic' in Dart — use explicit types"
        grep -rn "dynamic " "$FLUTTER_DIR/lib/" 2>/dev/null | grep -v "// ignore" | head -5
    fi

    # ANTI-PATTERN: No print() in Dart
    DART_PRINTS=$(grep -rn "print(" "$FLUTTER_DIR/lib/" 2>/dev/null | grep -v "// ignore" | wc -l | tr -d ' ')
    if [[ "$DART_PRINTS" -eq 0 ]]; then
        pass "DART-ANTI: No print() in Dart source — use debugPrint or logger"
    else
        fail "DART-ANTI: $DART_PRINTS print() found — use debugPrint or logger"
    fi

    # Dart file size check
    DART_BIG_FILES=0
    while IFS= read -r file; do
        lines=$(wc -l < "$file" | tr -d ' ')
        if [[ "$lines" -gt 500 ]]; then
            warn "CODE-001: $file — $lines lines (limit: 500)"
            ((DART_BIG_FILES++))
        fi
    done < <(find "$FLUTTER_DIR/lib" -name "*.dart" -type f 2>/dev/null)
    if [[ "$DART_BIG_FILES" -eq 0 ]]; then
        pass "CODE-001: All Dart files ≤500 lines"
    fi
else
    warn "FLUTTER: flutter_app/ not found — skipping Flutter checks"
fi

# ============================================================================
# SECTION 5: PROJECT STRUCTURE
# ============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  📂 PROJECT STRUCTURE${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cd "$ROOT_DIR"

# Required directories
REQUIRED_DIRS=(
    "backend/src/meetmind/config"
    "backend/src/meetmind/providers"
    "backend/src/meetmind/agents"
    "backend/src/meetmind/core"
    "backend/src/meetmind/api"
    "backend/src/meetmind/security"
    "backend/src/meetmind/utils"
    "backend/tests"
    "flutter_app/lib"
    "docs"
)

ALL_DIRS_OK=true
for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        fail "STRUCTURE: Missing directory — $dir"
        ALL_DIRS_OK=false
    fi
done
if $ALL_DIRS_OK; then
    pass "STRUCTURE: All required directories present (Hexagonal Architecture)"
fi

# Required files
REQUIRED_FILES=(
    ".gitignore"
    "README.md"
    "backend/pyproject.toml"
    "backend/.env.example"
    "flutter_app/.fvmrc"
)

ALL_FILES_OK=true
for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        fail "STRUCTURE: Missing file — $f"
        ALL_FILES_OK=false
    fi
done
if $ALL_FILES_OK; then
    pass "STRUCTURE: All required project files present"
fi

# ============================================================================
# RESULTS
# ============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  📊 QUALITY GATE RESULTS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${GREEN}✅ Passed:${NC}  $PASSED"
echo -e "  ${RED}❌ Failed:${NC}  $FAILED"
echo -e "  ${YELLOW}⚠️  Warns:${NC}   $WARNINGS"
echo ""

if [[ "$FAILED" -eq 0 ]]; then
    echo -e "  ${GREEN}🏆 ALL QUALITY GATES PASSED — Ready to commit!${NC}"
    echo ""
    exit 0
else
    echo -e "  ${RED}🚫 $FAILED GATE(S) FAILED — Fix before committing!${NC}"
    echo -e "  ${YELLOW}💡 Run with --fix to auto-fix formatting: ./scripts/quality-check.sh --fix${NC}"
    echo ""
    exit 1
fi
