# Make-based Ansible Tarantool Enterprise Deployment Tool

Этот проект предоставляет Makefile для удобного развертывания Tarantool Enterprise с использованием Ansible Tarantool Enterprise в Docker-контейнере.

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

## Установка ETCD кластера

- Подготовить инвентарь etcd и сконфигурировать установку согласно [документации роли](./custom_steps/etcd-role/README.md) 

```bash
# Установка etcd
sudo make install-etcd ENV=etcd-dev

# Удаление etcd
sudo make uninstall-etcd ENV=etcd-dev
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
# Deployment configuration for example environment
IMAGE_NAME=ansible-tarantool-enterprise
DEPLOY_TOOL_VERSION_TAG=1.10.2
SUPER_USER_NAME=admin
PACKAGE_NAME=./tarantooldb-2.2.1.linux.x86_64.tar.gz
PATH_TO_PRIVATE_KEY=/home/.ssh/id_rsa
PATH_TO_INVENTORY=/opt/inventories/hosts.yml
PATH_TO_PACKAGE=/opt/packages/${PACKAGE_NAME}

# Optional extra parameters
# VAULT_PASSWORD_FILE=/path/to/vault_password_file
# BACKUP_LIMIT=storage-1-1
# RESTORE_LIMIT=storage-1-1
# EXTRA_VOLUMES=-v ./centos.yml:/ansible/playbooks/prepare/os/centos.yml:Z
# EXTRA_VARS_FILE=/path/to/extra_vars.json
# Example extra_vars.json content
# {"custom_option": "value"}

# For encrypting strings with ansible-vault:
# sudo make encrypt-string ENV=env_name STRING_TO_ENCRYPT='your string'
```

## Использование Ansible Vault

Для работы с зашифрованными переменными через Ansible Vault:

1. Создайте файл с паролем для vault:
```bash
echo "your_vault_password" > ~/.vault_password
chmod 600 ~/.vault_password
```

2. Добавьте путь к файлу с паролем в .env файл окружения:
```ini
VAULT_PASSWORD_FILE=/home/user/.vault_password
```

3. При использовании команд Makefile vault-пароль будет автоматически подключаться к контейнеру и использоваться Ansible для расшифровки переменных.


4. Зашифровать строку (либо несколько строк разделённых пробелом)

```shell
sudo make encrypt-string ENV=test STRING_TO_ENCRYPT='super-password'
```

5. Полученный вывод добавить в значение переменной в инвентаре

```yaml
all:
  vars:
    replicator_password: !vault |
              $ANSIBLE_VAULT;1.1;AES256
              32363866663862313430363463336437656638376333646437663335663862623135333365336262
              ...
              ...
              ...
```

6. Указать эту переменную, например в параметре tarantool_config_global

```yaml
    tarantool_config_global:
      credentials:
        users:
          replicator:
            password: "{{replicator_password}}"
```

## Пользовательские параметры

### Дополнительные переменные
Создать JSON-файл с дополнительными переменными и укажите его в `EXTRA_VARS_FILE`:
```json
{
  "custom_option": "value"
}
```
### Дополнительные аргументы ansible
Указать дополнительные аргументы ansible в переменной `EXTRA_VARS` при запуске команд
```bash
sudo make ENV=local deploy-tdb EXTRA_VARS="-e tarantool_remote_backups_dir=/mnt/backups"
```

### Дополнительные тома
Для добавления кастомных маунтов указать переменную `EXTRA_VOLUMES`:
```ini
EXTRA_VOLUMES=-v ./centos.yml:/ansible/playbooks/prepare/os/centos.yml:Z
```

### Резервное копирование

#### Добавить следующие переменные в yaml инвентаря

```yaml
cartridge_etcd_host: 192.168.0.105
cartridge_etcd_port: 2379
```

#### Добавить в/создать json файл с дополнительными переменными (путь к директории бекапов на хостах и количество параллельных процессов резервного копирования)

```json
{
  "tarantool_remote_backups_dir": "/app/backups/",
  "tarantool_ansible_serial_executors": "4"
}
```

#### Создать резервные копии инстансов
```bash
# Для указания конкретных инстансов для резервного копирования, задать переменную в env файле окружения, например BACKUP_LIMIT=storage-1-1
sudo make backup-tarantool ENV=dev
```

#### Восстановиться из последних резервных копий
```bash
# Для указания конкретных инстансов для восстановления, задать переменную в env файле окружения, например RESTORE_LIMIT=storage-1-1
sudo make restore-tarantool ENV=dev
```

#### Для расширенных сценариев восстановления передать другие переменные для восстановления согласно [документации по ATE](https://www.tarantool.io/en/devops/latest/docker-scenarios-common/#ate-admin-auto-restore)

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
   - Файла пароля vault (если указан)

3. **Безопасность**:
   - Файлы монтируются в контейнер в режиме read-only
   - Поддержка Ansible Vault для работы с зашифрованными переменными

## Советы

- Все команды можно выполнять с `ENV=<name>` для выбора окружения
- Используйте `make help` для просмотра всех доступных команд
- Для дополнительной безопасности используйте Ansible Vault для хранения чувствительных данных