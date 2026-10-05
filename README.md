# Symfony Template

A Symfony 8.1 starter template running on PHP 8.4, pre-configured with Twig, Doctrine ORM, Tailwind CSS 4, Webpack Encore, and Symfony UX (Stimulus and Turbo). The development environment is containerized using Docker Compose, with PHP-FPM, Nginx, MySQL, and Mailpit.

Everything runs inside Docker. **You do not need PHP, Composer, Node, or NPM installed on your local machine.**

## 📋 Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.20.2 or newer, for health check `start_interval` support)

## 🚀 Getting Started (Development)

1. **Review the environment configuration:**

   The versioned `.env` file contains the defaults needed to run the development environment. The committed `.env.dev` supplies the development `APP_SECRET`, so a fresh checkout is ready to use these settings.

   Put personal overrides in `.env.local`, which is Git-ignored and takes precedence over `.env`.

2. **Start the development environment:**

   ```bash
   docker compose up --build -d
   ```

   *The first run builds the PHP image and downloads the service images. Nginx starts once PHP-FPM and MySQL are healthy.*

   On Linux, the PHP container uses UID/GID `1000:1000` by default. If your user has different IDs, prefix Compose commands with `env UID="$(id -u)" GID="$(id -g)"`, including the command above.

3. **Install dependencies and compile assets:**

   ```bash
   docker compose exec fpm composer install
   docker compose exec fpm npm ci
   docker compose exec fpm npm run dev
   ```

   Run Composer first: the frontend dependencies reference Symfony UX assets inside `vendor/`.

4. **Open the app:**

   Navigate to [http://localhost](http://localhost) in your browser.

   The project is mounted into the containers, so PHP and Twig changes are available on the next request. To rebuild frontend assets automatically, run this in a separate terminal:

   ```bash
   docker compose exec fpm npm run watch
   ```

   Refresh your browser after changes to `assets/` or Tailwind classes in templates. Compiled assets are written to `public/build/`.

5. **Stop the environment:**

   ```bash
   docker compose down
   ```

## 🛠️ Running Commands

Run PHP, Composer, and NPM commands inside the running **`fpm`** container using `docker compose exec fpm <command>`.

**Examples:**

- **Install a PHP dependency:**
  ```bash
  docker compose exec fpm composer require <package-name>
  ```
  Symfony Flex applies recipes for supported packages automatically.

- **Install a frontend dependency:**
  ```bash
  docker compose exec fpm npm install <package-name>
  ```

- **Generate a controller:**
  ```bash
  docker compose exec fpm php bin/console make:controller ExampleController --no-interaction
  ```

- **Inspect routes or clear the cache:**
  ```bash
  docker compose exec fpm php bin/console debug:router
  docker compose exec fpm php bin/console cache:clear
  ```

- **View container logs:**
  ```bash
  docker compose logs -f fpm nginx
  ```
  Symfony development logs are in `var/log/dev.log`, and the web profiler is available at [http://localhost/_profiler](http://localhost/_profiler).

## 🗄️ Database (Doctrine ORM)

MySQL 9.7.2 is configured in `compose.yaml`. The container creates the `app` database with the development username `app` and password `!ChangeMe!`.

Symfony connects to **`database:3306`** within Docker. Database tools on your host can connect to **`localhost:3306`** using the same credentials.

Schema changes use Doctrine migrations:

1. **Create or update an entity:**
   ```bash
   docker compose exec fpm php bin/console make:entity
   ```
   Follow the prompts to define the entity and its fields.

2. **Generate a migration:**
   ```bash
   docker compose exec fpm php bin/console make:migration --no-interaction
   ```

3. **Apply migrations:**
   ```bash
   docker compose exec fpm php bin/console doctrine:migrations:migrate --no-interaction
   ```

Migration files live in `migrations/`. Run the last command after pulling changes that include new migrations; migrations are applied manually.

## 📨 Background Jobs (Messenger)

Symfony Messenger is configured with a Doctrine-backed `async` transport and a `failed` queue in `config/packages/messenger.yaml`.

1. **Prepare the queue tables:**
   ```bash
   docker compose exec fpm php bin/console messenger:setup-transports
   ```
   The default DSN disables automatic table creation, so run this before dispatching queued messages.

2. **Create a message and handler:**
   ```bash
   docker compose exec fpm php bin/console make:message ExampleMessage --no-interaction
   ```
   Add your message class to the `routing` section of `config/packages/messenger.yaml` with `async` as its transport, then dispatch it using `MessageBusInterface`.

3. **Start a worker in a separate terminal:**
   ```bash
   docker compose exec fpm php bin/console messenger:consume async -vv
   ```

Email, chat, and SMS messages are already routed to `async`. The worker runs in the foreground; use Ctrl+C to stop it.

## ✉️ Development Email (Mailpit)

`compose.override.yaml` adds a Mailpit service, which Docker Compose loads automatically. To capture outgoing email, set the following in `.env.local`:

```dotenv
MAILER_DSN=smtp://mailer:1025
```

Start the Messenger worker described above so queued emails are sent. Find Mailpit's dynamically assigned web UI port with:

```bash
docker compose port mailer 8025
```

Open `http://localhost:<port>` using the returned host port. The default `null://null` mailer discards emails.

## 🧪 Testing

PHPUnit and Symfony's functional testing tools are included. Run the test suite inside the PHP container:

```bash
docker compose exec fpm php vendor/bin/phpunit
```

Tests live in `tests/` and use the `test` environment. Database-backed tests use the `app_test` database, as configured in `config/packages/doctrine.yaml`; provision it and grant the test database user access before running those tests. Put test-specific connection overrides in `.env.test.local`.

## 📦 Production

Build optimized, versioned frontend assets with:

```bash
docker compose exec fpm npm run build
```

The supplied Dockerfile and Compose files provide a development stack with mounted source code. Configure your production deployment with `APP_ENV=prod`, `APP_DEBUG=0`, a dedicated `APP_SECRET`, and production database and mailer settings. Install PHP dependencies with `composer install --no-dev --optimize-autoloader`, apply migrations, warm the production cache, and keep a Messenger worker running for asynchronous messages.

See the [Symfony deployment guide](https://symfony.com/doc/8.1/deployment.html) for the complete deployment workflow.
