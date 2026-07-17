# Домашнее задание 4. Продвинутые методы работы с Terraform

Задание делал в ветке `terraform-04`. Terraform использовал версии `1.12.2`, чтобы совпадало с требованием из задания.

Сразу важный момент: в моем каталоге Yandex Cloud уже была default-сеть, плюс есть лимит на количество сетей. Поэтому отдельную `production-example` сеть для демонстрации 4* я сначала попробовал создать, но уперся в quota. После этого оставил один рабочий VPC `develop`, а сам модуль сделал так, чтобы он принимал `list(object)` и создавал несколько подсетей. Получилось и задание закрыть, и не плодить лишние платные/лимитные ресурсы.

## Задание 1

Взял идею из демонстрации и использовал remote-модуль:

```hcl
source = "git::https://github.com/udjin10/yandex_compute_instance.git?ref=main"
```

Через него создал две прерываемые ВМ:

- `marketing-web-0`, label `project = marketing`;
- `analytics-web-0`, label `project = analytics`.

SSH-ключ в `cloud-init.yml` не захардкожен. Он читается из переменной `ssh_public_key_path`, потом передается в `template_file` через `vars`:

```hcl
data "template_file" "cloudinit" {
  template = file("${path.module}/templates/cloud-init.yml")

  vars = {
    ssh_public_key = local.ssh_public_key
  }
}
```

Внутри `cloud-init.yml` ключ передается списком, как и требуется:

```yaml
ssh_authorized_keys:
  - ${ssh_public_key}
```

Туда же добавил установку `nginx` и `vim`, плюс автозапуск nginx:

```yaml
packages:
  - nginx
  - vim

runcmd:
  - systemctl enable --now nginx
```

Проверка ВМ в Yandex Cloud:

- список ВМ: [`evidence/25_yc_compute_instances_final.txt`](evidence/25_yc_compute_instances_final.txt);
- labels marketing: [`evidence/26_yc_marketing_labels.txt`](evidence/26_yc_marketing_labels.txt);
- labels analytics: [`evidence/27_yc_analytics_labels.txt`](evidence/27_yc_analytics_labels.txt).

Проверка nginx по SSH:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

Файл с выводом: [`evidence/32_ssh_nginx_check_final.txt`](evidence/32_ssh_nginx_check_final.txt).

Terraform console по модулям:

- [`evidence/30_terraform_console_modules_separate.txt`](evidence/30_terraform_console_modules_separate.txt).

## Задание 2

Сделал локальный модуль VPC:

```text
src/modules/vpc
```

Модуль создает:

- одну сеть;
- подсети по переданному списку.

По базовому заданию нужна одна подсеть, но я сразу сделал вариант под задание 4*, чтобы не переписывать два раза. Вызов выглядит так:

```hcl
module "vpc_dev" {
  source   = "./modules/vpc"
  env_name = "develop"
  subnets  = var.dev_subnets
}
```

Переменная:

```hcl
variable "dev_subnets" {
  type = list(object({
    zone = string
    cidr = string
  }))
}
```

Модуль возвращает:

- `network_id`;
- `network_name`;
- `subnets`;
- `subnet_ids`;
- `subnet_info`.

Документация сгенерирована через `terraform-docs`:

- [`src/modules/vpc/README.md`](src/modules/vpc/README.md).

Вывод VPC в terraform console тоже есть тут:

- [`evidence/30_terraform_console_modules_separate.txt`](evidence/30_terraform_console_modules_separate.txt).

## Задание 3

Сначала вывел список ресурсов в state:

```bash
terraform state list
```

Потом удалил из state VPC и обе VM:

```bash
terraform state rm 'module.vpc_dev.yandex_vpc_subnet.this["ru-central1-a"]' \
  'module.vpc_dev.yandex_vpc_subnet.this["ru-central1-b"]' \
  'module.vpc_dev.yandex_vpc_network.this'

terraform state rm 'module.marketing_vm.yandex_compute_instance.vm[0]' \
  'module.analytics_vm.yandex_compute_instance.vm[0]'
```

После этого импортировал все обратно:

```bash
terraform import 'module.vpc_dev.yandex_vpc_network.this' enpr1bbu7d3c1ceiihds
terraform import 'module.vpc_dev.yandex_vpc_subnet.this["ru-central1-a"]' e9bh3fe9bei5kg8i22tv
terraform import 'module.vpc_dev.yandex_vpc_subnet.this["ru-central1-b"]' e2ljkcrbula4se8vlofl
terraform import 'module.marketing_vm.yandex_compute_instance.vm[0]' fhmon7h9bvavfinfm4qi
terraform import 'module.analytics_vm.yandex_compute_instance.vm[0]' epd1a93m7f01s52kms8f
```

Во время импорта подсетей поймал обычную неприятность: когда подсети удалены из state, output модуля временно неполный, а VM уже ссылаются на оба subnet id. Поправил output через `try(...)`, чтобы модуль нормально переживал пошаговый import.

После импорта сделал `terraform plan`. Сначала Terraform хотел синхронизировать только поле `allow_stopping_for_update` у импортированных ВМ. Применил это, потом повторил plan:

```text
No changes. Your infrastructure matches the configuration.
terraform plan detailed exit code: 0
```

Файлы:

- state remove/import: [`evidence/33_terraform_state_rm_import.txt`](evidence/33_terraform_state_rm_import.txt);
- повторный импорт подсетей: [`evidence/35_terraform_subnet_import_retry.txt`](evidence/35_terraform_subnet_import_retry.txt);
- финальный чистый plan: [`evidence/38_terraform_plan_after_import_clean.txt`](evidence/38_terraform_plan_after_import_clean.txt).

## Задание 4*

Модуль VPC изменен так, чтобы создавать подсети по списку объектов:

```hcl
resource "yandex_vpc_subnet" "this" {
  for_each = {
    for subnet in var.subnets : subnet.zone => subnet
  }

  name           = "${var.env_name}-${each.value.zone}"
  zone           = each.value.zone
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = [each.value.cidr]
}
```

В `develop` я передал две подсети:

```hcl
default = [
  {
    zone = "ru-central1-a"
    cidr = "10.10.1.0/24"
  },
  {
    zone = "ru-central1-b"
    cidr = "10.10.2.0/24"
  }
]
```

Результат в YC:

- сети: [`evidence/28_yc_networks_final.txt`](evidence/28_yc_networks_final.txt);
- подсети: [`evidence/29_yc_subnets_final.txt`](evidence/29_yc_subnets_final.txt).

План создания: [`evidence/17_terraform_plan_final_create.txt`](evidence/17_terraform_plan_final_create.txt).

## Что не делал из звездочек

Managed MySQL из задания 5* не создавал специально. Он может быстро начать стоить денег, а для этой работы обязательная часть уже закрыта.

S3/Vault/remote state в этом разделе тоже не поднимал, чтобы не смешивать все в одну кучу. Тут основной смысл был в модулях, cloud-init и state.

## Удаление ресурсов

По правилу задания созданные ресурсы удалены через:

```bash
terraform destroy -auto-approve
```

Файл с выводом удаления: [`evidence/39_terraform_destroy_final.txt`](evidence/39_terraform_destroy_final.txt).

Проверка после удаления:

- ВМ: [`evidence/40_yc_instances_after_destroy.txt`](evidence/40_yc_instances_after_destroy.txt);
- сети: [`evidence/41_yc_networks_after_destroy.txt`](evidence/41_yc_networks_after_destroy.txt);
- подсети: [`evidence/42_yc_subnets_after_destroy.txt`](evidence/42_yc_subnets_after_destroy.txt).
