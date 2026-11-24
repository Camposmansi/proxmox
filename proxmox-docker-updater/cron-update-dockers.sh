#!/usr/bin/env bash
set -u

SCRIPT_URL="${SCRIPT_URL:-https://raw.githubusercontent.com/Camposmansi/proxmox/main/proxmox-docker-updater/update-dockers.sh}"
INSTALL_PATH="/usr/local/bin/update-dockers.sh"
CONFIG_FILE="/etc/update-dockers.conf"
LOG_FILE="/var/log/update-dockers-cron.log"
CRON_LINE="0 3 * * 0 $INSTALL_PATH >> $LOG_FILE 2>&1"

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Este instalador debe ejecutarse como root."
    exit 1
  fi
}

download_script() {
  tmp="$(mktemp)"
  if ! curl -fsSL "$SCRIPT_URL" -o "$tmp"; then
    echo "ERROR: no se pudo descargar $SCRIPT_URL"
    rm -f "$tmp"
    exit 1
  fi

  if ! bash -n "$tmp"; then
    echo "ERROR: el script descargado tiene errores de sintaxis."
    rm -f "$tmp"
    exit 1
  fi

  install -m 0755 "$tmp" "$INSTALL_PATH"
  rm -f "$tmp"
  echo "Instalado: $INSTALL_PATH"
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
    echo "Creado: $CONFIG_FILE"
  else
    echo "Conservado: $CONFIG_FILE"
  fi
}

add_cron() {
  local current
  current="$(crontab -l 2>/dev/null || true)"

  if grep -Fq "$INSTALL_PATH >> $LOG_FILE" <<< "$current"; then
    echo "El cron ya existe."
    return
  fi

  {
    printf '%s\n' "$current"
    printf '%s\n' "$CRON_LINE"
  } | awk 'NF' | crontab -

  echo "Cron instalado: domingo a las 03:00"
}

remove_cron() {
  local current
  current="$(crontab -l 2>/dev/null || true)"
  printf '%s\n' "$current" | grep -Fv "$INSTALL_PATH >> $LOG_FILE" | crontab -
  echo "Cron eliminado."
}

status() {
  echo
  echo "Script:"
  if [[ -x "$INSTALL_PATH" ]]; then
    echo "  OK - $INSTALL_PATH"
  else
    echo "  NO instalado"
  fi

  echo "Configuracion:"
  if [[ -f "$CONFIG_FILE" ]]; then
    sed 's/^/  /' "$CONFIG_FILE"
  else
    echo "  NO existe"
  fi

  echo "Cron:"
  crontab -l 2>/dev/null | grep -F "$INSTALL_PATH" || echo "  NO instalado"

  echo "Ultimas lineas del log:"
  if [[ -f "$LOG_FILE" ]]; then
    tail -20 "$LOG_FILE"
  else
    echo "  Todavia no existe $LOG_FILE"
  fi
}

run_now() {
  if [[ ! -x "$INSTALL_PATH" ]]; then
    echo "Primero instala el script."
    exit 1
  fi

  touch "$LOG_FILE"
  "$INSTALL_PATH" 2>&1 | tee -a "$LOG_FILE"
}

install_all() {
  download_script
  ensure_config
  touch "$LOG_FILE"
  chmod 0644 "$LOG_FILE"
  add_cron
}

remove_all() {
  remove_cron
  rm -f "$INSTALL_PATH"
  echo "El script local ha sido eliminado."
  echo "Se conservan $CONFIG_FILE y $LOG_FILE."
}

require_root

case "${1:-menu}" in
  add|install)
    install_all
    ;;
  update)
    download_script
    ;;
  remove)
    remove_all
    ;;
  status)
    status
    ;;
  run)
    run_now
    ;;
  view)
    [[ -f "$CONFIG_FILE" ]] && cat "$CONFIG_FILE"
    echo
    [[ -f "$INSTALL_PATH" ]] && cat "$INSTALL_PATH"
    ;;
  rotate)
    if [[ -f "$LOG_FILE" ]]; then
      mv -f "$LOG_FILE" "$LOG_FILE.old"
      touch "$LOG_FILE"
      chmod 0644 "$LOG_FILE"
      echo "Log rotado a $LOG_FILE.old"
    fi
    ;;
  menu|*)
    cat <<EOF

Docker Compose Updater para Proxmox

1) Add       Instalar script y cron
2) Update    Actualizar copia local desde GitHub
3) Status    Mostrar estado
4) Run       Ejecutar ahora
5) View      Ver configuracion y script
6) Rotate    Rotar log
7) Remove    Eliminar script y cron
0) Exit

EOF
    read -r -p "Opcion: " option
    case "$option" in
      1) install_all ;;
      2) download_script ;;
      3) status ;;
      4) run_now ;;
      5)
        [[ -f "$CONFIG_FILE" ]] && cat "$CONFIG_FILE"
        echo
        [[ -f "$INSTALL_PATH" ]] && cat "$INSTALL_PATH"
        ;;
      6)
        if [[ -f "$LOG_FILE" ]]; then
          mv -f "$LOG_FILE" "$LOG_FILE.old"
          touch "$LOG_FILE"
          chmod 0644 "$LOG_FILE"
          echo "Log rotado a $LOG_FILE.old"
        fi
        ;;
      7) remove_all ;;
      0) exit 0 ;;
      *) echo "Opcion no valida" ;;
    esac
    ;;
esac
