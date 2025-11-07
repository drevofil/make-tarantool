#!/bin/bash
LOCK_DIR="/opt/ate/"
LOCK_FILE="$LOCK_DIR/backup.lock"
LOCK_TIMEOUT=3600
SCRIPT_NAME="tarantool-backup"
BACKUP_TYPE="${1:-unknown}"
BACKUP_ENV="test"
METRICS_DIR="/var/lib/prometheus/node-exporter/"
METRICS_FILE="$METRICS_DIR/backup_${BACKUP_TYPE}.prom"

LOCK_ACQUIRED=0

log_to_syslog() {
    local priority="$1"
    local message="$2"
    logger -t "$SCRIPT_NAME" -p "user.$priority" "$message"
}

log_info() {
    local message="[$(hostname)] $1"
    log_to_syslog "info" "$message"
    if [ -t 1 ]; then
        echo "$(date): INFO: $message"
    fi
}

log_warning() {
    local message="[$(hostname)] $1"
    log_to_syslog "warning" "$message"
    if [ -t 1 ]; then
        echo "$(date): WARNING: $message" >&2
    fi
}

log_error() {
    local message="[$(hostname)] $1"
    log_to_syslog "err" "$message"
    if [ -t 1 ]; then
        echo "$(date): ERROR: $message" >&2
    fi
}

cleanup() {
    if [ $LOCK_ACQUIRED -eq 1 ]; then
        release_lock
    fi
}

update_metrics() {
    local status="$1"
    local duration="$2"
    local size="${3:-0}"
    mkdir -p "$METRICS_DIR"
    
    cat > "${METRICS_FILE}.$$" << EOF
# HELP backup_status Backup completion status (0=failed, 1=success, 2=skipped)
# TYPE backup_status gauge
backup_status{server="$(hostname)",type="${BACKUP_TYPE}"} ${status}
# HELP backup_duration_seconds Backup duration in seconds
# TYPE backup_duration_seconds gauge
backup_duration_seconds{server="$(hostname)",type="${BACKUP_TYPE}"} ${duration}
# HELP backup_last_run_timestamp Backup last run timestamp
# TYPE backup_last_run_timestamp gauge
backup_last_run_timestamp{server="$(hostname)",type="${BACKUP_TYPE}"} $(date +%s)
# HELP backup_last_success_timestamp Backup last success timestamp
# TYPE backup_last_success_timestamp gauge
backup_last_success_timestamp{server="$(hostname)",type="${BACKUP_TYPE}"} $(if [ "$status" -eq 1 ]; then date +%s; else echo 0; fi)
EOF
    
    mv "${METRICS_FILE}.$$" "$METRICS_FILE"
}

acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_time=$(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)
        local current_time=$(date +%s)
        local lock_age=$((current_time - lock_time))
        
        if [ $lock_age -gt $LOCK_TIMEOUT ]; then
            log_warning "Removing stale lock file (age: ${lock_age}s)"
            rm -f "$LOCK_FILE"
        else
            local lock_host=$(cat "$LOCK_FILE" 2>/dev/null | cut -d: -f1)
            log_info "Backup already running on: $lock_host (lock age: ${lock_age}s)"
            return 1
        fi
    fi
    
    echo "$(hostname):$(date '+%Y-%m-%d %H:%M:%S')" > "$LOCK_FILE"
    if [ $? -eq 0 ]; then
        log_info "Lock acquired successfully"
        LOCK_ACQUIRED=1
        return 0
    else
        log_error "Failed to create lock file"
        return 1
    fi
}

release_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_host=$(cat "$LOCK_FILE" 2>/dev/null | cut -d: -f1)
        if [ "$lock_host" = "$(hostname)" ]; then
            rm -f "$LOCK_FILE"
            log_info "Lock released"
            LOCK_ACQUIRED=0
        else
            log_warning "Attempted to release lock owned by: $lock_host"
        fi
    fi
}

perform_backup() {
    local start_time=$(date +%s)
    log_info "Starting backup process"
    
    sudo make backup-tarantool ENV=$BACKUP_ENV EXTRA_VARS="-e tarantool_remote_backups_dir=/mnt/tnt_backups/$BACKUP_TYPE"
    
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        log_info "Backup process completed successfully in ${duration}s"
        update_metrics 1 $duration $size
    else
        log_error "Backup process failed after ${duration}s"
        update_metrics 0 $duration 0
    fi
    
    return $exit_code
}

trap cleanup EXIT

log_info "Backup script started for type: $BACKUP_TYPE"

SCRIPT_START=$(date +%s)

if acquire_lock; then
    log_info "Starting backup on $(hostname)"
    perform_backup
    BACKUP_EXIT=$?
    log_info "Backup script finished"
else
    log_info "Skipping backup - already running elsewhere"
    SCRIPT_END=$(date +%s)
    SCRIPT_DURATION=$((SCRIPT_END - SCRIPT_START))
    update_metrics 2 $SCRIPT_DURATION 0
    exit 0
fi

exit $BACKUP_EXIT