# Домашнее задание 5. Использование Terraform в команде

Делал на базе прошлого ДЗ. Код и выводы команд лежат в папке `netology/terraform-05`. Сначала прогнал проверки, потом исправил найденное и повторил проверки уже после правок.

Terraform использовал `1.12.2`.

## Задание 0

Статью прочитал. Смысл нормальный: не хранить один общий пароль/ключ на всех, не передавать секреты в чатах, не коммитить `.tfvars`, state и ключи. В этом ДЗ `backend.hcl`, `personal.auto.tfvars`, `.terraform`, state и plan локально исключены через `.git/info/exclude`.

## Задание 1. tflint и checkov

Сначала прогнал проверки по коду, который был взят из ДЗ 4.

Команды:

```bash
./tools/tflint --chdir=src --recursive --format=compact
checkov -d src --framework terraform --quiet --compact
```

Что нашлось по типам, без дублей:

- не зафиксирована версия remote module, использовался `ref=main`;
- не указаны version constraints для providers;
- часть переменных была объявлена, но не использовалась;
- у ВМ был public IP;
- у network interface не была назначена security group.

Файлы:

- первичный tflint: [`evidence/06_tflint_src_initial.txt`](evidence/06_tflint_src_initial.txt);
- первичный checkov: [`evidence/07_checkov_src_initial.txt`](evidence/07_checkov_src_initial.txt).

После исправлений:

- remote module закрепил на commit hash;
- добавил версии providers;
- лишнюю переменную убрал;
- validation-переменные вывел через local/output, чтобы они были частью конфигурации;
- добавил security group;
- отключил public IP у учебных ВМ, так как в этом ДЗ проверяется remote state, а не SSH снаружи.

Итог:

```text
tflint exit code: 0
Passed checks: 11, Failed checks: 0, Skipped checks: 0
checkov exit code: 0
```

Файлы:

- [`evidence/13_tflint_after_security_fix.txt`](evidence/13_tflint_after_security_fix.txt);
- [`evidence/14_checkov_after_security_fix.txt`](evidence/14_checkov_after_security_fix.txt).

## Задание 2. Remote state и lock

Для remote state создал:

- service account `netology-tfstate`;
- роль `storage.editor`;
- static access key;
- S3 bucket `netology-tfstate-20260717-b1glhd6ohrcmkvkg7v7q`.

Секретный ключ не коммитил. Он лежал только локально в `src/backend.hcl`, файл добавлен в локальный exclude.

Backend в `providers.tf`:

```hcl
backend "s3" {
  key    = "terraform-05/terraform.tfstate"
  region = "ru-central1"

  endpoints = {
    s3 = "https://storage.yandexcloud.net"
  }

  use_lockfile                = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_s3_checksum            = true
}
```

Bucket и access key передавались через локальный `backend.hcl`:

```bash
terraform init -backend-config=backend.hcl -migrate-state
```

Вывод:

- создание backend-ресурсов: [`evidence/01_yc_backend_resources_create.txt`](evidence/01_yc_backend_resources_create.txt);
- init/migrate-state: [`evidence/02_terraform_init_migrate_state.txt`](evidence/02_terraform_init_migrate_state.txt).

Проверка lock:

1. В одном окне открыл `terraform console`.
2. Во втором окне запустил `terraform apply -auto-approve`.
3. Terraform не получил lock и упал с ошибкой:

```text
Error acquiring the state lock
Lock Info:
  ID: 704d1642-d731-db7e-c24e-05c5cd3ea963
```

Файл: [`evidence/17_apply_blocked_by_console_lock.txt`](evidence/17_apply_blocked_by_console_lock.txt).

Потом разблокировал:

```bash
terraform force-unlock -force 704d1642-d731-db7e-c24e-05c5cd3ea963
```

Файл: [`evidence/18_terraform_force_unlock.txt`](evidence/18_terraform_force_unlock.txt).

После этого обычный `plan/apply/destroy` отработал через remote state:

- plan: [`evidence/19_terraform_plan_remote_state.txt`](evidence/19_terraform_plan_remote_state.txt);
- apply: [`evidence/20_terraform_apply_remote_state.txt`](evidence/20_terraform_apply_remote_state.txt);
- destroy: [`evidence/21_terraform_destroy_remote_state.txt`](evidence/21_terraform_destroy_remote_state.txt).

После destroy проверил, что от задания не осталось ВМ и отдельной сети:

- [`evidence/22_yc_instances_after_destroy.txt`](evidence/22_yc_instances_after_destroy.txt);
- [`evidence/23_yc_networks_after_destroy.txt`](evidence/23_yc_networks_after_destroy.txt).

Remote state bucket и service account тоже удалил после проверки:

- [`evidence/24_backend_resources_cleanup.txt`](evidence/24_backend_resources_cleanup.txt).

## Задание 3. Проверки после исправлений

После первичных проверок поправил код и повторно запустил `tflint`, `checkov` и `terraform plan`. Для комментария к ревью можно было бы отправить такой короткий итог:

```text
Исправил замечания tflint/checkov.

tflint:
  exit code: 0

checkov:
  Passed checks: 11
  Failed checks: 0

Изменения:
  - remote module закреплен на commit hash;
  - добавлены version constraints для providers;
  - добавлена security group;
  - у ВМ отключен public IP;
  - добавлены validation-переменные.

terraform plan:
  Plan: 6 to add, 0 to change, 0 to destroy.
```

Файлы проверок и plan приложены в `evidence`:

- [`evidence/13_tflint_after_security_fix.txt`](evidence/13_tflint_after_security_fix.txt);
- [`evidence/14_checkov_after_security_fix.txt`](evidence/14_checkov_after_security_fix.txt);
- [`evidence/19_terraform_plan_remote_state.txt`](evidence/19_terraform_plan_remote_state.txt).

## Задание 4. Validation

Добавил переменные:

- `single_ip`;
- `ip_list`;
- `lowercase_text`;
- `in_the_end_there_can_be_only_one`.

Проверка одного IP:

```hcl
validation {
  condition     = can(cidrhost("${var.single_ip}/32", 0))
  error_message = "single_ip must be a valid IPv4 address."
}
```

Проверка списка IP:

```hcl
validation {
  condition = alltrue([
    for ip in var.ip_list : can(cidrhost("${ip}/32", 0))
  ])
  error_message = "Every item in ip_list must be a valid IPv4 address."
}
```

Валидные значения проверил через `terraform console`:

- [`evidence/15_validation_console_valid.txt`](evidence/15_validation_console_valid.txt).

Невалидные значения:

- `1920.1680.0.1`;
- `["192.168.0.1", "1.1.1.1", "1270.0.0.1"]`;
- строка с верхним регистром;
- объект, где оба значения `true`.

Файл:

- [`evidence/16_validation_console_invalid.txt`](evidence/16_validation_console_invalid.txt).

## Дополнительные задания

### Задание 5*

Недорогое, поэтому сделал вместе с заданием 4:

- `lowercase_text` проверяет, что строка без верхнего регистра;
- `in_the_end_there_can_be_only_one` проверяет, что одно значение `true`, второе `false`.

### Задание 6*

CI/CD реально не настраивал. Как бы делал:

1. GitHub Actions workflow.
2. На pull request запускал бы `terraform fmt -check`, `terraform validate`, `tflint`, `checkov`, `terraform plan`.
3. На ручной запуск через `workflow_dispatch` можно было бы делать `apply` или `destroy`.

Секреты для YC и S3 backend положил бы в GitHub Actions Secrets, а не в репозиторий.

### Задание 7*

Отдельный root module для backend не делал, чтобы не усложнять ДЗ и не держать лишние ресурсы. Как бы делал:

- `backend-bootstrap/`;
- `yandex_iam_service_account`;
- `yandex_resourcemanager_folder_iam_member` с `storage.editor`;
- `yandex_iam_service_account_static_access_key`;
- `yandex_storage_bucket` с versioning;
- outputs: bucket name, access key id, secret key как `sensitive`, пример `backend "s3"`.

YDB/DynamoDB не нужен, потому что используется `use_lockfile = true`.
