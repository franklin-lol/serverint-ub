# 🚀 ServerInit

Universal server initialization script for Ubuntu & Debian. One command to get a production-ready stack with hardened security.

[Русский](#russian) | [English](#english)

---

<a name="russian"></a>
## 🇷🇺 Русский (Russian)

Скрипт для быстрой настройки свежего сервера. Заменяет 2 часа рутинной работы на 3 вопроса и 5 минут ожидания.

### Основные возможности
- **3 вопроса:** выбор стека, уровня безопасности и SSH-порта.
- **Оптимизация:** автоматический Swap, тюнинг ядра (sysctl), лимиты файловых дескрипторов.
- **Безопасность:** UFW, Fail2ban, Hardening SSH, автоматические обновления безопасности.
- **Стеки:** Docker + Compose, Node.js (NVM/PM2), Python 3 или базовый набор.
- **Отчет:** подробный лог и финальный чек-лист в `/root/serverinit_report.txt`.

### Запуск
```bash
# Рекомендуемый способ (через curl)
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/serverinit.sh | sudo bash

# Локально
sudo bash serverinit.sh
```

### Что проверяет аудит (Safety First)
- Скрипт **не отключит** вход для root, если не найдет другого пользователя с sudo (защита от lockout).
- Скрипт проверяет валидность конфига SSH перед перезагрузкой.
- Автоматически определяет дистрибутив (Ubuntu/Debian) для установки Docker.

---

<a name="english"></a>
## 🇺🇸 English (English)

A comprehensive script for rapid server initialization. Replaces hours of manual configuration with 3 simple questions.

### Key Features
- **3-Question Setup:** Choose your stack, security level, and SSH port.
- **Optimization:** Automatic Swap size, kernel tuning (sysctl), and increased file descriptor limits.
- **Security Hardening:** UFW firewall, Fail2ban, SSH hardening, and unattended security updates.
- **Stacks:** Docker + Compose, Node.js (NVM/PM2), Python 3, or a minimalist base kit.
- **Reporting:** Full installation logs and a summary report at `/root/serverinit_report.txt`.

### Usage
```bash
# Recommended (via curl)
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/serverinit.sh | sudo bash

# Locally
sudo bash serverinit.sh
```

### Portability & Safety
- **Anti-Lockout:** Does not disable Root Login unless another sudo user is detected.
- **Config Validation:** Validates SSH configuration before applying changes.
- **Smart Swap:** Uses `fallocate` with a `dd` fallback for different filesystems.
- **Multi-distro:** Automatically detects Ubuntu/Debian for proper repository setup.

---
*Created by Elite Tech Collective*
