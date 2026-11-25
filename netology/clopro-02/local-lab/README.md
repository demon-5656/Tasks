# Стенд проверки балансировки

## Состав

- три Apache/PHP backend с расширением `mysqli`;
- MariaDB для проверки SQL-соединения каждого backend;
- S3-совместимое Object Storage на SeaweedFS;
- HAProxy с TCP listener и HTTP health checks `/health.php`.

Стенд описан в [compose.yaml](compose.yaml), образы закреплены по digest. Приложение — [index.php](../app/index.php) и [health.php](../app/health.php). PHP выдаёт hostname и заголовок `X-Backend-Id`, поэтому видно, какой сервер обработал запрос. Картинка загружается отдельным запросом к S3.

Все опубликованные порты привязаны к `127.0.0.1`: приложение — `18880`, S3 — `18820`, статистика балансировщика — `18881`. SQL, backend и внутренние интерфейсы S3 наружу не публикуются. У S3 настроены отдельные подписанные административные запросы и анонимное чтение только тестового бакета; анонимная запись запрещена.

## Запуск

Нужны Docker с Compose, Python 3.10+, `requests` и `boto3 >= 1.36`. Пароли и ключи создаются заново и сохраняются с правами `0600` вне репозитория.

Из корня работы:

```bash
STATE="$HOME/GIT/agent-workspace/tasks/$(date +%F)-lamp-balancer/scratch/runtime"
python3 local-lab/bootstrap.py --state-dir "$STATE"

alias labcompose='docker compose --project-name netology-clopro15-2 --env-file "$STATE/private.env" -f local-lab/compose.yaml'
python3 local-lab/check.py object --format text
python3 local-lab/check.py sample --expect 3 --requests 30 --format text
```

Bootstrap создаёт приватную конфигурацию, запускает сервисы, создаёт бакет и загружает исходный PNG через подписанный S3 API. Затем сверяет публично полученные байты картинки с исходником и проверяет SQL на всех трёх backend. При уже существующем проекте или непустой папке состояния новый запуск не перезаписывает данные.

## Проверка отказов

Имена работающих серверов:

```bash
docker ps --filter label=com.docker.compose.project=netology-clopro15-2 \
  --filter label=com.docker.compose.service=web --format '{{.Names}}'
```

После удаления одного **своего тестового** web-контейнера проверка выполняется с `--expect 2`, после удаления второго — с `--expect 1`. Нельзя удалять контейнеры по общему поиску без фильтра проекта.

```bash
python3 local-lab/check.py sample --expect 2 --requests 30 --format text
python3 local-lab/check.py sample --expect 1 --requests 30 --format text

labcompose up -d --no-deps --scale web=3 --wait --wait-timeout 30 web
python3 local-lab/check.py sample --expect 3 --requests 30 --format text
```

Проверка ждёт, пока health checks отразят нужное количество доступных серверов. Каждый запрос открывает новое TCP-соединение: при повторном использовании keep-alive один TCP-сеанс может продолжать попадать на тот же backend, что не является ошибкой L4-балансировки.

В этой проверочной среде размер группы восстанавливается командой Compose. Настройки Instance Group и её health checks для облачной схемы находятся отдельно в [Terraform](../terraform).

## Остановка

```bash
labcompose down --volumes --remove-orphans
```

Эта команда относится только к проекту `netology-clopro15-2`. Новые образы удаляются отдельно с учётом исходного списка Docker images; глобальные `docker system prune` и `image prune` не нужны. Приватную папку состояния после остановки можно удалить, если её сохранение не требуется.
