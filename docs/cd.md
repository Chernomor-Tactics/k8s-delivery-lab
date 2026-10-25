# CD в отдельном приватном репозитории

Публичный репозиторий содержит всё для самостоятельного запуска. Приватный
репозиторий нужен только для авторского runner на Mac и его локального minikube.
CI выполняется на временных GitHub-hosted runner, CD — на self-hosted runner.

Пример: [cd-workflow.example.yml](cd-workflow.example.yml) и
[deploy-release.example.sh](deploy-release.example.sh). Они хранятся в docs,
поэтому не запускаются как workflow публичного репозитория.

Для собственного стенда:

1. Создай приватный репозиторий с веткой main и зарегистрируй там runner.
2. Замени Chernomor-Tactics/k8s-delivery-lab на свой публичный репозиторий в примере.
3. Скопируй workflow в `.github/workflows/cd.yml`, скрипт в `scripts/deploy.sh`.
4. Согласуй runs-on с реальными метками runner; добавь k8s-local.
5. Создай task-lab, ConfigMap, Deployment и Service по основным k8s-манифестам;
   укажи существующий образ и настрой Secret ghcr-pull в том же namespace.
6. Запусти workflow_dispatch на main, укажи полный SHA успешного CI develop.

У registry Secret должен быть действующий доступ к пакету. Он не хранится в Git.
Инструкция Kubernetes: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/

Пример CD проверяет наличие успешного CI по коммиту/ветке, применяет новый образ
и явный APP_VERSION одним patch Deployment, ждёт rollout, открывает временный
port-forward на 18002, проверяет версию и выполняет Newman из выбранного коммита.
concurrency исключает одновременные деплои, trap закрывает проброс порта.

Текущий скрипт работает с существующим task-lab. Автоматического отката и
первоначального развёртывания инфраструктуры нет. Публикация по SHA повторно
собирает образ из того же исходного коммита, а не передаёт проверенный бинарный
артефакт между job. Python-зависимости пока не зафиксированы lock-файлом.

GitHub рекомендует подключать self-hosted runners к приватным репозиториям:
https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners
