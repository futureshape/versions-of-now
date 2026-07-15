#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/sd-card.env"
INSTALL_SCRIPT="${SCRIPT_DIR}/install.sh"
DEST_DEVICE=""
WORK_DIR=""
BOOT_MOUNTED_BY_SCRIPT="0"
BOOT_MOUNT_POINT=""
BOOT_PARTITION=""

log() {
  printf '[xdaliclock-image] %s\n' "$*"
}

die() {
  printf '[xdaliclock-image] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  ./image-sd-card.sh [--env path/to/sd-card.env] <destination-device>

Examples:
  ./image-sd-card.sh /dev/rdisk4     # macOS
  ./image-sd-card.sh /dev/sdb        # Linux

The destination device will be overwritten.
EOF
}

cleanup() {
  if [ "${BOOT_MOUNTED_BY_SCRIPT}" = "1" ] && [ -n "${BOOT_MOUNT_POINT}" ]; then
    if mount | grep -q " on ${BOOT_MOUNT_POINT} "; then
      umount "${BOOT_MOUNT_POINT}" >/dev/null 2>&1 || true
    fi
  fi

  if [ -n "${WORK_DIR}" ] && [ -d "${WORK_DIR}" ]; then
    rm -rf "${WORK_DIR}"
  fi
}

shell_single_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --env)
        [ "$#" -ge 2 ] || die "--env requires a path"
        ENV_FILE="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --*)
        die "unknown option: $1"
        ;;
      *)
        [ -z "${DEST_DEVICE}" ] || die "only one destination device may be given"
        DEST_DEVICE="$1"
        shift
        ;;
    esac
  done

  [ -n "${DEST_DEVICE}" ] || {
    usage
    exit 1
  }
}

load_env() {
  [ -f "${ENV_FILE}" ] || die "missing env file: ${ENV_FILE}; copy sd-card.env.example first"
  # shellcheck disable=SC1090
  source "${ENV_FILE}"

  : "${RPI_IMAGER:=}"
  : "${RPI_IMAGER_CLI_FLAG=--cli}"
  : "${RPI_IMAGE:=https://downloads.raspberrypi.com/raspios_lite_arm64_latest}"
  : "${RPI_IMAGE_SHA256:=}"
  : "${RPI_EJECT_AFTER_WRITE:=1}"
  : "${PI_HOSTNAME:=xdaliclock}"
  : "${PI_ADMIN_USER:=clockadmin}"
  : "${PI_ADMIN_PASSWORD:=}"
  : "${PI_ADMIN_PASSWORD_HASH:=}"
  : "${SSH_AUTHORIZED_KEYS_FILE:=}"
  : "${PI_WIFI_COUNTRY:=GB}"
  : "${PI_WIFI_SSID:=}"
  : "${PI_WIFI_PASSWORD:=}"
  : "${PI_WIFI_HIDDEN:=0}"
  : "${PI_EMF_WIFI_ENABLE:=1}"
  : "${PI_EMF_WIFI_SSID:=emf}"
  : "${PI_EMF_WIFI_USERNAME:=emf}"
  : "${PI_EMF_WIFI_PASSWORD:=emf}"
  : "${PI_EMF_WIFI_EAP:=ttls}"
  : "${PI_EMF_WIFI_PHASE2_AUTH:=mschapv2}"
  : "${PI_TIMEZONE:=Europe/London}"
  : "${PI_LOCALE:=en_GB.UTF-8}"
  : "${YES_REALLY_WRITE:=0}"

  [ -n "${PI_ADMIN_USER}" ] || die "PI_ADMIN_USER must not be empty"
  [ -n "${PI_ADMIN_PASSWORD}" ] || die "PI_ADMIN_PASSWORD must not be empty"
  [ "${PI_ADMIN_PASSWORD}" != "change-this-password" ] || die "change PI_ADMIN_PASSWORD in ${ENV_FILE}"

  if ! [[ "${PI_ADMIN_USER}" =~ ^[a-z][-a-z0-9_]{0,30}$ ]]; then
    die "PI_ADMIN_USER must start with a lowercase letter and contain only lowercase letters, digits, hyphens, and underscores"
  fi
}

find_imager() {
  local candidate

  if [ -n "${RPI_IMAGER}" ]; then
    [ -x "${RPI_IMAGER}" ] || die "RPI_IMAGER is not executable: ${RPI_IMAGER}"
    return
  fi

  if command -v rpi-imager >/dev/null 2>&1; then
    RPI_IMAGER="$(command -v rpi-imager)"
    return
  fi

  for candidate in \
    "/Applications/Raspberry Pi Imager.app/Contents/MacOS/rpi-imager" \
    "/Applications/Raspberry Pi Imager.app/Contents/MacOS/Raspberry Pi Imager" \
    "${HOME}/Applications/Raspberry Pi Imager.app/Contents/MacOS/rpi-imager" \
    "${HOME}/Applications/Raspberry Pi Imager.app/Contents/MacOS/Raspberry Pi Imager"; do
    if [ -x "${candidate}" ]; then
      RPI_IMAGER="${candidate}"
      return
    fi
  done

  die "could not find Raspberry Pi Imager; set RPI_IMAGER in ${ENV_FILE}"
}

confirm_destination() {
  [ -e "${DEST_DEVICE}" ] || die "destination device does not exist: ${DEST_DEVICE}"

  if [ "${YES_REALLY_WRITE}" = "1" ]; then
    return
  fi

  printf 'This will overwrite %s. Type the device path to continue: ' "${DEST_DEVICE}" >&2
  read -r answer
  [ "${answer}" = "${DEST_DEVICE}" ] || die "confirmation did not match; aborting"
}

read_authorized_keys() {
  if [ -z "${SSH_AUTHORIZED_KEYS_FILE}" ]; then
    return
  fi

  if [ -f "${SSH_AUTHORIZED_KEYS_FILE}" ]; then
    cat "${SSH_AUTHORIZED_KEYS_FILE}"
  else
    log "SSH key file not found, continuing without authorized_keys: ${SSH_AUTHORIZED_KEYS_FILE}"
  fi
}

base64_one_line() {
  base64 <"$1" | tr -d '\n'
}

build_first_run_script() {
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/xdaliclock-image.XXXXXX")"
  local first_run="${WORK_DIR}/firstrun.sh"
  local install_b64
  local authorized_keys

  install_b64="$(base64_one_line "${INSTALL_SCRIPT}")"
  authorized_keys="$(read_authorized_keys)"

cat >"${first_run}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

BOOT_LOG_DIR="/boot"
if [ -d /boot/firmware ]; then
  BOOT_LOG_DIR="/boot/firmware"
fi
exec > >(tee -a "\${BOOT_LOG_DIR}/xdaliclock-firstboot.log") 2>&1

PI_HOSTNAME=$(shell_single_quote "${PI_HOSTNAME}")
PI_ADMIN_USER=$(shell_single_quote "${PI_ADMIN_USER}")
PI_ADMIN_PASSWORD=$(shell_single_quote "${PI_ADMIN_PASSWORD}")
PI_WIFI_COUNTRY=$(shell_single_quote "${PI_WIFI_COUNTRY}")
PI_WIFI_SSID=$(shell_single_quote "${PI_WIFI_SSID}")
PI_WIFI_PASSWORD=$(shell_single_quote "${PI_WIFI_PASSWORD}")
PI_WIFI_HIDDEN=$(shell_single_quote "${PI_WIFI_HIDDEN}")
PI_EMF_WIFI_ENABLE=$(shell_single_quote "${PI_EMF_WIFI_ENABLE}")
PI_EMF_WIFI_SSID=$(shell_single_quote "${PI_EMF_WIFI_SSID}")
PI_EMF_WIFI_USERNAME=$(shell_single_quote "${PI_EMF_WIFI_USERNAME}")
PI_EMF_WIFI_PASSWORD=$(shell_single_quote "${PI_EMF_WIFI_PASSWORD}")
PI_EMF_WIFI_EAP=$(shell_single_quote "${PI_EMF_WIFI_EAP}")
PI_EMF_WIFI_PHASE2_AUTH=$(shell_single_quote "${PI_EMF_WIFI_PHASE2_AUTH}")
PI_TIMEZONE=$(shell_single_quote "${PI_TIMEZONE}")
PI_LOCALE=$(shell_single_quote "${PI_LOCALE}")
AUTHORIZED_KEYS=$(shell_single_quote "${authorized_keys}")
INSTALL_B64=$(shell_single_quote "${install_b64}")

log() {
  printf '[xdaliclock-firstboot] %s\n' "\$*"
}

trap 'log "ERROR at line \${LINENO}; first boot provisioning did not complete"' ERR

set_hostname() {
  log "setting hostname to \${PI_HOSTNAME}"
  hostnamectl set-hostname "\${PI_HOSTNAME}" || printf '%s\n' "\${PI_HOSTNAME}" >/etc/hostname
  if grep -q '^127\.0\.1\.1' /etc/hosts; then
    sed -i -E "s/^127\\.0\\.1\\.1.*/127.0.1.1\t\${PI_HOSTNAME}/" /etc/hosts
  else
    printf '127.0.1.1\t%s\n' "\${PI_HOSTNAME}" >>/etc/hosts
  fi
}

set_localisation() {
  log "setting timezone and locale"
  timedatectl set-timezone "\${PI_TIMEZONE}" || true
  if [ -n "\${PI_LOCALE}" ]; then
    sed -i -E "s/^# ?(\${PI_LOCALE}[[:space:]]+UTF-8)/\\1/" /etc/locale.gen || true
    locale-gen "\${PI_LOCALE}" || true
    update-locale "LANG=\${PI_LOCALE}" || true
  fi
}

ensure_admin_user() {
  log "creating/updating admin user \${PI_ADMIN_USER}"
  if id "\${PI_ADMIN_USER}" >/dev/null 2>&1; then
    usermod --shell /bin/bash "\${PI_ADMIN_USER}"
  else
    useradd --create-home --shell /bin/bash "\${PI_ADMIN_USER}"
  fi

  printf '%s:%s\n' "\${PI_ADMIN_USER}" "\${PI_ADMIN_PASSWORD}" | chpasswd

  for group in adm dialout cdrom sudo audio video plugdev games users input render netdev lpadmin gpio i2c spi; do
    if getent group "\${group}" >/dev/null; then
      usermod --append --groups "\${group}" "\${PI_ADMIN_USER}"
    fi
  done

  install -d -m 0700 -o "\${PI_ADMIN_USER}" -g "\${PI_ADMIN_USER}" "/home/\${PI_ADMIN_USER}/.ssh"
  if [ -n "\${AUTHORIZED_KEYS}" ]; then
    printf '%s\n' "\${AUTHORIZED_KEYS}" >"/home/\${PI_ADMIN_USER}/.ssh/authorized_keys"
    chown "\${PI_ADMIN_USER}:\${PI_ADMIN_USER}" "/home/\${PI_ADMIN_USER}/.ssh/authorized_keys"
    chmod 0600 "/home/\${PI_ADMIN_USER}/.ssh/authorized_keys"
  fi
}

delete_wifi_profile() {
  local profile_name="\$1"

  if [ -z "\${profile_name}" ]; then
    return
  fi

  if nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "\${profile_name}"; then
    log "removing stale Wi-Fi profile for \${profile_name}"
    nmcli connection delete "\${profile_name}" >/dev/null 2>&1 || true
  fi
}

delete_stale_wifi_profile() {
  delete_wifi_profile "\${PI_WIFI_SSID}"
}

configure_emf_wifi_profile() {
  if [ "\${PI_EMF_WIFI_ENABLE}" != "1" ] || [ -z "\${PI_EMF_WIFI_SSID}" ]; then
    return
  fi

  log "configuring EMF Wi-Fi profile for \${PI_EMF_WIFI_SSID}"
  delete_wifi_profile "\${PI_EMF_WIFI_SSID}"

  nmcli connection add \
    type wifi \
    ifname "*" \
    con-name "\${PI_EMF_WIFI_SSID}" \
    ssid "\${PI_EMF_WIFI_SSID}" >/dev/null

  nmcli connection modify "\${PI_EMF_WIFI_SSID}" \
    connection.autoconnect yes \
    connection.autoconnect-priority 10 \
    wifi-sec.key-mgmt wpa-eap \
    802-1x.eap "\${PI_EMF_WIFI_EAP}" \
    802-1x.identity "\${PI_EMF_WIFI_USERNAME}" \
    802-1x.password "\${PI_EMF_WIFI_PASSWORD}" \
    802-1x.password-flags 0 \
    802-1x.phase2-auth "\${PI_EMF_WIFI_PHASE2_AUTH}"
}

try_emf_wifi_connection() {
  if [ "\${PI_EMF_WIFI_ENABLE}" != "1" ] || [ -z "\${PI_EMF_WIFI_SSID}" ]; then
    return 1
  fi

  for attempt in \$(seq 1 12); do
    if nmcli connection up "\${PI_EMF_WIFI_SSID}"; then
      return 0
    fi
    log "EMF Wi-Fi connect attempt \${attempt} failed; retrying"
    sleep 5
  done

  return 1
}

configure_wifi() {
  if [ -z "\${PI_WIFI_SSID}" ] && [ "\${PI_EMF_WIFI_ENABLE}" != "1" ]; then
    log "no Wi-Fi SSID configured; assuming Ethernet or existing network"
    return
  fi

  log "configuring Wi-Fi"
  raspi-config nonint do_wifi_country "\${PI_WIFI_COUNTRY}" || true
  rfkill unblock wifi || true
  systemctl start NetworkManager || true
  nmcli radio wifi on || true
  nmcli dev wifi rescan >/dev/null 2>&1 || true
  configure_emf_wifi_profile

  if [ -z "\${PI_WIFI_SSID}" ]; then
    try_emf_wifi_connection || log "EMF Wi-Fi did not connect; continuing in case Ethernet is available"
    return
  fi

  log "configuring primary Wi-Fi for \${PI_WIFI_SSID}"
  delete_stale_wifi_profile

  local hidden_args=()
  if [ "\${PI_WIFI_HIDDEN}" = "1" ]; then
    hidden_args=(hidden yes)
  fi

  for attempt in \$(seq 1 12); do
    if [ -n "\${PI_WIFI_PASSWORD}" ]; then
      if nmcli dev wifi connect "\${PI_WIFI_SSID}" password "\${PI_WIFI_PASSWORD}" "\${hidden_args[@]}"; then
        return
      fi
    else
      if nmcli dev wifi connect "\${PI_WIFI_SSID}" "\${hidden_args[@]}"; then
        return
      fi
    fi
    log "Wi-Fi connect attempt \${attempt} failed; retrying"
    delete_stale_wifi_profile
    sleep 5
  done

  try_emf_wifi_connection && return
  log "Wi-Fi did not connect; continuing in case Ethernet is available"
}

wait_for_network() {
  log "waiting for package network"
  for attempt in \$(seq 1 60); do
    if getent hosts deb.debian.org >/dev/null 2>&1 || getent hosts archive.raspberrypi.com >/dev/null 2>&1; then
      return
    fi
    sleep 5
  done
  log "network lookup did not become ready; apt may fail"
}

wait_for_clock_sync() {
  log "waiting for system clock sync"
  timedatectl set-ntp true >/dev/null 2>&1 || true
  systemctl restart systemd-timesyncd.service >/dev/null 2>&1 || true

  for attempt in \$(seq 1 60); do
    if [ "\$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)" = "yes" ]; then
      return
    fi
    sleep 2
  done

  log "system clock did not report NTP sync; APT will still retry if signatures are not yet valid"
}

install_clock() {
  log "running xdaliclock installer"
  printf '%s' "\${INSTALL_B64}" | base64 -d >/root/xdaliclock-install.sh
  chmod 0755 /root/xdaliclock-install.sh
  /root/xdaliclock-install.sh
}

remove_first_run_secrets() {
  rm -f /boot/firmware/firstrun.sh /boot/firstrun.sh || true
}

main() {
  set_hostname
  set_localisation
  ensure_admin_user
  configure_wifi
  wait_for_network
  wait_for_clock_sync
  install_clock
  remove_first_run_secrets
  log "first boot provisioning complete; rebooting into clock session"
  systemctl reboot
}

main "\$@"
EOF

  chmod 0700 "${first_run}"
  printf '%s\n' "${first_run}"
}

write_image() {
  local first_run="$1"
  local args=()

  if [ -n "${RPI_IMAGER_CLI_FLAG}" ]; then
    args+=("${RPI_IMAGER_CLI_FLAG}")
  fi

  args+=(--first-run-script "${first_run}" --disable-eject)

  if [ -n "${RPI_IMAGE_SHA256}" ]; then
    args+=(--sha256 "${RPI_IMAGE_SHA256}")
  fi

  args+=("${RPI_IMAGE}" "${DEST_DEVICE}")

  log "writing ${RPI_IMAGE} to ${DEST_DEVICE}"
  "${RPI_IMAGER}" "${args[@]}"
}

boot_disk_device_macos() {
  local base

  base="$(basename "${DEST_DEVICE}")"
  base="${base#r}"
  printf '/dev/%s\n' "${base}"
}

boot_partition_device() {
  case "$(uname -s)" in
    Darwin)
      printf '%ss1\n' "$(boot_disk_device_macos)"
      ;;
    Linux)
      if [[ "${DEST_DEVICE}" =~ [0-9]$ ]]; then
        printf '%sp1\n' "${DEST_DEVICE}"
      else
        printf '%s1\n' "${DEST_DEVICE}"
      fi
      ;;
    *)
      die "automatic bootfs editing is only implemented for macOS and Linux"
      ;;
  esac
}

wait_for_boot_partition() {
  local partition="$1"
  local attempt

  case "$(uname -s)" in
    Darwin)
      for attempt in $(seq 1 30); do
        if diskutil info "${partition}" >/dev/null 2>&1; then
          return
        fi
        sleep 1
      done
      ;;
    Linux)
      if command -v udevadm >/dev/null 2>&1; then
        udevadm settle || true
      fi
      for attempt in $(seq 1 30); do
        if [ -b "${partition}" ]; then
          return
        fi
        sleep 1
      done
      ;;
  esac

  die "could not find boot partition after imaging: ${partition}"
}

mount_point_macos() {
  local partition="$1"
  local mount_point

  mount_point="$(diskutil info "${partition}" | awk -F: '/Mount Point/ { sub(/^[[:space:]]+/, "", $2); print $2; exit }')"
  if [ -z "${mount_point}" ] || [ "${mount_point}" = "Not mounted" ]; then
    diskutil mount "${partition}" >/dev/null
    mount_point="$(diskutil info "${partition}" | awk -F: '/Mount Point/ { sub(/^[[:space:]]+/, "", $2); print $2; exit }')"
  fi

  [ -d "${mount_point}" ] || die "could not mount boot partition: ${partition}"
  printf '%s\n' "${mount_point}"
}

mount_point_linux() {
  local partition="$1"
  local mount_point

  [ "$(id -u)" -eq 0 ] || die "on Linux, run this script with sudo so it can mount and edit the boot partition"
  require_command lsblk

  mount_point="$(lsblk -no MOUNTPOINT "${partition}" | awk 'NF { print; exit }')"
  if [ -z "${mount_point}" ]; then
    BOOT_MOUNT_POINT="${WORK_DIR}/bootfs"
    mkdir -p "${BOOT_MOUNT_POINT}"
    mount "${partition}" "${BOOT_MOUNT_POINT}"
    BOOT_MOUNTED_BY_SCRIPT="1"
    mount_point="${BOOT_MOUNT_POINT}"
  fi

  [ -d "${mount_point}" ] || die "could not mount boot partition: ${partition}"
  printf '%s\n' "${mount_point}"
}

find_boot_mount_point() {
  BOOT_PARTITION="$(boot_partition_device)"
  wait_for_boot_partition "${BOOT_PARTITION}"

  case "$(uname -s)" in
    Darwin)
      mount_point_macos "${BOOT_PARTITION}"
      ;;
    Linux)
      mount_point_linux "${BOOT_PARTITION}"
      ;;
  esac
}

password_hash() {
  if [ -n "${PI_ADMIN_PASSWORD_HASH}" ]; then
    printf '%s\n' "${PI_ADMIN_PASSWORD_HASH}"
    return
  fi

  require_command openssl

  if openssl passwd -6 -salt xdaliclock-test test >/dev/null 2>&1; then
    openssl passwd -6 -salt "$(date +%s)" "${PI_ADMIN_PASSWORD}"
    return
  fi

  die "openssl on this system does not support SHA-512 password hashes; set PI_ADMIN_PASSWORD_HASH support before imaging"
}

write_userconf_to_bootfs() {
  local mount_point
  local userconf
  local ssh_marker
  local hash

  mount_point="$(find_boot_mount_point)"
  userconf="${mount_point}/userconf.txt"
  ssh_marker="${mount_point}/ssh"
  hash="$(password_hash)"

  log "writing Raspberry Pi OS first-user config to ${userconf}"
  printf '%s:%s\n' "${PI_ADMIN_USER}" "${hash}" >"${userconf}"
  log "writing SSH enable marker to ${ssh_marker}"
  : >"${ssh_marker}"
  sync
}

configure_bootfs() {
  write_userconf_to_bootfs
}

eject_or_sync_card() {
  if [ "${RPI_EJECT_AFTER_WRITE}" != "1" ]; then
    sync
    return
  fi

  case "$(uname -s)" in
    Darwin)
      log "ejecting ${DEST_DEVICE}"
      diskutil eject "$(boot_disk_device_macos)" >/dev/null || sync
      ;;
    Linux)
      sync
      if [ "${BOOT_MOUNTED_BY_SCRIPT}" = "1" ] && [ -n "${BOOT_MOUNT_POINT}" ]; then
        umount "${BOOT_MOUNT_POINT}"
        BOOT_MOUNTED_BY_SCRIPT="0"
      fi
      ;;
  esac
}

main() {
  parse_args "$@"
  load_env
  find_imager
  confirm_destination
  require_command base64
  require_command sed
  trap cleanup EXIT

  [ -f "${INSTALL_SCRIPT}" ] || die "missing install script: ${INSTALL_SCRIPT}"
  local first_run
  first_run="$(build_first_run_script)"
  write_image "${first_run}"
  configure_bootfs
  eject_or_sync_card

  log "SD card image written. Insert it into the Pi and power it on."
  log "First boot will configure Wi-Fi/HyperPixel/packages and then reboot into xdaliclock."
}

main "$@"
