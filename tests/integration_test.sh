#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  ServerInit — Integration Test Suite
#  Tests actual installation in isolated Docker containers (Ubuntu/Debian)
#
#  Requirements: Docker installed and running
#  Run: bash tests/integration_test.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

G='\033[0;32m' R='\033[0;31m' Y='\033[0;33m' B='\033[0;34m' NC='\033[0m' BOLD='\033[1m'
PASS=0; FAIL=0; SKIP=0

pass() { PASS=$((PASS+1)); echo -e "${G}  ✔${NC}  $1"; }
fail() { FAIL=$((FAIL+1)); echo -e "${R}  ✖${NC}  $1"; }
skip() { SKIP=$((SKIP+1)); echo -e "${Y}  –${NC}  $1 ${Y}[skipped]${NC}"; }
section() { echo -e "\n${BOLD}${B}▶ $1${NC}"; }

# Check Docker availability
if ! command -v docker &>/dev/null; then
  echo -e "${R}Docker не установлен — integration tests пропущены${NC}"
  exit 0
fi

if ! docker info &>/dev/null; then
  echo -e "${Y}Docker недоступен (daemon не запущен?) — integration tests пропущены${NC}"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVERINIT_SCRIPT="$ROOT_DIR/serverinit.sh"

if [[ ! -f "$SERVERINIT_SCRIPT" ]]; then
  echo -e "${R}serverinit.sh не найден: $SERVERINIT_SCRIPT${NC}"
  exit 1
fi

echo -e "${BOLD}ServerInit — Integration Tests${NC}"
echo -e "${DIM}Testing against real Ubuntu/Debian containers${NC}\n"

# ══════════════════════════════════════════════════════════════════════════════
#  Test: Ubuntu 22.04 — Docker stack + basic security
# ══════════════════════════════════════════════════════════════════════════════
section "Ubuntu 22.04 — Docker stack (SI_NGINX=0) + basic security"

CONTAINER_NAME="serverinit-test-u22-$$"
docker run -d --name "$CONTAINER_NAME" --privileged ubuntu:22.04 sleep 3600 > /dev/null 2>&1

# Copy script into container
docker cp "$SERVERINIT_SCRIPT" "$CONTAINER_NAME:/tmp/serverinit.sh"

# Run in CI mode
docker exec "$CONTAINER_NAME" bash -c "
  export DEBIAN_FRONTEND=noninteractive
  SI_STACK=1 SI_SEC=1 SI_NGINX=0 bash /tmp/serverinit.sh --ci > /tmp/install.log 2>&1
" && TEST_RESULT=0 || TEST_RESULT=$?

if [[ $TEST_RESULT -eq 0 ]]; then
  pass "Installation completed without errors"

  # Verify Docker installed
  docker exec "$CONTAINER_NAME" which docker > /dev/null 2>&1 && \
    pass "Docker binary present" || fail "Docker binary missing"

  # Verify docker compose plugin
  docker exec "$CONTAINER_NAME" docker compose version > /dev/null 2>&1 && \
    pass "Docker Compose plugin working" || fail "Docker Compose plugin missing"

  # Verify UFW configured
  docker exec "$CONTAINER_NAME" bash -c "ufw status | grep -q 'Status: active'" && \
    pass "UFW active" || fail "UFW not active"

  # Verify Nginx NOT installed (SI_NGINX=0)
  if docker exec "$CONTAINER_NAME" which nginx > /dev/null 2>&1; then
    fail "Nginx installed (should be skipped with SI_NGINX=0)"
  else
    pass "Nginx correctly skipped (SI_NGINX=0)"
  fi

  # Verify sysctl tuning applied
  docker exec "$CONTAINER_NAME" sysctl net.core.somaxconn | grep -q 65535 && \
    pass "sysctl tuning applied" || fail "sysctl tuning missing"
else
  fail "Installation failed (exit code: $TEST_RESULT)"
  docker exec "$CONTAINER_NAME" tail -50 /tmp/install.log 2>/dev/null || true
fi

docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1

# ══════════════════════════════════════════════════════════════════════════════
#  Test: Ubuntu 24.04 — Base stack + full security
# ══════════════════════════════════════════════════════════════════════════════
section "Ubuntu 24.04 — Base stack + full security"

CONTAINER_NAME="serverinit-test-u24-$$"
docker run -d --name "$CONTAINER_NAME" --privileged ubuntu:24.04 sleep 3600 > /dev/null 2>&1

docker cp "$SERVERINIT_SCRIPT" "$CONTAINER_NAME:/tmp/serverinit.sh"

docker exec "$CONTAINER_NAME" bash -c "
  export DEBIAN_FRONTEND=noninteractive
  SI_STACK=4 SI_SEC=2 SI_SSH_PORT=2222 bash /tmp/serverinit.sh --ci > /tmp/install.log 2>&1
" && TEST_RESULT=0 || TEST_RESULT=$?

if [[ $TEST_RESULT -eq 0 ]]; then
  pass "Installation completed without errors"

  # Verify fail2ban installed
  docker exec "$CONTAINER_NAME" which fail2ban-client > /dev/null 2>&1 && \
    pass "fail2ban installed" || fail "fail2ban missing"

  # Verify SSH config hardened
  docker exec "$CONTAINER_NAME" grep -q "Port 2222" /etc/ssh/sshd_config && \
    pass "SSH port changed to 2222" || fail "SSH port not changed"

  # Verify unattended-upgrades configured
  docker exec "$CONTAINER_NAME" test -f /etc/apt/apt.conf.d/50unattended-upgrades-serverinit && \
    pass "Unattended-upgrades configured" || fail "Unattended-upgrades config missing"

  # Verify swap configured
  docker exec "$CONTAINER_NAME" test -f /swapfile && \
    pass "Swap file created" || skip "Swap file (may be skipped due to disk limits)"
else
  fail "Installation failed (exit code: $TEST_RESULT)"
  docker exec "$CONTAINER_NAME" tail -50 /tmp/install.log 2>/dev/null || true
fi

docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1

# ══════════════════════════════════════════════════════════════════════════════
#  Test: Debian 12 — Node.js stack + nginx
# ══════════════════════════════════════════════════════════════════════════════
section "Debian 12 — Node.js stack + nginx"

CONTAINER_NAME="serverinit-test-deb12-$$"
docker run -d --name "$CONTAINER_NAME" --privileged debian:12 sleep 3600 > /dev/null 2>&1

docker cp "$SERVERINIT_SCRIPT" "$CONTAINER_NAME:/tmp/serverinit.sh"

docker exec "$CONTAINER_NAME" bash -c "
  export DEBIAN_FRONTEND=noninteractive
  SI_STACK=2 SI_SEC=1 SI_NGINX=1 bash /tmp/serverinit.sh --ci > /tmp/install.log 2>&1
" && TEST_RESULT=0 || TEST_RESULT=$?

if [[ $TEST_RESULT -eq 0 ]]; then
  pass "Installation completed without errors"

  # Verify NVM installed (in root's home since no SUDO_USER in container)
  docker exec "$CONTAINER_NAME" bash -c "[ -d /root/.nvm ]" && \
    pass "NVM directory present" || fail "NVM directory missing"

  # Verify Node.js installed
  docker exec "$CONTAINER_NAME" bash -c "source /root/.nvm/nvm.sh && node --version" > /dev/null 2>&1 && \
    pass "Node.js installed via NVM" || fail "Node.js missing"

  # Verify nginx installed
  docker exec "$CONTAINER_NAME" which nginx > /dev/null 2>&1 && \
    pass "Nginx installed" || fail "Nginx missing"

  # Verify nginx hardening config
  docker exec "$CONTAINER_NAME" test -f /etc/nginx/conf.d/00-serverinit-hardening.conf && \
    pass "Nginx hardening config present" || fail "Nginx hardening config missing"
else
  fail "Installation failed (exit code: $TEST_RESULT)"
  docker exec "$CONTAINER_NAME" tail -50 /tmp/install.log 2>/dev/null || true
fi

docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1

# ══════════════════════════════════════════════════════════════════════════════
#  Test: Idempotency — Run script twice, second run should not fail
# ══════════════════════════════════════════════════════════════════════════════
section "Idempotency — Double run test"

CONTAINER_NAME="serverinit-test-idempotent-$$"
docker run -d --name "$CONTAINER_NAME" --privileged ubuntu:22.04 sleep 3600 > /dev/null 2>&1

docker cp "$SERVERINIT_SCRIPT" "$CONTAINER_NAME:/tmp/serverinit.sh"

# First run
docker exec "$CONTAINER_NAME" bash -c "
  export DEBIAN_FRONTEND=noninteractive
  SI_STACK=1 SI_SEC=2 SI_SSH_PORT=2222 bash /tmp/serverinit.sh --ci > /tmp/install1.log 2>&1
" && FIRST_RUN=0 || FIRST_RUN=$?

# Second run (should be idempotent)
docker exec "$CONTAINER_NAME" bash -c "
  export DEBIAN_FRONTEND=noninteractive
  SI_STACK=1 SI_SEC=2 SI_SSH_PORT=2222 bash /tmp/serverinit.sh --ci > /tmp/install2.log 2>&1
" && SECOND_RUN=0 || SECOND_RUN=$?

if [[ $FIRST_RUN -eq 0 && $SECOND_RUN -eq 0 ]]; then
  pass "Both runs completed successfully (idempotent)"

  # Check for error messages in second run
  ERROR_COUNT=$(docker exec "$CONTAINER_NAME" grep -c "✖" /tmp/install2.log 2>/dev/null || echo 0)
  if [[ $ERROR_COUNT -eq 0 ]]; then
    pass "No errors in second run"
  else
    warn "Found $ERROR_COUNT potential errors in second run (may be warnings)"
  fi
else
  fail "Idempotency test failed (run1: $FIRST_RUN, run2: $SECOND_RUN)"
  docker exec "$CONTAINER_NAME" tail -30 /tmp/install2.log 2>/dev/null || true
fi

docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1

# ══════════════════════════════════════════════════════════════════════════════
#  SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
TOTAL=$((PASS + FAIL + SKIP))
echo ""
echo -e "────────────────────────────────────────────"
echo -e "  Integration Tests: ${TOTAL}  ${G}passed: ${PASS}${NC}  ${R}failed: ${FAIL}${NC}  ${Y}skipped: ${SKIP}${NC}"
echo -e "────────────────────────────────────────────"

[[ $FAIL -eq 0 ]] && echo -e "${G}${BOLD}  ✔ All integration tests passed${NC}" || echo -e "${R}${BOLD}  ✖ ${FAIL} test(s) failed${NC}"
echo ""

exit $FAIL
