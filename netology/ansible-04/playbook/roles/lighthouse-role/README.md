# lighthouse-role

Роль скачивает LightHouse, раскладывает статику в `/var/www/lighthouse` и настраивает nginx.

## Переменные

| Переменная | Значение по умолчанию | Описание |
| --- | --- | --- |
| `lighthouse_listen_port` | `80` | Порт nginx |
| `lighthouse_server_name` | `localhost` | `server_name` в nginx |
| `lighthouse_manage_service` | `true` | Перезагружать nginx через handler |

Внутренние пути и URL архива лежат в `vars/main.yml`.

## Пример

```yaml
- hosts: lighthouse
  pre_tasks:
    - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present
  roles:
    - role: lighthouse-role
```
