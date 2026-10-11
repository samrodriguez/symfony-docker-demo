# Symfony Docker Demo

A reusable Docker-based development environment for Symfony applications, built with PHP 8.4, Nginx, MariaDB, RabbitMQ and Mailpit.

The goal of this project is to provide a consistent local development environment with separate services, persistent data, configurable PHP settings and a dedicated web server.

## Features

- **PHP 8.4-FPM** running in a dedicated container.
- **Nginx** configured as the web server and FastCGI reverse proxy.
- **MariaDB** for relational database storage.
- **RabbitMQ Management** for asynchronous messaging and queue development.
- **Mailpit** for testing outgoing emails locally.
- **Docker Compose** for service orchestration.
- Persistent volumes and bind mounts for application data and development workflows.
- PHP development configuration with OPcache.
- Support for Symfony applications using Webpack Encore or AssetMapper, subject to the asset workflow configured by the application.
- Local-only port bindings for development services.

> **Scope:** This project is intended as a local development foundation. Review security settings, resource limits, image versions, secrets and networking before adapting it for staging or production.

## Architecture

| Service | Purpose | Local endpoint |
|---|---|---|
| Symfony PHP-FPM | Executes PHP and Symfony | Internal Docker network |
| Nginx | Serves static assets and forwards PHP requests | `http://localhost:8080` |
| MariaDB | Relational database | `127.0.0.1:3306` |
| RabbitMQ Management | Queue and broker administration | `http://localhost:15672` |
| Mailpit | Email testing interface | `http://localhost:8025` |

The PHP-FPM service is reached by Nginx through the internal Docker network. The application should use service names such as `mariadb`, `rabbitmq` and `mailpit` to communicate with the corresponding containers.

Ports published on `127.0.0.1` are intended to remain accessible only from the host machine, rather than from other devices on the network.

## Requirements

- Docker Engine.
- Docker Compose v2 with support for the `include` directive.
- Git.
- A Symfony application in the expected application source directory.
- Sufficient memory and CPU resources for the containers and development tools.

Check your Docker installation:

```bash
docker --version
docker compose version
docker compose config --help
```

## Project structure

The following structure describes the intended organization. Adjust it to match the files actually committed to the repository.

```text
symfony-docker-demo/
├── compose.yml
├── .env
├── .env.example
├── .gitignore
├── LICENSE
├── README.md
│
├── databases/
│   └── mariadb/
│       ├── compose.yml
│       └── initdb/
│
├── development/
│   ├── mailpit/
│   │   └── compose.yml
│   └── rabbitmq/
│       └── compose.yml
│
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
│
├── sf-code/
│   └── Symfony application source
│
└── data/
    ├── mariadb/
    ├── mailpit/
    └── rabbitmq/
```

The `sf-code/` directory contains the Symfony application. The `data/` directory stores persistent service data and should not be treated as disposable application code.

## 1. Configure environment variables

Create your local environment file from the example:

```bash
cp .env.example .env
```

If the repository intentionally tracks a `.env` containing only safe sample values, review those values before running the project. Never commit real passwords, production credentials, private keys or API tokens.

Example variables:

```dotenv
APPENV=dev

HOST_UID=1000
HOST_GID=1000

TZ=America/El_Salvador

MYSQL_ROOT_PASSWORD=change_me_root
MYSQL_USER=symfony
MYSQL_PASSWORD=change_me_password

RABBITMQ_USER=symfony
RABBITMQ_PASSWORD=change_me_rabbitmq_password
```

Use values appropriate for your environment. The sample passwords above are placeholders, not secure production credentials.

Ensure the variables used by Compose are defined. If the project uses additional variables, add them to `.env.example` and document their purpose.

## 2. Prepare the Docker network and persistent directories

The Compose files use an external network named `app-network`. Create it before starting the services:

```bash
docker network inspect app-network >/dev/null 2>&1 \
  || docker network create app-network
```

Create the persistent directories:

```bash
mkdir -p \
  data/mariadb \
  data/mailpit/data \
  data/rabbitmq
```

Verify the expected directories:

```bash
find data -maxdepth 3 -type d
```

The host user running the project must have the necessary permissions for the bind-mounted directories. Avoid solving permission issues by making all files world-writable.

## 3. Validate the Compose configuration

Before starting any container, validate the root Compose file:

```bash
docker compose -f compose.yml config --quiet
```

Then validate the application stack:

```bash
docker compose -f sf/compose.yml config --quiet
```

The root configuration uses Compose `include` to load the infrastructure stacks. Confirm that the included files and external network declarations resolve correctly with the installed Docker Compose version.

If validation reports an error, resolve it before building or starting the containers.

## 4. Start the infrastructure

From the repository root, start the services declared in the root Compose file:

```bash
docker compose -f compose.yml up -d
```

Check their status:

```bash
docker compose -f compose.yml ps
```

Review the logs if necessary:

```bash
docker compose -f compose.yml logs -f
```

The root stack includes the infrastructure services. The Symfony application stack is started separately.

## 5. Build and start Symfony

Build the PHP-FPM image and start the application and Nginx services:

```bash
docker compose -f sf/compose.yml up -d --build
```

Check the application stack:

```bash
docker compose -f sf/compose.yml ps
```

Follow the logs:

```bash
docker compose -f sf/compose.yml logs -f sf-app sf-nginx
```

Open the application:

- Symfony: `http://localhost:8080`
- Mailpit: `http://localhost:8025`
- RabbitMQ Management: `http://localhost:15672`

The database is available to services on the Docker network through its service hostname and internal port. Host-side tools can connect through `127.0.0.1:3306`.

### Symfony application setup

Enter the PHP container:

```bash
docker compose -f sf/compose.yml exec sf-app bash
```

Inside the container, run the commands required by the application. For example:

```bash
composer install
php bin/console about
php bin/console cache:clear
```

If the application requires a database, configure its `DATABASE_URL`, create the database if necessary, and run its migrations.

A typical Symfony configuration may use a DSN such as:

```dotenv
DATABASE_URL="mysql://symfony:change_me_password@mariadb:3306/symfony?serverVersion=10.11-MariaDB&charset=utf8mb4"
```

Adapt the database name, credentials and server version to the actual MariaDB image and database configuration. Do not copy this example blindly if those values differ.

The current MariaDB Compose configuration should also be reviewed to ensure the intended application database is created and the configured user has the required privileges.

## Nginx configuration

The Nginx configuration is maintained in:

```text
sf/nginx/default.conf
```

It is mounted into the Nginx container as `/etc/nginx/conf.d/default.conf`.

The configuration is responsible for:

- Serving the Symfony `public/` directory.
- Forwarding requests for `index.php` to PHP-FPM.
- Returning a local health-check response at `/health`.
- Denying direct access to PHP files other than the front controller.
- Protecting hidden files and sensitive application directories.
- Serving static assets directly.
- Configuring compression, response headers and request size limits.
- Writing access and error logs.

### Recommended Nginx baseline

Use the following as a reference for the local development configuration. Adapt it if the application uses additional entry points, asset paths or image-processing bundles.

```nginx
server {
    listen 80;
    server_name sf.local localhost;

    root /var/www/html/public;
    index index.php;

    server_tokens off;

    # Local container health check.
    location = /health {
        access_log off;
        default_type text/plain;
        return 200 "OK";
    }

    # Symfony front controller.
    location / {
        try_files $uri /index.php$is_args$args;
    }

    # PHP-FPM: execute only the Symfony front controller.
    location ~ ^/index\.php(/|$) {
        internal;

        fastcgi_pass sf-app:9000;
        fastcgi_split_path_info ^(.+\.php)(/|$);

        include fastcgi_params;

        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $document_root;
        fastcgi_param PATH_INFO $fastcgi_path_info;

        fastcgi_connect_timeout 30s;
        fastcgi_send_timeout 60s;
        fastcgi_read_timeout 120s;

        fastcgi_buffer_size 16k;
        fastcgi_buffers 8 16k;
    }

    # Never execute other PHP files.
    location ~ \.php(?:$|/) {
        return 404;
    }

    # Deny hidden files, including .env and .git.
    location ~ /\.(?!well-known/) {
        deny all;
    }

    # Protect application source and configuration directories.
    location ~ ^/(?:config|src|var|translations|migrations)(?:/|$) {
        deny all;
    }

    # Static files: serve only existing files.
    location ~* \.(?:css|js|png|jpg|jpeg|gif|ico|svg|webp|woff2?|ttf|eot|otf)$ {
        try_files $uri =404;
        access_log off;
        log_not_found off;
        expires 1h;
        add_header Cache-Control "public";
    }

    # Local development compression.
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 5;
    gzip_types
        text/plain
        text/css
        text/xml
        application/json
        application/javascript
        application/xml
        image/svg+xml;

    # Basic security headers.
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    client_max_body_size 50M;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;
}
```

**Important notes:**

- The PHP-FPM hostname `sf-app` must match the service name on the shared Docker network.
- `internal` prevents clients from calling the front-controller FastCGI location directly; normal Symfony routes are internally redirected there.
- The static-asset cache duration is intentionally short for development. Longer caching is better suited to fingerprinted assets in a production build.
- The example does not trust `X-Forwarded-Proto` to set the PHP `HTTPS` parameter. If the application is behind a reverse proxy that terminates TLS, configure trusted proxies correctly in Symfony and only trust headers from known proxy infrastructure.
- A restrictive Content Security Policy should be designed and tested for the specific application. Do not add a generic CSP blindly: it may break JavaScript, CSS, fonts, images or third-party integrations.
- Rate limiting is optional. Nginx's `limit_req_zone` directive belongs in the `http` context, not inside the `server` block. A zone must be declared at the appropriate level before using `limit_req` in a location.
- If the application uses LiipImagineBundle, verify that the generated cache path exists and that the Nginx rules serve generated files correctly. Do not place nested `location` blocks inside a regex `location` block.

Validate the Nginx configuration:

```bash
docker compose -f sf/compose.yml exec sf-nginx nginx -t
```

Reload Nginx after a configuration change:

```bash
docker compose -f sf/compose.yml exec sf-nginx nginx -s reload
```

## PHP development configuration

The PHP development configuration is stored in:

```text
sf/php84-fpm/php/dev/php.ini
sf/php84-fpm/php/dev/opcache.ini
```

These files are intended for local development and should be kept separate from production configuration.

### Recommended `php.ini` for development

```ini
[PHP]
memory_limit = 512M

realpath_cache_size = 16M
realpath_cache_ttl = 600

short_open_tag = Off

upload_max_filesize = 50M
post_max_size = 100M

max_execution_time = 60
max_input_time = 60

date.timezone = America/El_Salvador

display_errors = On
display_startup_errors = On
error_reporting = E_ALL

log_errors = On
error_log = /var/log/php_errors.log

default_charset = UTF-8

session.cookie_httponly = 1
session.use_strict_mode = 1
```

The `memory_limit` is set to `512M` as a conservative starting point. Increase it if Composer, tests or application workloads require more memory and the Docker container has sufficient resources.

`display_errors = On` is appropriate for local development, but should not be used for production applications exposed to users.

### Recommended `opcache.ini` for development

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

These settings enable OPcache while allowing PHP to detect changes to source files immediately, which is useful when the application source is mounted into the container.

`opcache.enable_cli` can improve performance for some CLI workloads, but it is not always necessary. If you encounter confusing behavior during tests or console commands, consider disabling CLI OPcache.

`opcache.fast_shutdown` is intentionally omitted because it is obsolete in modern PHP versions. The `opcache.file_cache` setting is also omitted because it is not required for this baseline.

After modifying PHP configuration, rebuild or recreate the PHP container so that the updated files are loaded:

```bash
docker compose -f sf/compose.yml up -d --build
```

Inspect the active configuration:

```bash
docker compose -f sf/compose.yml exec sf-app php --ini
docker compose -f sf/compose.yml exec sf-app php -i
```

For a concise OPcache check:

```bash
docker compose -f sf/compose.yml exec sf-app \
  php -r 'var_export(opcache_get_status(false));'
```

The last command may report that OPcache is unavailable if it is not enabled for the PHP CLI SAPI.

## Frontend asset management

Symfony applications may use different asset workflows. Choose the one configured in the application rather than running both workflows indiscriminately.

### Option A: Webpack Encore

For applications using Webpack Encore:

```bash
yarn install
yarn dev
```

For a production asset build:

```bash
yarn install
yarn build
```

Use the scripts defined in the application's `package.json`; script names may differ between projects.

The production Docker builder currently uses Yarn commands. Confirm that the package manifests, lockfile and build scripts are present in the build context.

### Option B: AssetMapper and Importmap

For applications using Symfony AssetMapper:

```bash
php bin/console debug:config framework
php bin/console asset-map:compile
```

The exact commands depend on the packages and Symfony configuration installed in the application.

The production image builder must be adapted for AssetMapper if it currently assumes `yarn install && yarn build`. A successful development workflow does not automatically mean the production build supports both asset systems.

## Database, RabbitMQ and email development

### MariaDB

Connect from other containers using the MariaDB service name and internal port:

```text
Host: mariadb
Port: 3306
```

The host port is published on `127.0.0.1:3306` for local database tools.

Ensure that the database name and user privileges match the Symfony `DATABASE_URL`. Initialization scripts in the MariaDB initialization directory run according to the official image's initialization behavior; they are not automatically rerun against an already initialized data directory.

### RabbitMQ

The management interface is available at:

```text
http://localhost:15672
```

Symfony applications should use the internal service hostname and port for AMQP connections. Configure credentials through environment variables and use a DSN appropriate for the messaging transport installed in the application.

The management interface and default development credentials must not be exposed publicly without additional security controls.

### Mailpit

Open the Mailpit interface at:

```text
http://localhost:8025
```

The SMTP service is reachable from containers on the shared Docker network:

```text
mailpit:1025
```

A typical local Symfony mailer DSN is:

```dotenv
MAILER_DSN=smtp://mailpit:1025
```

Mailpit is for development and testing, not a production mail delivery service. Authentication settings that accept arbitrary credentials or insecure SMTP are suitable only for an isolated local development environment.

## Persistence

The stack uses persistent bind mounts and named volumes to preserve data across container recreation.

| Data | Storage |
|---|---|
| MariaDB database files | `data/mariadb/` |
| Mailpit data | `data/mailpit/data/` |
| RabbitMQ data | `data/rabbitmq/` |
| Symfony application source | `sf-code/` |
| Composer and npm caches | Named Docker volumes |
| Symfony cache and logs | Named Docker volumes |
| Node modules | Named Docker volume |

Removing a container does not necessarily remove its persistent data. Conversely, deleting bind-mounted directories or explicitly removing volumes can permanently delete data.

Do not remove database directories or Docker volumes unless you understand the consequences.

## Resource limits

The Compose files define resource limits for individual services. Review them according to the host machine and workload.

For a local development environment:

- PHP-FPM may need additional memory for Composer, tests and static analysis.
- MariaDB needs enough memory for its buffer pool and active connections.
- RabbitMQ needs a memory limit consistent with its configured memory watermark.
- Nginx generally requires much less memory than PHP-FPM.

Container limits are not a substitute for measuring actual resource consumption. Check the running containers:

```bash
docker stats
```

## Maintenance and troubleshooting

### Check service status

```bash
docker compose -f compose.yml ps
docker compose -f sf/compose.yml ps
```

### Inspect logs

```bash
docker compose -f compose.yml logs --tail=100
docker compose -f sf/compose.yml logs --tail=100
```

### Validate the Compose configuration

```bash
docker compose -f compose.yml config --quiet
docker compose -f sf/compose.yml config --quiet
```

### Rebuild the PHP image

```bash
docker compose -f sf/compose.yml up -d --build
```

### Stop the application stack

```bash
docker compose -f sf/compose.yml down
```

### Stop the infrastructure stack

```bash
docker compose -f compose.yml down
```

Do not add `--volumes` unless you intend to remove the named volumes managed by the relevant Compose project. Bind-mounted data directories on the host are separate and may remain after containers stop.

## Security and maintenance recommendations

- Prefer explicit, maintained image versions over floating tags such as `latest` for reproducible environments.
- Update image tags deliberately and test compatibility before upgrading.
- Keep real credentials and production secrets out of Git.
- Bind development-only ports to `127.0.0.1` unless remote access is intentionally required.
- Do not use development PHP settings in production.
- Review Nginx security headers and Content Security Policy for each application.
- Configure Symfony trusted proxies when running behind a reverse proxy.
- Ensure the PHP-FPM, Nginx and infrastructure services share the intended Docker network.
- Validate the Dockerfiles, Compose files and Nginx configuration before treating the project as ready to use.
- Verify the production build separately from the local development workflow.

## Useful documentation

- [Symfony documentation](https://symfony.com/doc/current/index.html)
- [Symfony deployment documentation](https://symfony.com/doc/current/deployment.html)
- [Symfony AssetMapper](https://symfony.com/doc/current/frontend/asset_mapper.html)
- [Docker Compose documentation](https://docs.docker.com/compose/)
- [Nginx documentation](https://nginx.org/en/docs/)
- [PHP OPcache documentation](https://www.php.net/manual/en/book.opcache.php)
- [MariaDB Docker image](https://hub.docker.com/_/mariadb)
- [RabbitMQ Docker image](https://hub.docker.com/_/rabbitmq)
- [Mailpit documentation](https://mailpit.axllent.org/)

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
