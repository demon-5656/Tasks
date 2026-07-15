# Домашнее задание к занятию «Основы Terraform. Yandex Cloud»

Исходное задание: https://github.com/netology-code/ter-homeworks/blob/main/02/hw-02.md

## Задание 0

Документацию по security groups посмотрел.

Коротко: security group - это набор правил входящего и исходящего трафика для ресурсов в VPC. Если правил нет, трафик режется. В default security group обычно разрешены исходящие соединения, SSH/RDP и ICMP, но в нормальной работе лучше явно описывать свои правила.

Источник: https://yandex.cloud/ru/docs/vpc/concepts/security-groups

## Задание 1

Terraform использовал тот же локальный бинарник:

```text
Terraform v1.12.2
```

Для доступа к Yandex Cloud создал сервисный аккаунт:

```text
netology-terraform
```

Ключ сервисного аккаунта лежит локально и в git не добавляется:

```text
/home/pc243/.config/yandex-cloud/netology-terraform/authorized_key.json
```

Переменные для cloud/folder/key/ssh вынесены в `personal.auto.tfvars`, он тоже игнорируется git.

При первом запуске были ошибки:

```text
Platform "standard-v4" not found
```

В исходнике было `standart-v4`, это опечатка. Но `standard-v4` в этом облаке тоже не подошел, поэтому:

- для web VM поставил `standard-v1`, потому что нужен `core_fraction = 5`;
- для db VM оставил `standard-v3`, там `core_fraction = 20`.

Еще одна ошибка:

```text
the specified core fraction is not available on platform "standard-v3";
allowed core fractions: 20, 50, 100
```

То есть `core_fraction = 5` нельзя использовать на `standard-v3`.

После исправлений были созданы две ВМ:

```text
netology-develop-platform-web   ru-central1-a   111.88.249.199
netology-develop-platform-db    ru-central1-b   89.169.190.4
```

SSH-проверка:

```text
web:
fhmvf6sghqt24ep4fr30
111.88.249.199

db:
epd4dpm3fp2825u3d4e7
89.169.190.4
```

`curl ifconfig.me` внутри VM показал те же внешние IP, значит NAT и SSH работают.

`preemptible = true` и `core_fraction` в учебе полезны тем, что уменьшают стоимость. Прерываемая VM дешевле, но ее может остановить облако. `core_fraction` дает не полный CPU, а долю производительности. Для учебных стендов это нормально, потому что нагрузка маленькая.

## Задание 2

Хардкод из `yandex_compute_image` и `yandex_compute_instance` вынес в переменные.

Для web VM используются переменные с префиксом `vm_web_`, например:

```hcl
variable "vm_web_name" {
  type    = string
  default = "platform-web"
}

variable "vm_web_image_family" {
  type    = string
  default = "ubuntu-2004-lts"
}
```

После выноса переменных `terraform plan` проверял. В финальном состоянии:

```text
No changes. Your infrastructure matches the configuration.
```

## Задание 3

Создал файл:

```text
src/vms_platform.tf
```

Туда вынес переменные обеих VM.

Добавил вторую VM:

```text
netology-develop-platform-db
```

Параметры:

```text
zone          = ru-central1-b
cores         = 2
memory        = 2
core_fraction = 20
```

## Задание 4

В `outputs.tf` сделал один output `vm_info`.

Вывод:

```text
vm_info = {
  "db" = {
    "external_ip" = "89.169.190.4"
    "fqdn" = "epd4dpm3fp2825u3d4e7.auto.internal"
    "instance_name" = "netology-develop-platform-db"
  }
  "web" = {
    "external_ip" = "111.88.249.199"
    "fqdn" = "fhmvf6sghqt24ep4fr30.auto.internal"
    "instance_name" = "netology-develop-platform-web"
  }
}
```

## Задание 5

В `locals.tf` собрал имена VM через интерполяцию:

```hcl
locals {
  vm_web_name = "${var.project_name}-${var.env_name}-${var.vm_web_name}"
  vm_db_name  = "${var.project_name}-${var.env_name}-${var.vm_db_name}"
}
```

В ресурсах VM теперь используются:

```hcl
name = local.vm_web_name
name = local.vm_db_name
```

## Задание 6

Параметры CPU/RAM/disk объединил в `map(object)`:

```hcl
variable "vms_resources" {
  type = map(object({
    cores         = number
    memory        = number
    core_fraction = number
    hdd_size      = number
    hdd_type      = string
  }))
}
```

Использование:

```hcl
cores         = var.vms_resources.web.cores
memory        = var.vms_resources.web.memory
core_fraction = var.vms_resources.web.core_fraction
```

Metadata тоже вынесена отдельно:

```hcl
variable "metadata" {
  type = map(string)
}
```

SSH-ключ добавляется через `merge`, чтобы не хардкодить его в коде:

```hcl
vm_metadata = merge(
  var.metadata,
  {
    ssh-keys = "ubuntu:${var.vms_ssh_public_root_key}"
  }
)
```

Финальная проверка:

```text
No changes. Your infrastructure matches the configuration.
```

## Задание 7*

Команды из `terraform console`:

```text
> local.test_list[1]
"staging"

> length(local.test_list)
3

> local.test_map.admin
"John"

> format("%s is %s for %s server based on OS %s with %s vcpu, %s ram and %s virtual disks", local.test_map.admin, keys(local.test_map)[0], local.test_list[2], local.servers.production.image, local.servers.production.cpu, local.servers.production.ram, length(local.servers.production.disks))
"John is admin for production server based on OS ubuntu-20-04 with 10 vcpu, 40 ram and 4 virtual disks"
```

## Задание 8*

Тип переменной:

```hcl
variable "test" {
  type = list(map(list(string)))
}
```

Команда:

```text
> var.test[0]["dev1"][0]
"ssh -o 'StrictHostKeyChecking=no' ubuntu@62.84.124.117"
```

## Удаление ресурсов

После проверок выполнил:

```bash
terraform destroy -auto-approve
```

Результат:

```text
Destroy complete! Resources: 5 destroyed.
```

После удаления в списке VM осталась только старая остановленная машина, которая не относится к этому ДЗ:

```text
compute-vm-2-2-10-hdd-1781591729252   STOPPED
```

Созданная сеть `develop` тоже удалена, осталась только штатная `default`.

## Файлы

- Terraform-код: `src/`;
- выводы команд: `evidence/`;
- локальные секреты: `src/personal.auto.tfvars`, в git не попадает.
