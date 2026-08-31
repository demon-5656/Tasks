# Домашнее задание к занятию 11 «TeamCity»

В работе настроен учебный проект `plaindoll`: сборка запускается от VCS-триггера, для feature-веток выполняются тесты, а `master` публикуется в Nexus. Конфигурация TeamCity хранится в репозитории через Kotlin DSL.

## Ссылки

Папки с работой:

- [`example-teamcity`](example-teamcity) — fork проекта, исходники, тесты и Kotlin DSL;
- [`example-teamcity/.teamcity`](example-teamcity/.teamcity) — versioned configuration TeamCity;
- [`example-teamcity/teamcity`](example-teamcity/teamcity) — шаблон Maven settings;
- [`evidence`](evidence) — результаты локальных проверок;
- [`screenshots`](screenshots) — скриншоты стенда.

Fork на GitHub:

- <https://github.com/demon-5656/example-teamcity>

Для отправки в ЛК:

```text
https://github.com/demon-5656/Tasks/blob/main/netology/teamcity-01/REPORT.md
```

## Что сделано

В fork проекта добавлен метод `Welcomer.sayReply()`. Он возвращает реплику со словом `hunter`:

```java
public String sayReply() {
    return "A hunter must keep moving forward.";
}
```

Для него добавлен тест:

```java
@Test
public void welcomerReplyContainsHunter() {
    assertThat(welcomer.sayReply(), containsString("hunter"));
}
```

Ветка `feature/add_reply` влита в `master` merge-коммитом [`90c548c`](https://github.com/demon-5656/example-teamcity/commit/90c548cf11b858842d30c143372238d35c66c967).

## Конфигурация TeamCity

В [`example-teamcity/.teamcity/settings.kts`](example-teamcity/.teamcity/settings.kts) сохранена versioned configuration:

- VCS trigger запускает сборку после push;
- для веток, отличных от `master`, выполняется `mvn clean test`;
- для `master` выполняется `mvn clean deploy`;
- deploy использует Maven settings с именем `settings.xml`;
- артефакты сборки: `target/*.jar => target`.

Шаблон Maven settings находится в [`example-teamcity/teamcity/settings.xml.template`](example-teamcity/teamcity/settings.xml.template). Для Nexus используются переменные окружения `NEXUS_USERNAME` и `NEXUS_PASSWORD`, поэтому логин и пароль не хранятся в Git.

Конфигурация добавлена коммитом [`4615a78`](https://github.com/demon-5656/example-teamcity/commit/4615a78cb6a6554f14409bdb73a0e6747ae8b95d).

## Проверки

### Локальная сборка

```bash
javac -d target/classes src/main/java/plaindoll/*.java
java -cp 'target/classes;target/test-classes' TeamcityHomeworkCheck
```

Результат:

```text
All Welcomer checks passed
```

Полный вывод: [`evidence/01_local_build.txt`](evidence/01_local_build.txt).

После этого собран и запущен `target/plaindoll-0.0.2.jar`:

```text
Welcome home, good hunter. What is it your desire?
Farewell, good hunter. May you find your worth in waking world.
```

### Конфигурационные файлы

`pom.xml` и `teamcity/settings.xml.template` проверены XML-парсером:

```text
XML validation passed
```

Файл: [`evidence/02_xml_validation.txt`](evidence/02_xml_validation.txt).

## Стенд TeamCity

Для работы был поднят отдельный стенд в Yandex Cloud: TeamCity Server, Build Agent и VM для playbook. Первый запуск TeamCity:

![Первый запуск TeamCity](screenshots/teamcity-first-start.png)

На момент последней проверки прежний публичный адрес TeamCity не отвечал, а Nexus был доступен только из внутренней сети. Поэтому в этом обновлении не добавляю неподтверждённые скриншоты повторной live-сборки и загрузки артефакта в Nexus.
