# Локальный стенд для проверки маршрутизации

Четыре настоящие QEMU/KVM VM: `nat`, `public`, `private` и `router`. Последняя заменяет встроенный маршрутизатор VPC только в тестовой среде. Это не эмуляция API Yandex Cloud и не запуск облачного NAT-образа.

## Сеть

| VM | Интерфейсы учебной сети | Доступ с хоста |
|---|---|---|
| nat | public0: 192.168.10.254/24 | SSH 127.0.0.1:22350 |
| public | public0: 192.168.10.10/24 | SSH 127.0.0.1:22351 |
| router | public0: 192.168.10.1/24; private0: 192.168.20.1/24 | SSH 127.0.0.1:22352 |
| private | private0: 192.168.20.10/24 | Только через ProxyJump public |

У NAT, public и router дополнительно есть интерфейс `wan0` через QEMU user-mode networking. Его адрес `10.0.2.15` существует отдельно в каждой VM и не является публичным адресом облака. У private такого интерфейса нет.

Трафик private идёт на шлюз `192.168.20.1`. Router применяет к источнику `192.168.20.0/24` таблицу 100, где default route направлен на NAT `192.168.10.254`. NAT включает IPv4 forwarding и MASQUERADE для приватной подсети. Внутренние маршруты сохраняют прямую связь подсетей; NAT и public имеют обратный маршрут к `192.168.20.0/24` через router.

Учебные Ethernet-сегменты реализованы QEMU socket/multicast на loopback. Скрипт не создаёт мосты на хосте, не меняет его маршруты и не требует host sudo.

## Повторный запуск

Нужны Linux с доступным KVM, QEMU, `qemu-img`, `xorriso`, OpenSSH, Python 3.10+ и PyYAML. Базовый образ — Ubuntu 20.04 cloud image в формате qcow2. Он открывается как read-only backing image; записи идут в отдельные overlays.

Из этой папки:

```bash
BASE=/path/to/ubuntu-cloud-image.qcow2
STATE="$HOME/GIT/agent-workspace/tasks/$(date +%F)-nat-lab/scratch/vms"
python3 lab.py up --base-image "$BASE" --state-dir "$STATE"

alias labssh='ssh -q -F "$STATE/ssh-config"'
labssh public 'hostname; ip -4 route'
labssh private 'hostname; ip -4 route'
python3 verify.py --state-dir "$STATE" --output /path/to/local-verification.json
```

`lab.py` создаёт собственный SSH-ключ в закрытой папке состояния. Конфигурация private содержит `ProxyJump public`; напрямую проброшенного SSH-порта у private нет. В непустую папку состояния скрипт не записывает новый стенд.

`verify.py` проверяет HTTPS из public и private, таблицу маршрутизации и SSH ProxyJump. Затем временно отключает forwarding **в гостевой NAT VM**: private должен получить curl exit 28, а public — сохранить HTTP 200. Для отрицательной проверки адрес сайта фиксируется через `--resolve`, чтобы таймаут DNS не был принят за потерю маршрута. В `finally` forwarding включается обратно, затем проверяется восстановление HTTPS.

Для удаления **только созданного этим запуском стенда**:

```bash
python3 lab.py down --state-dir "$STATE" --delete
```

Сначала штатно выключаются гостевые ОС. При незавершённом shutdown файлы не удаляются. Исходный backing image сохраняется. Папку состояния, приватный SSH-ключ и диски VM в Git не добавлять.
