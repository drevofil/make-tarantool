# Make-based Ansible Tarantool Enterprise Deployment Tool

Этот проект предоставляет Makefile для удобного развертывания Tarantool Enterprise с использованием Ansible Tarantool Enterprise в Docker-контейнере.

## Предварительные требования

1. Docker установленный и запущенный
2. SSH-ключ для доступа к целевым серверам
3. Файл инвентаря Ansible (в формате YAML)
4. Архив с продуктом Tarantool Enterprise

## Быстрый старт

1. Создать файл окружения:
```bash
make env-template
mv .env.example .env.dev
```

2. Отредактировать `.env.dev` под ваше окружение

3. Запустить подготовку окружения:

```bash
sudo make env_prepare ENV=dev
```

4. Развернуть Tarantool DB:
```bash
sudo make deploy-tdb ENV=dev
```

## Основные команды

### Управление окружениями

-  Список доступных окружений

```bash
make environments
make envs
```

- Создать шаблон файла окружения

```bash
make env-template
```

- Показать текущие переменные

```bash
make variables ENV=dev
make vars ENV=dev
```

### Подготовка и развертывание

- Подготовка серверов (требует root)

```bash
sudo make env_prepare ENV=prod
```

- Установка Tarantool DB

```bash
sudo make deploy-tdb ENV=staging
```

- Установка Tarantool Cluster Manager

```bash
sudo make deploy-tcm ENV=tcm-staging
```

- Удаление Tarantool DB

```bash
sudo make uninstall-tarantool ENV=dev
```

- Удаление Tarantool Cluster Manager

```bash
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

- Проверить наличие необходимых файлов

```bash
make check-env ENV=dev
```

- Показать справку по всем командам

```bash
make help
```

- Сгенерировать конфигурацию с эндпоинтами метрик для Prometheus. Конфиг появится в текущем каталоге с именем prometheus-tarantool-$ENV.yml

```bash
sudo make gen-prometheus ENV=dev
```

- Получить эндпоинты для каждого инстанта Tarantool. Список появится в текущем каталоге с именем endpoints-$ENV.txt

```bash
sudo make get-endpoints ENV=dev
```

### Мониторинг

- Поднять на локальном хосте docker compose проект для мониторинга (требует наличие docker compose)

- Заполнить файл monitoring/prometheus.yml (например, внести конфиг из ранее созданного prometheus-tarantool-$ENV.yml)

```bash
cp prometheus-tarantool-$ENV.yml monitoring/prometheus.yml
sudo make monitoring-install
```

- Удалить мониторинг

```bash
sudo make monitoring-remove
```

### Расширение кластера Tarantool 3.x

- Добавить инстансы и/или хосты в инвентарь

- Выполнить установку из нового инвентаря (т.к. плейбук идемпотентный, выполнится только конфигурация ETCD и установка новых экземпляров)

```bash
sudo make deploy-tdb ENV=dev
```

- Применить ранее созданные миграции (любым способом), для того чтобы rebalancer перераспределил бакеты с учётом новых storage.

### Обновление кластера Tarantool 3.x

- Требуется ATE версии 1.14+

- Подобрать параметры `tt_failover_status_retries`, `tt_failover_status_delay`, `tt_failover_status_timeout`, так как на дефолтных не всегда успевают переключиться мастера. Пример в extra_vars.json

- Опционально указать группу с инстансами storage `storage_group`

- Выполнить обновление

```bash
sudo make update-tarantool3 ENV=dev
```

### Генерация тестовых данных

1. [generator.sh](./examples/generator.sh) Скрипт для генерации тестовых данных

```
Использование: ./examples/generator.sh [ПАРАМЕТРЫ] <количество_записей>

Генерация тестовых данных для таблицы 'bands' в Tarantool.
Для работы необходимо добавить данную миграцию в TDB

---
local helpers = require('tt-migrations.helpers')
local space_bands = box.schema.space.create('bands', {
    if_not_exists = true,
    format = {
        { name = 'id', type = 'integer' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'band_name', type = 'string' },
        { name = 'year', type = 'integer' },
    },
})
space_bands:create_index('primary_key', { parts = {'id'}, if_not_exists = true})
space_bands:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})
helpers.register_sharding_key(space_bands.name, {'id'})
---

Параметры:
  -m, --mode MODE        Режим работы: 'stdout' (по умолчанию) или 'execute'
  -u, --user USER        Имя пользователя Tarantool (по умолчанию: admin)
  -p, --password PASS    Пароль пользователя (по умолчанию: admin_password)
  -h, --host HOST        Хост Tarantool роутера (по умолчанию: 192.168.111.29)
  -P, --port PORT        Порт Tarantool роутера (по умолчанию: 3310)
  -v, --verbose          Подробный вывод
  --help                 Показать эту справку

Примеры:
  ./examples/generator.sh 100                     # Сгенерировать 100 команд и вывести в stdout
  ./examples/generator.sh -m execute -v 500      # Выполнить вставку 500 записей с подробным выводом
  ./examples/generator.sh -u myuser -p mypass -h 10.0.0.1 -P 3301 50  # С указанием своих параметров

Примечания:
  - В режиме 'execute' для каждой записи создается отдельное подключение
  - Для работы модуля CRUD требуется соответствующая настройка ролей роутера
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
# LIMIT=storage-1-1
# LIMIT=storage-1-1
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
"tarantool_remote_backups_dir":"/app/backups/",
"tarantool_ansible_serial_executors": "4",
"tt_failover_status_retries": 10,
"tt_failover_status_delay": 10,
"tt_failover_status_timeout": 60,
"storage_group": "STORAGES"
}
```
### Дополнительные аргументы ansible
Указать дополнительные аргументы для команды ansible в переменной `EXTRA_VARS` при запуске команд
```bash
sudo make ENV=local deploy-tdb EXTRA_VARS="-e tarantool_remote_backups_dir=/mnt/backups -vvv"
```

### Дополнительные тома
Для добавления кастомных маунтов указать переменную `EXTRA_VOLUMES`:
```ini
EXTRA_VOLUMES=-v ./centos.yml:/ansible/playbooks/prepare/os/centos.yml:Z
```

### Резервное копирование

- Добавить следующие переменные в yaml инвентаря

```yaml
cartridge_etcd_host: 192.168.0.105
cartridge_etcd_port: 2379
```

- Добавить в/создать json файл с дополнительными переменными (путь к директории бекапов на хостах и количество параллельных процессов резервного копирования)

```json
{
  "tarantool_remote_backups_dir": "/app/backups/",
  "tarantool_ansible_serial_executors": "4"
}
```

- Создать резервные копии инстансов
```bash
# Для указания конкретных инстансов для резервного копирования, задать переменную окружения, например LIMIT=storage-1-1
sudo make backup-tarantool ENV=dev
```

- Восстановиться из последних резервных копий
```bash
# Для указания конкретных инстансов для восстановления, задать переменную окружения, например LIMIT=storage-1-1
sudo make restore-tarantool ENV=dev
```

- Для расширенных сценариев восстановления передать другие переменные для восстановления согласно [документации по ATE](https://www.tarantool.io/en/devops/latest/docker-scenarios-common/#ate-admin-auto-restore)

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