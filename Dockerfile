# Stage 1: Builder for downloading and extracting the binary
FROM alpine:latest AS builder

# ARG for version and architecture (useful for GitLab CI)
ARG BACKHAUL_VERSION=latest
ARG ARCH_NAME

# Set environment variables
ENV BACKHAUL_CONFIG="/app/config.toml"

# Install prerequisites for download
RUN apk add --no-cache curl ca-certificates tar

# Detect architecture if ARG is not provided
RUN if [ -z "$ARCH_NAME" ]; then \
        ARCH=$(uname -m); \
        case $ARCH in \
            x86_64) ARCH_NAME="amd64" ;; \
            aarch64) ARCH_NAME="arm64" ;; \
            armv7l) ARCH_NAME="armv7" ;; \
            *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
        esac; \
    fi && \
    if [ "$BACKHAUL_VERSION" = "latest" ]; then \
        URL="https://github.com/Musixal/Backhaul/releases/latest/download/backhaul_linux_${ARCH_NAME}.tar.gz"; \
    else \
        URL="https://github.com/Musixal/Backhaul/releases/download/$BACKHAUL_VERSION/backhaul_linux_${ARCH_NAME}.tar.gz"; \
    fi && \
    echo "Downloading Backhaul version $BACKHAUL_VERSION for $ARCH_NAME" && \
    curl -L "$URL" -o /tmp/backhaul.tar.gz && \
    tar -xzf /tmp/backhaul.tar.gz -C /tmp && \
    mv /tmp/backhaul /tmp/backhaul-bin && \
    chmod +x /tmp/backhaul-bin && \
    rm /tmp/backhaul.tar.gz

# Final stage: Runtime image
FROM alpine:latest

# ARG for version (for metadata)
ARG BACKHAUL_VERSION=latest

# Set environment variables
ENV BACKHAUL_CONFIG="/app/config.toml"

# Install runtime prerequisites
RUN apk add --no-cache ca-certificates tzdata

# Copy binary from builder stage
COPY --from=builder /tmp/backhaul-bin /usr/local/bin/backhaul

# Create application directory
WORKDIR /app

# Create non-root user for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

USER appuser

# Set default ports
EXPOSE 3080 2060

# Set health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep backhaul || exit 1

# Run Backhaul
CMD ["backhaul", "-c", "${BACKHAUL_CONFIG}"]

# Add labels for GitLab CI and metadata
LABEL org.opencontainers.image.version="${BACKHAUL_VERSION}" \
      org.opencontainers.image.source="https://github.com/Musixal/Backhaul" \
      org.opencontainers.image.description="Backhaul reverse tunneling in Docker" 