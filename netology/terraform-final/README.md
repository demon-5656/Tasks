# Итоговый проект модуля «Облачная инфраструктура. Terraform»

В качестве приложения я взял свой проект [`legacy-100-years`](https://github.com/demon-5656/legacy-100-years). Это браузерная игра, которую я доработал под итоговый проект: добавил backend, регистрацию пользователей, подтверждение почты, восстановление пароля и сохранение прогресса в MySQL.

Получилось не просто поднять условный nginx, а развернуть приложение, которому реально нужны frontend, backend, база и переменные окружения.

## Что сделано

- описана VPC и две подсети;
- добавлены security groups для VM и MySQL;
- описана VM для приложения;
- через `cloud-init` ставятся Docker и Docker Compose;
- описан Yandex Managed MySQL;
- описан Yandex Container Registry;
- добавлен Lockbox для секретов приложения;
- backend приложения подключается к MySQL;
- Dockerfile приложения уже содержит multi-stage сборку;
- Docker Compose для облака использует образы из Container Registry;
- state рассчитан на хранение в S3 bucket с lock-файлом.

Код Terraform лежит в [`src`](src).

## Схема

Общая логика такая:

```text
Пользователь
    |
    | 80/443
    v
VM в Yandex Cloud
    |
    | Docker Compose
    v
nginx container -> api container
                    |
                    | 3306
                    v
              Yandex Managed MySQL

Container Registry хранит образы web/api.
Lockbox хранит пароль БД, JWT secret и SMTP password.
Remote state хранится в Object Storage.
```

## Задание 1. Инфраструктура

VPC создается ресурсом:

```hcl
resource "yandex_vpc_network" "app" {
  name = "${var.app_name}-vpc"
}
```

Подсети сделал через `for_each`, чтобы не копировать почти одинаковые блоки:

```hcl
resource "yandex_vpc_subnet" "this" {
  for_each = var.subnets

  name           = "${var.app_name}-${each.key}"
  zone           = each.value.zone
  network_id     = yandex_vpc_network.app.id
  v4_cidr_blocks = [each.value.cidr]
}
```

В переменных сейчас две подсети:

- `app-a` для VM;
- `db-b` для MySQL.

Security groups:

- для VM открыты `22`, `80`, `443`;
- для MySQL открыт `3306` только от security group приложения.

Это важный момент: базу не надо светить наружу, к ней должен ходить только backend.

## Задание 2. Docker через cloud-init

VM создается в [`src/compute.tf`](src/compute.tf). В `metadata.user-data` передается шаблон [`src/templates/cloud-init.yml`](src/templates/cloud-init.yml).

В cloud-init делается следующее:

```text
1. создается пользователь ubuntu;
2. добавляется SSH-ключ;
3. ставится Docker CE и docker compose plugin;
4. клонируется репозиторий приложения;
5. создается .env для compose;
6. запускается docker compose.
```

Да, `.env` оказывается на сервере. Это нормально для runtime-конфига, но его нельзя коммитить. В репозитории лежит только пример.

## Задание 3. Dockerfile и Container Registry

В приложении есть multi-stage [`Dockerfile`](https://github.com/demon-5656/legacy-100-years/blob/main/Dockerfile):

- `deps` ставит npm-зависимости;
- `frontend-build` собирает React/Vite frontend;
- `web` собирает nginx-образ со статикой;
- `api` собирает Node.js backend.

Локально образы собираются так:

```bash
docker build --target web -t legacy-100-years-web:local .
docker build --target api -t legacy-100-years-api:local .
```

После создания registry Terraform выводит адрес:

```bash
terraform output registry_url
```

Дальше образы можно затегать и отправить в Yandex Container Registry:

```bash
export CR_REGISTRY="$(terraform -chdir=src output -raw registry_url)"

docker tag legacy-100-years-web:local "$CR_REGISTRY/legacy-100-years-web:latest"
docker tag legacy-100-years-api:local "$CR_REGISTRY/legacy-100-years-api:latest"

docker push "$CR_REGISTRY/legacy-100-years-web:latest"
docker push "$CR_REGISTRY/legacy-100-years-api:latest"
```

## Задание 4. Приложение и БД

Backend приложения использует env-переменные:

```text
MYSQL_HOST
MYSQL_PORT
MYSQL_DATABASE
MYSQL_USER
MYSQL_PASSWORD
MYSQL_SSL
```

В Terraform база описана в [`src/mysql.tf`](src/mysql.tf):

- создается Managed MySQL cluster;
- создается база `legacy_100_years`;
- создается пользователь приложения;
- пользователю выдаются права на эту базу.

В приложении backend сам создает нужные таблицы при старте:

- `users`;
- `email_verification_tokens`;
- `password_reset_tokens`;
- `game_saves`.

Мне такой вариант тут кажется нормальным: Terraform отвечает за инфраструктуру и managed database, а приложение само ведет свою схему. Для маленького проекта это проще, чем отдельно тащить мигратор.

## Задание 5*. Lockbox

Добавил Lockbox:

```hcl
resource "yandex_lockbox_secret" "app" {
  name = "${var.app_name}-secrets"
}
```

В secret version складываются:

- `mysql_password`;
- `jwt_secret`;
- `smtp_password`.

В текущем варианте Terraform получает значения из локального `personal.auto.tfvars`, создает ресурсы и кладет эти же значения в Lockbox. Для боевого варианта я бы сделал жестче: сначала создал секрет руками или отдельным bootstrap-кодом, а основной Terraform уже читал бы его через data source. Но для учебного проекта сама интеграция с Lockbox описана и есть в коде.

## Remote state

Backend описан в [`src/providers.tf`](src/providers.tf):

```hcl
backend "s3" {
  key    = "terraform-final/terraform.tfstate"
  region = "ru-central1"

  endpoints = {
    s3 = "https://storage.yandexcloud.net"
  }

  use_lockfile = true
}
```

Реальные ключи для backend не лежат в Git. Для них есть пример [`src/backend.hcl.example`](src/backend.hcl.example), а настоящий `backend.hcl` игнорируется.

Инициализация с remote state:

```bash
terraform -chdir=src init -backend-config=backend.hcl
```

Для локальной проверки синтаксиса я использовал:

```bash
terraform -chdir=src init -backend=false
```

## Проверки

Terraform:

- [`evidence/01_terraform_fmt.txt`](evidence/01_terraform_fmt.txt);
- [`evidence/02_terraform_init_backend_false.txt`](evidence/02_terraform_init_backend_false.txt);
- [`evidence/03_terraform_validate.txt`](evidence/03_terraform_validate.txt).

Приложение:

- репозиторий: [`demon-5656/legacy-100-years`](https://github.com/demon-5656/legacy-100-years);
- commit приложения: [`evidence/00_app_repo_commit.txt`](evidence/00_app_repo_commit.txt).

## Что приложить скринами после apply

Чтобы отчет был прям совсем закрыт для проверки, после реального запуска нужно добавить скрины:

1. `terraform apply` с созданными ресурсами.
2. `terraform output` с IP/registry.
3. VM в Yandex Cloud.
4. Managed MySQL cluster.
5. Container Registry с двумя образами.
6. Lockbox secret.
7. Открытая страница приложения по IP или DNS.
8. Регистрация пользователя.
9. Письмо подтверждения или dev-лог SMTP, если почта еще не настроена.
10. Проверка сохранения прогресса после повторного входа.

Сейчас кодовая часть готова и проходит `terraform validate`. Финальный `apply` я бы запускал уже когда понятно, что можно спокойно создать платные ресурсы в Yandex Cloud.
