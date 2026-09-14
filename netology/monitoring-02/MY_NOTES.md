---
tags:
  - netology
  - monitoring
  - TICK
---

# 13 — Системы мониторинга

Выполнено задание по системам мониторинга: разобраны базовые метрики, SLI/SLO/SLA, pull и push-модели, классификация Prometheus, TICK, Zabbix, VictoriaMetrics и Nagios.

Поднят TICK-стек через Docker Compose. В рабочей конфигурации используются InfluxDB 1.8, Telegraf, Chronograf и Kapacitor. Chronograf доступен на `http://localhost:8888`, InfluxDB получает метрики CPU, system и Docker.

В `telegraf.conf` добавлен Docker input через `/var/run/docker.sock`. После перезапуска появились измерения `docker`, `docker_container_cpu`, `docker_container_mem`, `docker_container_net`, `docker_container_status` и другие.

В Data Explorer проверены база `telegraf.autogen`, измерение `cpu`, поле `usage_system` и host `telegraf-getting-started`. Запрос к InfluxDB вернул значения загрузки CPU.

Исходники, отчёт, скриншоты и evidence:

- [[README|Отчёт и исходники задания]]
- [[README#8. Data Explorer и CPU|Проверка CPU в Data Explorer]]
- [[README#9. Метрики Docker|Проверка Docker-метрик]]
