<div align="center">

```
  ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗
  ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗
  ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝
  ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗
  ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║
  ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝
            ██╗███╗   ██╗██╗████████╗
            ██║████╗  ██║██║╚══██╔══╝
          ██║██╔██╗ ██║██║   ██║
          ██║██║╚██╗██║██║   ██║
          ██║██║ ╚████║██║   ██║
          ╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝
```

**Universal production server setup — Ubuntu & Debian**

[![CI](https://github.com/franklin-lol/serverint-ub/actions/workflows/ci.yml/badge.svg)](https://github.com/franklin-lol/serverint-ub/actions/workflows/ci.yml)
[![ShellCheck](https://img.shields.io/badge/shellcheck-passing-brightgreen)](https://github.com/koalaman/shellcheck)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2020%2F22%2F24%20·%20Debian%2011%2F12-blue)](https://ubuntu.com/)
[![Shell](https://img.shields.io/badge/shell-bash%205%2B-blue)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-36%20passing-brightgreen)](tests/test_serverinit.sh)

</div>

> Replaces hours of repetitive server provisioning with **three questions and five minutes**.
> Interactive or fully unattended — your choice.

**Language / Язык:** [English](#english) · [Русский](#russian)

---

<a name="english"></a>

## ⚡ Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/franklin-lol/serverint-ub/main/serverinit.sh \
  -o /tmp/serverinit.sh && sudo bash /tmp/serverinit.sh
```

> **Why not `curl | bash`?** The script asks three configuration questions.
> Piping from curl consumes stdin — download first, then run.

**CI / Unattended deploy:**

```bash
# Docker + full security on port 2222 — zero interaction
SI_STACK=1 SI_SEC=2 SI_SSH_PORT=2222 sudo bash serverinit.sh --ci
```

---

## What It Does

Four phases, fully logged, error-trapped, idempotent where possible.

```
Phase 0 ── System detection    RAM · CPU · disk · OS · IP · swap calculation
Phase 1 ── Configuration       3 questions (or env vars in CI mode)
Phase 2 ── Base system         apt upgrade · utilities · swap · sysctl · fd limits
Phase 3 ── Security            UFW · fail2ban · SSH hardening · auto-updates
Phase 4 ── Stack               Docker / Node.js / Python / Base-only
```

### Stacks

| # | Stack | What gets installed |
|---|---|---|
| 1 | **Docker** | Docker CE, Compose Plugin, Nginx, daemon.json tuning, iptables DOCKER-USER hardening |
| 2 | **Node.js** | NVM, Node LTS 22, PM2 + systemd startup — under `$SUDO_USER`, not root |
| 3 | **Python 3** | python3, pip, venv, setuptools, wheel, pipx, Nginx |
| 4 | **Base only** | System hardening only, no application stack |

### Security Levels

| Level | Includes |
|---|---|
| **Basic** | UFW (deny-all + SSH/80/443), swap, sysctl tuning |
| **Full** | + fail2ban (3 attempts / 24h ban), SSH hardening, custom port, auto security updates, shared memory protection |

---

## CI / Unattended Mode

Pass `--ci` and control everything via environment variables:

| Variable | Default | Description |
|---|---|---|
| `SI_STACK` | `1` | Stack: `1`=Docker `2`=Node.js `3`=Python `4`=Base |
| `SI_SEC` | `1` | Security: `1`=Basic `2`=Full |
| `SI_SSH_PORT` | `22` | SSH port (1024–65535, only used when `SI_SEC=2`) |

**Examples:**

```bash
# Minimal — base stack + basic security
SI_STACK=4 SI_SEC=1 sudo bash serverinit.sh --ci

# Node.js + full hardening, default SSH port
SI_STACK=2 SI_SEC=2 sudo bash serverinit.sh --ci

# Docker + full security + custom SSH port
SI_STACK=1 SI_SEC=2 SI_SSH_PORT=2222 sudo bash serverinit.sh --ci
```

**Ansible / cloud-init example:**

```yaml
# cloud-init user-data
runcmd:
  - curl -fsSL https://raw.githubusercontent.com/franklin-lol/serverint-ub/main/serverinit.sh -o /tmp/si.sh
  - SI_STACK=1 SI_SEC=2 SI_SSH_PORT=2222 bash /tmp/si.sh --ci
```

```yaml
# Ansible task
- name: Run ServerInit
  shell: SI_STACK=1 SI_SEC=2 bash /tmp/serverinit.sh --ci
  environment:
    SI_STACK: "1"
    SI_SEC: "2"
    SI_SSH_PORT: "2222"
```

---

## Requirements

| | Details |
|---|---|
| OS | Ubuntu 20.04 / 22.04 / 24.04 · Debian 11 / 12 |
| Privileges | Root (`sudo`) |
| Terminal | Interactive TTY required for normal mode; not required with `--ci` |
| Network | Internet access (checked at startup, aborts early if absent) |
| Disk | Minimum 5 GB free (swap size is auto-reduced if space is tight) |

---

## Security Design

**SSH service name is portable.**
Uses `restart_ssh()` that tries `systemctl restart ssh`, then `sshd`, then legacy `service`. Ubuntu and Debian name the daemon differently; a hardcoded name silently fails on half of Debian installs.

**`PasswordAuthentication` is decided at runtime.**
Inspects `authorized_keys` across all home directories. Keys deployed → password auth disabled automatically. No keys → stays enabled with a prominent warning and exact commands to disable it later.

**SSH config is validated before applying.**
`sshd -t` runs before every restart. On failure, the original is restored from a timestamped backup.

**Root login is conditional.**
Counts sudo-group members first. On a fresh single-user server, root access is preserved rather than locking you out.

**UFW reset is conditional.**
If UFW is already active, rules are added on top — no reset, no wiping existing custom rules.

**Docker + UFW iptables bypass is addressed.**
Docker bypasses UFW by writing directly to iptables. The script inserts a `DROP` rule into the `DOCKER-USER` chain, then explicitly re-opens SSH/80/443, so container ports are only reachable when you deliberately allow them. Persisted via `iptables-persistent`.

**NVM is installed under the real user, not root.**
`$SUDO_USER` holds the invoking username. NVM, Node.js, and PM2 go into that user's home directory. `/etc/profile.d/nvm.sh` points to the right path.

**Swap respects available disk space.**
The RAM-based swap size is capped so at least 5 GB of free disk always remains after creation — no surprise "no space left" failures mid-install.

**`apt` uses retry with exponential backoff.**
Up to 3 attempts, 5 s → 10 s → 20 s delay. Covers transient mirror failures common on newly provisioned VPS instances.

**Error trap on every exit.**
`trap cleanup EXIT` catches any `set -e` abort, prints exit code + last 5 log lines + log path. The server is never left in an unknown state without a diagnostic.

---

## Testing

### Run tests locally

```bash
bash tests/test_serverinit.sh ./serverinit.sh
```

```
▶ Swap — RAM-based calculation (unlimited disk)
  ✔  RAM  512 MB → Swap 2 GB
  ✔  RAM 1024 MB → Swap 2 GB
  ✔  RAM 4096 MB → Swap 4 GB
  ✔  RAM 16 GB   → Swap 0 GB (no swap needed)

▶ Swap — Smart disk limiter
  ✔  Disk 7 GB, RAM 4 GB → Swap 2 GB (7-5=2, capped)
  ✔  Disk 5 GB, RAM 4 GB → Swap 0 GB (no room)
  ✔  Disk 3 GB, RAM 4 GB → Swap 0 GB (negative → 0)

▶ CI mode — env var validation
  ✔  Valid: STACK=1 SEC=1 PORT=22
  ✔  Invalid: STACK=5 rejected
  ✔  Invalid: PORT=80 rejected (<1024)

▶ SSH port — boundary validation
  ✔  Port 22 rejected (< 1024)
  ✔  Port 65536 rejected (> 65535)

▶ Script integrity
  ✔  Syntax check passed (bash -n)
  ✔  --ci flag present in script
  ✔  Disk limiter present

  Tests: 37  passed: 36  skipped: 1
  ✔ All tests passed
```

CI runs on every push via GitHub Actions — ShellCheck + full test suite on Ubuntu 22.04.

### Test on a VM before production

```bash
multipass launch 22.04 --name test-server
multipass shell test-server
curl -fsSL <URL> -o /tmp/serverinit.sh && sudo bash /tmp/serverinit.sh
```

### Verify after install

```bash
ufw status verbose                         # firewall rules
sysctl net.core.somaxconn vm.swappiness   # kernel tuning
fail2ban-client status sshd               # fail2ban (full mode)
iptables -L DOCKER-USER -n --line-numbers # Docker chain (Docker stack)
cat /root/serverinit_report.txt           # full install report
```

---

## Post-Installation Checklist

- [ ] Test SSH access on the new port **before** closing the current session
- [ ] If password auth is still enabled: deploy SSH keys, then disable per the report instructions
- [ ] Configure DNS and obtain SSL: `certbot --nginx -d yourdomain.com`
- [ ] For Docker — open additional ports in **both** UFW and iptables:
  ```bash
  ufw allow PORT/tcp
  iptables -I DOCKER-USER -p tcp --dport PORT -j ACCEPT
  netfilter-persistent save
  ```
- [ ] Review the full report: `cat /root/serverinit_report.txt`
- [ ] Reboot to apply kernel parameters: `sudo reboot`

---

## Output Files

| File | Description |
|---|---|
| `/root/serverinit_YYYYMMDD_HHMMSS.log` | Full installation log (last 5 kept, older auto-deleted) |
| `/root/serverinit_report.txt` | Summary with configuration and next steps |

---

## Changelog

**v3.1.0**
- Added: `--ci` unattended mode with `SI_STACK` / `SI_SEC` / `SI_SSH_PORT` env vars
- Added: Smart swap disk limiter — swap size auto-reduced to keep ≥5 GB free on disk
- Added: CI/CD pipeline (GitHub Actions) — ShellCheck + 36-test suite on push
- Added: `tests/test_serverinit.sh` covering swap logic, CI validation, SSH port rules, script integrity

**v3.0.0**
- Fixed: `systemctl restart sshd` → portable `restart_ssh()` (tries `ssh`, `sshd`, legacy `service`)
- Fixed: `ufw --force reset` skipped if UFW is already active — existing rules preserved
- Fixed: NVM and PM2 installed under `$SUDO_USER` instead of root
- Fixed: `PasswordAuthentication` decided at runtime via `authorized_keys` inspection
- Fixed: Docker + UFW iptables bypass addressed via DOCKER-USER chain + `iptables-persistent`
- Fixed: Existing inactive `/swapfile` activated in place, not recreated
- Fixed: `hostname -I` empty output falls back to `curl ipinfo.io/ip`
- Fixed: `clear` guarded with `[[ -t 1 ]]` — CI logs no longer broken
- Added: `retry()` with exponential backoff on all `apt` operations
- Added: Internet connectivity check at startup
- Added: `trap cleanup EXIT` — exit code + last log lines on any failure
- Added: Disk space warning below 5 GB

---

<a name="russian"></a>

## Русский

### Быстрый старт

```bash
curl -fsSL https://raw.githubusercontent.com/franklin-lol/serverint-ub/main/serverinit.sh \
  -o /tmp/serverinit.sh && sudo bash /tmp/serverinit.sh
```

**CI / автоматический деплой:**

```bash
SI_STACK=1 SI_SEC=2 SI_SSH_PORT=2222 sudo bash serverinit.sh --ci
```

### Описание

ServerInit автоматизирует полную настройку нового сервера на Ubuntu или Debian: обновление системы, хардинг ядра, файрвол, установку рабочего стека. Результат — production-ready окружение с задокументированным журналом изменений.

### Требования

| Требование | Детали |
|---|---|
| ОС | Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12 |
| Привилегии | Root (`sudo`) |
| Терминал | Интерактивный TTY для обычного режима; не нужен при `--ci` |
| Сеть | Доступ в интернет (проверяется при старте) |
| Диск | Минимум 5 GB (размер swap авто-уменьшается при нехватке места) |

### Установка

**Рекомендуемый способ — скачать, затем запустить:**

```bash
curl -fsSL https://raw.githubusercontent.com/franklin-lol/serverint-ub/main/serverinit.sh \
  -o /tmp/serverinit.sh && sudo bash /tmp/serverinit.sh
```

**Локальный запуск:**

```bash
sudo bash serverinit.sh
```

> **Почему не `curl | bash`?** Скрипт задаёт три вопроса. Pipe из curl занимает stdin — сначала скачай, потом запускай.

### CI / Массовый деплой

Флаг `--ci` отключает интерактив и читает параметры из переменных окружения:

| Переменная | По умолчанию | Описание |
|---|---|---|
| `SI_STACK` | `1` | Стек: `1`=Docker `2`=Node.js `3`=Python `4`=Базовый |
| `SI_SEC` | `1` | Безопасность: `1`=Базовый `2`=Полный |
| `SI_SSH_PORT` | `22` | SSH-порт (1024–65535, только при `SI_SEC=2`) |

```bash
# Docker + полная безопасность на порту 2222
SI_STACK=1 SI_SEC=2 SI_SSH_PORT=2222 sudo bash serverinit.sh --ci
```

### Что делает скрипт

**Фаза 0 — Определение системы**
Считывает RAM, CPU, диск, ОС, IP. При нехватке интернета завершается немедленно.
Swap рассчитывается автоматически с учётом доступного места на диске.

**Фаза 1 — Конфигурация**

| Вопрос | Варианты |
|---|---|
| Стек | Docker + Compose + Nginx · Node.js + PM2 + Nginx · Python 3 + pip + Nginx · Только утилиты |
| Безопасность | Базовый (UFW + swap) · Полный (+ fail2ban + SSH hardening + автообновления) |
| SSH порт | Нестандартный порт 1024–65535 или оставить 22 (только в полном режиме) |

**Фаза 2 — Базовая система**

- Полное обновление (`apt upgrade`) с автоматическим retry при сетевых ошибках
- Базовые утилиты: `htop`, `nano`, `vim`, `curl`, `wget`, `git`, `jq`, `ncdu`, `iotop` и другие
- Swap через `fallocate` (fallback на `dd`). Существующий неактивный файл — активируется без пересоздания
- Оптимизация ядра: `somaxconn=65535`, `tcp_syncookies=1`, тюнинг TCP, защита от SYN flood
- Лимиты файловых дескрипторов: 1 048 576

**Фаза 3 — Безопасность**

- UFW: запрет входящих, разрешить SSH/80/443. Если UFW уже активен — правила добавляются поверх, без сброса
- **Полный режим дополнительно:**
  - fail2ban: 3 попытки / бан 24 часа
  - SSH hardening: порт, `MaxAuthTries 3`, `LoginGraceTime 20`, `X11Forwarding no`
  - Защита от блокировки: root login отключается только при наличии другого sudo-пользователя
  - `PasswordAuthentication` — авто-решение по наличию `authorized_keys`
  - Автообновления безопасности (только security, без авто-ребута)
  - Защита `/dev/shm` (`noexec,nosuid,nodev`)

**Фаза 4 — Стек**

| Стек | Что устанавливается |
|---|---|
| Docker | Docker CE, Compose Plugin, Nginx, daemon.json, защита DOCKER-USER iptables |
| Node.js | NVM, Node LTS 22, PM2 + systemd — от имени `$SUDO_USER`, не root |
| Python 3 | python3, pip, venv, setuptools, wheel, pipx, Nginx |
| Базовый | Только хардинг, без стека |

### Тестирование

```bash
bash tests/test_serverinit.sh ./serverinit.sh
```

CI автоматически запускает ShellCheck + 36 тестов на каждый push.

**Проверки после установки:**

```bash
ufw status verbose
sysctl net.core.somaxconn vm.swappiness
fail2ban-client status sshd              # полный режим
iptables -L DOCKER-USER -n --line-numbers  # Docker стек
cat /root/serverinit_report.txt
```

### Чеклист после установки

- [ ] Проверить SSH-доступ на новом порту, не закрывая текущую сессию
- [ ] Если парольный вход оставлен: задеплоить SSH-ключи, затем отключить по инструкции из отчёта
- [ ] DNS + SSL: `certbot --nginx -d yourdomain.com`
- [ ] Docker: открывать порты одновременно в UFW **и** iptables DOCKER-USER:
  ```bash
  ufw allow PORT/tcp
  iptables -I DOCKER-USER -p tcp --dport PORT -j ACCEPT
  netfilter-persistent save
  ```
- [ ] Просмотреть отчёт: `cat /root/serverinit_report.txt`
- [ ] Перезагрузить сервер: `sudo reboot`

### Проектные решения

**Перезапуск SSH — переносимый.** `restart_ssh()` пробует `ssh`, `sshd`, legacy `service` по очереди. Ubuntu и Debian называют демон по-разному.

**`PasswordAuthentication` — рантайм-решение.** Проверяет `authorized_keys` во всех домашних директориях. Ключи есть → пароль отключается автоматически.

**SSH-конфиг валидируется.** `sshd -t` перед каждым перезапуском. При ошибке — откат на бэкап с временной меткой.

**Swap учитывает диск.** Размер ограничивается так, чтобы всегда оставалось ≥5 GB свободного места.

**Обработка ошибок через trap.** `trap cleanup EXIT` — код выхода, последние строки лога и путь к файлу при любом сбое.

---

*Created by [Franklin](https://franklin-sys.vercel.app) · MIT License*
