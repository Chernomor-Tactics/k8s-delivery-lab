# Что делает каждый этап

## Docker и локальный API

`docker build -t task-api:0.1.0 .` собирает образ. Точка задаёт build context,
`-t` присваивает имя/тег. Это не название образа, который нужно заранее скачать.
Базовый `python:3.14-slim` скачивается из публичного registry.

`Dockerfile` сначала устанавливает зависимости, затем копирует приложение,
чтобы изменения кода не сбрасывали кеш установки пакетов. `USER appuser`
переключает процесс на UID 10001. `EXPOSE` описывает порт, публикация выполняется
через `ports` в Compose. В контейнере Uvicorn слушает `0.0.0.0:8000`, на Mac
Compose ограничивает доступ адресом `127.0.0.1:8001`.

Локальный Uvicorn на 8000, Compose на 8001 и port-forward на 8002 — разные
экземпляры/способы доступа. Для Kubernetes локальный Uvicorn запускать не нужно.

## Kubernetes

Deployment поддерживает один Pod. ConfigMap задаёт конфигурацию; Secret
`ghcr-pull` используется только registry-сценарием. Service выбирает Pod по
`app: task-api`, его порт 80 направлен на порт контейнера 8000.

Startup probe даёт время запуска, readiness исключает неготовый Pod из endpoints,
liveness перезапускает контейнер при неуспешных проверках. Port-forward — туннель
к выбранному Pod; он не проверяет путь через ClusterIP и не является Ingress.

Локальная конфигурация `k8s-local` сохраняет проверки/ресурсы, но убирает зависимость
от Secret и запрещает скачивание образа: его заранее загружает minikube image load.
Скрипт вычисляет тег по исходникам, чтобы изменение кода создавало новую ревизию.

## Подготовка Ubuntu для Ansible

Пример для установленного Multipass (Mac). Достаточно отдельной VM, старые
master/worker менять не нужно. Проверь свободную память/диск перед созданием.

```bash
multipass launch 24.04 --name ansible-lab --cpus 2 --memory 2G --disk 10G
multipass info ansible-lab
ssh-keygen -t ed25519 -f ~/.ssh/ansible_lab -C ansible-lab
```

Не перезаписывай существующий ключ. Публичный `.pub` передаётся на VM, приватный
остаётся на Mac. Passphrase можно использовать с ssh-agent; учебный запуск также
проверялся с отдельным ключом без passphrase.

```bash
multipass transfer ~/.ssh/ansible_lab.pub ansible-lab:/tmp/ansible_lab.pub
multipass exec ansible-lab -- bash -c '
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  touch ~/.ssh/authorized_keys
  if ! grep -qxF "$(cat /tmp/ansible_lab.pub)" ~/.ssh/authorized_keys; then
    cat /tmp/ansible_lab.pub >> ~/.ssh/authorized_keys
  fi
  chmod 600 ~/.ssh/authorized_keys
'
```

Сверить отпечаток SSH-сервера можно командой:

```bash
multipass exec ansible-lab -- ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
ssh -i ~/.ssh/ansible_lab ubuntu@VM_IP
```

Затем скопируй example inventory и укажи адрес VM, как описано в README.
Ansible ping — проверка SSH и Python, а не ICMP. `become: true` использует sudo;
в стандартной Multipass VM ubuntu может выполнять sudo без пароля. На других
серверах настрой become или используй `--ask-become-pass`.

## Playbook

- apt: установленные пакеты; state present не требует постоянного обновления.
- systemd_service: Docker запущен и включён при загрузке.
- file: каталоги, владельцы и права.
- source mode: copy переносит четыре файла API/сборки; registry mode: docker_login
  сохраняет авторизацию у root. Никакие ключи приложения для Task API не нужны.
- template: Jinja2 генерирует `/opt/task-api/compose.yaml`.
- docker_compose_v2: контейнер запущен и healthy; в source mode сборка выполняется
  при изменении исходников/шаблона, в registry mode скачивается недостающий образ.
- uri/assert: API отвечает, его версия совпадает с выбранной.

Повторный запуск с changed=0 подтверждает отсутствие изменений в проверенном
состоянии. Это не универсальная гарантия: ручные изменения на VM, обновление
кеша apt и удалённый образ могут потребовать новых действий.

## Что рассказать на собеседовании

«Я сделал учебный стенд доставки API: Docker/Compose, проверки pytest и Postman,
GitHub Actions, GHCR и Kubernetes. CD по выбранному коммиту работает через runner
в приватном репозитории, проверяет CI и API после деплоя. Ansible подготавливает
отдельную Ubuntu VM и запускает Compose; повторный запуск проверен на отсутствие
изменений. У приложения одна реплика и память вместо БД, поэтому обновление
с простоем и потерей тестовых данных — известное ограничение».
