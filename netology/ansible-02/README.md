# Домашнее задание к занятию 2 «Работа с Playbook»

Использовал playbook из задания и дописал установку Vector вторым play. Для проверки взял docker-контейнеры, потому что поднимать отдельные VM ради этой домашки не хотелось. Немного повозился с архивом Vector: сначала указал путь к бинарнику слишком оптимистично, потом посмотрел структуру распаковки и поправил переменную.

Окружение:

```text
ansible [core 2.21.2]
ansible-lint 26.6.0
Docker 29.6.2
```

## Inventory

Inventory лежит в [`playbook/inventory/prod.yml`](playbook/inventory/prod.yml).

```yaml
clickhouse:
  hosts:
    clickhouse-01:
      ansible_connection: community.docker.docker

vector:
  hosts:
    vector-01:
      ansible_connection: community.docker.docker
```

Контейнеры поднял на `ubuntu:22.04`. Внутри поставил минимальный набор для Ansible: `python3`, `tar`, `gzip`, `ca-certificates`.

Проверка контейнеров: [`evidence/03_docker_containers.txt`](evidence/03_docker_containers.txt).

## Что делает playbook

Playbook [`playbook/site.yml`](playbook/site.yml) состоит из двух play.

Первый play ставит ClickHouse:

- создает каталоги `/opt/clickhouse`, `/etc/clickhouse-server`, `/var/lib/clickhouse`, `/var/log/clickhouse-server`;
- скачивает архив `clickhouse-common-static`;
- распаковывает его в `/opt/clickhouse`;
- создает ссылку `/usr/local/bin/clickhouse`;
- проверяет бинарник командой `clickhouse local --version`.

Второй play ставит Vector:

- создает каталоги `/opt/vector`, `/etc/vector`, `/var/lib/vector`;
- скачивает архив Vector;
- распаковывает его в `/opt/vector`;
- создает ссылку `/usr/local/bin/vector`;
- кладет конфиг из шаблона [`playbook/templates/vector.yaml.j2`](playbook/templates/vector.yaml.j2);
- проверяет конфиг командой `vector validate`.

Handlers для перезапуска `clickhouse-server` и `vector` добавлены. В docker-стенде они пропускаются, потому что контейнеры без systemd. На обычной VM можно включить переменные:

```yaml
clickhouse_manage_service: true
vector_manage_service: true
```

## Параметры

ClickHouse:

```yaml
clickhouse_version: "22.3.3.44"
clickhouse_arch: amd64
clickhouse_install_dir: /opt/clickhouse
clickhouse_config_dir: /etc/clickhouse-server
clickhouse_data_dir: /var/lib/clickhouse
clickhouse_log_dir: /var/log/clickhouse-server
clickhouse_manage_service: false
```

Файл: [`playbook/group_vars/clickhouse/vars.yml`](playbook/group_vars/clickhouse/vars.yml).

Vector:

```yaml
vector_version: "0.38.0"
vector_arch: x86_64-unknown-linux-gnu
vector_install_dir: /opt/vector
vector_config_dir: /etc/vector
vector_data_dir: /var/lib/vector
vector_source_interval: 10
vector_manage_service: false
```

Файл: [`playbook/group_vars/vector/vars.yml`](playbook/group_vars/vector/vars.yml).

## Теги

В playbook использованы два тега:

- `clickhouse` - задачи установки и проверки ClickHouse;
- `vector` - задачи установки, настройки и проверки Vector.

Примеры:

```bash
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml --tags clickhouse
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml --tags vector
```

## Проверка ansible-lint

```bash
uvx ansible-lint playbook/site.yml
```

Результат:

```text
Passed: 0 failure(s), 0 warning(s)
```

Файл: [`evidence/02_ansible_lint.txt`](evidence/02_ansible_lint.txt).

Синтаксис тоже проверил:

```bash
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml --syntax-check
```

Файл: [`evidence/01_syntax_check.txt`](evidence/01_syntax_check.txt).

## Запуск с --check

```bash
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml --check
```

`--check` прошел без ошибок. Часть задач с распаковкой и проверкой бинарников пропускается специально: в check-mode архив фактически не распаковывается, а значит следующих файлов еще нет.

Файл: [`evidence/04_check_mode.txt`](evidence/04_check_mode.txt).

## Запуск с --diff

```bash
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml --diff
```

При первом запуске Ansible создал каталоги, скачал архивы, распаковал ClickHouse и Vector, положил конфиг Vector.

Проверка ClickHouse:

```text
ClickHouse local version 22.3.3.44 (official build).
```

Проверка Vector:

```text
Validated
```

Файл: [`evidence/05_apply_diff.txt`](evidence/05_apply_diff.txt).

## Повторный запуск

Повторно запустил тот же playbook с `--diff`.

```text
clickhouse-01 : changed=0
vector-01     : changed=0
```

То есть playbook идемпотентен: второй запуск ничего лишнего не меняет.

Файл: [`evidence/06_idempotency_diff.txt`](evidence/06_idempotency_diff.txt).
