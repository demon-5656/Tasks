# Домашнее задание к занятию 6 «Создание собственных модулей»

В этой работе сделал свою Ansible collection с модулем и role. Модуль простой: создает текстовый файл по заданному пути и пишет туда заданное содержимое.

Сначала думал просто взять пример из документации и чуть поправить, но там демо-модуль только возвращает `goodbye`. Для задания нужен реальный эффект на хосте, поэтому сделал нормальную идемпотентность: если файл уже есть и текст совпадает, Ansible получает `changed: false`.

## Ссылки

Collection:

- [`collections/ansible_collections/demon5656/yandex_cloud_elk`](collections/ansible_collections/demon5656/yandex_cloud_elk)

Модуль:

- [`my_own_module.py`](collections/ansible_collections/demon5656/yandex_cloud_elk/plugins/modules/my_own_module.py)

Role:

- [`write_text_file`](collections/ansible_collections/demon5656/yandex_cloud_elk/roles/write_text_file)

Архив collection:

- [`demon5656-yandex_cloud_elk-1.0.0.tar.gz`](install-check/demon5656-yandex_cloud_elk-1.0.0.tar.gz)

Для отправки в ЛК:

```text
https://github.com/demon-5656/Tasks/blob/main/netology/ansible-06/README.md
```

## Что делает модуль

Пример вызова:

```yaml
- name: Create file from custom module
  demon5656.yandex_cloud_elk.my_own_module:
    path: /tmp/netology_direct_module.txt
    content: "Direct module call works"
    mode: "0644"
```

Параметры:

| Параметр | Описание |
| --- | --- |
| `path` | путь к файлу |
| `content` | текст, который нужно записать |
| `mode` | права файла, по умолчанию `0644` |

Логика:

- файла нет - создает файл, `changed: true`;
- файл есть, но текст отличается - обновляет файл, `changed: true`;
- файл есть и текст совпадает - ничего не делает, `changed: false`;
- в `check_mode` показывает, что изменил бы, но файл не пишет.

## Проверка модуля напрямую

Команда:

```bash
printf '{"ANSIBLE_MODULE_ARGS":{"path":"/tmp/netology_module_local.txt","content":"Module executable check","mode":"0644"}}' \
  | python collections/ansible_collections/demon5656/yandex_cloud_elk/plugins/modules/my_own_module.py
```

Результат:

```text
"changed": true
"message": "file created"
```

Файл: [`evidence/01_module_executable.txt`](evidence/01_module_executable.txt).

## Single task playbook

Playbook:

- [`direct_module.yml`](collections/ansible_collections/demon5656/yandex_cloud_elk/playbooks/direct_module.yml)

Первый запуск:

```bash
ANSIBLE_CONFIG=ansible.cfg ansible-playbook \
  collections/ansible_collections/demon5656/yandex_cloud_elk/playbooks/direct_module.yml \
  -i localhost, -c local
```

Результат:

```text
localhost : ok=1 changed=1 failed=0
```

Файл: [`evidence/02_direct_playbook_first.txt`](evidence/02_direct_playbook_first.txt).

Повторный запуск:

```text
localhost : ok=1 changed=0 failed=0
```

Файл: [`evidence/03_direct_playbook_idempotence.txt`](evidence/03_direct_playbook_idempotence.txt).

## Role внутри collection

Role:

- [`roles/write_text_file`](collections/ansible_collections/demon5656/yandex_cloud_elk/roles/write_text_file)

Defaults:

```yaml
text_file_path: /tmp/netology_my_own_module.txt
text_file_content: "Hello from my own Ansible module"
text_file_mode: "0644"
```

Playbook:

- [`role_module.yml`](collections/ansible_collections/demon5656/yandex_cloud_elk/playbooks/role_module.yml)

Первый запуск role:

```text
localhost : ok=1 changed=1 failed=0
```

Файл: [`evidence/04_role_playbook_first.txt`](evidence/04_role_playbook_first.txt).

Повторный запуск:

```text
localhost : ok=1 changed=0 failed=0
```

Файл: [`evidence/05_role_playbook_idempotence.txt`](evidence/05_role_playbook_idempotence.txt).

## Сборка collection

Команда:

```bash
cd collections/ansible_collections/demon5656/yandex_cloud_elk
ansible-galaxy collection build --force --output-path ../../../../install-check
```

Результат:

```text
Created collection for demon5656.yandex_cloud_elk
demon5656-yandex_cloud_elk-1.0.0.tar.gz
```

Файл: [`evidence/06_collection_build.txt`](evidence/06_collection_build.txt).

## Установка из архива

Для проверки сделал отдельную директорию [`install-check`](install-check). В ней лежит playbook и архив collection.

Команда:

```bash
cd install-check
ANSIBLE_CONFIG=ansible.cfg ansible-galaxy collection install \
  demon5656-yandex_cloud_elk-1.0.0.tar.gz \
  -p collections --force
```

Результат:

```text
demon5656.yandex_cloud_elk:1.0.0 was installed successfully
```

Файл: [`evidence/07_collection_install_from_archive.txt`](evidence/07_collection_install_from_archive.txt).

## Запуск playbook после установки collection

Playbook:

- [`install-check/use_installed_collection.yml`](install-check/use_installed_collection.yml)

Команда:

```bash
cd install-check
ANSIBLE_CONFIG=ansible.cfg ansible-playbook use_installed_collection.yml -i localhost, -c local
```

Результат:

```text
localhost : ok=1 changed=0 failed=0
Installed collection works
```

Файл: [`evidence/08_installed_collection_playbook.txt`](evidence/08_installed_collection_playbook.txt).

`changed=0` здесь потому, что файл уже был создан предыдущим запуском до пересборки архива. Для проверки это даже полезно: установленная collection отработала и показала идемпотентность.

## Тег

На итоговый коммит поставлен тег:

```text
1.0.0
```

Необязательную часть с созданием ВМ в Yandex Cloud не делал. Там уже нужно снова поднимать облако и тратить деньги, а основная часть задания закрыта собственным модулем, role, collection, сборкой и установкой из архива.
