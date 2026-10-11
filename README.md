# Symfony Docker Demo

Entorno de desarrollo basado en Docker para construir aplicaciones con **Symfony 7.4, PHP 8.4 y Nginx**, acompañado de MariaDB, RabbitMQ y Mailpit.

El objetivo de este repositorio es proporcionar una base reutilizable, organizada y fácil de mantener para desarrollar aplicaciones Symfony en un entorno aislado, sin necesidad de instalar PHP, Composer, Node.js o los servicios de infraestructura directamente en el sistema operativo.

## Características

- **PHP 8.4 FPM** con extensiones para aplicaciones Symfony y diferentes integraciones.
- **Nginx** como servidor web y proxy FastCGI hacia PHP-FPM.
- **MariaDB** para persistencia de datos.
- **RabbitMQ Management** para mensajería y procesamiento asíncrono.
- **Mailpit** para capturar y visualizar correos electrónicos durante el desarrollo.
- **Composer** para dependencias PHP.
- **Node.js y Yarn** para herramientas frontend y compilación de assets.
- **Symfony CLI** para tareas de desarrollo.
- **OPcache** configurado para desarrollo.
- Volúmenes persistentes para datos, cachés y dependencias.
- Healthchecks, límites de recursos y rotación de logs.
- Posibilidad de trabajar con Symfony AssetMapper o Webpack Encore, según la configuración del proyecto.

## Arquitectura

```text
symfony-docker-demo/
├── compose.yml
├── databases/
│   └── mariadb/
│       ├── compose.yml
│       └── initdb/
├── development/
│   ├── mailpit/
│   │   └── compose.yml
│   └── rabbitmq/
│       └── compose.yml
├── sf/
│   ├── compose.yml
│   ├── nginx/
│   │   └── default.conf
│   └── php84-fpm/
│       ├── Dockerfile
│       ├── docker-entrypoint.sh
│       └── php/
│           ├── dev/
│           │   ├── php.ini
│           │   └── opcache.ini
│           └── prod/
└── sf-code/
    └── Aplicación Symfony
```

> La estructura anterior representa la organización esperada de los componentes descritos. Si algún archivo tiene una ubicación diferente en tu rama actual, ajusta el árbol para que coincida con el repositorio.

### Servicios

| Servicio | Función | Acceso desde el host |
|---|---|---|
| `sf-app` | PHP-FPM y aplicación Symfony | Interno en Docker |
| `sf-nginx` | Servidor web | `http://localhost:8080` |
| `mariadb` | Base de datos | `127.0.0.1:3306` |
| `rabbitmq` | Interfaz de administración | `http://localhost:15672` |
| `mailpit` | Interfaz de correo | `http://localhost:8025` |

Las interfaces publicadas están vinculadas a `127.0.0.1`, por lo que están pensadas para el acceso local. RabbitMQ y Mailpit también utilizan puertos internos de Docker para la comunicación entre servicios.

## Requisitos

- Docker Engine.
- Docker Compose V2, con soporte para `include`.
- Git.
- Un proyecto Symfony que se ubique en `sf-code/`.
- Puertos locales disponibles: `3306`, `8080`, `8025` y `15672`.

Comprueba las versiones instaladas:

```bash
docker --version
docker compose version
git --version
```

## Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/samrodriguez/symfony-docker-demo.git
cd symfony-docker-demo
```

### 2. Preparar las variables de entorno

Crea un archivo `.env` a partir de la plantilla proporcionada, si existe:

```bash
cp .env.example .env
```

Si el repositorio todavía no contiene `.env.example`, crea uno con las variables necesarias para los archivos Compose:

```dotenv
APPENV=dev
HOST_UID=1000
HOST_GID=1000

MYSQL_ROOT_PASSWORD=change-me-root
MYSQL_USER=symfony
MYSQL_PASSWORD=change-me-app
MYSQL_DATABASE=symfony

RABBITMQ_USER=developer
RABBITMQ_PASSWORD=change-me-rabbitmq

TZ=America/El_Salvador
```

Estos valores son ejemplos para desarrollo. Cámbialos según tu entorno y no reutilices estas contraseñas en producción.

En Linux, obtén el UID y GID de tu usuario:

```bash
id -u
id -g
```

Actualiza `HOST_UID` y `HOST_GID` en `.env` para evitar problemas de permisos al trabajar con archivos montados desde el host.

No publiques credenciales reales ni secretos en Git. Mantén `.env` fuera del control de versiones y utiliza `.env.example` únicamente con valores de demostración.

### 3. Preparar la red Docker

Los archivos Compose utilizan una red externa denominada `app-network`. Créala antes de iniciar los servicios:

```bash
docker network create app-network
```

Si la red ya existe, no necesitas crearla de nuevo.

### 4. Preparar los directorios persistentes

Desde la raíz del repositorio:

```bash
mkdir -p data/mariadb
mkdir -p data/mailpit/data
mkdir -p data/rabbitmq
```

Estos directorios guardan datos fuera del ciclo de vida de los contenedores.

Asegúrate de que el usuario de Docker tenga los permisos necesarios para escribir en ellos.

### 5. Validar la configuración

Antes de iniciar los servicios:

```bash
docker compose config --quiet
docker compose -f sf/compose.yml config --quiet
```

Si utilizas variables de entorno adicionales, comprueba que estén definidas y que las rutas de los volúmenes y los contextos de compilación sean correctos.

### 6. Iniciar la infraestructura

Desde la raíz del repositorio:

```bash
docker compose up -d
```

Esto inicia los servicios definidos en el Compose raíz y los archivos incluidos: MariaDB, RabbitMQ y Mailpit.

Comprueba el estado:

```bash
docker compose ps
```

### 7. Iniciar Symfony

Desde la raíz del repositorio:

```bash
docker compose -f sf/compose.yml -p sf-stack up -d --build
```

Consulta el estado y los logs:

```bash
docker compose -f sf/compose.yml -p sf-stack ps

docker compose -f sf/compose.yml -p sf-stack logs -f sf-app sf-nginx
```

Abre la aplicación en:

**http://localhost:8080**

El archivo `sf-code/` debe contener una aplicación Symfony válida. Si no existe una aplicación en esa ubicación, prepara el código antes de iniciar el contenedor.

## Desarrollo frontend

Este entorno puede utilizar distintas estrategias para gestionar los assets de Symfony. Selecciona la que corresponda a tu aplicación.

### Opción A: Symfony AssetMapper e Importmap

AssetMapper permite gestionar assets sin depender de una compilación con Node.js para el flujo habitual de desarrollo.

Entre sus componentes se encuentran:

- Symfony AssetMapper.
- Symfony Importmap.
- Los archivos CSS y JavaScript de `assets/`.
- La publicación de assets en `public/assets/`.

En una aplicación que tenga estos componentes instalados, puedes ejecutar:

```bash
docker compose -f sf/compose.yml -p sf-stack exec sf-app \
  php bin/console asset-map:compile
```

El comando `asset-map:compile` está orientado a generar los assets para su publicación. No es necesario ejecutarlo después de cada cambio durante el desarrollo habitual.

La configuración final depende de las dependencias y de la estructura real de la aplicación Symfony.

### Opción B: Webpack Encore

Si la aplicación utiliza Webpack Encore, el entorno incluye Node.js y Yarn para gestionar dependencias y compilar los assets.

Desde el contenedor de PHP:

```bash
docker compose -f sf/compose.yml -p sf-stack exec sf-app yarn install
docker compose -f sf/compose.yml -p sf-stack exec sf-app yarn build
```

Para desarrollo con compilación automática, utiliza el script de vigilancia que defina el `package.json` de la aplicación, por ejemplo:

```bash
docker compose -f sf/compose.yml -p sf-stack exec sf-app yarn watch
```

El comando exacto depende de los scripts configurados en `package.json`.

**Importante:** el proceso de construcción de producción del Dockerfile actual utiliza Yarn. Si deseas soportar AssetMapper en producción, tendrás que adaptar ese proceso para compilar y copiar sus assets correctamente.

## Configuración de Nginx

Nginx sirve los archivos públicos de Symfony y reenvía las solicitudes PHP a PHP-FPM mediante FastCGI.

Archivo de referencia: `sf/nginx/default.conf`.

La configuración debe cumplir estos objetivos:

- Utilizar `public/` como raíz web.
- Enviar las rutas de la aplicación al controlador frontal `index.php`.
- Permitir la comunicación con `sf-app:9000`.
- Servir los archivos estáticos existentes.
- Evitar el acceso directo a archivos PHP arbitrarios, archivos ocultos y directorios internos.
- Proporcionar un endpoint de salud para Docker.

### Consideraciones importantes

- El nombre `sf-app` debe coincidir con el servicio PHP-FPM en la red Docker.
- El endpoint `/health` debe estar definido en Nginx para que el healthcheck funcione.
- El límite de carga de Nginx debe ser compatible con `upload_max_filesize` y `post_max_size` de PHP.
- La compresión gzip puede ser útil para respuestas de texto, pero no suele aportar ventajas a archivos ya comprimidos.
- No se debe confiar ciegamente en `X-Forwarded-Proto`: si existe un proxy inverso, debe configurarse como proxy de confianza y deben validarse los encabezados recibidos.
- La política CSP depende de los recursos utilizados por la aplicación. No se debe aplicar una política genérica sin comprobar que permite los scripts, estilos, fuentes e imágenes necesarios.

### Rate limiting opcional

Nginx permite limitar la frecuencia de solicitudes mediante `limit_req_zone` y `limit_req`. Sin embargo, `limit_req_zone` debe declararse en el contexto `http`, normalmente en la configuración principal de Nginx, y no dentro del bloque `server`.

Por eso, las directivas comentadas del archivo original no activan una protección contra exceso de solicitudes.

Si necesitas protección para una API o el inicio de sesión, configura los límites en el contexto correcto, aplica las reglas a las rutas específicas y prueba sus efectos antes de habilitarlas.

## Configuración de PHP

El contenedor utiliza PHP-FPM. Las opciones de desarrollo se encuentran en los archivos PHP del contexto de compilación.

### `php.ini` para desarrollo

Una configuración de referencia podría ser:

```ini
[PHP]
memory_limit = 1G

realpath_cache_size = 16M
realpath_cache_ttl = 600

short_open_tag = Off

upload_max_filesize = 50M
post_max_size = 100M

max_execution_time = 60
max_input_time = 60

date.timezone = "America/El_Salvador"

display_errors = On
display_startup_errors = On
error_reporting = E_ALL

log_errors = On
error_log = /var/log/php_errors.log

default_charset = "UTF-8"

session.cookie_httponly = 1
session.use_strict_mode = 1
```

Los valores de memoria y carga son ajustables. `memory_limit = 1G` es un límite por ejecución de PHP, no una reserva de 1 GB permanente para el contenedor.

En desarrollo se habilita la visualización de errores para facilitar la depuración. En producción debe desactivarse y los errores deben enviarse a los mecanismos de registro apropiados.

### OPcache para desarrollo

Una configuración de referencia:

```ini
[opcache]
opcache.enable = 1
opcache.enable_cli = 1

opcache.memory_consumption = 256
opcache.interned_strings_buffer = 20
opcache.max_accelerated_files = 20000

opcache.validate_timestamps = 1
opcache.revalidate_freq = 0

opcache.save_comments = 1
opcache.use_cwd = 1
```

Con `opcache.validate_timestamps = 1` y `opcache.revalidate_freq = 0`, OPcache comprueba las modificaciones en cada solicitud, lo que ayuda a que los cambios del código se reflejen inmediatamente durante el desarrollo.

`opcache.save_comments = 1` mantiene los comentarios de documentación que pueden necesitar herramientas y bibliotecas PHP.

No se incluye `opcache.fast_shutdown`, porque esta directiva se eliminó en PHP 7.2.

### Validar la configuración PHP

Después de construir el contenedor, verifica la configuración efectiva:

```bash
docker compose -f sf/compose.yml -p sf-stack exec sf-app php --ini
```

Para comprobar los valores de OPcache:

```bash
docker compose -f sf/compose.yml -p sf-stack exec sf-app \
  php -i | grep -E 'opcache.enable =>|opcache.validate_timestamps =>|opcache.revalidate_freq =>'
```

Si modificas los archivos de configuración que se copian durante la construcción de la imagen, vuelve a construir el contenedor:

```bash
docker compose -f sf/compose.yml -p sf-stack up -d --build
```

## MariaDB

MariaDB almacena los datos en `data/mariadb/`.

Variables de entorno habituales:

- `MYSQL_ROOT_PASSWORD`: contraseña del usuario administrador.
- `MYSQL_USER`: usuario de aplicación.
- `MYSQL_PASSWORD`: contraseña del usuario de aplicación.
- `MYSQL_DATABASE`: base de datos que utilizará Symfony, si la configuración del contenedor contempla su creación.

Comprueba que la base de datos exista y que el usuario de aplicación tenga los permisos adecuados.

El directorio `initdb/` permite proporcionar scripts de inicialización al contenedor. La ejecución de estos scripts depende de las reglas de inicialización de la imagen y, generalmente, de que el directorio de datos esté vacío en el primer arranque.

Para un entorno reproducible, fija una versión concreta de MariaDB en lugar de depender indefinidamente de la etiqueta `latest`.

## RabbitMQ

La interfaz de administración está disponible en:

**http://localhost:15672**

El usuario y la contraseña se configuran mediante:

```dotenv
RABBITMQ_USER=developer
RABBITMQ_PASSWORD=change-me-rabbitmq
```

Symfony puede comunicarse con RabbitMQ utilizando el nombre del servicio dentro de la red Docker, en lugar de `localhost`.

La conexión exacta debe definirse en las variables de entorno de Symfony y en la configuración de Messenger, si se utiliza.

El puerto de administración se publica solo en la interfaz local del host. No expongas la consola de administración directamente a Internet.

## Mailpit

La interfaz web está disponible en:

**http://localhost:8025**

En el entorno Docker, la aplicación puede utilizar el host `mailpit` y el puerto SMTP `1025`.

Ejemplo de DSN de desarrollo:

```dotenv
MAILER_DSN=smtp://mailpit:1025
```

Este DSN es válido cuando la aplicación y Mailpit comparten la misma red Docker y el servicio SMTP está configurado con esos valores.

Las opciones de Mailpit que permiten autenticación flexible o conexiones inseguras deben limitarse al desarrollo local. No utilices esta configuración como servidor de correo de producción.

## Persistencia y volúmenes

| Ruta | Propósito |
|---|---|
| `data/mariadb/` | Datos de MariaDB |
| `data/mailpit/data/` | Datos persistentes de Mailpit |
| `data/rabbitmq/` | Datos de RabbitMQ |
| `node_modules_data` | Dependencias frontend |
| `cache_data` | Caché Symfony |
| `log_data` | Logs Symfony |
| `composer_cache` | Caché de Composer |
| `npm_cache` | Caché de npm |

Los volúmenes permiten conservar datos y cachés al recrear los contenedores. No sustituyen una política de copias de seguridad.

No elimines los directorios de datos persistentes si necesitas conservar las bases de datos o los mensajes almacenados.

## Recursos y observabilidad

Los archivos Compose incluyen límites de CPU y memoria para controlar el consumo de recursos, además de healthchecks y rotación de logs.

Para comprobar los servicios:

```bash
docker compose ps
docker compose -f sf/compose.yml -p sf-stack ps
```

Para consultar los logs:

```bash
docker compose logs -f
docker compose -f sf/compose.yml -p sf-stack logs -f
```

Para observar el consumo de recursos:

```bash
docker stats
```

Los healthchecks indican si los servicios responden a las comprobaciones configuradas. No garantizan por sí solos que toda la aplicación esté funcionando correctamente.

## Detener los servicios

Detener la aplicación Symfony:

```bash
docker compose -f sf/compose.yml -p sf-stack down
```

Detener la infraestructura:

```bash
docker compose down
```

Estos comandos eliminan los contenedores correspondientes, pero normalmente conservan los volúmenes nombrados y los directorios persistentes. No añadas `-v` si necesitas conservar los datos.

## Buenas prácticas

- Utiliza `.env.example` para documentar las variables requeridas y mantén los secretos reales fuera del repositorio.
- Fija versiones concretas de las imágenes Docker para reducir cambios inesperados.
- Valida los archivos Compose antes de desplegar cambios.
- Mantén separadas las configuraciones de desarrollo y producción.
- No publiques directamente puertos de administración en interfaces de red públicas.
- Evita exponer información sensible mediante mensajes de error o logs.
- Configura los proxies de confianza de Symfony antes de depender de encabezados reenviados.
- Adapta CSP, cookies, HTTPS y rate limiting a las necesidades reales de la aplicación.
- Revisa las extensiones PHP y los paquetes instalados para conservar solo los necesarios en cada imagen.
- Prueba los cambios de Nginx y PHP después de reconstruir los contenedores.

## Limitaciones del entorno

Este repositorio está pensado principalmente para desarrollo local. No debe considerarse una distribución de producción lista para Internet sin una revisión adicional.

Antes de utilizarlo en producción, revisa al menos:

- Gestión de secretos.
- Versiones de imágenes y actualizaciones de seguridad.
- TLS y configuración del proxy inverso.
- Permisos y usuarios de los contenedores.
- Políticas de caché y encabezados HTTP.
- Configuración de OPcache para producción.
- Compilación y publicación de assets.
- Migraciones y estrategia de copias de seguridad.
- Límites de recursos y supervisión.
- Pruebas de integración y restauración de datos.

## Referencias

- [Symfony](https://symfony.com/doc/current/index.html)
- [Symfony AssetMapper](https://symfony.com/doc/current/asset_mapper.html)
- [Symfony Messenger](https://symfony.com/doc/current/messenger.html)
- [Docker Compose](https://docs.docker.com/compose/)
- [Nginx](https://nginx.org/en/docs/)
- [Configuración de OPcache en PHP](https://www.php.net/manual/en/opcache.configuration.php)
- [MariaDB Docker Official Image](https://hub.docker.com/_/mariadb)
- [RabbitMQ Docker Official Image](https://hub.docker.com/_/rabbitmq)
- [Mailpit](https://mailpit.axllent.org/)

## Licencia

Este proyecto se distribuye bajo la licencia MIT. Consulta el archivo `LICENSE` para conocer los términos completos.
