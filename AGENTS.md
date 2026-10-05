# OpenCode Agent Instructions

## Docker Compose Requirement (Crucial)

- **ALL application commands MUST run through Docker Compose.** Do not use local PHP, Composer, Node, NPM, PHPUnit, or Symfony CLIs directly.
- Run commands inside the PHP container using `docker compose exec -T fpm <command>`. The `-T` flag disables terminal allocation for automated execution.
  - *Install PHP dependencies:* `docker compose exec -T fpm composer install`
  - *Add a PHP package:* `docker compose exec -T fpm composer require <package>`
  - *Install frontend dependencies:* `docker compose exec -T fpm npm ci`
  - *Add a frontend package:* `docker compose exec -T fpm npm install <package>`
  - *Run the Symfony console:* `docker compose exec -T fpm php bin/console <command>`
- Start the development environment with `docker compose up --build -d`. Nginx serves the app at `http://localhost` on port `80` after MySQL and PHP-FPM become healthy.
- The source code is mounted at `/var/www/html`, so host edits sync automatically. PHP and Twig changes are available on the next request.
- The PHP container defaults to UID/GID `1000:1000`. On Linux, if the host user has different IDs, prefix Compose commands with `env UID="$(id -u)" GID="$(id -g)"`.
- Install Composer dependencies before NPM dependencies: Symfony UX frontend packages reference files in `vendor/`.

## Database & Doctrine ORM

- **MySQL 9.7.2 is the default**, configured in `compose.yaml` and the versioned `.env`. Doctrine ORM and Doctrine Migrations are installed.
- Connect to `database:3306` inside Docker, or `localhost:3306` from the host. Development database, username, and password are `app`, `app`, and `!ChangeMe!`.
- Schema changes MUST go through migrations. Do not use `doctrine:schema:update` or hand-written SQL to change the schema.
  - *Generate a migration:* `docker compose exec -T fpm php bin/console make:migration --no-interaction`
  - *Apply migrations:* `docker compose exec -T fpm php bin/console doctrine:migrations:migrate --no-interaction`
- Migrations live in `migrations/` and are applied manually; container startup does not run them.
- If a task requires switching databases, update the Compose service and `DATABASE_URL`, including the matching server version. Install any required PHP extensions through the Dockerfile and rebuild the PHP image.
- Tests use the `app_test` database by default. Database-backed tests require that database and appropriate user permissions; use `.env.test.local` for test-specific connection overrides.

## Project Constraints & Symfony Conventions

- The project uses Symfony 8.1 and PHP 8.4. Check `composer.json`, `composer.lock`, and `symfony.lock` for current versions, dependencies, and Flex recipes before using framework APIs.
- Twig, Forms, Validator, Serializer, SecurityBundle, Messenger, and MakerBundle are installed. Confirm other capabilities, such as API Platform or Lock, before using them.
- Use the existing Doctrine/Twig stack for related features. Ask before introducing a different persistence layer, an API stack, or an authentication flow whose requirements are unspecified.
- Install new Symfony capabilities with `docker compose exec -T fpm composer require <package>` and let Flex register bundles and generate base configuration. Avoid hand-wiring bundle registration or duplicating recipe configuration.
- Use PHP attributes for application routes, validation, security, commands, listeners, message handlers, and service metadata. Do not add YAML or XML application routes.
- Rely on autowiring and autoconfiguration. Prefer typed constructor arguments, `#[Autowire]`, and `#[Target]` over YAML service definitions.
- Controllers extend `AbstractController`, stay thin, and delegate work to services. Use Form, Validator, Security voters/authenticators, and Twig `path()`/`url()` for their respective concerns.
- Bind request data with `#[MapRequestPayload]` or `#[MapQueryString]` instead of manual JSON parsing. Use constructor property promotion and `readonly` DTOs/value objects; avoid `readonly` service classes that need inheritance-based lazy proxies.
- Prefer Symfony components for infrastructure. Use `symfony/lock` and `LockFactory` for mutual exclusion rather than custom flags or lock files.
- `.env` is versioned and contains shared defaults. Personal overrides and real secrets belong in Git-ignored `.env.local` files or the Symfony secrets vault; read configuration through `%env(...)%` or `#[Autowire]`.
- The Dockerfile and Compose files provide a development stack with mounted source code. Scope infrastructure and reverse-proxy changes to tasks that require them; consult `README.md` for production guidance.

## Frontend Assets

- Webpack Encore is configured in `webpack.config.js`; assets live in `assets/` and compile to `public/build/`.
- Tailwind CSS 4 is configured through `@tailwindcss/postcss` in `postcss.config.mjs` and imported in `assets/styles/app.css`. Keep this PostCSS setup when adding styles.
- Stimulus and Turbo are installed through Symfony UX. Follow the existing controllers and bootstrap configuration in `assets/`.
  - *Build development assets:* `docker compose exec -T fpm npm run dev`
  - *Watch asset changes:* `docker compose exec -T fpm npm run watch`
  - *Build production assets:* `docker compose exec -T fpm npm run build`
- Watch mode rebuilds assets; refresh the browser after changes. Do not edit generated files in `public/build/`, `vendor/`, or `node_modules/`.

## Background Jobs & Development Email

- Messenger uses Doctrine-backed `async` and `failed` transports, configured in `config/packages/messenger.yaml`.
- The default DSN disables automatic queue table creation. Prepare transports with `docker compose exec -T fpm php bin/console messenger:setup-transports` before dispatching queued messages.
- Start a worker with `docker compose exec -T fpm php bin/console messenger:consume async -vv`. It runs in the foreground and is not started automatically by Compose.
- Route custom message classes to `async` when asynchronous execution is required, and use `#[AsMessageHandler]` for handlers. Email, chat, and SMS messages are already routed to `async`.
- `compose.override.yaml` adds Mailpit. To capture development email, set `MAILER_DSN=smtp://mailer:1025` in `.env.local` and run the Messenger worker. The default `null://null` mailer discards emails.
- Find Mailpit's web UI port with `docker compose port mailer 8025`, then open `http://localhost:<port>`.

## Workflow, Testing & Code Style

- Before changing code for a failure, read `var/log/dev.log` and the web profiler at `http://localhost/_profiler`. Container logs are available through `docker compose logs -f fpm nginx`.
- Prefer MakerBundle commands with all arguments supplied and `--no-interaction` where supported. If a maker still needs interactive input, write the code directly instead of hanging an automated shell.
- Discover available APIs and configuration with `docker compose exec -T fpm php bin/console about`, `debug:router`, `debug:container`, `debug:autowiring <name>`, `debug:config <bundle>`, and `config:dump-reference <bundle>`. Read installed source and docblocks in `vendor/` when needed.
- PHPUnit, BrowserKit, and CSS Selector are installed. Functional/HTTP tests extend `WebTestCase`; service-level integration tests extend `KernelTestCase`. Test features through the interface a caller uses and assert meaningful behavior.
- Run tests with `docker compose exec -T fpm php vendor/bin/phpunit`.
- Run relevant checks before completing changes:
  - `docker compose exec -T fpm php bin/console lint:container`
  - `docker compose exec -T fpm php bin/console lint:twig templates/`
  - `docker compose exec -T fpm php bin/console lint:yaml config/`
  - `docker compose exec -T fpm npm run dev` for frontend changes.
- Follow Symfony's coding standard (`@Symfony` PHP-CS-Fixer ruleset). If `friendsofphp/php-cs-fixer` is installed, run `docker compose exec -T fpm php vendor/bin/php-cs-fixer fix`; it is not included by default.

## Documentation

Consult these guides before working on related tasks, using the Symfony version matching `composer.json`:

- [Symfony best practices](https://symfony.com/doc/8.1/best_practices.html)
- [Controllers and routing](https://symfony.com/doc/8.1/routing.html)
- [Twig templates](https://symfony.com/doc/8.1/templates.html)
- [Doctrine databases and migrations](https://symfony.com/doc/8.1/doctrine.html)
- [Forms and validation](https://symfony.com/doc/8.1/forms.html)
- [Security and authentication](https://symfony.com/doc/8.1/security.html)
- [Serializer and JSON APIs](https://symfony.com/doc/8.1/serializer.html)
- [Messenger and asynchronous work](https://symfony.com/doc/8.1/messenger.html)
- [Webpack Encore](https://symfony.com/doc/8.1/frontend/encore/index.html)
- [StimulusBundle](https://symfony.com/bundles/StimulusBundle/current/index.html) and [UX Turbo](https://symfony.com/bundles/ux-turbo/current/index.html)
- [Tailwind CSS with PostCSS](https://tailwindcss.com/docs/installation/using-postcss)
- [Testing](https://symfony.com/doc/8.1/testing.html)
