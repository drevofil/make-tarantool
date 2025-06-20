# Ansible-based Tarantool Enterprise Deployment Tool

Этот проект предоставляет Makefile для удобного развертывания Tarantool Enterprise с использованием Ansible Tarantool Enteprise в Docker-контейнере.

## Предварительные требования

1. Docker установленный и запущенный
2. SSH-ключ для доступа к целевым серверам
3. Файл инвентаризации Ansible (в формате YAML)
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
make vars
```

### Подготовка и развертывание
```bash
# Подготовка серверов (требует root)
sudo make env_prepare ENV=prod

# Установка Tarantool DB
sudo make deploy-tdb ENV=staging

# Удаление Tarantool DB
sudo make uninstall ENV=dev
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

## Пример рабочего процесса

1. Создаем окружение для разработки:
```bash
make env-template
cp .env.example .env.dev
nano .env.dev  # Редактируем параметры
```

2. Проверяем конфигурацию:
```bash
make check-env ENV=dev
make variables ENV=dev
```

3. Подготавливаем серверы:
```bash
sudo make env_prepare ENV=dev
```

4. Разворачиваем приложение Tarantool DB:
```bash
sudo make deploy-tdb ENV=dev
```

5. При необходимости удаляем:
```bash
sudo make uninstall ENV=dev
```

## Советы

- Все команды можно выполнять с `ENV=<name>` для выбора окружения
- Используйте `make help` для просмотра всех доступных команд