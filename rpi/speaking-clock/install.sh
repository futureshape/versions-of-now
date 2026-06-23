#!/usr/bin/env bash
set -euo pipefail

CLOCK_USER="speakingclock"
CLOCK_HOME="/var/lib/speaking-clock"
INSTALL_DIR="/opt/speaking-clock"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '[speaking-clock-install] %s\n' "$*"
}

die() {
  printf '[speaking-clock-install] ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "run this installer with sudo"
  fi
}

apt_update() {
  local attempt

  for attempt in 1 2 3 4 5; do
    log "updating APT package lists (attempt ${attempt})"
    if apt-get update --error-on=any; then
      return
    fi

    apt-get clean
    rm -rf /var/lib/apt/lists/*
    log "APT update failed; retrying after package-list refresh"
    sleep $((attempt * 10))
  done

  die "APT update failed after multiple attempts"
}

install_packages() {
  apt_update

  log "installing Python, espeak-ng, and ALSA playback tools"
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    alsa-utils \
    espeak-ng \
    python3
}

configure_time_sync() {
  log "enabling system time synchronization where available"

  if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-ntp true || true
  fi

  if systemctl list-unit-files systemd-timesyncd.service >/dev/null 2>&1; then
    systemctl enable --now systemd-timesyncd.service || true
  fi
}

existing_groups_csv() {
  local groups=()
  local group

  for group in audio; do
    if getent group "${group}" >/dev/null; then
      groups+=("${group}")
    fi
  done

  local IFS=,
  printf '%s\n' "${groups[*]}"
}

ensure_clock_group() {
  if ! getent group "${CLOCK_USER}" >/dev/null; then
    log "creating ${CLOCK_USER} group"
    groupadd --system "${CLOCK_USER}"
  fi
}

ensure_clock_user() {
  local groups
  groups="$(existing_groups_csv)"
  ensure_clock_group

  if id "${CLOCK_USER}" >/dev/null 2>&1; then
    log "updating existing ${CLOCK_USER} user"
    usermod --home "${CLOCK_HOME}" --shell /usr/sbin/nologin --gid "${CLOCK_USER}" "${CLOCK_USER}"
    if [ -n "${groups}" ]; then
      usermod --append --groups "${groups}" "${CLOCK_USER}"
    fi
  else
    log "creating ${CLOCK_USER} user"
    if [ -n "${groups}" ]; then
      useradd --system --create-home --home-dir "${CLOCK_HOME}" \
        --shell /usr/sbin/nologin --gid "${CLOCK_USER}" --groups "${groups}" "${CLOCK_USER}"
    else
      useradd --system --create-home --home-dir "${CLOCK_HOME}" \
        --shell /usr/sbin/nologin --gid "${CLOCK_USER}" "${CLOCK_USER}"
    fi
  fi

  install -d -m 0755 -o "${CLOCK_USER}" -g "${CLOCK_USER}" "${CLOCK_HOME}"
}

install_runtime_files() {
  log "installing speaking clock runtime files"

  install -d -m 0755 "${INSTALL_DIR}"
  install -m 0755 "${SCRIPT_DIR}/speaking_clock.py" "${INSTALL_DIR}/speaking_clock.py"

  install -d -m 0755 /etc/default
  if [ ! -f /etc/default/speaking-clock ]; then
    cat >/etc/default/speaking-clock <<'EOF'
# Arguments for the telephone-style speaking clock.
#
# Raspberry Pi defaults use espeak-ng for a British-English voice and ALSA
# playback through the system default audio output.
#
# If your vintage handset is a USB audio adapter, find its ALSA device with:
#   aplay -l
# Then add for example:
#   --audio-device plughw:1,0
SPEAKING_CLOCK_ARGS="--interval 10 --backend espeak-ng --player aplay --voice en-gb --rate 140 --require-sync"
EOF
  fi

  cat >/etc/systemd/system/speaking-clock.service <<EOF
[Unit]
Description=Telephone-style speaking clock
Documentation=file:${INSTALL_DIR}/speaking_clock.py
After=network-online.target sound.target time-sync.target
Wants=network-online.target sound.target time-sync.target

[Service]
Type=simple
User=${CLOCK_USER}
WorkingDirectory=${CLOCK_HOME}
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/etc/default/speaking-clock
ExecStart=/usr/bin/python3 ${INSTALL_DIR}/speaking_clock.py \$SPEAKING_CLOCK_ARGS
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
}

configure_service() {
  log "enabling speaking-clock.service"
  systemctl daemon-reload
  systemctl enable speaking-clock.service
  systemctl restart speaking-clock.service
}

main() {
  require_root
  install_packages
  configure_time_sync
  ensure_clock_user
  install_runtime_files
  configure_service

  log "done; plug the headset into the Pi audio output and check journalctl -u speaking-clock.service"
}

main "$@"
