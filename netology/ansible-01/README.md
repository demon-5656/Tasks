# Домашнее задание к занятию 1 «Введение в Ansible»

Использовал playbook из задания: `site.yml`, `inventory/test.yml`, `inventory/prod.yml` и `group_vars`.

Ansible на моей машине:

```text
ansible [core 2.21.2]
python version = 3.14.6
```

С docker-окружением немного повозился. Сначала попробовал старые учебные образы, но playbook не стартовал нормально: в одном контейнере не было подходящего Python, в другом Python оказался слишком старым для моего Ansible. После этого взял свежие образы, а имена хостов оставил как в задании:

- `centos7` -> `rockylinux:9`;
- `ubuntu` -> `ubuntu:22.04`.

Ansible все равно подключается к ним через `ansible_connection: docker`, так что логика задания не поменялась.

## 1. Запуск на test.yml

```bash
ansible-playbook -i playbook/inventory/test.yml playbook/site.yml
```

Результат:

```text
ok: [localhost] => {
    "msg": 12
}
```

Файл с выводом: [`evidence/01_test_initial.txt`](evidence/01_test_initial.txt).

Значение `some_fact` берется из файла:

```text
playbook/group_vars/all/examp.yml
```

Поменял значение на:

```yaml
some_fact: "all default fact"
```

## 2. Подготовка prod-окружения

```bash
docker run -d --name centos7 rockylinux:9 sleep infinity
docker run -d --name ubuntu ubuntu:22.04 sleep infinity
```

В контейнерах проверил `python3`, потому что без него Ansible не сможет собрать facts.

Проверка контейнеров:

```text
NAMES     IMAGE          STATUS
ubuntu    ubuntu:22.04   Up
centos7   rockylinux:9   Up
```

Файл: [`evidence/04_docker_containers_fixed.txt`](evidence/04_docker_containers_fixed.txt).

## 3. Запуск prod.yml до правки group_vars

```bash
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml
```

Получилось:

```text
centos7 -> el
ubuntu  -> deb
```

Файл: [`evidence/05_prod_before_group_fix_success.txt`](evidence/05_prod_before_group_fix_success.txt).

Тут как раз видно, что для хостов в группах `el` и `deb` срабатывают их групповые переменные, а не общее значение из `all`.

## 4. Правка group_vars для deb и el

Поменял значения:

```yaml
# playbook/group_vars/deb/examp.yml
some_fact: "deb default fact"

# playbook/group_vars/el/examp.yml
some_fact: "el default fact"
```

Повторный запуск:

```text
centos7 -> el default fact
ubuntu  -> deb default fact
```

Файл: [`evidence/06_prod_after_group_fix.txt`](evidence/06_prod_after_group_fix.txt).

## 5. Ansible Vault

Файлы групп `deb` и `el` зашифровал паролем `netology`:

```bash
ansible-vault encrypt \
  playbook/group_vars/deb/examp.yml \
  playbook/group_vars/el/examp.yml
```

Файл после шифрования начинается так:

```text
$ANSIBLE_VAULT;1.1;AES256
```

Проверка: [`evidence/07_vault_file_header.txt`](evidence/07_vault_file_header.txt).

Запуск playbook с vault:

```bash
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml --ask-vault-pass
```

Для сохранения вывода в evidence использовал тот же пароль через vault password file.
В обычном ручном запуске удобнее `--ask-vault-pass`: ввел пароль и playbook дальше сам расшифровывает нужные файлы.

Результат:

```text
centos7 -> el default fact
ubuntu  -> deb default fact
```

Файл: [`evidence/08_prod_with_vault.txt`](evidence/08_prod_with_vault.txt).

## 6. Connection plugin для control node

Для localhost использовал connection plugin:

```text
ansible.builtin.local
```

Он выполняет задачи на control node, то есть на машине, где запущен Ansible.
Для локального хоста это самый простой вариант, SSH тут вообще не нужен.

Проверка через `ansible-doc`: [`evidence/09_ansible_doc_local.txt`](evidence/09_ansible_doc_local.txt).

В `prod.yml` добавил группу:

```yaml
local:
  hosts:
    localhost:
      ansible_connection: ansible.builtin.local
```

```bash
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml --ask-vault-pass
```

Результат:

```text
centos7   -> el default fact
ubuntu    -> deb default fact
localhost -> all default fact
```

Файл: [`evidence/10_prod_with_local.txt`](evidence/10_prod_with_local.txt).

## 7. Проверка синтаксиса

```bash
ansible-playbook -i playbook/inventory/prod.yml playbook/site.yml --syntax-check --ask-vault-pass
```

Результат:

```text
playbook: playbook/site.yml
```

Файл: [`evidence/11_syntax_check.txt`](evidence/11_syntax_check.txt).
