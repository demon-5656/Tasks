# Kubernetes. Причины появления. Команда kubectl

## 1. Установка MicroK8s

Для самостоятельной практики использовал локальную виртуальную машину с Ubuntu 24.04: 2 vCPU и 4 ГБ RAM. Облачные ресурсы не использовал.

Установил MicroK8s и включил Dashboard:

```bash
sudo snap install microk8s --classic --channel=1.35/stable
sudo usermod -aG microk8s "$USER"
mkdir -p ~/.kube
chmod 700 ~/.kube
# После добавления в группу — новое подключение к VM.
microk8s status --wait-ready
microk8s enable dashboard
```

Результат проверки узла:

```text
NAME           STATUS   ROLES    AGE   VERSION
microk8s-lab   Ready    <none>   39m   v1.35.6
```

Dashboard запущен, все его компоненты готовы:

```text
NAME                                                    READY   STATUS    RESTARTS   AGE
kubernetes-dashboard-api-5cfbc8867b-2wbcx               1/1     Running   0          38m
kubernetes-dashboard-auth-775f74bf8b-2p5zx              1/1     Running   0          38m
kubernetes-dashboard-kong-78b7499b45-zr7kt              1/1     Running   0          38m
kubernetes-dashboard-metrics-scraper-594bbfb84b-bs9ck   1/1     Running   0          38m
kubernetes-dashboard-web-7f7574785f-f4vj2               1/1     Running   0          38m
```

Сертификат API сгенерирован MicroK8s и содержит адрес VM `10.0.2.15` и `127.0.0.1`. Для доступа с хоста используется локальный проброс `127.0.0.1:16443 → VM:16443`. Проверка сертификата включена; публичный IP для этой лаборатории не нужен.

## 2. Локальный kubectl и Dashboard

На хосте установил kubectl `v1.35.6`, проверил SHA256. Конфигурацию получил через `microk8s config`, сохранил в отдельный приватный kubeconfig и указал адрес API `https://127.0.0.1:16443`. Основной `~/.kube/config` не менял.

```bash
./kubectl --kubeconfig ./kubeconfig get nodes
./kubectl --kubeconfig ./kubeconfig -n kubernetes-dashboard \
  port-forward service/kubernetes-dashboard-kong-proxy 10443:443 \
  --address=127.0.0.1
```

Dashboard доступен на `https://127.0.0.1:10443` во время работы port-forward. Проверил получение страницы, вход по временному токену и авторизованный запрос списка узлов: HTTP 200, один узел.

В установленной версии Dashboard находится в namespace `kubernetes-dashboard`, а сервис называется `kubernetes-dashboard-kong-proxy`, поэтому старую команду из задания заменил на приведённую выше.

Ключ SSH, kubeconfig и токены в репозиторий не добавлял. Решение оформлено кратко для самостоятельной работы, без скриншотов.
