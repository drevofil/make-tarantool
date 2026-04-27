# Change Log
All notable changes to this project will be documented in this file.
 
The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).
 
## [Unreleased] - yyyy-mm-dd
 
Here we write upgrading notes for brands. It's a team effort to make them as
straightforward as possible.
 
### Added
 
### Changed
 
### Fixed

## [1.9.0] - 2026-04-27
 
### Added

- Добавлен таргет `get_tcm_password`. Команда получает сгенерированный начальный пароль админитратора Tarantool Cluster Manager из логов
- Добавлен таргет `set_bashrc`, который настраивает systemctl user scope и добавляет tt в $PATH пользователя tarantool
 
### Changed

- Изменён таргет `env_prepare`. Из него убран вызов плейбука `set-bashrc.yml`, теперь это отдельный target `set_bashrc` 
- Таргет `get_tcm_password` добавлен в шаг установки Tarantool Cluster Manager `deploy-tcm`
- Таргет `set_bashrc` добавлен в шаг устаноки Tarantool DB `deploy-tdb`
 
### Fixed
 
## [1.8.0] - 2026-01-20
  
Минимальная версия ATE - 1.14+

### Added

- Добавлен генератор данных ./examples/generator.sh
- Добавлена команда обновления Tarantool 3.x `update-tarantool3`
- Обновлён Grafana Dashboard
- Прочие уборки
 
### Changed
  
- Убрана поддержка переменных BACKUP_LIMIT, RESTORE_LIMIT. Вместо них используется переменная LIMIT
 
### Fixed
 
- Исправлена роль etcd, установка запускается одновременно на всех хостах
 
## [0.0.0-1.7.2] - 2025-07-11
 
### Added

- Тёмные времена, было добавлено всё

### Changed
 
### Fixed
 