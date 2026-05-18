# Dockerfile for kind explain.depesz.com local lab
# 
# PRE-REQUISITE: run `./scripts/fetch-upstream.sh` before building.
# That script clones the upstream source into app/docker/src/explain.depesz.com/
# We COPY it here rather than cloning inside the Dockerfile so that:
#   - Docker layer cache is preserved across rebuilds (no network hit)
#   - Builds work offline after the initial fetch
#   - You can pin a specific commit via UPSTREAM_REF in fetch-upstream.sh
#
# Build (from repo root):
#   ./scripts/fetch-upstream.sh
#   docker build -t pg-explain-app:latest ./app/docker
#
# Run locally (for testing outside k8s):
#   docker run -e DATABASE_URL=postgresql://explain_app:pw@host/explain \
#              -p 5000:5000 pg-explain-app:latest
# 

FROM perl:5.38-slim AS builder

ARG PGFORMATTER_VERSION=5.9

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    curl \
    cpanminus \
    libpq-dev \
    gcc \
    make \
    ca-certificates \
    libexpat1-dev \
    xz-utils \
    liblzma-dev \
 && rm -rf /var/lib/apt/lists/*

# Install pgFormatter from source
RUN set -eux; \
    curl -fsSL \
      -o "pgFormatter-v${PGFORMATTER_VERSION}.tar.gz" \
      "https://github.com/darold/pgFormatter/archive/refs/tags/v${PGFORMATTER_VERSION}.tar.gz"; \
    tar xzf "pgFormatter-v${PGFORMATTER_VERSION}.tar.gz"; \
    cd "pgFormatter-${PGFORMATTER_VERSION}"; \
    perl Makefile.PL; \
    make; \
    make install; \
    cd /; \
    rm -rf \
      "/pgFormatter-v${PGFORMATTER_VERSION}.tar.gz" \
      "/pgFormatter-${PGFORMATTER_VERSION}"

# Copy cpanfile first for layer-cache efficiency (only re-run cpanm if cpanfile changes)
COPY src/explain.depesz.com/cpanfile /tmp/app/cpanfile
WORKDIR /tmp/app
RUN cpanm --notest --installdeps . \
 && cpanm --notest LWP::Simple
WORKDIR /

# ── Runtime stage ──────────────────────────────────────────────────────────
FROM perl:5.38-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    ca-certificates \
    postgresql-client \
 && rm -rf /var/lib/apt/lists/*

# Copy installed Perl modules from builder
COPY --from=builder /usr/local/lib/perl5 /usr/local/lib/perl5
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy pre-fetched upstream source (run ./scripts/fetch-upstream.sh first)
# The .dockerignore excludes src/**/.git so the image stays lean.
COPY src/explain.depesz.com/ /app/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /app

# Non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser \
 && chown -R appuser:appuser /app

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD perl -MLWP::Simple -e 'exit(get("http://localhost:3000/") ? 0 : 1)' \
    || exit 1

# This does some initialization before running the app, such as waiting for the database to be ready.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/app/explain.pl", "daemon", "-l", "http://0.0.0.0:3000"]
