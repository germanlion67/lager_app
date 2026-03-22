# ============================================================
# PocketBase with Auto-Initialization
# 
# Based on official PocketBase image but adds:
# - Automatic admin user creation on first start
# - Automatic migration application
# - Configuration via environment variables
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

# Create directories
RUN mkdir -p /pb_data /pb_public /pb_migrations

# Set working directory
WORKDIR /pb

# Environment variables (can be overridden)
ENV PB_DATA_DIR=/pb_data
ENV PB_MIGRATIONS_DIR=/pb_migrations
ENV PB_ADMIN_EMAIL=admin@example.com
ENV PB_ADMIN_PASSWORD=changeme123

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=5 --start-period=10s \
    CMD wget --spider -q http://localhost:8080/api/health || exit 1

# Entrypoint script that runs initialization in background, then starts PocketBase
CMD sh -c '/pb/pocketbase serve --http=0.0.0.0:8080 --dir=/pb_data & \
    PB_PID=$! && \
    sleep 3 && \
    /pb/init-pocketbase.sh && \
    wait $PB_PID'
