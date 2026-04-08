# ServerInit

[![Shell](https://img.shields.io/badge/shell-bash_5%2B-blue)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%20%7C%20Debian-orange)](https://ubuntu.com/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

> Universal production server initialization script for Ubuntu and Debian.  
> Replaces hours of routine setup with three questions and five minutes of execution.

**Language / Язык:** [English](#english) · [Русский](#russian)

---

<a name="english"></a>
## English

### Overview

ServerInit automates the complete provisioning of a fresh Ubuntu or Debian server: system hardening, kernel tuning, firewall setup, and stack installation. The result is a production-ready environment with a documented audit trail.

### Requirements

| Requirement | Details |
|---|---|
| OS | Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12 |
| Privileges | Root (`sudo`) |
| Terminal | **Interactive TTY required** — do not run via unattended pipe |
| Network | Internet access (checked automatically at startup) |
| Disk | Minimum 5 GB free (checked with a warning) |

### Installation

**Recommended — download, then execute:**

```bash
curl -fsSL https://raw.githubusercontent.com/franklin-lol/serverint-ub/main/serverinit.sh \
  -o /tmp/serverinit.sh && sudo bash /tmp/serverinit.sh
```

**Local execution:**

```bash
sudo bash serverinit.sh
```

> **Why not `curl | bash`?**  
> The script requires interactive keyboard input for three configuration questions.  
> Piping directly from `curl` consumes the terminal's stdin, making `read` calls fail silently.  
> Always download the script first, then execute it interactively.

---

### What the Script Does

The script runs in four sequential phases.

**Phase 0 — System Detection**  
Reads RAM, CPU, disk, OS version, and IP address. IP detection falls back to `ipinfo.io` on cloud-init images where `hostname -I` returns empty. Calculates the optimal swap size automatically. Aborts immediately if there is no internet connection.

**Phase 1 — Configuration (Three Questions)**

| Question | Options |
|---|---|
| Stack | Docker + Compose + Nginx · Node.js (NVM) + PM2 + Nginx · Python 3 + pip + Nginx · Base utilities only |
| Security level | Basic (UFW + swap) · Full (+ fail2ban + SSH hardening + auto-updates) |
| SSH port | Custom port 1024–65535, or keep default 22 (Full security only) |

**Phase 2 — Base System**

- Full system update (`apt upgrade`) with automatic retry on network failures
- Essential utilities: `htop`, `nano`, `vim`, `curl`, `wget`, `git`, `jq`, `ncdu`, `iotop`, and more
- Swap file creation with `fallocate` (dd fallback for incompatible filesystems). If `/swapfile` already exists but is inactive, it is activated without recreation.
- Kernel tuning via `sysctl`: `somaxconn=65535`, `tcp_syncookies=1`, TCP buffer tuning, SYN flood protection
- File descriptor limits raised to 1,048,576

**Phase 3 — Security**

- UFW firewall: default deny incoming, allow SSH / 80 / 443. Existing active UFW rules are preserved — rules are added on top rather than reset.
- **Full mode additionally:**
  - fail2ban: SSH rate-limiting (3 attempts, 24-hour ban)
  - SSH hardening: custom port, `MaxAuthTries 3`, `LoginGraceTime 20`, `X11Forwarding no`, `MaxStartups 10:30:60`
  - Anti-lockout protection: root login disabled only when another sudo user is detected
  - Smart `PasswordAuthentication`: automatically disabled if `authorized_keys` files are found; kept enabled otherwise with an explicit warning
  - Unattended security upgrades (security packages only, no automatic reboot)
  - Shared memory protection (`/dev/shm` with `noexec,nosuid,nodev`)

**Phase 4 — Stack**

| Stack | Components installed |
|---|---|
| Docker | Docker CE, Docker Compose Plugin, Nginx, `daemon.json` tuning (log rotation 10 MB × 3, ulimits), iptables DOCKER-USER chain hardening |
| Node.js | NVM, Node.js LTS, PM2 with systemd startup — all installed under the invoking user (`$SUDO_USER`), not root |
| Python 3 | python3, pip, venv, setuptools, wheel, pipx, Nginx |
| Base | No additional stack — base utilities and security only |

**Output**

- Full installation log: `/root/serverinit_YYYYMMDD_HHMMSS.log`
- Summary report with next steps: `/root/serverinit_report.txt`
- On any failure: exit code, last log lines, and the log path are printed to stderr

---

### Security Design Decisions

**SSH service name is portable.** The script uses a `restart_ssh()` function that tries `systemctl restart ssh`, then `sshd`, then the legacy `service` command. Ubuntu and Debian name the service differently; a hardcoded `sshd` silently fails on half of Debian installs.

**`PasswordAuthentication` is decided at runtime.** The script inspects `authorized_keys` files across all home directories. If SSH keys are already deployed, password authentication is disabled automatically. If not, it stays enabled with a prominent warning and the exact commands to disable it after key deployment.

**SSH config is validated before applying.** `sshd -t` runs before every restart. On failure, the original config is restored from a timestamped backup.

**Root login is conditional.** The script checks for existing sudo-group members before disabling root login. On a fresh server with no other users, root access is preserved.

**UFW reset is conditional.** If UFW is already active (existing custom rules), the script adds new rules on top rather than resetting. A `--force reset` only runs on a clean UFW state.

**Docker + UFW iptables bypass is addressed.** Docker inserts rules directly into the kernel's `iptables` and bypasses UFW entirely when containers publish ports. The script inserts a `DROP` rule into the `DOCKER-USER` chain and then explicitly allows SSH/80/443, so published container ports are not reachable from the internet unless you deliberately open them. Rules are persisted via `iptables-persistent`.

**NVM is installed under the real user, not root.** When invoked via `sudo`, `$SUDO_USER` contains the invoking username. NVM, Node.js, and PM2 are installed into that user's home directory. The system-wide `/etc/profile.d/nvm.sh` points to the correct path.

**`apt` operations use retry with exponential backoff.** Up to 3 attempts, starting at 5 s delay, doubling each time. Covers transient package mirror failures common on newly provisioned VPS instances.

**Error handling via `trap`.** `trap cleanup EXIT` catches any `set -e` abort and prints the exit code, the last 5 lines of the log, and the log path. The server is never left in an unknown state without a hint.

---

### Testing Across Environments

**Local VM (recommended before production use):**

```bash
multipass launch 22.04 --name test-server
multipass shell test-server
curl -fsSL <URL> -o /tmp/serverinit.sh && sudo bash /tmp/serverinit.sh
```

**Docker container (functional test — no systemd):**

```bash
docker run -it --rm ubuntu:22.04 bash
apt-get update -qq && apt-get install -y -qq curl sudo
# Script will fail at systemctl calls — expected in containers
```

**Verify UFW rules:**

```bash
ufw status verbose
```

**Verify sysctl changes:**

```bash
sysctl net.core.somaxconn
sysctl vm.swappiness
```

**Verify fail2ban (full mode):**

```bash
fail2ban-client status sshd
```

**Verify Docker + iptables:**

```bash
docker run --rm hello-world
iptables -L DOCKER-USER -n --line-numbers
```

---

### Post-Installation Checklist

- [ ] Test SSH access on the new port before closing the current session
- [ ] If password auth is still enabled: deploy SSH keys, then disable it per the report instructions
- [ ] Configure DNS and obtain SSL certificates: `certbot --nginx -d yourdomain.com`
- [ ] For Docker: open additional ports in **both** UFW and iptables DOCKER-USER:  
  ```bash
  ufw allow PORT/tcp
  iptables -I DOCKER-USER -p tcp --dport PORT -j ACCEPT
  netfilter-persistent save
  ```
- [ ] Review the report: `cat /root/serverinit_report.txt`
- [ ] Reboot to apply kernel parameters and limits: `sudo reboot`

---

<a name="russian"></a>
## Русский

### Описание

ServerInit автоматизирует полную настройку нового сервера на Ubuntu или Debian: обновление системы, хардинг ядра, файрвол, установку рабочего стека. Результат — production-ready окружение с задокументированным журналом изменений.

### Требования

| Требование | Детали |
|---|---|
| ОС | Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12 |
| Привилегии | Root (`sudo`) |
| Терминал | **Требуется интерактивный TTY** — запуск через pipe не поддерживается |
| Сеть | Доступ в интернет (проверяется автоматически при старте) |
| Диск | Минимум 5 GB свободного места (проверяется с предупреждением) |

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

> **Почему не `curl | bash`?**  
> Скрипт требует интерактивного ввода для трёх вопросов конфигурации.  
> При прямом pipe из `curl` stdin терминала занят потоком данных — вызовы `read` возвращают пустую строку, что приводит к бесконечному циклу валидации.  
> Всегда сначала скачивайте скрипт, затем запускайте интерактивно.

---

### Что делает скрипт

Скрипт выполняется в четырёх последовательных фазах.

**Фаза 0 — Определение системы**  
Считывает RAM, CPU, диск, версию ОС и IP-адрес. Если `hostname -I` возвращает пустую строку (cloud-init), IP получается через `ipinfo.io`. Автоматически рассчитывает оптимальный размер swap. При отсутствии интернета завершается немедленно.

**Фаза 1 — Конфигурация (три вопроса)**

| Вопрос | Варианты |
|---|---|
| Стек | Docker + Compose + Nginx · Node.js (NVM) + PM2 + Nginx · Python 3 + pip + Nginx · Только базовые утилиты |
| Уровень безопасности | Базовый (UFW + swap) · Полный (+ fail2ban + SSH hardening + автообновления) |
| SSH порт | Нестандартный порт 1024–65535 или оставить 22 (только в полном режиме) |

**Фаза 2 — Базовая система**

- Полное обновление системы (`apt upgrade`) с автоматическим retry при сетевых ошибках
- Базовые утилиты: `htop`, `nano`, `vim`, `curl`, `wget`, `git`, `jq`, `ncdu`, `iotop` и другие
- Создание swap через `fallocate` (fallback на `dd`). Если `/swapfile` уже существует, но не активен — активируется без пересоздания.
- Оптимизация ядра через `sysctl`: `somaxconn=65535`, `tcp_syncookies=1`, тюнинг TCP-буферов, защита от SYN flood
- Лимиты файловых дескрипторов увеличены до 1 048 576

**Фаза 3 — Безопасность**

- UFW: запрет входящих по умолчанию, разрешить SSH / 80 / 443. Если UFW уже активен — правила добавляются поверх существующих без сброса.
- **Только в полном режиме:**
  - fail2ban: rate-limit SSH (3 попытки, бан 24 часа)
  - SSH hardening: нестандартный порт, `MaxAuthTries 3`, `LoginGraceTime 20`, `X11Forwarding no`, `MaxStartups 10:30:60`
  - Защита от блокировки: root login отключается только при наличии другого sudo-пользователя
  - Умный `PasswordAuthentication`: автоматически отключается если найдены `authorized_keys`; остаётся включённым с предупреждением если ключи не найдены
  - Автообновления безопасности (только security-пакеты, без автоперезагрузки)
  - Защита shared memory (`/dev/shm` с флагами `noexec,nosuid,nodev`)

**Фаза 4 — Стек**

| Стек | Что устанавливается |
|---|---|
| Docker | Docker CE, Docker Compose Plugin, Nginx, `daemon.json` (ротация логов 10 МБ × 3, ulimits), защита цепочки iptables DOCKER-USER |
| Node.js | NVM, Node.js LTS, PM2 с автозапуском через systemd — всё устанавливается от имени вызывающего пользователя (`$SUDO_USER`), а не root |
| Python 3 | python3, pip, venv, setuptools, wheel, pipx, Nginx |
| Базовый | Дополнительный стек не устанавливается |

**Результат**

- Полный лог установки: `/root/serverinit_YYYYMMDD_HHMMSS.log`
- Отчёт с итогами и следующими шагами: `/root/serverinit_report.txt`
- При любой ошибке: код выхода, последние строки лога и путь к логу выводятся в stderr

---

### Проектные решения по безопасности

**Перезапуск SSH — переносимый.** Используется функция `restart_ssh()`, которая последовательно пробует `systemctl restart ssh`, затем `sshd`, затем legacy-команду `service`. Ubuntu и Debian называют сервис по-разному; хардкод `sshd` молча падает на половине Debian-инсталляций.

**`PasswordAuthentication` определяется в рантайме.** Скрипт проверяет наличие `authorized_keys` во всех домашних директориях. Если SSH-ключи уже задеплоены — парольная аутентификация отключается автоматически. Если нет — остаётся включённой с явным предупреждением и командами для отключения после деплоя ключей.

**SSH-конфиг валидируется перед применением.** `sshd -t` выполняется перед каждым перезапуском. При ошибке конфиг восстанавливается из бэкапа с временной меткой.

**Root login — условно.** Скрипт проверяет наличие других членов группы sudo перед отключением root-входа. На чистом сервере без других пользователей root-доступ сохраняется.

**UFW reset — условный.** Если UFW уже активен (есть кастомные правила), скрипт добавляет новые правила поверх. `--force reset` выполняется только на чистом UFW.

**Docker + UFW: проблема iptables-bypass решена.** Docker вставляет правила напрямую в ядро iptables, полностью обходя UFW при публикации портов контейнеров. Скрипт вставляет DROP-правило в цепочку DOCKER-USER и явно разрешает SSH/80/443, так что опубликованные порты контейнеров недоступны из интернета пока не будут явно открыты. Правила сохраняются через `iptables-persistent`.

**NVM устанавливается под реального пользователя, не root.** При вызове через `sudo` в `$SUDO_USER` содержится имя вызывающего пользователя. NVM, Node.js и PM2 устанавливаются в домашнюю директорию этого пользователя. Системный `/etc/profile.d/nvm.sh` указывает на правильный путь.

**Операции `apt` используют retry с экспоненциальным backoff.** До 3 попыток, начиная с задержки 5 с с удвоением. Покрывает временные сбои зеркал пакетов, типичные для только что поднятых VPS.

**Обработка ошибок через `trap`.** `trap cleanup EXIT` перехватывает любой abort от `set -e` и печатает код выхода, последние 5 строк лога и путь к логу. Сервер никогда не остаётся в неизвестном состоянии без подсказки.

---

### Тестирование

**Локальная VM (рекомендуется перед production):**

```bash
multipass launch 22.04 --name test-server
multipass shell test-server
curl -fsSL <URL> -o /tmp/serverinit.sh && sudo bash /tmp/serverinit.sh
```

**Docker-контейнер (только функциональный тест — без systemd):**

```bash
docker run -it --rm ubuntu:22.04 bash
apt-get update -qq && apt-get install -y -qq curl sudo
# Скрипт завершится ошибкой на командах systemctl — ожидаемое поведение
```

**Проверка UFW:**

```bash
ufw status verbose
```

**Проверка sysctl:**

```bash
sysctl net.core.somaxconn
sysctl vm.swappiness
```

**Проверка fail2ban (полный режим):**

```bash
fail2ban-client status sshd
```

**Проверка Docker + iptables:**

```bash
docker run --rm hello-world
iptables -L DOCKER-USER -n --line-numbers
```

---

### Чеклист после установки

- [ ] Проверить SSH-доступ на новом порту, не закрывая текущую сессию
- [ ] Если парольный вход оставлен: задеплоить SSH-ключи, затем отключить пароль по инструкции из отчёта
- [ ] Настроить DNS и получить SSL-сертификат: `certbot --nginx -d yourdomain.com`
- [ ] Для Docker: открывать порты **одновременно** в UFW и iptables DOCKER-USER:  
  ```bash
  ufw allow PORT/tcp
  iptables -I DOCKER-USER -p tcp --dport PORT -j ACCEPT
  netfilter-persistent save
  ```
- [ ] Просмотреть отчёт: `cat /root/serverinit_report.txt`
- [ ] Перезагрузить сервер для применения параметров ядра: `sudo reboot`

---

### Changelog

**v3.0.0**
- Fixed: `systemctl restart sshd` replaced with portable `restart_ssh()` (tries `ssh`, `sshd`, legacy `service`)
- Fixed: `ufw --force reset` now skipped if UFW is already active — custom rules are preserved
- Fixed: NVM and PM2 installed under `$SUDO_USER` instead of root; `/etc/profile.d/nvm.sh` points to the correct home directory
- Fixed: `PasswordAuthentication` is now decided at runtime by inspecting `authorized_keys` files instead of being hardcoded to `yes`
- Fixed: Docker + UFW iptables bypass addressed via DOCKER-USER chain DROP rule with `iptables-persistent` for persistence across reboots
- Fixed: `/swapfile` existing but inactive no longer triggers recreation — it is activated in place
- Fixed: `hostname -I` empty output now falls back to `curl ipinfo.io/ip`
- Fixed: bare `clear` replaced with `[[ -t 1 ]] && clear` to avoid breaking CI logs and terminal multiplexers
- Added: `retry()` wrapper with exponential backoff applied to all `apt` operations
- Added: internet connectivity check at startup (aborts early instead of failing mid-install)
- Added: `trap cleanup EXIT` — prints exit code and last log lines on any failure
- Added: disk space warning when free space is below 5 GB

---

*Created by Franklin · MIT License*