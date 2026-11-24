#!/usr/bin/env bash
set -u

SCRIPT_URL="${SCRIPT_URL:-https://raw.githubusercontent.com/Camposmansi/proxmox/main/proxmox-docker-updater/update-dockers.sh}"
INSTALL_PATH="/usr/local/bin/update-dockers.sh"
CONFIG_FILE="/etc/update-dockers.conf"
LOG_FILE="/var/log/update-dockers-cron.log"
CRON_LINE="0 3 * * 0 $INSTALL_PATH >> $LOG_FILE 2>&1"
VERSION="1.1.0"

if [[ -t 1 ]]; then
  RESET="\033[0m"
  BOLD="\033[1m"
  DIM="\033[2m"
  RED="\033[31m"
  GREEN="\033[32m"
  YELLOW="\033[33m"
  BLUE="\033[34m"
  CYAN="\033[36m"
  WHITE="\033[37m"
else
  RESET=""
  BOLD=""
  DIM=""
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  CYAN=""
  WHITE=""
fi

clear_screen() {
  if [[ -t 1 ]]; then
    clear
  fi
}

line() {
  printf '%b\n' "${BLUE}────────────────────────────────────────────────────────${RESET}"
}

header() {
  clear_screen
  printf '%b\n' "${CYAN}${BOLD}"
  cat <<'EOF'
   ____                      __  ___
  / __ \_________  _  ______/  |/  /___  _  __
 / /_/ / ___/ __ \| |/_/ __  /|_/ / __ \| |/_/
/ ____/ /  / /_/ />  </ /_/ /  / / /_/ />  <
/_/   /_/   \____/_/|_|\__,_/_/ /_/\____/_/|_|

        Docker Compose Updater for Proxmox
EOF
  printf '%b\n' "${RESET}"
  printf '%b\n' "${DIM}Version ${VERSION} · Camposmansi/proxmox${RESET}"
  line
}

ok()    { printf '%b\n' "${GREEN}✓${RESET} $*"; }
info()  { printf '%b\n' "${CYAN}ℹ${RESET} $*"; }
warn()  { printf '%b\n' "${YELLOW}⚠${RESET} $*"; }
error() { printf '%b\n' "${RED}✗${RESET} $*"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    error "Este instalador debe ejecutarse como root."
    exit 1
  fi
}

cron_exists() {
  crontab -l 2>/dev/null | grep -Fq "$INSTALL_PATH >> $LOG_FILE"
}

show_status_compact() {
  local script_state cron_state config_state

  if [[ -x "$INSTALL_PATH" ]]; then
    script_state="${GREEN}INSTALADO${RESET}"
  else
    script_state="${RED}NO INSTALADO${RESET}"
  fi

  if cron_exists; then
    cron_state="${GREEN}ACTIVO${RESET}"
  else
    cron_state="${YELLOW}NO CONFIGURADO${RESET}"
  fi

  if [[ -f "$CONFIG_FILE" ]]; then
    config_state="${GREEN}OK${RESET}"
  else
    config_state="${YELLOW}NO EXISTE${RESET}"
  fi

  printf " %-18s %b\n" "Script:" "$script_state"
  printf " %-18s %b\n" "Cron:" "$cron_state"
  printf " %-18s %b\n" "Configuracion:" "$config_state"
  printf " %-18s %s\n" "Horario:" "Domingo 03:00"
  line
}

download_script() {
  local tmp
  tmp="$(mktemp)"

  info "Descargando update-dockers.sh desde GitHub..."

  if ! curl -fsSL "$SCRIPT_URL" -o "$tmp"; then
    rm -f "$tmp"
    error "No se pudo descargar:"
    printf '  %s\n' "$SCRIPT_URL"
    return 1
  fi

  if ! bash -n "$tmp"; then
    rm -f "$tmp"
    error "El script descargado contiene errores de sintaxis."
    return 1
  fi

  install -m 0755 "$tmp" "$INSTALL_PATH"
  rm -f "$tmp"

  ok "Script instalado en $INSTALL_PATH"
}

ensure_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" <<'EOF'
# CT de Proxmox que se revisaran para actualizar stacks Docker Compose.
# Separados por comas.
INCLUDE=112,118,120,130,150

# true = elimina solo imagenes dangling despues de actualizar.
# No elimina todas las imagenes antiguas.
PRUNE=true
EOF
    chmod 0644 "$CONFIG_FILE"
    ok "Configuracion creada en $CONFIG_FILE"
  else
    info "Se conserva la configuracion existente: $CONFIG_FILE"
  fi
}

add_cron() {
  local current
  current="$(crontab -l 2>/dev/null || true)"

  if cron_exists; then
    info "El cron ya esta instalado."
    return 0
  fi

  {
    printf '%s\n' "$current"
    printf '%s\n' "$CRON_LINE"
  } | awk 'NF' | crontab -

  ok "Cron instalado: domingos a las 03:00"
}

remove_cron() {
  local current
  current="$(crontab -l 2>/dev/null || true)"

  if ! cron_exists; then
    info "No hay ningun cron instalado."
    return 0
  fi

  printf '%s\n' "$current" | grep -Fv "$INSTALL_PATH >> $LOG_FILE" | crontab -
  ok "Cron eliminado."
}

status_full() {
  header
  printf '%b\n' "${BOLD}Estado del sistema${RESET}"
  line

  if [[ -x "$INSTALL_PATH" ]]; then
    ok "Script instalado: $INSTALL_PATH"
  else
    warn "Script no instalado."
  fi

  if [[ -f "$CONFIG_FILE" ]]; then
    ok "Configuracion: $CONFIG_FILE"
    echo
    sed 's/^/  /' "$CONFIG_FILE"
  else
    warn "No existe $CONFIG_FILE"
  fi

  echo
  if cron_exists; then
    ok "Cron activo"
    crontab -l 2>/dev/null | grep -F "$INSTALL_PATH"
  else
    warn "Cron no configurado"
  fi

  echo
  if [[ -f "$LOG_FILE" ]]; then
    printf '%b\n' "${BOLD}Ultimas 20 lineas del log${RESET}"
    line
    tail -20 "$LOG_FILE"
  else
    info "Todavia no existe $LOG_FILE"
  fi
}

run_now() {
  header

  if [[ ! -x "$INSTALL_PATH" ]]; then
    error "Primero debes instalar el script."
    return 1
  fi

  touch "$LOG_FILE"
  chmod 0644 "$LOG_FILE"

  printf '%b\n' "${BOLD}Ejecucion manual${RESET}"
  line
  info "El resultado tambien se guardara en $LOG_FILE"
  echo

  "$INSTALL_PATH" 2>&1 | tee -a "$LOG_FILE"
}

install_all() {
  header
  printf '%b\n' "${BOLD}Instalacion${RESET}"
  line

  download_script || return 1
  ensure_config
  touch "$LOG_FILE"
  chmod 0644 "$LOG_FILE"
  add_cron

  echo
  ok "Instalacion completada."
  printf "  %-16s %s\n" "Script:" "$INSTALL_PATH"
  printf "  %-16s %s\n" "Config:" "$CONFIG_FILE"
  printf "  %-16s %s\n" "Log:" "$LOG_FILE"
  printf "  %-16s %s\n" "Cron:" "Domingo 03:00"
}

update_local() {
  header
  printf '%b\n' "${BOLD}Actualizacion desde GitHub${RESET}"
  line

  download_script
}

view_files() {
  header
  printf '%b\n' "${BOLD}Configuracion${RESET}"
  line

  if [[ -f "$CONFIG_FILE" ]]; then
    cat "$CONFIG_FILE"
  else
    warn "No existe $CONFIG_FILE"
  fi

  echo
  printf '%b\n' "${BOLD}Script instalado${RESET}"
  line

  if [[ -f "$INSTALL_PATH" ]]; then
    cat "$INSTALL_PATH"
  else
    warn "No existe $INSTALL_PATH"
  fi
}

rotate_log() {
  header
  printf '%b\n' "${BOLD}Rotacion de log${RESET}"
  line

  if [[ -f "$LOG_FILE" ]]; then
    mv -f "$LOG_FILE" "$LOG_FILE.old"
    touch "$LOG_FILE"
    chmod 0644 "$LOG_FILE"
    ok "Log anterior guardado en $LOG_FILE.old"
  else
    warn "Todavia no existe $LOG_FILE"
  fi
}

remove_all() {
  header
  printf '%b\n' "${BOLD}Desinstalacion${RESET}"
  line

  remove_cron
  rm -f "$INSTALL_PATH"
  ok "Script local eliminado."

  info "Se conservan:"
  printf '  %s\n' "$CONFIG_FILE"
  printf '  %s\n' "$LOG_FILE"
}

pause_menu() {
  echo
  read -r -p "Pulsa ENTER para volver al menu..." _
}

menu() {
  while true; do
    header
    show_status_compact

    printf '%b\n' "${BOLD}Selecciona una opcion:${RESET}"
    echo
    printf "  ${CYAN}1${RESET}) Instalar / reparar instalacion\n"
    printf "  ${CYAN}2${RESET}) Actualizar script desde GitHub\n"
    printf "  ${CYAN}3${RESET}) Ver estado y ultimos logs\n"
    printf "  ${CYAN}4${RESET}) Ejecutar actualizacion ahora\n"
    printf "  ${CYAN}5${RESET}) Ver configuracion y script\n"
    printf "  ${CYAN}6${RESET}) Rotar log\n"
    printf "  ${RED}7${RESET}) Desinstalar\n"
    printf "  ${DIM}0${RESET}) Salir\n"
    echo
    line

    read -r -p "Opcion: " option

    case "$option" in
      1) install_all; pause_menu ;;
      2) update_local; pause_menu ;;
      3) status_full; pause_menu ;;
      4) run_now; pause_menu ;;
      5) view_files; pause_menu ;;
      6) rotate_log; pause_menu ;;
      7)
        remove_all
        pause_menu
        ;;
      0)
        clear_screen
        exit 0
        ;;
      *)
        warn "Opcion no valida."
        sleep 1
        ;;
    esac
  done
}

require_root

case "${1:-menu}" in
  add|install)
    install_all
    ;;
  update)
    update_local
    ;;
  status)
    status_full
    ;;
  run)
    run_now
    ;;
  view)
    view_files
    ;;
  rotate)
    rotate_log
    ;;
  remove)
    remove_all
    ;;
  menu|*)
    menu
    ;;
esac
