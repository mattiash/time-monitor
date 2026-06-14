#!/usr/bin/env -S uv run
# /// script
# dependencies = []
# ///

import argparse
import os
import re
import signal
import subprocess
import sys
import time


def read_chrony_offset():
    try:
        result = subprocess.run(["chronyc", "-n", "tracking"], capture_output=True, text=True, timeout=5)
    except subprocess.TimeoutExpired:
        raise RuntimeError("chronyc timed out")
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "chronyc exited non-zero")

    for line in result.stdout.splitlines():
        # "System time     : 0.000054321 seconds slow of NTP time"
        m = re.match(r'\s*System time\s*:\s*(\d+(?:\.\d+)?(?:e[+-]?\d+)?) seconds (slow|fast)', line)
        if m:
            offset = float(m.group(1))
            return -offset if m.group(2) == "slow" else offset

    raise RuntimeError("could not parse 'System time' from chronyc output")


def format_ms(seconds):
    return f"{seconds * 1000:+.3f}ms"


def main():
    def _shutdown(signum, frame):
        print("\nStopped.", flush=True)
        os._exit(0)

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    parser = argparse.ArgumentParser(
        description="Report local clock offset via chrony. Samples frequently, reports stats each interval."
    )
    parser.add_argument("--interval", type=float, default=10.0, metavar="SECONDS",
                        help="Reporting interval in seconds (default: 10)")
    parser.add_argument("--sample", type=float, default=1.0, metavar="SECONDS",
                        help="Sample interval in seconds (default: 1)")
    args = parser.parse_args()

    samples_per_interval = max(1, round(args.interval / args.sample))

    print(f"Sample: {args.sample}s   Report: {args.interval}s   ({samples_per_interval} samples/report)")
    print()
    print(f"{'Timestamp':25s}  {'Samples':>7s}  {'Min':>12s}  {'Max':>12s}  {'Avg':>12s}")
    print("-" * 75)

    while True:
        offsets = []
        errors = 0

        for _ in range(samples_per_interval):
            t0 = time.monotonic()
            try:
                offsets.append(read_chrony_offset())
            except Exception as e:
                errors += 1
                print(f"  [WARN] {e}", file=sys.stderr)
            elapsed = time.monotonic() - t0
            time.sleep(max(0.0, args.sample - elapsed))

        ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

        if offsets:
            label = f"{len(offsets)}" + (f"(-{errors})" if errors else "")
            print(
                f"{ts:25s}  {label:>7s}  "
                f"{format_ms(min(offsets)):>12s}  "
                f"{format_ms(max(offsets)):>12s}  "
                f"{format_ms(sum(offsets) / len(offsets)):>12s}"
            )
        else:
            print(f"{ts:25s}  all {errors} samples failed", file=sys.stderr)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nStopped.")
        sys.exit(0)
