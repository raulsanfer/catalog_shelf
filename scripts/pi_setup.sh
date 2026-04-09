#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/raulsanfer/catalog_shelf.git"
APP_DIR="/opt/showcatalog"
USB_LABEL="CatalogPen"
MOUNT_DIR="/mnt/catalogo"
HOST_PORT="8080"
APP_PORT="5000"
KIOSK_USER="piuser"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root (use sudo)."
  exit 1
fi

if ! id "$KIOSK_USER" >/dev/null 2>&1; then
  echo "User '$KIOSK_USER' not found. Create it or change KIOSK_USER."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  git \
  python3 \
  python3-pip \
  xserver-xorg \
  xserver-xorg-legacy \
  xinit \
  openbox \
  chromium \
  unclutter \
  x11-xserver-utils \
  fonts-dejavu-core

# --- USB automount ---
mkdir -p "$MOUNT_DIR"
if ! grep -q "LABEL=${USB_LABEL}" /etc/fstab; then
  echo "LABEL=${USB_LABEL} ${MOUNT_DIR} vfat nofail,x-systemd.automount,x-systemd.device-timeout=10,uid=${KIOSK_USER},gid=${KIOSK_USER},umask=0022 0 0" >> /etc/fstab
fi
systemctl daemon-reload
systemctl restart remote-fs.target || true

# --- Clone or update app ---
if [ -d "${APP_DIR}/.git" ]; then
  git -C "$APP_DIR" pull --ff-only
else
  rm -rf "$APP_DIR"
  git clone "$REPO_URL" "$APP_DIR"
fi

# --- Install Python dependencies ---
if [ -f "${APP_DIR}/requirements.txt" ]; then
  pip3 install -r "${APP_DIR}/requirements.txt"
fi

# --- Create app service ---
cat > /etc/systemd/system/showcatalog.service <<EOF
[Unit]
Description=ShowCatalog Python App
After=network.target remote-fs.target

[Service]
User=${KIOSK_USER}
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/python3 ${APP_DIR}/app.py
Restart=always
Environment=PORT=${APP_PORT}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now showcatalog.service

# --- X init config ---
cat > "/home/${KIOSK_USER}/.xinitrc" <<'EOF'
#!/bin/sh
xset -dpms
xset s off
xset s noblank

unclutter -idle 0.1 -root &
openbox-session &

# Wait for app to be ready
sleep 5

chromium \
  --kiosk \
  --incognito \
  --noerrdialogs \
  --disable-session-crashed-bubble \
  --disable-infobars \
  --check-for-update-interval=31536000 \
  --disable-gpu \
  --disable-dev-shm-usage \
  --no-sandbox \
  --disable-extensions \
  --disable-features=TranslateUI \
  --disable-software-rasterizer \
  http://localhost:8080
EOF

chown "${KIOSK_USER}:${KIOSK_USER}" "/home/${KIOSK_USER}/.xinitrc"
chmod +x "/home/${KIOSK_USER}/.xinitrc"

# --- X wrapper config ---
cat > /etc/X11/Xwrapper.config <<'EOF'
allowed_users=anybody
needs_root_rights=yes
EOF

# --- Kiosk service ---
cat > /etc/systemd/system/kiosk.service <<EOF
[Unit]
Description=Kiosk mode
After=network-online.target showcatalog.service
Wants=network-online.target

[Service]
User=${KIOSK_USER}
Environment=DISPLAY=:0
WorkingDirectory=/home/${KIOSK_USER}
ExecStart=/usr/bin/startx /home/${KIOSK_USER}/.xinitrc -- :0 vt1 -nocursor
Restart=always
RestartSec=2

[Install]
WantedBy=graphical.target
EOF

systemctl daemon-reload
systemctl enable kiosk.service
systemctl set-default graphical.target

echo "Setup complete. Reboot to start kiosk mode."