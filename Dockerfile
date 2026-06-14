FROM debian:bookworm-slim

ENV PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends chrony python3 \
    && rm -rf /var/lib/apt/lists/*

COPY ntp_monitor.py /app/ntp_monitor.py
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
