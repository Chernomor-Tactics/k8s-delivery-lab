# Диагностика

## Docker и minikube

Начни с `docker info`, затем `minikube status -p minikube`. Сохранённый контекст
kubectl не гарантирует, что кластер запущен. После смены порта:

```bash
minikube update-context -p minikube
kubectl --context=minikube get --raw=/readyz --request-timeout=10s
```

Если статус зависает, проверь `docker ps --filter name=minikube`. При работающем
Docker команды внутри minikube позволяют отделить проблемы runtime от API:

```bash
docker exec minikube systemctl is-active kubelet docker
docker exec minikube journalctl -u kubelet -n 50 --no-pager
docker exec minikube crictl ps -a --name kube-apiserver
docker exec minikube df -h /
docker stats --no-stream
```

В процессе работы стенда наблюдались OOM и недоступность внутреннего Docker.
Это не доказательство проблемы роутера. Учитывай суммарную память Docker,
Multipass VM и старых сервисов. Не запускай бесконтрольно старые стенды.
После обычного перезапуска контейнера может потребоваться `minikube start`.
Не начинай диагностику с удаления кластера или Factory reset.

## Приложение

Для локального варианта namespace task-lab-local; для CD — task-lab.

```bash
kubectl --context=minikube -n task-lab-local get pods,deployments,services
kubectl --context=minikube -n task-lab-local describe pods
kubectl --context=minikube -n task-lab-local logs deployment/task-api --tail=50
```

- ImagePullBackOff: проверь адрес образа, права registry и imagePullSecret.
- ErrImageNeverPull в локальном варианте: образ не загружен; повтори deploy.sh.
- CrashLoopBackOff: смотри logs, при необходимости `logs --previous` для Pod.
- Pod Running, но 0/1: describe pod покажет ошибки readiness/startup.
- Port-forward завершился после обновления Pod: запусти заново.
- Bind error: порт занят; `lsof -nP -iTCP:8002 -sTCP:LISTEN` на Mac.

При откате `kubectl rollout undo deployment/task-api -n task-lab` возвращается
шаблон Pod. ConfigMap автоматически не откатывается. CD задаёт APP_VERSION через
явный env в шаблоне Pod, поэтому эта версия откатывается вместе с образом.
Само наличие этой инструкции не означает, что отказ/откат был проверен.

## GitHub Actions

`Unexpected value publish` и повторное определение steps — обычно отступы YAML:
test и publish должны быть разными job внутри jobs. При ошибке разбора job не
создаётся и логи могут отсутствовать. Исправление требует нового коммита.

Если CD ждёт runner: проверь приватный репозиторий, Online/Idle и совпадение меток.
ARM64 и X64 — разные метки. В проверенном запуске использовался x64 runner на Mac;
для нового runner предпочтительна нативная архитектура, согласованная с workflow.
Не добавляй ложную метку архитектуры, чтобы обойти выбор runner.

## Ansible

- UNREACHABLE: IP, SSH-ключ, known_hosts, доступность VM.
- Permission denied / sudo: проверь become и права пользователя.
- Скрытая ошибка login: проверь GHCR_TOKEN/read:packages; не отключай no_log с токеном.
- changed>0: смотри названия изменённых задач; первый запуск должен менять состояние.
- Последующие запуски: registry mode использует pull missing, а не обновление latest.

## Остановить и продолжить

Перед выключением сохрани файлы. Дождись завершения CI/CD, останови ./run.sh и
port-forward через Ctrl+C. Compose: `docker compose stop`; minikube:
`minikube stop -p minikube`; отдельная VM: `multipass stop ansible-lab`.
Данные задач в памяти исчезнут, файлы проекта и образы сохранятся.

После включения: Docker Desktop, `minikube start -p minikube`, update-context,
проверка Pod. Для Ansible VM: `multipass start ansible-lab`. Runner и port-forward
нужно запустить снова, если они нужны. Multipass master/worker — другой кластер,
не тот minikube, который используется в этом проекте.
