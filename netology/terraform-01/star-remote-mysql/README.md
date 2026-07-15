# Дополнительное задание 2

Это код под чистую ВМ. В нашем случае VM поднята в Proxmox, а Terraform управляет Docker на ней через SSH Docker context.

Идея такая:

1. Создать ВМ в Proxmox.
2. Поставить на нее Docker.
3. Убедиться, что SSH работает.
4. Скопировать `personal.auto.tfvars.example` в `personal.auto.tfvars`.
5. Вписать туда SSH-адрес Docker host.
6. Запустить:

```bash
terraform init
terraform apply
```

Проверка env внутри контейнера:

```bash
ssh ubuntu@VM_PUBLIC_IP
docker exec -it ИМЯ_КОНТЕЙНЕРА env | grep MYSQL
```

На текущем ПК порт `3306` уже занят MySQL/MariaDB.
Поэтому именно тут код не применял, чтобы не сломать живую базу.

Фактически использовано:

```text
Proxmox: 192.168.1.61:8006
VMID:    103
VM name: netology-terraform-docker
VM IP:   192.168.3.201
User:    ubuntu
```

В `personal.auto.tfvars`:

```hcl
docker_host = "ssh://ubuntu@192.168.3.201:22"
```

При первом запуске `mysql:8` упал из-за CPU:

```text
Fatal glibc error: CPU does not support x86-64-v2
```

На Proxmox для VM поменял CPU на `host`, после этого контейнер стартовал нормально.
