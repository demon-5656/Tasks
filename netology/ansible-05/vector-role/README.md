# vector-role

Роль ставит Vector из официального архива, кладет конфиг и проверяет его через `vector validate`.

## Тестирование

В роли добавлены два Molecule-сценария:

- `default` - Docker, проверяет `ubuntu:latest` и `oraclelinux:8`;
- `podman` - облегченный сценарий для запуска через `tox`.

Команды:

```bash
molecule test -s default
tox
```

## Переменные

| Переменная | Значение по умолчанию | Описание |
| --- | --- | --- |
| `vector_version` | `0.38.0` | Версия Vector |
| `vector_arch` | `x86_64-unknown-linux-gnu` | Архитектура архива |
| `vector_manage_service` | `true` | Перезапускать systemd-сервис через handler |
| `vector_source_interval` | `10` | Интервал генерации demo logs |

Внутренние пути вынесены в `vars/main.yml`: `/opt/vector`, `/etc/vector`, `/var/lib/vector`.

## Пример

```yaml
- hosts: vector
  roles:
    - role: vector-role
```
