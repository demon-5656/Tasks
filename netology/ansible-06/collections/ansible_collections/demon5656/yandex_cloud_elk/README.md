# demon5656.yandex_cloud_elk

Учебная Ansible collection для задания по собственным модулям.

## Содержимое

- `plugins/modules/my_own_module.py` - модуль, который создает или обновляет текстовый файл.
- `roles/write_text_file` - role-обертка вокруг модуля.
- `playbooks/direct_module.yml` - пример прямого вызова модуля.
- `playbooks/role_module.yml` - пример вызова через role.

## Модуль

```yaml
- name: Create file from custom module
  demon5656.yandex_cloud_elk.my_own_module:
    path: /tmp/netology_direct_module.txt
    content: "Direct module call works"
    mode: "0644"
```

Параметры:

| Параметр | Обязательный | Описание |
| --- | --- | --- |
| `path` | да | Путь к файлу |
| `content` | да | Текстовое содержимое |
| `mode` | нет | Права файла, по умолчанию `0644` |

Модуль идемпотентный: если файл уже есть и содержимое совпадает, возвращает `changed: false`.

## Role

```yaml
- hosts: localhost
  roles:
    - role: demon5656.yandex_cloud_elk.write_text_file
      vars:
        text_file_path: /tmp/netology_role_module.txt
        text_file_content: "Role call works too"
```

## Сборка

```bash
ansible-galaxy collection build
```
