# Документация по Ansible роли для установки и настройки etcd

## Обзор

Роль устанавливает и настраивает etcd на целевых узлах. Поддерживает установку из архива (локального или удаленного) или из пакетов, настройку TLS (автоматическую или с предоставленными сертификатами) и кластерную конфигурацию.

## Переменные роли

### Основные настройки

- `etcd_install_method` (по умолчанию: `archive`): Способ установки. Допустимые значения: `archive` (установка из архива) или `package` (установка из пакета).
- `etcd_install_archive` (по умолчанию: `remote`): Если установка из архива, то откуда: `remote` (скачивание из интернета) или `local` (использование локального архива). Зависит от `etcd_install_method: archive`.
- `etcd_version` (по умолчанию: `"3.5.0"`): Версия etcd для установки.
- `etcd_user` (по умолчанию: `etcd`): Пользователь, от которого запускается etcd.
- `etcd_group` (по умолчанию: `etcd`): Группа пользователя etcd.
- `etcd_data_dir` (по умолчанию: `/var/lib/etcd`): Директория для данных etcd.

### Настройки архива (только для `etcd_install_method: archive`)

- `etcd_archive_local_path` (по умолчанию: `""`): Локальный путь к архиву, который необходимо положить в директорию `etcd-role/files` и передать имя файла в переменную (для `etcd_install_archive: local`). Пример: `"etcd-v3.6.4-linux-amd64.tar.gz"`.
- `etcd_archive_remote_url` (по умолчанию: `"https://github.com/etcd-io/etcd/releases/download/v{{ etcd_version }}/etcd-v{{ etcd_version }}-linux-amd64.tar.gz"`): URL для скачивания архива etcd (для `etcd_install_archive: remote`).
- `etcd_archive_checksum` (по умолчанию: `"sha256:https://github.com/etcd-io/etcd/releases/download/v{{ etcd_version }}/SHA256SUMS"`): Контрольная сумма архива. Может быть указана как прямая сумма или URL до файла с суммами.

### Настройки пакета (только для `etcd_install_method: package`)

- `etcd_package_name` (по умолчанию: `"etcd"`): Имя пакета etcd.
- `etcd_repository_enable` (по умолчанию: `false`): Включить внешний репозиторий для установки etcd.
- `etcd_repository_apt_url` (по умолчанию: `"deb https://example.com/etcd/deb {{ ansible_distribution_release }} main"`): URL репозитория для Debian/Ubuntu.
- `etcd_repository_yum_url` (по умолчанию: `"https://example.com/etcd/rpm/"`): URL репозитория для RedHat/CentOS.
- `etcd_repository_yum_gpgcheck` (по умолчанию: `no`): Проверять ли GPG подпись репозитория (для RedHat/CentOS).
- `etcd_repository_yum_gpgkey` (по умолчанию: `"https://example.com/etcd/gpg"`): Ключ для проверки GPG (для RedHat/CentOS).

### Настройки портов

- `etcd_client_port` (по умолчанию: `2379`): Порт для клиентских подключений.
- `etcd_peer_port` (по умолчанию: `2380`): Порт для пиринговых подключений между узлами etcd.

### Конфигурация etcd

- `etcd_name` (по умолчанию: `"{{ inventory_hostname }}"`): Имя узла etcd.
- `etcd_listen_peer_host` (по умолчанию: `"{{ ansible_host }}"`): IP адрес или хостнейм для прослушивания пиров.
- `etcd_listen_client_host` (по умолчанию: `"{{ ansible_host }}"`): IP адрес или хостнейм для прослушивания клиентов.
- `etcd_advertise_client_host` (по умолчанию: `"{{ ansible_host }}"`): IP адрес или хостнейм, который объявляется клиентам.
- `etcd_advertise_peer_host` (по умолчанию: `"{{ ansible_host }}"`): IP адрес или хостнейм, который объявляется пирам.
- `etcd_initial_cluster` (по умолчанию: `""`): Строка initial cluster. Если не задана, генерируется автоматически на основе инвентаря.
- `etcd_initial_cluster_state` (по умолчанию: `new`): Состояние кластера: `new` или `existing`.
- `etcd_initial_cluster_token` (по умолчанию: `etcd-cluster`): Токен кластера.
- `etcd_extra_config` (по умолчанию: `{}`): Дополнительные параметры конфигурации etcd в виде словаря. Они будут добавлены в конфигурационный файл.

### Настройки TLS

- `etcd_tls_enabled` (по умолчанию: `true`): Включить ли TLS.
- `etcd_tls_mode` (по умолчанию: `auto`): Режим TLS: `auto` (автогенерация сертификатов etcd) или `provided` (использование предоставленных сертификатов. Сертфиикаты нужно положить в директорию etcd-role/files/ectd-ssl).
- `etcd_tls_controller_certs_dir` (по умолчанию: `"etcd-role/files/etcd-ssl"`): Путь на контроллере, где хранятся сертификаты (для режима `provided`).
- `etcd_tls_ca_cert` (по умолчанию: `/etc/etcd/ssl/ca.pem`): Путь на узле до CA сертификата.
- `etcd_tls_cert` (по умолчанию: `/etc/etcd/ssl/server.pem`): Путь на узле до сертификата сервера.
- `etcd_tls_key` (по умолчанию: `/etc/etcd/ssl/server-key.pem`): Путь на узле до приватного ключа сервера.
- `etcd_auto_tls` (по умолчанию: `true`): Использовать автоматическую генерацию TLS для клиентских подключений (влияет только при `etcd_tls_mode: auto`).
- `etcd_peer_auto_tls` (по умолчанию: `true`): Использовать автоматическую генерацию TLS для пиров (влияет только при `etcd_tls_mode: auto`).

### Удаление

- `etcd_uninstall` (по умолчанию: `false`): Если установлено в `true`, роль удалит etcd с узла.

## Пример инвентаря

```yaml
all:
  children:
    etcd_cluster:
      hosts:
        etcd1:
          ansible_host: 192.168.0.105
          etcd_name: etcd1
        etcd2:
          ansible_host: 192.168.0.106
          etcd_name: etcd2
        etcd3:
          ansible_host: 192.168.0.107
          etcd_name: etcd3
  vars:
    ansible_user: admin
    etcd_initial_cluster_state: new
    etcd_initial_cluster_token: etcd-cluster-1
    etcd_version: 3.6.4
    etcd_tls_enabled: no
    etcd_tls_mode: auto
    etcd_install_method: archive
    etcd_install_archive: local
    etcd_archive_local_path: "etcd-v{{etcd_version}}-linux-amd64.tar.gz"
    etcd_user: root
    etcd_group: root
    etcd_extra_config:
      election-timeout: 5000
      heartbeat-interval: 250
      max-snapshots: 5
```

### Установка из удаленного архива

```yaml
  vars:
    etcd_install_method: archive
    etcd_install_archive: remote
    etcd_version: "3.5.0"
```

### Установка из локального архива

Положите архив в директорию `files` на контроллере и укажите путь:

```yaml
  vars:
    etcd_version: "3.5.0"
    etcd_install_method: archive
    etcd_install_archive: local
    etcd_archive_local_path: "etcd-v{{etcd_version}}-linux-amd64.tar.gz"
```

### Установка из пакета

```yaml
  vars:
    etcd_install_method: package
    etcd_package_name: "etcd"
```

### Использование предоставленных сертификатов

Положите сертификаты в директорию `files/etcd-ssl/` на контроллере с именами: `ca.pem`, `server.pem`, `server-key.pem`.

```yaml
vars:
  etcd_tls_enabled: true
  etcd_tls_mode: provided
```

### Отключение TLS

```yaml
vars:
  etcd_tls_enabled: false
```

### Передача дополнительных параметров конфигурации

```yaml
vars:
  etcd_extra_config:
    election-timeout: 5000
    heartbeat-interval: 250
    max-snapshots: 5
```

### Удаление etcd

```yaml
vars:
  etcd_uninstall: true
```


## Примечания

- При использовании TLS в режиме `auto` etcd автоматически генерирует самоподписанные сертификаты. Это удобно для разработки и тестирования, но для production рекомендуется использовать режим `provided` с сертификатами от доверенного CA.