#!/usr/bin/env bash
set -euo pipefail

CLOCK_USER="xdaliclock"
CLOCK_HOME="/home/${CLOCK_USER}"
BOOT_CONFIG=""

log() {
  printf '[xdaliclock-install] %s\n' "$*"
}

die() {
  printf '[xdaliclock-install] ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "run this installer with sudo"
  fi
}

find_boot_config() {
  if [ -f /boot/firmware/config.txt ]; then
    BOOT_CONFIG="/boot/firmware/config.txt"
    return
  fi

  if [ -f /boot/config.txt ]; then
    BOOT_CONFIG="/boot/config.txt"
    return
  fi

  die "could not find /boot/firmware/config.txt or /boot/config.txt"
}

package_has_candidate() {
  local package="$1"
  local candidate

  candidate="$(apt-cache policy "${package}" | awk '/Candidate:/ { print $2; exit }')"
  [ -n "${candidate}" ] && [ "${candidate}" != "(none)" ]
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

apt_install_display_packages() {
  local attempt

  for attempt in 1 2 3; do
    log "installing X11 and xdaliclock packages (attempt ${attempt})"
    if DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      x11-xserver-utils \
      libglib2.0-bin \
      xauth \
      xinit \
      xserver-xorg \
      xfonts-base \
      xdaliclock; then
      return
    fi

    apt-get clean
    rm -rf /var/lib/apt/lists/*
    apt_update
  done

  die "failed to install X11 and xdaliclock packages"
}

install_packages() {
  apt_update

  if ! package_has_candidate xdaliclock; then
    die "could not find the xdaliclock package in APT"
  fi

  apt_install_display_packages
}

append_global_config_line() {
  local line="$1"

  printf '\n[all]\n%s\n' "${line}" >>"${BOOT_CONFIG}"
}

ensure_overlay() {
  local overlay="$1"

  if ! grep -Eq "^[[:space:]]*dtoverlay=${overlay}([,[:space:]]|$)" "${BOOT_CONFIG}"; then
    append_global_config_line "dtoverlay=${overlay}"
  fi
}

set_overlay() {
  local overlay="$1"
  local params="$2"
  local line="dtoverlay=${overlay}"

  if [ -n "${params}" ]; then
    line="${line},${params}"
  fi

  if grep -Eq "^[[:space:]]*dtoverlay=${overlay}([,[:space:]]|$)" "${BOOT_CONFIG}"; then
    sed -i -E "s|^[[:space:]]*dtoverlay=${overlay}([,[:space:]].*)?$|${line}|" "${BOOT_CONFIG}"
  else
    append_global_config_line "${line}"
  fi
}

set_dtparam() {
  local name="$1"
  local value="$2"

  if grep -Eq "^[[:space:]]*dtparam=${name}=" "${BOOT_CONFIG}"; then
    sed -i -E "s|^[[:space:]]*dtparam=${name}=.*|dtparam=${name}=${value}|" "${BOOT_CONFIG}"
  else
    append_global_config_line "dtparam=${name}=${value}"
  fi
}

configure_hyperpixel() {
  log "configuring HyperPixel Square overlay in ${BOOT_CONFIG}"
  cp "${BOOT_CONFIG}" "${BOOT_CONFIG}.pre-xdaliclock.$(date +%Y%m%d%H%M%S)"

  ensure_overlay "vc4-kms-v3d"
  set_overlay "vc4-kms-dpi-hyperpixel4sq" "rotate=270"
  set_dtparam "i2c_arm" "off"
  set_dtparam "spi" "off"

  if command -v raspi-config >/dev/null 2>&1; then
    raspi-config nonint do_i2c 1 || true
    raspi-config nonint do_spi 1 || true
  fi
}

existing_groups_csv() {
  local groups=()
  local group

  for group in video input render; do
    if getent group "${group}" >/dev/null; then
      groups+=("${group}")
    fi
  done

  local IFS=,
  printf '%s\n' "${groups[*]}"
}

ensure_clock_user() {
  local groups
  groups="$(existing_groups_csv)"

  if id "${CLOCK_USER}" >/dev/null 2>&1; then
    log "updating existing ${CLOCK_USER} user"
    usermod --shell /bin/bash "${CLOCK_USER}"
    if [ -n "${groups}" ]; then
      usermod --append --groups "${groups}" "${CLOCK_USER}"
    fi
  else
    log "creating ${CLOCK_USER} user"
    if [ -n "${groups}" ]; then
      useradd --create-home --shell /bin/bash --groups "${groups}" "${CLOCK_USER}"
    else
      useradd --create-home --shell /bin/bash "${CLOCK_USER}"
    fi
  fi

  passwd --lock "${CLOCK_USER}" >/dev/null || true
}

install_runtime_files() {
  log "installing clock runtime files"

  install -d -m 0755 /etc/default
  install -d -m 0755 /usr/local/bin
  install -d -m 0755 "${CLOCK_HOME}"

  cat >/etc/default/xdaliclock-session <<'EOF'
# Arguments passed to the native xdaliclock X11 application.
# --root draws directly on the X root window, which keeps the clock session
# independent of a window manager.
#
# xdaliclock only supports --root, --display, --window-id, and --version as
# command-line options. Settings like 24-hour time and colors are GSettings
# preferences, configured below.
XDALICLOCK_ARGS="--root"

# Optional xdaliclock preferences. Leave values empty to keep the app default.
# Valid values from the packaged org.jwz.xdaliclock schema:
#   XDALICLOCK_HOURMODE: 12, 24
#   XDALICLOCK_TIMEMODE: HHMMSS, HHMM, SS
#   XDALICLOCK_DATEMODE: MMDDYY, DDMMYY, YYMMDD
#   XDALICLOCK_FOREGROUND / XDALICLOCK_BACKGROUND: #RRGGBB or #RRGGBBAA
#   XDALICLOCK_CYCLESPEED: integer
XDALICLOCK_HOURMODE="24"
XDALICLOCK_TIMEMODE=""
XDALICLOCK_DATEMODE=""
XDALICLOCK_FOREGROUND=""
XDALICLOCK_BACKGROUND=""
XDALICLOCK_CYCLESPEED=""
EOF

  cat >/usr/local/bin/xdaliclock-session <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ -f /etc/default/xdaliclock-session ]; then
  # shellcheck disable=SC1091
  source /etc/default/xdaliclock-session
fi

if ! command -v xdaliclock >/dev/null 2>&1; then
  printf 'xdaliclock is not installed.\n' >&2
  exit 1
fi

set_pref() {
  local key="$1"
  local value="$2"

  [ -n "${value}" ] || return 0

  if ! command -v gsettings >/dev/null 2>&1; then
    printf 'gsettings is not installed; cannot set xdaliclock %s.\n' "${key}" >&2
    exit 65
  fi

  if ! gsettings set org.jwz.xdaliclock "${key}" "${value}"; then
    printf 'failed to set xdaliclock preference %s=%s\n' "${key}" "${value}" >&2
    exit 65
  fi
}

validate_args() {
  local expect_value=""
  local arg

  for arg in "$@"; do
    if [ -n "${expect_value}" ]; then
      expect_value=""
      continue
    fi

    case "${arg}" in
      --root|--version)
        ;;
      --display|--window-id)
        expect_value="${arg}"
        ;;
      --display=*|--window-id=*)
        ;;
      -*)
        printf 'unsupported xdaliclock argument: %s\n' "${arg}" >&2
        printf 'Use /etc/default/xdaliclock-session GSettings variables for preferences such as 24-hour mode.\n' >&2
        exit 64
        ;;
    esac
  done

  if [ -n "${expect_value}" ]; then
    printf 'missing value after xdaliclock argument: %s\n' "${expect_value}" >&2
    exit 64
  fi
}

set_pref hourmode "${XDALICLOCK_HOURMODE:-}"
set_pref timemode "${XDALICLOCK_TIMEMODE:-}"
set_pref datemode "${XDALICLOCK_DATEMODE:-}"
set_pref foreground "${XDALICLOCK_FOREGROUND:-}"
set_pref background "${XDALICLOCK_BACKGROUND:-}"
set_pref cyclespeed "${XDALICLOCK_CYCLESPEED:-}"

read -r -a args <<<"${XDALICLOCK_ARGS:---root}"
validate_args "${args[@]}"
exec xdaliclock "${args[@]}"
EOF
  chmod 0755 /usr/local/bin/xdaliclock-session

  cat >/usr/local/bin/xdaliclock-startx <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if command -v dbus-run-session >/dev/null 2>&1; then
  exec dbus-run-session -- /usr/bin/startx /usr/local/bin/xdaliclock-xsession -- :0 vt1 -keeptty -nocursor -s 0 -dpms
fi

exec /usr/bin/startx /usr/local/bin/xdaliclock-xsession -- :0 vt1 -keeptty -nocursor -s 0 -dpms
EOF
  chmod 0755 /usr/local/bin/xdaliclock-startx

  cat >/usr/local/bin/xdaliclock-xsession <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

xset s off || true
xset s noblank || true
xset -dpms || true
xsetroot -solid black || true
# Rotate the framebuffer to match dtoverlay=vc4-kms-dpi-hyperpixel4sq,rotate=270.
# X does not inherit the DRM-level rotation, so we apply it here.
xrandr --output DPI-1 --rotate left || true

exec /usr/local/bin/xdaliclock-session
EOF
  chmod 0755 /usr/local/bin/xdaliclock-xsession

  cat >"${CLOCK_HOME}/.bash_profile" <<'EOF'
# xdaliclock is started by xdaliclock.service, not by an interactive shell.
EOF

  cat >"${CLOCK_HOME}/.xinitrc" <<'EOF'
#!/usr/bin/env bash

exec /usr/local/bin/xdaliclock-xsession
EOF
  chmod 0755 "${CLOCK_HOME}/.xinitrc"
  chown -R "${CLOCK_USER}:${CLOCK_USER}" "${CLOCK_HOME}"

  install -d -m 0755 /etc/X11/xorg.conf.d
  cat >/etc/X11/xorg.conf.d/99-xdaliclock-input.conf <<'EOF'
# Ignore the HyperPixel built-in touchscreen so that incidental touches do not
# trigger xdaliclock's date-display toggle.
Section "InputClass"
    Identifier "ignore-hyperpixel-touch"
    MatchProduct "EP0110M09"
    Option "Ignore" "true"
EndSection
EOF

  rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf

  cat >/etc/systemd/system/xdaliclock.service <<EOF
[Unit]
Description=Dali Clock X11 session on tty1
After=systemd-user-sessions.service systemd-logind.service
Wants=systemd-logind.service
Conflicts=getty@tty1.service

[Service]
User=${CLOCK_USER}
WorkingDirectory=${CLOCK_HOME}
Environment=HOME=${CLOCK_HOME}
Environment=XAUTHORITY=${CLOCK_HOME}/.Xauthority
PAMName=login
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty
StandardOutput=journal
StandardError=journal
Restart=always
RestartSec=5
RestartPreventExitStatus=64 65
ExecStart=/usr/local/bin/xdaliclock-startx

[Install]
WantedBy=multi-user.target
EOF
}

configure_boot_target() {
  log "configuring boot to xdaliclock service"
  systemctl set-default multi-user.target
  systemctl daemon-reload
  systemctl stop getty@tty1.service || true
  systemctl disable getty@tty1.service || true
  systemctl mask getty@tty1.service || true
  systemctl enable xdaliclock.service
  systemctl restart xdaliclock.service || true
}

main() {
  require_root
  find_boot_config
  install_packages
  configure_hyperpixel
  ensure_clock_user
  install_runtime_files
  configure_boot_target

  log "done; reboot the Pi to start the HyperPixel xdaliclock session"
}

main "$@"
