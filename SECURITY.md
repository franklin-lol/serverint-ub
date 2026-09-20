# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 3.2.x   | ✅ Full support    |
| 3.1.x   | ⚠️ Security fixes only |
| 3.0.x   | ⚠️ Security fixes only |
| < 3.0   | ❌ Not supported   |

## Security Features

### v3.2.0 Hardening

**Critical fixes implemented:**

1. **Race Condition Protection**
   - iptables DOCKER-USER modifications use flock locking
   - Prevents concurrent script execution conflicts

2. **Supply Chain Security**
   - NVM installation with SHA256 checksum verification
   - Prevents MITM attacks during package downloads

3. **Path Traversal Protection**
   - fail2ban scanbait jail catches `/../`, `%2e%2e`, encoded variants
   - Protects against reconnaissance attacks

4. **Configuration Integrity**
   - Docker daemon.json uses deep merge (preserves nested configs)
   - SSH config protected via DPkg hook (survives cloud-init regeneration)

5. **Audit Trail**
   - auditd monitors: docker.sock, ~/.ssh, passwd/shadow/sudoers
   - rkhunter baseline + scheduled scans

### Defense in Depth

**Network Layer:**
- UFW deny-all incoming (whitelist SSH/80/443)
- fail2ban (3 attempts → 24h ban)
- SSH rate limiting
- Docker DOCKER-USER iptables isolation

**SSH Hardening:**
- Custom port (1024-65535)
- Password auth auto-disabled when keys present
- MaxAuthTries=3, LoginGraceTime=20s
- Root login disabled (when other sudo user exists)
- Drop-in config (99-serverinit.conf) with DPkg persistence

**Kernel Tuning:**
- SYN flood protection (tcp_syncookies)
- Anti-spoofing (rp_filter=1)
- ICMP redirect blocking
- Martian packet logging

**System Integrity:**
- Unattended security updates (Debian/Ubuntu + Docker repos)
- Shared memory protection (noexec,nosuid,nodev)
- File descriptor limits: 1048576
- Minimal attack surface (base-only mode available)

## Reporting Vulnerabilities

**DO NOT open public issues for security vulnerabilities.**

Contact: franklin-sys.vercel.app

**Response timeline:**
- Acknowledgment: 48 hours
- Initial assessment: 7 days
- Fix timeline: Depends on severity

**Severity levels:**
- **Critical**: Remote code execution, privilege escalation → 48h fix target
- **High**: Authentication bypass, data exposure → 7 day fix target
- **Medium**: DoS, information disclosure → 30 day fix target
- **Low**: Best practice violations → Next release

## Security Best Practices

### After Installation

1. **Verify SSH access on new port BEFORE closing current session**
   ```bash
   # In a NEW terminal
   ssh -p YOUR_NEW_PORT user@server
   ```

2. **Deploy SSH keys, disable password auth**
   ```bash
   ssh-copy-id -p PORT user@server
   # Then on server:
   sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
   systemctl restart ssh
   ```

3. **Review fail2ban status**
   ```bash
   fail2ban-client status sshd
   fail2ban-client status nginx-scanbait
   ```

4. **Check auditd rules**
   ```bash
   auditctl -l
   ```

5. **Review rkhunter baseline**
   ```bash
   cat /root/rkhunter_report.log
   ```

### For Docker Stack

**Open container ports safely:**
```bash
# BOTH UFW and iptables required
ufw allow 8080/tcp
iptables -I DOCKER-USER -p tcp --dport 8080 -j ACCEPT
netfilter-persistent save
```

**Verify DOCKER-USER protection:**
```bash
iptables -L DOCKER-USER -n --line-numbers
# Should show: loopback, established, SSH/80/443, then DROP
```

### Regular Maintenance

```bash
# Check for failed login attempts
journalctl -u ssh | grep -i failed

# Review fail2ban bans
fail2ban-client banned

# Update rkhunter database
rkhunter --update && rkhunter --propupd

# Check unattended-upgrades log
cat /var/log/unattended-upgrades/unattended-upgrades.log
```

## Known Limitations

1. **Cloud-init race conditions** — In rare cases cloud-init may regenerate configs during boot. The DPkg hook mitigates this but doesn't cover all scenarios.

2. **Docker iptables bypass** — Requires manual port opening in both UFW and DOCKER-USER. Documented but easily forgotten.

3. **SSH lockout risk** — Changing SSH port without verifying cloud provider firewall can lock you out. Always check provider firewall first.

4. **Swap on small disks** — Swap disabled when <5GB free. Low-memory VPS may experience OOM without swap.

## Compliance Notes

**ServerInit helps meet but does not guarantee compliance with:**
- CIS Benchmark (partial coverage)
- PCI DSS (network segmentation, logging)
- SOC 2 (audit trails, access controls)
- GDPR (infrastructure security controls)

**Out of scope:**
- Application-level security (WAF, input validation, etc.)
- Data encryption at rest
- Intrusion detection systems (IDS/IPS)
- Log aggregation/SIEM

For production compliance, layer additional controls on top of ServerInit baseline.
