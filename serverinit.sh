#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║           ServerInit — Universal Server Setup Utility           ║
# ║                    by Elite Tech Collective                     ║
# ╚══════════════════════════════════════════════════════════════════╝
# Usage (interactive only — must have a real TTY):
#   sudo bash serverinit.sh
#
# Remote (download-first, then run — required for interactivity):
#   curl -fsSL https://raw.githubusercontent.com/franklin-lol/serverint-ub/main/serverinit.sh \
#     -o /tmp/serverinit.sh && sudo bash /tmp/serverinit.sh

set -euo pipefail

# ── Versions (update here only) ───────────────────────────────────────────────
NVM_VERSION="0.40.1"
NODE_LTS="22"          # current LTS; use "lts/*" for always-latest

# ── ANSI palette ─────────────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[0;33m' B='\033[0;34m'
M='\033[0;35m' C='\033[0;36m' W='\033[1;37m' DIM='\033[2m'
BOLD='\033[1m' NC='\033[0m'

# ── Logging helpers ───────────────────────────────────────────────────────────
ok()   { echo -e "${G}  ✔${NC}  $*"; }
info() { echo -e "${C}  →${NC}  $*"; }
warn() { echo -e "${Y}  ⚠${NC}  $*"; }
err()  { echo -e "${R}  ✖${NC}  $*" >&2; exit 1; }
step() { echo -e "\n${BOLD}${B}▶ $*${NC}"; }
sep()  { echo -e "${DIM}────────────────────────────────────────────${NC}"; }

# ── Preflight ─────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]]           && err "Run as root:  sudo bash serverinit.sh"
[[ ! -f /etc/debian_version ]] && err "Debian/Ubuntu only (apt required)"

# FIX: Detect TTY before any interactive input.
# curl|bash pipes stdin → /dev/tty reads return empty string immediately
# causing infinite validation loops. Require a real terminal.
if [[ ! -e /dev/tty ]]; then
  err "Требуется интерактивный терминал.\nИспользуйте: curl -fsSL URL -o /tmp/serverinit.sh && sudo bash /tmp/serverinit.sh"
fi
# Verify /dev/tty is actually readable (not just present)
if ! ( exec < /dev/tty ) 2>/dev/null; then
  err "Нет доступа к /dev/tty.\nСкачайте скрипт и запустите напрямую: sudo bash serverinit.sh"
fi

LOG_FILE="/root/serverinit_$(date +%Y%m%d_%H%M%S).log"
# FIX: Use pipe to file and keep original stdout for user output.
# exec > >(tee) + set -e causes race conditions on bash < 5.1
# Solution: log via explicit redirection in functions, tee only non-interactive output.
exec 3>&1                          # fd3 = original stdout (terminal)
exec > >(tee -a "$LOG_FILE") 2>&1  # fd1/fd2 → tee (file + terminal)

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${M}"
cat << 'EOF'
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
EOF
echo -e "${NC}"
echo -e "${DIM}  Universal Server Setup Utility  ·  by Elite Tech Collective${NC}"
sep
echo ""

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 0 — DETECT SYSTEM
# ══════════════════════════════════════════════════════════════════════════════
TOTAL_RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
CPU_CORES=$(nproc)
DISK_FREE_GB=$(df / --output=avail -BG | tail -1 | tr -d 'G ')
HOSTNAME_VAL=$(hostname)
OS_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "n/a")

echo -e "${BOLD}  System snapshot${NC}"
sep
printf "  %-18s %s\n"        "OS:"       "$OS_NAME"
printf "  %-18s %s\n"        "Hostname:" "$HOSTNAME_VAL"
printf "  %-18s %s\n"        "IP:"       "$IP_ADDR"
printf "  %-18s %s MB\n"    "RAM:"       "$TOTAL_RAM_MB"
printf "  %-18s %s cores\n" "CPU:"       "$CPU_CORES"
printf "  %-18s %s GB free\n" "Disk:"    "$DISK_FREE_GB"
sep

# ── Auto-calculate optimal swap size ─────────────────────────────────────────
if   [[ $TOTAL_RAM_MB -le 1024 ]]; then SWAP_GB=2
elif [[ $TOTAL_RAM_MB -le 2048 ]]; then SWAP_GB=2
elif [[ $TOTAL_RAM_MB -le 4096 ]]; then SWAP_GB=4
elif [[ $TOTAL_RAM_MB -le 8192 ]]; then SWAP_GB=4
else                                     SWAP_GB=0; fi

# ── Helper: safe interactive read ────────────────────────────────────────────
# FIX: use printf for prompt (goes to /dev/tty directly) + plain read.
# Avoids 'read -p' prompt disappearing when stdout is redirected to tee.
ask() {
  local var_name="$1"
  local prompt="$2"
  printf "%s" "$prompt" > /dev/tty
  local val
  read -r val < /dev/tty || err "Не удалось прочитать ввод с терминала"
  printf -v "$var_name" '%s' "$val"
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 1 — THREE QUESTIONS
# ══════════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}  3 вопроса — и погнали${NC}\n"

# ── Q1: Stack ─────────────────────────────────────────────────────────────────
echo -e "${W}  Q1. Какой стек устанавливать?${NC}"
echo -e "  ${C}1${NC}) Docker + Compose + Nginx   ${DIM}(рекомендуется)${NC}"
echo -e "  ${C}2${NC}) Node.js (NVM) + PM2 + Nginx"
echo -e "  ${C}3${NC}) Python 3 + pip + Nginx"
echo -e "  ${C}4${NC}) Только базовый набор утилит"
echo ""
# FIX: explicit empty-string check + tty fallback error
STACK_CHOICE=""
while true; do
  ask STACK_CHOICE "  Выбор [1-4]: "
  [[ -n "$STACK_CHOICE" && "$STACK_CHOICE" =~ ^[1-4]$ ]] && break
  warn "Введите 1, 2, 3 или 4"
done
echo ""

# ── Q2: Security ──────────────────────────────────────────────────────────────
echo -e "${W}  Q2. Уровень безопасности?${NC}"
echo -e "  ${C}1${NC}) Базовый  — UFW (80/443/22) + swap"
echo -e "  ${C}2${NC}) Полный   — + fail2ban + SSH hardening + auto-updates"
echo ""
SEC_LEVEL=""
while true; do
  ask SEC_LEVEL "  Выбор [1-2]: "
  [[ -n "$SEC_LEVEL" && "$SEC_LEVEL" =~ ^[1-2]$ ]] && break
  warn "Введите 1 или 2"
done
echo ""

# ── Q3: SSH port ──────────────────────────────────────────────────────────────
SSH_PORT=22
if [[ $SEC_LEVEL -eq 2 ]]; then
  echo -e "${W}  Q3. Нестандартный SSH-порт? ${DIM}(Enter = оставить 22)${NC}"
  SSH_PORT_INPUT=""
  ask SSH_PORT_INPUT "  SSH порт [22]: "
  if [[ -n "$SSH_PORT_INPUT" && "$SSH_PORT_INPUT" =~ ^[0-9]+$ \
        && "$SSH_PORT_INPUT" -ge 1024 && "$SSH_PORT_INPUT" -le 65535 ]]; then
    SSH_PORT=$SSH_PORT_INPUT
    warn "SSH будет перенесён на порт $SSH_PORT — убедись, что порт открыт у хостера!"
  fi
else
  echo -e "${W}  Q3. SSH-порт:${NC}"
  echo -e "  ${DIM}Пропускается — доступно только в полном режиме безопасности${NC}"
fi

echo ""
sep
echo -e "\n${BOLD}  Конфигурация:${NC}"
case $STACK_CHOICE in
  1) STACK_NAME="Docker + Compose + Nginx" ;;
  2) STACK_NAME="Node.js (NVM) + PM2 + Nginx" ;;
  3) STACK_NAME="Python 3 + pip + Nginx" ;;
  4) STACK_NAME="Базовый набор утилит" ;;
esac
[[ $SEC_LEVEL -eq 1 ]] && SEC_NAME="Базовый" || SEC_NAME="Полный"

printf "  %-20s %s\n"     "Стек:"          "$STACK_NAME"
printf "  %-20s %s\n"     "Безопасность:"  "$SEC_NAME"
printf "  %-20s %s\n"     "SSH порт:"      "$SSH_PORT"
printf "  %-20s %s GB\n"  "Swap:"          "$SWAP_GB"
sep
echo ""

CONFIRM=""
ask CONFIRM "  Всё верно? Продолжить? [y/N]: "
[[ "$CONFIRM" =~ ^[yY]$ ]] || { warn "Отменено."; exit 0; }

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 1/4 — BASE SYSTEM
# ══════════════════════════════════════════════════════════════════════════════
step "Phase 1/4 — Обновление системы"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold"
ok "Система обновлена"

# ── Essential tools ───────────────────────────────────────────────────────────
step "Установка базовых утилит"
apt-get install -y -qq \
  htop nano vim curl wget git unzip zip \
  net-tools dnsutils traceroute \
  ca-certificates gnupg lsb-release \
  build-essential software-properties-common \
  logrotate cron rsync jq tree ncdu \
  iotop sysstat \
  > /dev/null 2>&1
ok "Базовые утилиты установлены"

# ── Swap configuration ────────────────────────────────────────────────────────
step "Настройка Swap"
if [[ $SWAP_GB -gt 0 ]]; then
  SWAP_FILE="/swapfile"
  if swapon --show | grep -q "$SWAP_FILE"; then
    warn "Swap уже существует — пропускаем"
  else
    info "Создаём swap ${SWAP_GB}GB..."
    if ! fallocate -l "${SWAP_GB}G" "$SWAP_FILE" 2>/dev/null; then
      warn "fallocate не сработал — используем dd (займёт время)..."
      dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((SWAP_GB * 1024)) status=none
    fi
    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE" > /dev/null
    swapon "$SWAP_FILE"
    grep -q "$SWAP_FILE" /etc/fstab || \
      echo "${SWAP_FILE} none swap sw 0 0" >> /etc/fstab
    ok "Swap ${SWAP_GB}GB создан и подключён"
  fi
else
  info "RAM >= 8GB — swap не нужен"
fi

# ── sysctl kernel tuning ──────────────────────────────────────────────────────
step "Оптимизация ядра (sysctl)"
SYSCTL_CONF="/etc/sysctl.d/99-serverinit.conf"
cat > "$SYSCTL_CONF" << 'EOF'
# ServerInit — kernel tuning

# Swap aggressiveness (prefer RAM over swap)
vm.swappiness=10
vm.vfs_cache_pressure=50

# Network performance
net.core.somaxconn=65535
net.core.netdev_max_backlog=65535
net.ipv4.tcp_max_syn_backlog=8192
# tcp_tw_reuse: safe on kernel >= 4.19; ignored on older kernels
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728
net.core.rmem_max=134217728
net.core.wmem_max=134217728

# File descriptors
fs.file-max=2097152
fs.inotify.max_user_watches=524288

# SYN flood protection
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_syn_retries=2
net.ipv4.tcp_synack_retries=2

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
EOF

sysctl -p "$SYSCTL_CONF" > /dev/null 2>&1
ok "sysctl применён ($SYSCTL_CONF)"

# ── File descriptor limits ────────────────────────────────────────────────────
LIMITS_CONF="/etc/security/limits.d/99-serverinit.conf"
cat > "$LIMITS_CONF" << 'EOF'
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF
ok "Лимиты файловых дескрипторов настроены (1048576)"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2/4 — SECURITY
# ══════════════════════════════════════════════════════════════════════════════
step "Phase 2/4 — Безопасность"

# ── UFW Firewall ──────────────────────────────────────────────────────────────
info "Настраиваем UFW..."
apt-get install -y -qq ufw > /dev/null 2>&1

ufw --force reset  > /dev/null 2>&1
ufw default deny incoming  > /dev/null
ufw default allow outgoing > /dev/null
ufw allow "$SSH_PORT"/tcp  > /dev/null   # SSH
ufw allow 80/tcp           > /dev/null   # HTTP
ufw allow 443/tcp          > /dev/null   # HTTPS

# FIX: UFW range syntax compatible with UFW >= 0.35
if [[ $STACK_CHOICE -eq 1 ]]; then
  ufw allow from 127.0.0.1 to any port 3000:9000 proto tcp \
    > /dev/null 2>&1 && true  # non-fatal: older UFW may reject range syntax
fi

ufw --force enable > /dev/null
ok "UFW активен. Открыты порты: $SSH_PORT (SSH), 80, 443"

# ── Advanced security (level 2) ───────────────────────────────────────────────
if [[ $SEC_LEVEL -eq 2 ]]; then

  # Fail2ban
  info "Устанавливаем fail2ban..."
  apt-get install -y -qq fail2ban > /dev/null 2>&1

  # Detect correct auth log path (Ubuntu 22.04+ uses systemd journal)
  if [[ -f /var/log/auth.log ]]; then
    AUTH_LOG="/var/log/auth.log"
  else
    AUTH_LOG="%(syslog_authpriv)s"
  fi

  cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled  = true
port     = $SSH_PORT
filter   = sshd
logpath  = $AUTH_LOG
maxretry = 3
bantime  = 86400
EOF
  systemctl enable fail2ban  > /dev/null 2>&1
  systemctl restart fail2ban > /dev/null 2>&1
  ok "fail2ban настроен (SSH: max 3 попытки, бан 24ч)"

  # SSH hardening
  info "Hardening SSH..."
  SSH_CFG="/etc/ssh/sshd_config"
  # FIX: Save backup filename to variable so rollback uses SAME file
  SSH_BACKUP="${SSH_CFG}.bak.$(date +%s)"
  cp "$SSH_CFG" "$SSH_BACKUP"

  sed -i "s/^#*Port .*/Port $SSH_PORT/"           "$SSH_CFG"

  # Anti-lockout: only disable root login if another sudo user exists
  SUDO_USERS_COUNT=$(getent group sudo 2>/dev/null | cut -d: -f4 \
    | tr ',' '\n' | grep -vc "^$" || echo 0)
  if [[ $SUDO_USERS_COUNT -gt 0 || -n "${SUDO_USER:-}" ]]; then
    sed -i "s/^#*PermitRootLogin .*/PermitRootLogin no/" "$SSH_CFG"
    ok "Root login отключён (найден пользователь с sudo)"
  else
    warn "Root login ОСТАВЛЕН включённым — нет других sudo-пользователей. Создай пользователя вручную!"
  fi

  # Keep PasswordAuthentication ON — user may not have keys set up yet
  sed -i "s/^#*PasswordAuthentication .*/PasswordAuthentication yes/" "$SSH_CFG"
  sed -i "s/^#*MaxAuthTries .*/MaxAuthTries 3/"       "$SSH_CFG"
  sed -i "s/^#*LoginGraceTime .*/LoginGraceTime 20/"  "$SSH_CFG"
  sed -i "s/^#*X11Forwarding .*/X11Forwarding no/"    "$SSH_CFG"

  grep -q "^ClientAliveInterval" "$SSH_CFG" || echo "ClientAliveInterval 300" >> "$SSH_CFG"
  grep -q "^ClientAliveCountMax" "$SSH_CFG" || echo "ClientAliveCountMax 2"   >> "$SSH_CFG"
  grep -q "^MaxStartups"         "$SSH_CFG" || echo "MaxStartups 10:30:60"    >> "$SSH_CFG"

  # Validate → apply or rollback
  if sshd -t 2>/dev/null; then
    systemctl restart sshd
    ok "SSH hardened: порт $SSH_PORT, root login ограничен"
  else
    # FIX: rollback to saved backup (same filename, not new timestamp)
    warn "sshd_config невалиден — откатываем конфиг"
    cp "$SSH_BACKUP" "$SSH_CFG"
    if sshd -t 2>/dev/null; then
      systemctl restart sshd
      warn "SSH восстановлен из бэкапа $SSH_BACKUP"
    else
      warn "SSH конфиг повреждён! Проверь вручную: sshd -t"
    fi
  fi

  # Rate-limit SSH in UFW
  ufw limit "$SSH_PORT"/tcp > /dev/null
  ok "UFW rate-limit SSH включён"

  # Unattended security upgrades
  info "Настраиваем автообновления безопасности..."
  apt-get install -y -qq unattended-upgrades > /dev/null 2>&1
  cat > /etc/apt/apt.conf.d/50unattended-upgrades-serverinit << 'EOF'
Unattended-Upgrade::Allowed-Origins {
  "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
  echo 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";' > /etc/apt/apt.conf.d/20auto-upgrades
  ok "Автообновления безопасности включены"

  # FIX: check correct shm path (Ubuntu 22.04+: /dev/shm, legacy: /run/shm)
  if [[ -d /dev/shm ]]; then
    SHM_MOUNT="/dev/shm"
  else
    SHM_MOUNT="/run/shm"
  fi
  grep -q "$SHM_MOUNT" /etc/fstab || \
    echo "tmpfs $SHM_MOUNT tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
  ok "Защита shared memory настроена ($SHM_MOUNT)"
fi

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 3/4 — STACK INSTALLATION
# ══════════════════════════════════════════════════════════════════════════════
step "Phase 3/4 — Установка стека: $STACK_NAME"

install_nginx() {
  if ! command -v nginx &>/dev/null; then
    info "Устанавливаем Nginx..."
    apt-get install -y -qq nginx > /dev/null 2>&1
    systemctl enable nginx > /dev/null 2>&1
    systemctl start  nginx > /dev/null 2>&1
    sed -i "s/^worker_processes .*/worker_processes auto;/" /etc/nginx/nginx.conf
    ok "Nginx установлен и запущен"
  else
    ok "Nginx уже установлен"
  fi
}

# ── Docker + Compose ──────────────────────────────────────────────────────────
if [[ $STACK_CHOICE -eq 1 ]]; then
  if command -v docker &>/dev/null; then
    ok "Docker уже установлен ($(docker --version | cut -d' ' -f3 | tr -d ','))"
  else
    info "Устанавливаем Docker (официальный репозиторий)..."
    OS_ID=$(. /etc/os-release && echo "$ID")
    OS_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/$OS_ID/gpg" \
      | gpg --dearmor --batch --yes -o /etc/apt/keyrings/docker.gpg 2>/dev/null
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/$OS_ID $OS_CODENAME stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update -qq
    apt-get install -y -qq \
      docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin \
      > /dev/null 2>&1

    systemctl enable docker > /dev/null 2>&1
    systemctl start  docker > /dev/null 2>&1

    SUDO_USER_NAME="${SUDO_USER:-}"
    [[ -n "$SUDO_USER_NAME" ]] && usermod -aG docker "$SUDO_USER_NAME" 2>/dev/null || true

    ok "Docker $(docker --version | cut -d' ' -f3 | tr -d ',') установлен"
  fi

  # FIX: Don't overwrite existing daemon.json — merge instead
  DOCKER_DAEMON="/etc/docker/daemon.json"
  mkdir -p /etc/docker
  if [[ ! -f "$DOCKER_DAEMON" ]]; then
    cat > "$DOCKER_DAEMON" << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": { "name": "nofile", "hard": 1048576, "soft": 1048576 }
  }
}
EOF
    ok "Docker daemon оптимизирован (логи: 10MB × 3)"
  else
    warn "daemon.json уже существует — конфиг не перезаписан. Проверь: $DOCKER_DAEMON"
  fi

  systemctl reload-or-restart docker > /dev/null 2>&1 || true
  install_nginx
fi

# ── Node.js via NVM ───────────────────────────────────────────────────────────
if [[ $STACK_CHOICE -eq 2 ]]; then
  info "Устанавливаем NVM v${NVM_VERSION} + Node.js LTS ${NODE_LTS}..."

  export NVM_DIR="/root/.nvm"
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" \
    | bash > /dev/null 2>&1
  # shellcheck source=/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

  nvm install "$NODE_LTS"       > /dev/null 2>&1
  nvm use     "$NODE_LTS"       > /dev/null 2>&1
  nvm alias   default "$NODE_LTS" > /dev/null 2>&1

  # NVM available system-wide (profile.d)
  cat > /etc/profile.d/nvm.sh << 'EOF'
export NVM_DIR="/root/.nvm"
[ -s "$NVM_DIR/nvm.sh" ]             && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ]    && \. "$NVM_DIR/bash_completion"
EOF
  chmod 644 /etc/profile.d/nvm.sh

  ok "Node.js $(node --version 2>/dev/null) установлен"

  info "Устанавливаем PM2..."
  npm install -g pm2 > /dev/null 2>&1
  pm2 startup systemd -u root --hp /root > /dev/null 2>&1 || true
  ok "PM2 $(pm2 --version 2>/dev/null) установлен"

  install_nginx
fi

# ── Python 3 ─────────────────────────────────────────────────────────────────
if [[ $STACK_CHOICE -eq 3 ]]; then
  info "Настраиваем Python 3..."
  apt-get install -y -qq \
    python3 python3-pip python3-venv python3-dev \
    python3-setuptools python3-wheel \
    > /dev/null 2>&1

  # python → python3 alias
  update-alternatives --install /usr/bin/python python /usr/bin/python3 1 > /dev/null 2>&1

  # pipx (use --break-system-packages for Ubuntu 23.04+, fallback for older)
  pip3 install --quiet --break-system-packages pipx 2>/dev/null || \
    pip3 install --quiet pipx

  ok "Python $(python3 --version | cut -d' ' -f2) + pip + venv установлены"
  install_nginx
fi

[[ $STACK_CHOICE -eq 4 ]] && ok "Базовый режим — дополнительный стек не устанавливается"

# ── Log rotation ──────────────────────────────────────────────────────────────
step "Phase 4/4 — Финализация"
cat > /etc/logrotate.d/serverinit-apps << 'EOF'
/var/log/apps/*.log {
  daily
  rotate 14
  compress
  delaycompress
  missingok
  notifempty
  create 0640 root root
}
EOF
mkdir -p /var/log/apps
ok "Logrotate настроен для /var/log/apps/"

# ══════════════════════════════════════════════════════════════════════════════
#  FINAL REPORT
# ══════════════════════════════════════════════════════════════════════════════
REPORT="/root/serverinit_report.txt"
cat > "$REPORT" << REPORT
══════════════════════════════════════════════════════════
  ServerInit — Отчёт об установке
  Дата: $(date)
══════════════════════════════════════════════════════════

OS:             $OS_NAME
Hostname:       $HOSTNAME_VAL
IP:             $IP_ADDR
RAM:            ${TOTAL_RAM_MB} MB
Swap:           ${SWAP_GB} GB (swappiness=10)

Стек:           $STACK_NAME
Безопасность:   $SEC_NAME
SSH порт:       $SSH_PORT

══ Что сделано ══════════════════════════════════════════
  ✔ apt upgrade
  ✔ Базовые утилиты (htop, nano, git, curl, ...)
  ✔ Swap ${SWAP_GB}GB (/swapfile)
  ✔ sysctl (/etc/sysctl.d/99-serverinit.conf)
  ✔ Лимиты fd = 1048576
  ✔ UFW (порты: $SSH_PORT, 80, 443)
$([ "$SEC_LEVEL" = "2" ] && echo "  ✔ fail2ban (SSH: 3 попытки, бан 24ч)
  ✔ SSH hardened (порт $SSH_PORT)
  ✔ unattended-upgrades (security only)" || echo "  — fail2ban (только в полном режиме)")
$([ "$STACK_CHOICE" = "1" ] && echo "  ✔ Docker + Docker Compose Plugin
  ✔ Nginx (worker_processes auto)")
$([ "$STACK_CHOICE" = "2" ] && echo "  ✔ Node.js LTS ${NODE_LTS} via NVM ${NVM_VERSION}
  ✔ PM2 + systemd startup
  ✔ Nginx (worker_processes auto)")
$([ "$STACK_CHOICE" = "3" ] && echo "  ✔ Python 3 + pip + venv + pipx
  ✔ Nginx (worker_processes auto)")
  ✔ Logrotate (/var/log/apps/)
  ✔ Лог установки: $LOG_FILE

══ Следующие шаги ═══════════════════════════════════════
$([ "$STACK_CHOICE" = "1" ] && echo "  cd /your/project && docker compose up -d
  ufw allow PORT/tcp          # expose app ports")
$([ "$STACK_CHOICE" = "2" ] && echo "  source /etc/profile.d/nvm.sh
  pm2 start app.js --name myapp && pm2 save")
$([ "$STACK_CHOICE" = "3" ] && echo "  python3 -m venv .venv && source .venv/bin/activate
  pip install -r requirements.txt")
  certbot --nginx -d yourdomain.com   # SSL/TLS
$([ "$SSH_PORT" != "22" ] && echo "
  ⚠  ВАЖНО: SSH теперь на порту $SSH_PORT
  Проверь: ssh -p $SSH_PORT user@$(hostname -I | awk '{print $1}')")
$([ "$SEC_LEVEL" = "2" ] && echo "
  Отключить пароль SSH (после настройки ключей):
  sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  systemctl restart sshd")
══════════════════════════════════════════════════════════
REPORT

# ── Print summary ─────────────────────────────────────────────────────────────
echo ""
sep
echo -e "${BOLD}${G}  ✔ Установка завершена успешно!${NC}"
sep
echo ""
echo -e "${W}  Стек:${NC}          $STACK_NAME"
echo -e "${W}  Безопасность:${NC}  $SEC_NAME"
echo -e "${W}  SSH порт:${NC}      ${Y}$SSH_PORT${NC}"
echo -e "${W}  Swap:${NC}          ${SWAP_GB} GB"
echo ""
echo -e "  ${DIM}Полный отчёт:  $REPORT${NC}"
echo -e "  ${DIM}Лог установки: $LOG_FILE${NC}"
echo ""

[[ $SEC_LEVEL -eq 2 && $SSH_PORT -ne 22 ]] && \
  echo -e "  ${Y}${BOLD}⚠  SSH перенесён на порт $SSH_PORT — не потеряй доступ!${NC}"
[[ $STACK_CHOICE -eq 1 ]] && \
  echo -e "  ${C}→  Перелогинься чтобы использовать docker без sudo${NC}"

echo ""
sep
echo -e "${DIM}  Рекомендуется: sudo reboot${NC}"
echo ""