#!/bin/sh
set -e

NTP_SERVERS="${NTP_SERVERS:-pool.ntp.org time.cloudflare.com time.google.com}"

mkdir -p /run/chrony /var/lib/chrony /var/log/chrony
chown _chrony:_chrony /run/chrony /var/lib/chrony /var/log/chrony
chmod 750 /run/chrony

# Generate chrony config from NTP_SERVERS
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

CHRONY_LOG=/tmp/chronyd.log

# -x: track offset without adjusting the clock
# -d: don't daemonize, log to stderr
chronyd -x -d -f /etc/chrony/chrony.conf >"$CHRONY_LOG" 2>&1 &
CHRONY_PID=$!

# Wait for the Unix socket to appear (up to 10s)
i=0
until [ -S /run/chrony/chronyd.sock ]; do
    if ! kill -0 "$CHRONY_PID" 2>/dev/null; then
        echo "ERROR: chronyd exited unexpectedly. Output:" >&2
        cat "$CHRONY_LOG" >&2
        exit 1
    fi
    i=$((i + 1))
    if [ "$i" -ge 10 ]; then
        echo "ERROR: socket not found after 10s. chronyd output:" >&2
        cat "$CHRONY_LOG" >&2
        echo "Contents of /run/chrony:" >&2
        ls -la /run/chrony/ >&2
        echo "All sockets under /run:" >&2
        find /run -name "*.sock" 2>/dev/null >&2 || true
        exit 1
    fi
    sleep 1
done

cat "$CHRONY_LOG" >&2
tail -f "$CHRONY_LOG" >&2 &

exec python3 /app/ntp_monitor.py "$@"
