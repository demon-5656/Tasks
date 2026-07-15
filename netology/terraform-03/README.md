# Домашнее задание к занятию «Управляющие конструкции в коде Terraform»

Исходное задание: https://github.com/netology-code/ter-homeworks/blob/main/03/hw-03.md

Делал в отдельной ветке:

```text
terraform-03
```

## Что получилось

Поднял в Yandex Cloud:

- security group с правилами SSH/HTTP/HTTPS и исходящим трафиком;
- 2 web VM через `count`: `web-1`, `web-2`;
- 2 database VM через `for_each`: `main`, `replica`;
- 1 storage VM;
- 3 дополнительных диска по 1 GB и подключил их к `storage` через `dynamic secondary_disk`;
- ansible inventory через `templatefile`.

Все VM были `preemptible = true`, чтобы не жечь деньги просто так.

После проверки ресурсы удалил:

```text
Destroy complete! Resources: 13 destroyed.
```

## Задание 1

Проект изучил, инициализация прошла:

```text
Terraform has been successfully initialized!
```

Security group создалась такая:

```text
name: netology-terraform-03
rules:
  ssh   TCP 22   0.0.0.0/0
  http  TCP 80   0.0.0.0/0
  https TCP 443  0.0.0.0/0
  egress ANY     0.0.0.0/0
```

В коде это сделано динамическими блоками `ingress` и `egress`, чтобы не копировать одинаковые куски руками.

## Задание 2

Файл:

```text
src/count-vm.tf
```

Web VM созданы через `count`:

```hcl
resource "yandex_compute_instance" "web_nodes" {
  count = var.web_count

  name     = "web-${count.index + 1}"
  hostname = "web-${count.index + 1}"

  depends_on = [
    yandex_compute_instance.database_nodes
  ]
}
```

Из-за `count.index + 1` имена получились нормальные:

```text
web-1
web-2
```

Не `web-0` и `web-1`.

Security group назначена в `network_interface`:

```hcl
security_group_ids = [yandex_vpc_security_group.homework.id]
```

Файл:

```text
src/for_each-vm.tf
```

DB VM созданы через `for_each` из общей переменной `each_vm`:

```hcl
resource "yandex_compute_instance" "database_nodes" {
  for_each = local.db_nodes

  name = each.key
}
```

Переменная:

```hcl
variable "each_vm" {
  type = list(object({
    vm_name     = string
    cpu         = number
    ram         = number
    disk_volume = number
    platform_id = string
    fraction    = number
  }))
}
```

Получились:

```text
main
replica
```

Web VM создавались после DB VM, это видно по `depends_on` и по выводу apply: сначала поднялись `main` и `replica`, потом пошли `web-1` и `web-2`.

SSH-ключ читается через `file`:

```hcl
ssh_key = file(pathexpand(var.ssh_public_key_path))
```

## Задание 3

Файл:

```text
src/disk_vm.tf
```

Создал 3 диска по 1 GB:

```hcl
resource "yandex_compute_disk" "storage_extra" {
  count = var.storage_resources.extra_disks

  name = "storage-extra-${count.index + 1}"
  size = 1
}
```

Потом создал одну VM `storage` и подключил диски через `dynamic secondary_disk`:

```hcl
dynamic "secondary_disk" {
  for_each = yandex_compute_disk.storage_extra

  content {
    disk_id     = secondary_disk.value.id
    device_name = secondary_disk.value.name
    auto_delete = true
  }
}
```

В YC диски были видны как подключенные к `storage`:

```text
storage-extra-1   1GB   fhmvp6n5sb6nvtd2728t
storage-extra-2   1GB   fhmvp6n5sb6nvtd2728t
storage-extra-3   1GB   fhmvp6n5sb6nvtd2728t
```

## Задание 4

Inventory генерируется через `templatefile`.

Файл Terraform:

```text
src/ansible.tf
```

Шаблон:

```text
src/templates/hosts.tftpl
```

Получившийся inventory:

```ini
[webservers]
web-1 ansible_host=111.88.253.236 fqdn=web-1.ru-central1.internal
web-2 ansible_host=51.250.6.208 fqdn=web-2.ru-central1.internal

[databases]
main ansible_host=111.88.153.23 fqdn=main.ru-central1.internal
replica ansible_host=111.88.151.205 fqdn=replica.ru-central1.internal

[storage]
storage ansible_host=51.250.76.7 fqdn=storage.ru-central1.internal
```

Проверил inventory через Ansible `raw hostname`, потому что `ping` в Ansible 2.21 требует Python 3.9+, а в Ubuntu 20.04 стоит Python 3.8:

```text
web-1   -> web-1
web-2   -> web-2
main    -> main
replica -> replica
storage -> storage
```

## Задание 5*

Сделал output, который собирает VM из `count` и `for_each` без хардкода:

```hcl
output "count_and_for_each_vms" {
  value = concat(
    [
      for vm in yandex_compute_instance.web_nodes : {
        name = vm.name
        id   = vm.id
        fqdn = vm.fqdn
      }
    ],
    [
      for vm in values(yandex_compute_instance.database_nodes) : {
        name = vm.name
        id   = vm.id
        fqdn = vm.fqdn
      }
    ]
  )
}
```

Вывод:

```text
[
  { name = "web-1",   id = "fhm8jh2736e18te2vkrh", fqdn = "web-1.ru-central1.internal" },
  { name = "web-2",   id = "fhme0er16qoib2iv3ibn", fqdn = "web-2.ru-central1.internal" },
  { name = "main",    id = "epdlb9parn91highso0t", fqdn = "main.ru-central1.internal" },
  { name = "replica", id = "epd2tcni2f9rdndr4vt7", fqdn = "replica.ru-central1.internal" },
]
```

## Задание 6*

Это задание с `null_resource` и `ansible-playbook` под схему без внешних адресов. Я его не стал добивать в этом проходе: для этого уже нужен bastion/jump host или другой доступ во внутреннюю сеть.

Inventory при этом рабочий, подключение проверил через Ansible `raw`.

## Задание 7*

Выражение, которое удаляет третий элемент из `subnet_ids` и `subnet_zones`:

```hcl
merge(local.vpc_example, {
  subnet_ids   = concat(slice(local.vpc_example.subnet_ids, 0, 2), slice(local.vpc_example.subnet_ids, 3, length(local.vpc_example.subnet_ids)))
  subnet_zones = concat(slice(local.vpc_example.subnet_zones, 0, 2), slice(local.vpc_example.subnet_zones, 3, length(local.vpc_example.subnet_zones)))
})
```

Результат:

```text
subnet_ids = [
  "e9b0le401619ngf4h68n",
  "e2lbar6u8b2ftd7f5hia",
  "fl8ner8rjsio6rcpcf0h",
]

subnet_zones = [
  "ru-central1-a",
  "ru-central1-b",
  "ru-central1-d",
]
```

## Задание 8*

В сломанном шаблоне была ошибка в строке:

```text
${i["name"]} ansible_host=${i["network_interface"][0]["nat_ip_address"] platform_id=${i["platform_id "]}}
```

Проблемы:

- не закрыта интерполяция после `nat_ip_address`;
- в ключе `platform_id ` лишний пробел;
- в таком виде Terraform показывает ошибку по месту, где ломается шаблон.

Исправленный смысл:

```text
${i["name"]} ansible_host=${i["network_interface"][0]["nat_ip_address"]} platform_id=${i["platform_id"]}
```

В моем шаблоне я не тащил весь объект VM, а передал подготовленные map-ы:

```text
${node.name} ansible_host=${node.external_ip} fqdn=${node.fqdn}
```

Так проще читать и меньше шансов ошибиться в длинных индексах.

## Задание 9*

Список от `rc01` до `rc99`:

```hcl
[for i in range(1, 100) : format("rc%02d", i)]
```

Список от `rc01` до `rc96`, пропуская окончания `0`, `7`, `8`, `9`, но оставляя `rc19`:

```hcl
[for i in range(1, 97) : format("rc%02d", i) if !contains(["0", "7", "8", "9"], substr(format("%02d", i), 1, 1)) || i == 19]
```

## Удаление ресурсов

После проверки выполнил:

```bash
terraform destroy -auto-approve
```

Результат:

```text
Destroy complete! Resources: 13 destroyed.
```

После удаления осталась только старая остановленная VM, которая не относится к этому заданию:

```text
compute-vm-2-2-10-hdd-1781591729252   STOPPED
```

Созданные диски, сеть и security group удалились.

## Файлы

- код Terraform: `src/`;
- шаблон inventory: `src/templates/hosts.tftpl`;
- выводы команд: `evidence/`;
- локальные файлы `personal.auto.tfvars`, `terraform.tfstate`, `.terraform`, `tfplan`, `hosts.cfg` в git не попадают.
