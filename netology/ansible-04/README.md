# Домашнее задание к занятию 4 «Работа с roles»

В этой работе переделал прошлый playbook на роли. Идея простая: раньше задачи лежали одним большим файлом, теперь каждый продукт живет отдельно.

- ClickHouse подключается внешней ролью через `requirements.yml`;
- Vector вынесен в роль `vector-role`;
- LightHouse вынесен в роль `lighthouse-role`;
- основной playbook только связывает inventory, переменные и роли.

Проверку делал на docker-контейнерах, как и в прошлой работе. В Yandex Cloud не поднимал, потому что для проверки структуры ролей контейнеров хватает, а облако после Terraform-блока уже вычищено.

## Ссылки

Playbook: [`playbook/site.yml`](playbook/site.yml).

Роли:

- [`vector-role`](playbook/roles/vector-role);
- [`lighthouse-role`](playbook/roles/lighthouse-role).

Файл зависимостей:

- [`playbook/requirements.yml`](playbook/requirements.yml).

Для отправки в ЛК можно указать ссылку на этот файл:

```text
https://github.com/demon-5656/Tasks/blob/main/netology/ansible-04/README.md
```

Если проверяющий строго попросит именно отдельные публичные репозитории под роли, эти каталоги можно вынести в `demon-5656/vector-role` и `demon-5656/lighthouse-role` без изменения логики.

## requirements.yml

По заданию ClickHouse подключается готовой ролью:

```yaml
---
- src: git@github.com:AlexeySetevoi/ansible-clickhouse.git
  scm: git
  version: "1.13"
  name: clickhouse
```

Установка:

```bash
cd playbook
ansible-galaxy install -r requirements.yml -p roles --force
```

Результат сохранен в [`evidence/00_requirements_install.txt`](evidence/00_requirements_install.txt).

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
NAMES               IMAGE                           STATUS
lighthouse-01       ubuntu:22.04                    Up
vector-01           ubuntu:22.04                    Up
clickhouse-01       ubuntu:22.04                    Up
```

Файл: [`evidence/03_docker_containers.txt`](evidence/03_docker_containers.txt).

## Что изменилось в playbook

Раньше в `site.yml` были все tasks. Теперь он выглядит намного короче:

```yaml
- name: Install ClickHouse
  hosts: clickhouse
  roles:
    - role: clickhouse

- name: Install Vector
  hosts: vector
  roles:
    - role: vector-role

- name: Install LightHouse
  hosts: lighthouse
  pre_tasks:
    - name: Install LightHouse runtime packages
      ansible.builtin.apt:
        name:
          - nginx
          - tar
          - gzip
          - ca-certificates
        state: present
  roles:
    - role: lighthouse-role
```

С LightHouse оставил `pre_tasks`, потому что nginx и базовые пакеты - это зависимость окружения. Сначала хотел засунуть все внутрь роли, но потом решил оставить так: роль отвечает за сам LightHouse и nginx-конфиг, а подготовка пакетов видна в playbook.

## Vector role

Роль: [`playbook/roles/vector-role`](playbook/roles/vector-role).

Что делает:

- создает каталоги `/opt/vector`, `/etc/vector`, `/var/lib/vector`;
- скачивает архив Vector;
- распаковывает его;
- создает symlink `/usr/local/bin/vector`;
- кладет конфиг из шаблона;
- проверяет конфиг через `vector validate`.

Переменные по умолчанию: [`defaults/main.yml`](playbook/roles/vector-role/defaults/main.yml).

```yaml
vector_version: "0.38.0"
vector_arch: x86_64-unknown-linux-gnu
vector_manage_service: true
vector_source_interval: 10
```

Внутренние пути лежат в [`vars/main.yml`](playbook/roles/vector-role/vars/main.yml).

## LightHouse role

Роль: [`playbook/roles/lighthouse-role`](playbook/roles/lighthouse-role).

Что делает:

- создает `/var/www/lighthouse`;
- скачивает архив LightHouse;
- распаковывает статику;
- генерирует nginx-конфиг;
- включает сайт через symlink;
- отключает дефолтный сайт nginx;
- проверяет `nginx -t`;
- в docker-стенде запускает nginx командой `nginx`.

Переменные по умолчанию: [`defaults/main.yml`](playbook/roles/lighthouse-role/defaults/main.yml).

```yaml
lighthouse_listen_port: 80
lighthouse_server_name: localhost
lighthouse_manage_service: true
```

## Проверки

Синтаксис:

```bash
cd playbook
ansible-playbook site.yml --syntax-check
```

Файл: [`evidence/01_syntax_check.txt`](evidence/01_syntax_check.txt).

Lint:

```bash
ANSIBLE_CONFIG=playbook/ansible.cfg uvx ansible-lint playbook/site.yml
```

Результат:

```text
Passed: 0 failure(s), 0 warning(s)
```

Файл: [`evidence/02_ansible_lint.txt`](evidence/02_ansible_lint.txt).

## Запуск с --check

```bash
cd playbook
ansible-playbook site.yml --tags vector,lighthouse --check
```

`--check` прошел. Часть задач ожидаемо пропускается: в check-mode архивы не распаковываются, поэтому проверять бинарник и nginx-конфиг еще нечего.

Файл: [`evidence/04_check_mode.txt`](evidence/04_check_mode.txt).

В выводе видно несколько задач ClickHouse, хотя запускал только `vector,lighthouse`. Это не ошибка моего playbook: внешняя роль ClickHouse помечает часть внутренних задач тегом `always`, поэтому Ansible их показывает даже при запуске по тегам.

## Первый запуск

```bash
cd playbook
ansible-playbook site.yml --tags vector,lighthouse --diff
```

Первый запуск:

- установил Vector;
- положил конфиг Vector;
- проверил `vector validate`;
- установил nginx;
- разложил LightHouse;
- положил nginx-конфиг;
- проверил `nginx -t`;
- запустил nginx в контейнере.

Файл: [`evidence/05_apply_diff.txt`](evidence/05_apply_diff.txt).

Из вывода:

```text
Validated
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

## Повторный запуск

```bash
cd playbook
ansible-playbook site.yml --tags vector,lighthouse --diff
```

Повторный запуск ничего лишнего не поменял:

```text
lighthouse-01 : changed=0
vector-01     : changed=0
```

Файл: [`evidence/06_idempotency_diff.txt`](evidence/06_idempotency_diff.txt).

## Дополнительная проверка

LightHouse отвечает:

```text
200
```

Файл: [`evidence/07_lighthouse_http_check.txt`](evidence/07_lighthouse_http_check.txt).

Vector:

```text
vector 0.38.0
Validated
```

Файл: [`evidence/08_vector_check.txt`](evidence/08_vector_check.txt).
