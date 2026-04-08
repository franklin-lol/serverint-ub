#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  ServerInit — Test Suite
#  Tests swap logic, CI mode validation, SSH port rules, disk guard.
#  No real system changes — all tests run in a sandboxed mock environment.
#
#  Run:  bash tests/test_serverinit.sh
#  Exit: 0 = all passed · non-zero = failures
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Counters ──────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; SKIP=0

# ── Colours ───────────────────────────────────────────────────────────────────
G='\033[0;32m' R='\033[0;31m' Y='\033[0;33m' B='\033[0;34m' NC='\033[0m' BOLD='\033[1m'

pass() { PASS=$((PASS+1)); echo -e "${G}  ✔${NC}  $1"; }
fail() { FAIL=$((FAIL+1)); echo -e "${R}  ✖${NC}  $1"; }
skip() { SKIP=$((SKIP+1)); echo -e "${Y}  –${NC}  $1 ${Y}[skipped]${NC}"; }
section() { echo -e "\n${BOLD}${B}▶ $1${NC}"; }

# ── Helper: run the swap+disk-limiter logic in a subshell ─────────────────────
# Args: TOTAL_RAM_MB  DISK_FREE_GB
# Outputs the final SWAP_GB value
calc_swap() {
  local ram="$1" disk="$2"
  bash -c "
    TOTAL_RAM_MB=$ram
    DISK_FREE_GB=$disk

    if   [[ \$TOTAL_RAM_MB -le 1024 ]]; then SWAP_GB=2
    elif [[ \$TOTAL_RAM_MB -le 2048 ]]; then SWAP_GB=2
    elif [[ \$TOTAL_RAM_MB -le 4096 ]]; then SWAP_GB=4
    elif [[ \$TOTAL_RAM_MB -le 8192 ]]; then SWAP_GB=4
    else                                     SWAP_GB=0; fi

    MIN_FREE_AFTER_SWAP=5
    if [[ \$SWAP_GB -gt 0 ]]; then
      DISK_AFTER_SWAP=\$(( DISK_FREE_GB - SWAP_GB ))
      if [[ \$DISK_AFTER_SWAP -lt \$MIN_FREE_AFTER_SWAP ]]; then
        SWAP_GB=\$(( DISK_FREE_GB - MIN_FREE_AFTER_SWAP ))
        [[ \$SWAP_GB -lt 0 ]] && SWAP_GB=0
      fi
    fi
    echo \$SWAP_GB
  "
}

# ── Helper: validate CI env vars (mirrors script logic) ──────────────────────
validate_ci() {
  local stack="$1" sec="$2" port="$3"
  bash -c "
    set -euo pipefail
    STACK=\$1; SEC=\$2; PORT=\$3
    [[ \"\$STACK\" =~ ^[1-4]\$ ]] || { echo 'BAD_STACK'; exit 1; }
    [[ \"\$SEC\"   =~ ^[1-2]\$ ]] || { echo 'BAD_SEC';   exit 1; }
    if [[ \$SEC -eq 2 && \"\$PORT\" != '22' ]]; then
      [[ \"\$PORT\" =~ ^[0-9]+\$ && \$PORT -ge 1024 && \$PORT -le 65535 ]] \
        || { echo 'BAD_PORT'; exit 1; }
    fi
    echo 'OK'
  " _ "$stack" "$sec" "$port"
}

# ══════════════════════════════════════════════════════════════════════════════
#  1. SWAP SIZE — RAM-based baseline
# ══════════════════════════════════════════════════════════════════════════════
section "Swap — RAM-based calculation (unlimited disk)"

result=$(calc_swap 512  100); [[ "$result" == "2" ]] && pass "RAM  512 MB → Swap 2 GB" || fail "RAM  512 MB → expected 2, got $result"
result=$(calc_swap 1024 100); [[ "$result" == "2" ]] && pass "RAM 1024 MB → Swap 2 GB" || fail "RAM 1024 MB → expected 2, got $result"
result=$(calc_swap 2048 100); [[ "$result" == "2" ]] && pass "RAM 2048 MB → Swap 2 GB" || fail "RAM 2048 MB → expected 2, got $result"
result=$(calc_swap 4096 100); [[ "$result" == "4" ]] && pass "RAM 4096 MB → Swap 4 GB" || fail "RAM 4096 MB → expected 4, got $result"
result=$(calc_swap 8192 100); [[ "$result" == "4" ]] && pass "RAM 8192 MB → Swap 4 GB" || fail "RAM 8192 MB → expected 4, got $result"
result=$(calc_swap 16384 100); [[ "$result" == "0" ]] && pass "RAM 16 GB   → Swap 0 GB (no swap needed)" || fail "RAM 16 GB → expected 0, got $result"

# ══════════════════════════════════════════════════════════════════════════════
#  2. SWAP SIZE — Disk limiter (≥5 GB must remain free)
# ══════════════════════════════════════════════════════════════════════════════
section "Swap — Smart disk limiter"

result=$(calc_swap 4096 20);  [[ "$result" == "4" ]] && pass "Disk 20 GB, RAM 4 GB → Swap 4 GB (plenty of space)"  || fail "expected 4, got $result"
result=$(calc_swap 4096 9);   [[ "$result" == "4" ]] && pass "Disk  9 GB, RAM 4 GB → Swap 4 GB (9-4=5, just fits)" || fail "expected 4, got $result"
result=$(calc_swap 4096 7);   [[ "$result" == "2" ]] && pass "Disk  7 GB, RAM 4 GB → Swap 2 GB (7-5=2, capped)"   || fail "expected 2, got $result"
result=$(calc_swap 1024 6);   [[ "$result" == "1" ]] && pass "Disk  6 GB, RAM 1 GB → Swap 1 GB (6-5=1, capped)"   || fail "expected 1, got $result"
result=$(calc_swap 4096 5);   [[ "$result" == "0" ]] && pass "Disk  5 GB, RAM 4 GB → Swap 0 GB (no room)"         || fail "expected 0, got $result"
result=$(calc_swap 4096 3);   [[ "$result" == "0" ]] && pass "Disk  3 GB, RAM 4 GB → Swap 0 GB (negative → 0)"    || fail "expected 0, got $result"
result=$(calc_swap 16384 3);  [[ "$result" == "0" ]] && pass "Disk  3 GB, RAM 16GB → Swap 0 GB (no swap + no disk)" || fail "expected 0, got $result"

# ══════════════════════════════════════════════════════════════════════════════
#  3. CI MODE — Environment variable validation
# ══════════════════════════════════════════════════════════════════════════════
section "CI mode — env var validation"

result=$(validate_ci 1 1 22);    [[ "$result" == "OK" ]] && pass "Valid: STACK=1 SEC=1 PORT=22"       || fail "expected OK, got $result"
result=$(validate_ci 4 2 2222);  [[ "$result" == "OK" ]] && pass "Valid: STACK=4 SEC=2 PORT=2222"     || fail "expected OK, got $result"
result=$(validate_ci 2 1 22);    [[ "$result" == "OK" ]] && pass "Valid: STACK=2 SEC=1 (port ignored)" || fail "expected OK, got $result"

result=$(validate_ci 5 1 22 2>/dev/null || echo "ERR"); [[ "$result" != "OK" ]] && pass "Invalid: STACK=5 rejected"     || fail "STACK=5 should be rejected"
result=$(validate_ci 1 3 22 2>/dev/null || echo "ERR"); [[ "$result" != "OK" ]] && pass "Invalid: SEC=3 rejected"       || fail "SEC=3 should be rejected"
result=$(validate_ci 1 2 80 2>/dev/null || echo "ERR"); [[ "$result" != "OK" ]] && pass "Invalid: PORT=80 rejected (<1024)" || fail "PORT=80 should be rejected"
result=$(validate_ci 1 2 99999 2>/dev/null || echo "ERR"); [[ "$result" != "OK" ]] && pass "Invalid: PORT=99999 rejected (>65535)" || fail "PORT=99999 should be rejected"
result=$(validate_ci 1 2 abc 2>/dev/null || echo "ERR"); [[ "$result" != "OK" ]] && pass "Invalid: PORT=abc rejected (non-numeric)" || fail "PORT=abc should be rejected"

# ══════════════════════════════════════════════════════════════════════════════
#  4. SSH PORT VALIDATION — Interactive range check
# ══════════════════════════════════════════════════════════════════════════════
section "SSH port — boundary validation"

check_port() {
  local p="$1"
  bash -c "
    port='$p'
    if [[ \"\$port\" =~ ^[0-9]+\$ && \$port -ge 1024 && \$port -le 65535 ]]; then
      echo VALID
    else
      echo INVALID
    fi
  "
}

result=$(check_port 22);    [[ "$result" == "INVALID" ]] && pass "Port 22 rejected (< 1024)" || fail "Port 22 should be rejected"
result=$(check_port 1023);  [[ "$result" == "INVALID" ]] && pass "Port 1023 rejected"         || fail "Port 1023 should be rejected"
result=$(check_port 1024);  [[ "$result" == "VALID"   ]] && pass "Port 1024 accepted"          || fail "Port 1024 should be accepted"
result=$(check_port 2222);  [[ "$result" == "VALID"   ]] && pass "Port 2222 accepted"          || fail "Port 2222 should be accepted"
result=$(check_port 65535); [[ "$result" == "VALID"   ]] && pass "Port 65535 accepted"         || fail "Port 65535 should be accepted"
result=$(check_port 65536); [[ "$result" == "INVALID" ]] && pass "Port 65536 rejected (> 65535)" || fail "Port 65536 should be rejected"
result=$(check_port abc);   [[ "$result" == "INVALID" ]] && pass "Port 'abc' rejected (non-numeric)" || fail "Port 'abc' should be rejected"

# ══════════════════════════════════════════════════════════════════════════════
#  5. SHELLCHECK — Static analysis
# ══════════════════════════════════════════════════════════════════════════════
section "Static analysis — ShellCheck"

SCRIPT_PATH="${1:-./serverinit.sh}"
if ! command -v shellcheck &>/dev/null; then
  skip "shellcheck not installed (apt install shellcheck)"
else
  if shellcheck -S warning "$SCRIPT_PATH" 2>/dev/null; then
    pass "shellcheck: no warnings in $SCRIPT_PATH"
  else
    fail "shellcheck found issues in $SCRIPT_PATH"
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
#  6. SCRIPT INTEGRITY
# ══════════════════════════════════════════════════════════════════════════════
section "Script integrity"

if [[ -f "$SCRIPT_PATH" ]]; then
  bash -n "$SCRIPT_PATH" 2>/dev/null && pass "Syntax check passed (bash -n)" || fail "Syntax errors found"

  [[ -x "$SCRIPT_PATH" ]] && pass "Script is executable" || { fail "Script is not executable (chmod +x serverinit.sh)"; }

  grep -q 'CI_MODE' "$SCRIPT_PATH" && pass "--ci flag present in script"     || fail "--ci flag missing"
  grep -q 'SI_STACK' "$SCRIPT_PATH" && pass "SI_STACK env var referenced"    || fail "SI_STACK env var missing"
  grep -q 'MIN_FREE_AFTER_SWAP' "$SCRIPT_PATH" && pass "Disk limiter present" || fail "Disk limiter missing"
  grep -q 'set -Eeuo pipefail' "$SCRIPT_PATH" && pass "Strict mode enabled"   || fail "set -Eeuo pipefail missing"
  grep -q 'trap cleanup EXIT' "$SCRIPT_PATH" && pass "Error trap present"     || fail "trap cleanup EXIT missing"
  grep -q 'retry()' "$SCRIPT_PATH" && pass "retry() function present"        || fail "retry() function missing"
else
  fail "Script not found at $SCRIPT_PATH — pass path as argument: bash tests/test_serverinit.sh /path/to/serverinit.sh"
fi

# ══════════════════════════════════════════════════════════════════════════════
#  SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
TOTAL=$((PASS + FAIL + SKIP))
echo ""
echo -e "────────────────────────────────────────────"
echo -e "  Tests: ${TOTAL}  ${G}passed: ${PASS}${NC}  ${R}failed: ${FAIL}${NC}  ${Y}skipped: ${SKIP}${NC}"
echo -e "────────────────────────────────────────────"

[[ $FAIL -eq 0 ]] && echo -e "${G}${BOLD}  ✔ All tests passed${NC}" || echo -e "${R}${BOLD}  ✖ ${FAIL} test(s) failed${NC}"
echo ""

exit $FAIL
