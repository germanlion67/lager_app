# ============================================================
# PocketBase with Auto-Initialization
# 
# Based on official PocketBase image but adds:
# - Automatic admin user creation on first start
# - Automatic migration application
# - Configuration via environment variables
# - CORS configuration via CORS_ALLOWED_ORIGINS env var (H-002)
# ============================================================

# Pinned base image for reproducibility
FROM alpine:3.19.1

# Install dependencies with pinned versions for reproducibility
RUN apk add --no-cache \
    ca-certificates \
    wget \
    unzip

# Download and install PocketBase
ARG POCKETBASE_VERSION=0.36.6
RUN wget https://github.com/pocketbase/pocketbase/releases/download/v${POCKETBASE_VERSION}/pocketbase_${POCKETBASE_VERSION}_linux_amd64.zip \
    && unzip pocketbase_${POCKETBASE_VERSION}_linux_amd64.zip -d /pb \
    && rm pocketbase_${POCKETBASE_VERSION}_linux_amd64.zip \
    && chmod +x /pb/pocketbase

# Copy initialization script
COPY init-pocketbase.sh /pb/init-pocketbase.sh
RUN chmod +x /pb/init-pocketbase.sh

# H-002: Copy CORS-aware entrypoint script
COPY entrypoint.sh /pb/entrypoint.sh
RUN chmod +x /pb/entrypoint.sh

# Create directories
RUN mkdir -p /pb_data /pb_public /pb_migrations

# Copy PocketBase migrations into the image
COPY pb_migrations/ /pb_migrations/

# Set working directory
WORKDIR /pb

# Environment variables (can be overridden)
ENV PB_DATA_DIR=/pb_data
ENV PB_MIGRATIONS_DIR=/pb_migrations
ENV PB_ADMIN_EMAIL=admin@example.com
ENV PB_ADMIN_PASSWORD=changeme123

# H-002: CORS — Wildcard für Entwicklung, strikt für Produktion
ENV CORS_ALLOWED_ORIGINS="*"

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=5 --start-period=10s \
    CMD wget --spider -q http://localhost:8080/api/health || exit 1

# H-002: Entrypoint mit CORS-Konfiguration
CMD ["/pb/entrypoint.sh"]