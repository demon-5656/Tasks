# Домашнее задание к занятию 5 «Тестирование roles»

В этой работе настроил тесты для `vector-role`. Роль взял из прошлого задания и добавил к ней Molecule-сценарии.

Смысл задания, как я понял: не просто написать роль, а проверить, что она реально разворачивается на чистом окружении, проходит повторный запуск без изменений и не кладет битый конфиг.

## Ссылки

Роль:

- [`vector-role`](vector-role)

Molecule:

- [`molecule/default`](vector-role/molecule/default)
- [`molecule/podman`](vector-role/molecule/podman)

Tox:

- [`vector-role/tox.ini`](vector-role/tox.ini)

Для отправки в ЛК:

```text
https://github.com/demon-5656/Tasks/blob/main/netology/ansible-05/README.md
```

Теги:

- `ansible-05-molecule-v1.0.0`
- `ansible-05-tox-v1.0.0`

## Что добавлено в роль

В `vector-role` добавлены два сценария.

`default`:

- driver: `docker`;
- проверяет `ubuntu:latest`;
- проверяет `oraclelinux:8`;
- перед запуском роли ставит минимальные пакеты через `prepare.yml`;
- выполняет `converge`;
- проверяет идемпотентность;
- запускает `verify.yml`.

`podman`:

- driver: `podman`;
- используется для `tox`;
- сделан легче, на одном ansible-ready Ubuntu образе;
- использует те же `converge.yml` и `verify.yml`, чтобы проверки не расходились.

## Verify

В [`verify.yml`](vector-role/molecule/default/verify.yml) добавил проверки:

- существует symlink `/usr/local/bin/vector`;
- существует `/etc/vector/vector.yaml`;
- `vector --version` возвращает нужную версию;
- `vector validate /etc/vector/vector.yaml` проходит успешно;
- Vector может стартовать с созданным конфигом.

Для старта использовал `timeout 5`, потому что Vector - долгоживущий процесс. Если он не падает сразу и завершается по timeout, это нормальный результат для теста.

## Где пришлось повозиться

Первый прогон Molecule упал на имени роли. Папка называется `vector-role`, а Galaxy/Molecule сейчас хотят имя роли без дефиса. Папку оставил как в задании, но в `meta/main.yml` добавил:

```yaml
namespace: demon_5656
role_name: vector_role
```

Потом был второй тупняк с `oraclelinux:8`: там старый Python, а свежий Ansible уже использует синтаксис, который этот Python не понимает. Поэтому в `prepare.yml` для OracleLinux ставится `python39`, а в inventory сценария задано:

```yaml
ansible_python_interpreter: /usr/bin/python3.9
```

С Tox тоже пришлось чуть подкрутить. В образе `aragast/netology:latest` старый Python по умолчанию, зато есть `python3.9`. Поэтому `tox.ini` запускает окружение `py39` и пинит версии:

```ini
ansible-core==2.15.13
molecule==6.0.3
molecule-plugins[podman]==23.5.0
```

## Проверки

### Syntax

```bash
cd vector-role
ANSIBLE_ROLES_PATH=/home/pc243/GIT/Tasks/netology/ansible-05 ansible-playbook molecule/default/converge.yml --syntax-check
```

Файл: [`evidence/01_converge_syntax.txt`](evidence/01_converge_syntax.txt).

### Ansible Lint

```bash
cd netology/ansible-05
uvx ansible-lint vector-role
```

Результат:

```text
Passed: 0 failure(s), 0 warning(s)
```

Файл: [`evidence/02_ansible_lint.txt`](evidence/02_ansible_lint.txt).

### Molecule default

```bash
cd vector-role
uvx --with 'molecule-plugins[docker]' --with ansible-core --from molecule molecule test -s default
```

Результат:

```text
vector-oraclelinux : failed=0
vector-ubuntu      : failed=0
```

Внутри прогона:

- role установилась на Ubuntu и OracleLinux;
- `vector validate` прошел;
- idempotence дал `changed=0`;
- assert-проверки прошли.

Файл: [`evidence/03_molecule_default.txt`](evidence/03_molecule_default.txt).

### Образ для tox

```bash
docker pull aragast/netology:latest
```

Файл: [`evidence/04_docker_pull_netology.txt`](evidence/04_docker_pull_netology.txt).

### Tox + Podman

Запускал по схеме из задания:

```bash
docker run --rm --privileged=true \
  -e USER=root \
  -v /home/pc243/GIT/Tasks/netology/ansible-05/vector-role:/opt/vector-role \
  -w /opt/vector-role \
  aragast/netology:latest \
  /bin/bash -lc 'tox'
```

Результат:

```text
py39: commands succeeded
congratulations :)
```

Файл: [`evidence/05_tox_podman.txt`](evidence/05_tox_podman.txt).

## Итог

Роль Vector проверяется двумя сценариями:

- полноценный Molecule на Docker с двумя дистрибутивами;
- облегченный Molecule через Podman, запущенный из Tox.

Тесты проверяют не только факт установки, но и валидность конфига, старт Vector и идемпотентность.
