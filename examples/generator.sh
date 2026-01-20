#!/bin/bash
# Генерация тестовых данных для Tarantool

# Конфигурация по умолчанию
DEFAULT_USER="admin"
DEFAULT_PASSWORD="admin_password"
DEFAULT_HOST="192.168.111.29"
DEFAULT_PORT="3310"
MODE="stdout"
VERBOSE=false

# Генерация разнообразных названий групп
generate_band_name() {
    local prefixes=("The" "New" "Old" "Big" "Little" "Red" "Blue" "Black" "White" "Wild" "Crazy" "Mad")
    local adjectives=("Dark" "Electric" "Shadow" "Crimson" "Silver" "Urban" "Neon" "Cosmic" "Mystic" "Velvet" "Iron" "Jade" "Golden" "Frozen" "Burning" "Atomic" "Digital" "Virtual")
    local nouns=("Roses" "Dreams" "Wolves" "Eagles" "Phoenix" "Storm" "Ocean" "Machine" "Circuit" "Knights" "Dragons" "Code" "Data" "Wave" "Pulse" "Signal" "Frequency")
    local suffixes=("Band" "Project" "Collective" "Experience" "Society" "Inc." "Ltd." "Corp.")
    
    local pattern=$((RANDOM % 4))
    
    case $pattern in
        0)
            echo "${adjectives[$RANDOM % ${#adjectives[@]}]} ${nouns[$RANDOM % ${#nouns[@]}]}"
            ;;
        1)
            echo "The ${adjectives[$RANDOM % ${#adjectives[@]}]} ${nouns[$RANDOM % ${#nouns[@]}]}"
            ;;
        2)
            echo "${adjectives[$RANDOM % ${#adjectives[@]}]} ${nouns[$RANDOM % ${#nouns[@]}]} ${suffixes[$RANDOM % ${#suffixes[@]}]}"
            ;;
        3)
            echo "${prefixes[$RANDOM % ${#prefixes[@]}]} ${nouns[$RANDOM % ${#nouns[@]}]}"
            ;;
    esac
}

# Генерация года основания группы
generate_year() {
    # 80% групп основаны между 1960-2000, 20% - после 2000
    if [ $((RANDOM % 10)) -lt 8 ]; then
        echo $((1960 + RANDOM % 41))  # 1960-2000
    else
        echo $((2001 + RANDOM % 23))  # 2001-2023
    fi
}

check_tt_availability() {
    if ! command -v tt &> /dev/null; then
        echo "ОШИБКА: Утилита 'tt' не найдена в PATH" >&2
        echo "Установите Tarantool CLI: https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/installation/" >&2
        return 1
    fi
    return 0
}

check_tarantool_connection() {
    local user="${1:-$DEFAULT_USER}"
    local password="${2:-$DEFAULT_PASSWORD}"
    local host="${3:-$DEFAULT_HOST}"
    local port="${4:-$DEFAULT_PORT}"
    
    [ "$VERBOSE" = true ] && echo "Проверка подключения к Tarantool ($user@$host:$port)..."
    
    if ! timeout 5 tt connect "$user:$password@$host:$port" <<< 'return "Connection test successful"' &>/dev/null; then
        echo "ОШИБКА: Не удалось подключиться к Tarantool" >&2
        echo "Проверьте:" >&2
        echo "  1. Доступность сервера $host:$port" >&2
        echo "  2. Корректность логина/пароля" >&2
        return 1
    fi
    
    [ "$VERBOSE" = true ] && echo "✓ Подключение к Tarantool успешно"
    return 0
}

generate_data() {
    local count=$1
    local user="${2:-$DEFAULT_USER}"
    local password="${3:-$DEFAULT_PASSWORD}"
    local host="${4:-$DEFAULT_HOST}"
    local port="${5:-$DEFAULT_PORT}"
    
    local total_errors=0
    
    for ((i=1; i<=count; i++)); do
        band_name=$(generate_band_name)
        year=$(generate_year)
        band_name=$(echo "$band_name" | sed "s/'/''/g")
        
        if [ "$MODE" = "stdout" ]; then
            echo "crud.insert_object('bands', {id = $i, band_name = '$band_name', year = $year})"
        elif [ "$MODE" = "execute" ]; then
            if [ "$VERBOSE" = true ]; then
                echo -ne "  Вставка записи $i/$count: $band_name ($year)\r"
            fi
            
            tt connect "$user:$password@$host:$port" <<EOF
crud.insert_object('bands', {id = $i, band_name = '$band_name', year = $year})
EOF
            if [ $? -ne 0 ]; then
                echo "  Ошибка при вставке записи $i: $band_name ($year)" >&2
                ((total_errors++))
            fi
        fi
    done
    
    if [ "$MODE" = "execute" ]; then
        echo -e "\nГотово! Всего записей: $count, ошибок: $total_errors"
    fi
}

# Вывод справки
show_usage() {
    cat << EOF
Использование: $0 [ПАРАМЕТРЫ] <количество_записей>

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
  -u, --user USER        Имя пользователя Tarantool (по умолчанию: $DEFAULT_USER)
  -p, --password PASS    Пароль пользователя (по умолчанию: $DEFAULT_PASSWORD)
  -h, --host HOST        Хост Tarantool роутера (по умолчанию: $DEFAULT_HOST)
  -P, --port PORT        Порт Tarantool роутера (по умолчанию: $DEFAULT_PORT)
  -v, --verbose          Подробный вывод
  --help                 Показать эту справку

Примеры:
  $0 100                     # Сгенерировать 100 команд и вывести в stdout
  $0 -m execute -v 500      # Выполнить вставку 500 записей с подробным выводом
  $0 -u myuser -p mypass -h 10.0.0.1 -P 3301 50  # С указанием своих параметров

Примечания:
  - В режиме 'execute' для каждой записи создается отдельное подключение
  - Для работы модуля CRUD требуется соответствующая настройка ролей роутера

EOF
}

# Обработка аргументов командной строки
parse_arguments() {
    local count_provided=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                MODE="$2"
                if [[ ! "$MODE" =~ ^(stdout|execute)$ ]]; then
                    echo "ОШИБКА: Неверный режим '$MODE'. Допустимы: stdout, execute" >&2
                    exit 1
                fi
                shift 2
                ;;
            -u|--user)
                DEFAULT_USER="$2"
                shift 2
                ;;
            -p|--password)
                DEFAULT_PASSWORD="$2"
                shift 2
                ;;
            -h|--host)
                DEFAULT_HOST="$2"
                shift 2
                ;;
            -P|--port)
                DEFAULT_PORT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            -*)
                echo "ОШИБКА: Неизвестный параметр: $1" >&2
                show_usage
                exit 1
                ;;
            *)
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    RECORD_COUNT="$1"
                    count_provided=true
                    shift
                else
                    echo "ОШИБКА: Некорректное количество записей: $1" >&2
                    exit 1
                fi
                ;;
        esac
    done
    
    if [ "$count_provided" != true ]; then
        echo "ОШИБКА: Не указано количество записей" >&2
        show_usage
        exit 1
    fi
}

# Основная функция
main() {
    parse_arguments "$@"
    
    [ "$VERBOSE" = true ] && echo "Режим работы: $MODE"
    [ "$VERBOSE" = true ] && echo "Количество записей: $RECORD_COUNT"
    [ "$VERBOSE" = true ] && [ "$MODE" = "execute" ] && echo "Используется отдельное подключение для каждой записи"
    
    # В режиме execute проверяем доступность tt
    if [ "$MODE" = "execute" ]; then
        if ! check_tt_availability; then
            exit 1
        fi
        
        # Проверяем подключение к Tarantool
        if ! check_tarantool_connection "$DEFAULT_USER" "$DEFAULT_PASSWORD" "$DEFAULT_HOST" "$DEFAULT_PORT"; then
            exit 1
        fi
    fi
    
    # Генерация данных
    generate_data "$RECORD_COUNT" "$DEFAULT_USER" "$DEFAULT_PASSWORD" "$DEFAULT_HOST" "$DEFAULT_PORT"
}

# Запуск
main "$@"