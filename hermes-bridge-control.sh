#!/bin/sh
# Hermes ACP Bridge process manager
# Runs as www-data (no sudo needed)
# Actions: start, stop, restart, status

HERMES_HOME="${HERMES_HOME:-/var/www/moodledata/.hermes}"
PID_DIR="$HERMES_HOME/pids"
mkdir -p "$PID_DIR"

PROXY_PID_FILE="$PID_DIR/hermes-proxy.pid"
ACP_PID_FILE="$PID_DIR/hermes-acp.pid"

pid_is_running() {
    [ -f "$1" ] || return 1
    pid=$(cat "$1" 2>/dev/null | tr -d '[:space:]')
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || return 1
    return 0
}

stop_by_pid() {
    pid_file="$1"
    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file" 2>/dev/null | tr -d '[:space:]')
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null
            sleep 1
            kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
        fi
        rm -f "$pid_file"
    fi
}

stop_by_pattern() {
    # Fallback: kill processes matching the given command pattern
    pattern="$1"
    pids=$(pgrep -f "$pattern" 2>/dev/null)
    if [ -n "$pids" ]; then
        for pid in $pids; do
            # Don't kill ourselves
            [ "$pid" = "$$" ] && continue
            kill "$pid" 2>/dev/null
        done
        sleep 1
        # Force kill anything still alive
        pids=$(pgrep -f "$pattern" 2>/dev/null)
        for pid in $pids; do
            [ "$pid" = "$$" ] && continue
            kill -9 "$pid" 2>/dev/null
        done
    fi
}

start_proxy() {
    if pid_is_running "$PROXY_PID_FILE"; then
        cat "$PROXY_PID_FILE"
        return 0
    fi
    HERMES_HOME="$HERMES_HOME" nohup "$HERMES_HOME/venv/bin/python" "$HERMES_HOME/venv/bin/hermes_proxy_forward.py" >/dev/null 2>&1 &
    echo $! > "$PROXY_PID_FILE"
    sleep 1
    if pid_is_running "$PROXY_PID_FILE"; then
        cat "$PROXY_PID_FILE"
        return 0
    else
        rm -f "$PROXY_PID_FILE"
        echo "FAILED" >&2
        return 1
    fi
}

start_acp() {
    if pid_is_running "$ACP_PID_FILE"; then
        cat "$ACP_PID_FILE"
        return 0
    fi
    HERMES_HOME="$HERMES_HOME" nohup "$HERMES_HOME/venv/bin/hermes" acp >/dev/null 2>&1 &
    echo $! > "$ACP_PID_FILE"
    sleep 1
    if pid_is_running "$ACP_PID_FILE"; then
        cat "$ACP_PID_FILE"
        return 0
    else
        rm -f "$ACP_PID_FILE"
        echo "FAILED" >&2
        return 1
    fi
}

do_stop() {
    # First try PID files
    stop_by_pid "$PROXY_PID_FILE"
    stop_by_pid "$ACP_PID_FILE"

    # Fallback: kill by command pattern (catches orphaned processes)
    stop_by_pattern "hermes_proxy_forward.py"
    stop_by_pattern "hermes acp"
    stop_by_pattern "moodle_db_mcp.py"

    echo "stopped"
}

do_start() {
    # Kill any stale processes first
    stop_by_pattern "hermes_proxy_forward.py"
    stop_by_pattern "hermes acp"
    stop_by_pattern "moodle_db_mcp.py"
    rm -f "$PROXY_PID_FILE" "$ACP_PID_FILE"
    sleep 1

    proxy_pid=$(start_proxy)
    proxy_ret=$?
    acp_pid=$(start_acp)
    acp_ret=$?
    echo "proxy=$proxy_pid acp=$acp_pid proxy_ret=$proxy_ret acp_ret=$acp_ret"
}

do_restart() {
    do_stop
    sleep 1
    do_start
}

case "$1" in
    start)
        do_start
        ;;
    stop)
        do_stop
        ;;
    restart)
        do_restart
        ;;
    status)
        proxy_pid=""
        acp_pid=""
        if [ -f "$PROXY_PID_FILE" ]; then
            pid=$(cat "$PROXY_PID_FILE" 2>/dev/null | tr -d '[:space:]')
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                proxy_pid="$pid"
            else
                rm -f "$PROXY_PID_FILE"
            fi
        fi
        if [ -f "$ACP_PID_FILE" ]; then
            pid=$(cat "$ACP_PID_FILE" 2>/dev/null | tr -d '[:space:]')
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                acp_pid="$pid"
            else
                rm -f "$ACP_PID_FILE"
            fi
        fi
        echo "proxy=$proxy_pid acp=$acp_pid"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}" >&2
        exit 1
        ;;
esac
