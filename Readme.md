# Make-based Ansible Tarantool Enterprise Deployment Tool

Этот проект предоставляет Makefile для удобного развертывания Tarantool Enterprise с использованием Ansible Tarantool Enteprise в Docker-контейнере.

## Предварительные требования

1. Docker установленный и запущенный
2. SSH-ключ для доступа к целевым серверам
3. Файл инвентаря Ansible (в формате YAML)
4. Архив с продуктом Tarantool Enterprise

## Быстрый старт

1. Создайте файл окружения:
```bash
make env-template
mv .env.example .env.dev
```

2. Отредактируйте `.env.dev` под ваше окружение

3. Запустите подготовку окружения:
```bash
sudo make env_prepare ENV=dev
```

4. Разверните Tarantool DB:
```bash
sudo make deploy-tdb ENV=dev
```

## Основные команды

### Управление окружениями
```bash
# Список доступных окружений
make environments
make envs

# Создать шаблон файла окружения
make env-template

# Показать текущие переменные
make variables ENV=dev
make vars ENV=dev
```

### Подготовка и развертывание
```bash
# Подготовка серверов (требует root)
sudo make env_prepare ENV=prod

# Установка Tarantool DB
sudo make deploy-tdb ENV=staging

# Установка Tarantool Cluster Manager
sudo make deploy-tcm ENV=tcm-staging

# Удаление Tarantool DB
sudo make uninstall-tarantool ENV=dev

# Удаление Tarantool Cluster Manager
sudo make uninstall-tcm ENV=tcm-staging
```

### Вспомогательные команды
```bash
# Проверить наличие необходимых файлов
make check-env ENV=dev

# Показать справку по всем командам
make help

# Сгенерировать конфигурацию с эндпоинтами метрик для Prometheus. Конфиг появится в текущем каталоге с именем prometheus-tarantool-$ENV.yml
sudo make gen-prometheus ENV=dev

# Получить эндпоинты для каждого инстанта Tarantool. Список появится в текущем каталоге с именем endpoints-$ENV.txt
sudo make get-endpoints ENV=dev

```

### Мониторинг
```bash
# Поднять на локальном хосте docker compose проект для мониторинга (требует наличие docker compose)
# Заполнить файл monitoring/prometheus.yml (например, внести конфиг из ранее созданного prometheus-tarantool-$ENV.yml)
cp prometheus-tarantool-$ENV.yml monitoring/prometheus.yml
sudo make monitoring-install

# Удалить мониторинг
sudo make monitoring-remove

```

## Структура файлов окружения

Файлы окружения должны называться `.env.<name>` (например, `.env.prod`). Пример содержимого:

```ini
IMAGE_NAME=ansible-tarantool-enterprise
DEPLOY_TOOL_VERSION_TAG=1.10.2
SUPER_USER_NAME=admin
PACKAGE_NAME=./tarantooldb-2.2.1.linux.x86_64.tar.gz
PATH_TO_PRIVATE_KEY=/home/.ssh/id_rsa
PATH_TO_INVENTORY=/opt/inventories/hosts.yml
PATH_TO_PACKAGE=/opt/packages/${PACKAGE_NAME}

# Optional extra parameters
# EXTRA_VOLUMES=-v ./centos.yml:/ansible/playbooks/prepare/os/centos.yml:Z
# EXTRA_VARS_FILE=/path/to/extra_vars.json
# Example extra_vars.json content
# {"custom_option": "value"}
```

## Пользовательские параметры

### Дополнительные переменные
Создайте JSON-файл с дополнительными переменными и укажите его в `EXTRA_VARS_FILE`:
```json
{
  "custom_option": "value"
}
```

### Дополнительные тома
Добавляйте кастомные тома через `EXTRA_VOLUMES`:
```ini
EXTRA_VOLUMES=-v ./centos.yml:/ansible/playbooks/prepare/os/centos.yml:Z
```

## Особенности работы

1. **Автоподгрузка переменных**:
   - При запуске Makefile автоматически загружается `.env.<ENV>`
   - Если файл не найден, используется значения по умолчанию

2. **Проверка зависимостей**:
   Команда `check-env` проверяет наличие:
   - Файла окружения
   - SSH-ключа
   - Файла инвентаризации
   - Архива с продуктом
   - Дополнительного файла переменных (если указан)

3. **Безопасность**:
   - Файлы монтируются в контейнер в режиме read-only

## Советы

- Все команды можно выполнять с `ENV=<name>` для выбора окружения
- Используйте `make help` для просмотра всех доступных команд