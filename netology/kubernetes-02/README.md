# Kubernetes. Pod и Service

Практику выполнил в локальном MicroK8s. Для обоих Pod использовал образ `gcr.io/kubernetes-e2e-test-images/echoserver:2.2`.

## 1. Pod hello-world

Манифест: [hello-world.yaml](hello-world.yaml).

```bash
kubectl apply -f hello-world.yaml
kubectl wait --for=condition=Ready pod/hello-world --timeout=180s
kubectl port-forward pod/hello-world 18081:8080 --address=127.0.0.1
```

В другом терминале:

```bash
curl http://127.0.0.1:18081/
```

В ответе получил:

```text
Hostname: hello-world

Server values:
    server_version=nginx: 1.12.2 - lua: 10010

Request Information:
    client_address=127.0.0.1
    method=GET
    real path=/
```

## 2. Pod netology-web и Service netology-svc

Манифесты: [netology-web.yaml](netology-web.yaml), [netology-svc.yaml](netology-svc.yaml).

Pod имеет метку `app: netology-web`. Service выбирает его по этой метке и направляет запросы с порта `80` на порт контейнера `8080`.

```bash
kubectl apply -f netology-web.yaml -f netology-svc.yaml
kubectl wait --for=condition=Ready pod/netology-web --timeout=180s
kubectl port-forward service/netology-svc 18082:80 --address=127.0.0.1
```

В другом терминале:

```bash
curl http://127.0.0.1:18082/
```

В ответе получил:

```text
Hostname: netology-web

Server values:
    server_version=nginx: 1.12.2 - lua: 10010

Request Information:
    client_address=127.0.0.1
    method=GET
    real path=/
```

## Проверка

Вывод `kubectl get pods`:

```text
NAME           READY   STATUS    RESTARTS   AGE
hello-world    1/1     Running   0          28s
netology-web   1/1     Running   0          28s
```

Вывод `kubectl get svc netology-svc`:

```text
NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
netology-svc   ClusterIP   10.152.183.45   <none>        80/TCP    28s
```

EndpointSlice сервиса содержит адрес Pod `10.1.73.9` и порт `8080`. Оба HTTP-запроса завершились с кодом 200. После проверки port-forward остановлен.

Решение для самостоятельной работы оформлено кратко: вместо скриншотов приведён текстовый вывод команд и фрагменты реальных ответов.
