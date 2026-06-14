# time-monitor

Monitors local clock offset against public NTP servers from inside a Docker container. Useful when you cannot access the host NTP daemon but need to verify that the system clock is synchronized.

Runs [chrony](https://chrony-project.org/) in tracking-only mode (`-x`) so it measures the offset without ever adjusting the clock, then reports min/max/average offset at a configurable interval.

## Usage

### Interactive

```bash
docker run --rm --init -it ghcr.io/mattiash/time-monitor
```

`-it` allocates a TTY so that Ctrl-C is delivered through the PTY driver directly to the container. `--init` adds tini as PID 1 for clean process reaping.

### As a background service

```bash
docker run -d --init --name time-monitor ghcr.io/mattiash/time-monitor
docker logs -f time-monitor   # stream output
docker stop time-monitor      # stop cleanly
```

Sample output:

```
Sample: 1.0s   Report: 10.0s   (10 samples/report)

Timestamp                  Samples           Min           Max           Avg
---------------------------------------------------------------------------
2026-06-14T18:00:10Z            10      +0.412ms      +0.823ms      +0.601ms
2026-06-14T18:00:20Z            10      +0.388ms      +0.751ms      +0.534ms
```

## Configuration

### NTP servers

Pass a space-separated list of servers via `NTP_SERVERS` (defaults to `pool.ntp.org time.cloudflare.com time.google.com`):

```bash
docker run --rm --init -it -e NTP_SERVERS="pool.ntp.org time.google.com" ghcr.io/mattiash/time-monitor
```

### Reporting interval and sample rate

```bash
# Report every 60s, sample every 5s (12 samples per report)
docker run --rm --init -it ghcr.io/mattiash/time-monitor --interval 60 --sample 5
```

| Flag | Default | Description |
|---|---|---|
| `--interval` | `10` | How often to print a report (seconds) |
| `--sample` | `1` | How often to sample chrony (seconds) |
