# Мои заметки по итоговому проекту

Смысл задания не в том, чтобы руками натыкать VM в облаке. Идея в другом: описать всю инфраструктуру кодом, чтобы потом можно было поднять проект заново без гадания “а что я там включал в веб-интерфейсе”.

Что тут проверяют:

- понимаю ли я, что такое VPC и подсети;
- умею ли открыть нужные порты через security group;
- могу ли поставить Docker на VM через cloud-init;
- умею ли собрать приложение в Docker-образ;
- понимаю ли, зачем нужен Container Registry;
- могу ли вынести базу в Managed MySQL;
- не храню ли пароли прямо в коде;
- понимаю ли remote state и locking.

Почему взяли `legacy-100-years`:

- это мой проект, а не пустой nginx;
- у него есть frontend и backend;
- появилась авторизация;
- прогресс игры сохраняется в MySQL;
- значит, итоговый проект выглядит как живое приложение.

Как это работает по шагам:

1. Terraform создает сеть.
2. В сети появляется VM и Managed MySQL.
3. Terraform создает Container Registry.
4. Я собираю Docker-образы приложения и пушу их в registry.
5. VM через cloud-init ставит Docker.
6. VM запускает `docker-compose.cloud.yml`.
7. nginx-контейнер отдает frontend.
8. api-контейнер работает с MySQL.
9. Пользователь регистрируется, подтверждает почту, играет.
10. Прогресс сохраняется уже не в браузере, а в базе.

Важная мысль: Docker тут нужен не “потому что модно”, а чтобы сервер был тупым хостом для контейнеров. На новой машине не надо вспоминать версии Node/nginx/npm. Поднял Docker, дал `.env`, запустил compose.

Что надо не забыть перед реальным запуском:

- создать/подставить `backend.hcl`;
- создать `personal.auto.tfvars`;
- проверить, что в Git не попали пароли;
- сделать `terraform init -backend-config=backend.hcl`;
- сделать `terraform plan`;
- только потом `terraform apply`.

Что может сломаться:

- если образы не запушены в Container Registry, VM поднимется, но compose не скачает контейнеры;
- если registry приватный, надо настроить docker login/доступ для VM;
- если SMTP не задан, письма не уйдут наружу;
- если `PUBLIC_BASE_URL` оставить `http://localhost`, ссылки в письмах будут учебные, а не рабочие;
- Managed MySQL стоит денег, после проверки лучше сделать `terraform destroy`.

Нормальный порядок для скринов:

```bash
terraform -chdir=src fmt -check -recursive
terraform -chdir=src init -backend-config=backend.hcl
terraform -chdir=src validate
terraform -chdir=src plan
terraform -chdir=src apply
terraform -chdir=src output
```

Потом открыть приложение, создать пользователя, подтвердить почту, зайти заново и показать, что прогресс подтянулся.

## Автоудаление стенда

Чтобы не забыть удалить платные ресурсы после проверки, добавлены скрипты:

- `scripts/destroy_stack.sh` - делает `terraform init` и `terraform destroy`;
- `scripts/install_destroy_timer.sh` - ставит cron или systemd timer;
- `scripts/remove_destroy_timer.sh` - снимает таймер.

На моей машине `crontab` не установлен, поэтому поставлен systemd user timer.

Проверить:

```bash
systemctl --user list-timers netology-terraform-final-destroy.timer
```

Запланировано на `2026-07-28 10:00 MSK`.

Если проверка затянется, таймер можно снять:

```bash
netology/terraform-final/scripts/remove_destroy_timer.sh
```
