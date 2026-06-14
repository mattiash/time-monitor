#!/bin/sh
set -e

NTP_SERVERS="${NTP_SERVERS:-pool.ntp.org time.cloudflare.com time.google.com}"

mkdir -p /run/chrony /var/lib/chrony /var/log/chrony
chown _chrony:_chrony /run/chrony /var/lib/chrony /var/log/chrony
chmod 750 /run/chrony

{
    for server in $NTP_SERVERS; do
        printf 'server %s iburst\n' "$server"
    done
    cat <<'EOF'
driftfile /var/lib/chrony/drift
port 0
logdir /var/log/chrony
EOF
} > /etc/chrony/chrony.conf

# -x: track offset without adjusting the clock
# -d: don't daemonize; writes log to stderr which goes to docker logs
chronyd -x -d -f /etc/chrony/chrony.conf &
CHRONY_PID=$!

i=0
until [ -S /run/chrony/chronyd.sock ]; do
    if ! kill -0 "$CHRONY_PID" 2>/dev/null; then
        echo "ERROR: chronyd exited unexpectedly" >&2
        exit 1
    fi
    i=$((i + 1))
    if [ "$i" -ge 10 ]; then
        echo "ERROR: chronyd socket not found after 10s" >&2
        ls -la /run/chrony/ >&2
        exit 1
    fi
    sleep 1
done

python3 /app/ntp_monitor.py "$@" &
PYTHON_PID=$!

# Kill both children and wait for them on any signal or normal exit
cleanup() {
    kill "$PYTHON_PID" "$CHRONY_PID" 2>/dev/null
    wait
}
trap cleanup INT TERM EXIT

# Wait for Python; returns when Python exits or a signal fires the trap
wait "$PYTHON_PID"
