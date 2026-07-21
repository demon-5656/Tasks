# Итоговый проект модуля «Облачная инфраструктура. Terraform»

Для итогового проекта использовано приложение [`legacy-100-years`](https://github.com/demon-5656/legacy-100-years). Это web-приложение с frontend, backend, авторизацией пользователей, подтверждением почты, восстановлением пароля и сохранением игрового прогресса в MySQL.

Такой вариант выбран, потому что для него нужна полноценная инфраструктура: VM, Docker, Container Registry, managed database, переменные окружения и хранение секретов.

## Состав решения

- VPC и две подсети в Yandex Cloud;
- security groups для приложения и MySQL;
- VM для запуска приложения;
- установка Docker и Docker Compose через `cloud-init`;
- Yandex Managed MySQL;
- Yandex Container Registry;
- Lockbox для секретов приложения;
- remote state в Object Storage с lock-файлом;
- Docker Compose для запуска frontend/backend контейнеров;
- подключение backend к Managed MySQL.

Terraform-код находится в каталоге [`src`](src).

## Архитектура

```text
Пользователь
    |
    | HTTP/HTTPS
    v
VM в Yandex Cloud
    |
    | Docker Compose
    v
nginx container -> api container
                    |
                    | MySQL 3306
                    v
              Yandex Managed MySQL

Container Registry хранит Docker-образы web/api.
Lockbox хранит пароль БД, JWT secret и SMTP password.
Terraform state хранится в Object Storage.
```

## Задание 1. Инфраструктура в Yandex Cloud

VPC описана ресурсом `yandex_vpc_network`:

```hcl
resource "yandex_vpc_network" "app" {
  name = "${var.app_name}-vpc"
}
```

Подсети создаются через `for_each`:

```hcl
resource "yandex_vpc_subnet" "this" {
  for_each = var.subnets

  name           = "${var.app_name}-${each.key}"
  zone           = each.value.zone
  network_id     = yandex_vpc_network.app.id
  v4_cidr_blocks = [each.value.cidr]
}
```

В конфигурации используются две подсети:

- `app-a` для VM с приложением;
- `db-b` для Managed MySQL.

Для VM открыты порты:

- `22` для SSH;
- `80` для HTTP;
- `443` для HTTPS.

Для MySQL открыт порт `3306` только от security group приложения. База не доступна напрямую из интернета.

Файлы:

- [`src/network.tf`](src/network.tf);
- [`src/compute.tf`](src/compute.tf);
- [`src/mysql.tf`](src/mysql.tf);
- [`src/registry.tf`](src/registry.tf).

## Задание 2. Установка Docker через cloud-init

VM создается ресурсом `yandex_compute_instance`. В `metadata.user-data` передается шаблон [`src/templates/cloud-init.yml`](src/templates/cloud-init.yml).

Cloud-init выполняет:

```text
1. создание пользователя ubuntu;
2. добавление SSH-ключа;
3. установку Docker CE;
4. установку docker compose plugin;
5. клонирование репозитория приложения;
6. создание runtime .env;
7. запуск docker compose.
```

Runtime `.env` создается на сервере и содержит настройки подключения к MySQL, SMTP и параметры приложения. В Git хранится только пример файла с переменными, реальные значения исключены из репозитория.

## Задание 3. Dockerfile и Container Registry

В приложении используется multi-stage [`Dockerfile`](https://github.com/demon-5656/legacy-100-years/blob/main/Dockerfile):

- `deps` устанавливает npm-зависимости;
- `frontend-build` собирает React/Vite frontend;
- `web` формирует nginx-образ со статикой;
- `api` формирует Node.js backend-образ.

Локальная сборка образов:

```bash
docker build --target web -t legacy-100-years-web:local .
docker build --target api -t legacy-100-years-api:local .
```

Container Registry создается ресурсом:

```hcl
resource "yandex_container_registry" "app" {
  name = local.registry_name
}
```

После создания registry адрес доступен через output:

```bash
terraform -chdir=src output -raw registry_url
```

Пример публикации образов:

```bash
export CR_REGISTRY="$(terraform -chdir=src output -raw registry_url)"

docker tag legacy-100-years-web:local "$CR_REGISTRY/legacy-100-years-web:latest"
docker tag legacy-100-years-api:local "$CR_REGISTRY/legacy-100-years-api:latest"

docker push "$CR_REGISTRY/legacy-100-years-web:latest"
docker push "$CR_REGISTRY/legacy-100-years-api:latest"
```

## Задание 4. Подключение приложения к БД

Managed MySQL описан в [`src/mysql.tf`](src/mysql.tf). Создаются:

- MySQL cluster;
- база данных `legacy_100_years`;
- пользователь приложения;
- права пользователя на базу.

Backend получает подключение через переменные окружения:

```text
MYSQL_HOST
MYSQL_PORT
MYSQL_DATABASE
MYSQL_USER
MYSQL_PASSWORD
MYSQL_SSL
```

При старте backend создает таблицы приложения:

- `users`;
- `email_verification_tokens`;
- `password_reset_tokens`;
- `game_saves`.

Terraform в этом решении управляет инфраструктурой и managed database, а схема приложения создается самим backend. Для такого небольшого проекта это упрощает запуск и не требует отдельного миграционного сервиса.

## Задание 5*. Lockbox

Для секретов добавлен Yandex Lockbox:

```hcl
resource "yandex_lockbox_secret" "app" {
  name = "${var.app_name}-secrets"
}
```

В Lockbox сохраняются:

- `mysql_password`;
- `jwt_secret`;
- `smtp_password`.

Файл: [`src/lockbox.tf`](src/lockbox.tf).

Значения секретов передаются в Terraform через локальный `personal.auto.tfvars`, который исключен из Git. В репозитории оставлен только пример [`src/personal.auto.tfvars.example`](src/personal.auto.tfvars.example).

## Remote state

Backend настроен на Object Storage:

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

Файл: [`src/providers.tf`](src/providers.tf).

Настоящий `backend.hcl` с ключами доступа исключен из Git. В репозитории есть только шаблон [`src/backend.hcl.example`](src/backend.hcl.example).

## Проверки

Выполнены базовые проверки Terraform:

```bash
terraform -chdir=src fmt -check -recursive
terraform -chdir=src init -backend=false
terraform -chdir=src validate
```

Результаты:

- [`evidence/01_terraform_fmt.txt`](evidence/01_terraform_fmt.txt);
- [`evidence/02_terraform_init_backend_false.txt`](evidence/02_terraform_init_backend_false.txt);
- [`evidence/03_terraform_validate.txt`](evidence/03_terraform_validate.txt).

Приложение:

- репозиторий: [`demon-5656/legacy-100-years`](https://github.com/demon-5656/legacy-100-years);
- commit приложения: [`evidence/00_app_repo_commit.txt`](evidence/00_app_repo_commit.txt).
