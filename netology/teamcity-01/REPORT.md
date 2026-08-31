# Домашнее задание к занятию «TeamCity»

Репозиторий с fork и результатом: <https://github.com/demon-5656/example-teamcity>.

## Выполнено в репозитории fork

- В `master` добавлен `Welcomer.sayReply()` с репликой, содержащей `hunter`; тест `welcomerReplyContainsHunter` проверяет это условие.
- Изменения из `feature/add_reply` влиты в `master` merge-коммитом `90c548c`.
- В `.teamcity/settings.kts` сохранена versioned configuration TeamCity:
  - VCS trigger;
  - для не-`master` — `mvn clean test`;
  - для `master` — `mvn clean deploy` с Maven settings `settings.xml`;
  - артефакты — `target/*.jar => target`.
- Шаблон Maven settings расположен в `teamcity/settings.xml.template`. Учётные данные берутся из `NEXUS_USERNAME` и `NEXUS_PASSWORD`, поэтому секреты не попадают в Git.

Последний коммит конфигурации: [`4615a78`](https://github.com/demon-5656/example-teamcity/commit/4615a78cb6a6554f14409bdb73a0e6747ae8b95d).

## Локальная проверка

Исходники скомпилированы JDK 26. Проверка методов `Welcomer`, включая `sayReply()`, прошла успешно; собран и запущен `target/plaindoll-0.0.2.jar`. XML-файлы `pom.xml` и шаблон Maven settings успешно разобраны XML-парсером.

## Стенд TeamCity

Стенд ранее был поднят в Yandex Cloud: TeamCity Server, Build Agent и отдельная VM для playbook. Скриншот первого запуска:

![Первый запуск TeamCity](screenshots/teamcity-first-start.png)

На момент обновления отчёта ранее использовавшийся адрес TeamCity не отвечает, а Nexus доступен только из внутренней сети. Поэтому повторный live-запуск TeamCity, авторизацию агента и появление артефакта в Nexus в этой сессии подтвердить невозможно.
