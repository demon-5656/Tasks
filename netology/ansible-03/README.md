# Домашнее задание к занятию 3 «Использование Ansible»

В этом задании дописал playbook: к ClickHouse и Vector добавил установку LightHouse. По заданию надо было готовить три хоста в Yandex Cloud, но облако после прошлого блока уже вычищено, чтобы не платить за простой. Поэтому проверку сделал на трех docker-контейнерах. Для Ansible это все равно обычные managed hosts, только подключение идет через Docker connection.

С Docker опять был небольшой тупняк: минимальный `ubuntu:22.04` не содержит `python3-apt`, а без него `apt` в `--check` падает. Поэтому перед запуском playbook в контейнеры добавил базовый минимум: `python3`, `python3-apt`, `tar`, `gzip`, `ca-certificates`.

## Inventory

Inventory: [`playbook/inventory/prod.yml`](playbook/inventory/prod.yml).

```yaml
clickhouse:
  hosts:
    clickhouse-01:
      ansible_connection: community.docker.docker

vector:
  hosts:
    vector-01:
      ansible_connection: community.docker.docker

lighthouse:
  hosts:
    lighthouse-01:
      ansible_connection: community.docker.docker
```

Контейнеры:

```text
NAMES           IMAGE          STATUS
lighthouse-01   ubuntu:22.04   Up
vector-01       ubuntu:22.04   Up
clickhouse-01   ubuntu:22.04   Up
```

Файл: [`evidence/03_docker_containers.txt`](evidence/03_docker_containers.txt).

## Что делает playbook

Playbook: [`playbook/site.yml`](playbook/site.yml).

В нем три play:

- `Install ClickHouse`;
- `Install Vector`;
- `Install LightHouse`.

ClickHouse:

- создает рабочие каталоги;
- скачивает архив `clickhouse-common-static`;
- распаковывает ClickHouse;
- создает symlink `/usr/local/bin/clickhouse`;
- проверяет бинарник через `clickhouse local --version`.

Vector:

- создает каталоги;
- скачивает архив Vector;
- распаковывает Vector;
- создает symlink `/usr/local/bin/vector`;
- кладет конфиг из шаблона [`playbook/templates/vector.yaml.j2`](playbook/templates/vector.yaml.j2);
- проверяет конфиг командой `vector validate`.

LightHouse:

- ставит `nginx`;
- скачивает статику LightHouse с GitHub;
- распаковывает ее в `/var/www/lighthouse`;
- кладет nginx-конфиг из шаблона [`playbook/templates/lighthouse-nginx.conf.j2`](playbook/templates/lighthouse-nginx.conf.j2);
- включает сайт через symlink в `sites-enabled`;
- выключает дефолтный сайт nginx;
- проверяет конфиг командой `nginx -t`;
- запускает nginx в docker-стенде.

На обычной VM сервисы можно дергать через handlers. В контейнерах без systemd handlers специально не выполняются:

```yaml
clickhouse_manage_service: false
vector_manage_service: false
lighthouse_manage_service: false
```

## Параметры

ClickHouse: [`playbook/group_vars/clickhouse/vars.yml`](playbook/group_vars/clickhouse/vars.yml).

```yaml
clickhouse_version: "22.3.3.44"
clickhouse_arch: amd64
clickhouse_install_dir: /opt/clickhouse
clickhouse_config_dir: /etc/clickhouse-server
clickhouse_data_dir: /var/lib/clickhouse
clickhouse_log_dir: /var/log/clickhouse-server
clickhouse_manage_service: false
```

Vector: [`playbook/group_vars/vector/vars.yml`](playbook/group_vars/vector/vars.yml).

```yaml
vector_version: "0.38.0"
vector_arch: x86_64-unknown-linux-gnu
vector_install_dir: /opt/vector
vector_config_dir: /etc/vector
vector_data_dir: /var/lib/vector
vector_source_interval: 10
vector_manage_service: false
```

LightHouse: [`playbook/group_vars/lighthouse/vars.yml`](playbook/group_vars/lighthouse/vars.yml).

```yaml
lighthouse_install_dir: /var/www/lighthouse
lighthouse_archive_url: https://github.com/VKCOM/lighthouse/archive/refs/heads/master.tar.gz
lighthouse_listen_port: 80
lighthouse_server_name: localhost
lighthouse_manage_service: false
```

## Теги

В playbook есть три тега:

- `clickhouse`;
- `vector`;
- `lighthouse`.

Можно запускать только нужную часть:

```bash
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml --tags clickhouse
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml --tags vector
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml --tags lighthouse
```

## Проверки

Синтаксис:

```bash
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml --syntax-check
```

Файл: [`evidence/01_syntax_check.txt`](evidence/01_syntax_check.txt).

Lint:

```bash
uvx ansible-lint playbook/site.yml
```

Результат:

```text
Passed: 0 failure(s), 0 warning(s)
```

Файл: [`evidence/02_ansible_lint.txt`](evidence/02_ansible_lint.txt).

## Запуск с --check

```bash
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml --check
```

`--check` прошел. Часть задач пропускается, потому что в check-mode архивы реально не распаковываются, а значит бинарников и конфигов еще нет.

Файл: [`evidence/04_check_mode.txt`](evidence/04_check_mode.txt).

## Запуск с --diff

```bash
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml --diff
```

Первый запуск внес изменения:

- установил и проверил ClickHouse;
- установил и проверил Vector;
- установил nginx;
- скачал и разложил LightHouse;
- положил nginx-конфиг;
- поднял nginx.

Проверки из вывода:

```text
ClickHouse local version 22.3.3.44 (official build).
Validated
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

Файл: [`evidence/05_apply_diff.txt`](evidence/05_apply_diff.txt).

## Повторный запуск

Второй запуск с `--diff`:

```text
clickhouse-01  : changed=0
vector-01      : changed=0
lighthouse-01  : changed=0
```

Playbook идемпотентен, повторно ничего лишнего не меняет.

Файл: [`evidence/06_idempotency_diff.txt`](evidence/06_idempotency_diff.txt).

## Проверка LightHouse

После запуска nginx проверил HTTP внутри контейнера:

```text
200
```

Файл: [`evidence/07_lighthouse_http_check.txt`](evidence/07_lighthouse_http_check.txt).
