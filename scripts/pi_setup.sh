#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/raulsanfer/catalog_shelf.git"
APP_DIR="/opt/showcatalog"
IMAGE_NAME="showcatalog:local"
CONTAINER_NAME="showcatalog"
USB_LABEL="CatalogPen"
MOUNT_DIR="/mnt/catalogo"
HOST_PORT="8080"
CONTAINER_PORT="5000"
KIOSK_USER="pi"

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
  docker.io \
  xserver-xorg \
  xserver-xorg-legacy \
  xinit \
  openbox \
  chromium-browser \
  unclutter \
  x11-xserver-utils \
  fonts-dejavu-core

systemctl enable --now docker
usermod -aG docker "$KIOSK_USER"

mkdir -p "$MOUNT_DIR"
if ! grep -q "LABEL=${USB_LABEL}" /etc/fstab; then
  echo "LABEL=${USB_LABEL} ${MOUNT_DIR} vfat nofail,x-systemd.automount,x-systemd.device-timeout=10,uid=${KIOSK_USER},gid=${KIOSK_USER},umask=0022 0 0" >> /etc/fstab
fi
systemctl daemon-reload
systemctl restart remote-fs.target || true

if [ -d "${APP_DIR}/.git" ]; then
  git -C "$APP_DIR" pull --ff-only
else
  rm -rf "$APP_DIR"
  git clone "$REPO_URL" "$APP_DIR"
fi

docker build -t "$IMAGE_NAME" "$APP_DIR"

cat > /etc/systemd/system/showcatalog.service <<EOF
[Unit]
Description=ShowCatalog container
After=docker.service
Wants=docker.service

[Service]
Restart=always
ExecStartPre=-/usr/bin/docker rm -f ${CONTAINER_NAME}
ExecStart=/usr/bin/docker run --name ${CONTAINER_NAME} --restart=always \
  -p ${HOST_PORT}:${CONTAINER_PORT} \
  -v ${MOUNT_DIR}:/app/catalog:ro \
  -e BASE_CATALOG_PATH=/app/catalog \
  -e HOST=0.0.0.0 \
  -e PORT=${CONTAINER_PORT} \
  -e DEBUG=0 \
  ${IMAGE_NAME}
ExecStop=/usr/bin/docker stop ${CONTAINER_NAME}
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now showcatalog.service

cat > "/home/${KIOSK_USER}/.xinitrc" <<'EOF'
#!/bin/sh
xset -dpms
xset s off
xset s noblank
unclutter -idle 0.1 -root &
openbox-session &
chromium-browser \
  --kiosk \
  --incognito \
  --noerrdialogs \
  --disable-session-crashed-bubble \
  --disable-infobars \
  --check-for-update-interval=31536000 \
  http://localhost:8080
EOF

chown "${KIOSK_USER}:${KIOSK_USER}" "/home/${KIOSK_USER}/.xinitrc"
chmod +x "/home/${KIOSK_USER}/.xinitrc"

cat > /etc/X11/Xwrapper.config <<'EOF'
allowed_users=anybody
needs_root_rights=yes
EOF

cat > /etc/systemd/system/kiosk.service <<EOF
[Unit]
Description=Kiosk mode
After=network-online.target showcatalog.service
Wants=network-online.target

[Service]
User=${KIOSK_USER}
Environment=DISPLAY=:0
WorkingDirectory=/home/${KIOSK_USER}
ExecStart=/usr/bin/startx
Restart=always
RestartSec=2
TTYPath=/dev/tty1
StandardInput=tty
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
EOF

systemctl disable --now getty@tty1.service
systemctl daemon-reload
systemctl enable kiosk.service
systemctl set-default graphical.target

echo "Setup complete. Reboot to start kiosk mode."
