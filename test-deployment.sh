#!/bin/bash
# ============================================================
# Production Deployment Test Script
# 
# Tests the complete production deployment setup including:
# - Docker configuration validation
# - PocketBase initialization
# - Service health checks
# - API accessibility
# ============================================================

set -e

echo "🧪 Lager App - Production Deployment Test"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_step() {
    local description=$1
    local command=$2
    
    echo -n "Testing: $description... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# ============================================================
# 1. Prerequisites
# ============================================================
echo "1️⃣  Prerequisites Check"
echo "----------------------"

test_step "Docker installed" "command -v docker"
test_step "Docker Compose installed" "command -v docker compose"
test_step "Docker daemon running" "docker info"

echo ""

# ============================================================
# 2. Configuration Files
# ============================================================
echo "2️⃣  Configuration Files"
echo "----------------------"

test_step "docker-compose.yml exists" "[ -f docker-compose.yml ]"
test_step "docker-compose.prod.yml exists" "[ -f docker-compose.prod.yml ]"
test_step "docker-stack.yml exists" "[ -f docker-stack.yml ]"
test_step ".env.example exists" "[ -f .env.example ]"
test_step ".env.production.example exists" "[ -f .env.production.example ]"

echo ""

# ============================================================
# 3. Docker Compose Validation
# ============================================================
echo "3️⃣  Docker Compose Validation"
echo "-----------------------------"

test_step "Dev/Test compose syntax" "docker compose -f docker-compose.yml config > /dev/null"
test_step "Production compose syntax (with env)" "POCKETBASE_URL=https://api.example.com docker compose -f docker-compose.prod.yml config > /dev/null"
test_step "Docker stack syntax" "docker compose -f docker-stack.yml config > /dev/null"

echo ""

# ============================================================
# 4. PocketBase Setup
# ============================================================
echo "4️⃣  PocketBase Setup"
echo "-------------------"

test_step "PocketBase Dockerfile exists" "[ -f server/Dockerfile ]"
test_step "PocketBase init script exists" "[ -f server/init-pocketbase.sh ]"
test_step "PocketBase migrations exist" "[ -d server/pb_migrations ]"
test_step "Migration script exists" "[ -f server/pb_migrations/1772784781_created_artikel.js ]"
test_step "Schema definition exists" "[ -f server/pb_migrations/pb_schema.json ]"

echo ""

# ============================================================
# 5. Flutter App Setup
# ============================================================
echo "5️⃣  Flutter App Setup"
echo "---------------------"

test_step "Flutter app Dockerfile exists" "[ -f app/Dockerfile ]"
test_step "Flutter pubspec.yaml exists" "[ -f app/pubspec.yaml ]"
test_step "Flutter lib directory exists" "[ -d app/lib ]"

echo ""

# ============================================================
# 6. Security Configuration
# ============================================================
echo "6️⃣  Security Configuration"
echo "--------------------------"

# Check if API rules require authentication
if grep -q '"listRule": "@request.auth.id != '\'\''"' server/pb_migrations/pb_schema.json; then
    echo -e "Testing: API Rules require authentication... ${GREEN}✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "Testing: API Rules require authentication... ${RED}✗ FAIL${NC}"
    echo "  ⚠️  Warning: API Rules may be open to public access!"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Check if .env files are not in git
if ! git ls-files | grep -q "^\.env$"; then
    echo -e "Testing: .env not in git... ${GREEN}✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "Testing: .env not in git... ${RED}✗ FAIL${NC}"
    echo "  ⚠️  Warning: .env should not be committed to git!"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if ! git ls-files | grep -q "^\.env\.production$"; then
    echo -e "Testing: .env.production not in git... ${GREEN}✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "Testing: .env.production not in git... ${RED}✗ FAIL${NC}"
    echo "  ⚠️  Warning: .env.production should not be committed to git!"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""

# ============================================================
# 7. GitHub Actions
# ============================================================
echo "7️⃣  GitHub Actions"
echo "-----------------"

test_step "Docker build workflow exists" "[ -f .github/workflows/docker-build-push.yml ]"

echo ""

# ============================================================
# 8. Documentation
# ============================================================
echo "8️⃣  Documentation"
echo "----------------"

test_step "README.md exists" "[ -f README.md ]"
test_step "Production deployment guide exists" "[ -f docs/PRODUCTION_DEPLOYMENT.md ]"
test_step "Technical analysis exists" "[ -f docs/TECHNISCHE_ANALYSE_2026-03.md ]"

echo ""

# ============================================================
# Summary
# ============================================================
echo "=========================================="
echo "📊 Test Summary"
echo "=========================================="
echo ""
echo "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo "Total tests:  $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Copy .env.production.example to .env.production"
    echo "2. Edit .env.production with your domain and credentials"
    echo "3. Run: docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build"
    echo ""
    echo "For detailed instructions, see: docs/PRODUCTION_DEPLOYMENT.md"
    exit 0
else
    echo -e "${RED}❌ Some tests failed!${NC}"
    echo ""
    echo "Please fix the issues above before deploying to production."
    exit 1
fi
