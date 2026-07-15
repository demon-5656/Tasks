# Домашнее задание к занятию «Введение в Terraform»

Исходное задание: https://github.com/netology-code/ter-homeworks/blob/main/01/hw-01.md

## Задание 1

Исходники взял из каталога `01/src` и положил в `src`.

Terraform поставил локально в папку задания. Системный Terraform не трогал, так проще не сломать рабочее окружение.

Проверка версии:

```bash
Terraform v1.12.2
on linux_amd64
```

Docker тоже есть:

```bash
Docker version 29.6.1, build 8900f1d330
```

После `terraform init` подтянулись провайдеры:

```text
kreuzwerker/docker v4.5.0
hashicorp/random v3.9.0
```

### Где хранить секреты

В `src/.gitignore` есть строка:

```gitignore
personal.auto.tfvars
```

Значит личные значения можно складывать туда: токены, логины, пароли, ключи. Terraform этот файл сам подхватит, а в git он не уйдет.

Еще там закрыты state-файлы:

```gitignore
*.tfstate
*.tfstate.*
```

И это не просто так. В state секреты могут лежать обычным текстом.

### Секрет из state

После первого `terraform apply` появился ресурс:

```text
random_password.random_string
```

В state значение лежит в поле:

```text
result = jJ5Pv4S0Le6LWxKK
```

Команда `terraform state show` это поле маскирует как sensitive, но в самом `terraform.tfstate` оно есть. Вывод простой: state в публичный репозиторий лучше не тащить.

### Ошибки в закомментированном блоке

После раскомментирования блока `terraform validate` показал ошибки:

```text
Error: Missing name for resource
All resource blocks must have 2 labels (type, name).

Error: Invalid resource name
A name must start with a letter or underscore and may contain only letters,
digits, underscores, and dashes.
```

Что было сломано:

- у `resource "docker_image"` не было имени ресурса;
- `resource "docker_container" "1nginx"` начинался с цифры, Terraform так не разрешает;
- ссылка `random_password.random_string_FAKE.resulT` тоже неправильная: такого ресурса нет, плюс регистр поля неверный.

Исправил так:

```hcl
resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = true
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "example_${random_password.random_string.result}"

  ports {
    internal = 80
    external = 9090
  }
}
```

После этого `terraform validate` уже нормальный:

```text
Success! The configuration is valid.
```

Контейнер поднялся:

```text
CONTAINER ID   IMAGE          NAMES                      PORTS                  STATUS
aa087aaed6a4   8870c81b2834   example_jJ5Pv4S0Le6LWxKK   0.0.0.0:9090->80/tcp   Up Less than a second
```

### Контейнер hello_world

Потом поменял имя контейнера на `hello_world`. Образ оставил `nginx:latest`, как и просили.

Фрагмент:

```hcl
resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = true
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "hello_world"

  ports {
    internal = 80
    external = 9090
  }
}
```

После `terraform apply -auto-approve`:

```text
CONTAINER ID   IMAGE          NAMES         PORTS                  STATUS
56d060987c84   8870c81b2834   hello_world   0.0.0.0:9090->80/tcp   Up Less than a second
```

Проверка HTTP:

```text
HTTP/1.1 200 OK
Server: nginx/1.31.2
```

Про `-auto-approve`: штука удобная, но опасная. Terraform не спрашивает подтверждение и сразу применяет план. В тестовой лабе нормально, в проде можно случайно удалить что-то важное. Использовать имеет смысл в автоматизации, когда план уже проверен или стенд одноразовый.

### Удаление ресурсов

Удалил ресурсы:

```bash
terraform destroy -auto-approve
```

Результат:

```text
Destroy complete! Resources: 3 destroyed.
```

Контейнера уже нет:

```text
CONTAINER ID   IMAGE     NAMES     STATUS
```

Итоговый `terraform.tfstate`:

```json
{
  "version": 4,
  "terraform_version": "1.12.2",
  "serial": 11,
  "lineage": "f3a59dc3-8800-1dd5-b75d-da25b1632c4e",
  "outputs": {},
  "resources": [],
  "check_results": null
}
```

### Почему nginx-образ остался

Контейнер удалился, а образ остался:

```text
REPOSITORY   TAG       IMAGE ID       SIZE
nginx        latest    8870c81b2834   161MB
```

Причина прямо в коде:

```hcl
resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = true
}
```

`keep_locally = true` говорит провайдеру не удалять локальный образ при `destroy`.

В документации docker provider для `docker_image` это описано так: при `keep_locally = true` Docker image не удаляется во время destroy.  
Источник: https://library.tf/providers/kreuzwerker/docker/latest/docs/resources/image

## Дополнительное задание 2*

Сделал отдельный код под чистую ВМ: `star-remote-mysql/`.

Там Terraform подключается к удаленному Docker через SSH:

```hcl
provider "docker" {
  host = var.docker_host
}
```

Адрес ВМ выносится в `personal.auto.tfvars`, пример лежит рядом:

```hcl
docker_host = "ssh://ubuntu@VM_PUBLIC_IP:22"
```

Пароли генерируются через `random_password`:

```hcl
resource "random_password" "mysql_root" {
  length  = 20
  special = false
}

resource "random_password" "mysql_user" {
  length  = 20
  special = false
}
```

Контейнер MySQL:

```hcl
resource "docker_container" "mysql" {
  image = docker_image.mysql.image_id
  name  = "tf-mysql-wordpress"

  env = [
    "MYSQL_ROOT_PASSWORD=${random_password.mysql_root.result}",
    "MYSQL_DATABASE=wordpress",
    "MYSQL_USER=wordpress",
    "MYSQL_PASSWORD=${random_password.mysql_user.result}",
    "MYSQL_ROOT_HOST=%",
  ]

  ports {
    ip       = "127.0.0.1"
    internal = 3306
    external = 3306
  }
}
```

Код проверил:

```text
Success! The configuration is valid.
```

Сначала проверил, что на текущем ПК `3306` уже занят:

```text
LISTEN 0 80 0.0.0.0:3306 0.0.0.0:*
```

Поэтому взял отдельную VM в Proxmox, чтобы не мешать локальной базе.

Что получилось:

```text
Proxmox: 192.168.1.61:8006
VMID:    103
Name:    netology-terraform-docker
IP:      192.168.3.201
User:    ubuntu
Docker:  29.1.3
```

На VM поставил Docker и указал Terraform:

```hcl
docker_host = "ssh://ubuntu@192.168.3.201:22"
```

Первый запуск MySQL упал с ошибкой:

```text
Fatal glibc error: CPU does not support x86-64-v2
```

Причина была не в Terraform, а в настройке виртуального CPU. VM была создана с дефолтным CPU, а свежий `mysql:8` хочет `x86-64-v2`. На Proxmox поменял CPU VM на `host`, перезапустил VM и повторил `terraform apply`.

После этого контейнер поднялся:

```text
CONTAINER ID   IMAGE          NAMES                PORTS                                 STATUS
dbac72fd643f   c831a0f11348   tf-mysql-wordpress   127.0.0.1:3306->3306/tcp, 33060/tcp   Up 10 seconds
```

Порт слушает только внутри VM на localhost:

```text
LISTEN 0 4096 127.0.0.1:3306 0.0.0.0:*
```

Проверка env внутри контейнера на ВМ:

```text
MYSQL_DATABASE=<hidden>
MYSQL_MAJOR=<hidden>
MYSQL_PASSWORD=<hidden>
MYSQL_ROOT_HOST=<hidden>
MYSQL_ROOT_PASSWORD=<hidden>
MYSQL_SHELL_VERSION=<hidden>
MYSQL_USER=<hidden>
MYSQL_VERSION=<hidden>
```

Значения паролей в отчете замаскировал. Сам факт передачи env-переменных виден, а светить секреты в README смысла нет.

## Дополнительное задание 3*

Поставил OpenTofu локально:

```bash
OpenTofu v1.12.4
on linux_amd64
```

Запустил тот же код через `tofu`, а не через `terraform`.

Команды:

```bash
tofu init
tofu apply -auto-approve
docker ps --filter name=hello_world
tofu destroy -auto-approve
```

Контейнер поднялся:

```text
CONTAINER ID   IMAGE          NAMES         PORTS                  STATUS
13c402d804b6   8870c81b2834   hello_world   0.0.0.0:9090->80/tcp   Up Less than a second
```

После `tofu destroy` контейнер удален:

```text
CONTAINER ID   IMAGE     NAMES     PORTS     STATUS
```

По ощущениям для этого примера OpenTofu отработал как замена Terraform. Единственное, он обновил lock-файл под свой registry, так что смешивать Terraform и OpenTofu в одном проекте надо аккуратно.

## Файлы

- основной код: `src/main.tf`;
- код для remote MySQL: `star-remote-mysql/`;
- выводы команд: `evidence/`;
- OpenTofu и Terraform лежат в `bin/`, эта папка в git не идет.
