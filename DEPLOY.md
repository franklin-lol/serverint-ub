# ServerInit — Deploy Reference

Quick reference for all launch modes. Full docs: [README.md](README.md)

---

## Interactive (default)

```bash
curl -fsSL https://raw.githubusercontent.com/franklin-lol/serverint-ub/main/serverinit.sh \
  -o /tmp/serverinit.sh && sudo bash /tmp/serverinit.sh
```

---

## CI / Unattended (`--ci`)

| Variable | Values | Default |
|---|---|---|
| `SI_STACK` | `1` Docker · `2` Node.js · `3` Python · `4` Base | `1` |
| `SI_SEC` | `1` Basic · `2` Full | `1` |
| `SI_SSH_PORT` | `1024–65535` | `22` |

### Recipes

```bash
# Docker + basic security
SI_STACK=1 SI_SEC=1 sudo bash serverinit.sh --ci

# Docker + full security, port 2222
SI_STACK=1 SI_SEC=2 SI_SSH_PORT=2222 sudo bash serverinit.sh --ci

# Node.js + full security
SI_STACK=2 SI_SEC=2 sudo bash serverinit.sh --ci

# Python + basic security
SI_STACK=3 SI_SEC=1 sudo bash serverinit.sh --ci

# Hardening only (no app stack)
SI_STACK=4 SI_SEC=2 sudo bash serverinit.sh --ci
```

### Ansible

```yaml
- name: Download ServerInit
  get_url:
    url: https://raw.githubusercontent.com/franklin-lol/serverint-ub/main/serverinit.sh
    dest: /tmp/serverinit.sh
    mode: '0755'

- name: Run ServerInit (CI mode)
  shell: bash /tmp/serverinit.sh --ci
  environment:
    SI_STACK: "1"
    SI_SEC:   "2"
    SI_SSH_PORT: "2222"
  args:
    executable: /bin/bash
```

### cloud-init (user-data)

```yaml
#cloud-config
runcmd:
  - curl -fsSL https://raw.githubusercontent.com/franklin-lol/serverint-ub/main/serverinit.sh -o /tmp/si.sh
  - SI_STACK=1 SI_SEC=2 SI_SSH_PORT=2222 bash /tmp/si.sh --ci
  - rm -f /tmp/si.sh
```

### Terraform (remote-exec)

```hcl
provisioner "remote-exec" {
  inline = [
    "curl -fsSL https://raw.githubusercontent.com/franklin-lol/serverint-ub/main/serverinit.sh -o /tmp/si.sh",
    "SI_STACK=1 SI_SEC=2 SI_SSH_PORT=2222 sudo bash /tmp/si.sh --ci",
    "rm -f /tmp/si.sh"
  ]
}
```

---

## After Install

```bash
cat /root/serverinit_report.txt   # full report
ufw status verbose                 # firewall rules
sysctl vm.swappiness               # kernel tuning
fail2ban-client status sshd        # fail2ban (full mode only)
iptables -L DOCKER-USER -n         # Docker chain (Docker stack only)
sudo reboot                        # apply kernel params
```

---

*[Franklin](https://franklin-sys.vercel.app) · MIT*
