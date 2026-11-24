# Proxmox Docker Compose Updater

Actualizador automático de stacks Docker Compose alojados dentro de contenedores LXC de Proxmox.

El objetivo es separar la actualización del sistema operativo de los LXC de la actualización de los servicios Docker.

## Funcionamiento

El script se ejecuta desde el host Proxmox y recorre únicamente los contenedores LXC configurados.

Para cada CT:

1. Comprueba que el contenedor existe.
2. Si está apagado, lo arranca temporalmente.
3. Comprueba si Docker está instalado.
4. Detecta los proyectos Docker Compose activos.
5. Ejecuta:

```bash
docker compose pull
docker compose up -d --remove-orphans
```

6. Opcionalmente elimina imágenes `dangling` con:

```bash
docker image prune -f
```

7. Si el CT estaba apagado antes de comenzar, lo vuelve a apagar.
8. Registra el resultado en un archivo de log.

El script no modifica archivos `.env`, `docker-compose.yml`, etiquetas de imagen ni versiones configuradas manualmente.

## Archivos

```text
proxmox-docker-updater/
├── update-dockers.sh
├── cron-update-dockers.sh
└── README.md
```

### `update-dockers.sh`

Script encargado de localizar y actualizar los stacks Docker Compose.

### `cron-update-dockers.sh`

Instalador y gestor del actualizador.

Permite instalar, actualizar desde GitHub, consultar el estado, ejecutar manualmente, ver configuración y logs, rotar el log y desinstalar.

## Instalación

Ejecutar en el host Proxmox como `root`:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Camposmansi/proxmox/main/proxmox-docker-updater/cron-update-dockers.sh)"
```

Seleccionar:

```text
1) Instalar / reparar instalacion
```

El instalador crea:

```text
/usr/local/bin/update-dockers.sh
/etc/update-dockers.conf
/var/log/update-dockers-cron.log
```

y añade el cron:

```cron
0 3 * * 0 /usr/local/bin/update-dockers.sh >> /var/log/update-dockers-cron.log 2>&1
```

Esto significa: **domingo a las 03:00**.

## Configuración

Editar:

```bash
nano /etc/update-dockers.conf
```

Ejemplo:

```bash
INCLUDE=112,118,120,130,150
PRUNE=true
PING_URL=
```

### `INCLUDE`

Lista de IDs de contenedores LXC que se revisarán.

```bash
INCLUDE=112,118,120,130,150
```

Solo se procesarán esos CT. Esto evita que un nuevo contenedor sea actualizado automáticamente sin haberlo autorizado.

### `PRUNE`

Permite eliminar imágenes Docker `dangling` después de una actualización.

```bash
PRUNE=true
```

Para desactivarlo:

```bash
PRUNE=false
```

Se utiliza:

```bash
docker image prune -f
```

No se utiliza `docker image prune -a`, por lo que no se eliminan indiscriminadamente todas las imágenes antiguas.

## `PING_URL`

`PING_URL` puede utilizarse para monitorizar la ejecución del cron con servicios como Healthchecks.io.

Ejemplo:

```bash
PING_URL="https://hc-ping.com/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

La idea es poder notificar:

```text
/start  -> comienza la actualización
URL     -> actualización terminada correctamente
/fail   -> la actualización ha terminado con errores
```

Si no se desea utilizar monitorización externa:

```bash
PING_URL=
```

> Actualmente `PING_URL` debe considerarse opcional y solo tendrá efecto cuando el soporte correspondiente esté implementado en `update-dockers.sh`.

## Ejecución manual

Directamente:

```bash
/usr/local/bin/update-dockers.sh
```

O ejecutando el instalador y seleccionando:

```text
4) Ejecutar actualizacion ahora
```

## Logs

El log se guarda en:

```text
/var/log/update-dockers-cron.log
```

Ver el log completo:

```bash
cat /var/log/update-dockers-cron.log
```

Ver las últimas líneas:

```bash
tail -100 /var/log/update-dockers-cron.log
```

Seguir una ejecución en tiempo real:

```bash
tail -f /var/log/update-dockers-cron.log
```

## Actualizar el script

Ejecutar de nuevo:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Camposmansi/proxmox/main/proxmox-docker-updater/cron-update-dockers.sh)"
```

y seleccionar:

```text
2) Actualizar script desde GitHub
```

La copia local en `/usr/local/bin/update-dockers.sh` se sustituirá por la versión actual del repositorio.

La configuración en `/etc/update-dockers.conf` se conserva.

## Desinstalación

Ejecutar el instalador y seleccionar:

```text
7) Desinstalar
```

Se elimina el script local y la entrada del cron.

Por seguridad se conservan:

```text
/etc/update-dockers.conf
/var/log/update-dockers-cron.log
```

## Compatibilidad

Diseñado para ejecutarse en un host Proxmox VE con:

- `pct`
- contenedores LXC
- Docker
- Docker Compose Plugin (`docker compose`)

Los stacks deben haber sido creados mediante Docker Compose para poder detectarlos automáticamente mediante las etiquetas de Docker Compose.

## Notas importantes

El script trata todos los stacks por igual. No contiene lógica específica para Immich, Nextcloud, RustDesk u otras aplicaciones.

El comportamiento es siempre:

```bash
docker compose pull
docker compose up -d --remove-orphans
```

Docker Compose respeta exactamente las imágenes y etiquetas definidas en cada `docker-compose.yml` o `.env`.

Ejemplo:

```yaml
image: ejemplo/aplicacion:latest
```

podrá descargar una nueva imagen cuando `latest` cambie.

En cambio:

```yaml
image: ejemplo/aplicacion:v1.2.3
```

seguirá utilizando `v1.2.3` hasta que esa etiqueta se cambie manualmente.

## Repositorio

```text
https://github.com/Camposmansi/proxmox/tree/main/proxmox-docker-updater
```
