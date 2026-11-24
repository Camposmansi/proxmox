#!/usr/bin/env bash
set -u

CONFIG_FILE="/etc/update-dockers.conf"
LOG_PREFIX="[update-dockers]"
DEFAULT_INCLUDE=""

log() {
  printf '%s %s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$LOG_PREFIX" "$*"
}

if [[ $EUID -ne 0 ]]; then
  echo "Este script debe ejecutarse como root."
  exit 1
fi

if ! command -v pct >/dev/null 2>&1; then
  echo "No se encuentra 'pct'. Este script debe ejecutarse en el host Proxmox."
  exit 1
fi

INCLUDE="$DEFAULT_INCLUDE"
PRUNE="true"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

if [[ -z "${INCLUDE:-}" ]]; then
  log "ERROR: INCLUDE esta vacio en $CONFIG_FILE"
  exit 1
fi

IFS=',' read -r -a CTS <<< "$INCLUDE"

total=0
updated=0
skipped=0
failed=0

log "================================================="
log "Inicio de actualizacion Docker"
log "Contenedores incluidos: $INCLUDE"
log "================================================="

for raw_ct in "${CTS[@]}"; do
  ct="$(echo "$raw_ct" | xargs)"
  [[ -z "$ct" ]] && continue
  ((total++))

  if ! pct status "$ct" >/dev/null 2>&1; then
    log "CT $ct: ERROR - no existe o no es accesible"
    ((failed++))
    continue
  fi

  status="$(pct status "$ct" 2>/dev/null | awk '{print $2}')"
  started_by_script=0

  if [[ "$status" != "running" ]]; then
    log "CT $ct: estaba apagado, arrancando temporalmente"
    if ! pct start "$ct"; then
      log "CT $ct: ERROR - no se pudo arrancar"
      ((failed++))
      continue
    fi
    started_by_script=1
    sleep 5
  fi

  if ! pct exec "$ct" -- sh -lc 'command -v docker >/dev/null 2>&1'; then
    log "CT $ct: SKIP - Docker no esta instalado"
    ((skipped++))
    if [[ "$started_by_script" -eq 1 ]]; then
      pct shutdown "$ct" --timeout 60 >/dev/null 2>&1 || pct stop "$ct" >/dev/null 2>&1 || true
    fi
    continue
  fi

  # Descubre proyectos Compose activos a partir de las etiquetas que Docker Compose añade a los contenedores.
  mapfile -t compose_dirs < <(
    pct exec "$ct" -- sh -lc '
      docker ps -a --format "{{.Label \"com.docker.compose.project.working_dir\"}}" 2>/dev/null |
      awk "NF" |
      sort -u
    ' 2>/dev/null
  )

  if [[ "${#compose_dirs[@]}" -eq 0 ]]; then
    log "CT $ct: SKIP - no se detectaron stacks Docker Compose"
    ((skipped++))
    if [[ "$started_by_script" -eq 1 ]]; then
      pct shutdown "$ct" --timeout 60 >/dev/null 2>&1 || pct stop "$ct" >/dev/null 2>&1 || true
    fi
    continue
  fi

  ct_failed=0
  ct_changed=0

  for compose_dir in "${compose_dirs[@]}"; do
    compose_dir="$(echo "$compose_dir" | tr -d '\r')"
    [[ -z "$compose_dir" ]] && continue

    log "CT $ct: actualizando stack en $compose_dir"

    if ! pct exec "$ct" -- sh -lc "cd \"$compose_dir\" && docker compose pull"; then
      log "CT $ct: ERROR en docker compose pull ($compose_dir)"
      ct_failed=1
      continue
    fi

    if ! pct exec "$ct" -- sh -lc "cd \"$compose_dir\" && docker compose up -d --remove-orphans"; then
      log "CT $ct: ERROR en docker compose up -d ($compose_dir)"
      ct_failed=1
      continue
    fi

    ct_changed=1
    log "CT $ct: OK - stack actualizado ($compose_dir)"
  done

  if [[ "${PRUNE:-true}" == "true" ]]; then
    if pct exec "$ct" -- sh -lc 'docker image prune -f' >/dev/null 2>&1; then
      log "CT $ct: limpieza de imagenes dangling completada"
    else
      log "CT $ct: AVISO - fallo al limpiar imagenes dangling"
    fi
  fi

  if [[ "$ct_failed" -eq 1 ]]; then
    ((failed++))
  elif [[ "$ct_changed" -eq 1 ]]; then
    ((updated++))
  else
    ((skipped++))
  fi

  if [[ "$started_by_script" -eq 1 ]]; then
    log "CT $ct: devolviendo al estado apagado"
    pct shutdown "$ct" --timeout 60 >/dev/null 2>&1 || pct stop "$ct" >/dev/null 2>&1 || true
  fi
done

log "================================================="
log "RESUMEN"
log "CT procesados : $total"
log "Actualizados   : $updated"
log "Omitidos       : $skipped"
log "Con errores    : $failed"
log "================================================="

if [[ "$failed" -gt 0 ]]; then
  exit 1
fi

exit 0
