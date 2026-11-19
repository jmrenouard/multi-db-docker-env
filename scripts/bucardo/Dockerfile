FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    bucardo \
    postgresql-client \
    libdbd-pg-perl \
    perl \
    && mkdir -p /var/run/bucardo /var/log/bucardo \
    && rm -rf /var/lib/apt/lists/*
CMD ["tail", "-f", "/dev/null"]
