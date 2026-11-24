# Proxmox Tools

Repositorio personal de scripts y utilidades para administrar y mantener entornos Proxmox VE.

La idea es centralizar herramientas reutilizables para tareas habituales de mantenimiento, automatización, actualización y administración de contenedores LXC y servicios desplegados dentro de Proxmox.

## Estructura del repositorio

Actualmente:

```text
proxmox/
├── proxmox-docker-updater/
│   ├── update-dockers.sh
│   ├── cron-update-dockers.sh
│   └── README.md
└── README.md
```

## Proxmox Docker Updater

Directorio:

```text
proxmox-docker-updater/
```

Contiene un sistema para actualizar automáticamente stacks Docker Compose alojados dentro de contenedores LXC de Proxmox.

Funciones principales:

- Selección explícita de CT mediante configuración.
- Detección automática de Docker.
- Detección de stacks Docker Compose.
- Ejecución de:

```bash
docker compose pull
docker compose up -d --remove-orphans
```

- Limpieza opcional de imágenes `dangling`.
- Respeto del estado original del CT:
  - si estaba encendido, permanece encendido;
  - si estaba apagado, se arranca temporalmente y se vuelve a apagar.
- Registro de ejecución en log.
- Cron semanal configurable.
- Instalador con menú interactivo.

Documentación completa:

```text
proxmox-docker-updater/README.md
```

## Instalación rápida del Docker Updater

Desde el host Proxmox, como `root`:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Camposmansi/proxmox/main/proxmox-docker-updater/cron-update-dockers.sh)"
```

Por defecto, el cron queda programado para:

```text
Domingo a las 03:00
```

## Objetivo del repositorio

Este repositorio está pensado para separar claramente distintos tipos de mantenimiento.

Por ejemplo:

```text
Proxmox VE
├── Actualización del host
├── Actualización de sistemas operativos LXC
├── Actualización de stacks Docker
├── Copias de seguridad
├── Reparación de permisos
├── Mantenimiento de almacenamiento
└── Otras automatizaciones
```

Cada herramienta debe tener su propia carpeta, configuración y documentación.

## Filosofía

Las herramientas de este repositorio intentan seguir estos principios:

- No ejecutar tareas destructivas por defecto.
- Mantener configuraciones separadas del código.
- Utilizar listas explícitas cuando sea posible.
- Generar logs claros.
- Poder ejecutar tareas manualmente antes de automatizarlas.
- Evitar depender de descargas remotas durante cada ejecución programada.
- Instalar una copia local de los scripts cuando exista un cron.
- Mantener cada herramienta independiente del resto.
- Evitar lógica específica de aplicaciones salvo que sea imprescindible.

## Recomendación de estructura para nuevas herramientas

Cada utilidad nueva puede seguir este formato:

```text
nombre-herramienta/
├── script-principal.sh
├── instalador.sh
└── README.md
```

Si necesita configuración:

```text
/etc/nombre-herramienta.conf
```

Si necesita logs:

```text
/var/log/nombre-herramienta.log
```

Y si utiliza cron, es preferible ejecutar una copia local:

```text
/usr/local/bin/nombre-herramienta.sh
```

en lugar de descargar y ejecutar código remoto automáticamente en cada ejecución.

## Uso bajo responsabilidad

Estos scripts están pensados para administración de sistemas Proxmox VE.

Antes de utilizar cualquier automatización en un entorno importante:

1. Revisar el código.
2. Verificar los IDs de los CT.
3. Ejecutar manualmente una primera prueba.
4. Comprobar los logs.
5. Confirmar que existen copias de seguridad adecuadas.

## Repositorio

```text
https://github.com/Camposmansi/proxmox
```
