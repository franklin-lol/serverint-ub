# ServerInit

[![Shell](https://img.shields.io/badge/shell-bash_5%2B-blue)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%20%7C%20Debian-orange)](https://ubuntu.com/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

> Universal production server initialization script for Ubuntu and Debian.  
> Replaces hours of routine configuration with three questions and five minutes of execution.

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
| Network | Internet access for package downloads |
| Disk | Minimum 5 GB free |

### Installation

**Recommended method — download, then execute:**

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

### What the Script Does

The script runs in four sequential phases.

**Phase 0 — System Detection**  
Reads RAM, CPU, disk, OS version, and IP address. Calculates the optimal swap size automatically based on available RAM.

**Phase 1 — Configuration (Three Questions)**

| Question | Options |
|---|---|
| Stack | Docker + Compose + Nginx · Node.js (NVM) + PM2 + Nginx · Python 3 + pip + Nginx · Base utilities only |
| Security level | Basic (UFW + swap) · Full (+ fail2ban + SSH hardening + auto-updates) |
| SSH port | Custom port 1024–65535, or keep default 22 (Full security only) |

**Phase 2 — Base System**
- Full system update (`apt upgrade`)
- Essential utilities: `htop`, `nano`, `vim`, `curl`, `wget`, `git`, `jq`, `ncdu`, `iotop`, and more
- Swap file creation with `fallocate` (dd fallback for incompatible filesystems)
- Kernel tuning via `sysctl`: `somaxconn=65535`, `tcp_syncookies=1`, TCP buffer tuning, SYN flood protection
- File descriptor limits raised to 1,048,576

**Phase 3 — Security**
- UFW firewall: default deny incoming, allow SSH / 80 / 443
- **Full mode additionally:**
  - fail2ban: SSH rate-limiting (3 attempts, 24-hour ban)
  - SSH hardening: custom port, `MaxAuthTries 3`, `LoginGraceTime 20`, `X11Forwarding no`, `MaxStartups 10:30:60`
  - Anti-lockout protection: root login disabled only when another sudo user is detected
  - Unattended security upgrades (security packages only, no automatic reboot)
  - Shared memory protection (`/dev/shm` with `noexec,nosuid,nodev`)

**Phase 4 — Stack**

| Stack | Components installed |
|---|---|
| Docker | Docker CE, Docker Compose Plugin, Nginx, daemon.json tuning (log rotation 10 MB × 3, ulimits) |
| Node.js | NVM, Node.js LTS, PM2 with systemd startup, Nginx, system-wide NVM profile |
| Python 3 | python3, pip, venv, setuptools, wheel, pipx, Nginx |
| Base | No additional stack — base utilities and security only |

**Output**
- Full installation log: `/root/serverinit_YYYYMMDD_HHMMSS.log`
- Summary report with next steps: `/root/serverinit_report.txt`

### Security Design Decisions

**PasswordAuthentication stays enabled.** The script does not know whether SSH keys have been deployed. Disabling password authentication without keys causes immediate lockout. To disable manually after deploying keys:

```bash
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
```

**SSH config is validated before applying.** `sshd -t` runs before every `systemctl restart sshd`. On failure, the original config is restored from a timestamped backup.

**Root login is conditional.** The script checks for existing sudo-group members before disabling root login. On a fresh server with no other users, root access is preserved.

### Testing Across Environments

**Local VM (recommended before production use):**

```bash
# Create a throwaway VM
multipass launch 22.04 --name test-server
multipass shell test-server
curl -fsSL <URL> -o /tmp/serverinit.sh && sudo bash /tmp/serverinit.sh
```

**Docker container (functional test only — no systemd):**

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

**Verify Docker:**

```bash
docker run --rm hello-world
docker compose version
```

### Post-Installation Checklist

- [ ] Test SSH access on the new port before closing the current session
- [ ] Deploy SSH public keys, then disable password authentication
- [ ] Configure DNS and obtain SSL certificates: `certbot --nginx -d yourdomain.com`
- [ ] Open additional application ports: `ufw allow PORT/tcp`
- [ ] Review the report: `cat /root/serverinit_report.txt`
- [ ] Reboot to apply kernel parameters and limits: `sudo reboot`

---

<a name="russian"></a>
## Русский

### Описание

ServerInit автоматизирует полную настройку нового сервера на Ubuntu или Debian: обновление системы, хардинг ядра, файрвол, и установку рабочего стека. Результат — production-ready окружение с задокументированным журналом изменений.

### Требования

| Требование | Детали |
|---|---|
| ОС | Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12 |
| Привилегии | Root (`sudo`) |
| Терминал | **Требуется интерактивный TTY** — запуск через pipe не поддерживается |
| Сеть | Доступ в интернет для загрузки пакетов |
| Диск | Минимум 5 GB свободного места |

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
> При прямом pipe из `curl` stdin терминала занят потоком данных — вызовы `read` возвращают пустую строку немедленно, вызывая бесконечный цикл валидации.  
> Всегда сначала скачивайте скрипт, затем запускайте интерактивно.

### Что делает скрипт

Скрипт выполняется в четырёх последовательных фазах.

**Фаза 0 — Определение системы**  
Считывает RAM, CPU, диск, версию ОС и IP-адрес. Автоматически рассчитывает оптимальный размер swap по объёму RAM.

**Фаза 1 — Конфигурация (три вопроса)**

| Вопрос | Варианты |
|---|---|
| Стек | Docker + Compose + Nginx · Node.js (NVM) + PM2 + Nginx · Python 3 + pip + Nginx · Только базовые утилиты |
| Уровень безопасности | Базовый (UFW + swap) · Полный (+ fail2ban + SSH hardening + автообновления) |
| SSH порт | Нестандартный порт 1024–65535 или оставить 22 (только в полном режиме) |

**Фаза 2 — Базовая система**
- Полное обновление системы (`apt upgrade`)
- Базовые утилиты: `htop`, `nano`, `vim`, `curl`, `wget`, `git`, `jq`, `ncdu`, `iotop` и другие
- Создание swap-файла через `fallocate` (fallback на `dd` для несовместимых файловых систем)
- Оптимизация ядра через `sysctl`: `somaxconn=65535`, `tcp_syncookies=1`, тюнинг TCP-буферов, защита от SYN flood
- Лимиты файловых дескрипторов увеличены до 1 048 576

**Фаза 3 — Безопасность**
- UFW: запретить входящие по умолчанию, разрешить SSH / 80 / 443
- **Только в полном режиме:**
  - fail2ban: rate-limit SSH (3 попытки, бан 24 часа)
  - SSH hardening: нестандартный порт, `MaxAuthTries 3`, `LoginGraceTime 20`, `X11Forwarding no`, `MaxStartups 10:30:60`
  - Защита от блокировки: root login отключается только при наличии другого sudo-пользователя
  - Автообновления безопасности (только security-пакеты, без автоперезагрузки)
  - Защита shared memory (`/dev/shm` с флагами `noexec,nosuid,nodev`)

**Фаза 4 — Стек**

| Стек | Что устанавливается |
|---|---|
| Docker | Docker CE, Docker Compose Plugin, Nginx, daemon.json (ротация логов 10 МБ × 3, ulimits) |
| Node.js | NVM, Node.js LTS, PM2 с автозапуском через systemd, Nginx, профиль NVM для всей системы |
| Python 3 | python3, pip, venv, setuptools, wheel, pipx, Nginx |
| Базовый | Дополнительный стек не устанавливается |

**Результат**
- Полный лог установки: `/root/serverinit_YYYYMMDD_HHMMSS.log`
- Отчёт с итогами и следующими шагами: `/root/serverinit_report.txt`

### Проектные решения по безопасности

**PasswordAuthentication остаётся включённым.** Скрипт не знает, развёрнуты ли SSH-ключи. Отключение парольной аутентификации без ключей немедленно заблокирует доступ. Чтобы отключить вручную после настройки ключей:

```bash
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
```

**SSH-конфиг валидируется перед применением.** Перед каждым `systemctl restart sshd` выполняется `sshd -t`. При ошибке валидации оригинальный конфиг восстанавливается из бэкапа с временной меткой.

**Root login — условно.** Скрипт проверяет наличие других членов группы sudo перед отключением root-входа. На чистом сервере без других пользователей root-доступ сохраняется.

### Тестирование

**Локальная VM (рекомендуется перед production):**

```bash
# Создать тестовую VM
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

**Проверка Docker:**

```bash
docker run --rm hello-world
docker compose version
```

### Чеклист после установки

- [ ] Проверить SSH-доступ на новом порту, не закрывая текущую сессию
- [ ] Развернуть SSH-ключи, затем отключить парольную аутентификацию
- [ ] Настроить DNS и получить SSL-сертификат: `certbot --nginx -d yourdomain.com`
- [ ] Открыть порты приложений: `ufw allow PORT/tcp`
- [ ] Просмотреть отчёт: `cat /root/serverinit_report.txt`
- [ ] Перезагрузить сервер для применения параметров ядра: `sudo reboot`

---

### Changelog

**v2.0.0**
- Fixed: infinite input loop when launched via `curl|bash` — added TTY detection and `/dev/tty` readability check
- Fixed: SSH config rollback used wrong backup filename (new timestamp vs saved)
- Fixed: shared memory path auto-detection (`/dev/shm` vs legacy `/run/shm`)
- Fixed: Docker `daemon.json` no longer overwrites existing configuration
- Fixed: `gpg --batch --yes` flags added for non-interactive key import
- Added: `ask()` helper function for reliable interactive input across all environments
- Added: `AUTH_LOG` auto-detection for Ubuntu 22.04+ (journal vs auth.log)
- Changed: install command changed to download-first pattern
- Changed: NVM and Node.js versions extracted to top-level variables
- Improved: phase numbering corrected (1/4 through 4/4)
- Improved: `fail2ban` logpath dynamically set based on system configuration

---

*Created by Franklin · MIT License*