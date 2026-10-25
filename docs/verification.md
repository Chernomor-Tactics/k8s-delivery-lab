# Проверки завершённого проекта

Проверено 25 октября 2026 года на macOS arm64, Docker Desktop, minikube и отдельной
Ubuntu 24.04 VM. Это учебные проверки, не проверка production-нагрузки или HA.

| Проверка | Результат |
|---|---|
| pytest | 8 passed |
| Bash-синтаксис deploy/smoke/CD example | Без ошибок |
| YAML и Ansible syntax-check | Без ошибок |
| Сборка kustomize локального варианта | Namespace task-lab-local, без imagePullSecrets |
| Compose на отдельном порту | Healthy, smoke test успешен |
| Newman против Compose | 7 запросов, 7 assertions, 0 ошибок |
| Локальный Kubernetes без GHCR Secret | Rollout завершён, smoke test успешен |
| Newman против локального Kubernetes | 7 запросов, 7 assertions, 0 ошибок |
| Ansible source mode без GHCR_TOKEN | Развёртывание и health/version успешны |
| Повторный Ansible source mode | ok=12, changed=0, unreachable=0, failed=0 |
| Newman против Ansible VM | 7 запросов, 7 assertions, 0 ошибок |

Для проверки использовались отдельные Compose-проекты, namespace task-lab-local
и каталог /opt/task-api-public-check на VM. Действующее registry-приложение и
namespace task-lab не переключались. Первый source-build сообщил о недоступном
Buildx/Bake и успешно выполнил сборку через доступный Compose builder; второй
запуск не пересобирал образ.

Авторский CI с публикацией GHCR и ручной CD были успешно выполнены ранее в ходе
работы над стендом. Проверки текущего коммита доступны во вкладке Actions.
Деплой новой версии из текущего коммита через приватный CD в рамках оформления
README повторно не запускался. Сценарии отказа и автоматический откат не заявлены
как проверенные. Для проверки на другой машине следуй README: копирование
авторского inventory, kubeconfig или секретов не требуется.
