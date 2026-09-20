# Changelog

All notable changes to ServerInit are documented here.

## [3.2.0] - 2026-09-20

### Added
- **SI_NGINX environment variable** — Control nginx installation independently (`0`=skip, `1`=install, `auto`=detect based on stack)
- **Interactive nginx prompt** for Docker stack — Ask user if nginx needed on host (may run in container)
- **Integration test suite** (`tests/integration_test.sh`) — Real installation tests in Docker containers (Ubuntu/Debian)
- **CI matrix testing** — GitHub Actions now test all stack/security combinations
- **DPkg hook** for SSH config preservation — Survives openssh-server package updates and cloud-init regeneration

### Fixed (Critical Security)
- **Race condition in iptables DOCKER-USER** — Added flock locking to prevent concurrent modification conflicts
- **NVM installation security** — SHA256 checksum verification prevents MITM attacks
- **fail2ban path traversal protection** — Scanbait jail now catches `/../`, `%2e%2e`, and encoded variants
- **Docker daemon.json deep merge** — Preserves nested configuration objects (log-opts, default-ulimits) instead of overwriting
- **SSH config persistence** — DPkg hook ensures 99-serverinit.conf survives cloud-init overwrites

### Fixed (Reliability & Idempotency)
- **Log cleanup safety** — `find -print0 | xargs -0` handles filenames with whitespace
- **auditd conflict prevention** — Check existing rules before applying to avoid duplicate key errors
- **rkhunter timeout** — 10-minute limit prevents hanging on slow disks
- **sysctl idempotency** — Only reapply when configuration actually changed
- **apt retry mechanism** — Use native `Acquire::Retries` instead of bash loop (faster, more reliable)
- **nginx user config detection** — Skip modifications when custom sites-enabled configs detected
- **Python3 for daemon.json merge** — Replaced jq with Python for true deep merge

### Changed
- **retry() function** — Delegates to apt's native retry for apt-get commands, exponential backoff for others
- **install_nginx()** — Respects SI_NGINX override and detects existing user configurations
- **Test coverage** — 40+ unit tests, 4+ integration tests, idempotency validation

## [3.1.0] - 2024-XX-XX

### Added
- `--ci` unattended mode with environment variable control
- `SI_STACK`, `SI_SEC`, `SI_SSH_PORT` environment variables
- Smart swap disk limiter (keeps ≥5 GB free)
- GitHub Actions CI/CD pipeline
- Comprehensive test suite (36 tests)

### Fixed
- Swap calculation respects available disk space
- CI mode validation for all parameters

## [3.0.0] - 2024-XX-XX

### Fixed
- Portable SSH service restart (tries ssh, sshd, legacy service)
- UFW reset conditional (preserves existing rules when UFW active)
- NVM installed under $SUDO_USER instead of root
- PasswordAuthentication decided at runtime via authorized_keys inspection
- Docker + UFW iptables bypass via DOCKER-USER chain
- Inactive swapfile activation without recreation
- hostname -I fallback to curl ipinfo.io/ip
- clear command guarded with TTY check

### Added
- retry() with exponential backoff for apt operations
- Internet connectivity check at startup
- trap cleanup EXIT for error diagnostics
- Disk space warning below 5 GB

---

## Release Notes

### v3.2.0 Summary

**Production-ready hardening with critical security fixes.**

This release addresses all critical security vulnerabilities identified in code review:
- Race conditions in iptables management
- MITM attack vector in NVM installation
- Path traversal attacks in fail2ban
- Configuration corruption in Docker daemon.json
- SSH config overwrites by cloud-init

**Key improvements:**
- True idempotency (safe to run multiple times)
- Nginx installation now optional (Docker containerized nginx use case)
- Comprehensive test coverage (unit + integration)
- Deep merge for all JSON configurations

**Breaking changes:** None — fully backward compatible.

**Upgrade path:** Simply run the new script — all changes are additive and idempotent.
